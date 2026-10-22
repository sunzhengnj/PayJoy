import Foundation

struct FocusSession: Codable, Equatable, Identifiable {
    static let durationMinuteRange = 1...240

    static func customMinutes(from text: String) -> Int? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = input.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? input
        guard let minutes = Int(normalized), durationMinuteRange.contains(minutes) else { return nil }
        return minutes
    }

    let id: UUID
    let startedAt: Date
    let plannedDuration: TimeInterval
    let endsAtWork: Bool
    var endDate: Date
    var pausedRemaining: TimeInterval?
    var pausedAt: Date?
    var accumulatedPause: TimeInterval

    init(id: UUID = UUID(), startedAt: Date, duration: TimeInterval, endsAtWork: Bool = false) {
        self.id = id
        self.startedAt = startedAt
        self.plannedDuration = duration
        self.endsAtWork = endsAtWork
        self.endDate = startedAt.addingTimeInterval(duration)
        self.pausedRemaining = nil
        self.pausedAt = nil
        self.accumulatedPause = 0
    }

    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at date: Date) -> TimeInterval {
        max(0, min(plannedDuration, pausedRemaining ?? endDate.timeIntervalSince(date)))
    }

    func focusedDuration(at date: Date) -> TimeInterval {
        if endsAtWork {
            let pausedNow = pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
            return max(0, min(plannedDuration, date.timeIntervalSince(startedAt) - accumulatedPause - pausedNow))
        }
        return max(0, plannedDuration - remaining(at: date))
    }

    mutating func pause(at date: Date) {
        guard !isPaused else { return }
        pausedRemaining = remaining(at: date)
        pausedAt = date
    }

    mutating func resume(at date: Date) {
        guard let pausedRemaining else { return }
        if endsAtWork {
            accumulatedPause += max(0, date.timeIntervalSince(pausedAt ?? date))
        } else {
            endDate = date.addingTimeInterval(pausedRemaining)
        }
        self.pausedRemaining = nil
        pausedAt = nil
    }
}

struct FocusRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let plannedDuration: TimeInterval
    let focusedDuration: TimeInterval
    let completed: Bool
    let endsAtWork: Bool
}

struct FocusData: Codable, Equatable {
    var active: FocusSession?
    var records: [FocusRecord] = []
    var pendingResultID: UUID?
    var prefersDarkBackground = false
    var restoreEarningsActivity = false

    var pendingResult: FocusRecord? {
        records.first { $0.id == pendingResultID }
    }

    mutating func finish(at date: Date, completed: Bool) -> FocusRecord? {
        guard let session = active else { return nil }
        let endedAt = max(date, session.startedAt)
        let record = FocusRecord(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: endedAt,
            plannedDuration: session.plannedDuration,
            focusedDuration: session.focusedDuration(at: endedAt),
            completed: completed,
            endsAtWork: session.endsAtWork
        )
        active = nil
        if !records.contains(where: { $0.id == record.id }) {
            records.insert(record, at: 0)
        }
        pendingResultID = record.id
        return record
    }
}
