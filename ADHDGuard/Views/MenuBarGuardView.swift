import AppKit
import SwiftUI

private enum MenuPage: Int, CaseIterable, Identifiable {
    case status
    case focus
    case sites

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .status: "Status"
        case .focus: "Focus"
        case .sites: "Sites"
        }
    }

    var symbol: String {
        switch self {
        case .status: "scope"
        case .focus: "app.badge.checkmark"
        case .sites: "globe"
        }
    }
}

struct MenuBarGuardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var navigation: GuardNavigation
    @State private var page: MenuPage = .status
    @State private var transitionDirection = 1

    var body: some View {
        ZStack {
            GuardAuraBackground()

            VStack(spacing: 14) {
                header

                ZStack {
                    pageContent
                        .id(page)
                        .transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                MenuDock(selection: page, onSelect: select)
            }
            .padding(16)
        }
        .frame(width: 352, height: 456)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: page)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(GuardPalette.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: GuardPalette.accent.opacity(0.28), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text("ADHD Guard")
                    .font(.headline)
                Text(presentation.title)
                    .font(.caption)
                    .foregroundStyle(presentation.color)
            }

            Spacer()

            Button {
                open(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Open Settings")

            Menu {
                Button("Open ADHD Guard", action: { open(.status) })
                Divider()
                Button(store.configuration.monitoringEnabled ? "Pause reminders" : "Start Guard") {
                    store.configuration.monitoringEnabled.toggle()
                }
                .disabled(isDistractionAlertActive)
                Divider()
                Button("Quit ADHD Guard") {
                    NSApp.terminate(nil)
                }
                .disabled(isDistractionAlertActive)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .status:
            statusPage
        case .focus:
            focusPage
        case .sites:
            sitesPage
        }
    }

    private var statusPage: some View {
        VStack(spacing: 12) {
            StatusOrb(presentation: presentation, size: 100, showsDetail: false)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    if let context = displayContext {
                        ApplicationIcon(bundleIdentifier: context.bundleIdentifier, size: 38)
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundStyle(GuardPalette.accent)
                            .frame(width: 38, height: 38)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayContext?.applicationName ?? "Waiting for activity")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(displayContext?.browserURL?.host ?? contextClassification)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    StatusBadge(title: contextClassification, color: classificationColor)
                }

                if let contextActionTitle {
                    Button(contextActionTitle, action: performContextAction)
                        .buttonStyle(.borderedProminent)
                        .tint(classificationColor)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(13)
            .guardCard(cornerRadius: 16)

            Toggle("Focus reminders", isOn: $store.configuration.monitoringEnabled)
                .toggleStyle(.switch)
                .font(.subheadline.weight(.semibold))
                .disabled(isDistractionAlertActive)
                .padding(.horizontal, 4)
        }
    }

    private var focusPage: some View {
        MenuListPage(
            title: "Focus apps",
            subtitle: "These apps keep you in your focus zone.",
            count: store.configuration.applicationRules.count,
            color: GuardPalette.focused,
            emptyText: "Use your Mac for a moment — recent apps will appear here.",
            rows: monitor.recentApplications.map { application in
                MenuListRow(
                    id: application.id,
                    title: application.name,
                    subtitle: application.bundleIdentifier,
                    isAdded: store.containsFocusApplication(bundleIdentifier: application.bundleIdentifier),
                    action: {
                        store.addFocusApplication(
                            name: application.name,
                            bundleIdentifier: application.bundleIdentifier
                        )
                    }
                )
            },
            manageAction: { openRules(.focusApps) }
        )
    }

    private var sitesPage: some View {
        MenuListPage(
            title: "Distracting sites",
            subtitle: "These sites start your focus timer.",
            count: store.configuration.websiteRules.count,
            color: GuardPalette.alarm,
            emptyText: "Open a browser — recent sites will appear here.",
            rows: monitor.recentVisitedHosts.map { host in
                MenuListRow(
                    id: host,
                    title: host,
                    subtitle: "Recent website",
                    isAdded: store.containsDistractingSite(host),
                    action: { _ = store.addDistractingSite(host) }
                )
            },
            manageAction: { openRules(.distractingSites) }
        )
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

    private var displayDecision: RuleDecision? {
        guard let displayContext else { return nil }
        return RuleEvaluator.evaluate(
            context: displayContext,
            configuration: store.configuration,
            ownBundleIdentifier: Bundle.main.bundleIdentifier
        )
    }

    private var presentation: GuardStatusPresentation {
        GuardStatusPresentation(
            monitoringEnabled: store.configuration.monitoringEnabled,
            decision: displayDecision,
            remaining: monitor.distractionRemaining,
            graceSeconds: store.configuration.distractionGraceSeconds
        )
    }

    private var isDistractionAlertActive: Bool {
        alarm.activeAlarm?.kind == .distraction
    }

    private var contextClassification: String {
        guard let context = displayContext else { return "Waiting" }
        if let host = context.browserURL?.host, store.containsDistractingSite(host) {
            return "Distracting"
        }
        if store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier) {
            return "In Focus"
        }
        return "Unlisted"
    }

    private var classificationColor: Color {
        switch contextClassification {
        case "Distracting": GuardPalette.alarm
        case "In Focus": GuardPalette.focused
        default: GuardPalette.accent
        }
    }

    private var contextActionTitle: String? {
        guard let context = displayContext else { return nil }
        if let host = context.browserURL?.host {
            return store.containsDistractingSite(host) ? "Manage distracting sites" : "Mark site as distracting"
        }
        return store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier)
            ? "Manage focus apps"
            : "Add app to focus"
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertionEdge: Edge = transitionDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = transitionDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private func select(_ newPage: MenuPage) {
        transitionDirection = newPage.rawValue >= page.rawValue ? 1 : -1
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            page = newPage
        }
    }

    private func performContextAction() {
        guard let context = displayContext else { return }
        if let host = context.browserURL?.host {
            if store.containsDistractingSite(host) {
                openRules(.distractingSites)
            } else {
                _ = store.addDistractingSite(host)
            }
            return
        }

        if store.containsFocusApplication(bundleIdentifier: context.bundleIdentifier) {
            openRules(.focusApps)
        } else {
            store.addFocusApplication(
                name: context.applicationName,
                bundleIdentifier: context.bundleIdentifier
            )
        }
    }

    private func open(_ section: GuardSection) {
        navigation.selection = section
        showMainWindow()
    }

    private func openRules(_ collection: RuleCollection) {
        navigation.openRules(collection)
        showMainWindow()
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MenuDock: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let selection: MenuPage
    let onSelect: (MenuPage) -> Void
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MenuPage.allCases) { page in
                Button {
                    onSelect(page)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: page.symbol)
                            .font(.system(size: 13, weight: .semibold))
                        Text(page.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(selection == page ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background {
                        if selection == page {
                            Capsule()
                                .fill(GuardPalette.accent.opacity(0.15))
                                .matchedGeometryEffect(id: "menu-dock", in: selectionNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
                : AnyShapeStyle(.ultraThinMaterial),
            in: Capsule()
        )
        .overlay { Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1) }
    }
}

private struct MenuListRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let isAdded: Bool
    let action: () -> Void
}

private struct MenuListPage: View {
    let title: String
    let subtitle: String
    let count: Int
    let color: Color
    let emptyText: String
    let rows: [MenuListRow]
    let manageAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(color)
                        .frame(minWidth: 34, minHeight: 34)
                        .background(color.opacity(0.1), in: Circle())
                }

                Text("From recent activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if rows.isEmpty {
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 142)
                        .multilineTextAlignment(.center)
                        .guardCard(cornerRadius: 16)
                } else {
                    VStack(spacing: 7) {
                        ForEach(rows.prefix(3)) { row in
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(color)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(row.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button(row.isAdded ? "Added" : "Add", action: row.action)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(row.isAdded)
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 49)
                            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Text("This session only · history is not saved")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Button("Manage all and add manually…", action: manageAction)
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    .frame(maxWidth: .infinity)
            }
            .padding(2)
        }
    }
}
