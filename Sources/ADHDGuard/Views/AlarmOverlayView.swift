import SwiftUI

struct AlarmOverlayView: View {
    let alarm: AlarmPresentation
    let onBackToWork: () -> Void
    let onSnooze: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: alarm.kind == .idle ? "figure.stand" : "exclamationmark.shield.fill")
                .font(.system(size: 44, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(pulse ? 1.1 : 0.92)

            Text(alarm.title)
                .font(.system(size: 30, weight: .black, design: .rounded))

            Text(alarm.message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 12) {
                Button("Snooze 1 minute", action: onSnooze)
                    .buttonStyle(.bordered)

                Button("I'm going back", action: onBackToWork)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: alarm.kind == .idle
                            ? [Color.orange, Color.red]
                            : [Color.red, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alarm.title). \(alarm.message)")
    }
}
