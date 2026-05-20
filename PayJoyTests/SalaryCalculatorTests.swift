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

    func testOvertimeDateCountsRestDayAsWorkday() {
        let sunday = date("2026-05-17 10:00:00")
        let snapshot = calculator.snapshot(
            for: sunday,
            settings: .defaultValue,
            overtimeDateKeys: [calculator.dateKey(for: sunday)]
        )

        XCTAssertEqual(snapshot.status, .working)
        XCTAssertGreaterThan(snapshot.todayEarned, 0)
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
        XCTAssertEqual(breakdown.remainingWorkdays, 9)
        XCTAssertEqual(breakdown.completedWorkdayEquivalent, 11 + (3.0 / 9.0), accuracy: 0.001)
    }

    func testPeriodBreakdownOnRestDayDoesNotCountToday() {
        let settings = SalarySettings.defaultValue
        let breakdown = calculator.periodBreakdown(for: .today, date: date("2026-05-17 12:00:00"), settings: settings)

        XCTAssertEqual(breakdown.totalWorkdays, 0)
        XCTAssertEqual(breakdown.remainingWorkdays, 0)
        XCTAssertEqual(breakdown.completedWorkdayEquivalent, 0, accuracy: 0.001)
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)!
    }
}
