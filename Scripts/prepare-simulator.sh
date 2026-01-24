#!/bin/bash
# prepare-simulator.sh
# Löst das wiederkehrende "Failed to launch xctrunner" Problem
# IMMER vor XCUITests ausführen!

set -e

SIMULATOR_ID="${1:-EEF5B0DE-6B96-47CE-AA57-2EE024371F00}"

echo "🔧 Bereite Simulator vor..."

# 1. Alle Simulatoren stoppen
echo "  → Stoppe alle Simulatoren..."
xcrun simctl shutdown all 2>/dev/null || true

# 2. CoreSimulator Service neu starten
echo "  → Starte CoreSimulator Service neu..."
killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
sleep 2

# 3. Ziel-Simulator booten
echo "  → Boote Simulator $SIMULATOR_ID..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
sleep 3

# 4. Warten bis Simulator bereit ist
echo "  → Warte auf Simulator..."
for i in {1..10}; do
    STATUS=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -o "(Booted)" || echo "")
    if [ "$STATUS" = "(Booted)" ]; then
        echo "✅ Simulator bereit!"
        exit 0
    fi
    sleep 1
done

echo "⚠️ Simulator möglicherweise nicht bereit - trotzdem fortfahren"
exit 0
