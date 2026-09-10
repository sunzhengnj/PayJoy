import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var amountPulse = false
    @State private var lastEarnedCents = 0
    @State private var heroBubbleText = L10n.t("这段时间归你，工作先放一边。")
    @State private var lastBubbleRefresh = Date.distantPast
    @State private var overtimePresentation: OvertimePresentation?
    @State private var earlyLeaveConfirmation: EarlyLeaveConfirmation?
    @State private var isBossModePresented = false
    @State private var showsMembershipPrompt = false
    @State private var showsProPaywall = false

    var body: some View {
        ZStack {
            if shouldShowRewardRain {
                CoinRainLayer(style: appState.activeOvertimeRecord == nil ? .coin : .redPacket)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if !dynamicTypeSize.isAccessibilitySize {
                        hero
                            .padding(.bottom, -8)
                    }
                    if appState.isTodayPayday {
                        PaydayTodayCard()
                    }
                    EarningsCard(
                        snapshot: appState.snapshot,
                        pulse: amountPulse && !prefersReducedMotion,
                        reduceMotion: prefersReducedMotion,
                        showDecimalCents: appState.preferences.showDecimalCents,
                        hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                        currencySymbol: appState.settings.currencySymbol
                    )
                    if appState.canOpenClosingReceipt {
                        ClosingReceiptHomeCard(receipt: appState.todayClosingReceipt) {
                            appState.openClosingReceipt()
                        }
                    }
                    if appState.activeOvertimeRecord != nil || appState.canStartOvertime || appState.todayOvertimeDuration > 0 {
                        OvertimeActionCard(
                            activeRecord: appState.activeOvertimeRecord,
                            activeDuration: appState.activeOvertimeDuration,
                            todayDuration: appState.todayOvertimeDuration,
                            canStart: appState.canStartOvertime,
                            defaultStart: appState.defaultOvertimeStartDate,
                            startAction: {
                                overtimePresentation = .start(defaultStart: appState.now)
                            },
                            stopAction: {
                                if let activeRecord = appState.activeOvertimeRecord {
                                    overtimePresentation = .stop(record: activeRecord, defaultEnd: appState.now)
                                }
                            },
                            manualAction: {
                                overtimePresentation = .manual(defaultStart: appState.defaultOvertimeStartDate, defaultEnd: appState.defaultOvertimeEndDate)
                            }
                        )
                    }
                    if [.beforeWork, .working, .lunchBreak].contains(appState.snapshot.status) {
                        ProgressSummaryCard(snapshot: appState.snapshot, hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol)
                    }
                    if appState.snapshot.status == .afterWork {
                        DailyPayReportCard(
                            snapshot: appState.snapshot,
                            hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                            currencySymbol: appState.settings.currencySymbol
                        )
                    }
                    if [.beforeWork, .working, .lunchBreak].contains(appState.snapshot.status) {
                        HStack(spacing: 10) {
                            if let secondsUntilWorkStart = offDutySecondsUntilWorkStart {
                                SmallMetricCard(
                                    title: L10n.t("下次上班"),
                                    value: secondsUntilWorkStart.countdownText,
                                    caption: L10n.t("不着急，先好好休息")
                                )
                            } else {
                                SmallMetricCard(title: L10n.t("下班倒计时"), value: appState.snapshot.secondsUntilOffWork.countdownText, caption: appState.settings.workEnd.displayText)
                            }
                            SmallMetricCard(
                                title: L10n.t("今天还可赚"),
                                value: PrivacyText.compactMoney(appState.snapshot.remainingToday, hidden: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol),
                                caption: L10n.t("继续回血")
                            )
                        }
                    }
                    if [.beforeWork, .working, .lunchBreak].contains(appState.snapshot.status) {
                        MoyuCard(
                            snapshot: appState.snapshot,
                            hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                            currencySymbol: appState.settings.currencySymbol,
                            reduceMotion: prefersReducedMotion
                        )
                    }
                    if appState.canLeaveWorkEarlyToday {
                        EarlyLeaveButton(
                            remainingToday: appState.snapshot.remainingToday,
                            hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                            currencySymbol: appState.settings.currencySymbol
                        ) {
                            earlyLeaveConfirmation = .leave
                        }
                    } else if appState.hasLeftWorkEarlyToday {
                        CancelEarlyLeaveButton {
                            earlyLeaveConfirmation = .cancel
                        }
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 86)
            }

            if let confirmation = earlyLeaveConfirmation {
                EarlyLeaveConfirmationOverlay(
                    confirmation: confirmation,
                    dismiss: {
                        withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86)) {
                            earlyLeaveConfirmation = nil
                        }
                    },
                    confirm: {
                        withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)) {
                            switch confirmation {
                            case .leave:
                                appState.leaveWorkEarlyToday()
                                Task { @MainActor in
                                    await Task.yield()
                                    appState.openClosingReceipt()
                                }
                            case .cancel:
                                appState.cancelLeaveWorkEarlyToday()
                            }
                            earlyLeaveConfirmation = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }

        }
        .background(AppTheme.paper)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $isBossModePresented) {
            BossCalculatorView()
        }
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsProPaywall = true
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
        .sheet(item: $overtimePresentation) { presentation in
            switch presentation {
            case .start(let defaultStart):
                OvertimeStartSheet(defaultStart: defaultStart) { startAt in
                    withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.8)) {
                        appState.startOvertime(at: startAt)
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
            case .stop(let record, let defaultEnd):
                OvertimeStopSheet(record: record, defaultEnd: defaultEnd) { endAt in
                    withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)) {
                        appState.stopActiveOvertime(at: endAt)
                    }
                    Task { @MainActor in
                        await Task.yield()
                        appState.openClosingReceipt()
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
            case .manual(let defaultStart, let defaultEnd):
                OvertimeEntrySheet(
                    defaultStart: defaultStart,
                    defaultEnd: defaultEnd,
                    saveAction: { startAt, endAt in
                        appState.saveOvertimeRecord(startAt: startAt, endAt: endAt)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
            }
        }
        .onAppear {
            refreshBubble(force: true)
            if ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] == "boss" {
                isBossModePresented = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshBubble(force: true)
        }
        .onChange(of: appState.snapshot.status) { _, _ in
            refreshBubble(force: true)
        }
        .onChange(of: appState.activeOvertimeRecord?.id) { _, _ in
            refreshBubble(force: true)
        }
        .onChange(of: appState.now) { _, newValue in
            guard newValue.timeIntervalSince(lastBubbleRefresh) > 55 else { return }
            refreshBubble(force: false)
        }
        .onChange(of: appState.snapshot.todayEarned) { _, newValue in
            let cents = Int(newValue * 100)
            guard cents != lastEarnedCents else { return }
            lastEarnedCents = cents
            if prefersReducedMotion {
                amountPulse = false
            } else {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                    amountPulse.toggle()
                }
            }
        }
        .sensoryFeedback(.success, trigger: appState.todayClosingReceipt?.id)
    }

    private var shouldShowRewardRain: Bool {
        (appState.snapshot.status == .working || appState.activeOvertimeRecord != nil) &&
        appState.preferences.showCoinRain &&
        AppTheme.current != .midnight &&
        !prefersReducedMotion
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private var offDutySecondsUntilWorkStart: TimeInterval? {
        appState.offDutySecondsUntilWorkStart
    }

    private var showsRestPresentation: Bool {
        appState.activeOvertimeRecord == nil && (
            offDutySecondsUntilWorkStart != nil ||
            appState.snapshot.status == .afterWork ||
            appState.snapshot.status == .restDay
        )
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    headerActions
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("今天也给自己一点好心情。"))
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.t("打工赚钱的每一秒，都是热爱生活的证据！"))
                            .font(.body.weight(.heavy))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityElement(children: .combine)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    if L10n.currentLanguage == .zhHans, AppTheme.current != .midnight {
                        AssetImage(name: "home_header_lettering_spaced_v2")
                            .frame(width: 204, height: 147)
                            .offset(x: -2, y: 0)
                            .accessibilityLabel(Text(L10n.t("开薪！打工赚钱的每一秒，都是热爱生活的证据！")))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("今天也给自己一点好心情。"))
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 205, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            Text(L10n.t("打工赚钱的每一秒，都是热爱生活的证据！"))
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(AppTheme.ink)
                                .lineSpacing(3)
                                .frame(width: 250, alignment: .leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.76)
                        }
                        .frame(width: 250, height: 147, alignment: .topLeading)
                        .offset(x: 0, y: 12)
                        .accessibilityElement(children: .combine)
                    }

                    if AppTheme.current != .midnight {
                        AssetImage(name: "coin_single_v1")
                            .frame(width: 34, height: 34)
                            .rotationEffect(.degrees(22))
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                            .padding(.trailing, 48)
                            .offset(y: 22)

                        AssetImage(name: "coin_single_v1")
                            .frame(width: 26, height: 26)
                            .rotationEffect(.degrees(-24))
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                            .padding(.trailing, 118)
                            .offset(y: 102)
                    }

                    headerActions
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
                .frame(height: 116)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var headerActions: some View {
        HStack(spacing: 9) {
                Button {
                    openBossKey()
                } label: {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.softSurface.opacity(0.9))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.4))
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.92, reduceMotion: prefersReducedMotion))
                .accessibilityLabel(L10n.t("老板键"))

                Button {
                    withAnimation(prefersReducedMotion ? nil : .spring(response: 0.22, dampingFraction: 0.82)) {
                        appState.togglePrivacyMode()
                    }
                } label: {
                    Image(systemName: appState.preferences.hideSensitiveAmounts ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(AppTheme.ink)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.4))
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.92, reduceMotion: prefersReducedMotion))
                .accessibilityLabel(appState.preferences.hideSensitiveAmounts ? L10n.t("显示金额") : L10n.t("隐藏金额"))
                .accessibilityValue(appState.preferences.hideSensitiveAmounts ? L10n.t("已开启") : L10n.t("未开启"))
                .onLongPressGesture(minimumDuration: 0.7) {
                    openBossKey()
                }
            }
            .sensoryFeedback(.selection, trigger: appState.preferences.hideSensitiveAmounts)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            AssetImage(name: showsRestPresentation ? AppTheme.moyuWorkerAsset : AppTheme.heroWorkerAsset)
                .frame(maxWidth: .infinity)
                .frame(height: 116)
                .scaleEffect(showsRestPresentation ? 1 : AppTheme.heroArtworkScale, anchor: .bottom)
                .offset(y: showsRestPresentation ? 0 : AppTheme.heroArtworkYOffset)
            SpeechBubble(text: heroBubbleText, isYellow: false, tailX: 0.24, lineLimit: 3)
                .frame(width: 136)
                .offset(x: -6, y: -6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(100, AppTheme.heroSectionHeight - 18))
    }

    private func refreshBubble(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastBubbleRefresh) > 30 else { return }
        heroBubbleText = Self.randomBubbleText(for: appState, excluding: heroBubbleText)
        lastBubbleRefresh = now
    }

    private func openBossKey() {
        guard appState.hasEffectivePro else {
            showsMembershipPrompt = true
            return
        }
        isBossModePresented = true
    }

    private static func randomBubbleText(for appState: AppState, excluding current: String?) -> String {
        let messages = bubbleMessages(
            status: appState.snapshot.status,
            isOvertime: appState.activeOvertimeRecord != nil,
            isOffDutyBeforeWork: appState.offDutySecondsUntilWorkStart != nil,
            hour: Calendar.current.component(.hour, from: appState.now),
            weekday: Calendar.current.component(.weekday, from: appState.now)
        )
        let candidates = messages.filter { $0 != current }
        return candidates.randomElement() ?? messages[0]
    }

    static func bubbleMessages(
        status: WorkdayStatus,
        isOvertime: Bool,
        isOffDutyBeforeWork: Bool,
        hour: Int,
        weekday: Int
    ) -> [String] {
        // Work state takes precedence over the clock: being awake is not being at work.
        if !isOvertime {
            if isOffDutyBeforeWork || status == .afterWork || status == .restDay {
                return [
                    L10n.t("现在先休息，开工以后再说。"),
                    L10n.t("这段时间归你，工作先放一边。")
                ]
            }
            if status == .beforeWork {
                return [L10n.t("开工前，钱包正在做热身。")]
            }
            if status == .lunchBreak {
                return [L10n.t("午休暂停，快乐继续。")]
            }
        }
        if hour >= 22 || hour < 5 {
            return [
                L10n.t("夜班模式启动，屏幕也在陪你。"),
                L10n.t("深夜在线，金币别睡。")
            ]
        }
        if !isOvertime && weekday == 6 && hour >= 15 {
            return [
                L10n.t("周五下午，自由已经在门口刷卡。"),
                L10n.t("周五尾声，钱包和灵魂都在倒计时。")
            ]
        }
        return [
            L10n.t("每一秒都在回血。"),
            L10n.t("工资正在努力加载。"),
            L10n.t("摸鱼也有现金流。"),
            L10n.t("今天又多赚一点点。"),
            L10n.t("老板看不见，金币看得见。"),
            L10n.t("打工人钱包复活中。"),
            L10n.t("先别崩，钱在涨。"),
            L10n.t("只要数字在跳，我就还能撑。"),
            L10n.t("键盘一响，金币到账。"),
            L10n.t("开薪中，请保持微笑。")
        ]
    }
}

