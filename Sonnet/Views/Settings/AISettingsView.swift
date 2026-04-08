import SwiftUI

struct AISettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var apiKey: String = ""
    @State private var aiModel: String = OpenRouterClient.defaultModel
    @State private var aiEnabled: Bool = true
    @State private var usingBundledKey = false

    @State private var isTestingConnection = false
    @State private var connectionResult: ConnectionResult? = nil
    @FocusState private var apiKeyFocused: Bool

    private let models: [(id: String, label: String, desc: String)] = [
        ("anthropic/claude-3-haiku", "Claude Haiku", "速度快，适合日常记账"),
        ("google/gemini-flash-1.5", "Gemini Flash", "便宜且响应快"),
        ("deepseek/deepseek-chat", "DeepSeek", "长文本解析表现稳定"),
        ("qwen/qwen-2.5-72b-instruct", "Qwen", "中文理解更自然")
    ]

    enum ConnectionResult {
        case success, failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SonnetCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionLabel("AI 状态")

                        Rectangle()
                            .fill(SonnetColors.paperLine)
                            .frame(height: 0.5)
                            .padding(.leading, 18)

                        Toggle(isOn: Binding(
                            get: { aiEnabled },
                            set: { newValue in
                                aiEnabled = newValue
                                appState.setAIEnabled(newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("启用 AI 辅助")
                                    .font(SonnetTypography.body)
                                    .foregroundStyle(SonnetColors.textTitle)
                                Text("用于 OCR 解析、语音记账和消费洞察")
                                    .font(SonnetTypography.caption2)
                                    .foregroundStyle(SonnetColors.textCaption)
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 60)
                        .tint(SonnetColors.ink)

                        Rectangle()
                            .fill(SonnetColors.paperLine)
                            .frame(height: 0.5)
                            .padding(.leading, 18)

                        HStack {
                            Text("当前状态")
                                .font(SonnetTypography.body)
                                .foregroundStyle(SonnetColors.textTitle)
                            Spacer()
                            Text(statusText)
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(statusColor)
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 52)
                    }
                }

                SonnetCard {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionLabel("OpenRouter API Key")

                        Rectangle()
                            .fill(SonnetColors.paperLine)
                            .frame(height: 0.5)
                            .padding(.leading, 18)

                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(apiKey.isEmpty ? SonnetColors.textHint : SonnetColors.ink)

                            SecureField("sk-or-...", text: $apiKey)
                                .font(SonnetTypography.footnote)
                                .foregroundStyle(SonnetColors.textBody)
                                .focused($apiKeyFocused)

                            if appState.aiConfiguration.hasAPIKey {
                                Circle()
                                    .fill(SonnetColors.jade)
                                    .frame(width: 6, height: 6)
                            }
                        }
                            .padding(.horizontal, 18)
                            .frame(height: 52)

                        if usingBundledKey {
                            Rectangle()
                                .fill(SonnetColors.paperLine)
                                .frame(height: 0.5)
                                .padding(.leading, 18)

                            Text("当前已通过本地安全配置提供 API Key。填写并保存后，会优先使用你自己的 Key。")
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(SonnetColors.textCaption)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                        }

                        Rectangle()
                            .fill(SonnetColors.paperLine)
                            .frame(height: 0.5)
                            .padding(.leading, 18)

                        Button {
                            testConnection()
                        } label: {
                            HStack {
                                Text("测试连接")
                                    .font(SonnetTypography.body)
                                    .foregroundStyle(apiKey.isEmpty ? SonnetColors.textHint : SonnetColors.ink)
                                Spacer()
                                connectionStatusView
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 52)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentKeyForTesting.isEmpty || isTestingConnection)

                        Rectangle()
                            .fill(SonnetColors.paperLine)
                            .frame(height: 0.5)
                            .padding(.leading, 18)

                        HStack(spacing: 10) {
                            InkButton(title: "保存本地 Key", action: saveAPIKey, style: .primary)
                            InkButton(title: "清除本地 Key", action: clearAPIKey, style: .ghost)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                    }
                }

                SonnetCard {
                    VStack(spacing: 0) {
                        sectionLabel("模型选择")

                        Rectangle()
                            .fill(SonnetColors.paperLine)
                            .frame(height: 0.5)
                            .padding(.leading, 18)

                        ForEach(Array(models.enumerated()), id: \.element.id) { idx, model in
                            modelRow(model: model, isLast: idx == models.count - 1)
                        }
                    }
                }

                // ── 说明 ────────────────────────────────
                SonnetCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 15))
                            .foregroundStyle(SonnetColors.inkPale)
                            .padding(.top, 1)
                        Text("AI 功能通过 OpenRouter 调用。API Key 仅存储在本地设备，不会上传至任何服务器。用于智能分类识别和消费洞察分析。")
                            .font(SonnetTypography.footnote)
                            .foregroundStyle(SonnetColors.textCaption)
                            .lineSpacing(4)
                    }
                    .padding(16)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(SonnetColors.paper)
        .navigationTitle("AI 设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncFromStorage()
        }
    }

    // MARK: – Sub-views

    private var statusText: String {
        if !aiEnabled { return "已关闭" }
        if appState.aiConfiguration.hasAPIKey { return "可用" }
        return "待配置"
    }

    private var statusColor: Color {
        if !aiEnabled { return SonnetColors.textCaption }
        return appState.aiConfiguration.hasAPIKey ? SonnetColors.jade : SonnetColors.amber
    }

    private var currentKeyForTesting: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? KeychainManager.loadAPIKey() : trimmed
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(SonnetTypography.caption1)
            .foregroundStyle(SonnetColors.textCaption)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        if isTestingConnection {
            ProgressView()
                .scaleEffect(0.7)
                .tint(SonnetColors.ink)
        } else if let result = connectionResult {
            switch result {
            case .success:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("连接成功")
                }
                .font(SonnetTypography.caption1)
                .foregroundStyle(SonnetColors.jade)
            case .failure(let msg):
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                    Text(msg)
                }
                .font(SonnetTypography.caption1)
                .foregroundStyle(SonnetColors.vermilion)
                .lineLimit(1)
            }
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(SonnetColors.textHint)
        }
    }

    @ViewBuilder
    private func modelRow(model: (id: String, label: String, desc: String), isLast: Bool) -> some View {
        Button {
            withAnimation(SonnetMotion.spring) {
                aiModel = model.id
                appState.setAIModel(model.id)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.label)
                        .font(SonnetTypography.body)
                        .foregroundStyle(SonnetColors.textTitle)
                    Text(model.desc)
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(SonnetColors.textCaption)
                }
                Spacer()
                if aiModel == model.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(SonnetColors.ink)
                } else {
                    Circle()
                        .strokeBorder(SonnetColors.paperLine, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
        }
        .buttonStyle(.plain)

        if !isLast {
            Rectangle()
                .fill(SonnetColors.paperLine)
                .frame(height: 0.5)
                .padding(.leading, 18)
        }
    }

    // MARK: – Actions

    private func syncFromStorage() {
        aiEnabled = UserDefaults.standard.object(forKey: AppState.aiEnabledKey) as? Bool ?? true
        aiModel = UserDefaults.standard.string(forKey: OpenRouterClient.modelUserDefaultsKey) ?? OpenRouterClient.defaultModel
        usingBundledKey = !KeychainManager.hasCustomAPIKey() && !KeychainManager.loadAPIKey().isEmpty
        apiKey = KeychainManager.hasCustomAPIKey() ? KeychainManager.loadAPIKey() : ""
        appState.refreshAIConfiguration()
    }

    private func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainManager.saveAPIKey(trimmed)
            usingBundledKey = false
            connectionResult = .success
            apiKeyFocused = false
            appState.refreshAIConfiguration()
            HapticManager.success()
        } catch {
            connectionResult = .failure("保存失败")
            HapticManager.error()
        }
    }

    private func clearAPIKey() {
        KeychainManager.deleteAPIKey()
        apiKey = ""
        usingBundledKey = !KeychainManager.loadAPIKey().isEmpty
        connectionResult = nil
        appState.refreshAIConfiguration()
        HapticManager.warning()
    }

    private func testConnection() {
        let keyToTest = currentKeyForTesting
        guard !keyToTest.isEmpty else { return }
        isTestingConnection = true
        connectionResult = nil

        Task {
            var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
            request.setValue("Bearer \(keyToTest)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    isTestingConnection = false
                    connectionResult = code == 200 ? .success : .failure("状态码 \(code)")
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    connectionResult = .failure("网络错误")
                }
            }
        }
    }

    init() {}
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
    .background(SonnetColors.paper)
    .environment(AppState())
}
