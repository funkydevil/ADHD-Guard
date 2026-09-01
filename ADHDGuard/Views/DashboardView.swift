import AppKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 7) {
                    Text("Your focus. Safeguarded.")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("See what has your attention — and shape your focus zone in one click.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                AuroraActivityScene(
                    presentation: presentation,
                    monitoringEnabled: $store.configuration.monitoringEnabled,
                    guardControlDisabled: isDistractionAlertActive,
                    activities: dashboardActivities,
                    actionTitle: contextActionTitle,
                    actionColor: contextActionColor,
                    action: performContextAction,
                    openActivity: openActivity
                )

                HStack(spacing: 14) {
                    RuleShortcutCard(
                        title: "Focus apps",
                        count: store.configuration.applicationRules.count,
                        detail: "Apps that keep you in flow",
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
        var seenBundleIdentifiers = Set<String>()

        if let context = displayContext {
            let normalizedIdentifier = context.bundleIdentifier.lowercased()
            seenBundleIdentifiers.insert(normalizedIdentifier)
            activities.append(
                DashboardActivity(
                    id: "current|\(normalizedIdentifier)|\(context.browserURL?.host ?? "app")",
                    name: context.applicationName,
                    bundleIdentifier: context.bundleIdentifier,
                    detail: context.browserURL?.host ?? "Current activity",
                    badgeTitle: contextClassification,
                    badgeColor: classificationColor,
                    isCurrent: true,
                    isPlaceholder: false,
                    isWebsite: context.browserURL != nil,
                    browserURL: context.browserURL
                )
            )
        }

        for application in monitor.recentApplications {
            let normalizedIdentifier = application.bundleIdentifier.lowercased()
            guard !seenBundleIdentifiers.contains(normalizedIdentifier) else { continue }
            seenBundleIdentifiers.insert(normalizedIdentifier)
            activities.append(
                DashboardActivity(
                    id: "recent|\(normalizedIdentifier)",
                    name: application.name,
                    bundleIdentifier: application.bundleIdentifier,
                    detail: "Recently active",
                    badgeTitle: store.containsFocusApplication(bundleIdentifier: application.bundleIdentifier)
                        ? "Focus app"
                        : "Recent app",
                    badgeColor: store.containsFocusApplication(bundleIdentifier: application.bundleIdentifier)
                        ? GuardPalette.focused
                        : GuardPalette.accent,
                    isCurrent: false,
                    isPlaceholder: false,
                    isWebsite: false,
                    browserURL: nil
                )
            )
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
                    isPlaceholder: false,
                    isWebsite: false,
                    browserURL: nil
                )
            )
        }

        activities = Array(activities.prefix(3))
        while activities.count < 3 {
            let slot = activities.count
            activities.append(
                DashboardActivity(
                    id: "empty|\(slot)",
                    name: "Recent activity",
                    bundleIdentifier: nil,
                    detail: slot == 1
                        ? "Your next app will appear here"
                        : "History stays on this Mac",
                    badgeTitle: "Next",
                    badgeColor: GuardPalette.accent,
                    isCurrent: false,
                    isPlaceholder: true,
                    isWebsite: false,
                    browserURL: nil
                )
            )
        }

        return activities
    }

    private var contextClassification: String {
        guard let context = displayContext else { return "Waiting for activity" }
        if let host = context.browserURL?.host, store.containsDistractingSite(host) {
            return "Distracting site"
        }
        if store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier) {
            return "Focus app"
        }
        return "Not in your lists"
    }

    private var classificationColor: Color {
        switch contextClassification {
        case "Distracting site": GuardPalette.alarm
        case "Focus app": GuardPalette.focused
        default: GuardPalette.accent
        }
    }

    private var contextActionTitle: String? {
        guard let context = displayContext else { return nil }
        if let host = context.browserURL?.host {
            return store.containsDistractingSite(host)
                ? "Open distracting sites"
                : "Mark site as distracting"
        }
        return store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier)
            ? "Open focus apps"
            : "Add app to focus"
    }

    private var contextActionColor: Color {
        guard let context = displayContext else { return GuardPalette.accent }
        return context.browserURL?.host == nil ? GuardPalette.focused : GuardPalette.alarm
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
        guard !activity.isPlaceholder,
              let bundleIdentifier = activity.bundleIdentifier else { return }

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
    let isPlaceholder: Bool
    let isWebsite: Bool
    let browserURL: URL?
}

private struct AuroraActivityScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentation: GuardStatusPresentation
    @Binding var monitoringEnabled: Bool
    let guardControlDisabled: Bool
    let activities: [DashboardActivity]
    let actionTitle: String?
    let actionColor: Color
    let action: () -> Void
    let openActivity: (DashboardActivity) -> Void

    var body: some View {
        ZStack {
            AuroraBackdrop(presentation: presentation)

            VStack(spacing: 19) {
                statusHeader
                PerspectiveActivityStack(
                    activities: activities,
                    actionTitle: actionTitle,
                    actionColor: actionColor,
                    action: action,
                    openActivity: openActivity
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 312)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.24),
            value: activities.map(\.id)
        )
        .accessibilityElement(children: .contain)
    }

    private var statusHeader: some View {
        HStack(spacing: 14) {
            GuardMark(
                presentation: presentation,
                size: 39,
                gateColor: .white.opacity(0.82),
                coreColor: .white
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(presentation.title)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                    if let shortValue = presentation.shortValue {
                        Text(shortValue)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.14), in: Capsule())
                    }
                }
                Text(presentation.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)

            Spacer(minLength: 12)

            Toggle(isOn: $monitoringEnabled) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Guard mode")
                        .font(.caption.weight(.semibold))
                    Text(monitoringEnabled ? "On" : "Paused")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .foregroundStyle(.white)
            }
            .toggleStyle(.switch)
            .tint(presentation.color)
            .disabled(guardControlDisabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.18), in: Capsule())
            .help(
                guardControlDisabled
                    ? "Return to a focus activity before pausing Guard."
                    : "Turn focus reminders on or off."
            )
            .accessibilityHint(
                guardControlDisabled
                    ? "Return to a focus activity before pausing Guard."
                    : "Turns focus reminders on or off."
            )
        }
    }
}

