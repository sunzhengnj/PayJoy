import SwiftUI

@main
struct PayJoyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if AppState.isScreenshotMode {
                    ScreenshotHostView()
                } else {
                    AppRootView()
                }
            }
                .environment(appState)
                .environment(\.locale, Locale(identifier: appState.preferences.appLanguage.localeIdentifier))
                .environment(\.payJoyReduceMotion, appState.preferences.reduceMotion)
                .preferredColorScheme(appState.preferences.selectedTheme == .midnight ? .dark : .light)
        }
    }
}

private enum ScreenshotScreen: String {
    case root
    case home
    case homeAfterMidnight = "home-after-midnight"
    case homeRestDay = "home-rest-day"
    case countdown
    case stats
    case statsActualSalary = "stats-actual-salary"
    case statsLower = "stats-lower"
    case achievements
    case achievementsLower = "achievements-lower"
    case weeklyEcho = "weekly-echo"
    case weeklyReport = "weekly-report"
    case weeklyReportCompact = "weekly-report-compact"
    case dailyReport = "daily-report"
    case calendar
    case overtime
    case widgets
    case privacy
    case theme
    case worktime
    case worktimeError = "worktime-error"
    case salarySettings = "salary-settings"
    case payday
    case membershipPrompt = "membership-prompt"
    case actualSalary = "actual-salary"
    case profile
    case profileLower = "profile-lower"
    case incomePlan = "income-plan"
    case proReportEnergy = "pro-report-energy"
    case proReportBattle = "pro-report-battle"
    case proReportJourney = "pro-report-journey"
    case proReportMidnight = "pro-report-midnight"
    case proReportShareEnergy = "pro-report-share-energy"
    case proReportShareBattle = "pro-report-share-battle"
    case proReportShareJourney = "pro-report-share-journey"
    case proReportShareMidnight = "pro-report-share-midnight"
    case displayEffects = "display-effects"
    case helpFeedback = "help-feedback"
    case paywall
    case paywallLoading = "paywall-loading"
    case paywallError = "paywall-error"
    case paywallLower = "paywall-lower"
    case paywallReport = "paywall-report"
    case onboardingPay = "onboarding-pay"
    case wishTab = "wish-tab"
    case wishProgressEditor = "wish-progress-editor"
    case wishRealization = "wish-realization"
    case closingReceipt = "closing-receipt"
    case closingReceiptComplete = "closing-receipt-complete"

    static var current: ScreenshotScreen {
        let arguments = ProcessInfo.processInfo.arguments
        let argumentValue = arguments.first(where: { $0.hasPrefix("PAYJOY_SCREENSHOT_SCREEN=") })?
            .split(separator: "=", maxSplits: 1)
            .last
            .map(String.init)
        let value = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] ?? argumentValue ?? "home"
        return ScreenshotScreen(rawValue: value) ?? .home
    }
}

private struct ScreenshotHostView: View {
    @Environment(AppState.self) private var appState
    private let screen = ScreenshotScreen.current

