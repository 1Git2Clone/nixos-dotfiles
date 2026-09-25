# Ryzen 5 3600X, RX 5600 XT (Navi 10), 16GB, 512GB NVMe + 2TB LUKS ext4 HDD.
# This machine only; anything shared lives in hosts/common or modules/.
let
  disk = import ./disk.nix;
in
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common
    (import ../../modules/disk-layout.nix disk)
    ./hardware-configuration.nix
  ];

  networking.hostName = "hutao-desktop";

  boot.initrd.kernelModules = [ "amdgpu" ];

  # Left for removable NTFS media; the HDD itself is ext4 now.
  boot.supportedFilesystems.ntfs = true;

  # Formatted by hand, once -- deliberately not in modules/disk-layout.nix, so
  # a reinstall touches the NVMe alone and cannot wipe this. Only the unlock
  # and the mount are declared.
  #
  # In the initrd rather than stage 2 because boot.initrd.systemd is on:
  # systemd-cryptsetup retries the password it already cached for cryptroot,
  # so one prompt opens both. The cost is that a missing disk waits out a
  # 90s timeout before boot carries on.
  boot.initrd.luks.devices.crypthdd = {
    device = "${disk.hddDevice}-part1";
    allowDiscards = false;
    crypttabExtraOpts = [ "x-initrd.attach" ];
  };

  fileSystems.${disk.hddMount} = {
    device = "/dev/mapper/crypthdd";
    fsType = "ext4";
    # nofail, so a disk that is missing or will not open costs a failed mount
    # unit rather than a boot.
    options = [ "nofail" ];
  };

  # Userspace, so home-manager rather than environment.systemPackages -- and
  # here rather than home/, which every host shares. simple-scan is
  # for the printer below.
  home-manager.users.hutao.home.packages = with pkgs; [
    teams-for-linux

    # SANE's dll backend finds a driver through LD_LIBRARY_PATH, and brscan4's
    # lives in its own store path, linked into /etc/sane-libs. NixOS exports
    # that in /etc/set-environment, which only login shells read -- the
    # graphical session carries no LD_LIBRARY_PATH at all, so the backend
    # silently fails to load and simple-scan reports a missing driver.
    # Wrapped here rather than exported session-wide: one app needs the
    # linker path, every other app on the desktop does not.
    (symlinkJoin {
      name = "simple-scan-sane-libs";
      paths = [ simple-scan ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = "wrapProgram $out/bin/simple-scan --prefix LD_LIBRARY_PATH : /etc/sane-libs";
    })
  ];

  services = {
    # My power button was too easy to misclick.
    # NOTE:
    # 1. This *DOESN'T* affect starting the system, only poweroff.
    # 2. The 4+ second hold force off still works (BIOS/firmware enforced)
    logind.settings = {
      Login = {
        HandlePowerKey = "ignore";
      };
    };
    # The Brother DCP-1512E hangs off this machine's USB. brlaser rather than
    # Brother's own dcp1510 driver: it ships a "DCP-1510 series" model whose
    # 1284DeviceID matches what the printer reports, so CUPS picks the PPD up on
    # its own, and it is a real open-source filter rather than a repackaged
    # 32-bit binary.
    #
    # No avahi here -- the 1512E is USB-only, there is nothing to browse for.
    printing = {
      enable = true;
      drivers = [ pkgs.brlaser ];
    };

    # hutao-laptop as a third monitor, right of DP-1: Moonlight there streams
    # a headless output that exists only for the session, so the pointer
    # cannot wander onto an invisible screen while the laptop is closed.
    #
    # No openFirewall: tailscale0 is trusted, and the tailnet is the only way
    # in. wlr capture, not KMS, because a headless output has no CRTC to read.
    sunshine = {
      enable = true;
      settings = {
        capture = "wlr";
        output_name = "LAPTOP";
        # A monitor, not a game: the desktop keeps its own sound.
        stream_audio = "disabled";
      };
      applications.apps =
        let
          hyprctl = "${config.programs.hyprland.package}/bin/hyprctl";
        in
        [
          {
            name = "Laptop screen";
            prep-cmd = [
              {
                do = "${hyprctl} output create headless LAPTOP";
                undo = "${hyprctl} output remove LAPTOP";
              }
            ];
          }
        ];
    };
    # sunshine turns it on for LAN discovery; mDNS never crosses the tailnet,
    # so Moonlight adds this host by name instead.
    avahi.enable = false;
  };

  # The web UI login, from sops rather than a first-run form. --creds merges
  # into sunshine_state.json, so paired clients survive the re-seed on every
  # start. Given the same config file as ExecStart so both resolve the same
  # state file.
  # ponytail: the password is in argv for the instant --creds runs, readable by
  # any local user; hash it into the json ourselves if this ever isn't
  # single-user.
  systemd.user.services.sunshine.serviceConfig.ExecStartPre =
    let
      cfg = config.services.sunshine;
      configFile = (pkgs.formats.keyValue { }).generate "sunshine.conf" cfg.settings;
    in
    pkgs.writeShellScript "sunshine-seed-login" ''
      exec ${lib.getExe cfg.package} ${configFile} \
        --creds hutao "$(< ${config.sops.secrets.sunshine_password.path})"
    '';

  # Sunshine only runs the prep-cmd's undo when the app quits; a disconnect
  # (lid shut, wifi drop, closing Moonlight) keeps it running for a resume and
  # leaves LAPTOP behind as an invisible screen. It has no disconnect hook, so
  # quit the app through its own API and let it run the undo itself -- a
  # reconnect then relaunches it and gets LAPTOP back.
  # ponytail: keyed on the literal log line; if a Sunshine update rewords
  # "CLIENT DISCONNECTED", this silently stops firing.
  systemd.user.services.sunshine-quit-on-disconnect = {
    description = "Quit the Sunshine app when its client disconnects";
    wantedBy = [ "sunshine.service" ];
    bindsTo = [ "sunshine.service" ];
    after = [ "sunshine.service" ];
    path = [
      config.systemd.package
      pkgs.curl
      pkgs.gnugrep
    ];
    # No Origin header from curl, so Sunshine wants basic auth but no CSRF token.
    script =
      let
        webPort = toString (config.services.sunshine.settings.port + 1);
      in
      ''
        journalctl --user -fu sunshine -o cat -n 0 \
          | grep --line-buffered -F 'CLIENT DISCONNECTED' \
          | while read -r _; do
              curl -sk --netrc-file ${config.sops.templates."sunshine-netrc".path} \
                -X POST https://localhost:${webPort}/api/apps/close \
                || true
            done
      '';
  };

  # cupsd on its own only makes the printer *discoverable*; nothing lists a
  # printer until a queue exists, which is why Floorp's dialog came up empty.
  # Declared rather than added once through localhost:631, so a reinstall does
  # not need the click-through.
  #
  # The URI carries the serial because that is verbatim what `lpinfo -v`
  # reports for this unit -- CUPS' usb backend matches on the whole string.
  # Swap the printer and this needs re-reading.
  hardware.printers = {
    ensureDefaultPrinter = "Brother-DCP-1512E";
    ensurePrinters = [
      {
        name = "Brother-DCP-1512E";
        location = "desk";
        deviceUri = "usb://Brother/DCP-1510%20series?serial=E72166E9N125990";
        # From `lpinfo -m`; the .drv ships compiled by cups-driverd.
        model = "drv:///brlaser.drv/br1510.ppd";
      }
    ];
  };

  # The 1512E also scans, and brlaser is print-only. brscan4 is the generation
  # Brother ships for the DCP-1510 series (models4/ext_7.ini) -- unfree, and
  # the only thing that drives this scanner; no open backend claims it.
  hardware.sane = {
    enable = true;
    brscan4.enable = true;
  };

  # sane's udev rules hand the device to the scanner group; lp is CUPS.
  users.users.hutao.extraGroups = [
    "scanner"
    "lp"
  ];

  # There is no Outlook for Linux; evolution speaks EWS to Exchange Online.
  # The option rather than the two packages: dbus activates the backend's
  # daemons, and only evolutionWithPlugins' join lets them find the plugin.
  programs.evolution = {
    enable = true;
    plugins = [ pkgs.evolution-ews ];
  };

  # Never change after install.
  system.stateVersion = "26.05";
}
