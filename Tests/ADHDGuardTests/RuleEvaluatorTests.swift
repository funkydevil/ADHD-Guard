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
