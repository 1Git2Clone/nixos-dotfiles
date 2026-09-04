# Host-agnostic tuning. Replaces the imperative system/ tree the dotfiles
# repo used to carry.
{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # Bounded so a rebuild does not starve the desktop.
    max-jobs = 4;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "Europe/Sofia";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.networkmanager.enable = true;

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Higher priority than the swap LV, which exists only for hibernation.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 40;
    priority = 100;
  };

  # Rationale per value is in dotfiles/docs/performance.md.
  boot.kernel.sysctl = {
    "vm.swappiness" = 15;
    # zram is already compressed, so swap read-ahead only wastes work.
    "vm.page-cluster" = 0;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 3;
    "vm.dirty_writeback_centisecs" = 500;
    "vm.dirty_expire_centisecs" = 3000;

    # Electron apps and browsers exhaust the defaults.
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;

    "net.core.somaxconn" = 65535;
    "net.core.netdev_max_backlog" = 65536;

    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_no_metrics_save" = 1;

    # Alt+SysRq+R/E/I/S/U/B.
    "kernel.sysrq" = 1;
  };

  services.udev.extraRules = ''
    # SSDs: none — the hardware already queues.
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

    # HDDs: bfq.
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

  # Replaces the hand-written scx-lavd.service.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    btop
    ripgrep
    fzf
    lsd
    sops
    age
    ssh-to-age
  ];
}
