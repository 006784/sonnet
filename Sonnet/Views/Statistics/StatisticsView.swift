import SwiftUI
import Charts
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var viewModel = StatisticsViewModel()
    private let aiService = AIService()

    @Query(filter: #Predicate<AccountBook> { $0.isSelected })
    private var selectedBooks: [AccountBook]
    private var selectedBook: AccountBook? { selectedBooks.first }

    private var total: Double {
        viewModel.categorySummaries.reduce(0) { $0 + $1.totalAmount }
    }

    private var typeLabel: String {
        viewModel.selectedType == .expense ? "总支出" : "总收入"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ── 月份选择器 ─────────────────────────────
                monthPicker
                    .padding(.top, 4)

                // ── 支出 / 收入 切换 ──────────────────────
                Picker("类型", selection: $viewModel.selectedType) {
                    ForEach(RecordType.allCases, id: \.rawValue) {
                        Text($0.label).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedType) { _, _ in reload() }

                // ── 月度总金额 ─────────────────────────────
                totalAmountRow

                // ── 饼图卡片 ───────────────────────────────
                SonnetCard {
                    VStack(spacing: 0) {
                        sectionHeader(title: viewModel.selectedType == .expense ? "支出构成" : "收入构成")

                        if viewModel.categorySummaries.isEmpty {
                            emptyChartState
                        } else {
                            DonutChart(
                                summaries: viewModel.categorySummaries,
                                typeLabel: typeLabel
                            )
                            .padding(.vertical, 20)
                        }
                    }
                }

                // ── 分类排行卡片 ───────────────────────────
                if !viewModel.categorySummaries.isEmpty {
                    SonnetCard {
                        VStack(spacing: 0) {
                            sectionHeader(title: "分类排行")
                            CategoryRankList(summaries: viewModel.categorySummaries)
                                .padding(.bottom, 8)
                        }
                    }
                }

                // ── AI 洞察卡片 ────────────────────────────
                if appState.aiConfiguration.isAvailable && !viewModel.categorySummaries.isEmpty {
                    AIInsightCard(
                        insight: viewModel.aiInsight,
                        isLoading: viewModel.isLoadingInsight,
                        onRefresh: {
                            Task { await viewModel.loadAIInsight(service: aiService) }
                        }
                    )
                }

                // ── 月度趋势（近 6 个月）──────────────────
                if !viewModel.monthlyTrends.isEmpty {
                    trendCard
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
        }
        .background(SonnetColors.paper)
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .sonnetRecordChanged)) { _ in
            reload()
        }
    }

    // MARK: – Sub-views

    private var monthPicker: some View {
        HStack {
            Button {
                viewModel.previousMonth()
                reload()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SonnetColors.textSecond)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }

            Spacer()

            Text(DateUtils.monthString(viewModel.currentMonth))
                .font(SonnetTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(SonnetColors.textTitle)

            Spacer()

            Button {
                viewModel.nextMonth()
                reload()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SonnetColors.textSecond)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
    }

    private var totalAmountRow: some View {
        VStack(spacing: 4) {
            Text(typeLabel)
                .font(SonnetTypography.caption1)
                .foregroundStyle(SonnetColors.textCaption)
            Text("¥\(CurrencyUtils.format(total))")
                .font(SonnetTypography.amountLarge)
                .foregroundStyle(viewModel.selectedType == .expense ? SonnetColors.vermilion : SonnetColors.jade)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: total)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var emptyChartState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 36))
                .foregroundStyle(SonnetColors.textHint)
            Text("本月暂无\(viewModel.selectedType.label)记录")
                .font(SonnetTypography.footnote)
                .foregroundStyle(SonnetColors.textHint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var trendCard: some View {
        SonnetCard {
            VStack(spacing: 0) {
                sectionHeader(title: "近 6 个月趋势")

                Chart {
                    ForEach(viewModel.monthlyTrends) { trend in
                        LineMark(
                            x: .value("月", trend.month, unit: .month),
                            y: .value("支出", trend.totalExpense)
                        )
                        .foregroundStyle(SonnetColors.vermilion)
                        .symbol(.circle)

                        LineMark(
                            x: .value("月", trend.month, unit: .month),
                            y: .value("收入", trend.totalIncome)
                        )
                        .foregroundStyle(SonnetColors.jade)
                        .symbol(.circle)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("¥\(Int(v))")
                                    .font(SonnetTypography.caption2)
                                    .foregroundStyle(SonnetColors.textHint)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(SonnetColors.paperLine)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(SonnetColors.textHint)
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                HStack(spacing: 16) {
                    legendDot(color: SonnetColors.vermilion, label: "支出")
                    legendDot(color: SonnetColors.jade, label: "收入")
                }
                .padding(.bottom, 14)
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(SonnetTypography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(SonnetColors.textCaption)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(SonnetTypography.caption2)
                .foregroundStyle(SonnetColors.textCaption)
        }
    }

    private func reload() {
        viewModel.loadStatistics(from: modelContext, accountBook: selectedBook)
        if appState.aiConfiguration.isAvailable && !viewModel.categorySummaries.isEmpty {
            Task { await viewModel.loadAIInsight(service: aiService) }
        }
    }
}

// MARK: – Preview

#Preview {
    NavigationStack {
        StatisticsView()
    }
    .modelContainer(for: [Record.self, Category.self, AccountBook.self], inMemory: true)
    .environment(AppState())
}
