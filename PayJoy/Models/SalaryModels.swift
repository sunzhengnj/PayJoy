import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.app.payjoy.kaixin"
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Hashable {
    case system
    case zhHans
    case zhHant
    case en
    case ja
    case ko

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.t("跟随系统")
        case .zhHans: L10n.t("简体中文")
        case .zhHant: L10n.t("繁體中文")
        case .en: "English"
        case .ja: L10n.t("日本語")
        case .ko: "한국어"
        }
    }

    var shortTitle: String {
        switch self {
        case .system: L10n.t("系统")
        case .zhHans: L10n.t("简中")
        case .zhHant: L10n.t("繁中")
        case .en: "EN"
        case .ja: L10n.t("日文")
        case .ko: "한국어"
        }
    }

    var localeIdentifier: String {
        switch resolved {
        case .system, .zhHans: "zh-Hans"
        case .zhHant: "zh-Hant"
        case .en: "en"
        case .ja: "ja"
        case .ko: "ko"
        }
    }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        return AppLanguage.systemPreferred
    }

    static var systemPreferred: AppLanguage {
        let identifier = Locale.preferredLanguages.first?.lowercased() ?? ""
        if identifier.hasPrefix("zh-hant") || identifier.contains("hant") || identifier.hasPrefix("zh-tw") || identifier.hasPrefix("zh-hk") {
            return .zhHant
        }
        if identifier.hasPrefix("zh") {
            return .zhHans
        }
        if identifier.hasPrefix("ja") {
            return .ja
        }
        if identifier.hasPrefix("ko") {
            return .ko
        }
        if identifier.hasPrefix("en") {
            return .en
        }
        return .zhHans
    }
}

enum SalaryCurrency {
    static let symbols = ["¥", "$", "€", "£", "₩"]

    static var defaultSymbol: String {
        defaultSymbol(for: L10n.currentLanguage)
    }

    static func defaultSymbol(for language: AppLanguage) -> String {
        switch language.resolved {
        case .zhHans, .ja:
            return "¥"
        case .ko:
            return "₩"
        case .en, .zhHant, .system:
            return "$"
        }
    }

    static func normalized(_ symbol: String?) -> String {
        guard let symbol, symbols.contains(symbol) else { return defaultSymbol }
        return symbol
    }
}

enum SalaryType: String, Codable, CaseIterable, Identifiable {
    case yearly
    case monthly
    case daily
    case hourly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yearly: L10n.t("年薪")
        case .monthly: L10n.t("月薪")
        case .daily: L10n.t("日薪")
        case .hourly: L10n.t("时薪")
        }
    }

    var inputTitle: String {
        switch self {
        case .yearly: L10n.t("年薪金额")
        case .monthly: L10n.t("月薪金额")
        case .daily: L10n.t("日薪金额")
        case .hourly: L10n.t("时薪金额")
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
        case .monday: L10n.t("周一")
        case .tuesday: L10n.t("周二")
        case .wednesday: L10n.t("周三")
        case .thursday: L10n.t("周四")
        case .friday: L10n.t("周五")
        case .saturday: L10n.t("周六")
        case .sunday: L10n.t("周日")
        }
    }

    var shortTitle: String {
        switch self {
        case .monday: L10n.t("一")
        case .tuesday: L10n.t("二")
        case .wednesday: L10n.t("三")
        case .thursday: L10n.t("四")
        case .friday: L10n.t("五")
        case .saturday: L10n.t("六")
        case .sunday: L10n.t("日")
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
    var currencySymbol: String
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
        case currencySymbol
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
        currencySymbol: SalaryCurrency.defaultSymbol,
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
        currencySymbol: String = SalaryCurrency.defaultSymbol,
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
        self.currencySymbol = SalaryCurrency.normalized(currencySymbol)
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
        currencySymbol = SalaryCurrency.normalized(try container.decodeIfPresent(String.self, forKey: .currencySymbol))
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

struct OvertimeRecord: Codable, Equatable, Identifiable {
    var id: String
    var startAt: Date
    var endAt: Date?
    var createdAt: Date

    var isActive: Bool {
        endAt == nil
    }

    init(id: String = UUID().uuidString, startAt: Date, endAt: Date?, createdAt: Date = Date()) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.createdAt = createdAt
    }

    func duration(until date: Date) -> TimeInterval {
        max(0, (endAt ?? date).timeIntervalSince(startAt))
    }
}

struct OvertimeSummary: Equatable {
    var records: [OvertimeRecord]
    var totalSeconds: TimeInterval

    var count: Int {
        records.count
    }

    var totalHours: Double {
        totalSeconds / 3_600
    }

    var activeRecord: OvertimeRecord? {
        records.first { $0.isActive }
    }

    var hasActiveRecord: Bool {
        activeRecord != nil
    }

    var hasRecords: Bool {
        !records.isEmpty
    }
}

enum SalaryDayKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case normal
    case paidLeave
    case unpaidLeave
    case rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: L10n.t("正常")
        case .paidLeave: L10n.t("带薪假")
        case .unpaidLeave: L10n.t("无薪假")
        case .rest: L10n.t("休息")
        }
    }
}

