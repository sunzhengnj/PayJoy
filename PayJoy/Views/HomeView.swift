import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var amountPulse = false
    @State private var lastEarnedCents = 0
    @State private var heroBubbleText = HomeView.randomBubbleText()
    @State private var lastBubbleRefresh = Date.distantPast
    @State private var overtimePresentation: OvertimePresentation?
    @State private var earlyLeaveConfirmation: EarlyLeaveConfirmation?
    @State private var closingReport: ClosingReport?
    @State private var isBossModePresented = false
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
                    hero
                        .padding(.bottom, -8)
                    EarningsCard(
                        snapshot: appState.snapshot,
                        pulse: amountPulse,
                        showDecimalCents: appState.preferences.showDecimalCents,
                        hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                        currencySymbol: appState.settings.currencySymbol
                    )
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
                    ProgressSummaryCard(snapshot: appState.snapshot, hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol)
                    HStack(spacing: 10) {
                        SmallMetricCard(title: L10n.t("下班倒计时"), value: appState.snapshot.secondsUntilOffWork.countdownText, caption: appState.settings.workEnd.displayText)
                        SmallMetricCard(
                            title: L10n.t("今天还可赚"),
                            value: PrivacyText.compactMoney(appState.snapshot.remainingToday, hidden: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol),
                            caption: L10n.t("继续回血")
                        )
                    }
                    MoyuCard(snapshot: appState.snapshot, hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts, currencySymbol: appState.settings.currencySymbol)
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
                .padding(.bottom, 10)
            }

            if let confirmation = earlyLeaveConfirmation {
                EarlyLeaveConfirmationOverlay(
                    confirmation: confirmation,
                    dismiss: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            earlyLeaveConfirmation = nil
                        }
                    },
                    confirm: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            switch confirmation {
                            case .leave:
                                appState.leaveWorkEarlyToday()
                                closingReport = ClosingReport(
                                    kind: .earlyLeave,
                                    startAt: workStartDate(for: appState.now),
                                    endAt: appState.now,
                                    earned: appState.snapshot.todayTotal,
                                    progress: 1,
                                    overtimeDuration: nil
                                )
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

            if let report = closingReport {
                ClosingReportOverlay(
                    report: report,
                    hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                    currencySymbol: appState.settings.currencySymbol,
                    dismiss: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            closingReport = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(12)
            }
        }
        .background(AppTheme.paper)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $isBossModePresented) {
            BossCalculatorView()
        }
        .fullScreenCover(isPresented: $showsProPaywall) {
            ProPaywallSheet()
        }
        .sheet(item: $overtimePresentation) { presentation in
            switch presentation {
            case .start(let defaultStart):
                OvertimeStartSheet(defaultStart: defaultStart) { startAt in
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                        appState.startOvertime(at: startAt)
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.paper)
            case .stop(let record, let defaultEnd):
                OvertimeStopSheet(record: record, defaultEnd: defaultEnd) { endAt in
                    let report = ClosingReport(
                        kind: .overtime,
                        startAt: record.startAt,
                        endAt: endAt,
                        earned: appState.snapshot.todayEarned,
                        progress: appState.snapshot.progress,
                        overtimeDuration: max(0, endAt.timeIntervalSince(record.startAt))
                    )
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        appState.stopActiveOvertime(at: endAt)
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(260))
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            closingReport = report
                        }
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
        .onChange(of: appState.now) { _, newValue in
            guard newValue.timeIntervalSince(lastBubbleRefresh) > 55 else { return }
            refreshBubble(force: false)
        }
        .onChange(of: appState.snapshot.todayEarned) { _, newValue in
            let cents = Int(newValue * 100)
            guard cents != lastEarnedCents else { return }
            lastEarnedCents = cents
            withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                amountPulse.toggle()
            }
        }
    }

    private var shouldShowRewardRain: Bool {
        (appState.snapshot.status == .working || appState.activeOvertimeRecord != nil) &&
        appState.preferences.showCoinRain &&
        AppTheme.current != .midnight &&
        !appState.preferences.reduceMotion
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            if L10n.currentLanguage == .zhHans, AppTheme.current != .midnight {
                AssetImage(name: "home_header_lettering_spaced_v2")
                    .frame(width: 226, height: 163)
                    .offset(x: -2, y: 0)
                    .accessibilityLabel(Text(L10n.t("开薪！打工赚钱的每一秒，都是热爱生活的证据！")))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("开薪！"))
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(L10n.t("打工赚钱的每一秒，都是热爱生活的证据！"))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(AppTheme.ink)
                        .lineSpacing(3)
                        .frame(width: 250, alignment: .leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                }
                .frame(width: 270, height: 163, alignment: .topLeading)
                .offset(x: 0, y: 18)
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

            HStack(spacing: 9) {
                Button {
                    openBossKey()
                } label: {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.softSurface.opacity(0.9))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("老板键"))

                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        appState.togglePrivacyMode()
                    }
                } label: {
                    Image(systemName: appState.preferences.hideSensitiveAmounts ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.preferences.hideSensitiveAmounts ? L10n.t("显示金额") : L10n.t("隐藏金额"))
                .onLongPressGesture(minimumDuration: 0.7) {
                    openBossKey()
                }
            }
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            AssetImage(name: AppTheme.heroWorkerAsset)
                .frame(maxWidth: .infinity)
                .frame(height: 132)
                .scaleEffect(AppTheme.heroArtworkScale, anchor: .bottom)
                .offset(y: AppTheme.heroArtworkYOffset)
            SpeechBubble(text: heroBubbleText, isYellow: false, tailX: 0.24)
                .frame(width: 144)
                .offset(x: -6, y: -6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: AppTheme.heroSectionHeight)
    }

    private func refreshBubble(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastBubbleRefresh) > 30 else { return }
        heroBubbleText = Self.randomBubbleText(for: appState, excluding: heroBubbleText)
        lastBubbleRefresh = now
    }

    private func workStartDate(for date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = appState.settings.workStart.hour
        components.minute = appState.settings.workStart.minute
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }

    private func openBossKey() {
        guard appState.hasEffectivePro else {
            appState.requireProFeature(L10n.t("老板键是 PRO 功能，开通后可一键伪装成计算器。"))
            showsProPaywall = true
            return
        }
        isBossModePresented = true
    }

    private static func randomBubbleText(excluding current: String? = nil) -> String {
        randomBubbleText(for: nil, excluding: current)
    }

    private static func randomBubbleText(for appState: AppState?, excluding current: String? = nil) -> String {
        var priorityMessages: [String] = []
        if let appState {
            let hour = Calendar.current.component(.hour, from: appState.now)
            let weekday = Calendar.current.component(.weekday, from: appState.now)

            if hour >= 22 || hour < 5 {
                priorityMessages.append(contentsOf: [
                    L10n.t("夜班模式启动，屏幕也在陪你。"),
                    L10n.t("深夜在线，金币别睡。")
                ])
            }
            if weekday == 6 && hour >= 15 {
                priorityMessages.append(contentsOf: [
                    L10n.t("周五下午，自由已经在门口刷卡。"),
                    L10n.t("周五尾声，钱包和灵魂都在倒计时。")
                ])
            }
            switch appState.snapshot.status {
            case .beforeWork:
                priorityMessages.append(L10n.t("开工前，钱包正在做热身。"))
            case .lunchBreak:
                priorityMessages.append(L10n.t("午休暂停，快乐继续。"))
            case .afterWork:
                priorityMessages.append(L10n.t("今日到账，打工人安全下线。"))
            case .restDay:
                priorityMessages.append(L10n.t("休息日不开薪，也要开心。"))
            case .working:
                break
            }
        }

        let messages = [
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
        let candidates = (priorityMessages.isEmpty ? messages : priorityMessages).filter { $0 != current }
        return candidates.randomElement() ?? messages[0]
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
                Image(systemName: "figure.walk.departure")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.softSurface.opacity(0.72))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

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

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppTheme.ink)
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
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("提前下班"))
    }
}

