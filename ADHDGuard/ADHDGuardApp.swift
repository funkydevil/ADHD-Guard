import AppKit
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
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)

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
                .background(HiddenWindowTitle())
                .environmentObject(store)
                .environmentObject(alarm)
                .environmentObject(monitor)
                .environmentObject(navigation)
                .environmentObject(launchAtLogin)
                .preferredColorScheme(.dark)
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
                .tint(GuardPalette.accent)
                .environmentObject(store)
                .environmentObject(monitor)
                .environmentObject(alarm)
                .environmentObject(navigation)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarStatusIcon(presentation: menuBarPresentation)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .tint(GuardPalette.accent)
                .background(GuardAuraBackground())
                .environmentObject(store)
                .environmentObject(alarm)
                .environmentObject(monitor)
                .environmentObject(launchAtLogin)
                .frame(width: 560, height: 540)
                .preferredColorScheme(.dark)
        }
    }

    private var menuBarPresentation: GuardStatusPresentation {
        GuardStatusPresentation(
            monitoringEnabled: store.configuration.monitoringEnabled,
            decision: menuBarDecision,
            remaining: monitor.distractionRemaining,
            graceSeconds: store.configuration.distractionGraceSeconds
        )
    }

    private var menuBarDecision: RuleDecision? {
        let ownIdentifier = Bundle.main.bundleIdentifier ?? "com.funkydevil.ADHDGuard"
        let currentContext = monitor.currentContext
        let context = currentContext?.bundleIdentifier.caseInsensitiveCompare(ownIdentifier) == .orderedSame
            ? monitor.lastExternalContext
            : currentContext

        guard let context else { return nil }
        return RuleEvaluator.evaluate(
            context: context,
            configuration: store.configuration,
            ownBundleIdentifier: Bundle.main.bundleIdentifier
        )
    }
}

private struct HiddenWindowTitle: NSViewRepresentable {
    func makeNSView(context: Context) -> TitleView {
        TitleView()
    }

    func updateNSView(_ nsView: TitleView, context: Context) {
        nsView.window?.titleVisibility = .hidden
    }

    final class TitleView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.titleVisibility = .hidden
        }
    }
}