struct SalaryDayRecord: Codable, Equatable, Identifiable {
    var dateKey: String
    var kind: SalaryDayKind
    var note: String
    var settingsSnapshot: SalarySettings
    var scheduledAmount: Double
    var earnedAmount: Double
    var isEstimated: Bool
    var updatedAt: Date

    var id: String { dateKey }
}

struct SalaryCalendarDay: Equatable, Identifiable {
    var date: Date
    var dateKey: String
    var kind: SalaryDayKind
    var note: String
    var scheduledAmount: Double
    var earnedAmount: Double
    var isEstimated: Bool
    var isFuture: Bool
    var hasSavedRecord: Bool

    var id: String { dateKey }
}

struct SalaryMonthSummary: Equatable {
    var earnedAmount: Double
    var projectedAmount: Double
    var paidDayCount: Int
    var estimatedDayCount: Int
}

enum AppVisualTheme: String, Codable, CaseIterable, Identifiable, Hashable {
    case classic
    case pink
    case luckyCat
    case midnight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: L10n.t("元气打工")
        case .pink: L10n.t("粉桃通勤")
        case .luckyCat: L10n.t("招财喵喵")
        case .midnight: L10n.t("午夜打工台")
        }
    }
}

enum AppIconChoice: String, Codable, CaseIterable, Identifiable, Hashable {
    case classic
    case pink
    case luckyCat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: L10n.t("经典开薪")
        case .pink: L10n.t("粉桃开薪")
        case .luckyCat: L10n.t("招财开薪")
        }
    }

    var alternateIconName: String? {
        switch self {
        case .classic: nil
        case .pink: "AppIconPink"
        case .luckyCat: "AppIconLuckyCat"
        }
    }

    var previewAssetName: String {
        switch self {
        case .classic: "app_icon_classic_preview"
        case .pink: "app_icon_pink_preview"
        case .luckyCat: "app_icon_lucky_cat_preview"
        }
    }

    static func choice(forAlternateIconName alternateIconName: String?) -> AppIconChoice {
        allCases.first { $0.alternateIconName == alternateIconName } ?? .classic
    }
}

struct UserProfile: Codable, Equatable {
    var nickname: String
    var motto: String
    var avatarAssetName: String

    static let defaultNicknameKey = L10n.defaultProfileNicknameKey
    static let defaultMottoKey = L10n.defaultProfileMottoKey
    static let defaultAvatarAssetName = "profile_avatar_worker_v1"

    static let defaultValue = UserProfile(
        nickname: defaultNicknameKey,
        motto: defaultMottoKey,
        avatarAssetName: defaultAvatarAssetName
    )

    var displayNickname: String {
        isDefaultNickname ? L10n.t(Self.defaultNicknameKey) : nickname
    }

