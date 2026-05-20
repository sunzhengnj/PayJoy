import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.app.payjoy.kaixin"
}

enum SalaryType: String, Codable, CaseIterable, Identifiable {
    case yearly
    case monthly
    case daily
    case hourly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearly: "年薪"
        case .monthly: "月薪"
        case .daily: "日薪"
        case .hourly: "时薪"
        }
    }

    var inputTitle: String {
        switch self {
        case .yearly: "年薪金额"
        case .monthly: "月薪金额"
        case .daily: "日薪金额"
        case .hourly: "时薪金额"
        }
    }
}

enum Workday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    static let defaultWeekdays: Set<Int> = [
        Workday.monday.rawValue,
        Workday.tuesday.rawValue,
        Workday.wednesday.rawValue,
        Workday.thursday.rawValue,
        Workday.friday.rawValue
    ]

    static let displayOrder: [Workday] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday
    ]

    var title: String {
        switch self {
        case .monday: "周一"
        case .tuesday: "周二"
        case .wednesday: "周三"
        case .thursday: "周四"
        case .friday: "周五"
        case .saturday: "周六"
        case .sunday: "周日"
        }
    }

    var shortTitle: String {
        switch self {
        case .monday: "一"
        case .tuesday: "二"
        case .wednesday: "三"
        case .thursday: "四"
        case .friday: "五"
        case .saturday: "六"
        case .sunday: "日"
        }
    }
}

struct WorkTime: Codable, Equatable {
    var hour: Int
    var minute: Int

    static let defaultStart = WorkTime(hour: 9, minute: 0)
    static let defaultEnd = WorkTime(hour: 18, minute: 0)
    static let defaultLunchStart = WorkTime(hour: 12, minute: 0)
    static let defaultLunchEnd = WorkTime(hour: 13, minute: 0)

    var minutesFromStartOfDay: Int {
        hour * 60 + minute
    }

    var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

struct SalarySettings: Codable, Equatable {
    var salaryType: SalaryType
    var salaryAmount: Double
    var workStart: WorkTime
    var workEnd: WorkTime
    var deductLunch: Bool
    var lunchStart: WorkTime
    var lunchEnd: WorkTime
    var monthlyPaidDays: Double
    var workdays: Set<Int>

    enum CodingKeys: String, CodingKey {
        case salaryType
        case salaryAmount
        case workStart
        case workEnd
        case deductLunch
        case lunchStart
        case lunchEnd
        case monthlyPaidDays
        case workdays
    }

    static let defaultValue = SalarySettings(
        salaryType: .monthly,
        salaryAmount: 10_000,
        workStart: .defaultStart,
        workEnd: .defaultEnd,
        deductLunch: false,
        lunchStart: .defaultLunchStart,
        lunchEnd: .defaultLunchEnd,
        monthlyPaidDays: 21.75,
        workdays: Workday.defaultWeekdays
    )

    init(
        salaryType: SalaryType,
        salaryAmount: Double,
        workStart: WorkTime,
        workEnd: WorkTime,
        deductLunch: Bool,
        lunchStart: WorkTime,
        lunchEnd: WorkTime,
        monthlyPaidDays: Double,
        workdays: Set<Int>
    ) {
        self.salaryType = salaryType
        self.salaryAmount = salaryAmount
        self.workStart = workStart
        self.workEnd = workEnd
        self.deductLunch = deductLunch
        self.lunchStart = lunchStart
        self.lunchEnd = lunchEnd
        self.monthlyPaidDays = monthlyPaidDays
        self.workdays = workdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        salaryType = try container.decode(SalaryType.self, forKey: .salaryType)
        salaryAmount = try container.decode(Double.self, forKey: .salaryAmount)
        workStart = try container.decode(WorkTime.self, forKey: .workStart)
        workEnd = try container.decode(WorkTime.self, forKey: .workEnd)
        deductLunch = try container.decode(Bool.self, forKey: .deductLunch)
        lunchStart = try container.decode(WorkTime.self, forKey: .lunchStart)
        lunchEnd = try container.decode(WorkTime.self, forKey: .lunchEnd)
        monthlyPaidDays = try container.decode(Double.self, forKey: .monthlyPaidDays)
        workdays = try container.decodeIfPresent(Set<Int>.self, forKey: .workdays) ?? Workday.defaultWeekdays
    }
}

struct OvertimeDay: Codable, Equatable, Identifiable {
    var dateKey: String

