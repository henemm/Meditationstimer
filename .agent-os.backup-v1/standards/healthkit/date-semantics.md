# HealthKit Date Semantics

## .strictStartDate EndDate is EXCLUSIVE

**Problem:** Today's data not showing despite being saved.

**Root Cause:** Using `endOfMonth` (Oct 31 00:00:00) but `.strictStartDate` endDate is EXCLUSIVE.

```swift
// WRONG: Oct 31 00:00:00 excludes samples after midnight
let endDate = calendar.date(from: DateComponents(year: 2025, month: 10, day: 31))!

// CORRECT: Nov 1 00:00:00 includes entire October
let endDate = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1))!
```

**Rule:**
```
.strictStartDate endDate is EXCLUSIVE
-> Use "start of NEXT period" not "end of CURRENT period"
```

## Forward vs Backward Iteration

**When tracking cumulative resources (streaks, rewards), use FORWARD iteration.**

**Problem Example (NoAlc Streak):**
```swift
// WRONG: Backwards iteration
var checkDate = today
while true {
    if level == .easy && earnedRewards > 0 { // Try to use reward
        consumedRewards += 1
    }
    checkDate = previousDate  // Rewards earned BEFORE in time, AFTER in iteration!
}
```

**Why it fails:**
1. Start at Nov 8 (Easy day needing reward)
2. `earnedRewards = 0` (haven't iterated past yet)
3. Cannot heal Easy day -> streak ends
4. Rewards from Nov 1-7 encountered AFTER but earned BEFORE

**Solution:**
```swift
// CORRECT: Forward iteration
let sortedDates = data.keys.sorted()  // Earliest -> Latest
for date in sortedDates {
    if level == .steady {
        consecutiveDays += 1
        if consecutiveDays % 7 == 0 { earnedRewards += 1 }  // Earn chronologically
    } else if level == .easy {
        if earnedRewards - consumedRewards > 0 {  // Already earned!
            consumedRewards += 1
            consecutiveDays += 1
        }
    }
}
```

**When to use which:**
| Direction | Use For |
|-----------|---------|
| Forward | Earned/consumed resources, cumulative stats, state changes |
| Backward | Most recent value, "current streak from now", recency queries |

**The Simple Rule:**
- DO process chronological data in chronological order
- DO earn/consume resources in order they naturally occur
- DON'T use backwards iteration for cumulative tracking
- DON'T overcomplicate with "clever" directions

## DateComponents.weekday for Scheduling

**For weekday-specific notifications:**
```swift
// CORRECT: Use DateComponents.weekday
var components = DateComponents()
components.weekday = 2  // Monday = 2, Sunday = 1
components.hour = 9
components.minute = 0

let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
```

**DON'T:** Manual weekday filtering logic
**DO:** Let system handle with `DateComponents.weekday`

## Extract Both Hour AND Minute

```swift
// WRONG: Hardcoding minutes
components.hour = calendar.component(.hour, from: time)
components.minute = 0  // Always :00!

// CORRECT: Extract both
components.hour = calendar.component(.hour, from: time)
components.minute = calendar.component(.minute, from: time)
```
