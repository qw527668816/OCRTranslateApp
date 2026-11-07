import SwiftUI

/// 主框架:屏幕翻译(实时)/ 截图翻译(手动)/ 智能体(对话)
struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("屏幕翻译", systemImage: "rectangle.on.rectangle")
                }

            ManualTranslateView()
                .tabItem {
                    Label("截图翻译", systemImage: "photo.on.rectangle")
                }

            AgentChatView()
                .tabItem {
                    Label("智能体", systemImage: "sparkles")
                }

            PocketView()
                .tabItem {
                    Label("口袋", systemImage: "wand.and.stars")
                }
        }
        .background(translationBridge)
    }

    /// iOS 18+ 设备端 Apple 翻译的 session 桥接(0x0 隐藏视图)
    @ViewBuilder
    private var translationBridge: some View {
        if #available(iOS 18.0, *) {
            TranslationBridgeView()
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
