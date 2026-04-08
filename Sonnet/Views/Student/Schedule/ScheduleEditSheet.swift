import SwiftUI
import SwiftData

struct ScheduleEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var editingCourse: Course? = nil

    @State private var name = ""
    @State private var teacher = ""
    @State private var location = ""
    @State private var weekday = 1
    @State private var startPeriod = 1
    @State private var endPeriod = 2
    @State private var colorName = "ink"
    @State private var semester = ""
    @State private var startWeek = 1
    @State private var endWeek = 16
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    heroCard
                    courseInfoSection
                    scheduleSection
                    termSection
                    noteSection
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
                .padding(.bottom, SonnetDimens.spacingXXL)
            }
            .background(SonnetColors.paper)
            .navigationTitle(editingCourse == nil ? "添加课程" : "编辑课程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SonnetColors.textCaption)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SonnetColors.textHint : SonnetColors.ink)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { loadEditing() }
        }
    }

    private var heroCard: some View {
        StudentHeroCard(
            title: editingCourse == nil ? "新课程将落在这一周里" : "把这门课整理得更清楚一点",
            subtitle: "时间、地点和周次会被写进同一张课表卡片里，提醒也会随之更新。",
            icon: "calendar.badge.clock",
            colorName: colorName
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "星期", value: weekdayLabel, tint: selectedColors.text)
                StudentMetricPill(title: "节次", value: "\(startPeriod)-\(endPeriod) 节", tint: selectedColors.text)
                StudentMetricPill(title: "周次", value: "\(startWeek)-\(endWeek) 周", tint: selectedColors.text)
            }
        }
    }

    private var courseInfoSection: some View {
        StudentFormSection(
            title: "课程信息",
            subtitle: "先写下名字，再慢慢补全老师和地点。"
        ) {
            StudentTextEntry(
                title: "课程名称",
                prompt: "例如 高等数学",
                icon: "text.book.closed",
                accent: selectedColors.text,
                emphasizesValue: true,
                text: $name
            )

            StudentTextEntry(
                title: "授课教师",
                prompt: "选填，例如 王老师",
                icon: "person",
                accent: selectedColors.text,
                text: $teacher
            )

            StudentTextEntry(
                title: "上课地点",
                prompt: "选填，例如 教一 302",
                icon: "mappin.and.ellipse",
                accent: selectedColors.text,
                text: $location
            )
        }
    }

    private var scheduleSection: some View {
        StudentFormSection(
            title: "时间安排",
            subtitle: "选好上课日和起止节次，课表会自动按周归位。"
        ) {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                Text("上课日")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SonnetDimens.spacingS) {
                        ForEach(Weekday.allCases) { day in
                            StudentChoiceChip(
                                title: day.label,
                                systemImage: day.rawValue == weekday ? "checkmark" : nil,
                                isSelected: weekday == day.rawValue,
                                tint: selectedColors.text
                            ) {
                                withAnimation(SonnetMotion.springFast) {
                                    weekday = day.rawValue
                                }
                                HapticManager.selection()
                            }
                        }
                    }
                }
            }

            StudentFormDivider()

            stepperRow(
                title: "开始节次",
                subtitle: "第 \(startPeriod) 节 · \(PeriodInfo.shortTime(for: startPeriod))",
                value: startPeriodBinding,
                range: 1...11
            )

            StudentFormDivider()

            stepperRow(
                title: "结束节次",
                subtitle: "第 \(endPeriod) 节 · \(PeriodInfo.shortTime(for: endPeriod, end: true))",
                value: $endPeriod,
                range: startPeriod...12
            )
        }
    }

    private var termSection: some View {
        StudentFormSection(
            title: "周次与样式",
            subtitle: "学期和颜色会决定这张课程卡在整学期里的气质。",
            footer: "颜色只影响展示，不会影响课程排序。"
        ) {
            StudentTextEntry(
                title: "学期",
                prompt: "例如 2026 春",
                icon: "calendar",
                accent: selectedColors.text,
                text: $semester
            )

            StudentFormDivider()

            stepperRow(
                title: "起始周",
                subtitle: "从第 \(startWeek) 周开始出现",
                value: startWeekBinding,
                range: 1...19
            )

            StudentFormDivider()

            stepperRow(
                title: "结束周",
                subtitle: "持续到第 \(endWeek) 周",
                value: $endWeek,
                range: startWeek...20
            )

            StudentFormDivider()

            VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                Text("课程颜色")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
                colorPicker
            }
        }
    }

    private var noteSection: some View {
        StudentFormSection(
            title: "补充备注",
            subtitle: "把课堂提醒、分组信息或老师习惯写在这里。",
            footer: "备注会显示在课程详情里，方便临近上课时快速回看。"
        ) {
            StudentTextEntry(
                title: "备注",
                prompt: "例如 记得带计算器 / 双周上课",
                icon: "note.text",
                accent: selectedColors.text,
                axis: .vertical,
                text: $note
            )
        }
    }

    // MARK: - 颜色选择器

    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SonnetDimens.spacingS), count: 4), spacing: SonnetDimens.spacingS) {
            ForEach(CourseColors.allNames, id: \.self) { cn in
                let pair = CourseColors.color(for: cn)
                let isSelected = colorName == cn
                Button {
                    withAnimation(SonnetMotion.springFast) { colorName = cn }
                    HapticManager.selection()
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(pair.bg)
                                .frame(width: 28, height: 28)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(pair.text)
                                .frame(width: 14, height: 14)
                        }

                        Spacer(minLength: 0)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(pair.text)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(SonnetColors.paperWhite)
                .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                        .stroke(isSelected ? pair.text : SonnetColors.paperLine, lineWidth: isSelected ? 1.2 : 0.5)
                )
                .shadow(color: isSelected ? pair.text.opacity(0.12) : .clear, radius: 6, y: 3)
            }
        }
    }

    private var selectedColors: CourseColors.Pair {
        CourseColors.color(for: colorName)
    }

    private var weekdayLabel: String {
        Weekday.allCases.first(where: { $0.rawValue == weekday })?.label ?? "周\(weekday)"
    }

    private var startPeriodBinding: Binding<Int> {
        Binding(
            get: { startPeriod },
            set: { newValue in
                startPeriod = newValue
                if endPeriod < newValue { endPeriod = newValue }
            }
        )
    }

    private var startWeekBinding: Binding<Int> {
        Binding(
            get: { startWeek },
            set: { newValue in
                startWeek = newValue
                if endWeek < newValue { endWeek = newValue }
            }
        )
    }

    private func stepperRow(
        title: String,
        subtitle: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper(value: value, in: range) {
            HStack(spacing: SonnetDimens.spacingM) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SonnetTypography.body)
                        .foregroundStyle(SonnetColors.textTitle)
                    Text(subtitle)
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(SonnetColors.textCaption)
                }

                Spacer()

                Text("\(value.wrappedValue)")
                    .font(SonnetTypography.amountBody)
                    .foregroundStyle(selectedColors.text)
                    .monospacedDigit()
            }
        }
        .tint(selectedColors.text)
    }

    // MARK: - 数据

    private func loadEditing() {
        guard let c = editingCourse else { return }
        name        = c.name
        teacher     = c.teacher
        location    = c.location
        weekday     = c.weekday
        startPeriod = c.startPeriod
        endPeriod   = c.endPeriod
        colorName   = c.colorName
        semester    = c.semester
        startWeek   = c.startWeek
        endWeek     = c.endWeek
        note        = c.note
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let c = editingCourse {
            c.name        = trimmedName
            c.teacher     = teacher.trimmingCharacters(in: .whitespacesAndNewlines)
            c.location    = location.trimmingCharacters(in: .whitespacesAndNewlines)
            c.weekday     = weekday
            c.startPeriod = startPeriod
            c.endPeriod   = endPeriod
            c.colorName   = colorName
            c.semester    = semester.trimmingCharacters(in: .whitespacesAndNewlines)
            c.startWeek   = startWeek
            c.endWeek     = endWeek
            c.note        = note.trimmingCharacters(in: .whitespacesAndNewlines)
            NotificationService.shared.scheduleClassReminder(course: c)
        } else {
            let course = Course(
                name: trimmedName,
                teacher: teacher.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                weekday: weekday, startPeriod: startPeriod, endPeriod: endPeriod,
                colorName: colorName,
                semester: semester.trimmingCharacters(in: .whitespacesAndNewlines),
                startWeek: startWeek, endWeek: endWeek
            )
            course.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            modelContext.insert(course)
            NotificationService.shared.scheduleClassReminder(course: course)
        }
        try? modelContext.save()
        HapticManager.medium()
        dismiss()
    }
}

#Preview {
    ScheduleEditSheet()
        .modelContainer(for: Course.self, inMemory: true)
}
