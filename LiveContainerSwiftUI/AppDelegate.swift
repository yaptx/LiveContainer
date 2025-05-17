import UIKit
import SwiftUI

@objc class AppDelegate: UIResponder, UIApplicationDelegate {
        
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? ) -> Bool {
        application.shortcutItems = nil
        UserDefaults.standard.removeObject(forKey: "LCNeedToAcquireJIT")
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            // Fix launching app if user opens JIT waiting dialog and kills the app. Won't trigger normally.
            if DataManager.shared.model.isJITModalOpen && !UserDefaults.standard.bool(forKey: "LCKeepSelectedWhenQuit"){
                UserDefaults.standard.removeObject(forKey: "selected")
                UserDefaults.standard.removeObject(forKey: "selectedContainer")
            }
            
            if (UserDefaults.standard.object(forKey: "LCLastLanguages") != nil) {
                // recover livecontainer's own language
                UserDefaults.standard.set(UserDefaults.standard.object(forKey: "LCLastLanguages"), forKey: "AppleLanguages")
                UserDefaults.standard.removeObject(forKey: "LCLastLanguages")
            }
        }
        return true
    }
    
}
