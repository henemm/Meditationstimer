# Feature planen

Starte den `feature-planner` Agenten aus `.agent-os/agents/feature-planner.md`.

**Feature:** $ARGUMENTS

---

**Befolge den Workflow aus `.agent-os/workflows/feature-workflow.md`**

**Injizierte Standards:**
- `.agent-os/standards/global/analysis-first.md`
- `.agent-os/standards/global/scoping-limits.md`
- `.agent-os/standards/global/documentation-rules.md`
- `.agent-os/standards/swiftui/state-management.md`

**Anweisung:**

1. Feature-Intent verstehen (WAS, WARUM, Kategorie)
2. Bestehende Systeme pruefen (KRITISCH!)
3. Scoping (Max 4-5 Dateien, +/-250 LoC)
4. Dokumentiere in DOCS/ACTIVE-roadmap.md
5. Erstelle OpenSpec Proposal in `openspec/changes/[feature-name]/`

**KEINE direkte Implementierung ohne Spec!**
