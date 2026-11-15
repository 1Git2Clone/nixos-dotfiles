# Kernel device crash dumps

`modules/device-coredumps.nix`, imported by `modules/system.nix`, captures
kernel device coredumps on the desktop, laptop and desktop VM. This includes
AMDGPU diagnostic dumps exposed through the kernel's `devcoredump` interface.
It does not configure whole-kernel panic dumps (kdump) or application core dumps.

On a `devcoredump` add event, udev starts `save-device-coredump@devcdN.service`.
The service immediately copies the raw `data` file into `/var/lib/devcoredumps/`,
then records the UTC capture time, kernel version, boot ID, device path and,
when available, the device's uevent properties. Each capture gets a unique
UTC timestamp and device instance in its directory name. A `.partial` suffix
marks an incomplete capture; it is removed only after a successful save.

The archive directory is root-only (0700), with files created under a 0077
umask, because device dumps can contain sensitive data. Captures survive
reboots and have no automatic expiry; remove old directories manually when
no longer needed. The service leaves the kernel's original dump untouched.

## Activate and inspect

From the repository root on the desktop:

```sh
sudo nixos-rebuild switch --flake .#hutao-desktop
sudo ls -lh /var/lib/devcoredumps/
sudo journalctl -u 'save-device-coredump@*'
```

The archive directory is created when the first capture service starts.
Use `.#hutao-laptop` when rebuilding the laptop. Once activated, future dump
add events trigger capture without a terminal or desktop session. This saves
dumps only when the kernel actually generates one and userspace can still run;
it cannot guarantee a capture during a complete machine lockup or power loss.

## Why immediate capture matters

Learned 2026-11-16: the GPU dump from the desktop hang on 2026-11-15 disappeared
before it was copied. `/sys/class/drm/cardN/device/devcoredump/data` is a
temporary view of data in kernel memory, not a persistent disk file. The
kernel normally expires device coredumps after five minutes; drivers can choose
another timeout. See the
[kernel device-coredump documentation](https://www.kernel.org/doc/html/v6.19-rc1/process/debugging/driver_development_debugging_guide.html#device-coredump).
Saving a path from the journal does not preserve its contents, and enabling this
service cannot recover an already expired dump.
