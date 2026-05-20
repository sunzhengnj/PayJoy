import SwiftUI

enum SalarySettingsMode {
    case salary
    case workTime
    case all

    var title: String {
        switch self {
        case .salary: "薪资设置"
        case .workTime: "工作时间设置"
        case .all: "薪资设置"
        }
    }

    var subtitle: String {
        switch self {
        case .salary: "设置年薪、月薪、日薪或时薪。"
        case .workTime: "设置计薪日、上下班和午休时间。"
        case .all: "输入薪资和工作时间，开薪马上开始。"
        }
    }
}

struct SalarySettingsView: View {
    var mode: SalarySettingsMode = .all
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SalarySettings.defaultValue
    @State private var amountText = ""
    @State private var didLoad = false

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
                PrimaryButton(title: "保存设置") {
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
    }

    private var titleBlock: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("薪资设置")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .hidden()
            }
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    Text(mode.subtitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }
            }
            Spacer()
            AssetImage(name: "cat_corner_redraw_v1")
                .frame(width: 88, height: 58)
        }
    }

    private var salaryTypePicker: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("薪资类型")
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
                            .background(type == draft.salaryType ? AppTheme.coin : Color.white.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.ink, lineWidth: 1.3)
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
                HStack {
                    Text("¥")
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
                            Text(amount.compactMoneyText)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(AppTheme.coin.opacity(0.45))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.ink, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider().overlay(AppTheme.divider)
                Stepper(value: $draft.monthlyPaidDays, in: 1...31, step: 0.25) {
                    HStack {
                        Text("月计薪天数")
                        Spacer()
                        Text("\(draft.monthlyPaidDays, specifier: "%.2f") 天")
                            .fontWeight(.heavy)
                    }
                    .font(.caption.weight(.bold))
                }
                .tint(AppTheme.coin)
                Text("默认 21.75 天，适合多数固定月薪场景；时薪模式会按每日工作时长计算。")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var workTimeCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("工作时间")
                    .font(.headline.weight(.heavy))
                timeRow(title: "上班时间", time: $draft.workStart)
                timeRow(title: "下班时间", time: $draft.workEnd)
                HStack {
                    Text("每日工作时长")
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
                Text("计薪日")
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
                            .background(draft.workdays.contains(day.rawValue) ? AppTheme.coin : Color.white.opacity(0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.ink, lineWidth: 1.2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("可自由选择周一到周日任意计薪日；未选中的日期首页会显示休息日。")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var lunchCard: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $draft.deductLunch) {
                    Text("午休时间（可选）")
                        .font(.headline.weight(.heavy))
                }
                .tint(AppTheme.coin)
                if draft.deductLunch {
                    timeRow(title: "午休开始", time: $draft.lunchStart)
                    timeRow(title: "午休结束", time: $draft.lunchEnd)
                    Text("开启后，午休时间不会计入今日已赚和进度。")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }
            }
        }
    }

    private var previewCard: some View {
        let calculator = SalaryCalculator()
        let daySalary = calculator.dailySalary(for: draft)
        let seconds = calculator.workingSecondsPerDay(settings: draft)
        let perSecond = seconds > 0 ? daySalary / seconds : 0

        return ComicCard(background: Color(hex: 0xFFF1A8)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("保存后首页会这样算")
                    .font(.headline.weight(.heavy))
                HStack(spacing: 10) {
                    PreviewMetric(title: "预计日薪", value: daySalary.moneyText)
                    PreviewMetric(title: "每秒回血", value: "¥\(String(format: "%.4f", perSecond))")
                }
                Text("计薪日：\(workdaySummary)。未选中日期可在首页临时开启加班计薪。")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }
        }
    }

    private var workHoursText: String {
        let calculator = SalaryCalculator()
        let hours = calculator.workingSecondsPerDay(settings: draft) / 3_600
        return String(format: "%.1f 小时", hours)
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
        guard !selected.isEmpty else { return "未选择" }
        return selected.map(\.title).joined(separator: "、")
    }

    private var validationMessage: String? {
        guard draft.salaryAmount > 0 else { return "薪资金额要大于 0，钱包才知道怎么回血。" }
        guard draft.monthlyPaidDays > 0 else { return "月计薪天数要大于 0。" }
        guard !draft.workdays.isEmpty else { return "至少选择一天作为计薪日。" }
        guard draft.workEnd.minutesFromStartOfDay > draft.workStart.minutesFromStartOfDay else {
            return "下班时间必须晚于上班时间。"
        }
        if draft.deductLunch {
            guard draft.lunchEnd.minutesFromStartOfDay > draft.lunchStart.minutesFromStartOfDay else {
                return "午休结束时间必须晚于午休开始时间。"
            }
            guard draft.lunchStart.minutesFromStartOfDay >= draft.workStart.minutesFromStartOfDay,
                  draft.lunchEnd.minutesFromStartOfDay <= draft.workEnd.minutesFromStartOfDay else {
                return "午休时间需要落在上班和下班之间。"
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
        draft = appState.settings
        amountText = draft.salaryAmount.formatted(.number.precision(.fractionLength(0...2)))
        didLoad = true
    }

    private func save() {
        guard canSave else { return }
        appState.settings = draft
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
                .stroke(AppTheme.ink, lineWidth: 1.1)
        }
    }
}
