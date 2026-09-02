#!/usr/bin/env bash
#
# Install rehearsal: install.sh end to end against a blank virtual disk.
# Covers what hosts/hutao-vm cannot — disko, LUKS, LVM, the sops bootstrap, Limine,
# first boot. Use `nix run .#vm` for anything else; it is far faster.
#
#   all  build  up  install  boot  unlock  shot  ssh  down  clean
#
# Only state is $WORK. SEED=0 skips seeding the guest store from the host.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$HOME/.cache/nixos-vm-test}"

# Weak on purpose: typed one key at a time over the QEMU monitor (ASCII only).
LUKS_PASS="${LUKS_PASS:-test1234}"
USER_PASS="${USER_PASS:-test1234}"
ROOT_PASS="${ROOT_PASS:-test1234}"

DISK_SIZE="${DISK_SIZE:-512G}"
VM_RAM="${VM_RAM:-6144}"
VM_CPUS="${VM_CPUS:-6}"
SSH_PORT="${SSH_PORT:-2222}"

# Your real key, because the point is to prove that key works.
AGE_KEY="${AGE_KEY:-$HOME/.sops-nix/key.txt}"

KEY="$WORK/vmtest_key"
DISK="$WORK/disk.qcow2"
SERIAL="$WORK/serial.log"
MONITOR="$WORK/monitor.sock"
ISO_LINK="$WORK/installer.iso"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
  exit 1
}

mkdir -p "$WORK"

# Must be UEFI — a BIOS boot would silently test nothing.
find_ovmf() {
  [[ -n ${OVMF_CODE:-} ]] && return 0
  local c
  for c in \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
    /usr/share/qemu/edk2-x86_64-code.fd; do
    [[ -f $c ]] && {
      OVMF_CODE=$c
      break
    }
  done
  [[ -n ${OVMF_CODE:-} ]] || die "No OVMF firmware found. Set OVMF_CODE=/path/to/OVMF_CODE.fd"

  [[ -n ${OVMF_VARS_SRC:-} ]] && return 0
  for c in "${OVMF_CODE/CODE/VARS}" \
    /usr/share/edk2/x64/OVMF_VARS.4m.fd \
    /usr/share/OVMF/OVMF_VARS_4M.fd; do
    [[ -f $c ]] && {
      OVMF_VARS_SRC=$c
      break
    }
  done
  [[ -n ${OVMF_VARS_SRC:-} ]] || die "Found $OVMF_CODE but no matching VARS template."
}

mon() { printf '%s\n' "$*" | socat - "UNIX-CONNECT:$MONITOR" >/dev/null 2>&1 || true; }

vm_running() { [[ -S $MONITOR ]] && pgrep -f "qemu-system-x86_64.*nixos-install-test" >/dev/null; }

ssh_g() {
  ssh -q -i "$KEY" -p "$SSH_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 -o LogLevel=ERROR \
    root@localhost "$@"
}

