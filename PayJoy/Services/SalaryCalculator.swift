import Foundation

final class SalaryCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(
        for date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = []
    ) -> EarningsSnapshot {
        let daySalary = dailySalary(for: settings)
        let totalSeconds = workingSecondsPerDay(settings: settings)
        let perSecond = totalSeconds > 0 ? daySalary / totalSeconds : 0

        guard isWorkday(date, settings: settings, overtimeDateKeys: overtimeDateKeys) else {
            return EarningsSnapshot(
                todayEarned: 0,
                todayTotal: daySalary,
                earnedPerSecond: perSecond,
                progress: 0,
                remainingToday: daySalary,
                secondsUntilOffWork: 0,
                status: .restDay
            )
        }

        let currentMinute = minuteOfDay(for: date)
        let start = settings.workStart.minutesFromStartOfDay
        let end = settings.workEnd.minutesFromStartOfDay
        let endDate = dateAt(minutesFromStartOfDay: end, matching: date)
        let rawRemaining = max(0, endDate.timeIntervalSince(date))

        if currentMinute < start {
            return EarningsSnapshot(
                todayEarned: 0,
                todayTotal: daySalary,
                earnedPerSecond: perSecond,
                progress: 0,
                remainingToday: daySalary,
                secondsUntilOffWork: rawRemaining,
                status: .beforeWork
            )
        }

        if currentMinute >= end {
            return EarningsSnapshot(
                todayEarned: daySalary,
                todayTotal: daySalary,
                earnedPerSecond: perSecond,
                progress: 1,
                remainingToday: 0,
                secondsUntilOffWork: 0,
                status: .afterWork
            )
        }

        let workedSeconds = workedSecondsUntil(date, settings: settings)
        let earned = min(daySalary, max(0, workedSeconds * perSecond))
        let status = isLunchBreak(date, settings: settings) ? WorkdayStatus.lunchBreak : .working

        return EarningsSnapshot(
            todayEarned: earned,
            todayTotal: daySalary,
            earnedPerSecond: perSecond,
            progress: totalSeconds > 0 ? min(1, max(0, workedSeconds / totalSeconds)) : 0,
            remainingToday: max(0, daySalary - earned),
            secondsUntilOffWork: rawRemaining,
            status: status
        )
    }

    func periodEarnings(
        for period: StatsPeriod,
        date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = []
    ) -> PeriodEarnings {
        let today = snapshot(for: date, settings: settings, overtimeDateKeys: overtimeDateKeys)
        let daySalary = dailySalary(for: settings)

        switch period {
        case .today:
            return PeriodEarnings(earned: today.todayEarned, projected: today.todayTotal, progress: today.progress)
        case .month:
            let elapsedFullWorkdays = workdaysElapsed(in: .month, before: date, settings: settings, overtimeDateKeys: overtimeDateKeys)
            let earned = Double(elapsedFullWorkdays) * daySalary + today.todayEarned
            let projected = settings.salaryType == .monthly ? settings.salaryAmount : daySalary * settings.monthlyPaidDays
            return PeriodEarnings(earned: min(projected, earned), projected: projected, progress: projected > 0 ? min(1, earned / projected) : 0)
        case .year:
            let elapsedFullWorkdays = workdaysElapsed(in: .year, before: date, settings: settings, overtimeDateKeys: overtimeDateKeys)
            let earned = Double(elapsedFullWorkdays) * daySalary + today.todayEarned
            let projected = annualSalary(for: settings)
            return PeriodEarnings(earned: min(projected, earned), projected: projected, progress: projected > 0 ? min(1, earned / projected) : 0)
        }
    }

    func periodBreakdown(
        for period: StatsPeriod,
        date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = []
    ) -> PeriodBreakdown {
        let today = snapshot(for: date, settings: settings, overtimeDateKeys: overtimeDateKeys)

        switch period {
        case .today:
            let total = isWorkday(date, settings: settings, overtimeDateKeys: overtimeDateKeys) ? 1 : 0
            let completed = total == 0 ? 0 : today.progress
            let remaining = total == 0 || today.status == .afterWork ? 0 : 1
            return PeriodBreakdown(
                elapsedFullWorkdays: today.status == .afterWork ? total : 0,
                totalWorkdays: total,
                remainingWorkdays: remaining,
                completedWorkdayEquivalent: completed
            )
        case .month:
            return periodBreakdown(in: .month, date: date, settings: settings, overtimeDateKeys: overtimeDateKeys, todayProgress: today.progress)
        case .year:
            return periodBreakdown(in: .year, date: date, settings: settings, overtimeDateKeys: overtimeDateKeys, todayProgress: today.progress)
        }
    }

    func dailySalary(for settings: SalarySettings) -> Double {
        switch settings.salaryType {
        case .yearly:
            return settings.salaryAmount / 12 / settings.monthlyPaidDays
        case .monthly:
            return settings.salaryAmount / settings.monthlyPaidDays
        case .hourly:
            return settings.salaryAmount * workingSecondsPerDay(settings: settings) / 3_600
        }
    }

    func workingSecondsPerDay(settings: SalarySettings) -> TimeInterval {
        let workMinutes = max(0, settings.workEnd.minutesFromStartOfDay - settings.workStart.minutesFromStartOfDay)
        let lunchMinutes = settings.deductLunch ? overlapMinutes(
            startA: settings.workStart.minutesFromStartOfDay,
            endA: settings.workEnd.minutesFromStartOfDay,
            startB: settings.lunchStart.minutesFromStartOfDay,
            endB: settings.lunchEnd.minutesFromStartOfDay
        ) : 0
        return TimeInterval(max(0, workMinutes - lunchMinutes) * 60)
    }

    private func annualSalary(for settings: SalarySettings) -> Double {
        switch settings.salaryType {
        case .yearly:
            return settings.salaryAmount
        case .monthly:
            return settings.salaryAmount * 12
        case .hourly:
            return dailySalary(for: settings) * settings.monthlyPaidDays * 12
        }
    }

    private func workedSecondsUntil(_ date: Date, settings: SalarySettings) -> TimeInterval {
        let current = minuteOfDay(for: date)
        let start = settings.workStart.minutesFromStartOfDay
        let end = settings.workEnd.minutesFromStartOfDay
        let clampedCurrent = min(max(current, start), end)
        var workedMinutes = max(0, clampedCurrent - start)

        if settings.deductLunch {
            let lunchStart = settings.lunchStart.minutesFromStartOfDay
            let lunchEnd = settings.lunchEnd.minutesFromStartOfDay
            workedMinutes -= overlapMinutes(startA: start, endA: clampedCurrent, startB: lunchStart, endB: lunchEnd)
        }

        let baseSeconds = TimeInterval(max(0, workedMinutes) * 60)
        return baseSeconds + secondsIntoCurrentMinute(date: date, settings: settings)
    }

    private func secondsIntoCurrentMinute(date: Date, settings: SalarySettings) -> TimeInterval {
        guard !isLunchBreak(date, settings: settings) else { return 0 }
        let current = minuteOfDay(for: date)
        let start = settings.workStart.minutesFromStartOfDay
        let end = settings.workEnd.minutesFromStartOfDay
        guard current >= start, current < end else { return 0 }
        return TimeInterval(calendar.component(.second, from: date))
    }

    private func isLunchBreak(_ date: Date, settings: SalarySettings) -> Bool {
        guard settings.deductLunch else { return false }
        let current = minuteOfDay(for: date)
        return current >= settings.lunchStart.minutesFromStartOfDay && current < settings.lunchEnd.minutesFromStartOfDay
    }

    private func overlapMinutes(startA: Int, endA: Int, startB: Int, endB: Int) -> Int {
        max(0, min(endA, endB) - max(startA, startB))
    }

    func isRegularWorkday(_ date: Date, settings: SalarySettings) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return settings.workdays.contains(weekday)
    }

    func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func isWorkday(_ date: Date, settings: SalarySettings, overtimeDateKeys: Set<String>) -> Bool {
        isRegularWorkday(date, settings: settings) || overtimeDateKeys.contains(dateKey(for: date))
    }

    private func minuteOfDay(for date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private func dateAt(minutesFromStartOfDay: Int, matching date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = minutesFromStartOfDay / 60
        components.minute = minutesFromStartOfDay % 60
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private func workdaysElapsed(
        in component: Calendar.Component,
        before date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String>
    ) -> Int {
        let interval: DateInterval
        switch component {
        case .month:
            interval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)
        case .year:
            interval = calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, end: date)
        default:
            interval = DateInterval(start: date, end: date)
        }

        var count = 0
        var cursor = interval.start
        while cursor < calendar.startOfDay(for: date) {
            if isWorkday(cursor, settings: settings, overtimeDateKeys: overtimeDateKeys) { count += 1 }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }
        return count
    }

    private func periodBreakdown(
        in component: Calendar.Component,
        date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String>,
        todayProgress: Double
    ) -> PeriodBreakdown {
        let interval: DateInterval
        switch component {
        case .month:
            interval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)
        case .year:
            interval = calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, end: date)
        default:
            interval = DateInterval(start: date, end: date)
        }

        let total = workdays(in: interval, settings: settings, overtimeDateKeys: overtimeDateKeys)
        let elapsed = workdaysElapsed(in: component, before: date, settings: settings, overtimeDateKeys: overtimeDateKeys)
        let todayIsWorkday = isWorkday(date, settings: settings, overtimeDateKeys: overtimeDateKeys)
        let completed = Double(elapsed) + (todayIsWorkday ? todayProgress : 0)
        let futureOffset = todayIsWorkday ? 1 : 0
        let remaining = max(0, total - elapsed - futureOffset)

        return PeriodBreakdown(
            elapsedFullWorkdays: elapsed,
            totalWorkdays: total,
            remainingWorkdays: remaining,
            completedWorkdayEquivalent: completed
        )
    }

    private func workdays(in interval: DateInterval, settings: SalarySettings, overtimeDateKeys: Set<String>) -> Int {
        var count = 0
        var cursor = interval.start
        while cursor < interval.end {
            if isWorkday(cursor, settings: settings, overtimeDateKeys: overtimeDateKeys) { count += 1 }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }
        return count
    }
}