private struct EarlyLeaveButton: View {
    let remainingToday: Double
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(AppTheme.ink)
                    .frame(width: 5, height: 42)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("提前下班"))
                        .font(.headline.weight(.black))
                    Text(L10n.t("一键收工，补齐今日剩余 \(PrivacyText.money(remainingToday, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                Text(L10n.t("确认收工"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .background(AppTheme.cream.opacity(0.9))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
            }
            .padding(13)
            .background(AppTheme.coin)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.7)
            }
            .shadow(color: AppTheme.shadow.opacity(0.14), radius: 1, x: 3, y: 3)
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98))
        .accessibilityLabel(L10n.t("提前下班"))
    }
}

private struct CancelEarlyLeaveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(AppTheme.textGray)
                    .frame(width: 5, height: 42)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("取消一键收工"))
                        .font(.headline.weight(.black))
                    Text(L10n.t("恢复今天按当前时间继续计算。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                Text(L10n.t("恢复"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(AppTheme.softSurface.opacity(0.86))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
            }
            .padding(13)
            .background(AppTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.7)
            }
            .shadow(color: AppTheme.shadow.opacity(0.14), radius: 1, x: 3, y: 3)
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98))
        .accessibilityLabel(L10n.t("取消一键收工"))
    }
}

private enum EarlyLeaveConfirmation: Identifiable {
    case leave
    case cancel

