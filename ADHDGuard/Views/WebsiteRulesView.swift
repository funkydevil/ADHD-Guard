import SwiftUI

struct WebsiteRulesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var monitor: GuardMonitor
    @State private var newSite = ""
    @State private var validationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                addSurface
                savedWebsites
            }
            .padding(.bottom, 20)
        }
    }

    private var addSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add from recent activity")
                    .font(.headline)
                Text("Time on these sites starts your focus timer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if monitor.recentVisitedHosts.isEmpty {
                Label("Recently visited sites will appear here.", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    ForEach(monitor.recentVisitedHosts, id: \.self) { host in
                        RecentHostTile(
                            host: host,
                            isIncluded: store.containsDistractingSite(host),
                            onAdd: { add(host) }
                        )
                    }
                }
            }

            Text("This session only · browsing history is not saved")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "plus.square.dashed")
                    .font(.title3)
                    .foregroundStyle(GuardPalette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add manually")
                        .font(.subheadline.weight(.semibold))
                    TextField("Enter a website, for example youtube.com", text: $newSite)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addSite)
                }
                Button("Add site", action: addSite)
                    .buttonStyle(.borderedProminent)
                    .disabled(newSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(GuardPalette.alarm)
            }
        }
        .padding(18)
        .guardCard(cornerRadius: 20)
    }

    private var savedWebsites: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distracting · \(store.configuration.websiteRules.count)")
                .font(.headline)

            if store.configuration.websiteRules.isEmpty {
                EmptyRulesView(
                    title: "No distracting sites yet",
                    systemImage: "globe.badge.chevron.backward",
                    description: "Add a recent site or type one above."
                )
                .frame(maxWidth: .infinity)
                .guardCard(cornerRadius: 18)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(store.configuration.websiteRules) { rule in
                        HStack(spacing: 12) {
                            Image(systemName: "globe.badge.chevron.backward")
                                .font(.title3)
                                .foregroundStyle(GuardPalette.alarm)
                                .frame(width: 34, height: 34)
                                .background(GuardPalette.alarm.opacity(0.1), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.host)
                                    .font(.body.monospaced().weight(.medium))
                                Text("Matching subdomains also start the timer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                remove(rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove distracting site")
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)
                        .guardCard(cornerRadius: 15)
                    }
                }
            }
        }
    }

    private func add(_ host: String) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            _ = store.addDistractingSite(host)
        }
    }

    private func addSite() {
        guard let host = RuleEvaluator.normalizedHost(from: newSite) else {
            validationMessage = "Enter a valid hostname or URL."
            return
        }

        guard !store.containsDistractingSite(host) else {
            validationMessage = "This website is already in the list."
            return
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            _ = store.addDistractingSite(host)
        }
        newSite = ""
        validationMessage = nil
    }

    private func remove(_ id: UUID) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            store.configuration.websiteRules.removeAll { $0.id == id }
        }
    }
}

private struct RecentHostTile: View {
    let host: String
    let isIncluded: Bool
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(GuardPalette.alarm)
                    Spacer()
                    Image(systemName: isIncluded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(isIncluded ? GuardPalette.alarm : GuardPalette.accent)
                }

                Text(host)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .lineLimit(1)
                Text(isIncluded ? "Added" : "Add")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isIncluded ? GuardPalette.alarm : GuardPalette.accent)
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
        .accessibilityLabel("\(host), \(isIncluded ? "already added" : "add to Distracting sites")")
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
