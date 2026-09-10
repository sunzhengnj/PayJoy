import Foundation
import SwiftUI

enum AppTheme {
    private static let preferencesKey = "payjoy.app.preferences"
    private static let selectedThemeKey = "payjoy.app.selected.theme"

    static var current: AppVisualTheme {
        if let screenshotTheme = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_THEME"]
            .flatMap(AppVisualTheme.init(rawValue:)) {
            return screenshotTheme
        }
        if let cachedTheme = UserDefaults.standard.string(forKey: selectedThemeKey)
            .flatMap(AppVisualTheme.init(rawValue:)) {
            return cachedTheme
        }
        if let cachedTheme = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .string(forKey: selectedThemeKey)
            .flatMap(AppVisualTheme.init(rawValue:)) {
            return cachedTheme
        }
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            return preferences.selectedTheme
        }
        if let data = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            return preferences.selectedTheme
        }
        return .classic
    }

    static var paper: Color {
        switch current {
        case .classic: Color(hex: 0xFFF8E8)
        case .pink: Color(hex: 0xFFF0F6)
        case .luckyCat: Color(hex: 0xFFF2ED)
        case .midnight: Color(hex: 0x0B1020)
        }
    }

    static var cream: Color {
        switch current {
        case .classic: Color(hex: 0xFFFDF6)
        case .pink: Color(hex: 0xFFF9FC)
        case .luckyCat: Color(hex: 0xFFFFF4)
        case .midnight: Color(hex: 0x151D33)
        }
    }

    static var coin: Color {
        switch current {
        case .classic: Color(hex: 0xFFD33D)
        case .pink: Color(hex: 0xFF9CC4)
        case .luckyCat: Color(hex: 0xFFD86A)
        case .midnight: Color(hex: 0x4FC0AB)
        }
    }

    static var orange: Color {
        switch current {
        case .classic: Color(hex: 0xFF9F1C)
        case .pink: Color(hex: 0xFF5F94)
        case .luckyCat: Color(hex: 0xF2705B)
        case .midnight: Color(hex: 0xFF758F)
        }
    }

    static var ink: Color {
        current == .midnight ? Color(hex: 0xEDF4FF) : Color(hex: 0x1C1C1C)
    }

    static var outline: Color {
        current == .midnight ? Color(hex: 0x526079) : ink
    }

    static var shadow: Color {
        current == .midnight ? Color.black : ink
    }

    static var textGray: Color {
        current == .midnight ? Color(hex: 0xB2BED4) : Color(hex: 0x555555)
    }

    static var softSurface: Color {
        current == .midnight ? Color(hex: 0x202A44) : .white
    }

    static var tabBarBackground: Color {
        current == .midnight ? Color(hex: 0x11182B) : Color(hex: 0xFFFDF7)
    }
    static var muted: Color {
        switch current {
        case .classic: Color(hex: 0x8A7F6A)
        case .pink: Color(hex: 0x8A6D7A)
        case .luckyCat: Color(hex: 0x8C7366)
        case .midnight: Color(hex: 0x8290AA)
        }
    }

    static var divider: Color {
        switch current {
        case .classic: Color(hex: 0xD8C7A4)
        case .pink: Color(hex: 0xE8BFD0)
        case .luckyCat: Color(hex: 0xEBC9BC)
        case .midnight: Color(hex: 0x34415F)
        }
    }

    static var red: Color {
        current == .midnight ? Color(hex: 0xFF9A9A) : Color(hex: 0xB4232F)
    }
    static let green = Color(hex: 0x5EC27F)

    static let pagePadding: CGFloat = 16
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14

    enum Fonts {
        static let comicTitle = "HannotateSC-W7"
        static let comicSubtitle = "HannotateSC-W7"
    }

    static var proCardBackground: Color {
        switch current {
        case .classic: Color(hex: 0xFFE7A3)
        case .pink: Color(hex: 0xFFE1ED)
        case .luckyCat: Color(hex: 0xFFE1D8)
        case .midnight: Color(hex: 0x1A2940)
        }
    }

    static var highlightCardBackground: Color {
        switch current {
        case .classic: Color(hex: 0xFFF1A8)
        case .pink: Color(hex: 0xFFE5EF)
        case .luckyCat: Color(hex: 0xFFF0BF)
        case .midnight: Color(hex: 0x203654)
        }
    }

    static var accentGradientStart: Color {
        switch current {
        case .classic: Color(hex: 0xFFE16B)
        case .pink: Color(hex: 0xFFC4D8)
        case .luckyCat: Color(hex: 0xFFE5D8)
        case .midnight: Color(hex: 0x2F8F86)
        }
    }

    static var heroWorkerAsset: String {
        switch current {
        case .classic: "worker_at_desk_v1"
        case .pink: "pink_worker_at_desk_v1"
        case .luckyCat: "lucky_cat_worker_at_desk_v1"
        case .midnight: "midnight_worker_at_desk_v1"
        }
    }

    static var salaryReportHeroAsset: String {
        salaryReportHeroAsset(for: current)
    }

    static func salaryReportHeroAsset(for theme: AppVisualTheme) -> String {
        switch theme {
        case .classic: "pro_report_classic_hero"
        case .pink: "pro_report_pink_hero"
        case .luckyCat: "pro_report_lucky_cat_hero"
        case .midnight: "pro_report_midnight_hero"
        }
    }

    static var moyuWorkerAsset: String {
        switch current {
        case .classic: "moyu_chair_worker_redraw_v1"
        case .pink: "pink_moyu_chair_worker_v1"
        case .luckyCat: "lucky_cat_moyu_chair_worker_v1"
        case .midnight: "midnight_moyu_worker_v1"
        }
    }

    static var proWorkerAsset: String {
        switch current {
        case .classic: "pro_sunglasses_worker_redraw_v1"
        case .pink: "pink_pro_worker_v1"
        case .luckyCat: "lucky_cat_pro_worker_v1"
        case .midnight: "midnight_stats_worker_v1"
        }
    }

    static var proPaywallWorkerAsset: String {
        switch current {
        case .classic: "pro_sunglasses_worker_redraw_v1"
        case .pink: "pink_pro_worker_v1"
        case .luckyCat: "lucky_cat_paywall_worker_v1"
        case .midnight: "midnight_worker_at_desk_v1"
        }
    }

    static var statsCoinWorkerAsset: String {
        switch current {
        case .classic: "stats_coin_worker_redraw_v1"
        case .pink: "pink_stats_coin_worker_v1"
        case .luckyCat: "lucky_cat_stats_coin_worker_v1"
        case .midnight: "midnight_stats_worker_v1"
        }
    }

    static var statsTargetWorkerAsset: String {
        switch current {
        case .classic: "stats_target_worker_original_v1"
        case .pink: "pink_stats_target_worker_v1"
        case .luckyCat: "lucky_cat_stats_target_worker_v1"
        case .midnight: "midnight_stats_worker_v1"
        }
    }

    static var personalGoalWorkerAsset: String {
        switch current {
        case .classic: "payday_goal_worker_original_v1"
        case .pink: "pink_profile_avatar_target_v1"
        case .luckyCat: "lucky_cat_profile_avatar_crown_v2"
        case .midnight: "midnight_stats_worker_v1"
        }
    }

    static var paydayRocketAsset: String {
        switch current {
        case .classic: "payday_rocket_classic_v1"
        case .pink: "payday_rocket_pink_v1"
        case .luckyCat: "payday_rocket_lucky_cat_v1"
        case .midnight: "payday_rocket_midnight_v1"
        }
    }

    static var statsHeaderWorkerAsset: String {
        switch current {
        case .classic: "pro_sunglasses_worker_redraw_v1"
        case .pink: "pink_pro_worker_v1"
        case .luckyCat: "lucky_cat_peek_worker_v1"
        case .midnight: "midnight_stats_worker_v1"
        }
    }

    static var overtimeSummaryWorkerAsset: String {
        switch current {
        case .classic: "classic_overtime_summary_worker_v1"
        case .pink: "overtime_summary_worker_v1"
        case .luckyCat: "lucky_cat_overtime_summary_worker_v1"
        case .midnight: "midnight_overtime_worker_v1"
        }
    }

    static func avatarBackground(for assetName: String) -> Color {
        if assetName.hasPrefix("pink_") {
            return Color(hex: 0xFFD7E8)
        }
        if assetName.hasPrefix("lucky_cat_") {
            return Color(hex: 0xFFF0BF)
        }
        if assetName.hasPrefix("classic_") || assetName.hasPrefix("profile_avatar_") {
            return current == .midnight ? Color(hex: 0x253552) : Color(hex: 0xDDF3F6)
        }
        return cream
    }

    static var cornerWorkerAsset: String {
        switch current {
        case .classic: "cat_corner_redraw_v1"
        case .pink: "pink_peek_worker_v1"
        case .luckyCat: "lucky_cat_peek_worker_v1"
        case .midnight: "midnight_overtime_worker_v1"
        }
    }

    static var heroArtworkScale: CGFloat {
        switch current {
        case .luckyCat: 1.14
        case .midnight: 1.08
        default: 1
        }
    }

    static var heroArtworkYOffset: CGFloat {
        switch current {
        case .luckyCat: 18
        case .midnight: 8
        default: -2
        }
    }

    static var heroSectionHeight: CGFloat {
        switch current {
        case .luckyCat: 138
        case .midnight: 132
        default: 118
        }
    }

    static var cardArtworkScale: CGFloat {
        switch current {
        case .luckyCat: 1.2
        case .midnight: 1.08
        default: 1
        }
    }
}

