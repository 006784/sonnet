import SwiftUI

struct DonutChart: View {
    let summaries: [CategorySummary]
    var typeLabel: String = "总支出"

    @State private var progress: CGFloat = 0
    @State private var selectedIndex: Int? = nil

    private let outerR: CGFloat = 90
    private let lineW: CGFloat = 28
    private var innerR: CGFloat { outerR - lineW }
    private let gapDeg: Double = 2.0

    private var total: Double { summaries.reduce(0) { $0 + $1.totalAmount } }

    private struct SectorData {
        let start: Double
        let sweep: Double
        var mid: Double { start + sweep / 2 }
        var end: Double { start + sweep }
    }

    private var sectors: [SectorData] {
        guard !summaries.isEmpty else { return [] }
        let totalGap = gapDeg * Double(summaries.count)
        let available = 360.0 - totalGap
        var result: [SectorData] = []
        var cursor = -90.0
        for s in summaries {
            let sw = s.percentage * available
            result.append(SectorData(start: cursor, sweep: sw))
            cursor += sw + gapDeg
        }
        return result
    }

    var body: some View {
        ZStack {
            if summaries.isEmpty {
                emptyRing
            } else {
                donutCanvas
                centerLabel
            }
        }
        .frame(width: 180, height: 180)
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 1.0)) { progress = 1.0 }
        }
        .onChange(of: summaries.map { $0.category.id }) { _, _ in
            selectedIndex = nil
            progress = 0
            withAnimation(.easeOut(duration: 1.0)) { progress = 1.0 }
        }
    }

    // MARK: – Sub-views

    private var emptyRing: some View {
        ZStack {
            Circle()
                .strokeBorder(SonnetColors.paperLine, lineWidth: lineW)
                .frame(width: outerR * 2, height: outerR * 2)
            VStack(spacing: 2) {
                Text("¥0.00")
                    .font(SonnetTypography.amountSmall)
                    .foregroundStyle(SonnetColors.textHint)
                Text(typeLabel)
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
            }
        }
    }

    private var donutCanvas: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for (idx, sector) in sectors.enumerated() {
                let animSweep = sector.sweep * Double(progress)
                guard animSweep > 0.01 else { continue }

                // Radial pop for selected sector
                let pop: CGFloat = (selectedIndex == idx) ? 6 : 0
                let midRad = sector.mid * .pi / 180
                let arcCenter = CGPoint(
                    x: center.x + cos(midRad) * pop,
                    y: center.y + sin(midRad) * pop
                )

                var path = Path()
                path.addArc(center: arcCenter, radius: outerR,
                            startAngle: .degrees(sector.start),
                            endAngle: .degrees(sector.start + animSweep),
                            clockwise: false)
                path.addArc(center: arcCenter, radius: innerR,
                            startAngle: .degrees(sector.start + animSweep),
                            endAngle: .degrees(sector.start),
                            clockwise: true)
                path.closeSubpath()

                let color = SonnetColors.categoryColors(summaries[idx].category.colorName).icon
                ctx.fill(path, with: .color(color))
            }
        }
        .frame(width: 180, height: 180)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    handleTap(at: value.location)
                }
        )
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            if let idx = selectedIndex, idx < summaries.count {
                Text(summaries[idx].category.name)
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
                Text("¥\(CurrencyUtils.format(summaries[idx].totalAmount))")
                    .font(SonnetTypography.amountSmall)
                    .foregroundStyle(SonnetColors.textTitle)
            } else {
                Text(typeLabel)
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
                Text("¥\(CurrencyUtils.format(total))")
                    .font(SonnetTypography.amountSmall)
                    .foregroundStyle(SonnetColors.textTitle)
            }
        }
        .multilineTextAlignment(.center)
        .frame(width: outerR * 2 - lineW * 2 - 4)
        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        .allowsHitTesting(false)
    }

    // MARK: – Hit testing

    private func handleTap(at location: CGPoint) {
        let center = CGPoint(x: 90, y: 90)
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        let dist = sqrt(dx * dx + dy * dy)

        guard dist >= Double(innerR) - 6, dist <= Double(outerR) + 8 else {
            withAnimation(SonnetMotion.spring) { selectedIndex = nil }
            return
        }

        // Normalize angle to [-90, 270] to match sector start angles
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < -90 { angle += 360 }

        for (idx, sector) in sectors.enumerated() {
            if angle >= sector.start && angle <= sector.end {
                withAnimation(SonnetMotion.spring) {
                    selectedIndex = selectedIndex == idx ? nil : idx
                }
                return
            }
        }
        withAnimation(SonnetMotion.spring) { selectedIndex = nil }
    }
}

// MARK: – Preview

#Preview {
    let cat1 = Category(name: "餐饮", icon: "fork.knife", type: 0, sortOrder: 0, colorName: "food")
    let cat2 = Category(name: "交通", icon: "car.fill", type: 0, sortOrder: 1, colorName: "transport")
    let cat3 = Category(name: "购物", icon: "bag.fill", type: 0, sortOrder: 2, colorName: "shopping")

    let summaries = [
        CategorySummary(category: cat1, totalAmount: 1200, percentage: 0.5, count: 10),
        CategorySummary(category: cat2, totalAmount: 600, percentage: 0.25, count: 5),
        CategorySummary(category: cat3, totalAmount: 600, percentage: 0.25, count: 4)
    ]

    VStack(spacing: 32) {
        DonutChart(summaries: summaries, typeLabel: "总支出")
        DonutChart(summaries: [], typeLabel: "总支出")
    }
    .padding()
    .background(SonnetColors.paper)
}
