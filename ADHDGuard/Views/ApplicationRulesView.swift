import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationRulesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                addSurface
                savedApplications
            }
            .padding(.bottom, 20)
        }
    }

    private var addSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add from recent activity")
                    .font(.headline)
                Text("These apps count as focused activity.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if monitor.recentApplications.isEmpty {
                Label("Recent apps will appear here as you work.", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    ForEach(monitor.recentApplications) { application in
                        RecentApplicationTile(
                            application: application,
                            isIncluded: store.containsFocusApplication(
                                bundleIdentifier: application.bundleIdentifier
                            ),
                            onAdd: { add(application) }
                        )
                    }
                }
            }

            Text("This session only · activity history is not saved")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()

            HStack(spacing: 14) {
                Image(systemName: "plus.square.dashed")
                    .font(.title3)
                    .foregroundStyle(GuardPalette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add manually")
                        .font(.subheadline.weight(.semibold))
                    Text("Choose an app from your Applications folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Choose an application…", action: chooseApplication)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .guardCard(cornerRadius: 20)
    }

    private var savedApplications: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In Focus · \(store.configuration.applicationRules.count)")
                .font(.headline)

            if store.configuration.applicationRules.isEmpty {
                EmptyRulesView(
                    title: "No focus apps yet",
                    systemImage: "app.badge.checkmark",
                    description: "Add the apps that belong to your focus session."
                )
                .frame(maxWidth: .infinity)
                .guardCard(cornerRadius: 18)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(store.configuration.applicationRules) { rule in
                        HStack(spacing: 12) {
                            ApplicationIcon(bundleIdentifier: rule.bundleIdentifier)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name).font(.headline)
                                Text(rule.bundleIdentifier)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                remove(rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove focus app")
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)
                        .guardCard(cornerRadius: 15)
                    }
                }
            }
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose a focus application"
        panel.prompt = "Add to Focus"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        store.addFocusApplication(name: name, bundleIdentifier: bundleIdentifier)
    }

    private func add(_ application: RecentApplication) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            store.addFocusApplication(
                name: application.name,
                bundleIdentifier: application.bundleIdentifier
            )
        }
    }

    private func remove(_ id: UUID) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            store.configuration.applicationRules.removeAll { $0.id == id }
        }
    }
}

private struct RecentApplicationTile: View {
    let application: RecentApplication
    let isIncluded: Bool
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    ApplicationIcon(bundleIdentifier: application.bundleIdentifier, size: 30)
                    Spacer()
                    Image(systemName: isIncluded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(isIncluded ? GuardPalette.focused : GuardPalette.accent)
                }

                Text(application.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(isIncluded ? "Added" : "Add")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isIncluded ? GuardPalette.focused : GuardPalette.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isIncluded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(application.name), \(isIncluded ? "already added" : "add to Focus apps")")
    }
}