    var id: String { dateKey }
}

struct UserProfile: Codable, Equatable {
    var nickname: String
    var motto: String

    static let defaultValue = UserProfile(
        nickname: "打工人小开",
        motto: "上班赚钱，下班花钱，努力生活，开心开薪！"
    )
}

struct AppPreferences: Codable, Equatable {
    var remindersEnabled: Bool
    var showCoinRain: Bool
    var reduceMotion: Bool
    var showDecimalCents: Bool
    var isProUnlocked: Bool

    static let defaultValue = AppPreferences(
        remindersEnabled: false,
        showCoinRain: true,
        reduceMotion: false,
        showDecimalCents: true,
        isProUnlocked: false
    )

    enum CodingKeys: String, CodingKey {
        case remindersEnabled
        case showCoinRain
        case reduceMotion
        case showDecimalCents
        case isProUnlocked
    }

    init(
        remindersEnabled: Bool,
        showCoinRain: Bool,
        reduceMotion: Bool,
        showDecimalCents: Bool,
        isProUnlocked: Bool
    ) {
        self.remindersEnabled = remindersEnabled
        self.showCoinRain = showCoinRain
        self.reduceMotion = reduceMotion
        self.showDecimalCents = showDecimalCents
        self.isProUnlocked = isProUnlocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        showCoinRain = try container.decodeIfPresent(Bool.self, forKey: .showCoinRain) ?? true
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        showDecimalCents = try container.decodeIfPresent(Bool.self, forKey: .showDecimalCents) ?? true
        isProUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isProUnlocked) ?? false
    }
}

struct AppleAccount: Codable, Equatable {
    var userIdentifier: String
    var email: String?
    var fullName: String?
    var signedInAt: Date

    var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        if let email, !email.isEmpty { return email }
        return "Apple ID 已连接"
    }
}

enum ReminderPermissionState: String, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    var title: String {
        switch self {
        case .notDetermined: "尚未请求权限"
        case .denied: "系统通知已关闭"
        case .authorized: "通知权限已开启"
        case .provisional: "通知权限已临时开启"
        case .ephemeral: "通知权限已临时开启"
        case .unknown: "通知权限未知"
        }
    }

    var canScheduleReminders: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied, .unknown:
            false
        }
    }
}

enum WorkdayStatus: String, Codable, Equatable {
    case beforeWork
    case working
    case lunchBreak
    case afterWork
    case restDay

    var title: String {
        switch self {
        case .beforeWork: "钱包热身中"
        case .working: "开薪中"
        case .lunchBreak: "午休暂停"
        case .afterWork: "今日到账"
        case .restDay: "休息日"
        }
    }

    var message: String {
        switch self {
        case .beforeWork: "还没开工，钱包正在热身。"
        case .working: "每一秒都在回血。"
        case .lunchBreak: "午休时间，工资先歇会儿。"
        case .afterWork: "今日收入到账，打工人安全下线。"
        case .restDay: "今天休息，不开薪也开心。"
        }
    }
}

struct EarningsSnapshot: Equatable {
    var todayEarned: Double
    var todayTotal: Double
    var earnedPerSecond: Double
    var progress: Double
    var remainingToday: Double
    var secondsUntilOffWork: TimeInterval
    var status: WorkdayStatus
}

enum StatsPeriod: String, CaseIterable, Identifiable {
    case today
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "今日"
        case .month: "本月"
        case .year: "本年"
        }
    }
}

struct PeriodEarnings: Equatable {
    var earned: Double
    var projected: Double
    var progress: Double
}

struct PeriodBreakdown: Equatable {
    var elapsedFullWorkdays: Int
    var totalWorkdays: Int
    var remainingWorkdays: Int
    var completedWorkdayEquivalent: Double

    var workdayProgress: Double {
        guard totalWorkdays > 0 else { return 0 }
        return min(1, max(0, completedWorkdayEquivalent / Double(totalWorkdays)))
    }
}
