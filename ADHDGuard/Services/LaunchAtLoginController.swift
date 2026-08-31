import AppKit
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isAvailable = true
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    private let service: SMAppService
    private var appActivationCancellable: AnyCancellable?
    private var requestedEnabled: Bool?

    init(service: SMAppService = .mainApp) {
        self.service = service
        refresh()

        appActivationCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh(clearResolvedError: true)
            }
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        requestedEnabled = enabled

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            refresh(clearResolvedError: true)
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func refresh(clearResolvedError: Bool = false) {
        let status = service.status
        isEnabled = status == .enabled || status == .requiresApproval
        isAvailable = status != .notFound
        requiresApproval = status == .requiresApproval

        if status == .notFound {
            errorMessage = "ADHD Guard could not access its Login Item registration. Try reinstalling the app."
        } else if clearResolvedError,
                  requestedEnabled.map({ $0 == isEnabled }) ?? true {
            errorMessage = nil
            requestedEnabled = nil
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
