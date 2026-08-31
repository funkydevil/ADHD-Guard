import SwiftUI

struct WebsiteRulesView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @State private var newSite = ""
    @State private var newPolicy: RulePolicy = .blocked
    @State private var validationMessage: String?

    var body: some View {
        List {
            if !monitor.recentVisitedHosts.isEmpty {
                Section {
                    ForEach(monitor.recentVisitedHosts, id: \.self) { host in
                        RecentHostRow(
                            host: host,
                            matchingPolicy: matchingPolicy(for: host),
                            isExactlyBlocked: isExactlyBlocked(host),
                            onBlock: { block(host) }
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

                    Picker("Policy", selection: $newPolicy) {
                        ForEach(RulePolicy.allCases) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    .frame(width: 142)

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
                    ForEach($store.configuration.websiteRules) { $rule in
                        HStack(spacing: 12) {
                            Image(systemName: rule.policy.symbol)
                                .foregroundStyle(rule.policy == .allowed ? GuardPalette.focused : GuardPalette.alarm)
                                .frame(width: 24)

                            Text(rule.host)
                                .font(.body.monospaced())

                            Spacer()

                            Picker("Policy", selection: $rule.policy) {
                                ForEach(RulePolicy.allCases) { policy in
                                    Text(policy.title).tag(policy)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 112)

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
                Text("Website rules")
            } footer: {
                Text("Rules include subdomains. Sites outside a non-empty allow list use the focus buffer.")
            }
        }
        .navigationTitle("Websites")
    }

    private func matchingPolicy(for host: String) -> RulePolicy? {
        RuleEvaluator.matchingWebsiteRule(host: host, rules: store.configuration.websiteRules)?.policy
    }

    private func isExactlyBlocked(_ host: String) -> Bool {
        store.configuration.websiteRules.contains {
            $0.policy == .blocked && $0.host.caseInsensitiveCompare(host) == .orderedSame
        }
    }

    private func block(_ host: String) {
        if let index = store.configuration.websiteRules.firstIndex(where: {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }) {
            store.configuration.websiteRules[index].policy = .blocked
        } else {
            store.configuration.websiteRules.append(WebsiteRule(host: host, policy: .blocked))
        }
    }

    private func addSite() {
        guard let host = RuleEvaluator.normalizedHost(from: newSite) else {
            validationMessage = "Enter a valid hostname or URL."
            return
        }

        if let existingIndex = store.configuration.websiteRules.firstIndex(where: {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }) {
            store.configuration.websiteRules[existingIndex].policy = newPolicy
        } else {
            store.configuration.websiteRules.append(WebsiteRule(host: host, policy: newPolicy))
        }
        newSite = ""
        validationMessage = nil
    }

    private func remove(_ id: UUID) {
        store.configuration.websiteRules.removeAll { $0.id == id }
    }
}

private struct RecentHostRow: View {
    let host: String
    let matchingPolicy: RulePolicy?
    let isExactlyBlocked: Bool
    let onBlock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(GuardPalette.accent)
                .frame(width: 24)
            Text(host)
                .font(.body.monospaced())
            Spacer()

            if isExactlyBlocked {
                StatusBadge(
                    title: RulePolicy.blocked.title,
                    color: GuardPalette.alarm
                )
            } else {
                if let matchingPolicy {
                    StatusBadge(
                        title: matchingPolicy.title,
                        color: matchingPolicy == .allowed ? GuardPalette.focused : GuardPalette.alarm
                    )
                }
                Button("Block", action: onBlock)
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
