#!/usr/bin/env python3
"""
Implementation Gate Hook für Meditationstimer/HHHaven

Dieser Hook wird VOR jedem Write/Edit-Aufruf ausgeführt und erinnert
Claude an das Implementation Gate gemäß .agent-os/standards/global/implementation-gate.md

Exit Codes:
- 0 = Erlaubt (Dokumentation, Config, etc.)
- 2 = BLOCKIERT mit Fehlermeldung an Claude
"""
import json
import sys
import os
from pathlib import Path

# Dateitypen, die KEIN Gate benötigen (Dokumentation, Config)
EXEMPT_EXTENSIONS = {
    '.md', '.txt', '.json', '.yml', '.yaml', '.xml',
    '.gitignore', '.gitattributes'
}

# Pfade, die KEIN Gate benötigen
EXEMPT_PATHS = {
    'DOCS/', 'docs/', '.claude/', '.agent-os/',
    'openspec/', 'Scripts/', 'README', 'CHANGELOG',
    'Contents.json'  # Asset catalog configs
}

# Dateitypen, die das Gate IMMER benötigen
CODE_EXTENSIONS = {
    '.swift', '.m', '.h', '.c', '.cpp',
    '.py', '.js', '.ts', '.tsx', '.jsx'
}

def is_exempt(file_path: str) -> bool:
    """Prüft ob die Datei vom Gate ausgenommen ist"""
    path = Path(file_path)

    # Extension-basierte Ausnahme
    if path.suffix.lower() in EXEMPT_EXTENSIONS:
        return True

    # Pfad-basierte Ausnahme
    for exempt in EXEMPT_PATHS:
        if exempt in file_path:
            return True

    return False

def is_code_file(file_path: str) -> bool:
    """Prüft ob es sich um eine Code-Datei handelt"""
    path = Path(file_path)
    return path.suffix.lower() in CODE_EXTENSIONS

def main():
    try:
        # JSON-Input von Claude Code lesen
        input_data = json.load(sys.stdin)
        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})
        file_path = tool_input.get("file_path", "")

        # Nur Write und Edit prüfen
        if tool_name not in ["Write", "Edit"]:
            sys.exit(0)

        # Ausnahmen prüfen
        if is_exempt(file_path):
            sys.exit(0)

        # Code-Dateien benötigen das Gate!
        if is_code_file(file_path):
            # JSON-Output für Claude mit Warnung
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": (
                        "⚠️ IMPLEMENTATION GATE REMINDER ⚠️\\n"
                        "Vor Code-Änderungen MUSS das Gate durchlaufen werden:\\n"
                        "1. [ ] Bestehende Tests ausgeführt (xcodebuild test)\\n"
                        "2. [ ] Neue Tests definiert/geschrieben\\n"
                        "3. [ ] XCUITests für UI-Änderungen\\n"
                        "\\n"
                        "Siehe: .agent-os/standards/global/implementation-gate.md\\n"
                        "\\n"
                        "Bestätige, dass das Gate durchlaufen wurde."
                    )
                }
            }
            print(json.dumps(output))
            sys.exit(0)

        # Andere Dateien erlauben
        sys.exit(0)

    except json.JSONDecodeError:
        print("ERROR: Invalid JSON input", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
