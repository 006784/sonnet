import SwiftUI

enum SonnetMotion {
    static let gentleSpring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let buttonTap = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let softExpand = Animation.spring(response: 0.58, dampingFraction: 0.82)
    static let easeIn = Animation.easeIn(duration: 0.2)
    static let easeOut = Animation.easeOut(duration: 0.25)
    static let easeInOut = Animation.easeInOut(duration: 0.32)

    static let pageTransition: AnyTransition = .opacity.combined(with: .offset(y: 12))
    static let pageEnter: AnyTransition = .opacity.combined(with: .move(edge: .bottom))
    static let cardAppear: AnyTransition = .scale(scale: 0.97).combined(with: .opacity)
    static let shimmerDuration: Double = 1.35

    // MARK: - Backward compatibility aliases

    static let spring = gentleSpring
    static let springFast = buttonTap
    static let springSlow = softExpand
}
