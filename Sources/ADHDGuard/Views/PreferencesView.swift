import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var alarm: AlarmController

    var body: some View {
        Form {
            Section("Distraction timer") {
                Stepper(
                    "Allow up to \(store.configuration.distractionGraceSeconds) seconds outside focus",
                    value: $store.configuration.distractionGraceSeconds,
                    in: 0...600,
                    step: 5
                )
                Text("Explicitly blocked rules ignore this timer and alert immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Idle warning") {
                Toggle("Warn when there is no keyboard or mouse activity", isOn: $store.configuration.idleMonitoringEnabled)
                Stepper(
                    "Warn after \(store.configuration.idleThresholdSeconds / 60)m \(store.configuration.idleThresholdSeconds % 60)s",
                    value: $store.configuration.idleThresholdSeconds,
                    in: 30...3600,
                    step: 30
                )
                .disabled(!store.configuration.idleMonitoringEnabled)
            }

            Section("Alarm") {
                Toggle("Speak warning phrases", isOn: $store.configuration.speaksWarnings)
                Toggle("Play siren sound", isOn: $store.configuration.playsSound)
                TextField("Distraction phrase", text: $store.configuration.focusPhrase)
                TextField("Idle phrase", text: $store.configuration.idlePhrase)

                Button("Test alarm") {
                    alarm.present(
                        kind: .test,
                        title: "ADHD Guard test",
                        message: "This is how a focus warning will look.",
                        phrase: store.configuration.focusPhrase,
                        speaks: store.configuration.speaksWarnings,
                        playsSound: store.configuration.playsSound
                    )
                }
            }

            Section("Browser permission") {
                Text("The first time ADHD Guard reads Safari, Chrome, Edge, Brave, or Arc, macOS asks for Automation permission. If access was denied, enable it in System Settings › Privacy & Security › Automation.")
                    .foregroundStyle(.secondary)
                Text("No browsing history is stored. Only the active tab URL is checked locally against your rules.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Restore defaults", role: .destructive) {
                    store.reset()
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .navigationTitle("Preferences")
    }
}
