import SwiftUI
import SwiftData
import QuickLook
import UniformTypeIdentifiers

struct StudyFilesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\StudyFile.createdAt, order: .reverse)])
    private var allFiles: [StudyFile]
    @Query(sort: [SortDescriptor(\Course.name)])
    private var courses: [Course]

    private let externalCourseFilter: String?
    private let externalSearchText: String

    @State private var showAddSource = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showCourseInput = false
    @State private var pendingFileData: Data? = nil
    @State private var pendingFileName: String = ""
    @State private var pendingFileType: String = ""
    @State private var courseForNewFile: String = ""
    @State private var previewURL: URL? = nil
    @State private var showImageViewer = false
    @State private var viewingImageData: Data? = nil
    @State private var selectedFile: StudyFile? = nil
    @State private var localSelectedCourse = "全部"

    init(selectedCourse: String? = nil, searchText: String = "") {
        self.externalCourseFilter = selectedCourse
        self.externalSearchText = searchText
    }

    // MARK: – Computed

    private var effectiveSearchText: String {
        externalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveCourseFilter: String {
        guard let externalCourseFilter, !externalCourseFilter.isEmpty else {
            return localSelectedCourse
        }
        return externalCourseFilter
    }

    private var availableCourseNames: [String] {
        let names = Set(
            allFiles.compactMap { $0.courseName.isEmpty ? nil : $0.courseName } +
            courses.map(\.name).filter { !$0.isEmpty }
        )
        return ["全部"] + names.sorted()
    }

    private var filteredFiles: [StudyFile] {
        var list = allFiles
        if effectiveCourseFilter != "全部" {
            list = list.filter { $0.courseName == effectiveCourseFilter }
        }
        if !effectiveSearchText.isEmpty {
            let query = effectiveSearchText.lowercased()
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.courseName.localizedCaseInsensitiveContains(query)
            }
        }
        return list
    }

    private var groupedFiles: [(course: String, files: [StudyFile])] {
        let grouped = Dictionary(grouping: filteredFiles) { $0.courseName.isEmpty ? "未分类" : $0.courseName }
        return grouped
            .map { (course: $0.key, files: $0.value) }
            .sorted { $0.course < $1.course }
    }

    // MARK: – Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    materialsOverviewCard

                    if externalCourseFilter == nil, availableCourseNames.count > 1 {
                        courseFilterChips
                    }

                    if filteredFiles.isEmpty {
                        emptyMaterialsCard
                    } else {
                        VStack(spacing: SonnetDimens.spacingL) {
                            ForEach(groupedFiles, id: \.course) { group in
                                VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                                    StudentSectionHeader(
                                        title: group.course,
                                        subtitle: "\(group.files.count) 份资料"
                                    )

                                    SonnetCard {
                                        VStack(spacing: 0) {
                                            ForEach(Array(group.files.enumerated()), id: \.element.id) { idx, file in
                                                fileRow(file: file, isLast: idx == group.files.count - 1)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, 4)
                .padding(.bottom, 96)
            }
            .background(SonnetColors.paper)

            Button { showAddSource = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: SonnetDimens.fabSize, height: SonnetDimens.fabSize)
                    .background(SonnetColors.ink)
                    .clipShape(Circle())
                    .shadow(color: SonnetColors.ink.opacity(0.35), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .background(SonnetColors.paper)
        // Source picker
        .confirmationDialog("添加资料", isPresented: $showAddSource) {
            Button("拍照") { showCamera = true }
            Button("从相册选择") { showPhotoPicker = true }
            Button("选择文件") { showDocumentPicker = true }
            Button("取消", role: .cancel) {}
        }
        // Camera
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    pendingFileData  = data
                    pendingFileName  = "拍摄_\(dateStamp()).jpg"
                    pendingFileType  = "image"
                    showCourseInput  = true
                }
                showCamera = false
            }
            .ignoresSafeArea()
        }
        // Photo picker
        .sheet(isPresented: $showPhotoPicker) {
            PhotoFilePickerView { data, name in
                pendingFileData  = data
                pendingFileName  = name
                pendingFileType  = "image"
                showCourseInput  = true
            }
        }
        // Document picker
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                if let data = try? Data(contentsOf: url) {
                    pendingFileData  = data
                    pendingFileName  = url.lastPathComponent
                    pendingFileType  = fileType(for: url)
                    showCourseInput  = true
                }
            }
        }
        .sheet(isPresented: $showCourseInput, onDismiss: {
            if pendingFileData != nil {
                resetPending()
            }
        }) {
            MaterialCourseAssignmentSheet(
                fileName: pendingFileName,
                courseName: $courseForNewFile,
                suggestions: courseSuggestions,
                onCancel: resetPending,
                onSave: saveFile
            )
        }
        .sheet(item: $previewURL) { url in
            QuickLookView(url: url)
        }
        .sheet(isPresented: $showImageViewer) {
            if let data = viewingImageData {
                SingleImageViewer(imageData: data)
            }
        }
        .navigationDestination(item: $selectedFile) { file in
            StudyFileDetailView(file: file)
        }
        .onAppear {
            if let externalCourseFilter {
                localSelectedCourse = externalCourseFilter
            }
        }
        .onChange(of: externalCourseFilter) { _, newValue in
            if let newValue, !newValue.isEmpty {
                localSelectedCourse = newValue
            }
        }
    }

    // MARK: – File row

    private var materialsOverviewCard: some View {
        StudentHeroCard(
            title: "学习资料",
            subtitle: overviewSubtitle,
            icon: "folder",
            colorName: "education"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "资料数", value: "\(filteredFiles.count)", tint: SonnetColors.ink)
                StudentMetricPill(title: "课程数", value: "\(max(availableCourseNames.count - 1, 0))", tint: SonnetColors.jade)
                StudentMetricPill(title: "占用", value: filteredStorageText, tint: SonnetColors.amber)
            }
        }
    }

    private var courseFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SonnetDimens.spacingS) {
                ForEach(availableCourseNames, id: \.self) { course in
                    StudentChoiceChip(
                        title: course,
                        systemImage: localSelectedCourse == course ? "checkmark" : nil,
                        isSelected: localSelectedCourse == course,
                        tint: SonnetColors.ink
                    ) {
                        localSelectedCourse = course
                        HapticManager.selection()
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var emptyMaterialsCard: some View {
        StudentFormSection(
            title: "资料库还是空的",
            subtitle: "从板书照片、相册截图或文件开始，把每门课的材料慢慢归到一起。"
        ) {
            EmptyStateView(
                icon: "folder.badge.plus",
                title: "还没有资料",
                subtitle: "先导入第一份课件、板书或 PDF。"
            )

            HStack(spacing: SonnetDimens.spacingM) {
                InkButton(title: "拍照", action: { showCamera = true }, style: .ghost)
                InkButton(title: "选择文件", action: { showDocumentPicker = true }, style: .primary)
            }
        }
    }

    @ViewBuilder
    private func fileRow(file: StudyFile, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fileIconBg(file.fileType))
                    .frame(width: 40, height: 40)
                Image(systemName: fileIconName(file.fileType))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(fileIconColor(file.fileType))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textTitle)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(fileTypeLabel(file.fileType))
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(fileIconColor(file.fileType))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(fileIconBg(file.fileType))
                        .clipShape(Capsule())

                    Text("\(formatSize(file.fileSize))  ·  \(shortDate(file.createdAt))")
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(SonnetColors.textHint)
                }
            }

            Spacer()

            Button {
                selectedFile = file
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 15))
                    .foregroundStyle(SonnetColors.inkPale)
                    .frame(width: 32, height: 32)
                    .background(SonnetColors.inkWash)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFile = file
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { deleteFile(file) }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }

        if !isLast {
            Rectangle()
                .fill(SonnetColors.paperLine)
                .frame(height: 0.5)
                .padding(.leading, 68)
        }
    }

    // MARK: – Actions

    private func saveFile() {
        guard let data = pendingFileData else { return }
        let file = StudyFile(
            name: pendingFileName,
            fileType: pendingFileType,
            courseName: courseForNewFile.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        file.fileSize = data.count
        let threshold = 5 * 1024 * 1024     // 5 MB

        if data.count < threshold {
            file.fileData = data
        } else {
            // Save to app Documents
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dest = docs.appendingPathComponent(UUID().uuidString + "_" + pendingFileName)
            try? data.write(to: dest)
            file.fileURL = dest.path
        }

        modelContext.insert(file)
        try? modelContext.save()
        HapticManager.medium()
        resetPending()
    }

    private func deleteFile(_ file: StudyFile) {
        if !file.fileURL.isEmpty {
            try? FileManager.default.removeItem(atPath: file.fileURL)
        }
        modelContext.delete(file)
        try? modelContext.save()
        HapticManager.warning()
    }

    private func resetPending() {
        pendingFileData  = nil
        pendingFileName  = ""
        pendingFileType  = ""
        courseForNewFile = ""
    }

    // MARK: – Helpers

    private func fileType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "pdf"
        case "jpg", "jpeg", "png", "heic", "webp": return "image"
        default: return "doc"
        }
    }

    private func fileIconName(_ type: String) -> String {
        switch type {
        case "pdf":   return "doc.fill"
        case "image": return "photo.fill"
        default:      return "doc.text.fill"
        }
    }

    private func fileIconColor(_ type: String) -> Color {
        switch type {
        case "pdf":   return SonnetColors.vermilion
        case "image": return SonnetColors.ink
        default:      return SonnetColors.jade
        }
    }

    private func fileIconBg(_ type: String) -> Color {
        switch type {
        case "pdf":   return SonnetColors.vermilionLight
        case "image": return SonnetColors.inkWash
        default:      return SonnetColors.jadeLight
        }
    }

    private func fileTypeLabel(_ type: String) -> String {
        switch type {
        case "pdf": return "PDF"
        case "image": return "图片"
        default: return "文档"
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return fmt.string(from: date)
    }

    private var totalStorageText: String {
        formatSize(allFiles.reduce(0) { $0 + $1.fileSize })
    }

    private var filteredStorageText: String {
        formatSize(filteredFiles.reduce(0) { $0 + $1.fileSize })
    }

    private var overviewSubtitle: String {
        if let latest = filteredFiles.first {
            return "最近一次导入在 \(shortDate(latest.createdAt))，课程资料会按课程自然归档。"
        }
        return "拍照、相册截图和文件会被整理成同一份学习资料库。"
    }

    private var courseSuggestions: [String] {
        let names = courses.map(\.name).filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private func dateStamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd_HHmmss"
        return fmt.string(from: Date())
    }
}

