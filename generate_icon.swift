#!/usr/bin/env swift
// Generates AppIcon 1024x1024 PNG and a 60pt display version
// Run: swift generate_icon.swift

import CoreGraphics
import ImageIO
import Foundation

func makeIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size, height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let r = s * 0.22  // corner radius

    // ── Background gradient: ink (#4A5699) → inkLight (#6B78C4), 135°
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Approximate gradient with two-stop linear fill
    let colors: [CGFloat] = [
        0x4A/255.0, 0x56/255.0, 0x99/255.0, 1,   // ink
        0x6B/255.0, 0x78/255.0, 0xC4/255.0, 1    // inkLight
    ]
    let locs: [CGFloat] = [0, 1]
    guard let gradient = CGGradient(
        colorSpace: colorSpace,
        colorComponents: colors,
        locations: locs,
        count: 2
    ) else { return nil }

    // 135° = top-left → bottom-right
    let start = CGPoint(x: 0, y: 0)
    let end   = CGPoint(x: s, y: s)
    ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    ctx.resetClip()

    // ── White feather pen path (scaled to icon size)
    let cx = s / 2
    let cy = s / 2

    // Scale factor vs reference 1024
    let f = s / 1024.0

    // Feather body
    var path = CGMutablePath()
    let tipX = cx
    let tipY = cy + 290 * f

    path.move(to: CGPoint(x: tipX, y: tipY))
    path.addCurve(
        to: CGPoint(x: cx + 220 * f, y: cy - 280 * f),
        control1: CGPoint(x: cx + 180 * f, y: cy + 120 * f),
        control2: CGPoint(x: cx + 280 * f, y: cy - 100 * f)
    )
    path.addCurve(
        to: CGPoint(x: cx - 220 * f, y: cy - 200 * f),
        control1: CGPoint(x: cx + 80 * f, y: cy - 380 * f),
        control2: CGPoint(x: cx - 100 * f, y: cy - 380 * f)
    )
    path.addCurve(
        to: CGPoint(x: tipX, y: tipY),
        control1: CGPoint(x: cx - 200 * f, y: cy - 50 * f),
        control2: CGPoint(x: cx - 80 * f, y: cy + 180 * f)
    )
    path.closeSubpath()

    ctx.addPath(path)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))
    ctx.fillPath()

    // Center quill line
    var quill = CGMutablePath()
    quill.move(to: CGPoint(x: tipX, y: tipY))
    quill.addLine(to: CGPoint(x: cx, y: cy - 300 * f))
    ctx.addPath(quill)
    ctx.setStrokeColor(CGColor(red: 0x4A/255.0, green: 0x56/255.0, blue: 0x99/255.0, alpha: 0.35))
    ctx.setLineWidth(2 * f)
    ctx.setLineCap(.round)
    ctx.strokePath()

    // Ink drop near nib tip
    let dotR = 28 * f
    let dotCx = tipX - 40 * f
    let dotCy = tipY - 60 * f
    ctx.addEllipse(in: CGRect(x: dotCx - dotR, y: dotCy - dotR, width: dotR*2, height: dotR*2))
    ctx.setFillColor(CGColor(red: 0x6B/255.0, green: 0x78/255.0, blue: 0xC4/255.0, alpha: 1))
    ctx.fillPath()

    return ctx.makeImage()
}

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("❌ Cannot create destination for \(path)"); return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("✅ Saved: \(path)")
}

// Generate 1024x1024 app icon
if let icon1024 = makeIcon(size: 1024) {
    savePNG(icon1024, to: "Sonnet/Assets.xcassets/AppIcon.appiconset/icon_1024.png")
}

// Generate 60pt @3x (180px) display image
if let icon180 = makeIcon(size: 180) {
    savePNG(icon180, to: "Sonnet/Assets.xcassets/AppIconImage.imageset/icon_display.png")
}

print("Done.")
