import SwiftUI
import WebKit
import PhotosUI

/// 「口袋智能体」标签页:内置 pocket.html(问答/对话/翻译/识图/设置)
/// 页面文件打包在 App 内,完全不依赖任何网站;只有调用 AI API 需要联网。
struct PocketView: View {
    @State private var refreshToken = UUID()

    var body: some View {
        NavigationView {
            PocketWebView(refreshToken: refreshToken)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("口袋智能体")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            refreshToken = UUID()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        }
    }
}

struct PocketWebView: UIViewRepresentable {
    let refreshToken: UUID

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 允许本地页面正常发起 API 请求
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false

        if let url = Bundle.main.url(forResource: "pocket", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastRefresh != refreshToken {
            context.coordinator.lastRefresh = refreshToken
            webView.reload()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var lastRefresh = UUID()
        /// 网页里 <input type=file> 触发时暂存回调
        var fileCompletion: (([URL]?) -> Void)?

        // MARK: 文件选择(网页里 <input type=file> 触发,iOS 签名是 runOpenPanelWith)

        func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            fileCompletion = completionHandler

            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = parameters.allowsMultipleSelection ? 5 : 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self

            DispatchQueue.main.async {
                var top = webView.window?.rootViewController
                while let presented = top?.presentedViewController {
                    top = presented
                }
                top?.present(picker, animated: true)
            }
        }
    }
}

extension PocketWebView.Coordinator: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let completion = fileCompletion else { return }
        fileCompletion = nil

        let providers = results.map { $0.itemProvider }
        var urls: [URL?] = Array(repeating: nil, count: providers.count)
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
            group.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                defer { group.leave() }
                if let image = object as? UIImage,
                   let data = image.jpegData(compressionQuality: 0.85) {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("pocket_pick_\(UUID().uuidString).jpg")
                    try? data.write(to: url)
                    urls[index] = url
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            let picked = urls.compactMap { $0 }
            completion(picked.isEmpty ? nil : picked)
        }
    }
}
