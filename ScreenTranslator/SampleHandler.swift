import ReplayKit
import Vision
import CoreImage
import UIKit

class SampleHandler: RPBroadcastSampleHandler {

    private let ocrEngine = OCREngine.shared
    private let translationManager = TranslationManager.shared

    private var lastOCRFrame: OCRFrame?
    private var lastProcessTime: TimeInterval = 0
    private var frameCount: Int = 0

    private let processEveryNFrames = 30
    private let minimumProcessInterval: TimeInterval = 1.5

    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID)
    }

    private var translationDataPath: URL? {
        sharedContainerURL?.appendingPathComponent(AppConfig.translationDataFile)
    }

    private var stopSignalPath: URL? {
        sharedContainerURL?.appendingPathComponent(AppConfig.stopSignalFile)
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("[Broadcast] Started")
        translationManager.loadSettings()
        lastOCRFrame = nil
        lastProcessTime = Date().timeIntervalSince1970
        frameCount = 0
        if let path = stopSignalPath {
            try? FileManager.default.removeItem(at: path)
        }
        writeStatus("broadcasting")
    }

    override func broadcastPaused() {
        print("[Broadcast] Paused")
    }

    override func broadcastResumed() {
        print("[Broadcast] Resumed")
    }

    override func broadcastFinished() {
        print("[Broadcast] Finished")
        writeStatus("stopped")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            processVideoFrame(sampleBuffer)
        default:
            break
        }
    }

    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        if shouldStopBroadcast() {
            writeStatus("stopped")
            let error = NSError(domain: "ScreenTranslator", code: 0, userInfo: [NSLocalizedDescriptionKey: "屏幕翻译已停止"])
            finishBroadcastWithError(error)
            return
        }

        frameCount += 1
        guard frameCount % processEveryNFrames == 0 else { return }

        let now = Date().timeIntervalSince1970
        guard now - lastProcessTime >= minimumProcessInterval else { return }
        lastProcessTime = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        let cropRect = OCRRegionConfig.load().cropRect(in: ciImage.extent)
        let croppedImage = ciImage.cropped(to: cropRect)

        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else { return }

        performOCR(on: cgImage)
    }

    private func performOCR(on image: CGImage) {
        let semaphore = DispatchSemaphore(value: 0)

        ocrEngine.recognizeText(from: image) { [weak self] blocks in
            guard let self = self else {
                semaphore.signal()
                return
            }

            let newFrame = OCRFrame(blocks: blocks, timestamp: Date())

            guard self.ocrEngine.hasContentChanged(old: self.lastOCRFrame, new: newFrame) else {
                semaphore.signal()
                return
            }

            self.lastOCRFrame = newFrame

            // 逐段(按 OCR 文本块)翻译,保证原文-译文一一对照
            let segments = newFrame.blocks
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !segments.isEmpty else {
                semaphore.signal()
                return
            }

            print("[OCR] New frame, \(segments.count) segments")

            self.translationManager.translateSegments(segments) { [weak self] pairs in
                guard let self = self, !pairs.isEmpty else {
                    semaphore.signal()
                    return
                }

                let result = TranslateResult(
                    segments: pairs,
                    sourceLanguage: self.translationManager.config.sourceLanguage,
                    targetLanguage: self.translationManager.config.targetLanguage
                )
                self.writeTranslation(result)
                semaphore.signal()
            }
        }

        _ = semaphore.wait(timeout: .now() + 8.0)
    }

    private func shouldStopBroadcast() -> Bool {
        guard let path = stopSignalPath,
              let signal = try? String(contentsOf: path, encoding: .utf8) else {
            return false
        }
        return signal.trimmingCharacters(in: .whitespacesAndNewlines) == "stop"
    }

    private func writeTranslation(_ result: TranslateResult) {
        guard let path = translationDataPath else { return }
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: path, options: .atomic)
        } catch {
            print("[Broadcast] Write error: \(error)")
        }
    }

    private func writeStatus(_ status: String) {
        guard let container = sharedContainerURL else { return }
        let path = container.appendingPathComponent(AppConfig.broadcastStatusFile)
        try? status.write(to: path, atomically: true, encoding: .utf8)
    }
}
