//
//  MultitaskAppWindow.swift
//  LiveContainer
//
//  Created by s s on 2025/5/17.
//
import SwiftUI

struct MultitaskAppInfo {
    var ext: NSExtension
    var displayName: String
    var dataUUID: String
    var id: UUID
    
    func getWindowTitle() -> String {
        return "\(displayName) - \(ext.pid(forRequestIdentifier: id))"
    }
    
    func closeApp() {
        ext.setRequestInterruptionBlock { uuid in
            print("app closed!")
            MultitaskManager.unregisterMultitaskContainer(container: dataUUID)
        }
        ext._kill(SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            ext._kill(SIGKILL)
        }
        
    }
}

@available(iOS 16.1, *)
@objc class MultitaskWindowManager : NSObject {
    static var openWindow : OpenWindowAction? = nil
    static var appDict: [UUID:MultitaskAppInfo] = [:]
    
    @objc class func openAppWindow(id: UUID, ext:NSExtension, displayName: String, dataUUID: String) {
        DataManager.shared.model.enableMultipleWindow = true
        appDict[id] = MultitaskAppInfo(ext: ext, displayName: displayName, dataUUID: dataUUID, id: id)
        if let openWindow {
            openWindow(id: "appView", value: id)
        }
    }
    
}


@available(iOS 16.1, *)
struct GetOpenWindowActionView : View {
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        EmptyView()
    }
    
    init() {
        MultitaskWindowManager.openWindow = openWindow
    }
}

@available(iOS 16.1, *)
struct AppSceneViewSwiftUI : UIViewControllerRepresentable {
    
    @Binding var show : Bool
    var initSize: CGSize

    var ext: NSExtension
    var identifier: UUID
    var dataUUID: String
    
    class Coordinator: NSObject, AppSceneViewDelegate {
        let onExit : () -> Void
        init(onExit: @escaping () -> Void) {
            self.onExit = onExit
        }
        
        func appDidExit() {
            onExit()
        }
        
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator {
            show = false
        }
    }

    
    func makeUIViewController(context: Context) -> AppSceneViewController {
        return AppSceneViewController(with: ext, frame: CGRect(x: 0,y: 0,width: initSize.width,height: initSize.height), identifier: identifier, dataUUID: dataUUID, delegate: context.coordinator)
    }
    
    func updateUIViewController(_ vc: AppSceneViewController, context: Context) {

    }
}

@available(iOS 16.1, *)
struct MultitaskAppWindow : View {
    @State var id: UUID
    @State var show = true
    @State var appInfo : MultitaskAppInfo? = nil
    var appSceneView : AppSceneViewSwiftUI? = nil
    init(id: UUID) {
        self._id = State(initialValue: id)
        guard let appInfo = MultitaskWindowManager.appDict[id] else {
            return
        }
        self._appInfo = State(initialValue: appInfo)
        
    }

    var body: some View {
        if show, let appInfo {
            GeometryReader { geometry in
                AppSceneViewSwiftUI(show: $show, initSize:geometry.size, ext: appInfo.ext, identifier: appInfo.id, dataUUID: appInfo.dataUUID)
                    .background(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(.all, edges: .all)
            .navigationTitle(appInfo.getWindowTitle())
            .onDisappear(){
                appInfo.closeApp()
            }
            
        } else {
            Text("The app is terminated.")
        }
    }
}
