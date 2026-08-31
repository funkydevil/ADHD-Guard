import Foundation

struct ApplicationRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var bundleIdentifier: String
}

struct WebsiteRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var host: String
}

struct GuardConfiguration: Codable, Equatable {
    static let defaultWebsiteRules: [WebsiteRule] = [
        WebsiteRule(host: "youtube.com")
    ]

    static let browserApplicationRules: [ApplicationRule] = [
        ApplicationRule(name: "Safari", bundleIdentifier: "com.apple.Safari"),
        ApplicationRule(name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        ApplicationRule(name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
        ApplicationRule(name: "Brave Browser", bundleIdentifier: "com.brave.Browser"),
        ApplicationRule(name: "Arc", bundleIdentifier: "company.thebrowser.Browser")
    ]

    var monitoringEnabled = false
    var distractionGraceSeconds = 20
    var idleMonitoringEnabled = false
    var idleThresholdSeconds = 180
    var speaksWarnings = true
    var playsSound = true
    var focusPhrase = "Go back. Stop. Get back to work."
    var idlePhrase = "Stop procrastinating. Get back to work."
    var applicationRules: [ApplicationRule] = [
        ApplicationRule(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
        ApplicationRule(name: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode"),
        ApplicationRule(name: "Codex", bundleIdentifier: "com.openai.codex")
    ] + browserApplicationRules
    var websiteRules: [WebsiteRule] = defaultWebsiteRules

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
