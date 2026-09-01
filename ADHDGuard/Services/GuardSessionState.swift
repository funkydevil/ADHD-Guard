import Foundation

struct DistractionEpisode: Equatable {
    private(set) var startedAt: Date?
    private(set) var isAlarmLatched = false
    private(set) var pausedAt: Date?

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

            let effectiveNow = pausedAt ?? now
            let elapsed = effectiveNow.timeIntervalSince(startedAt ?? effectiveNow)
            let remaining = max(0, graceSeconds - Int(elapsed))
            if remaining == 0 {
                isAlarmLatched = true
            }
            return remaining
        }
    }

    mutating func pause(at now: Date) {
        guard startedAt != nil, pausedAt == nil else { return }
        pausedAt = now
    }

    mutating func resume(at now: Date) {
        guard let pausedAt else { return }
        if let startedAt {
            self.startedAt = startedAt.addingTimeInterval(max(0, now.timeIntervalSince(pausedAt)))
        }
        self.pausedAt = nil
    }

    mutating func reset() {
        startedAt = nil
        isAlarmLatched = false
        pausedAt = nil
    }
}

struct RecentHostHistory: Equatable {
    private(set) var hosts: [String] = []
    let limit: Int

    init(hosts: [String] = [], limit: Int = 3) {
        self.limit = max(1, limit)
        for host in hosts.reversed() {
            record(host)
        }
    }

    mutating func record(_ host: String) {
        guard let normalized = RuleEvaluator.normalizedHost(from: host) else { return }
        hosts.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        hosts.insert(normalized, at: 0)
        hosts = Array(hosts.prefix(limit))
    }
}

struct RecentApplication: Codable, Identifiable, Equatable {
    let name: String
    let bundleIdentifier: String

    var id: String { bundleIdentifier.lowercased() }
}

struct RecentApplicationHistory: Equatable {
    private(set) var applications: [RecentApplication] = []
    let limit: Int

    init(applications: [RecentApplication] = [], limit: Int = 3) {
        self.limit = max(1, limit)
        for application in applications.reversed() {
            record(name: application.name, bundleIdentifier: application.bundleIdentifier)
        }
    }

    mutating func record(name: String, bundleIdentifier: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedBundleIdentifier.isEmpty else { return }

        applications.removeAll {
            $0.bundleIdentifier.caseInsensitiveCompare(trimmedBundleIdentifier) == .orderedSame
        }
        applications.insert(
            RecentApplication(name: trimmedName, bundleIdentifier: trimmedBundleIdentifier),
            at: 0
        )
        applications = Array(applications.prefix(limit))
    }
}

enum RecentActivityKind: Codable, Equatable {
    case application
    case website(host: String)
}

struct RecentActivity: Codable, Identifiable, Equatable {
    let applicationName: String
    let bundleIdentifier: String
    let browserURL: URL?
    let kind: RecentActivityKind

    init?(context: ActivityContext) {
        let applicationName = context.applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleIdentifier = context.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !applicationName.isEmpty, !bundleIdentifier.isEmpty else { return nil }

        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier

        if context.isBrowser,
           let browserURL = context.browserURL,
           let host = RuleEvaluator.normalizedHost(from: browserURL.host ?? "") {
            self.browserURL = browserURL
            kind = .website(host: host)
        } else {
            browserURL = nil
            kind = .application
        }
    }

    var id: String {
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()
        switch kind {
        case .application:
            return "application|\(normalizedBundleIdentifier)"
        case let .website(host):
            return "website|\(normalizedBundleIdentifier)|\(host.lowercased())"
        }
    }
}

struct RecentActivityHistory: Equatable {
    private(set) var activities: [RecentActivity] = []
    let limit: Int

    init(activities: [RecentActivity] = [], limit: Int = 4) {
        self.limit = max(1, limit)
        for activity in activities.reversed() {
            record(activity)
        }
    }

    mutating func record(context: ActivityContext) {
        guard let activity = RecentActivity(context: context) else { return }
        record(activity)
    }

    private mutating func record(_ activity: RecentActivity) {
        activities.removeAll { $0.id == activity.id }
        activities.insert(activity, at: 0)
        activities = Array(activities.prefix(limit))
    }
}

struct RecentActivitySnapshot: Codable, Equatable {
    var hosts: [String]
    var applications: [RecentApplication]
    var activities: [RecentActivity]

    static let empty = RecentActivitySnapshot(hosts: [], applications: [], activities: [])
}

struct RecentActivityPersistence {
    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "adhd-guard.recent-activity.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load() -> RecentActivitySnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? decoder.decode(RecentActivitySnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func save(_ snapshot: RecentActivitySnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct FocusReturnTarget: Equatable {
    let processIdentifier: pid_t
    let applicationName: String
    let bundleIdentifier: String
    let browserURL: URL?
}

struct FocusReturnHistory: Equatable {
    private(set) var target: FocusReturnTarget?

    mutating func record(
        decision: RuleDecision,
        context: ActivityContext,
        processIdentifier: pid_t,
        isOwnApplication: Bool,
        isUserVisibleApplication: Bool
    ) {
        guard case .focused = decision,
              !isOwnApplication,
              isUserVisibleApplication,
              !context.bundleIdentifier.hasPrefix("unknown.") else {
            return
        }

        target = FocusReturnTarget(
            processIdentifier: processIdentifier,
            applicationName: context.applicationName,
            bundleIdentifier: context.bundleIdentifier,
            browserURL: context.isBrowser ? context.browserURL : nil
        )
    }
}
