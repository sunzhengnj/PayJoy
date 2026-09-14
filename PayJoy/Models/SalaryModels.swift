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
        preferredLanguage(for: Locale.preferredLanguages.first)
    }

    static func preferredLanguage(for identifier: String?) -> AppLanguage {
        let identifier = identifier?.lowercased() ?? ""
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
        return .en
    }
}

enum AppMarket: String, Codable, CaseIterable, Identifiable, Hashable {
    case mainlandChina
    case taiwan
    case hongKong
    case japan
    case southKorea
    case globalEnglish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainlandChina: "中国大陆"
        case .taiwan: "台灣"
        case .hongKong: "香港"
        case .japan: "日本"
        case .southKorea: "대한민국"
        case .globalEnglish: "Global · English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .mainlandChina: "zh-Hans-CN"
        case .taiwan: "zh-Hant-TW"
        case .hongKong: "zh-Hant-HK"
        case .japan: "ja-JP"
        case .southKorea: "ko-KR"
        case .globalEnglish: "en-US"
        }
    }

    var language: AppLanguage {
        switch self {
        case .mainlandChina: .zhHans
        case .taiwan, .hongKong: .zhHant
        case .japan: .ja
        case .southKorea: .ko
        case .globalEnglish: .en
        }
    }

    static var systemResolved: AppMarket {
        resolve(
            languageIdentifier: Locale.preferredLanguages.first,
            regionCode: Locale.current.region?.identifier
        )
    }

    static func resolve(languageIdentifier: String?, regionCode: String?) -> AppMarket {
        let language = (languageIdentifier ?? "").lowercased()
        let region = (regionCode ?? "").uppercased()

        switch region {
        case "CN": return .mainlandChina
        case "TW": return .taiwan
        case "HK", "MO": return .hongKong
        case "JP": return .japan
        case "KR": return .southKorea
        default: break
        }

        if language.hasPrefix("zh-hk") || language.hasPrefix("zh-mo") {
            return .hongKong
        }
        if language.hasPrefix("zh-tw") || language.contains("hant") {
            return .taiwan
        }
        if language.hasPrefix("zh") {
            return .mainlandChina
        }
        if language.hasPrefix("ja") {
            return .japan
        }
        if language.hasPrefix("ko") {
            return .southKorea
        }
        return .globalEnglish
    }
}

enum CurrencyCode: String, Codable, CaseIterable, Identifiable, Hashable {
    case CNY
    case JPY
    case KRW
    case TWD
    case HKD
    case USD
    case EUR
    case GBP

    var id: String { rawValue }

    var displaySymbol: String {
        switch self {
        case .CNY, .JPY: "¥"
        case .KRW: "₩"
        case .TWD: "NT$"
        case .HKD: "HK$"
        case .USD: "$"
        case .EUR: "€"
        case .GBP: "£"
        }
    }

    var fractionDigits: Int {
        switch self {
        case .JPY, .KRW: 0
        default: 2
        }
    }

    static func defaultCode(for market: AppMarket) -> CurrencyCode {
        switch market {
        case .mainlandChina: .CNY
        case .taiwan: .TWD
        case .hongKong: .HKD
        case .japan: .JPY
        case .southKorea: .KRW
        case .globalEnglish: .USD
        }
    }

    static func migrating(legacySymbol: String?, market: AppMarket = .systemResolved) -> CurrencyCode {
        switch legacySymbol {
        case "NT$": return .TWD
        case "HK$": return .HKD
        case "₩": return .KRW
        case "€": return .EUR
        case "£": return .GBP
        case "¥":
            return market == .japan ? .JPY : .CNY
        case "$":
            switch market {
            case .taiwan: return .TWD
            case .hongKong: return .HKD
            default: return .USD
            }
        default:
            return defaultCode(for: market)
        }
    }
}

enum SalaryCurrency {
    static let symbols = ["¥", "₩", "NT$", "HK$", "$", "€", "£"]
    private static let settingsKey = "payjoy.salary.settings"

