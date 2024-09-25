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
    
    fileprivate func moveVvFileToPrivateStorageAndConnect(_ url: URL, _ pathString: String) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let stateKeeper: StateKeeper = appDelegate.stateKeeper

        if let docsPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first {
            let destPath = String(format: "%@/%@", docsPath, "console.vv")
            if Utils.moveUrlToDestinationIfPossible(url, destPath) {
                log_callback_str(message: "\(#function) Could not connectIfConsoleFileFound")
                if !stateKeeper.connectIfConsoleFileFound(destPath) {
                    log_callback_str(message: "\(#function) Could not connectIfConsoleFileFound")
                }
            } else {
                log_callback_str(message: "\(#function) Could not move console.vv trying to use it as is.")
                if !stateKeeper.connectIfConsoleFileFound(pathString) {
                    log_callback_str(message: "\(#function) Could not connectIfConsoleFileFound in place")
                }
            }
        }
    }
    
    func connectWithConsoleFile(url: URL, pathString: String) {
        if (url.startAccessingSecurityScopedResource()) {
            moveVvFileToPrivateStorageAndConnect(url, pathString)
            url.stopAccessingSecurityScopedResource()
        } else {
            log_callback_str(message: "\(#function) Could not startAccessingSecurityScopedResource, trying without")
            log_callback_str(message: "\(#function) aSPICE may need to be granted Full Disk Access in settings")
            moveVvFileToPrivateStorageAndConnect(url, pathString)
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents.
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            globalWindow = UIWindow(windowScene: windowScene)
            appDelegate.stateKeeper.recreateMainPage()
        }
        
        log_callback_str(message: "\(#function): \(connectionOptions.urlContexts)")
        if CommandLine.arguments.count > 1 {
            let firstArg: String = CommandLine.arguments[1]
            if firstArg.starts(with: "/") {
                log_callback_str(message: "\(#function): Found argument that may be a file \(firstArg)")
                self.connectWithConsoleFile(url: URL(string: String(format: "%@%@", "file://", firstArg))!, pathString: firstArg)
            }
        }
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
                self.connectWithConsoleFile(url: url, pathString: url.pathComponents.joined(separator: "/"))
            }
        }
    }
    
    func scene(_ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>) {
        log_callback_str(message: #function)
        handleUrlContexts(URLContexts)
    }
    
    fileprivate func createIfNeededAndConnect(
        _ selectedConnection: [String : String]?,
        _ connectionName: String?,
        _ host: String,
        _ port: String,
        _ requiresVpn: String,
        _ vpnUriScheme: String,
        _ externalId: String?
    ) {
        var connection: [String : String] = selectedConnection ?? [:]
        connection["connectionName"] = connectionName!
        connection["address"] = host
        connection["port"] = port
        connection["requiresVpn"] = requiresVpn
        connection["vpnUriScheme"] = vpnUriScheme
        connection["externalId"] = externalId
        globalStateKeeper?.selectSaveAndConnect(connection: connection)
    }
    
    fileprivate func extractFromParameters(_ params: [URLQueryItem], _ field: String) -> String? {
        return params.first(where: { $0.name == field })?.value
    }
    
    func handleUniversalUrl(urlContext: UIOpenURLContext) -> Bool {
        let sendingAppID = urlContext.options.sourceApplication
        let url = urlContext.url
        log_callback_str(message: "\(#function) source application = \(sendingAppID ?? "Unknown")")
        log_callback_str(message: "\(#function) url = \(url)")
        
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host,
              let numericPort = components.port,
              let params = components.queryItems else {
            log_callback_str(message: "\(#function) Invalid URL")
            return false
        }
        let port = "\(numericPort)"
        log_callback_str(message: "\(#function) host = \(host)")
        log_callback_str(message: "\(#function) port = \(port)")

        var connectionName = extractFromParameters(params, "ConnectionName")
        let requiresVpn = extractFromParameters(params, "RequiresVpn") == "1" ? "true" : "false"
        let vpnUriScheme = extractFromParameters(params, "VpnUriScheme") ?? "vpn"
        let externalId = extractFromParameters(params, "ExternalId")

        if connectionName == nil {
            log_callback_str(message: "\(#function) ConnectionName missing")
            return false
        } else if (externalId != nil) {
            log_callback_str(message: "\(#function) externalId = \(externalId!)")
            let selectedConnection = globalStateKeeper?.connections.findFirstByExternalIdAddressAndPort(
                externalId: externalId!,
                address: host,
                port: port
            )
            createIfNeededAndConnect(selectedConnection, connectionName, host, port, requiresVpn, vpnUriScheme, externalId)
            return true
        } else {
            connectionName = connectionName!.replacingOccurrences(of: "+", with: " ")
            log_callback_str(message: "\(#function) connectionName = \(connectionName!)")
            let selectedConnection = globalStateKeeper?.connections.findFirstByName(connectionName: connectionName!)
            createIfNeededAndConnect(selectedConnection, connectionName, host, port, requiresVpn, vpnUriScheme, externalId)
            return true
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
