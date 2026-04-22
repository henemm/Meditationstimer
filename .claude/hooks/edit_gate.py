#!/usr/bin/env python3
"""
Edit Gate v3 — Consolidated PreToolUse Hook for Edit|Write
Adapted for Meditationstimer from my-daily-sprints.

Sequential short-circuit logic:
1. Protected State Files → BLOCK
1b. Archived Backlog Files → BLOCK
2. Always-Allowed (docs, tests, scripts, .md, .json) → ALLOW
3. Not code file → ALLOW
4. Infrastructure (.claude/hooks/) → Override token check
5. Stop-Lock → BLOCK
6. Find workflow for file (affected_files)
7. No workflow → BLOCK
8. Phase < phase5_implement → BLOCK
9. Override token → ALLOW (skip TDD check)
10. RED test artifacts → BLOCK if missing
11. ALLOW

Exit Codes: 0 = allowed, 2 = blocked
"""

import fcntl
import json
import os
import re
import sys
from pathlib import Path

_STDIN_SESSION_ID = ""

# --- Configuration ---

CODE_EXTENSIONS = {
    ".swift", ".kt", ".java", ".py", ".js", ".ts", ".tsx", ".jsx",
    ".go", ".rs", ".cpp", ".c", ".h", ".hpp",
}

ALWAYS_ALLOWED_DIRS = [
    "docs/", ".claude/commands/", "Scripts/", "tools/",
    "openspec/", ".agent-os/",
]

ALWAYS_ALLOWED_PATTERNS = [
    r"\.md$", r"\.txt$", r"\.json$", r"\.yaml$", r"\.yml$",
    r"\.gitignore$", r"README", r"CHANGELOG", r"LICENSE",
    r"\.xcstrings$",
]

PROTECTED_STATE_FILES = [
    ".claude/workflows/", "workflow_state.json", "user_override_token.json",
]

INFRASTRUCTURE_DIRS = [".claude/hooks/", ".claude/agents/"]

IMPL_PHASES = {
    "phase5_implement", "phase6_adversary", "phase7_done",
}

TEST_DIRS = [
    "Tests/", "LeanHealthTimerTests/", "LeanHealthTimerUITests/",
]

SOURCE_DIRS = [
    "Services/", "Meditationstimer iOS/", "Meditationstimer Watch/",
    "Meditationstimer Widget/",
]

# Phase4: nur Test-Dateien editierbar (TDD RED)
TEST_ONLY_PHASES = {"phase4_tdd_red"}

# Phase5: nur Source-Dateien editierbar (Tests dürfen NICHT angepasst werden!)
SOURCE_ONLY_PHASES = {"phase5_implement"}


# --- Helpers ---

