import Foundation

// MARK: - 错误类型

enum OpenRouterError: Error, LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int)
    case parseError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:           return "未配置 API Key，请在设置中填写 OpenRouter Key"
        case .httpError(let code):     return "请求失败 (HTTP \(code))"
        case .parseError(let msg):     return "解析响应失败: \(msg)"
        case .networkError(let err):   return "网络错误: \(err.localizedDescription)"
        }
    }
}

// MARK: - OpenRouter API 客户端（actor 保证线程安全）

actor OpenRouterClient {
    static let shared = OpenRouterClient()
    static let modelUserDefaultsKey = "openrouter_selected_model"
    static let defaultModel = "anthropic/claude-3-haiku"

    private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private let session: URLSession

    /// 当前选用模型（存 UserDefaults）
    var selectedModel: String {
        get { UserDefaults.standard.string(forKey: Self.modelUserDefaultsKey) ?? Self.defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: Self.modelUserDefaultsKey) }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - 核心请求

    /// 发送聊天请求，返回 AI 纯文本回复
    func chat(system: String, user: String, model: String? = nil) async throws -> String {
        let apiKey = await MainActor.run { KeychainManager.loadAPIKey() }
        guard !apiKey.isEmpty else { throw OpenRouterError.missingAPIKey }

        let resolvedModel = model ?? selectedModel

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue("Sonnet/1.0",        forHTTPHeaderField: "X-Title")
        request.setValue("https://sonnet.app", forHTTPHeaderField: "HTTP-Referer")

        let body: [String: Any] = [
            "model": resolvedModel,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user]
            ],
            "max_tokens": 512,
            "temperature": 0.15
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenRouterError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OpenRouterError.httpError(statusCode: http.statusCode)
        }

        guard
            let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices  = json["choices"] as? [[String: Any]],
            let message  = choices.first?["message"] as? [String: Any],
            let content  = message["content"] as? String
        else {
            throw OpenRouterError.parseError("无法从响应中提取内容")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 便捷方法（单 prompt 调用）

    func complete(prompt: String, model: String? = nil) async throws -> String {
        try await chat(system: "你是一个智能记账助手，请简洁准确地回答。", user: prompt, model: model)
    }
}
