# hutao-vm — the desktop layer under QEMU, for testing without an install.
#
# This is NOT the install rehearsal. It deliberately skips the three things
# that need real hardware and a real install:
#
#   disko    the VM gets a plain qcow2 from qemu-vm.nix, no LUKS, no LVM
#   sops     no host key exists to derive an age identity from, so the
#            password hashes cannot be decrypted; users get a known password
#   Limine   qemu-vm.nix boots the kernel directly, bypassing any bootloader
#
# What it DOES test is everything else, which is most of the risk surface:
# every package name in modules/desktop.nix, every stylix.* option, the
# home-manager wiring, caelestia, and whether Hyprland and SDDM actually come
# up. Those are the errors that otherwise surface on the laptop at 2am.
#
#   nix run .#vm                   build and boot it
#   ssh -p 2223 hutao@localhost    password: vm
#
# The full install rehearsal — disko, LUKS, sops, Limine — is vm/install-test.sh.
{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  networking.hostName = "hutao-vm";

  boot = {
    # Unused under direct kernel boot, but NixOS wants a bootloader declared
    # and this keeps the VM honest about being UEFI like the laptop.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;

    # Same pin as the laptop: services.scx needs 6.12+ and this is one of the
    # things worth confirming actually boots.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware.graphics.enable = true;

  # ── Users: plain passwords, since sops cannot work here ──────────────────
  # modules/users.nix is deliberately NOT imported — it is entirely sops-driven
  # and cannot evaluate without the encrypted hashes and a host key to unlock
  # them with. The install rehearsal covers that path instead.
  users.mutableUsers = false;
  users.users.hutao = {
    isNormalUser = true;
    description = "hutao";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
    password = "vm";
    shell = pkgs.zsh;
  };
  users.users.root.password = "vm";
  programs.zsh.enable = true;

  # The laptop keeps password auth off; the VM turns it back on so you can get
  # in without provisioning a key into a throwaway machine.
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

  # Straight into Hyprland — the point is to see whether the session starts.
  # defaultSession is not optional here: with several sessions registered,
  # autoLogin without it lands on whichever SDDM picks, and a VM that silently
  # logs into the wrong session looks like Hyprland failing to start.
  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "hutao";
    };
    defaultSession = "hyprland";
  };

  # QEMU has no GPU. Mesa falls back to llvmpipe, but wlroots refuses a
  # software renderer unless told explicitly, and Hyprland just exits without
  # it. This is a VM-only workaround; the laptop has amdgpu.
  environment.sessionVariables = {
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBGL_ALWAYS_SOFTWARE = "1";
  };

  virtualisation = {
    memorySize = 6144;
    cores = 4;
    # The desktop closure alone is well over 10G.
    diskSize = 32768;
    graphics = true;
    # No custom -vga/-display here on purpose. qemu-vm.nix already picks a
    # display when graphics = true, and passing a second -display makes qemu
    # refuse to start — a confusing failure for something that is only meant
    # to open a window.
    forwardPorts = [
      {
        from = "host";
        host.port = 2223;
        guest.port = 22;
      }
    ];
  };

  system.stateVersion = "26.05";
}
