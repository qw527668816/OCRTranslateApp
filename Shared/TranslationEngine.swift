import Foundation

// MARK: - Translation Engine Types

enum TranslationEngineType: String, Codable, CaseIterable {
    case apple = "apple"
    case google = "google"
    case baidu = "baidu"
    case tencent = "tencent"
    case openai = "openai"

    var displayName: String {
        switch self {
        case .apple:   return "Apple 翻译(设备端免费离线)"
        case .google:  return "Google Translate"
        case .baidu:   return "百度翻译"
        case .tencent: return "腾讯翻译"
        case .openai:  return "AI 翻译（OpenAI 兼容）"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .apple: return false
        default:     return true
        }
    }
}

// MARK: - Translation Engine Configuration

struct TranslationEngineConfig: Codable {
    var engineType: TranslationEngineType = .apple

    var apiKey: String = ""
    var apiSecret: String = ""
    var apiEndpoint: String = ""

    var aiModel: String = ""
    /// AI 视觉提取用的识图模型(截图翻译 AI 视觉引擎/识图页)
    var vlmModel: String = ""
    var aiPrompt: String = """
我将给你发送一个JSON对象,键是编号,值是待翻译文本。请把每个值翻译为简体中文,返回一个结构相同的JSON对象:键保持不变,值替换为对应译文。只输出JSON本身,不要解释,不要使用markdown代码块。
"""

    var sourceLanguage: String = "auto"
    var targetLanguage: String = "zh-Hans"

    /// 原文-译文对照显示(关闭则只显示译文)
    var showBilingual: Bool = true
}
