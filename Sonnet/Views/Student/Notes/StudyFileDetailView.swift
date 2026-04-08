import SwiftUI
import SwiftData
import PDFKit

struct StudyFileDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Course.name)]) private var courses: [Course]

    let file: StudyFile

    @State private var pdfBridge = PDFAnnotationBridge()
    @State private var localURL: URL? = nil
    @State private var previewURL: URL? = nil
    @State private var pdfPageCount = 0
    @State private var showingMetadataEditor = false
    @State private var showingAnnotationComposer = false
    @State private var annotationDraft = ""
    @State private var tempURL: URL? = nil
    @State private var isRunningMaterialAI = false
    @State private var materialActionError = ""
    @State private var showingActionError = false
    @State private var presentedNote: MaterialNoteTarget? = nil

    private let aiService = AIService()

    init(file: StudyFile) {
        self.file = file
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SonnetDimens.spacingL) {
                detailHero
                previewSection
                if file.fileType == "pdf" {
                    annotationSection
                }
                noteWorkflowSection
                metadataSection
                actionSection
            }
            .padding(.horizontal, SonnetDimens.pageHorizontal)
            .padding(.top, SonnetDimens.spacingL)
            .padding(.bottom, SonnetDimens.spacingXXL)
        }
        .background(SonnetColors.paper)
        .navigationTitle("资料详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingMetadataEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
        .sheet(item: $previewURL) { url in
            QuickLookView(url: url)
        }
        .sheet(isPresented: $showingMetadataEditor) {
            MaterialMetadataEditorSheet(
                file: file,
                suggestions: courseSuggestions,
                onSave: saveMetadata(name:courseName:)
            )
        }
        .sheet(isPresented: $showingAnnotationComposer) {
            MaterialAnnotationSheet(
                fileName: baseTitle,
                selectedText: pdfBridge.hasSelection ? pdfBridge.selectionPreview : nil
            ) { text in
                addTextAnnotation(text)
            }
        }
        .sheet(item: $presentedNote) { target in
            NavigationStack {
                NoteEditorView(editingNote: target.note)
            }
        }
        .alert("暂时无法完成", isPresented: $showingActionError) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(materialActionError)
        }
        .onAppear(perform: prepareLocalURL)
        .onDisappear(perform: cleanupTempURL)
    }

    private var detailHero: some View {
        StudentHeroCard(
            title: file.name,
            subtitle: heroSubtitle,
            icon: fileTypeSymbol,
            colorName: heroColorName
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "类型", value: fileTypeLabel, tint: heroTint)
                StudentMetricPill(title: "大小", value: formattedSize, tint: SonnetColors.amber)
                StudentMetricPill(title: "课程", value: file.courseName.isEmpty ? "未分类" : file.courseName, tint: SonnetColors.jade)
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        StudentFormSection(
            title: "内容预览",
            subtitle: previewSubtitle,
            footer: file.fileType == "pdf" ? "PDF 已支持应用内阅读、选中文本高亮、下划线和文字批注；批注会直接写回当前资料。" : nil
        ) {
            if file.fileType == "pdf", let localURL {
                AnnotatablePDFReaderView(url: localURL, bridge: pdfBridge)
                    .frame(minHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge, style: .continuous)
                            .stroke(SonnetColors.paperLine, lineWidth: 0.5)
                    )
            } else if file.fileType == "image", let image = loadedUIImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(SonnetDimens.spacingM)
                    .background(SonnetColors.paperWhite)
                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge, style: .continuous)
                            .stroke(SonnetColors.paperLine, lineWidth: 0.5)
                    )
            } else {
                VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
                    HStack(spacing: SonnetDimens.spacingM) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(heroBackground)
                                .frame(width: 44, height: 44)
                            Image(systemName: fileTypeSymbol)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(heroTint)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前文件使用系统预览")
                                .font(SonnetTypography.bodyBold)
                                .foregroundStyle(SonnetColors.textTitle)
                            Text("Word、表格和其他文档会通过 Quick Look 查看，也可以继续分享给外部应用。")
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(SonnetColors.textCaption)
                                .lineSpacing(4)
                        }
                    }

                    InkButton(title: "打开预览", action: quickLookFile, style: .ghost)
                }
            }
        }
    }

    @ViewBuilder
    private var annotationSection: some View {
        StudentFormSection(
            title: "PDF 批注",
            subtitle: "先在页面里选中文本，再决定是高亮、下划线，还是留下自己的批注。",
            footer: "如果没有先选中文字，高亮和下划线不会生效；文字批注会插入到当前页。撤回只影响你这次刚加上的批注。"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "页码", value: pdfBridge.pageLabel, tint: SonnetColors.vermilion)
                StudentMetricPill(title: "本页批注", value: "\(pdfBridge.currentPageAnnotationCount)", tint: SonnetColors.ink)
                StudentMetricPill(title: "状态", value: pdfBridge.hasSelection ? "已选中" : "等待选择", tint: pdfBridge.hasSelection ? SonnetColors.jade : SonnetColors.textCaption)
            }

            SonnetCard {
                VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                    HStack(spacing: 8) {
                        Image(systemName: pdfBridge.hasSelection ? "text.cursor" : "hand.tap")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(pdfBridge.hasSelection ? SonnetColors.ink : SonnetColors.textCaption)
                        Text(pdfBridge.hasSelection ? "当前选中" : "操作提示")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                    }

                    Text(pdfBridge.hasSelection ? pdfBridge.selectionPreview : "先在 PDF 里按住并拖拽选择文本，再点高亮或下划线。想补自己的想法，可以直接添加文字批注。")
                        .font(SonnetTypography.body)
                        .foregroundStyle(SonnetColors.textBody)
                        .lineSpacing(4)
                }
                .padding(SonnetDimens.cardPadding)
            }

            HStack(spacing: SonnetDimens.spacingM) {
                MaterialActionCard(
                    title: "高亮选中",
                    subtitle: "标出重点概念",
                    icon: "highlighter",
                    tint: SonnetColors.amber
                ) {
                    applyMarkup(.highlight)
                }

                MaterialActionCard(
                    title: "下划线",
                    subtitle: "留住定义与公式",
                    icon: "underline",
                    tint: SonnetColors.ink
                ) {
                    applyMarkup(.underline)
                }
            }

            InkButton(title: "添加文字批注", action: {
                annotationDraft = ""
                showingAnnotationComposer = true
            }, style: .ghost)

            InkButton(title: "撤回上一步", action: undoLastAnnotation, style: .danger)
                .disabled(!pdfBridge.canUndoLastAction)
                .opacity(pdfBridge.canUndoLastAction ? 1 : 0.42)
        }
    }

    private var noteWorkflowSection: some View {
        StudentFormSection(
            title: "转为笔记",
            subtitle: "把资料转成可继续编辑的课堂笔记，或直接把 PDF 摘要送进笔记页。",
            footer: file.fileType == "pdf" ? "摘要会先提取 PDF 文本，再用你当前配置的 AI 模型压成复习版笔记。" : "图片资料会连同图片一起带进笔记里，文档资料则会带上归档信息和手写留白。"
        ) {
            MaterialActionCard(
                title: "资料转笔记",
                subtitle: "生成一页可继续整理的课堂草稿",
                icon: "note.text.badge.plus",
                tint: SonnetColors.jade,
                isLoading: false,
                isWide: true
            ) {
                createNoteFromMaterial()
            }

            if file.fileType == "pdf" {
                MaterialActionCard(
                    title: "PDF 摘要入笔记",
                    subtitle: "提炼核心要点并直接落进一页新笔记",
                    icon: "sparkles.rectangle.stack",
                    tint: SonnetColors.ink,
                    isLoading: isRunningMaterialAI,
                    isWide: true
                ) {
                    Task {
                        await createSummaryNoteFromPDF()
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        StudentFormSection(
            title: "资料信息",
            subtitle: "这里展示文件的归档信息，必要时也可以再修改。"
        ) {
            metadataRow(title: "文件名", value: file.name, tint: SonnetColors.textTitle)
            StudentFormDivider()
            metadataRow(title: "所属课程", value: file.courseName.isEmpty ? "未分类" : file.courseName, tint: heroTint)
            StudentFormDivider()
            metadataRow(title: "导入时间", value: file.createdAt.formatted(.dateTime.year().month().day().hour().minute()), tint: SonnetColors.textBody)
            if file.fileType == "pdf" {
                StudentFormDivider()
                metadataRow(title: "PDF 页数", value: pdfPageCount > 0 ? "\(pdfPageCount) 页" : "读取中", tint: SonnetColors.amber)
            }
        }
    }

    private var actionSection: some View {
        StudentFormSection(
            title: "操作",
            subtitle: "可以继续阅读、分享或调整归档。"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                InkButton(title: "查看原文件", action: quickLookFile, style: .ghost)
                if let localURL {
                    ShareLink(item: localURL) {
                        Text("分享")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: SonnetDimens.bottomButtonHeight)
                            .foregroundStyle(SonnetColors.textOnInk)
                            .background(SonnetColors.ink)
                            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                    }
                }
            }

            InkButton(title: "编辑资料信息", action: { showingMetadataEditor = true }, style: .ghost)
        }
    }

    private func metadataRow(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: SonnetDimens.spacingM) {
            Text(title)
                .font(SonnetTypography.caption1)
                .foregroundStyle(SonnetColors.textCaption)

            Spacer()

            Text(value)
                .font(SonnetTypography.bodyBold)
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }

    private var loadedUIImage: UIImage? {
        if let data = file.fileData {
            return UIImage(data: data)
        }
        if let localURL,
           let data = try? Data(contentsOf: localURL) {
            return UIImage(data: data)
        }
        return nil
    }

    private var imageAttachmentData: [Data] {
        guard file.fileType == "image" else { return [] }
        if let data = file.fileData {
            return [data]
        }
        if let localURL,
           let data = try? Data(contentsOf: localURL) {
            return [data]
        }
        return []
    }

    private var courseSuggestions: [String] {
        let names = courses.map(\.name).filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private var heroTint: Color {
        switch file.fileType {
        case "pdf": return SonnetColors.vermilion
        case "image": return SonnetColors.ink
        default: return SonnetColors.jade
        }
    }

    private var heroBackground: Color {
        switch file.fileType {
        case "pdf": return SonnetColors.vermilionLight
        case "image": return SonnetColors.inkWash
        default: return SonnetColors.jadeLight
        }
    }

    private var heroColorName: String {
        switch file.fileType {
        case "pdf": return "gift"
        case "image": return "education"
        default: return "daily"
        }
    }

    private var fileTypeLabel: String {
        switch file.fileType {
        case "pdf": return "PDF"
        case "image": return "图片"
        default: return "文档"
        }
    }

    private var fileTypeSymbol: String {
        switch file.fileType {
        case "pdf": return "doc.richtext"
        case "image": return "photo"
        default: return "doc.text"
        }
    }

    private var formattedSize: String {
        let kb = Double(file.fileSize) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    private var heroSubtitle: String {
        switch file.fileType {
        case "pdf":
            return pdfPageCount > 0 ? "这份 PDF 共 \(pdfPageCount) 页，已经可以直接阅读、标注并转成笔记。" : "这份 PDF 已准备好在应用内阅读、标注并转成笔记。"
        case "image":
            return "图片资料适合和课堂笔记一起回看，照片与板书会更自然地留在同一门课里。"
        default:
            return "文档资料支持系统预览、分享，也可以先转成一页课堂笔记再继续整理。"
        }
    }

    private var previewSubtitle: String {
        switch file.fileType {
        case "pdf":
            return "保持在应用内阅读 PDF，不必跳出去也能快速过课件。"
        case "image":
            return "图片会按资料语言展示，适合看板书、讲义截图和拍照笔记。"
        default:
            return "Office 与其他文档当前仍以系统预览为主，避免做半成品编辑器。"
        }
    }

    private var baseTitle: String {
        let ext = "." + defaultExtension
        guard file.name.lowercased().hasSuffix(ext) else { return file.name }
        return String(file.name.dropLast(ext.count))
    }

    private func prepareLocalURL() {
        if !file.fileURL.isEmpty {
            let url = URL(fileURLWithPath: file.fileURL)
            localURL = url
            loadPDFMetadata(url)
            return
        }

        guard let data = file.fileData else { return }
        let ext = file.name.components(separatedBy: ".").last ?? defaultExtension
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        try? data.write(to: temp)
        tempURL = temp
        localURL = temp
        loadPDFMetadata(temp)
    }

    private func cleanupTempURL() {
        guard let tempURL else { return }
        try? FileManager.default.removeItem(at: tempURL)
        self.tempURL = nil
    }

    private func loadPDFMetadata(_ url: URL) {
        guard file.fileType == "pdf" else { return }
        pdfPageCount = PDFDocument(url: url)?.pageCount ?? 0
    }

    private func quickLookFile() {
        guard let localURL else { return }
        previewURL = localURL
    }

    private func saveMetadata(name: String, courseName: String) {
        let trimmedName = normalizeFileName(name)
        file.name = trimmedName
        file.courseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        HapticManager.medium()
    }

    private func normalizeFileName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return file.name }
        guard trimmed.contains(".") else {
            return trimmed + "." + defaultExtension
        }
        return trimmed
    }

    private var defaultExtension: String {
        switch file.fileType {
        case "pdf": return "pdf"
        case "image": return "jpg"
        default: return "doc"
        }
    }

    @MainActor
    private func applyMarkup(_ action: PDFMarkupAction) {
        let didApply: Bool

        switch action {
        case .highlight:
            didApply = pdfBridge.highlightSelection()
        case .underline:
            didApply = pdfBridge.underlineSelection()
        }

        guard didApply else {
            presentActionError("先在 PDF 里选中一段文字，再添加\(action.buttonTitle)。")
            return
        }

        persistPDFChanges(successHaptic: .medium)
    }

    @MainActor
    private func addTextAnnotation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presentActionError("批注内容还没有写下任何文字。")
            return
        }

        guard pdfBridge.addTextNote(trimmed) else {
            presentActionError("当前页面暂时无法插入批注，请先打开一页 PDF 再试。")
            return
        }

        persistPDFChanges(successHaptic: .medium)
    }

    @MainActor
    private func undoLastAnnotation() {
        guard pdfBridge.undoLastAction() else {
            presentActionError("当前没有可撤回的批注操作。")
            return
        }

        persistPDFChanges(successHaptic: .medium)
    }

    @MainActor
    private func persistPDFChanges(successHaptic: PDFSuccessHaptic) {
        guard file.fileType == "pdf",
              let data = pdfBridge.documentData(),
              let localURL else {
            presentActionError("当前 PDF 还没有准备好，稍后再试一次。")
            return
        }

        do {
            try data.write(to: localURL, options: .atomic)
            if file.fileURL.isEmpty {
                file.fileData = data
            }
            file.fileSize = data.count
            pdfPageCount = PDFDocument(data: data)?.pageCount ?? pdfPageCount
            pdfBridge.refreshState()
            try modelContext.save()
            switch successHaptic {
            case .medium:
                HapticManager.medium()
            case .none:
                break
            }
        } catch {
            presentActionError("批注已经加上了，但回写文件时失败了：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func createNoteFromMaterial() {
        let note = Note(
            title: baseTitle,
            content: buildMaterialNoteBody(summary: nil),
            courseName: file.courseName,
            colorName: heroColorName
        )
        note.imageData = imageAttachmentData
        note.updatedAt = Date()

        do {
            modelContext.insert(note)
            try modelContext.save()
            presentedNote = MaterialNoteTarget(note: note)
            HapticManager.medium()
        } catch {
            modelContext.delete(note)
            presentActionError("生成资料笔记失败：\(error.localizedDescription)")
        }
    }

    @MainActor
    private func createSummaryNoteFromPDF() async {
        guard file.fileType == "pdf" else { return }
        guard !isRunningMaterialAI else { return }
        guard let materialText = extractedPDFText(maxLength: 5000) else {
            presentActionError("这份 PDF 没有提取到可用文字，暂时还不能生成摘要笔记。")
            return
        }

        isRunningMaterialAI = true
        defer { isRunningMaterialAI = false }

        do {
            let summary = try await aiService.summarizeStudyMaterial(title: baseTitle, content: materialText)
            let note = Note(
                title: "\(baseTitle) 摘要",
                content: buildMaterialNoteBody(summary: summary),
                courseName: file.courseName,
                colorName: heroColorName
            )
            note.aiSummary = summary
            note.updatedAt = Date()

            modelContext.insert(note)
            try modelContext.save()
            presentedNote = MaterialNoteTarget(note: note)
            HapticManager.medium()
        } catch {
            presentActionError(error.localizedDescription)
        }
    }

    private func buildMaterialNoteBody(summary: String?) -> String {
        var sections: [String] = []

        sections.append(
            """
            ## 资料来源
            - 文件：\(file.name)
            - 类型：\(fileTypeLabel)
            - 课程：\(file.courseName.isEmpty ? "未分类" : file.courseName)
            - 导入：\(file.createdAt.formatted(.dateTime.year().month().day().hour().minute()))
            """
        )

        if let summary, !summary.isEmpty {
            sections.append(
                """
                ## AI 摘要
                \(summary)
                """
            )
            sections.append(
                """
                ## 复习补充
                - 在这里补上老师强调的重点
                - 记录自己还没完全吃透的概念
                - 可以继续追加例题、口诀或错因
                """
            )
        } else {
            if let excerpt = extractedMaterialExcerpt(maxLength: 360) {
                sections.append(
                    """
                    ## 原文摘录
                    \(excerpt)
                    """
                )
            }

            sections.append(
                """
                ## 课堂摘记
                - 先把老师强调的重点写在这里
                - 再补充自己的理解、例题和疑问
                """
            )
        }

        return sections.joined(separator: "\n\n")
    }

    private func extractedMaterialExcerpt(maxLength: Int) -> String? {
        switch file.fileType {
        case "pdf":
            return extractedPDFText(maxLength: maxLength)
        default:
            return nil
        }
    }

    private func extractedPDFText(maxLength: Int) -> String? {
        let document: PDFDocument?
        if let localURL {
            document = PDFDocument(url: localURL)
        } else if let data = file.fileData {
            document = PDFDocument(data: data)
        } else {
            document = nil
        }

        guard let raw = document?.string?
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if raw.count <= maxLength {
            return raw
        }

        return String(raw.prefix(maxLength))
    }

    @MainActor
    private func presentActionError(_ message: String) {
        materialActionError = message
        showingActionError = true
        HapticManager.warning()
    }
}

private struct MaterialNoteTarget: Identifiable {
    let id = UUID()
    let note: Note
}

private enum PDFMarkupAction {
    case highlight
    case underline

    var buttonTitle: String {
        switch self {
        case .highlight:
            return "高亮"
        case .underline:
            return "下划线"
        }
    }
}

private enum PDFSuccessHaptic {
    case medium
    case none
}

struct MaterialMetadataEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let file: StudyFile
    let suggestions: [String]
    let onSave: (String, String) -> Void

    @State private var draftName: String
    @State private var draftCourse: String

    init(file: StudyFile, suggestions: [String], onSave: @escaping (String, String) -> Void) {
        self.file = file
        self.suggestions = suggestions
        self.onSave = onSave
        _draftName = State(initialValue: file.name)
        _draftCourse = State(initialValue: file.courseName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    StudentHeroCard(
                        title: "编辑资料信息",
                        subtitle: "文件名和课程归档会直接影响它在资料库里的位置。",
                        icon: "square.and.pencil",
                        colorName: "education"
                    )

                    StudentFormSection(
                        title: "基础信息",
                        subtitle: "先把名字改得更清楚，再决定归到哪门课。"
                    ) {
                        StudentTextEntry(
                            title: "文件名",
                            prompt: "例如 第三章课件.pdf",
                            icon: "doc.text",
                            accent: SonnetColors.ink,
                            text: $draftName
                        )

                        StudentTextEntry(
                            title: "所属课程",
                            prompt: "例如 数据结构",
                            icon: "book.closed",
                            accent: SonnetColors.ink,
                            text: $draftCourse
                        )

                        if !suggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: SonnetDimens.spacingS) {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        StudentChoiceChip(
                                            title: suggestion,
                                            systemImage: draftCourse == suggestion ? "checkmark" : nil,
                                            isSelected: draftCourse == suggestion,
                                            tint: SonnetColors.ink
                                        ) {
                                            draftCourse = suggestion
                                            HapticManager.selection()
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
                .padding(.bottom, SonnetDimens.spacingXXL)
            }
            .background(SonnetColors.paper)
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SonnetColors.textCaption)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draftName, draftCourse)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(SonnetColors.ink)
                }
            }
        }
    }
}

