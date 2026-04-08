import SwiftUI

struct InkButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary
    var isLoading: Bool = false

    enum ButtonStyle {
        case primary    // ink 背景，白字
        case ghost      // 透明底，0.5pt ink 边框，ink 字
        case danger     // vermilion 背景，白字
    }

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(foregroundColor)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium))
            .overlay(
                Group {
                    if style == .ghost {
                        RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium)
                            .stroke(SonnetColors.ink, lineWidth: 0.5)
                    }
                }
            )
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(SonnetMotion.springFast, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return SonnetColors.ink
        case .ghost:   return .clear
        case .danger:  return SonnetColors.vermilion
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return SonnetColors.textOnInk
        case .ghost:   return SonnetColors.ink
        case .danger:  return SonnetColors.textOnInk
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        InkButton(title: "记一笔", action: {})
        InkButton(title: "取消", action: {}, style: .ghost)
        InkButton(title: "删除", action: {}, style: .danger)
        InkButton(title: "保存中...", action: {}, isLoading: true)
    }
    .padding()
    .background(SonnetColors.paper)
}
