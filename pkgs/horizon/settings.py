"""Keep the managed release selected without replacing accounts or GUI settings."""

import json
import os
from pathlib import Path
import sys

settings = Path(os.environ["HORIZON_LAUNCHER_HOME"]) / "settings.json"
state = json.loads(settings.read_text()) if settings.exists() else {}
state.update(
    selected=sys.argv[1],
    install_new_versions=False,
    prune_old_versions=False,
    desktop_entry=False,
)
staged = settings.with_suffix(".json.tmp")
staged.write_text(json.dumps(state, indent=2) + "\n")
staged.replace(settings)
