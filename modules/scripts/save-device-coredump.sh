#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
archive_dir=$2
instance=$(basename "$source_dir")

# mktemp avoids collisions across devices, repeated hangs and reboots.
# Keep incomplete captures visibly separate from successfully saved dumps.
capture=$(mktemp -d "$archive_dir/$(date -u +%Y%m%dT%H%M%SZ)-$instance-XXXXXX.partial")
trap 'echo "Incomplete device coredump capture: $capture" >&2' ERR

# Copy first: metadata collection must not consume the dump's short lifetime.
cat "$source_dir/data" >"$capture/data"
{
  printf 'captured_utc=%s\n' "$(date -u --iso-8601=seconds)"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'boot_id=%s\n' "$(cat /proc/sys/kernel/random/boot_id)"
  printf 'device=%s\n' "$(readlink -f "$source_dir/failing_device" || true)"
} >"$capture/metadata.txt"
if [[ -r "$source_dir/failing_device/uevent" ]]; then
  cat "$source_dir/failing_device/uevent" >"$capture/device-uevent.txt"
fi

# Flush the files before publishing a completed archive directory.
sync -f "$capture/data"
sync -f "$capture/metadata.txt"
completed=${capture%.partial}
mv "$capture" "$completed"
sync -f "$archive_dir"
echo "Saved kernel device coredump to $completed"
