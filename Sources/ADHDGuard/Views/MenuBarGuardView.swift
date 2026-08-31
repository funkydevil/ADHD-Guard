import AppKit
import SwiftUI

struct MenuBarGuardView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.configuration.monitoringEnabled ? "Guard is active" : "Guard is paused")
                .font(.headline)
            Text(monitor.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            Toggle("Monitoring", isOn: $store.configuration.monitoringEnabled)

            Button("Open ADHD Guard") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
            }

            Divider()

            Button("Quit ADHD Guard") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 250)
    }
}
