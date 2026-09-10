import SwiftUI

enum SalarySettingsMode {
    case salary
    case workTime
    case all

    var title: String {
        switch self {
        case .salary: L10n.t("薪资设置")
        case .workTime: L10n.t("工作时间设置")
        case .all: L10n.t("薪资设置")
        }
    }

    var subtitle: String {
        switch self {
        case .salary: L10n.t("设置年薪、月薪、日薪或时薪。")
        case .workTime: L10n.t("设置计薪日、上下班和午休时间。")
        case .all: L10n.t("输入薪资和工作时间，开薪马上开始。")
        }
    }
}

struct SalarySettingsView: View {
    var mode: SalarySettingsMode = .all
    var completesInitialSetup = false
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var draft = SalarySettings.defaultValue
    @State private var amountText = ""
    @State private var monthlyPaidDaysText = ""
    @State private var didLoad = false
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                if mode == .salary || mode == .all {
                    salaryTypePicker
                    amountCard
                    paydayCard
                }
                if mode == .workTime || mode == .all {
                    workTimeCard
                    workdayCard
                    lunchCard
                }
                if let validationMessage {
                    validationNotice(validationMessage)
                }
                previewCard
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 82)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveButton
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .background(AppTheme.paper)
                .overlay(alignment: .top) {
                    Divider()
                        .overlay(AppTheme.divider.opacity(0.7))
                }
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(AppTheme.current == .midnight ? .dark : .light, for: .navigationBar)
        .payJoyKeyboardDismissToolbar()
        .onAppear {
            appState.isTabBarHidden = true
            loadDraft()
        }
        .onDisappear {
            appState.isTabBarHidden = false
        }
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsProPaywall = true
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
        .sensoryFeedback(.selection, trigger: draft.salaryType)
        .sensoryFeedback(.selection, trigger: draft.workdays)
        .transaction { transaction in
            guard prefersReducedMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(mode.subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if !dynamicTypeSize.isAccessibilitySize {
                AssetImage(name: AppTheme.cornerWorkerAsset)
                    .frame(width: 78, height: 52)
                    .scaleEffect(AppTheme.cardArtworkScale, anchor: .trailing)
                    .accessibilityHidden(true)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var salaryTypePicker: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("薪资类型"))
                    .font(.headline.weight(.heavy))
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 8) {
                            ForEach(SalaryType.allCases) { type in
                                salaryTypeButton(type)
                            }
                        }
                    } else {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                            spacing: 8
                        ) {
                            ForEach(SalaryType.allCases) { type in
                                salaryTypeButton(type)
                            }
                        }
                    }
                }
            }
        }
    }

    private func salaryTypeButton(_ type: SalaryType) -> some View {
        Button {
            draft.salaryType = type
            if amountText.isEmpty || draft.salaryAmount <= 0 {
                let amount = defaultAmount(for: type)
                draft.salaryAmount = amount
                amountText = amount.formatted(.number.precision(.fractionLength(0...2)))
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(type == draft.salaryType ? AppTheme.ink : AppTheme.divider.opacity(0.55))
                    .frame(width: type == draft.salaryType ? 28 : 12, height: 4)
                    .animation(
                        prefersReducedMotion ? nil : .spring(response: 0.2, dampingFraction: 0.82),
                        value: draft.salaryType
                    )
                    .accessibilityHidden(true)
                Text(type.title)
                    .font(.subheadline.weight(.black))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 68 : 56, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
            .background(type == draft.salaryType ? AppTheme.coin : AppTheme.softSurface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.3)
            }
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.97, reduceMotion: prefersReducedMotion))
        .accessibilityLabel(type.title)
        .accessibilityValue(type == draft.salaryType ? L10n.t("已选择") : L10n.t("未选择"))
        .accessibilityAddTraits(type == draft.salaryType ? .isSelected : [])
    }

    private var amountCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(draft.salaryType.inputTitle)
                    .font(.headline.weight(.heavy))
                currencySymbolPicker
                HStack {
                    Text(draft.currencySymbol)
                        .font(.title2.weight(.black))
                    TextField("10000", text: $amountText)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .keyboardType(.decimalPad)
                        .onChange(of: amountText) { _, newValue in
                            let sanitized = sanitizeAmount(newValue)
                            if sanitized != newValue {
                                amountText = sanitized
                                return
                            }
                            draft.salaryAmount = parsedSalaryAmount(from: sanitized) ?? 0
                        }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                HStack(spacing: 8) {
                    ForEach(presetAmounts, id: \.self) { amount in
                        let isSelected = draft.salaryAmount == amount
                        Button {
                            draft.salaryAmount = amount
                            amountText = amount.formatted(.number.precision(.fractionLength(0...2)))
                        } label: {
                            Text(amount.compactMoneyText(currencySymbol: draft.currencySymbol))
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(isSelected ? AppTheme.coin : AppTheme.coin.opacity(0.32))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.outline, lineWidth: isSelected ? 1.5 : 1))
                        }
                        .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                Divider().overlay(AppTheme.divider)
                monthlyPaidDaysControl
                Text(monthlyPaidDaysHint)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var monthlyPaidDaysControl: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                monthlyPaidDaysLabel
                Spacer()
                monthlyPaidDaysStepper
            }

            VStack(alignment: .leading, spacing: 8) {
                monthlyPaidDaysLabel
                monthlyPaidDaysStepper
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var monthlyPaidDaysLabel: some View {
        Text(L10n.t("月计薪天数"))
            .font(.caption.weight(.bold))
    }

    private var monthlyPaidDaysStepper: some View {
        HStack(spacing: 0) {
                Button {
                    adjustMonthlyPaidDays(by: -0.25)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.92, reduceMotion: prefersReducedMotion))
                .disabled(draft.monthlyPaidDays <= 1)
                .opacity(draft.monthlyPaidDays <= 1 ? 0.35 : 1)
                .accessibilityLabel(Text("\(L10n.t("月计薪天数")) −0.25"))

                Divider()
                    .frame(height: 24)
                    .overlay(AppTheme.divider)

                HStack(spacing: 3) {
                    TextField("21.75", text: $monthlyPaidDaysText)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 58)
                        .accessibilityLabel(L10n.t("月计薪天数"))
                        .accessibilityValue(monthlyPaidDaysText)
                        .onChange(of: monthlyPaidDaysText) { _, newValue in
                            let sanitized = sanitizeMonthlyPaidDays(newValue)
                            if sanitized != newValue {
                                monthlyPaidDaysText = sanitized
                                return
                            }
                            updateMonthlyPaidDays(from: sanitized)
                        }
                    Text(L10n.t("天"))
                        .font(.caption.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .foregroundStyle(AppTheme.ink)
                .frame(width: 86, height: 44)

                Divider()
                    .frame(height: 24)
                    .overlay(AppTheme.divider)

                Button {
                    adjustMonthlyPaidDays(by: 0.25)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.92, reduceMotion: prefersReducedMotion))
                .disabled(draft.monthlyPaidDays >= 31)
                .opacity(draft.monthlyPaidDays >= 31 ? 0.35 : 1)
                .accessibilityLabel(Text("\(L10n.t("月计薪天数")) +0.25"))
            }
            .foregroundStyle(AppTheme.ink)
            .background(AppTheme.softSurface.opacity(0.76))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.outline.opacity(0.72), lineWidth: 1.1))
    }

    private var currencySymbolPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("货币"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CurrencyCode.allCases) { code in
                        Button {
                            draft.setCurrencyCode(code)
                        } label: {
                            Text("\(code.rawValue) \(code.displaySymbol)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(draft.currencyCode == code ? AppTheme.coin : AppTheme.softSurface.opacity(0.74))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.outline.opacity(0.74), lineWidth: 1))
                        }
                        .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
                        .accessibilityLabel("\(code.rawValue) \(code.displaySymbol)")
                        .accessibilityValue(draft.currencyCode == code ? L10n.t("已选择") : L10n.t("未选择"))
                        .accessibilityAddTraits(draft.currencyCode == code ? .isSelected : [])
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    private var monthlyPaidDaysHint: String {
        if appState.preferences.resolvedMarket == .mainlandChina {
            return L10n.t("默认 21.75 天；这里只用于趣味进度，不用于税务或工资核算。")
        }
        return L10n.t("按每周工作日估算月均计薪天数；这里只用于趣味进度。")
    }

    private var paydayCard: some View {
        ComicCard(background: AppTheme.highlightCardBackground) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("发薪日"))
                            .font(.headline.weight(.heavy))
                        Text(L10n.t("发薪日当天首次打开会出现原创全屏彩蛋，也可以随时从首页再次打开。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Button {
                        draft.paydayDay = draft.paydayDay == nil ? 25 : nil
                    } label: {
                        HStack(spacing: 8) {
                            Text(draft.paydayDay == nil ? L10n.t("添加") : L10n.t("已添加"))
                                .font(.caption.weight(.black))
                            ZStack(alignment: draft.paydayDay == nil ? .leading : .trailing) {
                                Capsule()
                                    .fill(draft.paydayDay == nil ? AppTheme.divider : AppTheme.coin)
                                    .frame(width: 42, height: 24)
                                Circle()
                                    .fill(AppTheme.softSurface)
                                    .frame(width: 18, height: 18)
                                    .padding(.horizontal, 3)
                                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1))
                            }
                        }
                        .foregroundStyle(AppTheme.ink)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
                    .accessibilityValue(draft.paydayDay == nil ? L10n.t("未开启") : L10n.t("已开启"))
                }

                if let selectedDay = draft.paydayDay {
                    Divider().overlay(AppTheme.divider)
                    Text(L10n.format("每月 %@ 日发薪", "\(selectedDay)"))
                        .font(.subheadline.weight(.black))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...31, id: \.self) { day in
                                Button {
                                    draft.paydayDay = day
                                } label: {
                                    Text("\(day)")
                                        .font(.subheadline.weight(.black))
                                        .foregroundStyle(AppTheme.ink)
                                        .frame(width: 44, height: 44)
                                        .background(day == selectedDay ? AppTheme.coin : AppTheme.softSurface.opacity(0.82))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: day == selectedDay ? 1.6 : 1))
                                }
                                .buttonStyle(PayJoyPressStyle(scale: 0.94, reduceMotion: prefersReducedMotion))
                                .accessibilityLabel(L10n.format("每月 %@ 日", "\(day)"))
                                .accessibilityAddTraits(day == selectedDay ? .isSelected : [])
                            }
                        }
                    }
                    Text(L10n.t("如果当月没有这一天，会在当月最后一天触发。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }
            }
        }
    }

    private var workTimeCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("工作时间"))
                    .font(.headline.weight(.heavy))
                timeRow(title: L10n.t("上班时间"), time: $draft.workStart)
                timeRow(title: L10n.t("下班时间"), time: $draft.workEnd)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        workDurationLabel
                        Spacer()
                        workDurationValue
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        workDurationLabel
                        workDurationValue
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var workdayCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("计薪日"))
                    .font(.headline.weight(.heavy))
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 8),
                        count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
                    ),
                    spacing: 8
                ) {
                    ForEach(Workday.displayOrder) { day in
                        Button {
                            toggleWorkday(day)
                        } label: {
                            Text(day.shortTitle)
                                .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 76 : 54)
                            .background(draft.workdays.contains(day.rawValue) ? AppTheme.coin : AppTheme.softSurface.opacity(0.74))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.2)
                            }
                        }
                        .buttonStyle(PayJoyPressStyle(scale: 0.97, reduceMotion: prefersReducedMotion))
                        .accessibilityLabel(day.title)
                        .accessibilityAddTraits(draft.workdays.contains(day.rawValue) ? .isSelected : [])
                        .accessibilityValue(draft.workdays.contains(day.rawValue) ? L10n.t("已选择") : L10n.t("未选择"))
                    }
                }
                Text(L10n.t("可自由选择周一到周日任意计薪日；未选中的日期首页会显示休息日。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var lunchCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("午休时间"))
                            .font(.headline.weight(.heavy))
                        Text(L10n.t("开启后午休不会计入今日已赚和进度。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    if appState.canUseLunchBreakSettings {
                        Toggle("", isOn: $draft.deductLunch)
                            .labelsHidden()
                            .tint(AppTheme.coin)
                            .accessibilityLabel(L10n.t("午休暂停计薪"))
                            .accessibilityValue(draft.deductLunch ? L10n.t("已开启") : L10n.t("未开启"))
                    } else {
                        Button {
                            showsMembershipPrompt = true
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
                        .accessibilityLabel(L10n.t("设置午休时间"))
                    }
                }

                if appState.canUseLunchBreakSettings && draft.deductLunch {
                    timeRow(title: L10n.t("午休开始"), time: $draft.lunchStart)
                    timeRow(title: L10n.t("午休结束"), time: $draft.lunchEnd)
                } else if !appState.canUseLunchBreakSettings {
                    Button {
                        showsMembershipPrompt = true
                    } label: {
                        Text(L10n.t("设置午休时间"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.coin)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
                }
            }
        }
    }

    private var previewCard: some View {
        let calculator = SalaryCalculator()
        let daySalary = calculator.dailySalary(for: draft)
        let seconds = calculator.workingSecondsPerDay(settings: draft)
        let perSecond = seconds > 0 ? daySalary / seconds : 0

        return ComicCard(background: AppTheme.highlightCardBackground) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("保存后首页会这样算"))
                    .font(.headline.weight(.heavy))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        previewMetrics(daySalary: daySalary, perSecond: perSecond)
                    }

                    VStack(spacing: 8) {
                        previewMetrics(daySalary: daySalary, perSecond: perSecond)
                    }
                }
                Text(L10n.t("计薪日：\(workdaySummary)。未选中日期可在首页临时开启加班计薪。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var workHoursText: String {
        let calculator = SalaryCalculator()
        let hours = calculator.workingSecondsPerDay(settings: draft) / 3_600
        return String(format: L10n.t("%.1f 小时"), hours)
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private var workDurationLabel: some View {
        Text(L10n.t("每日工作时长"))
    }

    private var workDurationValue: some View {
        Text(workHoursText)
            .fontWeight(.heavy)
    }

    @ViewBuilder
    private func previewMetrics(daySalary: Double, perSecond: Double) -> some View {
        PreviewMetric(title: L10n.t("预计日薪"), value: daySalary.moneyText(currencySymbol: draft.currencySymbol))
        PreviewMetric(title: L10n.t("每秒回血"), value: "\(draft.currencySymbol)\(String(format: "%.4f", perSecond))")
    }

    private func validationNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(AppTheme.red)
                .frame(width: 4, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("还差一步"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text(message)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.red.opacity(0.42), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var presetAmounts: [Double] {
        switch draft.salaryType {
        case .yearly:
            [120_000, 240_000, 360_000]
        case .monthly:
            [8_000, 10_000, 15_000]
        case .daily:
            [300, 500, 800]
        case .hourly:
            [30, 50, 80]
        }
    }

    private var canSave: Bool {
        validationMessage == nil
    }

    private var saveButton: some View {
        PrimaryButton(title: L10n.t("保存设置"), reduceMotion: prefersReducedMotion) {
            save()
        }
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.45)
        .accessibilityValue(canSave ? L10n.t("可以保存") : L10n.t("暂不可保存"))
    }

    private var workdaySummary: String {
        draft.workdaySummary
    }

    private var validationMessage: String? {
        guard draft.salaryAmount.isFinite, draft.salaryAmount > 0 else { return L10n.t("薪资金额要大于 0，钱包才知道怎么回血。") }
        guard draft.monthlyPaidDays > 0 else { return L10n.t("月计薪天数要大于 0。") }
        guard !draft.workdays.isEmpty else { return L10n.t("至少选择一天作为计薪日。") }
        guard draft.workEnd.minutesFromStartOfDay > draft.workStart.minutesFromStartOfDay else {
            return L10n.t("下班时间必须晚于上班时间。")
        }
        if draft.deductLunch {
            guard draft.lunchEnd.minutesFromStartOfDay > draft.lunchStart.minutesFromStartOfDay else {
                return L10n.t("午休结束时间必须晚于午休开始时间。")
            }
            guard draft.lunchStart.minutesFromStartOfDay >= draft.workStart.minutesFromStartOfDay,
                  draft.lunchEnd.minutesFromStartOfDay <= draft.workEnd.minutesFromStartOfDay else {
                return L10n.t("午休时间需要落在上班和下班之间。")
            }
        }
        return nil
    }

    private func timeRow(title: String, time: Binding<WorkTime>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                timeLabel(title)
                Spacer()
                timePicker(title: title, time: time)
            }

            VStack(alignment: .leading, spacing: 6) {
                timeLabel(title)
                timePicker(title: title, time: time)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func timeLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.bold))
    }

    private func timePicker(title: String, time: Binding<WorkTime>) -> some View {
        DatePicker(title, selection: dateBinding(for: time), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .tint(AppTheme.coin)
            .accessibilityLabel(title)
    }

    private func dateBinding(for time: Binding<WorkTime>) -> Binding<Date> {
        Binding<Date> {
            date(from: time.wrappedValue)
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            time.wrappedValue = WorkTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
        }
    }

    private func date(from time: WorkTime) -> Date {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func loadDraft() {
        guard !didLoad else { return }
        draft = appState.sanitizeSettingsForCurrentPlan(appState.settings)
        amountText = draft.salaryAmount.formatted(.number.precision(.fractionLength(0...2)))
        monthlyPaidDaysText = formatMonthlyPaidDays(draft.monthlyPaidDays)
#if DEBUG
        if AppState.isScreenshotMode,
           ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] == "worktime-error" {
            draft.workdays = []
        }
#endif
        didLoad = true
    }

    private func save() {
        guard canSave else { return }
        appState.settings = appState.sanitizeSettingsForCurrentPlan(draft)
        if completesInitialSetup {
            var updatedPreferences = appState.preferences
            updatedPreferences.hasCompletedInitialSetup = true
            appState.preferences = updatedPreferences
        }
        dismiss()
    }

    private func toggleWorkday(_ day: Workday) {
        if draft.workdays.contains(day.rawValue) {
            draft.workdays.remove(day.rawValue)
        } else {
            draft.workdays.insert(day.rawValue)
        }
    }

    private func sanitizeAmount(_ input: String) -> String {
        var hasDecimalPoint = false
        return input.filter { character in
            if character == "." {
                if hasDecimalPoint { return false }
                hasDecimalPoint = true
                return true
            }
            return character.isNumber
        }
    }

    private func parsedSalaryAmount(from input: String) -> Double? {
        guard let value = Double(input), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func sanitizeMonthlyPaidDays(_ input: String) -> String {
        var hasDecimalPoint = false
        var fractionalCount = 0
        var sanitized = ""

        for character in input {
            if character == "." {
                guard !hasDecimalPoint else { continue }
                hasDecimalPoint = true
                sanitized.append(character)
                continue
            }

            guard character.isNumber else { continue }
            if hasDecimalPoint {
                guard fractionalCount < 2 else { continue }
                fractionalCount += 1
            }
            sanitized.append(character)
        }

        return sanitized
    }

    private func updateMonthlyPaidDays(from text: String) {
        guard let value = Double(text), value <= 31 else {
            if let value = Double(text), value > 31 {
                draft.monthlyPaidDays = 31
                monthlyPaidDaysText = formatMonthlyPaidDays(31)
            } else {
                draft.monthlyPaidDays = 0
            }
            return
        }
        draft.monthlyPaidDays = value
    }

    private func adjustMonthlyPaidDays(by delta: Double) {
        let value = min(31, max(1, draft.monthlyPaidDays + delta))
        draft.monthlyPaidDays = value
        monthlyPaidDaysText = formatMonthlyPaidDays(value)
    }

    private func formatMonthlyPaidDays(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func defaultAmount(for type: SalaryType) -> Double {
        switch type {
        case .yearly: 120_000
        case .monthly: 10_000
        case .daily: 500
        case .hourly: 50
        }
    }
}

private struct PreviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.headline.weight(.black))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.cream.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.1)
        }
    }
}
