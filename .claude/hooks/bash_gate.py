#!/usr/bin/env python3
"""
Bash Gate v3 — Consolidated PreToolUse Hook for Bash
Adapted for Meditationstimer from my-daily-sprints.

Sequential logic:
1. Stop-Lock → BLOCK
2. State-Integrity: protected file + write indicator → BLOCK
3. Secrets: sensitive file + content output → BLOCK
4. Sim-Enforcer: direct xcodebuild/xcrun → BLOCK (use Scripts/)
5. Build-Lock: xcodebuild → acquire/wait
6. Git Commit gates (issue link, checkpoint 3, adversary, localize)
7. ALLOW

Exit Codes: 0 = allowed, 2 = blocked
"""

import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

_STDIN_SESSION_ID = ""

# --- Configuration ---

SENSITIVE_PATTERNS = [
    r"\.env", r"credentials\.json", r"service[_-]?account.*\.json",
    r"_key", r"_secret", r"\.pem$", r"\.key$",
]

ALWAYS_BLOCKED_SECRETS = [
    r"credentials\.json", r"service[_-]?account.*\.json",
    r"_key", r"_secret", r"\.pem$", r"\.key$",
]

CONTENT_OUTPUT_COMMANDS = [
    r"\bcat\b", r"\bhead\b", r"\btail\b", r"\bless\b", r"\bmore\b",
    r"\bsed\b.*-n.*p", r"\bawk\b.*print",
]

PROTECTED_FILE_PATTERNS = [
    r"\.claude/workflows/[^\s]*\.json",
    r"workflow_state\.json",
    r"user_override_token\.json",
    r"\.claude/hooks/[^\s]*\.py",
    r"\.claude/settings\.json",
    r"project\.pbxproj",
]

WRITE_INDICATORS = [
    r"json\.dump", r"open\(", r"write\(", r"sed\s+-i", r"mv\s", r"cp\s",
    r"echo\s", r"printf\s", r"python3?\s+-c", r"tee\s", r"rm\s",
    r"touch\s", r"cat\s*<<", r"unlink", r"truncate",
]

WHITELIST_COMMANDS = [
    "workflow.py", "qa_gate.py",
    "git add", "git commit", "git diff", "git status", "git log", "git push",
]

ALLOWED_SCRIPTS = ["run-uitests.sh", "prepare-simulator.sh"]

READONLY_XCODEBUILD = {"-list", "-showBuildSettings", "-showdestinations", "-version"}

POLL_INTERVAL = 5
MAX_WAIT = 240


def _project_root() -> Path:
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_dir:
        return Path(env_dir)
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


def _build_lock_path() -> Path:
    return _project_root() / ".claude" / "build_lock.json"


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


def _get_command() -> str:
    global _STDIN_SESSION_ID
    tool_input = os.environ.get("CLAUDE_TOOL_INPUT", "")
    if not tool_input:
        try:
            data = json.load(sys.stdin)
            tool_input = json.dumps(data.get("tool_input", {}))
            _STDIN_SESSION_ID = data.get("session_id", "")
        except (json.JSONDecodeError, Exception):
            return ""
    try:
        data = json.loads(tool_input) if isinstance(tool_input, str) else tool_input
    except json.JSONDecodeError:
        return ""
    return data.get("command", "")


def _is_whitelisted(command: str) -> bool:
    return any(a in command for a in WHITELIST_COMMANDS)


def _references_protected(command: str) -> bool:
    return any(re.search(p, command) for p in PROTECTED_FILE_PATTERNS)


def _has_write_indicator(command: str) -> bool:
    if any(re.search(p, command) for p in WRITE_INDICATORS):
        return True
    for m in re.finditer(r"(?<!\d)>{1,2}\s*(\S+)", command):
        if m.group(1) != "/dev/null":
            return True
    return False


def _is_sensitive(path: str, patterns: list) -> bool:
    return any(re.search(p, path, re.IGNORECASE) for p in patterns)


def _outputs_content(command: str) -> bool:
    return any(re.search(p, command) for p in CONTENT_OUTPUT_COMMANDS)


def _uses_wrapper(command: str) -> bool:
    return any(s in command for s in ALLOWED_SCRIPTS)


def _get_session_id() -> str:
    sid = os.environ.get("CLAUDE_SESSION_ID", "") or _STDIN_SESSION_ID
    return f"session:{sid}" if sid else f"ppid:{os.getppid()}"


def _try_acquire_build_lock(command: str) -> bool:
    lock_path = _build_lock_path()
    my_id = _get_session_id()
    if lock_path.exists():
        try:
            lock = json.loads(lock_path.read_text())
            holder_id = lock.get("holder_id", "")
            if not holder_id and "ppid" in lock:
                holder_id = f"ppid:{lock['ppid']}"
            if holder_id == my_id:
                return True
            if holder_id.startswith("ppid:"):
                try:
                    os.kill(int(holder_id.split(":")[1]), 0)
                except (OSError, ProcessLookupError, ValueError):
                    lock_path.unlink(missing_ok=True)
                else:
                    return False
            elif holder_id.startswith("session:"):
                created = lock.get("created", "")
                if created:
                    try:
                        age = (datetime.now() - datetime.fromisoformat(created)).total_seconds()
                        if age > 600:
                            lock_path.unlink(missing_ok=True)
                        else:
                            return False
                    except (ValueError, TypeError):
                        return False
                else:
                    return False
            else:
                return False
        except (json.JSONDecodeError, OSError):
            lock_path.unlink(missing_ok=True)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path.write_text(json.dumps({
        "holder_id": my_id,
        "ppid": os.getppid(),
        "created": datetime.now().isoformat(),
        "command": command[:200],
    }))
    return True


