import XCTest
@testable import PayJoy

final class FocusSessionTests: XCTestCase {
    @MainActor
    func testClockTitleKeepsTimeMeaningWhilePausedInEveryLanguage() throws {
        let defaults = UserDefaults.standard
        let key = "payjoy.app.preferences"
        let original = defaults.data(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }

        let cases: [(AppLanguage, String, String, String)] = [
            (.zhHans, "本段剩余", "距下班", "专注已暂停"),
            (.zhHant, "本段剩餘", "距下班", "專注已暫停"),
            (.en, "Focus remaining", "Until off work", "Focus paused"),
            (.ja, "残り時間", "終業まで", "集中は一時停止中"),
            (.ko, "집중 남은 시간", "퇴근까지", "집중 일시 정지")
        ]
        for (language, remaining, offWork, paused) in cases {
            var preferences = AppPreferences.defaultValue
            preferences.appLanguage = language
            defaults.set(try JSONEncoder().encode(preferences), forKey: key)
            for (showsOffWorkTime, meaning) in [(false, remaining), (true, offWork)] {
                XCTAssertEqual(FocusView.clockTitle(isPaused: false, showsOffWorkTime: showsOffWorkTime), meaning)
                XCTAssertEqual(FocusView.clockTitle(isPaused: true, showsOffWorkTime: showsOffWorkTime), "\(meaning) · \(paused)")
            }
        }
    }

    @MainActor
    func testRestoredPausedFocusUsesFocusTabBeforePresentingTimer() {
        let suiteName = "PayJoyTests.FocusRestore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = FocusSession(startedAt: start, duration: 120)
        session.pause(at: start.addingTimeInterval(30))
        store.saveFocusData(FocusData(active: session, prefersDarkBackground: true))

        let state = AppState(
            store: store,
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil),
            now: start.addingTimeInterval(90)
        )

