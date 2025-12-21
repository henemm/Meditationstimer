#!/usr/bin/env python3
"""
Helper-Script zum Aktualisieren des Workflow-States.

Aufruf:
  python3 update_state.py <phase> [--feature <name>] [--type <bug|feature>]

Phasen:
  idle, analysing, spec_written, spec_approved, implementing, validating
"""

import json
import sys
from datetime import datetime
from pathlib import Path

STATE_FILE = Path(__file__).parent.parent / "workflow_state.json"


def load_state() -> dict:
    """Lädt den aktuellen State."""
    if not STATE_FILE.exists():
        return {
            "current_phase": "idle",
            "workflow_type": None,
            "feature_name": None,
            "spec_file": None,
            "spec_approved": False,
            "tests_written": False,
            "tests_passing": False,
            "implementation_done": False,
            "validated": False,
            "last_updated": None,
            "phase_history": []
        }

    with open(STATE_FILE, "r") as f:
        return json.load(f)


def save_state(state: dict) -> None:
    """Speichert den State."""
    state["last_updated"] = datetime.now().isoformat()
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def main():
    if len(sys.argv) < 2:
        print("Usage: update_state.py <phase> [--feature <name>] [--type <bug|feature>]")
        print("       update_state.py tests_written   # Markiert Tests als geschrieben (RED)")
        print("       update_state.py tests_passing   # Markiert Tests als bestanden (GREEN)")
        sys.exit(1)

    command = sys.argv[1]
    valid_phases = ["idle", "analysing", "spec_written", "spec_approved", "implementing", "validating"]

    # Spezielle TDD-Befehle
    if command == "tests_written":
        state = load_state()
        state["tests_written"] = True
        save_state(state)
        print("✓ Tests als geschrieben markiert (RED-Phase abgeschlossen)")
        print("  → Du darfst jetzt Produktions-Code ändern")
        return

    if command == "tests_passing":
        state = load_state()
        state["tests_passing"] = True
        save_state(state)
        print("✓ Tests als bestanden markiert (GREEN-Phase erreicht)")
        return

    new_phase = command
    if new_phase not in valid_phases:
        print(f"Invalid phase: {new_phase}")
        print(f"Valid phases: {', '.join(valid_phases)}")
        print(f"TDD commands: tests_written, tests_passing")
        sys.exit(1)

    state = load_state()

    # Phase History tracken
    if "phase_history" not in state:
        state["phase_history"] = []

    state["phase_history"].append({
        "from": state.get("current_phase", "idle"),
        "to": new_phase,
        "timestamp": datetime.now().isoformat()
    })

    # Neue Phase setzen
    state["current_phase"] = new_phase

    # Bei neuer Analyse: TDD-Flags zurücksetzen
    if new_phase == "analysing":
        state["tests_written"] = False
        state["tests_passing"] = False
        state["implementation_done"] = False
        state["validated"] = False

    # Optionale Parameter
    args = sys.argv[2:]
    i = 0
    while i < len(args):
        if args[i] == "--feature" and i + 1 < len(args):
            state["feature_name"] = args[i + 1]
            i += 2
        elif args[i] == "--type" and i + 1 < len(args):
            state["workflow_type"] = args[i + 1]
            i += 2
        elif args[i] == "--spec" and i + 1 < len(args):
            state["spec_file"] = args[i + 1]
            i += 2
        elif args[i] == "--approved":
            state["spec_approved"] = True
            i += 1
        elif args[i] == "--tests-written":
            state["tests_written"] = True
            i += 1
        elif args[i] == "--tests-passing":
            state["tests_passing"] = True
            i += 1
        elif args[i] == "--implemented":
            state["implementation_done"] = True
            i += 1
        elif args[i] == "--validated":
            state["validated"] = True
            i += 1
        elif args[i] == "--reset":
            # Komplett zurücksetzen
            state = {
                "current_phase": "idle",
                "workflow_type": None,
                "feature_name": None,
                "spec_file": None,
                "spec_approved": False,
                "tests_written": False,
                "tests_passing": False,
                "implementation_done": False,
                "validated": False,
                "last_updated": None,
                "phase_history": []
            }
            i += 1
        else:
            i += 1

    save_state(state)
    print(f"✓ Phase: {new_phase}")
    if state.get("feature_name"):
        print(f"  Feature: {state['feature_name']}")
    if state.get("workflow_type"):
        print(f"  Type: {state['workflow_type']}")


if __name__ == "__main__":
    main()
