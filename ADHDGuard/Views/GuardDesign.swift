import AppKit
import SwiftUI

enum GuardPalette {
    static let accent = Color(red: 0.16, green: 0.75, blue: 0.65)
    static let focused = Color(red: 0.22, green: 0.82, blue: 0.65)
    static let warning = Color(red: 0.95, green: 0.67, blue: 0.24)
    static let alarm = Color(red: 0.94, green: 0.36, blue: 0.43)
    static let paused = Color(red: 0.53, green: 0.61, blue: 0.59)
    static let canvasDark = Color(red: 0.045, green: 0.075, blue: 0.068)
    static let cloudBase = Color(red: 0.035, green: 0.12, blue: 0.10)
}

enum GuardVisualState: Equatable {
    case paused
    case starting
    case focused
    case grace(Int)
    case alarm

    var kind: GuardVisualKind {
        switch self {
        case .paused: .paused
        case .starting: .starting
        case .focused: .focused
        case .grace: .grace
        case .alarm: .alarm
        }
    }
}

enum GuardVisualKind: Equatable {
    case paused
    case starting
    case focused
    case grace
    case alarm
}

struct GuardStatusPresentation: Equatable {
    let state: GuardVisualState
    let title: String
    let detail: String
    let color: Color
    let progress: Double

    var gradientColors: [Color] {
        switch state {
        case .paused:
            [
                Color(red: 0.31, green: 0.43, blue: 0.39),
                Color(red: 0.24, green: 0.39, blue: 0.36),
                Color(red: 0.36, green: 0.43, blue: 0.39)
            ]
        case .starting:
            [
                Color(red: 0.13, green: 0.63, blue: 0.53),
                Color(red: 0.17, green: 0.49, blue: 0.43),
                Color(red: 0.20, green: 0.39, blue: 0.31)
            ]
        case .focused:
            [
                Color(red: 0.13, green: 0.71, blue: 0.53),
                Color(red: 0.08, green: 0.59, blue: 0.53),
                Color(red: 0.29, green: 0.60, blue: 0.40)
            ]
        case .grace:
            [
                Color(red: 0.91, green: 0.66, blue: 0.29),
                Color(red: 0.85, green: 0.47, blue: 0.32),
                Color(red: 0.73, green: 0.31, blue: 0.39)
            ]
        case .alarm:
            [
                Color(red: 0.88, green: 0.32, blue: 0.39),
                Color(red: 0.71, green: 0.23, blue: 0.33),
                Color(red: 0.44, green: 0.23, blue: 0.51)
            ]
        }
    }

    var shortValue: String? {
        guard case let .grace(remaining) = state else { return nil }
        return "\(remaining)s"
    }

    var accessibilityTitle: String {
        if let shortValue {
            return "\(shortValue) outside focus"
        }
        return title
    }

    var kind: GuardVisualKind { state.kind }

    init(
        monitoringEnabled: Bool,
        decision: RuleDecision?,
        remaining: Int?,
        graceSeconds: Int
    ) {
        guard monitoringEnabled else {
            state = .paused
            title = "Reminders are off"
            detail = "Activity history still updates on this Mac."
            color = GuardPalette.paused
            progress = 1
            return
        }

        if remaining == 0 {
            state = .alarm
            title = "Refocus now"
            detail = "Return to a focus app to end the reminder."
            color = GuardPalette.alarm
            progress = 1
            return
        }

        if let remaining {
            state = .grace(remaining)
            title = "Reminder in \(remaining)s"
            detail = "You’re outside your focus zone."
            color = GuardPalette.warning
            progress = min(1, max(0.06, Double(remaining) / Double(max(1, graceSeconds))))
            return
        }

        switch decision {
        case .focused:
            state = .focused
            title = "In focus"
            detail = "This activity is in your focus list."
            color = GuardPalette.focused
            progress = 1
        case .distracted:
            state = .grace(graceSeconds)
            title = "Outside focus"
            detail = "The timer starts when you return to this activity."
            color = GuardPalette.warning
            progress = 1
        case nil:
            state = .starting
            title = "Getting ready"
            detail = "Waiting for your first activity."
            color = GuardPalette.accent
            progress = 0.68
        }
    }
}

struct GuardAuraBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var extendsUnderSafeArea = true

    var body: some View {
        Group {
            if extendsUnderSafeArea {
                background.ignoresSafeArea()
            } else {
                background
            }
        }
    }

    private var background: some View {
        ZStack {
            (colorScheme == .dark ? GuardPalette.canvasDark : Color(nsColor: .windowBackgroundColor))

            if !reduceTransparency {
                Circle()
                    .fill(GuardPalette.accent.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    .frame(width: 520, height: 520)
                    .blur(radius: 110)
                    .offset(x: -250, y: -260)

                Circle()
                    .fill(GuardPalette.focused.opacity(colorScheme == .dark ? 0.13 : 0.08))
                    .frame(width: 460, height: 460)
                    .blur(radius: 125)
                    .offset(x: 330, y: 270)
            }
        }
    }
}

