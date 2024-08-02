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

var globalStateKeeper: StateKeeper?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var stateKeeper: StateKeeper = StateKeeper()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        StoreReviewHelper.incrementAppOpenedCount()
        globalStateKeeper = stateKeeper
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    override func buildMenu(with builder: UIMenuBuilder) {
        if builder.system == .main {
            builder.remove(menu: .edit)
            builder.remove(menu: .format)
            builder.remove(menu: .help)
            builder.remove(menu: .file)
            builder.remove(menu: .window)
            builder.remove(menu: .view)
            
            let showOnscreenKeysCommand = UICommand(title: "Show On-Screen Keys",
                      action: #selector(showOnScreenKeys),
                      discoverabilityTitle: "show on-screen keys")
            let disconnectCommand = UICommand(title: "Disconnect",
                      action: #selector(disconnect),
                      discoverabilityTitle: "disconnect")
            let quitCommand = UICommand(title: "Quit",
                      action: #selector(quit),
                      discoverabilityTitle: "quit")

            let actionsMenu = UIMenu(title: "Actions", image: nil, identifier: UIMenu.Identifier("actions"),
                                     children: [showOnscreenKeysCommand, disconnectCommand, quitCommand])
            builder.replace(menu: .application, with: actionsMenu)
        }
    }
    
    @objc func showOnScreenKeys() {
        globalStateKeeper?.showOnScreenButtonsIfDrawing()
    }
    
    @objc func disconnect() {
        globalStateKeeper?.scheduleDisconnectTimerFromButton()
    }

    @objc func quit() {
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
              exit(0)
             }
        }
    }
}

extension UIApplication {

    static var appVersion: String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    static var appId: String? {
        return Bundle.main.bundleIdentifier
    }
}
