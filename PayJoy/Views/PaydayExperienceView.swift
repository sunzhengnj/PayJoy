import SwiftUI
import UIKit

struct PaydayCelebrationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var heroArrived = false
    @State private var contentArrived = false
    @State private var showsActualSalaryEntry = false
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false
    @State private var shareItem: PaydayShareItem?
    @State private var shareError: String?
    private let presentsMembershipPromptOnAppear: Bool

    init(presentsMembershipPromptOnAppear: Bool = false) {
        self.presentsMembershipPromptOnAppear = presentsMembershipPromptOnAppear
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                HStack {
                    Text(L10n.appDisplayName)
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textGray)
                    Spacer()
                    Button(L10n.t("稍后")) {
                        appState.dismissPaydayCelebration()
                        dismiss()
                    }
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(minWidth: 52, minHeight: 44)
                    .buttonStyle(PayJoyPressStyle(scale: 0.94, reduceMotion: prefersReducedMotion))
                }
                .padding(.horizontal, AppTheme.pagePadding)

                hero

                VStack(spacing: 9) {
                    Text(L10n.t("工资到账啦"))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(paydayDateText)
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(AppTheme.coin)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))

                    Text(appState.todayPaydayAmountIsActual ? L10n.t("本月实际薪资") : L10n.t("预计薪资"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(appState.todayPaydayAmountIsActual ? AppTheme.coin : AppTheme.softSurface.opacity(0.78))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline.opacity(0.86), lineWidth: 1))

                    Text(
                        PrivacyText.money(
                            appState.todayPaydayAmount,
                            hidden: appState.preferences.hideSensitiveAmounts,
                            currencySymbol: appState.settings.currencySymbol
                        )
                    )
                        .font(.system(size: 43, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .monospacedDigit()

                    Text(
                        appState.todayPaydayAmountIsActual
                            ? L10n.t("已同步到统计，辛苦有了准确回音。")
                            : L10n.t("到账后可填入真实金额，今天先收下这份快乐。")
                    )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .opacity(contentArrived ? 1 : 0)
                .offset(y: contentArrived ? 0 : 18)

                VStack(spacing: 9) {
                    Button {
                        if appState.hasEffectivePro {
                            showsActualSalaryEntry = true
                        } else {
                            showsMembershipPrompt = true
                        }
                    } label: {
                        Text(appState.todayPaydayAmountIsActual ? L10n.t("修改实际薪资") : L10n.t("填入实际薪资"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(AppTheme.softSurface.opacity(0.76))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.4)
                            }
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))

                    PrimaryButton(title: L10n.t("分享这份快乐"), reduceMotion: prefersReducedMotion) {
                        exportSharePoster()
                    }

                    PaydayPrivacyControl(
                        isOn: appState.hidesPaydayShareAmount,
                        title: L10n.t(
                            appState.preferences.hideSensitiveAmounts
                                ? "金额隐私模式已开启"
                                : "分享时隐藏金额"
                        )
                    ) {
                        guard !appState.preferences.hideSensitiveAmounts else { return }
                        appState.setPaydayShareHidesAmount(!appState.preferences.paydayShareHidesAmount)
                    }
                    .disabled(appState.preferences.hideSensitiveAmounts)

                    if let shareError {
                        Text(shareError)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.red)
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 18)
                .opacity(contentArrived ? 1 : 0)
            }
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
        .sheet(isPresented: $showsActualSalaryEntry) {
            ActualSalaryEntrySheet(month: appState.now)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
        }
        .sheet(item: $shareItem) { item in
            PaydayActivityView(activityItems: [item.url])
        }
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsProPaywall = true
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
        .onAppear {
            beginEntrance()
            guard presentsMembershipPromptOnAppear else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showsMembershipPrompt = true
            }
        }
        .transaction { transaction in
            guard prefersReducedMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var hero: some View {
        AssetImage(name: AppTheme.paydayRocketAsset)
            .frame(maxWidth: .infinity)
            .frame(height: 370)
            .scaleEffect(heroArrived ? 1 : 0.72, anchor: .bottomLeading)
            .rotationEffect(.degrees(heroArrived ? 0 : -9))
            .offset(x: heroArrived ? 0 : -72, y: heroArrived ? 0 : 74)
            .opacity(heroArrived ? 1 : 0)
            .comicIdleBob(enabled: heroArrived && !prefersReducedMotion, amplitude: 5, rotation: 2.2, duration: 2.8)
            .accessibilityHidden(true)
    }

    private var paydayDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentMarket.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return L10n.format("%@ · 本月发薪日", formatter.string(from: appState.now))
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private func beginEntrance() {
        guard !prefersReducedMotion else {
            heroArrived = true
            contentArrived = true
            return
        }
        withAnimation(.spring(response: 0.72, dampingFraction: 0.7)) {
            heroArrived = true
        }
        withAnimation(.easeOut(duration: 0.42).delay(0.28)) {
            contentArrived = true
        }
    }

    @MainActor
    private func exportSharePoster() {
        let poster = PaydaySharePoster(
            date: appState.now,
            amount: appState.todayPaydayAmount,
            amountIsActual: appState.todayPaydayAmountIsActual,
            hidesAmount: appState.hidesPaydayShareAmount,
            currencySymbol: appState.settings.currencySymbol
        )
        .frame(width: 360, height: 450)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            shareError = L10n.t("分享图生成失败，请稍后再试。")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClockJoy-Payday-\(appState.todayDateKey).png")
        do {
            try data.write(to: url, options: .atomic)
            shareError = nil
            shareItem = PaydayShareItem(url: url)
        } catch {
            shareError = L10n.t("分享图生成失败，请稍后再试。")
        }
    }
}