enum PrivacyText {
    static let hiddenCount = "•••"

    static var maskedMoney: String {
        maskedMoney(currencySymbol: SalaryCurrency.defaultSymbol)
    }

    static var maskedCompactMoney: String {
        maskedMoney
    }

    static var perSecond: String {
        perSecondText("••••", currencySymbol: SalaryCurrency.defaultSymbol)
    }

    static func maskedMoney(currencySymbol: String) -> String {
        "\(SalaryCurrency.normalized(currencySymbol))••••"
    }

    static func money(_ value: Double, hidden: Bool, currencySymbol: String = SalaryCurrency.defaultSymbol) -> String {
        hidden ? maskedMoney(currencySymbol: currencySymbol) : value.moneyText(currencySymbol: currencySymbol)
    }

    static func compactMoney(_ value: Double, hidden: Bool, currencySymbol: String = SalaryCurrency.defaultSymbol) -> String {
        hidden ? maskedMoney(currencySymbol: currencySymbol) : value.compactMoneyText(currencySymbol: currencySymbol)
    }

    static func perSecond(_ value: Double, hidden: Bool, currencySymbol: String = SalaryCurrency.defaultSymbol) -> String {
        let amount = hidden ? "••••" : String(format: "%.4f", value)
        return perSecondText(amount, currencySymbol: currencySymbol)
    }

