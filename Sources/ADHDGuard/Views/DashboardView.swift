import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatusCard(
                        title: "Active application",
                        value: monitor.currentContext?.applicationName ?? "—",
                        detail: monitor.currentContext?.bundleIdentifier ?? "Start Guard to inspect activity",
                        symbol: "macwindow"
                    )
                    StatusCard(
                        title: "Browser tab",
                        value: monitor.currentContext?.browserURL?.host ?? "—",
                        detail: monitor.currentContext?.browserURL?.absoluteString ?? "No browser URL detected",
                        symbol: "globe"
                    )
                    StatusCard(
                        title: "Idle time",
                        value: duration(monitor.currentContext?.idleSeconds ?? 0),
                        detail: store.configuration.idleMonitoringEnabled
                            ? "Alert after \(duration(TimeInterval(store.configuration.idleThresholdSeconds)))"
                            : "Idle alerts are disabled",
                        symbol: "timer"
                    )
                    StatusCard(
                        title: "Distraction budget",
                        value: monitor.distractionRemaining.map { "\($0)s" } ?? "Ready",
                        detail: "Maximum \(store.configuration.distractionGraceSeconds) seconds outside focus",
                        symbol: "hourglass"
                    )
                }

                if let browserAccessMessage = monitor.browserAccessMessage {
                    NoticeView(
                        title: "Browser access needs attention",
                        message: browserAccessMessage + " Enable ADHD Guard for your browser in System Settings › Privacy & Security › Automation.",
                        symbol: "lock.trianglebadge.exclamationmark",
                        color: .orange
                    )
                }

                NoticeView(
                    title: "How decisions work",
                    message: "Blocked rules alert immediately. Unlisted activity gets your distraction budget. An allowed website counts as focused even when the browser itself is not explicitly allowed.",
                    symbol: "list.bullet.clipboard",
                    color: .blue
                )
            }
            .padding(28)
        }
        .navigationTitle("Dashboard")
    }

    private var header: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(store.configuration.monitoringEnabled ? Color.green.opacity(0.18) : Color.secondary.opacity(0.14))
                Image(systemName: store.configuration.monitoringEnabled ? "shield.fill" : "shield.slash")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(store.configuration.monitoringEnabled ? .green : .secondary)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                Text(store.configuration.monitoringEnabled ? "Guard is active" : "Guard is paused")
                    .font(.largeTitle.bold())
                Text(monitor.statusText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Monitoring", isOn: $store.configuration.monitoringEnabled)
                .toggleStyle(.switch)
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total < 60 { return "\(total)s" }
        return "\(total / 60)m \(total % 60)s"
    }
}

private struct StatusCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NoticeView: View {
    let title: String
    let message: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
