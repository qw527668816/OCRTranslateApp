import SwiftUI
import WebKit

/// 「口袋智能体」标签页:内置 pocket.html(问答/对话/翻译/识图/设置)
/// 页面文件打包在 App 内,完全不依赖任何网站;只有调用 AI API 需要联网。
/// 注:iOS 13+ 的 WKWebView 会自动处理网页里的 <input type=file>(弹出系统选图器),无需实现任何委托。
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
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
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

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastRefresh = UUID()
    }
}
