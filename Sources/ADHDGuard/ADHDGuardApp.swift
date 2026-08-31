import SwiftUI

@main
@MainActor
struct ADHDGuardApp: App {
    @StateObject private var store: ConfigurationStore
    @StateObject private var alarm: AlarmController
    @StateObject private var monitor: GuardMonitor

    init() {
        let store = ConfigurationStore()
        let alarm = AlarmController()
        _store = StateObject(wrappedValue: store)
        _alarm = StateObject(wrappedValue: alarm)
        _monitor = StateObject(wrappedValue: GuardMonitor(store: store, alarm: alarm))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(alarm)
                .environmentObject(monitor)
                .onAppear { monitor.start() }
        }
        .defaultSize(width: 980, height: 680)
        .commands {
            CommandMenu("Guard") {
                Toggle("Monitoring", isOn: $store.configuration.monitoringEnabled)
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Test Alarm") {
                    alarm.present(
                        kind: .test,
                        title: "ADHD Guard test",
                        message: "This is how a focus warning will look.",
                        phrase: store.configuration.focusPhrase,
                        speaks: store.configuration.speaksWarnings,
                        playsSound: store.configuration.playsSound
                    )
                }
            }
        }

        MenuBarExtra {
            MenuBarGuardView()
                .environmentObject(store)
                .environmentObject(monitor)
        } label: {
            Label("ADHD Guard", systemImage: store.configuration.monitoringEnabled ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(store)
                .environmentObject(alarm)
                .frame(width: 560, height: 540)
        }
    }
}
