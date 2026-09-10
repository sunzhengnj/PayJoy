import SwiftUI
import UIKit

private extension AppVisualTheme {
    var reportTitle: String {
        switch self {
        case .classic: L10n.t("元气工资报告")
        case .pink: L10n.t("粉桃工资报告")
        case .luckyCat: L10n.t("喵喵工资报告")
        case .midnight: L10n.t("午夜工资报告")
        }
    }

    var reportAssetName: String {
        AppTheme.salaryReportHeroAsset(for: self)
    }

    var reportAccent: Color {
        switch self {
        case .classic: Color(hex: 0xF7B916)
        case .pink: Color(hex: 0xFF84B5)
        case .luckyCat: Color(hex: 0xF3AA46)
        case .midnight: Color(hex: 0x4FC0AB)
        }
    }

    var reportSurface: Color {
        switch self {
        case .classic: Color(hex: 0xFFF2C2)
        case .pink: Color(hex: 0xFFE0EB)
        case .luckyCat: Color(hex: 0xFFE9D4)
        case .midnight: Color(hex: 0x1A2940)
        }
    }
}

struct ProSalaryReportEntryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let summary: SalaryMonthSummary
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String

    var body: some View {
        ZStack(alignment: .leading) {
            AssetImage(name: AppTheme.salaryReportHeroAsset, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 178)
                .clipped()

            LinearGradient(
                colors: [
                    Color(hex: 0xFFF5DD).opacity(0.98),
                    Color(hex: 0xFFF5DD).opacity(0.9),
                    Color(hex: 0xFFF5DD).opacity(0.15)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.t("工资报告"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(entryCardMuted)

                Text(L10n.t("这个月的努力，有一份好看的答案。"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(entryCardInk)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 230 : 250, alignment: .leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text(PrivacyText.money(summary.earnedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(entryCardInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                HStack(spacing: 5) {
                    Text(L10n.t("跟随主题生成专属报告"))
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.black))
                }
                .font(.caption.weight(.black))
                .foregroundStyle(entryCardInk)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(AppTheme.coin)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 270 : 178)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.6)
        }
        .shadow(color: AppTheme.shadow.opacity(0.14), radius: 1, x: 3, y: 3)
        .accessibilityElement(children: .combine)
    }

    private var entryCardInk: Color {
        Color(hex: 0x181A1F)
    }

    private var entryCardMuted: Color {
        Color(hex: 0x625D54)
    }
}

struct ProSalaryReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var showsSharePoster: Bool
    private let reportThemeOverride: AppVisualTheme?

    init(
        initialStyle: AppVisualTheme? = nil,
        showsSharePosterInitially: Bool = false
    ) {
        _showsSharePoster = State(initialValue: showsSharePosterInitially)
        reportThemeOverride = initialStyle
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                heroCard
                styleInsight
                sharePosterButton
                trendCard
                annualOverview
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 32)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .defaultScrollAnchor(.top)
        .navigationTitle(L10n.t("工资报告"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSharePoster = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.black))
                }
                .accessibilityLabel(L10n.t("生成分享海报"))
            }
        }
        .sheet(isPresented: $showsSharePoster) {
            SalaryReportSharePosterSheet(
                style: selectedStyle,
                monthTitle: monthTitle,
                amountText: PrivacyText.money(
                    currentSummary.earnedAmount,
                    hidden: false,
                    currencySymbol: appState.settings.currencySymbol
                ),
                comparisonText: comparisonText,
                insight: shareInsight
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.paper)
        }
        .transaction { transaction in
            guard appState.preferences.reduceMotion || accessibilityReduceMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var currentSummary: SalaryMonthSummary {
        appState.salaryMonthSummary(for: appState.now)
    }

    private var previousMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: appState.now) ?? appState.now
    }

    private var previousSummary: SalaryMonthSummary {
        appState.salaryMonthSummary(for: previousMonthDate)
    }

    private var yearPeriod: PeriodEarnings {
        appState.periodEarnings(for: .year)
    }

    private var months: [SalaryReportMonth] {
        (0..<6).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .month, value: -offset, to: appState.now) else {
                return nil
            }
            return SalaryReportMonth(date: date, summary: appState.salaryMonthSummary(for: date))
        }
    }

    private var selectedStyle: AppVisualTheme {
        reportThemeOverride ?? appState.preferences.selectedTheme
    }

    private var reportInk: Color {
        selectedStyle == .midnight ? Color(hex: 0xEDF4FF) : Color(hex: 0x171717)
    }

    private var reportMutedInk: Color {
        selectedStyle == .midnight ? Color(hex: 0xB2BED4) : Color(hex: 0x5E5A50)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 7) {
                        reportMonthLabel
                        reportThemeBadge
                    }
                } else {
                    HStack {
                        reportMonthLabel
                        Spacer()
                        reportThemeBadge
                    }
                }

                Text(selectedStyle.reportTitle)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(reportInk)

                Text(PrivacyText.money(currentSummary.earnedAmount, hidden: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(reportInk)
                    .minimumScaleFactor(0.58)
                    .lineLimit(1)

                Text(comparisonText)
                    .font(.caption.weight(.black))
                    .foregroundStyle(reportInk)
            }
            .padding(16)

            AssetImage(name: selectedStyle.reportAssetName, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 222)
                .clipped()
                .id(selectedStyle)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .background(selectedStyle.reportSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(reportInk.opacity(0.82), lineWidth: 1.8)
        }
        .shadow(color: selectedStyle.reportAccent.opacity(0.2), radius: 0, x: 4, y: 4)
    }

    private var reportMonthLabel: some View {
        Text(monthTitle)
            .font(.caption.weight(.black))
            .foregroundStyle(reportMutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var reportThemeBadge: some View {
        Text(selectedStyle.title)
            .font(.caption2.weight(.black))
            .foregroundStyle(reportInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(selectedStyle.reportAccent)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(reportInk, lineWidth: 1))
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private var styleInsight: some View {
        switch selectedStyle {
        case .classic:
            ReportInsightCard(
                icon: "bolt.fill",
                title: L10n.t("本月能量"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: L10n.t("每一个工作日，都在给钱包充电。"),
                progress: currentSummary.progress,
                accent: selectedStyle.reportAccent
            )
        case .pink:
            ReportInsightCard(
                icon: "heart.fill",
                title: L10n.t("本月桃气"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: comparisonDetail,
                progress: currentSummary.progress,
                accent: selectedStyle.reportAccent
            )
        case .luckyCat:
            ReportInsightCard(
                icon: "pawprint.fill",
                title: L10n.t("本月好运"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: L10n.t("每一笔收入，都在稳稳靠近你。"),
                progress: currentSummary.progress,
                accent: selectedStyle.reportAccent
            )
        case .midnight:
            ReportInsightCard(
                icon: "moon.stars.fill",
                title: L10n.t("深夜进度"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: L10n.t("夜色里的专注，也在变成收入。"),
                progress: currentSummary.progress,
                accent: selectedStyle.reportAccent
            )
        }
    }

    private var trendCard: some View {
        ComicCard(background: AppTheme.cream, padding: 14) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("近 6 个月工资趋势"))
                            .font(.headline.weight(.black))
                        Text(L10n.t("看看努力是怎样一点点积累起来的。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(selectedStyle.reportAccent)
                }

                SalaryReportBarChart(
                    months: months,
                    accent: selectedStyle.reportAccent,
                    hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                    currencySymbol: appState.settings.currencySymbol
                )
            }
        }
    }

    private var sharePosterButton: some View {
        Button {
            showsSharePoster = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(reportInk)
                    .frame(width: 44, height: 44)
                    .background(selectedStyle.reportAccent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(reportInk.opacity(0.82), lineWidth: 1.2))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("生成分享海报"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(reportInk)
                    Text(L10n.t("把这个月的努力，发成一张战报。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(reportMutedInk)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(reportInk)
            }
            .padding(13)
            .background(selectedStyle.reportSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(reportInk.opacity(0.72), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.t("预览后可通过系统分享"))
    }

    private var annualOverview: some View {
        ComicCard(background: selectedStyle.reportSurface, padding: 0) {
            VStack(spacing: 0) {
                SalaryReportMetricRow(
                    title: L10n.t("本年累计已赚"),
                    value: PrivacyText.money(yearPeriod.earned, hidden: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol),
                    ink: reportInk,
                    mutedInk: reportMutedInk
                )
                Divider().overlay(reportInk.opacity(0.16))
                SalaryReportMetricRow(
                    title: L10n.t("本月预计收入"),
                    value: PrivacyText.money(currentSummary.projectedAmount, hidden: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol),
                    ink: reportInk,
                    mutedInk: reportMutedInk
                )
                Divider().overlay(reportInk.opacity(0.16))
                SalaryReportMetricRow(
                    title: L10n.t("本月计薪日"),
                    value: L10n.format("%@ 天", "\(currentSummary.paidDayCount)"),
                    ink: reportInk,
                    mutedInk: reportMutedInk
                )
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentLanguage.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter.string(from: appState.now)
    }

    private var comparisonRatio: Double? {
        let previousTotal = previousSummary.earnedAmount > 0
            ? previousSummary.earnedAmount
            : previousSummary.projectedAmount
        guard previousTotal > 0 else { return nil }
        return (currentSummary.projectedAmount - previousTotal) / previousTotal
    }

    private var comparisonValue: String {
        guard let comparisonRatio else { return L10n.t("正在积累") }
        return String(format: "%+.0f%%", comparisonRatio * 100)
    }

    private var comparisonText: String {
        guard let comparisonRatio else { return L10n.t("第一份报告正在积累中") }
        if abs(comparisonRatio) < 0.005 {
            return L10n.t("按当前计划，与上月基本持平")
        }
        let percentage = String(format: "%.0f%%", abs(comparisonRatio) * 100)
        return comparisonRatio >= 0
            ? L10n.format("按当前计划，预计比上月多 %@", percentage)
            : L10n.format("按当前计划，预计比上月少 %@", percentage)
    }

    private var comparisonDetail: String {
        guard let comparisonRatio else { return L10n.t("继续使用后，就能看到每月变化。") }
        if abs(comparisonRatio) < 0.005 {
            return L10n.t("这个月正在按计划稳稳推进。")
        }
        return comparisonRatio >= 0
            ? L10n.t("这个月的钱包正在稳稳升级。")
            : L10n.t("这个月还没结束，继续把进度追回来。")
    }

    private var journeyTitle: String {
        appState.personalGoal == nil ? L10n.t("本月旅程") : L10n.t("目标旅程")
    }

    private var journeyDetail: String {
        if let goal = appState.personalGoal, let progress = appState.personalGoalProgress {
            if progress.progress >= 1 {
                return L10n.format("%@ 已经达成，给自己一点奖励吧。", goal.title)
            }
            return L10n.format("再工作 %@ 天，离 %@ 又近一步。", "\(progress.estimatedWorkdaysRemaining)", goal.title)
        }
        return L10n.t("设定一个目标，让每一天的工资都有目的地。")
    }

    private var shareInsight: SalaryReportShareInsight {
        switch selectedStyle {
        case .classic:
            SalaryReportShareInsight(
                title: L10n.t("本月能量"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: L10n.t("每一个工作日，都在给钱包充电。"),
                progress: currentSummary.progress
            )
        case .pink:
            SalaryReportShareInsight(
                title: L10n.t("本月战绩"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: comparisonDetail,
                progress: currentSummary.progress
            )
        case .luckyCat:
            SalaryReportShareInsight(
                title: L10n.t("本月好运"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: L10n.t("每一笔收入，都在稳稳靠近你。"),
                progress: currentSummary.progress
            )
        case .midnight:
            SalaryReportShareInsight(
                title: L10n.t("深夜进度"),
                value: String(format: "%.0f%%", currentSummary.progress * 100),
                detail: L10n.t("夜色里的专注，也在变成收入。"),
                progress: currentSummary.progress
            )
        }
    }
}

struct SalaryReportShareInsight {
    let title: String
    let value: String
    let detail: String
    let progress: Double
}

private struct SalaryReportSharePosterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let style: AppVisualTheme
    let monthTitle: String
    let amountText: String
    let comparisonText: String
    let insight: SalaryReportShareInsight

    @State private var showsAmount = false
    @State private var shareItem: SalaryReportShareItem?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    privacyControl

                    SalaryReportSharePoster(
                        style: style,
                        monthTitle: monthTitle,
                        amountText: amountText,
                        comparisonText: comparisonText,
                        insight: insight,
                        showsAmount: showsAmount
                    )
                    .frame(maxWidth: 360)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: AppTheme.shadow.opacity(0.18), radius: 1, x: 4, y: 4)

                    Text(L10n.t("海报将以高清图片导出，分享前可再次确认。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, 104)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("分享工资战报"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("取消")) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                shareButton
            }
            .sheet(item: $shareItem) { item in
                SalaryReportActivityView(activityItems: [item.url])
                    .presentationDetents([.medium, .large])
            }
            .alert(
                L10n.t("暂时无法生成海报"),
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button(L10n.t("好"), role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .task {
                #if DEBUG
                guard AppState.isScreenshotMode else { return }
                if ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SHARE_SHOW_AMOUNT"] == "1" {
                    showsAmount = true
                }
                guard ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_AUTO_SHARE"] == "1" else { return }
                try? await Task.sleep(nanoseconds: 650_000_000)
                exportPoster()
                #endif
            }
        }
    }

    private var privacyControl: some View {
        HStack(spacing: 11) {
            Image(systemName: showsAmount ? "eye.fill" : "eye.slash.fill")
                .font(.body.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 40, height: 40)
                .background(style.reportAccent)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("显示具体金额"))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text(L10n.t("默认关闭，分享时更安心"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }

            Spacer()

            Toggle("", isOn: $showsAmount)
                .labelsHidden()
                .tint(style.reportAccent)
                .accessibilityLabel(L10n.t("显示具体金额"))
                .accessibilityValue(showsAmount ? L10n.t("已开启") : L10n.t("未开启"))
        }
        .padding(12)
        .background(AppTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.4)
        }
    }

    private var shareButton: some View {
        Button {
            exportPoster()
        } label: {
            Label(L10n.t("生成高清海报并分享"), systemImage: "square.and.arrow.up.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(style.reportAccent)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.6)
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.pagePadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AppTheme.paper.opacity(0.96))
    }

    @MainActor
    private func exportPoster() {
        let poster = SalaryReportSharePoster(
            style: style,
            monthTitle: monthTitle,
            amountText: amountText,
            comparisonText: comparisonText,
            insight: insight,
            showsAmount: showsAmount
        )
        .frame(width: 360, height: 480)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3

        guard let image = renderer.uiImage, let data = image.pngData() else {
            exportError = L10n.t("请稍后再试。")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClockJoy-Salary-Report-\(style.rawValue).png")

        do {
            try data.write(to: url, options: .atomic)
            shareItem = SalaryReportShareItem(url: url)
        } catch {
            exportError = L10n.t("请稍后再试。")
        }
    }
}

private struct SalaryReportSharePoster: View {
    let style: AppVisualTheme
    let monthTitle: String
    let amountText: String
    let comparisonText: String
    let insight: SalaryReportShareInsight
    let showsAmount: Bool

    private var ink: Color {
        style == .midnight ? Color(hex: 0xEDF4FF) : Color(hex: 0x171717)
    }

    private var mutedInk: Color {
        style == .midnight ? Color(hex: 0xB2BED4) : Color(hex: 0x5E5A50)
    }

    private var paper: Color { style.reportSurface }

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 360

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6 * unit) {
                    HStack {
                        Text(L10n.appDisplayName)
                            .font(.system(size: 10 * unit, weight: .black, design: .rounded))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 9 * unit)
                            .padding(.vertical, 5 * unit)
                            .background(style.reportAccent)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(ink, lineWidth: 1.1 * unit))

                        Spacer()

                        Text(monthTitle)
                            .font(.system(size: 10 * unit, weight: .black, design: .rounded))
                            .foregroundStyle(mutedInk)
                    }

                    Text(style.reportTitle)
                        .font(.system(size: 23 * unit, weight: .black, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(showsAmount ? amountText : L10n.t("本月收入，稳稳到账"))
                        .font(.system(size: (showsAmount ? 34 : 25) * unit, weight: .black, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    Text(comparisonText)
                        .font(.system(size: 10 * unit, weight: .black, design: .rounded))
                        .foregroundStyle(mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(15 * unit)
                .frame(height: 132 * unit)

                AssetImage(name: style.reportAssetName, contentMode: .fill)
                    .frame(width: proxy.size.width, height: 200 * unit)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        Text(style.title)
                            .font(.system(size: 10 * unit, weight: .black, design: .rounded))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 9 * unit)
                            .padding(.vertical, 5 * unit)
                            .background(style.reportAccent)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(ink, lineWidth: unit))
                            .padding(10 * unit)
                    }

                VStack(alignment: .leading, spacing: 8 * unit) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(insight.title)
                            .font(.system(size: 12 * unit, weight: .black, design: .rounded))
                            .foregroundStyle(mutedInk)
                        Spacer()
                        Text(insight.value)
                            .font(.system(size: 23 * unit, weight: .black, design: .rounded))
                            .foregroundStyle(ink)
                    }

                    Text(insight.detail)
                        .font(.system(size: 11 * unit, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    GeometryReader { progressProxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(paper)
                            Capsule()
                                .fill(style.reportAccent)
                                .frame(
                                    width: max(
                                        10 * unit,
                                        progressProxy.size.width * CGFloat(min(1, max(0, insight.progress)))
                                    )
                                )
                        }
                        .overlay(Capsule().stroke(ink, lineWidth: unit))
                    }
                    .frame(height: 10 * unit)

                    HStack {
                        Text(L10n.t("由 ClockJoy 开薪生成"))
                        Spacer()
                        Text(L10n.t("让每一份努力都有回响"))
                    }
                    .font(.system(size: 8.5 * unit, weight: .black, design: .rounded))
                    .foregroundStyle(mutedInk)
                }
                .padding(.horizontal, 15 * unit)
                .padding(.vertical, 11 * unit)
                .frame(height: 148 * unit)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(style.reportSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 24 * unit, style: .continuous)
                    .stroke(ink, lineWidth: 2 * unit)
            }
        }
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("工资报告分享海报预览"))
    }
}

private struct SalaryReportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SalaryReportActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct SalaryReportMonth: Identifiable {
    let date: Date
    let summary: SalaryMonthSummary

    var id: Date { date }
}

private struct ReportInsightCard: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let progress: Double
    let accent: Color

    var body: some View {
        ComicCard(background: AppTheme.cream, padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 42, height: 42)
                        .background(accent)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                        Text(value)
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                }

                Text(detail)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.softSurface)
                        Capsule()
                            .fill(accent)
                            .frame(width: max(12, proxy.size.width * CGFloat(min(1, max(0, progress)))))
                    }
                    .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.2))
                }
                .frame(height: 13)
            }
        }
    }
}

private struct SalaryReportBarChart: View {
    let months: [SalaryReportMonth]
    let accent: Color
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String

    private var maximum: Double {
        max(1, months.map(\.summary.earnedAmount).max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(months) { month in
                VStack(spacing: 6) {
                    Text(PrivacyText.compactMoney(month.summary.earnedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(accent.opacity(month.id == months.last?.id ? 1 : 0.48))
                        .frame(height: max(14, 102 * CGFloat(month.summary.earnedAmount / maximum)))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(AppTheme.outline.opacity(0.6), lineWidth: 1)
                        }

                    Text(monthLabel(month.date))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textGray)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 148, alignment: .bottom)
        .accessibilityElement(children: .contain)
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentLanguage.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }
}

private struct SalaryReportMetricRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let value: String
    let ink: Color
    let mutedInk: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                metricTitle
                Spacer()
                metricValue
            }
            VStack(alignment: .leading, spacing: 5) {
                metricTitle
                metricValue
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private var metricTitle: some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(mutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var metricValue: some View {
        Text(value)
            .font(.subheadline.weight(.black))
            .foregroundStyle(ink)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.72)
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
    }
}