private struct CancelEarlyLeaveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.softSurface.opacity(0.72))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.2))

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

                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppTheme.ink)
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
        .buttonStyle(.plain)
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
                .buttonStyle(.plain)
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

private struct ClosingReport: Identifiable, Equatable {
    enum Kind {
        case overtime
        case earlyLeave

        var title: String {
            switch self {
            case .overtime: L10n.t("下班结算战报")
            case .earlyLeave: L10n.t("今日收工战报")
            }
        }

        var subtitle: String {
            switch self {
            case .overtime: L10n.t("加班已收尾，辛苦值已记录。")
            case .earlyLeave: L10n.t("今天已标记收工，收入按整天结算。")
            }
        }

        var iconName: String {
            switch self {
            case .overtime: "moon.stars.fill"
            case .earlyLeave: "checkmark.seal.fill"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let startAt: Date
    let endAt: Date
    let earned: Double
    let progress: Double
    let overtimeDuration: TimeInterval?
}

private struct ClosingReportOverlay: View {
    let report: ClosingReport
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(AppTheme.current == .midnight ? 0.45 : 0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: report.kind.iconName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.coin)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.outline, lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(report.kind.title)
                            .font(.title3.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                        Text(report.kind.subtitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 9) {
                    ClosingReportMetric(title: L10n.t("今日已赚"), value: PrivacyText.money(report.earned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                    ClosingReportMetric(title: L10n.t("今日进度"), value: String(format: "%.1f%%", report.progress * 100))
                    if let overtimeDuration = report.overtimeDuration {
                        ClosingReportMetric(title: L10n.t("本次加班"), value: overtimeDuration.overtimeDurationText)
                    }
                    ClosingReportMetric(title: L10n.t("收工时间"), value: "\(report.startAt.localizedTimeText)-\(report.endAt.localizedTimeText)")
                }

                Button(action: dismiss) {
                    Text(L10n.t("收下战报"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.coin)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.outline, lineWidth: 1.3)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxWidth: 342)
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.outline, lineWidth: 1.8)
            }
            .shadow(color: AppTheme.shadow.opacity(0.24), radius: 0, x: 5, y: 5)
            .padding(.horizontal, 24)
        }
    }
}

private struct ClosingReportMetric: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
            Spacer(minLength: 8)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.softSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.outline.opacity(0.78), lineWidth: 1)
        }
    }
}

