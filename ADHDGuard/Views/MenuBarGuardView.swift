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

private enum MenuMetrics {
    static let width: CGFloat = 352
    static let height: CGFloat = 404
    static let horizontalInset: CGFloat = 14
    static let contentWidth: CGFloat = width - horizontalInset * 2
    static let headerHeight: CGFloat = 52
    static let bodyHeight: CGFloat = 302
    static let footerHeight: CGFloat = 48
}

struct MenuBarGuardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var navigation: GuardNavigation
    @State private var page: MenuPage = .status

    var body: some View {
        ZStack {
            GuardAuraBackground(extendsUnderSafeArea: false)

            VStack(spacing: 0) {
                header
                    .frame(
                        width: MenuMetrics.contentWidth,
                        height: MenuMetrics.headerHeight
                    )
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                ScrollView {
                    ZStack(alignment: .topLeading) {
                        pageContent
                            .id(page)
                            .frame(width: MenuMetrics.contentWidth, alignment: .topLeading)
                            .transition(pageTransition)
                    }
                    .frame(width: MenuMetrics.contentWidth, alignment: .topLeading)
                    .padding(.horizontal, MenuMetrics.horizontalInset)
                    .padding(.vertical, 12)
                }
                .frame(width: MenuMetrics.width, height: MenuMetrics.bodyHeight)
                .clipped()

                Divider()

                footer
                    .frame(
                        width: MenuMetrics.contentWidth,
                        height: MenuMetrics.footerHeight
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: MenuMetrics.width, height: MenuMetrics.height)
        }
        .frame(width: MenuMetrics.width, height: MenuMetrics.height)
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 10) {
            GuardMark(
                presentation: presentation,
                size: 28,
                gateColor: .primary.opacity(0.82),
                coreColor: presentation.color
            )
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("ADHD Guard")
                    .font(.headline)
            }

            Spacer()

            Menu {
                Button("Open ADHD Guard", action: { open(.status) })
                Button("Settings…", action: { open(.settings) })
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

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle("Focus reminders", isOn: $store.configuration.monitoringEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.caption.weight(.semibold))
                .disabled(isDistractionAlertActive)

            Spacer(minLength: 4)

            Button("Open app") {
                open(.status)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
        VStack(spacing: 10) {
            CompactGuardStatus(presentation: presentation)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    if let context = displayContext {
                        ApplicationIcon(bundleIdentifier: context.bundleIdentifier, size: 36)
                    } else {
                        GuardMark(
                            presentation: presentation,
                            size: 28,
                            gateColor: .secondary,
                            coreColor: presentation.color
                        )
                        .frame(width: 36, height: 36)
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
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    StatusBadge(title: contextClassification, color: classificationColor)
                        .fixedSize()
                }

                if let contextActionTitle {
                    Button(action: performContextAction) {
                        Label(
                            contextActionTitle,
                            systemImage: displayContext?.browserURL?.host == nil
                                ? "app.badge.checkmark"
                                : "exclamationmark.shield"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(contextActionColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
            .guardCard(cornerRadius: 16)

            MenuCollectionsCard(
                focusCount: store.configuration.applicationRules.count,
                siteCount: store.configuration.websiteRules.count,
                openFocus: { select(.focus) },
                openSites: { select(.sites) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
            backAction: { select(.status) },
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
            backAction: { select(.status) },
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

    private var contextActionColor: Color {
        guard let context = displayContext else { return GuardPalette.accent }
        return context.browserURL?.host == nil ? GuardPalette.focused : GuardPalette.alarm
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .center)),
            removal: .opacity
        )
    }

    private func select(_ newPage: MenuPage) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.11) : .easeOut(duration: 0.16)) {
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

private struct MenuCollectionsCard: View {
    let focusCount: Int
    let siteCount: Int
    let openFocus: () -> Void
    let openSites: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            row(
                title: "Focus Apps",
                count: focusCount,
                symbol: "app.badge.checkmark",
                color: GuardPalette.focused,
                action: openFocus
            )

            Divider()
                .padding(.leading, 38)

            row(
                title: "Distracting Sites",
                count: siteCount,
                symbol: "globe.badge.chevron.backward",
                color: GuardPalette.alarm,
                action: openSites
            )
        }
        .guardCard(cornerRadius: 15)
    }

    private func row(
        title: String,
        count: Int,
        symbol: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(color)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    let backAction: () -> Void
    let manageAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Button(action: backAction) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.borderless)

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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(2)
    }
}
