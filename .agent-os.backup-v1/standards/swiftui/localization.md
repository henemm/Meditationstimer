# SwiftUI Localization Standards

## When to Use Which Method

### LocalizedStringKey (Default for SwiftUI)

Use for static text in SwiftUI views:
```swift
Text("meditation_title")  // Automatically uses LocalizedStringKey
```

### NSLocalizedString (For Dynamic/Computed)

Use for:
- String interpolation
- Computed properties
- Non-View contexts

```swift
let message = NSLocalizedString("workout_complete", comment: "Shown after workout")
```

### String(localized:) (iOS 15+)

Modern alternative to NSLocalizedString:
```swift
let title = String(localized: "settings_title")
```

## Localizable.xcstrings Format

```json
{
  "key_name" : {
    "localizations" : {
      "de" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "German translation"
        }
      },
      "en" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "English translation"
        }
      }
    }
  }
}
```

## Project-Specific Vocabulary

| German | English |
|--------|---------|
| Meditation | Meditation |
| Atmen / Atemübung | Breathing / Breathing Exercise |
| Workout | Workout |
| Streak | Streak |
| Belohnungen | Rewards |
| Einstellungen | Settings |
| Kalender | Calendar |
| Phase 1 / Phase 2 | Phase 1 / Phase 2 |
| Start / Stop / Pause | Start / Stop / Pause |

## Localization Workflow

1. Find hardcoded strings (Grep for German text in .swift files)
2. Add key to Localizable.xcstrings with both DE and EN
3. Replace hardcoded string with localized key
4. Test both languages on device

## Common Mistakes

- DON'T hardcode any user-visible text
- DON'T forget to add BOTH DE and EN translations
- DON'T use different keys for same concept
- DO maintain consistency with existing vocabulary
- DO test both languages after changes
