import SwiftUI

struct NumberKeyboard: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    private let rows: [[String]] = [
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                    if row == rows.last {
                        doneButton
                    }
                }
            }
        }
        .padding(SonnetDimens.spacingM)
        .background(SonnetColors.paperCream)
    }

    private func keyButton(_ key: String) -> some View {
        KeyButton(label: {
            if key == "⌫" {
                Image(systemName: "delete.backward")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(SonnetColors.vermilion)
            } else {
                Text(key)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(SonnetColors.textTitle)
            }
        }, action: {
            HapticManager.impact(.light)
            if key == "⌫" { onDelete() } else { onDigit(key) }
        })
    }

    private var doneButton: some View {
        KeyButton(label: {
            Text("完成")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SonnetColors.textOnInk)
        }, action: {
            HapticManager.impact(.medium)
            onDone()
        }, background: AnyView(
            LinearGradient(
                colors: [SonnetColors.ink, SonnetColors.inkLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ))
    }
}

private struct KeyButton<Label: View>: View {
    let label: Label
    let action: () -> Void
    var background: AnyView = AnyView(SonnetColors.paperWhite)

    @State private var isPressed = false

    init(
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void,
        background: AnyView = AnyView(SonnetColors.paperWhite)
    ) {
        self.label = label()
        self.action = action
        self.background = background
    }

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium))
        }
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(
            Animation.spring(response: 0.2, dampingFraction: 0.65),
            value: isPressed
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}

#Preview {
    NumberKeyboard(onDigit: { _ in }, onDelete: {}, onDone: {})
}
