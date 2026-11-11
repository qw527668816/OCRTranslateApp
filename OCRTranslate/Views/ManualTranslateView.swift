import SwiftUI
import PhotosUI
import UIKit

/// 手动截图翻译:相册选图/拍照 → OCR → 逐段对照翻译
/// 两种提取引擎:
///  - 系统 OCR(Vision,免费离线,带文字坐标 → 支持"原位替换"预览)
///  - AI 视觉(VLM,复杂截图更准,仅对照列表)
enum ExtractionEngine: String, CaseIterable {
    case vision = "系统 OCR"
    case vlm = "AI 视觉"
}

struct ManualTranslateView: View {
    @StateObject private var manager = TranslationManager.shared
    @ObservedObject private var pip = PiPOverlay.shared

    @State private var pickedImage: UIImage?
    @State private var segments: [SegmentPair] = []
    @State private var ocrBlocks: [OCRBlockBox] = []   // Vision 识别框(像素坐标)
    @State private var inPlaceImage: UIImage?          // 原位替换渲染结果
    @State private var showInPlace = false             // 结果显示模式
    @State private var canInPlace = false
    @State private var engine: ExtractionEngine = .vision
    @State private var isProcessing = false
    @State private var statusText = ""
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var zoomScale: CGFloat = 1.0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    engineChips
                    actionButtons