struct PaydaySoonCard: View {
    let daysUntilPayday: Int

    var body: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 13) {
            HStack(spacing: 10) {
                AssetImage(name: AppTheme.paydayRocketAsset)
                    .frame(width: 72, height: 60)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.black))
                    Text(L10n.t("到时候会有一个小彩蛋。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var title: String {
        daysUntilPayday == 1
            ? L10n.t("明天发薪")
            : L10n.format("还有 %d 天发薪", daysUntilPayday)
    }
}

struct PaydayTodayCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        Button {
            appState.openPaydayCelebration()
        } label: {
            ComicCard(background: AppTheme.highlightCardBackground, padding: 13) {
                HStack(spacing: 10) {
                    AssetImage(name: AppTheme.paydayRocketAsset)
                        .frame(width: 92, height: 76)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("今天是发薪日"))
                            .font(.headline.weight(.black))
                        Text(appState.todayPaydayAmountIsActual ? L10n.t("实际薪资已记录，随时打开分享。") : L10n.t("彩蛋全天开放，也可以填入到账金额。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.t("打开发薪彩蛋"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.coin)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
        .accessibilityLabel(L10n.t("打开发薪彩蛋"))
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }
}

struct ActualSalaryHistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var entryMonth: ActualSalaryMonthSelection?
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("只记录每月到账总额，统计会自动用实际金额替换估算，不做记账。"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .fixedSize(horizontal: false, vertical: true)

                yearSelector

                yearSummaryCard

                Text(L10n.t("最近月份"))
                    .font(.headline.weight(.black))

                LazyVStack(spacing: 10) {
                    ForEach(displayedMonths, id: \.self) { month in
                        let date = monthDate(year: selectedYear, month: month)
                        monthRow(date)
                    }
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 28)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationTitle(L10n.t("实际薪资"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedYear = Calendar.current.component(.year, from: appState.now)
            appState.isTabBarHidden = true
        }
        .onDisappear {
            appState.isTabBarHidden = false
        }
        .sheet(item: $entryMonth) { selection in
            ActualSalaryEntrySheet(month: selection.date)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
        }
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsProPaywall = true
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
    }

    private var yearSelector: some View {
        HStack(spacing: 10) {
            Button(L10n.t("上一年")) {
                selectedYear -= 1
            }
            .frame(minWidth: 72, minHeight: 44)
            .buttonStyle(PayJoyPressStyle(scale: 0.95, reduceMotion: prefersReducedMotion))

            Text(String(selectedYear))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)

            Button(L10n.t("下一年")) {
                selectedYear += 1
            }
            .frame(minWidth: 72, minHeight: 44)
            .buttonStyle(PayJoyPressStyle(scale: 0.95, reduceMotion: prefersReducedMotion))
            .disabled(selectedYear >= currentYear)
            .opacity(selectedYear >= currentYear ? 0.32 : 1)
        }
        .font(.subheadline.weight(.black))
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 12)
        .background(AppTheme.softSurface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(AppTheme.outline, lineWidth: 1.2))
    }

    private var yearSummaryCard: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 13) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    yearSummaryLabels
                    Spacer(minLength: 8)
                    yearSummaryAmount
                }

                VStack(alignment: .leading, spacing: 8) {
                    yearSummaryLabels
                    yearSummaryAmount
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var yearSummaryLabels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t("实际到账合计"))
                .font(.subheadline.weight(.black))
            Text(L10n.format("已记录 %@ 个月", "\(selectedYearRecords.count)"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
        }
    }

    private var yearSummaryAmount: some View {
        Text(
            PrivacyText.money(
                selectedYearActualAmount,
                hidden: appState.preferences.hideSensitiveAmounts,
                currencySymbol: appState.settings.currencySymbol
            )
        )
        .font(.system(size: 29, weight: .black, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .monospacedDigit()
    }

    private func monthRow(_ date: Date) -> some View {
        let canEnter = appState.canEnterActualSalary(for: date)
        let record = appState.actualSalaryRecord(for: date)
        let estimate = appState.estimatedSalaryMonthSummary(for: date)
        let recordMatchesCurrency = record?.currencyCode == appState.settings.currencyCode

        return Button {
            guard canEnter else { return }
            if appState.hasEffectivePro {
                entryMonth = ActualSalaryMonthSelection(date: date)
            } else {
                showsMembershipPrompt = true
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(monthTitle(date))
                        .font(.headline.weight(.black))
                    Text(
                        record == nil
                            ? (canEnter ? L10n.t("填入到账金额") : L10n.t("发薪日后可填"))
                            : (recordMatchesCurrency ? L10n.t("实际薪资") : L10n.t("历史币种记录"))
                    )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(
                        PrivacyText.money(
                            record?.amount ?? estimate.projectedAmount,
                            hidden: appState.preferences.hideSensitiveAmounts,
                            currencySymbol: record?.currencyCode.displaySymbol ?? appState.settings.currencySymbol
                        )
                    )
                        .font(.subheadline.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(
                        monthDetailText(
                            canEnter: canEnter,
                            record: record,
                            recordMatchesCurrency: recordMatchesCurrency,
                            estimate: estimate
                        )
                    )
                        .font(.caption2.weight(.black))
                        .foregroundStyle(canEnter ? AppTheme.ink : AppTheme.textGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(AppTheme.ink)
            .padding(13)
            .background(recordMatchesCurrency ? AppTheme.highlightCardBackground : AppTheme.softSurface.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.outline, lineWidth: recordMatchesCurrency ? 1.5 : 1))
            .opacity(canEnter ? 1 : 0.5)
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
        .disabled(!canEnter)
    }

    private var selectedYearRecords: [ActualSalaryRecord] {
        appState.actualSalaryRecords.filter {
            $0.currencyCode == appState.settings.currencyCode && $0.monthKey.hasPrefix("\(selectedYear)-")
        }
    }

    private var selectedYearActualAmount: Double {
        selectedYearRecords.reduce(0) { $0 + $1.amount }
    }

    private var displayedMonths: [Int] {
        let lastMonth = selectedYear == currentYear
            ? Calendar.current.component(.month, from: appState.now)
            : 12
        return Array((1...lastMonth).reversed())
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: appState.now)
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private func monthDate(year: Int, month: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? appState.now
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentMarket.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    private func monthDetailText(
        canEnter: Bool,
        record: ActualSalaryRecord?,
        recordMatchesCurrency: Bool,
        estimate: SalaryMonthSummary
    ) -> String {
        guard canEnter else { return L10n.t("未到发薪时间") }
        guard let record else { return L10n.t("预计薪资") }
        guard recordMatchesCurrency else { return L10n.t("点按更新币种") }

        let difference = record.amount - estimate.projectedAmount
        if abs(difference) < 0.005 {
            return L10n.t("与预计一致")
        }
        let amount = PrivacyText.money(
            abs(difference),
            hidden: appState.preferences.hideSensitiveAmounts,
            currencySymbol: appState.settings.currencySymbol
        )
        return difference > 0
            ? L10n.format("比预计多 %@", amount)
            : L10n.format("比预计少 %@", amount)
    }
}

struct ActualSalaryEntrySheet: View {
    let month: Date
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var amountText = ""
    @State private var didLoad = false
    @State private var saveError: String?
    @State private var showsDeleteConfirmation = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(existingRecord == nil ? L10n.t("填入实际薪资") : L10n.t("修改实际薪资"))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        Text(monthTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }

                    Spacer(minLength: 4)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.softSurface.opacity(0.8))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.1))
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.94, reduceMotion: prefersReducedMotion))
                    .accessibilityLabel(L10n.t("关闭实际薪资填写"))
                }

                HStack {
                    Text(L10n.t("当前预计"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textGray)
                    Spacer()
                    Text(
                        PrivacyText.money(
                            estimate.projectedAmount,
                            hidden: appState.preferences.hideSensitiveAmounts,
                            currencySymbol: appState.settings.currencySymbol
                        )
                    )
                        .font(.subheadline.weight(.black))
                        .monospacedDigit()
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 46)
                .background(AppTheme.softSurface.opacity(0.74))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.outline.opacity(0.8), lineWidth: 1.1))

                ComicCard(background: AppTheme.highlightCardBackground) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("实际到账金额"))
                            .font(.headline.weight(.black))
                        HStack(spacing: 8) {
                            Text(appState.settings.currencySymbol)
                                .font(.title2.weight(.black))
                            TextField(L10n.t("输入到账金额"), text: $amountText)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .keyboardType(.decimalPad)
                                .accessibilityLabel(L10n.t("实际到账金额"))
                                .onChange(of: amountText) { _, value in
                                    let sanitized = sanitizeAmount(value)
                                    if sanitized != value { amountText = sanitized }
                                    saveError = nil
                                }
                            Text(appState.settings.currencyCode.rawValue)
                                .font(.caption.weight(.black))
                                .foregroundStyle(AppTheme.textGray)
                        }

                        if let differenceText {
                            Text(differenceText)
                                .font(.caption.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(AppTheme.coin.opacity(0.72))
                                .clipShape(Capsule())
                        }

                        Text(L10n.t("填写这个月最终到账总额，保存后会自动更新月度、年度统计和工资报告。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if hasCurrencyMismatch, let record = existingRecord {
                    Text(
                        L10n.format(
                            "原记录使用 %@，不会计入当前币种统计。保存后将按当前币种替换。",
                            record.currencyCode.displaySymbol
                        )
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryButton(title: L10n.t("保存实际薪资"), reduceMotion: prefersReducedMotion) {
                    save()
                }
                .disabled(parsedAmount == nil)
                .opacity(parsedAmount == nil ? 0.45 : 1)

                if existingRecord != nil {
                    Button(L10n.t("删除本月实际薪资"), role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }

                if let saveError {
                    Text(saveError)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.red)
                }
            }
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .payJoyKeyboardDismissToolbar()
        .onAppear(perform: load)
        .confirmationDialog(
            L10n.t("删除实际薪资？"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.t("确认删除"), role: .destructive) {
                appState.removeActualSalary(for: month)
                dismiss()
            }
            Button(L10n.t("取消"), role: .cancel) {}
        } message: {
            Text(L10n.t("删除后，该月会恢复使用预计薪资。"))
        }
    }

    private var parsedAmount: Double? {
        guard let value = Double(amountText), value.isFinite, value > 0 else { return nil }
        return value
    }

    private var existingRecord: ActualSalaryRecord? {
        appState.actualSalaryRecord(for: month)
    }

    private var estimate: SalaryMonthSummary {
        appState.estimatedSalaryMonthSummary(for: month)
    }

    private var differenceText: String? {
        guard let amount = parsedAmount else { return nil }
        let difference = amount - estimate.projectedAmount
        if abs(difference) < 0.005 {
            return L10n.t("与预计一致")
        }
        let value = PrivacyText.money(
            abs(difference),
            hidden: appState.preferences.hideSensitiveAmounts,
            currencySymbol: appState.settings.currencySymbol
        )
        return difference > 0
            ? L10n.format("比预计多 %@", value)
            : L10n.format("比预计少 %@", value)
    }

    private var hasCurrencyMismatch: Bool {
        guard let existingRecord else { return false }
        return existingRecord.currencyCode != appState.settings.currencyCode
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentMarket.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: month)
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private func load() {
        guard !didLoad else { return }
        if let record = existingRecord,
           record.currencyCode == appState.settings.currencyCode {
            amountText = record.amount.formatted(.number.precision(.fractionLength(0...2)))
        }
        didLoad = true
    }

    private func save() {
        guard let amount = parsedAmount,
              appState.saveActualSalary(amount: amount, for: month) else {
            saveError = L10n.t("这个月份暂时不能填写实际薪资。")
            return
        }
        dismiss()
    }

    private func sanitizeAmount(_ input: String) -> String {
        var hasDecimalPoint = false
        var fractionDigits = 0
        var result = ""
        for character in input {
            if character == "." {
                guard !hasDecimalPoint else { continue }
                hasDecimalPoint = true
                result.append(character)
            } else if character.isNumber {
                if hasDecimalPoint {
                    guard fractionDigits < 2 else { continue }
                    fractionDigits += 1
                }
                result.append(character)
            }
        }
        return result
    }
}

private struct PaydayPrivacyControl: View {
    let isOn: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? AppTheme.coin : AppTheme.divider)
                        .frame(width: 42, height: 24)
                    Circle()
                        .fill(AppTheme.softSurface)
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 3)
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1))
                }
                Text(title)
                    .font(.caption.weight(.black))
                Spacer()
                Text(isOn ? L10n.t("已隐藏") : L10n.t("显示金额"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.textGray)
            }
            .foregroundStyle(AppTheme.ink)
            .frame(minHeight: 44)
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.97))
        .accessibilityValue(isOn ? L10n.t("已开启") : L10n.t("未开启"))
    }
}

