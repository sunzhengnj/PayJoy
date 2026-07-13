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
                .preferredColorScheme(appState.preferences.selectedTheme == .midnight ? .dark : .light)
        }
    }
}

private enum ScreenshotScreen: String {
    case home
    case countdown
    case stats
    case calendar
    case overtime
    case widgets
    case privacy
    case worktime

    static var current: ScreenshotScreen {
        let value = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] ?? "home"
        return ScreenshotScreen(rawValue: value) ?? .home
    }
}

private struct ScreenshotHostView: View {
    @Environment(AppState.self) private var appState
    private let screen = ScreenshotScreen.current

    var body: some View {
        Group {
            switch screen {
            case .home, .countdown:
                NavigationStack { HomeView() }
            case .stats:
                NavigationStack { StatsView() }
            case .calendar:
                SalaryCalendarView()
            case .overtime:
                ScreenshotOvertimeView()
            case .widgets:
                ScreenshotWidgetView()
            case .privacy:
                ScreenshotPrivacyView()
            case .worktime:
                NavigationStack { SalarySettingsView(mode: .workTime) }
            }
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("小组件指引"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(L10n.t("把开薪小组件加到桌面"))
                                    .font(.headline.weight(.heavy))
                                Text(L10n.t("不用打开 App，也能看到今日已赚、进度和倒计时。"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textGray)
                            }
                            Spacer()
                            AssetImage(name: "widget_guide_preview_v1")
                                .frame(width: 116, height: 92)
                        }
                    }
                }

                LiveActivityControlCard(
                    isAvailable: true,
                    isActive: true,
                    statusTitle: appState.snapshot.status.title,
                    errorMessage: L10n.t("锁屏和灵动岛也能展示当前进度。")
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
}

private struct ScreenshotPrivacyView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("隐私与密码"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                ScreenshotEarningsCard(
                    snapshot: appState.snapshot,
                    hidesSensitiveAmounts: true,
                    currencySymbol: appState.settings.currencySymbol
                )

                ComicCard(background: AppTheme.highlightCardBackground, padding: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(L10n.t("多任务页面隐私保护"), systemImage: "rectangle.stack.badge.person.crop.fill")
                            .font(.headline.weight(.heavy))
                        Text(L10n.t("切到多任务页面时，开薪会自动盖上隐私遮罩，避免收入、进度和个人信息出现在系统预览里。"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textGray)
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 26, weight: .black))
                            Text(L10n.t("隐藏金额"))
                                .font(.title3.weight(.black))
                            Spacer()
                            Text("••••")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                        }
                        .padding(12)
                        .background(AppTheme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.ink, lineWidth: 1.4)
                        }
                    }
                }
            }
            .padding(AppTheme.pagePadding)
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
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }
}
