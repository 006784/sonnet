import SwiftUI
import SwiftData

struct ExamEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var editing: Exam? = nil

    @State private var examName = ""
    @State private var courseName = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    heroCard
                    infoSection
                    timeSection
                    noteSection
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
                .padding(.bottom, SonnetDimens.spacingXXL)
            }
            .background(SonnetColors.paper)
            .navigationTitle(editing == nil ? "添加考试" : "编辑考试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SonnetColors.textCaption)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SonnetColors.textHint : SonnetColors.ink)
                        .disabled(courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { loadEditing() }
        }
    }

    private var heroCard: some View {
        StudentHeroCard(
            title: editing == nil ? "把重要日期安静地放进倒计时里" : "把这场考试的信息补得更完整",
            subtitle: "时间、地点和课程会一起出现在考试列表里，临近时更容易一眼看清。",
            icon: "calendar.badge.exclamationmark",
            colorName: "amber"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "课程", value: courseName.isEmpty ? "待填写" : courseName, tint: SonnetColors.amber)
                StudentMetricPill(title: "日期", value: examDateLabel, tint: SonnetColors.ink)
            }
        }
    }

    private var infoSection: some View {
        StudentFormSection(
            title: "考试信息",
            subtitle: "写下课程与考试名称，倒计时会按这些文字生成。"
        ) {
            StudentTextEntry(
                title: "考试名称",
                prompt: "例如 期末考试 / 小测验",
                icon: "text.book.closed",
                accent: SonnetColors.amber,
                emphasizesValue: true,
                text: $examName
            )

            StudentTextEntry(
                title: "课程名称",
                prompt: "例如 数据结构",
                icon: "graduationcap",
                accent: SonnetColors.amber,
                text: $courseName
            )

            StudentTextEntry(
                title: "考场地点",
                prompt: "选填，例如 教三 201",
                icon: "mappin.and.ellipse",
                accent: SonnetColors.amber,
                text: $location
            )
        }
    }

    private var timeSection: some View {
        StudentFormSection(
            title: "考试时间",
            subtitle: "日期和时间会同时用于倒计时显示。",
            footer: "建议把开始时间填准确，首页倒计时会更可信。"
        ) {
            HStack {
                Label("考试日期", systemImage: "clock")
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textBody)

                Spacer()

                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(SonnetColors.amber)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )
        }
    }

    private var noteSection: some View {
        StudentFormSection(
            title: "补充备注",
            subtitle: "把考试范围、座位号或携带物品记下来。",
            footer: "例如：闭卷、带计算器、提前 20 分钟到场。"
        ) {
            StudentTextEntry(
                title: "备注",
                prompt: "选填，写一点考前提醒",
                icon: "note.text",
                accent: SonnetColors.amber,
                axis: .vertical,
                text: $note
            )
        }
    }

    private var examDateLabel: String {
        date.formatted(.dateTime.month().day())
    }

    private func loadEditing() {
        guard let e = editing else { return }
        examName   = e.name
        courseName = e.courseName
        date       = e.date
        location   = e.location
        note       = e.note
    }

    private func save() {
        let trimCourse = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimCourse.isEmpty else { return }
        let trimName = examName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let e = editing {
            e.name       = trimName
            e.courseName = trimCourse
            e.date       = date
            e.location   = trimLocation
            e.note       = trimNote
        } else {
            let exam = Exam(
                name: trimName,
                courseName: trimCourse,
                date: date,
                location: trimLocation,
                note: trimNote
            )
            modelContext.insert(exam)
        }
        try? modelContext.save()
        HapticManager.medium()
        dismiss()
    }
}

#Preview {
    ExamEditSheet()
        .modelContainer(for: Exam.self, inMemory: true)
}