private struct PaydaySharePoster: View {
    let date: Date
    let amount: Double
    let amountIsActual: Bool
    let hidesAmount: Bool
    let currencySymbol: String

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 360
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.appDisplayName)
                        .font(.system(size: 11 * unit, weight: .black, design: .rounded))
                    Spacer()
                    Text(dateText)
                        .font(.system(size: 10 * unit, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textGray)
                }
                .padding(.horizontal, 16 * unit)
                .padding(.top, 14 * unit)

                AssetImage(name: AppTheme.paydayRocketAsset)
                    .frame(width: 330 * unit, height: 250 * unit)
                    .accessibilityHidden(true)

                VStack(spacing: 6 * unit) {
                    Text(L10n.t("工资到账啦"))
                        .font(.system(size: 27 * unit, weight: .black, design: .rounded))
                    Text(hidesAmount ? L10n.t("今天，努力有了回音") : amount.moneyText(currencySymbol: currencySymbol))
                        .font(.system(size: (hidesAmount ? 21 : 31) * unit, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                    if !hidesAmount {
                        Text(amountIsActual ? L10n.t("实际薪资") : L10n.t("预计薪资"))
                            .font(.system(size: 9 * unit, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Text(L10n.t("辛苦有回音，今天可以对自己好一点。"))
                        .font(.system(size: 10 * unit, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textGray)
                }
                .padding(.horizontal, 18 * unit)

                Spacer(minLength: 8 * unit)

                HStack {
                    Text(L10n.t("由 ClockJoy 开薪生成"))
                    Spacer()
                    Text(AppTheme.current.title)
                }
                .font(.system(size: 8.5 * unit, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textGray)
                .padding(.horizontal, 16 * unit)
                .padding(.bottom, 13 * unit)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(AppTheme.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 22 * unit, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 2 * unit)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("发薪日分享图"))
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: L10n.currentMarket.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter.string(from: date)
    }
}

private struct ActualSalaryMonthSelection: Identifiable {
    let id = UUID()
    let date: Date
}

private struct PaydayShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PaydayActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