    var displayMotto: String {
        isDefaultMotto ? L10n.t(Self.defaultMottoKey) : motto
    }

    private var isDefaultNickname: Bool {
        let defaults = [
            Self.defaultNicknameKey,
            L10n.t(Self.defaultNicknameKey),
            "PayJoy Worker",
            "워커 샤오카이"
        ]
        return defaults.contains(nickname)
    }

    private var isDefaultMotto: Bool {
        let defaults = [
            Self.defaultMottoKey,
            L10n.t(Self.defaultMottoKey),
            "Earn at work, spend after work. Live well, enjoy payday!",
            "출근해서 벌고 퇴근 후 쓰며, 열심히 살고 즐겁게 PayJoy!"
        ]
        return defaults.contains(motto)
    }

    static let avatarOptions = [
        "profile_avatar_worker_v1",
        "classic_profile_avatar_typing_v2",
        "classic_profile_avatar_coffee_v2",
        "classic_profile_avatar_payday_v2",
        "classic_profile_avatar_focus_v2",
        "classic_profile_avatar_shades_v2",
        "classic_profile_avatar_commute_v2",
        "profile_avatar_focus_worker_v1",
        "profile_avatar_coffee_worker_v1",
        "profile_avatar_coin_worker_v1",
        "profile_avatar_cat_worker_v1",
        "profile_avatar_night_worker_v1",
        "profile_avatar_bob_worker_v1",
        "profile_avatar_latte_worker_v1",
        "profile_avatar_ponytail_worker_v1",
        "profile_avatar_bun_worker_v1",
        "profile_avatar_cool_worker_v1",
        "profile_avatar_smile_worker_v1",
        "pink_profile_avatar_worker_v1",
        "pink_profile_avatar_focus_v1",
        "pink_profile_avatar_phone_v1",
        "pink_profile_avatar_coin_v1",
        "pink_profile_avatar_moyu_v1",
        "pink_profile_avatar_target_v1",
        "lucky_cat_profile_avatar_v1",
        "lucky_cat_profile_avatar_wave_v2",
        "lucky_cat_profile_avatar_laptop_v2",
        "lucky_cat_profile_avatar_lounge_v2",
        "lucky_cat_profile_avatar_crown_v2",
        "lucky_cat_profile_avatar_target_v2",
        "lucky_cat_profile_avatar_peek_v2"
    ]

    enum CodingKeys: String, CodingKey {
        case nickname
        case motto
        case avatarAssetName
    }

    init(nickname: String, motto: String, avatarAssetName: String = UserProfile.defaultAvatarAssetName) {
        self.nickname = nickname
        self.motto = motto
        self.avatarAssetName = avatarAssetName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nickname = try container.decode(String.self, forKey: .nickname)
        motto = try container.decode(String.self, forKey: .motto)
        avatarAssetName = try container.decodeIfPresent(String.self, forKey: .avatarAssetName) ?? UserProfile.defaultAvatarAssetName
    }
}

struct AppPreferences: Codable, Equatable {
    var appLanguage: AppLanguage
    var selectedTheme: AppVisualTheme
    var selectedAppIcon: AppIconChoice
    var remindersEnabled: Bool
    var lunchRemindersEnabled: Bool
    var showCoinRain: Bool
    var reduceMotion: Bool
    var showDecimalCents: Bool
    var isProUnlocked: Bool
    var hideSensitiveAmounts: Bool
    var appLockEnabled: Bool
    var appLockPasscodeSalt: String?
    var appLockPasscodeHash: String?

    static let defaultValue = AppPreferences(
        appLanguage: .system,
        selectedTheme: .classic,
        selectedAppIcon: .classic,
        remindersEnabled: false,
        lunchRemindersEnabled: false,
        showCoinRain: true,
        reduceMotion: false,
        showDecimalCents: true,
        isProUnlocked: false,
        hideSensitiveAmounts: false,
        appLockEnabled: false,
        appLockPasscodeSalt: nil,
        appLockPasscodeHash: nil
    )