    var id: String {
        switch self {
        case .leave: "leave"
        case .cancel: "cancel"
        }
    }

    var iconName: String {
        switch self {
        case .leave: "figure.walk.departure"
        case .cancel: "arrow.uturn.backward.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .leave: L10n.t("确认提前收工？")
        case .cancel: L10n.t("取消一键收工？")
        }
    }

    var message: String {
        switch self {
        case .leave: L10n.t("会补齐今日剩余收入，并把今天标记为已收工。")
        case .cancel: L10n.t("取消后会恢复今天按当前时间继续计算。")
        }
    }

    var confirmTitle: String {
        switch self {
        case .leave: L10n.t("确认收工")
        case .cancel: L10n.t("确认取消一键收工")
        }
    }

    var confirmBackground: Color {
        switch self {
        case .leave: AppTheme.coin
        case .cancel: AppTheme.cream
        }
    }
}

private struct EarlyLeaveConfirmationOverlay: View {
    let confirmation: EarlyLeaveConfirmation
    let dismiss: () -> Void
    let confirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: confirmation.iconName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.6))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(confirmation.title)
                            .font(.title3.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(confirmation.message)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: dismiss) {
                        Text(L10n.t("取消"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.softSurface.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.5)
                            }
                    }

                    Button(action: confirm) {
                        Text(confirmation.confirmTitle)
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(confirmation.confirmBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.5)
                            }
                    }
                }
                .buttonStyle(PayJoyPressStyle(scale: 0.98))
            }
            .padding(18)
            .frame(maxWidth: 342)
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 2)
            }
            .shadow(color: AppTheme.shadow.opacity(0.24), radius: 0, x: 5, y: 5)
            .padding(.horizontal, 24)
        }
    }
}

private struct ClosingReceiptHomeCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let receipt: ClosingCapsule?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.highlightCardBackground, AppTheme.coin.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.outline, lineWidth: 1.6)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(receipt == nil ? L10n.t("今天辛苦了") : L10n.t("今天已收下"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.textGray)
                    Text(receipt == nil ? L10n.t("收下今天") : L10n.t("查看收工回执"))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Text(receipt == nil ? L10n.t("点一下今天的状态，给这一天一个句号。") : L10n.t("回执和分享入口今天都在这里。"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .lineLimit(2)
                        .frame(maxWidth: 224, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .padding(.trailing, 98)

                AssetImage(name: appState.selectedCompanion.avatarAssetName)
                    .frame(width: 104, height: 104)
                    .offset(x: -4, y: 8)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 126)
            .shadow(color: AppTheme.shadow.opacity(0.18), radius: 0, x: 4, y: 4)
        }
        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
        .accessibilityLabel(receipt == nil ? L10n.t("收下今天") : L10n.t("查看收工回执"))
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }
}

struct ClosingReceiptFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var receipt: ClosingCapsule?
    @State private var showsMembershipPrompt = false
    @State private var showsPaywall = false

    var body: some View {
        Group {
            if let resolvedReceipt {
                ClosingReceiptDetailView(capsule: resolvedReceipt)
            } else {
                moodStep
            }
        }
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsPaywall = true
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            ProPaywallSheet()
        }
        .onAppear {
            receipt = appState.closingReceiptForPresentation
        }
    }

    private var resolvedReceipt: ClosingCapsule? {
        receipt ?? appState.closingReceiptForPresentation
    }

    private var moodStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.t("收下今天"))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                        Text(L10n.t("今天过得怎么样？点一下就好。"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer(minLength: 8)
                    closeButton
                }

                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.coin.opacity(0.74), AppTheme.highlightCardBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(AppTheme.outline, lineWidth: 1.7)
                        }

                    VStack(alignment: .leading, spacing: 7) {
                        Text(L10n.t("今日已经到账"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                        Text(
                            PrivacyText.money(
                                appState.snapshot.todayEarned,
                                hidden: appState.preferences.hideSensitiveAmounts,
                                currencySymbol: appState.settings.currencySymbol
                            )
                        )
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                        Text(L10n.t("下班以后，时间还给自己。"))
                            .font(.subheadline.weight(.heavy))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .padding(.trailing, 104)

                    AssetImage(name: appState.selectedCompanion.avatarAssetName)
                        .frame(width: 118, height: 118)
                        .offset(x: -8, y: -3)
                        .accessibilityHidden(true)
                }
                .frame(height: 166)
                .shadow(color: AppTheme.shadow.opacity(0.18), radius: 0, x: 4, y: 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("选一个今天的状态"))
                        .font(.headline.weight(.black))

                    ForEach(Array(DailyMood.allCases.enumerated()), id: \.element.id) { index, mood in
                        Button {
                            complete(with: mood)
                        } label: {
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                                    .frame(width: 38, height: 34)
                                    .background(AppTheme.coin)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppTheme.outline, lineWidth: 1)
                                    }
                                Text(mood.title)
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 56)
                            .background(AppTheme.softSurface.opacity(0.82))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.outline.opacity(0.82), lineWidth: 1.2)
                            }
                        }
                        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
                        .accessibilityHint(L10n.t("选择后立即生成收工回执"))
                    }
                }

                Menu {
                    ForEach(EmotionalTonePack.allCases) { tone in
                        Button(tone.title) {
                            chooseTone(tone)
                        }
                    }
                } label: {
                    HStack {
                        Text(L10n.t("回执语气"))
                            .font(.subheadline.weight(.black))
                        Spacer()
                        Text(appState.engagementState.tone.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.outline.opacity(0.62), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 28)
        }
        .background(AppTheme.paper)
    }

    private var closeButton: some View {
        Button {
            appState.closeClosingReceipt()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 44, height: 44)
                .background(AppTheme.softSurface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("关闭"))
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appState.preferences.reduceMotion
    }

    private func complete(with mood: DailyMood) {
        appState.setDailyMood(mood)
        let generated = appState.completeClosingCapsule(revealsSalary: false)
        withAnimation(prefersReducedMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84)) {
            receipt = generated
        }
    }

    private func chooseTone(_ tone: EmotionalTonePack) {
        if tone.isPro, !appState.hasEffectivePro {
            showsMembershipPrompt = true
            return
        }
        _ = appState.selectEmotionalTone(tone)
    }
}

