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
        case .focusApps: "Other apps start the reminder timer when Focus mode is on."
        case .distractingSites: "These sites start the reminder timer, even in a focus browser."
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
                GlassNavigationRail(selection: $navigation.selection)
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


}

private struct GlassNavigationRail: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Binding var selection: GuardSection
    @State private var hoveredSection: GuardSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 4) {
                ForEach(GuardSection.allCases) { section in
                    navigationButton(section)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
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

    private func navigationButton(_ section: GuardSection) -> some View {
        let isSelected = selection == section
        return Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isSelected ? GuardPalette.focused : .secondary)
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                        ? GuardPalette.accent.opacity(0.16)
                        : Color.primary.opacity(hoveredSection == section ? 0.05 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredSection = isHovering ? section : nil
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
