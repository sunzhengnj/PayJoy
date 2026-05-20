import SwiftUI

enum AppTheme {
    static let paper = Color(hex: 0xFFF8E8)
    static let cream = Color(hex: 0xFFFDF6)
    static let coin = Color(hex: 0xFFD33D)
    static let orange = Color(hex: 0xFF9F1C)
    static let ink = Color(hex: 0x1C1C1C)
    static let textGray = Color(hex: 0x555555)
    static let muted = Color(hex: 0x8A7F6A)
    static let divider = Color(hex: 0xD8C7A4)
    static let red = Color(hex: 0xFF6B6B)
    static let green = Color(hex: 0x5EC27F)

    static let pagePadding: CGFloat = 16
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14

    enum Fonts {
        static let comicTitle = "HannotateSC-W7"
        static let comicSubtitle = "HannotateSC-W7"
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: self)) ?? "¥0.00"
    }

    var compactMoneyText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return "¥" + (formatter.string(from: NSNumber(value: self)) ?? "0")
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