    static var defaultSymbol: String {
        CurrencyCode.defaultCode(for: .systemResolved).displaySymbol
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

    static func code(for symbol: String) -> CurrencyCode {
        let defaultsSources = [
            UserDefaults.standard,
            UserDefaults(suiteName: AppConstants.appGroupIdentifier)
        ].compactMap { $0 }

        for defaults in defaultsSources {
            guard let data = defaults.data(forKey: settingsKey),
                  let settings = try? JSONDecoder().decode(SalarySettings.self, from: data),
                  settings.currencySymbol == symbol else {
                continue
            }
            return settings.currencyCode
        }

        return CurrencyCode.migrating(legacySymbol: symbol, market: L10n.currentMarket)
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

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            hour: try container.decode(Int.self, forKey: .hour),
            minute: try container.decode(Int.self, forKey: .minute)
        )
    }

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
    var currencyCode: CurrencyCode
    var workStart: WorkTime
    var workEnd: WorkTime
    var deductLunch: Bool
    var lunchStart: WorkTime
    var lunchEnd: WorkTime
    var monthlyPaidDays: Double
    var workdays: Set<Int>
    var paydayDay: Int?

    enum CodingKeys: String, CodingKey {
        case salaryType
        case salaryAmount
        case currencySymbol
        case currencyCode
        case workStart
        case workEnd
        case deductLunch
        case lunchStart
        case lunchEnd
        case monthlyPaidDays
        case workdays
        case paydayDay
    }

    static let defaultValue = SalarySettings(
        salaryType: .monthly,
        salaryAmount: 10_000,
        currencySymbol: CurrencyCode.defaultCode(for: .systemResolved).displaySymbol,
        currencyCode: CurrencyCode.defaultCode(for: .systemResolved),
        workStart: .defaultStart,
        workEnd: .defaultEnd,
        deductLunch: false,
        lunchStart: .defaultLunchStart,
        lunchEnd: .defaultLunchEnd,
        monthlyPaidDays: 21.75,
        workdays: Workday.defaultWeekdays,
        paydayDay: nil
    )

