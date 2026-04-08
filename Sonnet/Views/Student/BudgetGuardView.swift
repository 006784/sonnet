import SwiftUI
import SwiftData

struct StudentBudgetStatus {
    let title: String
    let subtitle: String
    let colorName: String
    let symbol: String
}

struct StudentBudgetSnapshot {
    var monthExpense: Double = 0
    var foodExpense: Double = 0
    var transportExpense: Double = 0
    var prevMonthExpense: Double = 0
    var thisWeekExpense: Double = 0
    var prevWeekExpense: Double = 0
    var remainingDaysInMonth: Int = 1

    static let empty = StudentBudgetSnapshot()

    var otherExpense: Double {
        max(0, monthExpense - foodExpense - transportExpense)
    }

    func remainingBudget(monthlyBudget: Double) -> Double {
        monthlyBudget - monthExpense
    }

    func dailyAllowance(monthlyBudget: Double) -> Double {
        max(0, remainingBudget(monthlyBudget: monthlyBudget)) / Double(max(remainingDaysInMonth, 1))
    }

    func usedPercent(monthlyBudget: Double) -> Double {
        guard monthlyBudget > 0 else { return 0 }
        return monthExpense / monthlyBudget
    }

    func status(monthlyBudget: Double) -> StudentBudgetStatus {
        let remaining = remainingBudget(monthlyBudget: monthlyBudget)
        let used = usedPercent(monthlyBudget: monthlyBudget)

        if remaining < 0 {
            return StudentBudgetStatus(
                title: "这个月已经超出生活费边界",
                subtitle: "目前超支 ¥\(CurrencyUtils.format(-remaining))，接下来几天要更克制一点。",
                colorName: "gift",
                symbol: "exclamationmark.triangle.fill"
            )
        }

        if used >= 0.85 {
            return StudentBudgetStatus(
                title: "这个月的预算开始变紧了",
                subtitle: "已用掉 \(Int(min(used, 1) * 100))%，最好开始留意大额支出。",
                colorName: "invest",
                symbol: "hourglass.bottomhalf.filled"
            )
        }

        return StudentBudgetStatus(
            title: "生活费还在稳稳地往前走",
            subtitle: "还剩 \(remainingDaysInMonth) 天，日均大约还能花 ¥\(CurrencyUtils.format(dailyAllowance(monthlyBudget: monthlyBudget)))。",
            colorName: "canteen",
            symbol: "wallet.pass.fill"
        )
    }

    static func load(modelContext: ModelContext, accountBookID: UUID, now: Date = Date()) -> StudentBudgetSnapshot {
        let cal = Calendar.current
        let monthStart = DateUtils.startOfMonth(now)
        let monthEnd = DateUtils.endOfMonth(now)

        let monthDesc = FetchDescriptor<Record>(predicate: #Predicate<Record> { record in
            record.type == 0 &&
            record.date >= monthStart &&
            record.date <= monthEnd &&
            record.accountBookId == accountBookID
        })
        let monthRecords = (try? modelContext.fetch(monthDesc)) ?? []

        var snapshot = StudentBudgetSnapshot()
        snapshot.monthExpense = monthRecords.reduce(0) { $0 + $1.amount }
        snapshot.foodExpense = monthRecords.filter {
            let name = $0.category?.name ?? ""
            return name == "餐饮" || name == "食堂" || name == "奶茶"
        }.reduce(0) { $0 + $1.amount }
        snapshot.transportExpense = monthRecords.filter {
            $0.category?.name == "交通"
        }.reduce(0) { $0 + $1.amount }

