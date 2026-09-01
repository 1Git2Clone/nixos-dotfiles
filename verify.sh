#!/usr/bin/env bash
#
# Evaluate the flake without a NixOS machine.
#
# Runs the real Nix evaluator in a container against a stubbed
# hardware-configuration.nix and a stubbed secrets file, so option-name
# errors and module conflicts surface before install day.
#
# This does NOT build anything and does NOT prove the system boots. It proves
# the configuration evaluates — which is the class of error that would
# otherwise strand you on a live ISO.
#
# Uses the committed flake.lock, so it does not re-resolve inputs against the
# GitHub API (which rate-limits at 60 req/h unauthenticated).
#
# Usage:  ./verify.sh          (needs docker; on NixOS just use nixos-rebuild)
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

command -v docker >/dev/null || { echo "docker not found"; exit 1; }

# Named volume keeps /nix/store between runs — first run downloads
# nixpkgs, later runs are fast.
docker volume create nixos-verify-store >/dev/null

# Optional: unauthenticated GitHub allows 60 API req/h, and resolving flake
# inputs burns them fast. Export a read-only token to raise it. Not required
# once flake.lock is committed.
#   export GH_TOKEN="$(gh auth token)"   # read-only; never committed
docker run --rm -e GH_TOKEN="${GH_TOKEN:-}" \
  -v "$PWD":/cfg:ro -v nixos-verify-store:/nix nixos/nix:latest sh -c '
  set -e
  [ -n "$GH_TOKEN" ] && echo "access-tokens = github.com=$GH_TOKEN" >> /etc/nix/nix.conf
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

  # Written by install.sh from your real passwords.
  mkdir -p secrets
  [ -s secrets/secrets.yaml ] || printf "hutao-password: x\nroot-password: x\n" > secrets/secrets.yaml

  # Flakes only see git-tracked files.
  git init -q . && git add -A && git -c user.email=v@v -c user.name=v commit -qm verify

  nix --extra-experimental-features "nix-command flakes" \
    eval ".#nixosConfigurations.hutao-laptop.config.system.build.toplevel.drvPath" \
    --no-update-lock-file
' 2>&1 | grep -vE '^(unpacking|copying|warning: not writing|• Added|    .(follows|github:|git\+))'
