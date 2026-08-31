import SwiftUI

private enum GuardSection: String, CaseIterable, Identifiable {
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

struct RootView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @State private var selection: GuardSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(GuardSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("ADHD Guard")
            .navigationSplitViewColumnWidth(min: 180, ideal: 205)
        } detail: {
            Group {
                switch selection ?? .dashboard {
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
                .help(store.configuration.monitoringEnabled ? "Stop monitoring" : "Start monitoring")
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onAppear { monitor.start() }
    }
}
