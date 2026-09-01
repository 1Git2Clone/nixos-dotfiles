#!/usr/bin/env bash
#
# NixOS install for hutao-laptop, run from a NixOS live environment.
#
#   LVM-on-LUKS. One passphrase at boot. Immutable users seeded from sops,
#   whose age identity is the machine's own ssh host key.
#
# Your passwords are read with `read -s`, never echoed, never written to
# disk in plaintext except the transient LUKS keyfile, which is shredded on
# exit (including on failure or Ctrl-C).
#
# Usage:
#   nix-shell -p sops age ssh-to-age mkpasswd git --run ./install.sh
#
set -euo pipefail

HOST="hutao-laptop"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUKS_KEY="/tmp/luks.key"
HOSTKEY="/tmp/ssh_host_ed25519_key"
PLAIN_SECRETS="/tmp/secrets.plain.yaml"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() {
  for f in "$LUKS_KEY" "$PLAIN_SECRETS"; do
    [[ -f $f ]] && shred -u "$f" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

confirm() {
  local reply
  read -rp "$1 [y/N] " reply
  [[ $reply == [yY] ]] || die "Aborted."
}

# Read a secret twice, compare, never echo. Result in the named global.
read_secret_twice() {
  local varname=$1 prompt=$2 first second
  while :; do
    read -rsp "$prompt: " first; echo
    read -rsp "$prompt (again): " second; echo
    [[ -z $first ]] && { warn "Empty. Try again."; continue; }
    [[ $first == "$second" ]] && break
    warn "They don't match. Try again."
  done
  printf -v "$varname" '%s' "$first"
}

# ── 0. Preflight ────────────────────────────────────────────────────────────
bold "── Preflight ──"
[[ $EUID -eq 0 ]] || die "Run as root (sudo -i, then re-run)."
[[ -d /sys/firmware/efi ]] || die "Not booted in UEFI mode. Limine needs UEFI here."

for t in sops age ssh-to-age mkpasswd git nixos-install; do
  command -v "$t" >/dev/null \
    || die "Missing '$t'. Re-run inside: nix-shell -p sops age ssh-to-age mkpasswd git --run ./install.sh"
done

ping -c1 -W3 cache.nixos.org >/dev/null 2>&1 || warn "cache.nixos.org unreachable — install will be very slow or fail."
info "UEFI ✓  tools ✓"

# ── 1. Pick the disk ────────────────────────────────────────────────────────
bold ""
bold "── Target disk ──"
lsblk -o NAME,SIZE,MODEL,TYPE,TRAN
echo
info "Stable by-id paths:"
ls -l /dev/disk/by-id/ | grep -vE 'part|CD-ROM' | awk '{print "   " $9 "  ->  " $11}' | grep -v '^   ->'
echo
read -rp "Full /dev/disk/by-id/... path for the target disk: " DISK
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
read -rp "Type the disk size ($SIZE) to confirm: " typed
[[ $typed == "$SIZE" ]] || die "Mismatch. Aborted — nothing was touched."

# Warn if the layout won't fit comfortably.
SIZE_G=$(( $(lsblk -bdno SIZE "$RESOLVED") / 1024 / 1024 / 1024 ))
if (( SIZE_G < 200 )); then
  warn "Disk is ${SIZE_G}G. Default layout (2G ESP + 12G swap + 90G root) leaves"
  warn "only ~$(( SIZE_G - 104 ))G for /home. Consider editing hosts/$HOST/disk.nix first."
  confirm "Continue anyway?"
fi

# ── 2. Credentials ──────────────────────────────────────────────────────────
bold ""
bold "── Credentials ──"
info "Nothing here is echoed or stored in plaintext."
echo
read_secret_twice LUKS_PASS   "LUKS passphrase (typed at every boot)"
read_secret_twice HUTAO_PASS  "Password for user 'hutao'"
read_secret_twice ROOT_PASS   "Password for 'root' (emergency access)"

echo
info "Optionally add a second sops recipient so you can edit secrets from"
info "another machine later. Adding recipients afterwards needs a rekey, so"
info "it is much cheaper to do it now."
read -rp "Path or contents of an ssh ed25519 *public* key (blank to skip): " EXTRA_PUB

# ── 3. Host key -> age identity ─────────────────────────────────────────────
bold ""
bold "── sops identity ──"
rm -f "$HOSTKEY" "$HOSTKEY.pub"
ssh-keygen -t ed25519 -N "" -C "$HOST" -f "$HOSTKEY" >/dev/null
HOST_AGE=$(ssh-to-age -i "$HOSTKEY.pub")
info "host recipient: $HOST_AGE"

AGE_LIST=("$HOST_AGE")
if [[ -n $EXTRA_PUB ]]; then
  if [[ -f $EXTRA_PUB ]]; then EXTRA_AGE=$(ssh-to-age -i "$EXTRA_PUB")
  else EXTRA_AGE=$(printf '%s\n' "$EXTRA_PUB" | ssh-to-age); fi
  AGE_LIST+=("$EXTRA_AGE")
  info "extra recipient: $EXTRA_AGE"
fi

{
  echo "creation_rules:"
  echo "  - path_regex: secrets/[^/]+\.yaml\$"
  echo "    age:"
  for a in "${AGE_LIST[@]}"; do echo "      - $a"; done
} > "$REPO/.sops.yaml"

# ── 4. Encrypt the password hashes ──────────────────────────────────────────
info "Hashing passwords (sha-512 crypt — not sha512sum)."
HUTAO_HASH=$(printf '%s' "$HUTAO_PASS" | mkpasswd -m sha-512 --stdin)
ROOT_HASH=$(printf '%s' "$ROOT_PASS"  | mkpasswd -m sha-512 --stdin)

umask 077
cat > "$PLAIN_SECRETS" <<EOF
hutao-password: "$HUTAO_HASH"
root-password: "$ROOT_HASH"
EOF

mkdir -p "$REPO/secrets"
sops --config "$REPO/.sops.yaml" -e "$PLAIN_SECRETS" > "$REPO/secrets/secrets.yaml"
shred -u "$PLAIN_SECRETS"
info "secrets/secrets.yaml encrypted ✓"

# ── 5. Pin the disk into the config ─────────────────────────────────────────
sed -i "s|/dev/disk/by-id/REPLACE_ME|$DISK|" "$REPO/hosts/$HOST/disk.nix"
grep -q "$DISK" "$REPO/hosts/$HOST/disk.nix" || die "Failed to write disk path into disk.nix"
info "disk.nix pinned to $DISK"

# ── 6. Partition ────────────────────────────────────────────────────────────
bold ""
bold "── Partitioning ──"
# printf %s, NOT echo: a trailing newline becomes part of the passphrase and
# you would never be able to type it at the boot prompt.
printf '%s' "$LUKS_PASS" > "$LUKS_KEY"
chmod 600 "$LUKS_KEY"

confirm "Last chance. Run disko and destroy $DISK?"

cd "$REPO"
git add -A >/dev/null 2>&1 || true   # flakes ignore untracked files in a git repo

nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake ".#$HOST"

info "Partitioned and mounted:"
findmnt -R /mnt

# ── 7. Hardware config ──────────────────────────────────────────────────────
bold ""
bold "── Hardware detection ──"
# --no-filesystems: disko owns fileSystems.*, so generating them here would
# produce a duplicate-definition eval error.
nixos-generate-config --no-filesystems --root /mnt --dir /tmp/hwcfg
cp /tmp/hwcfg/hardware-configuration.nix "$REPO/hosts/$HOST/hardware-configuration.nix"
info "hardware-configuration.nix captured"

# ── 8. Seed the sops key BEFORE install ─────────────────────────────────────
# nixos-install runs activation, which decrypts the user password hashes.
# If the key is not in place first, the install fails at the last step.
install -Dm600 "$HOSTKEY"     /mnt/etc/ssh/ssh_host_ed25519_key
install -Dm644 "$HOSTKEY.pub" /mnt/etc/ssh/ssh_host_ed25519_key.pub
info "host key seeded to /mnt/etc/ssh ✓"

# ── 9. Install ──────────────────────────────────────────────────────────────
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
