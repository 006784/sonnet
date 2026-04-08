import SwiftUI

struct ScanResultDraft {
    var amountText: String
    var note: String
    var merchant: String
    var date: Date
    var categoryName: String
    var type: RecordType
    var confidence: Double

    var amount: Double? {
        let parsed = CurrencyUtils.parseInput(amountText)
        return parsed > 0 ? parsed : nil
    }
}

struct ScanResultCard: View {
    let onConfirm: (ScanResultDraft) -> Void
    let onRetry: () -> Void
    private let confidence: Double

    @State private var appeared = false
    @State private var amountText: String
    @State private var noteText: String
    @State private var merchantText: String
    @State private var categoryText: String
    @State private var selectedDate: Date
    @State private var selectedType: RecordType

    init(
        amount: Double?,
        note: String,
        merchant: String? = nil,
        date: Date? = nil,
        categoryName: String? = nil,
        type: RecordType = .expense,
        confidence: Double = 0,
        onConfirm: @escaping (ScanResultDraft) -> Void,
        onRetry: @escaping () -> Void
    ) {
        let normalizedAmount = amount.map {
            $0.rounded(.towardZero) == $0 ? String(Int($0)) : String(format: "%.2f", $0)
        } ?? ""
        _amountText = State(initialValue: normalizedAmount)
        _noteText = State(initialValue: note)
        _merchantText = State(initialValue: merchant ?? "")
        _categoryText = State(initialValue: categoryName ?? "")
        _selectedDate = State(initialValue: date ?? Date())
        _selectedType = State(initialValue: type)
        self.confidence = confidence
        self.onConfirm = onConfirm
        self.onRetry = onRetry
    }

    private var canConfirm: Bool {
        (ScanResultDraft(
            amountText: amountText,
            note: noteText,
            merchant: merchantText,
            date: selectedDate,
            categoryName: categoryText,
            type: selectedType,
            confidence: confidence
        ).amount ?? 0) > 0
    }

    var body: some View {
        SonnetCard {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingL) {
                HStack(spacing: SonnetDimens.spacingXS) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                    Text(confidence > 0 && confidence < 0.7 ? "请确认识别结果" : "识别结果待确认")
                        .font(SonnetTypography.caption1)
                        .fontWeight(.medium)
                }
                .foregroundStyle(confidence > 0 && confidence < 0.7 ? SonnetColors.amber : SonnetColors.ink)
                .padding(.horizontal, SonnetDimens.spacingM)
                .padding(.vertical, SonnetDimens.spacingXS)
                .background(confidence > 0 && confidence < 0.7 ? SonnetColors.amberLight : SonnetColors.inkWash)
                .clipShape(Capsule())

                VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                    Text("金额")
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("¥")
                            .font(SonnetTypography.titleSection)
                            .foregroundStyle(SonnetColors.textCaption)
                        TextField("0.00", text: $amountText)
                            .font(SonnetTypography.amountLarge)
                            .monospacedDigit()
                            .foregroundStyle(amountText.isEmpty ? SonnetColors.textHint : SonnetColors.vermilion)
                            .keyboardType(.decimalPad)
                    }
                }

                VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
                    Picker("类型", selection: $selectedType) {
                        ForEach(RecordType.allCases, id: \.rawValue) { recordType in
                            Text(recordType.label).tag(recordType)
                        }
                    }
                    .pickerStyle(.segmented)

                    SonnetTextField(placeholder: "备注", text: $noteText, icon: "doc.text")
                    SonnetTextField(placeholder: "商家", text: $merchantText, icon: "storefront")
                    SonnetTextField(placeholder: "分类", text: $categoryText, icon: "tag")

                    HStack {
                        Label("日期", systemImage: "calendar")
                            .font(SonnetTypography.body)
                            .foregroundStyle(SonnetColors.textTitle)
                        Spacer()
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(SonnetColors.ink)
                    }
                    .padding(.horizontal, SonnetDimens.cardPadding)
                    .padding(.vertical, 14)
                    .background(SonnetColors.paperLight)
                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium))
                }

                HStack(spacing: SonnetDimens.spacingM) {
                    InkButton(title: "重试", action: onRetry, style: .ghost)
                    InkButton(title: "确认记账", action: confirm, style: .primary)
                        .disabled(!canConfirm)
                        .opacity(canConfirm ? 1 : 0.5)
                }
            }
            .padding(SonnetDimens.spacingL)
        }
        .offset(y: appeared ? 0 : 60)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(SonnetMotion.spring) { appeared = true }
        }
    }

    private func confirm() {
        onConfirm(
            ScanResultDraft(
                amountText: amountText,
                note: noteText,
                merchant: merchantText,
                date: selectedDate,
                categoryName: categoryText,
                type: selectedType,
                confidence: confidence
            )
        )
    }
}
