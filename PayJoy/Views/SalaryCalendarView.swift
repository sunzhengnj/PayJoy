import SwiftUI

struct SalaryCalendarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var monthAnchor = Date()
    @State private var selectedDate = Date()
    @State private var editingDay: SalaryCalendarDay?

    let showsBackButton: Bool

    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                monthSwitcher
                monthSummaryCard
                calendarCard
                selectedDayCard
                monthFooterCard
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, showsBackButton ? 28 : 86)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .sheet(item: $editingDay) { day in
            SalaryDayEditorSheet(
                day: day,
                defaultKind: appState.defaultSalaryDayKind(for: day.date),
                save: { kind, note in
                    appState.updateSalaryDay(date: day.date, kind: kind, note: note)
                },
                restore: {
                    appState.restoreSalaryDaySchedule(for: day.date)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.paper)
        }
        .onAppear {
            if showsBackButton {
                appState.isTabBarHidden = true
            }
            monthAnchor = monthStart(for: appState.now)
            selectedDate = Calendar.current.startOfDay(for: appState.now)
        }
        .onDisappear {
            if showsBackButton {
                appState.isTabBarHidden = false
            }
        }
        .transaction { transaction in
            guard prefersReducedMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var monthSummary: SalaryMonthSummary {
        appState.salaryMonthSummary(for: monthAnchor)
    }

    private var selectedDay: SalaryCalendarDay {
        appState.salaryCalendarDay(for: selectedDate)
    }

    private var selectedDayOvertime: OvertimeSummary {
        appState.overtimeSummary(forDayContaining: selectedDate)
    }

    private var hidesSensitiveAmounts: Bool {
        appState.preferences.hideSensitiveAmounts
    }

    private var currencySymbol: String {
        appState.settings.currencySymbol
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private var header: some View {
        ZStack {
            Text(L10n.t("工资日历"))
                .font(.system(size: 27, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)

            HStack {
                if showsBackButton {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.4)
                            }
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.94, reduceMotion: prefersReducedMotion))
                    .accessibilityLabel(L10n.t("返回"))
                }

                Spacer()

                AssetImage(name: AppTheme.statsCoinWorkerAsset)
                    .frame(width: 78, height: 58)
                    .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottomTrailing)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 58)
        .padding(.top, 4)
    }

    private var monthSwitcher: some View {
        HStack(spacing: 10) {
            monthButton(systemImage: "chevron.left", label: L10n.t("查看上个月")) {
                moveMonth(by: -1)
            }

            Text(monthAnchor.salaryCalendarMonthText)
                .font(.title3.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            if !isViewingCurrentMonth {
                Button {
                    jumpToToday()
                } label: {
                    Text(L10n.t("今天"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 44)
                        .background(AppTheme.coin)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
                .accessibilityLabel(L10n.t("回到今天"))
            }

            monthButton(systemImage: "chevron.right", label: L10n.t("查看下个月")) {
                moveMonth(by: 1)
            }
        }
        .padding(8)
        .background(AppTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.4)
        }
    }

    private func monthButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.9, reduceMotion: prefersReducedMotion))
        .accessibilityLabel(label)
    }

    private var monthSummaryCard: some View {
        ComicCard(background: AppTheme.cream, radius: 20, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.t("本月已赚"))
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                        Text(PrivacyText.money(monthSummary.earnedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                        Text(L10n.t("按每日计薪快照汇总"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AssetImage(name: AppTheme.statsCoinWorkerAsset)
                        .frame(width: 118, height: 86)
                        .scaleEffect(AppTheme.cardArtworkScale, anchor: .bottomTrailing)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(L10n.t("本月预计"))
                            .font(.caption.weight(.black))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .foregroundStyle(AppTheme.textGray)
                        Spacer()
                        Text(PrivacyText.compactMoney(monthSummary.projectedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                            .font(.caption.weight(.black))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .foregroundStyle(AppTheme.ink)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    ComicProgressBar(progress: monthSummary.projectedAmount > 0 ? monthSummary.earnedAmount / monthSummary.projectedAmount : 0)
                }
                .padding(10)
                .background(AppTheme.paper.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.outline.opacity(0.9), lineWidth: 1.1)
                }
            }
        }
    }

    private var calendarCard: some View {
        ComicCard(background: AppTheme.cream.opacity(0.72), radius: 20, padding: 10) {
            VStack(spacing: 9) {
                LazyVGrid(columns: calendarColumns, spacing: 7) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2.weight(.black))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .foregroundStyle(AppTheme.textGray)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            calendarDayCell(for: date)
                        } else {
                            Color.clear.frame(height: 58)
                        }
                    }
                }

                Divider().overlay(AppTheme.divider)
                legend
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    }

    private var weekdaySymbols: [String] {
        ["日", "一", "二", "三", "四", "五", "六"].map(L10n.t)
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let start = monthStart(for: monthAnchor)
        let leading = max(0, calendar.component(.weekday, from: start) - 1)
        let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        var result = Array<Date?>(repeating: nil, count: leading)
        result.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        })
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    private func calendarDayCell(for date: Date) -> some View {
        let day = appState.salaryCalendarDay(for: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button {
            withAnimation(prefersReducedMotion ? nil : .spring(response: 0.22, dampingFraction: 0.84)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 3) {
                Text(date.salaryCalendarDayNumber)
                    .font(.caption.weight(.black))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(AppTheme.ink)

                Text(calendarCellCaption(for: day))
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(day.isFuture ? AppTheme.textGray.opacity(0.65) : AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Circle()
                    .fill(day.kind.salaryCalendarColor)
                    .frame(width: 7, height: 7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isSelected ? AppTheme.coin : AppTheme.paper.opacity(day.isFuture ? 0.42 : 0.82))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isSelected ? AppTheme.outline : AppTheme.outline.opacity(0.45), lineWidth: isSelected ? 1.4 : 0.9)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.95))
        .accessibilityLabel(dayAccessibilityLabel(day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func calendarCellCaption(for day: SalaryCalendarDay) -> String {
        guard day.kind == .normal else { return day.kind.title }
        if hidesSensitiveAmounts { return PrivacyText.maskedMoney(currencySymbol: currencySymbol) }
        return day.scheduledAmount.compactMoneyText(currencySymbol: currencySymbol)
    }

    private var legend: some View {
        HStack(spacing: 11) {
            ForEach(SalaryDayKind.allCases) { kind in
                HStack(spacing: 4) {
                    Circle()
                        .fill(kind.salaryCalendarColor)
                        .frame(width: 8, height: 8)
                    Text(kind.title)
                        .font(.system(size: 9.5, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedDayCard: some View {
        ComicCard(background: AppTheme.cream, radius: 18, padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(L10n.t("当日明细"))
                        .font(.headline.weight(.black))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    Spacer()
                    if selectedDay.isEstimated {
                        Text(L10n.t("估算"))
                            .font(.caption2.weight(.black))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.cream)
                            .clipShape(Capsule())
                    }
                    Text(selectedDate.salaryCalendarDayText)
                        .font(.caption.weight(.black))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(AppTheme.textGray)
                    SalaryDayKindBadge(kind: selectedDay.kind)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.coin.opacity(0.34))

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        accessibilityDayMetric(
                            title: selectedDay.isFuture ? L10n.t("预计日薪") : L10n.t("当日已赚"),
                            value: selectedDayAmountText
                        )
                        Divider().overlay(AppTheme.divider)
                        accessibilityDayMetric(title: L10n.t("加班时长"), value: selectedDayOvertime.totalSeconds.salaryCalendarOvertimeText)
                        Divider().overlay(AppTheme.divider)
                        accessibilityDayMetric(title: L10n.t("备注"), value: selectedDay.note.isEmpty ? L10n.t("无") : selectedDay.note)
                        editSelectedDayButton(expanded: true)
                    }
                    .padding(14)
                } else {
                    HStack(spacing: 0) {
                        dayMetric(
                            title: selectedDay.isFuture ? L10n.t("预计日薪") : L10n.t("当日已赚"),
                            value: selectedDayAmountText
                        )
                        Divider().frame(height: 46).overlay(AppTheme.divider)
                        dayMetric(title: L10n.t("加班时长"), value: selectedDayOvertime.totalSeconds.salaryCalendarOvertimeText)
                        Divider().frame(height: 46).overlay(AppTheme.divider)
                        dayMetric(title: L10n.t("备注"), value: selectedDay.note.isEmpty ? L10n.t("无") : selectedDay.note)
                        editSelectedDayButton(expanded: false)
                            .padding(.trailing, 12)
                    }
                    .padding(.vertical, 13)
                }
            }
        }
    }

    private var selectedDayAmountText: String {
        PrivacyText.compactMoney(
            selectedDay.isFuture ? selectedDay.scheduledAmount : selectedDay.earnedAmount,
            hidden: hidesSensitiveAmounts,
            currencySymbol: currencySymbol
        )
    }

    private func editSelectedDayButton(expanded: Bool) -> some View {
        Button {
            editingDay = selectedDay
        } label: {
            Text(expanded ? L10n.t("编辑当日记录") : L10n.t("编辑"))
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(.horizontal, 11)
                .frame(maxWidth: expanded ? .infinity : nil)
                .frame(height: 44)
                .background(AppTheme.coin)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(AppTheme.outline, lineWidth: 1)
                }
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.95))
        .accessibilityLabel(L10n.t("编辑当日记录"))
    }

    private func accessibilityDayMetric(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Spacer(minLength: 8)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }

    private func dayMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    private var monthFooterCard: some View {
        ComicCard(background: AppTheme.cream, radius: 18, padding: 13) {
            HStack(spacing: 12) {
                AssetImage(name: "coin_single_v1")
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("本月概览"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                    Text(PrivacyText.compactMoney(monthSummary.projectedAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                        .font(.title3.weight(.black))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(L10n.t("计薪天数"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                    Text(L10n.t("%@ 天", "\(monthSummary.paidDayCount)"))
                        .font(.headline.weight(.black))
                    if monthSummary.estimatedDayCount > 0 {
                        Text(L10n.t("估算") + " " + "\(monthSummary.estimatedDayCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                }
            }
        }
    }

    private func dayAccessibilityLabel(_ day: SalaryCalendarDay) -> String {
        let amount = PrivacyText.compactMoney(day.scheduledAmount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol)
        return "\(day.date.salaryCalendarDayText)，\(day.kind.title)，\(amount)"
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: value, to: monthAnchor) else { return }
        withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86)) {
            monthAnchor = monthStart(for: newMonth)
            if Calendar.current.isDate(monthAnchor, equalTo: appState.now, toGranularity: .month) {
                selectedDate = Calendar.current.startOfDay(for: appState.now)
            } else {
                selectedDate = monthAnchor
            }
        }
    }

    private var isViewingCurrentMonth: Bool {
        Calendar.current.isDate(monthAnchor, equalTo: appState.now, toGranularity: .month)
    }

    private func jumpToToday() {
        withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86)) {
            monthAnchor = monthStart(for: appState.now)
            selectedDate = Calendar.current.startOfDay(for: appState.now)
        }
    }

    private func monthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct SalaryDayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: SalaryCalendarDay
    let defaultKind: SalaryDayKind
    let save: (SalaryDayKind, String) -> Void
    let restore: () -> Void
    @State private var selectedKind: SalaryDayKind
    @State private var note: String

    init(
        day: SalaryCalendarDay,
        defaultKind: SalaryDayKind,
        save: @escaping (SalaryDayKind, String) -> Void,
        restore: @escaping () -> Void
    ) {
        self.day = day
        self.defaultKind = defaultKind
        self.save = save
        self.restore = restore
        _selectedKind = State(initialValue: day.kind)
        _note = State(initialValue: day.note)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ComicCard(background: AppTheme.highlightCardBackground, padding: 13) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.date.salaryCalendarDayText)
                                    .font(.title3.weight(.black))
                                Text(L10n.t("校正日期状态与备注，金额会按规则自动计算。"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                            }
                            Spacer()
                            SalaryDayKindBadge(kind: selectedKind)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("日期状态"))
                            .font(.headline.weight(.black))
                        LazyVGrid(columns: editorColumns, spacing: 10) {
                            ForEach(SalaryDayKind.allCases) { kind in
                                Button {
                                    selectedKind = kind
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(kind.salaryCalendarColor)
                                            .frame(width: 10, height: 10)
                                        Text(kind.title)
                                            .font(.subheadline.weight(.black))
                                        Spacer()
                                    }
                                    .foregroundStyle(AppTheme.ink)
                                    .padding(12)
                                    .background(selectedKind == kind ? AppTheme.coin : AppTheme.cream)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppTheme.outline, lineWidth: selectedKind == kind ? 1.4 : 1)
                                    }
                                }
                                .buttonStyle(PayJoyPressStyle(scale: 0.97))
                                .accessibilityLabel(kind.title)
                                .accessibilityValue(selectedKind == kind ? L10n.t("已选择") : L10n.t("未选择"))
                                .accessibilityAddTraits(selectedKind == kind ? .isSelected : [])
                            }
                        }
                        .sensoryFeedback(.selection, trigger: selectedKind)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("备注"))
                            .font(.headline.weight(.black))
                        TextField(L10n.t("例如：年假、调休或临时请假"), text: $note, axis: .vertical)
                            .font(.body.weight(.semibold))
                            .lineLimit(3...5)
                            .padding(12)
                            .background(AppTheme.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.1)
                            }
                    }

                    Button {
                        save(selectedKind, note)
                        dismiss()
                    } label: {
                        Text(L10n.t("保存当日记录"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppTheme.coin)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.3)
                            }
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.98))

                    if day.hasSavedRecord {
                        Button(L10n.t("恢复默认排班")) {
                            restore()
                            dismiss()
                        }
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.textGray)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("编辑当日记录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("取消")) { dismiss() }
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
    }

    private var editorColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }
}

private struct SalaryDayKindBadge: View {
    let kind: SalaryDayKind

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(kind.salaryCalendarColor)
                .frame(width: 8, height: 8)
            Text(kind.title)
                .font(.caption.weight(.black))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(AppTheme.paper.opacity(0.8))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.outline.opacity(0.7), lineWidth: 0.8))
    }
}

private extension SalaryDayKind {
    var salaryCalendarColor: Color {
        switch self {
        case .normal: Color(hex: 0x55A94A)
        case .paidLeave: Color(hex: 0x8A4AC7)
        case .unpaidLeave: Color(hex: 0x48A8D8)
        case .rest: Color(hex: 0x9A9A9A)
        }
    }
}

private extension Date {
    var salaryCalendarMonthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentLanguage.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return formatter.string(from: self)
    }

    var salaryCalendarDayNumber: String {
        String(Calendar.current.component(.day, from: self))
    }

    var salaryCalendarDayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentLanguage.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: self)
    }
}

private extension TimeInterval {
    var salaryCalendarOvertimeText: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
