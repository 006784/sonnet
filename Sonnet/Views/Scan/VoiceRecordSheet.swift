import SwiftUI
import SwiftData
import Speech

struct VoiceRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var speechService = SpeechService()
    @State private var aiService = AIService()

    @Query(filter: #Predicate<AccountBook> { $0.isSelected })
    private var selectedBooks: [AccountBook]

    @State private var phase: VoicePhase = .idle
    @State private var parsedAmount: Double?
    @State private var parsedNote: String = ""
    @State private var parsedMerchant: String = ""
    @State private var parsedCategoryName: String = ""
    @State private var parsedType: Int = 0
    @State private var parsedConfidence: Double = 0
    @State private var errorMessage: String?

    // Pulse animation
    @State private var pulse1: CGFloat = 1.0
    @State private var pulse2: CGFloat = 1.0
    @State private var pulse3: CGFloat = 1.0

    // Waveform animation
    @State private var waveHeights: [CGFloat] = [12, 20, 14]

    // Loading rotation
    @State private var loadingAngle: Double = 0

    enum VoicePhase {
        case idle, recording, parsing, result, error
    }

    var body: some View {
        ZStack {
            SonnetColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(SonnetColors.inkMist)
                    .frame(width: 36, height: 4)
                    .padding(.top, SonnetDimens.spacingL)
                    .padding(.bottom, SonnetDimens.spacingXXL)

                Spacer()

                switch phase {
                case .idle:
                    idleView
                case .recording:
                    recordingView
                case .parsing:
                    parsingView
                case .result:
                    resultView
                case .error:
                    errorView
                }

                Spacer()
                Spacer()
            }
        }
        .animation(SonnetMotion.spring, value: phase)
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: SonnetDimens.spacingXXL) {
            ZStack {
                // Outer pale ring
                Circle()
                    .stroke(SonnetColors.inkPale.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 100, height: 100)

                // Mic button
                Circle()
                    .fill(SonnetColors.ink)
                    .frame(width: 72, height: 72)
                    .shadow(color: SonnetColors.ink.opacity(0.3), radius: 12, y: 4)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white)
                    }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onEnded { _ in startRecording() }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        if phase == .recording { stopRecording() }
                    }
            )

            Text("长按说话")
                .font(SonnetTypography.caption1)
                .foregroundStyle(SonnetColors.textCaption)

            Button("取消") { dismiss() }
                .font(SonnetTypography.subheadline)
                .foregroundStyle(SonnetColors.textCaption)
        }
    }

    // MARK: - Recording State

    private var recordingView: some View {
        VStack(spacing: SonnetDimens.spacingXXL) {
            ZStack {
                // Pulse rings (3 concentric expanding circles)
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(SonnetColors.ink.opacity(0.15), lineWidth: 1)
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseScale(index: i))
                        .opacity(pulseOpacity(index: i))
                }

                // Core mic button (pressed state - slightly smaller)
                Circle()
                    .fill(SonnetColors.ink)
                    .frame(width: 64, height: 64)
                    .shadow(color: SonnetColors.ink.opacity(0.4), radius: 16, y: 6)
                    .overlay {
                        // Waveform: 3 vertical bars
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: 3, height: waveHeights[i])
                                    .animation(
                                        .easeInOut(duration: 0.35)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.12),
                                        value: waveHeights[i]
                                    )
                            }
                        }
                    }
            }
            .onAppear { startPulseAnimation(); startWaveAnimation() }

            Text("正在聆听...")
                .font(SonnetTypography.subheadline)
                .foregroundStyle(SonnetColors.ink)
                .opacity(0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: phase)

            Button {
                stopRecording()
            } label: {
                Text("松开完成")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
                    .padding(.horizontal, SonnetDimens.spacingL)
                    .padding(.vertical, SonnetDimens.spacingS)
                    .background(SonnetColors.paperCream)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Parsing State

    private var parsingView: some View {
        VStack(spacing: SonnetDimens.spacingXXL) {
            ZStack {
                Circle()
                    .fill(SonnetColors.inkWash)
                    .frame(width: 72, height: 72)

                Image(systemName: "waveform")
                    .font(.system(size: 24))
                    .foregroundStyle(SonnetColors.ink)
                    .rotationEffect(.degrees(loadingAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            loadingAngle = 360
                        }
                    }
            }

            Text("正在理解...")
                .font(SonnetTypography.subheadline)
                .foregroundStyle(SonnetColors.ink)

            if !speechService.transcript.isEmpty {
                Text("\u{201C}\(speechService.transcript)\u{201D}")
                    .font(SonnetTypography.footnote)
                    .foregroundStyle(SonnetColors.textCaption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SonnetDimens.spacing32)
            }
        }
    }

    // MARK: - Result State

    private var resultView: some View {
        VStack(spacing: SonnetDimens.spacingL) {
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SonnetDimens.spacingXL)
            }

            ScanResultCard(
                amount: parsedAmount,
                note: parsedNote,
                merchant: parsedMerchant,
                date: Date(),
                categoryName: parsedCategoryName,
                type: RecordType(rawValue: parsedType) ?? .expense,
                confidence: parsedConfidence,
                onConfirm: saveVoiceRecord,
                onRetry: { resetToIdle() }
            )
            .padding(.horizontal, SonnetDimens.spacingL)
        }
    }

    // MARK: - Save voice record to SwiftData

    private func saveVoiceRecord(_ draft: ScanResultDraft) {
        guard let book = selectedBooks.first else { dismiss(); return }
        guard let amount = draft.amount else {
            HapticManager.warning()
            return
        }

        let targetType = draft.type.rawValue
        let catDesc = FetchDescriptor<Category>(predicate: #Predicate { $0.type == targetType })
        let categories = (try? modelContext.fetch(catDesc)) ?? []
        let category = categories.first { $0.name == draft.categoryName } ?? categories.first
        guard let category else { dismiss(); return }

        let record = Record(
            amount: amount,
            categoryId: category.id,
            note: draft.note.isEmpty ? (draft.merchant.isEmpty ? "语音记录" : draft.merchant) : draft.note,
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

    // MARK: - Error State

    private var errorView: some View {
        VStack(spacing: SonnetDimens.spacingXXL) {
            ZStack {
                Circle()
                    .fill(SonnetColors.vermilion.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(SonnetColors.vermilion)
            }

            VStack(spacing: SonnetDimens.spacingS) {
                Text("没有听清，请再说一次")
                    .font(SonnetTypography.subheadline)
                    .foregroundStyle(SonnetColors.textBody)
                if let err = errorMessage {
                    Text(err)
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)
                }
            }

            HStack(spacing: SonnetDimens.spacingM) {
                Button("取消") { dismiss() }
                    .font(SonnetTypography.subheadline)
                    .foregroundStyle(SonnetColors.textCaption)

                InkButton(title: "重试", action: resetToIdle, style: .primary)
                    .frame(width: 120)
            }
        }
    }

    // MARK: - Actions

    private func startRecording() {
        HapticManager.impact(.heavy)
        Task {
            let granted = await speechService.requestPermission()
            guard granted else {
                await MainActor.run {
                    errorMessage = speechService.error ?? "请在设置中允许语音识别权限"
                    phase = .error
                }
                return
            }
            do {
                try speechService.startRecording()
                await MainActor.run { phase = .recording }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .error
                    HapticManager.error()
                }
            }
        }
    }

    private func stopRecording() {
        HapticManager.impact(.light)
        speechService.stopRecording()
        let transcript = speechService.transcript

        guard !transcript.isEmpty else {
            errorMessage = nil
            phase = .error
            HapticManager.error()
            return
        }

        phase = .parsing
        Task {
            let result = await parseVoiceTranscript(transcript)
            await MainActor.run {
                parsedAmount = result.amount
                parsedNote = result.note ?? transcript
                parsedMerchant = result.merchant ?? ""
                parsedCategoryName = result.category ?? ""
                parsedType = result.type ?? 0
                parsedConfidence = result.confidence
                errorMessage = result.amount == nil ? "没有识别到有效金额，请手动补充确认" : nil
                phase = .result
                if result.amount == nil {
                    HapticManager.warning()
                } else {
                    HapticManager.success()
                }
            }
        }
    }

    private func parseVoiceTranscript(_ text: String) async -> ParsedRecordResult {
        if appStateCanUseAI {
            if let parsed = try? await aiService.parseVoiceInput(text: text), parsed.amount != nil {
                return parsed
            }
        }

        let patterns = [
            #"(\d+\.?\d*)\s*[元块圆]"#,
            #"[¥￥]\s*(\d+\.?\d*)"#,
            #"(\d+\.?\d+)"#
        ]
        var amount: Double?
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                amount = Double(text[range])
                break
            }
        }
        return ParsedRecordResult(
            amount: amount,
            note: text,
            type: 0,
            confidence: amount == nil ? 0 : 0.45
        )
    }

    private func resetToIdle() {
        parsedAmount = nil
        parsedNote = ""
        parsedMerchant = ""
        parsedCategoryName = ""
        parsedType = 0
        parsedConfidence = 0
        errorMessage = nil
        phase = .idle
    }

    private var appStateCanUseAI: Bool {
        let enabled = UserDefaults.standard.object(forKey: AppState.aiEnabledKey) as? Bool ?? true
        return enabled && !KeychainManager.loadAPIKey().isEmpty
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        let delays: [Double] = [0, 0.2, 0.4]
        let baseScale: CGFloat = 1.0
        let targetScale: CGFloat = 2.2

        for (i, delay) in delays.enumerated() {
            withAnimation(
                .easeOut(duration: 1.2)
                .repeatForever(autoreverses: false)
                .delay(delay)
            ) {
                switch i {
                case 0: pulse1 = targetScale
                case 1: pulse2 = targetScale
                default: pulse3 = targetScale
                }
                _ = baseScale // suppress warning
            }
        }
    }

    private func pulseScale(index: Int) -> CGFloat {
        switch index {
        case 0: return pulse1
        case 1: return pulse2
        default: return pulse3
        }
    }

    private func pulseOpacity(index: Int) -> Double {
        let scale = pulseScale(index: index)
        // Fade as it expands
        return Double(max(0, 1 - (scale - 1) / 1.2))
    }

    private func startWaveAnimation() {
        let targets: [CGFloat] = [20, 10, 24]
        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
            waveHeights = targets
        }
    }
}
