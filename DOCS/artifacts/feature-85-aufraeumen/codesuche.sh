#!/bin/bash
# RED-Beleg A2c-2 (#85): Codesuche laut Test Plan
cd "$1" || exit 1
SHA="$2"
F="Meditationstimer iOS/Tabs/WorkoutProgramsView.swift"
echo "# RED-Beleg A2c-2 (#85) — $(date -u +%Y-%m-%dT%H:%M:%SZ) — Commit $SHA"
echo "# Test Plan A2c-2: keine neuen Tests (reine Löschung + Doku); RED = Codesuche"
echo
echo "## Prüfung 1: exerciseSuggestions in allen Swift-Dateien (Soll nach A2c-2: 0)"
grep -rn --include='*.swift' --exclude-dir=.claude --exclude-dir=.build "exerciseSuggestions" .
N1=$(grep -rn --include='*.swift' --exclude-dir=.claude --exclude-dir=.build "exerciseSuggestions" . | wc -l | tr -d ' ')
echo "TREFFER exerciseSuggestions: $N1 -> $( [ "$N1" -gt 0 ] && echo FAILED || echo ok) (Soll 0)"
echo
echo "## Prüfung 2: legacyDefault (Soll 0, schon durch #101 erfüllt)"
N2=$(grep -rn --include='*.swift' --exclude-dir=.claude --exclude-dir=.build "legacyDefault" . | wc -l | tr -d ' ')
echo "TREFFER legacyDefault: $N2 -> $( [ "$N2" -gt 0 ] && echo FAILED || echo ok) (Soll 0)"
echo
echo "## Prüfung 3: MARK 'Main View (Placeholder for Phase 1)' -> 'Namespace'"
grep -n "MARK: - " "$F" | grep -i "Placeholder\|Namespace\|Suggestions"
N3=$(grep -c "Placeholder for Phase 1" "$F")
echo "TREFFER Placeholder-MARK: $N3 -> $( [ "$N3" -gt 0 ] && echo FAILED || echo ok) (Soll 0)"
echo
echo "## Prüfung 4: workouts.md-Szenarien (AC-26, Doku-Stand der Spec-Phase)"
for s in "Exercise Hint Line" "Exercise Hint TTS" "Exercise Catalog Identifiers"; do
  echo "$s: $(grep -c "$s" openspec/specs/features/workouts.md)"
done
echo
echo "ERGEBNIS: RED — exerciseSuggestions $N1 Treffer, Placeholder-MARK $N3 Treffer"
