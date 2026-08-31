import SwiftUI

struct WebsiteRulesView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @State private var newSite = ""
    @State private var validationMessage: String?

    var body: some View {
        List {
            if !monitor.recentVisitedHosts.isEmpty {
                Section {
                    ForEach(monitor.recentVisitedHosts, id: \.self) { host in
                        RecentHostRow(
                            host: host,
                            isOutsideFocus: isOutsideFocus(host),
                            onAdd: { add(host) }
                        )
                    }
                } header: {
                    Text("Recently visited")
                } footer: {
                    Text("From this session only · browsing history is not saved")
                }
            }

            Section {
                HStack(spacing: 10) {
                    TextField("youtube.com or https://example.com/path", text: $newSite)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addSite)

                    Button("Add", action: addSite)
                        .buttonStyle(.borderedProminent)
                        .tint(GuardPalette.accent)
                        .disabled(newSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(GuardPalette.alarm)
                }
            } header: {
                Text("Add website")
            }

            Section {
                if store.configuration.websiteRules.isEmpty {
                    EmptyRulesView(
                        title: "No website rules yet",
                        systemImage: "globe.badge.chevron.backward",
                        description: "Visit a distracting site or add a hostname above."
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.configuration.websiteRules) { rule in
                        HStack(spacing: 12) {
                            Image(systemName: "globe.badge.chevron.backward")
                                .foregroundStyle(GuardPalette.alarm)
                                .frame(width: 24)

                            Text(rule.host)
                                .font(.body.monospaced())

                            Spacer()

                            Button(role: .destructive) {
                                remove(rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove website rule")
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Outside focus")
            } footer: {
                Text("Every website in this list is outside focus. Matching subdomains use the distraction buffer.")
            }
        }
        .navigationTitle("Websites")
    }

    private func isOutsideFocus(_ host: String) -> Bool {
        RuleEvaluator.matchingWebsiteRule(host: host, rules: store.configuration.websiteRules) != nil
    }

    private func add(_ host: String) {
        guard !store.configuration.websiteRules.contains(where: {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }) else { return }

        store.configuration.websiteRules.append(WebsiteRule(host: host))
    }

    private func addSite() {
        guard let host = RuleEvaluator.normalizedHost(from: newSite) else {
            validationMessage = "Enter a valid hostname or URL."
            return
        }

        guard !store.configuration.websiteRules.contains(where: {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }) else {
            validationMessage = "This website is already in the list."
            return
        }

        store.configuration.websiteRules.append(WebsiteRule(host: host))
        newSite = ""
        validationMessage = nil
    }

    private func remove(_ id: UUID) {
        store.configuration.websiteRules.removeAll { $0.id == id }
    }
}

private struct RecentHostRow: View {
    let host: String
    let isOutsideFocus: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(GuardPalette.accent)
                .frame(width: 24)
            Text(host)
                .font(.body.monospaced())
            Spacer()

            if isOutsideFocus {
                StatusBadge(
                    title: "In list",
                    color: GuardPalette.alarm
                )
            } else {
                Button("Add", action: onAdd)
                    .buttonStyle(.bordered)
                    .tint(GuardPalette.alarm)
            }
        }
        .padding(.vertical, 3)
    }
}

struct EmptyRulesView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