        if let prevMonth = cal.date(byAdding: .month, value: -1, to: now) {
            let pStart = DateUtils.startOfMonth(prevMonth)
            let pEnd = DateUtils.endOfMonth(prevMonth)
            let pDesc = FetchDescriptor<Record>(predicate: #Predicate<Record> { record in
                record.type == 0 &&
                record.date >= pStart &&
                record.date <= pEnd &&
                record.accountBookId == accountBookID
            })
            snapshot.prevMonthExpense = ((try? modelContext.fetch(pDesc)) ?? []).reduce(0) { $0 + $1.amount }
        }

        let weekday = cal.component(.weekday, from: now)
        let daysFromMon = weekday == 1 ? 6 : weekday - 2
        let weekStart = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysFromMon, to: now) ?? now)
        let weekDesc = FetchDescriptor<Record>(predicate: #Predicate<Record> { record in
            record.type == 0 &&
            record.date >= weekStart &&
            record.accountBookId == accountBookID
        })
        snapshot.thisWeekExpense = ((try? modelContext.fetch(weekDesc)) ?? []).reduce(0) { $0 + $1.amount }

        let prevWeekStart = cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let prevWeekEnd = cal.date(byAdding: .second, value: -1, to: weekStart) ?? weekStart
        let prevWeekDesc = FetchDescriptor<Record>(predicate: #Predicate<Record> { record in
            record.type == 0 &&
            record.date >= prevWeekStart &&
            record.date <= prevWeekEnd &&
            record.accountBookId == accountBookID
        })
        snapshot.prevWeekExpense = ((try? modelContext.fetch(prevWeekDesc)) ?? []).reduce(0) { $0 + $1.amount }

        if let monthStartDate = cal.date(from: cal.dateComponents([.year, .month], from: now)),
           let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStartDate),
           let lastDay = cal.date(byAdding: .day, value: -1, to: nextMonth) {
            let days = cal.dateComponents([.day], from: now, to: lastDay).day ?? 0
            snapshot.remainingDaysInMonth = max(1, days + 1)
        }

        return snapshot
    }
}

struct BudgetGuardView: View {
    @Environment(\.modelContext) private var modelContext

    // Budget amounts stored in UserDefaults
    @AppStorage("student_monthly_budget")    private var monthlyBudget:    Double = 1500
    @AppStorage("student_food_budget")       private var foodBudget:       Double = 800
    @AppStorage("student_transport_budget")  private var transportBudget:  Double = 200
    @AppStorage("student_other_budget")      private var otherBudget:      Double = 500

    @State private var editingField: EditField? = nil
    @State private var inputText = ""

    // Loaded expense data
    @State private var monthExpense:     Double = 0
    @State private var foodExpense:      Double = 0
    @State private var transportExpense: Double = 0
    @State private var prevMonthExpense: Double = 0
    @State private var thisWeekExpense:  Double = 0
    @State private var prevWeekExpense:  Double = 0

