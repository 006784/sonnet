import SwiftUI

struct EmptyStateView: View {
    var icon: String? = nil
    var title: String = "暂无数据"
    var subtitle: String = ""

    @State private var appeared = false

    var body: some View {
        VStack(spacing: SonnetDimens.spacingL) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(SonnetColors.ink.opacity(0.45))
                    .frame(width: 52, height: 52)
            } else {
                PenTipIcon()
                    .frame(width: 52, height: 52)
            }

            VStack(spacing: SonnetDimens.spacingS) {
                Text(title)
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textSecond)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textHint)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(SonnetMotion.spring) {
                appeared = true
            }
        }
    }
}

/// 极简钢笔尖——三条 Path 线
private struct PenTipIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let color = GraphicsContext.Shading.color(SonnetColors.ink.opacity(0.3))
            let style = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

            // 主轴：左上 → 右下
            var shaft = Path()
            shaft.move(to: CGPoint(x: w * 0.18, y: h * 0.18))
            shaft.addLine(to: CGPoint(x: w * 0.82, y: h * 0.82))
            ctx.stroke(shaft, with: color, style: style)

            // 笔尖左侧
            var nibLeft = Path()
            nibLeft.move(to: CGPoint(x: w * 0.82, y: h * 0.82))
            nibLeft.addLine(to: CGPoint(x: w * 0.48, y: h * 0.66))
            ctx.stroke(nibLeft, with: color, style: style)

            // 笔尖右侧
            var nibRight = Path()
            nibRight.move(to: CGPoint(x: w * 0.82, y: h * 0.82))
            nibRight.addLine(to: CGPoint(x: w * 0.66, y: h * 0.48))
            ctx.stroke(nibRight, with: color, style: style)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        EmptyStateView(
            title: "故事从第一笔开始",
            subtitle: "点击 + 记录你的第一笔"
        )
        EmptyStateView()
    }
    .background(SonnetColors.paper)
}
