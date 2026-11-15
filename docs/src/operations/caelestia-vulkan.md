# Caelestia Vulkan measurements

On 2026-11-16, the desktop's Caelestia launcher switched from the default
OpenGL Qt Quick backend to Vulkan. In the measured dashboard workload,
Caelestia's mean CPU use fell from **44.3% to 15.0% of one logical core**, a
66% reduction. Launcher CPU use also fell, from 12.4% to 7.7%. These results
support keeping Vulkan for this desktop's shell; they do not demonstrate a
fix for the earlier AMDGPU hang or prove better frame pacing.

The setting is `QSG_RHI_BACKEND=vulkan` in
`dotfiles/dot-config/hypr/modules/programs.lua`, with `QSG_INFO=1` to report
the selected renderer. See [the shell launcher](../architecture/user-layer.md#the-shell-restarts-on-rebuild)
for activation and switching back to OpenGL.

## Machine and session

- AMD Ryzen 5 3600X, ASRock Radeon RX 5600 XT Phantom Gaming 6 GB, 16 GB RAM.
- NixOS, Linux 7.3.3, Hyprland 0.57.0, Quickshell 0.3.2, Qt 6.12.0,
  Mesa 26.2.6; Vulkan selected RADV NAVI10.
- DP-1: AOC 1920 × 1080 at 165 Hz; HDMI-A-1: Samsung 1920 × 1080 at 60 Hz.
- Two mapped Floorp windows, one per monitor; no other mapped applications.
  Background services continued running.
- OpenGL run started at 00:36:03 EET; Vulkan run at 00:41:34 EET.
  The rebuild restarted Caelestia. Hyprland and the main Floorp process
  remained running; some browser subprocesses changed between runs.

OpenGL was identified from the live shell's OpenGL worker threads
(`quickshell:gl0`), Mesa EGL/Gallium libraries and GPU file descriptors;
there was no `QSG_RHI_BACKEND` override. A Vulkan loader being mapped alone
would not establish that Qt Quick was using Vulkan.

After the rebuild, `/proc/<shell-pid>/environ` contained
`QSG_RHI_BACKEND=vulkan`, and Qt's startup log explicitly reported
`Creating QRhi with backend Vulkan` and selected
`AMD Radeon RX 5600 XT (RADV NAVI10)`. This verifies hardware Vulkan rendering,
rather than assuming an environment variable took effect or mistaking a
software device enumerated by Qt for the selected GPU.

## Results

Arithmetic means of the samples in each phase. CPU 100% means one logical
core, not the entire 12-thread CPU. GPU utilization and power cover the
whole device, including Hyprland and Floorp.

| Phase | Caelestia CPU, GL → VK | GPU busy, GL → VK | GPU power, GL → VK |
| --- | --- | --- | --- |
| Initial idle | 0.0% → 0.0% | 5.3% → 5.0% | 26.0 W → 25.4 W |
| Launcher toggles | 12.4% → 7.7% | 10.4% → 10.3% | 27.8 W → 27.0 W |
| Dashboard toggles | 44.3% → 15.0% | 16.0% → 12.8% | 30.0 W → 28.5 W |
| Workspace switches | 9.0% → 6.8% | 8.8% → 10.5% | 27.5 W → 27.7 W |
| Final idle | 0.1% → 0.0% | 5.5% → 5.2% | 26.1 W → 25.6 W |

Hyprland CPU use remained around 10–13% of one core. Floorp averaged roughly
120–136% during idle and drawer phases, so this was not an otherwise idle
machine. Its activity is recorded separately in the raw samples.

Memory did not move uniformly downward. At final idle, Caelestia RSS fell
from 543.3 to 464.5 MiB. Whole-device VRAM use rose from 1118.9 to 1136.8 MiB,
and GTT allocation rose from 71.4 to 241.9 MiB. RSS is resident process memory;
GTT is the driver's GTT allocation counter. These counters have different
accounting and should not be added into a single total.

No GPU error was found in the kernel warning log during the Vulkan
measurement. That short observation does not establish long-term stability.

## Measurement method

The same Python script ran once per backend, using only the standard library
and the installed `hyprctl` and `caelestia-shell` commands. It did not record
video, change browser pages, or inject a GPU reset.

1. Locate Quickshell, Hyprland and Floorp processes through `/proc/*/exe`.
   Read the running shell's environment to connect to its Wayland/Hyprland
   session. Save graphics environment variables, loaded graphics libraries,
   monitor configuration and mapped application classes.
2. Verify that the launcher and dashboard drawers are closed using
   `caelestia-shell ipc call drawers isOpen <drawer>`.
3. Sample counters every 0.5 seconds while performing the sequence below.
   Save each sample immediately to CSV, with elapsed monotonic time and phase.
4. Save timestamped action results and per-phase arithmetic mean, maximum and
   nearest-rank 95th percentile. Each run collected 113 samples: 19 initial
   idle, 25 launcher, 25 dashboard, 24 workspace and 20 final idle samples.
5. Close the drawers and restore the original workspace after the sequence.

The sequence was:

- 10 seconds initial idle.
- Three launcher open/close cycles, waiting two seconds after each toggle.
- Three dashboard open/close cycles, waiting two seconds after each toggle.
- Three round trips between the original workspace (2) and an unused
  workspace (1), waiting two seconds after each switch.
- 10 seconds final idle.

Drawer interactions used
`caelestia-shell ipc call drawers toggle launcher` (or `dashboard`).
Workspace changes used Hyprland's Lua dispatcher, for example
`hyprctl dispatch 'hl.dsp.focus({ workspace = 1 })'`.
CLI execution adds a little time beyond the nominal 56 seconds of waits.

The counters were:

- Per-process-group CPU: delta of user plus system CPU ticks from
  `/proc/<pid>/stat`, divided by `SC_CLK_TCK` and the elapsed monotonic time,
  multiplied by 100. Floorp values sum its initially discovered processes.
- RSS: resident page counts from `/proc/<pid>/stat`, multiplied by
  `SC_PAGE_SIZE`, summed per group and converted to MiB.
- GPU: `gpu_busy_percent`, `mem_info_vram_used` and `mem_info_gtt_used`
  under `/sys/class/drm/card1/device/`.
- Power and temperature: `hwmon/hwmon*/power1_average` divided by 1,000,000
  for watts, and `temp1_input` divided by 1,000 for degrees Celsius.

## Reproduce and inspect the evidence

The original script, raw CSV files, summaries, action timestamps and selected
metadata are tracked under `docs/measurements/2026-11-16-caelestia/`.
The selected metadata omits original process IDs, compositor addresses and
monitor serial numbers. The renderer text is an identifying excerpt, not the
full Qt log.

Run the script as the logged-in desktop user from a terminal with access to
that user's processes and compositor sockets. It changes visible drawers and
workspaces. Start with both drawers closed and an unused workspace among 1–9.
It expects the paths, GPU card number and single shell instance used above;
check them before using it on another host. From the repository root:

```sh
run_dir=$(mktemp -d /tmp/caelestia-measurement.XXXXXX)
cp docs/measurements/2026-11-16-caelestia/measure.py "$run_dir/measure.py"
python3 "$run_dir/measure.py" vulkan
```

Copy the timestamped output directory to permanent storage before `/tmp` is
cleaned. To compare backends, rebuild with the desired launcher setting,
verify the live renderer, let startup settle, and run again with the same
browser pages, displays and background workload. Keep the Qt theme and
logging settings identical for a better controlled comparison.

## Limits of this comparison

This was one short run per backend. It measured resource use, not FPS,
frame times, input latency or responsiveness. The 0.5-second sampling and
kernel counter averaging do not resolve individual animation frames.

The rebuild also changed `QT_QPA_PLATFORMTHEME` from `qtengine` to
`hyprqt6engine` and enabled `QSG_INFO` logging. Browser activity varied too.
The dashboard CPU reduction is a useful observation on this machine, but
these runs cannot attribute every difference exclusively to Vulkan.

The original sampler fixes each process group at startup: newly spawned
browser processes are not included, and an exiting tracked process can
invalidate a CPU delta. No negative group CPU samples occurred in these
runs. RSS sums can count shared pages more than once. Whole-GPU memory,
power and utilization include background applications. A stronger benchmark
would track process lifetimes, repeat alternating backend runs and measure
frame times while holding the remaining settings constant.
