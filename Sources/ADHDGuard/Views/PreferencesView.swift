import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var alarm: AlarmController
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginController

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Start ADHD Guard at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .disabled(!launchAtLogin.isAvailable)

                if launchAtLogin.requiresApproval {
                    LabeledContent {
                        Button("Open Login Items") {
                            launchAtLogin.openLoginItemsSettings()
                        }
                    } label: {
                        Label("Approval is required in System Settings", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(GuardPalette.warning)
                    }
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(GuardPalette.alarm)
                }
            }

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

            Section("Reminder sound") {
                Toggle("Play a reminder chime", isOn: $store.configuration.playsSound)
                Toggle("Speak a focus phrase", isOn: $store.configuration.speaksWarnings)

                LabeledContent("Focus phrase") {
                    TextField("Focus phrase", text: $store.configuration.focusPhrase)
                        .labelsHidden()
                        .frame(maxWidth: 320)
                }
                .disabled(!store.configuration.speaksWarnings)

                LabeledContent("Idle phrase") {
                    TextField("Idle phrase", text: $store.configuration.idlePhrase)
                        .labelsHidden()
                        .frame(maxWidth: 320)
                }
                .disabled(!store.configuration.speaksWarnings)

                Button("Preview reminder") {
                    alarm.preview(
                        phrase: store.configuration.focusPhrase,
                        speaks: store.configuration.speaksWarnings,
                        playsSound: store.configuration.playsSound
                    )
                }

                Text("The chime repeats every 15 seconds. Voice repeats every 30 seconds until you return to an allowed context.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
