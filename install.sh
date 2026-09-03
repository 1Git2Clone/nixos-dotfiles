#!/usr/bin/env bash
#
# NixOS install for hutao-laptop, from a live environment. LVM-on-LUKS.
#
#   ./install.sh                                  # this repo's ISO
#   nix-shell -p sops age git --run ./install.sh  # stock ISO
#
# Reads every credential from secrets/secrets.yaml — the LUKS passphrase, the
# root hash and the hutao hash. It prompts for nothing and writes nothing back
# into the repo. Author them first:
#
#   SOPS_AGE_KEY_FILE=~/.sops-nix/key.txt sops secrets/secrets.yaml
#
# See docs/sops-example.yaml for the shape. Bring your age key — see AGE_KEY.
set -euo pipefail

HOST="${HOST:-hutao-laptop}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# INSTALL_* overrides are honoured only with INSTALL_NONINTERACTIVE=1 set
# explicitly, so a stray variable cannot skip the destructive confirmation.
NONINTERACTIVE="${INSTALL_NONINTERACTIVE:-0}"

LUKS_KEY="/tmp/luks-passphrase" # must match modules/disk-layout.nix
SECRETS_FILE="$REPO/secrets/secrets.yaml"

# The identity .sops.yaml is encrypted to. Getting it here is the one manual
# step — a machine cannot bootstrap a decryption key from nothing:
#
#   scp ~/.sops-nix/key.txt nixos@<installer-ip>:/tmp/age.key
#   INSTALL_AGE_KEY=/tmp/age.key ./install.sh
AGE_KEY="${INSTALL_AGE_KEY:-${SOPS_AGE_KEY_FILE:-$HOME/.sops-nix/key.txt}}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -f $LUKS_KEY ]] && shred -u "$LUKS_KEY" 2>/dev/null
  return 0
}
trap cleanup EXIT INT TERM

confirm() {
  local reply
  if [[ $NONINTERACTIVE == 1 ]]; then
    warn "non-interactive: auto-confirming -- $1"
    return 0
  fi
  read -rp "$1 [y/N] " reply
  [[ $reply == [yY] ]] || die "Aborted."
}

# Pull one value out of secrets/secrets.yaml. Command substitution strips the
# trailing newline sops emits, which matters enormously for the passphrase: a
# stray \n gets baked into the LUKS keyslot and can never be typed at boot.
sops_get() {
  SOPS_AGE_KEY_FILE="$AGE_KEY" sops -d --extract "[\"$1\"]" "$SECRETS_FILE" 2>/dev/null
}

# ── 0. Preflight ────────────────────────────────────────────────────────────
bold "── Preflight ──"
[[ $EUID -eq 0 ]] || die "Run as root (sudo -i, then re-run)."
[[ -d /sys/firmware/efi ]] || die "Not booted in UEFI mode. Limine needs UEFI here."

for t in sops age git nixos-install; do
  command -v "$t" >/dev/null ||
    die "Missing '$t'. Re-run inside: nix-shell -p sops age git --run ./install.sh"
done

[[ -f $AGE_KEY ]] ||
  die "No age key at $AGE_KEY. Copy it over first, or set INSTALL_AGE_KEY. See the header."

# Fail now, not mid-install: a key that is not a recipient gives a machine
# that installs cleanly then cannot decrypt its own passwords.
AGE_PUB=$(age-keygen -y "$AGE_KEY" 2>/dev/null) ||
  die "$AGE_KEY is not a valid age private key."
grep -q "$AGE_PUB" "$REPO/.sops.yaml" ||
  die "$AGE_PUB is not a recipient in .sops.yaml — the installed host could not decrypt anything."

ping -c1 -W3 cache.nixos.org >/dev/null 2>&1 ||
  warn "cache.nixos.org unreachable — install will be very slow or fail."
info "UEFI ✓  tools ✓  age key ✓ ($AGE_PUB)"

