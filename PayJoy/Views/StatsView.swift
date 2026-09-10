import SwiftUI

struct StatsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedPeriod: StatsPeriod = .month
    @State private var isOvertimeSheetPresented = false
    @State private var overtimeMonthAnchor = Date()
    @State private var showsProSalaryReport = false
    @State private var showsSalaryReportMembershipPrompt = false
    @State private var showsSalaryReportPaywall = false
    @State private var showsActualSalaryHistory = false
    @State private var showsActualSalaryMembershipPrompt = false
    @State private var showsActualSalaryPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                statsHeader
                summaryCard
                salaryReportCard
                salaryAchievementCard
                weeklyPayReportCard
                salaryCalendarCard
                detailsCard
                overtimeCard
                exchangeCard
                targetCard
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 86)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .defaultScrollAnchor(isLowerScreenshot ? .bottom : .top)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showsProSalaryReport) {
            ProSalaryReportView()
        }
        .navigationDestination(isPresented: $showsActualSalaryHistory) {
            ActualSalaryHistoryView()
        }
        .membershipFeatureAlert(isPresented: $showsSalaryReportMembershipPrompt) {
            showsSalaryReportPaywall = true
        }
        .membershipFeatureAlert(isPresented: $showsActualSalaryMembershipPrompt) {
            showsActualSalaryPaywall = true
        }
        .fullScreenCover(isPresented: $showsSalaryReportPaywall) {
            ProPaywallSheet(context: .salaryReport)
        }
        .fullScreenCover(isPresented: $showsActualSalaryPaywall) {
            ProPaywallSheet()
        }
        .sheet(isPresented: $isOvertimeSheetPresented) {
            OvertimeRecordsSheet(
                monthAnchor: $overtimeMonthAnchor,
                reducesMotion: appState.preferences.reduceMotion,
                currentDate: appState.now,
                summaryProvider: { appState.overtimeSummary(forMonthContaining: $0) },
                addRecord: { startAt, endAt in
                    appState.saveOvertimeRecord(startAt: startAt, endAt: endAt)
                },
                updateRecord: { record, startAt, endAt in
                    appState.updateOvertimeRecord(id: record.id, startAt: startAt, endAt: endAt)
                },
                deleteRecord: { appState.removeOvertimeRecord(id: $0.id) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .transaction { transaction in
            guard prefersReducedMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var period: PeriodEarnings {
        appState.periodEarnings(for: selectedPeriod)
    }

    private var isLowerScreenshot: Bool {
        AppState.isScreenshotMode && ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] == "stats-lower"
    }

    private var breakdown: PeriodBreakdown {
        appState.periodBreakdown(for: selectedPeriod)
    }

    private var dailySalary: Double {
        SalaryCalculator().dailySalary(for: appState.settings)
    }

    private var workHours: Double {
        SalaryCalculator().workingSecondsPerDay(settings: appState.settings) / 3_600
    }

    private var hidesSensitiveAmounts: Bool {
        appState.preferences.hideSensitiveAmounts
    }

    private var currencySymbol: String {
        appState.settings.currencySymbol
    }

    private var currentMonthActualRecord: ActualSalaryRecord? {
        guard selectedPeriod == .month,
              let record = appState.actualSalaryRecord(for: appState.now),
              record.currencyCode == appState.settings.currencyCode else { return nil }
        return record
    }

    private var currentMonthEstimate: SalaryMonthSummary {
        appState.estimatedSalaryMonthSummary(for: appState.now)
    }

    private var currentYearActualSalaryCount: Int {
        let year = Calendar.current.component(.year, from: appState.now)
        return appState.actualSalaryRecords.filter {
            $0.currencyCode == appState.settings.currencyCode && $0.monthKey.hasPrefix("\(year)-")
        }.count
    }

    private var remainingTargetAmount: Double {
        max(0, period.projected - period.earned)
    }

    private var monthlyOvertimeSummary: OvertimeSummary {
        appState.overtimeSummary(forMonthContaining: appState.now)
    }

    private var statsHeader: some View {
        VStack(spacing: 12) {
            Text(L10n.t("统计"))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            if dynamicTypeSize.isAccessibilitySize {
                periodPicker
            } else {
                ZStack(alignment: .topTrailing) {
                    periodPicker

                    AssetImage(name: AppTheme.statsHeaderWorkerAsset)
                        .frame(width: 74, height: 54)
                        .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottom)
                        .offset(x: -32, y: -49)
                        .zIndex(2)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var periodPicker: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 6) {
                    ForEach(StatsPeriod.allCases) { period in
                        periodButton(period)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(StatsPeriod.allCases) { period in
                        periodButton(period)
                    }
                }
            }
        }
        .padding(4)
        .background(AppTheme.cream.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.5)
        }
        .shadow(color: AppTheme.shadow.opacity(0.09), radius: 0, x: 2, y: 2)
        .sensoryFeedback(.selection, trigger: selectedPeriod)
    }

    private func periodButton(_ period: StatsPeriod) -> some View {
        Button {
            withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)) {
                selectedPeriod = period
            }
        } label: {
            Text(period.title)
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 5 : 0)
                .background(selectedPeriod == period ? AppTheme.coin : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    if selectedPeriod == period {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: 1.3)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
        .accessibilityLabel(period.title)
        .accessibilityValue(selectedPeriod == period ? L10n.t("已选择") : L10n.t("未选择"))
        .accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appState.preferences.reduceMotion
    }

    private var summaryCard: some View {
        ComicCard(background: AppTheme.cream, radius: 20, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                if dynamicTypeSize.isAccessibilitySize {
                    summaryHeadline
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        summaryHeadline

                        StatsSummaryIllustration()
                            .frame(width: 146, height: 108)
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 3) {
                                progressTitle
                                progressValue
                            }
                        } else {
                            HStack {
                                progressTitle
                                Spacer()
                                progressValue
                            }
                        }
                    }

                    ComicProgressBar(progress: period.progress)
                }
                .padding(10)
                .background(AppTheme.paper.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.outline.opacity(0.9), lineWidth: 1.2)
                }

                if selectedPeriod != .today {
                    actualSalaryStatusRow
                }
            }
        }
        .padding(.top, 2)
    }

    private var progressTitle: some View {
        Text(L10n.t("\(selectedPeriod.title)进度"))
            .font(.caption.weight(.black))
            .foregroundStyle(AppTheme.textGray)
    }

    private var progressValue: some View {
        Text("\(period.progress * 100, specifier: "%.1f")%")
            .font(.headline.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .monospacedDigit()
    }

    private var summaryHeadline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                currentMonthActualRecord == nil
                    ? L10n.t("\(selectedPeriod.title)已赚")
                    : L10n.t("本月实际薪资")
            )
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)

            Text(PrivacyText.money(period.earned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                .font(.system(size: 37, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .minimumScaleFactor(0.62)
                .lineLimit(1)

            Text(summaryReferenceText)
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.textGray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryReferenceText: String {
        if currentMonthActualRecord != nil {
            return L10n.format(
                "已替换原预计 %@",
                PrivacyText.money(
                    currentMonthEstimate.projectedAmount,
                    hidden: hidesSensitiveAmounts,
                    currencySymbol: currencySymbol
                )
            )
        }
        if selectedPeriod == .year, currentYearActualSalaryCount > 0 {
            return L10n.format(
                "含 %@ 个月实际薪资 · 全年参考 %@",
                "\(currentYearActualSalaryCount)",
                PrivacyText.money(period.projected, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol)
            )
        }
        return L10n.t("预计 \(PrivacyText.money(period.projected, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))")
    }

    private var actualSalaryStatusRow: some View {
        Button {
            if appState.hasEffectivePro {
                showsActualSalaryHistory = true
            } else {
                showsActualSalaryMembershipPrompt = true
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("实际薪资"))
                        .font(.subheadline.weight(.black))
                    Text(actualSalaryStatusText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(L10n.t("管理"))
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 11)
                    .frame(minHeight: 36)
                    .background(AppTheme.coin)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
            }
            .foregroundStyle(AppTheme.ink)
            .padding(11)
            .background(AppTheme.softSurface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.outline.opacity(0.86), lineWidth: 1.1)
            }
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
        .accessibilityLabel("\(L10n.t("实际薪资"))，\(actualSalaryStatusText)，\(L10n.t("管理"))")
    }

    private var actualSalaryStatusText: String {
        if selectedPeriod == .year {
            return L10n.format("已记录 %@ 个月", "\(currentYearActualSalaryCount)")
        }
        if currentMonthActualRecord != nil {
            return L10n.t("本月已记录")
        }
        if appState.canEnterActualSalary(for: appState.now) {
            return L10n.t("本月待填写")
        }
        return L10n.t("可补录历史月份")
    }

    private var exchangeCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("换算一下，你已经赚到："))
                    .font(.headline.weight(.heavy))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ExchangeItem(image: "exchange_milk_tea_v1", title: L10n.t("奶茶"), amount: period.earned / 19, hidesSensitiveAmounts: hidesSensitiveAmounts)
                    ExchangeItem(image: "exchange_coffee_v1", title: L10n.t("咖啡"), amount: period.earned / 32, hidesSensitiveAmounts: hidesSensitiveAmounts)
                    ExchangeItem(image: "exchange_hotpot_v1", title: L10n.t("火锅"), amount: period.earned / 150, hidesSensitiveAmounts: hidesSensitiveAmounts)
                    ExchangeItem(image: "exchange_iphone_v1", title: "iPhone", amount: period.earned / 5999, hidesSensitiveAmounts: hidesSensitiveAmounts)
                }
            }
        }
    }

    private var salaryCalendarCard: some View {
        NavigationLink {
            SalaryCalendarView()
        } label: {
            ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("工资日历"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.t("逐日查看计薪快照，也能标记请假和休息。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(2)

                        HStack(spacing: 5) {
                            Text(L10n.t("打开日历"))
                                .font(.caption.weight(.black))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.black))
                        }
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(AppTheme.coin)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AssetImage(name: AppTheme.statsCoinWorkerAsset)
                        .frame(width: 112, height: 82)
                        .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottomTrailing)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(PayJoyPressStyle())
        .accessibilityLabel(L10n.t("打开工资日历"))
    }

    private var salaryAchievementCard: some View {
        SalaryAchievementCompactEntry(
            badges: appState.salaryBadges
        )
    }

    private var salaryReportCard: some View {
        Button {
            if appState.hasEffectivePro {
                showsProSalaryReport = true
            } else {
                showsSalaryReportMembershipPrompt = true
            }
        } label: {
            ProSalaryReportEntryCard(
                summary: appState.salaryMonthSummary(for: appState.now),
                hidesSensitiveAmounts: hidesSensitiveAmounts,
                currencySymbol: currencySymbol
            )
        }
        .buttonStyle(PayJoyPressStyle())
        .accessibilityLabel(L10n.t("查看工资报告"))
    }

    private var weeklyPayReportCard: some View {
        WeeklyPayReportCard(
            report: appState.weeklyPayReport,
            hidesSensitiveAmounts: hidesSensitiveAmounts,
            currencySymbol: currencySymbol,
            style: .compact
        )
    }

    private var overtimeCard: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.t("本月加班记录"))
                            .font(.headline.weight(.heavy))
                        Text(monthlyOvertimeSummary.hasRecords ? L10n.t("加班只统计时长，不计入收入。") : L10n.t("下班后或休息日，可在首页开始记录加班。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 6)

                    AssetImage(name: AppTheme.overtimeSummaryWorkerAsset)
                        .frame(width: 96, height: 74)
                        .accessibilityHidden(true)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    OvertimeSummaryMetric(title: L10n.t("记录数"), value: L10n.t("%@ 条", "\(monthlyOvertimeSummary.count)"))
                    OvertimeSummaryMetric(title: L10n.t("加班时长"), value: monthlyOvertimeSummary.totalSeconds.overtimeDurationText)
                    OvertimeSummaryMetric(title: L10n.t("进行中"), value: monthlyOvertimeSummary.hasActiveRecord ? L10n.t("是") : L10n.t("否"))
                }

                Button {
                    overtimeMonthAnchor = appState.now
                    isOvertimeSheetPresented = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "tablecells.fill")
                            .font(.system(size: 14, weight: .black))
                        Text(L10n.t("查看汇总表"))
                            .font(.subheadline.weight(.black))
                    }
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 11)
                    .background(AppTheme.coin)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: 1.2)
                    }
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
                .accessibilityLabel(L10n.t("查看加班汇总表"))
            }
        }
    }

    private var detailsCard: some View {
        ComicCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("计算明细"))
                    .font(.headline.weight(.heavy))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    StatsMetric(title: L10n.t("预计日薪"), value: PrivacyText.money(dailySalary, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                    StatsMetric(title: L10n.t("等效时薪"), value: workHours > 0 ? PrivacyText.compactMoney(dailySalary / workHours, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol) : "\(currencySymbol)0")
                    StatsMetric(title: L10n.t("当前状态"), value: appState.snapshot.status.title)
                    StatsMetric(title: L10n.t("还差目标"), value: PrivacyText.compactMoney(max(0, period.projected - period.earned), hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                }
                Divider().overlay(AppTheme.divider)
                HStack(spacing: 10) {
                    WorkdayPill(title: L10n.t("已完成"), value: L10n.t("%@ 天", String(format: "%.1f", breakdown.completedWorkdayEquivalent)))
                    WorkdayPill(title: L10n.t("总工作日"), value: L10n.t("%@ 天", "\(breakdown.totalWorkdays)"))
                    WorkdayPill(title: L10n.t("剩余"), value: L10n.t("%@ 天", "\(breakdown.remainingWorkdays)"))
                }
                ComicProgressBar(progress: breakdown.workdayProgress)
            }
        }
    }

    private var targetCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ComicCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("距离\(selectedPeriod.title)目标还差"))
                            .font(.headline.weight(.heavy))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(PrivacyText.money(remainingTargetAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                            .font(.title2.weight(.black))
                            .minimumScaleFactor(0.72)
                            .lineLimit(1)
                        Text(targetCaption)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ZStack(alignment: .bottomTrailing) {
                    ComicCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.t("距离\(selectedPeriod.title)目标还差"))
                                    .font(.headline.weight(.heavy))
                                Text(PrivacyText.money(remainingTargetAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                                    .font(.title2.weight(.black))
                                Text(targetCaption)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                            }
                            Spacer()
                            Color.clear.frame(width: 138, height: 74)
                        }
                        .frame(minHeight: 92)
                    }

                    SpeechBubble(text: targetBubbleText, isYellow: false, tailX: 0.52)
                        .frame(width: 142)
                        .offset(x: -10, y: -86)
                        .zIndex(4)

                    AssetImage(name: AppTheme.statsTargetWorkerAsset)
                        .frame(width: 134, height: 96)
                        .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottomTrailing)
                        .offset(x: -2, y: 15)
                        .zIndex(3)

                    AssetImage(name: "coin_pile_v1")
                        .frame(width: 82, height: 50)
                        .offset(x: -134, y: -5)
                        .zIndex(2)
                }
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
    }

    private var targetCaption: String {
        guard remainingTargetAmount > 0 else {
            return L10n.t("\(selectedPeriod.title)目标已达成，今天可以放心开心一下。")
        }

        switch selectedPeriod {
        case .today:
            switch appState.snapshot.status {
            case .beforeWork:
                return L10n.t("今天还没开工，开工后再慢慢回血。")
            case .working:
                return L10n.t("保持当前节奏，下班前还能继续回血。")
            case .lunchBreak:
                return L10n.t("午休先回血一点精神，回来继续开薪。")
            case .afterWork:
                return L10n.t("今日工作已结束，看看明天能不能再多一点。")
            case .restDay:
                return L10n.t("今天是休息日，目标会在工作日继续推进。")
            }
        case .month:
            return periodTargetCaption(periodName: "本月", finishName: "月末")
        case .year:
            return periodTargetCaption(periodName: "今年", finishName: "年底")
        }
    }

    private var targetBubbleText: String {
        guard remainingTargetAmount > 0 else {
            return L10n.t("\(selectedPeriod.title)目标达成！")
        }

        switch selectedPeriod {
        case .today:
            switch appState.snapshot.status {
            case .beforeWork:
                return L10n.t("准备开薪！")
            case .working:
                return L10n.t("离下班更近，也离到账更近！")
            case .lunchBreak:
                return L10n.t("午休暂停，回来继续！")
            case .afterWork:
                return L10n.t("今日到账，收工！")
            case .restDay:
                return L10n.t("休息日也要快乐！")
            }
        case .month:
            return periodTargetBubble(periodName: "本月", finishName: "月末")
        case .year:
            return periodTargetBubble(periodName: "今年", finishName: "年底")
        }
    }

    private func periodTargetCaption(periodName: String, finishName: String) -> String {
        let remainingWorkdays = max(0, breakdown.remainingWorkdays)
        switch remainingWorkdays {
        case 0:
            return L10n.t("\(periodName)工作日已结束，看看目标完成情况。")
        case 1:
            return L10n.t("\(periodName)只剩 1 个工作日，今天冲刺一下。")
        case 2...3:
            return L10n.t("\(periodName)还剩 \(remainingWorkdays) 个工作日，收尾阶段稳住。")
        default:
            return L10n.t("\(periodName)还剩 \(remainingWorkdays) 个工作日，按节奏继续攒进度。")
        }
    }

    private func periodTargetBubble(periodName: String, finishName: String) -> String {
        let remainingWorkdays = max(0, breakdown.remainingWorkdays)
        switch remainingWorkdays {
        case 0:
            return L10n.t("\(finishName)收官，看看战绩！")
        case 1:
            return L10n.t("最后 1 个工作日，冲！")
        case 2...5:
            return L10n.t("还剩 \(remainingWorkdays) 个工作日，稳住！")
        default:
            return L10n.t("\(periodName)剩 \(remainingWorkdays) 个工作日！")
        }
    }
}

