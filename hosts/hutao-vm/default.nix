# The desktop layer under QEMU. Fast path for anything in modules/desktop
# or the nvim-config module — no install, no LUKS, no sops.
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

  # modules/users.nix needs sops, so the VM declares throwaway accounts.
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

  # No autoLogin: the greeter is usually what you booted this to look at.
  services.displayManager.defaultSession = "hyprland";

  # caelestia suspends at 10 minutes and the Wayland session does not survive
  # a QEMU wakeup, so an unattended VM eats itself.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # wlroots refuses llvmpipe unless told to, and Hyprland just exits. VM-only.
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
    # qemu-vm.nix already sets -vga/-display; a second makes qemu refuse.
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
