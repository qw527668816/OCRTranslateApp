import Foundation
import NaturalLanguage

class TranslationManager: ObservableObject {
    static let shared = TranslationManager()

    @Published var config = TranslationEngineConfig()
    @Published var history: [HistoryEntry] = []

    private let defaults = UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    private let configKey = "translationEngineConfig"
    private let historyKey = "translateHistory"

    private init() {
        loadHistory()
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: configKey)
        }
    }

    func loadSettings() {
        guard let data = defaults.data(forKey: configKey),
              let saved = try? JSONDecoder().decode(TranslationEngineConfig.self, from: data) else { return }
        config = saved
    }

    // MARK: - 翻译历史

    struct HistoryEntry: Codable, Identifiable {
        let id: UUID
        let date: Date
        let engine: String
        let segments: [SegmentPair]
    }

    func appendHistory(segments: [SegmentPair], engine: String) {
        guard !segments.isEmpty else { return }
        history.insert(HistoryEntry(id: UUID(), date: Date(), engine: engine, segments: segments), at: 0)
        if history.count > 30 { history = Array(history.prefix(30)) }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    func clearHistory() {
        history = []
        defaults.removeObject(forKey: historyKey)
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        history = saved
    }

    // MARK: - 单段翻译(兼容旧接口)

    func translate(_ text: String, completion: @escaping (String?) -> Void) {
        translateSegments([text]) { pairs in
            completion(pairs.map { $0.translated }.joined(separator: "\n"))
        }
    }

    // MARK: - 分段对照翻译(核心入口)

    /// 输入若干段文字,返回与输入一一对应的"原文-译文"对照数组。
    /// 每个引擎都以"段"为单位翻译,保证第 i 段原文对应第 i 段译文。
    func translateSegments(_ input: [String], completion: @escaping ([SegmentPair]) -> Void) {
        let segments = input
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(AppConfig.maxSegmentsPerRequest)
            .map { String($0) }

        guard !segments.isEmpty else {
            completion([])
            return
        }

        // 统一保证回调在主线程(UI 与扩展都安全)
        let mainCompletion: ([SegmentPair]) -> Void = { pairs in
            DispatchQueue.main.async { completion(pairs) }
        }

        switch config.engineType {
        case .apple:
            translateWithApple(segments, completion: mainCompletion)
        case .google:
            translateWithGoogle(segments, completion: mainCompletion)
        case .baidu:
            translateWithBaidu(segments, completion: mainCompletion)
        case .tencent:
            translateWithTencent(segments, completion: mainCompletion)
        case .openai:
            translateWithAI(segments, completion: mainCompletion)
        }
    }

    // MARK: - Apple 设备端翻译(iOS 18+,免费离线,无需任何 Key)

    private func translateWithApple(_ segments: [String], completion: @escaping ([SegmentPair]) -> Void) {
#if SCREEN_EXTENSION
        // 录屏扩展无 UI,无法通过 SwiftUI 桥接创建 TranslationSession,引导用户切换引擎
        completion(self.errorPair(
            segments,
            "[实时屏幕翻译暂不支持 Apple 设备端引擎,请在设置中改用 AI 翻译或百度翻译]"
        ))
#else
        if #available(iOS 18.0, *) {
            let target = Locale.Language(identifier: config.targetLanguage)

            // 整批统一检测源语言(同屏通常同语言);检测不出则交给系统自动判断
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(segments.joined(separator: "\n"))
            let source = recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue) }

            Task {
                do {
                    let results = try await AppleTranslationService.shared.translate(
                        texts: segments,
                        source: source,
                        target: target
                    )
                    let pairs = zip(segments, results).map { pair in
                        SegmentPair(original: pair.0, translated: pair.1)
                    }
                    completion(pairs)
                } catch {
                    completion(self.errorPair(segments, "[Apple 翻译失败: \(error.localizedDescription)]"))
                }
            }
        } else {
            completion(self.errorPair(
                segments,
                "[Apple 设备端翻译需要 iOS 18.0 及以上,请改用 AI 翻译或百度翻译引擎]"
            ))
        }
