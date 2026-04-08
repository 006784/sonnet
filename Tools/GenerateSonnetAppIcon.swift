import SwiftUI
import AppKit

enum IconVariant: Equatable {
    case light
    case dark
    case tinted
}

struct SonnetIconArtwork: View {
    let variant: IconVariant

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let rect = CGRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            )
            let background = Path(
                roundedRect: rect,
                cornerRadius: side * 0.23,
                style: .continuous
            )

            if variant == .light {
                ctx.fill(
                    background,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 66 / 255, green: 80 / 255, blue: 143 / 255),
                            Color(red: 94 / 255, green: 108 / 255, blue: 178 / 255),
                            Color(red: 121 / 255, green: 134 / 255, blue: 200 / 255),
                        ]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    )
                )
            }

            if variant == .light {
                let glowPath = Path(ellipseIn: CGRect(
                    x: rect.minX - side * 0.06,
                    y: rect.minY - side * 0.08,
                    width: side * 0.60,
                    height: side * 0.44
                ))
                ctx.fill(glowPath, with: .color(.white.opacity(0.10)))

                ctx.stroke(
                    background,
                    with: .color(.white.opacity(0.12)),
                    style: StrokeStyle(lineWidth: side * 0.014)
                )
            }

            let work = rect.insetBy(dx: side * 0.20, dy: side * 0.16)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: work.minX + x * work.width, y: work.minY + y * work.height)
            }

            let spineColor: Color
            let strokeColor: Color
            let foldColor: Color

            switch variant {
            case .light:
                spineColor = .white.opacity(0.96)
                strokeColor = .white
                foldColor = .white.opacity(0.96)
            case .dark:
                spineColor = .white.opacity(0.94)
                strokeColor = .white
                foldColor = .white.opacity(0.72)
            case .tinted:
                spineColor = Color(.sRGB, white: 0.92, opacity: 1)
                strokeColor = Color(.sRGB, white: 1.0, opacity: 1)
                foldColor = Color(.sRGB, white: 0.68, opacity: 1)
            }

            var spinePath = Path()
            spinePath.move(to: point(0.40, 0.14))
            spinePath.addCurve(
                to: point(0.35, 0.88),
                control1: point(0.37, 0.32),
                control2: point(0.31, 0.68)
            )
            ctx.stroke(
                spinePath,
                with: .color(spineColor),
                style: StrokeStyle(lineWidth: side * 0.05, lineCap: .round, lineJoin: .round)
            )

            var sPath = Path()
            sPath.move(to: point(0.72, 0.10))
            sPath.addCurve(
                to: point(0.30, 0.34),
                control1: point(0.64, 0.05),
                control2: point(0.39, 0.11)
            )
            sPath.addCurve(
                to: point(0.57, 0.54),
                control1: point(0.21, 0.46),
                control2: point(0.46, 0.43)
            )
            sPath.addCurve(
                to: point(0.73, 0.78),
                control1: point(0.69, 0.64),
                control2: point(0.78, 0.69)
            )
            sPath.addCurve(
                to: point(0.35, 0.92),
                control1: point(0.67, 0.90),
                control2: point(0.45, 0.97)
            )
            ctx.stroke(
                sPath,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: side * 0.11, lineCap: .round, lineJoin: .round)
            )

            var foldPath = Path()
            foldPath.move(to: point(0.66, 0.10))
            foldPath.addLine(to: point(0.83, 0.24))
            ctx.stroke(
                foldPath,
                with: .color(foldColor),
                style: StrokeStyle(lineWidth: side * 0.038, lineCap: .round)
            )
        }
    }
}

@MainActor
func renderPNG(size: CGFloat, variant: IconVariant, to path: String) throws {
    let content = SonnetIconArtwork(variant: variant)
        .frame(width: size, height: size)

    let renderer = ImageRenderer(content: content)
    renderer.scale = 1
    renderer.proposedSize = ProposedViewSize(width: size, height: size)

    guard let cgImage = renderer.cgImage else {
        throw NSError(domain: "GenerateSonnetAppIcon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Failed to render icon artwork."
        ])
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateSonnetAppIcon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Failed to encode icon PNG."
        ])
    }

    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

@main
struct GenerateSonnetAppIcon {
    @MainActor
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let targets: [(CGFloat, IconVariant, String)] = [
            (1024, .light, "Sonnet/Assets.xcassets/AppIcon.appiconset/icon_1024.png"),
            (1024, .dark, "Sonnet/Assets.xcassets/AppIcon.appiconset/icon_dark.png"),
            (1024, .tinted, "Sonnet/Assets.xcassets/AppIcon.appiconset/icon_tinted.png"),
            (180, .light, "Sonnet/Assets.xcassets/AppIconImage.imageset/icon_display.png"),
        ]

        for (size, variant, relativePath) in targets {
            let outputURL = root.appendingPathComponent(relativePath)
            try renderPNG(size: size, variant: variant, to: outputURL.path)
            print("generated \(outputURL.path)")
        }
    }
}
