"""Keep Caelestia's screenshot command on the desktop's capture backend."""

import subprocess


class Command:
    def __init__(self, args):
        self.args = args

    def run(self):
        # HyprCapture always freezes selection. Region arguments open its
        # interactive selector rather than cropping with another backend.
        action = (
            "hl.plugin.hyprcapture.open_editor('region')"
            if self.args.region
            else "hl.plugin.hyprcapture.quick('fullscreen')"
        )
        subprocess.run(["@HYPRCTL@", "eval", action], check=True)
