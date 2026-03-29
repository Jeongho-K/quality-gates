#!/usr/bin/env python3
"""PostToolUse hook for quality-gates plugin.

Detects when `gh pr create` succeeds and injects a system message
to trigger the quality pipeline. Prevents double-triggering by checking
for an active state file.
"""

import json
import os
import re
import sys


def main():
    try:
        input_data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        print(json.dumps({}))
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    tool_output = input_data.get("tool_output", {})

    if tool_name != "Bash":
        print(json.dumps({}))
        sys.exit(0)

    command = tool_input.get("command", "")

    # Check if this is a gh pr create command
    if not re.search(r"gh\s+pr\s+create", command):
        print(json.dumps({}))
        sys.exit(0)

    # Check for active pipeline state file to prevent double-trigger
    # Use CWD env var if available (more reliable in agent threads), fallback to os.getcwd()
    project_dir = os.environ.get("CWD", os.getcwd())
    state_file = os.path.join(project_dir, ".claude", "quality-gates.local.md")
    if os.path.exists(state_file):
        print(json.dumps({}))
        sys.exit(0)

    # Extract PR URL from output
    # tool_output can be a dict {"stdout": "..."} or a plain string
    if isinstance(tool_output, dict):
        stdout = tool_output.get("stdout", "")
    else:
        stdout = str(tool_output)
    pr_url_match = re.search(r"https://github\.com/[^\s]+/pull/\d+", stdout)
    pr_url = pr_url_match.group(0) if pr_url_match else ""

    if not pr_url:
        print(json.dumps({}))
        sys.exit(0)

    result = {
        "systemMessage": (
            f"Quality Gates: PR created at {pr_url}. "
            "You MUST now run the quality-gates pipeline. "
            "Use the Skill tool to invoke 'quality-gates:quality-pipeline' "
            f"with args '--pr-url {pr_url}'."
        )
    }

    print(json.dumps(result))
    sys.exit(0)


if __name__ == "__main__":
    main()
