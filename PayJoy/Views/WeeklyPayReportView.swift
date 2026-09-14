import SwiftUI

enum WeeklyPayReportCardStyle: Equatable {
    case regular
    case compact
}

struct WeeklyPayReportCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let report: WeeklyPayReport
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String
    let style: WeeklyPayReportCardStyle

    init(
        report: WeeklyPayReport,
        hidesSensitiveAmounts: Bool,
        currencySymbol: String,
        style: WeeklyPayReportCardStyle = .regular
    ) {
        self.report = report
        self.hidesSensitiveAmounts = hidesSensitiveAmounts
        self.currencySymbol = currencySymbol
        self.style = style
    }

    var body: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: style == .compact ? 11 : 14) {
            VStack(alignment: .leading, spacing: style == .compact ? 8 : 13) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.t("本周战报"))
                            .font(headerFont)
                            .foregroundStyle(AppTheme.ink)
                        if style == .regular {
                            Text(L10n.t("把这一周的每一秒，变成看得见的进度。"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 4)

                    if style == .regular && dynamicTypeSize < .xxLarge {
                        AssetImage(name: AppTheme.statsCoinWorkerAsset)
                            .frame(width: 82, height: 62)
                            .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottomTrailing)
                            .accessibilityHidden(true)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(PrivacyText.money(report.earnedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                        .font(.system(size: style == .compact ? 25 : 31, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    Text(L10n.t("本周已赚"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textGray)
                }

                WeeklyPayRhythmChart(days: report.days, compact: style == .compact)

                HStack(spacing: 8) {
                    Text(L10n.format("已计薪 %@ / %@ 天", "\(report.paidDayCount)", "\(report.totalWorkdays)"))
                    Spacer(minLength: 4)
                    Text(L10n.format("本周进度 %@", String(format: "%.0f%%", report.progress * 100)))
                }
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.textGray)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
    }

    private var headerFont: Font {
        style == .compact ? .subheadline.weight(.black) : .headline.weight(.black)
    }
}

private struct WeeklyPayRhythmChart: View {
    let days: [WeeklyPayDay]
    let compact: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(AppTheme.divider.opacity(0.32))
                .frame(height: 1)
                .padding(.horizontal, compact ? 18 : 24)
                .offset(y: compact ? 28 : 31)

            HStack(alignment: .top, spacing: 0) {
                ForEach(days) { day in
                    WeeklyPayRhythmNode(day: day, compact: compact)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, compact ? 5 : 9)
        .padding(.vertical, compact ? 7 : 9)
        .background(AppTheme.paper.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("本周每日计薪进度"))
    }
}

private struct WeeklyPayRhythmNode: View {
    let day: WeeklyPayDay
    let compact: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(weekdayTitle)
                .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded))
                .foregroundStyle(day.isToday ? AppTheme.ink : AppTheme.textGray)

            ZStack {
                Circle()
                    .fill(nodeFill)
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay {
                        Circle()
                            .stroke(day.isToday ? AppTheme.ink : trackColor, lineWidth: day.isToday ? 1.5 : 1)
                    }

                Image(systemName: statusIcon)
                    .font(.system(size: compact ? 8 : 9, weight: .black))
                    .foregroundStyle(iconColor)
            }

            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(.system(size: compact ? 10 : 11, weight: .black, design: .rounded))
                .foregroundStyle(day.isToday ? AppTheme.ink : AppTheme.textGray)
                .frame(height: 13)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(weekdayTitle) \(Calendar.current.component(.day, from: day.date))，\(day.kind.title)")
        .accessibilityValue("\(Int((day.progress * 100).rounded()))%")
    }

    private var weekdayTitle: String {
        let weekday = Calendar.current.component(.weekday, from: day.date)
        return Workday(rawValue: weekday)?.shortTitle ?? ""
    }

    private var nodeSize: CGFloat {
        day.isToday ? (compact ? 23 : 26) : (compact ? 18 : 21)
    }

    private var trackColor: Color {
        if day.isFuture { return AppTheme.divider.opacity(0.5) }
        if day.kind == .rest || day.kind == .unpaidLeave { return AppTheme.divider.opacity(0.7) }
        return AppTheme.divider.opacity(0.62)
    }

    private var nodeColor: Color {
        if day.isToday { return AppTheme.orange }
        if day.kind == .paidLeave { return Color(hex: 0x56A681) }
        if day.kind == .unpaidLeave { return AppTheme.textGray }
        return day.progress >= 1 ? AppTheme.coin : AppTheme.orange
    }

    private var nodeFill: Color {
        if day.isFuture { return AppTheme.softSurface }
        if day.kind == .rest || day.kind == .unpaidLeave { return AppTheme.paper }
        return nodeColor.opacity(day.isToday ? 0.2 : 0.15)
    }

    private var statusIcon: String {
        if day.isFuture { return "circle.fill" }
        switch day.kind {
        case .paidLeave:
            return "checkmark"
        case .rest:
            return "moon.fill"
        case .unpaidLeave:
            return "minus"
        case .normal:
            return day.progress >= 1 ? "checkmark" : "circle.fill"
        }
    }

    private var iconColor: Color {
        if day.isFuture || day.kind == .rest || day.kind == .unpaidLeave {
            return AppTheme.textGray
        }
        return nodeColor
    }
}