# Every credential, resolved here — before the disk gate, so a missing or
# unreadable value costs nothing. Activation renders the two hashes at the very
# end of nixos-install; discovering one is absent there gives a partitioned
# disk holding a system nobody can log into.
[[ -f $SECRETS_FILE ]] ||
  die "No $SECRETS_FILE. Author it first: sops secrets/secrets.yaml (see docs/sops-example.yaml)."

SOPS_AGE_KEY_FILE="$AGE_KEY" sops -d "$SECRETS_FILE" >/dev/null 2>&1 ||
  die "$SECRETS_FILE does not decrypt with $AGE_KEY."

LUKS_PASS=$(sops_get luks_passphrase) ||
  die "secrets.yaml has no 'luks_passphrase'. Add it: sops secrets/secrets.yaml"
[[ -n $LUKS_PASS ]] || die "'luks_passphrase' is empty — the disk would have no passphrase."

# Not used here, only checked. sops-nix reads them from the same file during
# activation; this is the cheap place to find out they are missing.
for key in root_password user_password tailscale_authkey; do
  val=$(sops_get "$key") ||
    die "secrets.yaml has no '$key'. Add it: sops secrets/secrets.yaml"
  [[ -n $val ]] || die "'$key' is empty."
done
unset val

# hashedPasswordFile wants crypt(3) output, not a digest. A bare 128-hex
# sha512sum is the classic mistake and it locks you out silently.
for key in root_password user_password; do
  case "$(sops_get "$key")" in
    '$'*'$'*) ;;
    *) die "'$key' is not a crypt(3) hash. Generate it with: mkpasswd -m yescrypt" ;;
  esac
done
info "secrets ✓  luks_passphrase, root_password, user_password, tailscale_authkey"