    enum CodingKeys: String, CodingKey {
        case remindersEnabled
        case lunchRemindersEnabled
        case showCoinRain
        case reduceMotion
        case showDecimalCents
        case isProUnlocked
        case hideSensitiveAmounts
        case appLockEnabled
        case appLockPasscodeSalt
        case appLockPasscodeHash
        case appLanguage
        case selectedTheme
        case selectedAppIcon
    }

    init(
        appLanguage: AppLanguage,
        selectedTheme: AppVisualTheme,
        selectedAppIcon: AppIconChoice,
        remindersEnabled: Bool,
        lunchRemindersEnabled: Bool,
        showCoinRain: Bool,
        reduceMotion: Bool,
        showDecimalCents: Bool,
        isProUnlocked: Bool,
        hideSensitiveAmounts: Bool,
        appLockEnabled: Bool,
        appLockPasscodeSalt: String?,
        appLockPasscodeHash: String?
    ) {
        self.appLanguage = appLanguage
        self.selectedTheme = selectedTheme
        self.selectedAppIcon = selectedAppIcon
        self.remindersEnabled = remindersEnabled
        self.lunchRemindersEnabled = lunchRemindersEnabled
        self.showCoinRain = showCoinRain
        self.reduceMotion = reduceMotion
        self.showDecimalCents = showDecimalCents
        self.isProUnlocked = isProUnlocked
        self.hideSensitiveAmounts = hideSensitiveAmounts
        self.appLockEnabled = appLockEnabled
        self.appLockPasscodeSalt = appLockPasscodeSalt
        self.appLockPasscodeHash = appLockPasscodeHash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .system
        selectedTheme = try container.decodeIfPresent(AppVisualTheme.self, forKey: .selectedTheme) ?? .classic
        selectedAppIcon = try container.decodeIfPresent(AppIconChoice.self, forKey: .selectedAppIcon) ?? .classic
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        lunchRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .lunchRemindersEnabled) ?? false
        showCoinRain = try container.decodeIfPresent(Bool.self, forKey: .showCoinRain) ?? true
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        showDecimalCents = try container.decodeIfPresent(Bool.self, forKey: .showDecimalCents) ?? true
        isProUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isProUnlocked) ?? false
        hideSensitiveAmounts = try container.decodeIfPresent(Bool.self, forKey: .hideSensitiveAmounts) ?? false
        appLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .appLockEnabled) ?? false
        appLockPasscodeSalt = try container.decodeIfPresent(String.self, forKey: .appLockPasscodeSalt)
        appLockPasscodeHash = try container.decodeIfPresent(String.self, forKey: .appLockPasscodeHash)
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
        return L10n.t("Apple ID 已连接")
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
        case .notDetermined: L10n.t("尚未请求权限")
        case .denied: L10n.t("系统通知已关闭")
        case .authorized: L10n.t("通知权限已开启")
        case .provisional: L10n.t("通知权限已临时开启")
        case .ephemeral: L10n.t("通知权限已临时开启")
        case .unknown: L10n.t("通知权限未知")
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
        case .beforeWork: L10n.t("钱包热身中")
        case .working: L10n.t("开薪中")
        case .lunchBreak: L10n.t("午休暂停")
        case .afterWork: L10n.t("今日到账")
        case .restDay: L10n.t("休息日")
        }
    }

    var message: String {
        switch self {
        case .beforeWork: L10n.t("还没开工，钱包正在热身。")
        case .working: L10n.t("每一秒都在回血。")
        case .lunchBreak: L10n.t("午休时间，工资先歇会儿。")
        case .afterWork: L10n.t("今日收入到账，打工人安全下线。")
        case .restDay: L10n.t("今天休息，不开薪也开心。")
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
        case .today: L10n.t("今日")
        case .month: L10n.t("本月")
        case .year: L10n.t("本年")
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
