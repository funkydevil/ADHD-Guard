import AppKit
import SwiftUI

enum GuardPalette {
    static let accent = Color(red: 0.47, green: 0.41, blue: 1.00)
    static let focused = Color(red: 0.18, green: 0.78, blue: 0.58)
    static let warning = Color(red: 0.95, green: 0.67, blue: 0.24)
    static let alarm = Color(red: 0.94, green: 0.36, blue: 0.43)
    static let paused = Color(red: 0.55, green: 0.57, blue: 0.65)
    static let canvasDark = Color(red: 0.055, green: 0.063, blue: 0.10)
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
    let symbol: String
    let color: Color
    let progress: Double

    var gradientColors: [Color] {
        switch state {
        case .paused:
            [
                Color(red: 0.32, green: 0.35, blue: 0.56),
                Color(red: 0.20, green: 0.43, blue: 0.46),
                Color(red: 0.42, green: 0.30, blue: 0.54)
            ]
        case .starting:
            [
                Color(red: 0.39, green: 0.35, blue: 0.85),
                Color(red: 0.32, green: 0.42, blue: 0.75),
                Color(red: 0.25, green: 0.30, blue: 0.47)
            ]
        case .focused:
            [
                Color(red: 0.13, green: 0.71, blue: 0.53),
                Color(red: 0.18, green: 0.56, blue: 0.62),
                Color(red: 0.38, green: 0.35, blue: 0.78)
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
            title = "Paused"
            detail = "Reminders are paused. Activity stays visible locally."
            symbol = "pause.fill"
            color = GuardPalette.paused
            progress = 1
            return
        }

        if remaining == 0 {
            state = .alarm
            title = "Refocus now"
            detail = "Your focus buffer has ended."
            symbol = "arrow.uturn.backward"
            color = GuardPalette.alarm
            progress = 1
            return
        }

        if let remaining {
            state = .grace(remaining)
            title = "\(remaining) seconds left"
            detail = "You’re outside your focus zone."
            symbol = "hourglass"
            color = GuardPalette.warning
            progress = min(1, max(0.06, Double(remaining) / Double(max(1, graceSeconds))))
            return
        }

        switch decision {
        case .focused:
            state = .focused
            title = "Focused"
            detail = "Guard is quietly watching your activity."
            symbol = "checkmark"
            color = GuardPalette.focused
            progress = 1
        case .distracted:
            state = .grace(graceSeconds)
            title = "Outside focus"
            detail = "Your focus buffer is ready to start."
            symbol = "hourglass"
            color = GuardPalette.warning
            progress = 1
        case nil:
            state = .starting
            title = "Getting ready"
            detail = "Waiting for your first activity."
            symbol = "scope"
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
    let presentation: GuardStatusPresentation
    var size: CGFloat = 28
    var gateColor: Color = .primary
    var coreColor: Color? = nil

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
        switch presentation.kind {
        case .focused:
            Circle()
                .fill(coreColor ?? presentation.color)
                .frame(width: size * 0.24, height: size * 0.24)
        case .starting:
            Circle()
                .stroke(coreColor ?? presentation.color, lineWidth: max(1.2, size * 0.06))
                .frame(width: size * 0.25, height: size * 0.25)
        case .grace:
            Circle()
                .trim(from: 0.10, to: 0.88)
                .stroke(
                    coreColor ?? presentation.color,
                    style: StrokeStyle(lineWidth: max(1.3, size * 0.065), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.28, height: size * 0.28)
        case .alarm:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                    .fill(coreColor ?? presentation.color)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .rotationEffect(.degrees(45))
                Text("!")
                    .font(.system(size: size * 0.19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        case .paused:
            HStack(spacing: size * 0.06) {
                Capsule().fill(coreColor ?? presentation.color)
                Capsule().fill(coreColor ?? presentation.color)
            }
            .frame(width: size * 0.24, height: size * 0.25)
        }
    }
}

struct CompactGuardStatus: View {
    let presentation: GuardStatusPresentation

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: presentation.gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(presentation.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Group {
                if let shortValue = presentation.shortValue {
                    Text(shortValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                } else {
                    Image(systemName: presentation.symbol)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(presentation.color)
            .frame(minWidth: 28)
            .fixedSize()
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 60)
        .guardCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Guard status: \(presentation.accessibilityTitle). \(presentation.detail)")
    }
}

struct MenuBarStatusIcon: View {
    let presentation: GuardStatusPresentation

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .frame(width: 18, height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ADHD Guard, \(presentation.accessibilityTitle)")
    }

    private var symbol: String {
        switch presentation.kind {
        case .paused:
            "pause.circle"
        case .starting:
            "ellipsis.circle"
        case .focused:
            "scope"
        case .grace:
            "timer"
        case .alarm:
            "exclamationmark.triangle.fill"
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

    var body: some View {
        Group {
            if let applicationURL = NSWorkspace.shared.urlForApplication(
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
