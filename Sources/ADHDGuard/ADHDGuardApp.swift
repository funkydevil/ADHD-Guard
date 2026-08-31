import SwiftUI

@main
@MainActor
struct ADHDGuardApp: App {
    @StateObject private var store: ConfigurationStore
    @StateObject private var alarm: AlarmController
    @StateObject private var monitor: GuardMonitor
    @StateObject private var navigation: GuardNavigation
    @StateObject private var launchAtLogin: LaunchAtLoginController

    init() {
        let store = ConfigurationStore()
        let alarm = AlarmController()
        _store = StateObject(wrappedValue: store)
        _alarm = StateObject(wrappedValue: alarm)
        _monitor = StateObject(wrappedValue: GuardMonitor(store: store, alarm: alarm))
        _navigation = StateObject(wrappedValue: GuardNavigation())
        _launchAtLogin = StateObject(wrappedValue: LaunchAtLoginController())
    }

    var body: some Scene {
        Window("ADHD Guard", id: "main") {
            RootView()
                .environmentObject(store)
                .environmentObject(alarm)
                .environmentObject(monitor)
                .environmentObject(navigation)
                .environmentObject(launchAtLogin)
                .onAppear { monitor.start() }
        }
        .defaultSize(width: 980, height: 680)
        .commands {
            CommandMenu("Guard") {
                Toggle("Monitoring", isOn: $store.configuration.monitoringEnabled)
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(alarm.activeAlarm?.kind == .distraction)
                Button("Preview Reminder") {
                    alarm.preview(
                        phrase: store.configuration.focusPhrase,
                        speaks: store.configuration.speaksWarnings,
                        playsSound: store.configuration.playsSound
                    )
                }
            }

            CommandGroup(replacing: .appTermination) {
                Button("Quit ADHD Guard") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
                .disabled(alarm.activeAlarm?.kind == .distraction)
            }
        }

        MenuBarExtra {
            MenuBarGuardView()
                .environmentObject(store)
                .environmentObject(monitor)
                .environmentObject(alarm)
                .environmentObject(navigation)
        } label: {
            Label("ADHD Guard", systemImage: store.configuration.monitoringEnabled ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(store)
                .environmentObject(alarm)
                .environmentObject(launchAtLogin)
                .frame(width: 560, height: 540)
        }
    }
}
