import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                focusSurface

                LazyVGrid(columns: columns, spacing: 14) {
                    MetricCard(
                        title: "Application",
                        value: monitor.currentContext?.applicationName ?? "No activity yet",
                        detail: monitor.currentContext?.bundleIdentifier ?? "Waiting for the first check",
                        symbol: "macwindow"
                    )
                    MetricCard(
                        title: "Website",
                        value: monitor.currentContext?.browserURL?.host ?? "Not in a browser",
                        detail: monitor.currentContext?.browserURL?.absoluteString ?? "Active tab appears here",
                        symbol: "globe"
                    )
                    MetricCard(
                        title: "Focus buffer",
                        value: timerValue,
                        detail: "Up to \(store.configuration.distractionGraceSeconds)s outside focus",
                        symbol: "timer"
                    )
                }

                HStack(spacing: 10) {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(GuardPalette.accent)
                    Text("Idle time")
                        .font(.subheadline.weight(.semibold))
                    Text(duration(monitor.currentContext?.idleSeconds ?? 0))
                        .font(.subheadline.monospacedDigit())
                    Spacer()
                    Text(idleDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .guardCard(cornerRadius: 12)

                if let browserAccessMessage = monitor.browserAccessMessage {
                    NoticeView(
                        title: "Browser access needs attention",
                        message: browserAccessMessage + " Enable access in System Settings › Privacy & Security › Automation.",
                        symbol: "lock.trianglebadge.exclamationmark",
                        color: GuardPalette.warning
                    )
                }
            }
            .frame(maxWidth: 800, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Dashboard")
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: store.configuration.monitoringEnabled ? "scope" : "pause.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 54, height: 54)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(store.configuration.monitoringEnabled ? "Guard is active" : "Guard is paused")
                    .font(.system(size: 25, weight: .semibold))
                Text(monitor.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            StatusBadge(title: statusLabel, color: statusColor)
        }
    }

    private var focusSurface: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("CURRENT FOCUS STATE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(focusHeadline)
                    .font(.system(size: 20, weight: .semibold))
                Text(focusDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: focusSymbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 58, height: 58)
                .background(statusColor.opacity(0.1), in: Circle())
        }
        .padding(20)
        .guardCard(cornerRadius: 14)
    }

    private var statusColor: Color {
        guard store.configuration.monitoringEnabled else { return .secondary }
        guard let decision = monitor.lastDecision else { return GuardPalette.accent }
        switch decision {
        case .focused: return GuardPalette.focused
        case .distracted: return monitor.distractionRemaining == 0 ? GuardPalette.alarm : GuardPalette.warning
        }
    }

    private var statusLabel: String {
        guard store.configuration.monitoringEnabled else { return "Paused" }
        guard let decision = monitor.lastDecision else { return "Starting" }
        switch decision {
        case .focused: return "Focused"
        case .distracted: return monitor.distractionRemaining == 0 ? "Refocus now" : "Outside focus"
        }
    }

    private var focusHeadline: String {
        guard store.configuration.monitoringEnabled else { return "Monitoring is paused" }
        switch monitor.lastDecision {
        case .focused: return "You’re in a focused context"
        case .distracted: return monitor.distractionRemaining == 0 ? "The focus reminder is active" : "Your focus buffer is running"
        case nil: return "Waiting for activity"
        }
    }

    private var focusDetail: String {
        if let host = monitor.currentContext?.browserURL?.host {
            return "\(monitor.currentContext?.applicationName ?? "Browser") · \(host)"
        }
        return monitor.currentContext?.applicationName ?? "Open an app to begin monitoring."
    }

    private var focusSymbol: String {
        switch monitor.lastDecision {
        case .focused: "checkmark.circle.fill"
        case .distracted: monitor.distractionRemaining == 0 ? "exclamationmark.circle.fill" : "hourglass.circle.fill"
        case nil: "scope"
        }
    }

    private var timerValue: String {
        if let remaining = monitor.distractionRemaining {
            return remaining == 0 ? "Alerting" : "\(remaining)s left"
        }
        return "Ready"
    }

    private var idleDetail: String {
        store.configuration.idleMonitoringEnabled
            ? "Warn after \(duration(TimeInterval(store.configuration.idleThresholdSeconds)))"
            : "Idle reminders are off"
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total < 60 { return "\(total)s" }
        return "\(total / 60)m \(total % 60)s"
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .guardCard(cornerRadius: 14)
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
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