    var body: some View {
        Group {
            switch screen {
            case .root:
                AppRootView()
            case .home, .homeAfterMidnight, .homeRestDay, .countdown:
                NavigationStack { HomeView() }
            case .stats, .statsActualSalary, .statsLower:
                NavigationStack { StatsView() }
            case .achievements, .achievementsLower:
                NavigationStack {
                    ScrollView {
                        SalaryAchievementCard(badges: appState.salaryBadges)
                            .padding(AppTheme.pagePadding)
                    }
                    .background(AppTheme.paper.ignoresSafeArea())
                    .defaultScrollAnchor(screen == .achievementsLower ? .bottom : .top)
                    .navigationTitle(L10n.t("开薪成就"))
                    .navigationBarTitleDisplayMode(.inline)
                }
            case .weeklyEcho:
                WeeklyEchoSheet()
            case .weeklyReport:
                ScreenshotWeeklyReportView()
            case .weeklyReportCompact:
                ScreenshotWeeklyReportView(style: .compact)
            case .dailyReport:
                ScreenshotDailyReportView()
            case .calendar:
                SalaryCalendarView()
            case .overtime:
                ScreenshotOvertimeView()
            case .widgets:
                ScreenshotWidgetView()
            case .privacy:
                ProfileDetailSheet(sheet: .privacy)
            case .theme:
                ProfileDetailSheet(sheet: .theme)
            case .worktime, .worktimeError:
                NavigationStack { SalarySettingsView(mode: .workTime) }
            case .salarySettings:
                NavigationStack { SalarySettingsView(mode: .salary) }
            case .payday:
                PaydayCelebrationView()
            case .membershipPrompt:
                PaydayCelebrationView(presentsMembershipPromptOnAppear: true)
            case .actualSalary:
                NavigationStack { ActualSalaryHistoryView() }
            case .profile, .profileLower:
                NavigationStack { ProfileView() }
            case .displayEffects:
                NavigationStack {
                    DisplayEffectsSettingsSheet()
                        .navigationTitle(L10n.t("显示与动效"))
                        .navigationBarTitleDisplayMode(.inline)
                }
            case .helpFeedback:
                ProfileDetailSheet(sheet: .help)
            case .incomePlan:
                ScreenshotPersonalGoalView()
            case .proReportEnergy:
                NavigationStack { ProSalaryReportView(initialStyle: .classic) }
            case .proReportBattle:
                NavigationStack { ProSalaryReportView(initialStyle: .pink) }
            case .proReportJourney:
                NavigationStack { ProSalaryReportView(initialStyle: .luckyCat) }
            case .proReportMidnight:
                NavigationStack { ProSalaryReportView(initialStyle: .midnight) }
            case .proReportShareEnergy:
                NavigationStack {
                    ProSalaryReportView(initialStyle: .classic, showsSharePosterInitially: true)
                }
            case .proReportShareBattle:
                NavigationStack {
                    ProSalaryReportView(initialStyle: .pink, showsSharePosterInitially: true)
                }
            case .proReportShareJourney:
                NavigationStack {
                    ProSalaryReportView(initialStyle: .luckyCat, showsSharePosterInitially: true)
                }
            case .proReportShareMidnight:
                NavigationStack {
                    ProSalaryReportView(initialStyle: .midnight, showsSharePosterInitially: true)
                }
            case .paywall, .paywallLoading, .paywallError, .paywallLower:
                ProPaywallSheet()
            case .paywallReport:
                ProPaywallSheet(context: .salaryReport)
            case .onboardingPay:
                NavigationStack { EmotionalOnboardingView() }
            case .wishTab:
                AppRootView()
            case .wishProgressEditor:
                ScreenshotWishProgressEditorView()
            case .wishRealization:
                ScreenshotWishRealizationView()
            case .closingReceipt, .closingReceiptComplete:
                ClosingReceiptFlowView()
            }
        }
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

private struct ScreenshotPersonalGoalView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: false) {
            PersonalGoalCard(
                goal: appState.personalGoal,
                progress: appState.personalGoalProgress,
                hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                currencySymbol: appState.settings.currencySymbol,
                editGoalAction: {},
                celebrateGoalAction: {}
            )
            .padding(AppTheme.pagePadding)
        }
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

private struct ScreenshotWeeklyReportView: View {
    @Environment(AppState.self) private var appState
    var style: WeeklyPayReportCardStyle = .regular

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("本周战报"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                WeeklyPayReportCard(
                    report: appState.weeklyPayReport,
                    hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                    currencySymbol: appState.settings.currencySymbol,
                    style: style
                )
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, 18)
        }
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

private struct ScreenshotDailyReportView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("今日收工"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                DailyPayReportCard(
                    snapshot: appState.snapshot,
                    hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                    currencySymbol: appState.settings.currencySymbol
                )
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, 18)
        }
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