    init(
        salaryType: SalaryType,
        salaryAmount: Double,
        currencySymbol: String = SalaryCurrency.defaultSymbol,
        currencyCode: CurrencyCode? = nil,
        workStart: WorkTime,
        workEnd: WorkTime,
        deductLunch: Bool,
        lunchStart: WorkTime,
        lunchEnd: WorkTime,
        monthlyPaidDays: Double,
        workdays: Set<Int>,
        paydayDay: Int? = nil
    ) {
        self.salaryType = salaryType
        self.salaryAmount = salaryAmount.isFinite ? max(0, salaryAmount) : 0
        let resolvedCurrencyCode = currencyCode ?? CurrencyCode.migrating(legacySymbol: currencySymbol)
        self.currencyCode = resolvedCurrencyCode
        self.currencySymbol = resolvedCurrencyCode.displaySymbol
        let hasValidWorkWindow = workEnd.minutesFromStartOfDay > workStart.minutesFromStartOfDay
        self.workStart = hasValidWorkWindow ? workStart : .defaultStart
        self.workEnd = hasValidWorkWindow ? workEnd : .defaultEnd
        self.lunchStart = lunchStart
        self.lunchEnd = lunchEnd
        let hasValidLunchWindow = lunchEnd.minutesFromStartOfDay > lunchStart.minutesFromStartOfDay
            && lunchStart.minutesFromStartOfDay >= self.workStart.minutesFromStartOfDay
            && lunchEnd.minutesFromStartOfDay <= self.workEnd.minutesFromStartOfDay
        self.deductLunch = deductLunch && hasValidLunchWindow
        self.monthlyPaidDays = monthlyPaidDays.isFinite
            ? min(max(monthlyPaidDays, 1), 31)
            : Self.defaultValue.monthlyPaidDays
        let validWorkdays = Set(workdays.filter { Workday(rawValue: $0) != nil })
        self.workdays = validWorkdays.isEmpty ? Workday.defaultWeekdays : validWorkdays
        self.paydayDay = paydayDay.map { min(max($0, 1), 31) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacySymbol = try container.decodeIfPresent(String.self, forKey: .currencySymbol)
        let decodedCurrencyCode = try container.decodeIfPresent(CurrencyCode.self, forKey: .currencyCode)
        self.init(
            salaryType: try container.decode(SalaryType.self, forKey: .salaryType),
            salaryAmount: try container.decode(Double.self, forKey: .salaryAmount),
            currencySymbol: legacySymbol ?? SalaryCurrency.defaultSymbol,
            currencyCode: decodedCurrencyCode ?? CurrencyCode.migrating(legacySymbol: legacySymbol),
            workStart: try container.decode(WorkTime.self, forKey: .workStart),
            workEnd: try container.decode(WorkTime.self, forKey: .workEnd),
            deductLunch: try container.decode(Bool.self, forKey: .deductLunch),
            lunchStart: try container.decode(WorkTime.self, forKey: .lunchStart),
            lunchEnd: try container.decode(WorkTime.self, forKey: .lunchEnd),
            monthlyPaidDays: try container.decode(Double.self, forKey: .monthlyPaidDays),
            workdays: try container.decodeIfPresent(Set<Int>.self, forKey: .workdays) ?? Workday.defaultWeekdays,
            paydayDay: try container.decodeIfPresent(Int.self, forKey: .paydayDay)
        )
    }

    var sanitized: SalarySettings {
        SalarySettings(
            salaryType: salaryType,
            salaryAmount: salaryAmount,
            currencySymbol: currencySymbol,
            currencyCode: currencyCode,
            workStart: workStart,
            workEnd: workEnd,
            deductLunch: deductLunch,
            lunchStart: lunchStart,
            lunchEnd: lunchEnd,
            monthlyPaidDays: monthlyPaidDays,
            workdays: workdays,
            paydayDay: paydayDay
        )
    }

    mutating func setCurrencyCode(_ code: CurrencyCode) {
        currencyCode = code
        currencySymbol = code.displaySymbol
    }

    mutating func migrateLegacyCurrency(for market: AppMarket) {
        guard currencySymbol == "$" || currencySymbol == "¥" else { return }
        setCurrencyCode(CurrencyCode.migrating(legacySymbol: currencySymbol, market: market))
    }

    var workdaySummary: String {
        let selected = Workday.displayOrder.filter { workdays.contains($0.rawValue) }
        guard !selected.isEmpty else { return L10n.t("未选择") }
        return selected.map(\.title).joined(separator: "、")
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
    var actualAmount: Double? = nil

    var progress: Double {
        guard projectedAmount > 0 else { return 0 }
        return min(1, max(0, earnedAmount / projectedAmount))
    }
}

struct ActualSalaryRecord: Codable, Equatable, Identifiable {
    var monthKey: String
    var amount: Double
    var currencyCode: CurrencyCode
    var updatedAt: Date

    var id: String { monthKey }

    init(monthKey: String, amount: Double, currencyCode: CurrencyCode, updatedAt: Date = Date()) {
        self.monthKey = monthKey
        self.amount = amount.isFinite ? max(0, amount) : 0
        self.currencyCode = currencyCode
        self.updatedAt = updatedAt
    }
}

struct PersonalGoalProgress: Equatable {
    var earnedAmount: Double
    var remainingAmount: Double
    var progress: Double
    var estimatedWorkdaysRemaining: Int
    var estimatedCompletionDate: Date?
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
            "Workday Buddy",
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
    var goalRemindersEnabled: Bool
    var showCoinRain: Bool
    var reduceMotion: Bool
    var showDecimalCents: Bool
    var isProUnlocked: Bool
    var hideSensitiveAmounts: Bool
    var hasCompletedInitialSetup: Bool
    var unlockedBadgeIDs: Set<String>
    var appLockEnabled: Bool
    var appLockPasscodeSalt: String?
    var appLockPasscodeHash: String?
    var marketOverride: AppMarket?
    var paydayShareHidesAmount: Bool

    static let defaultValue = AppPreferences(
        appLanguage: .system,
        selectedTheme: .classic,
        selectedAppIcon: .classic,
        remindersEnabled: false,
        lunchRemindersEnabled: false,
        goalRemindersEnabled: false,
        showCoinRain: true,
        reduceMotion: false,
        showDecimalCents: true,
        isProUnlocked: false,
        hideSensitiveAmounts: false,
        hasCompletedInitialSetup: false,
        unlockedBadgeIDs: [],
        appLockEnabled: false,
        appLockPasscodeSalt: nil,
        appLockPasscodeHash: nil,
        marketOverride: nil,
        paydayShareHidesAmount: true
    )

    enum CodingKeys: String, CodingKey {
        case remindersEnabled
        case lunchRemindersEnabled
        case goalRemindersEnabled
        case showCoinRain
        case reduceMotion
        case showDecimalCents
        case isProUnlocked
        case hideSensitiveAmounts
        case hasCompletedInitialSetup
        case unlockedBadgeIDs
        case appLockEnabled
        case appLockPasscodeSalt
        case appLockPasscodeHash
        case appLanguage
        case selectedTheme
        case selectedAppIcon
        case marketOverride
        case hasPresentedEmotionalProPreview
        case paydayShareHidesAmount
    }

    init(
        appLanguage: AppLanguage,
        selectedTheme: AppVisualTheme,
        selectedAppIcon: AppIconChoice,
        remindersEnabled: Bool,
        lunchRemindersEnabled: Bool,
        goalRemindersEnabled: Bool,
        showCoinRain: Bool,
        reduceMotion: Bool,
        showDecimalCents: Bool,
        isProUnlocked: Bool,
        hideSensitiveAmounts: Bool,
        hasCompletedInitialSetup: Bool = false,
        unlockedBadgeIDs: Set<String> = [],
        appLockEnabled: Bool,
        appLockPasscodeSalt: String?,
        appLockPasscodeHash: String?,
        marketOverride: AppMarket? = nil,
        paydayShareHidesAmount: Bool = true
    ) {
        self.appLanguage = appLanguage
        self.selectedTheme = selectedTheme
        self.selectedAppIcon = selectedAppIcon
        self.remindersEnabled = remindersEnabled
        self.lunchRemindersEnabled = lunchRemindersEnabled
        self.goalRemindersEnabled = goalRemindersEnabled
        self.showCoinRain = showCoinRain
        self.reduceMotion = reduceMotion
        self.showDecimalCents = showDecimalCents
        self.isProUnlocked = isProUnlocked
        self.hideSensitiveAmounts = hideSensitiveAmounts
        self.hasCompletedInitialSetup = hasCompletedInitialSetup
        self.unlockedBadgeIDs = unlockedBadgeIDs
        self.appLockEnabled = appLockEnabled
        self.appLockPasscodeSalt = appLockPasscodeSalt
        self.appLockPasscodeHash = appLockPasscodeHash
        self.marketOverride = marketOverride
        self.paydayShareHidesAmount = paydayShareHidesAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .system
        selectedTheme = try container.decodeIfPresent(AppVisualTheme.self, forKey: .selectedTheme) ?? .classic
        selectedAppIcon = try container.decodeIfPresent(AppIconChoice.self, forKey: .selectedAppIcon) ?? .classic
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        lunchRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .lunchRemindersEnabled) ?? false
        goalRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .goalRemindersEnabled) ?? false
        showCoinRain = try container.decodeIfPresent(Bool.self, forKey: .showCoinRain) ?? true
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        showDecimalCents = try container.decodeIfPresent(Bool.self, forKey: .showDecimalCents) ?? true
        isProUnlocked = try container.decodeIfPresent(Bool.self, forKey: .isProUnlocked) ?? false
        hideSensitiveAmounts = try container.decodeIfPresent(Bool.self, forKey: .hideSensitiveAmounts) ?? false
        hasCompletedInitialSetup = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedInitialSetup) ?? true
        unlockedBadgeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .unlockedBadgeIDs) ?? []
        appLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .appLockEnabled) ?? false
        appLockPasscodeSalt = try container.decodeIfPresent(String.self, forKey: .appLockPasscodeSalt)
        appLockPasscodeHash = try container.decodeIfPresent(String.self, forKey: .appLockPasscodeHash)
        marketOverride = try container.decodeIfPresent(AppMarket.self, forKey: .marketOverride)
        paydayShareHidesAmount = try container.decodeIfPresent(Bool.self, forKey: .paydayShareHidesAmount) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appLanguage, forKey: .appLanguage)
        try container.encode(selectedTheme, forKey: .selectedTheme)
        try container.encode(selectedAppIcon, forKey: .selectedAppIcon)
        try container.encode(remindersEnabled, forKey: .remindersEnabled)
        try container.encode(lunchRemindersEnabled, forKey: .lunchRemindersEnabled)
        try container.encode(goalRemindersEnabled, forKey: .goalRemindersEnabled)
        try container.encode(showCoinRain, forKey: .showCoinRain)
        try container.encode(reduceMotion, forKey: .reduceMotion)
        try container.encode(showDecimalCents, forKey: .showDecimalCents)
        try container.encode(isProUnlocked, forKey: .isProUnlocked)
        try container.encode(hideSensitiveAmounts, forKey: .hideSensitiveAmounts)
        try container.encode(hasCompletedInitialSetup, forKey: .hasCompletedInitialSetup)
        try container.encode(unlockedBadgeIDs, forKey: .unlockedBadgeIDs)
        try container.encode(appLockEnabled, forKey: .appLockEnabled)
        try container.encodeIfPresent(marketOverride, forKey: .marketOverride)
        try container.encode(paydayShareHidesAmount, forKey: .paydayShareHidesAmount)
    }

    func preservingLocalSecurityState(from localPreferences: AppPreferences) -> AppPreferences {
        var restored = self
        restored.isProUnlocked = localPreferences.isProUnlocked
        restored.unlockedBadgeIDs.formUnion(localPreferences.unlockedBadgeIDs)
        restored.appLockEnabled = localPreferences.appLockEnabled
        restored.clearLegacyAppLockCredential()
        return restored
    }

    mutating func clearLegacyAppLockCredential() {
        appLockPasscodeSalt = nil
        appLockPasscodeHash = nil
    }

    var resolvedMarket: AppMarket {
        if let marketOverride {
            return marketOverride
        }
        guard appLanguage != .system else {
            return .systemResolved
        }
        switch appLanguage {
        case .system: return .systemResolved
        case .zhHans: return .mainlandChina
        case .zhHant:
            return Locale.current.region?.identifier == "HK" ? .hongKong : .taiwan
        case .en: return .globalEnglish
        case .ja: return .japan
        case .ko: return .southKorea
        }
    }
}

