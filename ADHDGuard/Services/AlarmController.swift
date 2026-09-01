import AppKit
import AudioToolbox
import Combine
import SwiftUI

@MainActor
final class AlarmController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var activeAlarm: AlarmPresentation?

    private let panelSize = NSSize(width: 560, height: 72)
    private let panelEdgeInset: CGFloat = 16
    private let panelPositionKeyPrefix = "adhd-guard.alarm-position."
    private let speechSynthesizer = NSSpeechSynthesizer()
    private let previewSpeechSynthesizer = NSSpeechSynthesizer()
    private var panels: [NSNumber: NSPanel] = [:]
    private var panelScreenIdentifiers: [ObjectIdentifier: NSNumber] = [:]
    private var isUpdatingPanelFrame = false
    private var screenParametersCancellable: AnyCancellable?
    private var repeatTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var returnToFocusAction: (() -> Void)?

    override init() {
        super.init()
        screenParametersCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let activeAlarm = self.activeAlarm else { return }
                self.showPanels(alarm: activeAlarm)
            }
    }

    func present(
        kind: AlarmKind,
        title: String,
        message: String,
        phrase: String,
        speaks: Bool,
        playsSound: Bool,
        returnToFocus: @escaping () -> Void
    ) {
        returnToFocusAction = returnToFocus
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
        returnToFocusAction = nil
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
            let panel: NSPanel
            if let existingPanel = panels[identifier] {
                panel = existingPanel
            } else {
                panel = makePanel()
                panels[identifier] = panel
                panelScreenIdentifiers[ObjectIdentifier(panel)] = identifier
            }
            let returnToFocus = { [weak self] in
                self?.returnToFocusAction?()
                return
            }
            panel.contentView = DraggableHostingView(
                rootView: AlarmOverlayView(
                    alarm: alarm,
                    onReturnToFocus: returnToFocus
                ),
                onClick: returnToFocus
            )
            position(panel, on: screen, identifier: identifier)
            panel.orderFrontRegardless()
        }

        for identifier in Array(panels.keys) where !activeScreenIDs.contains(identifier) {
            if let panel = panels[identifier] {
                panel.orderOut(nil)
                panelScreenIdentifiers[ObjectIdentifier(panel)] = nil
            }
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
        panel.ignoresMouseEvents = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self
        return panel
    }

    private func positionPanels() {
        for screen in NSScreen.screens {
            guard let identifier = screenIdentifier(screen), let panel = panels[identifier] else { continue }
            position(panel, on: screen, identifier: identifier)
        }
    }

    private func position(_ panel: NSPanel, on screen: NSScreen, identifier: NSNumber) {
        let visibleFrame = screen.visibleFrame
        let size = NSSize(
            width: min(panelSize.width, visibleFrame.width - panelEdgeInset * 2),
            height: min(panelSize.height, visibleFrame.height - panelEdgeInset * 2)
        )
        let origin = storedOrigin(for: identifier, in: visibleFrame, panelSize: size)
            ?? NSPoint(x: visibleFrame.midX - size.width / 2, y: visibleFrame.midY - size.height / 2)

        setFrame(NSRect(origin: origin, size: size), for: panel)
    }

    func windowDidMove(_ notification: Notification) {
        guard !isUpdatingPanelFrame,
              let panel = notification.object as? NSPanel,
              let identifier = panelScreenIdentifiers[ObjectIdentifier(panel)],
              let screen = NSScreen.screens.first(where: { screenIdentifier($0) == identifier }) else {
            return
        }

        let constrainedOrigin = constrainedOrigin(
            panel.frame.origin,
            panelSize: panel.frame.size,
            in: screen.visibleFrame
        )
        if constrainedOrigin != panel.frame.origin {
            setFrame(NSRect(origin: constrainedOrigin, size: panel.frame.size), for: panel)
        }
        store(origin: constrainedOrigin, panelSize: panel.frame.size, on: screen, identifier: identifier)
    }

    private func setFrame(_ frame: NSRect, for panel: NSPanel) {
        isUpdatingPanelFrame = true
        panel.setFrame(frame, display: true)
        isUpdatingPanelFrame = false
    }

    private func constrainedOrigin(_ origin: NSPoint, panelSize: NSSize, in visibleFrame: NSRect) -> NSPoint {
        let minimumX = visibleFrame.minX + panelEdgeInset
        let maximumX = max(minimumX, visibleFrame.maxX - panelSize.width - panelEdgeInset)
        let minimumY = visibleFrame.minY + panelEdgeInset
        let maximumY = max(minimumY, visibleFrame.maxY - panelSize.height - panelEdgeInset)

        return NSPoint(
            x: min(max(origin.x, minimumX), maximumX),
            y: min(max(origin.y, minimumY), maximumY)
        )
    }

    private func store(origin: NSPoint, panelSize: NSSize, on screen: NSScreen, identifier: NSNumber) {
        let visibleFrame = screen.visibleFrame
        let minimumX = visibleFrame.minX + panelEdgeInset
        let minimumY = visibleFrame.minY + panelEdgeInset
        let horizontalTravel = max(visibleFrame.width - panelSize.width - panelEdgeInset * 2, 1)
        let verticalTravel = max(visibleFrame.height - panelSize.height - panelEdgeInset * 2, 1)
        let normalizedX = min(max((origin.x - minimumX) / horizontalTravel, 0), 1)
        let normalizedY = min(max((origin.y - minimumY) / verticalTravel, 0), 1)

        UserDefaults.standard.set(
            ["x": Double(normalizedX), "y": Double(normalizedY)],
            forKey: panelPositionKey(for: identifier)
        )
    }

    private func storedOrigin(for identifier: NSNumber, in visibleFrame: NSRect, panelSize: NSSize) -> NSPoint? {
        guard let position = UserDefaults.standard.dictionary(forKey: panelPositionKey(for: identifier)),
              let normalizedX = position["x"] as? Double,
              let normalizedY = position["y"] as? Double else {
            return nil
        }

        let minimumX = visibleFrame.minX + panelEdgeInset
        let minimumY = visibleFrame.minY + panelEdgeInset
        let horizontalTravel = max(visibleFrame.width - panelSize.width - panelEdgeInset * 2, 1)
        let verticalTravel = max(visibleFrame.height - panelSize.height - panelEdgeInset * 2, 1)
        return constrainedOrigin(
            NSPoint(
                x: minimumX + horizontalTravel * CGFloat(normalizedX),
                y: minimumY + verticalTravel * CGFloat(normalizedY)
            ),
            panelSize: panelSize,
            in: visibleFrame
        )
    }

    private func panelPositionKey(for identifier: NSNumber) -> String {
        panelPositionKeyPrefix + identifier.stringValue
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

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    private let onClick: () -> Void

    init(rootView: Content, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("init(rootView:) is unavailable")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let originalPointerLocation = NSEvent.mouseLocation
        window.performDrag(with: event)

        if AlarmPointerInteraction.isClick(
            from: originalPointerLocation,
            to: NSEvent.mouseLocation
        ) {
            onClick()
        }
    }
}

enum AlarmPointerInteraction {
    private static let maximumClickTravel: CGFloat = 0.75

    static func isClick(from originalOrigin: NSPoint, to currentOrigin: NSPoint) -> Bool {
        hypot(
            currentOrigin.x - originalOrigin.x,
            currentOrigin.y - originalOrigin.y
        ) < maximumClickTravel
    }
}