private struct ClosingReceiptDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let capsule: ClosingCapsule
    let showsNavigationActions: Bool
    @State private var revealsSalary: Bool
    @State private var showsHistory = false
    @State private var shareItem: ClosingReceiptShareItem?
    @State private var shareError: String?

    init(capsule: ClosingCapsule, showsNavigationActions: Bool = true) {
        self.capsule = capsule
        self.showsNavigationActions = showsNavigationActions
        _revealsSalary = State(initialValue: capsule.revealsSalary)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("收工回执"))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                        Text(capsule.createdAt.localizedDateText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    Button {
                        appState.closeClosingReceipt()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.black))
                            .frame(width: 44, height: 44)
                            .background(AppTheme.softSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.ink)
                    .accessibilityLabel(L10n.t("关闭"))
                }

                capsuleCard

                Toggle(isOn: amountVisibilityBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("分享时显示金额"))
                            .font(.subheadline.weight(.black))
                        Text(
                            appState.preferences.hideSensitiveAmounts
                                ? L10n.t("金额隐私模式已开启")
                                : L10n.t("分享默认隐藏真实金额")
                        )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                    }
                }
                .tint(AppTheme.orange)
                .disabled(appState.preferences.hideSensitiveAmounts)

                Button {
                    exportSharePoster()
                } label: {
                    Label(L10n.t("分享这份小快乐"), systemImage: "square.and.arrow.up")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.coin)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PayJoyPressStyle(reduceMotion: prefersReducedMotion))

                if let shareError {
                    Text(shareError)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.red)
                }

                if showsNavigationActions {
                    if capsule.wishTitle != nil || appState.focusedWish != nil {
                        Button {
                            appState.selectedTab = .wish
                            appState.closeClosingReceipt()
                            dismiss()
                        } label: {
                            Text(L10n.t("去更新愿望进度"))
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(AppTheme.softSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.outline, lineWidth: 1.2)
                                }
                        }
                        .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
                    }

                    Button {
                        showsHistory = true
                    } label: {
                        Text(L10n.t("查看往日回执"))
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(AppTheme.paper)
        .sheet(isPresented: $showsHistory) {
            NavigationStack {
                ClosingReceiptHistoryView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.paper)
        }
        .sheet(item: $shareItem) { item in
            ClosingReceiptActivityView(activityItems: [item.url, item.caption])
        }
    }

    private var capsuleCard: some View {
        VStack(spacing: 18) {
            AssetImage(name: companion.avatarAssetName)
                .frame(width: 122, height: 122)
                .background(AppTheme.coin.opacity(0.26))
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(L10n.t(capsule.messageKey))
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let mood = capsule.mood {
                Text(mood.title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.paper.opacity(0.72))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.outline.opacity(0.62), lineWidth: 1))
            }

            HStack(spacing: 10) {
                capsuleMetric(
                    title: L10n.t(showsAmount ? "今日已赚" : "今日完成度"),
                    value: showsAmount
                        ? capsule.earnedAmount.compactMoneyText(currencySymbol: receiptCurrencySymbol)
                        : "\(Int(capsule.workProgress * 100))%"
                )
                capsuleMetric(
                    title: capsule.wishTitle ?? L10n.t("愿望进度"),
                    value: capsule.wishProgress.map { "\(Int($0 * 100))%" } ?? "—"
                )
            }

            Text(L10n.t("分享默认隐藏真实金额"))
                .font(.caption2.weight(.black))
                .foregroundStyle(AppTheme.textGray)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppTheme.coin.opacity(0.52), AppTheme.highlightCardBackground, AppTheme.softSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.outline, lineWidth: 1.6)
        }
        .shadow(color: AppTheme.shadow.opacity(0.2), radius: 0, x: 5, y: 5)
    }

    private var companion: CompanionProfile {
        CompanionProfile.catalog.first { $0.id == capsule.companionID } ?? .defaultValue
    }

    private var shareText: String {
        let amountLine = showsAmount
            ? capsule.earnedAmount.compactMoneyText(currencySymbol: receiptCurrencySymbol)
            : "\(Int(capsule.workProgress * 100))%"
        return [
            L10n.t(capsule.messageKey),
            "\(L10n.t(showsAmount ? "今日已赚" : "今日完成度"))：\(amountLine)",
            MarketCampaignLink.url(for: appState.preferences.resolvedMarket).absoluteString
        ].joined(separator: "\n")
    }

    @MainActor
    private func exportSharePoster() {
        let poster = ClosingReceiptSharePoster(
            capsule: capsule,
            companionAssetName: companion.avatarAssetName,
            showsAmount: showsAmount,
            currencySymbol: receiptCurrencySymbol
        )
        .frame(width: 360, height: 500)

        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            shareError = L10n.t("分享图生成失败，请稍后再试。")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClockJoy-Closing-Receipt-\(capsule.dateKey).png")
        do {
            try data.write(to: url, options: .atomic)
            shareError = nil
            shareItem = ClosingReceiptShareItem(url: url, caption: shareText)
            appState.recordClosingCapsuleShared()
        } catch {
            shareError = L10n.t("分享图生成失败，请稍后再试。")
        }
    }

    private var showsAmount: Bool {
        revealsSalary && !appState.preferences.hideSensitiveAmounts
    }

    private var receiptCurrencySymbol: String {
        capsule.currencyCode?.displaySymbol ?? appState.settings.currencySymbol
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }

    private var amountVisibilityBinding: Binding<Bool> {
        Binding(
            get: { showsAmount },
            set: { value in
                revealsSalary = value
                appState.setClosingCapsuleSalaryVisibility(id: capsule.id, revealsSalary: value)
            }
        )
    }

    private func capsuleMetric(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.paper.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ClosingReceiptSharePoster: View {
    let capsule: ClosingCapsule
    let companionAssetName: String
    let showsAmount: Bool
    let currencySymbol: String

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("收工回执"))
                    .font(.title2.weight(.black))
                Spacer()
                Text(capsule.createdAt.localizedDateText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }

            AssetImage(name: companionAssetName)
                .frame(width: 130, height: 130)
                .background(AppTheme.coin.opacity(0.24))
                .clipShape(Circle())

            Text(L10n.t(capsule.messageKey))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            if let mood = capsule.mood {
                Text(mood.title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.paper.opacity(0.74))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                metric(
                    title: L10n.t(showsAmount ? "今日已赚" : "今日完成度"),
                    value: showsAmount
                        ? capsule.earnedAmount.compactMoneyText(currencySymbol: currencySymbol)
                        : "\(Int(capsule.workProgress * 100))%"
                )
                metric(
                    title: capsule.wishTitle ?? L10n.t("愿望进度"),
                    value: capsule.wishProgress.map { "\(Int($0 * 100))%" } ?? "—"
                )
            }

            Text(L10n.t("今天也给自己一点好心情。"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [AppTheme.coin.opacity(0.54), AppTheme.highlightCardBackground, AppTheme.paper],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(AppTheme.ink)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.paper.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ClosingReceiptShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let caption: String
}

private struct ClosingReceiptActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ClosingReceiptHistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var showsMembershipPrompt = false
    @State private var showsPaywall = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 11) {
                if appState.visibleClosingReceipts.isEmpty {
                    Text(L10n.t("收工以后，第一张回执会留在这里。"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 42)
                } else {
                    ForEach(appState.visibleClosingReceipts) { receipt in
                        NavigationLink {
                            ClosingReceiptDetailView(
                                capsule: receipt,
                                showsNavigationActions: false
                            )
                        } label: {
                            historyRow(receipt)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if appState.hasLockedClosingReceipts {
                    Button {
                        showsMembershipPrompt = true
                    } label: {
                        VStack(spacing: 4) {
                            Text(L10n.t("查看更早的回执"))
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text(L10n.t("最近 7 条可直接查看"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                        .background(AppTheme.coin.opacity(0.58))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.outline, lineWidth: 1.2)
                        }
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.98, reduceMotion: prefersReducedMotion))
                }
            }
            .padding(AppTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(AppTheme.paper)
        .navigationTitle(L10n.t("往日回执"))
        .navigationBarTitleDisplayMode(.inline)
        .membershipFeatureAlert(isPresented: $showsMembershipPrompt) {
            showsPaywall = true
        }
        .fullScreenCover(isPresented: $showsPaywall) {
            ProPaywallSheet()
        }
    }

    private func historyRow(_ receipt: ClosingCapsule) -> some View {
        HStack(spacing: 12) {
            Text(receipt.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 54, height: 42)
                .background(AppTheme.coin)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t(receipt.messageKey))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                Text(receipt.mood?.title ?? L10n.t("今天已收下"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textGray)
            }

            Spacer(minLength: 4)

            Text("\(Int(receipt.workProgress * 100))%")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .monospacedDigit()
        }
        .padding(13)
        .background(AppTheme.softSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var prefersReducedMotion: Bool {
        appState.preferences.reduceMotion || accessibilityReduceMotion
    }
}

private enum MarketCampaignLink {
    static func url(for market: AppMarket) -> URL {
        let campaign: String
        switch market {
        case .taiwan: campaign = "closing_capsule_tw"
        case .hongKong: campaign = "closing_capsule_hk"
        case .japan: campaign = "closing_capsule_jp"
        case .southKorea: campaign = "closing_capsule_kr"
        case .mainlandChina: campaign = "closing_capsule_cn"
        case .globalEnglish: campaign = "closing_capsule_global"
        }
        var components = URLComponents(string: "https://apps.apple.com/app/id6771261514")!
        components.queryItems = [
            URLQueryItem(name: "ct", value: campaign),
            URLQueryItem(name: "mt", value: "8")
        ]
        return components.url!
    }
}

private struct BossCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.payJoyReduceMotion) private var appReduceMotion
    @AppStorage("payjoy.boss.key.didShowExitGuide") private var didShowExitGuide = false
    @State private var display = "0"
    @State private var storedValue: Double?
    @State private var pendingOperation: String?
    @State private var startsFreshNumber = true
    @State private var showsExitGuide = false

    private let rows = [
        ["AC", "+/-", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"],
        ["0", ".", "="]
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer()

                Text(display)
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.38)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: 92)
                    .padding(.horizontal, 22)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.8) {
                        dismiss()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.t("计算器显示区"))
                    .accessibilityValue(display)
                    .accessibilityHint(L10n.t("轻点两下退出老板键"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        dismiss()
                    }

                VStack(spacing: 11) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 11) {
                            ForEach(row, id: \.self) { symbol in
                                Button {
                                    handle(symbol)
                                } label: {
                                    Text(symbol)
                                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                                        .foregroundStyle(buttonForeground(for: symbol))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 72)
                                        .background(buttonBackground(for: symbol))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }

            if showsExitGuide {
                BossKeyExitGuide {
                    withAnimation(prefersReducedMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86)) {
                        showsExitGuide = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didShowExitGuide else { return }
            didShowExitGuide = true
            withAnimation(prefersReducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86)) {
                showsExitGuide = true
            }
        }
    }

    private var prefersReducedMotion: Bool {
        accessibilityReduceMotion || appReduceMotion
    }

    private func handle(_ symbol: String) {
        if symbol.count == 1, symbol.first?.isNumber == true {
            appendDigit(symbol)
            return
        }

        switch symbol {
        case ".":
            appendDecimalPoint()
        case "AC":
            display = "0"
            storedValue = nil
            pendingOperation = nil
            startsFreshNumber = true
        case "+/-":
            if display.hasPrefix("-") {
                display.removeFirst()
            } else if display != "0" {
                display = "-\(display)"
            }
        case "%":
            setDisplay(currentValue / 100)
            startsFreshNumber = true
        case "+", "-", "×", "÷":
            applyPendingOperation()
            storedValue = currentValue
            pendingOperation = symbol
            startsFreshNumber = true
        case "=":
            applyPendingOperation()
            pendingOperation = nil
            startsFreshNumber = true
        default:
            break
        }
    }

    private func appendDigit(_ digit: String) {
        if startsFreshNumber || display == "0" {
            display = digit
            startsFreshNumber = false
            return
        }
        guard display.filter(\.isNumber).count < 9 else { return }
        display.append(digit)
    }

    private func appendDecimalPoint() {
        if startsFreshNumber {
            display = "0."
            startsFreshNumber = false
            return
        }
        guard !display.contains(".") else { return }
        display.append(".")
    }

    private func applyPendingOperation() {
        guard let pendingOperation, let storedValue else { return }
        let value = currentValue
        switch pendingOperation {
        case "+":
            setDisplay(storedValue + value)
        case "-":
            setDisplay(storedValue - value)
        case "×":
            setDisplay(storedValue * value)
        case "÷":
            setDisplay(value == 0 ? 0 : storedValue / value)
        default:
            break
        }
    }

    private var currentValue: Double {
        Double(display) ?? 0
    }

    private func setDisplay(_ value: Double) {
        guard value.isFinite else {
            display = "0"
            return
        }
        if value.rounded() == value {
            display = String(Int(value))
        } else {
            var text = String(format: "%.6f", value)
            while text.last == "0" {
                text.removeLast()
            }
            if text.last == "." {
                text.removeLast()
            }
            display = text
        }
        if display.count > 12 {
            display = String(display.prefix(12))
        }
    }

    private func buttonForeground(for symbol: String) -> Color {
        if ["AC", "+/-", "%"].contains(symbol) {
            return .black
        }
        return .white
    }

    private func buttonBackground(for symbol: String) -> Color {
        if ["÷", "×", "-", "+", "="].contains(symbol) {
            return Color.orange
        }
        if ["AC", "+/-", "%"].contains(symbol) {
            return Color(white: 0.68)
        }
        return Color(white: 0.2)
    }
}

private struct BossKeyExitGuide: View {
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.orange)
                .clipShape(Circle())

            VStack(spacing: 5) {
                Text(L10n.t("老板键已启动"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Text(L10n.t("长按上方数字显示区，即可退出计算器并返回开薪。"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: dismiss) {
                Text(L10n.t("知道了"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PayJoyPressStyle(scale: 0.96))
        }
        .padding(18)
        .frame(maxWidth: 280)
        .background(Color(white: 0.12).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.36), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 26)
    }
}

private enum OvertimePresentation: Identifiable {
    case start(defaultStart: Date)
    case stop(record: OvertimeRecord, defaultEnd: Date)
    case manual(defaultStart: Date, defaultEnd: Date)

    var id: String {
        switch self {
        case .start(let defaultStart):
            return "start-\(defaultStart.timeIntervalSinceReferenceDate)"
        case .stop(let record, let defaultEnd):
            return "stop-\(record.id)-\(defaultEnd.timeIntervalSinceReferenceDate)"
        case .manual(let defaultStart, let defaultEnd):
            return "manual-\(defaultStart.timeIntervalSinceReferenceDate)-\(defaultEnd.timeIntervalSinceReferenceDate)"
        }
    }
}

private struct OvertimeActionCard: View {
    let activeRecord: OvertimeRecord?
    let activeDuration: TimeInterval
    let todayDuration: TimeInterval
    let canStart: Bool
    let defaultStart: Date
    let startAction: () -> Void
    let stopAction: () -> Void
    let manualAction: () -> Void

    var body: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: activeRecord == nil ? "timer.circle.fill" : "stopwatch.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(activeRecord == nil ? L10n.t("加班计时") : L10n.t("加班中"))
                            .font(.subheadline.weight(.heavy))
                        Text(statusText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 4)

                    Text((activeRecord == nil ? todayDuration : activeDuration).overtimeDurationText)
                        .font(.headline.weight(.black))
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    Button(action: activeRecord == nil ? startAction : stopAction) {
                        Text(activeRecord == nil ? L10n.t("开始加班") : L10n.t("结束加班"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(canStart || activeRecord != nil ? AppTheme.coin : AppTheme.divider.opacity(0.7))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.97))
                    .disabled(activeRecord == nil && !canStart)
                    .opacity(activeRecord == nil && !canStart ? 0.58 : 1)

                    Button(action: manualAction) {
                        Text(L10n.t("补录"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(AppTheme.cream.opacity(0.9))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
                    }
                    .buttonStyle(PayJoyPressStyle(scale: 0.97))
                }
            }
        }
    }

    private var statusText: String {
        if let activeRecord {
            return L10n.t("从 \(activeRecord.startAt.localizedTimeText) 开始，仅记录时长，不计入收入。")
        }
        return L10n.t("默认从 \(defaultStart.localizedTimeText) 开始，可手动补录开始和结束时间。")
    }
}

struct OvertimeStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startAt: Date
    let title: String
    let message: String
    let saveTitle: String
    let saveAction: (Date) -> Void

    init(
        defaultStart: Date,
        title: String = L10n.t("选择开始时间"),
        message: String = L10n.t("默认使用当前时间，也可以改成实际开始加班的时间。"),
        saveTitle: String = L10n.t("开始加班"),
        saveAction: @escaping (Date) -> Void
    ) {
        _startAt = State(initialValue: defaultStart)
        self.title = title
        self.message = message
        self.saveTitle = saveTitle
        self.saveAction = saveAction
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ComicCard(background: AppTheme.highlightCardBackground) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(title, systemImage: "play.circle.fill")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text(message)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                                .lineSpacing(2)

                            DatePicker(L10n.t("开始时间"), selection: $startAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.heavy))
                        }
                    }

                    Button {
                        saveAction(startAt)
                        dismiss()
                    } label: {
                        Text(saveTitle)
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.coin)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.4)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("加班记录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成")) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .environment(\.locale, Locale(identifier: L10n.currentLanguage.localeIdentifier))
    }
}