# ── 1. Pick the disk ────────────────────────────────────────────────────────
bold ""
bold "── Target disk ──"
lsblk -o NAME,SIZE,MODEL,TYPE,TRAN
echo
info "Stable by-id paths:"
# Glob, not `ls | grep`: model strings contain spaces.
for link in /dev/disk/by-id/*; do
  [[ -e $link ]] || continue
  case $link in
    *-part*) continue ;;
    *CD-ROM* | *cdrom*) continue ;;
  esac
  printf '   %s  ->  %s\n' "$link" "$(readlink -f "$link")"
done
echo
if [[ $NONINTERACTIVE == 1 ]]; then
  DISK="${INSTALL_DISK:-}"
  [[ -n $DISK ]] || die "Non-interactive mode needs INSTALL_DISK set."
  info "non-interactive: target disk $DISK"
else
  read -rp "Full /dev/disk/by-id/... path for the target disk: " DISK
fi
[[ -b $DISK ]] || die "$DISK is not a block device."

RESOLVED=$(readlink -f "$DISK")
SIZE=$(lsblk -bdno SIZE "$RESOLVED" | numfmt --to=iec)

echo
warn "════════════════════════════════════════════════════════════"
warn " EVERYTHING ON THIS DISK WILL BE DESTROYED"
warn "   path:  $DISK"
warn "   real:  $RESOLVED  ($SIZE)"
warn "════════════════════════════════════════════════════════════"
echo
if [[ $NONINTERACTIVE == 1 ]]; then
  warn "non-interactive: skipping the type-the-size gate"
else
  read -rp "Type the disk size ($SIZE) to confirm: " typed
  [[ $typed == "$SIZE" ]] || die "Mismatch. Aborted — nothing was touched."
fi

# Tracks hosts/hutao-laptop/disk.nix — change both together.
SIZE_G=$(($(lsblk -bdno SIZE "$RESOLVED") / 1024 / 1024 / 1024))
if ((SIZE_G < 200)); then
  warn "Disk is ${SIZE_G}G. The layout (2G ESP + 20G swap + 120G root) leaves"
  warn "only ~$((SIZE_G - 142))G for /home. Consider editing hosts/$HOST/disk.nix first."
  confirm "Continue anyway?"
fi

# ── 2. Pin the disk into the config ─────────────────────────────────────────
sed -i "s|/dev/disk/by-id/REPLACE_ME|$DISK|" "$REPO/hosts/$HOST/disk.nix"
grep -q "$DISK" "$REPO/hosts/$HOST/disk.nix" || die "Failed to write disk path into disk.nix"
info "disk.nix pinned to $DISK"

# ── 3. Hardware detection ───────────────────────────────────────────────────
# MUST precede the evaluation below. The flake imports
# hardware-configuration.nix, so generating it after disko means the pre-disko
# eval can never succeed on a fresh clone.
#
# --no-filesystems: nothing here needs /mnt, and disko owns fileSystems.*.
bold ""
bold "── Hardware detection ──"
nixos-generate-config --no-filesystems --dir /tmp/hwcfg
cp /tmp/hwcfg/hardware-configuration.nix "$REPO/hosts/$HOST/hardware-configuration.nix"
info "hardware-configuration.nix captured"

# ── 4. Partition ────────────────────────────────────────────────────────────
bold ""
bold "── Partitioning ──"
# printf %s, NOT echo: a trailing newline becomes part of the passphrase.
printf '%s' "$LUKS_PASS" >"$LUKS_KEY"
chmod 600 "$LUKS_KEY"

# Before touching the disk: an eval error here costs a minute, not the disk.
info "Dry-evaluating the flake (nothing destructive yet)..."
cd "$REPO"
git add -A >/dev/null 2>&1 || true
if ! nix --extra-experimental-features "nix-command flakes" \
  eval ".#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath" \
  >/dev/null; then
  die "The flake does not evaluate. Disk untouched. Fix the error above and re-run."
fi
info "Flake evaluates ✓"

confirm "Last chance. Run disko and destroy $DISK?"

git add -A >/dev/null 2>&1 || true # flakes ignore untracked files in a git repo

# disko prompts on stdin, unanswerable over ssh. We have already asked twice
# by here. Mode is one comma-separated argument, hence the quotes (SC2054).
disko_args=(--mode "destroy,format,mount" --flake ".#$HOST")
[[ $NONINTERACTIVE == 1 ]] && disko_args+=(--yes-wipe-all-disks)

nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- "${disko_args[@]}"

info "Partitioned and mounted:"
findmnt -R /mnt

# ── 5. Turn the target's swap on ────────────────────────────────────────────
# disko formats the swap LV but never activates it, and the live / is tmpfs.
# On 8GB that combination OOM-kills nixos-install (exit 137) deep into the
# build. The 20G swap is already formatted; just switch it on.
bold ""
bold "── Swap ──"
if swapon /dev/pool/swap 2>/dev/null; then
  info "swap on: $(swapon --show=NAME,SIZE --noheadings | tr -s ' ')"
else
  warn "could not enable /dev/pool/swap — a machine with little RAM may OOM"
  warn "during the build below. Check 'lvs' if the install dies with 'Killed'."
fi

# ── 6. Seed the age key BEFORE install ──────────────────────────────────────
# nixos-install runs activation, which renders the password hashes. No key
# here means an install that fails at its last step, with no way in.
install -Dm600 "$AGE_KEY" /mnt/var/lib/sops-nix/key.txt
info "age key seeded to /mnt/var/lib/sops-nix/key.txt ✓"

# ── 7. Install ──────────────────────────────────────────────────────────────
bold ""
bold "── Installing ──"
mkdir -p /mnt/etc/nixos
cp -r "$REPO"/. /mnt/etc/nixos/
git -C /mnt/etc/nixos add -A >/dev/null 2>&1 || true

# root's hash comes from sops.
nixos-install --flake "/mnt/etc/nixos#$HOST" --no-root-password

bold ""
bold "════════════════════════════════════════════════════════════"
bold " Done."
bold "════════════════════════════════════════════════════════════"
info "Config installed at /mnt/etc/nixos (also still in $REPO)"
info "Push it:  git remote add origin https://git.hu-tao.dev/hutao/nixos-dotfiles && git push -u origin main"
echo
warn "First boot asks for the LUKS passphrase before anything graphical."
info "Then: reboot, unlock, log in as hutao."
