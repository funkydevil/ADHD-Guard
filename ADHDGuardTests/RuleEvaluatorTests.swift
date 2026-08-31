import ServiceManagement
import XCTest
@testable import ADHDGuard

final class RuleEvaluatorTests: XCTestCase {
    private let ownBundleIdentifier = "com.funkydevil.ADHDGuard"

    func testAllowedApplicationIsFocused() {
        let configuration = config(
            applications: [ApplicationRule(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", policy: .allowed)]
        )

        let decision = RuleEvaluator.evaluate(
            context: context(app: "Xcode", bundle: "com.apple.dt.Xcode"),
            configuration: configuration,
            ownBundleIdentifier: ownBundleIdentifier
        )

        XCTAssertEqual(decision, .focused(detail: "Allowed application: Xcode"))
    }

    func testBlockedApplicationAlertsImmediately() {
        let configuration = config(
            applications: [ApplicationRule(name: "Games", bundleIdentifier: "com.example.game", policy: .blocked)]
        )

        let decision = RuleEvaluator.evaluate(
            context: context(app: "Games", bundle: "com.example.game"),
            configuration: configuration,
            ownBundleIdentifier: ownBundleIdentifier
        )

        XCTAssertEqual(decision, .distracted(detail: "Blocked application: Games", immediate: true))
    }

    func testUnlistedApplicationUsesGracePeriod() {
        let decision = RuleEvaluator.evaluate(
            context: context(app: "Messages", bundle: "com.apple.MobileSMS"),
            configuration: config(),
            ownBundleIdentifier: ownBundleIdentifier
        )

        XCTAssertEqual(
            decision,
            .distracted(detail: "Application is outside your allow list: Messages", immediate: false)
        )
    }

    func testBlockedWebsiteOverridesAllowedBrowser() {
        let configuration = config(
            applications: [ApplicationRule(name: "Safari", bundleIdentifier: "com.apple.Safari", policy: .allowed)],
            websites: [WebsiteRule(host: "youtube.com", policy: .blocked)]
        )

        let decision = RuleEvaluator.evaluate(
            context: context(
                app: "Safari",
                bundle: "com.apple.Safari",
                url: URL(string: "https://www.youtube.com/watch?v=1"),
                browser: true
            ),
            configuration: configuration,
            ownBundleIdentifier: ownBundleIdentifier
        )

        XCTAssertEqual(decision, .distracted(detail: "Blocked website: youtube.com", immediate: true))
    }

    func testSupportedBrowsersAreAllowedByDefault() {
        let configuredBrowsers = Set(
            GuardConfiguration.browserApplicationRules.map { $0.bundleIdentifier }
        )
        let readableBrowsers = Set(BrowserURLReader.browsers.map { $0.bundleIdentifier })

        XCTAssertEqual(configuredBrowsers, readableBrowsers)
        XCTAssertTrue(GuardConfiguration.browserApplicationRules.allSatisfy { $0.policy == .allowed })
        XCTAssertTrue(readableBrowsers.allSatisfy { bundleIdentifier in
            GuardConfiguration.defaults.applicationRules.contains {
                $0.bundleIdentifier == bundleIdentifier && $0.policy == .allowed
            }
        })
    }

    func testAllowedWebsiteCanFocusAnUnlistedBrowser() {
        let configuration = config(
            websites: [WebsiteRule(host: "developer.apple.com", policy: .allowed)]
        )

        let decision = RuleEvaluator.evaluate(
            context: context(
                app: "Safari",
                bundle: "com.apple.Safari",
                url: URL(string: "https://developer.apple.com/documentation"),
                browser: true
            ),
            configuration: configuration,
            ownBundleIdentifier: ownBundleIdentifier
        )

        XCTAssertEqual(decision, .focused(detail: "Allowed website: developer.apple.com"))
    }

    func testWebsiteOutsideNonemptyAllowListUsesGracePeriod() {
        let configuration = config(
            websites: [WebsiteRule(host: "developer.apple.com", policy: .allowed)]
        )

        let decision = RuleEvaluator.evaluate(
            context: context(
                app: "Safari",
                bundle: "com.apple.Safari",
                url: URL(string: "https://news.example.com"),
                browser: true
            ),
            configuration: configuration,
            ownBundleIdentifier: ownBundleIdentifier
        )

        XCTAssertEqual(
            decision,
            .distracted(detail: "Website is outside your allow list: news.example.com", immediate: false)
        )
    }

    func testHostMatchingIncludesSubdomainsButNotLookalikes() {
        XCTAssertTrue(RuleEvaluator.host("music.youtube.com", matches: "youtube.com"))
        XCTAssertTrue(RuleEvaluator.host("www.youtube.com", matches: "*.youtube.com"))
        XCTAssertFalse(RuleEvaluator.host("notyoutube.com", matches: "youtube.com"))
    }

    func testMatchingWebsiteRuleUsesBlockedFirstPriority() {
        let allowed = WebsiteRule(host: "youtube.com", policy: .allowed)
        let blocked = WebsiteRule(host: "music.youtube.com", policy: .blocked)

        XCTAssertEqual(
            RuleEvaluator.matchingWebsiteRule(
                host: "music.youtube.com",
                rules: [allowed, blocked]
            ),
            blocked
        )
    }

    func testOwnApplicationIsAlwaysFocused() {
        let decision = RuleEvaluator.evaluate(
            context: context(app: "ADHD Guard", bundle: ownBundleIdentifier),
            configuration: config(),
            ownBundleIdentifier: ownBundleIdentifier
        )

        XCTAssertEqual(decision, .focused(detail: "ADHD Guard settings"))
    }

    private func config(
        applications: [ApplicationRule] = [],
        websites: [WebsiteRule] = []
    ) -> GuardConfiguration {
        var configuration = GuardConfiguration.defaults
        configuration.applicationRules = applications
        configuration.websiteRules = websites
        return configuration
    }

    private func context(
        app: String,
        bundle: String,
        url: URL? = nil,
        browser: Bool = false
    ) -> ActivityContext {
        ActivityContext(
            applicationName: app,
            bundleIdentifier: bundle,
            browserURL: url,
            isBrowser: browser,
            idleSeconds: 0
        )
    }
}

final class GuardSessionStateTests: XCTestCase {
    func testDistractedContextChangesKeepOriginalStartTime() {
        var episode = DistractionEpisode()
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Blocked A", immediate: false),
                now: start,
                graceSeconds: 20
            ),
            20
        )
        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Blocked B", immediate: false),
                now: start.addingTimeInterval(7),
                graceSeconds: 20
            ),
            13
        )
        XCTAssertEqual(episode.startedAt, start)
    }

    func testAlarmRemainsLatchedUntilFocusedContext() {
        var episode = DistractionEpisode()
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Blocked", immediate: true),
                now: start,
                graceSeconds: 20
            ),
            0
        )
        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Unlisted", immediate: false),
                now: start.addingTimeInterval(1),
                graceSeconds: 20
            ),
            0
        )
        XCTAssertTrue(episode.isAlarmLatched)

        XCTAssertNil(
            episode.remaining(
                for: .focused(detail: "Allowed"),
                now: start.addingTimeInterval(2),
                graceSeconds: 20
            )
        )
        XCTAssertFalse(episode.isAlarmLatched)
        XCTAssertNil(episode.startedAt)
    }

    func testResetAfterAlarmReturnStartsANewFullBuffer() {
        var episode = DistractionEpisode()
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Unlisted app", immediate: false),
                now: start,
                graceSeconds: 20
            ),
            20
        )
        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Unlisted app", immediate: false),
                now: start.addingTimeInterval(20),
                graceSeconds: 20
            ),
            0
        )

        episode.reset()

        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Another unlisted app", immediate: false),
                now: start.addingTimeInterval(21),
                graceSeconds: 20
            ),
            20
        )
        XCTAssertFalse(episode.isAlarmLatched)
    }

    func testImmediateBlockLatchesAnExistingGraceEpisode() {
        var episode = DistractionEpisode()
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Unlisted app", immediate: false),
                now: start,
                graceSeconds: 20
            ),
            20
        )
        XCTAssertEqual(
            episode.remaining(
                for: .distracted(detail: "Blocked website", immediate: true),
                now: start.addingTimeInterval(5),
                graceSeconds: 20
            ),
            0
        )
        XCTAssertEqual(episode.startedAt, start)
        XCTAssertTrue(episode.isAlarmLatched)
    }

    func testRecentHostsAreNewestFirstDeduplicatedAndCapped() {
        var history = RecentHostHistory()

        history.record("www.youtube.com")
        history.record("reddit.com")
        history.record("news.ycombinator.com")
        history.record("youtube.com")
        history.record("example.com")

        XCTAssertEqual(history.hosts, ["example.com", "youtube.com", "news.ycombinator.com"])
    }

    func testRecentApplicationsAreNewestFirstDeduplicatedAndCapped() {
        var history = RecentApplicationHistory()

        history.record(name: "Finder", bundleIdentifier: "com.apple.finder")
        history.record(name: "Notes", bundleIdentifier: "com.apple.Notes")
        history.record(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap")
        history.record(name: "Finder", bundleIdentifier: "com.apple.finder")
        history.record(name: "Music", bundleIdentifier: "com.apple.Music")

        XCTAssertEqual(
            history.applications,
            [
                RecentApplication(name: "Music", bundleIdentifier: "com.apple.Music"),
                RecentApplication(name: "Finder", bundleIdentifier: "com.apple.finder"),
                RecentApplication(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap")
            ]
        )
    }

    func testFocusReturnHistoryKeepsLastFocusedExternalContext() {
        var history = FocusReturnHistory()
        let focusedContext = ActivityContext(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            browserURL: URL(string: "https://developer.apple.com/documentation"),
            isBrowser: true,
            idleSeconds: 0
        )

        history.record(
            decision: .focused(detail: "Allowed website"),
            context: focusedContext,
            processIdentifier: 42,
            isOwnApplication: false,
            isUserVisibleApplication: true
        )
        history.record(
            decision: .distracted(detail: "Blocked website", immediate: true),
            context: contextForHistory(name: "Safari", bundle: "com.apple.Safari"),
            processIdentifier: 42,
            isOwnApplication: false,
            isUserVisibleApplication: true
        )

        XCTAssertEqual(
            history.target,
            FocusReturnTarget(
                processIdentifier: 42,
                applicationName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                browserURL: URL(string: "https://developer.apple.com/documentation")
            )
        )
    }

    func testFocusReturnHistoryIgnoresADHDGuardItself() {
        var history = FocusReturnHistory()
        history.record(
            decision: .focused(detail: "ADHD Guard settings"),
            context: contextForHistory(name: "ADHD Guard", bundle: "com.funkydevil.ADHDGuard"),
            processIdentifier: 7,
            isOwnApplication: true,
            isUserVisibleApplication: true
        )

        XCTAssertNil(history.target)
    }

    func testBrowserTabActivationScriptEscapesURLAndTargetsBrowser() throws {
        let descriptor = try XCTUnwrap(BrowserURLReader.descriptor(for: "com.google.Chrome"))
        let url = try XCTUnwrap(URL(string: "https://example.com/search?q=%22focus%22"))
        let script = try XCTUnwrap(BrowserURLReader.tabActivationScript(for: descriptor, url: url))

        XCTAssertTrue(script.contains("tell application \"Google Chrome\""))
        XCTAssertTrue(script.contains(url.absoluteString))
        XCTAssertTrue(script.contains("set active tab index"))
    }

    func testAlarmPointerInteractionDistinguishesClickFromDrag() {
        XCTAssertTrue(
            AlarmPointerInteraction.isClick(
                from: CGPoint(x: 100, y: 100),
                to: CGPoint(x: 101, y: 100)
            )
        )
        XCTAssertFalse(
            AlarmPointerInteraction.isClick(
                from: CGPoint(x: 100, y: 100),
                to: CGPoint(x: 103, y: 100)
            )
        )
    }

    private func contextForHistory(name: String, bundle: String) -> ActivityContext {
        ActivityContext(
            applicationName: name,
            bundleIdentifier: bundle,
            browserURL: nil,
            isBrowser: false,
            idleSeconds: 0
        )
    }
}

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testNotFoundStatusDoesNotShowAnErrorBeforeRegistrationIsAttempted() {
        let service = LaunchAtLoginServiceFake(status: .notFound)
        let controller = LaunchAtLoginController(service: service)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertNil(controller.errorMessage)
    }

    func testNotFoundStatusCanRecoverByRegistering() {
        let service = LaunchAtLoginServiceFake(status: .notFound)
        service.statusAfterRegister = .enabled
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.errorMessage)
    }

    func testRegistrationFailureShowsAnActionableErrorOnlyAfterAttempt() {
        let service = LaunchAtLoginServiceFake(status: .notFound)
        service.registerError = LaunchAtLoginTestError.denied
        let controller = LaunchAtLoginController(service: service)

        controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertTrue(controller.errorMessage?.contains("macOS could not update Start at Login") == true)
        XCTAssertTrue(controller.errorMessage?.contains("Applications") == true)
    }
}