def main():
    command = _get_command()
    if not command:
        sys.exit(0)

    # 1. Stop-lock
    if _is_stop_locked():
        print("BLOCKED: Stop-lock active.", file=sys.stderr)
        sys.exit(2)

    # Git commands always pass — EXCEPT git commit
    if command.lstrip().startswith("git ") and "git commit" not in command:
        sys.exit(0)

    # 2. State-integrity
    if _references_protected(command):
        if _is_whitelisted(command):
            sys.exit(0)
        if _has_write_indicator(command):
            print("BLOCKED: Direct state file manipulation. Use workflow.py CLI.", file=sys.stderr)
            sys.exit(2)

    # 3. Secrets guard
    if _is_sensitive(command, SENSITIVE_PATTERNS) and _outputs_content(command):
        if _is_sensitive(command, ALWAYS_BLOCKED_SECRETS):
            print("BLOCKED: Secrets guard — sensitive credentials/keys.", file=sys.stderr)
            sys.exit(2)

    # 4. Sim-enforcer: direct xcodebuild/xcrun without wrapper
    has_xcodebuild = "xcodebuild" in command
    has_simctl = "xcrun simctl" in command
    if has_simctl or has_xcodebuild:
        if _uses_wrapper(command):
            pass
        elif has_xcodebuild:
            if any(f in command for f in READONLY_XCODEBUILD):
                pass
            else:
                print("BLOCKED: Direct xcodebuild. Use ./Scripts/run-uitests.sh instead.", file=sys.stderr)
                sys.exit(2)

    # 5. Build-lock for xcodebuild
    if has_xcodebuild and not command.lstrip().startswith("git "):
        if not _try_acquire_build_lock(command):
            waited = 0
            while waited < MAX_WAIT:
                time.sleep(POLL_INTERVAL)
                waited += POLL_INTERVAL
                if _try_acquire_build_lock(command):
                    break
            else:
                print(f"BLOCKED: Build-lock timeout after {MAX_WAIT}s.", file=sys.stderr)
                sys.exit(2)

    # 6. Git commit gates
    if "git commit" in command and "--amend" not in command:
        is_fix_or_feat = bool(re.search(r'(?:^|[\n"\'])(?:fix|feat)[:(]', command, re.MULTILINE))
        has_issue_ref = bool(re.search(r'#\d+', command))
        if is_fix_or_feat and not has_issue_ref:
            print("BLOCKED: fix:/feat: commits must reference a GitHub Issue (#N).", file=sys.stderr)
            sys.exit(2)

        if is_fix_or_feat:
            wf_dir = _project_root() / ".claude" / "workflows"
            active_wf = None
            session_id = os.environ.get("CLAUDE_SESSION_ID", "")
            if session_id:
                sessions_file = wf_dir / ".sessions.json"
                if sessions_file.exists():
                    try:
                        sessions = json.loads(sessions_file.read_text())
                        wf_name = sessions.get(session_id)
                        if wf_name:
                            wf_path = wf_dir / f"{wf_name}.json"
                            if wf_path.exists():
                                active_wf = json.loads(wf_path.read_text())
                    except (json.JSONDecodeError, OSError):
                        pass
            if not active_wf:
                link = wf_dir / ".active"
                if link.is_symlink():
                    try:
                        target = Path(os.readlink(str(link)))
                        if not target.is_absolute():
                            target = link.parent / target
                        if target.exists():
                            active_wf = json.loads(target.read_text())
                    except (json.JSONDecodeError, OSError):
                        pass
            if active_wf:
                if not active_wf.get("checkpoint3_approved"):
                    print("BLOCKED: Kein Commit ohne Checkpoint 3! "
                          "Henning muss 'commit' sagen.", file=sys.stderr)
                    sys.exit(2)
                findings = active_wf.get("adversary_findings", [])
                unresolved = [f for f in findings if f.get("status") is None]
                if unresolved:
                    print(f"BLOCKED: {len(unresolved)} Adversary-Finding(s) noch offen.",
                          file=sys.stderr)
                    sys.exit(2)
                loc_checked = active_wf.get("localize_checked", False)
                no_strings = active_wf.get("no_user_strings", False)
                if not loc_checked and not no_strings:
                    print("BLOCKED: Lokalisierung nicht geprüft. "
                          "workflow.py mark-localize oder set-field no_user_strings true",
                          file=sys.stderr)
                    sys.exit(2)

    # 7. Allow
    sys.exit(0)


if __name__ == "__main__":
    main()
