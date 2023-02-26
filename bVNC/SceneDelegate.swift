/**
 * Copyright (C) 2021- Morpheusly Inc. All rights reserved.
 *
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
 * USA.
 */

import UIKit
import SwiftUI

var globalWindow: UIWindow?

class MyUIHostingController<Content> : UIHostingController<Content> where Content : View {
    override var prefersStatusBarHidden: Bool {
        return true
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        log_callback_str(message: "Received a memory warning.")
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func connectWithConsoleFile(url: URL) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if (url.startAccessingSecurityScopedResource()) {
            if let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                let destPath = String(format: "%@/%@", docsPath, "console.vv")
                do {
                    try FileManager.default.copyItem(atPath: url.path, toPath: destPath)
                } catch (let error) {
                    log_callback_str(message: "Cannot copy item at \(url) to \(destPath): \(error)")
                }
                log_callback_str(message: "\(#function): \(destPath)")
                appDelegate.stateKeeper.connectWithConsoleFile(consoleFile: destPath)
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents.
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let contentView = ContentView(stateKeeper: appDelegate.stateKeeper,
                                      searchConnectionText: appDelegate.stateKeeper.connections.getSearchConnectionText(),
                                      filteredConnections: appDelegate.stateKeeper.connections.filteredConnections)
        
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            window = UIWindow(windowScene: windowScene)
            window!.rootViewController = MyUIHostingController(rootView: contentView)
            //window!.rootViewController?.modalPresentationCapturesStatusBarAppearance = true

            window!.makeKeyAndVisible()
            globalWindow = window
        }
        
        log_callback_str(message: "\(#function): \(connectionOptions.urlContexts)")
        guard (connectionOptions.urlContexts.first?.url) != nil else {
            return
        }
        handleUrlContexts(connectionOptions.urlContexts)
    }
    
    fileprivate func handleUrlContexts(_ URLContexts: Set<UIOpenURLContext>) {
        if let urlContext = URLContexts.first {
            log_callback_str(message: "\(#function): \(urlContext.url)")
            if (!self.handleUniversalUrl(urlContext: urlContext)) {
                let url = urlContext.url
                self.connectWithConsoleFile(url: url)
            }
        }
    }
    
    func scene(_ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>) {
        log_callback_str(message: #function)
        handleUrlContexts(URLContexts)
    }
    
    func handleUniversalUrl(urlContext: UIOpenURLContext) -> Bool {
        let sendingAppID = urlContext.options.sourceApplication
        let url = urlContext.url
        log_callback_str(message: "\(#function) source application = \(sendingAppID ?? "Unknown")")
        log_callback_str(message: "\(#function) url = \(url)")
        
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host,
              let port = components.port,
              let params = components.queryItems else {
            log_callback_str(message: "\(#function) Invalid URL")
            return false
        }

        if let connectionName = params.first(where: { $0.name == "ConnectionName" })?.value {
            log_callback_str(message: "\(#function) host = \(host)")
            log_callback_str(message: "\(#function) port = \(port)")
            let connectionName = connectionName.replacingOccurrences(of: "+", with: " ")
            log_callback_str(message: "\(#function) connectionName = \(connectionName)")
            let selectedConnection = globalStateKeeper?.connections.findFirstByName(connectionName: connectionName)
            if (selectedConnection != nil) {
                globalStateKeeper?.connections.selectedConnection = selectedConnection!
                globalStateKeeper?.connect(connection: selectedConnection!)
            } else {
                let selectedConnection: [String : String] = [
                    "connectionName": connectionName,
                    "address": host,
                    "port": "\(port)",
                ]
                globalStateKeeper?.connections.selectedConnection = selectedConnection
                globalStateKeeper?.addOrEditConnection()
            }
            return true
        } else {
            log_callback_str(message: "\(#function) ConnectionName missing")
            return false
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        log_callback_str(message: "\(#function) called.")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        log_callback_str(message: "\(#function) called.")
        globalStateKeeper?.reconnectIfDisconnectedDueToBackgrounding()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        log_callback_str(message: "\(#function) called.")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        log_callback_str(message: "\(#function) called.")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        log_callback_str(message: "\(#function) called.")
        globalStateKeeper?.disconnectDueToBackgrounding()
    }
    
    func windowScene(_ windowScene: UIWindowScene,
                    didUpdate previousCoordinateSpace: UICoordinateSpace,
         interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
                              traitCollection previousTraitCollection: UITraitCollection) {
        log_callback_str(message: "\(#function) called.")
        globalStateKeeper?.resizeWindow()
    }
    
    @objc func clipboardChanged(_ notification: Notification) {
        log_callback_str(message: "\(#function) Detected change in clipboard: \(UIPasteboard.general.string)")
    }
}