struct OvertimeStopSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var endAt: Date
    let record: OvertimeRecord
    let saveAction: (Date) -> Void

    private var endRange: ClosedRange<Date> {
        let now = Date()
        return min(record.startAt, now)...now
    }

    init(record: OvertimeRecord, defaultEnd: Date, saveAction: @escaping (Date) -> Void) {
        self.record = record
        let now = Date()
        _endAt = State(initialValue: min(max(defaultEnd, min(record.startAt, now)), now))
        self.saveAction = saveAction
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ComicCard(background: AppTheme.highlightCardBackground) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.t("选择结束时间"), systemImage: "stop.circle.fill")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text(L10n.t("默认使用当前时间，也可以改成实际结束加班的时间。"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                                .lineSpacing(2)

                            DatePicker(L10n.t("结束时间"), selection: $endAt, in: endRange, displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.heavy))

                            OvertimeTotalRow(duration: max(0, endAt.timeIntervalSince(record.startAt)))
                        }
                    }

                    Button {
                        saveAction(endAt)
                        dismiss()
                    } label: {
                        Text(L10n.t("结束加班"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.coin)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.4)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("加班记录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成")) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .environment(\.locale, Locale(identifier: L10n.currentLanguage.localeIdentifier))
    }
}

struct OvertimeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startAt: Date
    @State private var endAt: Date
    let title: String
    let message: String
    let saveTitle: String
    let saveAction: (Date, Date) -> Void

    private var canSave: Bool {
        endAt > startAt && endAt <= Date()
    }

    init(
        defaultStart: Date,
        defaultEnd: Date,
        title: String = L10n.t("补录加班时间"),
        message: String = L10n.t("只统计加班时长，不会增加今日已赚或月度收入。"),
        saveTitle: String = L10n.t("保存加班记录"),
        saveAction: @escaping (Date, Date) -> Void
    ) {
        _startAt = State(initialValue: defaultStart)
        _endAt = State(initialValue: defaultEnd)
        self.title = title
        self.message = message
        self.saveTitle = saveTitle
        self.saveAction = saveAction
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ComicCard(background: AppTheme.highlightCardBackground) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(title, systemImage: "timer")
                                .font(.headline.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                            Text(message)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textGray)
                                .lineSpacing(2)

                            DatePicker(L10n.t("开始时间"), selection: $startAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.heavy))
                            DatePicker(L10n.t("结束时间"), selection: $endAt, in: startAt...Date(), displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.heavy))

                            OvertimeTotalRow(duration: max(0, endAt.timeIntervalSince(startAt)))

                            if !canSave {
                                Text(L10n.t("结束时间需晚于开始时间。"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.red)
                            }
                        }
                    }

                    Button {
                        saveAction(startAt, endAt)
                        dismiss()
                    } label: {
                        Text(saveTitle)
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.coin)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                                    .stroke(AppTheme.outline, lineWidth: 1.4)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.48)
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("加班记录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("完成")) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .environment(\.locale, Locale(identifier: L10n.currentLanguage.localeIdentifier))
    }
}

