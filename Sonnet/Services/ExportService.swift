import Foundation
import UIKit

@Observable
final class ExportService {
    var isExporting: Bool = false
    var exportURL: URL?
    var error: String?

    // MARK: - CSV 导出

    /// 导出记录为 CSV 文件，返回临时文件 URL
    func exportToCSV(records: [Record]) -> URL {
        let url = buildCSVFile(records: records)
        exportURL = url
        return url
    }

    /// 异步版本（向后兼容）
    func exportCSV(records: [Record]) async throws -> URL {
        isExporting = true
        defer { isExporting = false }
        let url = buildCSVFile(records: records)
        exportURL = url
        return url
    }

    // MARK: - 系统分享

    /// 弹出系统分享 Sheet 分享 CSV 文件
    func shareCSV(from viewController: UIViewController, url: URL) {
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        // iPad 需要 sourceView
        if let popover = controller.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0, height: 0
            )
        }
        viewController.present(controller, animated: true)
    }

    // MARK: - 内部实现

    private func buildCSVFile(records: [Record]) -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = ["日期,类型,分类,金额,备注"]
        for record in records {
            let dateStr  = fmt.string(from: record.date)
            let typeStr  = record.type == 0 ? "支出" : "收入"
            let catStr   = record.category?.name ?? ""
            let noteStr  = record.note.replacingOccurrences(of: ",", with: "，")
                                      .replacingOccurrences(of: "\n", with: " ")
            lines.append("\(dateStr),\(typeStr),\(catStr),\(record.amount),\(noteStr)")
        }

        let csv = lines.joined(separator: "\n")
        let timestamp = Int(Date().timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sonnet_export_\(timestamp).csv")

        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
