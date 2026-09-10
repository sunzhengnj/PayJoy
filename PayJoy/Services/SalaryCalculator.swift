import Foundation

final class SalaryCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func snapshot(
        for date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = [],
        earlyLeaveDateKeys: Set<String> = [],
        record: SalaryDayRecord? = nil
    ) -> EarningsSnapshot {
        let effectiveSettings = record?.settingsSnapshot ?? settings
        let daySalary = record?.scheduledAmount ?? dailySalary(for: effectiveSettings)
        let totalSeconds = workingSecondsPerDay(settings: effectiveSettings)
        let perSecond = totalSeconds > 0 ? daySalary / totalSeconds : 0

        if record?.kind == .paidLeave {
            return EarningsSnapshot(
                todayEarned: daySalary,
                todayTotal: daySalary,
                earnedPerSecond: 0,
                progress: 1,
                remainingToday: 0,
                secondsUntilOffWork: 0,
                status: .afterWork
            )
        }

        let isPaidWorkday = record?.kind == .normal
            || (record == nil && isWorkday(date, settings: effectiveSettings, overtimeDateKeys: overtimeDateKeys))
        guard isPaidWorkday else {
            return EarningsSnapshot(
                todayEarned: 0,
                todayTotal: 0,
                earnedPerSecond: 0,
                progress: 0,
                remainingToday: 0,
                secondsUntilOffWork: 0,
                status: .restDay
            )
        }

        let currentMinute = minuteOfDay(for: date)
        let start = effectiveSettings.workStart.minutesFromStartOfDay
        let end = effectiveSettings.workEnd.minutesFromStartOfDay
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

        let workedSeconds = workedSecondsUntil(date, settings: effectiveSettings)
        let earned = min(daySalary, max(0, workedSeconds * perSecond))
        let status = isLunchBreak(date, settings: effectiveSettings) ? WorkdayStatus.lunchBreak : .working

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

    func offDutySecondsUntilWorkStart(
        for date: Date,
        settings: SalarySettings,
        earlyLeaveDateKeys: Set<String> = [],
        records: [SalaryDayRecord] = []
    ) -> TimeInterval? {
        let recordsByDate = latestRecordsByDate(records)
        let currentSnapshot = snapshot(
            for: date,
            settings: settings,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            record: recordsByDate[dateKey(for: date)]
        )
        guard currentSnapshot.status == .beforeWork else { return nil }

        let startOfToday = calendar.startOfDay(for: date)
        let previousDayEnd = startOfToday.addingTimeInterval(-1)
        let previousSnapshot = snapshot(
            for: previousDayEnd,
            settings: settings,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            record: recordsByDate[dateKey(for: previousDayEnd)]
        )
        guard previousSnapshot.status == .afterWork else { return nil }

        let effectiveSettings = recordsByDate[dateKey(for: date)]?.settingsSnapshot ?? settings
        let workStart = dateAt(
            minutesFromStartOfDay: effectiveSettings.workStart.minutesFromStartOfDay,
            matching: date
        )
        let remaining = workStart.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    func periodEarnings(
        for period: StatsPeriod,
        date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = [],
        earlyLeaveDateKeys: Set<String> = [],
        records: [SalaryDayRecord] = [],
        actualSalaryRecords: [ActualSalaryRecord] = []
    ) -> PeriodEarnings {
        let recordsByDate = latestRecordsByDate(records)
        let today = snapshot(
            for: date,
            settings: settings,
            overtimeDateKeys: overtimeDateKeys,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            record: recordsByDate[dateKey(for: date)]
        )

        switch period {
        case .today:
            return PeriodEarnings(earned: today.todayEarned, projected: today.todayTotal, progress: today.progress)
        case .month:
            let summary = salaryMonthSummary(
                for: date,
                now: date,
                settings: settings,
                records: records,
                completedDateKeys: earlyLeaveDateKeys,
                actualSalaryRecords: actualSalaryRecords
            )
            return PeriodEarnings(
                earned: summary.earnedAmount,
                projected: summary.projectedAmount,
                progress: summary.progress
            )
        case .year:
            let interval = periodInterval(for: .year, date: date)
            var cursor = interval.start
            var earned = 0.0
            var projected = 0.0

            while cursor < interval.end {
                let summary = salaryMonthSummary(
                    for: cursor,
                    now: date,
                    settings: settings,
                    records: records,
                    completedDateKeys: earlyLeaveDateKeys,
                    actualSalaryRecords: actualSalaryRecords
                )
                earned += summary.earnedAmount
                projected += summary.projectedAmount
                cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? interval.end
            }

            return PeriodEarnings(
                earned: earned,
                projected: projected,
                progress: projected > 0 ? min(1, earned / projected) : 0
            )
        }
    }

    func periodBreakdown(
        for period: StatsPeriod,
        date: Date,
        settings: SalarySettings,
        overtimeDateKeys: Set<String> = [],
        earlyLeaveDateKeys: Set<String> = [],
        records: [SalaryDayRecord] = []
    ) -> PeriodBreakdown {
        let recordsByDate = latestRecordsByDate(records)
        let today = snapshot(
            for: date,
            settings: settings,
            overtimeDateKeys: overtimeDateKeys,
            earlyLeaveDateKeys: earlyLeaveDateKeys,
            record: recordsByDate[dateKey(for: date)]
        )

        switch period {
        case .today:
            let total = today.todayTotal > 0 ? 1 : 0
            let completed = total == 0 ? 0 : today.progress
            let remaining = total == 0 || today.status == .afterWork ? 0 : 1
            return PeriodBreakdown(
                elapsedFullWorkdays: today.status == .afterWork ? total : 0,
                totalWorkdays: total,
                remainingWorkdays: remaining,
                completedWorkdayEquivalent: completed
            )
        case .month, .year:
            let component: Calendar.Component = period == .month ? .month : .year
            return calendarPeriodBreakdown(
                in: component,
                date: date,
                settings: settings,
                recordsByDate: recordsByDate,
                completedDateKeys: earlyLeaveDateKeys
            )
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

    func refreshedFutureSalaryDayRecord(
        _ record: SalaryDayRecord,
        for date: Date,
        now: Date,
        settings: SalarySettings
    ) -> SalaryDayRecord {
        let day = calendar.startOfDay(for: date)
        guard record.isEstimated, day > calendar.startOfDay(for: now) else { return record }

        var refreshed = record
        refreshed.settingsSnapshot = settings
        refreshed.scheduledAmount = amount(for: record.kind, date: day, settings: settings)
        refreshed.earnedAmount = 0
        refreshed.updatedAt = now
        return refreshed
    }

    func salaryMonthSummary(
        for month: Date,
        now: Date,
        settings: SalarySettings,
        records: [SalaryDayRecord],
        completedDateKeys: Set<String> = [],
        actualSalaryRecords: [ActualSalaryRecord] = []
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

        let actualRecord = latestActualSalaryByMonth(
            actualSalaryRecords.filter { $0.currencyCode == settings.currencyCode }
        )[monthKey(for: month)]
        if let actualRecord {
            earnedAmount = actualRecord.amount
            projectedAmount = actualRecord.amount
            estimatedDayCount = 0
        }

        return SalaryMonthSummary(
            earnedAmount: earnedAmount,
            projectedAmount: projectedAmount,
            paidDayCount: paidDayCount,
            estimatedDayCount: estimatedDayCount,
            actualAmount: actualRecord?.amount
        )
    }

    func personalGoalProgress(
        for wish: WishExperience,
        now: Date,
        settings: SalarySettings,
        records: [SalaryDayRecord],
        completedDateKeys: Set<String> = []
    ) -> PersonalGoalProgress {
        let targetAmount = wish.targetAmount.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: wish.createdAt)
        var recordsByDate: [String: SalaryDayRecord] = [:]
        for record in records {
            let current = recordsByDate[record.dateKey]?.updatedAt ?? .distantPast
            if record.updatedAt > current {
                recordsByDate[record.dateKey] = record
            }
        }

        var cursor = start
        var earned = 0.0
        while cursor <= today {
            let record = recordsByDate[dateKey(for: cursor)]
            earned += salaryCalendarDay(
                for: cursor,
                now: now,
                settings: settings,
                record: record,
                completedDateKeys: completedDateKeys
            ).earnedAmount
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? today.addingTimeInterval(86_400)
        }

        let remaining = max(0, targetAmount - earned)
        let dailyAmount = max(0.01, dailySalary(for: settings))
        let completionDate = estimatePersonalGoalCompletionDate(
            remaining: remaining,
            today: today,
            now: now,
            settings: settings,
            recordsByDate: recordsByDate,
            completedDateKeys: completedDateKeys
        )

        return PersonalGoalProgress(
            earnedAmount: earned,
            remainingAmount: remaining,
            progress: targetAmount > 0 ? min(1, max(0, earned / targetAmount)) : 0,
            estimatedWorkdaysRemaining: Int(ceil(remaining / dailyAmount)),
            estimatedCompletionDate: completionDate
        )
    }

    private func estimatePersonalGoalCompletionDate(
        remaining: Double,
        today: Date,
        now: Date,
        settings: SalarySettings,
        recordsByDate: [String: SalaryDayRecord],
        completedDateKeys: Set<String>
    ) -> Date? {
        guard remaining > 0 else { return today }
        var outstanding = remaining
        var cursor = today

        for _ in 0..<3_660 {
            let record = recordsByDate[dateKey(for: cursor)]
            let day = salaryCalendarDay(
                for: cursor,
                now: now,
                settings: settings,
                record: record,
                completedDateKeys: completedDateKeys
            )
            let available = cursor == today
                ? max(0, day.scheduledAmount - day.earnedAmount)
                : day.scheduledAmount
            outstanding -= available
            if outstanding <= 0 { return cursor }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return nil }
            cursor = next
        }
        return nil
    }

    func weeklyPayReport(
        now: Date,
        settings: SalarySettings,
        records: [SalaryDayRecord],
        completedDateKeys: Set<String> = []
    ) -> WeeklyPayReport {
        let today = calendar.startOfDay(for: now)
        let interval = calendar.dateInterval(of: .weekOfYear, for: today)
            ?? DateInterval(start: today, end: calendar.date(byAdding: .day, value: 7, to: today) ?? today)
        var recordsByDate: [String: SalaryDayRecord] = [:]
        for record in records {
            let current = recordsByDate[record.dateKey]?.updatedAt ?? .distantPast
            if record.updatedAt > current {
                recordsByDate[record.dateKey] = record
            }
        }

        var days: [WeeklyPayDay] = []
        var earnedAmount = 0.0
        var projectedAmount = 0.0
        var paidDayCount = 0
        var totalWorkdays = 0
        var cursor = interval.start

        while cursor < interval.end {
            let record = recordsByDate[dateKey(for: cursor)]
            let calendarDay = salaryCalendarDay(
                for: cursor,
                now: now,
                settings: settings,
                record: record,
                completedDateKeys: completedDateKeys
            )
            let isPaidKind = calendarDay.kind == .normal || calendarDay.kind == .paidLeave
            if isPaidKind {
                totalWorkdays += 1
                projectedAmount += calendarDay.scheduledAmount
            }
            if !calendarDay.isFuture {
                earnedAmount += calendarDay.earnedAmount
                if isPaidKind, calendarDay.earnedAmount > 0 {
                    paidDayCount += 1
                }
            }
            days.append(
                WeeklyPayDay(
                    date: cursor,
                    dateKey: calendarDay.dateKey,
                    earnedAmount: calendarDay.isFuture ? 0 : calendarDay.earnedAmount,
                    scheduledAmount: calendarDay.scheduledAmount,
                    kind: calendarDay.kind,
                    isFuture: calendarDay.isFuture,
                    isToday: calendar.isDate(cursor, inSameDayAs: today)
                )
            )
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }

        return WeeklyPayReport(
            weekStart: interval.start,
            weekEnd: interval.end,
            days: days,
            earnedAmount: earnedAmount,
            projectedAmount: projectedAmount,
            paidDayCount: paidDayCount,
            totalWorkdays: totalWorkdays
        )
    }

    func salaryBadges(
        now: Date,
        settings: SalarySettings,
        records: [SalaryDayRecord],
        completedDateKeys: Set<String> = [],
        focusedWish: WishExperience?,
        wishes _: [WishExperience],
        overtimeRecords: [OvertimeRecord],
        unlockedBadgeIDs: Set<String> = []
    ) -> [SalaryBadge] {
        let month = salaryMonthSummary(
            for: now,
            now: now,
            settings: settings,
            records: records,
            completedDateKeys: completedDateKeys
        )
        let week = weeklyPayReport(
            now: now,
            settings: settings,
            records: records,
            completedDateKeys: completedDateKeys
        )
        let overtime = overtimeSummary(
            in: .month,
            date: now,
            now: now,
            overtimeRecords: overtimeRecords
        )
        let goalProgress = focusedWish.flatMap { wish -> PersonalGoalProgress? in
            guard wish.targetAmount != nil else { return nil }
            return personalGoalProgress(
                for: wish,
                now: now,
                settings: settings,
                records: records,
                completedDateKeys: completedDateKeys
            )
        }
        let savedCalendarDayCount = Set(records.map(\.dateKey)).count
        let hasEverEarned = month.earnedAmount > 0 || records.contains { $0.earnedAmount > 0 }
        let workweekPaidDayTarget = max(1, week.totalWorkdays)
        let specialScheduleCount = records.filter { $0.kind != .normal }.count
        let paidLeaveCount = records.filter { $0.kind == .paidLeave }.count
        let restRecordCount = records.filter { $0.kind == .rest }.count
        let calendarNoteCount = records.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let overtimeRecordCount = overtimeRecords.count
        let weekendOvertimeCount = overtimeRecords.filter { record in
            !settings.workdays.contains(calendar.component(.weekday, from: record.startAt))
        }.count
        let badges = [
            SalaryBadge(
                id: "first-payday",
                title: L10n.t("第一次开薪"),
                subtitle: L10n.t("让钱包先开张"),
                icon: "sparkles",
                progress: hasEverEarned ? 1 : 0
            ),
            SalaryBadge(
                id: "workweek-earned",
                title: L10n.t("稳定产出"),
                subtitle: L10n.format("本周完成 %@ 个计薪日", "\(workweekPaidDayTarget)"),
                icon: "calendar.badge.checkmark",
                progress: min(1, Double(week.paidDayCount) / Double(workweekPaidDayTarget))
            ),
            SalaryBadge(
                id: "month-halfway",
                title: L10n.t("半程加速"),
                subtitle: L10n.t("完成本月一半计薪进度"),
                icon: "gauge.medium",
                progress: min(1, month.progress / 0.5)
            ),
            SalaryBadge(
                id: "month-quarter",
                title: L10n.t("开局顺利"),
                subtitle: L10n.t("完成本月 25% 计薪进度"),
                icon: "chart.line.uptrend.xyaxis",
                progress: min(1, month.progress / 0.25)
            ),
            SalaryBadge(
                id: "month-three-quarter",
                title: L10n.t("稳步向前"),
                subtitle: L10n.t("完成本月 75% 计薪进度"),
                icon: "chart.bar.fill",
                progress: min(1, month.progress / 0.75)
            ),
            SalaryBadge(
                id: "month-finish",
                title: L10n.t("月度结算"),
                subtitle: L10n.t("完成本月计薪进度"),
                icon: "flag.checkered",
                progress: month.progress
            ),
            SalaryBadge(
                id: "payday-direction",
                title: L10n.t("目标启程"),
                subtitle: L10n.t("设置一个开薪目标"),
                icon: "target",
                progress: focusedWish == nil ? 0 : 1
            ),
            SalaryBadge(
                id: "goal-reached",
                title: L10n.t("目标抵达"),
                subtitle: L10n.t("完成一个开薪目标"),
                icon: "flag.2.crossed.fill",
                progress: goalProgress?.progress ?? 0
            ),
            SalaryBadge(
                id: "goal-halfway",
                title: L10n.t("目标过半"),
                subtitle: L10n.t("完成开薪目标的 50%"),
                icon: "scope",
                progress: min(1, (goalProgress?.progress ?? 0) / 0.5)
            ),
            SalaryBadge(
                id: "goal-sprint",
                title: L10n.t("目标冲刺"),
                subtitle: L10n.t("完成开薪目标的 80%"),
                icon: "figure.run",
                progress: min(1, (goalProgress?.progress ?? 0) / 0.8)
            ),
            SalaryBadge(
                id: "calendar-caretaker",
                title: L10n.t("日历匠人"),
                subtitle: L10n.t("保存 3 条工资日历记录"),
                icon: "calendar.badge.clock",
                progress: min(1, Double(savedCalendarDayCount) / 3)
            ),
            SalaryBadge(
                id: "calendar-week",
                title: L10n.t("周记初成"),
                subtitle: L10n.t("保存 7 条工资日历记录"),
                icon: "calendar.day.timeline.leading",
                progress: min(1, Double(savedCalendarDayCount) / 7)
            ),
            SalaryBadge(
                id: "calendar-collector",
                title: L10n.t("日历收藏家"),
                subtitle: L10n.t("保存 10 条工资日历记录"),
                icon: "calendar.badge.plus",
                progress: min(1, Double(savedCalendarDayCount) / 10)
            ),
            SalaryBadge(
                id: "calendar-month",
                title: L10n.t("两周记忆"),
                subtitle: L10n.t("保存 20 条工资日历记录"),
                icon: "calendar.circle.fill",
                progress: min(1, Double(savedCalendarDayCount) / 20)
            ),
            SalaryBadge(
                id: "calendar-archivist",
                title: L10n.t("日历档案员"),
                subtitle: L10n.t("保存 30 条工资日历记录"),
                icon: "archivebox.fill",
                progress: min(1, Double(savedCalendarDayCount) / 30)
            ),
            SalaryBadge(
                id: "calendar-grandmaster",
                title: L10n.t("工资档案馆"),
                subtitle: L10n.t("保存 60 条工资日历记录"),
                icon: "books.vertical.fill",
                progress: min(1, Double(savedCalendarDayCount) / 60)
            ),
            SalaryBadge(
                id: "calendar-vault",
                title: L10n.t("工资资料室"),
                subtitle: L10n.t("保存 90 条工资日历记录"),
                icon: "cabinet.fill",
                progress: min(1, Double(savedCalendarDayCount) / 90)
            ),
            SalaryBadge(
                id: "calendar-yearbook",
                title: L10n.t("薪资年鉴"),
                subtitle: L10n.t("保存 180 条工资日历记录"),
                icon: "book.closed.fill",
                progress: min(1, Double(savedCalendarDayCount) / 180)
            ),
            SalaryBadge(
                id: "calendar-note",
                title: L10n.t("备注一下"),
                subtitle: L10n.t("为工资日历写下第一条备注"),
                icon: "note.text",
                progress: calendarNoteCount > 0 ? 1 : 0
            ),
            SalaryBadge(
                id: "calendar-journal",
                title: L10n.t("工资手账"),
                subtitle: L10n.t("为 5 条工资日历记录添加备注"),
                icon: "text.book.closed.fill",
                progress: min(1, Double(calendarNoteCount) / 5)
            ),
            SalaryBadge(
                id: "schedule-owner",
                title: L10n.t("日程由我"),
                subtitle: L10n.t("在工资日历标记一次请假或休息"),
                icon: "calendar.badge.minus",
                progress: specialScheduleCount > 0 ? 1 : 0
            ),
            SalaryBadge(
                id: "schedule-master",
                title: L10n.t("排班达人"),
                subtitle: L10n.t("在工资日历标记 3 次特殊日程"),
                icon: "calendar.badge.exclamationmark",
                progress: min(1, Double(specialScheduleCount) / 3)
            ),
            SalaryBadge(
                id: "paid-leave",
                title: L10n.t("带薪休整"),
                subtitle: L10n.t("在工资日历标记一次带薪休假"),
                icon: "beach.umbrella.fill",
                progress: paidLeaveCount > 0 ? 1 : 0
            ),
            SalaryBadge(
                id: "schedule-director",
                title: L10n.t("日程掌舵"),
                subtitle: L10n.t("在工资日历标记 5 次特殊日程"),
                icon: "calendar.badge.gearshape",
                progress: min(1, Double(specialScheduleCount) / 5)
            ),
            SalaryBadge(
                id: "rest-planner",
                title: L10n.t("休息有数"),
                subtitle: L10n.t("在工资日历标记 3 次休息日"),
                icon: "moon.zzz.fill",
                progress: min(1, Double(restRecordCount) / 3)
            ),
            SalaryBadge(
                id: "overtime-starter",
                title: L10n.t("加班开张"),
                subtitle: L10n.t("本月累计 1 小时加班"),
                icon: "bolt.fill",
                progress: min(1, overtime.totalHours)
            ),
            SalaryBadge(
                id: "overtime-advanced",
                title: L10n.t("加班进阶"),
                subtitle: L10n.t("本月累计 4 小时加班"),
                icon: "bolt.badge.clock.fill",
                progress: min(1, overtime.totalHours / 4)
            ),
            SalaryBadge(
                id: "overtime-hero",
                title: L10n.t("加班英雄"),
                subtitle: L10n.t("本月加班 8 小时"),
                icon: "moon.stars.fill",
                progress: min(1, overtime.totalHours / 8)
            ),
            SalaryBadge(
                id: "overtime-marathon",
                title: L10n.t("加班马拉松"),
                subtitle: L10n.t("本月累计 16 小时加班"),
                icon: "flame.fill",
                progress: min(1, overtime.totalHours / 16)
            ),
            SalaryBadge(
                id: "overtime-logbook",
                title: L10n.t("加班留档"),
                subtitle: L10n.t("记录 3 次加班"),
                icon: "doc.text.fill",
                progress: min(1, Double(overtimeRecordCount) / 3)
            ),
            SalaryBadge(
                id: "overtime-ledger",
                title: L10n.t("加班账本"),
                subtitle: L10n.t("记录 10 次加班"),
                icon: "list.bullet.rectangle.fill",
                progress: min(1, Double(overtimeRecordCount) / 10)
            ),
            SalaryBadge(
                id: "weekend-shift",
                title: L10n.t("周末出勤"),
                subtitle: L10n.t("在休息日记录一次加班"),
                icon: "sun.and.horizon.fill",
                progress: weekendOvertimeCount > 0 ? 1 : 0
            ),
            SalaryBadge(
                id: "weekend-regular",
                title: L10n.t("周末常客"),
                subtitle: L10n.t("在休息日记录 3 次加班"),
                icon: "sun.max.trianglebadge.exclamationmark.fill",
                progress: min(1, Double(weekendOvertimeCount) / 3)
            ),
            SalaryBadge(
                id: "weekend-veteran",
                title: L10n.t("周末熟客"),
                subtitle: L10n.t("在休息日记录 6 次加班"),
                icon: "sun.max.fill",
                progress: min(1, Double(weekendOvertimeCount) / 6)
            )
        ]
        return badges.map {
            SalaryBadge(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                icon: $0.icon,
                progress: $0.progress,
                isUnlocked: unlockedBadgeIDs.contains($0.id)
            )
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

    func monthKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    func paydayDate(forMonthContaining date: Date, paydayDay: Int) -> Date {
        let monthInterval = periodInterval(for: .month, date: date)
        let dayRange = calendar.range(of: .day, in: .month, for: monthInterval.start) ?? 1..<2
        let resolvedDay = min(max(paydayDay, 1), dayRange.count)
        return calendar.date(byAdding: .day, value: resolvedDay - 1, to: monthInterval.start) ?? monthInterval.start
    }

    func isPayday(_ date: Date, settings: SalarySettings) -> Bool {
        guard let paydayDay = settings.paydayDay else { return false }
        return calendar.isDate(date, inSameDayAs: paydayDate(forMonthContaining: date, paydayDay: paydayDay))
    }

    func canEnterActualSalary(for month: Date, now: Date, settings: SalarySettings) -> Bool {
        let monthStart = periodInterval(for: .month, date: month).start
        let currentMonthStart = periodInterval(for: .month, date: now).start
        if monthStart < currentMonthStart { return true }
        guard monthStart == currentMonthStart, let paydayDay = settings.paydayDay else { return false }
        let payday = paydayDate(forMonthContaining: month, paydayDay: paydayDay)
        return calendar.startOfDay(for: now) >= calendar.startOfDay(for: payday)
    }

    private func latestActualSalaryByMonth(_ records: [ActualSalaryRecord]) -> [String: ActualSalaryRecord] {
        var result: [String: ActualSalaryRecord] = [:]
        for record in records {
            if result[record.monthKey]?.updatedAt ?? .distantPast < record.updatedAt {
                result[record.monthKey] = record
            }
        }
        return result
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

    private func calendarPeriodBreakdown(
        in component: Calendar.Component,
        date: Date,
        settings: SalarySettings,
        recordsByDate: [String: SalaryDayRecord],
        completedDateKeys: Set<String>
    ) -> PeriodBreakdown {
        let interval = periodInterval(for: component, date: date)
        let today = calendar.startOfDay(for: date)
        var cursor = interval.start
        var total = 0
        var elapsed = 0
        var completed = 0.0
        var remaining = 0

        while cursor < interval.end {
            let day = salaryCalendarDay(
                for: cursor,
                now: date,
                settings: settings,
                record: recordsByDate[dateKey(for: cursor)],
                completedDateKeys: completedDateKeys
            )
            let isPaidDay = day.kind == .normal || day.kind == .paidLeave
            guard isPaidDay else {
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
                continue
            }

            total += 1
            if cursor < today {
                elapsed += 1
                completed += 1
            } else if cursor == today {
                let progress = day.scheduledAmount > 0 ? day.earnedAmount / day.scheduledAmount : 0
                completed += progress
                if progress < 1 { remaining += 1 }
            } else {
                remaining += 1
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }

        return PeriodBreakdown(
            elapsedFullWorkdays: elapsed,
            totalWorkdays: total,
            remainingWorkdays: remaining,
            completedWorkdayEquivalent: completed
        )
    }

    private func latestRecordsByDate(_ records: [SalaryDayRecord]) -> [String: SalaryDayRecord] {
        var recordsByDate: [String: SalaryDayRecord] = [:]
        for record in records {
            let existingUpdate = recordsByDate[record.dateKey]?.updatedAt ?? .distantPast
            if existingUpdate < record.updatedAt {
                recordsByDate[record.dateKey] = record
            }
        }
        return recordsByDate
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