enum DailyMood: String, Codable, CaseIterable, Identifiable {
    case tired
    case steady
    case bright

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tired: L10n.t("今天想慢一点")
        case .steady: L10n.t("平稳营业")
        case .bright: L10n.t("今天有点期待")
        }
    }

    var emoji: String {
        switch self {
        case .tired: "🌧️"
        case .steady: "🌿"
        case .bright: "✨"
        }
    }
}

enum EmotionalTonePack: String, Codable, CaseIterable, Identifiable {
    case gentle
    case dryHumor
    case spicy

    var id: String { rawValue }
    var isPro: Bool { self != .gentle }

    var title: String {
        switch self {
        case .gentle: L10n.t("温柔一点")
        case .dryHumor: L10n.t("冷幽默")
        case .spicy: L10n.t("犀利一点")
        }
    }
}

struct CompanionProfile: Codable, Equatable, Identifiable {
    let id: String
    let nameKey: String
    let avatarAssetName: String

    var displayName: String { L10n.t(nameKey) }

    static let catalog: [CompanionProfile] = [
        CompanionProfile(id: "kai", nameKey: "小开", avatarAssetName: "profile_avatar_worker_v1"),
        CompanionProfile(id: "coffee", nameKey: "咖啡仔", avatarAssetName: "classic_profile_avatar_coffee_v2"),
        CompanionProfile(id: "lucky", nameKey: "好运喵", avatarAssetName: "lucky_cat_profile_avatar_wave_v2"),
        CompanionProfile(id: "night", nameKey: "夜灯", avatarAssetName: "profile_avatar_night_worker_v1")
    ]

