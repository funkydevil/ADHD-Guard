import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 16) {
                    FocusModeControl(
                        isOn: $store.configuration.monitoringEnabled,
                        isLocked: isDistractionAlertActive,
                        graceSeconds: store.configuration.distractionGraceSeconds,
                        remaining: monitor.distractionRemaining
                    )
                }
                .padding(20)
                .guardCard(cornerRadius: 20)
                .background {
                    AuroraBackdrop(presentation: presentation)
                        .opacity(0.5)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(activityHeading)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let activity = dashboardActivities.first {
                        DashboardActivityRow(
                            activity: activity,
                            openActivity: { openActivity(activity) }
                        )
                    }
                    if let contextActionTitle {
                        Button(contextActionTitle, action: performContextAction)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                if dashboardActivities.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent activity")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 6) {
                            ForEach(dashboardActivities.dropFirst()) { activity in
                                DashboardActivityRow(
                                    activity: activity,
                                    openActivity: { openActivity(activity) }
                                )
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your focus lists")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        RuleShortcutCard(
                            title: "Focus apps",
                            count: store.configuration.applicationRules.count,
                            detail: "Other apps start the timer",
                            symbol: "app.badge.checkmark",
                            color: GuardPalette.focused,
                            action: { navigation.openRules(.focusApps) }
                        )
                        RuleShortcutCard(
                            title: "Distracting sites",
                            count: store.configuration.websiteRules.count,
                            detail: "Sites that start the timer",
                            symbol: "globe.badge.chevron.backward",
                            color: GuardPalette.alarm,
                            action: { navigation.openRules(.distractingSites) }
                        )
                    }
                }

                if let browserAccessMessage = monitor.browserAccessMessage {
                    NoticeView(
                        title: "Browser access needs attention",
                        message: browserAccessMessage + " Enable access in System Settings › Privacy & Security › Automation.",
                        symbol: "lock.trianglebadge.exclamationmark",
                        color: GuardPalette.warning
                    )
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }

    private var activityHeading: String {
        let ownIdentifier = Bundle.main.bundleIdentifier ?? "com.funkydevil.ADHDGuard"
        return monitor.currentContext?.bundleIdentifier.caseInsensitiveCompare(ownIdentifier) == .orderedSame
            ? "Last active" : "Current activity"
    }

    private var displayContext: ActivityContext? {
        guard let current = monitor.currentContext else {
            return monitor.lastExternalContext
        }

        let ownIdentifier = Bundle.main.bundleIdentifier ?? "com.funkydevil.ADHDGuard"
        if current.bundleIdentifier.caseInsensitiveCompare(ownIdentifier) == .orderedSame {
            return monitor.lastExternalContext
        }
        return current
    }

    private var displayDecision: RuleDecision? {
        guard let displayContext else { return nil }
        return RuleEvaluator.evaluate(
            context: displayContext,
            configuration: store.configuration,
            ownBundleIdentifier: Bundle.main.bundleIdentifier
        )
    }

    private var presentation: GuardStatusPresentation {
        GuardStatusPresentation(
            monitoringEnabled: store.configuration.monitoringEnabled,
            decision: displayDecision,
            remaining: monitor.distractionRemaining,
            graceSeconds: store.configuration.distractionGraceSeconds
        )
    }

    private var isDistractionAlertActive: Bool {
        alarm.activeAlarm?.kind == .distraction
    }

    private var dashboardActivities: [DashboardActivity] {
        var activities: [DashboardActivity] = []
        var seenActivityIDs = Set<String>()

        if let context = displayContext {
            let normalizedIdentifier = context.bundleIdentifier.lowercased()
            let currentActivityID = RecentActivity(context: context)?.id
                ?? "application|\(normalizedIdentifier)"
            seenActivityIDs.insert(currentActivityID)
            activities.append(
                DashboardActivity(
                    id: "current|\(normalizedIdentifier)|\(context.browserURL?.host ?? "app")",
                    name: context.applicationName,
                    bundleIdentifier: context.bundleIdentifier,
                    detail: context.browserURL?.host ?? "Application",
                    badgeTitle: contextClassification,
                    badgeColor: classificationColor,
                    isCurrent: true,
                    browserURL: context.browserURL
                )
            )
        }

        for recentActivity in monitor.recentActivities {
            guard !seenActivityIDs.contains(recentActivity.id) else { continue }
            seenActivityIDs.insert(recentActivity.id)
            activities.append(dashboardActivity(from: recentActivity))
        }

        if activities.isEmpty {
            activities.append(
                DashboardActivity(
                    id: "waiting",
                    name: "Waiting for activity",
                    bundleIdentifier: nil,
                    detail: "Your recent activity will appear here",
                    badgeTitle: "Ready",
                    badgeColor: GuardPalette.accent,
                    isCurrent: true,
                    browserURL: nil
                )
            )
        }

        return Array(activities.prefix(4))
    }

    private func dashboardActivity(from recentActivity: RecentActivity) -> DashboardActivity {
        switch recentActivity.kind {
        case .application:
            let isFocusApplication = store.containsFocusApplication(
                bundleIdentifier: recentActivity.bundleIdentifier
            )
            return DashboardActivity(
                id: "recent|\(recentActivity.id)",
                name: recentActivity.applicationName,
                bundleIdentifier: recentActivity.bundleIdentifier,
                detail: "Recently active",
                badgeTitle: isFocusApplication ? "In focus" : "Outside focus",
                badgeColor: isFocusApplication ? GuardPalette.focused : GuardPalette.warning,
                isCurrent: false,
                browserURL: nil
            )

        case let .website(host):
            let isDistractingSite = store.containsDistractingSite(host)
            let isFocusApplication = store.containsFocusApplication(
                bundleIdentifier: recentActivity.bundleIdentifier
            )
            let badgeTitle: String
            let badgeColor: Color
            if isDistractingSite {
                badgeTitle = "Distracting site"
                badgeColor = GuardPalette.alarm
            } else if isFocusApplication {
                badgeTitle = "In focus"
                badgeColor = GuardPalette.focused
            } else {
                badgeTitle = "Outside focus"
                badgeColor = GuardPalette.warning
            }
            return DashboardActivity(
                id: "recent|\(recentActivity.id)",
                name: recentActivity.applicationName,
                bundleIdentifier: recentActivity.bundleIdentifier,
                detail: host,
                badgeTitle: badgeTitle,
                badgeColor: badgeColor,
                isCurrent: false,
                browserURL: recentActivity.browserURL
            )
        }
    }

    private var contextClassification: String {
        guard let context = displayContext else { return "Waiting for activity" }
        if let host = context.browserURL?.host, store.containsDistractingSite(host) {
            return "Distracting site"
        }
        if store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier) {
            return "In focus"
        }
        return "Outside focus"
    }

    private var classificationColor: Color {
        switch contextClassification {
        case "Distracting site": GuardPalette.alarm
        case "In focus": GuardPalette.focused
        default: GuardPalette.warning
        }
    }

    private var contextActionTitle: String? {
        guard let context = displayContext else { return nil }
        if let host = context.browserURL?.host {
            return store.containsDistractingSite(host)
                ? nil
                : "Mark site as distracting"
        }
        return store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier)
            ? nil
            : "Add to focus apps"
    }

    private func performContextAction() {
        guard let context = displayContext else { return }
        if let host = context.browserURL?.host {
            if store.containsDistractingSite(host) {
                navigation.openRules(.distractingSites)
            } else {
                _ = store.addDistractingSite(host)
            }
            return
        }

        if store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier) {
            navigation.openRules(.focusApps)
        } else {
            store.addFocusApplication(
                name: context.applicationName,
                bundleIdentifier: context.bundleIdentifier
            )
        }
    }

    private func openActivity(_ activity: DashboardActivity) {
        guard let bundleIdentifier = activity.bundleIdentifier else { return }

        let workspace = NSWorkspace.shared
        let applicationURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)

        if let browserURL = activity.browserURL,
           let descriptor = BrowserURLReader.descriptor(for: bundleIdentifier) {
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

        if let runningApplication = workspace.runningApplications.first(where: {
            $0.bundleIdentifier?.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }) {
            runningApplication.unhide()
            if #available(macOS 14.0, *) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.yieldActivation(to: runningApplication)
                _ = runningApplication.activate(
                    from: NSRunningApplication.current,
                    options: [.activateAllWindows]
                )
            } else {
                _ = runningApplication.activate(
                    options: [.activateAllWindows, .activateIgnoringOtherApps]
                )
            }
            return
        }

        if let applicationURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            workspace.openApplication(at: applicationURL, configuration: configuration)
        }
    }
}