private struct MaterialAnnotationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fileName: String
    let selectedText: String?
    let onSave: (String) -> Void

    @State private var draftText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    StudentHeroCard(
                        title: "添加文字批注",
                        subtitle: "这条批注会直接附着在 PDF 当前页里，适合写提醒、疑问和复习线索。",
                        icon: "character.bubble",
                        colorName: "gift"
                    ) {
                        StudentMetricPill(title: "资料", value: fileName, tint: SonnetColors.vermilion)
                    }

                    StudentFormSection(
                        title: "批注内容",
                        subtitle: "尽量写短一点，回头翻页时会更容易扫到。"
                    ) {
                        StudentTextEntry(
                            title: "写一句提醒",
                            prompt: "例如 这段定义容易和上一章混淆",
                            icon: "highlighter",
                            accent: SonnetColors.vermilion,
                            axis: .vertical,
                            text: $draftText
                        )

                        if let selectedText, !selectedText.isEmpty {
                            SonnetCard {
                                VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                                    Text("当前选中")
                                        .font(SonnetTypography.caption1)
                                        .foregroundStyle(SonnetColors.textCaption)
                                    Text(selectedText)
                                        .font(SonnetTypography.body)
                                        .foregroundStyle(SonnetColors.textBody)
                                        .lineSpacing(4)
                                }
                                .padding(SonnetDimens.cardPadding)
                            }
                        }
                    }
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
                .padding(.bottom, SonnetDimens.spacingXXL)
            }
            .background(SonnetColors.paper)
            .navigationTitle("文字批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SonnetColors.textCaption)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draftText)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(SonnetColors.ink)
                }
            }
        }
    }
}

