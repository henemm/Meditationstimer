# 1-analyse-bug: Bug-Analyse starten

## ⚡ WORKFLOW STATE UPDATE (PFLICHT!)

**ZUERST** den Workflow-State setzen:
```bash
python3 .claude/hooks/update_state.py analysing --type bug --feature "$ARGUMENTS"
```

---

## Phase 1: ANALYSING (Bug)

Starte den `bug-investigator` Agenten aus `.agent-os/agents/bug-investigator.md`.

**Bug:** $ARGUMENTS

**Befolge den Workflow aus `.agent-os/workflows/bug-fix-workflow.md`**

**Injizierte Standards:**
- `.agent-os/standards/global/analysis-first.md`
- `.agent-os/standards/global/scoping-limits.md`
- `.agent-os/standards/swiftui/lifecycle-patterns.md`
- `.agent-os/standards/healthkit/date-semantics.md`

---

## Bug-Workflow Übersicht

```
/1-analyse-bug    ←── DU BIST HIER (Phase 1)
        ↓
   Root Cause finden
        ↓
   User: "Freigegeben"
        ↓
/3-implement      ←── Nächster Schritt (Phase 3)
        ↓
/4-validate       ←── Danach (Phase 4)
        ↓
/0-reset          ←── Abschluss
```

**Hinweis:** Bug-Workflow überspringt `/2-spec` (kein Spec nötig).

---

## Anweisung

1. **Analysiere** den Bug nach Analysis-First Prinzip
2. **Finde Root Cause** mit SICHERHEIT (kein Raten!)
3. **Dokumentiere** in DOCS/ACTIVE-todos.md
4. **Schlage Fix vor** und warte auf User-Freigabe
5. Nach Freigabe: User ruft `/3-implement` auf!

**⛔ KEIN Code-Edit ohne `/3-implement`!**
**⛔ KEIN Trial-and-Error!**

---

## Nächster Schritt

Nach User-Approval → `/3-implement`
