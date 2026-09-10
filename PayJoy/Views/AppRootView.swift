import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var didPrepareAppLock = false

    var body: some View {
        @Bindable var appState = appState

        GeometryReader { proxy in
            let needsInitialSetup = !appState.preferences.hasCompletedInitialSetup
            ZStack(alignment: .bottom) {
                AppTheme.paper.ignoresSafeArea()

                Group {
                    if needsInitialSetup {
                        NavigationStack { EmotionalOnboardingView() }
                    } else {
                        switch appState.selectedTab {
                        case .home:
                            NavigationStack { HomeView() }
                        case .stats:
                            NavigationStack { StatsView() }
                        case .wish:
                            NavigationStack { WishExperienceView() }
                        case .profile:
                            NavigationStack { ProfileView() }
                        }
                    }
                }
                .padding(.bottom, appState.isTabBarHidden || needsInitialSetup ? 0 : 58)

                if !appState.isTabBarHidden && !needsInitialSetup {
                    ComicTabBar(selectedTab: $appState.selectedTab)
                        .padding(.bottom, max(-22, -proxy.safeAreaInsets.bottom + 8))
                        .ignoresSafeArea(.container, edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if appState.shouldShowPrivacyShield {
                    AppPrivacyShield(
                        requiresPasscode: appState.isAppLocked,
                        message: appState.appLockMessage,
                        onSubmit: { passcode in
                            appState.unlockApp(with: passcode)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .animation(prefersReducedMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: appState.isTabBarHidden)
            .animation(prefersReducedMotion ? nil : .easeOut(duration: 0.16), value: appState.shouldShowPrivacyShield)
        }
        .fullScreenCover(isPresented: $appState.shouldPresentPaydayCelebration) {
            PaydayCelebrationView()
        }
        .sheet(isPresented: $appState.shouldPresentClosingReceipt) {
            ClosingReceiptFlowView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppTheme.paper)
                .interactiveDismissDisabled(false)
                .onDisappear {
                    appState.closeClosingReceipt()
                }
        }
        .onAppear {
            guard !didPrepareAppLock else { return }
            appState.prepareAppLockOnLaunch()
            appState.applicationDidBecomeActive()
            didPrepareAppLock = true
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                appState.applicationDidBecomeActive()
            case .inactive, .background:
                appState.applicationWillResignActive()
            @unknown default:
                appState.applicationWillResignActive()
            }
        }
        .task {
            while !Task.isCancelled {
                appState.updateClock()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .transaction { transaction in
            guard appState.preferences.reduceMotion || accessibilityReduceMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }
}

struct EmotionalOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft = SalarySettings.defaultValue
    @State private var salaryAmountText = ""
    @State private var workStart = Date()
    @State private var workEnd = Date()
    @State private var showsAdvancedSettings = false
    @State private var didPrepareDefaults = false
    @State private var heroIsFloating = false

    var body: some View {
        VStack(spacing: 0) {
            onboardingHeader

            ScrollView(showsIndicators: false) {
                payStep
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.vertical, 18)
            }

            onboardingActions
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .payJoyKeyboardDismissToolbar()
        .onAppear(perform: prepareDefaultsIfNeeded)
        .onAppear {
            guard !accessibilityReduceMotion, !appState.preferences.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                heroIsFloating = true
            }
        }
    }

    private var onboardingHeader: some View {
        Text(L10n.appDisplayName)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
        .padding(.horizontal, AppTheme.pagePadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(AppTheme.paper)
    }

    private var payStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            onboardingPayHero

            ComicCard {
                VStack(alignment: .leading, spacing: 14) {
                    onboardingTitle(
                        L10n.t("工资和上下班时间"),
                        subtitle: L10n.t("用于趣味工资进度与收工仪式，不做工资或税务核算。")
                    )

                    LazyVGrid(columns: onboardingChoiceColumns, spacing: 8) {
                        ForEach(SalaryType.allCases) { type in
                            Button {
                                draft.salaryType = type
                            } label: {
                                Text(type.title)
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .background(draft.salaryType == type ? AppTheme.coin : AppTheme.softSurface)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PayJoyPressStyle(scale: 0.97, reduceMotion: prefersReducedMotion))
                            .accessibilityLabel(type.title)
                            .accessibilityAddTraits(draft.salaryType == type ? .isSelected : [])
                            .accessibilityValue(draft.salaryType == type ? L10n.t("已选择") : L10n.t("未选择"))
                        }
                    }

                    HStack(spacing: 10) {
                        Menu {
                            ForEach(CurrencyCode.allCases) { code in
                                Button("\(code.rawValue) · \(code.displaySymbol)") {
                                    draft.setCurrencyCode(code)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(draft.currencyCode.rawValue)
                                Image(systemName: "chevron.down")
                            }
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 48)
                            .background(AppTheme.softSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }

                        TextField("10000", text: $salaryAmountText)
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .keyboardType(.decimalPad)
                            .onChange(of: salaryAmountText) { _, value in
                                let normalized = value.replacingOccurrences(of: ",", with: "")
                                draft.salaryAmount = Double(normalized) ?? 0
                            }
                    }

                    Divider().overlay(AppTheme.divider)

                    DatePicker(
                        L10n.t("上班时间"),
                        selection: $workStart,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.headline.weight(.black))
                    .environment(\.locale, Locale(identifier: L10n.currentMarket.localeIdentifier))

                    Divider().overlay(AppTheme.divider)

                    DatePicker(
                        L10n.t("下班时间"),
                        selection: $workEnd,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.headline.weight(.black))
                    .environment(\.locale, Locale(identifier: L10n.currentMarket.localeIdentifier))
                }
            }

            DisclosureGroup(isExpanded: $showsAdvancedSettings) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.t("工作日"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textGray)

                    HStack(spacing: 6) {
                        ForEach(Workday.displayOrder) { day in
                            Button {
                                if draft.workdays.contains(day.rawValue) {
                                    if draft.workdays.count > 1 {
                                        draft.workdays.remove(day.rawValue)
                                    }
                                } else {
                                    draft.workdays.insert(day.rawValue)
                                }
                                updateEstimatedPaidDays()
                            } label: {
                                Text(day.shortTitle)
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(draft.workdays.contains(day.rawValue) ? AppTheme.coin : AppTheme.softSurface)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PayJoyPressStyle(scale: 0.96, reduceMotion: prefersReducedMotion))
                            .accessibilityLabel(day.title)
                            .accessibilityAddTraits(draft.workdays.contains(day.rawValue) ? .isSelected : [])
                            .accessibilityValue(draft.workdays.contains(day.rawValue) ? L10n.t("已选择") : L10n.t("未选择"))
                        }
                    }

                    Text(monthlyEstimateText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                }
                .padding(.top, 14)
            } label: {
                HStack(spacing: 10) {
                    Text(showsAdvancedSettings ? "02" : "01")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 34, height: 28)
                        .background(showsAdvancedSettings ? AppTheme.coin : AppTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(AppTheme.outline, lineWidth: 1)
                        }
                        .accessibilityHidden(true)
                    Text(L10n.t("高级设置"))
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .padding(16)
            .background(AppTheme.softSurface.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var onboardingPayHero: some View {
        ZStack(alignment: .bottomLeading) {
            AssetImage(name: "onboarding_time_to_income_v1", contentMode: .fill)
                .scaleEffect(heroIsFloating ? 1.035 : 1.015)
                .offset(y: heroIsFloating ? -3 : 3)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 178 : 218)
                .clipped()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.t("第一次见，先把开薪搭起来！"))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                Text(L10n.t("每一分钟，都在靠近下班。"))
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.7)
        }
        .shadow(color: AppTheme.shadow.opacity(0.16), radius: 1, x: 3, y: 3)
        .accessibilityElement(children: .combine)
    }

    private var onboardingActions: some View {
        PrimaryButton(title: L10n.t("开始今天的小快乐"), reduceMotion: prefersReducedMotion) {
            advance()
        }
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.48)
        .accessibilityValue(canAdvance ? L10n.t("可以继续") : onboardingValidationMessage)
        .padding(.horizontal, AppTheme.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(AppTheme.paper)
        .overlay(alignment: .top) {
            Divider().overlay(AppTheme.divider.opacity(0.68))
        }
    }

    private var canAdvance: Bool {
        draft.salaryAmount > 0 && workEnd > workStart
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appState.preferences.reduceMotion
    }

    private var onboardingValidationMessage: String {
        if draft.salaryAmount <= 0 {
            return L10n.t("请输入大于 0 的有效金额。")
        }
        return L10n.t("下班时间必须晚于上班时间。")
    }

    private var onboardingChoiceColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
        )
    }

    private var monthlyEstimateText: String {
        L10n.format("月均约 %.2f 个计薪日，仅用于趣味进度。", draft.monthlyPaidDays)
    }

    private func onboardingTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            Text(subtitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func prepareDefaultsIfNeeded() {
        guard !didPrepareDefaults else { return }
        didPrepareDefaults = true
        let market = appState.preferences.resolvedMarket
        let currencyCode = CurrencyCode.defaultCode(for: market)
        draft.setCurrencyCode(currencyCode)
        draft.salaryAmount = defaultSalaryAmount(for: market)
        salaryAmountText = String(format: "%.0f", draft.salaryAmount)
        if market == .mainlandChina {
            draft.monthlyPaidDays = 21.75
        } else {
            updateEstimatedPaidDays()
        }
        workStart = date(for: draft.workStart)
        workEnd = date(for: draft.workEnd)
    }

    private func advance() {
        guard canAdvance else { return }
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: workStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: workEnd)
        draft.workStart = WorkTime(hour: startComponents.hour ?? 9, minute: startComponents.minute ?? 0)
        draft.workEnd = WorkTime(hour: endComponents.hour ?? 18, minute: endComponents.minute ?? 0)
        appState.completeEmotionalOnboarding(
            settings: draft,
            companionID: CompanionProfile.defaultValue.id
        )
    }

    private func updateEstimatedPaidDays() {
        guard appState.preferences.resolvedMarket != .mainlandChina else { return }
        draft.monthlyPaidDays = min(31, max(1, Double(draft.workdays.count) * 52 / 12))
    }

    private func date(for time: WorkTime) -> Date {
        Calendar.current.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func defaultSalaryAmount(for market: AppMarket) -> Double {
        switch market {
        case .mainlandChina: 10_000
        case .taiwan: 45_000
        case .hongKong: 20_000
        case .japan: 300_000
        case .southKorea: 3_000_000
        case .globalEnglish: 4_000
        }
    }
}

private struct AppPrivacyShield: View {
    let requiresPasscode: Bool
    let message: String?
    let onSubmit: (String) -> Bool
    @State private var passcode = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x063B42),
                    Color(hex: 0x0A1A22),
                    Color(hex: 0x083A35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: requiresPasscode ? "lock.fill" : "eye.slash.fill")
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 98, height: 98)
                    .background(
                        RadialGradient(
                            colors: [AppTheme.coin, AppTheme.orange],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 88
                        )
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 3))
                    .shadow(color: AppTheme.coin.opacity(0.35), radius: 18, x: 0, y: 8)

                VStack(spacing: 6) {
                    Text(requiresPasscode ? L10n.t("开薪已锁定") : L10n.t("开薪隐私保护中"))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(requiresPasscode ? L10n.t("请输入 4 位密码继续。") : L10n.t("多任务预览已隐藏你的收入和工作信息。"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.74))
                        .multilineTextAlignment(.center)
                }

                if requiresPasscode {
                    VStack(spacing: 18) {
                        HiddenPasscodeField(passcode: $passcode) {
                            submit()
                        }
                        PasscodeDots(count: passcode.count)
                        NumberPad(passcode: $passcode)
                        if let message {
                            Text(message)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(AppTheme.coin)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 34)
        }
        .onChange(of: passcode) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(4))
            if digits != newValue {
                passcode = digits
                return
            }
            if digits.count == 4 {
                submit()
            }
        }
    }

    private func submit() {
        guard passcode.count == 4 else { return }
        if onSubmit(passcode) {
            passcode = ""
        } else {
            passcode = ""
        }
    }
}

private struct HiddenPasscodeField: View {
    @Binding var passcode: String
    let onSubmit: () -> Void

    var body: some View {
        TextField("", text: $passcode)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .onSubmit(onSubmit)
    }
}

private struct PasscodeDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < count ? AppTheme.coin : Color.white.opacity(0.26))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1.4))
            }
        }
        .padding(.vertical, 2)
    }
}

private struct NumberPad: View {
    @Binding var passcode: String

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "delete.left.fill"]
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { value in
                        Button {
                            tap(value)
                        } label: {
                            Group {
                                if value == "delete.left.fill" {
                                    Image(systemName: value)
                                } else {
                                    Text(value)
                                }
                            }
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 74, height: 58)
                            .background(value.isEmpty ? Color.clear : Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(value.isEmpty)
                        .accessibilityLabel(Text(value == "delete.left.fill" ? L10n.t("删除") : value))
                    }
                }
            }
        }
    }

    private func tap(_ value: String) {
        if value == "delete.left.fill" {
            if !passcode.isEmpty {
                passcode.removeLast()
            }
            return
        }
        guard passcode.count < 4, !value.isEmpty else { return }
        passcode.append(value)
    }
}
