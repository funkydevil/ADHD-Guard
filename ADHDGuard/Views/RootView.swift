import SwiftUI

enum GuardSection: String, CaseIterable, Identifiable {
    case status
    case rules
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "Status"
        case .rules: "Lists"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .status: "scope"
        case .rules: "square.stack.3d.up"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum RuleCollection: String, CaseIterable, Identifiable {
    case focusApps
    case distractingSites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusApps: "Focus apps"
        case .distractingSites: "Distracting sites"
        }
    }

    var subtitle: String {
        switch self {
        case .focusApps: "Apps that keep you in flow."
        case .distractingSites: "Sites that start your focus timer."
        }
    }
}

@MainActor
final class GuardNavigation: ObservableObject {
    @Published var selection: GuardSection = .status
    @Published var ruleCollection: RuleCollection = .focusApps

    func openRules(_ collection: RuleCollection) {
        ruleCollection = collection
        selection = .rules
    }
}

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        ZStack {
            GuardAuraBackground()

            HStack(spacing: 0) {
                GlassNavigationRail(
                    selection: $navigation.selection,
                    presentation: presentation
                )
                    .frame(width: 176)

                ZStack {
                    detailView
                        .id(navigation.selection)
                        .transition(detailTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: navigation.selection)
            }
        }
        .tint(GuardPalette.accent)
        .frame(minWidth: 900, minHeight: 620)
        .onAppear { monitor.start() }
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigation.selection {
        case .status:
            DashboardView()
        case .rules:
            RulesView()
        case .settings:
            PreferencesView()
        }
    }

    private var detailTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }

    private var presentation: GuardStatusPresentation {
        GuardStatusPresentation(
            monitoringEnabled: store.configuration.monitoringEnabled,
            decision: monitor.lastDecision,
            remaining: monitor.distractionRemaining,
            graceSeconds: store.configuration.distractionGraceSeconds
        )
    }
}

private struct GlassNavigationRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Binding var selection: GuardSection
    let presentation: GuardStatusPresentation
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            brand

            VStack(spacing: 8) {
                ForEach(GuardSection.allCases) { section in
                    navigationButton(section)
                }
            }

            Spacer()
        }
        .padding(18)
        .background {
            if reduceTransparency {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black.opacity(0.94), location: 0.78),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.055))
                .frame(width: 1)
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            GuardMark(
                presentation: presentation,
                size: 23,
                gateColor: .white.opacity(0.9),
                coreColor: .white
            )
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [GuardPalette.accent, GuardPalette.accent.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .shadow(color: GuardPalette.accent.opacity(0.32), radius: 12, y: 5)

            Text("ADHD\nGuard")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }

    private func navigationButton(_ section: GuardSection) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82)) {
                selection = section
            }
        } label: {
            HStack(spacing: 11) {
                Group {
                    if section == .status {
                        GuardMark(
                            presentation: presentation,
                            size: 18,
                            gateColor: selection == section ? .primary : .secondary,
                            coreColor: presentation.color
                        )
                    } else {
                        Image(systemName: section.symbol)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .frame(width: 20)
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selection == section ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background {
                if selection == section {
                    Capsule()
                        .fill(GuardPalette.accent.opacity(0.14))
                        .overlay {
                            Capsule().stroke(GuardPalette.accent.opacity(0.22), lineWidth: 1)
                        }
                        .matchedGeometryEffect(id: "rail-selection", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == section ? .isSelected : [])
    }
}

private struct RulesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var navigation: GuardNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(navigation.ruleCollection.title)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text(navigation.ruleCollection.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("List", selection: $navigation.ruleCollection) {
                    ForEach(RuleCollection.allCases) { collection in
                        Text(collection.title).tag(collection)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 300)
            }

            Group {
                switch navigation.ruleCollection {
                case .focusApps:
                    ApplicationRulesView()
                case .distractingSites:
                    WebsiteRulesView()
                }
            }
            .id(navigation.ruleCollection)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: navigation.ruleCollection)
        }
        .padding(30)
        .frame(maxWidth: 900, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
