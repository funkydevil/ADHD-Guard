import AppKit
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginController
    @State private var confirmsReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("Tune your reminders. Keep everything else quiet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                generalCard
                focusTimingCard
                remindersCard
                privacyCard

                Divider()
                    .padding(.top, 2)

                HStack {
                    Spacer()
                    Button("Restore defaults…", role: .destructive) {
                        confirmsReset = true
                    }
                    .buttonStyle(.borderless)
                }
            }
            .frame(maxWidth: 700)
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog(
            "Restore every setting to its default?",
            isPresented: $confirmsReset,
            titleVisibility: .visible
        ) {
            Button("Restore defaults", role: .destructive) {
                store.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your focus apps and distracting sites will also be reset.")
        }
    }

    private var generalCard: some View {
        SettingsSectionCard(
            title: "General",
            subtitle: "Keep Guard ready when your Mac starts.",
            symbol: "power",
            color: GuardPalette.accent
        ) {
            Toggle(
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            ) {
                SettingsRowLabel(
                    title: "Launch at login",
                    detail: "Start quietly in the menu bar."
                )
            }

            if launchAtLogin.requiresApproval {
                Divider()
                PermissionNotice(
                    title: "Approval required",
                    detail: "Allow ADHD Guard in Login Items to finish setup.",
                    color: GuardPalette.warning,
                    actionTitle: "Open Login Items",
                    action: launchAtLogin.openLoginItemsSettings
                )
            }

            if let errorMessage = launchAtLogin.errorMessage {
                Divider()
                Label(errorMessage, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(GuardPalette.alarm)
            }
        }
    }

    private var focusTimingCard: some View {
        SettingsSectionCard(
            title: "Focus timing",
            subtitle: "Choose when a detour becomes a reminder.",
            symbol: "timer",
            color: GuardPalette.warning
        ) {
            HStack(spacing: 14) {
                SettingsRowLabel(
                    title: "Focus buffer",
                    detail: "Time allowed outside focus before reminders begin."
                )
                Spacer(minLength: 12)
                Stepper(
                    value: $store.configuration.distractionGraceSeconds,
                    in: 0...600,
                    step: 5
                ) {
                    SettingsValueBadge(text: "\(store.configuration.distractionGraceSeconds) sec", color: GuardPalette.warning)
                }
            }

            Divider()

            Toggle(isOn: $store.configuration.idleMonitoringEnabled) {
                SettingsRowLabel(
                    title: "Idle reminder",
                    detail: "Nudge me after no keyboard or mouse activity."
                )
            }

            if store.configuration.idleMonitoringEnabled {
                Divider()
                HStack(spacing: 14) {
                    SettingsRowLabel(
                        title: "Remind me after",
                        detail: "Only while focus reminders are active."
                    )
                    Spacer(minLength: 12)
                    Stepper(
                        value: $store.configuration.idleThresholdSeconds,
                        in: 30...3600,
                        step: 30
                    ) {
                        SettingsValueBadge(text: idleThresholdText, color: GuardPalette.warning)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    private var remindersCard: some View {
        SettingsSectionCard(
            title: "Reminders",
            subtitle: "Make the interruption noticeable, not noisy.",
            symbol: "bell.badge",
            color: GuardPalette.focused
        ) {
            Toggle(isOn: $store.configuration.playsSound) {
                SettingsRowLabel(
                    title: "Chime",
                    detail: "Play a soft repeating sound."
                )
            }

            Divider()

            Toggle(isOn: $store.configuration.speaksWarnings) {
                SettingsRowLabel(
                    title: "Spoken reminder",
                    detail: "Speak a phrase until you return to focus."
                )
            }

            if store.configuration.speaksWarnings {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("CUSTOMIZE PHRASES")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LabeledContent("Focus phrase") {
                        TextField("Focus phrase", text: $store.configuration.focusPhrase)
                            .labelsHidden()
                            .frame(maxWidth: 330)
                    }

                    LabeledContent("Idle phrase") {
                        TextField("Idle phrase", text: $store.configuration.idlePhrase)
                            .labelsHidden()
                            .frame(maxWidth: 330)
                    }
                }
                .padding(.leading, 12)
            }

            Divider()

            HStack {
                Text("Sound repeats every 15s · voice every 30s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Preview reminder") {
                    alarm.preview(
                        phrase: store.configuration.focusPhrase,
                        speaks: store.configuration.speaksWarnings,
                        playsSound: store.configuration.playsSound
                    )
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var privacyCard: some View {
        SettingsSectionCard(
            title: "App & Privacy",
            subtitle: "Active context stays on this Mac.",
            symbol: "lock.shield",
            color: GuardPalette.focused
        ) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(GuardPalette.focused)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Browser access")
                            .font(.subheadline.weight(.semibold))
                        StatusBadge(title: "Local only", color: GuardPalette.focused)
                    }
                    Text("Only the active tab is checked against your rules. Browsing history is never stored.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let browserAccessMessage = monitor.browserAccessMessage {
                Divider()
                PermissionNotice(
                    title: "Browser access needs attention",
                    detail: browserAccessMessage,
                    color: GuardPalette.warning,
                    actionTitle: "Open Automation Settings",
                    action: openAutomationSettings
                )
            }
        }
    }

    private var idleThresholdText: String {
        let seconds = store.configuration.idleThresholdSeconds
        return seconds.isMultiple(of: 60)
            ? "\(seconds / 60) min"
            : "\(seconds / 60)m \(seconds % 60)s"
    }

    private func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .guardCard(cornerRadius: 18)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsValueBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.1), in: Capsule())
    }
}

private struct PermissionNotice: View {
    let title: String
    let detail: String
    let color: Color
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