    static let defaultValue = catalog[0]
}

struct CompanionDailyState: Codable, Equatable {
    var dateKey: String
    var mood: DailyMood?

    enum CodingKeys: String, CodingKey {
        case dateKey
        case mood
        case claimedMilestones
    }

    init(dateKey: String, mood: DailyMood?) {
        self.dateKey = dateKey
        self.mood = mood
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decodeIfPresent(String.self, forKey: .dateKey)
            ?? EmotionalDayKey.string(from: Date())
        mood = try container.decodeIfPresent(DailyMood.self, forKey: .mood)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dateKey, forKey: .dateKey)
        try container.encodeIfPresent(mood, forKey: .mood)
    }

    static func empty(for date: Date = Date(), calendar: Calendar = .current) -> CompanionDailyState {
        CompanionDailyState(
            dateKey: EmotionalDayKey.string(from: date, calendar: calendar),
            mood: nil
        )
    }
}

struct ClosingCapsule: Codable, Equatable, Identifiable {
    let id: String
    let dateKey: String
    let createdAt: Date
    let messageIndex: Int
    let earnedAmount: Double
    let currencyCode: CurrencyCode?
    let workProgress: Double
    let wishProgress: Double?
    let wishID: UUID?
    let wishTitle: String?
    let companionID: String
    let mood: DailyMood?
    let tone: EmotionalTonePack
    var revealsSalary: Bool

