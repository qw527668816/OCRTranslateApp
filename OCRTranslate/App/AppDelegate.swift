import UIKit
import ReplayKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static weak var shared: AppDelegate?
    
    private(set) var isBroadcasting = false
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppDelegate.shared = self
        TranslationManager.shared.loadSettings()
        return true
    }
    
    func refreshBroadcastState() {
        // Broadcast state is tracked via extension messages
    }
    
    func startBroadcast() {
        // This triggers the system broadcast picker
        // The actual broadcast is handled by the extension
    }
}
