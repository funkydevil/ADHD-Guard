import AppKit
import SwiftUI

struct MenuBarGuardView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ADHD Guard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    open(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
                .accessibilityLabel("Settings")
            }

            FocusModeControl(
                isOn: $store.configuration.monitoringEnabled,
                isLocked: isDistractionAlertActive,
                graceSeconds: store.configuration.distractionGraceSeconds,
                remaining: monitor.distractionRemaining,
                compact: true
            )

            Divider()

            if let context = displayContext {
                VStack(alignment: .leading, spacing: 10) {
                    Text(activityHeading)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ApplicationIcon(bundleIdentifier: context.bundleIdentifier, size: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(context.applicationName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(context.browserURL?.host ?? contextClassification)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if context.browserURL?.host != nil {
                                Text(contextClassification)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(classificationColor)
                            }
                        }
                        Spacer(minLength: 4)
                    }
                    if let contextActionTitle {
                        Button(contextActionTitle, action: performContextAction)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
            }

            if monitor.browserAccessMessage != nil {
                Button {
                    open(.status)
                } label: {
                    Label("Browser access needs attention", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(GuardPalette.warning)
                }
                .buttonStyle(.plain)
            }

            Divider()
            HStack {
                Button("Open app") { open(.status) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Quit ADHD Guard") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .disabled(isDistractionAlertActive)
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 340)
        .background(GuardPalette.canvasDark)
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
        return current.bundleIdentifier.caseInsensitiveCompare(ownIdentifier) == .orderedSame
            ? monitor.lastExternalContext
            : current
    }

    private var isDistractionAlertActive: Bool {
        alarm.activeAlarm?.kind == .distraction
    }

    private var contextClassification: String {
        guard let context = displayContext else { return "Waiting for activity" }
        if let host = context.browserURL?.host, store.containsDistractingSite(host) {
            return "Distracting site"
        }
        return store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier)
            ? "In focus" : "Outside focus"
    }

    private var contextActionTitle: String? {
        guard let context = displayContext else { return nil }
        if let host = context.browserURL?.host {
            return store.containsDistractingSite(host) ? nil : "Mark site as distracting"
        }
        return store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier)
            ? nil : "Add to focus apps"
    }

    private var classificationColor: Color {
        switch contextClassification {
        case "Distracting site": GuardPalette.alarm
        case "In focus": GuardPalette.focused
        default: GuardPalette.warning
        }
    }

    private func performContextAction() {
        guard let context = displayContext else { return }
        if let host = context.browserURL?.host {
            _ = store.addDistractingSite(host)
        } else {
            store.addFocusApplication(
                name: context.applicationName,
                bundleIdentifier: context.bundleIdentifier
            )
        }
    }

    private func open(_ section: GuardSection) {
        navigation.selection = section
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
