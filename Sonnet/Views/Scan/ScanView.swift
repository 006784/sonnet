import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScanViewModel()
    @State private var aiService = AIService()
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var cameraAccessDenied = false

    @Query(filter: #Predicate<AccountBook> { $0.isSelected })
    private var selectedBooks: [AccountBook]

    // Processing animation
    @State private var processingPhase = 0
    @State private var rotationAngle: Double = 0
    @State private var processingTimer: Timer?
    private let processingTexts = ["正在识别...", "正在解析...", "即将完成..."]

    var body: some View {
        NavigationStack {
            ZStack {
                SonnetColors.paper.ignoresSafeArea()

                if viewModel.showResult {
                    resultView
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if viewModel.isProcessing {
                    processingView
                        .transition(.opacity)
                } else {
                    waitingView
                        .transition(.opacity)
                }
            }
            .animation(SonnetMotion.easeInOut, value: viewModel.isProcessing)
            .animation(SonnetMotion.easeInOut, value: viewModel.showResult)
            .navigationTitle("扫描记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SonnetColors.ink)
                }
            }
            .alert("无法使用相机", isPresented: $cameraAccessDenied) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请在系统设置中允许十四行诗访问相机")
            }
        }
        .sheet(isPresented: $showingCamera) {
            ScanCameraPickerView { image in
                guard let image else { return }
                Task { await viewModel.process(image: image, aiService: aiService) }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ScanPhotoLibraryPickerView { image in
                guard let image else { return }
                Task { await viewModel.process(image: image, aiService: aiService) }
            }
        }
    }

    // MARK: - Waiting State

    private var waitingView: some View {
        VStack(spacing: SonnetDimens.spacingXL) {
            RoundedRectangle(cornerRadius: 18)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                .foregroundStyle(SonnetColors.ink)
                .frame(height: 280)
                .overlay {
                    VStack(spacing: SonnetDimens.spacingL) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(SonnetColors.ink)
                        VStack(spacing: SonnetDimens.spacingXS) {
                            Text("拍照或选择图片")
                                .font(SonnetTypography.title3)
                                .foregroundStyle(SonnetColors.ink)
                            Text("支持小票、微信/支付宝账单截图")
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(SonnetColors.textCaption)
                        }
                    }
                    .padding(SonnetDimens.spacingXXL)
                }
                .padding(.horizontal, SonnetDimens.spacingL)

            HStack(spacing: SonnetDimens.spacingM) {
                Button {
                    checkCameraPermission()
                } label: {
                    HStack(spacing: SonnetDimens.spacingS) {
                        Image(systemName: "camera")
                            .font(.system(size: 16, weight: .medium))
                        Text("拍照")
                            .font(SonnetTypography.bodyBold)
                    }
                    .foregroundStyle(SonnetColors.textOnInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SonnetColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium))
                }

                Button {
                    showingPhotoPicker = true
                } label: {
                    HStack(spacing: SonnetDimens.spacingS) {
                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .medium))
                        Text("相册")
                            .font(SonnetTypography.bodyBold)
                    }
                    .foregroundStyle(SonnetColors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium)
                            .stroke(SonnetColors.ink, lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, SonnetDimens.spacingL)

            Spacer()
        }
        .padding(.top, SonnetDimens.spacingXXL)
    }

    // MARK: - Processing State

    private var processingView: some View {
        VStack(spacing: SonnetDimens.spacingXL) {
            RoundedRectangle(cornerRadius: 18)
                .fill(SonnetColors.inkWash)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(SonnetColors.inkMist, lineWidth: 1.5)
                )
                .frame(height: 280)
                .overlay {
                    VStack(spacing: SonnetDimens.spacingL) {
                        PoetryDivider()
                            .frame(width: 120)
                            .rotationEffect(.degrees(rotationAngle))

                        Text(processingTexts[processingPhase])
                            .font(SonnetTypography.subheadline)
                            .foregroundStyle(SonnetColors.ink)
                            .id(processingPhase)
                            .transition(.opacity)
                            .animation(SonnetMotion.easeInOut, value: processingPhase)
                    }
                }
                .padding(.horizontal, SonnetDimens.spacingL)

            Spacer()
        }
        .padding(.top, SonnetDimens.spacingXXL)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            startProcessingAnimation()
        }
        .onDisappear { stopProcessingAnimation() }
    }

    // MARK: - Result State

    private var resultView: some View {
        ScrollView {
            VStack(spacing: SonnetDimens.spacingL) {
                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge))
                }

                if let error = viewModel.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ScanResultCard(
                    amount: viewModel.parsedAmount,
                    note: viewModel.parsedNote,
                    merchant: viewModel.parsedMerchant,
                    date: viewModel.parsedDate,
                    categoryName: viewModel.parsedCategory,
                    type: viewModel.parsedType,
                    confidence: viewModel.confidence,
                    onConfirm: saveScannedRecord,
                    onRetry: { viewModel.reset() }
                )
            }
            .padding(SonnetDimens.spacingL)
        }
    }

    // MARK: - Save scanned record to SwiftData

    private func saveScannedRecord(_ draft: ScanResultDraft) {
        guard let book = selectedBooks.first else { dismiss(); return }
        guard let amount = draft.amount else {
            HapticManager.warning()
            return
        }

        let targetType = draft.type.rawValue
        let catDesc = FetchDescriptor<Category>(predicate: #Predicate { $0.type == targetType })
        let allCategories = (try? modelContext.fetch(catDesc)) ?? []
        let matched: Category?
        if !draft.categoryName.isEmpty {
            let name = draft.categoryName
            matched = allCategories.first { $0.name == name } ?? allCategories.first
        } else {
            matched = allCategories.first
        }
        guard let category = matched else { dismiss(); return }

        let record = Record(
            amount: amount,
            categoryId: category.id,
            note: draft.note.isEmpty ? (draft.merchant.isEmpty ? "小票记录" : draft.merchant) : draft.note,
            date: draft.date,
            type: targetType,
            accountBookId: book.id
        )
        record.category = category
        record.accountBook = book
        modelContext.insert(record)
        try? modelContext.save()

        HapticManager.success()
        NotificationCenter.default.post(name: .sonnetRecordChanged, object: nil)
        dismiss()
    }

    // MARK: - Helpers

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showingCamera = true }
                    else { cameraAccessDenied = true }
                }
            }
        default:
            cameraAccessDenied = true
        }
    }

    private func startProcessingAnimation() {
        processingPhase = 0
        processingTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            withAnimation(SonnetMotion.easeInOut) {
                processingPhase = (processingPhase + 1) % processingTexts.count
            }
        }
    }

    private func stopProcessingAnimation() {
        processingTimer?.invalidate()
        processingTimer = nil
    }
}

// MARK: - Camera UIImagePickerController Bridge

struct ScanCameraPickerView: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { self.onImage(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.onImage(nil) }
        }
    }
}

// MARK: - Photo Library PHPickerViewController Bridge

struct ScanPhotoLibraryPickerView: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onImage(nil); return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async { self.onImage(object as? UIImage) }
            }
        }
    }
}