private struct BossCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
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
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
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
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                showsExitGuide = true
            }
        }
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
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
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
                        Label(activeRecord == nil ? L10n.t("开始加班") : L10n.t("结束加班"), systemImage: activeRecord == nil ? "play.fill" : "stop.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(canStart || activeRecord != nil ? AppTheme.coin : AppTheme.divider.opacity(0.7))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
                    }
                    .buttonStyle(.plain)
                    .disabled(activeRecord == nil && !canStart)

                    Button(action: manualAction) {
                        Label(L10n.t("补录"), systemImage: "square.and.pencil")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(AppTheme.cream.opacity(0.9))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.outline, lineWidth: 1.1))
                    }
                    .buttonStyle(.plain)
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

                            DatePicker(L10n.t("开始时间"), selection: $startAt, displayedComponents: [.date, .hourAndMinute])
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

    init(record: OvertimeRecord, defaultEnd: Date, saveAction: @escaping (Date) -> Void) {
        self.record = record
        _endAt = State(initialValue: defaultEnd)
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

                            DatePicker(L10n.t("结束时间"), selection: $endAt, displayedComponents: [.date, .hourAndMinute])
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

                            DatePicker(L10n.t("开始时间"), selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.heavy))
                            DatePicker(L10n.t("结束时间"), selection: $endAt, displayedComponents: [.date, .hourAndMinute])
                                .font(.subheadline.weight(.heavy))

                            OvertimeTotalRow(duration: max(0, endAt.timeIntervalSince(startAt)))
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
        formatted(.dateTime.locale(Locale(identifier: L10n.currentLanguage.localeIdentifier)).hour().minute())
    }
}

private struct EarningsCard: View {
    let snapshot: EarningsSnapshot
    let pulse: Bool
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
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pulse)
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
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
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
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            finishedSession = nil
            startedAt = Date()
        }
    }

    private func stopMoyu() {
        guard let startedAt else { return }
        let duration = max(0, Date().timeIntervalSince(startedAt))
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            finishedSession = MoyuSession(duration: duration, amount: duration * snapshot.earnedPerSecond)
            self.startedAt = nil
        }
    }

    private func clearMoyu() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
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
