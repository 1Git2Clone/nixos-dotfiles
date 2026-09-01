# Shared system tuning. Host-agnostic on purpose: when the desktop joins,
# it imports this same file and the two machines stay identical below the
# hardware line. This is the bit that replaces `system/install.sh`.
{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    # 8GB soldered. Unbounded parallel builds will OOM on this machine.
    max-jobs = 2;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "Europe/Sofia";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.networkmanager.enable = true;

  # sshd is not optional here: sops-nix derives its age identity from the
  # ed25519 host key, so this must stay enabled or secrets stop decrypting.
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

  # ── zram ────────────────────────────────────────────────────────────────
  # Compressed RAM swap. Close to mandatory at 8GB. Coexists fine with the
  # on-disk swap LV: zram takes the higher priority for runtime paging,
  # the LV exists for hibernation.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # ── sysctl — translated from system/sysctl.d/99-custom.conf ─────────────
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

  # ── I/O scheduler — from system/udev/rules.d/60-io-scheduler.rules ──────
  services.udev.extraRules = ''
    # NVMe and SSDs: none (lowest latency, hardware handles queuing)
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

    # HDDs: bfq (fair queuing for spinning rust)
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

  # ── sched_ext — replaces system/systemd/system/scx-lavd.service ─────────
  # Your hand-written unit, upstream. Requires kernel 6.12+.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  # Deliberately minimal: this repo is the *core system*. The desktop
  # (Hyprland, SDDM, Stylix) lands in modules/desktop.nix as a follow-up.
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