private struct MaterialActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var isLoading: Bool = false
    var isWide: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SonnetDimens.spacingM) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 42, height: 42)
                    if isLoading {
                        ProgressView()
                            .tint(tint)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SonnetTypography.bodyBold)
                        .foregroundStyle(SonnetColors.textTitle)
                    Text(subtitle)
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)
            }
            .padding(SonnetDimens.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusXL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusXL, style: .continuous)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .frame(maxWidth: isWide ? .infinity : nil)
    }
}

@Observable
final class PDFAnnotationBridge {
    weak var pdfView: PDFView?
    var selectionPreview = ""
    var currentPageNumber = 1
    var pageCount = 0
    var currentPageAnnotationCount = 0
    var canUndoLastAction = false

    private var lastAddedAnnotations: [PDFAnnotation] = []

    var hasSelection: Bool {
        !selectionPreview.isEmpty
    }

    var pageLabel: String {
        if pageCount > 0 {
            return "\(currentPageNumber)/\(pageCount)"
        }
        return "1/1"
    }

    func highlightSelection() -> Bool {
        addMarkup(type: .highlight, color: UIColor.systemYellow.withAlphaComponent(0.42))
    }

    func underlineSelection() -> Bool {
        addMarkup(type: .underline, color: UIColor.systemIndigo.withAlphaComponent(0.8))
    }

