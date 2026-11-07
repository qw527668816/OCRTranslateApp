import AVFoundation
import AVKit
import UIKit

/// 画中画悬浮:把"原文-译文对照"渲染成图片页 → 合成循环视频 → 以画中画小窗悬浮在任意 App 上方。
/// 用于无巨魔/无越狱手机实现"停在原界面看翻译"。
/// 说明:视频仅含画面不含音轨;若真机上离开 App 后小窗自动暂停,
/// 后续可加静音音轨修复(见 docs/自用安装指南.md 测试清单)。
final class PiPOverlay: NSObject, ObservableObject {
    static let shared = PiPOverlay()

    @Published var isActive = false
    @Published var statusText = ""

    private var player: AVPlayer?
    private var pipController: AVPictureInPictureController?
    private var endObserver: NSObjectProtocol?

    private let videoSize = CGSize(width: 720, height: 960)
    private let secondsPerPage: Double = 8

    // MARK: - 对外入口

    func show(segments: [SegmentPair], bilingual: Bool) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            statusText = "此设备不支持画中画"
            return
        }
        guard !segments.isEmpty else {
            statusText = "没有可显示的内容"
            return
        }
        statusText = "正在生成悬浮页…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let pages = Self.renderPages(segments: segments, bilingual: bilingual, size: self.videoSize)
            guard !pages.isEmpty else {
                DispatchQueue.main.async { self.statusText = "没有可显示的内容" }
                return
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("pip_\(UUID().uuidString).mp4")
            do {
                try Self.writeVideo(pages: pages, to: url, size: self.videoSize, secondsPerPage: self.secondsPerPage)
                DispatchQueue.main.async { self.play(url: url) }
            } catch {
                DispatchQueue.main.async { self.statusText = "生成失败: \(error.localizedDescription)" }
            }
        }
    }

    func stop() {
        pipController?.stopPictureInPicture()
        player?.pause()
        player = nil
        pipController = nil
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        isActive = false
        statusText = ""
    }

    // MARK: - 播放与画中画

    private func play(url: URL) {
        stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .none

        // 循环播放
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        // 画中画需要 playback 音频会话
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)

        let layer = AVPlayerLayer(player: player)
        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.canStartPictureInPictureAutomaticallyFromInline = true

        self.player = player
        self.pipController = controller

        player.play()
        controller?.startPictureInPicture()
        isActive = true
        statusText = "悬浮窗已开启,可切换到任意 App"
    }

    // MARK: - 渲染对照页(每页若干段,深色卡片风)

    static func renderPages(segments: [SegmentPair], bilingual: Bool, size: CGSize) -> [UIImage] {
        let perPage = 6
        let pad: CGFloat = 28
        let maxW = size.width - pad * 2
        let oFont = UIFont.systemFont(ofSize: 15, weight: .regular)
        let tFont = UIFont.systemFont(ofSize: 21, weight: .semibold)
        let renderer = UIGraphicsImageRenderer(size: size)

        var pages: [UIImage] = []
        var index = 0

        while index < segments.count {
            let slice = Array(segments[index..<min(index + perPage, segments.count)])
            index += perPage

            let image = renderer.image { ctx in
                UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.97).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))

                var y: CGFloat = pad
                for pair in slice {
                    if bilingual && !pair.original.isEmpty {
                        let oH = (pair.original as NSString).boundingRect(
                            with: CGSize(width: maxW, height: 600),
                            options: [.usesLineFragmentOrigin],
                            attributes: [.font: oFont],
                            context: nil
                        ).height
                        (pair.original as NSString).draw(
                            with: CGRect(x: pad, y: y, width: maxW, height: min(oH + 4, 600)),
                            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                            attributes: [.font: oFont, .foregroundColor: UIColor(white: 1, alpha: 0.55)],
                            context: nil
                        )
                        y += min(oH + 4, 600) + 7
                    }

                    let tH = (pair.translated as NSString).boundingRect(
                        with: CGSize(width: maxW, height: 900),
                        options: [.usesLineFragmentOrigin],
                        attributes: [.font: tFont],
                        context: nil
                    ).height
                    (pair.translated as NSString).draw(
                        with: CGRect(x: pad, y: y, width: maxW, height: min(tH + 4, 900)),
                        options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                        attributes: [.font: tFont, .foregroundColor: UIColor.white],
                        context: nil
                    )
                    y += min(tH + 4, 900) + 20

                    if y > size.height - 60 { break }
                }
            }
            pages.append(image)
        }
        return pages
    }

    // MARK: - 图片页合成循环视频

    static func writeVideo(pages: [UIImage], to url: URL, size: CGSize, secondsPerPage: Double) throws {
        let fps = 12
        let framesPerPage = max(1, Int(secondsPerPage * Double(fps)))
        let totalFrames = framesPerPage * pages.count

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        writer.add(input)

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attrs
        )

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<totalFrames {
            while !input.isReadyForMoreMediaData {
                usleep(3000)
            }
            let pageIndex = min(frame / framesPerPage, pages.count - 1)
            guard let cgImage = pages[pageIndex].cgImage,
                  let pool = adaptor.pixelBufferPool else {
                continue
            }

            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard let pb = pixelBuffer else { continue }

            CVPixelBufferLockBaseAddress(pb, [])
            if let context = CGContext(
                data: CVPixelBufferGetBaseAddress(pb),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) {
                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }
            CVPixelBufferUnlockBaseAddress(pb, [])

            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))
            adaptor.append(pb, withPresentationTime: time)
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "PiPOverlay", code: 2)
        }
    }
}
