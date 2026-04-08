import SwiftUI
import SwiftData
import PhotosUI

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Course.name)]) private var courses: [Course]

    var editingNote: Note? = nil

    // ── Editor state ──────────────────────────────────────
    @State private var note: Note? = nil
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var courseName: String = ""
    @State private var colorName: String = "ink"
    @State private var imageData: [Data] = []
    @State private var aiSummary: String? = nil
    @State private var isPinned: Bool = false

    // ── UI state ──────────────────────────────────────────
    @FocusState private var contentFocused: Bool
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showAIResult = false
    @State private var aiResultText = ""
    @State private var aiResultTitle = ""
    @State private var isRunningAI = false
    @State private var showImageViewer = false
    @State private var viewingImageIndex = 0

    // ── Auto-save debounce ────────────────────────────────
    @State private var saveTask: Task<Void, Never>? = nil

    private let aiService = AIService()

    // MARK: – Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    materialsHero
                    noteMetaSection
                    titleSection
                    attachmentSection
                    aiSection
                    contentSection
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
                .padding(.bottom, 110)
            }
            .background(SonnetColors.paper)

            if isRunningAI {
                aiLoadingBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(editingNote == nil ? "新建笔记" : "编辑笔记")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        withAnimation(SonnetMotion.spring) { isPinned.toggle() }
                        scheduleSave()
                    } label: {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .foregroundStyle(isPinned ? SonnetColors.ink : SonnetColors.textHint)
                    }
                }
            }

            // Keyboard toolbar
            ToolbarItemGroup(placement: .keyboard) {
                Button { insertMarkdown("**", "**", placeholder: "加粗文字") } label: {
                    Text("**B**")
                        .font(.system(size: 14, weight: .bold))
                }

                Button { insertHeading() } label: {
                    Text("H")
                        .font(.system(size: 14, weight: .semibold))
                }

                Button { insertList() } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                }

                Button { showImageSourcePicker = true } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 14))
                }

                Spacer()

                if isRunningAI {
                    ProgressView().scaleEffect(0.7).tint(SonnetColors.ink)
                } else {
                    Menu {
                        Button {
                            Task { await runSummarize() }
                        } label: {
                            Label("总结要点", systemImage: "sparkles")
                        }
                        .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button {
                            Task { await runExplain() }
                        } label: {
                            Label("扩展解释选段", systemImage: "text.magnifyingglass")
                        }
                        .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button {
                            Task { await runOutline() }
                        } label: {
                            Label("生成大纲", systemImage: "list.number")
                        }
                        .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                            Text("AI")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(SonnetColors.ink)
                    }
                }
            }
        }
        // Image source action sheet
        .confirmationDialog("添加图片", isPresented: $showImageSourcePicker) {
            Button("拍照") { showCamera = true }
            Button("从相册选择") { showPhotoPicker = true }
            Button("取消", role: .cancel) {}
        }
        // Camera
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                handleCapturedImage(image)
                showCamera = false
            }
            .ignoresSafeArea()
        }
        // Photo library
        .photosPicker(isPresented: $showPhotoPicker,
                      selection: $selectedPhotoItem,
                      matching: .images)
        .onChange(of: selectedPhotoItem) { _, item in
            Task { await loadPhotoItem(item) }
        }
        // AI result sheet
        .sheet(isPresented: $showAIResult) {
            AIResultSheet(title: aiResultTitle, content: aiResultText,
                          onAppendToNote: { appendAIResult() })
        }
        // Image viewer
        .sheet(isPresented: $showImageViewer) {
            ImageViewerSheet(images: imageData, initialIndex: viewingImageIndex,
                             onDelete: { idx in
                withAnimation {
                    _ = imageData.remove(at: idx)
                }
                scheduleSave()
            })
        }
        .onChange(of: courseName) { _, _ in scheduleSave() }
        .onAppear(perform: loadState)
        .onDisappear(perform: cleanup)
    }

    // MARK: – Sub-views

    private var materialsHero: some View {
        StudentHeroCard(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "这页课堂记录还在慢慢成形" : title,
            subtitle: materialsSubtitle,
            icon: "note.text",
            colorName: colorName
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "课程", value: courseName.isEmpty ? "未归类" : courseName, tint: selectedMaterialColors.icon)
                StudentMetricPill(title: "附件", value: "\(imageData.count) 张", tint: SonnetColors.amber)
                StudentMetricPill(title: "状态", value: saveStatusText, tint: saveTask == nil ? SonnetColors.jade : SonnetColors.textCaption)
            }
        }
    }

    private var noteMetaSection: some View {
        StudentFormSection(
            title: "资料信息",
            subtitle: "课程、色标和置顶会一起影响这页笔记在资料区里的位置。"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                Button {
                    withAnimation(SonnetMotion.spring) { isPinned.toggle() }
                    HapticManager.selection()
                    scheduleSave()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isPinned ? "已置顶" : "置顶")
                            .font(SonnetTypography.body)
                    }
                    .foregroundStyle(isPinned ? SonnetColors.textOnInk : SonnetColors.textBody)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(isPinned ? SonnetColors.ink : SonnetColors.paperWhite)
                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                            .stroke(isPinned ? SonnetColors.ink : SonnetColors.paperLine, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("自动保存")
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(SonnetColors.textCaption)
                    Text(saveStatusText)
                        .font(SonnetTypography.bodyBold)
                        .foregroundStyle(saveTask == nil ? SonnetColors.jade : SonnetColors.textBody)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(SonnetColors.paperWhite)
                .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                        .stroke(SonnetColors.paperLine, lineWidth: 0.5)
                )
            }

            StudentTextEntry(
                title: "所属课程",
                prompt: "例如 线性代数",
                icon: "book.closed",
                accent: selectedMaterialColors.icon,
                text: $courseName
            )

            if !courseSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SonnetDimens.spacingS) {
                        ForEach(courseSuggestions, id: \.self) { suggestion in
                            StudentChoiceChip(
                                title: suggestion,
                                systemImage: courseName == suggestion ? "checkmark" : nil,
                                isSelected: courseName == suggestion,
                                tint: selectedMaterialColors.icon
                            ) {
                                courseName = suggestion
                                HapticManager.selection()
                                scheduleSave()
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            StudentFormDivider()

            VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                Text("页面色标")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SonnetDimens.spacingS), count: 4), spacing: SonnetDimens.spacingS) {
                    ForEach(materialColorOptions, id: \.self) { option in
                        let colors = SonnetColors.categoryColors(for: option)
                        let selected = colorName == option
                        Button {
                            withAnimation(SonnetMotion.springFast) { colorName = option }
                            HapticManager.selection()
                            scheduleSave()
                        } label: {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(colors.bg)
                                        .frame(width: 26, height: 26)
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(colors.icon)
                                        .frame(width: 12, height: 12)
                                }
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(colors.icon)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(SonnetColors.paperWhite)
                            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                                    .stroke(selected ? colors.icon : SonnetColors.paperLine, lineWidth: selected ? 1.2 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        StudentFormSection(
            title: "标题",
            subtitle: "给这页笔记一个之后回看也能立刻认出的名字。"
        ) {
            StudentTextEntry(
                title: "笔记标题",
                prompt: "例如 第五章重点整理",
                icon: "text.book.closed",
                accent: selectedMaterialColors.icon,
                axis: .vertical,
                emphasizesValue: true,
                text: $title
            )
            .onChange(of: title) { _, _ in scheduleSave() }
        }
    }

    private var attachmentSection: some View {
        StudentFormSection(
            title: "资料附件",
            subtitle: "把板书、课件截图和纸面笔记都收在同一页里。",
            footer: "点击缩略图可以全屏查看，也能直接从这里继续补图。"
        ) {
            Button {
                showImageSourcePicker = true
            } label: {
                HStack(spacing: SonnetDimens.spacingM) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(SonnetColors.inkWash)
                            .frame(width: 40, height: 40)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(SonnetColors.ink)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(imageData.isEmpty ? "添加图片资料" : "继续补充图片")
                            .font(SonnetTypography.bodyBold)
                            .foregroundStyle(SonnetColors.textTitle)
                        Text(imageData.isEmpty ? "支持拍照和相册导入" : "当前已附 \(imageData.count) 张图片")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                    }

                    Spacer()

                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SonnetColors.ink)
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
            .buttonStyle(.plain)

            if !imageData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SonnetDimens.spacingS) {
                        ForEach(imageData.indices, id: \.self) { idx in
                            if let uiImg = UIImage(data: imageData[idx]) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 94, height: 94)
                                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                                            .stroke(SonnetColors.paperLine, lineWidth: 0.5)
                                    )
                                    .onTapGesture {
                                        viewingImageIndex = idx
                                        showImageViewer = true
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var aiSection: some View {
        StudentFormSection(
            title: aiSummary == nil ? "AI 辅助" : "AI 摘要",
            subtitle: aiSummary == nil ? "让 Sonnet 帮你提炼重点、扩写解释或整理大纲。" : "这份摘要会和正文一起保存在当前笔记里。"
        ) {
            if let aiSummary, !aiSummary.isEmpty {
                Text(aiSummary)
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textBody)
                    .lineSpacing(5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SonnetColors.paperWhite)
                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                            .stroke(SonnetColors.paperLine, lineWidth: 0.5)
                    )
            }

            HStack(spacing: SonnetDimens.spacingM) {
                InkButton(
                    title: aiSummary == nil ? "总结要点" : "重新总结",
                    action: { Task { await runSummarize() } },
                    style: .primary,
                    isLoading: isRunningAI
                )

                InkButton(
                    title: "生成大纲",
                    action: { Task { await runOutline() } },
                    style: .ghost
                )
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunningAI)
                .opacity(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunningAI ? 0.45 : 1)
            }

            InkButton(
                title: "扩展解释最后一段",
                action: { Task { await runExplain() } },
                style: .ghost
            )
            .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunningAI)
            .opacity(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunningAI ? 0.45 : 1)
        }
    }

    private var contentSection: some View {
        StudentFormSection(
            title: "正文",
            subtitle: "键盘工具栏支持标题、列表、加粗、插图和 AI，适合边上课边整理。"
        ) {
            TextEditor(text: $content)
                .font(SonnetTypography.body)
                .foregroundStyle(SonnetColors.textBody)
                .focused($contentFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(minHeight: 320, alignment: .topLeading)
                .background(SonnetColors.paperWhite)
                .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                        .stroke(SonnetColors.paperLine, lineWidth: 0.5)
                )
                .onChange(of: content) { _, _ in scheduleSave() }
        }
    }

    private var aiLoadingBanner: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8).tint(.white)
            Text("AI 处理中…")
                .font(SonnetTypography.footnote)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(SonnetColors.ink)
        .clipShape(Capsule())
        .padding(.bottom, 16)
    }

    private var materialColorOptions: [String] {
        ["ink", "education", "salary", "parttime", "daily", "transport", "gift", "other"]
    }

    private var selectedMaterialColors: (icon: Color, bg: Color) {
        SonnetColors.categoryColors(for: colorName)
    }

    private var courseSuggestions: [String] {
        let courseNames = courses.map(\.name).filter { !$0.isEmpty }
        let merged = courseName.isEmpty ? courseNames : [courseName] + courseNames
        return Array(NSOrderedSet(array: merged)) as? [String] ?? merged
    }

    private var materialsSubtitle: String {
        if let aiSummary, !aiSummary.isEmpty {
            return "这页笔记已经有 AI 提炼过的重点，适合继续补正文和图片。"
        }
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "正文已经写下来了，可以继续补图、设课程，或让 AI 帮你收束重点。"
        }
        return "先写标题，再慢慢把课堂上的重点、图片和灵感装进这一页。"
    }

    private var saveStatusText: String {
        saveTask == nil ? "已自动保存" : "保存中"
    }

    // MARK: – State management

    private func loadState() {
        if let e = editingNote {
            note       = e
            title      = e.title
            content    = e.content
            courseName = e.courseName
            colorName  = e.colorName
            imageData  = e.imageData
            aiSummary  = e.aiSummary
            isPinned   = e.isPinned
        } else {
            let newNote = Note(title: "")
            modelContext.insert(newNote)
            note = newNote
        }
    }

    private func cleanup() {
        saveTask?.cancel()
        // Flush final save immediately
        guard let n = note else { return }
        if n.title.isEmpty && n.content.isEmpty && n.imageData.isEmpty {
            modelContext.delete(n)
        } else {
            n.title      = title
            n.content    = content
            n.courseName = courseName
            n.colorName  = colorName
            n.imageData  = imageData
            n.aiSummary  = aiSummary
            n.isPinned   = isPinned
            n.updatedAt  = Date()
        }
        try? modelContext.save()
    }

    // MARK: – Auto-save

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await MainActor.run { flush() }
        }
    }

    private func flush() {
        guard let n = note else { return }
        n.title      = title
        n.content    = content
        n.courseName = courseName
        n.colorName  = colorName
        n.imageData  = imageData
        n.aiSummary  = aiSummary
        n.isPinned   = isPinned
        n.updatedAt  = Date()
        try? modelContext.save()
        saveTask = nil
    }

    // MARK: – Markdown helpers

    private func insertMarkdown(_ prefix: String, _ suffix: String, placeholder: String) {
        let insert = "\(prefix)\(placeholder)\(suffix)"
        if content.isEmpty || content.hasSuffix("\n") {
            content += insert
        } else {
            content += " " + insert
        }
    }

    private func insertHeading() {
        let prefix = content.isEmpty || content.hasSuffix("\n") ? "" : "\n"
        content += "\(prefix)## 标题\n"
    }

    private func insertList() {
        let prefix = content.isEmpty || content.hasSuffix("\n") ? "" : "\n"
        content += "\(prefix)- "
    }

    // MARK: – Image handling

    private func handleCapturedImage(_ image: UIImage) {
        guard let compressed = compressImage(image) else { return }
        withAnimation(SonnetMotion.spring) { imageData.append(compressed) }
        scheduleSave()
    }

    private func loadPhotoItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data),
           let compressed = compressImage(uiImage) {
            await MainActor.run {
                withAnimation(SonnetMotion.spring) { imageData.append(compressed) }
                scheduleSave()
            }
        }
        await MainActor.run { selectedPhotoItem = nil }
    }

    private func compressImage(_ image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data? {
        let size = image.size
        let scale = min(maxDimension / max(size.width, 1),
                        maxDimension / max(size.height, 1), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: – AI operations

    @MainActor
    private func runSummarize() async {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isRunningAI = true
        defer { isRunningAI = false }
        do {
            let result = try await aiService.summarizeNote(content: content)
            // Store in note
            aiSummary = result
            flush()
            // Show result sheet
            aiResultTitle = "AI 要点总结"
            aiResultText  = result
            showAIResult  = true
        } catch {
            aiResultTitle = "生成失败"
            aiResultText  = error.localizedDescription
            showAIResult  = true
        }
    }

    @MainActor
    private func runExplain() async {
        // Use last paragraph as selected text proxy
        let text = content.components(separatedBy: "\n\n").last?
                       .trimmingCharacters(in: .whitespaces) ?? content
        guard !text.isEmpty else { return }
        isRunningAI = true
        defer { isRunningAI = false }
        do {
            let result = try await aiService.explainText(text)
            aiResultTitle = "AI 扩展解释"
            aiResultText  = result
            showAIResult  = true
        } catch {
            aiResultTitle = "生成失败"
            aiResultText  = error.localizedDescription
            showAIResult  = true
        }
    }

    @MainActor
    private func runOutline() async {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isRunningAI = true
        defer { isRunningAI = false }
        do {
            let result = try await aiService.generateOutline(content: content)
            aiResultTitle = "AI 大纲"
            aiResultText  = result
            showAIResult  = true
        } catch {
            aiResultTitle = "生成失败"
            aiResultText  = error.localizedDescription
            showAIResult  = true
        }
    }

    private func appendAIResult() {
        content += "\n\n---\n**\(aiResultTitle)**\n\(aiResultText)"
        scheduleSave()
    }
}

// MARK: – Camera picker (UIKit bridge)

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onCapture(img)
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: – AI result sheet

struct AIResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    let onAppendToNote: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textBody)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(SonnetColors.paper)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("插入笔记") {
                        onAppendToNote()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(SonnetColors.ink)
                }
            }
        }
    }
}

// MARK: – Full-screen image viewer sheet

struct ImageViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let images: [Data]
    let initialIndex: Int
    let onDelete: (Int) -> Void

    @State private var currentIndex: Int = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { idx in
                    if let uiImg = UIImage(data: images[idx]) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFit()
                            .tag(idx)
                    }
                }
            }
            .tabViewStyle(.page)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        onDelete(currentIndex)
                        if images.count <= 1 { dismiss() }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear { currentIndex = initialIndex }
    }
}

// MARK: – Preview

#Preview {
    NavigationStack {
        NoteEditorView(editingNote: nil)
    }
    .modelContainer(for: [Note.self, Course.self], inMemory: true)
}