private struct DashboardActivity: Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let detail: String
    let badgeTitle: String
    let badgeColor: Color
    let isCurrent: Bool
    let browserURL: URL?
}

private struct AuroraBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let presentation: GuardStatusPresentation

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                cloudBlob(
                    color: GuardPalette.cloudBase,
                    width: proxy.size.width * 1.14,
                    height: proxy.size.height * 1.04,
                    x: 0,
                    y: 8,
                    blur: reduceTransparency ? 48 : 68,
                    opacity: 0.98
                )

                cloudBlob(
                    color: presentation.gradientColors[0],
                    width: proxy.size.width * 0.72,
                    height: proxy.size.height * 0.62,
                    x: -proxy.size.width * 0.27,
                    y: -proxy.size.height * 0.18,
                    blur: reduceTransparency ? 42 : 62,
                    opacity: reduceTransparency ? 0.60 : 0.86
                )

                cloudBlob(
                    color: presentation.gradientColors[1],
                    width: proxy.size.width * 0.80,
                    height: proxy.size.height * 0.72,
                    x: proxy.size.width * 0.28,
                    y: proxy.size.height * 0.02,
                    blur: reduceTransparency ? 46 : 68,
                    opacity: reduceTransparency ? 0.54 : 0.78
                )

                cloudBlob(
                    color: presentation.gradientColors[2],
                    width: proxy.size.width * 0.68,
                    height: proxy.size.height * 0.58,
                    x: -proxy.size.width * 0.08,
                    y: proxy.size.height * 0.30,
                    blur: reduceTransparency ? 44 : 66,
                    opacity: reduceTransparency ? 0.48 : 0.72
                )

                cloudBlob(
                    color: presentation.color,
                    width: proxy.size.width * 0.44,
                    height: proxy.size.height * 0.42,
                    x: proxy.size.width * 0.15,
                    y: proxy.size.height * 0.30,
                    blur: reduceTransparency ? 38 : 58,
                    opacity: reduceTransparency ? 0.44 : 0.68
                )
            }
            .compositingGroup()
        }
        .opacity(reduceTransparency ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cloudBlob(
        color: Color,
        width: CGFloat,
        height: CGFloat,
        x: CGFloat,
        y: CGFloat,
        blur: CGFloat,
        opacity: Double
    ) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.72), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(width, height) * 0.48
                )
            )
            .frame(width: width, height: height)
            .blur(radius: blur)
            .opacity(opacity)
            .offset(x: x, y: y)
            .blendMode(.screen)
    }
}

private struct DashboardActivityRow: View {
    @State private var isHovering = false
    let activity: DashboardActivity
    let openActivity: () -> Void

    var body: some View {
        Button(action: openActivity) {
            HStack(spacing: 12) {
                if let bundleIdentifier = activity.bundleIdentifier {
                    ApplicationIcon(bundleIdentifier: bundleIdentifier, size: activity.isCurrent ? 36 : 30)
                } else {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.name)
                        .font(.system(size: activity.isCurrent ? 15 : 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(activity.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if activity.bundleIdentifier != nil {
                    StatusBadge(title: activity.badgeTitle, color: activity.badgeColor)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundStyle(isHovering ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: activity.isCurrent ? 68 : 54)
            .background(isHovering ? Color.white.opacity(0.06) : .clear)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .guardCard(cornerRadius: 14)
        .disabled(activity.bundleIdentifier == nil)
        .onHover { isHovering = $0 }
        .help(activity.bundleIdentifier == nil ? "Waiting for activity" : "Switch to \(activity.name)")
    }
}

private struct RuleShortcutCard: View {
    let title: String
    let count: Int
    let detail: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(title) · \(count)")
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .guardCard(cornerRadius: 18)
    }
}

struct NoticeView: View {
    let title: String
    let message: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
