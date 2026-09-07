import AppKit
import SwiftUI

struct AlarmOverlayView: View {
    let alarm: AlarmPresentation
    let onReturnToFocus: () -> Void

    var body: some View {
        ZStack {
            // Only the explicit button returns to focus. A press anywhere else
            // can start a drag, but can never dismiss the reminder.
            AlarmDragRegion()
                .accessibilityHidden(true)

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 7) {
                        Image(systemName: "circle.grid.2x3.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("ADHD Guard")
                            .font(.system(size: 11, weight: .semibold))
                        Text("·  Drag to move")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(0.58))

                    HStack(spacing: 12) {
                        GuardMark(
                            kind: alarm.kind == .idle ? .grace : .alarm,
                            color: accentColor,
                            size: 30,
                            gateColor: accentColor,
                            coreColor: accentColor
                        )
                        .frame(width: 44, height: 44)
                        .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(alarm.title)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(alarm.message)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.76))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    AlarmDragRegion()
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(alarm.title). \(alarm.message)")
                .accessibilityHint("Drag to move the reminder.")

                Button(action: onReturnToFocus) {
                    HStack(spacing: 7) {
                        Text("Return to focus")
                        Image(systemName: "arrow.turn.up.left")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .foregroundStyle(.white)
                    .background(accentColor.opacity(0.23), in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .help("Return to your last focused app or website")
                .accessibilityHint("Switches to your last focused app or website.")
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.15, blue: 0.14), GuardPalette.canvasDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var accentColor: Color {
        alarm.kind == .idle ? GuardPalette.warning : GuardPalette.alarm
    }
}

private struct AlarmDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> AlarmDragView {
        AlarmDragView()
    }

    func updateNSView(_ nsView: AlarmDragView, context: Context) {}
}

/// A drag-only event target, deliberately separate from the return button.
final class AlarmDragView: NSView {
    private var dragStartPointer: NSPoint?
    private var dragStartOrigin: NSPoint?

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartPointer = window.convertPoint(toScreen: event.locationInWindow)
        dragStartOrigin = window.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStartPointer, let dragStartOrigin else { return }
        // Screen coordinates stay stable while the window itself is moving.
        let pointer = window.convertPoint(toScreen: event.locationInWindow)
        window.setFrameOrigin(NSPoint(
            x: dragStartOrigin.x + pointer.x - dragStartPointer.x,
            y: dragStartOrigin.y + pointer.y - dragStartPointer.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        dragStartPointer = nil
        dragStartOrigin = nil
    }
}
