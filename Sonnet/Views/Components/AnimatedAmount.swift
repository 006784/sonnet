import SwiftUI

struct AnimatedAmount: View {
    let amount: Double
    var font: Font = SonnetTypography.amountMedium
    var color: Color = SonnetColors.textTitle
    var showSign: Bool = false

    @State private var displayAmount: Double = 0

    var body: some View {
        Text(CurrencyUtils.format(displayAmount, showSign: showSign))
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(SonnetMotion.spring) {
                    displayAmount = amount
                }
            }
            .onChange(of: amount) { _, newValue in
                withAnimation(SonnetMotion.spring) {
                    displayAmount = newValue
                }
            }
    }
}
