import Foundation

enum RulePolicy: String, Codable, CaseIterable, Identifiable {
    case allowed
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allowed: "Allowed"
        case .blocked: "Blocked"
        }
    }

    var symbol: String {
        switch self {
        case .allowed: "checkmark.circle.fill"
        case .blocked: "hand.raised.fill"
        }
    }
}

struct ApplicationRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var bundleIdentifier: String
    var policy: RulePolicy
}

struct WebsiteRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var host: String
    var policy: RulePolicy
}

struct GuardConfiguration: Codable, Equatable {
    var monitoringEnabled = false
    var distractionGraceSeconds = 20
    var idleMonitoringEnabled = false
    var idleThresholdSeconds = 180
    var speaksWarnings = true
    var playsSound = true
    var focusPhrase = "Go back. Stop. Get back to work."
    var idlePhrase = "Stop procrastinating. Get back to work."
    var applicationRules: [ApplicationRule] = [
        ApplicationRule(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", policy: .allowed),
        ApplicationRule(name: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode", policy: .allowed),
        ApplicationRule(name: "Codex", bundleIdentifier: "com.openai.codex", policy: .allowed)
    ]
    var websiteRules: [WebsiteRule] = []

    static let defaults = GuardConfiguration()
}

struct ActivityContext: Equatable {
    var applicationName: String
    var bundleIdentifier: String
    var browserURL: URL?
    var isBrowser: Bool
    var idleSeconds: TimeInterval
}

enum RuleDecision: Equatable {
    case focused(detail: String)
    case distracted(detail: String, immediate: Bool)
}

enum AlarmKind: String, Equatable {
    case distraction
    case idle
    case test
}

struct AlarmPresentation: Identifiable, Equatable {
    let id = UUID()
    let kind: AlarmKind
    let title: String
    let message: String
    let phrase: String
}