private struct OvertimeTotalRow: View {
    let duration: TimeInterval

    var body: some View {
        HStack {
            Text(L10n.t("合计"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Spacer()
            Text(duration.overtimeDurationText)
                .font(.headline.weight(.black))
                .monospacedDigit()
        }
        .padding(10)
        .background(AppTheme.paper.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.86), lineWidth: 1)
        }
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
}

private extension Date {
    var localizedTimeText: String {
        formatted(.dateTime.locale(Locale(identifier: L10n.currentMarket.localeIdentifier)).hour().minute())
    }
}

private struct EarningsCard: View {
    let snapshot: EarningsSnapshot
    let pulse: Bool
    let reduceMotion: Bool
    let showDecimalCents: Bool
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String

    var body: some View {
        ComicCard(background: AppTheme.cream.opacity(0.62), radius: 20) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text(L10n.t("今日已赚"))
                        .font(.headline.weight(.heavy))
                    Text(amountText)
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.64)
                        .lineLimit(1)
                        .scaleEffect(pulse ? 1.045 : 1)
                        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.5), value: pulse)
                    Text(PrivacyText.perSecond(snapshot.earnedPerSecond, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textGray)
                    Text(snapshot.status.title)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.coin.opacity(0.7))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("今日已赚"))
        .accessibilityValue("\(amountText)，\(PrivacyText.perSecond(snapshot.earnedPerSecond, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))，\(snapshot.status.title)")
    }

    private var amountText: String {
        if hidesSensitiveAmounts {
            return PrivacyText.maskedMoney(currencySymbol: currencySymbol)
        }
        return showDecimalCents ? snapshot.todayEarned.moneyText(currencySymbol: currencySymbol) : snapshot.todayEarned.compactMoneyText(currencySymbol: currencySymbol)
    }
}

