import SwiftUI
import SwiftData

// MARK: - 课程表主视图

struct ScheduleView: View {
    @Query(sort: [SortDescriptor(\Course.weekday), SortDescriptor(\Course.startPeriod)])
    private var courses: [Course]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var editingCourse: Course? = nil
    @State private var isWeekMode = true
    @State private var currentWeek = 1
    @State private var selectedDay = 1

    // 当前周几（1=周一）
    private var todayWeekday: Int {
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: Date())
        return wd == 1 ? 7 : wd - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            scheduleSummaryCard
                .padding(.horizontal, SonnetDimens.spacingXL)
                .padding(.top, SonnetDimens.spacingL)

            // ── 周次 / 视图切换 bar ─────────────────────────────
            headerBar

            if isWeekMode {
                weekGrid
            } else {
                dayList
            }
        }
        .background(SonnetColors.paper)
        .navigationTitle("课程表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { ScheduleEditSheet() }
        .sheet(item: $editingCourse) { ScheduleEditSheet(editingCourse: $0) }
        .onAppear {
            selectedDay = todayWeekday
        }
    }

    private var scheduleSummaryCard: some View {
        StudentHeroCard(
            title: "本周课表",
            subtitle: isWeekMode ? "以周视图翻阅整周节奏" : "切换到日视图后，可以专注看某一天的安排",
            icon: "calendar.day.timeline.left",
            colorName: "education"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "今日课程", value: "\(todayCoursesCount) 节", tint: SonnetColors.ink)
                StudentMetricPill(title: "当前周次", value: "第 \(currentWeek) 周", tint: SonnetColors.amber)
                StudentMetricPill(title: "查看方式", value: isWeekMode ? "周视图" : "日视图", tint: SonnetColors.jade)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        SonnetCard {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Button { if currentWeek > 1 { currentWeek -= 1 } } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SonnetColors.ink)
                    }
                    Text("第 \(currentWeek) 周")
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textBody)
                        .frame(minWidth: 52)
                    Button { if currentWeek < 20 { currentWeek += 1 } } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SonnetColors.ink)
                    }
                }
                Spacer()
                Picker("", selection: $isWeekMode) {
                    Image(systemName: "rectangle.grid.3x2").tag(true)
                    Image(systemName: "list.bullet").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
            }
        }
        .padding(.horizontal, SonnetDimens.spacingXL)
        .padding(.vertical, 10)
        .background(SonnetColors.paper)
    }

    // MARK: - 周视图网格

    private var weekGrid: some View {
        ScrollView(showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // 节次列（左侧）
                periodColumn

                // 7 天列
                ForEach(1...7, id: \.self) { day in
                    dayColumn(weekday: day)
                }
            }
            .padding(.bottom, 20)
        }
        .background(SonnetColors.paper)
    }

    // 节次时间列
    private var periodColumn: some View {
        VStack(spacing: 0) {
            // 顶部空白（对齐星期头）
            Color.clear.frame(width: 32, height: 36)

            ForEach(1...12, id: \.self) { period in
                VStack(spacing: 1) {
                    Text("\(period)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SonnetColors.textHint)
                    Text(PeriodInfo.shortTime(for: period))
                        .font(.system(size: 9))
                        .foregroundStyle(SonnetColors.textHint)
                }
                .frame(width: 32, height: gridCellHeight)
            }
        }
    }

    // 单天列
    private func dayColumn(weekday: Int) -> some View {
        let dayLabel = Weekday(rawValue: weekday)?.shortLabel ?? ""
        let isToday = weekday == todayWeekday
        let dayCourses = coursesForDay(weekday: weekday)

        return VStack(spacing: 0) {
            // 星期头
            ZStack {
                if isToday {
                    Circle()
                        .fill(SonnetColors.ink)
                        .frame(width: 24, height: 24)
                }
                Text(dayLabel)
                    .font(.system(size: 12, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? .white : SonnetColors.textCaption)
            }
            .frame(height: 36)

            // 12 个格子，合并多节连续课程
            ZStack(alignment: .top) {
                // 背景格
                VStack(spacing: 0) {
                    ForEach(1...12, id: \.self) { period in
                        Rectangle()
                            .fill(period % 2 == 0 ? SonnetColors.paperCream.opacity(0.5) : Color.clear)
                            .frame(height: gridCellHeight)
                            .overlay(Divider(), alignment: .bottom)
                    }
                }

                // 课程块
                ForEach(dayCourses) { course in
                    courseBlock(course)
                        .offset(y: CGFloat(course.startPeriod - 1) * gridCellHeight)
                        .onTapGesture { editingCourse = course }
                }
            }
            .frame(height: CGFloat(12) * gridCellHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private func courseBlock(_ course: Course) -> some View {
        let colors = CourseColors.color(for: course.colorName)
        let spans = course.endPeriod - course.startPeriod + 1
        let h = CGFloat(spans) * gridCellHeight - 2

        return VStack(alignment: .leading, spacing: 1) {
            Text(course.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(colors.text)
                .lineLimit(2)
            if !course.location.isEmpty {
                Text(course.location)
                    .font(.system(size: 9))
                    .foregroundStyle(colors.text.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: h, alignment: .top)
        .background(colors.bg)
        .overlay(
            Rectangle()
                .fill(colors.text)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 1)
    }

    private let gridCellHeight: CGFloat = 52

    // MARK: - 日视图列表

    private var dayList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // 星期选择条
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Weekday.allCases) { day in
                            let isSel = day.rawValue == selectedDay
                            Button {
                                selectedDay = day.rawValue
                            } label: {
                                VStack(spacing: 1) {
                                    Text(day.shortLabel)
                                        .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                                        .foregroundStyle(isSel ? .white : SonnetColors.textCaption)
                                }
                                .frame(width: 36, height: 36)
                                .background(isSel ? SonnetColors.ink : Color.clear)
                                .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, SonnetDimens.spacingXL)
                }
                .padding(.vertical, 8)

                let displayedCourses = coursesForDay(weekday: selectedDay)
                if displayedCourses.isEmpty {
                    EmptyStateView(title: "今天没有课", subtitle: "点击右上角添加课程")
                        .padding(.top, 60)
                } else {
                    ForEach(displayedCourses) { course in
                        dayRow(course)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(SonnetColors.paper)
    }

    private func dayRow(_ course: Course) -> some View {
        let colors = CourseColors.color(for: course.colorName)
        return Button { editingCourse = course } label: {
            HStack(spacing: 0) {
                // 时间列
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PeriodInfo.shortTime(for: course.startPeriod))
                        .font(.system(size: 12))
                    Text(PeriodInfo.shortTime(for: course.endPeriod, end: true))
                        .font(.system(size: 11))
                        .foregroundStyle(SonnetColors.textHint)
                }
                .frame(width: 48)
                .padding(.trailing, 10)

                // 色条 + 内容
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(colors.text)
                        .frame(width: 3)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name)
                            .font(SonnetTypography.bodyBold)
                            .foregroundStyle(SonnetColors.textTitle)
                        HStack(spacing: 8) {
                            if !course.location.isEmpty {
                                Label(course.location, systemImage: "mappin")
                                    .font(SonnetTypography.caption2)
                                    .foregroundStyle(SonnetColors.textCaption)
                            }
                            if !course.teacher.isEmpty {
                                Text(course.teacher)
                                    .font(SonnetTypography.caption2)
                                    .foregroundStyle(SonnetColors.textHint)
                            }
                        }
                        Text("第 \(course.startPeriod)–\(course.endPeriod) 节")
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(SonnetColors.textHint)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.bg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, SonnetDimens.spacingXL)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据筛选

    private func coursesForDay(weekday: Int) -> [Course] {
        courses.filter {
            $0.weekday == weekday &&
            $0.startWeek <= currentWeek &&
            $0.endWeek   >= currentWeek
        }
    }

    private var todayCoursesCount: Int {
        coursesForDay(weekday: todayWeekday).count
    }
}

// MARK: - 课程颜色系统（8色）

enum CourseColors {
    struct Pair { let text: Color; let bg: Color }

    static let palette: [String: Pair] = [
        "ink":    Pair(text: Color(hex: 0xFF4A5699), bg: Color(hex: 0xFFEEF0F9)),
        "coral":  Pair(text: Color(hex: 0xFFD4734B), bg: Color(hex: 0xFFFFF0ED)),
        "jade":   Pair(text: Color(hex: 0xFF3D9B72), bg: Color(hex: 0xFFEDF7F1)),
        "violet": Pair(text: Color(hex: 0xFF8B6AAD), bg: Color(hex: 0xFFF3EDFA)),
        "rose":   Pair(text: Color(hex: 0xFFCB5B7B), bg: Color(hex: 0xFFFCEDF1)),
        "cyan":   Pair(text: Color(hex: 0xFF4EADAD), bg: Color(hex: 0xFFE8F5F5)),
        "amber":  Pair(text: Color(hex: 0xFFCB8A34), bg: Color(hex: 0xFFFFF8EC)),
        "blue":   Pair(text: Color(hex: 0xFF4A8BBF), bg: Color(hex: 0xFFECF3FC)),
    ]

    static func color(for name: String) -> Pair {
        palette[name] ?? palette["ink"]!
    }

    static let allNames: [String] = ["ink","coral","jade","violet","rose","cyan","amber","blue"]
}

// MARK: - PeriodInfo 时间文字

extension PeriodInfo {
    static func shortTime(for period: Int, end: Bool = false) -> String {
        let starts = [1:"8:00",2:"8:55",3:"10:00",4:"10:55",
                      5:"14:00",6:"14:55",7:"16:00",8:"16:55",
                      9:"19:00",10:"19:55",11:"20:45",12:"21:30"]
        let ends   = [1:"8:45",2:"9:40",3:"10:45",4:"11:40",
                      5:"14:45",6:"15:40",7:"16:45",8:"17:40",
                      9:"19:45",10:"20:40",11:"21:30",12:"22:15"]
        return end ? (ends[period] ?? "--") : (starts[period] ?? "--")
    }
}

#Preview {
    NavigationStack { ScheduleView() }
        .modelContainer(for: Course.self, inMemory: true)
}