                    if let image = pickedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .opacity(showInPlace && inPlaceImage != nil ? 0.25 : 1)
                    }

                    if isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(statusText.isEmpty ? "处理中…" : statusText)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !statusText.isEmpty {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    resultArea

                    tipsCard
                }
                .padding()
            }
            .navigationTitle("截图翻译")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showLibrary) {
                PhotoPicker(image: $pickedImage) {
                    translatePicked()
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $pickedImage) {
                    translatePicked()
                }
            }
        }
    }

    // MARK: - 子视图

    private var engineChips: some View {
        HStack(spacing: 8) {
            ForEach(ExtractionEngine.allCases, id: \.self) { e in
                Button {
                    engine = e
                } label: {
                    Text(e.rawValue)
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(engine == e ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill))
                        .foregroundColor(engine == e ? .accentColor : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showLibrary = true
            } label: {
                Label("相册选图", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.tertiarySystemFill))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    private var resultArea: some View {
        if !segments.isEmpty {
            // 原位替换可用时,提供"原位替换 / 对照列表"切换
            if canInPlace {
                HStack(spacing: 8) {
                    resultModeChip("原位替换", active: showInPlace) { showInPlace = true }
                    resultModeChip("对照列表", active: !showInPlace) { showInPlace = false }
                }
            }

            if showInPlace, let image = inPlaceImage {
                inPlaceCard(image)
            } else {
               对照Card
            }
        }
    }

    private func inPlaceCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("译文已按原位置覆盖(捏合缩放查看)")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView([.vertical, .horizontal]) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width - 32)
                    .scaleEffect(zoomScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoomScale = min(max(1.0, value), 4.0)
                            }
                    )
            }
            .frame(maxHeight: 460)

            HStack(spacing: 14) {
                Button {
                    if let data = image.pngData(),
                       let saved = UIImage(data: data) {
                        UIImageWriteToSavedPhotosAlbum(saved, nil, nil, nil)
                        showToast("已保存到相册")
                    }
                } label: {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button {
                    UIPasteboard.general.string = segments
                        .map { "\($0.original)\n\($0.translated)" }
                        .joined(separator: "\n\n")
                    showToast("已复制对照全文")
                } label: {
                    Label("复制对照", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var 对照Card: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("翻译结果(共 \(segments.count) 段)")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                SegmentListView(segments: segments, showBilingual: manager.config.showBilingual)
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                pip.show(segments: segments, bilingual: manager.config.showBilingual)
            } label: {
                Label(
                    pip.isActive ? "停止悬浮窗" : "画中画悬浮(任意 App 上方)",
                    systemImage: pip.isActive ? "pip.exit" : "pip.enter"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(pip.isActive ? Color.red : Color(.tertiarySystemFill))
                .foregroundColor(pip.isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !pip.statusText.isEmpty {
                Text(pip.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func resultModeChip(_ text: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.footnote)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(active ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill))
                .foregroundColor(active ? .accentColor : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用说明")
                .font(.headline)
            instructionRow("1.circle.fill", "系统 OCR:免费离线、带文字坐标,支持原位替换预览")
            instructionRow("2.circle.fill", "AI 视觉:花体字/复杂截图识别更准,仅对照列表")
            instructionRow("3.circle.fill", "原位替换:译文直接覆盖在截图原文字位置,可缩放查看、存相册")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func instructionRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 翻译流程

    private func translatePicked() {
        guard let image = pickedImage, let cgImage = image.cgImage else {
            statusText = "图片无效,请重新选择"
            return
        }

        segments = []
        ocrBlocks = []
        inPlaceImage = nil
        showInPlace = false
        canInPlace = false
        zoomScale = 1.0
        statusText = ""
        isProcessing = true

        switch engine {
        case .vision:
            runVisionFlow(image: image, cgImage: cgImage)
        case .vlm:
            runVLMFlow(cgImage: cgImage)
        }
    }

    /// 系统 OCR:免费离线,返回文字坐标 → 支持原位替换
    private func runVisionFlow(image: UIImage, cgImage: CGImage) {
        statusText = "正在识别文字(系统 OCR)…"

        OCREngine.shared.recognizeText(from: cgImage) { blocks in
            DispatchQueue.main.async {
                let texts = blocks
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                guard !texts.isEmpty else {
                    isProcessing = false
                    statusText = "未识别到文字,请换一张更清晰的图片"
                    return
                }

                let w = image.size.width
                let h = image.size.height
                ocrBlocks = blocks.enumerated().compactMap { i, b in
                    let text = b.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    // Vision 归一化框(左下原点)→ 像素坐标(左上原点)
                    let rect = CGRect(
                        x: b.boundingBox.origin.x * w,
                        y: (1 - b.boundingBox.origin.y - b.boundingBox.height) * h,
                        width: b.boundingBox.width * w,
                        height: b.boundingBox.height * h
                    )
                    return OCRBlockBox(index: i, text: text, rect: rect)
                }

                statusText = "正在翻译 \(texts.count) 段…"

                manager.translateSegments(texts) { pairs in
                    segments = pairs
                    isProcessing = false

                    if pairs.isEmpty {
                        statusText = "翻译失败,请检查 API 配置"
                        return
                    }

                    manager.appendHistory(segments: pairs, engine: "系统OCR")

                    // 有坐标 → 渲染原位替换
                    if !ocrBlocks.isEmpty {
                        inPlaceImage = OverlayRenderer.render(
                            source: image,
                            blocks: ocrBlocks,
                            translations: pairs.map { $0.translated }
                        )
                        canInPlace = true
                        showInPlace = true
                    }
                }
            }
        }
    }

    /// AI 视觉提取(VLM):复杂截图更准,无坐标 → 仅对照列表
    private func runVLMFlow(cgImage: CGImage) {
        statusText = "第 1/2 步:AI 视觉提取文字…"

        let dataUrl = "data:image/jpeg;base64,\(compressForUpload(cgImage))"
        let model = manager.config.vlmModel.isEmpty ? manager.config.aiModel : manager.config.vlmModel

        Task {
            do {
                let texts = try await VLMExtractor.extract(
                    endpoint: manager.config.apiEndpoint,
                    apiKey: manager.config.apiKey,
                    model: model,
                    dataUrl: dataUrl
                )

                await MainActor.run {
                    statusText = "第 2/2 步:逐段翻译…"
                }

                manager.translateSegments(texts) { pairs in
                    segments = pairs
                    isProcessing = false
                    canInPlace = false
                    showInPlace = false

                    if pairs.isEmpty {
                        statusText = "翻译失败,请检查 API 配置"
                    } else {
                        manager.appendHistory(segments: pairs, engine: "AI视觉")
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    statusText = "AI 视觉提取失败: \(error.localizedDescription)"
                }
            }
        }
    }

    /// 压成 base64 dataURL(最长边 1280,控制上传体积)
    private func compressForUpload(_ cgImage: CGImage) -> String {
        var image = UIImage(cgImage: cgImage)
        let maxSide: CGFloat = 1280
        let maxDimension = max(image.size.width, image.size.height)
        if maxDimension > maxSide {
            let ratio = maxSide / maxDimension
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let scaled = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
            image = scaled
        }
        let jpeg = image.jpegData(compressionQuality: 0.8) ?? Data()
        return jpeg.base64EncodedString()
    }
}

/// OpenAI 兼容接口的多模态原始调用(提取用,返回分段文本数组)
enum VLMExtractor {
    static func extract(endpoint: String, apiKey: String, model: String, dataUrl: String) async throws -> [String] {
        guard !endpoint.isEmpty, !apiKey.isEmpty else { throw LLMError.notConfigured }
        let url = URL(string: OpenAICompatBackend.normalizedEndpoint(endpoint))!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": "识别图片中的所有文字,按阅读顺序分段。返回一个JSON对象:键为编号(\"0\",\"1\"…),值为对应文字段。只输出JSON,不要解释。"],
                    ["type": "image_url", "image_url": ["url": dataUrl]]
                ]
            ]],
            "temperature": 0.2,
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
              let content = message["content"] as? String else {
            throw LLMError.emptyResponse
        }
        let cleaned = OpenAICompatBackend.stripJSONFence(content)
        guard let obj = try? JSONSerialization.jsonObject(with: cleaned.data(using: .utf8) ?? Data()) as? [String: Any],
              !obj.isEmpty else {
            return [cleaned]
        }
        return obj.keys
            .filter { $0.range(of: "^[0-9]+$", options: .regularExpression) != nil }
            .sorted { Int($0)! < Int($1)! }
            .compactMap { obj[$0] as? String }
    }
}

// MARK: - 相册选择(PHPicker,无需相册权限)

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onPicked: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return // 用户取消,不触发翻译
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let img = object as? UIImage {
                        self.parent.image = img
                    }
                    self.parent.onPicked()
                }
            }
        }
    }
}

// MARK: - 相机拍照

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onCaptured: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            picker.dismiss(animated: true)
            parent.onCaptured()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
