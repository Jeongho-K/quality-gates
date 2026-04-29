#!/usr/bin/env python3
"""PostToolUse hook: track files edited in this session for /qg scope.

Appends absolute file paths to .claude/quality-gates-session.local.md.
Triggered by Edit, Write, MultiEdit. Idempotent (dedup). No fsync.

Performance: ~10ms per call (Python interpreter cold-start dominates).
Hook logic itself is sub-millisecond: read state file, set-union, atomic rename.

Kill switches:
  DEVBREW_DISABLE_QUALITY_GATES=1   - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-tracker  - skip just this one
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

STATE_FILE = Path(".claude/quality-gates-session.local.md")
TRACKED_TOOLS = {"Edit", "Write", "MultiEdit"}
HEADER = "# Quality-Gates Session Files\n\n"


def _disabled() -> bool:
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    return "quality-gates:session-tracker" in skip


def _read_existing(path: Path) -> set[str]:
    if not path.exists():
        return set()
    seen = set()
    for line in path.read_text().splitlines():
        if line.startswith("- "):
            seen.add(line[2:].strip())
    return seen


def _write_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # PID-suffixed tmp avoids clobber if two hook invocations race.
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    tmp.write_text(content)
    tmp.replace(path)


def main() -> int:
    if _disabled():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    tool = payload.get("tool_name", "")
    if tool not in TRACKED_TOOLS:
        return 0
    file_path = payload.get("tool_input", {}).get("file_path")
    if not file_path:
        return 0
    abs_path = str(Path(file_path).resolve())
    existing = _read_existing(STATE_FILE)
    if abs_path in existing:
        return 0
    lines = [HEADER]
    sorted_paths = sorted(existing | {abs_path})
    lines.extend(f"- {p}\n" for p in sorted_paths)
    _write_atomic(STATE_FILE, "".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
