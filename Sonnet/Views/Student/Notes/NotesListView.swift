import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var allNotes: [Note]
    @Query(sort: [SortDescriptor(\StudyFile.createdAt, order: .reverse)])
    private var allFiles: [StudyFile]

    @State private var selectedTab: NoteTab = .notes
    @State private var searchText: String = ""
    @State private var selectedCourse: String = "全部"
    @State private var createNote = false
    @State private var editingNote: Note? = nil
    @State private var selectedStudyFile: StudyFile? = nil

    enum NoteTab: String, CaseIterable {
        case notes = "笔记"
        case files = "资料"
    }

    init() {
        _allNotes = Query(sort: [
            SortDescriptor(\Note.updatedAt, order: .reverse)
        ])
    }

    // MARK: – Computed

    private var courseNames: [String] {
        let courses = Set(
            allNotes.compactMap { $0.courseName.isEmpty ? nil : $0.courseName } +
            allFiles.compactMap { $0.courseName.isEmpty ? nil : $0.courseName }
        )
        return ["全部"] + courses.sorted()
    }

    private var filteredNotes: [Note] {
        var list = allNotes
        if selectedCourse != "全部" {
            list = list.filter { $0.courseName == selectedCourse }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(q) ||
                $0.content.localizedCaseInsensitiveContains(q) ||
                $0.courseName.localizedCaseInsensitiveContains(q)
            }
        }
        return list.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private var filteredFiles: [StudyFile] {
        var list = allFiles
        if selectedCourse != "全部" {
            list = list.filter { $0.courseName == selectedCourse }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.courseName.localizedCaseInsensitiveContains(query)
            }
        }
        return list
    }

    private var recentLinkedFiles: [StudyFile] {
        Array(filteredFiles.prefix(6))
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryCard
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)

            // ── Tab 切换 ──────────────────────────────────
            SonnetCard {
                Picker("", selection: $selectedTab) {
                    ForEach(NoteTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, SonnetDimens.cardPadding)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(SonnetColors.paper)

            if selectedTab == .notes {
                notesContent
            } else {
                StudyFilesView(selectedCourse: selectedCourse, searchText: searchText)
            }
        }
        .background(SonnetColors.paper)
        .navigationTitle("课堂笔记")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索笔记标题、内容")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { createNote = true } label: {
                    Image(systemName: "square.and.pencil")
                        .fontWeight(.semibold)
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
        .navigationDestination(isPresented: $createNote) {
            NoteEditorView(editingNote: nil)
        }
        .navigationDestination(item: $editingNote) { note in
            NoteEditorView(editingNote: note)
        }
        .navigationDestination(item: $selectedStudyFile) { file in
            StudyFileDetailView(file: file)
        }
    }

    private var summaryCard: some View {
        StudentHeroCard(
            title: "课堂笔记",
            subtitle: selectedTab == .notes ? "把课堂上的重点、灵感和图片资料安静地收在一起。" : "把课件、照片和资料按课程整理到同一页。",
            icon: selectedTab == .notes ? "note.text" : "folder",
            colorName: "salary"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "笔记数", value: "\(allNotes.count)", tint: SonnetColors.ink)
                StudentMetricPill(title: "资料数", value: "\(allFiles.count)", tint: SonnetColors.amber)
                StudentMetricPill(
                    title: selectedTab == .notes ? "课程数" : "当前视图",
                    value: selectedTab == .notes ? recentLinkedFilesTitle : selectedTab.rawValue,
                    tint: SonnetColors.jade
                )
            }
        }
    }

    // MARK: – Notes content

    @ViewBuilder
    private var notesContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if courseNames.count > 1 {
                    courseFilterChips
                        .padding(.bottom, 12)
                }

                if !recentLinkedFiles.isEmpty {
                    relatedMaterialsStrip
                        .padding(.bottom, 16)
                }

                if filteredNotes.isEmpty {
                    EmptyStateView(
                        icon: "note.text",
                        title: searchText.isEmpty ? "还没有笔记" : "没有匹配的笔记",
                        subtitle: searchText.isEmpty ? "点击右上角 ✏️ 开始记录" : "换个关键词试试"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredNotes) { note in
                            NoteCardView(note: note, onTap: { editingNote = note },
                                         onDelete: { deleteNote(note) },
                                         onTogglePin: { togglePin(note) })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 4)
        }
    }

    private var relatedMaterialsStrip: some View {
        VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
            HStack {
                StudentSectionHeader(
                    title: selectedCourse == "全部" ? "最近导入的资料" : "\(selectedCourse) 的资料",
                    subtitle: selectedCourse == "全部" ? "最近上传的课件、照片和 PDF 会出现在这里。" : "同一门课的资料和笔记会自然靠近。"
                )
                Spacer()
                Button {
                    withAnimation(SonnetMotion.spring) {
                        selectedTab = .files
                    }
                } label: {
                    Text("看全部")
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SonnetDimens.pageHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SonnetDimens.spacingS) {
                    ForEach(recentLinkedFiles) { file in
                        relatedMaterialCard(file)
                    }
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
            }
        }
    }

    private func relatedMaterialCard(_ file: StudyFile) -> some View {
        let colors = materialColors(for: file.fileType)

        return Button {
            selectedStudyFile = file
        } label: {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colors.bg)
                        .frame(width: 40, height: 40)
                    Image(systemName: fileTypeSymbol(for: file.fileType))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(colors.icon)
                }

                Text(file.name)
                    .font(SonnetTypography.bodyBold)
                    .foregroundStyle(SonnetColors.textTitle)
                    .lineLimit(2)

                Text(file.courseName.isEmpty ? "未分类" : file.courseName)
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textCaption)
                    .lineLimit(1)
            }
            .padding(SonnetDimens.spacingM)
            .frame(width: 170, alignment: .leading)
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge, style: .continuous)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: – Course filter chips

    private var courseFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(courseNames, id: \.self) { name in
                    let isSelected = selectedCourse == name
                    Button { selectedCourse = name } label: {
                        Text(name)
                            .font(SonnetTypography.caption1)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? SonnetColors.textOnInk : SonnetColors.textSecond)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(isSelected ? SonnetColors.ink : SonnetColors.paperCream)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(SonnetMotion.springFast, value: selectedCourse)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: – Actions

    private func deleteNote(_ note: Note) {
        withAnimation(SonnetMotion.spring) {
            modelContext.delete(note)
            try? modelContext.save()
        }
    }

    private func togglePin(_ note: Note) {
        withAnimation(SonnetMotion.spring) {
            note.isPinned.toggle()
            try? modelContext.save()
        }
    }

    private var recentLinkedFilesTitle: String {
        selectedTab == .notes ? "\(max(courseNames.count - 1, 0)) 门课" : selectedTab.rawValue
    }

    private func fileTypeSymbol(for type: String) -> String {
        switch type {
        case "pdf": return "doc.richtext"
        case "image": return "photo"
        default: return "doc.text"
        }
    }

    private func materialColors(for type: String) -> (icon: Color, bg: Color) {
        switch type {
        case "pdf":
            return (SonnetColors.vermilion, SonnetColors.vermilionLight)
        case "image":
            return (SonnetColors.ink, SonnetColors.inkWash)
        default:
            return (SonnetColors.jade, SonnetColors.jadeLight)
        }
    }
}

