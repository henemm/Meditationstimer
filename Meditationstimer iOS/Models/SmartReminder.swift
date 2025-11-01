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

    /// Calendar weekday value (1=Sunday, 2=Monday, ..., 7=Saturday)
    public var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
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
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: triggerTime)

        // Format selected days
        let dayString: String
        if selectedDays.count == 7 {
            dayString = "Täglich"
        } else if selectedDays.isEmpty {
            dayString = "Keine Tage"
        } else {
            let sortedDays = Weekday.allCases.filter { selectedDays.contains($0) }
            let dayAbbreviations = sortedDays.map { day -> String in
                switch day {
                case .monday: return "Mo"
                case .tuesday: return "Di"
                case .wednesday: return "Mi"
                case .thursday: return "Do"
                case .friday: return "Fr"
                case .saturday: return "Sa"
                case .sunday: return "So"
                }
            }
            dayString = dayAbbreviations.joined(separator: ", ")
        }

        // Activity description
        let activityDescription: String
        if hoursInactive == 1 {
            // Singular: "in der letzten Stunde"
            switch activityType {
            case .mindfulness: activityDescription = "in der letzten Stunde keine Meditation gemacht wurde"
            case .workout: activityDescription = "in der letzten Stunde kein Workout gemacht wurde"
            case .noalc: activityDescription = "in der letzten Stunde keinen Alkoholkonsum protokolliert haben"
            }
        } else {
            // Plural: "in den letzten X Stunden"
            switch activityType {
            case .mindfulness: activityDescription = "in den letzten \(hoursInactive) Stunden keine Meditation gemacht wurde"
            case .workout: activityDescription = "in den letzten \(hoursInactive) Stunden kein Workout gemacht wurde"
            case .noalc: activityDescription = "in den letzten \(hoursInactive) Stunden keinen Alkoholkonsum protokolliert haben"
            }
        }

        return "\(dayString) um \(timeString) wenn \(activityDescription)"
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