private struct CoinRainLayer: View {
    enum Style {
        case coin
        case redPacket
    }

    let style: Style

    private let coins: [FallingCoin] = [
        FallingCoin(x: 0.08, phase: 0.1, duration: 4.2, size: 24, asset: "coin_rain_left_v1"),
        FallingCoin(x: 0.18, phase: 1.7, duration: 5.1, size: 18, asset: "coin_single_v1"),
        FallingCoin(x: 0.27, phase: 3.0, duration: 4.7, size: 30, asset: "coin_rain_side_v1"),
        FallingCoin(x: 0.36, phase: 0.9, duration: 5.6, size: 16, asset: "coin_rain_right_v1"),
        FallingCoin(x: 0.45, phase: 2.2, duration: 4.4, size: 22, asset: "coin_single_v1"),
        FallingCoin(x: 0.55, phase: 3.8, duration: 5.3, size: 19, asset: "coin_rain_left_v1"),
        FallingCoin(x: 0.64, phase: 1.2, duration: 4.8, size: 32, asset: "coin_rain_right_v1"),
        FallingCoin(x: 0.73, phase: 2.8, duration: 5.7, size: 17, asset: "coin_rain_side_v1"),
        FallingCoin(x: 0.83, phase: 0.4, duration: 4.6, size: 26, asset: "coin_single_v1"),
        FallingCoin(x: 0.93, phase: 3.4, duration: 5.4, size: 20, asset: "coin_rain_left_v1"),
        FallingCoin(x: 0.14, phase: 4.0, duration: 6.0, size: 15, asset: "decor_sparkle_v1"),
        FallingCoin(x: 0.50, phase: 4.5, duration: 5.8, size: 14, asset: "decor_sparkle_v1"),
        FallingCoin(x: 0.88, phase: 5.2, duration: 6.2, size: 15, asset: "decor_sparkle_v1")
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            GeometryReader { proxy in
                ZStack {
                    ForEach(coins) { coin in
                        let progress = coin.progress(at: timeline.date)
                        let x = proxy.size.width * coin.x
                        let y = -70 + progress * (proxy.size.height + 160)

                        fallingReward(for: coin)
                            .rotationEffect(.degrees(progress * 760 + coin.phase * 90))
                            .position(x: x, y: y)
                            .opacity(coin.opacity(at: progress))
                            .scaleEffect(0.86 + progress * 0.22)
                    }
                }
                .clipped()
            }
        }
    }

    @ViewBuilder
    private func fallingReward(for coin: FallingCoin) -> some View {
        if coin.isSparkle {
            AssetImage(name: coin.asset)
                .frame(width: coin.size, height: coin.size)
        } else {
            switch style {
            case .coin:
                AssetImage(name: coin.asset)
                    .frame(width: coin.size, height: coin.size)
            case .redPacket:
                RedPacketRainItem(size: coin.size)
            }
        }
    }
}

