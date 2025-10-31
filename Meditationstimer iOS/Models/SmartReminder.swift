import Foundation

public enum ActivityType: String, Codable {
    case mindfulness = "mindfulness"
    case workout = "workout"
    case noalc = "noalc"
}

public enum Weekday: String, CaseIterable, Codable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    public var displayName: String {
        switch self {
        case .sunday: return "Sonntag"
        case .monday: return "Montag"
        case .tuesday: return "Dienstag"
        case .wednesday: return "Mittwoch"
        case .thursday: return "Donnerstag"
        case .friday: return "Freitag"
        case .saturday: return "Samstag"
        }
    }
}

public struct SmartReminder: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var message: String
    public var hoursInactive: Int
    public var triggerTime: Date
    public var isEnabled: Bool
    public var selectedDays: Set<Weekday>
    public var activityType: ActivityType
    
    // Computed properties für Engine-Kompatibilität
    public var triggerHour: Int {
        Calendar.current.component(.hour, from: triggerTime)
    }
    
    public var windowMinutes: Int {
        60 // 1 Stunde Fenster
    }
    
    public var lookbackHours: Int {
        hoursInactive
    }
    
    public var checkType: ActivityType {
        activityType
    }

    public var description: String {
        "Erinnert dich, wenn du länger als \(hoursInactive) Stunden keine Aktivität hattest."
    }

    static func sampleData() -> [SmartReminder] {
        return [
            SmartReminder(
                id: UUID(),
                title: "Morgendliche Meditation",
                message: "Nimm dir einen Moment zum Atmen 🌿",
                hoursInactive: 24,
                triggerTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                isEnabled: true,
                selectedDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday],
                activityType: .mindfulness
            ),
            SmartReminder(
                id: UUID(),
                title: "Abendliches Workout",
                message: "Zeit für dein tägliches Workout! 💪",
                hoursInactive: 48,
                triggerTime: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date(),
                isEnabled: true,
                selectedDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                activityType: .workout
            ),
            SmartReminder(
                id: UUID(),
                title: "NoAlc Check-In",
                message: "Log your drinks to keep your streak going 💧",
                hoursInactive: 24,
                triggerTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
                isEnabled: false,  // Disabled by default - user must enable
                selectedDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday],
                activityType: .noalc
            )
        ]
    }
}