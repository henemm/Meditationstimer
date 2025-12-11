# Feature planen oder ändern

Starte den `feature-planner` Agenten aus `.agent-os/agents/feature-planner.md`.

**Anfrage:** $ARGUMENTS

---

## Modus erkennen

| Formulierung | Modus |
|--------------|-------|
| "Neues Feature...", "Füge hinzu...", "Implementiere..." | **NEU** |
| "Änderung an...", "Passe an...", "Erweitere...", "Modifiziere..." | **ÄNDERUNG** |

---

**Befolge den Workflow aus `.agent-os/workflows/feature-workflow.md`**

**Injizierte Standards:**
- `.agent-os/standards/global/analysis-first.md`
- `.agent-os/standards/global/scoping-limits.md`
- `.agent-os/standards/global/documentation-rules.md`
- `.agent-os/standards/swiftui/state-management.md`

**Anweisung:**

1. **Modus bestimmen:** NEU oder ÄNDERUNG?
2. Feature-Intent verstehen (WAS, WARUM, Kategorie)
3. **Bei ÄNDERUNG:** Aktuellen Zustand dokumentieren, Delta identifizieren
4. Bestehende Systeme pruefen (KRITISCH!)
5. Scoping (Max 4-5 Dateien, +/-250 LoC)
6. Dokumentiere in DOCS/ACTIVE-roadmap.md
7. **NEU:** Erstelle OpenSpec Proposal in `openspec/changes/[feature-name]/`
8. **ÄNDERUNG:** Aktualisiere bestehende Spec in `openspec/specs/`

**KEINE direkte Implementierung ohne Spec!**
