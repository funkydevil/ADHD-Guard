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

struct StatusOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let presentation: GuardStatusPresentation
    var size: CGFloat = 172
    var showsDetail = true

    var body: some View {
        VStack(spacing: showsDetail ? 16 : 8) {
            ZStack {
                Circle()
                    .fill(presentation.color.opacity(0.13))
                    .blur(radius: size * 0.11)
                    .padding(size * 0.04)

                Circle()
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
                            : AnyShapeStyle(.regularMaterial)
                    )

                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)

                Circle()
                    .trim(from: 0, to: presentation.progress)
                    .stroke(
                        AngularGradient(
                            colors: [presentation.color.opacity(0.28), presentation.color, presentation.color.opacity(0.72)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: max(5, size * 0.045), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.055)

                VStack(spacing: size * 0.04) {
                    Image(systemName: presentation.symbol)
                        .font(.system(size: size * 0.20, weight: .semibold, design: .rounded))
                    Text(presentation.title)
                        .font(.system(size: size * 0.105, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .foregroundStyle(presentation.color)
                .padding(size * 0.16)
                .id(presentation.title)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .frame(width: size, height: size)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: presentation)

            if showsDetail {
                Text(presentation.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Guard status: \(presentation.title). \(presentation.detail)")
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
