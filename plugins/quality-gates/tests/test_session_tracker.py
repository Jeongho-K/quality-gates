"""Tests for the post-tool-use session-tracker hook."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "post-tool-use-session-tracker.py"


def run_hook(payload, cwd):
    """Run the hook with a JSON payload on stdin and return (returncode, state_path, stderr)."""
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=cwd,
    )
    state_path = Path(cwd) / ".claude" / "quality-gates-session.local.md"
    return proc.returncode, state_path, proc.stderr


class TestSessionTracker(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.tmp, ".claude"), exist_ok=True)

    def test_appends_edit_path(self):
        payload = {"tool_name": "Edit", "tool_input": {"file_path": "/abs/path/foo.py"}}
        rc, state, err = run_hook(payload, self.tmp)
        self.assertEqual(rc, 0, msg=err)
        self.assertTrue(state.exists())
        content = state.read_text()
        self.assertIn("- /abs/path/foo.py", content)

    def test_dedup_within_run(self):
        for _ in range(2):
            run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": "/abs/path/bar.py"}},
                self.tmp,
            )
        state = Path(self.tmp) / ".claude" / "quality-gates-session.local.md"
        self.assertEqual(state.read_text().count("/abs/path/bar.py"), 1)

    def test_multiedit(self):
        payload = {
            "tool_name": "MultiEdit",
            "tool_input": {"file_path": "/abs/x.py", "edits": [{}]},
        }
        rc, state, _ = run_hook(payload, self.tmp)
        self.assertEqual(rc, 0)
        self.assertIn("- /abs/x.py", state.read_text())

    def test_ignores_non_edit_tools(self):
        payload = {"tool_name": "Read", "tool_input": {"file_path": "/abs/q.py"}}
        run_hook(payload, self.tmp)
        state = Path(self.tmp) / ".claude" / "quality-gates-session.local.md"
        self.assertFalse(state.exists())

    def test_kill_switch_env(self):
        env = os.environ.copy()
        env["DEVBREW_DISABLE_QUALITY_GATES"] = "1"
        proc = subprocess.run(
            [sys.executable, str(HOOK)],
            input=json.dumps(
                {"tool_name": "Edit", "tool_input": {"file_path": "/abs/k.py"}}
            ),
            capture_output=True,
            text=True,
            cwd=self.tmp,
            env=env,
        )
        self.assertEqual(proc.returncode, 0)
        state = Path(self.tmp) / ".claude" / "quality-gates-session.local.md"
        self.assertFalse(state.exists())

    def test_relative_path_resolved_to_absolute(self):
        payload = {"tool_name": "Edit", "tool_input": {"file_path": "rel/path.py"}}
        rc, state, _ = run_hook(payload, self.tmp)
        self.assertEqual(rc, 0)
        self.assertIn(os.path.join(self.tmp, "rel/path.py"), state.read_text())

    def test_kill_switch_skip_hooks(self):
        env = os.environ.copy()
        env["DEVBREW_SKIP_HOOKS"] = "quality-gates:session-tracker"
        proc = subprocess.run(
            [sys.executable, str(HOOK)],
            input=json.dumps(
                {"tool_name": "Edit", "tool_input": {"file_path": "/abs/s.py"}}
            ),
            capture_output=True,
            text=True,
            cwd=self.tmp,
            env=env,
        )
        self.assertEqual(proc.returncode, 0)
        state = Path(self.tmp) / ".claude" / "quality-gates-session.local.md"
        self.assertFalse(state.exists())


if __name__ == "__main__":
    unittest.main()
