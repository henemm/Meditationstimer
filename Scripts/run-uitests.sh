#!/bin/bash
#
# run-uitests.sh - XCUITest Runner mit automatischer Simulator-Vorbereitung
#
# VERWENDUNG:
#   ./Scripts/run-uitests.sh                    # Alle UI Tests
#   ./Scripts/run-uitests.sh testName           # Einzelner Test
#
# Dieses Skript:
# 1. Bereitet den Simulator vor (PFLICHT!)
# 2. Führt Tests mit Retry-Logik aus
# 3. Bei Exit Code 64: Löscht DerivedData und versucht erneut
# 4. Zeigt Ergebnis an
#

# Simulator per Name + OS statt fester UDID — UDIDs ändern sich mit jedem
# Runtime-Update (siehe #19). Die UDID wird zur Laufzeit aufgelöst, weil
# simctl boot/bootstatus/erase eine UDID brauchen.
SIMULATOR_NAME="iPhone 17 Pro"
SIMULATOR_OS="26.5"
SIMULATOR_ID=$(xcrun simctl list devices available "iOS $SIMULATOR_OS" \
    | grep "^    $SIMULATOR_NAME (" \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1)
if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ Kein verfügbarer Simulator '$SIMULATOR_NAME' mit iOS $SIMULATOR_OS gefunden."
    echo "   Verfügbare Geräte: xcrun simctl list devices available"
    exit 1
fi
PROJECT="Meditationstimer.xcodeproj"
SCHEME="Lean Health Timer"
UITEST_TARGET="LeanHealthTimerUITests"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# ============================================
# FUNKTIONEN
# ============================================

prepare_simulator() {
    echo "📱 Simulator vorbereiten..."
    echo ""

    # Alle Simulatoren stoppen
    echo "   → Stoppe alle Simulatoren..."
    xcrun simctl shutdown all 2>/dev/null || true

    # CoreSimulator Service neustarten (behebt 90% der Launch-Fehler)
    echo "   → Starte CoreSimulator Service neu..."
    launchctl kickstart -k system/com.apple.coresimulatorservice 2>/dev/null || true
    sleep 3

    # Ziel-Simulator booten
    echo "   → Boote Simulator $SIMULATOR_NAME (iOS $SIMULATOR_OS, $SIMULATOR_ID)..."
    xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true

    # WARTEN bis Simulator bereit ist
    echo "   → Warte auf Simulator..."
    xcrun simctl bootstatus "$SIMULATOR_ID" -b

    echo ""
    echo "✅ Simulator bereit!"
}

run_tests() {
    local test_filter="$1"

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "  🧪 Tests ausführen"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""

    # Tests mit Retry ausführen
    # -parallel-testing-enabled NO: Runner startet unter Xcode 27.0 sonst auf einem
    # Simulator-Klon nicht (Issue #23)
    xcodebuild test \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -retry-tests-on-failure \
      -test-iterations 3 \
      -parallel-testing-enabled NO \
      $test_filter \
      2>&1 | tee /tmp/xcuitest_output.log | grep -E "(Test Case|passed|failed|error:|TEST SUCCEEDED|TEST FAILED|Code=64)"

    return ${PIPESTATUS[0]}
}

clean_derived_data() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "  🗑️  EXIT CODE 64 ERKANNT - DerivedData wird gelöscht"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "   Dies ist die häufigste Lösung für 'Failed to launch xctrunner'."
    echo ""

    rm -rf "$DERIVED_DATA"
    echo "   ✅ DerivedData gelöscht ($DERIVED_DATA)"

    # Simulator auch zurücksetzen
    echo "   → Setze Simulator zurück..."
    xcrun simctl shutdown all 2>/dev/null || true
    xcrun simctl erase "$SIMULATOR_ID" 2>/dev/null || true
    echo "   ✅ Simulator zurückgesetzt"
    echo ""
}

# ============================================
# HAUPTPROGRAMM
# ============================================

echo "═══════════════════════════════════════════════════════════════════════"
echo "  🧪 XCUITest Runner - Automatische Vorbereitung + Auto-Repair"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""

# Test-Target bestimmen
if [ -n "$1" ]; then
    # Wenn der Parameter einen "/" enthält, wird er als "Klasse/Methode" interpretiert
    # z.B. "BackgroundMeditationUITests/test_foo" → -only-testing:LeanHealthTimerUITests/BackgroundMeditationUITests/test_foo
    # Andernfalls wird die Default-Klasse (LeanHealthTimerUITests) verwendet
    if [[ "$1" == *"/"* ]]; then
        TEST_FILTER="-only-testing:$UITEST_TARGET/$1"
    else
        TEST_FILTER="-only-testing:$UITEST_TARGET/$UITEST_TARGET/$1"
    fi
    echo "📋 Einzelner Test: $1"
else
    TEST_FILTER="-only-testing:$UITEST_TARGET"
    echo "📋 Alle UI Tests"
fi

# ============================================
# VERSUCH 1: Normal
# ============================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VERSUCH 1/2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

prepare_simulator
run_tests "$TEST_FILTER"
TEST_EXIT_CODE=$?

# Prüfe auf Exit Code 64 (Simulator Launch Failure)
if grep -q "Code=64" /tmp/xcuitest_output.log 2>/dev/null; then
    echo ""
    echo "⚠️  Exit Code 64 erkannt - Simulator konnte App nicht starten"

    # ============================================
    # VERSUCH 2: Nach DerivedData-Cleanup
    # ============================================
    clean_derived_data

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  VERSUCH 2/2 (nach DerivedData-Cleanup)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    prepare_simulator
    run_tests "$TEST_FILTER"
    TEST_EXIT_CODE=$?
fi

# ============================================
# ERGEBNIS
# ============================================
echo ""
echo "═══════════════════════════════════════════════════════════════════════"

if grep -q "TEST SUCCEEDED" /tmp/xcuitest_output.log; then
    echo "  ✅ ALLE TESTS BESTANDEN"
    echo "═══════════════════════════════════════════════════════════════════════"
    exit 0
else
    echo "  ❌ TESTS FEHLGESCHLAGEN"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Fehlgeschlagene Tests:"
    grep "failed" /tmp/xcuitest_output.log 2>/dev/null || echo "  (keine Details verfügbar)"
    echo ""

    # Hinweis bei Exit Code 64 nach beiden Versuchen
    if grep -q "Code=64" /tmp/xcuitest_output.log 2>/dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ⚠️  EXIT CODE 64 PERSISTIERT"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  Weitere Schritte zum Versuchen:"
        echo "  1. Xcode komplett beenden und neu starten"
        echo "  2. Mac neu starten"
        echo "  3. Simulator manuell löschen und neu erstellen:"
        echo "     xcrun simctl delete $SIMULATOR_ID"
        echo "     xcrun simctl create '$SIMULATOR_NAME' '$SIMULATOR_NAME' 'iOS $SIMULATOR_OS'"
        echo ""
    fi

    exit 1
fi
