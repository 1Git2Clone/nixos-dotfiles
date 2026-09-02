# LVM-on-LUKS: one encrypted container, one passphrase prompt at boot.
#
#   nvme
#   ├── p1  ESP   2G    vfat, unencrypted  -> /boot   (kernels + initrd)
#   └── p2  LUKS2       "cryptroot"
#         └── LVM PV -> vg "pool"
#               ├── lv swap  20G  (resume target for hibernation)
#               ├── lv root  120G ext4 -> /
#               └── lv home  rest ext4 -> /home
#
# Only runs when invoked. `nixos-rebuild` never repartitions.
_:
let
  disk = import ./disk.nix;
in
{
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
              # install.sh writes this with `printf %s` (no trailing newline)
              # and shreds it afterwards. A stray \n would be baked into the
              # passphrase and you could never type it at the boot prompt.
              passwordFile = "/tmp/luks.key";
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