private final class LaunchAtLoginServiceFake: LaunchAtLoginServicing {
    var status: SMAppService.Status
    var statusAfterRegister: SMAppService.Status?
    var registerError: Error?
    private(set) var registerCallCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        if let statusAfterRegister {
            status = statusAfterRegister
        }
    }

    func unregister() throws {
        status = .notRegistered
    }
}

private enum LaunchAtLoginTestError: LocalizedError {
    case denied

    var errorDescription: String? { "Registration denied" }
}

@MainActor
final class ConfigurationStoreTests: XCTestCase {
    func testBrowserRulesAreMigratedOnceWithoutOverwritingLaterRemoval() throws {
        let suiteName = "ADHDGuardTests.ConfigurationStore.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var legacyConfiguration = GuardConfiguration.defaults
        let browserBundleIdentifiers = Set(
            GuardConfiguration.browserApplicationRules.map { $0.bundleIdentifier.lowercased() }
        )
        legacyConfiguration.applicationRules.removeAll {
            browserBundleIdentifiers.contains($0.bundleIdentifier.lowercased())
        }
        legacyConfiguration.applicationRules.append(
            ApplicationRule(name: "My App", bundleIdentifier: "com.example.my-app", policy: .blocked)
        )
        defaults.set(
            try JSONEncoder().encode(legacyConfiguration),
            forKey: "adhd-guard.configuration.v1"
        )

        let migratedStore = ConfigurationStore(defaults: defaults)
        XCTAssertTrue(GuardConfiguration.browserApplicationRules.allSatisfy { browser in
            migratedStore.configuration.applicationRules.contains {
                $0.bundleIdentifier.caseInsensitiveCompare(browser.bundleIdentifier) == .orderedSame
                    && $0.policy == .allowed
            }
        })
        XCTAssertTrue(migratedStore.configuration.applicationRules.contains {
            $0.bundleIdentifier == "com.example.my-app" && $0.policy == .blocked
        })

        migratedStore.configuration.applicationRules.removeAll {
            $0.bundleIdentifier == "com.apple.Safari"
        }
        let reloadedStore = ConfigurationStore(defaults: defaults)

        XCTAssertFalse(reloadedStore.configuration.applicationRules.contains {
            $0.bundleIdentifier == "com.apple.Safari"
        })
    }
}
