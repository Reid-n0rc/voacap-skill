#!/usr/bin/env python3
"""SessionStart hook: bootstraps the VOACAP engine on first use.

Runs on every session start, but setup.sh/setup.ps1 are idempotent
(they no-op quickly once already built/installed), so this is cheap on
the common path. Never raises: a failed build here shouldn't block the
session -- the skill's own error message tells the user to run setup
manually if the engine still isn't found when a prediction is attempted.
"""
import subprocess
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "skills" / "voacap" / "scripts"


def main():
    try:
        if sys.platform.startswith("win"):
            subprocess.run(
                [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(SCRIPTS_DIR / "setup.ps1"),
                ],
                check=False,
            )
        else:
            subprocess.run([str(SCRIPTS_DIR / "setup.sh")], check=False)
    except OSError as exc:
        print(f"voacap: setup hook failed to run ({exc}); "
              f"run {SCRIPTS_DIR}/setup.sh manually.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
