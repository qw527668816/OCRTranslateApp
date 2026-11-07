import SwiftUI

@main
struct OCRTranslateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    TranslationManager.shared.loadSettings()
                }
        }
    }
}
