import SwiftUI

extension View {
    func cardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color(.systemBackground))
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    func primaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(14)
            .font(.headline)
    }

    func secondaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .foregroundColor(.blue)
            .cornerRadius(14)
            .font(.headline)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.5)))
    }

    func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            self
        }
    }

    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Haptic Feedback
struct HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
