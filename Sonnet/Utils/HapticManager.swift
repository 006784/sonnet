import UIKit

enum HapticManager {
    static func light() { impact(.light) }
    static func medium() { impact(.medium) }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }

    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(type)
    }

    static func success() { notification(.success) }
    static func warning() { notification(.warning) }
    static func error()   { notification(.error) }
}