// MARK: – Note Card

struct NoteCardView: View {
    let note: Note
    let onTap: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    private var colors: (icon: Color, bg: Color) {
        SonnetColors.categoryColors(note.colorName)
    }

    var body: some View {
        SonnetCard {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    // Header row
                    HStack(alignment: .center, spacing: 8) {
                        // Course tag
                        if !note.courseName.isEmpty {
                            Text(note.courseName)
                                .font(SonnetTypography.caption2)
                                .foregroundStyle(colors.icon)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(colors.bg)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Spacer()

                        Text(shortDate(note.updatedAt))
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(SonnetColors.textHint)

                        // More menu
                        Menu {
                            Button {
                                onTogglePin()
                            } label: {
                                Label(note.isPinned ? "取消置顶" : "置顶",
                                      systemImage: note.isPinned ? "pin.slash" : "pin.fill")
                            }
                            Divider()
                            Button(role: .destructive, action: onDelete) {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(SonnetColors.textHint)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                    }

                    // Title
                    HStack(spacing: 6) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(colors.icon)
                        }
                        Text(note.title.isEmpty ? "无标题" : note.title)
                            .font(SonnetTypography.bodyBold)
                            .foregroundStyle(SonnetColors.textTitle)
                            .lineLimit(1)
                    }

                    // Content preview
                    if !note.content.isEmpty {
                        Text(note.content)
                            .font(SonnetTypography.footnote)
                            .foregroundStyle(SonnetColors.textSecond)
                            .lineLimit(2)
                    }

                    // Image thumbnails
                    if !note.imageData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(note.imageData.indices, id: \.self) { idx in
                                    if let uiImg = UIImage(data: note.imageData[idx]) {
                                        Image(uiImage: uiImg)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }

                    // AI summary badge
                    if let summary = note.aiSummary, !summary.isEmpty {
                        HStack(spacing: 4) {
                            Text("✦")
                                .font(.system(size: 10))
                                .foregroundStyle(SonnetColors.ink)
                            Text("AI 摘要")
                                .font(SonnetTypography.caption2)
                                .foregroundStyle(SonnetColors.ink)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(SonnetColors.inkWash)
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
        }
        .background(note.isPinned ? SonnetColors.inkWash.opacity(0.4) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge))
    }

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return fmt.string(from: date)
        } else if cal.isDateInYesterday(date) {
            return "昨天"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "M/d"
            return fmt.string(from: date)
        }
    }
}

// MARK: – Preview

#Preview {
    NavigationStack { NotesListView() }
        .modelContainer(for: [Note.self, StudyFile.self], inMemory: true)
}