private struct AuroraBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isDrifting = false

    let presentation: GuardStatusPresentation

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.08)

                LinearGradient(
                    colors: presentation.gradientColors.map { $0.opacity(reduceTransparency ? 0.72 : 0.34) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if !reduceTransparency {
                    ribbon(
                        colors: [presentation.gradientColors[0], presentation.gradientColors[1], .clear],
                        width: proxy.size.width * 0.98,
                        height: 104,
                        rotation: -10,
                        x: isDrifting ? proxy.size.width * 0.10 : -proxy.size.width * 0.12,
                        y: -proxy.size.height * 0.20,
                        opacity: 0.78
                    )

                    ribbon(
                        colors: [.clear, presentation.gradientColors[2], presentation.gradientColors[0]],
                        width: proxy.size.width * 1.08,
                        height: 126,
                        rotation: 12,
                        x: isDrifting ? -proxy.size.width * 0.11 : proxy.size.width * 0.08,
                        y: proxy.size.height * 0.08,
                        opacity: 0.60
                    )

                    Circle()
                        .fill(presentation.color.opacity(0.48))
                        .frame(width: proxy.size.width * 0.42)
                        .blur(radius: 58)
                        .offset(
                            x: isDrifting ? proxy.size.width * 0.28 : proxy.size.width * 0.12,
                            y: proxy.size.height * 0.22
                        )
                        .blendMode(.screen)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.12), .black.opacity(0.48)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 16).repeatForever(autoreverses: true),
            value: isDrifting
        )
        .animation(.easeInOut(duration: reduceMotion ? 0 : 0.35), value: presentation.kind)
        .onAppear { updateMotion() }
        .onChange(of: reduceMotion) { _ in updateMotion() }
        .accessibilityHidden(true)
    }

    private func ribbon(
        colors: [Color],
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        x: CGFloat,
        y: CGFloat,
        opacity: Double
    ) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 32)
            .opacity(opacity)
            .offset(x: x, y: y)
            .blendMode(.screen)
    }

    private func updateMotion() {
        isDrifting = !reduceMotion
    }
}

private struct PerspectiveActivityStack: View {
    let activities: [DashboardActivity]
    let actionTitle: String?
    let actionColor: Color
    let action: () -> Void
    let openActivity: (DashboardActivity) -> Void

    var body: some View {
        VStack(spacing: 7) {
            ForEach(activities) { activity in
                let depth = activities.firstIndex(where: { $0.id == activity.id }) ?? 0
                PerspectiveActivityRow(
                    activity: activity,
                    depth: depth,
                    actionTitle: activity.isCurrent ? actionTitle : nil,
                    actionColor: actionColor,
                    action: action,
                    openActivity: { openActivity(activity) }
                )
                .scaleEffect(1 - CGFloat(depth) * 0.045)
                .rotation3DEffect(
                    .degrees(Double(depth) * -1.6),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    perspective: 0.42
                )
                .opacity(1 - Double(depth) * 0.18)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 205, alignment: .top)
    }
}

private struct PerspectiveActivityRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false
    @State private var isHovering = false

    let activity: DashboardActivity
    let depth: Int
    let actionTitle: String?
    let actionColor: Color
    let action: () -> Void
    let openActivity: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Button(action: openActivity) {
                HStack(spacing: 13) {
                    activityIcon

                    VStack(alignment: .leading, spacing: 3) {
                        Text(activity.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(activity.detail)
                            .font(activity.isWebsite ? .caption.monospaced() : .caption)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                    StatusBadge(title: activity.badgeTitle, color: activity.badgeColor)
                        .fixedSize()

                    if !activity.isPlaceholder {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(isHovering ? 0.82 : 0.46))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(activity.isPlaceholder)
            .help(activity.isPlaceholder ? "" : "Switch to \(activity.name)")

            if let actionTitle {
                Button(action: action) {
                    Label(
                        actionTitle,
                        systemImage: activity.isWebsite
                            ? "exclamationmark.shield"
                            : "plus.app"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(actionColor)
                .controlSize(.small)
                .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(
            .black.opacity((activity.isCurrent ? 0.24 : 0.16) + (isHovering ? 0.08 : 0)),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .opacity(activity.isPlaceholder ? 0.72 : 1)
        .offset(
            x: reduceMotion ? 0 : (isFloating ? floatingX : -floatingX),
            y: reduceMotion ? 0 : (isFloating ? -1.4 : 1.4)
        )
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 4.8 + Double(depth) * 0.65).repeatForever(autoreverses: true),
            value: isFloating
        )
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .onAppear { updateFloatingState() }
        .onChange(of: reduceMotion) { _ in updateFloatingState() }
        .onHover { isHovering = $0 && !activity.isPlaceholder }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var activityIcon: some View {
        if let bundleIdentifier = activity.bundleIdentifier {
            ApplicationIcon(bundleIdentifier: bundleIdentifier, size: 36)
        } else {
            Image(systemName: activity.isPlaceholder ? "clock.arrow.circlepath" : "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private var floatingX: CGFloat {
        depth.isMultiple(of: 2) ? 0.8 : -0.8
    }

    private func updateFloatingState() {
        isFloating = !reduceMotion
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