    func addTextNote(_ text: String) -> Bool {
        guard let pdfView else { return false }
        let targetPage = pdfView.currentSelection?.pages.first
            ?? pdfView.currentPage
            ?? pdfView.document?.page(at: 0)

        guard let page = targetPage else { return false }

        let pageBounds = page.bounds(for: .cropBox)
        let selectionBounds = pdfView.currentSelection?.bounds(for: page)
        let proposedWidth = min(max(selectionBounds?.width ?? 180, 180), max(pageBounds.width - 32, 180))
        let originX = min(max(selectionBounds?.minX ?? (pageBounds.minX + 20), pageBounds.minX + 16), pageBounds.maxX - proposedWidth - 16)
        let originY = max(pageBounds.minY + 20, (selectionBounds?.minY ?? pageBounds.midY) - 88)
        let noteBounds = CGRect(x: originX, y: originY, width: proposedWidth, height: 80)

        let annotation = PDFAnnotation(bounds: noteBounds, forType: .text, withProperties: nil)
        annotation.contents = text
        annotation.color = UIColor.systemPink.withAlphaComponent(0.85)
        page.addAnnotation(annotation)
        lastAddedAnnotations = [annotation]
        canUndoLastAction = true
        pdfView.clearSelection()
        refreshState()
        return true
    }

