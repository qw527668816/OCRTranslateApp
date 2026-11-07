import Foundation
import Combine

/// 主 App 端的观察者，定时读取 ScreenTranslator Extension
/// 写入 App Group 共享容器的数据（翻译结果 + 广播状态）。
final class BroadcastMonitor: ObservableObject {
    static let shared = BroadcastMonitor()

    @Published var isBroadcasting: Bool = false
    @Published var lastOCRText: String = ""
    @Published var lastTranslatedText: String = ""
    @Published var lastUpdateTime: Date?
    /// 最新一次翻译结果(含逐段原文-译文对照)
    @Published var latestResult: TranslateResult?

    private var timer: Timer?
    private var lastResultID: UUID?

    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID)
    }

    private var translationDataPath: URL? {
        sharedContainerURL?.appendingPathComponent(AppConfig.translationDataFile)
    }

    private var statusPath: URL? {
        sharedContainerURL?.appendingPathComponent(AppConfig.broadcastStatusFile)
    }

    private var stopSignalPath: URL? {
        sharedContainerURL?.appendingPathComponent(AppConfig.stopSignalFile)
    }

    private init() {
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Polling

    private func startPolling() {
        // 每秒读取一次共享容器中的最新结果与状态
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    private func refresh() {
        refreshStatus()
        refreshTranslation()
    }

    private func refreshStatus() {
        guard let path = statusPath,
              let status = try? String(contentsOf: path, encoding: .utf8) else { return }

        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let broadcasting = (trimmed == "broadcasting")

        if broadcasting != isBroadcasting {
            isBroadcasting = broadcasting
        }
    }

    private func refreshTranslation() {
        guard let path = translationDataPath,
              let data = try? Data(contentsOf: path),
              let result = try? JSONDecoder().decode(TranslateResult.self, from: data) else { return }

        // 避免重复刷新同一条结果
        guard result.id != lastResultID else { return }
        lastResultID = result.id

        latestResult = result
        lastOCRText = result.originalText
        lastTranslatedText = result.translatedText
        lastUpdateTime = result.timestamp
    }

    // MARK: - Commands

    /// 写入停止信号文件。
    /// 注意：由于系统限制，主 App 无法直接强制结束 Broadcast Upload Extension，
    /// 用户仍需通过系统控制中心手动停止屏幕录制/直播。
    /// 这里写入信号文件仅用于：
    /// 1. 让 UI 立即反映"已停止"的状态
    /// 2. 供 Extension 在下一帧检查并自行结束
    func sendStopCommand() {
        if let path = stopSignalPath {
            try? "stop".write(to: path, atomically: true, encoding: .utf8)
        }
        isBroadcasting = false
    }
}
