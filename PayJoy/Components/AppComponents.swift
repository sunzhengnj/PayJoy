import SwiftUI
import UIKit

struct ComicCard<Content: View>: View {
    var background: Color = AppTheme.cream
    var radius: CGFloat = AppTheme.cardRadius
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.ink, lineWidth: 1.6)
            }
            .shadow(color: AppTheme.ink.opacity(0.14), radius: 1, x: 3, y: 3)
    }
}

struct ComicProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.55))
                Capsule()
                    .fill(AppTheme.coin)
                    .frame(width: max(12, proxy.size.width * CGFloat(min(1, max(0, progress)))))
            }
            .overlay {
                Capsule().stroke(AppTheme.ink, lineWidth: 1.4)
            }
        }
        .frame(height: 13)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.coin)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                        .stroke(AppTheme.ink, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }
}

struct AssetImage: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = UIImage(named: name) ?? UIImage(named: "\(name).png") {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Color.clear
        }
    }
}

struct SpeechBubble: View {
    let text: String
    var isYellow = false
    var tailX: CGFloat = 0.22

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 17)
            .background(bubbleFill)
            .clipShape(ComicBubbleShape(tailX: tailX))
            .overlay(ComicBubbleShape(tailX: tailX).stroke(AppTheme.ink, lineWidth: 1.8))
            .shadow(color: AppTheme.ink.opacity(0.08), radius: 0, x: 2, y: 2)
    }

    private var bubbleFill: Color {
        isYellow ? Color(hex: 0xFFF1A8) : Color.white
    }
}

struct ComicBubbleShape: Shape {
    var tailX: CGFloat = 0.22
    var radius: CGFloat = 15
    var tailWidth: CGFloat = 20
    var tailHeight: CGFloat = 15

    func path(in rect: CGRect) -> Path {
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(0, rect.height - tailHeight)
        )
        let tailCenter = min(max(rect.width * tailX, radius + tailWidth / 2), rect.width - radius - tailWidth / 2)
        let tailLeft = bubbleRect.minX + tailCenter - tailWidth / 2
        let tailRight = bubbleRect.minX + tailCenter + tailWidth / 2
        let tailTip = CGPoint(x: bubbleRect.minX + tailCenter - 5, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.minY))
        path.addLine(to: CGPoint(x: bubbleRect.maxX - radius, y: bubbleRect.minY))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY + radius), control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY))
        path.addLine(to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.maxX - radius, y: bubbleRect.maxY), control: CGPoint(x: bubbleRect.maxX, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: tailRight, y: bubbleRect.maxY))
        path.addLine(to: tailTip)
        path.addLine(to: CGPoint(x: tailLeft, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.maxY))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY - radius), control: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: bubbleRect.minX + radius, y: bubbleRect.minY), control: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY))
        path.closeSubpath()
        return path
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case stats
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .stats: "统计"
        case .profile: "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .stats: "chart.bar.fill"
        case .profile: "person.fill"
        }
    }
}

struct ComicTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(Color.clear)
                .shadow(color: AppTheme.ink.opacity(0.18), radius: 0, x: 0, y: 3)
                .offset(y: 4)

            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(Color(hex: 0xFFFDF7))
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.78))
                        .frame(height: 3)
                        .padding(.horizontal, 36)
                        .padding(.top, 7)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .stroke(AppTheme.ink, lineWidth: 2.4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.18), lineWidth: 1)
                        .padding(6)
                }

            HStack(spacing: 7) {
                ForEach(AppTab.allCases) { tab in
                    ComicTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.70)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(8)
        }
        .frame(height: 78)
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}

struct LiveActivityControlCard: View {
    let isAvailable: Bool
    let isActive: Bool
    let statusTitle: String
    let errorMessage: String?
    let action: () -> Void

    var body: some View {
        ComicCard(background: AppTheme.cream.opacity(0.78), padding: 12) {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "sparkles.rectangle.stack.fill" : "rectangle.inset.filled.and.person.filled")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(isAvailable ? AppTheme.coin : AppTheme.divider)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1.2))

                VStack(alignment: .leading, spacing: 3) {
                    Text("锁屏 / 灵动岛")
                        .font(.subheadline.weight(.heavy))
                    Text(statusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(errorMessage == nil ? AppTheme.textGray : AppTheme.red)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Button(action: action) {
                    Text(isActive ? "结束" : "开启")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(isAvailable ? AppTheme.coin : AppTheme.divider)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.ink, lineWidth: 1.1))
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable)
                .opacity(isAvailable ? 1 : 0.55)
            }
        }
    }

    private var statusText: String {
        if let errorMessage {
            return errorMessage
        }
        return isAvailable ? "\(statusTitle)，可在系统实时活动中展示。" : "当前系统未开放实时活动。"
    }
}

private struct ComicTabButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.ink)
                        .offset(x: 2.5, y: 3.5)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xFFE16B), AppTheme.coin],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.ink, lineWidth: 2)
                }

                VStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 24 : 22, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .frame(height: 24)
                    Text(tab.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .offset(y: isSelected ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .opacity(isSelected ? 1 : 0.78)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}