    func documentData() -> Data? {
        pdfView?.document?.dataRepresentation()
    }

    func undoLastAction() -> Bool {
        guard !lastAddedAnnotations.isEmpty else { return false }

        for annotation in lastAddedAnnotations {
            annotation.page?.removeAnnotation(annotation)
        }

        lastAddedAnnotations.removeAll()
        canUndoLastAction = false
        refreshState()
        return true
    }

    func refreshState() {
        guard let pdfView else {
            selectionPreview = ""
            currentPageNumber = 1
            pageCount = 0
            currentPageAnnotationCount = 0
            return
        }

        pageCount = pdfView.document?.pageCount ?? 0

        if let currentPage = pdfView.currentPage,
           let document = pdfView.document {
            currentPageNumber = document.index(for: currentPage) + 1
            currentPageAnnotationCount = currentPage.annotations.count
        } else {
            currentPageNumber = 1
            currentPageAnnotationCount = 0
        }

        let rawSelection = pdfView.currentSelection?.string?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        selectionPreview = String(rawSelection.prefix(80))
    }

    private func addMarkup(type: PDFAnnotationSubtype, color: UIColor) -> Bool {
        guard let pdfView, let selection = pdfView.currentSelection else { return false }

        let lineSelections = selection.selectionsByLine()
        var addedAnnotations: [PDFAnnotation] = []

        for lineSelection in lineSelections {
            let pages = lineSelection.pages
            for page in pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0, bounds.height > 0, !bounds.isNull else { continue }
                let annotation = PDFAnnotation(
                    bounds: bounds.insetBy(dx: -1, dy: -1),
                    forType: type,
                    withProperties: nil
                )
                annotation.color = color
                page.addAnnotation(annotation)
                addedAnnotations.append(annotation)
            }
        }

