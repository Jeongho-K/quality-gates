#!/usr/bin/env python3
"""SessionStart hook: advisory only — never mutates state.

Prints a one-line message to stdout if a /qg pipeline is mid-flight.
Honors CLAUDE.md rule: SessionStart hooks are read-only advisors.

Statuses recognized as "in-flight" come from the canonical state-file format
(see skills/quality-pipeline/references/state-file-format.md):
  gate1_running | gate2_running | gate3_running

Terminal statuses (completed | aborted) are silent — pipeline is over.

Working-directory contract: hook is invoked with cwd = workspace root
(Claude Code SessionStart contract). All paths in this file are relative
to that root.

Kill switch: DEVBREW_DISABLE_QUALITY_GATES=1 (checked before any file I/O).
"""

import os
import re
import sys
from pathlib import Path

STATE_FILE = Path(".claude/quality-gates.local.md")
ACTIVE_STATUSES = {"gate1_running", "gate2_running", "gate3_running"}
GATE_RX = re.compile(r"^current_gate:\s*(\S+)", re.MULTILINE)
STARTED_AT_RX = re.compile(r"^started_at:\s*\"?([^\"\n]+)\"?", re.MULTILINE)
STATUS_RX = re.compile(r"^status:\s*(\S+)", re.MULTILINE)


def _strip_quotes(value: str) -> str:
    return value.strip().strip('"').strip("'")


def main() -> int:
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return 0
    if not STATE_FILE.exists():
        return 0
    try:
        text = STATE_FILE.read_text()
    except OSError:
        return 0

    status_match = STATUS_RX.search(text)
    if not status_match:
        return 0
    status = _strip_quotes(status_match.group(1)).lower()
    if status not in ACTIVE_STATUSES:
        return 0

    gate_match = GATE_RX.search(text)
    gate = _strip_quotes(gate_match.group(1)) if gate_match else "?"
    started_match = STARTED_AT_RX.search(text)
    started = _strip_quotes(started_match.group(1)) if started_match else None

    suffix = f" (started {started})" if started else ""
    sys.stdout.write(
        f"[quality-gates] In-flight pipeline at Gate {gate}{suffix}. "
        f"Run `/qg` to resume or `/qg --reset` to clear.\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
