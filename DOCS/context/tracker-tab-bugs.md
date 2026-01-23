# Context: Tracker Tab Bugs

## Request Summary
Zwei UI-Bugs im TrackerTab: (1) vertikales Wabbeln beim horizontalen Scrollen der Level-Buttons, (2) generische Tracker-Darstellung (Icons zu klein, fehlende Datums-Auswahl für rückwirkende Einträge).

## Related Files

| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | Hauptview mit NoAlc-Card und vertikalem ScrollView |
| `Meditationstimer iOS/Tracker/TrackerRow.swift` | Generische Tracker-Zeile mit Level-Buttons (Bug 2a: Icons zu klein) |
| `Meditationstimer iOS/NoAlcLogSheet.swift` | Hat "Advanced" Modus mit DatePicker - Vorlage für Bug 2b |
| `Meditationstimer iOS/UI/GlassCard.swift` | Container-Komponente |
| `Meditationstimer iOS/ContentView.swift` | Tab-Container mit TrackerTab |
| `Services/TrackerModels.swift` | TrackerLevel Definition mit icon/label |
| `Services/TrackerManager.swift` | Logging-Funktionen für Tracker |

## Bugs im Detail

### Bug 1: Horizontales Scroll-Wabbeln
**Problem:** Die gesamte ScrollView wabbelt leicht vertikal (nach rechts/links), wenn man horizontal durch die Level-Buttons scrollt.

**Analyse:**
- `TrackerTab.swift:76-86` verwendet `ScrollView` ohne explizite Achsen-Einschränkung
- Die Level-Buttons in `noAlcCard` (Line 254-258) und `TrackerRow` (Line 237-241) sind in `HStack` angeordnet
- `HStack(spacing: 6)` ohne `ScrollViewReader` - könnte ungewolltes Scroll-Verhalten verursachen
- Der `.ultraThinMaterial` Background der GlassCard könnte bei Touch-Events mitscrollen

**Mögliche Ursachen:**
1. ScrollView ist bidirektional (default), sollte `.scrollBounceBehavior(.basedOnSize)` oder nur `.vertical` sein
2. Kein `.scrollTargetBehavior` definiert
3. Die Level-Buttons selbst haben kein `.contentShape(Rectangle())` für präzise Hit-Tests

### Bug 2a: Level-Icons zu klein
**Problem:** Die Icons in `TrackerRow` sind viel kleiner als im proprietären NoAlc-Card.

**Vergleich:**
- **NoAlc-Card** (`TrackerTab.swift:158-159`): `Text(level.icon).font(.system(size: 32))` mit `.frame(maxWidth: .infinity)` und `.padding(.vertical, 12)`
- **TrackerRow** (`TrackerRow.swift:249-254`): `Text(level.icon).font(.system(size: levelIconSize))` wo `levelIconSize = 28` (oder 24 bei >3 Levels)

**Unterschied:**
- NoAlc-Card hat die Buttons in einer **separaten Zeile** unter dem Header
- TrackerRow zeigt alles in **einer HStack-Zeile** (Icon + Name + Status + Level-Buttons + Edit)

**Lösung:** TrackerRow sollte das NoAlc-Card-Layout übernehmen: Level-Buttons in eigener Zeile, größere Icons.

### Bug 2b: Fehlende Datums-Auswahl
**Problem:** Bei generischen Trackern fehlt die Möglichkeit, für ein anderes Datum zu loggen (z.B. gestern nachholen).

**Vergleich:**
- **NoAlcLogSheet.swift** hat "Advanced" Button (Line 67-76) der DatePicker öffnet
- **TrackerRow** hat keine solche Funktion

**Lösung:** Dediziertes Icon (z.B. `calendar.badge.plus`) das ein Sheet mit DatePicker öffnet. Dieses Feature war Teil der Spec (`generic-tracker-system-implementation.md`).

## Existing Patterns