    var messageKey: String {
        let messages: [EmotionalTonePack: [String]] = [
            .gentle: [
                "今天已经很努力了，剩下的时间留给自己。",
                "辛苦被好好收进今天，明天再慢慢来。",
                "今天的每一步，都在靠近想要的生活。"
            ],
            .dryHumor: [
                "今日工作已保存，可以安全退出。",
                "今天也成功把时间兑换成了小快乐。",
                "工位留在公司，快乐记得带走。"
            ],
            .spicy: [
                "今天的班到此为止，别让工作追到门外。",
                "够了，今天已经给工作很多面子了。",
                "准时收工不是逃跑，是边界感。"
            ]
        ]
        let values = messages[tone] ?? messages[.gentle]!
        return values[messageIndex % values.count]
    }
}

struct EngagementState: Codable, Equatable {
    var selectedCompanionID: String
    var tone: EmotionalTonePack
    var dailyState: CompanionDailyState
    var capsules: [ClosingCapsule]

    enum CodingKeys: String, CodingKey {
        case selectedCompanionID
        case tone
        case dailyState
        case inventory
        case capsules
        // Retired v1 fields remain decodable so older local and CloudKit payloads migrate safely.
        case purpose
        case completedCapsuleCount
        case viewedStoryChapterCount
    }

    static let defaultValue = EngagementState(
        selectedCompanionID: CompanionProfile.defaultValue.id,
        tone: .gentle,
        dailyState: .empty(),
        capsules: []
    )

