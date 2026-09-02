# Host-agnostic tuning. Replaces the dotfiles repo's system/install.sh.
{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # 16GB. Bounded so a big rebuild does not starve the desktop.
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

  # Compressed RAM swap; near-mandatory at 8GB. Higher priority than the swap
  # LV, which exists for hibernation.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 40;
    priority = 100;
  };

  # From the dotfiles repo's sysctl.d/99-custom.conf.
  boot.kernel.sysctl = {
    # Virtual memory
    # Low swappiness: prefer keeping processes in RAM, let ZRAM handle overflow
    "vm.swappiness" = 15;
    # ZRAM-friendly: no read-ahead for swap (already compressed)
    "vm.page-cluster" = 0;
    # More aggressive page writeback for responsive desktop
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 3;
    "vm.dirty_writeback_centisecs" = 500;
    "vm.dirty_expire_centisecs" = 3000;

    # Kernel — higher fd limits for Electron apps, browsers, etc.
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;

    # Network — higher connection backlog
    "net.core.somaxconn" = 65535;
    "net.core.netdev_max_backlog" = 65536;

    # TCP performance
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_no_metrics_save" = 1;

    # Magic SysRq for emergency recovery (Alt+SysRq+R/E/I/S/U/B)
    "kernel.sysrq" = 1;

    # Forwarding — carried over from your Tailscale exit-node setup.
    # If you enable services.tailscale, prefer setting
    #   services.tailscale.useRoutingFeatures = "both";
    # which sets these for you, and drop them from here.
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.udev.extraRules = ''
    # NVMe and SSDs: none (lowest latency, hardware handles queuing)
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

    # HDDs: bfq (fair queuing for spinning rust)
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

  # Replaces the hand-written scx-lavd.service. Needs kernel 6.12+.
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