private struct StatsSummaryIllustration: View {
    var body: some View {
        AssetImage(name: AppTheme.statsCoinWorkerAsset)
            .frame(width: 136, height: 112)
            .scaleEffect(1.08 * AppTheme.cardArtworkScale)
            .offset(x: 2, y: 8)
            .clipped()
    }
}

private struct StatsMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.subheadline.weight(.black))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.paper.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.85), lineWidth: 1)
        }
    }
}

private struct WorkdayPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.caption.weight(.black))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OvertimeSummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .minimumScaleFactor(0.68)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(AppTheme.paper.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.86), lineWidth: 1)
        }
    }
}

private struct OvertimeRecordsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Binding var monthAnchor: Date
    @State private var editingRecord: OvertimeRecord?
    @State private var isAddingRecord = false
    @State private var isCalendarExpanded = false
    @State private var selectedDayFilter: Date?
    let reducesMotion: Bool
    let currentDate: Date
    let summaryProvider: (Date) -> OvertimeSummary
    let addRecord: (Date, Date) -> Void
    let updateRecord: (OvertimeRecord, Date, Date?) -> Void
    let deleteRecord: (OvertimeRecord) -> Void

    private var calendar: Calendar { .current }
    private var summary: OvertimeSummary { summaryProvider(monthAnchor) }
    private var displayedRecords: [OvertimeRecord] {
        guard let selectedDayFilter else { return summary.records }
        return summary.records.filter { calendar.isDate($0.startAt, inSameDayAs: selectedDayFilter) }
    }
    private var displayedTotalSeconds: TimeInterval {
        displayedRecords.reduce(0) { $0 + $1.duration(until: currentDate) }
    }
    private var displayedHasActiveRecord: Bool {
        displayedRecords.contains { $0.isActive }
    }

    private var defaultNewRecordStart: Date {
        if let selectedDayFilter {
            if calendar.isDate(selectedDayFilter, inSameDayAs: currentDate) {
                return currentDate.addingTimeInterval(-60 * 60)
            }
            return date(on: selectedDayFilter, hour: 19, minute: 0)
        }
        if calendar.isDate(monthAnchor, equalTo: currentDate, toGranularity: .month) {
            return currentDate.addingTimeInterval(-60 * 60)
        }
        return date(on: monthAnchor, hour: 19, minute: 0)
    }

    private var defaultNewRecordEnd: Date {
        min(currentDate, defaultNewRecordStart.addingTimeInterval(60 * 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    monthSwitcher
                    totalsCard
                    recordsCard
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("加班汇总表"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isAddingRecord = true
                    } label: {
                        Label(L10n.t("新增"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.heavy))
                    }
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(AppTheme.ink)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成")) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .sheet(isPresented: $isAddingRecord) {
            OvertimeEntrySheet(
                defaultStart: defaultNewRecordStart,
                defaultEnd: defaultNewRecordEnd,
                title: L10n.t("新增加班记录"),
                message: L10n.t("手动新增一条加班记录，只统计时长，不会增加收入。"),
                saveTitle: L10n.t("保存加班记录"),
                saveAction: { startAt, endAt in
                    addRecord(startAt, endAt)
                    monthAnchor = startAt
                    selectedDayFilter = startAt
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.paper)
        }
        .sheet(item: $editingRecord) { record in
            if record.isActive {
                OvertimeStartSheet(
                    defaultStart: record.startAt,
                    title: L10n.t("编辑加班记录"),
                    message: L10n.t("这条加班还在进行中，可先调整开始时间。"),
                    saveTitle: L10n.t("保存修改"),
                    saveAction: { startAt in
                        updateRecord(record, startAt, nil)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
            } else {
                OvertimeEntrySheet(
                    defaultStart: record.startAt,
                    defaultEnd: record.endAt ?? currentDate,
                    title: L10n.t("编辑加班记录"),
                    message: L10n.t("调整开始和结束时间后，加班时长会自动重新计算。"),
                    saveTitle: L10n.t("保存修改"),
                    saveAction: { startAt, endAt in
                        updateRecord(record, startAt, endAt)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
            }
        }
    }

    private var monthSwitcher: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.cream)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("查看上个月"))

                Button {
                    withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86)) {
                        isCalendarExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(monthAnchor.localizedMonthText)
                            .font(.title3.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Image(systemName: isCalendarExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCalendarExpanded ? L10n.t("收起日历") : L10n.t("展开日历"))

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(canMoveToNextMonth ? AppTheme.cream : AppTheme.divider.opacity(0.62))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveToNextMonth)
                .opacity(canMoveToNextMonth ? 1 : 0.48)
                .accessibilityLabel(L10n.t("查看下个月"))
            }

            if isCalendarExpanded {
                calendarPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var calendarPanel: some View {
        ComicCard(background: AppTheme.cream.opacity(0.78), padding: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let selectedDayFilter {
                        Text("\(L10n.t("已筛选")) \(selectedDayFilter.localizedDayText)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    } else {
                        Text(L10n.t("点选日期查看当天加班"))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    if selectedDayFilter != nil {
                        Button {
                            withAnimation(prefersReducedMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86)) {
                                selectedDayFilter = nil
                            }
                        } label: {
                            Text(L10n.t("查看整月"))
                                .font(.caption.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(AppTheme.coin.opacity(0.86))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 7) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            calendarDayCell(for: day)
                        } else {
                            Color.clear
                                .frame(height: 54)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func calendarDayCell(for day: Date) -> some View {
        let duration = overtimeDuration(on: day)
        let isSelected = selectedDayFilter.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isFuture = day > currentDate && !calendar.isDate(day, inSameDayAs: currentDate)
        Button {
            withAnimation(prefersReducedMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86)) {
                selectedDayFilter = isSelected ? nil : day
            }
        } label: {
            VStack(spacing: 2) {
                Text(day.dayNumberText)
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text(duration > 0 ? duration.overtimeCompactDurationText : " ")
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                    .foregroundStyle(duration > 0 ? AppTheme.red : AppTheme.textGray.opacity(0.1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isSelected ? AppTheme.coin : AppTheme.paper.opacity(duration > 0 ? 0.86 : 0.48))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.outline.opacity(isSelected || duration > 0 ? 0.92 : 0.25), lineWidth: isSelected ? 1.3 : 0.9)
            }
            .opacity(isFuture ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(calendarDayAccessibilityLabel(for: day, duration: duration))
    }

    private var totalsCard: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.t("汇总表"))
                            .font(.headline.weight(.heavy))
                        Text(L10n.t("只统计加班时长，不会增加收入。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    AssetImage(name: AppTheme.overtimeSummaryWorkerAsset)
                        .frame(width: 86, height: 62)
                        .accessibilityHidden(true)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    OvertimeSummaryMetric(title: L10n.t("记录数"), value: L10n.t("%@ 条", "\(displayedRecords.count)"))
                    OvertimeSummaryMetric(title: L10n.t("加班时长"), value: displayedTotalSeconds.overtimeDurationText)
                    OvertimeSummaryMetric(title: L10n.t("当前加班"), value: displayedHasActiveRecord ? L10n.t("计时中") : L10n.t("未开始"))
                }
            }
        }
    }

    private var recordsCard: some View {
        ComicCard(padding: 14) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text(L10n.t("记录明细"))
                        .font(.headline.weight(.heavy))
                    Spacer()
                    if let selectedDayFilter {
                        Text(selectedDayFilter.localizedDayText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(1)
                    }
                }

                if displayedRecords.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(displayedRecords.enumerated()), id: \.element.id) { index, record in
                        OvertimeRecordRow(
                            record: record,
                            now: currentDate,
                            editAction: { editingRecord = record },
                            deleteAction: { deleteRecord(record) }
                        )
                        if index < displayedRecords.count - 1 {
                            Divider().overlay(AppTheme.divider)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 38, height: 38)
                .background(AppTheme.coin)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.1))

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(selectedDayFilter == nil ? "这个月还没有加班" : "这一天还没有加班"))
                    .font(.subheadline.weight(.heavy))
                Text(L10n.t("下班后或休息日，可在首页开始记录加班。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.86), lineWidth: 1)
        }
    }

    private var canMoveToNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: monthAnchor) else { return false }
        return calendar.startOfMonth(for: next) <= calendar.startOfMonth(for: currentDate)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentLanguage.localeIdentifier)
        formatter.calendar = calendar
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        guard symbols.count == 7 else { return [] }
        let start = max(0, calendar.firstWeekday - 1)
        return Array(symbols[start..<symbols.count]) + Array(symbols[0..<start])
    }

    private var calendarDays: [Date?] {
        let monthStart = calendar.startOfMonth(for: monthAnchor)
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekdayIndex = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let leading = Array(repeating: Optional<Date>.none, count: firstWeekdayIndex)
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        return leading + days
    }

    private func overtimeDuration(on day: Date) -> TimeInterval {
        summary.records
            .filter { calendar.isDate($0.startAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.duration(until: currentDate) }
    }

    private func calendarDayAccessibilityLabel(for day: Date, duration: TimeInterval) -> String {
        let dayText = day.localizedFullDateText
        guard duration > 0 else { return "\(dayText)，\(L10n.t("没有加班记录"))" }
        return "\(dayText)，\(L10n.t("加班时长")) \(duration.overtimeDurationText)"
    }

    private func moveMonth(by offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: monthAnchor) else { return }
        withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.84)) {
            monthAnchor = next
            selectedDayFilter = nil
        }
    }

    private func date(on day: Date, hour: Int, minute: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? day
    }

    private var prefersReducedMotion: Bool {
        reducesMotion || accessibilityReduceMotion
    }
}

