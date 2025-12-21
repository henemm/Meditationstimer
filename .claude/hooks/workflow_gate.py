#!/usr/bin/env python3
"""
Workflow Gate Hook - Erzwingt Phasen-basiertes Arbeiten

Phasen:
  idle          → Keine aktive Arbeit
  analysing     → Bug/Feature wird analysiert
  spec_written  → Spezifikation geschrieben
  spec_approved → User hat Spec freigegeben
  implementing  → Code wird geschrieben (EINZIGE Phase für Edit/Write!)
  validating    → Tests laufen, Validierung

Exit Codes:
  0 = Erlaubt
  2 = Blockiert (Tool wird nicht ausgeführt)
"""

import json
import os
import sys
import re
from datetime import datetime
from pathlib import Path

# Pfade relativ zum Projekt
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent.parent
STATE_FILE = SCRIPT_DIR.parent / "workflow_state.json"

# Dateien die IMMER erlaubt sind (auch ohne Workflow)
ALWAYS_ALLOWED_PATTERNS = [
    r"\.claude/.*",           # Claude config
    r"\.agent-os/.*",         # Agent OS config
    r"DOCS/.*\.md",           # Dokumentation
    r"openspec/.*",           # Specs
    r".*\.xcstrings",         # Lokalisierung (via /localize)
    r"\.gitignore",
    r"README\.md",
    r"CLAUDE\.md",
]

# Geschützte Pfade die Workflow erfordern
PROTECTED_PATTERNS = [
    r".*\.swift$",            # Swift Code
    r".*\.xcdatamodeld/.*",   # Core Data
    r".*\.xcodeproj/.*",      # Projekt-Dateien
]


def load_state() -> dict:
    """Lädt den aktuellen Workflow-State."""
    if not STATE_FILE.exists():
        return {"current_phase": "idle"}

    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return {"current_phase": "idle"}


def is_always_allowed(file_path: str) -> bool:
    """Prüft ob Datei immer erlaubt ist."""
    rel_path = file_path
    if file_path.startswith(str(PROJECT_DIR)):
        rel_path = file_path[len(str(PROJECT_DIR)):].lstrip("/")

    for pattern in ALWAYS_ALLOWED_PATTERNS:
        if re.match(pattern, rel_path):
            return True
    return False


def requires_workflow(file_path: str) -> bool:
    """Prüft ob Datei den Workflow erfordert."""
    rel_path = file_path
    if file_path.startswith(str(PROJECT_DIR)):
        rel_path = file_path[len(str(PROJECT_DIR)):].lstrip("/")

    for pattern in PROTECTED_PATTERNS:
        if re.match(pattern, rel_path):
            return True
    return False


def get_phase_error(phase: str, file_path: str) -> str:
    """Generiert kontextabhängige Fehlermeldung."""

    messages = {
        "idle": f"""
╔══════════════════════════════════════════════════════════════════╗
║  ⛔ WORKFLOW GATE: Keine aktive Phase                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Du versuchst Code zu ändern ohne aktiven Workflow!              ║
║                                                                  ║
║  STARTE ZUERST:                                                  ║
║    • /bug [beschreibung]     → für Bug-Fixes                     ║
║    • /feature [name]         → für neue Features                 ║
║                                                                  ║
║  Datei: {file_path[:50]}...
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""",
        "analysing": f"""
╔══════════════════════════════════════════════════════════════════╗
║  ⛔ WORKFLOW GATE: Noch in Analyse-Phase                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Die Analyse ist noch nicht abgeschlossen!                       ║
║                                                                  ║
║  NÄCHSTE SCHRITTE:                                               ║
║    1. Analyse abschließen (Root Cause identifizieren)            ║
║    2. /spec schreiben oder Approval einholen                     ║
║    3. DANN erst /implement aufrufen                              ║
║                                                                  ║
║  Datei: {file_path[:50]}...
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""",
        "spec_written": f"""
╔══════════════════════════════════════════════════════════════════╗
║  ⛔ WORKFLOW GATE: Spec noch nicht freigegeben                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Die Spezifikation wartet auf User-Approval!                     ║
║                                                                  ║
║  NÄCHSTER SCHRITT:                                               ║
║    → User muss "Approved" oder "Freigegeben" sagen               ║
║    → DANN erst /implement aufrufen                               ║
║                                                                  ║
║  Datei: {file_path[:50]}...
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""",
        "spec_approved": f"""
╔══════════════════════════════════════════════════════════════════╗
║  ⛔ WORKFLOW GATE: /implement noch nicht aufgerufen              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Die Spec ist freigegeben - aber die Implementierungs-Phase      ║
║  wurde noch nicht gestartet!                                     ║
║                                                                  ║
║  NÄCHSTER SCHRITT:                                               ║
║    → /implement aufrufen um Code-Änderungen zu erlauben          ║
║                                                                  ║
║  Datei: {file_path[:50]}...
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""",
        "validating": f"""
╔══════════════════════════════════════════════════════════════════╗
║  ⛔ WORKFLOW GATE: In Validierungs-Phase                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Die Implementierung ist abgeschlossen - jetzt wird validiert!   ║
║                                                                  ║
║  Wenn Fixes nötig sind:                                          ║
║    → /implement erneut aufrufen                                  ║
║                                                                  ║
║  Datei: {file_path[:50]}...
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
""",
    }

    return messages.get(phase, f"Phase '{phase}' erlaubt keine Code-Änderungen.")