private struct FocusGateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: rect.minX + width * 0.38, y: rect.minY + height * 0.12))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.14, y: rect.minY + height * 0.37),
            control1: CGPoint(x: rect.minX + width * 0.24, y: rect.minY + height * 0.13),
            control2: CGPoint(x: rect.minX + width * 0.15, y: rect.minY + height * 0.23)
        )
        path.addLine(to: CGPoint(x: rect.minX + width * 0.14, y: rect.minY + height * 0.63))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.38, y: rect.minY + height * 0.88),
            control1: CGPoint(x: rect.minX + width * 0.15, y: rect.minY + height * 0.77),
            control2: CGPoint(x: rect.minX + width * 0.24, y: rect.minY + height * 0.87)
        )

        path.move(to: CGPoint(x: rect.minX + width * 0.62, y: rect.minY + height * 0.12))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.86, y: rect.minY + height * 0.37),
            control1: CGPoint(x: rect.minX + width * 0.76, y: rect.minY + height * 0.13),
            control2: CGPoint(x: rect.minX + width * 0.85, y: rect.minY + height * 0.23)
        )
        path.addLine(to: CGPoint(x: rect.minX + width * 0.86, y: rect.minY + height * 0.63))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.62, y: rect.minY + height * 0.88),
            control1: CGPoint(x: rect.minX + width * 0.85, y: rect.minY + height * 0.77),
            control2: CGPoint(x: rect.minX + width * 0.76, y: rect.minY + height * 0.87)
        )
        return path
    }
}

struct GuardMark: View {
    var size: CGFloat = 28
    var gateColor: Color = .primary
    var coreColor: Color? = nil

    private let kind: GuardVisualKind
    private let stateColor: Color

    init(
        presentation: GuardStatusPresentation,
        size: CGFloat = 28,
        gateColor: Color = .primary,
        coreColor: Color? = nil
    ) {
        kind = presentation.kind
        stateColor = presentation.color
        self.size = size
        self.gateColor = gateColor
        self.coreColor = coreColor
    }

    init(
        kind: GuardVisualKind,
        color: Color,
        size: CGFloat = 28,
        gateColor: Color = .primary,
        coreColor: Color? = nil
    ) {
        self.kind = kind
        stateColor = color
        self.size = size
        self.gateColor = gateColor
        self.coreColor = coreColor
    }

