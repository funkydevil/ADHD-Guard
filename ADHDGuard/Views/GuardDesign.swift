import SwiftUI

enum GuardPalette {
    static let accent = Color(red: 0.37, green: 0.42, blue: 0.82)
    static let focused = Color(red: 0.09, green: 0.53, blue: 0.36)
    static let warning = Color(red: 0.70, green: 0.42, blue: 0.00)
    static let alarm = Color(red: 0.62, green: 0.13, blue: 0.16)
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
        .background(color.opacity(0.1), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

private struct GuardCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

extension View {
    func guardCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(GuardCardModifier(cornerRadius: cornerRadius))
    }
}