    init(
        selectedCompanionID: String,
        tone: EmotionalTonePack,
        dailyState: CompanionDailyState,
        capsules: [ClosingCapsule]
    ) {
        self.selectedCompanionID = CompanionProfile.catalog.contains { $0.id == selectedCompanionID }
            ? selectedCompanionID
            : CompanionProfile.defaultValue.id
        self.tone = tone
        self.dailyState = dailyState
        self.capsules = Array(capsules.prefix(400))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedCompanionID: try container.decodeIfPresent(
                String.self,
                forKey: .selectedCompanionID
            ) ?? CompanionProfile.defaultValue.id,
            tone: try container.decodeIfPresent(EmotionalTonePack.self, forKey: .tone) ?? .gentle,
            dailyState: try container.decodeIfPresent(
                CompanionDailyState.self,
                forKey: .dailyState
            ) ?? .empty(),
            capsules: try container.decodeIfPresent([ClosingCapsule].self, forKey: .capsules) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedCompanionID, forKey: .selectedCompanionID)
        try container.encode(tone, forKey: .tone)
        try container.encode(dailyState, forKey: .dailyState)
        try container.encode(capsules, forKey: .capsules)
    }

    var selectedCompanion: CompanionProfile {
        CompanionProfile.catalog.first { $0.id == selectedCompanionID } ?? .defaultValue
    }

    mutating func prepareDay(for date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let dateKey = EmotionalDayKey.string(from: date, calendar: calendar)
        guard dailyState.dateKey != dateKey else { return }
        dailyState = CompanionDailyState(dateKey: dateKey, mood: nil)
    }
}

enum EmotionalDayKey {
    static func string(from date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
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

struct WeeklyPayDay: Equatable, Identifiable {
    let date: Date
    let dateKey: String
    let earnedAmount: Double
    let scheduledAmount: Double
    let kind: SalaryDayKind
    let isFuture: Bool
    let isToday: Bool

    var id: String { dateKey }

    var progress: Double {
        guard scheduledAmount > 0 else { return 0 }
        return min(1, max(0, earnedAmount / scheduledAmount))
    }
}

struct WeeklyPayReport: Equatable {
    let weekStart: Date
    let weekEnd: Date
    let days: [WeeklyPayDay]
    let earnedAmount: Double
    let projectedAmount: Double
    let paidDayCount: Int
    let totalWorkdays: Int

    var progress: Double {
        guard projectedAmount > 0 else { return 0 }
        return min(1, max(0, earnedAmount / projectedAmount))
    }
}

enum SalaryBadgeFamily: String, CaseIterable, Identifiable {
    case paydayProgress
    case wish
    case calendar
    case journal
    case overtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paydayProgress: L10n.t("开薪进度")
        case .wish: L10n.t("愿望足迹")
        case .calendar: L10n.t("日历收藏")
        case .journal: L10n.t("手账排班")
        case .overtime: L10n.t("加班时光")
        }
    }
}

struct SalaryBadge: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let progress: Double

    var isUnlocked: Bool {
        progress >= 1
    }

    var family: SalaryBadgeFamily {
        switch id {
        case "first-payday", "workweek-earned", "month-quarter", "month-halfway", "month-three-quarter", "month-finish":
            return .paydayProgress
        case "payday-direction", "goal-halfway", "goal-sprint", "goal-reached":
            return .wish
        case "calendar-note", "calendar-journal", "schedule-owner", "schedule-master", "schedule-director", "paid-leave", "rest-planner":
            return .journal
        case let value where value.hasPrefix("calendar-"):
            return .calendar
        default:
            return .overtime
        }
    }

    var artworkName: String {
        "achievement_\(id.replacingOccurrences(of: "-", with: "_"))_v1"
    }

    init(id: String, title: String, subtitle: String, icon: String, progress: Double, isUnlocked: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.progress = isUnlocked ? 1 : min(1, max(0, progress))
    }
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
