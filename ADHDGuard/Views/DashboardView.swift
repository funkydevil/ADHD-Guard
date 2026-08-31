import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 7) {
                    Text("Your focus, at a glance")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("One status. One current activity. Nothing else competing for attention.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                StatusOrb(presentation: presentation)
                    .padding(.vertical, 4)

                if !store.configuration.monitoringEnabled {
                    Button("Start Guard", action: startGuard)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                ActiveContextCard(
                    context: displayContext,
                    classification: contextClassification,
                    classificationColor: classificationColor,
                    actionTitle: contextActionTitle,
                    action: performContextAction
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

    private func startGuard() {
        store.configuration.monitoringEnabled = true
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
}

private struct ActiveContextCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let context: ActivityContext?
    let classification: String
    let classificationColor: Color
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            if let context {
                ApplicationIcon(bundleIdentifier: context.bundleIdentifier, size: 50)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(GuardPalette.accent)
                    .frame(width: 50, height: 50)
                    .background(GuardPalette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Current activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context?.applicationName ?? "Waiting for activity")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if let host = context?.browserURL?.host {
                    Text(host)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                StatusBadge(title: classification, color: classificationColor)
                    .padding(.top, 3)
            }

            Spacer(minLength: 12)

            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(classificationColor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .guardCard(cornerRadius: 22)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: (context?.bundleIdentifier ?? "") + "|" + (context?.browserURL?.host ?? "")
        )
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
