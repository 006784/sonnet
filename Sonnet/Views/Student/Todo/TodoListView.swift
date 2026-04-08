import SwiftUI
import SwiftData

struct TodoListView: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse)
    private var items: [TodoItem]

    @Environment(\.modelContext) private var modelContext

    @State private var filter: FilterTab    = .all
    @State private var quickTitle: String   = ""
    @State private var showFullEdit         = false
    @State private var editingItem: TodoItem? = nil

    // MARK: - Filter

    enum FilterTab: String, CaseIterable {
        case all     = "全部"
        case today   = "今天"
        case week    = "本周"
        case expired = "已过期"
        case done    = "已完成"
    }

    private var filtered: [TodoItem] {
        let cal        = Calendar.current
        let now        = Date()
        let todayStart = cal.startOfDay(for: now)
        let todayEnd   = cal.date(byAdding: .day, value:  1, to: todayStart)!
        let weekEnd    = cal.date(byAdding: .day, value:  7, to: todayStart)!

        let base = items.filter { item in
            switch filter {
            case .all:     return !item.isCompleted
            case .today:
                if let d = item.dueDate { return !item.isCompleted && d >= todayStart && d < todayEnd }
                return !item.isCompleted && item.createdAt >= todayStart
            case .week:
                if let d = item.dueDate { return !item.isCompleted && d >= todayStart && d < weekEnd }
                return false
            case .expired:
                if let d = item.dueDate { return !item.isCompleted && d < now }
                return false
            case .done:    return item.isCompleted
            }
        }

        return base.sorted { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            switch (a.dueDate, b.dueDate) {
            case (let da?, let db?): return da < db
            case (.some, .none):     return true
            default:                 return false
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            summaryCard
                .padding(.horizontal, SonnetDimens.spacingXL)
                .padding(.top, SonnetDimens.spacingL)

            filterBar
                .padding(.vertical, SonnetDimens.spacingS)
                .background(SonnetColors.paper)

            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { item in
                        SonnetCard {
                            todoRow(item)
                                .padding(.horizontal, SonnetDimens.cardPadding)
                                .padding(.vertical, 8)
                        }
                            .listRowBackground(SonnetColors.paper)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { delete(item) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingItem = item
                                    showFullEdit = true
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(SonnetColors.ink)
                            }
                    }
                    // 底部留白，避免被快捷输入栏遮挡
                    Color.clear.frame(height: 72).listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(SonnetColors.paper)
            }

            quickAddBar
        }
        .background(SonnetColors.paper)
        .navigationTitle("待办清单")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFullEdit, onDismiss: { editingItem = nil }) {
            TodoEditSheet(editing: editingItem)
        }
    }

    private var summaryCard: some View {
        StudentHeroCard(
            title: "待办清单",
            subtitle: "把今天要做的事写清楚，页面会帮你保持先后顺序和轻重缓急。",
            icon: "checklist",
            colorName: "daily"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "未完成", value: "\(pendingCount)", tint: SonnetColors.ink)
                StudentMetricPill(title: "今天到期", value: "\(todayCount)", tint: SonnetColors.amber)
                StudentMetricPill(title: "已过期", value: "\(expiredCount)", tint: SonnetColors.vermilion)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterTab.allCases, id: \.self) { tab in
                    filterCapsule(tab)
                }
            }
            .padding(.horizontal, SonnetDimens.spacingXL)
        }
    }

    private func filterCapsule(_ tab: FilterTab) -> some View {
        let sel = filter == tab
        return Button {
            withAnimation(SonnetMotion.springFast) { filter = tab }
        } label: {
            Text(tab.rawValue)
                .font(.system(size: 13, weight: sel ? .semibold : .regular))
                .foregroundStyle(sel ? SonnetColors.textOnInk : SonnetColors.textSecond)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(sel ? SonnetColors.ink : SonnetColors.paperCream))
        }
    }

    // MARK: - Todo Row

    @ViewBuilder
    private func todoRow(_ item: TodoItem) -> some View {
        HStack(alignment: .center, spacing: SonnetDimens.spacingM) {
            // 完成按钮
            completionButton(item)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(SonnetTypography.body)
                    .foregroundStyle(item.isCompleted ? SonnetColors.textHint : SonnetColors.textTitle)
                    .strikethrough(item.isCompleted, color: SonnetColors.textHint)
                    .lineLimit(2)

                // 标签行
                rowTagLine(item)
            }

            Spacer()
        }
        .frame(minHeight: 56)
        .padding(.vertical, SonnetDimens.spacingXS)
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
            showFullEdit = true
        }
    }

    private func completionButton(_ item: TodoItem) -> some View {
        Button {
            withAnimation(SonnetMotion.spring) {
                item.isCompleted.toggle()
                item.completedAt = item.isCompleted ? Date() : nil
                try? modelContext.save()
            }
            HapticManager.impact(.light)
        } label: {
            ZStack {
                if item.isCompleted {
                    Circle()
                        .fill(SonnetColors.jade)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // 脉冲动画（仅紧急）
                    if item.priority == 2 {
                        PulseRing()
                    }
                    Circle()
                        .stroke(priorityBorderColor(item.priority), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
    }

    @ViewBuilder
    private func rowTagLine(_ item: TodoItem) -> some View {
        let tags = tagInfos(item)
        if !tags.isEmpty {
            HStack(spacing: 6) {
                ForEach(tags, id: \.label) { info in
                    Text(info.label)
                        .font(.system(size: 11))
                        .foregroundStyle(info.textColor)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(info.bgColor)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // ── 优先级颜色 ───────────────────────────────────────
    private func priorityBorderColor(_ p: Int) -> Color {
        switch p {
        case 2: return SonnetColors.vermilion
        case 1: return SonnetColors.amber
        default: return SonnetColors.textHint
        }
    }

    // ── 标签信息 ─────────────────────────────────────────
    private struct TagInfo { let label: String; let textColor: Color; let bgColor: Color }

    private func tagInfos(_ item: TodoItem) -> [TagInfo] {
        var result: [TagInfo] = []

        // 课程/标签
        if !item.tag.isEmpty && item.tag != "学习" {
            let c = SonnetColors.categoryColors("education")
            result.append(.init(label: item.tag, textColor: c.icon, bgColor: c.bg))
        }

        // 截止日期
        if let due = item.dueDate, !item.isCompleted {
            let cal = Calendar.current
            let now = Date()
            if due < now {
                result.append(.init(label: "已过期", textColor: SonnetColors.vermilion, bgColor: SonnetColors.vermilionLight))
            } else if cal.isDateInToday(due) {
                result.append(.init(label: "今天", textColor: SonnetColors.amber, bgColor: SonnetColors.amberLight))
            } else if cal.isDateInTomorrow(due) {
                result.append(.init(label: "明天", textColor: SonnetColors.textSecond, bgColor: SonnetColors.paperCream))
            } else {
                let fmt = DateFormatter(); fmt.dateFormat = "M月d日"
                result.append(.init(label: fmt.string(from: due), textColor: SonnetColors.textCaption, bgColor: SonnetColors.paperCream))
            }
        }

        // 优先级标签
        if item.priority == 2 {
            result.append(.init(label: "紧急", textColor: SonnetColors.vermilion, bgColor: SonnetColors.vermilionLight))
        } else if item.priority == 1 {
            result.append(.init(label: "重要", textColor: SonnetColors.amber, bgColor: SonnetColors.amberLight))
        }

        return result
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: SonnetDimens.spacingM) {
            // 更多
            Button { showFullEdit = true } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(SonnetColors.textHint)
            }

            // 输入框
            TextField("添加新待办...", text: $quickTitle)
                .font(SonnetTypography.body)
                .onSubmit { quickAdd() }

            // 发送
            Button { quickAdd() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(quickTitle.isEmpty ? SonnetColors.textHint : SonnetColors.ink)
            }
            .disabled(quickTitle.isEmpty)
        }
        .padding(.horizontal, SonnetDimens.spacingL)
        .padding(.vertical, SonnetDimens.spacingM)
        .background(SonnetColors.paperWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SonnetColors.paperLine, lineWidth: 0.5)
        )
        .padding(SonnetDimens.spacingL)
        .background(SonnetColors.paper)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        let title: String
        let subtitle: String
        switch filter {
        case .done:    title = "还没有完成的任务";  subtitle = "完成一条任务，它会出现在这里"
        case .expired: title = "没有过期任务";       subtitle = "很棒！所有任务都在掌控中"
        case .today:   title = "今天没有待办";       subtitle = "休息一下，或者添加一条新任务"
        default:       title = "待办清单是空的";     subtitle = "点击下方输入框，添加第一条"
        }
        return EmptyStateView(title: title, subtitle: subtitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func quickAdd() {
        guard !quickTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let item = TodoItem(title: quickTitle.trimmingCharacters(in: .whitespaces))
        modelContext.insert(item)
        try? modelContext.save()
        HapticManager.impact(.light)
        withAnimation(SonnetMotion.spring) { quickTitle = "" }
    }

    private func delete(_ item: TodoItem) {
        withAnimation(SonnetMotion.spring) {
            modelContext.delete(item)
            try? modelContext.save()
        }
    }

    private var pendingCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    private var todayCount: Int {
        let cal = Calendar.current
        return items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return !item.isCompleted && cal.isDateInToday(dueDate)
        }.count
    }

    private var expiredCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return !item.isCompleted && dueDate < startOfToday
        }.count
    }
}

// MARK: - Pulse Ring（紧急项脉冲动画）

private struct PulseRing: View {
    @State private var scale: CGFloat = 1

    var body: some View {
        Circle()
            .stroke(SonnetColors.vermilion.opacity(0.35), lineWidth: 1)
            .frame(width: 32, height: 32)
            .scaleEffect(scale)
            .opacity(2 - Double(scale))
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.1).repeatForever(autoreverses: false)
                ) { scale = 1.6 }
            }
    }
}

#Preview {
    NavigationStack { TodoListView() }
        .modelContainer(for: [TodoItem.self], inMemory: true)
}
