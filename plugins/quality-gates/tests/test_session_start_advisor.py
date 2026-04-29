"""Tests for the SessionStart advisor (read-only).

Status fixtures use the canonical vocabulary documented in
skills/quality-pipeline/references/state-file-format.md:
  gate1_running | gate2_running | gate3_running | completed | aborted
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "session-start-advisor.py"


def make_state(status: str, gate: int = 2, started_at: str = "2026-04-29T08:14:00Z") -> str:
    return (
        "---\n"
        f"status: {status}\n"
        f"current_gate: {gate}\n"
        "total_iterations: 1\n"
        f'started_at: "{started_at}"\n'
        "---\n"
        "# Quality Gates Pipeline State\n"
    )


def run_advisor(cwd):
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps({}),
        capture_output=True,
        text=True,
        cwd=cwd,
    )
    return proc


class TestAdvisor(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.tmp, ".claude"), exist_ok=True)

    def test_no_state_silent(self):
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_active_state_prints_one_liner(self):
        Path(self.tmp, ".claude/quality-gates.local.md").write_text(make_state("gate2_running", gate=2))
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("/qg", proc.stdout)
        self.assertIn("--reset", proc.stdout)

    def test_done_state_silent(self):
        Path(self.tmp, ".claude/quality-gates.local.md").write_text(make_state("completed"))
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_aborted_state_silent(self):
        Path(self.tmp, ".claude/quality-gates.local.md").write_text(make_state("aborted"))
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_does_not_mutate_files(self):
        state_path = Path(self.tmp, ".claude/quality-gates.local.md")
        session_path = Path(self.tmp, ".claude/quality-gates-session.local.md")
        state_path.write_text(make_state("gate2_running"))
        session_path.write_text("- /a\n- /b\n")
        before = (state_path.read_text(), session_path.read_text())
        run_advisor(self.tmp)
        after = (state_path.read_text(), session_path.read_text())
        self.assertEqual(before, after)

    def test_kill_switch(self):
        Path(self.tmp, ".claude/quality-gates.local.md").write_text(make_state("gate2_running"))
        env = os.environ.copy()
        env["DEVBREW_DISABLE_QUALITY_GATES"] = "1"
        proc = subprocess.run(
            [sys.executable, str(HOOK)],
            input=json.dumps({}),
            capture_output=True,
            text=True,
            cwd=self.tmp,
            env=env,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_each_active_status_prints(self):
        for status in ("gate1_running", "gate2_running", "gate3_running"):
            with self.subTest(status=status):
                Path(self.tmp, ".claude/quality-gates.local.md").write_text(make_state(status))
                proc = run_advisor(self.tmp)
                self.assertEqual(proc.returncode, 0)
                self.assertIn("--reset", proc.stdout, msg=f"silent on {status}")

    def test_each_terminal_status_silent(self):
        for status in ("completed", "aborted"):
            with self.subTest(status=status):
                Path(self.tmp, ".claude/quality-gates.local.md").write_text(make_state(status))
                proc = run_advisor(self.tmp)
                self.assertEqual(proc.returncode, 0)
                self.assertEqual(proc.stdout, "", msg=f"output on terminal {status}")

    def test_advisory_includes_gate_and_timestamp(self):
        Path(self.tmp, ".claude/quality-gates.local.md").write_text(
            make_state("gate2_running", gate=2, started_at="2026-04-29T08:14:00Z")
        )
        proc = run_advisor(self.tmp)
        self.assertIn("Gate 2", proc.stdout)
        self.assertIn("2026-04-29T08:14:00Z", proc.stdout)

    def test_quoted_status_value_handled(self):
        # Defensive: even though current writers don't quote bare statuses,
        # tolerate `status: "gate2_running"` if it ever appears.
        Path(self.tmp, ".claude/quality-gates.local.md").write_text(
            "---\nstatus: \"gate2_running\"\ncurrent_gate: 2\n---\n"
        )
        proc = run_advisor(self.tmp)
        self.assertIn("--reset", proc.stdout)


if __name__ == "__main__":
    unittest.main()
