#!/usr/bin/env bash
#
# Evaluate the flake without a NixOS machine — the real evaluator in a
# container, against stubbed hardware and secrets files.
#
# Proves the config evaluates, not that it builds or boots. That is the class
# of error that otherwise strands you on a live ISO.
#
# Usage:  ./verify.sh          (needs docker; on NixOS use nixos-rebuild)
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

command -v docker >/dev/null || {
  echo "docker not found"
  exit 1
}

# Named volume keeps /nix/store between runs.
docker volume create nixos-verify-store >/dev/null

# Optional, to raise GitHub's 60 req/h. Unnecessary once flake.lock exists.
#   export GH_TOKEN="$(gh auth token)"   # read-only; never committed
#
# NIX_CONFIG, not an append to /etc/nix/nix.conf: that path is a symlink into
# the persisted /nix volume, so an append is permanent — and an empty token
# lands as "access-tokens = github.com=", which GitHub rejects forever after.
docker run --rm -e GH_TOKEN="${GH_TOKEN:-}" \
  -v "$PWD":/cfg:ro -v nixos-verify-store:/nix nixos/nix:latest sh -c '
  set -e
  [ -n "$GH_TOKEN" ] && export NIX_CONFIG="access-tokens = github.com=$GH_TOKEN"
  mkdir -p /tmp/w && cp -r /cfg/. /tmp/w/ && cd /tmp/w && rm -rf .git

  # Generated at install time by nixos-generate-config.
  cat > hosts/hutao-laptop/hardware-configuration.nix <<"HW"
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usbhid" ];
  boot.kernelModules = [ "kvm-amd" ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
}
HW

  # Placeholder for a fresh clone; sops-nix does not decrypt at eval time.
  mkdir -p secrets
  [ -s secrets/secrets.yaml ] || printf "root_password: x\nuser_password: x\ntailscale_authkey: x\nluks_passphrase: x\n" > secrets/secrets.yaml

  # Flakes only see git-tracked files.
  git init -q . && git add -A && git -c user.email=v@v -c user.name=v commit -qm verify

  nix --extra-experimental-features "nix-command flakes" \
    eval ".#nixosConfigurations.hutao-laptop.config.system.build.toplevel.drvPath" \
    --no-update-lock-file
' 2>&1 | grep -vE '^(unpacking|copying|warning: not writing|• Added|    .(follows|github:|git\+))'
