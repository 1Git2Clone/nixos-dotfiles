#!/usr/bin/env bash
#
# NixOS install for hutao-laptop, run from a NixOS live environment.
#
#   LVM-on-LUKS. One passphrase at boot. Immutable users whose password
#   hashes come from a sops file encrypted to your personal age key.
#
# Your passwords are read with `read -s`, never echoed, and never written to
# disk in plaintext except two transient files — the LUKS keyfile and the
# pre-encryption hash file — both shredded on exit, including on failure and
# on Ctrl-C.
#
# Usage, from the installer ISO built by this repo (which already has the
# tools):
#
#   ./install.sh
#
# or from the stock NixOS ISO:
#
#   nix-shell -p sops age ssh-to-age mkpasswd git --run ./install.sh
#
# You must bring your age private key with you. See "The age key" below.
set -euo pipefail

HOST="hutao-laptop"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Non-interactive mode ────────────────────────────────────────────────────
# vm/install-test.sh drives this script unattended. Every prompt below has an
# INSTALL_* override, but they are honoured ONLY when INSTALL_NONINTERACTIVE=1
# is set explicitly, so a stray variable in someone's environment can never
# silently skip the "this destroys the disk" confirmation on a real machine.
NONINTERACTIVE="${INSTALL_NONINTERACTIVE:-0}"

LUKS_KEY="/tmp/luks.key"
PLAIN_HASHES="$REPO/secrets/secrets.yaml"

# ── The age key ─────────────────────────────────────────────────────────────
# The identity that .sops.yaml is encrypted to. On a workstation this is
# ~/.sops-nix/key.txt; on the installed host it ends up at
# /var/lib/sops-nix/key.txt, put there by step 8 below.
#
# Getting it onto the live environment is the one genuinely manual step:
#
#   scp ~/.sops-nix/key.txt nixos@<installer-ip>:/tmp/age.key
#   INSTALL_AGE_KEY=/tmp/age.key ./install.sh
#
# There is no way around this. A machine cannot bootstrap a decryption key
# from nothing, and without one the first activation cannot render the user
# password hashes — leaving a machine with no way to log in.
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
  # If sops failed between writing and encrypting, this still holds plaintext
  # password hashes inside the repo. Shredding an already-encrypted file would
  # destroy the install, so only unencrypted content is removed.
  if [[ -f $PLAIN_HASHES ]] && ! grep -q '^sops:' "$PLAIN_HASHES" 2>/dev/null; then
    warn "removing un-encrypted $PLAIN_HASHES"
    shred -u "$PLAIN_HASHES" 2>/dev/null
  fi
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

# Read a secret twice, compare, never echo. Result in the named global.
read_secret_twice() {
  local varname=$1 prompt=$2 envvar=${3:-} first second
  if [[ $NONINTERACTIVE == 1 ]]; then
    [[ -n $envvar && -n ${!envvar:-} ]] ||
      die "Non-interactive mode needs $envvar set."
    printf -v "$varname" '%s' "${!envvar}"
    return 0
  fi
  while :; do
    read -rsp "$prompt: " first
    echo
    read -rsp "$prompt (again): " second
    echo
    [[ -z $first ]] && {
      warn "Empty. Try again."
      continue
    }
    [[ $first == "$second" ]] && break
    warn "They don't match. Try again."
  done
  printf -v "$varname" '%s' "$first"
}

# ── 0. Preflight ────────────────────────────────────────────────────────────
bold "── Preflight ──"
[[ $EUID -eq 0 ]] || die "Run as root (sudo -i, then re-run)."
[[ -d /sys/firmware/efi ]] || die "Not booted in UEFI mode. Limine needs UEFI here."

for t in sops age mkpasswd git nixos-install; do
  command -v "$t" >/dev/null ||
    die "Missing '$t'. Re-run inside: nix-shell -p sops age ssh-to-age mkpasswd git --run ./install.sh"
done

[[ -f $AGE_KEY ]] ||
  die "No age key at $AGE_KEY. Copy it over first, or set INSTALL_AGE_KEY. See the header."

