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
                        Text("今日已赚")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.72))
                        Text(context.state.earned.moneyText)
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("下班倒计时")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.72))
                        Text(context.state.remainingText)
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        WidgetPNGImage(name: "widget_worker_at_desk")
                            .frame(width: 62, height: 42)
                            .clipped()
                        VStack(alignment: .leading, spacing: 5) {
                            Text("≈ ¥\(String(format: "%.4f", context.state.perSecond)) / 秒")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(WidgetColors.coin)
                            WidgetProgress(progress: context.state.progress)
                                .frame(height: 8)
                        }
                    }
                }
            } compactLeading: {
                Text("开薪中")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.coin)
            } compactTrailing: {
                HStack(spacing: 5) {
                    Text(context.state.earned.compactMoneyText)
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
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 13) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("今日已赚")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                    Text(state.earned.compactMoneyText)
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
                    Text("≈ ¥\(String(format: "%.4f", state.perSecond)) / 秒")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.coin)
                        .lineLimit(1)
                }
                .frame(width: 104, alignment: .leading)

                Spacer(minLength: 76)
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 12)

            ActivitySpeechBubble(text: "正在努力\n赚钱中...")
                .frame(width: 86, height: 50)
                .offset(x: -10, y: -50)

            WidgetPNGImage(name: "widget_worker_at_desk")
                .frame(width: 122, height: 82)
                .offset(x: 5, y: 14)
                .clipped()
        }
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 104)
        .widgetAccentable(false)
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
                    .stroke(WidgetColors.ink, lineWidth: 1.3)
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
