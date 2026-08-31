import CoreGraphics
import Foundation

enum IdleTimeProvider {
    static func currentIdleSeconds() -> TimeInterval {
        let eventTypes: [CGEventType] = [
            .keyDown,
            .flagsChanged,
            .mouseMoved,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel
        ]

        return eventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }
}
