import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationRulesView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor

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
                if !monitor.recentApplications.isEmpty {
                    Section {
                        ForEach(monitor.recentApplications) { application in
                            RecentApplicationRow(
                                application: application,
                                policy: applicationRule(for: application)?.policy,
                                onAllow: { allow(application) }
                            )
                        }
                    } header: {
                        Text("Recently active")
                    } footer: {
                        Text("The last three active apps from this session · activity history is not saved")
                    }
                }

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

    private func applicationRule(for application: RecentApplication) -> ApplicationRule? {
        store.configuration.applicationRules.first {
            $0.bundleIdentifier.caseInsensitiveCompare(application.bundleIdentifier) == .orderedSame
        }
    }

    private func allow(_ application: RecentApplication) {
        if let index = store.configuration.applicationRules.firstIndex(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(application.bundleIdentifier) == .orderedSame
        }) {
            store.configuration.applicationRules[index].name = application.name
            store.configuration.applicationRules[index].policy = .allowed
        } else {
            store.configuration.applicationRules.append(
                ApplicationRule(
                    name: application.name,
                    bundleIdentifier: application.bundleIdentifier,
                    policy: .allowed
                )
            )
        }
    }
}

private struct RecentApplicationRow: View {
    let application: RecentApplication
    let policy: RulePolicy?
    let onAllow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ApplicationIcon(bundleIdentifier: application.bundleIdentifier)

            VStack(alignment: .leading, spacing: 2) {
                Text(application.name)
                    .font(.headline)
                Text(application.bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let policy {
                StatusBadge(
                    title: policy.title,
                    color: policy == .allowed ? GuardPalette.focused : GuardPalette.alarm
                )
            }

            if policy != .allowed {
                Button("Allow", action: onAllow)
                    .buttonStyle(.bordered)
                    .tint(GuardPalette.focused)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ApplicationIcon: View {
    let bundleIdentifier: String

    var body: some View {
        Group {
            if let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
            ) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
        }
        .frame(width: 28, height: 28)
    }
}