# ── build ───────────────────────────────────────────────────────────────────
cmd_build() {
  bold "── Building the installer ISO ──"
  [[ -f "$KEY" ]] || {
    info "generating throwaway key $KEY"
    ssh-keygen -t ed25519 -N '' -C 'nixos-vm-test (throwaway)' -f "$KEY" >/dev/null
    info "add this to vm/authorized_keys and re-run:"
    cat "$KEY.pub"
  }
  grep -qFf <(cut -d' ' -f2 "$KEY.pub") "$REPO/vm/authorized_keys" ||
    die "$KEY.pub is not in vm/authorized_keys — the ISO would lock you out."

  nix build "$REPO#installer-iso" --out-link "$WORK/iso-result"
  local iso
  iso=$(echo "$WORK"/iso-result/iso/*.iso)
  [[ -f $iso ]] || die "No ISO produced."
  ln -sf "$iso" "$ISO_LINK"
  info "ISO: $(readlink -f "$ISO_LINK")"
}

# ── up ──────────────────────────────────────────────────────────────────────
cmd_up() {
  find_ovmf
  cmd_down
  [[ -e $ISO_LINK ]] || die "No ISO. Run: $0 build"

  bold "── Fresh disk + installer VM ──"
  rm -f "$DISK" "$SERIAL"
  qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
  cp "$OVMF_VARS_SRC" "$WORK/OVMF_VARS.fd"
  chmod u+w "$WORK/OVMF_VARS.fd"
  info "blank $DISK_SIZE disk created (sparse)"

  _boot --cdrom "$ISO_LINK" -boot d
  _wait_ssh 300
}

# ── boot (from the installed disk) ──────────────────────────────────────────
cmd_boot() {
  find_ovmf
  cmd_down
  bold "── Booting the installed system ──"
  [[ -f $DISK ]] || die "No disk at $DISK."
  _boot
  info "Booting. The LUKS prompt is on the graphical console, not serial."
  info "Next:  $0 unlock     then:  $0 shot"
}

_boot() {
  local extra=("$@")
  qemu-system-x86_64 \
    -name nixos-install-test \
    -machine q35,accel=kvm \
    -cpu host -smp "$VM_CPUS" -m "$VM_RAM" \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$WORK/OVMF_VARS.fd" \
    -drive if=none,id=nvm,format=qcow2,file="$DISK",cache=writeback,discard=unmap \
    -device nvme,serial=vmtestnvme0,drive=nvm \
    -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22" \
    -device virtio-net-pci,netdev=n0 \
    -device virtio-rng-pci \
    -serial "file:$SERIAL" \
    -monitor "unix:$MONITOR,server,nowait" \
    -vga std -display none \
    "${extra[@]}" &
  disown
  sleep 3
}

_wait_ssh() {
  local timeout=${1:-300} start now
  start=$(date +%s)
  info "waiting for sshd (up to ${timeout}s)…"
  # `if`, not `(( … )) && { … }`: under set -e the latter aborts the loop on
  # its first iteration.
  while ! ssh_g true 2>/dev/null; do
    now=$(date +%s)
    if ((now - start > timeout)); then
      tail -20 "$SERIAL" 2>/dev/null || true
      die "guest never came up on port $SSH_PORT"
    fi
    sleep 3
  done
  info "guest reachable ✓  $(ssh_g 'uname -sr')"
}

# ── seed ────────────────────────────────────────────────────────────────────
# `up` starts from a blank disk, so without this the guest re-downloads the
# whole desktop closure every run. hosts/hutao-vm shares nearly all of it with the
# laptop, so pushing that closure leaves only host-specific paths to fetch.
_seed_store() {
  if [[ ${SEED:-1} != 1 ]]; then
    info "SEED=0 — guest will download its own closure"
    return 0
  fi

  bold "── Seeding the guest store from the host ──"
  info "building the shared closure on the host (cached after the first run)"

  local top
  if ! top=$(nix build "$REPO#nixosConfigurations.hutao-vm.config.system.build.toplevel" \
    --no-link --print-out-paths 2>/dev/null); then
    warn "host build failed — the guest will download everything itself"
    return 0
  fi

  local bytes size
  bytes=$(nix path-info -S "$top" 2>/dev/null | awk '{print $2}')
  size=$(awk -v b="${bytes:-0}" 'BEGIN { printf "%.1f GiB", b/1073741824 }')
  info "copying $size into the guest"

  # NIX_SSHOPTS: the ssh store has no `port` parameter.
  if ! NIX_SSHOPTS="-i $KEY -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR" \
    nix copy --to "ssh-ng://root@localhost" --no-check-sigs "$top" 2>&1 | tail -3; then
    warn "nix copy failed — the guest will download instead"
    return 0
  fi
  info "store seeded ✓"
}

# ── install ─────────────────────────────────────────────────────────────────
cmd_install() {
  vm_running || die "No VM running. Run: $0 up"
  bold "── Copying the repo into the guest ──"

  # Fixed serial, so the by-id path is deterministic (disko needs that).
  local byid="/dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_vmtestnvme0"
  ssh_g "test -b $byid" ||
    die "Expected $byid in the guest. Check the -device nvme serial."

  ssh_g 'rm -rf /root/repo && mkdir -p /root/repo'
  rsync -a --delete --exclude '.git' --exclude 'result*' \
    -e "ssh -q -i $KEY -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR" \
    "$REPO"/ root@localhost:/root/repo/

  # install.sh refuses to start without it.
  [[ -f $AGE_KEY ]] || die "No age key at $AGE_KEY. Set AGE_KEY=/path/to/key.txt"
  scp -q -i "$KEY" -P "$SSH_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "$AGE_KEY" root@localhost:/tmp/age.key
  ssh_g 'chmod 600 /tmp/age.key'
  info "age key staged into the guest"

  _seed_store

  bold "── Running install.sh ──"
  warn "this builds the whole desktop closure in the guest — expect 20-45 min"

  ssh_g "cd /root/repo && \
    INSTALL_NONINTERACTIVE=1 \
    INSTALL_AGE_KEY=/tmp/age.key \
    INSTALL_DISK='$byid' \
    INSTALL_LUKS_PASS='$LUKS_PASS' \
    INSTALL_HUTAO_PASS='$USER_PASS' \
    INSTALL_ROOT_PASS='$ROOT_PASS' \
    ./install.sh" 2>&1 | tee "$WORK/install.log"

  info "install log: $WORK/install.log"
}

# ── unlock ──────────────────────────────────────────────────────────────────
# The installed system has no serial console, so the emulated keyboard is the
# only way to answer the LUKS prompt headless.
cmd_unlock() {
  vm_running || die "No VM running."
  info "typing the LUKS passphrase on the virtual keyboard"
  local c
  for ((i = 0; i < ${#LUKS_PASS}; i++)); do
    c="${LUKS_PASS:i:1}"
    case "$c" in
      [a-z]) mon "sendkey $c" ;;
      [A-Z]) mon "sendkey shift-$(tr '[:upper:]' '[:lower:]' <<<"$c")" ;;
      [0-9]) mon "sendkey $c" ;;
      -) mon "sendkey minus" ;;
      .) mon "sendkey dot" ;;
      *) die "Passphrase character '$c' has no known QEMU keyname. Keep LUKS_PASS alphanumeric." ;;
    esac
    sleep 0.05
  done
  mon "sendkey ret"
  info "sent. give it a minute, then: $0 shot"
}

# ── observability ───────────────────────────────────────────────────────────
cmd_shot() {
  vm_running || die "No VM running."
  rm -f "$WORK/console.ppm"
  mon "screendump $WORK/console.ppm"
  sleep 1
  [[ -f "$WORK/console.ppm" ]] || die "screendump produced nothing"
  if command -v magick >/dev/null; then
    magick "$WORK/console.ppm" "$WORK/console.png" && info "$WORK/console.png"
  elif command -v convert >/dev/null; then
    convert "$WORK/console.ppm" "$WORK/console.png" && info "$WORK/console.png"
  else
    info "$WORK/console.ppm (install imagemagick for PNG)"
  fi
}

cmd_serial() { tail -n "${1:-60}" "$SERIAL" 2>/dev/null || die "no serial log yet"; }
cmd_ssh() { ssh_g "$@"; }

# ── lifecycle ───────────────────────────────────────────────────────────────
cmd_down() {
  if vm_running; then
    info "stopping VM"
    mon "quit"
    sleep 2
  fi
  pkill -f "qemu-system-x86_64.*nixos-install-test" 2>/dev/null || true
  rm -f "$MONITOR"
}

cmd_clean() {
  cmd_down
  rm -f "$DISK" "$SERIAL" "$WORK/OVMF_VARS.fd" "$WORK/console.ppm" "$WORK/console.png"
  info "cleaned $WORK (ISO and key kept)"
}

cmd_all() {
  cmd_build
  cmd_up
  cmd_install
  cmd_boot
  info "waiting 45s for the initrd to reach the passphrase prompt"
  sleep 45
  cmd_unlock
  sleep 60
  cmd_shot
  bold ""
  bold "Rehearsal complete. Check $WORK/console.png for a login prompt."
}

case "${1:-}" in
  build | up | install | boot | unlock | shot | serial | ssh | down | clean | all)
    c="$1"
    shift
    "cmd_$c" "$@"
    ;;
  *)
    sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
