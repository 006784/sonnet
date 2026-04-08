import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingRecord: Record? = nil
    var prefillDraft: QuickRecordDraft? = nil

    @State private var viewModel = RecordViewModel()
    @State private var showSuccess = false
    @State private var didLoadInitialData = false
    @Namespace private var typeNS

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // ── 拖动把手 ──
                    Capsule()
                        .fill(SonnetColors.paperLine)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // ── 自定义收支切换 ──
                    typeSegmented
                        .padding(.horizontal, SonnetDimens.spacingXL)
                        .padding(.vertical, SonnetDimens.spacingM)

                    // ── 金额区 ──
                    amountSection
                        .padding(.vertical, SonnetDimens.spacingXL)

                    // ── 分类网格 ──
                    CategoryGrid(
                        type: viewModel.selectedType,
                        selected: $viewModel.selectedCategory
                    )
                    .padding(.bottom, SonnetDimens.spacingM)

                    // ── 备注 + 日期 ──
                    SonnetTextField(
                        placeholder: "备注（选填）",
                        text: $viewModel.note,
                        icon: "text.bubble"
                    )
                    .padding(.horizontal, SonnetDimens.pageHorizontal)
                    .padding(.bottom, SonnetDimens.spacingS)

                    dateSection
                        .padding(.horizontal, SonnetDimens.pageHorizontal)
                        .padding(.bottom, SonnetDimens.spacingM)

                    Spacer(minLength: SonnetDimens.spacingM)

                    // ── 数字键盘 ──
                    NumberKeyboard(
                        onDigit:  viewModel.appendDigit,
                        onDelete: viewModel.deleteDigit,
                        onDone:   saveRecord
                    )
                }
                .background(SonnetColors.paper)

                // ── 保存成功动画 ──
                if showSuccess {
                    successOverlay
                }
            }
            .navigationTitle(editingRecord == nil ? "记一笔" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            guard !didLoadInitialData else { return }
            didLoadInitialData = true
            if let rec = editingRecord {
                viewModel.loadForEditing(rec)
            } else if let draft = prefillDraft {
                viewModel.loadDraft(draft, context: modelContext)
            }
        }
    }

    // ── 自定义 Segmented ──
    private var typeSegmented: some View {
        HStack(spacing: 0) {
            ForEach(RecordType.allCases, id: \.rawValue) { type in
                Button {
                    withAnimation(SonnetMotion.springFast) {
                        viewModel.selectedType = type
                    }
                } label: {
                    Text(type.label)
                        .font(.system(size: 14, weight: viewModel.selectedType == type ? .semibold : .regular))
                        .foregroundStyle(
                            viewModel.selectedType == type
                                ? SonnetColors.textOnInk
                                : SonnetColors.textSecond
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Group {
                                if viewModel.selectedType == type {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(SonnetColors.ink)
                                        .matchedGeometryEffect(id: "typePill", in: typeNS)
                                }
                            }
                        )
                }
            }
        }
        .frame(width: 200, height: 40)
        .background(SonnetColors.inkWash)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // ── 金额区 ──
    private var amountSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("¥")
                .font(SonnetTypography.titleSection)
                .foregroundStyle(
                    viewModel.amountInput == "0"
                        ? SonnetColors.textHint
                        : SonnetColors.textCaption
                )

            Text(viewModel.amountInput)
                .font(SonnetTypography.amountHero)
                .monospacedDigit()
                .tracking(-1.5)
                .foregroundStyle(
                    viewModel.amountInput == "0"
                        ? SonnetColors.textHint
                        : SonnetColors.textTitle
                )
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(SonnetMotion.spring, value: viewModel.amountInput)
    }

    private var dateSection: some View {
        SonnetCard {
            DatePicker(
                "记账时间",
                selection: $viewModel.date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .font(SonnetTypography.body)
            .foregroundStyle(SonnetColors.textTitle)
            .padding(.horizontal, SonnetDimens.cardPadding)
            .padding(.vertical, 14)
        }
    }

    // ── 保存成功遮罩 ──
    private var successOverlay: some View {
        ZStack {
            Color(SonnetColors.paper).opacity(0.85)
                .ignoresSafeArea()

            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(SonnetColors.jade)
                .scaleEffect(showSuccess ? 1 : 0)
                .animation(
                    Animation.spring(response: 0.4, dampingFraction: 0.55),
                    value: showSuccess
                )
        }
        .transition(.opacity)
    }

    // ── 保存逻辑 ──
    private func saveRecord() {
        let desc = FetchDescriptor<AccountBook>(predicate: #Predicate { $0.isSelected })
        let book = try? modelContext.fetch(desc).first
        let didSave = viewModel.save(context: modelContext, accountBook: book)

        if didSave {
            HapticManager.success()
            NotificationCenter.default.post(name: .sonnetRecordChanged, object: nil)
            withAnimation(SonnetMotion.spring) { showSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                dismiss()
            }
        } else {
            HapticManager.warning()
        }
    }
}

#Preview {
    RecordView()
        .modelContainer(for: [Record.self, Category.self, AccountBook.self], inMemory: true)
}
