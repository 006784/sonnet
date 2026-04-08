import SwiftUI
import SwiftData

struct TodoEditSheet: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Course.name) private var courses: [Course]

    var editing: TodoItem? = nil

    @State private var title      = ""
    @State private var detail     = ""        // 对应 model.note
    @State private var hasDueDate = false
    @State private var dueDate    = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var priority   = 0
    @State private var tag        = "学习"

    private let builtInTags = ["学习", "生活", "其他"]

    // 优先级元数据
    private let priorities: [(label: String, icon: String, color: Color)] = [
        ("普通", "circle",              SonnetColors.textHint),
        ("重要", "exclamationmark",     SonnetColors.amber),
        ("紧急", "exclamationmark.2",   SonnetColors.vermilion),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    heroCard
                    titleSection
                    prioritySection
                    dueDateSection
                    tagSection
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
                .padding(.bottom, SonnetDimens.spacingXXL)
            }
            .background(SonnetColors.paper)
            .navigationTitle(editing == nil ? "新建待办" : "编辑待办")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SonnetColors.textSecond)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(title.isEmpty ? SonnetColors.textHint : SonnetColors.ink)
                        .disabled(title.isEmpty)
                }
            }
            .onAppear { loadEditing() }
        }
    }

    private var heroCard: some View {
        StudentHeroCard(
            title: editing == nil ? "先写下今天最想完成的一件事" : "把任务重新排得更清楚一些",
            subtitle: "优先级、截止时间和标签会一起决定它在今日节奏里的位置。",
            icon: "checklist",
            colorName: priorityColorName
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "优先级", value: priorities[priority].label, tint: priorities[priority].color)
                StudentMetricPill(title: "标签", value: tag, tint: SonnetColors.ink)
                StudentMetricPill(title: "截止", value: dueDateSummary, tint: hasDueDate ? SonnetColors.amber : SonnetColors.textCaption)
            }
        }
    }

    // MARK: - 标题区

    private var titleSection: some View {
        StudentFormSection(
            title: "任务内容",
            subtitle: "一句清楚的标题，往往比长长一段自我提醒更有用。"
        ) {
            StudentTextEntry(
                title: "任务标题",
                prompt: "例如 把实验报告交上去",
                icon: "square.and.pencil",
                accent: SonnetColors.ink,
                emphasizesValue: true,
                text: $title
            )

            StudentTextEntry(
                title: "详细说明",
                prompt: "选填，写一点背景或拆分步骤",
                icon: "text.alignleft",
                accent: SonnetColors.ink,
                axis: .vertical,
                text: $detail
            )
        }
    }

    // MARK: - 优先级区

    private var prioritySection: some View {
        StudentFormSection(
            title: "优先级",
            subtitle: "真正紧急的事情应该一眼能被看见。"
        ) {
            HStack(spacing: SonnetDimens.spacingS) {
                ForEach(priorities.indices, id: \.self) { index in
                    priorityChip(index: index)
                }
            }
        }
    }

    private func priorityChip(index: Int) -> some View {
        let info = priorities[index]
        return StudentChoiceChip(
            title: info.label,
            systemImage: info.icon,
            isSelected: priority == index,
            tint: info.color
        ) {
            withAnimation(SonnetMotion.springFast) { priority = index }
            HapticManager.selection()
        }
    }

    // MARK: - 截止日期区

    private var dueDateSection: some View {
        StudentFormSection(
            title: "截止日期",
            subtitle: "需要时间感的任务，最好让它带上一点明确的边界。",
            footer: "如果先不确定时间，也可以先不设置。"
        ) {
            HStack {
                Label("设置截止日期", systemImage: "calendar")
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textBody)
                Spacer()
                Toggle("", isOn: $hasDueDate)
                    .labelsHidden()
                    .tint(SonnetColors.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )

            if hasDueDate {
                DatePicker(
                    "",
                    selection: $dueDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(SonnetColors.ink)
                .padding(.horizontal, SonnetDimens.spacingS)
            }
        }
    }

    // MARK: - 标签区

    private var tagSection: some View {
        StudentFormSection(
            title: "标签 / 课程",
            subtitle: "把待办挂到某门课下，复盘时会更自然。"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SonnetDimens.spacingS) {
                    ForEach(allTags, id: \.self) { t in
                        tagChip(t)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var allTags: [String] {
        var tags = builtInTags
        let courseNames = courses.map { $0.name }
        tags.append(contentsOf: courseNames.filter { !tags.contains($0) })
        return tags
    }

    private func tagChip(_ t: String) -> some View {
        StudentChoiceChip(
            title: t,
            systemImage: tag == t ? "checkmark" : nil,
            isSelected: tag == t,
            tint: SonnetColors.ink
        ) {
            withAnimation(SonnetMotion.springFast) { tag = t }
        }
    }

    // MARK: - Data

    private var priorityColorName: String {
        switch priority {
        case 2: return "gift"
        case 1: return "invest"
        default: return "education"
        }
    }

    private var dueDateSummary: String {
        guard hasDueDate else { return "未设置" }
        return dueDate.formatted(.dateTime.month().day())
    }

    private func loadEditing() {
        guard let e = editing else { return }
        title      = e.title
        detail     = e.note
        priority   = e.priority
        tag        = e.tag
        if let d = e.dueDate { hasDueDate = true; dueDate = d }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = editing {
            e.title    = trimmedTitle
            e.note     = trimmedDetail
            e.priority = priority
            e.tag      = tag
            e.dueDate  = hasDueDate ? dueDate : nil
        } else {
            let item = TodoItem(
                title:    trimmedTitle,
                note:     trimmedDetail,
                dueDate:  hasDueDate ? dueDate : nil,
                priority: priority,
                tag:      tag
            )
            modelContext.insert(item)
        }
        try? modelContext.save()
        HapticManager.medium()
        dismiss()
    }
}

#Preview {
    TodoEditSheet()
        .modelContainer(for: [TodoItem.self, Course.self], inMemory: true)
}