#endif
    }

    // MARK: - Google Translate(一次请求携带多段,按顺序配对)

    private func translateWithGoogle(_ segments: [String], completion: @escaping ([SegmentPair]) -> Void) {
        guard !config.apiKey.isEmpty else {
            completion(errorPair(segments, "[请配置 Google API Key]"))
            return
        }

        let targetLang = config.targetLanguage == "zh-Hans" ? "zh-CN" : config.targetLanguage

        var body: [String: Any] = [
            "q": segments,
            "target": targetLang,
            "format": "text",
            "key": config.apiKey
        ]
        if config.sourceLanguage != "auto" {
            body["source"] = config.sourceLanguage
        }

        guard let url = URL(string: "https://translation.googleapis.com/language/translate/v2"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else {
            completion(errorPair(segments, "[Google翻译请求构造失败]"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard error == nil, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataObj = json["data"] as? [String: Any],
                      let translations = dataObj["translations"] as? [[String: Any]] else {
                    completion(self.errorPair(segments, "[Google翻译失败]"))
                    return
                }

                var pairs: [SegmentPair] = []
                for (i, seg) in segments.enumerated() where i < translations.count {
                    let translated = translations[i]["translatedText"] as? String ?? ""
                    pairs.append(SegmentPair(original: seg, translated: translated))
                }
                completion(pairs.count == segments.count ? pairs : self.errorPair(segments, "[Google翻译结果数量不匹配]"))
            }
        }.resume()
    }

    // MARK: - Baidu Translate(trans_result 天然按段返回 src/dst)

    private func translateWithBaidu(_ segments: [String], completion: @escaping ([SegmentPair]) -> Void) {
        guard !config.apiKey.isEmpty, !config.apiSecret.isEmpty else {
            completion(errorPair(segments, "[请配置百度翻译 AppID 和密钥]"))
            return
        }

        let salt = "\(Int.random(in: 10000...99999))"
        let q = segments.joined(separator: "\n")
        let signStr = config.apiKey + q + salt + config.apiSecret
        let sign = signStr.md5

        let sourceLang = config.sourceLanguage == "auto" ? "auto" : config.sourceLanguage
        let targetLang = config.targetLanguage == "zh-Hans" ? "zh" : config.targetLanguage

        var components = URLComponents(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")
        components?.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "from", value: sourceLang),
            URLQueryItem(name: "to", value: targetLang),
            URLQueryItem(name: "appid", value: config.apiKey),
            URLQueryItem(name: "salt", value: salt),
            URLQueryItem(name: "sign", value: sign)
        ]

        guard let url = components?.url else {
            completion(errorPair(segments, "[百度翻译URL错误]"))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                let json = (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any]
                guard error == nil,
                      let results = json?["trans_result"] as? [[String: Any]] else {
                    let errMsg = (json?["error_msg"] as? String).map { "[百度翻译失败: \($0)]" } ?? "[百度翻译失败]"
                    completion(self.errorPair(segments, errMsg))
                    return
                }

                let pairs: [SegmentPair] = segments.enumerated().compactMap { (i, seg) -> SegmentPair? in
                    guard i < results.count, let dst = results[i]["dst"] as? String else { return nil }
                    return SegmentPair(original: seg, translated: dst)
                }
                completion(pairs.isEmpty ? self.errorPair(segments, "[百度翻译结果为空]") : pairs)
            }
        }.resume()
    }

    // MARK: - Tencent (占位)

    private func translateWithTencent(_ segments: [String], completion: @escaping ([SegmentPair]) -> Void) {
        completion(errorPair(segments, "[腾讯翻译需要完整SDK,请使用其他引擎]"))
    }

    // MARK: - AI Translation(OpenAI 兼容,JSON 键值逐段回填)

    private func translateWithAI(_ segments: [String], completion: @escaping ([SegmentPair]) -> Void) {
        guard !config.apiEndpoint.isEmpty, !config.apiKey.isEmpty else {
            completion(errorPair(segments, "[请配置AI翻译API地址和Key]"))
            return
        }

        // 键 = 段落编号,值 = 原文;要求模型按相同键回填译文,保证逐段对应不串行
        let textDict = Dictionary(uniqueKeysWithValues: segments.enumerated().map { ("\($0.offset)", $0.element) })
        guard let jsonData = try? JSONSerialization.data(withJSONObject: textDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(errorPair(segments, "[AI翻译数据格式错误]"))
            return
        }

        let prompt = config.aiPrompt.isEmpty
            ? "Translate the following JSON values to \(config.targetLanguage). Keep the JSON keys unchanged, return only the JSON."
            : config.aiPrompt

        let messages = [
            ChatMessage(role: "system", content: prompt),
            ChatMessage(role: "user", content: jsonString)
        ]

        let model = config.aiModel.isEmpty ? "gpt-3.5-turbo" : config.aiModel
        let backend = OpenAICompatBackend(endpoint: config.apiEndpoint, apiKey: config.apiKey)

        Task {
            do {
                let content = try await backend.chat(messages: messages, model: model, temperature: 0.2)
                let cleaned = OpenAICompatBackend.stripJSONFence(content)

                if let contentData = cleaned.data(using: .utf8),
                   let resultDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                   !resultDict.isEmpty {
                    var pairs: [SegmentPair] = []
                    var matched = true
                    for (i, seg) in segments.enumerated() {
                        if let v = resultDict["\(i)"] as? String, !v.isEmpty {
                            pairs.append(SegmentPair(original: seg, translated: v))
                        } else {
                            matched = false
                            break
                        }
                    }
                    if matched {
                        completion(pairs)
                        return
                    }
                }
                // 模型未按 JSON 返回时,整体作为一段译文,保证不丢结果
                completion([SegmentPair(original: segments.joined(separator: "\n"), translated: cleaned)])
            } catch {
                completion(self.errorPair(segments, "[AI翻译失败: \(error.localizedDescription)]"))
            }
        }
    }

    // MARK: - Helpers

    /// 出错时保留原文,错误信息作为译文,便于用户看到是哪一段出了问题
    private func errorPair(_ segments: [String], _ message: String) -> [SegmentPair] {
        [SegmentPair(original: segments.joined(separator: "\n"), translated: message)]
    }
}

import CryptoKit

extension String {
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
