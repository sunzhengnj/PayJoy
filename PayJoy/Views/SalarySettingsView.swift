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
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SalarySettings.defaultValue
    @State private var amountText = ""
    @State private var monthlyPaidDaysText = ""
    @State private var didLoad = false
    @State private var showsProUpsell = false
    @State private var showsProPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                if mode == .salary || mode == .all {
                    salaryTypePicker
                    amountCard
                }
                if mode == .workTime || mode == .all {
                    workTimeCard
                    workdayCard
                    lunchCard
                }
                previewCard
                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(AppTheme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                PrimaryButton(title: L10n.t("保存设置")) {
                    save()
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 18)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            appState.isTabBarHidden = true
            loadDraft()
        }
        .onDisappear {
            appState.isTabBarHidden = false
        }
        .alert(L10n.t("午休时间是 PRO 功能"), isPresented: $showsProUpsell) {
            Button(L10n.t("稍后"), role: .cancel) {}
            Button(L10n.t("开通 PRO")) {
                showsProPaywall = true
            }
        } message: {
            Text(L10n.t("开通后可设置午休暂停计薪，让今日收入和进度更贴近实际。"))
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            AssetImage(name: AppTheme.cornerWorkerAsset)
                .frame(width: 78, height: 52)
                .scaleEffect(AppTheme.cardArtworkScale, anchor: .trailing)
        }
    }

    private var salaryTypePicker: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("薪资类型"))
                    .font(.headline.weight(.heavy))
                HStack(spacing: 10) {
                    ForEach(SalaryType.allCases) { type in
                        Button {
                            draft.salaryType = type
                            if amountText.isEmpty || draft.salaryAmount <= 0 {
                                let amount = defaultAmount(for: type)
                                draft.salaryAmount = amount
                                amountText = amount.formatted(.number.precision(.fractionLength(0...2)))
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type == draft.salaryType ? "checkmark.seal.fill" : "briefcase.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text(type.title)
                                    .font(.caption.weight(.heavy))
                            }
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(type == draft.salaryType ? AppTheme.coin : AppTheme.softSurface.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
                            draft.salaryAmount = Double(sanitized) ?? 0
                        }
                }
                HStack(spacing: 8) {
                    ForEach(presetAmounts, id: \.self) { amount in
                        Button {
                            draft.salaryAmount = amount
                            amountText = amount.formatted(.number.precision(.fractionLength(0...2)))
                        } label: {
                            Text(amount.compactMoneyText(currencySymbol: draft.currencySymbol))
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(AppTheme.coin.opacity(0.45))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider().overlay(AppTheme.divider)
                monthlyPaidDaysControl
                Text(L10n.t("默认 21.75 天，适合多数固定月薪场景；时薪模式会按每日工作时长计算。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var monthlyPaidDaysControl: some View {
        HStack(spacing: 12) {
            Text(L10n.t("月计薪天数"))
                .font(.caption.weight(.bold))
            Spacer()
            HStack(spacing: 0) {
                Button {
                    adjustMonthlyPaidDays(by: -0.25)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 42, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(draft.monthlyPaidDays <= 1)
                .opacity(draft.monthlyPaidDays <= 1 ? 0.35 : 1)

                Divider()
                    .frame(height: 24)
                    .overlay(AppTheme.divider)

                HStack(spacing: 3) {
                    TextField("21.75", text: $monthlyPaidDaysText)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 58)
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
                }
                .foregroundStyle(AppTheme.ink)
                .frame(width: 86, height: 40)

                Divider()
                    .frame(height: 24)
                    .overlay(AppTheme.divider)

                Button {
                    adjustMonthlyPaidDays(by: 0.25)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 42, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(draft.monthlyPaidDays >= 31)
                .opacity(draft.monthlyPaidDays >= 31 ? 0.35 : 1)
            }
            .foregroundStyle(AppTheme.ink)
            .background(AppTheme.softSurface.opacity(0.76))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.outline.opacity(0.72), lineWidth: 1.1))
        }
    }

    private var currencySymbolPicker: some View {
        HStack(spacing: 8) {
            Text(L10n.t("符号"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Spacer()
            ForEach(SalaryCurrency.symbols, id: \.self) { symbol in
                Button {
                    draft.currencySymbol = symbol
                } label: {
                    Text(symbol)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 34, height: 32)
                        .background(draft.currencySymbol == symbol ? AppTheme.coin : AppTheme.softSurface.opacity(0.74))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline.opacity(0.74), lineWidth: 1))
                }
                .buttonStyle(.plain)
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
                HStack {
                    Text(L10n.t("每日工作时长"))
                    Spacer()
                    Text(workHoursText)
                        .fontWeight(.heavy)
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Workday.displayOrder) { day in
                        Button {
                            toggleWorkday(day)
                        } label: {
                            VStack(spacing: 4) {
                                Text(day.shortTitle)
                                    .font(.headline.weight(.black))
                                Text(day.title)
                                    .font(.caption2.weight(.heavy))
                            }
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(draft.workdays.contains(day.rawValue) ? AppTheme.coin : AppTheme.softSurface.opacity(0.74))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.2)
                            }
                        }
                        .buttonStyle(.plain)
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
                        Text(L10n.t("午休时间（PRO）"))
                            .font(.headline.weight(.heavy))
                        Text(appState.canUseLunchBreakSettings ? L10n.t("开启后午休不会计入今日已赚和进度。") : L10n.t("开通 PRO 后可设置午休暂停计薪。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    if appState.canUseLunchBreakSettings {
                        Toggle("", isOn: $draft.deductLunch)
                            .labelsHidden()
                            .tint(AppTheme.coin)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.coin.opacity(0.78))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))
                    }
                }

                if appState.canUseLunchBreakSettings && draft.deductLunch {
                    timeRow(title: L10n.t("午休开始"), time: $draft.lunchStart)
                    timeRow(title: L10n.t("午休结束"), time: $draft.lunchEnd)
                } else if !appState.canUseLunchBreakSettings {
                    Button {
                        showsProUpsell = true
                        appState.requireProFeature(L10n.t("午休时间设置是 PRO 功能，开通后可让收入进度自动跳过午休。"))
                    } label: {
                        Text(L10n.t("开通 PRO 后使用"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.coin)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
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
                HStack(spacing: 10) {
                    PreviewMetric(title: L10n.t("预计日薪"), value: daySalary.moneyText(currencySymbol: draft.currencySymbol))
                    PreviewMetric(title: L10n.t("每秒回血"), value: "\(draft.currencySymbol)\(String(format: "%.4f", perSecond))")
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

    private var workdaySummary: String {
        let selected = Workday.displayOrder.filter { draft.workdays.contains($0.rawValue) }
        guard !selected.isEmpty else { return L10n.t("未选择") }
        return selected.map(\.title).joined(separator: "、")
    }

    private var validationMessage: String? {
        guard draft.salaryAmount > 0 else { return L10n.t("薪资金额要大于 0，钱包才知道怎么回血。") }
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
        HStack {
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
            DatePicker("", selection: dateBinding(for: time), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(AppTheme.coin)
        }
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
        didLoad = true
    }

    private func save() {
        guard canSave else { return }
        appState.settings = appState.sanitizeSettingsForCurrentPlan(draft)
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
