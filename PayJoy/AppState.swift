import Foundation
import ActivityKit
import AuthenticationServices
import CloudKit
import CryptoKit
import Observation
import StoreKit
import UIKit
import UserNotifications
import WidgetKit

@MainActor
@Observable
final class AppState {
    var settings: SalarySettings {
        didSet {
            store.save(settings)
            refreshCurrentSalaryDayRecord(refreshSettingsSnapshot: true)
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            if preferences.remindersEnabled {
                reminderScheduler.scheduleWorkdayReminders(settings: settings)
            }
            if preferences.lunchRemindersEnabled, canUseLunchReminders {
                reminderScheduler.scheduleLunchReminders(settings: settings)
            } else if preferences.lunchRemindersEnabled {
                setLunchRemindersEnabled(false)
            }
            scheduleCloudSyncIfNeeded()
        }
    }
    var profile: UserProfile {
        didSet {
            store.saveProfile(profile)
            scheduleCloudSyncIfNeeded()
        }
    }
    var preferences: AppPreferences {
        didSet {
            store.savePreferences(preferences)
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var overtimeDateKeys: Set<String> {
        didSet {
            store.saveOvertimeDays(overtimeDateKeys)
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var overtimeRecords: [OvertimeRecord] {
        didSet {
            store.saveOvertimeRecords(overtimeRecords)
            scheduleCloudSyncIfNeeded()
        }
    }
    var earlyLeaveDateKeys: Set<String> {
        didSet {
            store.saveEarlyLeaveDays(earlyLeaveDateKeys)
            refreshCurrentSalaryDayRecord()
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var salaryDayRecords: [SalaryDayRecord] {
        didSet {
            guard !Self.isScreenshotMode else { return }
            store.saveSalaryDayRecords(salaryDayRecords)
            scheduleCloudSyncIfNeeded()
        }
    }
    var now: Date
    var selectedTab: AppTab = .home
    var isTabBarHidden = false
    var reminderPermissionState: ReminderPermissionState = .unknown
    var liveActivityErrorMessage: String?
    var appleAccount: AppleAccount?
    var cloudStatusKey = "尚未检查 iCloud"
    var syncMessage = L10n.t("数据保存在本机")
    var isSyncing = false
    var isAppLocked = false
    var isScenePrivacyShieldVisible = false
    var appLockMessage: String?
    var suppressesPrivacyShieldForSystemAuth = false
    var proPriceText: String
    var proPurchaseMessage: String?
    var appIconMessage: String?
    var isLoadingProProduct = false
    var isPurchasingPro = false

    private let calculator: SalaryCalculator
    private let store: SettingsStore
    private let reminderScheduler: WorkReminderScheduler
    private let cloudKit: PayJoyCloudKitService
    private let storeKit: StoreKitService
    @ObservationIgnored private var pendingCloudSyncTask: Task<Void, Never>?
    @ObservationIgnored private var pendingWidgetRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var isApplyingCloudSnapshot = false
    @ObservationIgnored private var lastSalaryRecordRefreshMinute: Int?

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
        self.storeKit = StoreKitService()
        let loadedSettings = store.load()
        let loadedOvertimeDateKeys = store.loadOvertimeDays()
        let savedOvertimeRecords = store.loadOvertimeRecords()

        let screenshotMode = Self.isScreenshotMode
        self.settings = screenshotMode ? Self.screenshotSettings : loadedSettings
        self.profile = screenshotMode ? Self.screenshotProfile : store.loadProfile()
        self.preferences = screenshotMode ? Self.screenshotPreferences : store.loadPreferences()
        self.overtimeDateKeys = loadedOvertimeDateKeys
        self.overtimeRecords = screenshotMode ? Self.screenshotOvertimeRecords : (savedOvertimeRecords.isEmpty ? Self.migratedOvertimeRecords(from: loadedOvertimeDateKeys, settings: loadedSettings) : savedOvertimeRecords)
        self.earlyLeaveDateKeys = store.loadEarlyLeaveDays()
        self.salaryDayRecords = screenshotMode ? Self.screenshotSalaryDayRecords : store.loadSalaryDayRecords()
        self.appleAccount = store.loadAppleAccount()
        self.now = screenshotMode ? Self.screenshotNow : now
        self.proPriceText = Self.fallbackProPriceText
        guard !screenshotMode else {
            cloudStatusKey = "iCloud 可用"
            syncMessage = L10n.t("数据保存在本机")
            return
        }
        enforceProFeatureAvailability()
        synchronizeAppIconPreference()
        refreshReminderAuthorization()
        startTransactionUpdatesListener()
        refreshCurrentSalaryDayRecord()
        Task {
            await loadProProduct()
            await refreshProEntitlement()
            await refreshCloudStatus()
            await refreshAppleCredentialState()
        }
    }

    var snapshot: EarningsSnapshot {
        calculator.snapshot(for: now, settings: settings, earlyLeaveDateKeys: earlyLeaveDateKeys)
    }

    var hasEffectivePro: Bool {
        preferences.isProUnlocked || Self.unlocksProForLocalDebug
    }

    var cloudStatusText: String {
        L10n.t(cloudStatusKey)
    }

    func periodEarnings(for period: StatsPeriod) -> PeriodEarnings {
        calculator.periodEarnings(for: period, date: now, settings: settings, earlyLeaveDateKeys: earlyLeaveDateKeys)
    }

    func periodBreakdown(for period: StatsPeriod) -> PeriodBreakdown {
        calculator.periodBreakdown(for: period, date: now, settings: settings, earlyLeaveDateKeys: earlyLeaveDateKeys)
    }

    func overtimeSummary(forMonthContaining date: Date) -> OvertimeSummary {
        calculator.overtimeSummary(in: .month, date: date, now: now, overtimeRecords: overtimeRecords)
    }

    func overtimeSummary(forDayContaining date: Date) -> OvertimeSummary {
        calculator.overtimeSummary(in: .day, date: date, now: now, overtimeRecords: overtimeRecords)
    }

    var activeOvertimeRecord: OvertimeRecord? {
        overtimeRecords.first { $0.isActive }
    }

    var canStartOvertime: Bool {
        activeOvertimeRecord == nil && (now >= workEndDate(for: now) || !calculator.isRegularWorkday(now, settings: settings))
    }

    var defaultOvertimeStartDate: Date {
        now
    }

    var defaultOvertimeEndDate: Date {
        max(now, defaultOvertimeStartDate.addingTimeInterval(30 * 60))
    }

    var activeOvertimeDuration: TimeInterval {
        activeOvertimeRecord?.duration(until: now) ?? 0
    }

    var todayOvertimeDuration: TimeInterval {
        overtimeSummary(forDayContaining: now).totalSeconds
    }

    var canLeaveWorkEarlyToday: Bool {
        [.working, .lunchBreak].contains(snapshot.status) && !earlyLeaveDateKeys.contains(todayDateKey)
    }

    var hasLeftWorkEarlyToday: Bool {
        earlyLeaveDateKeys.contains(todayDateKey)
    }

    var todayDateKey: String {
        calculator.dateKey(for: now)
    }

    func updateClock() {
        now = Date()
        let minute = Int(now.timeIntervalSince1970 / 60)
        if lastSalaryRecordRefreshMinute != minute {
            lastSalaryRecordRefreshMinute = minute
            refreshCurrentSalaryDayRecord()
        }
        if isLiveActivityActive, Int(now.timeIntervalSince1970) % 15 == 0 {
            updateLiveActivity()
        }
    }

    func startOvertimeNow() {
        startOvertime(at: now)
    }

    func startOvertime(at startAt: Date) {
        guard activeOvertimeRecord == nil else { return }
        overtimeRecords.insert(OvertimeRecord(startAt: startAt, endAt: nil, createdAt: now), at: 0)
    }

    func stopActiveOvertime() {
        stopActiveOvertime(at: now)
    }

    func stopActiveOvertime(at endAt: Date) {
        guard let index = overtimeRecords.firstIndex(where: { $0.isActive }) else { return }
        var updatedRecords = overtimeRecords
        let startAt = updatedRecords[index].startAt
        updatedRecords[index].endAt = max(endAt, startAt)
        updatedRecords.sort { $0.startAt > $1.startAt }
        overtimeRecords = updatedRecords
    }

    func saveOvertimeRecord(startAt: Date, endAt: Date) {
        let normalizedEnd = max(endAt, startAt)
        var updatedRecords = overtimeRecords
        updatedRecords.insert(OvertimeRecord(startAt: startAt, endAt: normalizedEnd, createdAt: now), at: 0)
        updatedRecords.sort { $0.startAt > $1.startAt }
        overtimeRecords = updatedRecords
    }

    func updateOvertimeRecord(id: String, startAt: Date, endAt: Date?) {
        guard let index = overtimeRecords.firstIndex(where: { $0.id == id }) else { return }
        var updatedRecords = overtimeRecords
        updatedRecords[index].startAt = startAt
        updatedRecords[index].endAt = endAt.map { max($0, startAt) }
        updatedRecords.sort { $0.startAt > $1.startAt }
        overtimeRecords = updatedRecords
    }

    func removeOvertimeRecord(id: String) {
        overtimeRecords.removeAll { $0.id == id }
    }

    func leaveWorkEarlyToday() {
        guard canLeaveWorkEarlyToday else { return }
        earlyLeaveDateKeys.insert(todayDateKey)
    }

    func cancelLeaveWorkEarlyToday() {
        earlyLeaveDateKeys.remove(todayDateKey)
    }

    func salaryCalendarDay(for date: Date) -> SalaryCalendarDay {
        calculator.salaryCalendarDay(
            for: date,
            now: now,
            settings: settings,
            record: salaryDayRecords.first { $0.dateKey == calculator.dateKey(for: date) },
            completedDateKeys: earlyLeaveDateKeys
        )
    }

    func salaryMonthSummary(for month: Date) -> SalaryMonthSummary {
        calculator.salaryMonthSummary(
            for: month,
            now: now,
            settings: settings,
            records: salaryDayRecords,
            completedDateKeys: earlyLeaveDateKeys
        )
    }

    func defaultSalaryDayKind(for date: Date) -> SalaryDayKind {
        calculator.defaultSalaryDayKind(for: date, settings: settings)
    }

    func updateSalaryDay(date: Date, kind: SalaryDayKind, note: String) {
        let dateKey = calculator.dateKey(for: date)
        let existing = salaryDayRecords.first { $0.dateKey == dateKey }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: now)
        let isToday = startOfDay == today
        let isEstimated = existing?.isEstimated ?? !isToday
        let settingsSnapshot = existing?.settingsSnapshot ?? settings
        let scheduledAmount = (kind == .normal || kind == .paidLeave)
            ? calculator.scheduledSalaryAmount(for: date, settings: settingsSnapshot)
            : 0
        let previewRecord = SalaryDayRecord(
            dateKey: dateKey,
            kind: kind,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            settingsSnapshot: settingsSnapshot,
            scheduledAmount: scheduledAmount,
            earnedAmount: 0,
            isEstimated: isEstimated,
            updatedAt: now
        )
        let day = calculator.salaryCalendarDay(
            for: date,
            now: now,
            settings: settings,
            record: previewRecord,
            completedDateKeys: earlyLeaveDateKeys
        )
        upsertSalaryDayRecord(
            SalaryDayRecord(
                dateKey: dateKey,
                kind: kind,
                note: previewRecord.note,
                settingsSnapshot: settingsSnapshot,
                scheduledAmount: scheduledAmount,
                earnedAmount: day.earnedAmount,
                isEstimated: isEstimated,
                updatedAt: now
            )
        )
    }

    func restoreSalaryDaySchedule(for date: Date) {
        updateSalaryDay(
            date: date,
            kind: calculator.defaultSalaryDayKind(for: date, settings: settings),
            note: ""
        )
    }

    private func refreshCurrentSalaryDayRecord(refreshSettingsSnapshot: Bool = false) {
        guard !isApplyingCloudSnapshot else { return }
        let today = Calendar.current.startOfDay(for: now)
        let todayKey = calculator.dateKey(for: today)
        var updatedRecords = salaryDayRecords.map { record in
            guard let date = date(fromKey: record.dateKey),
                  date < today,
                  !record.isEstimated,
                  record.earnedAmount != record.scheduledAmount else { return record }
            var finalized = record
            finalized.earnedAmount = finalized.scheduledAmount
            finalized.updatedAt = now
            return finalized
        }

        let existing = updatedRecords.first { $0.dateKey == todayKey }
        let settingsSnapshot = refreshSettingsSnapshot || existing == nil || existing?.isEstimated == true
            ? settings
            : existing?.settingsSnapshot ?? settings
        let kind = existing?.kind ?? calculator.defaultSalaryDayKind(for: today, settings: settingsSnapshot)
        let scheduledAmount = (kind == .normal || kind == .paidLeave)
            ? calculator.scheduledSalaryAmount(for: today, settings: settingsSnapshot)
            : 0
        let previewRecord = SalaryDayRecord(
            dateKey: todayKey,
            kind: kind,
            note: existing?.note ?? "",
            settingsSnapshot: settingsSnapshot,
            scheduledAmount: scheduledAmount,
            earnedAmount: existing?.earnedAmount ?? 0,
            isEstimated: false,
            updatedAt: now
        )
        let day = calculator.salaryCalendarDay(
            for: today,
            now: now,
            settings: settings,
            record: previewRecord,
            completedDateKeys: earlyLeaveDateKeys
        )
        let refreshedRecord = SalaryDayRecord(
            dateKey: todayKey,
            kind: kind,
            note: previewRecord.note,
            settingsSnapshot: settingsSnapshot,
            scheduledAmount: scheduledAmount,
            earnedAmount: day.earnedAmount,
            isEstimated: false,
            updatedAt: now
        )

        updatedRecords.removeAll { $0.dateKey == todayKey }
        updatedRecords.append(refreshedRecord)
        updatedRecords.sort { $0.dateKey > $1.dateKey }
        if updatedRecords != salaryDayRecords {
            salaryDayRecords = updatedRecords
        }
    }

    private func upsertSalaryDayRecord(_ record: SalaryDayRecord) {
        var updatedRecords = salaryDayRecords
        updatedRecords.removeAll { $0.dateKey == record.dateKey }
        updatedRecords.append(record)
        updatedRecords.sort { $0.dateKey > $1.dateKey }
        salaryDayRecords = updatedRecords
    }

    private func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
            .map { Calendar.current.startOfDay(for: $0) }
    }

    func refreshWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: "PayJoyEarningsWidgetV3")
        WidgetCenter.shared.reloadAllTimelines()
        pendingWidgetRefreshTask?.cancel()
        pendingWidgetRefreshTask = Task { @MainActor in
            for delay in [250_000_000, 1_000_000_000] {
                try? await Task.sleep(nanoseconds: UInt64(delay))
                guard !Task.isCancelled else { return }
                WidgetCenter.shared.reloadTimelines(ofKind: "PayJoyEarningsWidgetV3")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    var isLiveActivityAvailable: Bool {
        hasEffectivePro && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isLiveActivityActive: Bool {
        !Activity<PayJoyActivityAttributes>.activities.isEmpty
    }

    func startLiveActivity() {
        liveActivityErrorMessage = nil
        guard hasEffectivePro else {
            liveActivityErrorMessage = L10n.t("锁屏/灵动岛是 PRO 功能，开通后即可使用。")
            return
        }
        guard isLiveActivityAvailable else { return }
        if isLiveActivityActive {
            updateLiveActivity()
            return
        }

        do {
            _ = try Activity.request(
                attributes: PayJoyActivityAttributes(title: L10n.t("开薪中")),
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
            return L10n.t("实时活动扩展未被系统识别，请重新安装后再试。")
        }
        return "\(L10n.t("开启失败"))：\(rawMessage)"
    }

    private func liveActivityState() -> PayJoyActivityAttributes.ContentState {
        PayJoyActivityAttributes.ContentState(
            earned: snapshot.todayEarned,
            total: snapshot.todayTotal,
            perSecond: snapshot.earnedPerSecond,
            progress: snapshot.progress,
            statusTitle: snapshot.status.title,
            endDate: workEndDate(for: now),
            remainingText: snapshot.secondsUntilOffWork.countdownText,
            hidesSensitiveAmounts: preferences.hideSensitiveAmounts,
            currencySymbol: settings.currencySymbol,
            visualTheme: preferences.selectedTheme
        )
    }

    private func workEndDate(for date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = settings.workEnd.hour
        components.minute = settings.workEnd.minute
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }

    private static func migratedOvertimeRecords(from dateKeys: Set<String>, settings: SalarySettings) -> [OvertimeRecord] {
        dateKeys.compactMap { key -> OvertimeRecord? in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            var startComponents = DateComponents()
            startComponents.calendar = Calendar.current
            startComponents.year = parts[0]
            startComponents.month = parts[1]
            startComponents.day = parts[2]
            startComponents.hour = settings.workStart.hour
            startComponents.minute = settings.workStart.minute
            startComponents.second = 0
            var endComponents = startComponents
            endComponents.hour = settings.workEnd.hour
            endComponents.minute = settings.workEnd.minute
            guard let startAt = startComponents.date,
                  let endAt = endComponents.date,
                  endAt > startAt else {
                return nil
            }
            return OvertimeRecord(id: key, startAt: startAt, endAt: endAt, createdAt: endAt)
        }
        .sorted { $0.startAt > $1.startAt }
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

    var canUseLunchReminders: Bool {
        hasEffectivePro && settings.deductLunch
    }

    func setLunchRemindersEnabled(_ isEnabled: Bool) {
        Task {
            guard isEnabled else {
                var updatedPreferences = preferences
                updatedPreferences.lunchRemindersEnabled = false
                preferences = updatedPreferences
                reminderScheduler.cancelLunchReminders()
                reminderPermissionState = await reminderScheduler.authorizationState()
                return
            }

            guard canUseLunchReminders else {
                var updatedPreferences = preferences
                updatedPreferences.lunchRemindersEnabled = false
                preferences = updatedPreferences
                reminderScheduler.cancelLunchReminders()
                syncMessage = L10n.t("午休提醒需要开通 PRO，并在工作时间设置里开启午休时间。")
                return
            }

            let granted = await reminderScheduler.requestAuthorization()
            reminderPermissionState = await reminderScheduler.authorizationState()
            var updatedPreferences = preferences
            updatedPreferences.lunchRemindersEnabled = granted
            preferences = updatedPreferences
            if granted {
                reminderScheduler.scheduleLunchReminders(settings: settings)
            }
        }
    }

    var isSignedInWithApple: Bool {
        appleAccount != nil
    }

    var appleAccountDetail: String {
        appleAccount?.displayName ?? L10n.t("Apple ID 可用于账号登录；iCloud 同步需开通 PRO。")
    }

    var canUseCloudSync: Bool {
        hasEffectivePro
    }

    func setAppIconChoice(_ icon: AppIconChoice) {
        appIconMessage = nil

        guard hasEffectivePro || icon == .classic else {
            appIconMessage = L10n.t("App 图标是 PRO 功能，开通后可切换。")
            return
        }

        guard UIApplication.shared.supportsAlternateIcons else {
            appIconMessage = L10n.t("当前系统不支持切换 App 图标。")
            return
        }

        guard preferences.selectedAppIcon != icon else {
            appIconMessage = "\(L10n.t("已使用"))\(icon.title)。"
            return
        }

        applyAppIconChoice(icon)
    }

    private func applyAppIconChoice(_ icon: AppIconChoice) {
        #if targetEnvironment(simulator)
        var updatedPreferences = preferences
        updatedPreferences.selectedAppIcon = icon
        preferences = updatedPreferences
        appIconMessage = L10n.t("模拟器仅预览 App 图标，真机安装后会切换系统图标。")
        #else
        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("Failed to switch app icon: \(error.localizedDescription)")
                    self.appIconMessage = L10n.t("图标切换失败，请稍后再试。")
                    self.synchronizeAppIconPreference()
                    return
                }

                var updatedPreferences = self.preferences
                updatedPreferences.selectedAppIcon = icon
                self.preferences = updatedPreferences
                self.appIconMessage = "\(L10n.t("已切换为"))\(icon.title)。"
            }
        }
        #endif
    }

    private func synchronizeAppIconPreference() {
        let currentIcon = AppIconChoice.choice(forAlternateIconName: UIApplication.shared.alternateIconName)
        guard hasEffectivePro else {
            guard preferences.selectedAppIcon != .classic else { return }
            var updatedPreferences = preferences
            updatedPreferences.selectedAppIcon = .classic
            preferences = updatedPreferences
            resetAppIconToClassicIfNeeded()
            return
        }
        guard preferences.selectedAppIcon != currentIcon else { return }
        var updatedPreferences = preferences
        updatedPreferences.selectedAppIcon = currentIcon
        preferences = updatedPreferences
    }

    static var fallbackProPriceText: String {
        "¥6"
    }

    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_MODE"] == "1" ||
        ProcessInfo.processInfo.arguments.contains("PAYJOY_SCREENSHOT_MODE")
    }

    private static var screenshotNow: Date {
        let calendarScreen = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] == "calendar"
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Shanghai")
        components.year = 2026
        components.month = calendarScreen ? 7 : 6
        components.day = calendarScreen ? 14 : 3
        components.hour = 15
        components.minute = 24
        return components.date ?? Date()
    }

    private static var screenshotSettings: SalarySettings {
        return SalarySettings(
            salaryType: .monthly,
            salaryAmount: 18_000,
            currencySymbol: "¥",
            workStart: WorkTime(hour: 9, minute: 30),
            workEnd: WorkTime(hour: 18, minute: 30),
            deductLunch: false,
            lunchStart: .defaultLunchStart,
            lunchEnd: .defaultLunchEnd,
            monthlyPaidDays: 21.75,
            workdays: Workday.defaultWeekdays
        )
    }

    private static var screenshotProfile: UserProfile {
        UserProfile(nickname: "打工人小开", motto: "上班赚钱，下班快乐，今天也要开薪！")
    }

    private static var screenshotPreferences: AppPreferences {
        let selectedTheme = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_THEME"]
            .flatMap(AppVisualTheme.init(rawValue:)) ?? .classic

        return AppPreferences(
            appLanguage: .zhHans,
            selectedTheme: selectedTheme,
            selectedAppIcon: .classic,
            remindersEnabled: true,
            lunchRemindersEnabled: false,
            showCoinRain: true,
            reduceMotion: true,
            showDecimalCents: true,
            isProUnlocked: true,
            hideSensitiveAmounts: ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] == "privacy",
            appLockEnabled: false,
            appLockPasscodeSalt: nil,
            appLockPasscodeHash: nil
        )
    }

    private static var screenshotOvertimeRecords: [OvertimeRecord] {
        let calendar = Calendar(identifier: .gregorian)
        let base = screenshotNow
        func date(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let shifted = calendar.date(byAdding: .day, value: dayOffset, to: base) ?? base
            var components = calendar.dateComponents([.year, .month, .day], from: shifted)
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components) ?? shifted
        }
        if ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] == "calendar" {
            return [
                OvertimeRecord(startAt: date(dayOffset: 0, hour: 12, minute: 54), endAt: date(dayOffset: 0, hour: 15, minute: 24), createdAt: date(dayOffset: 0, hour: 12, minute: 54))
            ]
        }

