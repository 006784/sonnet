import SwiftUI
import UIKit

enum SonnetColors {

    // MARK: - Ink + Paper

    static let ink = dynamic(light: 0xFF4A5699, dark: Dark.inkHex)
    static let inkLight = dynamic(light: 0xFF6B78C4, dark: Dark.inkLightHex)
    static let inkPale = Color(hex: 0xFF8E98D8)
    static let inkWash = dynamic(light: 0xFFF0F1F8, dark: Dark.inkWashHex)
    static let inkSurface = dynamic(light: 0xFFE8EAF4, dark: Dark.inkWashHex)

    static let paper = dynamic(light: 0xFFF8F6F1, dark: Dark.paperHex)
    static let paperWhite = dynamic(light: 0xFFFFFFFF, dark: Dark.paperSurfaceHex)
    static let paperLight = dynamic(light: 0xFFF2F0EB, dark: Dark.paperLightHex)
    static let paperLine = dynamic(light: 0xFFE8E5DF, dark: Dark.paperLineHex)

    static let vermilion = dynamic(light: 0xFFD4574E, dark: Dark.vermilionHex)
    static let vermilionLight = dynamic(light: 0xFFFFF0EE, dark: 0xFF3B2423)
    static let jade = dynamic(light: 0xFF3D9B72, dark: Dark.jadeHex)
    static let jadeLight = dynamic(light: 0xFFEDF7F1, dark: 0xFF20332B)
    static let amber = dynamic(light: 0xFFCB8A34, dark: Dark.amberHex)
    static let amberLight = dynamic(light: 0xFFFFF8EC, dark: 0xFF382D1E)

    static let textTitle = dynamic(light: 0xFF1A1917, dark: Dark.textTitleHex)
    static let textBody = dynamic(light: 0xFF3D3C38, dark: Dark.textBodyHex)
    static let textCaption = dynamic(light: 0xFF8E8D88, dark: Dark.textCaptionHex)
    static let textHint = dynamic(light: 0xFFB5B4AF, dark: Dark.textHintHex)
    static let textOnInk = Color.white

    // MARK: - Backward compatibility aliases

    static let inkMist = inkSurface
    static let paperCream = paperLight
    static let paperKey = paperLight
    static let textSecond = textCaption

    enum Category {
        static let foodIcon = Color(hex: 0xFFD4734B)
        static let foodBg = Color(hex: 0xFFFFF3EC)
        static let transportIcon = Color(hex: 0xFF4A8BBF)
        static let transportBg = Color(hex: 0xFFECF3FC)
        static let shoppingIcon = Color(hex: 0xFF8B6AAD)
        static let shoppingBg = Color(hex: 0xFFF3EDFA)
        static let dailyIcon = Color(hex: 0xFF5A9E7E)
        static let dailyBg = Color(hex: 0xFFEDF6F1)
        static let entertainIcon = Color(hex: 0xFFCB5B7B)
        static let entertainBg = Color(hex: 0xFFFCEDF1)
        static let medicalIcon = Color(hex: 0xFF4A9E9E)
        static let medicalBg = Color(hex: 0xFFE8F5F5)
        static let educationIcon = Color(hex: 0xFF5E80AD)
        static let educationBg = Color(hex: 0xFFEDF1F8)
        static let commIcon = Color(hex: 0xFFA68745)
        static let commBg = Color(hex: 0xFFF8F3E6)
        static let salaryIcon = Color(hex: 0xFF3D9B72)
        static let salaryBg = Color(hex: 0xFFEDF7F1)
        static let partTimeIcon = Color(hex: 0xFF6B78C4)
        static let partTimeBg = Color(hex: 0xFFEEF0F9)
        static let investIcon = Color(hex: 0xFFCB8A34)
        static let investBg = Color(hex: 0xFFFFF8EC)
        static let giftIcon = Color(hex: 0xFFD4574E)
        static let giftBg = Color(hex: 0xFFFFF0EE)
        static let otherIcon = Color(hex: 0xFF8E8D88)
        static let otherBg = Color(hex: 0xFFF2F0EB)

        static let canteenIcon = Color(hex: 0xFFE07C4A)
        static let canteenBg = Color(hex: 0xFFFFF3EC)
        static let bobaIcon = Color(hex: 0xFFC4785B)
        static let bobaBg = Color(hex: 0xFFFBF0EA)
        static let stationeryIcon = Color(hex: 0xFF6B8FC4)
        static let stationeryBg = Color(hex: 0xFFEEF4FB)
        static let printingIcon = Color(hex: 0xFF7A7974)
        static let printingBg = Color(hex: 0xFFF2F0EB)
        static let clubIcon = Color(hex: 0xFF8B6AAD)
        static let clubBg = Color(hex: 0xFFF3EDFA)
    }

