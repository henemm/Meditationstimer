#!/usr/bin/env python3
"""
XCUITest Gate Hook - BLOCKT UI-Code ohne XCUITest

PFLICHT: Bevor UI-Code geschrieben wird, MUSS ein XCUITest existieren.

Dieser Hook:
1. Erkennt Änderungen an UI-Dateien (Tabs/, Tracker/, Views/, iOS/)
2. Prüft ob ein zugehöriger XCUITest existiert
3. BLOCKT wenn kein Test vorhanden ist

Exit Codes:
- 0: Erlaubt (Test existiert oder keine UI-Datei)
- 2: BLOCKIERT (kein XCUITest vorhanden)
"""

import json
import os
import sys
from pathlib import Path

# UI-Patterns die XCUITests erfordern
UI_PATTERNS = [
    "Tabs/",
    "Tracker/",
    "Views/",
    "/iOS/",
    "Meditationstimer iOS/",
]

# Ausnahmen (brauchen keine UI-Tests)
EXEMPTIONS = [
    "Services/",
    "Models/",
    "Engine/",
    "Manager/",
    ".md",
    "Tests/",
    "UITests/",
    "xcstrings",  # Lokalisierung
    "Assets.xcassets",
    "Info.plist",
    "ContentView.swift",  # Container, kein eigener Test nötig
]

# XCUITest Verzeichnis
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


def is_ui_file(file_path: str) -> bool:
    """Check if file is a UI file that requires XCUITest."""
    # Skip exemptions
    for exemption in EXEMPTIONS:
        if exemption in file_path:
            return False

    # Must be Swift file
    if not file_path.endswith(".swift"):
        return False

    # Check UI patterns
    for pattern in UI_PATTERNS:
        if pattern in file_path:
            return True

    return False


def get_active_workflow() -> dict:
    """Get active workflow from workflow_state.json."""
    project_root = get_project_root()
    state_file = project_root / ".claude" / "workflow_state.json"

    if not state_file.exists():
        return {}

    try:
        with open(state_file, 'r') as f:
            state = json.load(f)

        active_id = state.get("active_workflow")
        if active_id:
            return state.get("workflows", {}).get(active_id, {})
    except (json.JSONDecodeError, Exception):
        pass

    return {}


def has_xcuitest_artifact(workflow: dict) -> bool:
    """Check if workflow has XCUITest artifacts."""
    artifacts = workflow.get("test_artifacts", [])

    for artifact in artifacts:
        desc = artifact.get("description", "").lower()
        path = artifact.get("path", "").lower()

        # Check for XCUITest indicators
        xcuitest_indicators = [
            "xcuitest", "uitest", "ui test", "ui-test",
            "leanhealtimeritests", "leanhealthtimeruitests"
        ]

        for indicator in xcuitest_indicators:
            if indicator in desc or indicator in path:
                return True

    return False


def find_existing_uitests(feature_name: str) -> list[str]:
    """Find existing UI tests that might cover this feature."""
    project_root = get_project_root()
    uitest_dir = project_root / UITEST_DIR

    if not uitest_dir.exists():
        return []

    # Normalize feature name for matching
    feature_lower = feature_name.lower().replace("-", "").replace("_", "")

    found_tests = []
    for test_file in uitest_dir.glob("*.swift"):
        file_lower = test_file.stem.lower().replace("-", "").replace("_", "")

        # Check if feature name appears in test file name
        if feature_lower in file_lower or file_lower in feature_lower:
            found_tests.append(test_file.name)

    return found_tests


def check_xcuitest_exists(file_path: str) -> tuple[bool, str]:
    """
    Check if XCUITest exists for the given UI file.
    Returns (allowed, reason).
    """
    workflow = get_active_workflow()

    # If no workflow, we can't enforce - allow with warning
    if not workflow:
        return True, "Kein aktiver Workflow - XCUITest-Prüfung übersprungen"

    # Check workflow phase - only enforce in implementation phases
    phase = workflow.get("current_phase", "")
    if phase not in ["phase5_tdd_red", "phase6_implement"]:
        return True, f"Phase {phase} - XCUITest-Gate nicht aktiv"

    # In TDD RED phase, we're writing tests - allow
    if phase == "phase5_tdd_red":
        return True, "TDD RED Phase - Tests werden geschrieben"

    # In IMPLEMENT phase, check for XCUITest artifact
    if not has_xcuitest_artifact(workflow):
        # Get workflow name for hint
        workflow_id = ""
        project_root = get_project_root()
        state_file = project_root / ".claude" / "workflow_state.json"
        try:
            with open(state_file, 'r') as f:
                state = json.load(f)
            workflow_id = state.get("active_workflow", "unbekannt")
        except:
            pass

        # Check for existing tests
        existing = find_existing_uitests(workflow_id)
        existing_hint = ""
        if existing:
            existing_hint = f"\n|  Existierende Tests: {', '.join(existing[:3])}"

        return False, f"""
╔══════════════════════════════════════════════════════════════════════╗
║  ⛔ BLOCKIERT: KEIN XCUITEST VORHANDEN!                              ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Du versuchst UI-Code zu schreiben OHNE XCUITest.                    ║
║                                                                      ║
║  Feature: {workflow_id[:50]:<50} ║
║  Datei: {file_path[-50:]:<50} ║{existing_hint}
║                                                                      ║
║  ══════════════════════════════════════════════════════════════════  ║
║  PFLICHT VOR JEDER UI-ÄNDERUNG:                                      ║
║                                                                      ║
║  1. XCUITest schreiben in LeanHealthTimerUITests/                    ║
║  2. Test ausführen (muss FEHLSCHLAGEN = TDD RED)                     ║
║  3. Artefakt hinzufügen: /add-artifact                               ║
║  4. DANN erst Code schreiben                                         ║
║                                                                      ║
║  Kein Ausweg! Keine manuellen Test-Checklisten!                      ║
╚══════════════════════════════════════════════════════════════════════╝
"""

    return True, "XCUITest-Artefakt vorhanden"


def main():
    tool_input = get_tool_input()
    file_path = tool_input.get("file_path", "")

    if not file_path:
        sys.exit(0)

    # Check if this is a UI file
    if not is_ui_file(file_path):
        sys.exit(0)

    # Check for XCUITest
    allowed, reason = check_xcuitest_exists(file_path)

    if not allowed:
        print(reason, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