private struct ScreenshotOvertimeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("加班记录"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.t("加班中"))
                                .font(.headline.weight(.heavy))
                            Text(appState.activeOvertimeDuration.screenshotDurationText)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .monospacedDigit()
                            Label(L10n.t("结束加班"), systemImage: "stop.fill")
                                .font(.caption.weight(.black))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.coin)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.ink, lineWidth: 1))
                        }
                        Spacer()
                        AssetImage(name: AppTheme.moyuWorkerAsset)
                            .frame(width: 116, height: 92)
                    }
                }

                ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(L10n.t("本月加班记录"))
                                    .font(.headline.weight(.heavy))
                                Text(L10n.t("加班只统计时长，不计入收入。"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                            }
                            Spacer()
                            AssetImage(name: AppTheme.overtimeSummaryWorkerAsset)
                                .frame(width: 106, height: 82)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ScreenshotMetric(title: L10n.t("记录数"), value: L10n.t("%@ 条", "\(appState.overtimeSummary(forMonthContaining: appState.now).count)"))
                            ScreenshotMetric(title: L10n.t("加班时长"), value: appState.overtimeSummary(forMonthContaining: appState.now).totalSeconds.screenshotDurationText)
                            ScreenshotMetric(title: L10n.t("进行中"), value: L10n.t("是"))
                        }
                    }
                }

                VStack(spacing: 10) {
                    ForEach(appState.overtimeRecords.prefix(3)) { record in
                        ComicCard(background: AppTheme.cream, padding: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.isActive ? L10n.t("当前加班") : L10n.t("加班记录"))
                                        .font(.headline.weight(.black))
                                    Text(record.isActive ? L10n.t("计时中") : L10n.t("已完成"))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.textGray)
                                }
                                Spacer()
                                Text(record.duration(until: appState.now).screenshotDurationText)
                                    .font(.title2.weight(.black))
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
        }
    }
}

private struct ScreenshotWidgetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("小组件指引"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
                    if dynamicTypeSize.isAccessibilitySize {
                        widgetGuideCopy
                    } else {
                        HStack(spacing: 12) {
                            widgetGuideCopy
                            Spacer()
                            AssetImage(name: "widget_guide_preview_v1")
                                .frame(width: 116, height: 92)
                                .accessibilityHidden(true)
                        }
                    }
                }

                LiveActivityControlCard(
                    isAvailable: true,
                    isActive: true,
                    statusTitle: appState.snapshot.status.title,
                    statusMessage: L10n.t("锁屏和灵动岛也能展示当前进度。"),
                    errorMessage: nil
                ) {}

                ScreenshotEarningsCard(
                    snapshot: appState.snapshot,
                    hidesSensitiveAmounts: appState.preferences.hideSensitiveAmounts,
                    currencySymbol: appState.settings.currencySymbol
                )
            }
            .padding(AppTheme.pagePadding)
        }
    }

    private var widgetGuideCopy: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.t("把开薪小组件加到桌面"))
                .font(.headline.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("不用打开 App，也能看到今日已赚、进度和倒计时。"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textGray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ScreenshotMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.black))
                .foregroundStyle(AppTheme.textGray)
            Text(value)
                .font(.headline.weight(.black))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.paper.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct ScreenshotEarningsCard: View {
    let snapshot: EarningsSnapshot
    let hidesSensitiveAmounts: Bool
    let currencySymbol: String

    var body: some View {
        ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.t("今日已赚"))
                            .font(.headline.weight(.heavy))
                        Text(PrivacyText.money(snapshot.todayEarned, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .minimumScaleFactor(0.62)
                            .lineLimit(1)
                        Text(PrivacyText.perSecond(snapshot.earnedPerSecond, hidden: hidesSensitiveAmounts, currencySymbol: currencySymbol))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                    }
                    Spacer()
                    AssetImage(name: AppTheme.heroWorkerAsset)
                        .frame(width: 128, height: 96)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(L10n.t("今日进度"))
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.textGray)
                        Spacer()
                        Text("\(snapshot.progress * 100, specifier: "%.1f")%")
                            .font(.headline.weight(.black))
                            .monospacedDigit()
                    }
                    ComicProgressBar(progress: snapshot.progress)
                }
                .padding(10)
                .background(AppTheme.paper.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.9), lineWidth: 1.2)
                }
            }
        }
    }
}

private extension TimeInterval {
    var screenshotDurationText: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return L10n.format("%d小时%d分钟", hours, minutes)
        }
        return L10n.format("%d分钟", minutes)
    }
}
