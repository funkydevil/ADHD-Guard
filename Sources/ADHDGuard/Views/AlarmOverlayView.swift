import SwiftUI

struct AlarmOverlayView: View {
    let alarm: AlarmPresentation

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: alarm.kind == .idle ? "figure.walk.motion" : "scope")
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(alarm.title)
                    .font(.system(size: 20, weight: .semibold))
                Text(alarm.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }

            Spacer(minLength: 24)

            Label(instruction, systemImage: "arrow.right.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alarm.kind == .idle ? Color(red: 0.70, green: 0.42, blue: 0.00) : Color(red: 0.62, green: 0.13, blue: 0.16))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.16))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alarm.title). \(alarm.message)")
        .accessibilityHint(instruction)
    }

    private var instruction: String {
        switch alarm.kind {
        case .distraction:
            "Return to an allowed context to silence this alert"
        case .idle:
            "Move the pointer or press a key to silence this alert"
        case .test:
            "Preview"
        }
    }
}
