import Foundation
import Translation

/// iOS 18+ 设备端 Apple 翻译(免费、离线、无需任何 API Key)
///
/// Translation 框架的 TranslationSession 只能通过 SwiftUI 的 .translationTask 修饰符获取,
/// 这里用一个 0x0 的隐藏桥接视图持有 session,供 App 内任意处复用:
/// - 同一对语言复用已有 session
/// - 语言对变化时,重新赋值 activeConfiguration 触发系统创建新 session
/// - session 失效(切后台等)时自动重建重试一次
@available(iOS 18.0, *)
final class AppleTranslationService: ObservableObject {
    static let shared = AppleTranslationService()

    /// 由桥接视图观察;赋新值(非 nil)会触发 translationTask 并回调 attachSession
    @Published var activeConfiguration: TranslationSession.Configuration?

    private var session: TranslationSession?
    private let lock = NSLock()

    // MARK: - 桥接(由 TranslationBridgeView 调用)

    func attachSession(_ session: TranslationSession) {
        lock.lock()
        self.session = session
        lock.unlock()
    }

    private func waitForSession(timeout: TimeInterval) async throws -> TranslationSession {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            lock.lock()
            let current = session
            lock.unlock()
            if let current { return current }
            guard Date() < deadline else { throw LLMError.sessionTimeout }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - 翻译

    /// 批量翻译:返回与输入一一对应的译文数组
    func translate(texts: [String], source: Locale.Language?, target: Locale.Language) async throws -> [String] {
        let config = TranslationSession.Configuration(source: source, target: target)
        await MainActor.run { self.activeConfiguration = config }

        do {
            let session = try await waitForSession(timeout: 5)
            return try await runBatch(session, texts: texts, source: source, target: target)
        } catch {
            // session 可能已失效(切后台/语言对变化):重建一次再试
            lock.lock()
            self.session = nil
            lock.unlock()
            await MainActor.run {
                self.activeConfiguration = nil
            }
            try await Task.sleep(nanoseconds: 50_000_000)
            let retryConfig = TranslationSession.Configuration(source: source, target: target)
            await MainActor.run {
                self.activeConfiguration = retryConfig
            }
            let retrySession = try await waitForSession(timeout: 3)
            return try await runBatch(retrySession, texts: texts, source: source, target: target)
        }
    }

    private func runBatch(
        _ session: TranslationSession,
        texts: [String],
        source: Locale.Language?,
        target: Locale.Language
    ) async throws -> [String] {
        // 语言包已支持但未下载时,先触发系统准备(首次会有下载弹窗)
        if let source {
            let availability = await LanguageAvailability(source: source, target: target).status
            if availability == .supported {
                try? await session.prepareTranslation()
            }
        }
        let responses = try await session.translations(for: texts)
        return responses.map { $0.targetText }
    }
}

/// 隐藏桥接视图:挂在根视图上,负责向 AppleTranslationService 提供 TranslationSession
@available(iOS 18.0, *)
struct TranslationBridgeView: View {
    @ObservedObject private var service = AppleTranslationService.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(service.activeConfiguration) { session in
                service.attachSession(session)
            }
    }
}
