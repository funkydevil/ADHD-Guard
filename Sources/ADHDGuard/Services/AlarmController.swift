import AppKit
import AudioToolbox
import Combine
import SwiftUI

@MainActor
final class AlarmController: ObservableObject {
    @Published private(set) var activeAlarm: AlarmPresentation?

    private let speechSynthesizer = NSSpeechSynthesizer()
    private let previewSpeechSynthesizer = NSSpeechSynthesizer()
    private var panels: [NSNumber: NSPanel] = [:]
    private var repeatTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?

    func present(
        kind: AlarmKind,
        title: String,
        message: String,
        phrase: String,
        speaks: Bool,
        playsSound: Bool
    ) {
        if let activeAlarm,
           activeAlarm.kind == kind,
           activeAlarm.message == message {
            positionPanels()
            return
        }

        let alarm = AlarmPresentation(kind: kind, title: title, message: message, phrase: phrase)
        let startsNewEpisode = activeAlarm == nil || activeAlarm?.kind != kind
        if startsNewEpisode {
            previewTask?.cancel()
            previewSpeechSynthesizer.stopSpeaking()
        }
        activeAlarm = alarm
        showPanels(alarm: alarm)
        if startsNewEpisode {
            announce(alarm)
            beginRepeatingAlert(phrase: phrase, speaks: speaks, playsSound: playsSound)
        }
    }

    func dismiss() {
        repeatTask?.cancel()
        repeatTask = nil
        speechSynthesizer.stopSpeaking()
        panels.values.forEach { $0.orderOut(nil) }
        activeAlarm = nil
    }

    func preview(phrase: String, speaks: Bool, playsSound: Bool) {
        guard activeAlarm == nil else { return }
        previewTask?.cancel()
        previewSpeechSynthesizer.stopSpeaking()
        previewTask = Task { [weak self] in
            guard let self else { return }
            if playsSound {
                await self.playChime()
            }
            guard !Task.isCancelled, speaks else { return }
            self.previewSpeechSynthesizer.startSpeaking(phrase)
        }
    }

    private func showPanels(alarm: AlarmPresentation) {
        let activeScreenIDs = Set(NSScreen.screens.compactMap(screenIdentifier))

        for screen in NSScreen.screens {
            guard let identifier = screenIdentifier(screen) else { continue }
            let panel = panels[identifier] ?? makePanel()
            panels[identifier] = panel
            panel.contentView = NSHostingView(rootView: AlarmOverlayView(alarm: alarm))
            position(panel, on: screen)
            panel.orderFrontRegardless()
        }

        for identifier in Array(panels.keys) where !activeScreenIDs.contains(identifier) {
            panels[identifier]?.orderOut(nil)
            panels[identifier] = nil
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        return panel
    }

    private func positionPanels() {
        for screen in NSScreen.screens {
            guard let identifier = screenIdentifier(screen), let panel = panels[identifier] else { continue }
            position(panel, on: screen)
        }
    }

    private func position(_ panel: NSPanel, on screen: NSScreen) {
        let height: CGFloat = 92
        panel.setFrame(
            NSRect(
                x: screen.frame.minX,
                y: screen.visibleFrame.maxY - height,
                width: screen.frame.width,
                height: height
            ),
            display: true
        )
    }

    private func screenIdentifier(_ screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }

    private func announce(_ alarm: AlarmPresentation) {
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "\(alarm.title). \(alarm.message)",
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    private func beginRepeatingAlert(phrase: String, speaks: Bool, playsSound: Bool) {
        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
            guard let self else { return }
            await self.deliverAlert(phrase: phrase, speaks: speaks, playsSound: playsSound)

            var cycle = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { return }
                cycle += 1
                if playsSound {
                    await self.playChime()
                }
                if speaks, cycle.isMultiple(of: 2) {
                    self.speechSynthesizer.stopSpeaking()
                    self.speechSynthesizer.startSpeaking(phrase)
                }
            }
        }
    }

    private func deliverAlert(phrase: String, speaks: Bool, playsSound: Bool) async {
        if playsSound {
            await playChime()
        }
        guard !Task.isCancelled, speaks else { return }
        speechSynthesizer.stopSpeaking()
        speechSynthesizer.startSpeaking(phrase)
    }

    private func playChime() async {
        if let glass = NSSound(named: NSSound.Name("Glass")) {
            glass.play()
            try? await Task.sleep(nanoseconds: 180_000_000)
        }
        guard !Task.isCancelled else { return }
        if let tink = NSSound(named: NSSound.Name("Tink")) {
            tink.play()
        } else {
            AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert)
        }
    }
}
