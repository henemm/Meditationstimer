# NoAlc Tracker – Feature Specification
**Projekt:** Lean Health Timer
**Autor:** Henning
**Version:** 1.1
**Datum:** 2025-10-30
**Letzte Änderung:** 2025-10-30 (Klarstellungen: TabView, Notification-Regel, HealthKit Type)

---

## 🧭 Overview
The **NoAlc Tracker** extends the existing Lean Health Timer ecosystem (Meditation / Workout / Breathing) by adding a fourth dimension: **alcohol consumption tracking**.
Data is stored in **Apple HealthKit** (`numberOfAlcoholicBeverages`) and visualized directly in the **calendar view** through color-coded inner fills.
Interaction happens primarily via **Smart Notifications** and a **dedicated Tab** in the app, so users rarely need manual logging.

---

## 🔹 Core Behavior

| Aspect | Description |
|--------|--------------|
| **Goal** | Encourage alcohol-free (or low-consumption) streaks using the same mechanism as Meditation / Workout / Breathing. |
| **Storage** | Native HealthKit Type: `HKQuantityTypeIdentifier.numberOfAlcoholicBeverages` (integers). |
| **Reminder Logic** | Daily Smart Notification (default 09:00) checks if target day has a recorded value. If not, prompts user to log. **Day Assignment Rule:** Notifications before 18:00 reference "yesterday", notifications at/after 18:00 reference "today". |
| **Quick Interaction** | User can log directly from the notification by choosing one of three buttons. |
| **Manual Entry** | 4th Tab in TabView (`drop.fill` icon) shows quick-log buttons and date picker. |

---

## 🔹 Data Model

| Field | Type | Description |
|--------|------|-------------|
| `date` | `Date` | Calendar day of the entry |
| `drinks` | `Int` | Encoded consumption value (0 = Steady, 4 = Easy, 6 = Wild) |
| `source` | `String` | `"notification"` or `"manual"` |
| `timestamp` | `Date` | When entry was logged |

**HealthKit Mapping**

| Level | Drink Range | HealthKit Value | Label | Emoji |
|--------|-------------|----------------|--------|--------|
| **Steady** | 0–1 drinks | `0` | No/minimal consumption | 💧 |
| **Easy** | 2–5 drinks | `4` | Moderate consumption | ✨ |
| **Wild** | 6+ drinks | `6` | High consumption | 💥 |

**Technical Details:**
- Native HealthKit Type: `HKQuantityTypeIdentifier.numberOfAlcoholicBeverages`
- Unit: `.count()` (integer values)
- Permission: Write access required (`HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)`)
- Values are **representative** (0, 4, 6) not actual drink counts - serves as category encoding

---

## 🔹 UI Specification

### A. Smart Notification
- **Trigger:** Daily at configured time (default 09:00) if no NoAlc entry for target day.
- **Day Assignment Rule:**
  - **Notification time < 18:00** → References "yesterday" (Rückblick-Modus)
  - **Notification time >= 18:00** → References "today" (Aktuell-Modus)
- **Title Examples:**
  - Before 18:00: `How was your evening yesterday?`
  - At/After 18:00: `How's your evening going?`
- **Body:** `Log your drinks to keep your streak going 💧`
- **Buttons (Actionable):**

| Label | Emoji | SF Symbol | HealthKit Value | Color |
|--------|-------|-----------|----------------|-------|
| **Steady** | 💧 | `drop.fill` | `0` | `#00C853` (strong green) |
| **Easy** | ✨ | `bubbles.and.sparkles` | `4` | `#A5D6A7` (medium green) |
| **Wild** | 💥 | `burst.fill` | `6` | `#E8F5E9` (light green) |

→ Tap = immediate write to HealthKit + confirmation toast.

---

### B. Manual Entry (4th Tab in TabView)
**Tab Icon:** `drop.fill`
**Tab Label:** "NoAlc" or "Clarity"

**Layout (compact mode):**
```
💧 Steady    ✨ Easy    💥 Wild
```
- Direct tap logs the value for target day (follows same time-based rule as notifications).
- Expanding via "📅 Other Date" reveals:
  - `DatePicker` (defaults to target day based on current time)
  - `Submit` button (required only in expanded mode)

**Color coding:** Identical to calendar and notification (ensures visual consistency).

**Integration:**
- Added as 4th tab in `ContentView.swift` TabView
- Positioned after "Workouts" tab
- Uses same `.environmentObject(streakManager)` pattern as other tabs

---

## 🔹 Calendar Integration

| Layer | Function |
|--------|-----------|
| Outer circles | Meditation / Workout (existing rings) |
| Inner fill | NoAlc status color (solid fill) |
| Tap on day | Shows existing detail sheet → now includes `drinks` value |
| Colors | `#00C853` (Steady) → `#A5D6A7` (Easy) → `#E8F5E9` (Wild) → `#FFFFFF` (no data) |

**Accessibility Note:**
- Inner fill colors **must maintain sufficient contrast** with calendar date numbers
- Date numbers remain readable across all fill colors
- Consider text shadow or outline if contrast insufficient

---

## 🔹 Streak System

| Rule | Description |
|------|--------------|
| +1 Streak Point | 7 consecutive days with `drinks <= 1 (= 0 value)` |
| Symbol | 🍃 (streak marker) |
| Forgiveness | Accumulated streak points can offset one “Wild” day without reset. |
| Integration | Reuses existing Streak logic (no new mechanism). |

---

## 🔹 Symbol System Consistency

| Feature | Symbol | Semantics |
|----------|---------|-----------|
| Meditation | `leaf.fill` | Mind / Balance |
| Workout | `flame.fill` | Body / Energy |
| NoAlc | `drop.fill` | Clarity / Purity |

---

## 🔹 Design Guidelines
- **Aesthetic:** Glass-style (consistent with iOS 18 / watchOS 11).  
- **Tone:** Light, encouraging, never moralizing.  
- **Text length:** Short; buttons fit in notification width.  
- **Color harmony:** reuse existing Meditation/Workout palette with adjusted green hues.  
- **Animations:** Subtle scale feedback on tap.

---

## 🔹 Future Extensions
- Configurable reminder time (Smart Reminder Settings).  
- Visualization of consumption trends over weeks.  
- Optional correlation views with Sleep / Heart Rate data.

---

## ✅ Summary
| Element | Decision |
|----------|-----------|
| **Labels** | 💧 Steady  ✨ Easy  💥 Wild |
| **Tab Icon** | `drop.fill` (4th tab in TabView) |
| **Notification Day Rule** | < 18:00 = yesterday, >= 18:00 = today |
| **HealthKit Type** | `numberOfAlcoholicBeverages` (native, integer count) |
| **HealthKit Values** | 0 (Steady), 4 (Easy), 6 (Wild) |
| **Calendar Integration** | Inner fill color (maintains contrast with date numbers) |
| **Colors** | `#00C853` → `#A5D6A7` → `#E8F5E9` → `#FFFFFF` |
| **Streak Logic** | Identical to Meditation / Workout (7 days = 1 reward) |

---
