import SwiftUI

struct StudentHeroCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let colorName: String
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        icon: String,
        colorName: String = "education",
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colorName = colorName
        self.content = content()
    }

    var body: some View {
        let colors = SonnetColors.categoryColors(for: colorName)

        return SonnetCard {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingL) {
                HStack(spacing: SonnetDimens.spacingM) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colors.bg)
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(colors.icon)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(SonnetTypography.titleCard)
                            .foregroundStyle(SonnetColors.textTitle)
                        Text(subtitle)
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 0)
                }

                content
            }
            .padding(SonnetDimens.cardPadding)
        }
    }
}

struct StudentMetricPill: View {
    let title: String
    let value: String
    var tint: Color = SonnetColors.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(SonnetTypography.amountBody)
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .font(SonnetTypography.caption2)
                .foregroundStyle(SonnetColors.textCaption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SonnetColors.paperLight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct StudentSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(SonnetTypography.titleCard)
                .foregroundStyle(SonnetColors.textTitle)
            if let subtitle {
                Text(subtitle)
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textCaption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StudentFormSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var footer: String? = nil
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
            StudentSectionHeader(title: title, subtitle: subtitle)

            SonnetCard {
                VStack(alignment: .leading, spacing: SonnetDimens.spacingL) {
                    content
                }
                .padding(SonnetDimens.cardPadding)
            }

            if let footer {
                Text(footer)
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textHint)
                    .lineSpacing(3)
            }
        }
    }
}

struct StudentFormDivider: View {
    var body: some View {
        Rectangle()
            .fill(SonnetColors.paperLine)
            .frame(height: 0.5)
    }
}

struct StudentTextEntry: View {
    let title: String
    let prompt: String
    var icon: String? = nil
    var accent: Color = SonnetColors.ink
    var axis: Axis = .horizontal
    var emphasizesValue = false
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
            HStack(spacing: SonnetDimens.spacingXS) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
            }

            TextField(prompt, text: $text, axis: axis)
                .font(emphasizesValue ? SonnetTypography.titleCard : SonnetTypography.body)
                .foregroundStyle(SonnetColors.textTitle)
                .lineLimit(axis == .vertical ? 5 : 1)
                .padding(.horizontal, 14)
                .padding(.vertical, axis == .vertical ? 14 : 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SonnetColors.paperWhite)
                .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                        .stroke(SonnetColors.paperLine, lineWidth: 0.5)
                )
        }
    }
}

struct StudentChoiceChip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool
    var tint: Color = SonnetColors.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? SonnetColors.textOnInk : SonnetColors.textBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? tint : SonnetColors.paperLight)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.08) : SonnetColors.paperLine, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
