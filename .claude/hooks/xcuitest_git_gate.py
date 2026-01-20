#!/usr/bin/env python3
"""
XCUITest Git Gate - NICHT UMGEHBAR!

Dieser Hook prüft GIT STATUS statt State-Dateien.
Git kann nicht manipuliert werden!

Logik:
1. git status --porcelain zeigt geänderte Dateien
2. Wenn UI-Dateien geändert wurden → UITest-Dateien MÜSSEN auch geändert sein
3. Sonst: BLOCKIERT

Exit Codes:
- 0: Erlaubt
- 2: BLOCKIERT (keine UITests für UI-Änderungen)
"""

import json
import os
import subprocess
import sys
from pathlib import Path


# UI-Patterns die XCUITests erfordern
UI_PATTERNS = [
    "Meditationstimer iOS/Tabs/",
    "Meditationstimer iOS/Tracker/",
    "Meditationstimer iOS/Views/",
    "Meditationstimer iOS/Calendar",
    "Meditationstimer iOS/Settings",
    "Meditationstimer iOS/Sheet",
]

# Ausnahmen (brauchen keine UI-Tests)
EXEMPTIONS = [
    "Services/",
    "Models/",
    "Engine/",
    "Manager.swift",  # Service-Klassen
    ".md",
    "Tests/",
    "UITests/",
    "xcstrings",
    "Assets.xcassets",
    "Info.plist",
    "ContentView.swift",
    "App.swift",
    "Preview",  # Preview Provider
]

# UITest Verzeichnis
UITEST_DIR = "LeanHealthTimerUITests"


def get_project_root() -> Path:
    """Find project root."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def get_tool_input() -> dict:
    """Read tool input from stdin or environment."""
    tool_input_str = os.environ.get("CLAUDE_TOOL_INPUT", "")

    if tool_input_str:
        try:
            return json.loads(tool_input_str)
        except json.JSONDecodeError:
            pass

    try:
        data = json.load(sys.stdin)
        return data.get("tool_input", data)
    except (json.JSONDecodeError, EOFError, Exception):
        return {}


def get_git_modified_files() -> list[str]:
    """Get list of modified files from git status."""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain", "-uno"],  # -uno = ignore untracked
            capture_output=True,
            text=True,
            cwd=get_project_root(),
            timeout=5
        )

        files = []
        for line in result.stdout.strip().split("\n"):
            if line:
                # Format: "XY filename" or "XY old -> new" for renames
                parts = line[3:].split(" -> ")
                filename = parts[-1].strip()
                if filename:
                    files.append(filename)
        return files
    except (subprocess.TimeoutExpired, Exception) as e:
        print(f"Git status error: {e}", file=sys.stderr)
        return []


def is_ui_file(file_path: str) -> bool:
    """Check if file is a UI file that requires XCUITest."""
    # Must be Swift file
    if not file_path.endswith(".swift"):
        return False

    # Skip exemptions
    for exemption in EXEMPTIONS:
        if exemption in file_path:
            return False

    # Check UI patterns
    for pattern in UI_PATTERNS:
        if pattern in file_path:
            return True

    return False


def is_uitest_file(file_path: str) -> bool:
    """Check if file is a UI test file."""
    return UITEST_DIR in file_path and file_path.endswith(".swift")


def check_uitests_for_ui_changes(current_file: str) -> tuple[bool, str]:
    """
    Check if UI changes have corresponding UITest changes.
    Returns (allowed, reason).
    """
    modified_files = get_git_modified_files()

    # Add the current file being edited (it's not yet in git status)
    if current_file and current_file not in modified_files:
        # Normalize path
        project_root = get_project_root()
        try:
            relative_path = Path(current_file).relative_to(project_root)
            modified_files.append(str(relative_path))
        except ValueError:
            modified_files.append(current_file)

    # Separate UI files and UITest files
    ui_files_changed = [f for f in modified_files if is_ui_file(f)]
    uitest_files_changed = [f for f in modified_files if is_uitest_file(f)]

    # If no UI files changed, allow
    if not ui_files_changed:
        return True, "Keine UI-Dateien geändert"

    # If UI files changed but NO UITest files changed → BLOCK
    if ui_files_changed and not uitest_files_changed:
        ui_list = "\n".join([f"    • {f}" for f in ui_files_changed[:5]])
        if len(ui_files_changed) > 5:
            ui_list += f"\n    • ... und {len(ui_files_changed) - 5} weitere"

        return False, f"""
╔══════════════════════════════════════════════════════════════════════╗
║  ⛔ BLOCKIERT: UI-ÄNDERUNGEN OHNE XCUITESTS!                         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Du hast UI-Dateien geändert:                                        ║
{ui_list}
║                                                                      ║
║  ABER keine XCUITest-Dateien in LeanHealthTimerUITests/              ║
║                                                                      ║
║  ══════════════════════════════════════════════════════════════════  ║
║  DIESE PRÜFUNG IST GIT-BASIERT UND NICHT UMGEHBAR!                   ║
║  ══════════════════════════════════════════════════════════════════  ║
║                                                                      ║
║  Du MUSST:                                                           ║
║  1. XCUITest schreiben in LeanHealthTimerUITests/                    ║
║  2. Test committen oder stagen                                       ║
║  3. DANN erst UI-Code schreiben                                      ║
║                                                                      ║
║  ⚠️ State-Dateien manipulieren hilft NICHT!                          ║
║  Diese Prüfung verwendet `git status` direkt.                        ║
╚══════════════════════════════════════════════════════════════════════╝
"""

    return True, f"UI-Änderungen haben UITests: {', '.join(uitest_files_changed[:3])}"


def main():
    tool_input = get_tool_input()
    file_path = tool_input.get("file_path", "")

    if not file_path:
        sys.exit(0)

    # Skip if editing UITest files (we want to allow writing tests!)
    if is_uitest_file(file_path):
        sys.exit(0)

    # Skip if not a UI file
    if not is_ui_file(file_path):
        sys.exit(0)

    # Check for UITests
    allowed, reason = check_uitests_for_ui_changes(file_path)

    if not allowed:
        print(reason, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
