pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.components.misc

Scope {
    id: root

    function capture(clipboardOnly: bool): void {
        const action = clipboardOnly
            ? "hl.plugin.hyprcapture.open('region', { save = false, clipboard = true })"
            : "hl.plugin.hyprcapture.open_editor('region')";
        Quickshell.execDetached(["@HYPRCTL@", "eval", action]);
    }

    IpcHandler {
        target: "picker"
        function open(): void { root.capture(false); }
        function openFreeze(): void { root.capture(false); }
        function openClip(): void { root.capture(true); }
        function openFreezeClip(): void { root.capture(true); }
    }

    CustomShortcut {
        name: "screenshot"
        description: "Open HyprCapture"
        onPressed: root.capture(false)
    }
    CustomShortcut {
        name: "screenshotFreeze"
        description: "Open HyprCapture"
        onPressed: root.capture(false)
    }
    CustomShortcut {
        name: "screenshotClip"
        description: "Open HyprCapture (clipboard only)"
        onPressed: root.capture(true)
    }
    CustomShortcut {
        name: "screenshotFreezeClip"
        description: "Open HyprCapture (clipboard only)"
        onPressed: root.capture(true)
    }
}