        return [
            OvertimeRecord(startAt: date(dayOffset: 0, hour: 18, minute: 45), endAt: nil, createdAt: date(dayOffset: 0, hour: 18, minute: 45)),
            OvertimeRecord(startAt: date(dayOffset: -2, hour: 19), endAt: date(dayOffset: -2, hour: 21, minute: 20), createdAt: date(dayOffset: -2, hour: 19)),
            OvertimeRecord(startAt: date(dayOffset: -5, hour: 18, minute: 40), endAt: date(dayOffset: -5, hour: 20, minute: 10), createdAt: date(dayOffset: -5, hour: 18, minute: 40))
        ]
    }

    private static var screenshotSalaryDayRecords: [SalaryDayRecord] {
        let calendar = Calendar(identifier: .gregorian)
        let settings = screenshotSettings
        let calculator = SalaryCalculator(calendar: calendar)

        func date(day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: 18, minute: 30)) ?? screenshotNow
        }

        let specialDays: [Int: (SalaryDayKind, String)] = [
            6: (.paidLeave, ""),
            9: (.unpaidLeave, ""),
            11: (.rest, ""),
            14: (.normal, "项目加班")
        ]

        return (1...14).map { day in
            let value = date(day: day)
            let kind = specialDays[day]?.0 ?? calculator.defaultSalaryDayKind(for: value, settings: settings)
            let amount = (kind == .normal || kind == .paidLeave)
                ? calculator.scheduledSalaryAmount(for: value, settings: settings)
                : 0
            return SalaryDayRecord(
                dateKey: calculator.dateKey(for: value),
                kind: kind,
                note: specialDays[day]?.1 ?? "",
                settingsSnapshot: settings,
                scheduledAmount: amount,
                earnedAmount: amount,
                isEstimated: false,
                updatedAt: value
            )
        }
    }

    var canPurchasePro: Bool {
        !hasEffectivePro && !isPurchasingPro && !isLoadingProProduct
    }

    func loadProProduct() async {
        guard !isLoadingProProduct else { return }
        isLoadingProProduct = true
        defer { isLoadingProProduct = false }

        do {
            let product = try await storeKit.loadProProduct()
            proPriceText = product.displayPrice
            proPurchaseMessage = nil
        } catch {
            proPriceText = Self.fallbackProPriceText
            print("Failed to load PRO product: \(error.localizedDescription)")
            proPurchaseMessage = L10n.t("PRO 商品暂时无法加载，请稍后再试。")
        }
    }

    func purchasePro() async {
        guard !hasEffectivePro, !isPurchasingPro else { return }
        isPurchasingPro = true
        proPurchaseMessage = nil
        defer { isPurchasingPro = false }

        do {
            let result = try await storeKit.purchasePro()
            switch result {
            case .purchased:
                await refreshProEntitlement(successMessage: L10n.t("开薪 PRO 已开通，iCloud、锁屏/灵动岛、密码保护和午休设置已解锁。"))
            case .pending:
                proPurchaseMessage = L10n.t("购买正在等待 Apple 处理，完成后会自动解锁 PRO。")
            case .cancelled:
                proPurchaseMessage = L10n.t("已取消购买。")
            }
        } catch {
            print("Failed to purchase PRO: \(error.localizedDescription)")
            proPurchaseMessage = L10n.t("购买失败，请稍后再试。")
        }
    }

    func restoreProPurchases() async {
        guard !isPurchasingPro else { return }
        isPurchasingPro = true
        proPurchaseMessage = nil
        defer { isPurchasingPro = false }

        do {
            try await storeKit.restorePurchases()
            await refreshProEntitlement(successMessage: L10n.t("已恢复 PRO 购买。"), missingMessage: L10n.t("没有找到可恢复的 PRO 购买记录。"))
        } catch {
            print("Failed to restore PRO purchase: \(error.localizedDescription)")
            proPurchaseMessage = L10n.t("恢复购买失败，请稍后再试。")
        }
    }

    func refreshProEntitlement(successMessage: String? = nil, missingMessage: String? = nil) async {
        if Self.unlocksProForLocalDebug {
            return
        }

        let hasPro = await storeKit.hasProEntitlement()
        setProUnlocked(hasPro)

        if hasPro {
            if let successMessage {
                proPurchaseMessage = successMessage
                syncMessage = successMessage
            }
        } else if let missingMessage {
            proPurchaseMessage = missingMessage
        }
    }

    func togglePrivacyMode() {
        var updatedPreferences = preferences
        updatedPreferences.hideSensitiveAmounts.toggle()
        preferences = updatedPreferences
    }

    var canUseAppLock: Bool {
        hasEffectivePro
    }

    var canUseLunchBreakSettings: Bool {
        hasEffectivePro
    }

    var isAppLockConfigured: Bool {
        preferences.appLockPasscodeSalt?.isEmpty == false && preferences.appLockPasscodeHash?.isEmpty == false
    }

    var isAppLockActive: Bool {
        canUseAppLock && preferences.appLockEnabled && isAppLockConfigured
    }

    var shouldShowPrivacyShield: Bool {
        isScenePrivacyShieldVisible || isAppLocked
    }

    func prepareAppLockOnLaunch() {
        guard isAppLockActive else { return }
        appLockMessage = nil
        isAppLocked = true
    }

    func applicationWillResignActive() {
        guard !suppressesPrivacyShieldForSystemAuth else { return }
        isScenePrivacyShieldVisible = true
        if isAppLockActive {
            appLockMessage = nil
            isAppLocked = true
        }
    }

    func applicationDidBecomeActive() {
        suppressesPrivacyShieldForSystemAuth = false
        isScenePrivacyShieldVisible = false
        if !isAppLockActive {
            isAppLocked = false
        }
    }

    func setAppLockPasscode(_ passcode: String) {
        guard canUseAppLock, isValidPasscode(passcode) else { return }
        let salt = UUID().uuidString
        var updatedPreferences = preferences
        updatedPreferences.appLockPasscodeSalt = salt
        updatedPreferences.appLockPasscodeHash = passcodeHash(passcode, salt: salt)
        updatedPreferences.appLockEnabled = true
        preferences = updatedPreferences
        isAppLocked = false
        appLockMessage = nil
    }

    func disableAppLock() {
        var updatedPreferences = preferences
        updatedPreferences.appLockEnabled = false
        updatedPreferences.appLockPasscodeSalt = nil
        updatedPreferences.appLockPasscodeHash = nil
        preferences = updatedPreferences
        isAppLocked = false
        appLockMessage = nil
    }

    func unlockApp(with passcode: String) -> Bool {
        guard isAppLockActive,
              let salt = preferences.appLockPasscodeSalt,
              let storedHash = preferences.appLockPasscodeHash else {
            isAppLocked = false
            return true
        }
        guard isValidPasscode(passcode),
              passcodeHash(passcode, salt: salt) == storedHash else {
            appLockMessage = L10n.t("密码不对，再试一次。")
            return false
        }
        appLockMessage = nil
        isAppLocked = false
        return true
    }

    func requireProFeature(_ message: String = L10n.t("这是 PRO 功能，开通后即可使用。")) {
        syncMessage = message
    }

    func sanitizeSettingsForCurrentPlan(_ settings: SalarySettings) -> SalarySettings {
        guard !canUseLunchBreakSettings, settings.deductLunch else { return settings }
        var sanitized = settings
        sanitized.deductLunch = false
        return sanitized
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
        suppressesPrivacyShieldForSystemAuth = false
        isScenePrivacyShieldVisible = false
        let existing = appleAccount?.userIdentifier == userIdentifier ? appleAccount : nil
        let account = AppleAccount(
            userIdentifier: userIdentifier,
            email: clean(email) ?? existing?.email,
            fullName: clean(fullName) ?? existing?.fullName,
            signedInAt: Date()
        )
        appleAccount = account
        store.saveAppleAccount(account)
        syncMessage = canUseCloudSync ? L10n.t("Apple ID 已连接，后续修改会自动同步到 iCloud。") : L10n.t("Apple ID 已连接；开通 PRO 后可自动同步。")
        scheduleCloudSyncIfNeeded()
    }

    func signInFailed(_ error: Error) {
        suppressesPrivacyShieldForSystemAuth = false
        isScenePrivacyShieldVisible = false
        syncMessage = L10n.t("Apple 登录失败，请稍后再试。")
    }

    func signOutAppleID() {
        pendingCloudSyncTask?.cancel()
        appleAccount = nil
        store.clearAppleAccount()
        syncMessage = L10n.t("已退出 Apple ID，本机数据仍会继续保存。")
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
            pendingCloudSyncTask?.cancel()
            appleAccount = nil
            store.clearAppleAccount()
            syncMessage = L10n.t("Apple ID 授权已失效，请重新登录。")
        @unknown default:
            break
        }
    }

    func refreshCloudStatus() async {
        do {
            let status = try await cloudKit.accountStatus()
            switch status {
            case .available:
                cloudStatusKey = "iCloud 可用"
            case .noAccount:
                cloudStatusKey = "未登录 iCloud"
            case .restricted:
                cloudStatusKey = "iCloud 受限"
            case .couldNotDetermine:
                cloudStatusKey = "无法确认 iCloud 状态"
            case .temporarilyUnavailable:
                cloudStatusKey = "iCloud 暂时不可用"
            @unknown default:
                cloudStatusKey = "未知 iCloud 状态"
            }
        } catch {
            cloudStatusKey = "检查 iCloud 失败"
            syncMessage = cloudFailureMessage(for: error, fallbackKey: "检查 iCloud 失败，请稍后再试。")
        }
    }

    func syncToCloud() async {
        guard canUseCloudSync else {
            syncMessage = L10n.t("iCloud 同步是 PRO 功能，开通后可用。")
            return
        }
        guard isSignedInWithApple else {
            syncMessage = L10n.t("请先连接 Apple ID，再同步到 iCloud。")
            return
        }

        await performCloudSync(isAutomatic: false)
    }

    private func scheduleCloudSyncIfNeeded() {
        pendingCloudSyncTask?.cancel()
        guard !isApplyingCloudSnapshot, canUseCloudSync, isSignedInWithApple else { return }

        pendingCloudSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled else { return }
            await self?.performCloudSync(isAutomatic: true)
        }
    }

    private func performCloudSync(isAutomatic: Bool) async {
        guard canUseCloudSync, isSignedInWithApple else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await cloudKit.saveSnapshot(
                PayJoyCloudSnapshot(
                    settings: settings,
                    profile: profile,
                    preferences: preferences,
                    overtimeDateKeys: overtimeDateKeys,
                    overtimeRecords: overtimeRecords,
                    earlyLeaveDateKeys: earlyLeaveDateKeys,
                    salaryDayRecords: salaryDayRecords,
                    updatedAt: Date()
                )
            )
            syncMessage = isAutomatic ? L10n.t("已自动同步到 iCloud。") : L10n.t("已同步到 iCloud。")
        } catch {
            syncMessage = cloudFailureMessage(
                for: error,
                fallbackKey: isAutomatic ? "自动同步失败，请稍后再试。" : "同步失败，请稍后再试。"
            )
        }
    }

    func restoreFromCloud() async {
        guard canUseCloudSync else {
            syncMessage = L10n.t("iCloud 恢复是 PRO 功能，开通后可用。")
            return
        }
        guard isSignedInWithApple else {
            syncMessage = L10n.t("请先连接 Apple ID，再从 iCloud 恢复。")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            guard let snapshot = try await cloudKit.fetchSnapshot() else {
                syncMessage = L10n.t("iCloud 里暂时没有开薪数据。")
                return
            }
            pendingCloudSyncTask?.cancel()
            isApplyingCloudSnapshot = true
            settings = snapshot.settings
            profile = snapshot.profile
            preferences = snapshot.preferences
            enforceProFeatureAvailability()
            overtimeDateKeys = snapshot.overtimeDateKeys
            overtimeRecords = snapshot.overtimeRecords.isEmpty ? Self.migratedOvertimeRecords(from: snapshot.overtimeDateKeys, settings: snapshot.settings) : snapshot.overtimeRecords
            earlyLeaveDateKeys = snapshot.earlyLeaveDateKeys
            salaryDayRecords = snapshot.salaryDayRecords
            isApplyingCloudSnapshot = false
            refreshCurrentSalaryDayRecord()
            syncMessage = L10n.t("已从 iCloud 恢复数据。")
        } catch {
            isApplyingCloudSnapshot = false
            syncMessage = cloudFailureMessage(for: error, fallbackKey: "恢复失败，请稍后再试。")
        }
    }

    func deleteAccountAndLocalData() async {
        let cloudDeletionError: String? = await {
            guard isSignedInWithApple else { return nil }
            do {
                try await cloudKit.deleteAllPrivateData()
                return nil
            } catch {
                return cloudFailureMessage(for: error, fallbackKey: "iCloud 删除失败，请稍后再试。")
            }
        }()

        endLiveActivity()
        reminderScheduler.cancelWorkdayReminders()
        reminderScheduler.cancelLunchReminders()
        store.clearAllLocalData()
        pendingCloudSyncTask?.cancel()
        isApplyingCloudSnapshot = true
        appleAccount = nil
        settings = .defaultValue
        profile = .defaultValue
        preferences = .defaultValue
        overtimeDateKeys = []
        overtimeRecords = []
        earlyLeaveDateKeys = []
        salaryDayRecords = []
        isApplyingCloudSnapshot = false
        selectedTab = .home
        isAppLocked = false
        isScenePrivacyShieldVisible = false
        appLockMessage = nil
        syncMessage = cloudDeletionError.map { "\(L10n.t("账号和本机数据已删除，iCloud 删除失败"))：\($0)" } ?? L10n.t("账号、本机与 iCloud 数据已删除。")
    }

    private func cloudFailureMessage(for error: Error, fallbackKey: String) -> String {
        if error is PayJoyCloudFallbackError {
            return L10n.t("iCloud 同步未完成，请确认系统 iCloud 云盘与开薪的 iCloud 权限已开启。")
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain,
           let code = CKError.Code(rawValue: nsError.code) {
            switch code {
            case .notAuthenticated:
                return L10n.t("未登录 iCloud，请先在系统设置中登录。")
            case .networkUnavailable, .networkFailure:
                return L10n.t("网络不可用，iCloud 同步稍后再试。")
            case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return L10n.t("iCloud 暂时不可用，请稍后再试。")
            case .quotaExceeded:
                return L10n.t("iCloud 空间不足，请清理空间后重试。")
            case .missingEntitlement, .badContainer, .badDatabase, .permissionFailure:
                return L10n.t("iCloud 同步配置异常，请更新 App 或联系支持。")
            case .serverRejectedRequest, .invalidArguments, .constraintViolation:
                return L10n.t("iCloud 私有库暂时无法写入，已尝试使用 iCloud 备用同步。")
            default:
                break
            }
        }
        return L10n.t(fallbackKey)
    }

    private func enforceProFeatureAvailability() {
        if !hasEffectivePro {
            if settings.deductLunch {
                var updatedSettings = settings
                updatedSettings.deductLunch = false
                settings = updatedSettings
            }
            if preferences.appLockEnabled ||
                preferences.lunchRemindersEnabled ||
                preferences.selectedTheme != .classic ||
                preferences.selectedAppIcon != .classic {
                var updatedPreferences = preferences
                updatedPreferences.appLockEnabled = false
                updatedPreferences.lunchRemindersEnabled = false
                updatedPreferences.selectedTheme = .classic
                updatedPreferences.selectedAppIcon = .classic
                preferences = updatedPreferences
            }
            resetAppIconToClassicIfNeeded()
            reminderScheduler.cancelLunchReminders()
            isAppLocked = false
        }
    }

    private func setProUnlocked(_ isUnlocked: Bool) {
        guard preferences.isProUnlocked != isUnlocked else { return }
        var updatedPreferences = preferences
        updatedPreferences.isProUnlocked = isUnlocked
        preferences = updatedPreferences
        enforceProFeatureAvailability()
    }

    private static var unlocksProForLocalDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private func resetAppIconToClassicIfNeeded() {
        #if targetEnvironment(simulator)
        appIconMessage = nil
        #else
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != nil else { return }

        UIApplication.shared.setAlternateIconName(nil) { [weak self] error in
            Task { @MainActor in
                if let error {
                    print("Failed to restore app icon: \(error.localizedDescription)")
                    self?.appIconMessage = L10n.t("图标恢复失败，请稍后再试。")
                    return
                }
                self?.appIconMessage = nil
            }
        }
        #endif
    }

    private func startTransactionUpdatesListener() {
        transactionUpdatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshProEntitlement(successMessage: L10n.t("PRO 权益已更新。"))
            }
        }
    }

    private func isValidPasscode(_ passcode: String) -> Bool {
        passcode.count == 4 && passcode.allSatisfy(\.isNumber)
    }

    private func passcodeHash(_ passcode: String, salt: String) -> String {
        let data = Data("\(salt):\(passcode)".utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
    private let lunchStartPrefix = "payjoy.lunch.start"
    private let lunchEndPrefix = "payjoy.lunch.end"

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
                title: L10n.t("开薪开始"),
                body: L10n.t("上班时间到，每一秒都在回血。"),
                time: settings.workStart,
                weekday: weekday
            )
            addReminder(
                id: "\(endPrefix).\(weekday)",
                title: L10n.t("今日到账"),
                body: L10n.t("下班啦，今天的金币先收工。"),
                time: settings.workEnd,
                weekday: weekday
            )
        }
    }

    func scheduleLunchReminders(settings: SalarySettings) {
        cancelLunchReminders()
        guard settings.deductLunch else { return }

        for weekday in settings.workdays.sorted() {
            addReminder(
                id: "\(lunchStartPrefix).\(weekday)",
                title: L10n.t("午休开始"),
                body: L10n.t("午休时间到，工资进度先暂停一下。"),
                time: settings.lunchStart,
                weekday: weekday
            )
            addReminder(
                id: "\(lunchEndPrefix).\(weekday)",
                title: L10n.t("午休结束"),
                body: L10n.t("午休结束，开薪继续回血。"),
                time: settings.lunchEnd,
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

    func cancelLunchReminders() {
        let identifiers = (1...7).flatMap { weekday in
            ["\(lunchStartPrefix).\(weekday)", "\(lunchEndPrefix).\(weekday)"]
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
