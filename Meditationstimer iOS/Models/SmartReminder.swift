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
        case .sunday: return NSLocalizedString("Sunday", comment: "Weekday name")
        case .monday: return NSLocalizedString("Monday", comment: "Weekday name")
        case .tuesday: return NSLocalizedString("Tuesday", comment: "Weekday name")
        case .wednesday: return NSLocalizedString("Wednesday", comment: "Weekday name")
        case .thursday: return NSLocalizedString("Thursday", comment: "Weekday name")
        case .friday: return NSLocalizedString("Friday", comment: "Weekday name")
        case .saturday: return NSLocalizedString("Saturday", comment: "Weekday name")
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
            dayString = NSLocalizedString("Daily", comment: "All days selected")
        } else if selectedDays.isEmpty {
            dayString = NSLocalizedString("No days", comment: "No days selected")
        } else {
            let sortedDays = Weekday.allCases.filter { selectedDays.contains($0) }
            let dayAbbreviations = sortedDays.map { day -> String in
                switch day {
                case .monday: return NSLocalizedString("Mon", comment: "Monday abbreviation")
                case .tuesday: return NSLocalizedString("Tue", comment: "Tuesday abbreviation")
                case .wednesday: return NSLocalizedString("Wed", comment: "Wednesday abbreviation")
                case .thursday: return NSLocalizedString("Thu", comment: "Thursday abbreviation")
                case .friday: return NSLocalizedString("Fri", comment: "Friday abbreviation")
                case .saturday: return NSLocalizedString("Sat", comment: "Saturday abbreviation")
                case .sunday: return NSLocalizedString("Sun", comment: "Sunday abbreviation")
                }
            }
            dayString = dayAbbreviations.joined(separator: ", ")
        }

        // Activity description
        let activityDescription: String
        if hoursInactive == 1 {
            // Singular: "in the last hour"
            switch activityType {
            case .mindfulness: activityDescription = NSLocalizedString("no meditation in the last hour", comment: "Mindfulness reminder condition singular")
            case .workout: activityDescription = NSLocalizedString("no workout in the last hour", comment: "Workout reminder condition singular")
            case .noalc: activityDescription = NSLocalizedString("no alcohol logged in the last hour", comment: "NoAlc reminder condition singular")
            }
        } else {
            // Plural: "in the last X hours"
            switch activityType {
            case .mindfulness: activityDescription = String(format: NSLocalizedString("no meditation in the last %d hours", comment: "Mindfulness reminder condition plural"), hoursInactive)
            case .workout: activityDescription = String(format: NSLocalizedString("no workout in the last %d hours", comment: "Workout reminder condition plural"), hoursInactive)
            case .noalc: activityDescription = String(format: NSLocalizedString("no alcohol logged in the last %d hours", comment: "NoAlc reminder condition plural"), hoursInactive)
            }
        }

        return String(format: NSLocalizedString("%@ at %@ if %@", comment: "Reminder description format: days, time, condition"), dayString, timeString, activityDescription)
    }

    static func sampleData() -> [SmartReminder] {
        return [
            SmartReminder(
                id: UUID(),
                title: "Morning Meditation",
                message: "Take a moment to breathe 🌿",
                hoursInactive: 24,
                triggerTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                isEnabled: true,
                selectedDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday],
                activityType: .mindfulness
            ),
            SmartReminder(
                id: UUID(),
                title: "Evening Workout",
                message: "Time for your daily workout! 💪",
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