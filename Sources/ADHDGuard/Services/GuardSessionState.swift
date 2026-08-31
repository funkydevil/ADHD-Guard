import Foundation

struct DistractionEpisode: Equatable {
    private(set) var startedAt: Date?
    private(set) var isAlarmLatched = false

    mutating func remaining(
        for decision: RuleDecision,
        now: Date,
        graceSeconds: Int
    ) -> Int? {
        switch decision {
        case .focused:
            reset()
            return nil

        case let .distracted(_, immediate):
            if startedAt == nil {
                startedAt = now
            }

            if immediate {
                isAlarmLatched = true
            }

            if isAlarmLatched {
                return 0
            }

            let elapsed = now.timeIntervalSince(startedAt ?? now)
            let remaining = max(0, graceSeconds - Int(elapsed))
            if remaining == 0 {
                isAlarmLatched = true
            }
            return remaining
        }
    }

    mutating func reset() {
        startedAt = nil
        isAlarmLatched = false
    }
}

struct RecentHostHistory: Equatable {
    private(set) var hosts: [String] = []
    let limit: Int

    init(limit: Int = 3) {
        self.limit = max(1, limit)
    }

    mutating func record(_ host: String) {
        guard let normalized = RuleEvaluator.normalizedHost(from: host) else { return }
        hosts.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        hosts.insert(normalized, at: 0)
        hosts = Array(hosts.prefix(limit))
    }
}
