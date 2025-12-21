#!/usr/bin/env python3
"""
Wrapper - leitet an workflow_gate.py weiter.
Existiert nur für Rückwärtskompatibilität mit gecachten Sessions.
"""
import subprocess
import sys
from pathlib import Path

# stdin komplett lesen
stdin_data = sys.stdin.read()

# workflow_gate.py aufrufen
new_hook = Path(__file__).parent / "workflow_gate.py"
result = subprocess.run(
    ["python3", str(new_hook)],
    input=stdin_data,
    text=True,
    capture_output=True
)

# stderr ausgeben (Fehlermeldungen)
if result.stderr:
    print(result.stderr, file=sys.stderr)

# stdout ausgeben falls vorhanden
if result.stdout:
    print(result.stdout)

sys.exit(result.returncode)
