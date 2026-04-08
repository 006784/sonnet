import SwiftUI
import SwiftData

struct StudyView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Course.weekday), SortDescriptor(\Course.startPeriod)])
    private var allCourses: [Course]
    @Query(filter: #Predicate<AccountBook> { $0.isSelected })
    private var selectedBooks: [AccountBook]

    @Query(filter: #Predicate<TodoItem> { !$0.isCompleted })
    private var pendingTodos: [TodoItem]

    @Query(sort: [SortDescriptor(\Exam.date)])
    private var allExams: [Exam]

    @Query(sort: [SortDescriptor(\FocusSession.startTime)])
    private var allSessions: [FocusSession]

    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var allNotes: [Note]

    @Query(sort: [SortDescriptor(\GradeRecord.createdAt, order: .reverse)])
    private var gradeRecords: [GradeRecord]

    @AppStorage("student_monthly_budget") private var monthlyBudget: Double = 1500
    @State private var budgetSnapshot: StudentBudgetSnapshot = .empty

    // MARK: - Computed

    private var todayWeekday: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 ? 7 : wd - 1   // Calendar: 1=Sun→7; Course: 1=Mon→7=Sun
    }

    private var todayCourses: [Course] {
        allCourses.filter { $0.weekday == todayWeekday }
    }

    private var sortedPendingTodos: [TodoItem] {
        pendingTodos.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                return l < r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.createdAt < rhs.createdAt
            }
        }
    }

    private var todayTodos: [TodoItem] {
        let cal = Calendar.current
        return pendingTodos.filter { todo in
            guard let dueDate = todo.dueDate else { return false }
            return cal.isDate(dueDate, inSameDayAs: Date())
        }
    }

    private var overdueTodos: [TodoItem] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return pendingTodos.filter { todo in
            guard let dueDate = todo.dueDate else { return false }
            return dueDate < startOfToday
        }
    }

    private var upcomingExamWithin7Days: Exam? {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return allExams.first { !$0.isCompleted && $0.date >= now && $0.date <= cutoff }
    }

    private var nextUpcomingExam: Exam? {
        let now = Date()
        return allExams.first { !$0.isCompleted && $0.date >= now }
    }

    private var weekFocusByDay: [Int: Int] {
        let cal = Calendar.current
        let now = Date()
        var result: [Int: Int] = [:]
        for session in allSessions where session.isCompleted {
            let diff = cal.dateComponents([.day], from: session.startTime, to: now).day ?? 0
            if diff >= 0 && diff < 7 {
                let idx = 6 - diff   // 0 = 6 days ago, 6 = today
                result[idx, default: 0] += session.duration
            }
        }
        return result
    }

    private var todayFocusMinutes: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return allSessions
            .filter { $0.isCompleted && cal.startOfDay(for: $0.startTime) == today }
            .reduce(0) { $0 + $1.duration } / 60
    }

    private var weekTotalMinutes: Int {
        weekFocusByDay.values.reduce(0, +) / 60
    }

    private var gpa: Double? {
        guard !gradeRecords.isEmpty else { return nil }
        let credits = gradeRecords.reduce(0) { $0 + $1.credit }
        guard credits > 0 else { return nil }
        return gradeRecords.reduce(0) { $0 + $1.gradePoint * $1.credit } / credits
    }

    private var budgetStatus: StudentBudgetStatus {
        budgetSnapshot.status(monthlyBudget: monthlyBudget)
    }

    private var remainingBudget: Double {
        budgetSnapshot.remainingBudget(monthlyBudget: monthlyBudget)
    }

    private var budgetUsedPercent: Double {
        budgetSnapshot.usedPercent(monthlyBudget: monthlyBudget)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: SonnetDimens.spacingL) {
                todayCourseCard
                todayTodoCard
                budgetGuardCard
                quickEntryGrid
                if let exam = upcomingExamWithin7Days {
                    examCountdownMini(exam)
                }
                weekFocusCard
                if let gpa {
                    gpaPeekCard(gpa: gpa)
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, SonnetDimens.spacingXL)
            .padding(.top, SonnetDimens.spacingL)
        }
        .background(SonnetColors.paper)
        .navigationTitle("学习")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshBudgetSnapshot)
        .onReceive(NotificationCenter.default.publisher(for: .sonnetRecordChanged)) { _ in
            refreshBudgetSnapshot()
        }
        .onChange(of: selectedBooks.first?.id) { _, _ in
            refreshBudgetSnapshot()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("学习")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SonnetColors.textTitle)
                    Text(todayDateString)
                        .font(.system(size: 10))
                        .foregroundStyle(SonnetColors.textCaption)
                }
            }
        }
    }

    // MARK: - Today's Courses Card

    private var todayCourseCard: some View {
        VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
            Text("今日课程")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))

            if todayCourses.isEmpty {
                Text("今天没有课，好好休息")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.vertical, SonnetDimens.spacingM)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SonnetDimens.spacingM) {
                        ForEach(todayCourses) { course in
                            let isCurrent = CoursePeriodHelper.isCurrentlyInProgress(
                                startPeriod: course.startPeriod,
                                endPeriod: course.endPeriod
                            )
                            courseChip(course: course, isCurrent: isCurrent)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(SonnetDimens.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [SonnetColors.ink, SonnetColors.inkLight, SonnetColors.inkPale],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusXL))
    }

    private func courseChip(course: Course, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(course.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            if !course.location.isEmpty {
                Text(course.location)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            Text(CoursePeriodHelper.timeString(
                startPeriod: course.startPeriod,
                endPeriod: course.endPeriod
            ))
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: isCurrent ? 1.5 : 0)
        )
    }

    // MARK: - Quick Entry 2x2 Grid

    private var quickEntryGrid: some View {
        let items: [QuickEntry] = [
            QuickEntry(icon: "calendar.day.timeline.left", colorName: "education",
                       title: "课表",
                       subtitle: todayCourses.isEmpty ? "今日无课" : "今天 \(todayCourses.count) 节课"),
            QuickEntry(icon: "timer", colorName: "transport",
                       title: "专注计时",
                       subtitle: todayFocusMinutes > 0 ? "今日已专注 \(todayFocusMinutes) 分钟" : "开始专注"),
            QuickEntry(icon: "checklist", colorName: "daily",
                       title: "待办清单",
                       subtitle: pendingTodos.isEmpty ? "暂无待办" : "\(pendingTodos.count) 条未完成"),
            QuickEntry(icon: "note.text", colorName: "salary",
                       title: "课堂笔记",
                       subtitle: allNotes.isEmpty ? "还没有笔记" : "\(allNotes.count) 篇笔记"),
            QuickEntry(icon: "calendar.badge.clock", colorName: "gift",
                       title: "考试倒计时",
                       subtitle: examSubtitle),
            QuickEntry(icon: "chart.line.uptrend.xyaxis", colorName: "parttime",
                       title: "GPA 计算",
                       subtitle: gpaSubtitle),
        ]

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: SonnetDimens.spacingM),
                      GridItem(.flexible(), spacing: SonnetDimens.spacingM)],
            spacing: SonnetDimens.spacingM
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                NavigationLink(destination: quickEntryDestination(index: index)) {
                    quickEntryCard(item: item)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func quickEntryCard(item: QuickEntry) -> some View {
        let colors = SonnetColors.categoryColors(item.colorName)
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.bg)
                    .frame(width: 36, height: 36)
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(colors.icon)
            }
            Spacer(minLength: SonnetDimens.spacingL)
            Text(item.title)
                .font(SonnetTypography.bodyBold)
                .foregroundStyle(SonnetColors.textTitle)
                .lineLimit(1)
            Text(item.subtitle)
                .font(SonnetTypography.caption2)
                .foregroundStyle(SonnetColors.textCaption)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .padding(SonnetDimens.spacingL)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(SonnetColors.paperWhite)
        .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
    }

    @ViewBuilder
    private func quickEntryDestination(index: Int) -> some View {
        switch index {
        case 0: ScheduleView()
        case 1: FocusTimerView()
        case 2: TodoListView()
        case 3: NotesListView()
        case 4: ExamCountdownView()
        case 5: GPACalculatorView()
        default: EmptyView()
        }
    }

    // MARK: - Todo Summary

    private var todayTodoCard: some View {
        NavigationLink(destination: TodoListView()) {
            SonnetCard {
                VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SonnetColors.categoryColors(for: "daily").bg)
                                .frame(width: 40, height: 40)
                            Image(systemName: "checklist")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(SonnetColors.categoryColors(for: "daily").icon)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("今日待办")
                                .font(SonnetTypography.titleCard)
                                .foregroundStyle(SonnetColors.textTitle)
                            Text(todoHeadline)
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(SonnetColors.textCaption)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SonnetColors.textHint)
                    }

                    HStack(spacing: SonnetDimens.spacingM) {
                        todoMetric(value: "\(todayTodos.count)", label: "今天到期", tint: SonnetColors.ink)
                        todoMetric(value: "\(overdueTodos.count)", label: "已逾期", tint: SonnetColors.vermilion)
                        todoMetric(value: "\(pendingTodos.count)", label: "全部待办", tint: SonnetColors.amber)
                    }

                    if let nextTodo = sortedPendingTodos.first {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("下一件事")
                                .font(SonnetTypography.label)
                                .foregroundStyle(SonnetColors.textHint)
                            Text(nextTodo.title)
                                .font(SonnetTypography.bodyBold)
                                .foregroundStyle(SonnetColors.textTitle)
                                .lineLimit(1)

                            if let dueDate = nextTodo.dueDate {
                                Text(todoDueText(for: dueDate))
                                    .font(SonnetTypography.caption1)
                                    .foregroundStyle(
                                        dueDate < Calendar.current.startOfDay(for: Date())
                                            ? SonnetColors.vermilion
                                            : SonnetColors.textCaption
                                    )
                            }
                        }
                    } else {
                        Text("今天的任务页还很安静，适合先安排一件想认真完成的小事。")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                            .lineSpacing(4)
                    }
                }
                .padding(SonnetDimens.spacingL)
            }
        }
        .buttonStyle(.plain)
    }

    private func todoMetric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(SonnetTypography.amountBody)
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(SonnetTypography.caption2)
                .foregroundStyle(SonnetColors.textCaption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(SonnetColors.paperLight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Exam Countdown Mini

    private func examCountdownMini(_ exam: Exam) -> some View {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: exam.date).day ?? 0
        let accentColor: Color = days <= 3 ? SonnetColors.vermilion
            : days <= 5 ? SonnetColors.amber
            : SonnetColors.jade

        return NavigationLink(destination: ExamCountdownView()) {
            SonnetCard {
                HStack(spacing: SonnetDimens.spacingM) {
                    VStack(spacing: 2) {
                        Text("\(max(0, days))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                        Text("天后")
                            .font(.system(size: 11))
                            .foregroundStyle(SonnetColors.textCaption)
                    }
                    .frame(width: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(accentColor)
                            Text("即将考试")
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(accentColor)
                        }
                        Text(exam.name.isEmpty ? exam.courseName : exam.name)
                            .font(SonnetTypography.bodyBold)
                            .foregroundStyle(SonnetColors.textTitle)
                        Text(DateUtils.dayString(exam.date))
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(SonnetColors.textCaption)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(SonnetColors.textHint)
                }
                .padding(SonnetDimens.spacingL)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Focus Stats

    private var weekFocusCard: some View {
        SonnetCard {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
                HStack {
                    Text("本周专注")
                        .font(SonnetTypography.bodyBold)
                        .foregroundStyle(SonnetColors.textTitle)
                    Spacer()
                    let h = weekTotalMinutes / 60
                    let m = weekTotalMinutes % 60
                    Text(h > 0 ? "共 \(h)h \(m)m" : "共 \(m)m")
                        .font(SonnetTypography.amountSmall)
                        .foregroundStyle(SonnetColors.ink)
                }

                // 7-day bar chart
                let maxSecs = max(1, weekFocusByDay.values.max() ?? 1)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        let secs = weekFocusByDay[i, default: 0]
                        let ratio = CGFloat(secs) / CGFloat(maxSecs)
                        let isToday = i == 6

                        VStack(spacing: 4) {
                            Capsule()
                                .fill(isToday ? SonnetColors.ink : SonnetColors.inkMist)
                                .frame(height: max(4, ratio * 48))
                            Text(weekdayLabel(index: i))
                                .font(.system(size: 9))
                                .foregroundStyle(isToday ? SonnetColors.ink : SonnetColors.textHint)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 62)
                .animation(SonnetMotion.spring, value: weekFocusByDay.count)
            }
            .padding(SonnetDimens.spacingL)
        }
    }

    private var budgetGuardCard: some View {
        NavigationLink(destination: BudgetGuardView()) {
            StudentHeroCard(
                title: budgetStatus.title,
                subtitle: budgetStatus.subtitle,
                icon: budgetStatus.symbol,
                colorName: budgetStatus.colorName
            ) {
                HStack(spacing: SonnetDimens.spacingM) {
                    StudentMetricPill(title: "预算", value: "¥\(CurrencyUtils.format(monthlyBudget))", tint: SonnetColors.ink)
                    StudentMetricPill(title: "已用", value: "¥\(CurrencyUtils.format(budgetSnapshot.monthExpense))", tint: budgetProgressColor)
                    StudentMetricPill(title: "剩余", value: remainingBudget < 0 ? "超 ¥\(CurrencyUtils.format(-remainingBudget))" : "¥\(CurrencyUtils.format(remainingBudget))", tint: remainingBudget < 0 ? SonnetColors.vermilion : SonnetColors.jade)
                }

                VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                    HStack {
                        Text("本月进度")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                        Spacer()
                        Text("\(Int(min(max(budgetUsedPercent, 0), 1.2) * 100))%")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(budgetProgressColor)
                    }

                    GeometryReader { geo in
                        let clamped = min(max(budgetUsedPercent, 0), 1)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(SonnetColors.paperLine)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(budgetProgressColor)
                                .frame(width: geo.size.width * clamped, height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("点进去可以看餐饮、交通和本周对比。")
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(SonnetColors.textHint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var budgetProgressColor: Color {
        if remainingBudget < 0 { return SonnetColors.vermilion }
        if budgetUsedPercent > 0.85 { return SonnetColors.amber }
        return SonnetColors.ink
    }

    // MARK: - GPA Peek

    private func gpaPeekCard(gpa: Double) -> some View {
        NavigationLink(destination: GPACalculatorView()) {
            SonnetCard {
                HStack(spacing: SonnetDimens.spacingL) {
                    ZStack {
                        Circle()
                            .stroke(SonnetColors.paperLine, lineWidth: 5)
                            .frame(width: 48, height: 48)
                        Circle()
                            .trim(from: 0, to: min(gpa / 4.0, 1.0))
                            .stroke(
                                gpaColor(gpa),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 48, height: 48)
                        Text(String(format: "%.1f", gpa))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(gpaColor(gpa))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("当前 GPA")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                        Text(String(format: "%.2f", gpa))
                            .font(SonnetTypography.amountMedium)
                            .foregroundStyle(SonnetColors.ink)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Text("详情")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(SonnetColors.textHint)
                    }
                }
                .padding(SonnetDimens.spacingL)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var todayDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日 EEEE"
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: Date())
    }

    private func weekdayLabel(index: Int) -> String {
        let labels = ["日", "一", "二", "三", "四", "五", "六"]
        let daysAgo = 6 - index
        guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) else { return "" }
        let wd = Calendar.current.component(.weekday, from: date) - 1   // 0=Sun
        return labels[wd]
    }

    private func gpaColor(_ gpa: Double) -> Color {
        gpa >= 3.7 ? SonnetColors.jade : gpa >= 2.0 ? SonnetColors.amber : SonnetColors.vermilion
    }

    private var todoHeadline: String {
        if overdueTodos.count > 0 {
            return "有 \(overdueTodos.count) 件事已经超过计划时间"
        }
        if todayTodos.count > 0 {
            return "今天有 \(todayTodos.count) 件事要完成"
        }
        if pendingTodos.count > 0 {
            return "还有 \(pendingTodos.count) 件事在等待你推进"
        }
        return "今天的安排还很轻，可以从容开始"
    }

    private var examSubtitle: String {
        guard let exam = nextUpcomingExam else { return "暂无考试安排" }
        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: exam.date).day ?? 0)
        return "\(days) 天后 · \(exam.courseName)"
    }

    private var gpaSubtitle: String {
        guard let gpa else { return "录入课程成绩" }
        return String(format: "当前 %.2f", gpa)
    }

    private func todoDueText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDate(date, inSameDayAs: Date()) ? "今天 HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func refreshBudgetSnapshot() {
        guard let selectedBook = selectedBooks.first else {
            budgetSnapshot = .empty
            return
        }
        budgetSnapshot = StudentBudgetSnapshot.load(modelContext: modelContext, accountBookID: selectedBook.id)
        NotificationService.shared.scheduleBudgetWarningIfNeeded(
            monthlyBudget: monthlyBudget,
            usedPercent: budgetUsedPercent,
            remainingBudget: remainingBudget,
            remainingDays: budgetSnapshot.remainingDaysInMonth
        )
    }
}

// MARK: - Supporting Types

private struct QuickEntry {
    let icon: String
    let colorName: String
    let title: String
    let subtitle: String
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(SonnetMotion.springFast, value: configuration.isPressed)
    }
}

// MARK: - Course Period Helper

enum CoursePeriodHelper {
    // (start, end) in minutes from midnight — standard Chinese university schedule
    private static let periodTimes: [(start: Int, end: Int)] = [
        (480, 525),   //  1st  08:00–08:45
        (535, 580),   //  2nd  08:55–09:40
        (600, 645),   //  3rd  10:00–10:45
        (655, 700),   //  4th  10:55–11:40
        (840, 885),   //  5th  14:00–14:45
        (895, 940),   //  6th  14:55–15:40
        (960, 1005),  //  7th  16:00–16:45
        (1015, 1060), //  8th  16:55–17:40
        (1110, 1155), //  9th  18:30–19:15
        (1165, 1210), // 10th  19:25–20:10
    ]

    static func timeString(startPeriod: Int, endPeriod: Int) -> String {
        guard startPeriod >= 1, startPeriod <= periodTimes.count else { return "" }
        let startMins = periodTimes[startPeriod - 1].start
        let endIdx   = min(endPeriod, periodTimes.count) - 1
        let endMins  = endIdx >= 0 ? periodTimes[endIdx].end : startMins + 45
        return "\(fmt(startMins))–\(fmt(endMins))"
    }

    static func isCurrentlyInProgress(startPeriod: Int, endPeriod: Int) -> Bool {
        guard startPeriod >= 1, startPeriod <= periodTimes.count else { return false }
        let startMins = periodTimes[startPeriod - 1].start
        let endIdx    = min(max(1, endPeriod), periodTimes.count) - 1
        let endMins   = periodTimes[endIdx].end
        let cal = Calendar.current
        let now = cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
        return now >= startMins && now <= endMins
    }

    private static func fmt(_ mins: Int) -> String {
        String(format: "%02d:%02d", mins / 60, mins % 60)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { StudyView() }
        .modelContainer(for: [Course.self, TodoItem.self, FocusSession.self,
                               Note.self, Exam.self, GradeRecord.self, AccountBook.self,
                               Record.self, Category.self], inMemory: true)
        .environment(AppState())
}
