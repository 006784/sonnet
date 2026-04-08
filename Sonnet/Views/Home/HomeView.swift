import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @State private var fabExpanded = false
    @State private var shortcutDraft: QuickRecordDraft?
    @State private var showingScan = false
    @State private var showingVoice = false

    @Query(filter: #Predicate<AccountBook> { $0.isSelected })
    private var selectedBooks: [AccountBook]
    private var selectedBook: AccountBook? { selectedBooks.first }

    private var budgetPercent: Double {
        guard let book = selectedBook, book.budget > 0 else { return 0 }
        return min((viewModel.monthlyExpense / book.budget) * 100, 100)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    MonthlySummaryCard(
                        income: viewModel.monthlyIncome,
                        expense: viewModel.monthlyExpense,
                        balance: viewModel.monthBalance,
                        month: viewModel.currentMonth,
                        bookName: selectedBook?.name ?? "日常账本",
                        budgetUsedPercent: budgetPercent,
                        onPrevious: {
                            viewModel.previousMonth()
                            reload()
                        },
                        onNext: {
                            viewModel.nextMonth()
                            reload()
                        }
                    )
                    .padding(.top, SonnetDimens.spacingL)

                    if viewModel.isLoading {
                        loadingSection
                    } else if let errorMessage = viewModel.errorMessage {
                        EmptyStateView(
                            title: "今天的纸页暂时没展开",
                            subtitle: errorMessage
                        )
                    } else if viewModel.dailyGroups.isEmpty {
                        EmptyStateView(
                            title: "故事从第一笔开始",
                            subtitle: "点击 + 记录你的第一笔"
                        )
                    } else {
                        ForEach(viewModel.dailyGroups) { group in
                            DailyRecordGroupView(group: group)
                        }
                    }
                }
                .padding(.horizontal, SonnetDimens.spacingXL)
                .padding(.bottom, 100)
            }
            .background(SonnetColors.paper)

            ExpandableFAB(
                isExpanded: $fabExpanded,
                onAddRecord: {
                    shortcutDraft = nil
                    AppShortcutStore.clearQuickRecordDraft()
                    appState.showingAddRecord = true
                },
                onScan: { showingScan = true },
                onVoice: { showingVoice = true }
            )
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("十四行诗")
                    .font(SonnetTypography.titleSection)
                    .foregroundStyle(SonnetColors.textTitle)
            }
        }
        .onAppear {
            reload()
            syncShortcutDraftIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sonnetRecordChanged)) { _ in
            reload()
            syncShortcutDraftIfNeeded()
        }
        .sheet(
            isPresented: Binding(
                get: { appState.showingAddRecord },
                set: { newValue in
                    appState.showingAddRecord = newValue
                    if !newValue {
                        shortcutDraft = nil
                        AppShortcutStore.clearQuickRecordDraft()
                    }
                }
            ),
            onDismiss: reload
        ) {
            RecordView(prefillDraft: shortcutDraft)
        }
        .sheet(isPresented: $showingScan, onDismiss: reload) {
            ScanView()
        }
        .sheet(isPresented: $showingVoice, onDismiss: reload) {
            VoiceRecordSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var loadingSection: some View {
        VStack(spacing: SonnetDimens.spacingL) {
            ForEach(0..<2, id: \.self) { _ in
                SonnetCard {
                    RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge)
                        .fill(SonnetColors.paperLight)
                        .frame(height: 148)
                        .shimmer(when: true)
                }
            }
        }
    }

    private func reload() {
        viewModel.loadRecords(from: modelContext, accountBook: selectedBook)
    }

    private func syncShortcutDraftIfNeeded() {
        guard let draft = AppShortcutStore.peekQuickRecordDraft() else { return }
        shortcutDraft = draft
        appState.showingAddRecord = true
    }
}

#Preview {
    NavigationStack { HomeView() }
        .modelContainer(for: [Record.self, Category.self, AccountBook.self], inMemory: true)
        .environment(AppState())
}