    enum Dark {
        fileprivate static let paperHex: UInt = 0xFF1A1917
        fileprivate static let paperSurfaceHex: UInt = 0xFF262520
        fileprivate static let paperLightHex: UInt = 0xFF302F2B
        fileprivate static let paperLineHex: UInt = 0xFF3D3C38
        fileprivate static let inkHex: UInt = 0xFF8E98D8
        fileprivate static let inkLightHex: UInt = 0xFFA8B0E2
        fileprivate static let inkWashHex: UInt = 0xFF2A2D3E
        fileprivate static let vermilionHex: UInt = 0xFFE87B72
        fileprivate static let jadeHex: UInt = 0xFF5EC98E
        fileprivate static let amberHex: UInt = 0xFFE0A855
        fileprivate static let textTitleHex: UInt = 0xFFF2F0EB
        fileprivate static let textBodyHex: UInt = 0xFFCCCAC4
        fileprivate static let textCaptionHex: UInt = 0xFF7A7974
        fileprivate static let textHintHex: UInt = 0xFF4A4944

        static let paper = Color(hex: paperHex)
        static let paperSurface = Color(hex: paperSurfaceHex)
        static let paperLight = Color(hex: paperLightHex)
        static let paperLine = Color(hex: paperLineHex)
        static let ink = Color(hex: inkHex)
        static let inkLight = Color(hex: inkLightHex)
        static let inkWash = Color(hex: inkWashHex)
        static let vermilion = Color(hex: vermilionHex)
        static let jade = Color(hex: jadeHex)
        static let amber = Color(hex: amberHex)
        static let textTitle = Color(hex: textTitleHex)
        static let textBody = Color(hex: textBodyHex)
        static let textCaption = Color(hex: textCaptionHex)
        static let textHint = Color(hex: textHintHex)
    }

    static func categoryColors(for colorName: String) -> (icon: Color, bg: Color) {
        switch colorName {
        case "food":
            return (Category.foodIcon, dynamic(light: 0xFFFFF3EC, dark: 0xFF32221D))
        case "transport":
            return (Category.transportIcon, dynamic(light: 0xFFECF3FC, dark: 0xFF1F2833))
        case "shopping":
            return (Category.shoppingIcon, dynamic(light: 0xFFF3EDFA, dark: 0xFF292231))
        case "daily":
            return (Category.dailyIcon, dynamic(light: 0xFFEDF6F1, dark: 0xFF1E2A24))
        case "entertain":
            return (Category.entertainIcon, dynamic(light: 0xFFFCEDF1, dark: 0xFF34232A))
        case "medical":
            return (Category.medicalIcon, dynamic(light: 0xFFE8F5F5, dark: 0xFF1E2C2D))
        case "education":
            return (Category.educationIcon, dynamic(light: 0xFFEDF1F8, dark: 0xFF202833))
        case "comm":
            return (Category.commIcon, dynamic(light: 0xFFF8F3E6, dark: 0xFF322C20))
        case "salary":
            return (Category.salaryIcon, dynamic(light: 0xFFEDF7F1, dark: 0xFF1F2D25))
        case "parttime", "partTime":
            return (Category.partTimeIcon, dynamic(light: 0xFFEEF0F9, dark: 0xFF242A35))
        case "invest":
            return (Category.investIcon, dynamic(light: 0xFFFFF8EC, dark: 0xFF352E22))
        case "gift":
            return (Category.giftIcon, dynamic(light: 0xFFFFF0EE, dark: 0xFF372624))
        case "canteen":
            return (Category.canteenIcon, dynamic(light: 0xFFFFF3EC, dark: 0xFF35231E))
        case "boba":
            return (Category.bobaIcon, dynamic(light: 0xFFFBF0EA, dark: 0xFF34251F))
        case "stationery":
            return (Category.stationeryIcon, dynamic(light: 0xFFEEF4FB, dark: 0xFF232B34))
        case "printing":
            return (Category.printingIcon, dynamic(light: 0xFFF2F0EB, dark: 0xFF2B2925))
        case "club":
            return (Category.clubIcon, dynamic(light: 0xFFF3EDFA, dark: 0xFF2B2433))
        default:
            return (Category.otherIcon, dynamic(light: 0xFFF2F0EB, dark: 0xFF2B2925))
        }
    }

    static func categoryColors(_ colorName: String) -> (icon: Color, bg: Color) {
        categoryColors(for: colorName)
    }

    private static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(hex: dark)
                    : UIColor(hex: light)
            }
        )
    }
}

extension Color {
    init(hex: UInt) {
        let argb = hex > 0xFFFFFF
        let alpha = argb ? Double((hex >> 24) & 0xFF) / 255 : 1
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        let argb = hex > 0xFFFFFF
        let alpha = argb ? CGFloat((hex >> 24) & 0xFF) / 255 : 1
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
