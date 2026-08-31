import Combine
import Foundation

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published var configuration: GuardConfiguration {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let storageKey = "adhd-guard.configuration.v1"
    private let browserRulesMigrationKey = "adhd-guard.migration.browser-rules.v1"
    private let defaultWebsiteRulesMigrationKey = "adhd-guard.migration.default-website-rules.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loadedConfiguration: GuardConfiguration
        if let data = defaults.data(forKey: storageKey),
           let saved = try? decoder.decode(GuardConfiguration.self, from: data) {
            loadedConfiguration = saved
        } else {
            loadedConfiguration = .defaults
        }

        var addedBrowserRules = false
        if !defaults.bool(forKey: browserRulesMigrationKey) {
            for browserRule in GuardConfiguration.browserApplicationRules where !loadedConfiguration.applicationRules.contains(where: {
                $0.bundleIdentifier.caseInsensitiveCompare(browserRule.bundleIdentifier) == .orderedSame
            }) {
                loadedConfiguration.applicationRules.append(browserRule)
                addedBrowserRules = true
            }
            defaults.set(true, forKey: browserRulesMigrationKey)
        }

        var addedDefaultWebsiteRules = false
        if !defaults.bool(forKey: defaultWebsiteRulesMigrationKey) {
            for defaultRule in GuardConfiguration.defaultWebsiteRules {
                if !loadedConfiguration.websiteRules.contains(where: {
                    $0.host.caseInsensitiveCompare(defaultRule.host) == .orderedSame
                }) {
                    loadedConfiguration.websiteRules.append(defaultRule)
                    addedDefaultWebsiteRules = true
                }
            }
            defaults.set(true, forKey: defaultWebsiteRulesMigrationKey)
        }

        configuration = loadedConfiguration
        if addedBrowserRules || addedDefaultWebsiteRules {
            save()
        }
    }

    func reset() {
        configuration = .defaults
    }

    func containsFocusApplication(bundleIdentifier: String) -> Bool {
        configuration.applicationRules.contains {
            $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    func addFocusApplication(name: String, bundleIdentifier: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              !trimmedBundleIdentifier.isEmpty,
              !trimmedBundleIdentifier.hasPrefix("unknown.") else { return }

        if let index = configuration.applicationRules.firstIndex(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(trimmedBundleIdentifier) == .orderedSame
        }) {
            configuration.applicationRules[index].name = trimmedName
        } else {
            configuration.applicationRules.append(
                ApplicationRule(name: trimmedName, bundleIdentifier: trimmedBundleIdentifier)
            )
        }
    }

    func containsDistractingSite(_ host: String) -> Bool {
        RuleEvaluator.matchingWebsiteRule(
            host: host,
            rules: configuration.websiteRules
        ) != nil
    }

    func addDistractingSite(_ input: String) -> Bool {
        guard let host = RuleEvaluator.normalizedHost(from: input) else { return false }
        guard !configuration.websiteRules.contains(where: {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }) else { return true }

        configuration.websiteRules.append(WebsiteRule(host: host))
        return true
    }

    private func save() {
        guard let data = try? encoder.encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