private struct OvertimeRecordRow: View {
    let record: OvertimeRecord
    let now: Date
    let editAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.startAt.localizedDayText)
                    .font(.subheadline.weight(.black))
                Text(record.startAt.localizedWeekdayText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(record.duration(until: now).overtimeDurationText)
                    .font(.subheadline.weight(.black))
                    .monospacedDigit()
                Text(record.timeRangeText(until: now))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(AppTheme.textGray)
                    .monospacedDigit()
            }

            Button(action: editAction) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.coin.opacity(0.86))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("编辑这条加班记录"))

            Button(action: deleteAction) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.paper.opacity(0.72))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("删除这条加班记录"))
        }
        .padding(.vertical, 3)
    }
}

private struct ExchangeItem: View {
    let image: String
    let title: String
    let amount: Double
    let hidesSensitiveAmounts: Bool

    var body: some View {
        VStack(spacing: 5) {
            AssetImage(name: image)
                .frame(width: 38, height: 38)
            Text(title)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(quantityText)
                .font(.subheadline.weight(.black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(quantityText))
    }

    private var quantityText: String {
        let quantity = hidesSensitiveAmounts ? PrivacyText.hiddenCount : String(format: "%.1f", amount)
        return "×\(quantity)"
    }
}

private struct SalaryAchievementCompactEntry: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let badges: [SalaryBadge]
    @State private var showsAll = false

    var body: some View {
        Button {
            showsAll = true
        } label: {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 13))
            layout {
                SalaryAchievementMedalArtwork(badge: badges.first, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("开薪成就"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                    Text(L10n.format("已收下 %@ 份小成就", "\(badges.filter(\.isUnlocked).count)"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 4)
                }
                Text(L10n.t("查看全部"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(14)
            .background(AppTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(AppTheme.outline, lineWidth: 1.4))
        }
        .buttonStyle(PayJoyPressStyle())
        .sheet(isPresented: $showsAll) {
            NavigationStack {
                ScrollView {
                    SalaryAchievementCard(badges: badges)
                        .padding(AppTheme.pagePadding)
                }
                .background(AppTheme.paper)
                .navigationTitle(L10n.t("开薪成就"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.t("关闭")) { showsAll = false }
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .accessibilityLabel(L10n.format("已收下 %@ 份小成就", "\(badges.filter(\.isUnlocked).count)"))
        .accessibilityHint(L10n.t("查看全部成就"))
    }
}

private struct SalaryAchievementCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let badges: [SalaryBadge]
    @State private var selectedBadge: SalaryBadge?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(spacing: 14))
            headerLayout {
                SalaryAchievementMedalArtwork(badge: badges.first, size: 86)
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.format("已收下 %@ 份小成就", "\(badges.filter(\.isUnlocked).count)"))
                        .font(.title3.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                    Text(L10n.t("一点点进展，也值得收下。"))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textGray)
                }
            }

            LazyVGrid(
                columns: dynamicTypeSize.isAccessibilitySize
                    ? [GridItem(.flexible())]
                    : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 18
            ) {
                ForEach(badges) { badge in
                    achievementMedal(badge)
                }
            }
        }
        .sheet(item: $selectedBadge) { badge in
            SalaryBadgeDetailSheet(badge: badge)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func achievementMedal(_ badge: SalaryBadge) -> some View {
        Button {
            selectedBadge = badge
        } label: {
            VStack(spacing: 8) {
                SalaryAchievementMedalArtwork(badge: badge, size: dynamicTypeSize.isAccessibilitySize ? 112 : 104)
                Text(badge.title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(badge.isUnlocked ? L10n.t("已收下") : L10n.t("慢慢来，也很好"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(badge.isUnlocked ? AppTheme.ink : AppTheme.textGray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge.title)
        .accessibilityValue(badge.isUnlocked ? L10n.t("已收下") : "\(Int(badge.progress * 100))%")
    }
}

private struct SalaryAchievementMedalArtwork: View {
    let badge: SalaryBadge?
    let size: CGFloat

    private var asset: String {
        switch badge?.id {
        case "first-payday": return "achievement_first_payday_v1"
        case "workweek-earned": return "achievement_workweek_earned_v1"
        case "month-halfway": return "achievement_month_halfway_v1"
        case "month-quarter": return "achievement_month_quarter_v1"
        case "month-three-quarter": return "achievement_month_three_quarter_v1"
        case "month-finish": return "achievement_month_finish_v1"
        case "payday-direction": return "achievement_payday_direction_v1"
        case "goal-reached": return "achievement_goal_reached_v1"
        case "goal-halfway": return "achievement_month_quarter_v1"
        case "goal-sprint": return "achievement_month_three_quarter_v1"
        case "calendar-caretaker": return "achievement_workweek_earned_v1"
        case "calendar-week": return "achievement_month_quarter_v1"
        case "calendar-collector": return "achievement_goal_reached_v1"
        case "calendar-month": return "achievement_month_three_quarter_v1"
        case "calendar-archivist": return "achievement_month_finish_v1"
        case "calendar-grandmaster": return "achievement_payday_direction_v1"
        case "calendar-vault": return "achievement_first_payday_v1"
        case "calendar-yearbook": return "achievement_goal_reached_v1"
        case "calendar-note": return "achievement_workweek_earned_v1"
        case "calendar-journal": return "achievement_month_halfway_v1"
        case "schedule-owner", "paid-leave": return "achievement_month_halfway_v1"
        case "schedule-master", "rest-planner": return "achievement_goal_reached_v1"
        case "schedule-director": return "achievement_payday_direction_v1"
        case "overtime-starter", "weekend-shift": return "achievement_month_quarter_v1"
        case "overtime-advanced", "weekend-regular": return "achievement_month_three_quarter_v1"
        case "overtime-hero", "weekend-veteran": return "achievement_month_finish_v1"
        case "overtime-marathon": return "achievement_payday_direction_v1"
        case "overtime-logbook": return "achievement_workweek_earned_v1"
        case "overtime-ledger": return "achievement_goal_reached_v1"
        default: return "achievement_first_payday_v1"
        }
    }

    var body: some View {
        AssetImage(name: asset)
            .frame(width: size, height: size)
            .saturation(badge?.isUnlocked == true ? 1 : 0)
            .opacity(badge?.isUnlocked == true ? 1 : 0.42)
            .overlay {
                if badge?.isUnlocked == false, let badge {
                    Circle()
                        .trim(from: 0, to: badge.progress)
                        .stroke(AppTheme.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(size * 0.08)
                }
            }
        .accessibilityHidden(true)
    }
}

private struct SalaryBadgeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let badge: SalaryBadge

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    SalaryAchievementMedalArtwork(badge: badge, size: 210)
                    Text(badge.title)
                        .font(.title.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                    Text(badge.isUnlocked ? L10n.t("已收下") : L10n.t("慢慢来，也很好"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                    ComicCard(background: AppTheme.cream, padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(badge.subtitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.ink)
                            if !badge.isUnlocked {
                                ProgressView(value: badge.progress)
                                    .tint(AppTheme.orange)
                                    .accessibilityLabel(L10n.t("进度"))
                            }
                            Text(L10n.t("一点点进展，也值得收下。"))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textGray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(AppTheme.pagePadding)
            }
            .background(AppTheme.paper)
            .navigationTitle(L10n.t("开薪成就"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("关闭")) { dismiss() }
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}

private extension Date {
    var localizedMonthText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)).year().month(.wide))
    }

    var localizedDayText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)).month().day())
    }

    var localizedFullDateText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)).year().month().day())
    }

    var dayNumberText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentMarket.localeIdentifier)).day())
    }

    var localizedWeekdayText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentMarket.localeIdentifier)).weekday(.wide))
    }

    var localizedTimeText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentMarket.localeIdentifier)).hour().minute())
    }
}

private extension TimeInterval {
    var overtimeDurationText: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var overtimeCompactDurationText: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0, minutes > 0 {
            return "\(hours)h\(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

private extension OvertimeRecord {
    func timeRangeText(until date: Date) -> String {
        let endText = endAt?.localizedTimeText ?? L10n.t("进行中")
        return "\(startAt.localizedTimeText)-\(endText)"
    }
}
