import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WidgetColors {
    private static let preferencesKey = "payjoy.app.preferences"

    static var current: AppVisualTheme {
        if let screenshotTheme = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_THEME"]
            .flatMap(AppVisualTheme.init(rawValue:)) {
            return screenshotTheme
        }
        if let data = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            return preferences.selectedTheme
        }
        return .classic
    }

    static var paper: Color { paper(for: current) }
    static var cream: Color { cream(for: current) }
    static var coin: Color { coin(for: current) }
    static var ink: Color {
        current == .midnight ? Color(hex: 0xEDF4FF) : Color(hex: 0x1C1C1C)
    }
    static var outline: Color {
        current == .midnight ? Color(hex: 0x526079) : ink
    }
    static var shadow: Color {
        current == .midnight ? Color.black : ink
    }
    static var muted: Color {
        switch current {
        case .classic: Color(hex: 0x6E654F)
        case .pink: Color(hex: 0x7A6570)
        case .luckyCat: Color(hex: 0x7D6559)
        case .midnight: Color(hex: 0xA7B4CB)
        }
    }
    static var divider: Color {
        switch current {
        case .classic: Color(hex: 0xE5D4B3)
        case .pink: Color(hex: 0xE8BFD0)
        case .luckyCat: Color(hex: 0xEBC9BC)
        case .midnight: Color(hex: 0x34415F)
        }
    }

    static func paper(for theme: AppVisualTheme) -> Color {
        switch theme {
        case .classic: Color(hex: 0xFFF8E8)
        case .pink: Color(hex: 0xFFF0F6)
        case .luckyCat: Color(hex: 0xFFF2ED)
        case .midnight: Color(hex: 0x0B1020)
        }
    }

    static func cream(for theme: AppVisualTheme) -> Color {
        switch theme {
        case .classic: Color(hex: 0xFFFDF6)
        case .pink: Color(hex: 0xFFF9FC)
        case .luckyCat: Color(hex: 0xFFFFF4)
        case .midnight: Color(hex: 0x151D33)
        }
    }

    static func coin(for theme: AppVisualTheme) -> Color {
        switch theme {
        case .classic: Color(hex: 0xFFD33D)
        case .pink: Color(hex: 0xFF9CC4)
        case .luckyCat: Color(hex: 0xFFD86A)
        case .midnight: Color(hex: 0x4FC0AB)
        }
    }

    static func smallMoyuWorkerAsset(for theme: AppVisualTheme = current) -> String {
        switch theme {
        case .classic: "widget_moyu_chair_worker_small"
        case .pink: "pink_widget_moyu_chair_worker_small"
        case .luckyCat: "lucky_widget_moyu_chair_worker_small_v2"
        case .midnight: "midnight_widget_moyu"
        }
    }

    static func moyuWorkerAsset(for theme: AppVisualTheme = current) -> String {
        switch theme {
        case .classic: "widget_moyu_chair_worker"
        case .pink: "pink_widget_moyu_chair_worker"
        case .luckyCat: "lucky_widget_moyu_chair_worker_v2"
        case .midnight: "midnight_widget_worker"
        }
    }

    static func liveWorkerAsset(for theme: AppVisualTheme = current) -> String {
        switch theme {
        case .classic: "widget_desk_worker_original"
        case .pink: "pink_widget_peek_worker"
        case .luckyCat: "lucky_widget_peek_worker_v2"
        case .midnight: "midnight_widget_overtime"
        }
    }

    static func artworkScale(for theme: AppVisualTheme = current) -> CGFloat {
        switch theme {
        case .luckyCat: 1.2
        case .midnight: 1.08
        default: 1
        }
    }
}

struct WidgetPNGImage: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                WidgetAssetFallback(name: name)
            }
            #else
            Image(name, bundle: .main)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: contentMode)
            #endif
        }
        .widgetAccentable(false)
    }
}

private struct WidgetAssetFallback: View {
    let name: String

    var body: some View {
        if name.contains("lucky") {
            LuckyCatFallbackIllustration()
        } else if name.contains("midnight") {
            OriginalWorkerIllustration(compact: true)
                .colorMultiply(Color(hex: 0x4FC0AB))
        } else if name.contains("pink") {
            OriginalWorkerIllustration(compact: true)
                .colorMultiply(Color(hex: 0xFFB4D2))
        } else {
            OriginalWorkerIllustration(compact: true)
        }
    }
}

