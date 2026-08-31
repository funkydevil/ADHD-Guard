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
                switch rule.policy {
                case .blocked:
                    return .distracted(detail: "Blocked website: \(rule.host)", immediate: true)
                case .allowed:
                    return .focused(detail: "Allowed website: \(rule.host)")
                }
            }

            let allowedSites = configuration.websiteRules.filter { $0.policy == .allowed }
            if !allowedSites.isEmpty {
                return .distracted(detail: "Website is outside your allow list: \(host)", immediate: false)
            }
        }

        if let rule = configuration.applicationRules.first(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(context.bundleIdentifier) == .orderedSame
        }) {
            switch rule.policy {
            case .allowed:
                return .focused(detail: "Allowed application: \(rule.name)")
            case .blocked:
                return .distracted(detail: "Blocked application: \(rule.name)", immediate: true)
            }
        }

        return .distracted(
            detail: "Application is outside your allow list: \(context.applicationName)",
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

    private static func matchingWebsiteRule(host: String, rules: [WebsiteRule]) -> WebsiteRule? {
        // A blocked rule wins if a user accidentally adds the same host to both lists.
        rules.first { $0.policy == .blocked && Self.host(host, matches: $0.host) }
            ?? rules.first { $0.policy == .allowed && Self.host(host, matches: $0.host) }
    }
}
