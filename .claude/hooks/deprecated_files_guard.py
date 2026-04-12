#!/usr/bin/env python3
"""
Deprecated Files Guard - Prevents writing to legacy tracking files.

Bugs and tasks are now tracked via GitHub Issues.
ACTIVE-todos.md and ACTIVE-roadmap.md are deprecated.

Exit Codes:
- 0: Allowed
- 2: Blocked (writing to deprecated file)
"""

import json
import sys

DEPRECATED_FILES = [
    "ACTIVE-todos.md",
    "ACTIVE-roadmap.md",
]

BLOCK_MESSAGE = """⛔ BLOCKED: {file} ist deprecated!

Bugs & Tasks werden jetzt über GitHub Issues verwaltet:
  gh issue create --title "..." --label "bug" --body "..."
  gh issue list
  gh issue close #N

ACTIVE-todos.md und ACTIVE-roadmap.md werden NICHT mehr beschrieben."""


def main():
    tool_input = json.loads(sys.stdin.read())
    tool_name = tool_input.get("tool_name", "")

    if tool_name not in ("Edit", "Write"):
        sys.exit(0)

    tool_input_data = tool_input.get("tool_input", {})
    file_path = tool_input_data.get("file_path", "")

    for deprecated in DEPRECATED_FILES:
        if file_path.endswith(deprecated):
            print(BLOCK_MESSAGE.format(file=deprecated), file=sys.stderr)
            sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
