import Foundation
import ActivityKit
import AuthenticationServices
import CloudKit
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
    var appleAccount: AppleAccount?
    var cloudStatusText = "尚未检查 iCloud"
    var syncMessage = "数据保存在本机"
    var isSyncing = false

    private let calculator: SalaryCalculator
    private let store: SettingsStore
    private let reminderScheduler: WorkReminderScheduler
    private let cloudKit: PayJoyCloudKitService

    init(
        calculator: SalaryCalculator = SalaryCalculator(),
        store: SettingsStore = SettingsStore(),
        reminderScheduler: WorkReminderScheduler = WorkReminderScheduler(),
        cloudKit: PayJoyCloudKitService = PayJoyCloudKitService(),
        now: Date = Date()
    ) {
        self.calculator = calculator
        self.store = store
        self.reminderScheduler = reminderScheduler
        self.cloudKit = cloudKit
        self.settings = store.load()
        self.profile = store.loadProfile()
        self.preferences = store.loadPreferences()
        self.overtimeDateKeys = store.loadOvertimeDays()
        self.appleAccount = store.loadAppleAccount()
        self.now = now
        refreshReminderAuthorization()
        Task {
            await refreshCloudStatus()
            await refreshAppleCredentialState()
        }
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
        preferences.isProUnlocked && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isLiveActivityActive: Bool {
        !Activity<PayJoyActivityAttributes>.activities.isEmpty
    }

    func startLiveActivity() {
        liveActivityErrorMessage = nil
        guard preferences.isProUnlocked else {
            liveActivityErrorMessage = "锁屏/灵动岛是 PRO 功能，开通后即可使用。"
            return
        }
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

    var isSignedInWithApple: Bool {
        appleAccount != nil
    }

    var appleAccountDetail: String {
        appleAccount?.displayName ?? "Apple ID 可用于账号登录；iCloud 同步需开通 PRO。"
    }

    var canUseCloudSync: Bool {
        preferences.isProUnlocked
    }

    func unlockProForCurrentVersion() {
        var updatedPreferences = preferences
        updatedPreferences.isProUnlocked = true
        preferences = updatedPreferences
        syncMessage = "开薪 PRO 已开通，iCloud、锁屏/灵动岛已解锁。"
    }

    func signInCompleted(credential: ASAuthorizationAppleIDCredential) {
        let formatter = PersonNameComponentsFormatter()
        let fullName = credential.fullName.map { formatter.string(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
        signInCompleted(
            userIdentifier: credential.user,
            email: credential.email,
            fullName: fullName?.isEmpty == false ? fullName : nil
        )
    }

    func signInCompleted(userIdentifier: String, email: String? = nil, fullName: String? = nil) {
        let existing = appleAccount?.userIdentifier == userIdentifier ? appleAccount : nil
        let account = AppleAccount(
            userIdentifier: userIdentifier,
            email: clean(email) ?? existing?.email,
            fullName: clean(fullName) ?? existing?.fullName,
            signedInAt: Date()
        )
        appleAccount = account
        store.saveAppleAccount(account)
        syncMessage = canUseCloudSync ? "Apple ID 已连接，可以同步到 iCloud。" : "Apple ID 已连接；开通 PRO 后可使用 iCloud 同步。"
    }

    func signInFailed(_ error: Error) {
        syncMessage = "Apple 登录失败：\(error.localizedDescription)"
    }

    func signOutAppleID() {
        appleAccount = nil
        store.clearAppleAccount()
        syncMessage = "已退出 Apple ID，本机数据仍会继续保存。"
    }

    func refreshAppleCredentialState() async {
        guard let userIdentifier = appleAccount?.userIdentifier else { return }
        let state = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, _ in
                continuation.resume(returning: state)
            }
        }

        switch state {
        case .authorized, .transferred:
            break
        case .revoked, .notFound:
            appleAccount = nil
            store.clearAppleAccount()
            syncMessage = "Apple ID 授权已失效，请重新登录。"
        @unknown default:
            break
        }
    }

    func refreshCloudStatus() async {
        do {
            let status = try await cloudKit.accountStatus()
            switch status {
            case .available:
                cloudStatusText = "iCloud 可用"
            case .noAccount:
                cloudStatusText = "未登录 iCloud"
            case .restricted:
                cloudStatusText = "iCloud 受限"
            case .couldNotDetermine:
                cloudStatusText = "无法确认 iCloud 状态"
            case .temporarilyUnavailable:
                cloudStatusText = "iCloud 暂时不可用"
            @unknown default:
                cloudStatusText = "未知 iCloud 状态"
            }
        } catch {
            cloudStatusText = "检查 iCloud 失败"
            syncMessage = error.localizedDescription
        }
    }

    func syncToCloud() async {
        guard canUseCloudSync else {
            syncMessage = "iCloud 同步是 PRO 功能，¥6 开通后可用。"
            return
        }
        guard isSignedInWithApple else {
            syncMessage = "请先连接 Apple ID，再同步到 iCloud。"
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await cloudKit.saveSnapshot(
                PayJoyCloudSnapshot(
                    settings: settings,
                    profile: profile,
                    preferences: preferences,
                    overtimeDateKeys: overtimeDateKeys,
                    updatedAt: Date()
                )
            )
            syncMessage = "已同步到 iCloud。"
        } catch {
            syncMessage = "同步失败：\(error.localizedDescription)"
        }
    }

    func restoreFromCloud() async {
        guard canUseCloudSync else {
            syncMessage = "iCloud 恢复是 PRO 功能，¥6 开通后可用。"
            return
        }
        guard isSignedInWithApple else {
            syncMessage = "请先连接 Apple ID，再从 iCloud 恢复。"
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            guard let snapshot = try await cloudKit.fetchSnapshot() else {
                syncMessage = "iCloud 里暂时没有开薪数据。"
                return
            }
            settings = snapshot.settings
            profile = snapshot.profile
            preferences = snapshot.preferences
            overtimeDateKeys = snapshot.overtimeDateKeys
            syncMessage = "已从 iCloud 恢复数据。"
        } catch {
            syncMessage = "恢复失败：\(error.localizedDescription)"
        }
    }

    func deleteAccountAndLocalData() async {
        let cloudDeletionError: String? = await {
            guard isSignedInWithApple else { return nil }
            do {
                try await cloudKit.deleteAllPrivateData()
                return nil
            } catch {
                return error.localizedDescription
            }
        }()

        endLiveActivity()
        reminderScheduler.cancelWorkdayReminders()
        store.clearAllLocalData()
        appleAccount = nil
        settings = .defaultValue
        profile = .defaultValue
        preferences = .defaultValue
        overtimeDateKeys = []
        selectedTab = .home
        syncMessage = cloudDeletionError.map { "账号和本机数据已删除，iCloud 删除失败：\($0)" } ?? "账号、本机与 iCloud 数据已删除。"
    }

    private func clean(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
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
