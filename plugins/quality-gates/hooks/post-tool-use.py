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
    # Actual field name from Claude Code is "tool_response", not "tool_output"
    tool_response = input_data.get("tool_response", {})

    if tool_name != "Bash":
        print(json.dumps({}))
        sys.exit(0)

    command = tool_input.get("command", "")

    # Check if this is a gh pr create command
    if not re.search(r"gh\s+pr\s+create", command):
        print(json.dumps({}))
        sys.exit(0)

    # Check for active pipeline state file to prevent double-trigger
    project_dir = input_data.get("cwd", os.getcwd())
    state_file = os.path.join(project_dir, ".claude", "quality-gates.local.md")
    if os.path.exists(state_file):
        print(json.dumps({}))
        sys.exit(0)

    # Extract PR URL from tool_response.stdout
    if isinstance(tool_response, dict):
        stdout = tool_response.get("stdout", "")
    else:
        stdout = str(tool_response)
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
