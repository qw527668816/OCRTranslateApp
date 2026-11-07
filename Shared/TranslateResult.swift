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

    /// 主键集合:只包含存储属性,Encodable 可自动合成
    private enum CodingKeys: String, CodingKey {
        case id, segments, sourceLanguage, targetLanguage, timestamp
    }

    /// 旧版本文件的键集合(只有 originalText/translatedText,没有 segments)
    private enum LegacyKeys: String, CodingKey {
        case originalText, translatedText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sourceLanguage = try c.decode(String.self, forKey: .sourceLanguage)
        targetLanguage = try c.decode(String.self, forKey: .targetLanguage)
        timestamp = try c.decode(Date.self, forKey: .timestamp)

        if let segs = try? c.decode([SegmentPair].self, forKey: .segments), !segs.isEmpty {
            segments = segs
        } else if let legacy = try? decoder.container(keyedBy: LegacyKeys.self) {
            let o = (try? legacy.decode(String.self, forKey: .originalText)) ?? ""
            let t = (try? legacy.decode(String.self, forKey: .translatedText)) ?? ""
            segments = [SegmentPair(original: o, translated: t)]
        } else {
            segments = []
        }
    }
}