    @Query(filter: #Predicate<AccountBook> { $0.isSelected })
    private var selectedBooks: [AccountBook]

    enum EditField: Identifiable {
        case monthly, food, transport, other
        var id: Self { self }
        var label: String {
            switch self {
            case .monthly:   return "月生活费"
            case .food:      return "餐饮预算"
            case .transport: return "交通预算"
            case .other:     return "其他预算"
            }
        }
    }

    // MARK: - Computed

    private var remainingDaysInMonth: Int {
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let nextMonth  = cal.date(byAdding: .month, value: 1, to: monthStart),
              let lastDay    = cal.date(byAdding: .day, value: -1, to: nextMonth) else { return 1 }
        let days = cal.dateComponents([.day], from: now, to: lastDay).day ?? 0
        return max(1, days + 1)
    }

    private var remainingBudget: Double { monthlyBudget - monthExpense }

    private var dailyAllowance: Double {
        max(0, remainingBudget) / Double(remainingDaysInMonth)
    }

    private var usedPercent: Double {
        guard monthlyBudget > 0 else { return 0 }
        return monthExpense / monthlyBudget
    }

    private var otherExpense: Double { max(0, monthExpense - foodExpense - transportExpense) }
    private var budgetStatus: StudentBudgetStatus { budgetSnapshot.status(monthlyBudget: monthlyBudget) }
    private var budgetSnapshot: StudentBudgetSnapshot {
        StudentBudgetSnapshot(
            monthExpense: monthExpense,
            foodExpense: foodExpense,
            transportExpense: transportExpense,
            prevMonthExpense: prevMonthExpense,
            thisWeekExpense: thisWeekExpense,
            prevWeekExpense: prevWeekExpense,
            remainingDaysInMonth: remainingDaysInMonth
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: SonnetDimens.spacingL) {
                budgetHeroCard
                monthlyBudgetCard
                dailyAllowanceCard
                comparisonCard
                Spacer(minLength: 40)
            }
            .padding(.horizontal, SonnetDimens.spacingXL)
            .padding(.top, SonnetDimens.spacingL)
        }
        .background(SonnetColors.paper)
        .navigationTitle("生活费管家")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExpenseData() }
        .onReceive(NotificationCenter.default.publisher(for: .sonnetRecordChanged)) { _ in
            loadExpenseData()
        }
        .onChange(of: selectedBooks.first?.id) { _, _ in
            loadExpenseData()
        }
        .alert(editingField?.label ?? "", isPresented: .init(
            get: { editingField != nil },
            set: { if !$0 { editingField = nil } }
        )) {
            TextField("输入金额", text: $inputText)
                .keyboardType(.decimalPad)
            Button("确认") {
                if let v = Double(inputText), v > 0 {
                    switch editingField {
                    case .monthly:   monthlyBudget   = v
                    case .food:      foodBudget       = v
                    case .transport: transportBudget  = v
                    case .other:     otherBudget      = v
                    case nil: break
                    }
                }
                editingField = nil
            }
            Button("取消", role: .cancel) { editingField = nil }
        } message: {
            Text("请输入新的金额（元）")
        }
    }

    private var budgetHeroCard: some View {
        StudentHeroCard(
            title: budgetStatus.title,
            subtitle: budgetStatus.subtitle,
            icon: budgetStatus.symbol,
            colorName: budgetStatus.colorName
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "本月已花", value: "¥\(CurrencyUtils.format(monthExpense))", tint: progressColor(usedPercent))
                StudentMetricPill(title: "还能花", value: remainingBudget < 0 ? "超 ¥\(CurrencyUtils.format(-remainingBudget))" : "¥\(CurrencyUtils.format(remainingBudget))", tint: remainingBudget < 0 ? SonnetColors.vermilion : SonnetColors.jade)
                StudentMetricPill(title: "日均额度", value: "¥\(CurrencyUtils.format(dailyAllowance))", tint: SonnetColors.ink)
            }
        }
    }

    // MARK: - Monthly Budget Card

    private var monthlyBudgetCard: some View {
        SonnetCard {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingL) {

                // Header
                HStack {
                    Text("本月生活费")
                        .font(SonnetTypography.bodyBold)
                        .foregroundStyle(SonnetColors.textTitle)
                    Spacer()
                    Button {
                        inputText = String(format: "%.0f", monthlyBudget)
                        editingField = .monthly
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(SonnetColors.ink)
                    }
                }

                // Budget amount
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("¥")
                        .font(SonnetTypography.title2)
                        .foregroundStyle(SonnetColors.textCaption)
                    Text(CurrencyUtils.format(monthlyBudget))
                        .font(SonnetTypography.amountLarge)
                        .foregroundStyle(SonnetColors.ink)
                }

                PoetryDivider()

                // Sub-category budgets
                VStack(spacing: SonnetDimens.spacingM) {
                    budgetSubRow(icon: "tray.fill",    label: "餐饮",
                                 spent: foodExpense,      total: foodBudget,
                                 colorName: "food",       field: .food)
                    budgetSubRow(icon: "bus.fill",     label: "交通",
                                 spent: transportExpense, total: transportBudget,
                                 colorName: "transport",  field: .transport)
                    budgetSubRow(icon: "ellipsis.circle", label: "其他",
                                 spent: otherExpense,     total: otherBudget,
                                 colorName: "other",      field: .other)
                }

                PoetryDivider()

                // Total progress bar
                VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                    HStack {
                        Text("总支出")
                            .font(SonnetTypography.footnote)
                            .foregroundStyle(SonnetColors.textCaption)
                        Spacer()
                        Text("¥\(CurrencyUtils.format(monthExpense)) / ¥\(CurrencyUtils.format(monthlyBudget))")
                            .font(SonnetTypography.footnote)
                            .foregroundStyle(SonnetColors.textCaption)
                    }

                    GeometryReader { geo in
                        let clampedPct = min(usedPercent, 1.0)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(SonnetColors.paperLine)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor(usedPercent))
                                .frame(width: geo.size.width * clampedPct, height: 8)
                                .animation(SonnetMotion.spring, value: clampedPct)
                        }
                    }
                    .frame(height: 8)

                    HStack(spacing: SonnetDimens.spacingS) {
                        Text(String(format: "%.0f%%", min(usedPercent, 1.0) * 100))
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(progressColor(usedPercent))

                        if usedPercent > 1.0 {
                            Text("已超支")
                                .font(SonnetTypography.caption2)
                                .foregroundStyle(SonnetColors.vermilion)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SonnetColors.vermilionLight)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(SonnetDimens.spacingL)
        }
    }

    private func budgetSubRow(
        icon: String, label: String,
        spent: Double, total: Double,
        colorName: String, field: EditField
    ) -> some View {
        let pct  = total > 0 ? min(spent / total, 1.0) : 0
        let colors = SonnetColors.categoryColors(colorName)

        return VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(colors.icon)
                    .frame(width: 20)
                Text(label)
                    .font(SonnetTypography.footnote)
                    .foregroundStyle(SonnetColors.textBody)
                Spacer()
                Text("¥\(CurrencyUtils.format(spent))")
                    .font(SonnetTypography.footnote)
                    .foregroundStyle(SonnetColors.textCaption)
                Text("/ ¥\(CurrencyUtils.format(total))")
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textHint)

                Button {
                    inputText = String(format: "%.0f", total)
                    editingField = field
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(SonnetColors.inkPale)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colors.bg)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colors.icon)
                        .frame(width: geo.size.width * pct, height: 5)
                        .animation(SonnetMotion.spring, value: pct)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Daily Allowance Card

    private var dailyAllowanceCard: some View {
        SonnetCard {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                if remainingBudget >= 0 {
                    HStack(spacing: SonnetDimens.spacingXS) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(SonnetColors.amber)
                        Text("今天还可以花")
                            .font(SonnetTypography.footnote)
                            .foregroundStyle(SonnetColors.textBody)
                        Text("¥\(CurrencyUtils.format(dailyAllowance))")
                            .font(SonnetTypography.amountSmall)
                            .foregroundStyle(SonnetColors.ink)
                    }
                } else {
                    HStack(spacing: SonnetDimens.spacingXS) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(SonnetColors.vermilion)
                        Text("今天已超支 ¥\(CurrencyUtils.format(-remainingBudget))，明天少花一点")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.vermilion)
                    }
                }

                Text("还剩 \(remainingDaysInMonth) 天 · 剩余生活费 ¥\(CurrencyUtils.format(max(0, remainingBudget)))")
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textHint)
            }
            .padding(SonnetDimens.spacingL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Comparison Card

    private var comparisonCard: some View {
        SonnetCard {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingL) {
                Text("消费对比")
                    .font(SonnetTypography.bodyBold)
                    .foregroundStyle(SonnetColors.textTitle)

                HStack(spacing: 0) {
                    comparisonCol(label: "本周消费",
                                  current: thisWeekExpense,
                                  previous: prevWeekExpense,
                                  prevLabel: "vs 上周")
                    Divider().frame(height: 52)
                    comparisonCol(label: "本月消费",
                                  current: monthExpense,
                                  previous: prevMonthExpense,
                                  prevLabel: "vs 上月")
                }
            }
            .padding(SonnetDimens.spacingL)
        }
    }

    private func comparisonCol(
        label: String, current: Double, previous: Double, prevLabel: String
    ) -> some View {
        let diff  = previous > 0 ? (current - previous) / previous : 0
        let isUp  = diff > 0
        let pct   = abs(diff) * 100

        return VStack(spacing: 4) {
            Text("¥\(CurrencyUtils.format(current))")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(SonnetColors.textTitle)
            Text(label)
                .font(SonnetTypography.caption2)
                .foregroundStyle(SonnetColors.textCaption)

            if previous > 0 {
                HStack(spacing: 2) {
                    Image(systemName: isUp ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.0f%%", pct))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(isUp ? SonnetColors.vermilion : SonnetColors.jade)
            } else {
                Text(prevLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(SonnetColors.textHint)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func progressColor(_ pct: Double) -> Color {
        pct > 1.0 ? SonnetColors.vermilion
            : pct > 0.8 ? SonnetColors.amber
            : SonnetColors.ink
    }

    private func loadExpenseData() {
        guard let book = selectedBooks.first else { return }
        let snapshot = StudentBudgetSnapshot.load(modelContext: modelContext, accountBookID: book.id)
        monthExpense = snapshot.monthExpense
        foodExpense = snapshot.foodExpense
        transportExpense = snapshot.transportExpense
        prevMonthExpense = snapshot.prevMonthExpense
        thisWeekExpense = snapshot.thisWeekExpense
        prevWeekExpense = snapshot.prevWeekExpense
        NotificationService.shared.scheduleBudgetWarningIfNeeded(
            monthlyBudget: monthlyBudget,
            usedPercent: snapshot.usedPercent(monthlyBudget: monthlyBudget),
            remainingBudget: snapshot.remainingBudget(monthlyBudget: monthlyBudget),
            remainingDays: snapshot.remainingDaysInMonth
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { BudgetGuardView() }
        .modelContainer(for: [AccountBook.self, Record.self, Category.self], inMemory: true)
}
