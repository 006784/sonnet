import SwiftUI

struct SonnetTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String = ""

    var body: some View {
        HStack(spacing: SonnetDimens.spacingM) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundStyle(SonnetColors.textHint)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .font(SonnetTypography.body)
                .foregroundStyle(SonnetColors.textBody)
        }
        .padding(.horizontal, SonnetDimens.spacingL)
        .padding(.vertical, SonnetDimens.spacingM)
        .background(SonnetColors.paperKey)
        .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium))
    }
}
