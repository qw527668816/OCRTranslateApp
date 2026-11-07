import SwiftUI
import PhotosUI
import UIKit

/// 手动截图翻译:从相册选图或拍照 → 系统 OCR → 逐段对照翻译
struct ManualTranslateView: View {
    @StateObject private var manager = TranslationManager.shared
    @ObservedObject private var pip = PiPOverlay.shared

    @State private var pickedImage: UIImage?
    @State private var segments: [SegmentPair] = []
    @State private var isProcessing = false
    @State private var statusText = ""
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    actionButtons

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

                    if !segments.isEmpty {
                        resultCard
                    }

                    tipsCard
                }
                .padding()
            }
            .navigationTitle("截图翻译")
            .toolbar {
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

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showLibrary = true
            } label: {
                Label("从相册选择", systemImage: "photo.on.rectangle")
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
                    Label("拍照识别", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.tertiarySystemFill))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var resultCard: some View {
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
                if pip.isActive {
                    pip.stop()
                } else {
                    pip.show(segments: segments, bilingual: manager.config.showBilingual)
                }
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

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用说明")
                .font(.headline)
            instructionRow("1.circle.fill", "先把要翻译的画面截屏,或直接拍照")
            instructionRow("2.circle.fill", "点「从相册选择」选中该截图")
            instructionRow("3.circle.fill", "自动识别文字并逐段翻译为对照结果")
            instructionRow("4.circle.fill", "引擎与 API 在「设置」中配置,建议使用 AI 翻译")
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
        statusText = ""
        isProcessing = true

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

                statusText = "正在翻译 \(texts.count) 段…"

                TranslationManager.shared.translateSegments(texts) { pairs in
                    segments = pairs
                    isProcessing = false
                    statusText = pairs.isEmpty ? "翻译失败,请检查 API 配置" : ""
                }
            }
        }
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
