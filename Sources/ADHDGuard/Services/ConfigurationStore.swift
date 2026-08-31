import Combine
import Foundation

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published var configuration: GuardConfiguration {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let storageKey = "adhd-guard.configuration.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let saved = try? decoder.decode(GuardConfiguration.self, from: data) {
            configuration = saved
        } else {
            configuration = .defaults
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
