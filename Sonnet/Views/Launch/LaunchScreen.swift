import SwiftUI

struct SplashView: View {
    @Binding var showMainApp: Bool

    @State private var splashScale: CGFloat = 0.8
    @State private var splashOpacity: Double = 0
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            SonnetColors.paper.ignoresSafeArea()
            Circle()
                .fill(SonnetColors.inkWash.opacity(0.75))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .offset(x: -70, y: -120)

            Circle()
                .fill(SonnetColors.paperWhite.opacity(0.95))
                .frame(width: 180, height: 180)
                .blur(radius: 12)
                .offset(x: 90, y: -170)

            VStack(spacing: 10) {
                AppIconSymbol()
                    .frame(width: 60, height: 60)
                    .scaleEffect(splashScale)
                    .opacity(splashOpacity)

                Text("十四行诗")
                    .font(SonnetTypography.titlePage)
                    .foregroundStyle(SonnetColors.ink)
                    .opacity(titleOpacity)

                Text("让每一笔记录，都像被认真写下的一行诗")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
                    .opacity(titleOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                splashScale = 1.0
                splashOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                titleOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(SonnetMotion.easeInOut) {
                    showMainApp = true
                }
            }
        }
    }
}

// MARK: - App icon symbol (canvas-drawn feather pen, used in splash & settings)

struct AppIconSymbol: View {
    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let rect = CGRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            )
            let bgPath = Path(
                roundedRect: rect,
                cornerRadius: side * 0.23,
                style: .continuous
            )

            ctx.fill(
                bgPath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: 0xFF42508F),
                        Color(hex: 0xFF5E6CB2),
                        Color(hex: 0xFF7986C8),
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )

            let glowPath = Path(ellipseIn: CGRect(
                x: rect.minX - side * 0.06,
                y: rect.minY - side * 0.08,
                width: side * 0.60,
                height: side * 0.44
            ))
            ctx.fill(glowPath, with: .color(.white.opacity(0.10)))

            ctx.stroke(
                bgPath,
                with: .color(.white.opacity(0.12)),
                style: StrokeStyle(lineWidth: side * 0.014)
            )

            let work = rect.insetBy(dx: side * 0.20, dy: side * 0.16)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: work.minX + x * work.width, y: work.minY + y * work.height)
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
                with: .color(.white.opacity(0.96)),
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
                with: .color(.white),
                style: StrokeStyle(lineWidth: side * 0.11, lineCap: .round, lineJoin: .round)
            )

            var foldPath = Path()
            foldPath.move(to: point(0.66, 0.10))
            foldPath.addLine(to: point(0.83, 0.24))
            ctx.stroke(
                foldPath,
                with: .color(.white.opacity(0.96)),
                style: StrokeStyle(lineWidth: side * 0.038, lineCap: .round)
            )
        }
    }
}
