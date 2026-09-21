#!/usr/bin/env bash
# Prüfskript für Scripts/apac-export.swift, siehe docs/specs/features/FEAT-apac-export.md
# set -u statt set -e: jeder Einzeltest wird gezählt, nicht beim ersten Fehler abgebrochen.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/apac-export.swift"
FIXTURE="$SCRIPT_DIR/Fixtures/spatial-sample.qta"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
PASS=0; FAIL=0

# Meldet einen Einzeltest im Format "PASS:/FAIL: Test <Nr> - <Beschreibung>".
report() {
    if [ "$1" -eq 0 ]; then echo "PASS: Test $2 - $3"; PASS=$((PASS + 1))
    else echo "FAIL: Test $2 - $3 (${4:-})"; FAIL=$((FAIL + 1)); fi
}

# Werkzeug fehlt noch (TDD RED) -> alle Werkzeug-Tests kontrolliert als FAIL melden,
# statt mit kryptischem "No such file"-Shellfehler abzubrechen.
if [ ! -f "$TOOL" ]; then
    echo "HINWEIS: $TOOL existiert noch nicht - TDD RED-Zustand, Implementation steht aus."
    for nr_desc in "1:Sondiermodus listet zwei Spuren, eine davon apac/4ch" \
                   "2:Abbruch bei fehlender APAC-Spur, stderr enthaelt APAC" \
                   "3:Abbruch bei falschem Layout-Override" \
                   "4:Ausgabegroesse entspricht Dauer x Rate x 4 x 4 Byte"; do
        report 1 "${nr_desc%%:*}" "${nr_desc#*:}" "Werkzeug fehlt"
    done
    echo ""; echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"; exit 1
fi
[ -f "$FIXTURE" ] || { echo "FEHLER: Fixture $FIXTURE fehlt."; exit 1; }

# Verbindliches --probe-Ausgabeformat (Vorgabe fuer die Implementierung): eine Zeile pro
# Tonspur, Leerzeichen-getrennte Felder ohne eingebettete Leerzeichen in den Werten:
#   track=<n> format=<fourcc> channels=<n> layout=<tag-oder-none>
# Beispiel: "track=2 format=apac channels=4 layout=190_4"
#
# Test 1: --probe listet genau zwei Spuren; die apac-Spur traegt channels=4 als eigenes
# Feld (nicht als Teilstring, sonst wuerde z.B. "48000 Hz" faelschlich als "4" durchgehen).
OUT="$("$TOOL" --probe "$FIXTURE" 2>"$TMPDIR/1.err")"; RC=$?
LINES=$(printf '%s\n' "$OUT" | grep -c .)
APAC_LINE=$(printf '%s\n' "$OUT" | grep -E '(^| )format=apac( |$)')
APAC_LINE_COUNT=$(printf '%s\n' "$APAC_LINE" | grep -c .)
if [ "$RC" -eq 0 ] && [ "$LINES" -eq 2 ] && [ "$APAC_LINE_COUNT" -eq 1 ] \
    && printf '%s\n' "$APAC_LINE" | grep -qE '(^| )channels=4( |$)'; then
    report 0 1 "Sondiermodus listet zwei Spuren, eine davon apac/4ch"
else
    report 1 1 "Sondiermodus listet zwei Spuren, eine davon apac/4ch" "rc=$RC lines=$LINES apac_line='$APAC_LINE'"
fi

# Test 2: Datei ohne APAC-Spur (nur Stereo, per ffmpeg erzeugt) wird abgelehnt.
ffmpeg -v error -y -i "$FIXTURE" -map 0:0 -c:a copy "$TMPDIR/stereo.mov" 2>"$TMPDIR/ffmpeg.err"
"$TOOL" "$TMPDIR/stereo.mov" "$TMPDIR/no-apac.pcm" 2>"$TMPDIR/2.err"; RC=$?
if [ "$RC" -ne 0 ] && grep -q "APAC" "$TMPDIR/2.err" && [ ! -f "$TMPDIR/no-apac.pcm" ]; then
    report 0 2 "Abbruch bei fehlender APAC-Spur, stderr enthaelt APAC"
else
    report 1 2 "Abbruch bei fehlender APAC-Spur, stderr enthaelt APAC" "rc=$RC"
fi

# Test 3: Falscher Layout-Override (Test-Hook) bricht ab - UND nur deswegen. Ein Werkzeug,
# das grundsaetzlich immer fehlschlaegt (unabhaengig vom Override), soll hier nicht
# faelschlich bestehen: dazu wird zusaetzlich ein Basislauf ohne Override verlangt, der
# gelingen muss, waehrend derselbe Aufruf mit falschem Override scheitern muss.
"$TOOL" "$FIXTURE" "$TMPDIR/layout-baseline.pcm" 2>"$TMPDIR/3-baseline.err"; BASELINE_RC=$?
APAC_EXPORT_EXPECT_LAYOUT_TAG="0" "$TOOL" "$FIXTURE" "$TMPDIR/layout.pcm" 2>"$TMPDIR/3.err"; RC=$?
if [ "$BASELINE_RC" -eq 0 ] && [ "$RC" -ne 0 ]; then
    report 0 3 "Abbruch bei falschem Layout-Override"
else
    report 1 3 "Abbruch bei falschem Layout-Override" "baseline_rc=$BASELINE_RC override_rc=$RC"
fi

# Test 4: Ausgabegroesse = Dauer x tatsaechliche Abtastrate x 4 Kanaele x 4 Byte, +/-32768 Byte.
BLOCK="$(afinfo "$FIXTURE" | awk 'BEGIN{RS="----\n"} /apac/{print}')"
RATE=$(printf '%s\n' "$BLOCK" | grep -oE '[0-9]+ Hz' | grep -oE '[0-9]+')
DURATION=$(printf '%s\n' "$BLOCK" | grep "estimated duration:" | grep -oE '[0-9]+\.[0-9]+')
EXPECTED=$(awk -v d="$DURATION" -v r="$RATE" 'BEGIN{printf "%.0f", d*r*4*4}')
"$TOOL" "$FIXTURE" "$TMPDIR/decoded.pcm" 2>"$TMPDIR/4.err"; RC=$?
if [ "$RC" -eq 0 ] && [ -f "$TMPDIR/decoded.pcm" ]; then
    ACTUAL=$(stat -f%z "$TMPDIR/decoded.pcm")
    DIFF=$(( ACTUAL > EXPECTED ? ACTUAL - EXPECTED : EXPECTED - ACTUAL ))
    if [ "$DIFF" -le 32768 ]; then report 0 4 "Ausgabegroesse entspricht Dauer x Rate x 4 x 4 Byte"
    else report 1 4 "Ausgabegroesse entspricht Dauer x Rate x 4 x 4 Byte" "erwartet=$EXPECTED tatsaechlich=$ACTUAL"; fi
else
    report 1 4 "Ausgabegroesse entspricht Dauer x Rate x 4 x 4 Byte" "rc=$RC"
fi

# Test 5: Skript-Rueckgabewert selbst - 0 nur wenn alle Einzelpruefungen bestanden haben.
echo ""; echo "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
[ "$FAIL" -eq 0 ]
