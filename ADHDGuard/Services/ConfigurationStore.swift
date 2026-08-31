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

        configuration = loadedConfiguration
        if addedBrowserRules {
            save()
        }
    }

    func reset() {
        configuration = .defaults
    }

    private func save() {
        guard let data = try? encoder.encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
