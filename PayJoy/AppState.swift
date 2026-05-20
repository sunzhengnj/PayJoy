import Foundation
import ActivityKit
import Observation
import UserNotifications
import WidgetKit

@MainActor
@Observable
final class AppState {
    var settings: SalarySettings {
        didSet {
            store.save(settings)
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            if preferences.remindersEnabled {
                reminderScheduler.scheduleWorkdayReminders(settings: settings)
            }
        }
    }
    var profile: UserProfile {
        didSet { store.saveProfile(profile) }
    }
    var preferences: AppPreferences {
        didSet { store.savePreferences(preferences) }
    }
    var overtimeDateKeys: Set<String> {
        didSet {
            store.saveOvertimeDays(overtimeDateKeys)
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
        }
    }
    var now: Date
    var selectedTab: AppTab = .home
    var isTabBarHidden = false
    var reminderPermissionState: ReminderPermissionState = .unknown
    var liveActivityErrorMessage: String?

    private let calculator: SalaryCalculator
    private let store: SettingsStore
    private let reminderScheduler: WorkReminderScheduler

    init(
        calculator: SalaryCalculator = SalaryCalculator(),
        store: SettingsStore = SettingsStore(),
        reminderScheduler: WorkReminderScheduler = WorkReminderScheduler(),
        now: Date = Date()
    ) {
        self.calculator = calculator
        self.store = store
        self.reminderScheduler = reminderScheduler
        self.settings = store.load()
        self.profile = store.loadProfile()
        self.preferences = store.loadPreferences()
        self.overtimeDateKeys = store.loadOvertimeDays()
        self.now = now
        refreshReminderAuthorization()
    }

    var snapshot: EarningsSnapshot {
        calculator.snapshot(for: now, settings: settings, overtimeDateKeys: overtimeDateKeys)
    }

    func periodEarnings(for period: StatsPeriod) -> PeriodEarnings {
        calculator.periodEarnings(for: period, date: now, settings: settings, overtimeDateKeys: overtimeDateKeys)
    }

    func periodBreakdown(for period: StatsPeriod) -> PeriodBreakdown {
        calculator.periodBreakdown(for: period, date: now, settings: settings, overtimeDateKeys: overtimeDateKeys)
    }

    var canEnableOvertimeToday: Bool {
        !calculator.isRegularWorkday(now, settings: settings) && !overtimeDateKeys.contains(todayDateKey)
    }

    var todayDateKey: String {
        calculator.dateKey(for: now)
    }

    func updateClock() {
        now = Date()
        if isLiveActivityActive, Int(now.timeIntervalSince1970) % 15 == 0 {
            updateLiveActivity()
        }
    }

    func resetDemoData() {
        settings = .defaultValue
        profile = .defaultValue
        preferences = .defaultValue
        overtimeDateKeys = []
        reminderScheduler.cancelWorkdayReminders()
    }

    func enableOvertimeToday() {
        overtimeDateKeys.insert(todayDateKey)
    }

    func refreshWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: "PayJoyEarningsWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }

    var isLiveActivityAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isLiveActivityActive: Bool {
        !Activity<PayJoyActivityAttributes>.activities.isEmpty
    }

    func startLiveActivity() {
        liveActivityErrorMessage = nil
        guard isLiveActivityAvailable else { return }
        if isLiveActivityActive {
            updateLiveActivity()
            return
        }

        do {
            _ = try Activity.request(
                attributes: PayJoyActivityAttributes(title: "开薪中"),
                content: ActivityContent(state: liveActivityState(), staleDate: Date(timeIntervalSinceNow: 60)),
                pushType: nil
            )
        } catch {
            liveActivityErrorMessage = liveActivityFailureMessage(for: error)
        }
    }

    func updateLiveActivity() {
        let content = ActivityContent(
            state: liveActivityState(),
            staleDate: Date(timeIntervalSinceNow: 60)
        )
        Task {
            for activity in Activity<PayJoyActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    private func updateLiveActivityIfNeeded() {
        guard isLiveActivityActive else { return }
        updateLiveActivity()
    }

    func endLiveActivity() {
        liveActivityErrorMessage = nil
        Task {
            for activity in Activity<PayJoyActivityAttributes>.activities {
                await activity.end(ActivityContent(state: liveActivityState(), staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    }

    private func liveActivityFailureMessage(for error: Error) -> String {
        let rawMessage = String(describing: error)
        if rawMessage.contains("unsupportedTarget") {
            return "实时活动扩展未被系统识别，请重新安装后再试。"
        }
        return "开启失败：\(rawMessage)"
    }

    private func liveActivityState() -> PayJoyActivityAttributes.ContentState {
        PayJoyActivityAttributes.ContentState(
            earned: snapshot.todayEarned,
            total: snapshot.todayTotal,
            perSecond: snapshot.earnedPerSecond,
            progress: snapshot.progress,
            statusTitle: snapshot.status.title,
            endDate: workEndDate(for: now),
            remainingText: snapshot.secondsUntilOffWork.countdownText
        )
    }

    private func workEndDate(for date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = settings.workEnd.hour
        components.minute = settings.workEnd.minute
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }

    func refreshReminderAuthorization() {
        Task {
            reminderPermissionState = await reminderScheduler.authorizationState()
        }
    }

    func setRemindersEnabled(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                let granted = await reminderScheduler.requestAuthorization()
                reminderPermissionState = await reminderScheduler.authorizationState()
                var updatedPreferences = preferences
                updatedPreferences.remindersEnabled = granted
                preferences = updatedPreferences
                if granted {
                    reminderScheduler.scheduleWorkdayReminders(settings: settings)
                }
            } else {
                var updatedPreferences = preferences
                updatedPreferences.remindersEnabled = false
                preferences = updatedPreferences
                reminderScheduler.cancelWorkdayReminders()
                reminderPermissionState = await reminderScheduler.authorizationState()
            }
        }
    }
}

final class WorkReminderScheduler {
    private let center: UNUserNotificationCenter
    private let startPrefix = "payjoy.work.start"
    private let endPrefix = "payjoy.work.end"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationState() async -> ReminderPermissionState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }

    func scheduleWorkdayReminders(settings: SalarySettings) {
        cancelWorkdayReminders()

        for weekday in settings.workdays.sorted() {
            addReminder(
                id: "\(startPrefix).\(weekday)",
                title: "开薪开始",
                body: "上班时间到，每一秒都在回血。",
                time: settings.workStart,
                weekday: weekday
            )
            addReminder(
                id: "\(endPrefix).\(weekday)",
                title: "今日到账",
                body: "下班啦，今天的金币先收工。",
                time: settings.workEnd,
                weekday: weekday
            )
        }
    }

    func cancelWorkdayReminders() {
        let identifiers = (1...7).flatMap { weekday in
            ["\(startPrefix).\(weekday)", "\(endPrefix).\(weekday)"]
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func addReminder(id: String, title: String, body: String, time: WorkTime, weekday: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.current
        dateComponents.weekday = weekday
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
