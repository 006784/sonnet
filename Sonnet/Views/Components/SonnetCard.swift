import SwiftUI

struct SonnetCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusXL))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusXL)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )
    }
}

// 可点击版本，带按压动效
struct TappableSonnetCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    @State private var isPressed = false

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        content
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusXL))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusXL)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(SonnetMotion.springFast, value: isPressed)
            .onTapGesture(perform: action)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded   { _ in isPressed = false }
            )
    }
}

#Preview {
    VStack(spacing: 16) {
        SonnetCard {
            Text("静态卡片")
                .padding()
        }
        TappableSonnetCard(action: {}) {
            Text("可点击卡片")
                .padding()
        }
    }
    .padding()
    .background(SonnetColors.paper)
}
