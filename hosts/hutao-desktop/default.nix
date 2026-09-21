# Ryzen 5 3600X, RX 5700 XT (Navi 10), 16GB, 512GB NVMe + 2TB NTFS HDD.
# This machine only; anything shared lives in hosts/common or modules/.
let
  disk = import ./disk.nix;
in
{ pkgs, ... }:
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

  # The Brother DCP-1512E hangs off this machine's USB. brlaser rather than
  # Brother's own dcp1510 driver: it ships a "DCP-1510 series" model whose
  # 1284DeviceID matches what the printer reports, so CUPS picks the PPD up on
  # its own, and it is a real open-source filter rather than a repackaged
  # 32-bit binary.
  #
  # No avahi here -- the 1512E is USB-only, there is nothing to browse for.
  services.printing = {
    enable = true;
    drivers = [ pkgs.brlaser ];
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
