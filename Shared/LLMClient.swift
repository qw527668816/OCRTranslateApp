import Foundation

// MARK: - 消息与错误

struct ChatMessage: Codable, Equatable {
    var role: String   // "system" / "user" / "assistant"
    var content: String
}

enum LLMError: LocalizedError {
    case notConfigured
    case httpError(Int, String)
    case emptyResponse
    case localNotEnabled
    case sessionTimeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "请先在设置中配置 AI 翻译引擎的 API 地址和 Key"
        case .httpError(let code, let body):
            return "API 请求失败(\(code)): \(body.prefix(200))"
        case .emptyResponse:
            return "API 返回内容为空"
        case .localNotEnabled:
            return "本地模型暂未启用(接口已预留,见 LLMClient.swift)"
        case .sessionTimeout:
            return "翻译会话未就绪,请重试"
        }
    }
}

// MARK: - 模型后端抽象(本地 AI 的对接窗口)

/// 当前实现:OpenAICompatBackend(云端 OpenAI 兼容接口)
/// 预留:本地端侧模型(MLX / llama.cpp / 国行 Apple 智能端侧模型等)。
/// 后续只需新增一个实现 ChatBackend 的 struct,在选取后端处切换即可,上层无需改动。
protocol ChatBackend {
    var backendName: String { get }
    func chat(messages: [ChatMessage], model: String, temperature: Double) async throws -> String
}

// MARK: - OpenAI 兼容后端(DeepSeek / 通义 / Kimi / 百度千帆 / OpenAI 等)

struct OpenAICompatBackend: ChatBackend {
    var endpoint: String
    var apiKey: String

    var backendName: String { "OpenAI 兼容" }

    /// 兼容三种填法:
    /// https://api.deepseek.com                    -> https://api.deepseek.com/v1/chat/completions
    /// https://api.deepseek.com/v1                 -> https://api.deepseek.com/v1/chat/completions
    /// https://api.deepseek.com/v1/chat/completions-> 原样使用
    static func normalizedEndpoint(_ raw: String) -> String {
        var e = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while e.hasSuffix("/") { e.removeLast() }
        if e.hasSuffix("/chat/completions") { return e }
        if e.hasSuffix("/v1") { return e + "/chat/completions" }
        return e + "/v1/chat/completions"
    }

    func chat(messages: [ChatMessage], model: String, temperature: Double) async throws -> String {
        guard !endpoint.isEmpty, !apiKey.isEmpty else { throw LLMError.notConfigured }

        guard let url = URL(string: Self.normalizedEndpoint(endpoint)) else {
            throw LLMError.httpError(-1, "API 地址无效: \(endpoint)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw LLMError.httpError(code, String(data: data, encoding: .utf8) ?? "")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty else {
            throw LLMError.emptyResponse
        }
        return content
    }

    /// 去掉模型可能输出的 ```json ... ``` 围栏
    static func stripJSONFence(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if let fenceRange = t.range(of: "```", options: .backwards) {
                t = String(t[..<fenceRange.lowerBound])
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 本地模型后端(接口预留,暂不启用)

/// 本地 AI 先待定:保留此接口桩。
/// 未来可对接:设备端 Apple 智能(Foundation Models)、MLX、llama.cpp 等,
/// 实现本协议后即可在设置中切换,翻译/智能体所有功能无需改动。
struct LocalAIBackend: ChatBackend {
    var backendName: String { "本地模型(预留)" }

    func chat(messages: [ChatMessage], model: String, temperature: Double) async throws -> String {
        throw LLMError.localNotEnabled
    }
}
