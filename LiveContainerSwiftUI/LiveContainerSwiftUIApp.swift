//
//  LiveContainerSwiftUIApp.swift
//  LiveContainer
//
//  Created by s s on 2025/5/16.
//
import SwiftUI




@main
struct LiveContainerSwiftUIApp : App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup(id: "Main") {
            LCTabView()
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
            if #available(iOS 16.1, *) {
                GetOpenWindowActionView()
                    .hidden()
            }
        }
        
        
        if UIApplication.shared.supportsMultipleScenes, #available(iOS 16.1, *) {
            WindowGroup(id: "appView", for: UUID.self) { $id in
                if let id {
                    MultitaskAppWindow(id: id)
                }
            }

        }
    }
    
}
