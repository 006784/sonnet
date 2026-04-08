import SwiftUI

enum SonnetTypography {
    static let titlePage = Font.system(size: 20, weight: .semibold, design: .serif)
    static let titleSection = Font.system(size: 16, weight: .semibold, design: .default)
    static let titleCard = Font.system(size: 15, weight: .medium, design: .default)

    static let amountHero = Font.system(size: 36, weight: .semibold, design: .rounded)
    static let amountLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let amountBody = Font.system(size: 15, weight: .medium, design: .rounded)
    static let amountMedium = amountLarge
    static let amountSmall = amountBody

    static let body = Font.system(size: 14, weight: .regular, design: .default)
    static let bodyBold = Font.system(size: 14, weight: .semibold, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let callout = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    static let label = Font.system(size: 10, weight: .medium, design: .default)

    // MARK: - Backward compatibility aliases

    static let largeTitle = Font.system(size: 30, weight: .semibold, design: .serif)
    static let title1 = Font.system(size: 28, weight: .semibold, design: .serif)
    static let title2 = titlePage
    static let title3 = titleSection
}