def get_tdd_error(file_path: str) -> str:
    """Generiert TDD-Fehlermeldung wenn Tests fehlen."""
    return f"""
╔══════════════════════════════════════════════════════════════════╗
║  🔴 TDD GATE: Erst Tests schreiben!                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Du versuchst Produktions-Code zu ändern OHNE vorherigen Test!  ║
║                                                                  ║
║  TDD-WORKFLOW:                                                   ║
║    1. Test schreiben der das erwartete Verhalten prüft           ║
║    2. Test ausführen → muss ROT sein (fehlschlagen)              ║
║    3. Dann: python3 .claude/hooks/update_state.py tests_written  ║
║    4. JETZT darfst du den Produktions-Code ändern                ║
║                                                                  ║
║  Datei: {file_path[:50]}...
║                                                                  ║
║  ⚠️  KEIN Trial-and-Error! Erst analysieren, dann testen!        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
"""


def main():
    """Hauptlogik des Workflow Gates."""

    # Input von Claude Code lesen (JSON auf stdin)
    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        # Kein gültiger Input - erlauben (Fallback)
        sys.exit(0)

    # Tool und Parameter extrahieren
    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Nur Edit und Write prüfen
    if tool_name not in ["Edit", "Write"]:
        sys.exit(0)

    # Dateipfad extrahieren
    file_path = tool_input.get("file_path", "")
    if not file_path:
        sys.exit(0)

    # Immer erlaubte Dateien durchlassen
    if is_always_allowed(file_path):
        sys.exit(0)

    # Prüfen ob Datei Workflow erfordert
    if not requires_workflow(file_path):
        sys.exit(0)

    # State laden und Phase prüfen
    state = load_state()
    current_phase = state.get("current_phase", "idle")

    # NUR in "implementing" Phase sind Code-Änderungen erlaubt!
    if current_phase == "implementing":
        # ZUSÄTZLICH: TDD-Check - Tests müssen VORHER geschrieben sein!
        tests_written = state.get("tests_written", False)

        # Unterscheide zwischen Test-Dateien und Produktion-Code
        is_test_file = "Tests/" in file_path or "Test" in file_path

        if is_test_file:
            # Test-Dateien immer erlauben (das ist ja der RED-Schritt)
            sys.exit(0)

        if not tests_written:
            # Produktion-Code ohne vorherige Tests → BLOCKIEREN
            error_msg = get_tdd_error(file_path)
            print(error_msg, file=sys.stderr)
            sys.exit(2)

        # Tests geschrieben → Code-Änderungen erlaubt
        sys.exit(0)

    # Alle anderen Phasen: BLOCKIEREN
    error_msg = get_phase_error(current_phase, file_path)
    print(error_msg, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
