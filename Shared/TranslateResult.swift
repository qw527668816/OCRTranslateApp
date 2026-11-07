import Foundation

/// 一段"原文-译文"对照单元
struct SegmentPair: Codable, Equatable {
    var original: String
    var translated: String
}

/// 一次翻译结果:由若干"原文-译文"分段组成,保证逐句对照不串行
struct TranslateResult: Codable, Equatable {
    let id: UUID
    var segments: [SegmentPair]
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date

    var originalText: String { segments.map { $0.original }.joined(separator: "\n") }
    var translatedText: String { segments.map { $0.translated }.joined(separator: "\n") }

    init(segments: [SegmentPair], sourceLanguage: String, targetLanguage: String) {
        self.id = UUID()
        self.segments = segments
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = Date()
    }

    /// 兼容旧版单条结果
    init(originalText: String, translatedText: String, sourceLanguage: String, targetLanguage: String) {
        self.init(
            segments: [SegmentPair(original: originalText, translated: translatedText)],
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, segments, sourceLanguage, targetLanguage, timestamp
        case originalText, translatedText
    }

    /// 兼容旧版本写入磁盘的 JSON(只有 originalText/translatedText,没有 segments)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sourceLanguage = try c.decode(String.self, forKey: .sourceLanguage)
        targetLanguage = try c.decode(String.self, forKey: .targetLanguage)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        if let segs = try? c.decode([SegmentPair].self, forKey: .segments) {
            segments = segs
        } else {
            let o = (try? c.decode(String.self, forKey: .originalText)) ?? ""
            let t = (try? c.decode(String.self, forKey: .translatedText)) ?? ""
            segments = [SegmentPair(original: o, translated: t)]
        }
    }
}
