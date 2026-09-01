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
    @Published private(set) var recentApplications: [RecentApplication] = []
    @Published private(set) var recentActivities: [RecentActivity] = []
    @Published private(set) var lastExternalContext: ActivityContext?

    private let store: ConfigurationStore
    private let alarm: AlarmController
    private let recentActivityPersistence: RecentActivityPersistence
    private var loopTask: Task<Void, Never>?
    private var distractionEpisode = DistractionEpisode()
    private var recentHostHistory: RecentHostHistory
    private var recentApplicationHistory: RecentApplicationHistory
    private var recentActivityHistory: RecentActivityHistory
    private var focusReturnHistory = FocusReturnHistory()
    private var workspaceLifecycleCancellables = Set<AnyCancellable>()
    private var isComputerSleeping = false
    private var lastBrowserReadAt = Date.distantPast
    private var cachedBrowserURL: URL?
    private var cachedBrowserBundleIdentifier: String?

    init(
        store: ConfigurationStore,
        alarm: AlarmController,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.alarm = alarm
        let persistence = RecentActivityPersistence(defaults: defaults)
        recentActivityPersistence = persistence

        let snapshot = persistence.load()
        let hostHistory = RecentHostHistory(hosts: snapshot.hosts)
        let applicationHistory = RecentApplicationHistory(applications: snapshot.applications)
        let activityHistory = RecentActivityHistory(activities: snapshot.activities)
        recentHostHistory = hostHistory
        recentApplicationHistory = applicationHistory
        recentActivityHistory = activityHistory
        recentVisitedHosts = hostHistory.hosts
        recentApplications = applicationHistory.applications
        recentActivities = activityHistory.activities

        subscribeToWorkspaceLifecycle()
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
        guard !isComputerSleeping else { return }

        let configuration = store.configuration

        // Keep the current context and locally persisted recents useful while
        // reminders are paused. Enforcement still exits below.
        guard let application = NSWorkspace.shared.frontmostApplication else {
            statusText = configuration.monitoringEnabled
                ? "Waiting for the active application"
                : "Reminders are paused"
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
        recordRecentHistoryIfNeeded(
            context: context,
            isOwnApplication: isOwnApplication,
            isUserVisibleApplication: application.activationPolicy == .regular
        )

        let decision = RuleEvaluator.evaluate(
            context: context,
            configuration: configuration,
            ownBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.funkydevil.ADHDGuard"
        )
        lastDecision = decision
        if !isOwnApplication {
            lastExternalContext = context
        }

        guard configuration.monitoringEnabled else {
            resetDistraction()
            alarm.dismiss()
            statusText = "Reminders are paused"
            return
        }

        focusReturnHistory.record(
            decision: decision,
            context: context,
            processIdentifier: application.processIdentifier,
            isOwnApplication: isOwnApplication,
            isUserVisibleApplication: application.activationPolicy == .regular
        )
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
                    playsSound: configuration.playsSound,
                    returnToFocus: { [weak self] in self?.returnToLastFocusedContext() }
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
                    playsSound: configuration.playsSound,
                    returnToFocus: { [weak self] in self?.returnToLastFocusedContext() }
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

    private func subscribeToWorkspaceLifecycle() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSystemWillSleep(at: Date())
            }
            .store(in: &workspaceLifecycleCancellables)

        notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSystemDidWake(at: Date())
            }
            .store(in: &workspaceLifecycleCancellables)
    }

    private func handleSystemWillSleep(at date: Date) {
        guard !isComputerSleeping else { return }
        isComputerSleeping = true
        distractionEpisode.pause(at: date)
    }

    private func handleSystemDidWake(at date: Date) {
        guard isComputerSleeping else { return }
        distractionEpisode.resume(at: date)
        isComputerSleeping = false
        checkNow()
    }

    private func returnToLastFocusedContext() {
        guard let target = focusReturnHistory.target else { return }

        // Do not wait for the polling loop to observe the restored app. Without
        // this reset, a quick subsequent switch can inherit the previous alarm's
        // latched state and skip the configured focus buffer.
        resetDistraction()
        alarm.dismiss()

        let workspace = NSWorkspace.shared
        let runningApplication = NSRunningApplication(processIdentifier: target.processIdentifier)
            .flatMap { application in
                application.bundleIdentifier?.caseInsensitiveCompare(target.bundleIdentifier) == .orderedSame
                    ? application
                    : nil
            }
        let applicationURL = runningApplication?.bundleURL
            ?? workspace.urlForApplication(withBundleIdentifier: target.bundleIdentifier)

        if let browserURL = target.browserURL,
           let descriptor = BrowserURLReader.descriptor(for: target.bundleIdentifier) {
            if BrowserURLReader.activateExistingTab(url: browserURL, for: descriptor) {
                return
            }

            if let applicationURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                workspace.open(
                    [browserURL],
                    withApplicationAt: applicationURL,
                    configuration: configuration
                )
                return
            }
        }

        if let runningApplication,
           activate(runningApplication) {
            return
        }

        if let applicationURL {
            openApplication(at: applicationURL, using: workspace)
        }
    }

    private func activate(_ application: NSRunningApplication) -> Bool {
        application.unhide()

        if #available(macOS 14.0, *) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.yieldActivation(to: application)
            return application.activate(
                from: NSRunningApplication.current,
                options: [.activateAllWindows]
            )
        }

        return application.activate(
            options: [.activateAllWindows, .activateIgnoringOtherApps]
        )
    }

    private func openApplication(at applicationURL: URL, using workspace: NSWorkspace) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: applicationURL, configuration: configuration)
    }

    private func recordRecentHistoryIfNeeded(
        context: ActivityContext,
        isOwnApplication: Bool,
        isUserVisibleApplication: Bool
    ) {
        let previousSnapshot = recentActivitySnapshot

        if context.isBrowser, let host = context.browserURL?.host {
            recentHostHistory.record(host)
        }

        if isUserVisibleApplication,
           !isOwnApplication,
           !context.bundleIdentifier.hasPrefix("unknown.") {
            recentApplicationHistory.record(
                name: context.applicationName,
                bundleIdentifier: context.bundleIdentifier
            )
            recentActivityHistory.record(context: context)
        }

        recentVisitedHosts = recentHostHistory.hosts
        recentApplications = recentApplicationHistory.applications
        recentActivities = recentActivityHistory.activities

        let updatedSnapshot = recentActivitySnapshot
        if updatedSnapshot != previousSnapshot {
            recentActivityPersistence.save(updatedSnapshot)
        }
    }

    private var recentActivitySnapshot: RecentActivitySnapshot {
        RecentActivitySnapshot(
            hosts: recentHostHistory.hosts,
            applications: recentApplicationHistory.applications,
            activities: recentActivityHistory.activities
        )
    }

    private func alarmMessage(from detail: String) -> String {
        let websitePrefixes = ["Website outside focus: "]
        for prefix in websitePrefixes where detail.hasPrefix(prefix) {
            return "You’re on \(detail.dropFirst(prefix.count))"
        }

        let applicationPrefixes = ["Application outside focus list: "]
        for prefix in applicationPrefixes where detail.hasPrefix(prefix) {
            return "You’re using \(detail.dropFirst(prefix.count))"
        }
        return detail
    }
}
