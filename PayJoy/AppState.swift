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
            refreshEstimatedSalaryDayRecords()
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
            scheduleGoalReminderIfNeeded()
            refreshUnlockedBadgeIDsIfNeeded()
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
            if preferences.goalRemindersEnabled {
                scheduleGoalReminderIfNeeded()
            } else {
                reminderScheduler.cancelGoalReminder()
            }
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
            refreshUnlockedBadgeIDsIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var earlyLeaveDateKeys: Set<String> {
        didSet {
            store.saveEarlyLeaveDays(earlyLeaveDateKeys)
            refreshCurrentSalaryDayRecord()
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            refreshUnlockedBadgeIDsIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var salaryDayRecords: [SalaryDayRecord] {
        didSet {
            guard !Self.isScreenshotMode else { return }
            store.saveSalaryDayRecords(salaryDayRecords)
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            scheduleGoalReminderIfNeeded()
            refreshUnlockedBadgeIDsIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var actualSalaryRecords: [ActualSalaryRecord] {
        didSet {
            guard !Self.isScreenshotMode else { return }
            store.saveActualSalaryRecords(actualSalaryRecords)
            refreshWidgetTimelines()
            scheduleGoalReminderIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var wishExperiences: [WishExperience] {
        didSet {
            guard !Self.isScreenshotMode else { return }
            store.saveWishExperiences(wishExperiences)
            refreshWidgetTimelines()
            updateLiveActivityIfNeeded()
            scheduleGoalReminderIfNeeded()
            refreshUnlockedBadgeIDsIfNeeded()
            scheduleCloudSyncIfNeeded()
        }
    }
    var engagementState: EngagementState {
        didSet {
            guard !Self.isScreenshotMode else { return }
            store.saveEngagementState(engagementState)
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
    var isProProductAvailable = false
    var proPurchaseMessage: String?
    var appIconMessage: String?
    var isLoadingProProduct = false
    var isPurchasingPro = false
    var shouldPresentPaydayCelebration = false
    var shouldPresentClosingReceipt = false
    private var pendingClosingReceiptAfterPayday = false
    private var pendingClosingReceiptAfterOvertime = false
    private var pendingCrossMidnightClosingReceiptDate: Date?

    private let calculator: SalaryCalculator
    private let store: SettingsStore
    private let reminderScheduler: WorkReminderScheduler
    private var cloudKit: PayJoyCloudKitService?
    private let storeKit: StoreKitService
    private let engagementAnalytics: any EngagementAnalytics
    private let wishPlanningExporter: any WishPlanningExporting
    @ObservationIgnored private var pendingCloudSyncTask: Task<Void, Never>?
    @ObservationIgnored private var pendingWidgetRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var isApplyingCloudSnapshot = false
    @ObservationIgnored private var isDeletingAccountData = false
    @ObservationIgnored private var activeCloudOperationCount = 0
    @ObservationIgnored private var lastGoalReminderRefreshMinute: Int?
    @ObservationIgnored private var lastSalaryRecordRefreshDateKey: String?
    @ObservationIgnored private var appLockCredential: AppLockCredential?

    init(
        calculator: SalaryCalculator = SalaryCalculator(),
        store: SettingsStore = SettingsStore(),
        reminderScheduler: WorkReminderScheduler = WorkReminderScheduler(),
        cloudKit: PayJoyCloudKitService? = nil,
        engagementAnalytics: any EngagementAnalytics = LocalEngagementAnalytics(),
        wishPlanningExporter: any WishPlanningExporting = DisabledWishPlanningExporter(),
        now: Date = Date()
    ) {
        self.calculator = calculator
        self.store = store
        self.reminderScheduler = reminderScheduler
        self.cloudKit = cloudKit
        self.storeKit = StoreKitService()
        self.engagementAnalytics = engagementAnalytics
        self.wishPlanningExporter = wishPlanningExporter
        let screenshotMode = Self.isScreenshotMode
        let loadedSettings = store.load()
        var loadedPreferences = store.loadPreferences()
        let originalPreferences = loadedPreferences
        let loadedAppLockCredential = screenshotMode ? nil : store.migrateLegacyAppLockCredential(from: &loadedPreferences)
        let migratedLegacyAppLockCredential = !screenshotMode && loadedPreferences != originalPreferences
        if migratedLegacyAppLockCredential {
            store.savePreferences(loadedPreferences)
        }
        let loadedOvertimeDateKeys = store.loadOvertimeDays()
        let savedOvertimeRecords = store.loadOvertimeRecords()

        self.settings = screenshotMode ? Self.screenshotSettings : loadedSettings
        self.profile = screenshotMode ? Self.screenshotProfile : store.loadProfile()
        self.preferences = screenshotMode ? Self.screenshotPreferences : loadedPreferences
        self.overtimeDateKeys = loadedOvertimeDateKeys
        self.overtimeRecords = screenshotMode ? Self.screenshotOvertimeRecords : (savedOvertimeRecords.isEmpty ? Self.migratedOvertimeRecords(from: loadedOvertimeDateKeys, settings: loadedSettings) : savedOvertimeRecords)
        self.earlyLeaveDateKeys = store.loadEarlyLeaveDays()
        self.salaryDayRecords = screenshotMode ? Self.screenshotSalaryDayRecords : store.loadSalaryDayRecords()
        self.actualSalaryRecords = screenshotMode ? Self.screenshotActualSalaryRecords : store.loadActualSalaryRecords()
        self.wishExperiences = screenshotMode ? Self.screenshotWishExperiences : store.loadWishExperiences()
        self.engagementState = screenshotMode ? Self.screenshotEngagementState : store.loadEngagementState()
        self.appleAccount = store.loadAppleAccount()
        self.now = screenshotMode ? Self.screenshotNow : now
        self.proPriceText = ""
        self.selectedTab = screenshotMode && Self.screenshotScreen == "wish-tab" ? .wish : .home
        self.appLockCredential = screenshotMode ? nil : loadedAppLockCredential
        AppNotificationResponseHandler.shared.routeHandler = { [weak self] route in
            self?.handleNotificationRoute(route)
        }
        if screenshotMode && Self.screenshotScreen == "paywall-loading" {
            self.isLoadingProProduct = true
        }
        guard !screenshotMode else {
            cloudStatusKey = "iCloud 可用"
            syncMessage = L10n.t("数据保存在本机")
            return
        }
        enforceProFeatureAvailability()
        refreshReminderAuthorization()
        startTransactionUpdatesListener()
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            synchronizeAppIconPreference()
            refreshCurrentSalaryDayRecord()
            refreshUnlockedBadgeIDsIfNeeded()
            if migratedLegacyAppLockCredential {
                scheduleCloudSyncIfNeeded()
            }
            await loadProProduct()
            await refreshProEntitlement()
            await refreshCloudStatus()
            await refreshAppleCredentialState()
        }
    }

    private var cloudService: PayJoyCloudKitService {
        if let cloudKit {
            return cloudKit
        }
        let service = PayJoyCloudKitService()
        cloudKit = service
        return service
    }

    var snapshot: EarningsSnapshot {
        calculator.snapshot(
            for: now,
            settings: settings,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            record: salaryDayRecord(for: now)
        )
    }

    var offDutySecondsUntilWorkStart: TimeInterval? {
        guard activeOvertimeRecord == nil else { return nil }
        return calculator.offDutySecondsUntilWorkStart(
            for: now,
            settings: settings,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            records: salaryDayRecords
        )
    }

    var focusedWish: WishExperience? {
        wishExperiences
            .filter(\.isActive)
            .sorted {
                ($0.focusedAt ?? .distantPast) > ($1.focusedAt ?? .distantPast)
            }
            .first
    }

    var personalGoal: WishExperience? {
        focusedWish
    }

    var activeWishes: [WishExperience] {
        wishExperiences
            .filter(\.isActive)
            .sorted {
                ($0.focusedAt ?? $0.createdAt) > ($1.focusedAt ?? $1.createdAt)
            }
    }

    var archivedWishes: [WishExperience] {
        wishExperiences
            .filter { !$0.isActive }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var isWishPlanningAvailable: Bool {
        wishPlanningExporter.isAvailable
    }

    var hasEffectivePro: Bool {
        preferences.isProUnlocked || Self.unlocksProForLocalDebug
    }

    var cloudStatusText: String {
        L10n.t(cloudStatusKey)
    }

    func periodEarnings(for period: StatsPeriod) -> PeriodEarnings {
        calculator.periodEarnings(
            for: period,
            date: now,
            settings: settings,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            records: salaryDayRecords,
            actualSalaryRecords: actualSalaryRecords
        )
    }

    func periodBreakdown(for period: StatsPeriod) -> PeriodBreakdown {
        calculator.periodBreakdown(
            for: period,
            date: now,
            settings: settings,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            records: salaryDayRecords
        )
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
        guard !Self.isScreenshotMode else { return }
        now = Date()
        let dateKey = todayDateKey
        if lastSalaryRecordRefreshDateKey != dateKey {
            lastSalaryRecordRefreshDateKey = dateKey
            refreshCurrentSalaryDayRecord()
        }
        let minute = Int(now.timeIntervalSince1970 / 60)
        if lastGoalReminderRefreshMinute != minute {
            lastGoalReminderRefreshMinute = minute
            scheduleGoalReminderIfNeeded()
            refreshUnlockedBadgeIDsIfNeeded()
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
        let normalizedStart = min(startAt, now)
        overtimeRecords.insert(OvertimeRecord(startAt: normalizedStart, endAt: nil, createdAt: now), at: 0)
    }

    func stopActiveOvertime() {
        stopActiveOvertime(at: now)
    }

    func stopActiveOvertime(at endAt: Date) {
        guard let index = overtimeRecords.firstIndex(where: { $0.isActive }) else { return }
        var updatedRecords = overtimeRecords
        let startAt = min(updatedRecords[index].startAt, now)
        let normalizedEnd = min(max(endAt, startAt), now)
        updatedRecords[index].startAt = startAt
        updatedRecords[index].endAt = normalizedEnd
        updatedRecords.sort { $0.startAt > $1.startAt }
        if calculator.dateKey(for: startAt) != calculator.dateKey(for: normalizedEnd) {
            pendingCrossMidnightClosingReceiptDate = startAt
        }
        overtimeRecords = updatedRecords
        if pendingClosingReceiptAfterOvertime {
            pendingClosingReceiptAfterOvertime = false
            openClosingReceipt()
        }
    }

    func saveOvertimeRecord(startAt: Date, endAt: Date) {
        let normalizedStart = min(startAt, now)
        let normalizedEnd = min(max(endAt, normalizedStart), now)
        guard normalizedEnd > normalizedStart else { return }
        var updatedRecords = overtimeRecords
        updatedRecords.insert(OvertimeRecord(startAt: normalizedStart, endAt: normalizedEnd, createdAt: now), at: 0)
        updatedRecords.sort { $0.startAt > $1.startAt }
        overtimeRecords = updatedRecords
    }

    func updateOvertimeRecord(id: String, startAt: Date, endAt: Date?) {
        guard let index = overtimeRecords.firstIndex(where: { $0.id == id }) else { return }
        let normalizedStart = min(startAt, now)
        let normalizedEnd = endAt.map { min($0, now) }
        if let normalizedEnd, normalizedEnd <= normalizedStart { return }
        var updatedRecords = overtimeRecords
        updatedRecords[index].startAt = normalizedStart
        updatedRecords[index].endAt = normalizedEnd
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
            record: salaryDayRecord(for: date),
            completedDateKeys: earlyLeaveDateKeys
        )
    }

    func salaryMonthSummary(for month: Date) -> SalaryMonthSummary {
        calculator.salaryMonthSummary(
            for: month,
            now: now,
            settings: settings,
            records: salaryDayRecords,
            completedDateKeys: earlyLeaveDateKeys,
            actualSalaryRecords: actualSalaryRecords
        )
    }

    func estimatedSalaryMonthSummary(for month: Date) -> SalaryMonthSummary {
        calculator.salaryMonthSummary(
            for: month,
            now: now,
            settings: settings,
            records: salaryDayRecords,
            completedDateKeys: earlyLeaveDateKeys
        )
    }

    var isTodayPayday: Bool {
        calculator.isPayday(now, settings: settings)
    }

    var todayPaydayAmount: Double {
        salaryMonthSummary(for: now).actualAmount ?? salaryMonthSummary(for: now).projectedAmount
    }

    var todayPaydayAmountIsActual: Bool {
        salaryMonthSummary(for: now).actualAmount != nil
    }

    var hidesPaydayShareAmount: Bool {
        preferences.hideSensitiveAmounts || preferences.paydayShareHidesAmount
    }

    func actualSalaryRecord(for month: Date) -> ActualSalaryRecord? {
        let key = calculator.monthKey(for: month)
        return actualSalaryRecords
            .filter { $0.monthKey == key }
            .max { $0.updatedAt < $1.updatedAt }
    }

    func canEnterActualSalary(for month: Date) -> Bool {
        calculator.canEnterActualSalary(for: month, now: now, settings: settings)
    }

    @discardableResult
    func saveActualSalary(amount: Double, for month: Date) -> Bool {
        guard hasEffectivePro,
              amount.isFinite,
              amount > 0,
              canEnterActualSalary(for: month) else { return false }
        let key = calculator.monthKey(for: month)
        var updated = actualSalaryRecords.filter { $0.monthKey != key }
        updated.append(
            ActualSalaryRecord(
                monthKey: key,
                amount: amount,
                currencyCode: settings.currencyCode,
                updatedAt: now
            )
        )
        updated.sort { $0.monthKey > $1.monthKey }
        actualSalaryRecords = updated
        return true
    }

    func removeActualSalary(for month: Date) {
        guard hasEffectivePro else { return }
        let key = calculator.monthKey(for: month)
        actualSalaryRecords.removeAll { $0.monthKey == key }
    }

    func openPaydayCelebration() {
        guard isTodayPayday else { return }
        shouldPresentPaydayCelebration = true
    }

    func dismissPaydayCelebration() {
        shouldPresentPaydayCelebration = false
        guard pendingClosingReceiptAfterPayday else { return }
        pendingClosingReceiptAfterPayday = false
        shouldPresentClosingReceipt = canOpenClosingReceipt
    }

    func setPaydayShareHidesAmount(_ hidesAmount: Bool) {
        guard preferences.paydayShareHidesAmount != hidesAmount else { return }
        var updatedPreferences = preferences
        updatedPreferences.paydayShareHidesAmount = hidesAmount
        preferences = updatedPreferences
    }

    private func preparePaydayCelebrationIfNeeded() {
        guard preferences.hasCompletedInitialSetup,
              !isAppLocked,
              isTodayPayday else { return }
        let key = todayDateKey
        guard store.lastPaydayCelebrationDate() != key else { return }
        store.markPaydayCelebrationShown(dateKey: key)
        shouldPresentPaydayCelebration = true
    }

    func defaultSalaryDayKind(for date: Date) -> SalaryDayKind {
        calculator.defaultSalaryDayKind(for: date, settings: settings)
    }

    var personalGoalProgress: PersonalGoalProgress? {
        guard let personalGoal, personalGoal.targetAmount != nil else { return nil }
        return calculator.personalGoalProgress(
            for: personalGoal,
            now: now,
            settings: settings,
            records: salaryDayRecords,
            completedDateKeys: earlyLeaveDateKeys
        )
    }

    var weeklyPayReport: WeeklyPayReport {
        calculator.weeklyPayReport(
            now: now,
            settings: settings,
            records: salaryDayRecords,
            completedDateKeys: earlyLeaveDateKeys
        )
    }

    var salaryBadges: [SalaryBadge] {
        calculator.salaryBadges(
            now: now,
            settings: settings,
            records: salaryDayRecords,
            completedDateKeys: earlyLeaveDateKeys,
            focusedWish: personalGoal,
            wishes: wishExperiences,
            overtimeRecords: overtimeRecords,
            unlockedBadgeIDs: preferences.unlockedBadgeIDs
        )
    }

    private func refreshUnlockedBadgeIDsIfNeeded() {
        guard !Self.isScreenshotMode else { return }
        let currentUnlockedIDs = Set(
            calculator.salaryBadges(
                now: now,
                settings: settings,
                records: salaryDayRecords,
                completedDateKeys: earlyLeaveDateKeys,
                focusedWish: personalGoal,
                wishes: wishExperiences,
                overtimeRecords: overtimeRecords
            )
            .filter(\.isUnlocked)
            .map(\.id)
        )
        let newUnlockedIDs = currentUnlockedIDs.subtracting(preferences.unlockedBadgeIDs)
        guard !newUnlockedIDs.isEmpty else { return }
        var updatedPreferences = preferences
        updatedPreferences.unlockedBadgeIDs.formUnion(newUnlockedIDs)
        preferences = updatedPreferences
    }

    var canCreateWish: Bool {
        hasEffectivePro || activeWishes.count < 3
    }

    @discardableResult
    func createWish(
        title: String,
        archetype: WishArchetype? = nil,
        captureSource: WishCaptureSource,
        sourceURL: URL? = nil,
        coverAssetReference: String? = nil,
        targetAmount: Decimal? = nil,
        currencyCode: CurrencyCode? = nil
    ) -> WishExperience? {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, canCreateWish else { return nil }

        let canBecomeActive = activeWishes.count < 3
        let shouldFocus = canBecomeActive && focusedWish == nil
        let wish = WishExperience(
            title: cleanedTitle,
            archetype: archetype,
            captureSource: captureSource,
            sourceURL: sourceURL,
            coverAssetReference: coverAssetReference,
            targetAmount: targetAmount,
            currencyCode: currencyCode ?? settings.currencyCode,
            status: canBecomeActive ? .active : .paused,
            createdAt: now,
            focusedAt: shouldFocus ? now : nil
        )
        wishExperiences.insert(wish, at: 0)
        engagementAnalytics.record(.wishCreated, market: preferences.resolvedMarket)
        return wish
    }

    func focusWish(id: UUID) {
        guard let targetIndex = wishExperiences.firstIndex(where: { $0.id == id && $0.isActive }) else { return }
        for index in wishExperiences.indices {
            wishExperiences[index].focusedAt = index == targetIndex ? now : nil
        }
    }

    func setWishStatus(id: UUID, status: WishStatus) {
        guard let index = wishExperiences.firstIndex(where: { $0.id == id }) else { return }
        if status == .active,
           !wishExperiences[index].isActive,
           activeWishes.count >= 3 {
            return
        }
        wishExperiences[index].status = status
        wishExperiences[index].completedAt = status == .completed ? now : nil
        if status != .active {
            wishExperiences[index].focusedAt = nil
        }
        if focusedWish == nil,
           let nextIndex = wishExperiences.firstIndex(where: \.isActive) {
            wishExperiences[nextIndex].focusedAt = now
        }
    }

    func updateWishProgress(id: UUID, progress: Double) {
        guard let index = wishExperiences.firstIndex(where: { $0.id == id }) else { return }
        wishExperiences[index].updateProgress(progress)
    }

    func completeWish(id: UUID, realizedAssetReference: String?) {
        guard let index = wishExperiences.firstIndex(where: { $0.id == id }) else { return }
        wishExperiences[index].realizedAssetReference = realizedAssetReference
        wishExperiences[index].status = .completed
        wishExperiences[index].completedAt = now
        wishExperiences[index].focusedAt = nil
        if focusedWish == nil,
           let nextIndex = wishExperiences.firstIndex(where: \.isActive) {
            wishExperiences[nextIndex].focusedAt = now
        }
    }

    func removeWish(id: UUID) {
        wishExperiences.removeAll { $0.id == id }
        if focusedWish == nil,
           let nextIndex = wishExperiences.firstIndex(where: \.isActive) {
            wishExperiences[nextIndex].focusedAt = now
        }
    }

    func updateSalaryDay(date: Date, kind: SalaryDayKind, note: String) {
        let dateKey = calculator.dateKey(for: date)
        let existing = salaryDayRecords.first { $0.dateKey == dateKey }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: now)
        let isEstimated = startOfDay > today
        let settingsSnapshot = startOfDay > today ? settings : (existing?.settingsSnapshot ?? settings)
        let scheduledAmount = (kind == .normal || kind == .paidLeave)
            ? calculator.scheduledSalaryAmount(for: date, settings: settingsSnapshot)
            : 0
        let previewRecord = SalaryDayRecord(
            dateKey: dateKey,
            kind: kind,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            settingsSnapshot: settingsSnapshot,
            scheduledAmount: scheduledAmount,
            earnedAmount: startOfDay < today ? scheduledAmount : 0,
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
        salaryDayRecords.removeAll { $0.dateKey == calculator.dateKey(for: date) }
        refreshCurrentSalaryDayRecord()
    }

    private func refreshCurrentSalaryDayRecord(refreshSettingsSnapshot: Bool = false) {
        guard !isApplyingCloudSnapshot else { return }
        let today = Calendar.current.startOfDay(for: now)
        let todayKey = calculator.dateKey(for: today)
        var updatedRecords = salaryDayRecords.map { record in
            guard let date = date(fromKey: record.dateKey),
                  date < today,
                  (record.isEstimated || record.earnedAmount != record.scheduledAmount) else { return record }
            var finalized = record
            finalized.earnedAmount = finalized.scheduledAmount
            finalized.isEstimated = false
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
        let reusesExistingRecord = existing.map {
            $0.kind == kind
                && $0.note == previewRecord.note
                && $0.settingsSnapshot == settingsSnapshot
                && $0.scheduledAmount == scheduledAmount
                && !$0.isEstimated
        } ?? false
        let refreshedRecord = SalaryDayRecord(
            dateKey: todayKey,
            kind: kind,
            note: previewRecord.note,
            settingsSnapshot: settingsSnapshot,
            scheduledAmount: scheduledAmount,
            earnedAmount: reusesExistingRecord ? (existing?.earnedAmount ?? day.earnedAmount) : day.earnedAmount,
            isEstimated: false,
            updatedAt: reusesExistingRecord ? (existing?.updatedAt ?? now) : now
        )

        updatedRecords.removeAll { $0.dateKey == todayKey }
        updatedRecords.append(refreshedRecord)
        updatedRecords.sort { $0.dateKey > $1.dateKey }
        if updatedRecords != salaryDayRecords {
            salaryDayRecords = updatedRecords
        }
    }

    private func refreshEstimatedSalaryDayRecords() {
        let updatedRecords = salaryDayRecords.map { record in
            guard let date = date(fromKey: record.dateKey) else { return record }
            return calculator.refreshedFutureSalaryDayRecord(
                record,
                for: date,
                now: now,
                settings: settings
            )
        }
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

    private func salaryDayRecord(for date: Date) -> SalaryDayRecord? {
        let dateKey = calculator.dateKey(for: date)
        return salaryDayRecords
            .filter { $0.dateKey == dateKey }
            .max { $0.updatedAt < $1.updatedAt }
    }

    private func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
            .map { Calendar.current.startOfDay(for: $0) }
    }

    func refreshWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: "PayJoyEarningsWidgetV3")
        pendingWidgetRefreshTask?.cancel()
        pendingWidgetRefreshTask = Task { @MainActor in
            for delay in [250_000_000, 1_000_000_000] {
                try? await Task.sleep(nanoseconds: UInt64(delay))
                guard !Task.isCancelled else { return }
                WidgetCenter.shared.reloadTimelines(ofKind: "PayJoyEarningsWidgetV3")
            }
        }
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
        let offDutyRemaining = offDutySecondsUntilWorkStart
        return PayJoyActivityAttributes.ContentState(
            earned: snapshot.todayEarned,
            total: snapshot.todayTotal,
            perSecond: snapshot.earnedPerSecond,
            progress: snapshot.progress,
            statusTitle: snapshot.status.title,
            endDate: offDutyRemaining.map { now.addingTimeInterval($0) } ?? workEndDate(for: now),
            remainingText: (offDutyRemaining ?? snapshot.secondsUntilOffWork).countdownText,
            countdownTitle: offDutyRemaining == nil ? L10n.t("下班倒计时") : L10n.t("下次上班"),
            isOffDuty: offDutyRemaining != nil,
            hidesSensitiveAmounts: preferences.hideSensitiveAmounts,
            currencySymbol: settings.currencySymbol,
            visualTheme: preferences.selectedTheme,
            goalTitle: personalGoal?.title,
            goalProgress: personalGoalProgress?.progress,
            goalRemainingText: personalGoalProgress.map { progress in
                progress.progress >= 1
                    ? L10n.t("已达成")
                    : PrivacyText.compactMoney(progress.remainingAmount, hidden: preferences.hideSensitiveAmounts, currencySymbol: settings.currencySymbol)
            },
            goalCompletionText: personalGoalProgress.flatMap { progress in
                guard progress.progress < 1, let date = progress.estimatedCompletionDate else { return nil }
                return L10n.format("预计 %@ 达成。", date.localizedDateText)
            }
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
                syncMessage = L10n.t("午休提醒需要开通会员，并在工作时间设置里开启午休时间。")
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

    func setGoalRemindersEnabled(_ isEnabled: Bool) {
        Task {
            guard isEnabled else {
                var updatedPreferences = preferences
                updatedPreferences.goalRemindersEnabled = false
                preferences = updatedPreferences
                reminderScheduler.cancelGoalReminder()
                reminderPermissionState = await reminderScheduler.authorizationState()
                return
            }

            guard personalGoal != nil else {
                syncMessage = L10n.t("请先设置一个开薪目标。")
                return
            }

            let granted = await reminderScheduler.requestAuthorization()
            reminderPermissionState = await reminderScheduler.authorizationState()
            var updatedPreferences = preferences
            updatedPreferences.goalRemindersEnabled = granted
            preferences = updatedPreferences
            if granted {
                scheduleGoalReminderIfNeeded()
            }
        }
    }

    private func scheduleGoalReminderIfNeeded() {
        guard preferences.goalRemindersEnabled,
              let goal = personalGoal,
              let progress = personalGoalProgress else {
            reminderScheduler.cancelGoalReminder()
            return
        }
        reminderScheduler.scheduleGoalReminder(goal: goal, progress: progress, settings: settings, now: now)
    }

    var isSignedInWithApple: Bool {
        appleAccount != nil
    }

    private var hasInitializedCloudSync: Bool {
        guard let userIdentifier = appleAccount?.userIdentifier else { return false }
        return store.hasInitializedCloudSync(for: userIdentifier)
    }

    var requiresCloudSyncSourceConfirmation: Bool {
        canUseCloudSync && isSignedInWithApple && !hasInitializedCloudSync
    }

    var appleAccountDetail: String {
        appleAccount?.displayName ?? L10n.t("Apple ID 可用于账号登录和在多台设备间恢复数据。")
    }

    var canUseCloudSync: Bool {
        hasEffectivePro
    }

    func setAppIconChoice(_ icon: AppIconChoice) {
        appIconMessage = nil

        guard hasEffectivePro || icon == .classic else {
            appIconMessage = L10n.t("这是会员功能，开通后可切换 App 图标。")
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
                if error != nil {
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

    static var isScreenshotMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_MODE"] == "1" ||
        ProcessInfo.processInfo.arguments.contains("PAYJOY_SCREENSHOT_MODE")
        #else
        false
        #endif
    }

    private static var screenshotNow: Date {
        let calendarScreen = screenshotScreen == "calendar"
        let afterMidnightScreen = screenshotScreen == "home-after-midnight"
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Shanghai")
        components.year = 2026
        components.month = calendarScreen ? 7 : 6
        components.day = calendarScreen ? 14 : 3
        components.hour = afterMidnightScreen ? 0 : 15
        components.minute = afterMidnightScreen ? 18 : 24
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
            workdays: Workday.defaultWeekdays,
            paydayDay: screenshotScreen == "payday" ||
                screenshotScreen == "membership-prompt" ||
                screenshotScreen == "actual-salary" ||
                screenshotScreen == "stats-actual-salary" ? 3 : nil
        )
    }

    private static var screenshotProfile: UserProfile {
        .defaultValue
    }

    private static var screenshotPreferences: AppPreferences {
        let selectedTheme = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_THEME"]
            .flatMap(AppVisualTheme.init(rawValue:)) ?? .classic
        let appLanguage = ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_LANGUAGE"]
            .flatMap(AppLanguage.init(rawValue:)) ?? .zhHans

        return AppPreferences(
            appLanguage: appLanguage,
            selectedTheme: selectedTheme,
            selectedAppIcon: .classic,
            remindersEnabled: true,
            lunchRemindersEnabled: false,
            goalRemindersEnabled: false,
            showCoinRain: true,
            reduceMotion: true,
            showDecimalCents: true,
            isProUnlocked: ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_PRO_LOCKED"] != "1",
            hideSensitiveAmounts: screenshotScreen == "privacy" ||
                ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_HIDE_AMOUNTS"] == "1",
            hasCompletedInitialSetup: true,
            appLockEnabled: false,
            appLockPasscodeSalt: nil,
            appLockPasscodeHash: nil
        )
    }

    private static var screenshotScreen: String {
        let arguments = ProcessInfo.processInfo.arguments
        let argumentValue = arguments.first(where: { $0.hasPrefix("PAYJOY_SCREENSHOT_SCREEN=") })?
            .split(separator: "=", maxSplits: 1)
            .last
            .map(String.init)
        return ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_SCREEN"] ?? argumentValue ?? "home"
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
        if screenshotScreen == "calendar" {
            return [
                OvertimeRecord(startAt: date(dayOffset: 0, hour: 12, minute: 54), endAt: date(dayOffset: 0, hour: 15, minute: 24), createdAt: date(dayOffset: 0, hour: 12, minute: 54))
            ]
        }

        if screenshotScreen == "home-after-midnight" {
            return []
        }

        return [
            OvertimeRecord(startAt: date(dayOffset: 0, hour: 14, minute: 45), endAt: nil, createdAt: date(dayOffset: 0, hour: 14, minute: 45)),
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

    private static var screenshotActualSalaryRecords: [ActualSalaryRecord] {
        if screenshotScreen == "stats-actual-salary" {
            return [
                ActualSalaryRecord(
                    monthKey: "2026-06",
                    amount: 18_680,
                    currencyCode: screenshotSettings.currencyCode,
                    updatedAt: screenshotNow
                )
            ]
        }
        guard screenshotScreen == "actual-salary" else { return [] }
        return [
            ActualSalaryRecord(
                monthKey: "2026-05",
                amount: 18_680,
                currencyCode: screenshotSettings.currencyCode,
                updatedAt: screenshotNow
            ),
            ActualSalaryRecord(
                monthKey: "2026-04",
                amount: 17_920,
                currencyCode: screenshotSettings.currencyCode,
                updatedAt: screenshotNow.addingTimeInterval(-86_400)
            )
        ]
    }

    private static var screenshotWishExperiences: [WishExperience] {
        [
            WishExperience(
                title: L10n.t("去九寨沟看看秋天"),
                archetype: .journey,
                captureSource: .inspiration,
                targetAmount: 6_000,
                currencyCode: .CNY,
                manualProgress: 0.31,
                createdAt: screenshotNow.addingTimeInterval(-6 * 86_400),
                focusedAt: screenshotNow.addingTimeInterval(-6 * 86_400)
            ),
            WishExperience(
                title: L10n.t("一只软乎乎的小狮子"),
                archetype: .companion,
                captureSource: .inspiration,
                createdAt: screenshotNow.addingTimeInterval(-2 * 86_400)
            ),
            WishExperience(
                title: L10n.t("换一部喜欢的新手机"),
                archetype: .possession,
                captureSource: .inspiration,
                createdAt: screenshotNow.addingTimeInterval(-86_400)
            )
        ]
    }

    private static var screenshotEngagementState: EngagementState {
        let receipts: [ClosingCapsule]
        if screenshotScreen == "closing-receipt-complete" {
            receipts = [
                ClosingCapsule(
                    id: "screenshot-closing-receipt",
                    dateKey: EmotionalDayKey.string(from: screenshotNow),
                    createdAt: screenshotNow,
                    messageIndex: 1,
                    earnedAmount: 542.53,
                    currencyCode: screenshotSettings.currencyCode,
                    workProgress: 1,
                    wishProgress: 0.31,
                    wishID: screenshotWishExperiences.first?.id,
                    wishTitle: screenshotWishExperiences.first?.title,
                    companionID: CompanionProfile.defaultValue.id,
                    mood: .steady,
                    tone: .gentle,
                    revealsSalary: false
                )
            ]
        } else {
            receipts = []
        }
        return EngagementState(
            selectedCompanionID: CompanionProfile.defaultValue.id,
            tone: .gentle,
            dailyState: CompanionDailyState(
                dateKey: EmotionalDayKey.string(from: screenshotNow),
                mood: .steady
            ),
            capsules: receipts
        )
    }

    var canStartProPrimaryAction: Bool {
        !hasEffectivePro && !isPurchasingPro && !isLoadingProProduct
    }

    var selectedCompanion: CompanionProfile {
        engagementState.selectedCompanion
    }

    var todayClosingReceipt: ClosingCapsule? {
        engagementState.capsules.first { $0.dateKey == todayDateKey }
    }

    var closingReceiptForPresentation: ClosingCapsule? {
        let date = pendingCrossMidnightClosingReceiptDate ?? now
        let dateKey = calculator.dateKey(for: date)
        return engagementState.capsules.first { $0.dateKey == dateKey }
    }

    var visibleClosingReceipts: [ClosingCapsule] {
        let sorted = engagementState.capsules.sorted { $0.createdAt > $1.createdAt }
        return hasEffectivePro ? sorted : Array(sorted.prefix(7))
    }

    var hasLockedClosingReceipts: Bool {
        !hasEffectivePro && engagementState.capsules.count > visibleClosingReceipts.count
    }

    var canOpenClosingReceipt: Bool {
        guard activeOvertimeRecord == nil else { return false }
        return pendingCrossMidnightClosingReceiptDate != nil
            || snapshot.status == .afterWork
            || hasLeftWorkEarlyToday
            || todayOvertimeDuration > 0
    }

    func recordPaywallViewed() {
        engagementAnalytics.record(.paywallViewed, market: preferences.resolvedMarket)
    }

    func setDailyMood(_ mood: DailyMood) {
        var updated = engagementState
        updated.prepareDay(for: now)
        updated.dailyState.mood = mood
        engagementState = updated
        engagementAnalytics.record(.moodSelected, market: preferences.resolvedMarket)
    }

    @discardableResult
    func selectCompanion(id: String) -> Bool {
        guard let companion = CompanionProfile.catalog.first(where: { $0.id == id }) else { return false }
        var updated = engagementState
        updated.selectedCompanionID = companion.id
        engagementState = updated
        var updatedProfile = profile
        updatedProfile.avatarAssetName = companion.avatarAssetName
        profile = updatedProfile
        return true
    }

    @discardableResult
    func selectEmotionalTone(_ tone: EmotionalTonePack) -> Bool {
        guard !tone.isPro || hasEffectivePro else { return false }
        var updated = engagementState
        updated.tone = tone
        engagementState = updated
        return true
    }

    func openClosingReceipt() {
        guard canOpenClosingReceipt else { return }
        selectedTab = .home
        if shouldPresentPaydayCelebration {
            pendingClosingReceiptAfterPayday = true
            return
        }
        guard !shouldPresentClosingReceipt else { return }
        shouldPresentClosingReceipt = true
        engagementAnalytics.record(.closingReceiptOpened, market: preferences.resolvedMarket)
    }

    func closeClosingReceipt() {
        shouldPresentClosingReceipt = false
        pendingCrossMidnightClosingReceiptDate = nil
    }

    func handleNotificationRoute(_ route: AppNotificationRoute) {
        switch route {
        case .closingReceipt:
            if activeOvertimeRecord != nil {
                pendingClosingReceiptAfterOvertime = true
            } else {
                openClosingReceipt()
            }
        }
    }

    @discardableResult
    func completeClosingCapsule(revealsSalary: Bool = false) -> ClosingCapsule {
        let receiptDate = pendingCrossMidnightClosingReceiptDate ?? now
        let dateKey = calculator.dateKey(for: receiptDate)
        if let existing = engagementState.capsules.first(where: { $0.dateKey == dateKey }) {
            pendingCrossMidnightClosingReceiptDate = nil
            return existing
        }

        let isCurrentDay = dateKey == todayDateKey
        let earnedAmount = isCurrentDay
            ? snapshot.todayEarned
            : salaryCalendarDay(for: receiptDate).earnedAmount
        let workProgress = isCurrentDay ? min(1, max(0, snapshot.progress)) : 1

        let seed = dateKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            + engagementState.selectedCompanionID.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            + engagementState.tone.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let capsule = ClosingCapsule(
            id: UUID().uuidString,
            dateKey: dateKey,
            createdAt: now,
            messageIndex: seed % 3,
            earnedAmount: earnedAmount,
            currencyCode: settings.currencyCode,
            workProgress: workProgress,
            // The receipt mirrors the progress the user set on the wish. It must not
            // infer or allocate salary toward a wish like a budgeting product.
            wishProgress: focusedWish?.progress,
            wishID: focusedWish?.id,
            wishTitle: focusedWish?.title,
            companionID: engagementState.selectedCompanionID,
            mood: engagementState.dailyState.mood,
            tone: engagementState.tone,
            revealsSalary: revealsSalary
        )
        var updated = engagementState
        updated.capsules.insert(capsule, at: 0)
        updated.capsules = Array(updated.capsules.prefix(400))
        engagementState = updated
        pendingCrossMidnightClosingReceiptDate = nil
        engagementAnalytics.record(.closingCapsuleCompleted, market: preferences.resolvedMarket)
        return capsule
    }

    func recordClosingCapsuleShared() {
        engagementAnalytics.record(.closingCapsuleShared, market: preferences.resolvedMarket)
    }

    func setClosingCapsuleSalaryVisibility(id: String, revealsSalary: Bool) {
        guard let index = engagementState.capsules.firstIndex(where: { $0.id == id }) else { return }
        var updated = engagementState
        updated.capsules[index].revealsSalary = revealsSalary
        engagementState = updated
    }

    func completeEmotionalOnboarding(
        settings newSettings: SalarySettings,
        companionID: String
    ) {
        engagementAnalytics.record(.onboardingStarted, market: preferences.resolvedMarket)
        settings = newSettings.sanitized
        _ = selectCompanion(id: companionID)
        var updatedPreferences = preferences
        updatedPreferences.hasCompletedInitialSetup = true
        preferences = updatedPreferences
        engagementAnalytics.record(.onboardingCompleted, market: preferences.resolvedMarket)
        engagementAnalytics.record(.firstValueReached, market: preferences.resolvedMarket)
    }

    func loadProProduct() async {
#if DEBUG
        if Self.isScreenshotMode && Self.screenshotScreen == "paywall-error" {
            proPriceText = ""
            isProProductAvailable = false
            proPurchaseMessage = L10n.t("会员商品暂时无法加载，请稍后再试。")
            return
        }
#endif
        guard !isLoadingProProduct else { return }
        isLoadingProProduct = true
        defer { isLoadingProProduct = false }

        do {
            let product = try await storeKit.loadProProduct()
            proPriceText = product.displayPrice
            isProProductAvailable = true
            proPurchaseMessage = nil
        } catch {
            proPriceText = ""
            isProProductAvailable = false
            proPurchaseMessage = L10n.t("会员商品暂时无法加载，请稍后再试。")
        }
    }

    func purchasePro() async {
        guard !hasEffectivePro, !isPurchasingPro else { return }
        engagementAnalytics.record(.purchaseStarted, market: preferences.resolvedMarket)
        isPurchasingPro = true
        proPurchaseMessage = nil
        defer { isPurchasingPro = false }

        do {
            let result = try await storeKit.purchasePro()
            switch result {
            case .purchased:
                await refreshProEntitlement(successMessage: L10n.t("开薪会员已开通，全部会员功能已经解锁。"))
                engagementAnalytics.record(.purchaseCompleted, market: preferences.resolvedMarket)
            case .pending:
                proPurchaseMessage = L10n.t("购买正在等待 Apple 处理，完成后会自动解锁会员功能。")
            case .cancelled:
                proPurchaseMessage = L10n.t("已取消购买。")
            }
        } catch {
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
            await refreshProEntitlement(successMessage: L10n.t("已恢复会员购买。"), missingMessage: L10n.t("没有找到可恢复的会员购买记录。"))
        } catch {
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
        appLockCredential != nil
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
        preparePaydayCelebrationIfNeeded()
    }

    func setAppLockPasscode(_ passcode: String) {
        guard canUseAppLock, isValidPasscode(passcode) else { return }
        let salt = UUID().uuidString
        let credential = AppLockCredential(salt: salt, hash: passcodeHash(passcode, salt: salt))!
        guard store.saveAppLockCredential(credential) else {
            appLockMessage = L10n.t("无法安全保存密码，请稍后再试。")
            return
        }
        var updatedPreferences = preferences
        updatedPreferences.clearLegacyAppLockCredential()
        updatedPreferences.appLockEnabled = true
        preferences = updatedPreferences
        appLockCredential = credential
        isAppLocked = false
        appLockMessage = nil
    }

    func disableAppLock() {
        store.clearAppLockCredential()
        var updatedPreferences = preferences
        updatedPreferences.appLockEnabled = false
        updatedPreferences.clearLegacyAppLockCredential()
        preferences = updatedPreferences
        appLockCredential = nil
        isAppLocked = false
        appLockMessage = nil
    }

    func unlockApp(with passcode: String) -> Bool {
        guard isAppLockActive,
              let credential = appLockCredential else {
            isAppLocked = false
            return true
        }
        guard isValidPasscode(passcode),
              passcodeHash(passcode, salt: credential.salt) == credential.hash else {
            appLockMessage = L10n.t("密码不对，再试一次。")
            return false
        }
        appLockMessage = nil
        isAppLocked = false
        preparePaydayCelebrationIfNeeded()
        return true
    }

    func requireProFeature(_ message: String = L10n.t("这是会员功能，开通后即可使用。")) {
        syncMessage = message
    }

    func sanitizeSettingsForCurrentPlan(_ settings: SalarySettings) -> SalarySettings {
        var sanitized = settings.sanitized
        guard !canUseLunchBreakSettings, sanitized.deductLunch else { return sanitized }
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
        syncMessage = canUseCloudSync
            ? (hasInitializedCloudSync
                ? L10n.t("Apple ID 已连接，后续修改会自动同步到 iCloud。")
                : L10n.t("Apple ID 已连接。为避免覆盖已有 iCloud 数据，请先选择上传或恢复。"))
            : L10n.t("Apple ID 已连接；开通会员后可自动同步。")
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
            let status = try await cloudService.accountStatus()
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
            syncMessage = L10n.t("这是会员功能，开通后可使用 iCloud 同步。")
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
        guard !isApplyingCloudSnapshot, !isDeletingAccountData, canUseCloudSync, isSignedInWithApple, hasInitializedCloudSync else { return }

        pendingCloudSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled else { return }
            await self?.performCloudSync(isAutomatic: true)
        }
    }

    private func performCloudSync(isAutomatic: Bool) async {
        guard !isApplyingCloudSnapshot,
              !isDeletingAccountData,
              canUseCloudSync,
              isSignedInWithApple,
              !isAutomatic || hasInitializedCloudSync else { return }

        beginCloudOperation()
        defer { endCloudOperation() }

        do {
            try await cloudService.saveSnapshot(
                PayJoyCloudSnapshot(
                    settings: settings,
                    profile: profile,
                    preferences: preferences,
                    overtimeDateKeys: overtimeDateKeys,
                    overtimeRecords: overtimeRecords,
                    earlyLeaveDateKeys: earlyLeaveDateKeys,
                    salaryDayRecords: salaryDayRecords,
                    actualSalaryRecords: actualSalaryRecords,
                    wishExperiences: wishExperiences,
                    engagementState: engagementState,
                    updatedAt: Date()
                )
            )
            guard !isApplyingCloudSnapshot, !isDeletingAccountData else { return }
            if let userIdentifier = appleAccount?.userIdentifier {
                store.markCloudSyncInitialized(for: userIdentifier)
            }
            syncMessage = isAutomatic ? L10n.t("已自动同步到 iCloud。") : L10n.t("已同步到 iCloud。")
        } catch {
            guard !isApplyingCloudSnapshot, !isDeletingAccountData else { return }
            syncMessage = cloudFailureMessage(
                for: error,
                fallbackKey: isAutomatic ? "自动同步失败，请稍后再试。" : "同步失败，请稍后再试。"
            )
        }
    }

    func restoreFromCloud() async {
        guard !isApplyingCloudSnapshot, !isDeletingAccountData else { return }
        guard canUseCloudSync else {
            syncMessage = L10n.t("这是会员功能，开通后可从 iCloud 恢复。")
            return
        }
        guard isSignedInWithApple else {
            syncMessage = L10n.t("请先连接 Apple ID，再从 iCloud 恢复。")
            return
        }

        beginCloudOperation()
        defer { endCloudOperation() }

        do {
            guard let snapshot = try await cloudService.fetchSnapshot() else {
                syncMessage = L10n.t("iCloud 里暂时没有开薪数据。")
                return
            }
            guard !isDeletingAccountData else { return }
            pendingCloudSyncTask?.cancel()
            isApplyingCloudSnapshot = true
            settings = snapshot.settings
            profile = snapshot.profile
            preferences = snapshot.preferences.preservingLocalSecurityState(from: preferences)
            enforceProFeatureAvailability()
            overtimeDateKeys = snapshot.overtimeDateKeys
            overtimeRecords = snapshot.overtimeRecords.isEmpty ? Self.migratedOvertimeRecords(from: snapshot.overtimeDateKeys, settings: snapshot.settings) : snapshot.overtimeRecords
            earlyLeaveDateKeys = snapshot.earlyLeaveDateKeys
            salaryDayRecords = snapshot.salaryDayRecords
            actualSalaryRecords = snapshot.actualSalaryRecords
            if let restoredWishes = snapshot.wishExperiences {
                wishExperiences = restoredWishes
            } else {
                let currency = snapshot.settings.currencyCode
                var migratedWishes: [WishExperience] = []
                if let goal = snapshot.personalGoal {
                    migratedWishes.append(
                        WishExperience(
                            title: goal.title,
                            targetAmount: Decimal(goal.targetAmount),
                            currencyCode: currency,
                            createdAt: goal.startedAt,
                            focusedAt: goal.startedAt
                        )
                    )
                }
                migratedWishes.append(contentsOf: (snapshot.salaryWishes ?? []).map { wish in
                    WishExperience(
                        id: wish.id,
                        title: wish.title,
                        targetAmount: Decimal(wish.targetAmount),
                        currencyCode: currency,
                        status: wish.isCompleted ? .completed : .active,
                        createdAt: wish.createdAt,
                        completedAt: wish.isCompleted ? now : nil
                    )
                })
                wishExperiences = migratedWishes
            }
            if let restoredEngagementState = snapshot.engagementState {
                engagementState = restoredEngagementState
            }
            isApplyingCloudSnapshot = false
            refreshCurrentSalaryDayRecord()
            if let userIdentifier = appleAccount?.userIdentifier {
                store.markCloudSyncInitialized(for: userIdentifier)
            }
            syncMessage = L10n.t("已从 iCloud 恢复数据。")
        } catch {
            isApplyingCloudSnapshot = false
            syncMessage = cloudFailureMessage(for: error, fallbackKey: "恢复失败，请稍后再试。")
        }
    }

    func deleteAccountAndLocalData() async {
        guard !isDeletingAccountData else { return }
        isDeletingAccountData = true
        defer { isDeletingAccountData = false }
        pendingCloudSyncTask?.cancel()
        pendingCloudSyncTask = nil
        isApplyingCloudSnapshot = true
        await waitForActiveCloudOperationsToFinish()
        beginCloudOperation()
        defer { endCloudOperation() }
        let cloudDeletionError: String? = await {
            guard isSignedInWithApple else { return nil }
            do {
                try await cloudService.deleteAllPrivateData()
                return nil
            } catch {
                return cloudFailureMessage(for: error, fallbackKey: "iCloud 删除失败，请稍后再试。")
            }
        }()

        resetLocalData()
        isApplyingCloudSnapshot = false
        syncMessage = cloudDeletionError.map { "\(L10n.t("账号和本机数据已删除，iCloud 删除失败"))：\($0)" } ?? L10n.t("账号、本机与 iCloud 数据已删除。")
    }

    func clearLocalData() async {
        guard !isDeletingAccountData else { return }
        isDeletingAccountData = true
        defer { isDeletingAccountData = false }
        pendingCloudSyncTask?.cancel()
        pendingCloudSyncTask = nil
        isApplyingCloudSnapshot = true
        await waitForActiveCloudOperationsToFinish()
        resetLocalData()
        isApplyingCloudSnapshot = false
        syncMessage = L10n.t("本机数据已删除。若此前同步过，重新连接 Apple ID 后可从 iCloud 恢复。")
    }

    private func resetLocalData() {
        endLiveActivity()
        reminderScheduler.cancelWorkdayReminders()
        reminderScheduler.cancelLunchReminders()
        store.clearAllLocalData()
        appLockCredential = nil
        appleAccount = nil
        settings = .defaultValue
        profile = .defaultValue
        preferences = .defaultValue
        overtimeDateKeys = []
        overtimeRecords = []
        earlyLeaveDateKeys = []
        salaryDayRecords = []
        actualSalaryRecords = []
        wishExperiences = []
        engagementState = .defaultValue
        isApplyingCloudSnapshot = false
        selectedTab = .home
        isAppLocked = false
        isScenePrivacyShieldVisible = false
        appLockMessage = nil
    }

    private func beginCloudOperation() {
        activeCloudOperationCount += 1
        isSyncing = true
    }

    private func endCloudOperation() {
        activeCloudOperationCount = max(0, activeCloudOperationCount - 1)
        isSyncing = activeCloudOperationCount > 0
    }

    private func waitForActiveCloudOperationsToFinish() async {
        while activeCloudOperationCount > 0 {
            try? await Task.sleep(for: .milliseconds(50))
        }
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
            if appLockCredential != nil {
                store.clearAppLockCredential()
                appLockCredential = nil
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
        isScreenshotMode && ProcessInfo.processInfo.environment["PAYJOY_SCREENSHOT_PRO_LOCKED"] != "1"
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
                if error != nil {
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
            for await verification in Transaction.updates {
                guard let self else { return }
                do {
                    try await storeKit.finishUpdatedTransaction(verification)
                    await refreshProEntitlement(successMessage: L10n.t("会员权益已更新。"))
                } catch {
                    proPurchaseMessage = L10n.t("购买校验未通过，请稍后重试或联系支持。")
                }
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

enum AppNotificationRoute: String, Sendable {
    case closingReceipt
}

final class AppNotificationResponseHandler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = AppNotificationResponseHandler()
    static let routeUserInfoKey = "payjoy.route"

    @MainActor var routeHandler: ((AppNotificationRoute) -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    static func route(from userInfo: [AnyHashable: Any]) -> AppNotificationRoute? {
        guard let rawValue = userInfo[routeUserInfoKey] as? String else { return nil }
        return AppNotificationRoute(rawValue: rawValue)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let route = Self.route(from: response.notification.request.content.userInfo) else { return }
        await MainActor.run { [weak self] in
            self?.routeHandler?(route)
        }
    }
}

final class WorkReminderScheduler {
    private let center: UNUserNotificationCenter
    private let startPrefix = "payjoy.work.start"
    private let endPrefix = "payjoy.work.end"
    private let lunchStartPrefix = "payjoy.lunch.start"
    private let lunchEndPrefix = "payjoy.lunch.end"
    private let goalPrefix = "payjoy.goal.complete"

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
                weekday: weekday,
                route: .closingReceipt
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

    func scheduleGoalReminder(goal: WishExperience, progress: PersonalGoalProgress, settings: SalarySettings, now: Date) {
        cancelGoalReminder()
        guard progress.progress < 1,
              let completionDate = progress.estimatedCompletionDate,
              let triggerDate = Self.goalReminderFireDate(
                completionDate: completionDate,
                workEnd: settings.workEnd,
                now: now
              ) else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)

        let content = UNMutableNotificationContent()
        content.title = L10n.t("目标达成提醒")
        content.body = L10n.format("%@ 就要达成了，今天也辛苦了。", goal.title)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: goalPrefix, content: content, trigger: trigger))
    }

    static func goalReminderFireDate(
        completionDate: Date,
        workEnd: WorkTime,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: completionDate)
        components.hour = workEnd.hour
        components.minute = workEnd.minute
        components.second = 0
        guard let triggerDate = calendar.date(from: components), triggerDate > now else { return nil }
        return triggerDate
    }

    func cancelGoalReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [goalPrefix])
    }

    private func addReminder(
        id: String,
        title: String,
        body: String,
        time: WorkTime,
        weekday: Int,
        route: AppNotificationRoute? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let route {
            content.userInfo[AppNotificationResponseHandler.routeUserInfoKey] = route.rawValue
        }

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