def _project_root() -> Path:
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _read_workflow_locked(path: Path) -> dict | None:
    try:
        fd = os.open(str(path), os.O_RDONLY)
        try:
            fcntl.flock(fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
            content = path.read_text()
            return json.loads(content) if content.strip() else None
        except BlockingIOError:
            return json.loads(path.read_text())
        finally:
            try:
                fcntl.flock(fd, fcntl.LOCK_UN)
            except OSError:
                pass
            os.close(fd)
    except (OSError, json.JSONDecodeError):
        return None


def _read_active_workflow() -> dict | None:
    wf_dir = _project_root() / ".claude" / "workflows"
    session_id = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID
    if session_id:
        sessions_file = wf_dir / ".sessions.json"
        if sessions_file.exists():
            try:
                sessions = json.loads(sessions_file.read_text())
                wf_name = sessions.get(session_id)
                if wf_name:
                    wf_path = wf_dir / f"{wf_name}.json"
                    if wf_path.exists():
                        return _read_workflow_locked(wf_path)
            except (OSError, json.JSONDecodeError):
                pass
    link = wf_dir / ".active"
    if not link.exists():
        return None
    try:
        target = Path(os.readlink(str(link)))
        if not target.is_absolute():
            target = link.parent / target
        if target.exists():
            return _read_workflow_locked(target)
    except (OSError, json.JSONDecodeError):
        pass
    return None


def _find_workflow_for_file(file_path: str) -> dict | None:
    wf_dir = _project_root() / ".claude" / "workflows"
    if not wf_dir.exists():
        return None
    root = str(_project_root())
    rel = file_path
    if rel.startswith(root):
        rel = rel[len(root):].lstrip("/")
    for f in wf_dir.glob("*.json"):
        if f.name == ".sessions.json":
            continue
        data = _read_workflow_locked(f)
        if data is None:
            continue
        phase = data.get("current_phase", "phase0_idle")
        if phase in ("phase7_done", "phase0_idle"):
            continue
        for af in data.get("affected_files", []):
            if rel == af or rel.endswith("/" + af) or af.endswith("/" + rel):
                return data
    return None


def _has_override_token(workflow_name: str = None) -> bool:
    if not workflow_name:
        return False
    token_file = _project_root() / ".claude" / "user_override_token.json"
    if not token_file.exists():
        return False
    try:
        data = json.loads(token_file.read_text())
        tokens = data.get("tokens", {}) if data.get("version") == 2 else {}
        return workflow_name in tokens or "__global__" in tokens
    except (json.JSONDecodeError, OSError):
        return False


def _is_stop_locked() -> bool:
    lock = _project_root() / ".claude" / "stop_lock.json"
    if not lock.exists():
        return False
    try:
        data = json.loads(lock.read_text())
        if data.get("version") == 2:
            sessions = data.get("sessions", {})
            if not sessions:
                return False
            sid = os.environ.get("CLAUDE_SESSION_ID", "")
            return sid in sessions or "__global__" in sessions
        return data.get("enabled", False)
    except (json.JSONDecodeError, OSError):
        return False


def _is_test_file(file_path: str) -> bool:
    return any(d in file_path for d in TEST_DIRS)


def _is_source_file(file_path: str) -> bool:
    return any(d in file_path for d in SOURCE_DIRS)


# --- Main ---

def main():
    global _STDIN_SESSION_ID
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
            _STDIN_SESSION_ID = data.get("session_id", "")
        except (json.JSONDecodeError, Exception):
            sys.exit(0)
    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
        file_path = data.get("file_path", "")
    except json.JSONDecodeError:
        sys.exit(0)

    if not file_path:
        sys.exit(0)

    # 1. Protected state files
    for pf in PROTECTED_STATE_FILES:
        if pf in file_path:
            print(f"BLOCKED: Protected state file: {pf}", file=sys.stderr)
            sys.exit(2)

    # 1b. Backlog-Dateien → GitHub Issues
    fname = Path(file_path).name.lower()
    if fname in ("active-todos.md", "archive-todos.md"):
        print("BLOCKED: Backlog-Dateien sind archiviert. Nutze GitHub Issues.", file=sys.stderr)
        sys.exit(2)

    # 2. Always-allowed directories
    for d in ALWAYS_ALLOWED_DIRS:
        if d in file_path:
            sys.exit(0)

    # 2b. Always-allowed patterns
    for p in ALWAYS_ALLOWED_PATTERNS:
        if re.search(p, file_path, re.IGNORECASE):
            sys.exit(0)

    # 3. Not a code file
    ext = Path(file_path).suffix.lower()
    if ext not in CODE_EXTENSIONS:
        sys.exit(0)

    # 4. Infrastructure file
    for infra in INFRASTRUCTURE_DIRS:
        if infra in file_path:
            if _has_override_token("__infra__") or _has_override_token("__global__"):
                sys.exit(0)
            print("BLOCKED: Infrastructure file — needs override token.", file=sys.stderr)
            sys.exit(2)

    # 5. Stop-lock
    if _is_stop_locked():
        print("BLOCKED: Stop-lock active.", file=sys.stderr)
        sys.exit(2)

    # 6. Find workflow for file
    workflow = _find_workflow_for_file(file_path)
    if not workflow:
        active = _read_active_workflow()
        if active and not active.get("affected_files"):
            workflow = active

    # 7. No workflow
    if not workflow:
        print(f"BLOCKED: No active workflow for {file_path}. Start with /10-bug or /11-feature.", file=sys.stderr)
        sys.exit(2)

    phase = workflow.get("current_phase", "phase0_idle")
    wf_name = workflow.get("name", "unknown")

    # 8. Phase-spezifische Edit-Einschränkungen
    is_test = _is_test_file(file_path)

    if phase in TEST_ONLY_PHASES:
        if is_test:
            if any(d in file_path for d in ["LeanHealthTimerUITests/"]):
                if not workflow.get("inspect_ui_done"):
                    print("BLOCKED: inspect-ui ist PFLICHT vor UI-Test-Writes.", file=sys.stderr)
                    sys.exit(2)
            sys.exit(0)
        if not _has_override_token(wf_name):
            print(f"BLOCKED: Phase {phase} erlaubt nur Test-Dateien.", file=sys.stderr)
            sys.exit(2)

    elif phase in SOURCE_ONLY_PHASES:
        if is_test and not _has_override_token(wf_name):
            print(f"BLOCKED: Phase {phase} erlaubt keine Test-Änderungen. "
                  f"Tests dürfen nicht an Implementation angepasst werden!", file=sys.stderr)
            sys.exit(2)

    elif phase not in IMPL_PHASES:
        if not _has_override_token(wf_name):
            print(f"BLOCKED: Phase {phase} erlaubt keine Code-Edits.", file=sys.stderr)
            sys.exit(2)

    # 9. Scope-Guard: max 5 Code-Dateien
    if phase in IMPL_PHASES:
        affected = workflow.get("affected_files", [])
        code_affected = [f for f in affected if any(f.endswith(e) for e in CODE_EXTENSIONS)]
        if len(code_affected) > 5:
            print(f"BLOCKED: Scope-Limit überschritten — {len(code_affected)} Code-Dateien (max 5).",
                  file=sys.stderr)
            sys.exit(2)

    # 10. Override token skips TDD check
    if _has_override_token(wf_name):
        sys.exit(0)

    # 11. RED test artifacts
    if phase in IMPL_PHASES:
        red_done = workflow.get("red_test_done", False) or workflow.get("ui_test_red_done", False)
        if not red_done:
            red_arts = [a for a in workflow.get("test_artifacts", [])
                       if a.get("phase") == "phase4_tdd_red"]
            if not red_arts:
                print("BLOCKED: No RED test artifacts. Run /04-tdd-red first.", file=sys.stderr)
                sys.exit(2)

    # 12. Allow
    sys.exit(0)


if __name__ == "__main__":
    main()
