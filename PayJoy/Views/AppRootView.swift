import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("payjoy.focus.keepScreenAwake") private var keepsScreenAwake = false
    @State private var didPrepareAppLock = false
    @State private var hasDuoHinge = false
    @State private var deskSuppressedForCurrentFold = false
    @State private var focusShowsOffWorkTime = false
    @State private var stoppingDeskOvertime: OvertimeRecord?
    @State private var opensReceiptAfterDeskOvertime = false
    @State private var homeRootVisible = true
    @State private var homePresentationClear = true
    @State private var activeWindowScene: UIWindowScene?

    var body: some View {
        @Bindable var appState = appState

        let needsInitialSetup = !appState.preferences.hasCompletedInitialSetup
        let barVisible = !appState.isTabBarHidden && !needsInitialSetup
            && !appState.isFocusPresented && !appState.shouldPresentPaydayCelebration

        GeometryReader { proxy in
            let layout = AdaptiveLayoutContext(proxy: proxy)
            let useSystemTabs = hasDuoHinge
            let showDesk = !needsInitialSetup && appState.selectedTab == .home && homeRootVisible && homePresentationClear
                && !appState.isTabBarHidden && !deskSuppressedForCurrentFold
                && !appState.isFocusPresented && !appState.shouldPresentClosingReceipt
                && !appState.shouldPresentPaydayCelebration
                && layout.canShowDeskClock
            let bottomSafeArea = proxy.safeAreaInsets.bottom
            let occupancy = TabChromeLayout.occupancy(
                barVisible: barVisible && !useSystemTabs && !showDesk,
                bottomSafeArea: bottomSafeArea
            )
            let padding = occupancy.paddingInSafeAreaRespectingContainer(bottomSafeArea: bottomSafeArea)
            ZStack(alignment: .bottom) {
                Group {
                    if needsInitialSetup {
                        NavigationStack { EmotionalOnboardingView() }
                    } else if useSystemTabs {
                        TabView(selection: $appState.selectedTab) {
                            ForEach(AppTab.allCases) { tab in
                                tabContent(tab, showDesk: showDesk)
                                    .toolbar(appState.isTabBarHidden || showDesk ? .hidden : .automatic, for: .tabBar)
                                    .tabItem {
                                        Label(tab.title, systemImage: tab.icon)
                                    }
                                    .tag(tab)
                            }
                        }
                    } else {
                        tabContent(appState.selectedTab, showDesk: showDesk)
                    }
                }
                .padding(.bottom, padding.contentBottomInset)
                .accessibilityHidden(appState.isFocusPresented || appState.shouldPresentPaydayCelebration || appState.shouldShowPrivacyShield)

                if barVisible && !useSystemTabs && !showDesk {
                    ComicTabBar(selectedTab: $appState.selectedTab)
                        .padding(.bottom, padding.barBottomOffset)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityHidden(appState.isFocusPresented || appState.shouldPresentPaydayCelebration || appState.shouldShowPrivacyShield)
                }

                privacyShield
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(AppTheme.paper.ignoresSafeArea())
            .environment(\.adaptiveLayoutContext, layout)
            .animation(prefersReducedMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: appState.isTabBarHidden)
            .onAppear {
                if !layout.divisionRegions.isEmpty { hasDuoHinge = true }
            }
            .onChange(of: layout.divisionRegions.isEmpty) { _, isEmpty in
                if !isEmpty { hasDuoHinge = true }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake(showDesk: showDesk)
            }
            .onChange(of: shouldKeepScreenAwake(showDesk: showDesk)) { _, shouldKeepAwake in
                UIApplication.shared.isIdleTimerDisabled = shouldKeepAwake
            }
        }
        .background(WindowSceneReader(
            onSceneChange: { activeWindowScene = $0 },
            onHingeAvailabilityChange: { if $0 { hasDuoHinge = true } },
            onHingeFullyOpen: { deskSuppressedForCurrentFold = false }
        ))
        .background(ScenePrivacyShieldWindow(
            scene: activeWindowScene,
            isVisible: appState.shouldShowPrivacyShield,
            requiresPasscode: appState.isAppLocked,
            message: appState.appLockMessage,
            onSubmit: { appState.unlockApp(with: $0) }
        ))
        .environment(\.duoDeviceAvailable, hasDuoHinge)
        .environment(\.payJoyWindowScene, activeWindowScene)
        .fullScreenCover(isPresented: $appState.shouldPresentPaydayCelebration) {
            PaydayCelebrationView()
                .overlay { privacyShield }
        }
        .fullScreenCover(isPresented: $appState.isFocusPresented, onDismiss: {
            appState.focusPresentationDidDismiss()
        }) {
            FocusView(showsOffWorkTime: $focusShowsOffWorkTime, onDeskClose: { deskSuppressedForCurrentFold = true })
                .environment(\.duoDeviceAvailable, hasDuoHinge)
                .environment(\.payJoyWindowScene, activeWindowScene)
                .overlay { privacyShield }
        }
        .sheet(isPresented: $appState.shouldPresentClosingReceipt) {
            ClosingReceiptFlowView()
                .overlay { privacyShield }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppTheme.paper)
                .interactiveDismissDisabled(false)
                .onDisappear {
                    appState.closeClosingReceipt()
                }
        }
        .sheet(item: $stoppingDeskOvertime, onDismiss: {
            guard opensReceiptAfterDeskOvertime else { return }
            opensReceiptAfterDeskOvertime = false
            appState.openClosingReceipt()
        }) { record in
            OvertimeStopSheet(record: record, defaultEnd: appState.now) { endAt in
                appState.stopActiveOvertime(at: endAt)
                opensReceiptAfterDeskOvertime = true
            }
            .presentationDetents([.medium])
            .presentationBackground(AppTheme.paper)
        }
        .onAppear {
            FocusOrientationPolicy.update(orientation: hasDuoHinge ? .allButUpsideDown : .portrait, in: activeWindowScene, requestRotation: false)
            guard !didPrepareAppLock else { return }
            appState.prepareAppLockOnLaunch()
            appState.applicationDidBecomeActive()
            didPrepareAppLock = true
        }
        .onChange(of: appState.isFocusPresented) { _, isPresented in
            if !isPresented {
                FocusOrientationPolicy.update(orientation: hasDuoHinge ? .allButUpsideDown : .portrait, in: activeWindowScene, requestRotation: !hasDuoHinge)
            }
        }
        .onChange(of: hasDuoHinge) { _, isDuo in
            FocusOrientationPolicy.update(orientation: isDuo ? .allButUpsideDown : .portrait, in: activeWindowScene, requestRotation: !isDuo)
        }
        .onChange(of: activeWindowScene?.session.persistentIdentifier) { _, _ in
            guard !appState.isFocusPresented else { return }
            FocusOrientationPolicy.update(orientation: hasDuoHinge ? .allButUpsideDown : .portrait, in: activeWindowScene, requestRotation: false)
        }
        .onChange(of: appState.selectedTab) { _, tab in
            if tab == .focus && appState.focusData.active != nil {
                appState.presentFocus()
            }
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
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
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

    @ViewBuilder
    private var privacyShield: some View {
        if appState.shouldShowPrivacyShield {
            AppPrivacyShield(
                requiresPasscode: appState.isAppLocked,
                message: appState.appLockMessage,
                onSubmit: { passcode in
                    appState.unlockApp(with: passcode)
                }
            )
            .zIndex(20)
        }
    }

    private func shouldKeepScreenAwake(showDesk: Bool) -> Bool {
        keepsScreenAwake && scenePhase == .active && !appState.shouldShowPrivacyShield
            && (showDesk || (appState.isFocusPresented && appState.focusData.active != nil))
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab, showDesk: Bool) -> some View {
        Group {
        switch tab {
        case .home:
            ZStack {
                NavigationStack {
                    HomeView(
                        onRootVisibilityChange: { homeRootVisible = $0 },
                        onPresentationChange: { homePresentationClear = $0 }
                    )
                        .accessibilityHidden(showDesk || appState.isFocusPresented)
                }
                    .opacity(showDesk ? 0 : 1)
                    .allowsHitTesting(!showDesk)
                    .accessibilityHidden(showDesk || appState.isFocusPresented)
                if showDesk {
                    DeskClockView(showsOffWorkTime: $focusShowsOffWorkTime, onStopOvertime: { record in
                        stoppingDeskOvertime = record
                    }) {
                        deskSuppressedForCurrentFold = true
                    }
                    .transition(.opacity)
                }
            }
            .animation(prefersReducedMotion ? nil : .easeInOut(duration: 0.2), value: showDesk)
        case .focus:
            FocusView(showsOffWorkTime: $focusShowsOffWorkTime, embeddedInTab: true, onDeskClose: { deskSuppressedForCurrentFold = true })
        case .stats:
            NavigationStack { StatsView() }
        case .wish:
            NavigationStack { WishExperienceView() }
        case .profile:
            NavigationStack { ProfileView() }
        }
        }
        .environment(\.payJoyAmbientMotionEnabled,
                     appState.selectedTab == tab && !appState.isFocusPresented
                     && !appState.shouldPresentClosingReceipt && !appState.shouldPresentPaydayCelebration
                     && !appState.shouldShowPrivacyShield && !(tab == .home && showDesk))
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
    @FocusState private var salaryFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveLayoutContext(proxy: geometry)
            let paneWidth = layout.verticalDivision.map { max(0, $0.minX - 12) }
            let compactAccessibilityLayout = paneWidth != nil && dynamicTypeSize.isAccessibilitySize
            VStack(spacing: 0) {
                onboardingHeader

                ScrollView(showsIndicators: false) {
                    payStep(compactAccessibilityLayout: compactAccessibilityLayout)
                    .padding(.horizontal, AppTheme.pagePadding)
                    .padding(.vertical, 18)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }

                onboardingActions(compactAccessibilityLayout: compactAccessibilityLayout)
                    .frame(maxWidth: 620)
            }
            .adaptiveSinglePane(in: layout)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .payJoyKeyboardDismissToolbar()
        .onAppear(perform: prepareDefaultsIfNeeded)

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

    private func payStep(compactAccessibilityLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                onboardingPayHero
            }

            ComicCard {
                VStack(alignment: .leading, spacing: 14) {
                    onboardingTitle(
                        L10n.t("工资和上下班时间"),
                        subtitle: L10n.t("用于趣味工资进度与收工仪式，不做工资或税务核算。"),
                        showsSubtitle: !compactAccessibilityLayout
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

                    if compactAccessibilityLayout {
                        VStack(alignment: .leading, spacing: 10) {
                            salaryCurrencyMenu
                            salaryAmountField(compactAccessibilityLayout: true)
                            if salaryFieldFocused {
                                Button(L10n.t("完成")) { salaryFieldFocused = false }
                                    .font(.body.weight(.heavy))
                                    .frame(minHeight: 44)
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            salaryCurrencyMenu
                            salaryAmountField(compactAccessibilityLayout: false)
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

                    if compactAccessibilityLayout {
                        Text(L10n.t("用于趣味工资进度与收工仪式，不做工资或税务核算。"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                .comicIdleBob(enabled: !accessibilityReduceMotion && !appState.preferences.reduceMotion, amplitude: 3, rotation: 0, duration: 2.4)
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

    private var salaryCurrencyMenu: some View {
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
    }

    private func salaryAmountField(compactAccessibilityLayout: Bool) -> some View {
        TextField("10000", text: $salaryAmountText)
            .font(compactAccessibilityLayout ? .title3.weight(.black) : .system(size: 27, weight: .black, design: .rounded))
            .keyboardType(.decimalPad)
            .focused($salaryFieldFocused)
            .onChange(of: salaryAmountText) { _, value in
                let normalized = value.replacingOccurrences(of: ",", with: "")
                draft.salaryAmount = Double(normalized) ?? 0
            }
    }

    private func onboardingActions(compactAccessibilityLayout: Bool) -> some View {
        PrimaryButton(title: L10n.t(compactAccessibilityLayout ? "下一步" : "开始今天的小快乐"), reduceMotion: prefersReducedMotion) {
            advance()
        }
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.48)
        .accessibilityLabel(L10n.t("开始今天的小快乐"))
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

    private func onboardingTitle(_ title: String, subtitle: String, showsSubtitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            if showsSubtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

private struct ScenePrivacyShieldWindow: UIViewRepresentable {
    let scene: UIWindowScene?
    let isVisible: Bool
    let requiresPasscode: Bool
    let message: String?
    let onSubmit: (String) -> Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.update(
            scene: scene,
            isVisible: isVisible,
            requiresPasscode: requiresPasscode,
            message: message,
            onSubmit: onSubmit
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.removeWindow()
    }

    final class Coordinator {
        private var window: UIWindow?
        private var host: UIHostingController<AppPrivacyShield>?
        private var lastRequiresPasscode: Bool?
        private var lastMessage: String?
        private var lastIsVisible: Bool?

        func update(
            scene: UIWindowScene?,
            isVisible: Bool,
            requiresPasscode: Bool,
            message: String?,
            onSubmit: @escaping (String) -> Bool
        ) {
            guard let scene else {
                removeWindow()
                return
            }
            if window?.windowScene !== scene {
                removeWindow()
                let host = UIHostingController(rootView: AppPrivacyShield(
                    requiresPasscode: requiresPasscode,
                    message: message,
                    onSubmit: onSubmit
                ))
                host.view.backgroundColor = .clear
                let window = UIWindow(windowScene: scene)
                window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
                window.rootViewController = host
                self.window = window
                self.host = host
                lastRequiresPasscode = requiresPasscode
                lastMessage = message
            } else if lastRequiresPasscode != requiresPasscode || lastMessage != message {
                host?.rootView = AppPrivacyShield(
                    requiresPasscode: requiresPasscode,
                    message: message,
                    onSubmit: onSubmit
                )
                lastRequiresPasscode = requiresPasscode
                lastMessage = message
            }
            if lastIsVisible != isVisible {
                window?.isHidden = !isVisible
                lastIsVisible = isVisible
            }
        }

        func removeWindow() {
            window?.isHidden = true
            window?.rootViewController = nil
            window?.windowScene = nil
            window = nil
            host = nil
            lastRequiresPasscode = nil
            lastMessage = nil
            lastIsVisible = nil
        }
    }
}

private struct AppPrivacyShield: View {
    let requiresPasscode: Bool
    let message: String?
    let onSubmit: (String) -> Bool
    @State private var passcode = ""

    var body: some View {
        GeometryReader { proxy in
            let layout = AdaptiveLayoutContext(proxy: proxy)
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

                if layout.canShowDeskClock, let division = layout.horizontalDivision {
                    VStack(spacing: 0) {
                        ScrollView {
                            header(compact: division.minY < 250)
                                .frame(maxWidth: 420)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: division.minY)
                        }
                        .frame(height: max(0, division.minY))

                        Color.clear.frame(height: max(0, division.height))

                        ScrollView {
                            if requiresPasscode {
                                passcodeControls
                                    .frame(maxWidth: 420)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: max(0, proxy.size.height - division.maxY))
                            }
                        }
                        .frame(height: max(0, proxy.size.height - division.maxY))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 22) {
                            header(compact: false)
                            if requiresPasscode { passcodeControls }
                        }
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity, minHeight: layout.singleColumnBounds.height)
                    }
                    .adaptiveSinglePane(in: layout)
                }
            }
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

    private func header(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 22) {
            Image(systemName: requiresPasscode ? "lock.fill" : "eye.slash.fill")
                .font(.system(size: compact ? 30 : 46, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: compact ? 64 : 98, height: compact ? 64 : 98)
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
                    .font(.system(size: compact ? 24 : 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(requiresPasscode ? L10n.t("请输入 4 位密码继续。") : L10n.t("多任务预览已隐藏你的收入和工作信息。"))
                    .font(compact ? .footnote.weight(.bold) : .headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.74))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, compact ? 12 : 34)
    }

    private var passcodeControls: some View {
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
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
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
