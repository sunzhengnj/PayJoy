import XCTest
@testable import PayJoy

final class SalaryCalculatorTests: XCTestCase {
    private var calendar: Calendar!
    private var calculator: SalaryCalculator!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calculator = SalaryCalculator(calendar: calendar)
    }

    func testSalaryModesCalculateDailyIncome() {
        var settings = SalarySettings.defaultValue

        settings.salaryType = .monthly
        settings.salaryAmount = 10_000
        XCTAssertEqual(calculator.dailySalary(for: settings), 10_000 / 21.75, accuracy: 0.001)

        settings.salaryType = .yearly
        settings.salaryAmount = 240_000
        XCTAssertEqual(calculator.dailySalary(for: settings), 240_000 / 12 / 21.75, accuracy: 0.001)

        settings.salaryType = .daily
        settings.salaryAmount = 500
        XCTAssertEqual(calculator.dailySalary(for: settings), 500, accuracy: 0.001)

        settings.salaryType = .hourly
        settings.salaryAmount = 100
        XCTAssertEqual(calculator.dailySalary(for: settings), 900, accuracy: 0.001)
    }

    func testBeforeWorkWorkingAndAfterWorkStates() {
        let settings = SalarySettings.defaultValue

        let before = calculator.snapshot(for: date("2026-05-18 08:30:00"), settings: settings)
        XCTAssertEqual(before.status, .beforeWork)
        XCTAssertEqual(before.todayEarned, 0, accuracy: 0.001)

        let working = calculator.snapshot(for: date("2026-05-18 10:00:00"), settings: settings)
        XCTAssertEqual(working.status, .working)
        XCTAssertGreaterThan(working.todayEarned, 0)
        XCTAssertLessThan(working.todayEarned, working.todayTotal)

        let after = calculator.snapshot(for: date("2026-05-18 18:00:00"), settings: settings)
        XCTAssertEqual(after.status, .afterWork)
        XCTAssertEqual(after.todayEarned, after.todayTotal, accuracy: 0.001)
        XCTAssertEqual(after.progress, 1, accuracy: 0.001)
    }

    func testLunchDeductionPausesEarningsAndProgress() {
        var settings = SalarySettings.defaultValue
        settings.deductLunch = true

        let lunch = calculator.snapshot(for: date("2026-05-18 12:30:00"), settings: settings)
        let beforeLunchEnd = calculator.snapshot(for: date("2026-05-18 12:59:00"), settings: settings)

        XCTAssertEqual(lunch.status, .lunchBreak)
        XCTAssertEqual(lunch.todayEarned, beforeLunchEnd.todayEarned, accuracy: 0.5)
        XCTAssertEqual(calculator.workingSecondsPerDay(settings: settings), 8 * 3_600, accuracy: 0.001)
    }

    func testWeekendIsRestDay() {
        let snapshot = calculator.snapshot(for: date("2026-05-17 10:00:00"), settings: .defaultValue)
        XCTAssertEqual(snapshot.status, .restDay)
        XCTAssertEqual(snapshot.todayEarned, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.progress, 0, accuracy: 0.001)
    }

    func testCustomWorkdaysCanIncludeSunday() {
        var settings = SalarySettings.defaultValue
        settings.workdays = [Workday.sunday.rawValue]

        let snapshot = calculator.snapshot(for: date("2026-05-17 10:00:00"), settings: settings)

        XCTAssertEqual(snapshot.status, .working)
        XCTAssertGreaterThan(snapshot.todayEarned, 0)
    }

    func testOvertimeDateDoesNotCountRestDayAsPaidWork() {
        let sunday = date("2026-05-17 10:00:00")
        let snapshot = calculator.snapshot(
            for: sunday,
            settings: .defaultValue,
            overtimeDateKeys: [calculator.dateKey(for: sunday)]
        )

        XCTAssertEqual(snapshot.status, .restDay)
        XCTAssertEqual(snapshot.todayEarned, 0, accuracy: 0.001)
    }

    func testOvertimeSummaryCountsMonthlyRecords() {
        let firstStart = date("2026-05-17 18:00:00")
        let firstEnd = date("2026-05-17 20:30:00")
        let secondStart = date("2026-05-23 19:00:00")
        let secondEnd = date("2026-05-23 21:00:00")
        let juneStart = date("2026-06-07 18:00:00")
        let summary = calculator.overtimeSummary(
            in: .month,
            date: date("2026-05-30 12:00:00"),
            now: date("2026-05-30 12:00:00"),
            overtimeRecords: [
                OvertimeRecord(id: "may-1", startAt: firstStart, endAt: firstEnd),
                OvertimeRecord(id: "may-2", startAt: secondStart, endAt: secondEnd),
                OvertimeRecord(id: "jun-1", startAt: juneStart, endAt: juneStart.addingTimeInterval(3_600))
            ]
        )

        XCTAssertEqual(summary.count, 2)
        XCTAssertEqual(summary.totalHours, 4.5, accuracy: 0.001)
        XCTAssertEqual(summary.records.map(\.id), ["may-2", "may-1"])
    }

    func testOvertimeSummaryIncludesActiveRecordUntilNow() {
        let summary = calculator.overtimeSummary(
            in: .month,
            date: date("2026-05-30 12:00:00"),
            now: date("2026-05-30 21:15:00"),
            overtimeRecords: [
                OvertimeRecord(id: "active", startAt: date("2026-05-30 18:00:00"), endAt: nil)
            ]
        )

        XCTAssertEqual(summary.count, 1)
        XCTAssertTrue(summary.hasActiveRecord)
        XCTAssertEqual(summary.totalHours, 3.25, accuracy: 0.001)
    }

    func testBoundaryTimesDoNotExceedDaySalary() {
        let settings = SalarySettings.defaultValue
        let atStart = calculator.snapshot(for: date("2026-05-18 09:00:00"), settings: settings)
        let atEnd = calculator.snapshot(for: date("2026-05-18 18:00:00"), settings: settings)

        XCTAssertEqual(atStart.todayEarned, 0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(atEnd.todayEarned, atEnd.todayTotal)
        XCTAssertGreaterThanOrEqual(atEnd.remainingToday, 0)
    }

    func testPeriodBreakdownCountsWorkdays() {
        let settings = SalarySettings.defaultValue
        let breakdown = calculator.periodBreakdown(for: .month, date: date("2026-05-18 12:00:00"), settings: settings)

        XCTAssertEqual(breakdown.totalWorkdays, 21)
        XCTAssertEqual(breakdown.elapsedFullWorkdays, 11)
        XCTAssertEqual(breakdown.remainingWorkdays, 10)
        XCTAssertEqual(breakdown.completedWorkdayEquivalent, 11 + (3.0 / 9.0), accuracy: 0.001)
    }

    func testPeriodBreakdownOnRestDayDoesNotCountToday() {
        let settings = SalarySettings.defaultValue
        let breakdown = calculator.periodBreakdown(for: .today, date: date("2026-05-17 12:00:00"), settings: settings)

        XCTAssertEqual(breakdown.totalWorkdays, 0)
        XCTAssertEqual(breakdown.remainingWorkdays, 0)
        XCTAssertEqual(breakdown.completedWorkdayEquivalent, 0, accuracy: 0.001)
    }

    func testMonthlySalaryCompletesWhenMonthHasNoRemainingWorkdays() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .monthly
        settings.salaryAmount = 10_000
        settings.monthlyPaidDays = 21.75

        let earnings = calculator.periodEarnings(for: .month, date: date("2026-05-30 22:00:00"), settings: settings)
        let breakdown = calculator.periodBreakdown(for: .month, date: date("2026-05-30 22:00:00"), settings: settings)

        XCTAssertEqual(breakdown.totalWorkdays, 21)
        XCTAssertEqual(breakdown.remainingWorkdays, 0)
        XCTAssertEqual(earnings.projected, 10_000, accuracy: 0.001)
        XCTAssertEqual(earnings.earned, 10_000, accuracy: 0.001)
        XCTAssertEqual(earnings.progress, 1, accuracy: 0.001)
    }

    func testMonthlySalaryUsesActualMonthWorkdayProgress() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .monthly
        settings.salaryAmount = 10_000
        settings.monthlyPaidDays = 21.75

        let earnings = calculator.periodEarnings(for: .month, date: date("2026-05-18 12:00:00"), settings: settings)
        let expectedProgress = (11 + 3.0 / 9.0) / 21

        XCTAssertEqual(earnings.projected, 10_000, accuracy: 0.001)
        XCTAssertEqual(earnings.progress, expectedProgress, accuracy: 0.001)
        XCTAssertEqual(earnings.earned, 10_000 * expectedProgress, accuracy: 0.001)
    }

    func testSalaryCalendarDistributesMonthlySalaryAcrossActualWorkdays() {
        var settings = SalarySettings.defaultValue
        settings.salaryType = .monthly
        settings.salaryAmount = 10_000

        let amount = calculator.scheduledSalaryAmount(for: date("2026-05-18 12:00:00"), settings: settings)

        XCTAssertEqual(amount, 10_000 / 21, accuracy: 0.001)
    }

    func testSalaryCalendarUsesSavedSnapshotForPastDay() {
        var originalSettings = SalarySettings.defaultValue
        originalSettings.salaryAmount = 10_000
        let day = date("2026-05-18 18:00:00")
        let savedAmount = calculator.scheduledSalaryAmount(for: day, settings: originalSettings)
        let record = SalaryDayRecord(
            dateKey: calculator.dateKey(for: day),
            kind: .normal,
            note: "",
            settingsSnapshot: originalSettings,
            scheduledAmount: savedAmount,
            earnedAmount: savedAmount,
            isEstimated: false,
            updatedAt: day
        )
        var currentSettings = originalSettings
        currentSettings.salaryAmount = 20_000

        let calendarDay = calculator.salaryCalendarDay(
            for: day,
            now: date("2026-06-01 12:00:00"),
            settings: currentSettings,
            record: record
        )

        XCTAssertEqual(calendarDay.earnedAmount, savedAmount, accuracy: 0.001)
        XCTAssertFalse(calendarDay.isEstimated)
    }

    func testSalaryCalendarCompletesTodayAfterEarlyLeave() {
        let settings = SalarySettings.defaultValue
        let now = date("2026-05-18 12:00:00")
        let dateKey = calculator.dateKey(for: now)

        let calendarDay = calculator.salaryCalendarDay(
            for: now,
            now: now,
            settings: settings,
            record: nil,
            completedDateKeys: [dateKey]
        )

        XCTAssertEqual(calendarDay.earnedAmount, calendarDay.scheduledAmount, accuracy: 0.001)
    }

    func testUnpaidLeaveRemovesDayFromSalaryMonthProjection() {
        let settings = SalarySettings.defaultValue
        let leaveDate = date("2026-05-18 12:00:00")
        let record = SalaryDayRecord(
            dateKey: calculator.dateKey(for: leaveDate),
            kind: .unpaidLeave,
            note: "请假",
            settingsSnapshot: settings,
            scheduledAmount: 0,
            earnedAmount: 0,
            isEstimated: true,
            updatedAt: leaveDate
        )

        let summary = calculator.salaryMonthSummary(
            for: leaveDate,
            now: date("2026-05-31 23:00:00"),
            settings: settings,
            records: [record]
        )

        XCTAssertEqual(summary.paidDayCount, 20)
        XCTAssertEqual(summary.projectedAmount, 10_000 - (10_000 / 21), accuracy: 0.001)
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)!
    }
}