### DatePicker Pattern (NoAlcLogSheet)
```swift
// Compact mode with Advanced button
Button {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        isExpanded = true
    }
} label: {
    Text("Advanced")
        .font(.footnote)
        .foregroundColor(.secondary)
}

// Extended mode with DatePicker
DatePicker(
    "Date",
    selection: $selectedDate,
    displayedComponents: .date
)
.datePickerStyle(.graphical)
```

### Level Button Layout (NoAlc-Card - Best Practice)
```swift
VStack(spacing: 12) {
    // Header row
    HStack {
        Text("🍷").font(.system(size: 28))
        Text("NoAlc").font(.headline)
        // ... streak, buttons
    }

    // Level buttons in SEPARATE row
    HStack(spacing: 10) {
        ForEach(levels) { level in
            Button(...)
        }
    }
}
```

## Dependencies

### Upstream
- `TrackerLevel` (TrackerModels.swift) - defines icons, keys, labels
- `TrackerManager.logEntry()` - saves log to SwiftData
- `GlassCard` - visual container

### Downstream
- TrackerRow is used by TrackerTab for ALL custom trackers
- Any fix here affects all level-based trackers (not just NoAlc)

## Existing Specs

- `DOCS/specs/features/generic-tracker-system-implementation.md` - Phase 2.1 mentions removing hardcoded NoAlc, but TrackerRow layout issues were overlooked
- `openspec/specs/features/generic-tracker-system.md` - Original design spec

## Risks & Considerations

1. **Layout-Änderungen**: TrackerRow wird für ALLE Tracker verwendet - Änderungen müssen für Counter, YesNo, Awareness, Avoidance UND Levels funktionieren
2. **Scroll-Verhalten**: Änderungen am ScrollView können iOS-Version-abhängig sein
3. **DatePicker UX**: Muss klar verständlich sein (Icon-Wahl wichtig)
4. **Performance**: Mehr UI-Elemente in jeder Row = mehr Render-Aufwand

## Analysis

### Affected Files (with changes)

| File | Change Type | LoC Estimate | Description |
|------|-------------|--------------|-------------|
| `Meditationstimer iOS/Tabs/TrackerTab.swift` | MODIFY | ~+3 | ScrollView auf `.vertical` setzen |
| `Meditationstimer iOS/Tracker/TrackerRow.swift` | MODIFY | ~+40 | Level-Buttons in separate Zeile, DatePicker-Button |

### Scope Assessment
- **Files:** 2
- **Estimated LoC:** +43/-10 (~33 net)
- **Risk Level:** LOW (lokale UI-Änderungen)

### Technical Approach

#### Bug 1: Scroll-Wabbeln beheben
**Root Cause:** `ScrollView` in TrackerTab.swift (Zeile 76) hat keine explizite Achsen-Einschränkung. Default ist `.axes: .vertical` aber ohne `.horizontal` Sperre kann minimale horizontale Bewegung auftreten.

**Fix:**
```swift
// TrackerTab.swift:76
ScrollView(.vertical, showsIndicators: false) {
```

Zusätzlich `.scrollBounceBehavior(.basedOnSize)` um übermäßiges Bounce-Verhalten zu verhindern.

#### Bug 2a: Level-Icons vergrößern
**Root Cause:** TrackerRow packt ALLES in eine HStack (Icon, Name, Status, Level-Buttons, Edit-Button). Das zwingt die Level-Buttons in einen schmalen Bereich.

**Vergleich NoAlc-Card vs TrackerRow:**
| Aspekt | NoAlc-Card | TrackerRow |
|--------|-----------|------------|
| Layout | VStack mit Header + Buttons-Zeile | Alles in einer HStack |
| Icon-Größe | 32px | 24-28px |
| Button-Breite | `maxWidth: .infinity` | Geteilt mit anderen Elementen |
| Padding | `.padding(.vertical, 12)` | `.padding(.vertical, 10)` |

**Fix:** TrackerRow für `isLevelBased` Tracker umstrukturieren:
```swift
// STATT einer HStack:
VStack(spacing: 12) {
    // Zeile 1: Icon, Name, Streak, Edit, History-Button
    HStack { ... }

    // Zeile 2: Level-Buttons (volle Breite)
    HStack(spacing: 10) {
        ForEach(trackerLevels) { level in
            levelButton(level) // mit 32px Icon
        }
    }

    // Zeile 3: Today's status (optional)
    todayStatusView
}
```

