# The desktop layer under QEMU. Fast path for anything in modules/desktop.nix
# or modules/neovim.nix — no install, no LUKS, no sops.
#
#   nix run .#vm     then log in as hutao / vm
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
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware.graphics.enable = true;

  # modules/users.nix is sops-driven and cannot evaluate without the encrypted
  # file, so the VM declares its own throwaway accounts.
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

  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

  # No autoLogin: the greeter is part of the desktop layer and is usually what
  # you booted this to look at.
  services.displayManager.defaultSession = "hyprland";

  # caelestia's idle timeouts end in suspend-then-hibernate at 10 minutes.
  # QEMU has no meaningful suspend — the guest pauses, and the Wayland session
  # does not survive the wakeup — so an unattended VM eats itself.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # QEMU has no GPU. wlroots refuses llvmpipe unless told explicitly and
  # Hyprland just exits. VM-only.
  environment.sessionVariables = {
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBGL_ALWAYS_SOFTWARE = "1";
  };

  virtualisation = {
    memorySize = 6144;
    cores = 4;
    diskSize = 32768;
    graphics = true;
    # No -vga/-display here: qemu-vm.nix sets one and a second makes qemu
    # refuse to start.
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
