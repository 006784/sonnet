import Speech
import AVFoundation

// MARK: - 语音识别服务

@Observable
final class SpeechService: NSObject {
    var isRecording: Bool = false
    var recognizedText: String = ""     // 实时识别文字
    var isAuthorized: Bool = false
    var error: String?

    // 向后兼容别名
    var transcript: String { recognizedText }

    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        super.init()
        // 检查初始授权状态
        isAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - 权限

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = (status == .authorized)
                if status != .authorized {
                    self?.error = "语音识别未授权，请在系统设置中开启"
                }
            }
        }
    }

    func requestPermission() async -> Bool {
        let speechAuthorized: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                let authorized = status == .authorized
                DispatchQueue.main.async { self?.isAuthorized = authorized }
                continuation.resume(returning: authorized)
            }
        }

        let microphoneAuthorized: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        let allAuthorized = speechAuthorized && microphoneAuthorized
        await MainActor.run {
            isAuthorized = allAuthorized
            if !speechAuthorized {
                error = "语音识别未授权，请在系统设置中开启"
            } else if !microphoneAuthorized {
                error = "麦克风未授权，请在系统设置中开启"
            } else {
                error = nil
            }
        }
        return allAuthorized
    }

    // MARK: - 录音控制

    func startRecording() throws {
        guard isAuthorized else {
            throw SpeechError.notAuthorized
        }
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw SpeechError.microphoneDenied
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognizedText = ""
        error = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, err in
            guard let self else { return }
            if let result {
                self.recognizedText = result.bestTranscription.formattedString
            }
            if err != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    @discardableResult
    func stopRecording() -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        return recognizedText
    }
}

// MARK: - 错误类型

enum SpeechError: Error, LocalizedError {
    case notAuthorized
    case microphoneDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:          return "未获得语音识别权限"
        case .microphoneDenied:       return "未获得麦克风权限"
        case .recognizerUnavailable:  return "语音识别器不可用（检查网络或设备支持）"
        }
    }
}