private struct RedPacketRainItem: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.22, blue: 0.22), Color(red: 0.72, green: 0.04, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.78), lineWidth: max(0.8, size * 0.045))

            Rectangle()
                .fill(Color(red: 1.0, green: 0.78, blue: 0.22))
                .frame(width: size * 0.42, height: size * 0.12)
                .offset(y: -size * 0.2)

            Circle()
                .fill(AppTheme.coin)
                .frame(width: size * 0.34, height: size * 0.34)
                .overlay {
                    Circle()
                        .stroke(AppTheme.outline.opacity(0.62), lineWidth: max(0.7, size * 0.035))
                }
                .offset(y: size * 0.08)

            Text("¥")
                .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .offset(y: size * 0.08)
        }
        .frame(width: size * 0.82, height: size * 1.08)
        .shadow(color: AppTheme.shadow.opacity(0.16), radius: 1, x: 1, y: 1)
        .accessibilityHidden(true)
    }
}

private struct FallingCoin: Identifiable {
    let id = UUID()
    let x: CGFloat
    let phase: Double
    let duration: Double
    let size: CGFloat
    let asset: String

    var isSparkle: Bool {
        asset.contains("sparkle")
    }

    func progress(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate + phase
        return elapsed.truncatingRemainder(dividingBy: duration) / duration
    }

    func opacity(at progress: Double) -> Double {
        if progress < 0.08 {
            return progress / 0.08
        }
        if progress > 0.88 {
            return max(0, (1 - progress) / 0.12)
        }
        return 0.9
    }
}

private struct ProgressSummaryCard: View {
    let snapshot: EarningsSnapshot
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String

    var body: some View {
        ComicCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("今日进度"))
                            .font(.headline.weight(.heavy))
                        Text("\(snapshot.progress * 100, specifier: "%.1f")%")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                    }
                    Spacer()
                    AssetImage(name: "decor_sun_progress_v1")
                        .frame(width: 42, height: 42)
                }
                ComicProgressBar(progress: snapshot.progress)
                HStack {
                    Text(L10n.t("目标"))
                    Spacer()
                    Text(PrivacyText.money(snapshot.todayTotal, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            }
        }
    }
}

private struct SmallMetricCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        ComicCard(padding: 12) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.heavy))
                Text(value)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text(caption)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MoyuCard: View {
    let snapshot: EarningsSnapshot
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String
    let reduceMotion: Bool

    @State private var startedAt: Date?
    @State private var finishedSession: MoyuSession?

    var body: some View {
        ComicCard(background: AppTheme.cream, padding: 12) {
            HStack(alignment: .center, spacing: 12) {
                MoyuActionPanel(
                    snapshot: snapshot,
                    hidesSensitiveAmounts: hidesSensitiveAmounts,
                    currencySymbol: currencySymbol,
                    startedAt: startedAt,
                    finishedSession: finishedSession,
                    start: startMoyu,
                    stop: stopMoyu,
                    clear: clearMoyu
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                AssetImage(name: AppTheme.moyuWorkerAsset)
                    .frame(width: 118, height: 100)
                    .scaleEffect(AppTheme.cardArtworkScale, anchor: .trailing)
                    .accessibilityHidden(true)
            }
        }
    }

    private func startMoyu() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)) {
            finishedSession = nil
            startedAt = Date()
        }
    }

    private func stopMoyu() {
        guard let startedAt else { return }
        let duration = max(0, Date().timeIntervalSince(startedAt))
        withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)) {
            finishedSession = MoyuSession(duration: duration, amount: duration * snapshot.earnedPerSecond)
            self.startedAt = nil
        }
    }

    private func clearMoyu() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82)) {
            finishedSession = nil
            startedAt = nil
        }
    }
}

private struct MoyuActionPanel: View {
    let snapshot: EarningsSnapshot
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String
    let startedAt: Date?
    let finishedSession: MoyuSession?
    let start: () -> Void
    let stop: () -> Void
    let clear: () -> Void

    var body: some View {
        Group {
            if let startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    runningContent(startedAt: startedAt, now: timeline.date)
                }
            } else if let finishedSession {
                finishedContent(finishedSession)
            } else {
                idleContent
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("开始摸鱼"))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(L10n.t("单独记录这段快乐时间，公司买单。"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .fixedSize(horizontal: false, vertical: true)

            MoyuButton(title: L10n.t("开始摸鱼"), systemImage: "play.fill", background: AppTheme.coin, action: start)
        }
    }

    private func runningContent(startedAt: Date, now: Date) -> some View {
        let duration = max(0, now.timeIntervalSince(startedAt))
        let amount = duration * snapshot.earnedPerSecond

        return VStack(alignment: .leading, spacing: 7) {
            Text(L10n.t("摸鱼中"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 8) {
                MoyuMetric(label: L10n.t("时长"), value: duration.moyuDurationText)
                MoyuMetric(label: L10n.t("快乐金"), value: PrivacyText.money(amount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
            }

            MoyuButton(title: L10n.t("停止摸鱼"), systemImage: "pause.fill", background: Color(hex: 0xFFE9A8), action: stop)
        }
    }

    private func finishedContent(_ session: MoyuSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("快乐到账"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            Text(L10n.t("刚才摸鱼 \(session.duration.moyuDurationText)，公司为你的快乐支付了 \(PrivacyText.money(session.amount, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))。"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.textGray)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            MoyuButton(title: L10n.t("清空"), systemImage: "arrow.counterclockwise", background: AppTheme.coin, action: clear)
        }
    }
}

private struct MoyuButton: View {
    let title: String
    let systemImage: String
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.outline, lineWidth: 1.4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct MoyuMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(AppTheme.softSurface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.7), lineWidth: 1)
        }
    }
}

private struct MoyuSession: Equatable {
    let duration: TimeInterval
    let amount: Double
}

private extension TimeInterval {
    var moyuDurationText: String {
        let totalSeconds = max(0, Int(self.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return L10n.t("\(minutes)分\(seconds)秒")
        }
        return L10n.t("\(seconds)秒")
    }
}