# Fail here, not three minutes into an install, if this key is not actually a
# recipient. An age key that is not in .sops.yaml produces a machine that
# installs cleanly and then cannot decrypt its own passwords.
AGE_PUB=$(age-keygen -y "$AGE_KEY" 2>/dev/null) ||
  die "$AGE_KEY is not a valid age private key."
grep -q "$AGE_PUB" "$REPO/.sops.yaml" ||
  die "$AGE_PUB is not a recipient in .sops.yaml — the installed host could not decrypt anything."

ping -c1 -W3 cache.nixos.org >/dev/null 2>&1 ||
  warn "cache.nixos.org unreachable — install will be very slow or fail."
info "UEFI ✓  tools ✓  age key ✓ ($AGE_PUB)"

# ── 1. Pick the disk ────────────────────────────────────────────────────────
bold ""
bold "── Target disk ──"
lsblk -o NAME,SIZE,MODEL,TYPE,TRAN
echo
info "Stable by-id paths:"
# A glob rather than `ls | grep`: partition links are filtered by name and the
# target is resolved properly, so a disk whose model string contains a space
# does not get split into two columns.
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

# Warn if the layout won't fit. These numbers track hosts/hutao-laptop/disk.nix
# — 2G ESP + 20G swap + 120G root — so a change there needs a change here.
SIZE_G=$(($(lsblk -bdno SIZE "$RESOLVED") / 1024 / 1024 / 1024))
if ((SIZE_G < 200)); then
  warn "Disk is ${SIZE_G}G. The layout (2G ESP + 20G swap + 120G root) leaves"
  warn "only ~$((SIZE_G - 142))G for /home. Consider editing hosts/$HOST/disk.nix first."
  confirm "Continue anyway?"
fi

# ── 2. Credentials ──────────────────────────────────────────────────────────
bold ""
bold "── Credentials ──"
info "Nothing here is echoed or stored in plaintext."
echo
read_secret_twice LUKS_PASS "LUKS passphrase (typed at every boot)" INSTALL_LUKS_PASS
read_secret_twice HUTAO_PASS "Password for user 'hutao'" INSTALL_HUTAO_PASS
read_secret_twice ROOT_PASS "Password for 'root' (emergency access)" INSTALL_ROOT_PASS

# ── 3. Encrypt the password hashes ──────────────────────────────────────────
bold ""
bold "── Secrets ──"
info "Hashing passwords (sha-512 crypt — not sha512sum)."
# shellcheck disable=SC2153  # read_secret_twice assigns these with `printf -v`,
# which shellcheck cannot follow, so it reads them as typos of *_HASH.
HUTAO_HASH=$(printf '%s' "$HUTAO_PASS" | mkpasswd -m sha-512 --stdin)
# shellcheck disable=SC2153
ROOT_HASH=$(printf '%s' "$ROOT_PASS" | mkpasswd -m sha-512 --stdin)

# Written INSIDE the repo and encrypted in place, not piped in from /tmp.
# .sops.yaml matches on `secrets/<name>.yaml`, and a path like
# /tmp/plain.yaml does not match that rule — sops then exits with
# "no matching creation rules" and the install dies at step 3.
umask 077
mkdir -p "$REPO/secrets"
cat >"$PLAIN_HASHES" <<EOF
root_password: "$ROOT_HASH"
user_password: "$HUTAO_HASH"
EOF

sops --config "$REPO/.sops.yaml" -e -i "$PLAIN_HASHES" ||
  die "sops failed to encrypt. The plaintext file has been shredded."
grep -q '^sops:' "$PLAIN_HASHES" || die "sops produced a file with no metadata — refusing to continue."
info "secrets/secrets.yaml encrypted to $AGE_PUB ✓"

# Prove the round trip before the disk is touched. If this fails, the machine
# would install and then fail activation with no way in.
SOPS_AGE_KEY_FILE="$AGE_KEY" sops -d "$PLAIN_HASHES" >/dev/null ||
  die "Encrypted file does not decrypt with $AGE_KEY."
info "decryption round-trip verified ✓"

