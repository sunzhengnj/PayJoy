import SwiftUI

struct WidgetColors {
    static let paper = Color(hex: 0xFFF8E8)
    static let cream = Color(hex: 0xFFFDF6)
    static let coin = Color(hex: 0xFFD33D)
    static let ink = Color(hex: 0x1C1C1C)
    static let muted = Color(hex: 0x6E654F)
    static let divider = Color(hex: 0xE5D4B3)
}

struct WidgetPNGImage: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .widgetAccentable(false)
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
                        .stroke(WidgetColors.ink, lineWidth: compact ? 1.2 : 1.7)
                }
                .offset(x: compact ? -18 : -28, y: compact ? 12 : 18)

            workerBody
                .offset(x: compact ? 18 : 28, y: compact ? 20 : 26)

            workerHead
                .offset(x: compact ? 16 : 24, y: compact ? -6 : -8)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: 0xD9B382))
                .frame(width: compact ? 98 : 142, height: compact ? 8 : 12)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(WidgetColors.ink, lineWidth: compact ? 0.9 : 1.2))
                .offset(y: compact ? 42 : 62)
        }
        .frame(width: compact ? 118 : 172, height: compact ? 96 : 142)
    }

    private var workerHead: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFDDBB))
                .frame(width: compact ? 34 : 48, height: compact ? 34 : 48)
                .overlay(Circle().stroke(WidgetColors.ink, lineWidth: compact ? 1.3 : 1.8))

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
                    .stroke(WidgetColors.ink, lineWidth: compact ? 1.3 : 1.8)
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
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(WidgetColors.ink, lineWidth: 1.8))
                .offset(y: 24)

            Circle()
                .fill(Color(hex: 0xFFDDBB))
                .frame(width: 54, height: 54)
                .overlay(Circle().stroke(WidgetColors.ink, lineWidth: 1.9))
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
            .overlay(Circle().stroke(WidgetColors.ink, lineWidth: 1.2))
            .overlay {
                Text("¥")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
            }
            .shadow(color: WidgetColors.ink.opacity(0.14), radius: 0, x: 1, y: 1)
    }
}
