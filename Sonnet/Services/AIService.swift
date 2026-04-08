import Foundation

struct ParsedRecordResult: Codable {
    let amount: Double?
    let merchant: String?
    let category: String?
    let date: String?
    let note: String?
    let type: Int?
    let confidence: Double

    init(
        amount: Double? = nil,
        merchant: String? = nil,
        category: String? = nil,
        date: String? = nil,
        note: String? = nil,
        type: Int? = nil,
        confidence: Double = 0
    ) {
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.date = date
        self.note = note
        self.type = type
        self.confidence = confidence
    }
}

typealias ParsedRecord = ParsedRecordResult

// MARK: - AI 服务

@Observable
final class AIService {
    private let client: OpenRouterClient

    init(client: OpenRouterClient = .shared) {
        self.client = client
    }

    // MARK: - 小票 OCR 解析

    /// 从 OCR 文本解析单条账单记录（小票场景）
    func parseReceipt(ocrText: String) async throws -> ParsedRecord {
        let system = """
        你是专业的小票解析助手。从 OCR 识别文本中提取消费信息，只返回 JSON，不要任何解释，不要 markdown。
        JSON 格式：{"amount":数字,"merchant":"商家","category":"分类","date":"日期字符串","note":"备注","type":0,"confidence":0.0}
        其中 type 0=支出 1=收入，category 从以下选择：餐饮/交通/购物/日用/娱乐/医疗/教育/通讯/其他。
        如果无法识别某字段，对应值设为 null。
        """
        let user = "OCR 文本：\n\(ocrText)"
        let raw = try await client.chat(system: system, user: user)
        return parseRecordJSON(raw, defaultConfidence: 0.85)
    }

    /// 从 OCR 文本解析多条记录（账单截图场景）
    func parseBillScreenshot(ocrText: String) async throws -> [ParsedRecord] {
        let system = """
        你是专业的账单解析助手。从 OCR 识别文本中提取所有消费记录，只返回 JSON 数组，不要任何解释，不要 markdown。
        JSON 格式：[{"amount":数字,"merchant":"商家","category":"分类","date":"日期","note":"备注","type":0,"confidence":0.0}]
        category 从以下选择：餐饮/交通/购物/日用/娱乐/医疗/教育/通讯/其他。
        如果文本中没有账单信息，返回空数组 []。
        """
        let user = "OCR 文本：\n\(ocrText)"
        let raw = try await client.chat(system: system, user: user)
        return parseRecordArrayJSON(raw)
    }

    // MARK: - 分类推断

    /// 根据备注内容推断最匹配的分类名
    func suggestCategory(note: String, categories: [String]) async throws -> String {
        let catList = categories.joined(separator: "、")
        let system = """
        你是记账分类助手。根据用户备注内容，从给定分类中选择最匹配的一个，只返回分类名，不要任何解释。
        可选分类：\(catList)
        如果都不匹配，返回"其他"。
        """
        let result = try await client.chat(system: system, user: note)
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return categories.contains(cleaned) ? cleaned : "其他"
    }

    // MARK: - 语音输入解析

    /// 从语音转文字结果解析记账信息
    func parseVoiceInput(text: String) async throws -> ParsedRecord {
        let system = """
        你是语音记账助手。从用户语音转文字中提取记账信息，只返回 JSON，不要任何解释，不要 markdown。
        JSON 格式：{"amount":数字,"merchant":"商家","category":"分类","note":"备注","type":0,"confidence":0.0}
        其中 type 0=支出 1=收入，category 从以下选择：餐饮/交通/购物/日用/娱乐/医疗/教育/通讯/工资/兼职/理财/红包/其他。
        示例："吃饭花了35块" → {"amount":35,"merchant":null,"category":"餐饮","note":"吃饭","type":0}
        """
        let raw = try await client.chat(system: system, user: text)
        return parseRecordJSON(raw, defaultConfidence: 0.75)
    }

    // MARK: - 月度洞察