        XCTAssertEqual(state.selectedTab, .focus, "The restoring cover must not reveal salary content underneath")
        XCTAssertTrue(state.isFocusPresented)
        XCTAssertEqual(state.focusData.active?.id, session.id)
        XCTAssertEqual(state.focusData.active?.remaining(at: state.now), 90)
        XCTAssertTrue(state.focusData.prefersDarkBackground)
    }

    @MainActor
    func testRestoredResultUsesFocusTabWithoutSettlingAgain() {
        let suiteName = "PayJoyTests.FocusResultRestore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = FocusSession(startedAt: start, duration: 120)
        var data = FocusData(active: session)
        _ = data.finish(at: start.addingTimeInterval(120), completed: true)
        store.saveFocusData(data)

        let state = AppState(
            store: store,
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil),
            now: start.addingTimeInterval(180)
        )

        XCTAssertEqual(state.selectedTab, .focus, "Restoring a result must keep earnings out of the launch transition")
        XCTAssertTrue(state.isFocusPresented)
        state.reconcileFocusSession()
        XCTAssertEqual(state.focusData.pendingResult?.id, session.id)
        XCTAssertEqual(state.focusData.records.count, 1)
    }

    func testCustomFocusMinutesAcceptFullWidthDigits() {
        XCTAssertEqual(FocusSession.customMinutes(from: "２５"), 25)
        XCTAssertEqual(FocusSession.customMinutes(from: "４５"), 45)
        XCTAssertEqual(FocusSession.customMinutes(from: "２４０"), 240)
        XCTAssertEqual(FocusSession.customMinutes(from: "2５"), 25)
    }

    func testCustomFocusMinutesAllowSurroundingWhitespace() {
        XCTAssertEqual(FocusSession.customMinutes(from: " 25\n"), 25)
        XCTAssertEqual(FocusSession.customMinutes(from: "　４５　"), 45)
        XCTAssertEqual(FocusSession.customMinutes(from: "1"), 1)
    }

    func testCustomFocusMinutesRejectInvalidOrOutOfRangeInput() {
        for input in ["", "　", "0", "０", "241", "２４１", "-25", "25.5", "２５．５", "2 5", "25 minutes", "1,5", "999999999999999999999999999"] {
            XCTAssertNil(FocusSession.customMinutes(from: input), input)
        }
    }

    func testPauseAndResumePreserveFocusedTime() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = FocusSession(startedAt: start, duration: 25 * 60)

        session.pause(at: start.addingTimeInterval(6 * 60))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(30 * 60)), 19 * 60)
        XCTAssertEqual(session.focusedDuration(at: start.addingTimeInterval(30 * 60)), 6 * 60)

        session.resume(at: start.addingTimeInterval(30 * 60))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(35 * 60)), 14 * 60)
        XCTAssertEqual(session.focusedDuration(at: start.addingTimeInterval(35 * 60)), 11 * 60)
    }

    func testCompletionCreatesOnlyOneRecord() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = FocusSession(startedAt: start, duration: 25 * 60)
        var data = FocusData(active: session)

        XCTAssertNotNil(data.finish(at: session.endDate, completed: true))
        XCTAssertNil(data.finish(at: session.endDate.addingTimeInterval(5), completed: true))
        XCTAssertEqual(data.records.count, 1)
        XCTAssertEqual(data.records[0].focusedDuration, 25 * 60)
        XCTAssertEqual(data.pendingResultID, session.id)
    }

    func testPausedSessionSurvivesStorageRoundTrip() {
        let defaults = UserDefaults(suiteName: "payjoy.focus.tests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = FocusSession(startedAt: start, duration: 45 * 60)
        session.pause(at: start.addingTimeInterval(10 * 60))
        store.saveFocusData(FocusData(active: session))

        let restored = store.loadFocusData().active
        XCTAssertEqual(restored?.id, session.id)
        XCTAssertEqual(restored?.remaining(at: start.addingTimeInterval(90 * 60)), 35 * 60)
    }

    func testRestoredPausedSessionResumesAndSettlesOnce() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = FocusSession(startedAt: start, duration: 25 * 60)
        session.pause(at: start.addingTimeInterval(6 * 60))
        let stored = try JSONEncoder().encode(FocusData(active: session))
        var restored = try JSONDecoder().decode(FocusData.self, from: stored)

        restored.active?.resume(at: start.addingTimeInterval(30 * 60))
        let end = start.addingTimeInterval(49 * 60)
        let first = restored.finish(at: end, completed: true)

        XCTAssertEqual(first?.focusedDuration, 25 * 60)
        XCTAssertEqual(first?.endedAt, end)
        XCTAssertNil(restored.finish(at: end.addingTimeInterval(1), completed: true))
        XCTAssertEqual(restored.records.count, 1)
    }

    func testFocusUntilOffWorkKeepsOriginalEndAfterPause() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = FocusSession(startedAt: start, duration: 20 * 60, endsAtWork: true)
        let originalEnd = session.endDate

        session.pause(at: start.addingTimeInterval(5 * 60))
        session.resume(at: start.addingTimeInterval(10 * 60))

        XCTAssertEqual(session.endDate, originalEnd)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(15 * 60)), 5 * 60)
        XCTAssertEqual(session.focusedDuration(at: originalEnd), 15 * 60)
    }

    func testFocusUntilOffWorkPausedAtEndKeepsOnlyFocusedTime() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = FocusSession(startedAt: start, duration: 20 * 60, endsAtWork: true)
        session.pause(at: start.addingTimeInterval(5 * 60))
        var data = FocusData(active: session)

        let record = data.finish(at: session.endDate, completed: false)

        XCTAssertEqual(record?.focusedDuration, 5 * 60)
        XCTAssertEqual(record?.endedAt, session.endDate)
    }

    func testFocusUntilOffWorkPausedThenCompletedSettlesOnce() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = FocusSession(startedAt: start, duration: 18 * 60, endsAtWork: true)
        session.pause(at: start.addingTimeInterval(8 * 60))
        session.resume(at: start.addingTimeInterval(10 * 60))
        var data = FocusData(active: session)

        let record = data.finish(at: session.endDate, completed: true)

        XCTAssertEqual(session.endDate, start.addingTimeInterval(18 * 60))
        XCTAssertEqual(record?.focusedDuration, 16 * 60)
        XCTAssertEqual(record?.id, session.id)
        XCTAssertNil(data.finish(at: session.endDate.addingTimeInterval(1), completed: true))
        XCTAssertEqual(data.records.count, 1)
    }

    func testFixedFocusCrossingMidnightKeepsPausedTimeOutOfResult() {
        let start = ISO8601DateFormatter().date(from: "2026-10-16T23:50:00Z")!
        var session = FocusSession(startedAt: start, duration: 25 * 60)
        session.pause(at: start.addingTimeInterval(5 * 60))
        session.resume(at: start.addingTimeInterval(15 * 60))

        XCTAssertEqual(session.endDate, start.addingTimeInterval(35 * 60))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(25 * 60)), 10 * 60)

        var data = FocusData(active: session)
        let record = data.finish(at: session.endDate, completed: true)
        XCTAssertEqual(record?.focusedDuration, 25 * 60)
        XCTAssertEqual(record?.endedAt, start.addingTimeInterval(35 * 60))
    }

    func testEndingAfterSystemClockMovesBackwardDoesNotReverseRecordDates() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var data = FocusData(active: FocusSession(startedAt: start, duration: 25 * 60))

        let record = data.finish(at: start.addingTimeInterval(-90), completed: false)

        XCTAssertEqual(record?.endedAt, start)
        XCTAssertEqual(record?.focusedDuration, 0)
        XCTAssertNil(data.finish(at: start, completed: false))
        XCTAssertEqual(data.records.count, 1)
    }

    @MainActor
    func testPaydayCelebrationWaitsUntilFocusResultIsDismissed() {
        let suiteName = "PayJoyTests.FocusPayday.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults, sharedDefaults: nil)
        let state = AppState(
            store: store,
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil)
        )
        var preferences = state.preferences
        preferences.hasCompletedInitialSetup = true
        preferences.remindersEnabled = false
        preferences.lunchRemindersEnabled = false
        state.preferences = preferences
        var settings = state.settings
        settings.paydayDay = Calendar.current.component(.day, from: Date())
        state.settings = settings
        state.focusData.active = FocusSession(startedAt: Date().addingTimeInterval(-60), duration: 25 * 60)
        state.isFocusPresented = true

        state.applicationDidBecomeActive()
        XCTAssertFalse(state.shouldPresentPaydayCelebration)
        XCTAssertNil(store.lastPaydayCelebrationDate())

        state.endFocus()
        XCTAssertNotNil(state.focusData.pendingResult)
        XCTAssertFalse(state.shouldPresentPaydayCelebration)

        state.dismissFocusResult()
        XCTAssertFalse(state.shouldPresentPaydayCelebration)
        state.focusPresentationDidDismiss()
        XCTAssertTrue(state.shouldPresentPaydayCelebration)
        XCTAssertEqual(store.lastPaydayCelebrationDate(), state.todayDateKey)
    }

    @MainActor
    func testFocusResultOpensPaydayCelebrationBeforeClosingReceipt() {
        let suiteName = "PayJoyTests.FocusPaydayReceipt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 19))!
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil),
            now: date
        )
        var settings = state.settings
        settings.paydayDay = 17
        settings.workdays = Set(1...7)
        state.settings = settings
        var preferences = state.preferences
        preferences.hasCompletedInitialSetup = true
        state.preferences = preferences
        XCTAssertTrue(state.canOpenClosingReceipt)
        let session = FocusSession(startedAt: date.addingTimeInterval(-85 * 60), duration: 25 * 60, endsAtWork: true)
        var focusData = FocusData(active: session)
        _ = focusData.finish(at: session.endDate, completed: true)
        state.focusData = focusData
        XCTAssertNotNil(state.focusData.pendingResult)

        state.isFocusPresented = true
        state.dismissFocusResult(openClosingReceipt: true)
        XCTAssertFalse(state.shouldPresentPaydayCelebration)
        XCTAssertFalse(state.shouldPresentClosingReceipt)

        state.focusPresentationDidDismiss()
        XCTAssertTrue(state.shouldPresentPaydayCelebration)
        XCTAssertFalse(state.shouldPresentClosingReceipt)

        state.dismissPaydayCelebration()
        XCTAssertTrue(state.shouldPresentClosingReceipt)
    }

    @MainActor
    func testEmbeddedFocusResultOpensClosingReceiptWithoutCoverDismissal() {
        let suiteName = "PayJoyTests.EmbeddedFocusReceipt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 19))!
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil),
            now: date
        )
        var settings = state.settings
        settings.workdays = Set(1...7)
        state.settings = settings
        XCTAssertTrue(state.canOpenClosingReceipt)
        let session = FocusSession(startedAt: date.addingTimeInterval(-85 * 60), duration: 25 * 60, endsAtWork: true)
        var focusData = FocusData(active: session)
        _ = focusData.finish(at: session.endDate, completed: true)
        state.focusData = focusData
        XCTAssertNotNil(state.focusData.pendingResult)
        XCTAssertFalse(state.isFocusPresented)

        state.dismissFocusResult(openClosingReceipt: true)

        XCTAssertTrue(state.shouldPresentClosingReceipt)
    }

    @MainActor
    func testOldFocusNotificationOpensTabWithoutEmptyFullScreenCover() {
        let suiteName = "PayJoyTests.OldFocusNotification.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil)
        )
        state.selectedTab = .home
        state.focusData = FocusData()

        state.handleNotificationRoute(.focus)

        XCTAssertEqual(state.selectedTab, .focus)
        XCTAssertFalse(state.isFocusPresented)
    }

    @MainActor
    func testFocusNotificationStillOpensPendingResult() {
        let suiteName = "PayJoyTests.PendingFocusNotification.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let state = AppState(
            store: SettingsStore(defaults: defaults, sharedDefaults: nil),
            cloudKit: PayJoyCloudKitService(container: nil, keyValueStore: nil)
        )
        let startedAt = Date().addingTimeInterval(-25 * 60)
        let session = FocusSession(startedAt: startedAt, duration: 25 * 60)
        var data = FocusData(active: session)
        _ = data.finish(at: session.endDate, completed: true)
        state.focusData = data

        state.handleNotificationRoute(.focus)

        XCTAssertTrue(state.isFocusPresented)
        XCTAssertEqual(state.focusData.pendingResultID, session.id)
    }
}