    private static func perSecondText(_ amount: String, currencySymbol: String) -> String {
        L10n.t("≈ ¥%@ / 秒", amount).replacingOccurrences(of: "¥", with: SalaryCurrency.normalized(currencySymbol))
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension Double {
    var moneyText: String {
        moneyText(currencySymbol: SalaryCurrency.defaultSymbol)
    }

    func moneyText(currencySymbol: String) -> String {
        let formatter = NumberFormatter()
        let currencyCode = SalaryCurrency.code(for: currencySymbol)
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.rawValue
        formatter.currencySymbol = currencyCode.displaySymbol
        formatter.maximumFractionDigits = currencyCode.fractionDigits
        formatter.minimumFractionDigits = currencyCode.fractionDigits
        formatter.locale = Locale(identifier: L10n.currentMarket.localeIdentifier)
        let zero = currencyCode.fractionDigits == 0 ? "0" : "0.00"
        return formatter.string(from: NSNumber(value: self)) ?? "\(currencyCode.displaySymbol)\(zero)"
    }

    var compactMoneyText: String {
        compactMoneyText(currencySymbol: SalaryCurrency.defaultSymbol)
    }

    func compactMoneyText(currencySymbol: String) -> String {
        let formatter = NumberFormatter()
        let currencyCode = SalaryCurrency.code(for: currencySymbol)
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: L10n.currentMarket.localeIdentifier)
        formatter.maximumFractionDigits = currencyCode.fractionDigits
        formatter.minimumFractionDigits = 0
        return currencyCode.displaySymbol + (formatter.string(from: NSNumber(value: self)) ?? "0")
    }
}

extension TimeInterval {
    var countdownText: String {
        let total = max(0, Int(self))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

extension Date {
    var localizedDateText: String {
        let locale = Locale(identifier: L10n.currentMarket.localeIdentifier)
        return formatted(.dateTime.locale(locale).year().month().day())
    }
}
