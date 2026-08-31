import AppKit
import AudioToolbox
import Combine
import SwiftUI

@MainActor
final class AlarmController: ObservableObject {
    @Published private(set) var activeAlarm: AlarmPresentation?

    private let speechSynthesizer = NSSpeechSynthesizer()
    private var panel: NSPanel?
    private var repeatTask: Task<Void, Never>?
    private var snoozedUntil: Date?

    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > Date()
    }

    func present(
        kind: AlarmKind,
        title: String,
        message: String,
        phrase: String,
        speaks: Bool,
        playsSound: Bool
    ) {
        guard !isSnoozed else { return }

        if let activeAlarm,
           activeAlarm.kind == kind,
           activeAlarm.message == message {
            return
        }

        let alarm = AlarmPresentation(kind: kind, title: title, message: message, phrase: phrase)
        activeAlarm = alarm
        showPanel(alarm: alarm)
        beginRepeatingAlert(phrase: phrase, speaks: speaks, playsSound: playsSound)
    }

    func dismiss() {
        repeatTask?.cancel()
        repeatTask = nil
        speechSynthesizer.stopSpeaking()
        panel?.orderOut(nil)
        activeAlarm = nil
    }

    func snooze(seconds: TimeInterval = 60) {
        snoozedUntil = Date().addingTimeInterval(seconds)
        dismiss()
    }

    private func showPanel(alarm: AlarmPresentation) {
        let content = AlarmOverlayView(
            alarm: alarm,
            onBackToWork: { [weak self] in self?.dismiss() },
            onSnooze: { [weak self] in self?.snooze() }
        )

        let hostingView = NSHostingView(rootView: content)
        let size = NSSize(width: 520, height: 270)

        let panel: NSPanel
        if let existing = self.panel {
            panel = existing
            panel.contentView = hostingView
            panel.setContentSize(size)
        } else {
            panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.contentView = hostingView
            self.panel = panel
        }

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.maxY - size.height - 36
            ))
        } else {
            panel.center()
        }
        panel.orderFrontRegardless()
    }

    private func beginRepeatingAlert(phrase: String, speaks: Bool, playsSound: Bool) {
        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if playsSound {
                    if let sound = NSSound(named: NSSound.Name("Sosumi")) {
                        sound.play()
                    } else {
                        AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert)
                    }
                }
                if speaks {
                    self.speechSynthesizer.stopSpeaking()
                    self.speechSynthesizer.startSpeaking(phrase)
                }
                try? await Task.sleep(nanoseconds: 3_500_000_000)
            }
        }
    }
}
