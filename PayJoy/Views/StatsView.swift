import SwiftUI

struct StatsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPeriod: StatsPeriod = .month
    @State private var isOvertimeSheetPresented = false
    @State private var overtimeMonthAnchor = Date()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                statsHeader
                summaryCard
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
        .navigationBarHidden(true)
        .sheet(isPresented: $isOvertimeSheetPresented) {
            OvertimeRecordsSheet(
                monthAnchor: $overtimeMonthAnchor,
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
    }

    private var period: PeriodEarnings {
        appState.periodEarnings(for: selectedPeriod)
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

            ZStack(alignment: .topTrailing) {
                periodPicker

                AssetImage(name: AppTheme.statsHeaderWorkerAsset)
                    .frame(width: 74, height: 54)
                    .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottom)
                    .offset(x: -32, y: -49)
                    .zIndex(2)
            }
        }
        .padding(.bottom, 8)
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(StatsPeriod.allCases) { period in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                        selectedPeriod = period
                    }
                } label: {
                    Text(period.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedPeriod == period ? AppTheme.coin : AppTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.outline, lineWidth: 1.4)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryCard: some View {
        ComicCard(background: AppTheme.cream, radius: 20, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("\(selectedPeriod.title)已赚"))
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.ink)

                        Text(PrivacyText.money(period.earned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                            .font(.system(size: 37, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .minimumScaleFactor(0.62)
                            .lineLimit(1)

                        Text(L10n.t("预计 \(PrivacyText.money(period.projected, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    StatsSummaryIllustration()
                        .frame(width: 146, height: 108)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(L10n.t("\(selectedPeriod.title)进度"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                        Spacer()
                        Text("\(period.progress * 100, specifier: "%.1f")%")
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .monospacedDigit()
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
            }
        }
        .padding(.top, 2)
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
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("打开工资日历"))
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppTheme.coin)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: 1.2)
                    }
                }
                .buttonStyle(.plain)
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
    @Binding var monthAnchor: Date
    @State private var editingRecord: OvertimeRecord?
    @State private var isAddingRecord = false
    @State private var isCalendarExpanded = false
    @State private var selectedDayFilter: Date?
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
            return date(on: selectedDayFilter, hour: 19, minute: 0)
        }
        if calendar.isDate(monthAnchor, equalTo: currentDate, toGranularity: .month) {
            return currentDate
        }
        return date(on: monthAnchor, hour: 19, minute: 0)
    }

    private var defaultNewRecordEnd: Date {
        defaultNewRecordStart.addingTimeInterval(60 * 60)
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
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
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
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                                selectedDayFilter = nil
                            }
                        } label: {
                            Text(L10n.t("查看整月"))
                                .font(.caption.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
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
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
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
        withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
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
                    .frame(width: 32, height: 32)
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
                    .frame(width: 32, height: 32)
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
                .font(.caption2.weight(.bold))
            Text(hidesSensitiveAmounts ? PrivacyText.hiddenCount : String(format: "%.1f", amount))
                .font(.caption.weight(.black))
        }
        .frame(maxWidth: .infinity)
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
        formatted(.dateTime.locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)).day())
    }

    var localizedWeekdayText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)).weekday(.wide))
    }

    var localizedTimeText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)).hour().minute())
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
