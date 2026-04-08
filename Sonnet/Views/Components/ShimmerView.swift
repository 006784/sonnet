import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    SonnetColors.paperLine,
                    SonnetColors.paperWhite.opacity(0.6),
                    SonnetColors.paperLine
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: phase * geo.size.width)
            .onAppear {
                withAnimation(
                    .linear(duration: SonnetMotion.shimmerDuration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
    }
}

struct ShimmerModifier: ViewModifier {
    var isLoading: Bool

    func body(content: Content) -> some View {
        if isLoading {
            content.overlay(ShimmerView())
        } else {
            content
        }
    }
}

extension View {
    func shimmer(when isLoading: Bool) -> some View {
        modifier(ShimmerModifier(isLoading: isLoading))
    }
}
