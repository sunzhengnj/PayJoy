import Foundation

final class SalaryCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(
        for date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = [],
        earlyLeaveDateKeys: Set<String> = []
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

        if earlyLeaveDateKeys.contains(dateKey(for: date)) {
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
        overtimeDateKeys: Set<String> = [],
        earlyLeaveDateKeys: Set<String> = []
    ) -> PeriodEarnings {
        let today = snapshot(for: date, settings: settings, overtimeDateKeys: overtimeDateKeys, earlyLeaveDateKeys: earlyLeaveDateKeys)
        let daySalary = dailySalary(for: settings)

        switch period {
        case .today:
            return PeriodEarnings(earned: today.todayEarned, projected: today.todayTotal, progress: today.progress)
        case .month:
            let regularToday = snapshot(for: date, settings: settings, earlyLeaveDateKeys: earlyLeaveDateKeys)
            let projected = settings.salaryType == .monthly ? settings.salaryAmount : daySalary * settings.monthlyPaidDays
            if settings.salaryType == .monthly || settings.salaryType == .yearly {
                return fixedSalaryPeriodEarnings(
                    projected: projected,
                    component: .month,
                    date: date,
                    settings: settings,
                    todayProgress: regularToday.progress
                )
            }
            let elapsedFullWorkdays = workdaysElapsed(in: .month, before: date, settings: settings, overtimeDateKeys: [])
            let earned = Double(elapsedFullWorkdays) * daySalary + regularToday.todayEarned
            return PeriodEarnings(earned: min(projected, earned), projected: projected, progress: projected > 0 ? min(1, earned / projected) : 0)
        case .year:
            let regularToday = snapshot(for: date, settings: settings, earlyLeaveDateKeys: earlyLeaveDateKeys)
            let projected = annualSalary(for: settings)
            if settings.salaryType == .monthly || settings.salaryType == .yearly {
                return fixedSalaryPeriodEarnings(
                    projected: projected,
                    component: .year,
                    date: date,
                    settings: settings,
                    todayProgress: regularToday.progress
                )
            }
            let elapsedFullWorkdays = workdaysElapsed(in: .year, before: date, settings: settings, overtimeDateKeys: [])
            let earned = Double(elapsedFullWorkdays) * daySalary + regularToday.todayEarned
            return PeriodEarnings(earned: min(projected, earned), projected: projected, progress: projected > 0 ? min(1, earned / projected) : 0)
        }
    }

    func periodBreakdown(
        for period: StatsPeriod,
        date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = [],
        earlyLeaveDateKeys: Set<String> = []
    ) -> PeriodBreakdown {
        let today = snapshot(for: date, settings: settings, overtimeDateKeys: overtimeDateKeys, earlyLeaveDateKeys: earlyLeaveDateKeys)

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
            let regularToday = snapshot(for: date, settings: settings, earlyLeaveDateKeys: earlyLeaveDateKeys)
            return periodBreakdown(in: .month, date: date, settings: settings, overtimeDateKeys: [], todayProgress: regularToday.progress)
        case .year:
            let regularToday = snapshot(for: date, settings: settings, earlyLeaveDateKeys: earlyLeaveDateKeys)
            return periodBreakdown(in: .year, date: date, settings: settings, overtimeDateKeys: [], todayProgress: regularToday.progress)
        }
    }

    func overtimeSummary(
        in component: Calendar.Component,
        date: Date,
        now: Date,
        overtimeRecords: [OvertimeRecord]
    ) -> OvertimeSummary {
        let interval = periodInterval(for: component, date: date)
        let records = overtimeRecords.filter { record in
            record.startAt >= interval.start && record.startAt < interval.end
        }
        .sorted { $0.startAt > $1.startAt }
        let totalSeconds = records.reduce(0) { $0 + $1.duration(until: now) }

        return OvertimeSummary(records: records, totalSeconds: totalSeconds)
    }

    func dailySalary(for settings: SalarySettings) -> Double {
        switch settings.salaryType {
        case .yearly:
            return settings.salaryAmount / 12 / settings.monthlyPaidDays
        case .monthly:
            return settings.salaryAmount / settings.monthlyPaidDays
        case .daily:
            return settings.salaryAmount
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

    func defaultSalaryDayKind(for date: Date, settings: SalarySettings) -> SalaryDayKind {
        isRegularWorkday(date, settings: settings) ? .normal : .rest
    }

    func scheduledSalaryAmount(for date: Date, settings: SalarySettings) -> Double {
        switch settings.salaryType {
        case .monthly, .yearly:
            let interval = periodInterval(for: .month, date: date)
            var cursor = interval.start
            var workdayCount = 0
            while cursor < interval.end {
                if isRegularWorkday(cursor, settings: settings) {
                    workdayCount += 1
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
            }
            guard workdayCount > 0 else { return 0 }
            let monthlyAmount = settings.salaryType == .monthly ? settings.salaryAmount : settings.salaryAmount / 12
            return monthlyAmount / Double(workdayCount)
        case .daily, .hourly:
            return dailySalary(for: settings)
        }
    }

    func salaryCalendarDay(
        for date: Date,
        now: Date,
        settings: SalarySettings,
        record: SalaryDayRecord?,
        completedDateKeys: Set<String> = []
    ) -> SalaryCalendarDay {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let effectiveSettings = record?.settingsSnapshot ?? settings
        let kind = record?.kind ?? defaultSalaryDayKind(for: day, settings: effectiveSettings)
        let scheduledAmount = record?.scheduledAmount ?? amount(
            for: kind,
            date: day,
            settings: effectiveSettings
        )
        let isFuture = day > today
        let earnedAmount: Double

        if isFuture {
            earnedAmount = 0
        } else if day == today {
            switch kind {
            case .normal:
                earnedAmount = completedDateKeys.contains(dateKey(for: day))
                    ? scheduledAmount
                    : scheduledAmount * workdayProgress(at: now, settings: effectiveSettings)
            case .paidLeave:
                earnedAmount = scheduledAmount
            case .unpaidLeave, .rest:
                earnedAmount = 0
            }
        } else {
            earnedAmount = record?.earnedAmount ?? scheduledAmount
        }

        return SalaryCalendarDay(
            date: day,
            dateKey: dateKey(for: day),
            kind: kind,
            note: record?.note ?? "",
            scheduledAmount: scheduledAmount,
            earnedAmount: earnedAmount,
            isEstimated: record?.isEstimated ?? true,
            isFuture: isFuture,
            hasSavedRecord: record != nil
        )
    }

    func salaryMonthSummary(
        for month: Date,
        now: Date,
        settings: SalarySettings,
        records: [SalaryDayRecord],
        completedDateKeys: Set<String> = []
    ) -> SalaryMonthSummary {
        let interval = periodInterval(for: .month, date: month)
        var recordsByDate: [String: SalaryDayRecord] = [:]
        for record in records {
            let existingUpdate = recordsByDate[record.dateKey]?.updatedAt ?? .distantPast
            if existingUpdate < record.updatedAt {
                recordsByDate[record.dateKey] = record
            }
        }
        var cursor = interval.start
        var earnedAmount = 0.0
        var projectedAmount = 0.0
        var paidDayCount = 0
        var estimatedDayCount = 0

        while cursor < interval.end {
            let record = recordsByDate[dateKey(for: cursor)]
            let day = salaryCalendarDay(
                for: cursor,
                now: now,
                settings: settings,
                record: record,
                completedDateKeys: completedDateKeys
            )
            earnedAmount += day.earnedAmount
            projectedAmount += day.scheduledAmount
            if day.kind == .normal || day.kind == .paidLeave {
                paidDayCount += 1
            }
            if day.isEstimated, !day.isFuture {
                estimatedDayCount += 1
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }

        return SalaryMonthSummary(
            earnedAmount: earnedAmount,
            projectedAmount: projectedAmount,
            paidDayCount: paidDayCount,
            estimatedDayCount: estimatedDayCount
        )
    }

    private func annualSalary(for settings: SalarySettings) -> Double {
        switch settings.salaryType {
        case .yearly:
            return settings.salaryAmount
        case .monthly:
            return settings.salaryAmount * 12
        case .daily:
            return settings.salaryAmount * settings.monthlyPaidDays * 12
        case .hourly:
            return dailySalary(for: settings) * settings.monthlyPaidDays * 12
        }
    }

    private func fixedSalaryPeriodEarnings(
        projected: Double,
        component: Calendar.Component,
        date: Date,
        settings: SalarySettings,
        todayProgress: Double
    ) -> PeriodEarnings {
        let breakdown = periodBreakdown(in: component, date: date, settings: settings, overtimeDateKeys: [], todayProgress: todayProgress)
        guard projected > 0, breakdown.totalWorkdays > 0 else {
            return PeriodEarnings(earned: 0, projected: projected, progress: 0)
        }

        let progress = min(1, max(0, breakdown.completedWorkdayEquivalent / Double(breakdown.totalWorkdays)))
        return PeriodEarnings(earned: projected * progress, projected: projected, progress: progress)
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

    private func amount(for kind: SalaryDayKind, date: Date, settings: SalarySettings) -> Double {
        switch kind {
        case .normal, .paidLeave:
            return scheduledSalaryAmount(for: date, settings: settings)
        case .unpaidLeave, .rest:
            return 0
        }
    }

    private func workdayProgress(at date: Date, settings: SalarySettings) -> Double {
        let totalSeconds = workingSecondsPerDay(settings: settings)
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, workedSecondsUntil(date, settings: settings) / totalSeconds))
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
        isRegularWorkday(date, settings: settings)
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
        let interval = periodInterval(for: component, date: date)

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
        let interval = periodInterval(for: component, date: date)

        let total = workdays(in: interval, settings: settings, overtimeDateKeys: overtimeDateKeys)
        let elapsed = workdaysElapsed(in: component, before: date, settings: settings, overtimeDateKeys: overtimeDateKeys)
        let todayIsWorkday = isWorkday(date, settings: settings, overtimeDateKeys: overtimeDateKeys)
        let completed = Double(elapsed) + (todayIsWorkday ? todayProgress : 0)
        let completedTodayOffset = todayIsWorkday && todayProgress >= 1 ? 1 : 0
        let remaining = max(0, total - elapsed - completedTodayOffset)

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

    private func periodInterval(for component: Calendar.Component, date: Date) -> DateInterval {
        switch component {
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)
        case .year:
            return calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, end: date)
        default:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            return DateInterval(start: start, end: end)
        }
    }
}
