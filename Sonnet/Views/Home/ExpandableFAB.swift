import SwiftUI

struct ExpandableFAB: View {
    @Binding var isExpanded: Bool
    let onAddRecord: () -> Void
    let onScan: () -> Void
    var onVoice: (() -> Void)? = nil

    private let subSpring = Animation.spring(response: 0.4, dampingFraction: 0.65)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 半透明遮罩
            if isExpanded {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(subSpring) { isExpanded = false }
                    }
                    .transition(.opacity)
            }

            // 按钮组
            VStack(alignment: .trailing, spacing: 16) {
                if isExpanded {
                    if let onVoice {
                        fabOption(icon: "mic.fill", label: "语音记账") {
                            withAnimation(subSpring) { isExpanded = false }; onVoice()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .bottom).combined(with: .opacity)))
                    }

                    fabOption(icon: "camera.fill", label: "拍照识别") {
                        withAnimation(subSpring) { isExpanded = false }; onScan()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .bottom).combined(with: .opacity)))

                    fabOption(icon: "pencil", label: "手动记账") {
                        withAnimation(subSpring) { isExpanded = false }; onAddRecord()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .bottom).combined(with: .opacity)))
                }

                // 主 FAB
                Button {
                    withAnimation(subSpring) { isExpanded.toggle() }
                    HapticManager.impact(.medium)
                } label: {
                    ZStack {
                        Circle()
                            .fill(SonnetColors.ink)
                            .frame(width: SonnetDimens.fabSize, height: SonnetDimens.fabSize)
                            .shadow(color: SonnetColors.ink.opacity(0.35), radius: 8, y: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isExpanded ? 45 : 0))
                            .animation(subSpring, value: isExpanded)
                    }
                }
                .frame(width: 56, height: 56)
            }
            .padding(.trailing, SonnetDimens.spacingXL)
            .padding(.bottom, SonnetDimens.spacingXL)
        }
    }

    private func fabOption(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SonnetDimens.spacingS) {
                Text(label)
                    .font(SonnetTypography.footnote)
                    .foregroundStyle(SonnetColors.textBody)
                    .padding(.horizontal, SonnetDimens.spacingM)
                    .padding(.vertical, 7)
                    .background(SonnetColors.paperWhite)
                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusFull))
                    .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)

                ZStack {
                    Circle()
                        .fill(SonnetColors.paperWhite)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
        .frame(minWidth: 44, minHeight: 44)
    }
}

#Preview {
    @Previewable @State var expanded = false
    ZStack(alignment: .bottomTrailing) {
        Color(SonnetColors.paper).ignoresSafeArea()
        ExpandableFAB(isExpanded: $expanded, onAddRecord: {}, onScan: {}, onVoice: {})
    }
}