private struct LuckyCatFallbackIllustration: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                CoinSymbol()
                    .frame(width: 12, height: 12)
                    .offset(x: coinOffsets[index].x, y: coinOffsets[index].y)
            }

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0xD48A5B))
                .frame(width: 86, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(WidgetColors.outline, lineWidth: 1.2))
                .offset(y: 38)

            Circle()
                .fill(Color(hex: 0xFFF7EA))
                .frame(width: 60, height: 60)
                .overlay(Circle().stroke(WidgetColors.outline, lineWidth: 1.6))

            HStack(spacing: 28) {
                Triangle()
                    .fill(Color(hex: 0xFFB23D))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-18))
                Triangle()
                    .fill(Color(hex: 0xFFB23D))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(18))
            }
            .offset(y: -28)

            HStack(spacing: 14) {
                ArcSmile()
                    .stroke(WidgetColors.outline, lineWidth: 1.6)
                    .frame(width: 13, height: 8)
                ArcSmile()
                    .stroke(WidgetColors.outline, lineWidth: 1.6)
                    .frame(width: 13, height: 8)
            }
            .offset(y: -3)

            Circle()
                .fill(Color(hex: 0xE95F4B))
                .frame(width: 5, height: 5)
                .offset(y: 4)

            Circle()
                .fill(WidgetColors.coin)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(WidgetColors.outline, lineWidth: 1.2))
                .offset(y: 32)
        }
        .frame(width: 112, height: 88)
    }

    private var coinOffsets: [CGPoint] {
        [
            CGPoint(x: -48, y: -18),
            CGPoint(x: 50, y: -22),
            CGPoint(x: -58, y: 22),
            CGPoint(x: 60, y: 18),
            CGPoint(x: 38, y: 42)
        ]
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ArcSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

struct OriginalWorkerIllustration: View {
    var compact = false

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                CoinSymbol()
                    .frame(width: compact ? 10 : 15, height: compact ? 10 : 15)
                    .rotationEffect(.degrees(Double(index) * 22))
                    .offset(x: coinOffsets[index].x * (compact ? 0.72 : 1), y: coinOffsets[index].y * (compact ? 0.72 : 1))
            }

            RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                .fill(Color(hex: 0xB9BBC2))
                .frame(width: compact ? 54 : 82, height: compact ? 42 : 62)
                .rotationEffect(.degrees(-2))
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                        .stroke(WidgetColors.outline, lineWidth: compact ? 1.2 : 1.7)
                }
                .offset(x: compact ? -18 : -28, y: compact ? 12 : 18)

            workerBody
                .offset(x: compact ? 18 : 28, y: compact ? 20 : 26)

            workerHead
                .offset(x: compact ? 16 : 24, y: compact ? -6 : -8)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: 0xD9B382))
                .frame(width: compact ? 98 : 142, height: compact ? 8 : 12)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(WidgetColors.outline, lineWidth: compact ? 0.9 : 1.2))
                .offset(y: compact ? 42 : 62)
        }
        .frame(width: compact ? 118 : 172, height: compact ? 96 : 142)
    }

    private var workerHead: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFDDBB))
                .frame(width: compact ? 34 : 48, height: compact ? 34 : 48)
                .overlay(Circle().stroke(WidgetColors.outline, lineWidth: compact ? 1.3 : 1.8))

            Capsule()
                .fill(WidgetColors.ink)
                .frame(width: compact ? 32 : 46, height: compact ? 18 : 25)
                .offset(y: compact ? -12 : -17)

            HStack(spacing: compact ? 9 : 12) {
                Circle().fill(WidgetColors.ink).frame(width: compact ? 3 : 4)
                Circle().fill(WidgetColors.ink).frame(width: compact ? 3 : 4)
            }
            .offset(y: compact ? 1 : 2)

            Capsule()
                .fill(Color(hex: 0xFF7765))
                .frame(width: compact ? 10 : 14, height: compact ? 4 : 5)
                .offset(y: compact ? 10 : 14)
        }
    }

    private var workerBody: some View {
        RoundedRectangle(cornerRadius: compact ? 13 : 18, style: .continuous)
            .fill(Color(hex: 0x1D6DAE))
            .frame(width: compact ? 54 : 78, height: compact ? 42 : 58)
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 13 : 18, style: .continuous)
                    .stroke(WidgetColors.outline, lineWidth: compact ? 1.3 : 1.8)
            }
    }

    private var coinOffsets: [CGPoint] {
        [
            CGPoint(x: -62, y: -26),
            CGPoint(x: 72, y: -34),
            CGPoint(x: 80, y: 10),
            CGPoint(x: -76, y: 18),
            CGPoint(x: 48, y: 42)
        ]
    }
}

struct SunglassesWorkerIllustration: View {
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                CoinSymbol()
                    .frame(width: 12, height: 12)
                    .offset(x: sparkleOffsets[index].x, y: sparkleOffsets[index].y)
            }

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: 0x1D6DAE))
                .frame(width: 78, height: 62)
                .rotationEffect(.degrees(-8))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(WidgetColors.outline, lineWidth: 1.8))
                .offset(y: 24)

            Circle()
                .fill(Color(hex: 0xFFDDBB))
                .frame(width: 54, height: 54)
                .overlay(Circle().stroke(WidgetColors.outline, lineWidth: 1.9))
                .offset(y: -6)

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6).fill(WidgetColors.ink).frame(width: 18, height: 11)
                RoundedRectangle(cornerRadius: 6).fill(WidgetColors.ink).frame(width: 18, height: 11)
            }
            .rotationEffect(.degrees(-5))
            .offset(y: -7)

            Capsule()
                .fill(Color(hex: 0xFF7765))
                .frame(width: 16, height: 5)
                .offset(y: 9)
        }
        .frame(width: 122, height: 104)
    }

    private var sparkleOffsets: [CGPoint] {
        [
            CGPoint(x: -44, y: -34),
            CGPoint(x: 46, y: -42),
            CGPoint(x: -58, y: 8),
            CGPoint(x: 54, y: 12),
            CGPoint(x: -28, y: 46),
            CGPoint(x: 36, y: 46)
        ]
    }
}

struct CoinSymbol: View {
    var body: some View {
        Circle()
            .fill(WidgetColors.coin)
            .overlay(Circle().stroke(WidgetColors.outline, lineWidth: 1.2))
            .overlay {
                Text("¥")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
            }
            .shadow(color: WidgetColors.shadow.opacity(0.14), radius: 0, x: 1, y: 1)
    }
}
