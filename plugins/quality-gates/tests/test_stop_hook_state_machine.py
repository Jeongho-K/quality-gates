"""Tests for stop-hook state machine after cross-gate loop removal."""
import importlib.util
import sys
import unittest
from pathlib import Path

HOOK_PATH = Path(__file__).resolve().parent.parent / "hooks" / "stop-hook.py"
spec = importlib.util.spec_from_file_location("stop_hook", HOOK_PATH)
stop_hook = importlib.util.module_from_spec(spec)
sys.modules["stop_hook"] = stop_hook
spec.loader.exec_module(stop_hook)


class TestForwardOnlyStateMachine(unittest.TestCase):
    def test_no_max_total_iterations_constant(self):
        # The constant must be removed (it was stored in state, not as a module constant;
        # confirm no module-level MAX_TOTAL_ITERATIONS attribute exists)
        self.assertFalse(hasattr(stop_hook, "MAX_TOTAL_ITERATIONS"))

    def test_gate2_needs_restart_does_not_loop_to_gate1(self):
        state = {
            "current_gate": 2,
            "gate2_iteration": 1,
            "max_gate2_iterations": 5,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"gate": "2", "verdict": "NEEDS_RESTART", "summary": "fix needed"}
        transition = stop_hook.compute_transition(state, signal)
        # Forward-only contract: NEEDS_RESTART must NOT trigger fix-loop or restart;
        # it always escalates to user-choice with the canonical prompt key.
        self.assertEqual(transition["type"], "gate2_user_choice")
        self.assertEqual(transition["prompt_key"], "gate2_needs_restart")

    def test_gate3_needs_restart_terminates_with_user_choice(self):
        state = {
            "current_gate": 3,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "gate2_iteration": 0,
            "max_gate2_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"gate": "3", "verdict": "NEEDS_RESTART", "summary": "runtime fail"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_fail")
        # Forward-only: never returns "restart"
        self.assertNotEqual(transition["type"], "restart")

    def test_trivia_skipped_verdict_completes_pipeline(self):
        state = {
            "current_gate": 1,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "gate2_iteration": 0,
            "max_gate2_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"verdict": "trivia-skipped", "reason": "whitespace"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "complete")

    def test_scout_fallback_verdict_does_not_break(self):
        state = {
            "current_gate": 2,
            "gate2_iteration": 1,
            "max_gate2_iterations": 5,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"verdict": "scout-fallback", "reason": "json parse error"}
        transition = stop_hook.compute_transition(state, signal)
        # Pipeline continues; scout fallback is informational, not terminal
        self.assertIn(transition["type"], {"continue", "retry_gate", "next_gate"})

    def test_repeat_detected_triggers_user_choice(self):
        state = {
            "current_gate": 2,
            "gate2_iteration": 3,
            "max_gate2_iterations": 5,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"verdict": "repeat-detected"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate2_user_choice")


if __name__ == "__main__":
    unittest.main()
