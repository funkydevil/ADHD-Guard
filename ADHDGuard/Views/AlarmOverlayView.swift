import SwiftUI

struct AlarmOverlayView: View {
    let alarm: AlarmPresentation
    let onReturnToFocus: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alarm.kind == .idle ? "figure.walk.motion" : "scope")
                .font(.system(size: 21, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(alarm.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Label("Drag to move", systemImage: "hand.draw.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(instruction)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alarm.title). \(alarm.message)")
        .accessibilityHint("Click to return to your last focused context. Drag to move. \(instruction)")
        .accessibilityAction(named: "Return to last focused context", onReturnToFocus)
    }

    private var backgroundColor: Color {
        alarm.kind == .idle
            ? Color(red: 0.48, green: 0.25, blue: 0.00)
            : Color(red: 0.62, green: 0.13, blue: 0.16)
    }

    private var instruction: String {
        switch alarm.kind {
        case .distraction:
            "Click to return • Drag to move"
        case .idle:
            "Click to return • Drag to move"
        case .test:
            "Preview"
        }
    }
}
