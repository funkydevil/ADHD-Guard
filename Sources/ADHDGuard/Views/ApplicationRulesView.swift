import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationRulesView: View {
    @EnvironmentObject private var store: ConfigurationStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "app.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(GuardPalette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose where focus belongs")
                        .font(.headline)
                    Text("Blocked apps alert immediately. Unlisted apps use the focus buffer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            List {
                Section {
                    if store.configuration.applicationRules.isEmpty {
                        EmptyRulesView(
                            title: "No application rules",
                            systemImage: "app.badge.checkmark",
                            description: "Add the apps that belong to your focus session."
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach($store.configuration.applicationRules) { $rule in
                            HStack(spacing: 12) {
                                Image(systemName: rule.policy.symbol)
                                    .foregroundStyle(rule.policy == .allowed ? GuardPalette.focused : GuardPalette.alarm)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.name).font(.headline)
                                    Text(rule.bundleIdentifier)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Picker("Policy", selection: $rule.policy) {
                                    ForEach(RulePolicy.allCases) { policy in
                                        Text(policy.title).tag(policy)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 110)

                                Button(role: .destructive) {
                                    remove(rule.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove rule")
                            }
                            .padding(.vertical, 5)
                        }
                    }
                } header: {
                    Text("Application rules")
                } footer: {
                    Text("Return to an allowed app or website to silence an active focus alert.")
                }
            }
        }
        .navigationTitle("Applications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: chooseApplication) {
                    Label("Add Application", systemImage: "plus")
                }
            }
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.prompt = "Add Rule"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return }

        if store.configuration.applicationRules.contains(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }) {
            return
        }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        store.configuration.applicationRules.append(
            ApplicationRule(name: name, bundleIdentifier: bundleIdentifier, policy: .allowed)
        )
    }

    private func remove(_ id: UUID) {
        store.configuration.applicationRules.removeAll { $0.id == id }
    }
}
