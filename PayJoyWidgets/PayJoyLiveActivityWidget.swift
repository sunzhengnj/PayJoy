import ActivityKit
import SwiftUI
import WidgetKit

struct PayJoyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PayJoyActivityAttributes.self) { context in
            PayJoyLockScreenActivityView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(WidgetColors.coin)
        } dynamicIsland: { context in
                DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("今日已赚"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        Text(PrivacyText.money(context.state.earned, hidden: context.state.hidesSensitiveAmounts, currencySymbol: context.state.currencySymbol))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.leading, 10)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(L10n.t("下班倒计时"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        Text(context.state.remainingText)
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.trailing, 10)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(PrivacyText.perSecond(context.state.perSecond, hidden: context.state.hidesSensitiveAmounts, currencySymbol: context.state.currencySymbol))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(WidgetColors.coin)
                            WidgetProgress(progress: context.state.progress)
                                .frame(height: 8)
                        }
                        LiveActivityWorkerImage(width: 62, height: 40, theme: context.state.visualTheme)
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Text(L10n.t("开薪中"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.coin)
            } compactTrailing: {
                HStack(spacing: 5) {
                    Text(PrivacyText.compactMoney(context.state.earned, hidden: context.state.hidesSensitiveAmounts, currencySymbol: context.state.currencySymbol))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    CoinSymbol()
                        .frame(width: 18, height: 18)
                }
            } minimal: {
                CoinSymbol()
                    .frame(width: 18, height: 18)
            }
        }
    }
}

struct PayJoyLockScreenActivityView: View {
    let state: PayJoyActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.t("今日已赚"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                Text(PrivacyText.compactMoney(state.earned, hidden: state.hidesSensitiveAmounts, currencySymbol: state.currencySymbol))
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                ActivityProgressBar(progress: state.progress, width: 78)
            }
            .frame(width: 116, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.13))
                .frame(width: 1, height: 66)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(state.progress * 100, specifier: "%.1f")%")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                ActivityProgressBar(progress: state.progress, width: 84)
                Text(PrivacyText.perSecond(state.perSecond, hidden: state.hidesSensitiveAmounts, currencySymbol: state.currencySymbol))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.coin)
                    .lineLimit(1)
            }
            .frame(width: 104, alignment: .leading)

            Spacer(minLength: 0)

            LiveActivitySideVisual(theme: state.visualTheme)
                .frame(width: 110)
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 104)
        .widgetAccentable(false)
    }
}

private struct LiveActivitySideVisual: View {
    let theme: AppVisualTheme

    var body: some View {
        LiveActivityWorkerImage(width: 108, height: 74, theme: theme)
    }
}

private struct LiveActivityWorkerImage: View {
    let width: CGFloat
    let height: CGFloat
    var theme: AppVisualTheme = WidgetColors.current

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WidgetColors.cream(for: theme).opacity(0.92),
                            WidgetColors.coin(for: theme).opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: WidgetColors.coin(for: theme).opacity(0.22), radius: 10, x: 0, y: 0)

            WidgetPNGImage(name: WidgetColors.liveWorkerAsset(for: theme), contentMode: .fit)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .scaleEffect(WidgetColors.artworkScale(for: theme))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ActivityProgressBar: View {
    let progress: Double
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.13))
            Capsule()
                .fill(WidgetColors.coin)
                .frame(width: max(12, width * CGFloat(min(1, max(0, progress)))))
        }
        .frame(width: width, height: 9)
        .overlay {
            Capsule().stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
    }
}

private struct ActivitySpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(WidgetColors.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(WidgetActivityBubbleShape())
            .overlay {
                WidgetActivityBubbleShape()
                    .stroke(WidgetColors.outline, lineWidth: 1.3)
            }
    }
}

private struct WidgetActivityBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tailHeight: CGFloat = 9
        let bubbleRect = rect.insetBy(dx: 0, dy: 0).offsetBy(dx: 0, dy: 0)
        let rounded = CGRect(
            x: bubbleRect.minX,
            y: bubbleRect.minY,
            width: bubbleRect.width,
            height: bubbleRect.height - tailHeight
        )
        var path = Path(roundedRect: rounded, cornerRadius: 10)
        let tailBaseY = rounded.maxY - 1
        path.move(to: CGPoint(x: rounded.maxX - 28, y: tailBaseY))
        path.addLine(to: CGPoint(x: rounded.maxX - 15, y: rect.maxY))
        path.addLine(to: CGPoint(x: rounded.maxX - 12, y: tailBaseY))
        path.closeSubpath()
        return path
    }
}