struct MaterialCourseAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fileName: String
    @Binding var courseName: String
    let suggestions: [String]
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    StudentHeroCard(
                        title: "关联课程",
                        subtitle: "给这份资料一个归属，之后在资料区里会更容易找到它。",
                        icon: "folder.badge.plus",
                        colorName: "education"
                    ) {
                        HStack(spacing: SonnetDimens.spacingM) {
                            StudentMetricPill(title: "文件名", value: fileName.isEmpty ? "未命名文件" : fileName, tint: SonnetColors.ink)
                        }
                    }

                    StudentFormSection(
                        title: "课程名称",
                        subtitle: "可以手动输入，也可以直接点已有课程。"
                    ) {
                        StudentTextEntry(
                            title: "所属课程",
                            prompt: "例如 概率论",
                            icon: "book.closed",
                            accent: SonnetColors.ink,
                            text: $courseName
                        )

                        if !suggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: SonnetDimens.spacingS) {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        StudentChoiceChip(
                                            title: suggestion,
                                            systemImage: courseName == suggestion ? "checkmark" : nil,
                                            isSelected: courseName == suggestion,
                                            tint: SonnetColors.ink
                                        ) {
                                            courseName = suggestion
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
            .navigationTitle("保存资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(SonnetColors.textCaption)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(SonnetColors.ink)
                }
            }
        }
    }
}

// MARK: – Document picker bridge

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .image, .spreadsheet, .presentation, .text, .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: – Photo file picker (returns Data + filename)

struct PhotoFilePickerView: UIViewControllerRepresentable {
    let onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (Data, String) -> Void
        init(onPick: @escaping (Data, String) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let name = (info[.imageURL] as? URL)?.lastPathComponent ?? "image.jpg"
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.8) {
                onPick(data, name)
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: – QuickLook preview bridge

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewControllerWrapper {
        QLPreviewControllerWrapper(url: url)
    }
    func updateUIViewController(_ vc: QLPreviewControllerWrapper, context: Context) {}
}

final class QLPreviewControllerWrapper: UIViewController, QLPreviewControllerDataSource {
    let url: URL
    init(url: URL) { self.url = url; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let ql = QLPreviewController()
        ql.dataSource = self
        present(ql, animated: true)
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        url as QLPreviewItem
    }
}

// MARK: – Single image full-screen viewer

struct SingleImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let imageData: Data

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = UIImage(data: imageData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}

// MARK: – URL Identifiable extension for .sheet(item:)

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: – Preview

#Preview {
    NavigationStack { StudyFilesView() }
        .modelContainer(for: [StudyFile.self, Course.self], inMemory: true)
}
