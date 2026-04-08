import Vision
import UIKit

// MARK: - OCR 错误

enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(Error)
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:              return "无效的图片"
        case .recognitionFailed(let e): return "识别失败：\(e.localizedDescription)"
        case .noTextFound:              return "未识别到文字"
        }
    }
}

// MARK: - OCR 服务（actor 保证线程安全）

actor OCRService {

    /// 识别图片中的文字，返回识别结果字符串
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01   // 识别小字

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(error)
        }

        let observations = request.results ?? []
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        if text.isEmpty { throw OCRError.noTextFound }
        return text
    }

    /// 从 OCR 文本中提取金额（正则）
    nonisolated func extractAmount(from text: String) -> Double? {
        // 优先匹配"合计"/"总计"/"实付"等关键词后面的金额
        let patterns = [
            #"(?:合计|总计|实付|应付|金额)[：:\s]*¥?\s*(\d+\.?\d*)"#,
            #"¥\s*(\d+\.?\d*)"#,
            #"(\d+\.\d{2})"#    // 两位小数兜底
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let amount = Double(text[range]) {
                return amount
            }
        }
        return nil
    }
}
