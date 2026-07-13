import SwiftUI
import WidgetKit

struct PayJoyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: EarningsSnapshot
    let settings: SalarySettings
    let preferences: AppPreferences
}

struct PayJoyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PayJoyWidgetEntry {
        previewEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (PayJoyWidgetEntry) -> Void) {
        completion(context.isPreview ? previewEntry : entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PayJoyWidgetEntry>) -> Void) {
        let now = Date()
        let entries = stride(from: 0, through: 25, by: 5).compactMap { offset in
            Calendar.current.date(byAdding: .minute, value: offset, to: now).map(entry(for:))
        }
        completion(Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 300))))
    }

    private func entry(for date: Date) -> PayJoyWidgetEntry {
        let store = SettingsStore(defaults: UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard)
        let settings = store.load()
        let preferences = store.loadPreferences()
        let snapshot = SalaryCalculator().snapshot(
            for: date,
            settings: settings,
            overtimeDateKeys: store.loadOvertimeDays(),
            earlyLeaveDateKeys: store.loadEarlyLeaveDays()
        )
        return PayJoyWidgetEntry(date: date, snapshot: snapshot, settings: settings, preferences: preferences)
    }

    private var previewEntry: PayJoyWidgetEntry {
        PayJoyWidgetEntry(
            date: Date(),
            snapshot: EarningsSnapshot(
                todayEarned: 420.15,
                todayTotal: 460,
                earnedPerSecond: 0.0098,
                progress: 0.914,
                remainingToday: 39.85,
                secondsUntilOffWork: 1_860,
                status: .working
            ),
            settings: .defaultValue,
            preferences: .defaultValue
        )
    }
}

struct PayJoyEarningsWidget: Widget {
    let kind = "PayJoyEarningsWidgetV3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PayJoyWidgetProvider()) { entry in
            PayJoyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetColors.paper
                }
        }
        .configurationDisplayName(L10n.t("开薪实时收入"))
        .description(L10n.t("不用打开 App，也能看到今天赚了多少。"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PayJoyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PayJoyWidgetEntry

    private var hidesSensitiveAmounts: Bool {
        entry.preferences.hideSensitiveAmounts
    }

    private var currencySymbol: String {
        entry.settings.currencySymbol
    }

    var body: some View {
        ZStack {
            WidgetColors.paper
            switch family {
            case .systemSmall:
                smallWidget
            case .systemLarge:
                largeWidget
            default:
                mediumWidget
            }
        }
        .foregroundStyle(WidgetColors.ink)
        .widgetAccentable(false)
        .unredacted()
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("开薪中"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(L10n.t("今日已赚"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetColors.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                WidgetPNGImage(name: WidgetColors.smallMoyuWorkerAsset(for: entry.preferences.selectedTheme), contentMode: .fit)
                    .frame(width: 48, height: 38)
                    .scaleEffect(WidgetColors.artworkScale(for: entry.preferences.selectedTheme), anchor: .trailing)
                    .accessibilityHidden(true)
            }

            Text(PrivacyText.money(entry.snapshot.todayEarned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(WidgetColors.ink)
                .minimumScaleFactor(0.56)
                .lineLimit(1)

            Text(PrivacyText.perSecond(entry.snapshot.earnedPerSecond, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(WidgetColors.ink)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            WidgetProgress(progress: entry.snapshot.progress)

            Text("\(entry.snapshot.progress * 100, specifier: "%.1f")%")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(WidgetColors.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var mediumWidget: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.t("开薪! 努力搬砖中"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(L10n.t("今日已赚"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.muted)
                Text(PrivacyText.money(entry.snapshot.todayEarned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                    .font(.system(size: 33, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(PrivacyText.perSecond(entry.snapshot.earnedPerSecond, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                WidgetProgress(progress: entry.snapshot.progress)
                Text("\(entry.snapshot.progress * 100, specifier: "%.1f")%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
            }
            .frame(width: 138, alignment: .leading)

            WidgetPNGImage(name: WidgetColors.moyuWorkerAsset(for: entry.preferences.selectedTheme), contentMode: .fit)
                .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 116, alignment: .center)
                .scaleEffect(1.08 * WidgetColors.artworkScale(for: entry.preferences.selectedTheme))
                .offset(x: 2, y: 6)
                .clipped()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var largeWidget: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("今日已赚"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                    Text(PrivacyText.money(entry.snapshot.todayEarned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(PrivacyText.perSecond(entry.snapshot.earnedPerSecond, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.muted)
                }

                Divider()
                    .overlay(WidgetColors.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("下班倒计时"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                    Text(entry.snapshot.secondsUntilOffWork.countdownText)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Divider()
                .overlay(WidgetColors.divider)
                .padding(.vertical, 14)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("今日进度"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                    Text("\(entry.snapshot.progress * 100, specifier: "%.1f")%")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                    WidgetProgress(progress: entry.snapshot.progress)
                        .frame(maxWidth: 190)
                }
                Spacer()
                WidgetPNGImage(name: WidgetColors.moyuWorkerAsset(for: entry.preferences.selectedTheme), contentMode: .fit)
                    .frame(width: 172, height: 150)
                    .scaleEffect(WidgetColors.artworkScale(for: entry.preferences.selectedTheme), anchor: .trailing)
                    .offset(x: -4, y: 14)
                .clipped()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var sparkleOffsets: [CGPoint] {
        [
            CGPoint(x: -44, y: -38),
            CGPoint(x: 38, y: -43),
            CGPoint(x: -58, y: 12),
            CGPoint(x: 50, y: 24)
        ]
    }

}

struct WidgetProgress: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetColors.cream)
                Capsule()
                    .fill(WidgetColors.coin)
                    .frame(width: max(12, proxy.size.width * CGFloat(min(1, max(0, progress)))))
            }
            .overlay(Capsule().stroke(WidgetColors.outline.opacity(0.82), lineWidth: 1.4))
        }
        .frame(height: 11)
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(WidgetColors.ink.opacity(0.72))
            .frame(height: 1.5)
    }
}

private struct SpeechBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(WidgetColors.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(WidgetColors.outline, lineWidth: 1.4)
            }
    }
}
