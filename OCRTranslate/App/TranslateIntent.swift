import AppIntents
import UIKit

/// 快捷指令动作:翻译剪贴板(逐段对照)
///
/// 在「快捷指令」App 中搜索「翻译剪贴板」即可添加到:
/// 快捷指令流程 / 操作按钮 / 轻点背面 / 锁屏控件 / Siri
/// 使用当前 App 内配置的翻译引擎(Apple 设备端引擎则完全免费离线)。
@available(iOS 16.0, *)
struct TranslateClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "翻译剪贴板"
    static let description = IntentDescription("把剪贴板文字逐段翻译为对照结果(使用 App 内配置的翻译引擎)")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let raw = UIPasteboard.general.string ?? ""
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return .result(dialog: "剪贴板没有可翻译的文字")
        }

        TranslationManager.shared.loadSettings()
        let pairs = await withCheckedContinuation { continuation in
            TranslationManager.shared.translateSegments(lines) { result in
                continuation.resume(returning: result)
            }
        }

        guard !pairs.isEmpty else {
            return .result(dialog: "翻译失败,请检查 App 内的引擎配置")
        }

        let text = pairs
            .map { "\($0.original)\n\($0.translated)" }
            .joined(separator: "\n\n")
        return .result(dialog: IntentDialog(stringLiteral: String(text.prefix(2500))))
    }
}
