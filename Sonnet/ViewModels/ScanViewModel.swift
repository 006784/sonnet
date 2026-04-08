import SwiftUI
import Foundation

@Observable
final class ScanViewModel {
    var capturedImage: UIImage?
    var recognizedText: String = ""
    var parsedAmount: Double?
    var parsedNote: String = ""
    var parsedMerchant: String?
    var parsedCategory: String?
    var parsedDate: Date = Date()
    var parsedType: RecordType = .expense
    var confidence: Double = 0
    var isProcessing: Bool = false
    var showResult: Bool = false
    var errorMessage: String?

    // actor 类型，不需要 @Observable
    private let ocrService = OCRService()

    // MARK: - 处理入口

    func process(image: UIImage, aiService: AIService) async {
        capturedImage = image
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            // Step 1: OCR 识别
            let text = try await ocrService.recognizeText(from: image)
            recognizedText = text

            // Step 2: AI 解析（有 API Key 时）
            let parsed = try await aiService.parseReceipt(ocrText: text)

            // Step 3: 回填结果
            let fallback = ocrService.extractAmount(from: text)
            parsedAmount   = parsed.amount ?? fallback
            parsedMerchant = parsed.merchant
            parsedCategory = parsed.category
            parsedNote     = parsed.note ?? parsed.merchant ?? "小票记录"
            parsedDate     = parseDate(from: parsed.date)
            parsedType     = RecordType(rawValue: parsed.type ?? 0) ?? .expense
            confidence     = parsed.confidence
        } catch {
            // OCR 失败或无 AI Key 时，退化到本地正则提取
            let text = recognizedText.isEmpty ? "" : recognizedText
            parsedAmount = ocrService.extractAmount(from: text)
            parsedNote   = "小票记录"
            parsedDate   = Date()
            parsedType   = .expense
            confidence   = 0
            if let msg = (error as? OCRError)?.localizedDescription {
                errorMessage = msg
            }
        }

        showResult = true
    }

    // MARK: - 重置

    func reset() {
        capturedImage  = nil
        recognizedText = ""
        parsedAmount   = nil
        parsedNote     = ""
        parsedMerchant = nil
        parsedCategory = nil
        parsedDate     = Date()
        parsedType     = .expense
        confidence     = 0
        errorMessage   = nil
        showResult     = false
    }

    private func parseDate(from rawValue: String?) -> Date {
        guard let rawValue, !rawValue.isEmpty else { return Date() }

        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy.M.d",
            "yyyy年M月d日",
            "M月d日",
            "MM-dd",
            "M/d"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = format

            if let date = formatter.date(from: rawValue) {
                if format == "M月d日" || format == "MM-dd" || format == "M/d" {
                    return Calendar.current.date(
                        bySetting: .year,
                        value: Calendar.current.component(.year, from: Date()),
                        of: date
                    ) ?? date
                }
                return date
            }
        }

        return Date()
    }
}