        if !addedAnnotations.isEmpty {
            lastAddedAnnotations = addedAnnotations
            canUndoLastAction = true
            pdfView.clearSelection()
            refreshState()
            return true
        }

        return false
    }
}

struct AnnotatablePDFReaderView: UIViewRepresentable {
    let url: URL
    let bridge: PDFAnnotationBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        pdfView.document = PDFDocument(url: url)
        bridge.pdfView = pdfView
        context.coordinator.startObserving(pdfView)
        bridge.refreshState()
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
        bridge.pdfView = uiView
        context.coordinator.startObserving(uiView)
        bridge.refreshState()
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    final class Coordinator {
        private let bridge: PDFAnnotationBridge
        private var observedView: PDFView?
        private var observers: [NSObjectProtocol] = []

        init(bridge: PDFAnnotationBridge) {
            self.bridge = bridge
        }

        func startObserving(_ pdfView: PDFView) {
            guard observedView !== pdfView else { return }
            stopObserving()
            observedView = pdfView

            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: Notification.Name.PDFViewSelectionChanged, object: pdfView, queue: .main) { [weak bridge] _ in
                    bridge?.refreshState()
                },
                center.addObserver(forName: Notification.Name.PDFViewPageChanged, object: pdfView, queue: .main) { [weak bridge] _ in
                    bridge?.refreshState()
                }
            ]
        }

        func stopObserving() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            observedView = nil
        }

        deinit {
            stopObserving()
        }
    }
}
