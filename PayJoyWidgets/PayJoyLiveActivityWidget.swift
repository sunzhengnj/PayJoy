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
                        Text(context.state.isOffDuty == true ? L10n.t("休息中") : L10n.t("今日已赚"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        Text(
                            context.state.isOffDuty == true
                                ? L10n.t("这段时间归你")
                                : PrivacyText.money(context.state.earned, hidden: context.state.hidesSensitiveAmounts, currencySymbol: context.state.currencySymbol)
                        )
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.leading, 10)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(context.state.countdownTitle ?? L10n.t("下班倒计时"))
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
                            if context.state.isOffDuty == true {
                                Text(L10n.t("不着急，先好好休息"))
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(.white)
                                Text(L10n.t("工作先放一边。"))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(WidgetColors.coin)
                            } else if let title = context.state.goalTitle, let goalProgress = context.state.goalProgress {
                                Text(title)
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                WidgetProgress(progress: goalProgress)
                                    .frame(height: 8)
                                Text(context.state.goalCompletionText ?? context.state.goalRemainingText ?? "")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(WidgetColors.coin)
                                    .lineLimit(1)
                            } else {
                                Text(PrivacyText.perSecond(context.state.perSecond, hidden: context.state.hidesSensitiveAmounts, currencySymbol: context.state.currencySymbol))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(WidgetColors.coin)
                                WidgetProgress(progress: context.state.progress)
                                    .frame(height: 8)
                            }
                        }
                        LiveActivityWorkerImage(width: 62, height: 40, theme: context.state.visualTheme)
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Text(context.state.isOffDuty == true ? L10n.t("休息中") : L10n.t("开薪中"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.coin)
            } compactTrailing: {
                HStack(spacing: 5) {
                    Text(
                        context.state.isOffDuty == true
                            ? context.state.remainingText
                            : PrivacyText.compactMoney(context.state.earned, hidden: context.state.hidesSensitiveAmounts, currencySymbol: context.state.currencySymbol)
                    )
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    if context.state.isOffDuty != true {
                        CoinSymbol()
                            .frame(width: 18, height: 18)
                    }
                }
            } minimal: {
                if context.state.isOffDuty == true {
                    Text(L10n.t("休"))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.coin)
                } else {
                    CoinSymbol()
                        .frame(width: 18, height: 18)
                }
            }
        }
    }
}

struct PayJoyLockScreenActivityView: View {
    let state: PayJoyActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isOffDuty == true {
                offDutyView
            } else {
                earningsView
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 104)
        .widgetAccentable(false)
    }

    private var offDutyView: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.t("休息中"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                Text(state.countdownTitle ?? L10n.t("下次上班"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                Text(state.remainingText)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(L10n.t("不着急，先好好休息"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.coin)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LiveActivitySideVisual(theme: state.visualTheme)
                .frame(width: 120)
        }
    }

    private var earningsView: some View {
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
                if let title = state.goalTitle, let goalProgress = state.goalProgress {
                    Text(title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(goalProgress * 100, specifier: "%.0f")%")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    ActivityProgressBar(progress: goalProgress, width: 84)
                    Text(state.goalCompletionText ?? state.goalRemainingText ?? "")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.coin)
                        .lineLimit(1)
                } else {
                    Text("\(state.progress * 100, specifier: "%.1f")%")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    ActivityProgressBar(progress: state.progress, width: 84)
                    Text(PrivacyText.perSecond(state.perSecond, hidden: state.hidesSensitiveAmounts, currencySymbol: state.currencySymbol))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.coin)
                        .lineLimit(1)
                }
            }
            .frame(width: 104, alignment: .leading)

            Spacer(minLength: 0)

            LiveActivitySideVisual(theme: state.visualTheme)
                .frame(width: 110)
        }
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
