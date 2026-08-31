import SwiftUI

enum GuardSection: String, CaseIterable, Identifiable {
    case dashboard
    case applications
    case websites
    case preferences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .applications: "Applications"
        case .websites: "Websites"
        case .preferences: "Preferences"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "shield.lefthalf.filled"
        case .applications: "app.dashed"
        case .websites: "globe"
        case .preferences: "slider.horizontal.3"
        }
    }
}

@MainActor
final class GuardNavigation: ObservableObject {
    @Published var selection: GuardSection? = .dashboard
}

struct RootView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        NavigationSplitView {
            List(GuardSection.allCases, selection: $navigation.selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("ADHD Guard")
            .navigationSplitViewColumnWidth(min: 180, ideal: 205)
        } detail: {
            Group {
                switch navigation.selection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .applications:
                    ApplicationRulesView()
                case .websites:
                    WebsiteRulesView()
                case .preferences:
                    PreferencesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $store.configuration.monitoringEnabled) {
                    Label("Guard", systemImage: store.configuration.monitoringEnabled ? "shield.fill" : "shield")
                }
                .toggleStyle(.switch)
                .disabled(alarm.activeAlarm?.kind == .distraction)
                .help(
                    alarm.activeAlarm?.kind == .distraction
                        ? "Return to a focused context before pausing"
                        : (store.configuration.monitoringEnabled ? "Stop monitoring" : "Start monitoring")
                )
            }
        }
        .tint(GuardPalette.accent)
        .frame(minWidth: 900, minHeight: 620)
        .onAppear { monitor.start() }
    }
}
