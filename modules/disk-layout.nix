# LVM-on-LUKS, so one passphrase unlocks everything:
#
#   p1  ESP 2G  unencrypted -> /boot
#   p2  LUKS2 "cryptroot" -> LVM PV -> vg "pool" -> swap / root / home
#
# The second disk is per-host: only a `disk.nix` that sets hddDevice gets one,
# so hutao-laptop is unaffected.
#
# Runs only when disko is invoked; nixos-rebuild never repartitions.
disk:
{ lib, ... }:
{
  disko.devices = {
    disk = {
      main = {
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
    }
    // lib.optionalAttrs (disk ? hddDevice) {
      # LUKS2 + ext4, no LVM: one filesystem, nothing to carve up.
      hdd = {
        type = "disk";
        device = disk.hddDevice;
        content = {
          type = "gpt";
          partitions.luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypthdd";
              settings = {
                # No TRIM: spinning rust.
                allowDiscards = false;
                crypttabExtraOpts = [ "x-initrd.attach" ];
              };
              # The same file cryptroot takes, so both keyslots hold the same
              # passphrase. boot.initrd.systemd is on, and systemd-cryptsetup
              # retries its cached password on the second device -- so one
              # prompt opens both.
              passwordFile = "/tmp/luks-passphrase";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = disk.hddMount;
                # A disk that is missing or will not open must not hold up
                # boot, which x-initrd.attach would otherwise let it do.
                mountOptions = [ "nofail" ];
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
