import AppKit
import Combine
import ServiceManagement

protocol LaunchAtLoginServicing {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LaunchAtLoginServicing {}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    private let service: any LaunchAtLoginServicing
    private var appActivationCancellable: AnyCancellable?
    private var requestedEnabled: Bool?

    init(service: any LaunchAtLoginServicing = SMAppService.mainApp) {
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
            errorMessage = registrationErrorMessage(for: error)
            refresh()
        }
    }

    func refresh(clearResolvedError: Bool = false) {
        let status = service.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval

        if clearResolvedError,
           requestedEnabled.map({ $0 == isEnabled }) ?? true {
            errorMessage = nil
            requestedEnabled = nil
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func registrationErrorMessage(for error: Error) -> String {
        let installHint: String
        if Bundle.main.bundleURL.path.hasPrefix("/Applications/") {
            installHint = "Open Login Items in System Settings and try again."
        } else {
            installHint = "Move ADHD Guard to Applications, reopen it, and try again."
        }
        return "macOS could not update Start at Login. \(installHint) \(error.localizedDescription)"
    }
}
