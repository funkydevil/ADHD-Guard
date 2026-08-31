import AppKit
import Combine
import Foundation

@MainActor
final class GuardMonitor: ObservableObject {
    @Published private(set) var currentContext: ActivityContext?
    @Published private(set) var statusText = "Monitoring is off"
    @Published private(set) var browserAccessMessage: String?
    @Published private(set) var distractionRemaining: Int?
    @Published private(set) var lastDecision: RuleDecision?
    @Published private(set) var recentVisitedHosts: [String] = []

    private let store: ConfigurationStore
    private let alarm: AlarmController
    private var loopTask: Task<Void, Never>?
    private var distractionEpisode = DistractionEpisode()
    private var recentHostHistory = RecentHostHistory()
    private var lastBrowserReadAt = Date.distantPast
    private var cachedBrowserURL: URL?
    private var cachedBrowserBundleIdentifier: String?

    init(store: ConfigurationStore, alarm: AlarmController) {
        self.store = store
        self.alarm = alarm
    }

    deinit {
        loopTask?.cancel()
    }

    func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkNow()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        resetDistraction()
        alarm.dismiss()
        statusText = "Monitoring is off"
    }

    func checkNow() {
        let configuration = store.configuration
        guard configuration.monitoringEnabled else {
            resetDistraction()
            alarm.dismiss()
            statusText = "Monitoring is off"
            return
        }

        guard let application = NSWorkspace.shared.frontmostApplication else {
            statusText = "Waiting for the active application"
            return
        }

        let name = application.localizedName ?? "Unknown application"
        let isOwnApplication = application.processIdentifier == ProcessInfo.processInfo.processIdentifier
        let bundleIdentifier = application.bundleIdentifier
            ?? (isOwnApplication ? "com.funkydevil.ADHDGuard" : "unknown.\(application.processIdentifier)")
        let browserDescriptor = BrowserURLReader.descriptor(for: bundleIdentifier)
        let browserURL = readBrowserURLIfNeeded(descriptor: browserDescriptor, bundleIdentifier: bundleIdentifier)
        let context = ActivityContext(
            applicationName: name,
            bundleIdentifier: bundleIdentifier,
            browserURL: browserURL,
            isBrowser: browserDescriptor != nil,
            idleSeconds: IdleTimeProvider.currentIdleSeconds()
        )
        currentContext = context
        recordRecentHostIfNeeded(context: context)

        let decision = RuleEvaluator.evaluate(
            context: context,
            configuration: configuration,
            ownBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.funkydevil.ADHDGuard"
        )
        lastDecision = decision
        apply(decision: decision, context: context, configuration: configuration)
    }

    private func readBrowserURLIfNeeded(
        descriptor: BrowserDescriptor?,
        bundleIdentifier: String
    ) -> URL? {
        guard let descriptor else {
            browserAccessMessage = nil
            cachedBrowserURL = nil
            cachedBrowserBundleIdentifier = nil
            return nil
        }

        if cachedBrowserBundleIdentifier == bundleIdentifier,
           Date().timeIntervalSince(lastBrowserReadAt) < 2 {
            return cachedBrowserURL
        }

        cachedBrowserBundleIdentifier = bundleIdentifier
        lastBrowserReadAt = Date()
        switch BrowserURLReader.currentURL(for: descriptor) {
        case let .success(url):
            cachedBrowserURL = url
            browserAccessMessage = nil
            return url
        case let .failure(error):
            cachedBrowserURL = nil
            browserAccessMessage = error.localizedDescription
            return nil
        }
    }

    private func apply(
        decision: RuleDecision,
        context: ActivityContext,
        configuration: GuardConfiguration
    ) {
        switch decision {
        case let .focused(detail):
            resetDistraction()
            if configuration.idleMonitoringEnabled,
               context.idleSeconds >= TimeInterval(configuration.idleThresholdSeconds) {
                statusText = "Idle warning"
                alarm.present(
                    kind: .idle,
                    title: "Still there?",
                    message: "No keyboard or mouse activity for \(Int(context.idleSeconds)) seconds.",
                    phrase: configuration.idlePhrase,
                    speaks: configuration.speaksWarnings,
                    playsSound: configuration.playsSound
                )
            } else {
                statusText = detail
                alarm.dismiss()
            }

        case let .distracted(detail, immediate):
            let remaining = distractionEpisode.remaining(
                for: .distracted(detail: detail, immediate: immediate),
                now: Date(),
                graceSeconds: configuration.distractionGraceSeconds
            ) ?? 0
            distractionRemaining = remaining

            if remaining == 0 {
                statusText = "Distraction limit reached"
                alarm.present(
                    kind: .distraction,
                    title: "Time to refocus",
                    message: alarmMessage(from: detail),
                    phrase: configuration.focusPhrase,
                    speaks: configuration.speaksWarnings,
                    playsSound: configuration.playsSound
                )
            } else {
                statusText = "Distraction: \(remaining)s remaining"
                alarm.dismiss()
            }
        }
    }

    private func resetDistraction() {
        distractionEpisode.reset()
        distractionRemaining = nil
    }

    private func recordRecentHostIfNeeded(context: ActivityContext) {
        guard context.isBrowser,
              let host = context.browserURL?.host else { return }

        recentHostHistory.record(host)
        recentVisitedHosts = recentHostHistory.hosts
    }

    private func alarmMessage(from detail: String) -> String {
        let websitePrefixes = ["Blocked website: ", "Website is outside your allow list: "]
        for prefix in websitePrefixes where detail.hasPrefix(prefix) {
            return "You’re on \(detail.dropFirst(prefix.count))"
        }

        let applicationPrefixes = ["Blocked application: ", "Application is outside your allow list: "]
        for prefix in applicationPrefixes where detail.hasPrefix(prefix) {
            return "You’re using \(detail.dropFirst(prefix.count))"
        }
        return detail
    }
}