    /// 根据分类汇总生成月度消费洞察
    func generateMonthlyInsight(summaries: [CategorySummary]) async throws -> String {
        guard !summaries.isEmpty else {
            return "记录再多一点，我会把这个月的消费节奏梳理给你。"
        }
        let total = summaries.reduce(0.0) { $0 + $1.totalAmount }
        let top = summaries.prefix(4)
            .map { "\($0.category.name) ¥\(String(format: "%.1f", $0.totalAmount))（\(Int($0.percentage * 100))%）" }
            .joined(separator: "、")

        let system = """
        你是温暖克制的记账助手。根据月度消费数据，用两句话给出消费洞察和建议。
        语气自然、有信息量、不说教。回复控制在80字以内。
        """
        let user = "本月消费总额 ¥\(String(format: "%.2f", total))，主要花销：\(top)。"
        return try await client.chat(system: system, user: user)
    }

    // MARK: - 已有方法（向后兼容）

    func generateInsight(monthExpense: Double, categories: [CategorySummary]) async throws -> String {
        try await generateMonthlyInsight(summaries: categories)
    }

    func categorize(text: String) async throws -> String {
        try await suggestCategory(
            note: text,
            categories: ["餐饮", "交通", "购物", "日用", "娱乐", "医疗", "教育", "通讯", "其他"]
        )
    }

    // MARK: - 笔记 AI 功能

    /// 总结笔记要点（3-5 条，带序号）
    func summarizeNote(content: String) async throws -> String {
        let system = """
        你是一个学习助手。请用3-5个要点总结以下课堂笔记的核心内容。
        用简洁的中文，每个要点一行，前面加序号（1. 2. 3. …）。
        不要有多余说明，直接输出要点列表。
        """
        return try await client.chat(system: system, user: content)
    }

    /// 扩展解释选中文字
    func explainText(_ text: String) async throws -> String {
        let system = """
        你是一个知识渊博的学习助手。请用简洁易懂的中文解释以下概念或内容，
        举1-2个例子帮助理解。回复控制在150字以内。
        """
        return try await client.chat(system: system, user: text)
    }

    /// 将笔记整理成 Markdown 大纲
    func generateOutline(content: String) async throws -> String {
        let system = """
        请将以下笔记内容整理成层级大纲（用 Markdown 缩进格式）。
        用 # ## ### 表示层级，要点用 - 列出。只输出大纲，不要说明。
        """
        return try await client.chat(system: system, user: content)
    }

    /// 总结学习资料，适合 PDF / 课件文本
    func summarizeStudyMaterial(title: String, content: String) async throws -> String {
        let system = """
        你是一个克制、清晰的学习助手。请根据用户提供的学习资料正文，输出一份适合放进课堂笔记的中文摘要。
        要求：
        1. 先给出 3-5 条核心要点，每条单独一行。
        2. 再给出一个“适合复习时看的简短结论”。
        3. 不要空话，不要寒暄，不要 markdown 代码块。
        """
        let user = "资料标题：\(title)\n\n资料正文：\n\(content)"
        return try await client.chat(system: system, user: user)
    }

    // MARK: - JSON 解析工具

    private func parseRecordJSON(_ raw: String, defaultConfidence: Double) -> ParsedRecord {
        guard
            let jsonStr = extractJSON(from: raw),
            let data = jsonStr.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(ParsedRecordResult.self, from: data)
        else {
            return ParsedRecord(confidence: 0)
        }

        return ParsedRecord(
            amount: decoded.amount,
            merchant: decoded.merchant,
            category: decoded.category,
            date: decoded.date,
            note: decoded.note,
            type: decoded.type,
            confidence: decoded.confidence > 0 ? decoded.confidence : defaultConfidence
        )
    }

    private func parseRecordArrayJSON(_ raw: String) -> [ParsedRecord] {
        guard
            let jsonStr = extractJSONArray(from: raw),
            let data = jsonStr.data(using: .utf8),
            let arr = try? JSONDecoder().decode([ParsedRecordResult].self, from: data)
        else { return [] }

        return arr.map { item in
            ParsedRecord(
                amount: item.amount,
                merchant: item.merchant,
                category: item.category,
                date: item.date,
                note: item.note,
                type: item.type,
                confidence: item.confidence > 0 ? item.confidence : 0.8
            )
        }
    }

    /// 从 AI 回复中抽取 JSON 对象字符串（处理 markdown 代码块）
    private func extractJSON(from text: String) -> String? {
        // 去掉 ```json ... ``` 包裹
        if let range = text.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }

    private func extractJSONArray(from text: String) -> String? {
        if let range = text.range(of: #"\[[\s\S]*\]"#, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
}