    var body: some View {
        ZStack {
            FocusGateShape()
                .stroke(
                    gateColor,
                    style: StrokeStyle(
                        lineWidth: max(1.4, size * 0.075),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            core
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var core: some View {
        switch kind {
        case .focused:
            Circle()
                .fill(coreColor ?? stateColor)
                .frame(width: size * 0.24, height: size * 0.24)
        case .starting:
            Circle()
                .stroke(coreColor ?? stateColor, lineWidth: max(1.2, size * 0.06))
                .frame(width: size * 0.25, height: size * 0.25)
        case .grace:
            Circle()
                .trim(from: 0.10, to: 0.88)
                .stroke(
                    coreColor ?? stateColor,
                    style: StrokeStyle(lineWidth: max(1.3, size * 0.065), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.28, height: size * 0.28)
        case .alarm:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                    .fill(coreColor ?? stateColor)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .rotationEffect(.degrees(45))
                Text("!")
                    .font(.system(size: size * 0.19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        case .paused:
            HStack(spacing: size * 0.06) {
                Capsule().fill(coreColor ?? stateColor)
                Capsule().fill(coreColor ?? stateColor)
            }
            .frame(width: size * 0.24, height: size * 0.25)
        }
    }
}

/// Shared, explicit control for the same setting on both app surfaces.
struct FocusModeControl: View {
    @Binding var isOn: Bool
    let isLocked: Bool
    let graceSeconds: Int
    let remaining: Int?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle(isOn: $isOn) {
                HStack(spacing: 10) {
                    Text("Focus mode")
                        .font(compact ? .headline : .title2.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(isOn ? "On" : "Off")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? GuardPalette.focused : .secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(GuardPalette.focused)
            .controlSize(.regular)
            .disabled(isLocked)
            .accessibilityLabel("Focus mode")
            .accessibilityHint(isLocked
                ? "Return to a focus app before turning Focus mode off."
                : "Turns focus reminders on or off.")
            .help(isLocked
                ? "Return to a focus app before turning Focus mode off."
                : "Turn focus reminders on or off.")

            Text("Reminders after \(graceSeconds)s outside your focus apps or on distracting sites.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isOn, let remaining, remaining > 0 {
                Label("Reminder in \(remaining)s", systemImage: "timer")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(GuardPalette.warning)
            }

            if isLocked {
                Label("Return to a focus app before turning Focus mode off.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(GuardPalette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MenuBarStatusIcon: View {
    let presentation: GuardStatusPresentation

    var body: some View {
        Image(nsImage: Self.templateImage(for: presentation.kind))
            .renderingMode(.template)
            .frame(width: 18, height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ADHD Guard, \(presentation.accessibilityTitle)")
    }

    static func templateImage(for kind: GuardVisualKind) -> NSImage {
        let imageSize = NSSize(width: 18, height: 18)
        let image = NSImage(size: imageSize, flipped: true) { rect in
            drawGate(in: rect)
            drawCore(for: kind, in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawGate(in rect: NSRect) {
        let width = rect.width
        let height = rect.height
        let path = NSBezierPath()

        path.move(to: NSPoint(x: rect.minX + width * 0.38, y: rect.minY + height * 0.12))
        path.curve(
            to: NSPoint(x: rect.minX + width * 0.14, y: rect.minY + height * 0.37),
            controlPoint1: NSPoint(x: rect.minX + width * 0.24, y: rect.minY + height * 0.13),
            controlPoint2: NSPoint(x: rect.minX + width * 0.15, y: rect.minY + height * 0.23)
        )
        path.line(to: NSPoint(x: rect.minX + width * 0.14, y: rect.minY + height * 0.63))
        path.curve(
            to: NSPoint(x: rect.minX + width * 0.38, y: rect.minY + height * 0.88),
            controlPoint1: NSPoint(x: rect.minX + width * 0.15, y: rect.minY + height * 0.77),
            controlPoint2: NSPoint(x: rect.minX + width * 0.24, y: rect.minY + height * 0.87)
        )

        path.move(to: NSPoint(x: rect.minX + width * 0.62, y: rect.minY + height * 0.12))
        path.curve(
            to: NSPoint(x: rect.minX + width * 0.86, y: rect.minY + height * 0.37),
            controlPoint1: NSPoint(x: rect.minX + width * 0.76, y: rect.minY + height * 0.13),
            controlPoint2: NSPoint(x: rect.minX + width * 0.85, y: rect.minY + height * 0.23)
        )
        path.line(to: NSPoint(x: rect.minX + width * 0.86, y: rect.minY + height * 0.63))
        path.curve(
            to: NSPoint(x: rect.minX + width * 0.62, y: rect.minY + height * 0.88),
            controlPoint1: NSPoint(x: rect.minX + width * 0.85, y: rect.minY + height * 0.77),
            controlPoint2: NSPoint(x: rect.minX + width * 0.76, y: rect.minY + height * 0.87)
        )

        path.lineWidth = 1.55
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.black.setStroke()
        path.stroke()
    }

    private static func drawCore(for kind: GuardVisualKind, in rect: NSRect) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let coreRect = NSRect(x: center.x - 2.1, y: center.y - 2.1, width: 4.2, height: 4.2)
        NSColor.black.setFill()
        NSColor.black.setStroke()

        switch kind {
        case .focused:
            NSBezierPath(ovalIn: coreRect).fill()
        case .starting:
            let path = NSBezierPath(ovalIn: coreRect)
            path.lineWidth = 1.2
            path.stroke()
        case .grace:
            let path = NSBezierPath()
            path.appendArc(
                withCenter: center,
                radius: 2.2,
                startAngle: 50,
                endAngle: 330,
                clockwise: false
            )
            path.lineWidth = 1.25
            path.lineCapStyle = .round
            path.stroke()
        case .alarm:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x, y: center.y - 2.4))
            path.line(to: NSPoint(x: center.x + 2.4, y: center.y))
            path.line(to: NSPoint(x: center.x, y: center.y + 2.4))
            path.line(to: NSPoint(x: center.x - 2.4, y: center.y))
            path.close()
            path.fill()
        case .paused:
            NSBezierPath(
                roundedRect: NSRect(x: center.x - 2.2, y: center.y - 2.2, width: 1.45, height: 4.4),
                xRadius: 0.7,
                yRadius: 0.7
            ).fill()
            NSBezierPath(
                roundedRect: NSRect(x: center.x + 0.75, y: center.y - 2.2, width: 1.45, height: 4.4),
                xRadius: 0.7,
                yRadius: 0.7
            ).fill()
        }
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.11), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct ApplicationIcon: View {
    let bundleIdentifier: String
    var size: CGFloat = 34

    // Load our icon directly: Launch Services may resolve an older installed build.
    private static let ownIcon = Bundle.main.url(forResource: "AppIcon-1024", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        Group {
            if bundleIdentifier.caseInsensitiveCompare(Bundle.main.bundleIdentifier ?? "com.funkydevil.ADHDGuard") == .orderedSame,
               let ownIcon = Self.ownIcon {
                Image(nsImage: ownIcon)
                    .resizable()
            } else if let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
            ) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(size * 0.14)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct GuardCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
                            : AnyShapeStyle(.thinMaterial)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

extension View {
    func guardCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GuardCardModifier(cornerRadius: cornerRadius))
    }
}
