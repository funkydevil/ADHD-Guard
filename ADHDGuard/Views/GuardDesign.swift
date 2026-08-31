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
                Color(red: 0.47, green: 0.49, blue: 0.57),
                Color(red: 0.30, green: 0.32, blue: 0.40),
                Color(red: 0.46, green: 0.42, blue: 0.53)
            ]
        case .starting:
            [
                Color(red: 0.47, green: 0.41, blue: 1.00),
                Color(red: 0.32, green: 0.49, blue: 1.00),
                Color(red: 0.61, green: 0.39, blue: 1.00)
            ]
        case .focused:
            [
                Color(red: 0.13, green: 0.79, blue: 0.54),
                Color(red: 0.21, green: 0.78, blue: 0.74),
                Color(red: 0.40, green: 0.47, blue: 1.00)
            ]
        case .grace:
            [
                Color(red: 1.00, green: 0.76, blue: 0.29),
                Color(red: 0.96, green: 0.54, blue: 0.24),
                Color(red: 0.94, green: 0.36, blue: 0.44)
            ]
        case .alarm:
            [
                Color(red: 1.00, green: 0.38, blue: 0.45),
                Color(red: 0.85, green: 0.20, blue: 0.35),
                Color(red: 0.49, green: 0.25, blue: 0.89)
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

    var body: some View {
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
        .ignoresSafeArea()
    }
}

struct FocusLensShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.09, y: rect.minY + rect.height * 0.09))
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.minY + rect.height * 0.22),
            control1: CGPoint(x: rect.minX + rect.width * 0.31, y: rect.minY - rect.height * 0.03),
            control2: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY - rect.height * 0.10),
            control1: CGPoint(x: rect.maxX + rect.width * 0.02, y: rect.minY + rect.height * 0.45),
            control2: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.07, y: rect.maxY - rect.height * 0.18),
            control1: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.maxY + rect.height * 0.03),
            control2: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY + rect.height * 0.01)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.09, y: rect.minY + rect.height * 0.09),
            control1: CGPoint(x: rect.minX - rect.width * 0.01, y: rect.maxY - rect.height * 0.38),
            control2: CGPoint(x: rect.minX + rect.width * 0.01, y: rect.minY + rect.height * 0.23)
        )
        path.closeSubpath()
        return path
    }
}

struct FocusStatusObject: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var shiftsGradient = false

    let presentation: GuardStatusPresentation

    var body: some View {
        ZStack {
            FocusLensShape()
                .fill(presentation.color.opacity(reduceTransparency ? 0.13 : 0.22))
                .blur(radius: reduceTransparency ? 0 : 22)
                .padding(8)

            FocusLensShape()
                .fill(
                    LinearGradient(
                        colors: presentation.gradientColors,
                        startPoint: shiftsGradient ? .topTrailing : .topLeading,
                        endPoint: shiftsGradient ? .bottomLeading : .bottomTrailing
                    )
                )

            FocusLensShape()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.34), .clear],
                        center: shiftsGradient ? .topTrailing : .topLeading,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .opacity(reduceTransparency ? 0.28 : 0.72)

            FocusLensShape()
                .stroke(.white.opacity(0.2), lineWidth: 1)

            HStack(spacing: 18) {
                Image(systemName: presentation.symbol)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(presentation.title)
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(presentation.detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let shortValue = presentation.shortValue {
                    Text(shortValue)
                        .font(.system(size: 29, weight: .bold, design: .rounded).monospacedDigit())
                        .transition(.opacity)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 34)
            .padding(.vertical, 26)

            if case .grace = presentation.state {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white.opacity(0.75))
                        .frame(width: max(22, (proxy.size.width - 68) * presentation.progress), height: 3)
                        .position(x: 34 + max(22, (proxy.size.width - 68) * presentation.progress) / 2, y: proxy.size.height - 22)
                }
            }
        }
        .frame(maxWidth: 500)
        .frame(height: 156)
        .shadow(color: presentation.color.opacity(0.24), radius: 24, y: 12)
        .animation(reduceMotion ? nil : .easeInOut(duration: 8).repeatForever(autoreverses: true), value: shiftsGradient)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: presentation)
        .onAppear { shiftsGradient = !reduceMotion }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Guard status: \(presentation.accessibilityTitle). \(presentation.detail)")
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

            Spacer(minLength: 6)

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
        ZStack {
            Image(systemName: presentation.state == .alarm ? "exclamationmark.shield.fill" : "shield.fill")
                .font(.system(size: 15, weight: .medium))
            Circle()
                .fill(presentation.color)
                .frame(width: 5, height: 5)
                .overlay {
                    Circle()
                        .stroke(Color(nsColor: .windowBackgroundColor).opacity(0.8), lineWidth: 0.5)
                }
                .offset(y: 2)
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("ADHD Guard, \(presentation.accessibilityTitle)")
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
