import SwiftUI
import WidgetKit

struct PayJoyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: EarningsSnapshot
    let settings: SalarySettings
}

struct PayJoyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PayJoyWidgetEntry {
        entry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PayJoyWidgetEntry) -> Void) {
        completion(entry(for: Date()))
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
        let snapshot = SalaryCalculator().snapshot(
            for: date,
            settings: settings,
            overtimeDateKeys: store.loadOvertimeDays()
        )
        return PayJoyWidgetEntry(date: date, snapshot: snapshot, settings: settings)
    }
}

struct PayJoyEarningsWidget: Widget {
    let kind = "PayJoyEarningsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PayJoyWidgetProvider()) { entry in
            PayJoyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetColors.paper
                }
        }
        .configurationDisplayName("开薪实时收入")
        .description("不用打开 App，也能看到今天赚了多少。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PayJoyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PayJoyWidgetEntry

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
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Text("开薪中")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                WidgetPNGImage(name: "widget_pro_worker", contentMode: .fill)
                    .frame(width: 76, height: 52)
                    .offset(x: 8, y: 25)
                    .clipped()
            }
            .frame(height: 34)

            DividerLine()

            Text("今日已赚")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(WidgetColors.muted)
            Text(entry.snapshot.todayEarned.moneyText)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(WidgetColors.ink)
                .minimumScaleFactor(0.58)
                .lineLimit(1)
            Text("\(entry.snapshot.progress * 100, specifier: "%.1f")%")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(WidgetColors.ink)
            WidgetProgress(progress: entry.snapshot.progress)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var mediumWidget: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                Text("开薪! 努力搬砖中")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text("今日已赚")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.muted)
                Text(entry.snapshot.todayEarned.moneyText)
                    .font(.system(size: 33, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("≈ ¥\(String(format: "%.4f", entry.snapshot.earnedPerSecond)) / 秒")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
                    .lineLimit(1)
                WidgetProgress(progress: entry.snapshot.progress)
                Text("\(entry.snapshot.progress * 100, specifier: "%.1f")%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(WidgetColors.ink)
            }
            .frame(width: 148, alignment: .leading)

            ZStack(alignment: .bottom) {
                ForEach(0..<5, id: \.self) { index in
                    CoinSymbol()
                        .frame(width: 14, height: 14)
                        .offset(x: mediumSparkleOffsets[index].x, y: mediumSparkleOffsets[index].y)
                }
                WidgetPNGImage(name: "widget_worker_at_desk")
                    .frame(width: 166, height: 108)
                    .offset(x: 8, y: 12)
            }
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .bottom)
            .clipped()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var largeWidget: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日已赚")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                    Text(entry.snapshot.todayEarned.moneyText)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("≈ ¥\(String(format: "%.4f", entry.snapshot.earnedPerSecond)) / 秒")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.muted)
                }

                Divider()
                    .overlay(WidgetColors.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text("下班倒计时")
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
                    Text("今日进度")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                    Text("\(entry.snapshot.progress * 100, specifier: "%.1f")%")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(WidgetColors.ink)
                    WidgetProgress(progress: entry.snapshot.progress)
                        .frame(maxWidth: 190)
                }
                Spacer()
                ZStack(alignment: .topLeading) {
                    SpeechBadge(text: "马上下班，\n快乐加倍！")
                        .frame(width: 92, height: 54)
                        .offset(x: -14, y: 0)
                        .zIndex(3)
                    ForEach(0..<4, id: \.self) { index in
                        CoinSymbol()
                            .frame(width: 14, height: 14)
                            .offset(x: largeSparkleOffsets[index].x, y: largeSparkleOffsets[index].y)
                            .zIndex(1)
                    }
                    WidgetPNGImage(name: "widget_pro_worker")
                        .frame(width: 154, height: 112)
                        .offset(x: 18, y: 24)
                        .zIndex(2)
                }
                .frame(width: 158, height: 124)
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

    private var mediumSparkleOffsets: [CGPoint] {
        [
            CGPoint(x: -52, y: -34),
            CGPoint(x: 54, y: -40),
            CGPoint(x: -62, y: 2),
            CGPoint(x: 60, y: 12),
            CGPoint(x: 38, y: 43)
        ]
    }

    private var largeSparkleOffsets: [CGPoint] {
        [
            CGPoint(x: 94, y: 42),
            CGPoint(x: 122, y: 20),
            CGPoint(x: 42, y: 72),
            CGPoint(x: 136, y: 82)
        ]
    }
}

struct WidgetProgress: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xFFFDF6))
                Capsule()
                    .fill(WidgetColors.coin)
                    .frame(width: max(12, proxy.size.width * CGFloat(min(1, max(0, progress)))))
            }
            .overlay(Capsule().stroke(WidgetColors.ink.opacity(0.82), lineWidth: 1.4))
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
                    .stroke(WidgetColors.ink, lineWidth: 1.4)
            }
    }
}