# ── 4. Pin the disk into the config ─────────────────────────────────────────
sed -i "s|/dev/disk/by-id/REPLACE_ME|$DISK|" "$REPO/hosts/$HOST/disk.nix"
grep -q "$DISK" "$REPO/hosts/$HOST/disk.nix" || die "Failed to write disk path into disk.nix"
info "disk.nix pinned to $DISK"

# ── 5. Hardware detection ───────────────────────────────────────────────────
# This MUST come before the evaluation below, not after disko.
#
# hosts/hutao-laptop/default.nix imports ./hardware-configuration.nix, so the
# flake cannot evaluate at all until that file exists. Generating it after
# disko — the obvious order, and what this script used to do — means the
# pre-disko evaluation always fails on a fresh clone with
#
#   error: path '…/hosts/hutao-laptop/hardware-configuration.nix' does not exist
#
# which defeats the entire point of evaluating before touching the disk.
#
# Nothing here needs /mnt. `--no-filesystems` reports kernel modules, CPU
# microcode and the host platform, all of which are properties of the machine
# you are standing at, not of the target filesystem. (It is also required for
# a different reason: disko owns `fileSystems.*`, and generating those here
# would be a duplicate definition.)
bold ""
bold "── Hardware detection ──"
nixos-generate-config --no-filesystems --dir /tmp/hwcfg
cp /tmp/hwcfg/hardware-configuration.nix "$REPO/hosts/$HOST/hardware-configuration.nix"
info "hardware-configuration.nix captured"

# ── 6. Partition ────────────────────────────────────────────────────────────
bold ""
bold "── Partitioning ──"
# printf %s, NOT echo: a trailing newline becomes part of the passphrase and
# you would never be able to type it at the boot prompt.
printf '%s' "$LUKS_PASS" >"$LUKS_KEY"
chmod 600 "$LUKS_KEY"

# Evaluate the flake BEFORE touching the disk. An eval error found here costs a
# minute; found after disko it costs the whole disk plus a reboot.
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

# disko asks "are you sure you want to wipe" itself, on stdin. Over a
# non-interactive ssh session there is nothing to answer with and it aborts.
# By this point install.sh has already asked twice — type-the-disk-size, then
# "Last chance" — so suppressing disko's third ask loses no real safety in the
# unattended path, and the interactive path keeps it.
# The mode value is one comma-separated argument, not three elements — quoted
# so shellcheck (SC2054) and the reader both see that.
disko_args=(--mode "destroy,format,mount" --flake ".#$HOST")
[[ $NONINTERACTIVE == 1 ]] && disko_args+=(--yes-wipe-all-disks)

nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- "${disko_args[@]}"

info "Partitioned and mounted:"
findmnt -R /mnt

# ── 7. Seed the age key BEFORE install ──────────────────────────────────────
# This is the step that matters. nixos-install runs activation, which renders
# the sops values — including the user password hashes. With
# users.mutableUsers = false and no key in place, the install fails at its last
# step and you get a machine with no way in.
install -Dm600 "$AGE_KEY" /mnt/var/lib/sops-nix/key.txt
info "age key seeded to /mnt/var/lib/sops-nix/key.txt ✓"

# ── 8. Install ──────────────────────────────────────────────────────────────
bold ""
bold "── Installing ──"
mkdir -p /mnt/etc/nixos
cp -r "$REPO"/. /mnt/etc/nixos/
git -C /mnt/etc/nixos add -A >/dev/null 2>&1 || true

# --no-root-password: root's hash comes from sops, so suppress the prompt.
nixos-install --flake "/mnt/etc/nixos#$HOST" --no-root-password

bold ""
bold "════════════════════════════════════════════════════════════"
bold " Done."
bold "════════════════════════════════════════════════════════════"
info "Config installed at /mnt/etc/nixos (also still in $REPO)"
info "Push it:  git remote add origin https://git.hu-tao.dev/hutao/nixos-dotfiles && git push -u origin main"
echo
warn "On first boot you will be asked for the LUKS passphrase BEFORE anything"
warn "graphical appears. If it rejects a passphrase you are sure is right, the"
warn "cause is almost always a trailing newline in the keyfile — not the case"
warn "here, but that is the thing to suspect."
echo
info "Then: reboot, unlock, log in as hutao."
