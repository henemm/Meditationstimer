#!/usr/bin/env python3
"""
Helper-Script zum Aktualisieren des Workflow-States.

Aufruf:
  python3 update_state.py <phase> [--feature <name>] [--type <bug|feature>]

Phasen:
  idle, analysing, spec_written, spec_approved, implementing, validating

TDD-Befehle:
  tests_written --proof <log_file>   # Markiert Tests als RED (mit Beweis!)
  tests_written --user-verified      # User bestätigt manuell (für lokale Tests)
  tests_passing                      # Markiert Tests als GREEN
"""

import json
import sys
import re
from datetime import datetime
from pathlib import Path

STATE_FILE = Path(__file__).parent.parent / "workflow_state.json"
TDD_LOG_FILE = Path(__file__).parent.parent / "tdd_proof.log"


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
            "tdd_proof": None,  # NEU: Beweis für TDD RED
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


def verify_test_failure(log_content: str) -> tuple[bool, str]:
    """
    Prüft ob der Test-Log echte Test-Failures enthält.

    Returns: (is_valid, reason)
    """
    # Muster für echte Test-Failures (nicht nur Compile-Errors!)
    failure_patterns = [
        r"Test Case .* failed",
        r"XCTAssert.*failed",
        r"expected .* but got",
        r"Executed \d+ tests?, with \d+ failure",
        r"\*\* TEST FAILED \*\*",
        r"FAILED.*\d+ test",
    ]

    # Muster für Compile-Errors (das ist KEIN echter TDD RED!)
    compile_error_patterns = [
        r"error:.*has no member",
        r"error:.*cannot find .* in scope",
        r"error:.*undeclared type",
        r"Build Failed",
    ]

    has_test_failure = any(re.search(p, log_content, re.IGNORECASE) for p in failure_patterns)
    has_compile_error = any(re.search(p, log_content, re.IGNORECASE) for p in compile_error_patterns)

    if has_compile_error and not has_test_failure:
        return False, "Compile-Error ist KEIN echter TDD RED! Tests müssen kompilieren aber im Verhalten fehlschlagen."

    if has_test_failure:
        return True, "Echte Test-Failures gefunden."

    return False, "Keine Test-Failures im Log gefunden. Tests müssen ausgeführt werden und fehlschlagen."


def main():
    if len(sys.argv) < 2:
        print("Usage: update_state.py <phase> [--feature <name>] [--type <bug|feature>]")
        print("")
        print("TDD-Befehle:")
        print("  tests_written --proof <log_file>   # Beweis für echte Test-Failures")
        print("  tests_written --user-verified      # User bestätigt manuell")
        print("  tests_passing                      # Tests sind jetzt grün")
        sys.exit(1)

    command = sys.argv[1]
    valid_phases = ["idle", "analysing", "spec_written", "spec_approved", "implementing", "validating"]

    # Spezielle TDD-Befehle
    if command == "tests_written":
        args = sys.argv[2:]

        # PFLICHT: Beweis oder User-Bestätigung
        if "--proof" in args:
            proof_idx = args.index("--proof")
            if proof_idx + 1 >= len(args):
                print("❌ --proof benötigt eine Log-Datei als Argument")
                sys.exit(1)

            log_file = Path(args[proof_idx + 1])
            if not log_file.exists():
                print(f"❌ Log-Datei nicht gefunden: {log_file}")
                sys.exit(1)

            log_content = log_file.read_text()
            is_valid, reason = verify_test_failure(log_content)

            if not is_valid:
                print(f"❌ TDD RED ABGELEHNT: {reason}")
                print("")
                print("Ein echter TDD RED Test muss:")
                print("  1. Mit dem bestehenden Code KOMPILIEREN")
                print("  2. Im VERHALTEN fehlschlagen (XCTAssert fails)")
                print("  3. Nicht nur 'Methode existiert nicht' prüfen")
                sys.exit(1)

            # Beweis speichern
            TDD_LOG_FILE.write_text(log_content)

            state = load_state()
            state["tests_written"] = True
            state["tdd_proof"] = f"log_verified:{datetime.now().isoformat()}"
            save_state(state)
            print("✓ TDD RED verifiziert: Echte Test-Failures gefunden")
            print("  → Du darfst jetzt Produktions-Code ändern")
            return

        elif "--user-verified" in args:
            state = load_state()
            state["tests_written"] = True
            state["tdd_proof"] = f"user_verified:{datetime.now().isoformat()}"
            save_state(state)
            print("✓ User hat TDD RED manuell bestätigt")
            print("  → Du darfst jetzt Produktions-Code ändern")
            return

        else:
            print("❌ TDD RED benötigt Beweis!")
            print("")
            print("Optionen:")
            print("  --proof <log_file>   Log mit Test-Output (muss Failures zeigen)")
            print("  --user-verified      User bestätigt manuell (für lokale Tests)")
            print("")
            print("WICHTIG: Ein Compile-Error ist KEIN echter TDD RED!")
            print("Tests müssen kompilieren aber im Verhalten fehlschlagen.")
            sys.exit(1)

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
