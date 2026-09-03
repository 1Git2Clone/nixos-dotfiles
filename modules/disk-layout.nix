# LVM-on-LUKS, so one passphrase unlocks everything:
#
#   p1  ESP 2G  unencrypted -> /boot
#   p2  LUKS2 "cryptroot" -> LVM PV -> vg "pool" -> swap / root / home
#
# Runs only when disko is invoked; nixos-rebuild never repartitions.
disk: _: {
  disko.devices = {
    disk.main = {
      type = "disk";
      inherit (disk) device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            type = "EF00";
            size = "2G";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          luks = {
            priority = 2;
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings = {
                allowDiscards = true;
                crypttabExtraOpts = [ "x-initrd.attach" ];
              };
              # install.sh writes this without a trailing newline; a stray \n
              # is baked into the keyslot and can never be typed at boot.
              passwordFile = "/tmp/luks-passphrase";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };

    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = disk.swapSize;
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };

        root = {
          size = disk.rootSize;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };

        home = {
          size = "100%FREE";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/home";
          };
        };
      };
    };
  };
}
