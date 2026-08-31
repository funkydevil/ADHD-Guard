import SwiftUI

struct WebsiteRulesView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @State private var newSite = ""
    @State private var newPolicy: RulePolicy = .blocked
    @State private var validationMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Add website") {
                    HStack {
                        TextField("youtube.com or https://example.com/path", text: $newSite)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addSite)

                        Picker("Policy", selection: $newPolicy) {
                            ForEach(RulePolicy.allCases) { policy in
                                Text(policy.title).tag(policy)
                            }
                        }
                        .frame(width: 150)

                        Button("Add", action: addSite)
                            .buttonStyle(.borderedProminent)
                            .disabled(newSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 135)

            List {
                Section {
                    ForEach($store.configuration.websiteRules) { $rule in
                        HStack(spacing: 12) {
                            Image(systemName: rule.policy.symbol)
                                .foregroundStyle(rule.policy == .allowed ? .green : .red)
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
                            .frame(width: 110)

                            Button(role: .destructive) {
                                remove(rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 5)
                    }
                } header: {
                    Text("Website rules")
                } footer: {
                    Text("A rule also matches subdomains. When at least one site is Allowed, every other readable browser site uses the distraction timer.")
                }
            }
            .overlay {
                if store.configuration.websiteRules.isEmpty {
                    EmptyRulesView(
                        title: "No website rules",
                        systemImage: "globe.badge.chevron.backward",
                        description: "Add blocked distractions or a focused-site allow list."
                    )
                }
            }
        }
        .navigationTitle("Websites")
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

struct EmptyRulesView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
