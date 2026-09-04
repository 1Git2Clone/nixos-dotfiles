#!/usr/bin/env bash
#
# Install NixOS onto this machine, from a live environment.
#
#   INSTALL_AGE_KEY=/tmp/age.key HOST=hutao-desktop ./install.sh
#
# Credentials all come from secrets/secrets.yaml -- nothing is prompted for
# or written back. README > Install carries the why for each step below.
set -euo pipefail

HOST="${HOST:-hutao-laptop}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS="$REPO/secrets/secrets.yaml"
DISK_NIX="$REPO/hosts/$HOST/disk.nix"
LUKS_KEY=/tmp/luks-passphrase # modules/disk-layout.nix reads this exact path
AGE_KEY="${INSTALL_AGE_KEY:-${SOPS_AGE_KEY_FILE:-$HOME/.sops-nix/key.txt}}"
NONINTERACTIVE="${INSTALL_NONINTERACTIVE:-0}" # gated, so a stray INSTALL_* cannot skip the disk gate
export NIX_CONFIG="experimental-features = nix-command flakes"

say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
  exit 1
}
confirm() {
  [[ $NONINTERACTIVE == 1 ]] && return 0
  local reply
  read -rp "$1 [y/N] " reply
  [[ $reply == [yY] ]] || die "Aborted."
}
sops_get() { SOPS_AGE_KEY_FILE="$AGE_KEY" sops -d --extract "[\"$1\"]" "$SECRETS" 2>/dev/null; }
trap 'shred -u "$LUKS_KEY" 2>/dev/null || true' EXIT INT TERM

# ── Preflight ───────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run as root (sudo -i, then re-run)."
[[ -d /sys/firmware/efi ]] || die "Not booted in UEFI mode. Limine needs UEFI here."
for t in sops age git nixos-install nixos-generate-config; do
  command -v "$t" >/dev/null ||
    die "Missing '$t'. Re-run inside: nix-shell -p sops age git --run ./install.sh"
done
[[ -f $AGE_KEY ]] || die "No age key at $AGE_KEY. See README > Install."
[[ -f $SECRETS ]] || die "No $SECRETS. Author it first: sops secrets/secrets.yaml"
[[ -f $DISK_NIX ]] || die "No $DISK_NIX. See README > On new hardware."

# A non-recipient key installs cleanly, then cannot decrypt its own passwords.
AGE_PUB=$(age-keygen -y "$AGE_KEY") || die "$AGE_KEY is not a valid age private key."
grep -q "$AGE_PUB" "$REPO/.sops.yaml" ||
  die "$AGE_PUB is not a recipient in .sops.yaml -- the installed host could not decrypt anything."

for key in luks_passphrase root_password user_password tailscale_authkey; do
  value=$(sops_get "$key") || die "secrets.yaml has no '$key'. Add it: sops secrets/secrets.yaml"
  [[ -n $value ]] || die "'$key' is empty."
  # hashedPasswordFile wants crypt(3), not a digest. A sha512sum locks you out silently.
  case "$key=$value" in
    *_password='$'*'$'*) ;;
    *_password=*) die "'$key' is not a crypt(3) hash. Generate it with: mkpasswd -m yescrypt" ;;
  esac
done
say "UEFI, tools, age key ($AGE_PUB) and all four secrets check out"

# ── Target disk ─────────────────────────────────────────────────────────────
if [[ $NONINTERACTIVE == 1 ]]; then
  DISK="${INSTALL_DISK:?non-interactive mode needs INSTALL_DISK}"
else
  lsblk -o NAME,SIZE,MODEL,TYPE,TRAN
  say "Stable by-id paths (never /dev/nvme0n1, enumeration order moves):"
  find /dev/disk/by-id -type l -not -name '*-part*' -not -name '*cdrom*' \
    -printf '   %p -> ' -exec readlink -f {} \;
  read -rp "Full /dev/disk/by-id/... path for the target disk: " DISK
fi
[[ -b $DISK ]] || die "$DISK is not a block device."
SIZE=$(lsblk -bdno SIZE "$DISK" | numfmt --to=iec)

printf '\n\033[1;33m!! EVERYTHING ON THIS DISK WILL BE DESTROYED\n   %s\n   %s (%s)\033[0m\n\n' \
  "$DISK" "$(readlink -f "$DISK")" "$SIZE"
if [[ $NONINTERACTIVE != 1 ]]; then
  read -rp "Type the disk size ($SIZE) to confirm: " typed
  [[ $typed == "$SIZE" ]] || die "Mismatch. Aborted -- nothing was touched."
fi

# ── Pin the disk, capture the hardware ──────────────────────────────────────
# disko takes the device from the flake, so the choice has to land in disk.nix
# first. awk via ENVIRON: other substitution tools mangle by-id paths.
PINNED=$(awk -F'"' '/^[[:space:]]*device[[:space:]]*=/ { print $2; exit }' "$DISK_NIX")
[[ -n $PINNED ]] || die "$DISK_NIX has no 'device = \"...\";' line to pin. Fix it by hand."
if [[ $PINNED != "$DISK" ]]; then
  [[ $PINNED == */REPLACE_ME ]] ||
    confirm "$DISK_NIX names $PINNED, you chose $DISK. Rewrite it?"
  d="$DISK" awk '/^[[:space:]]*device[[:space:]]*=/ { printf "  device = \"%s\";\n", ENVIRON["d"]; next } { print }' \
    "$DISK_NIX" >"$DISK_NIX.tmp" && mv "$DISK_NIX.tmp" "$DISK_NIX"
  say "disk.nix pinned to $DISK"
fi

# --no-filesystems: disko owns fileSystems.*. Before the eval, which imports it.
nixos-generate-config --no-filesystems --dir /tmp/hwcfg
cp /tmp/hwcfg/hardware-configuration.nix "$REPO/hosts/$HOST/"

# ── Destroy, install ────────────────────────────────────────────────────────
cd "$REPO"
git add -A >/dev/null 2>&1 || true # flakes ignore untracked files
nix eval ".#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath" >/dev/null ||
  die "The flake does not evaluate. Disk untouched. Fix the error above and re-run."
confirm "Last chance. Run disko and destroy $DISK?"

printf '%s' "$(sops_get luks_passphrase)" >"$LUKS_KEY" # printf: a trailing \n is baked into the keyslot
chmod 600 "$LUKS_KEY"

disko_args=(--mode "destroy,format,mount" --flake ".#$HOST")
[[ $NONINTERACTIVE == 1 ]] && disko_args+=(--yes-wipe-all-disks)
nix run "$REPO#disko" -- "${disko_args[@]}"
findmnt -R /mnt
swapon --show | grep -q . || say "note: no swap active, a low-RAM machine may OOM during the build"

# Before nixos-install: activation renders the password hashes at its last step.
install -Dm600 "$AGE_KEY" /mnt/var/lib/sops-nix/key.txt
mkdir -p /mnt/etc/nixos && cp -r "$REPO"/. /mnt/etc/nixos/
nixos-install --flake "/mnt/etc/nixos#$HOST" --no-root-password # root's hash comes from sops

say "Done. Config is at /mnt/etc/nixos. Reboot, unlock with the LUKS passphrase, log in as hutao."
