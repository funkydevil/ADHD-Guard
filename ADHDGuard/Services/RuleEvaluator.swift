import Foundation

enum RuleEvaluator {
    static func evaluate(
        context: ActivityContext,
        configuration: GuardConfiguration,
        ownBundleIdentifier: String?
    ) -> RuleDecision {
        if let ownBundleIdentifier,
           context.bundleIdentifier.caseInsensitiveCompare(ownBundleIdentifier) == .orderedSame {
            return .focused(detail: "ADHD Guard settings")
        }

        if context.isBrowser, let host = context.browserURL?.host?.lowercased() {
            if let rule = matchingWebsiteRule(host: host, rules: configuration.websiteRules) {
                return .distracted(detail: "Website outside focus: \(rule.host)", immediate: false)
            }
        }

        if let rule = configuration.applicationRules.first(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(context.bundleIdentifier) == .orderedSame
        }) {
            return .focused(detail: "Focus application: \(rule.name)")
        }

        return .distracted(
            detail: "Application outside focus list: \(context.applicationName)",
            immediate: false
        )
    }

    static func normalizedHost(from input: String) -> String? {
        var candidate = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !candidate.isEmpty else { return nil }

        if candidate.hasPrefix("*.") {
            candidate.removeFirst(2)
        }

        if !candidate.contains("://") {
            candidate = "https://\(candidate)"
        }

        guard let url = URL(string: candidate), var host = url.host?.lowercased() else {
            return nil
        }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host.isEmpty ? nil : host
    }

    static func host(_ host: String, matches ruleHost: String) -> Bool {
        guard let normalizedRule = normalizedHost(from: ruleHost) else { return false }
        var normalizedCandidate = host.lowercased()
        if normalizedCandidate.hasPrefix("www.") {
            normalizedCandidate.removeFirst(4)
        }
        return normalizedCandidate == normalizedRule || normalizedCandidate.hasSuffix(".\(normalizedRule)")
    }

    static func matchingWebsiteRule(host: String, rules: [WebsiteRule]) -> WebsiteRule? {
        rules.first { Self.host(host, matches: $0.host) }
    }
}
