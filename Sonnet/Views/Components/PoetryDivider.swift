import SwiftUI

/// 三行诗意分隔线
/// 85% 左对齐 / 65% 右对齐 / 75% 居中
struct PoetryDivider: View {
    var isWhite: Bool = false

    private var lineColor: Color {
        isWhite ? Color.white.opacity(0.15) : SonnetColors.paperLine
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            VStack(alignment: .leading, spacing: 4) {
                // 85% 左对齐
                lineColor
                    .frame(width: w * 0.85, height: 1)

                // 65% 右对齐
                HStack {
                    Spacer()
                    lineColor
                        .frame(width: w * 0.65, height: 1)
                }

                // 75% 居中
                HStack {
                    Spacer()
                    lineColor
                        .frame(width: w * 0.75, height: 1)
                    Spacer()
                }
            }
        }
        .frame(height: 13) // 3 × 1pt lines + 2 × 4pt gaps = 11, add 2 buffer
    }
}

#Preview {
    VStack(spacing: 24) {
        PoetryDivider()
            .padding(.horizontal)

        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(SonnetColors.ink)
            PoetryDivider(isWhite: true)
                .padding(.horizontal)
        }
        .frame(height: 60)
        .padding(.horizontal)
    }
    .padding()
    .background(SonnetColors.paper)
}