#### Bug 2b: Datums-Auswahl hinzufügen
**Bestehende Lösung:** `LevelSelectionView` existiert bereits und hat:
- Compact Mode mit Quick-Log
- "Advanced" Button der DatePicker öffnet
- Extended Mode mit graphischem DatePicker

**Problem:** TrackerRow nutzt inline-Buttons statt Sheet.

**Fix:** "History/Date" Icon neben Edit-Button hinzufügen:
```swift
// Neben Edit-Button
Button(action: { showingLevelSheet = true }) {
    Image(systemName: "calendar.badge.plus")
        .font(.system(size: 18))
        .foregroundStyle(.secondary)
}
```

Dies öffnet `LevelSelectionView` das bereits Advanced-Modus mit DatePicker hat.

**Icon-Optionen:**
- `calendar.badge.plus` - Kalender mit Plus (klar: "Eintrag für Datum hinzufügen")
- `clock.arrow.circlepath` - Wie bei NoAlc History-Button
- `calendar` - Einfach Kalender

**Empfehlung:** `calendar.badge.plus` weil es am klarsten "Eintrag für anderes Datum" kommuniziert.

### Detaillierte Code-Änderungen

#### TrackerTab.swift
```diff
-            ScrollView {
+            ScrollView(.vertical, showsIndicators: false) {
                 VStack(spacing: 20) {
```

#### TrackerRow.swift - Strukturänderung für Level-Tracker
```diff
 var body: some View {
     GlassCard {
-        HStack(alignment: .center, spacing: 14) {
+        // Level-based trackers get 2-row layout like NoAlc card
+        if isLevelBased {
+            levelBasedLayout
+        } else {
+            legacyLayout  // HStack like before
+        }
+    }
+    ...
+ }
+
+ // NEW: Level-based layout (matches noAlcCard)
+ @ViewBuilder
+ private var levelBasedLayout: some View {
+     VStack(spacing: 12) {
+         // Row 1: Icon, Name, Streak, Buttons
+         HStack {
              Text(tracker.icon)
-                 .font(.system(size: 42))
-             VStack(alignment: .leading, spacing: 4) {
-                 HStack(spacing: 8) {
-                     Text(tracker.name)
-                         .font(.headline)
-                     streakBadge
-                 }
-                 todayStatusView
-             }
+                 .font(.system(size: 28))
+             Text(tracker.name)
+                 .font(.headline)
+             streakBadge
              Spacer()
-             quickLogButton
-             Button(action: onEdit) { ... }
+             // History button (opens LevelSelectionView for date picking)
+             Button(action: { showingLevelSheet = true }) {
+                 Image(systemName: "calendar.badge.plus")
+                     .font(.system(size: 18))
+                     .foregroundStyle(.secondary)
+             }
+             Button(action: onEdit) {
+                 Image(systemName: "ellipsis") ...
+             }
          }
-         .frame(minHeight: 80)
+
+         // Row 2: Level buttons (full width, 32px icons)
+         HStack(spacing: 10) {
+             ForEach(trackerLevels) { level in
+                 levelButtonLarge(level)  // 32px icons like noAlcCard
+             }
+         }
+
+         // Row 3: Today's status
+         todayStatusView
      }
+     .padding(.vertical, 4)
  }
```

### Open Questions

- [x] Icon für Datums-Auswahl: `calendar.badge.plus` (empfohlen)
- [x] LevelSelectionView existiert bereits mit DatePicker - kann wiederverwendet werden
- [ ] Soll die Today-Status-Anzeige unter den Buttons bleiben oder in die Header-Zeile?

### Empfehlung

**Today-Status unter Buttons lassen** (wie bei NoAlc-Card), weil:
1. Visuell konsistent mit NoAlc-Card Layout
2. Genug Platz in der eigenen Zeile
3. Nicht zu voll in der Header-Zeile
