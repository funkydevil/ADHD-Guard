import AppKit
import SwiftUI

struct MenuBarGuardView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Toggle(isOn: $store.configuration.monitoringEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guard enabled")
                        .font(.subheadline.weight(.semibold))
                    Text(toggleDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(isDistractionAlertActive)

            currentContext

            Divider()

            VStack(spacing: 2) {
                NavigationRow(title: "Open Dashboard", symbol: "rectangle.grid.1x2") {
                    open(.dashboard)
                }
                NavigationRow(title: "Applications", symbol: "app.dashed") {
                    open(.applications)
                }
                NavigationRow(title: "Websites", symbol: "globe") {
                    open(.websites)
                }
                NavigationRow(title: "Preferences", symbol: "slider.horizontal.3") {
                    open(.preferences)
                }
            }

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit ADHD Guard", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .disabled(isDistractionAlertActive)
            .help(isDistractionAlertActive ? "Return to an allowed context before quitting" : "Quit ADHD Guard")
        }
        .padding(16)
        .frame(width: 316)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "scope")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(GuardPalette.accent)
                .frame(width: 36, height: 36)
                .background(GuardPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("ADHD Guard")
                    .font(.headline)
                Text(monitor.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .accessibilityLabel(statusLabel)
        }
    }

    private var currentContext: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("CURRENT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(contextState)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Text(monitor.currentContext?.applicationName ?? "Waiting for activity")
                .font(.subheadline.weight(.semibold))
            if let host = monitor.currentContext?.browserURL?.host {
                Text(host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .guardCard(cornerRadius: 12)
    }

    private var isDistractionAlertActive: Bool {
        alarm.activeAlarm?.kind == .distraction
    }

    private var toggleDetail: String {
        isDistractionAlertActive
            ? "Return to an allowed context before pausing"
            : "Watch active apps and browser tabs"
    }

    private var contextState: String {
        if let remaining = monitor.distractionRemaining {
            return remaining == 0 ? "Refocus" : "\(remaining)s"
        }
        return store.configuration.monitoringEnabled ? "Focused" : "Paused"
    }

    private var statusColor: Color {
        guard store.configuration.monitoringEnabled else { return .secondary }
        if monitor.distractionRemaining == 0 { return GuardPalette.alarm }
        if monitor.distractionRemaining != nil { return GuardPalette.warning }
        return GuardPalette.focused
    }

    private var statusLabel: String {
        store.configuration.monitoringEnabled ? contextState : "Paused"
    }

    private func open(_ section: GuardSection) {
        navigation.selection = section
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct NavigationRow: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 18)
                    .foregroundStyle(GuardPalette.accent)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }
}
