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

import Foundation
import Combine
import SwiftUI
import GameController

class StateKeeper: NSObject, ObservableObject, KeyboardObserving, NSCoding {
    static let bH = CGFloat(30.0)
    static let bW = CGFloat(40.0)
    static let tbW = CGFloat(30.0)
    static let bSp = CGFloat(5.0)
    static let tbSp = CGFloat(3.0)
    static let z = CGFloat(0.0)
    static let bBg = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
    let lightbBG = UIColor.lightGray
    let darkbBG = bBg

    let objectWillChange = PassthroughSubject<StateKeeper, Never>()
    
    // Enabled applications for HELP resources
    let helpDialogAppIds = ["com.iiordanov.sCloudRDP", "com.iiordanov.freesCloudRDP", "com.iiordanov.aRDP",
                            "com.iiordanov.freeaRDP", "com.iiordanov.aSPICE", "com.iiordanov.freeaSPICE"]
    // Enabled application for SSH tunneling
    let sshAppIds = ["com.iiordanov.sCloudRDP", "com.iiordanov.freesCloudRDP", "com.iiordanov.aRDP",
                     "com.iiordanov.freeaRDP", "com.iiordanov.freeaSPICE", "com.iiordanov.aSPICE"]
    
    var connections: FilterableConnections = FilterableConnections(stateKeeper: nil)
    var settings = UserDefaults.standard
    var title: String?
    var localizedTitle: LocalizedStringKey?
    var message: String = ""
    var localizedMessages: [ LocalizedStringKey ] = []
    var yesNoDialogLock: NSLock = NSLock()
    var yesNoDialogResponse: Int32 = 0
    var imageView: TouchEnabledUIImageView?
    var captureImageView: UIImageView?
    var remoteSession: RemoteSession?
    var modifierButtons: [String: UIControl]
    var keyboardButtons: [String: UIControl]
    var topButtons: [String: UIControl]
    var interfaceButtons: [String: UIControl]
    var keyboardHeight: CGFloat = 0.0
    var clientLog: [String] = []
    var sshForwardingLock: NSLock = NSLock()
    var sshForwardingStatus: Bool = false
    var sshTunnelingStarted: Bool = false
    var globalWriteTlsLock: NSLock = NSLock()
    var frames = 0
    var superUpKeyTimer: Timer = Timer()
    var orientationTimer: Timer = Timer()
    var fullScreenUpdateTimer: Timer = Timer()
    var partialScreenUpdateTimer: Timer = Timer()
    var recurringPartialScreenUpdateTimer: Timer = Timer()
    var disconnectTimer: Timer = Timer()
    var minScale: CGFloat = 0
    var macOs: Bool = false
    var iPadOnMacOs: Bool = false
    var iPhoneOrPad = false

    var topSpacing: CGFloat = bH
    var topButtonSpacing: CGFloat = 0.0
    var leftSpacing: CGFloat = 0.0
    
    var orientation: Int = -1 /* -1 == Uninitialized, 0 == Portrait, 1 == Landscape */
    
    var disconnectedDueToBackgrounding: Bool = false
    var connectedWithConsoleFileOrUri: Bool = false
    var currInst: Int = -1
    
    var cl: [UnsafeMutableRawPointer?]
    var maxClCapacity = 1000
    
    var receivedUpdate: Bool = false
    var isDrawing: Bool = false
    var isKeptFresh: Bool = false
    
    var currentTransition: String = ""
    var logLock: NSLock = NSLock()

    var allowZooming = true
    var allowPanning = true
    
    var originalImageRect: CGRect = CGRect()
    
    var modifiers = [
        XK_Control_L: false,
        XK_Control_R: false,
        XK_Alt_L: false,
        XK_Alt_R: false,
        XK_Shift_L: false,
        XK_Shift_R: false,
        XK_Super_L: false,
        XK_Super_R: false,
    ]
    
    let bundleID = Bundle.main.bundleIdentifier
    
    // Dictionaries desctibing onscreen ToggleButton type buttons
    let topButtonData: [ String: [ String: Any ] ] = [
        "f1Button": [ "title": "F1", "lx": 1*tbW+1*tbSp, "ly": z, "send": XK_F1, "tgl": false, "top": true, "right": false ],
        "f2Button": [ "title": "F2", "lx": 2*tbW+2*tbSp, "ly": z, "send": XK_F2, "tgl": false, "top": true, "right": false ],
        "f3Button": [ "title": "F3", "lx": 3*tbW+3*tbSp, "ly": z, "send": XK_F3, "tgl": false, "top": true, "right": false ],
        "f4Button": [ "title": "F4", "lx": 4*tbW+4*tbSp, "ly": z, "send": XK_F4, "tgl": false, "top": true, "right": false ],
        "f5Button": [ "title": "F5", "lx": 5*tbW+5*tbSp, "ly": z, "send": XK_F5, "tgl": false, "top": true, "right": false ],
        "f6Button": [ "title": "F6", "lx": 6*tbW+6*tbSp, "ly": z, "send": XK_F6, "tgl": false, "top": true, "right": false ],
        "f7Button": [ "title": "F7", "lx": 7*tbW+7*tbSp, "ly": z, "send": XK_F7, "tgl": false, "top": true, "right": false ],
        "f8Button": [ "title": "F8", "lx": 8*tbW+8*tbSp, "ly": z, "send": XK_F8, "tgl": false, "top": true, "right": false ],
        "f9Button": [ "title": "F9", "lx": 9*tbW+9*tbSp, "ly": z, "send": XK_F9, "tgl": false, "top": true, "right": false ],
        "f10Button": [ "title": "F10", "lx": 10*tbW+10*tbSp, "ly": z, "send": XK_F10, "tgl": false, "top": true, "right": false ],
        "f11Button": [ "title": "F11", "lx": 11*tbW+11*tbSp, "ly": z, "send": XK_F11, "tgl": false, "top": true, "right": false ],
        "f12Button": [ "title": "F12", "lx": 12*tbW+12*tbSp, "ly": z, "send": XK_F12, "tgl": false, "top": true, "right": false ],
        "pageUp": [ "title": "⇞", "lx": 13*tbW+13*tbSp, "ly": z, "send": XK_Page_Up, "tgl": false, "top": true, "right": false ],
        "pageDown": [ "title": "⇟", "lx": 14*tbW+14*tbSp, "ly": z, "send": XK_Page_Down, "tgl": false, "top": true, "right": false ],
        "home": [ "title": "⇤", "lx": 15*tbW+15*tbSp, "ly": z, "send": XK_Home, "tgl": false, "top": true, "right": false ],
        "end": [ "title": "⇥", "lx": 16*tbW+16*tbSp, "ly": z, "send": XK_End, "tgl": false, "top": true, "right": false ],
        "del": [ "title": "Del", "lx": 17*tbW+17*tbSp, "ly": z, "send": XK_Delete, "tgl": false, "top": true, "right": false ],
    ]

    let modifierButtonData: [ String: [ String: Any ] ] = [
        "ctrlButton": [ "title": "⌃", "lx": 0*bW+0*bSp, "ly": 1*bH, "send": XK_Control_L, "tgl": true, "top": false, "right": false ],
        "superButton": [ "title": "❖", "lx": 1*bW+1*bSp, "ly": 1*bH, "send": XK_Super_L, "tgl": true, "top": false, "right": false ],
        "altButton": [ "title": "⎇", "lx": 2*bW+2*bSp, "ly": 1*bH, "send": XK_Alt_L, "tgl": true, "top": false, "right": false ],
        "shiftButton": [ "title": "⇧", "lx": 2*bW+2*bSp, "ly": 2*bH+1*bSp, "send": XK_Shift_L, "tgl": true, "top": false, "right": false ],
    ]
    
    let keyboardButtonData: [ String: [ String: Any ] ] = [
        "escButton": [ "title": "⎋", "lx": 0*bW+0*bSp, "ly": 2*bH+1*bSp, "send": XK_Escape, "tgl": false, "top": false, "right": false ],
        "tabButton": [ "title": "↹", "lx": 1*bW+1*bSp, "ly": 2*bH+1*bSp, "send": XK_Tab, "tgl": false, "top": false, "right": false ],
        "leftButton": [ "title": "←", "lx": 4*bW+3*bSp, "ly": 1*bH, "send": XK_Left, "tgl": false, "top": false, "right": true ],
        "downButton": [ "title": "↓", "lx": 3*bW+2*bSp, "ly": 1*bH, "send": XK_Down, "tgl": false, "top": false, "right": true ],
        "rightButton": [ "title": "→", "lx": 2*bW+1*bSp, "ly": 1*bH, "send": XK_Right, "tgl": false, "top": false, "right": true ],
        "upButton": [ "title": "↑", "lx": 3*bW+2*bSp, "ly": 2*bH+1*bSp, "send": XK_Up, "tgl": false, "top": false, "right": true ],
    ]

    var interfaceButtonData: [ String: [ String: Any ] ] = [
        "disconnectButton": [ "title": "", "lx": 1*bW+0*bSp, "ly": 2*bH+1*bSp, "send": Int32(-1), "tgl": false, "top": false, "right": true, "image": "clear.fill"],
        "keyboardButton": [ "title": "", "lx": 1*bW+0*bSp, "ly": 1*bH+0*bSp, "send": Int32(-1), "tgl": false, "top": false, "right": true, "image": "keyboard"]
    ]
    
    var keyboardLayouts: [String] = []
    var mainPage: MainPage?
    var physicalKeyboardHandler: PhysicalKeyboardHandler?
    var clipboardMonitor: ClipboardMonitor?
    var requestingCredentials: Bool = false
    var requestingSshCredentials: Bool = false

    var onScreenKeysHidden: Bool = true
    var fbW: CGFloat = 0.0
    var fbH: CGFloat = 0.0

    @objc func reDraw() {
        self.remoteSession?.reDraw()
    }
    
    func rescheduleSuperKeyUpTimer() {
        self.superUpKeyTimer.invalidate()
        self.superUpKeyTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(sendSuperKeyUp), userInfo: nil, repeats: false)
    }
    
    @objc func sendSuperKeyUp() {
        guard self.getCurrentInstance() != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        
        self.remoteSession?.sendUniDirectionalSpecialKeyByXKeySym(key: XK_Super_L, down: false)
        self.modifiers[XK_Super_L] = false
        self.rescheduleScreenUpdateRequest(timeInterval: 0.2, fullScreenUpdate: false, recurring: false)
    }
    
    @objc func requestFullScreenUpdate(sender: Timer) {
        if self.isDrawing && (sender.userInfo as! Int) == self.currInst {
            //print("Firing off a whole screen update request.")
            self.remoteSession?.sendScreenUpdateRequest(incrementalUpdate: false)
        }
    }

    @objc func requestPartialScreenUpdate(sender: Timer) {
        if self.isDrawing && (sender.userInfo as! Int) == self.currInst {
            //print("Firing off a partial screen update request.")
            self.remoteSession?.sendScreenUpdateRequest(incrementalUpdate: true)
        }
    }

    @objc func requestRecurringPartialScreenUpdate(sender: Timer) {
        if self.isDrawing && (sender.userInfo as! Int) == self.currInst {
            //print("Firing off a recurring partial screen update request.")
            self.remoteSession?.sendScreenUpdateRequest(incrementalUpdate: true)
            UserInterface {
                self.rescheduleScreenUpdateRequest(timeInterval: 20, fullScreenUpdate: false, recurring: true)
            }
        }
    }
    
    func rescheduleScreenUpdateRequest(timeInterval: TimeInterval, fullScreenUpdate: Bool, recurring: Bool) {
        UserInterface {
            if (self.isDrawing) {
                if (fullScreenUpdate) {
                    self.fullScreenUpdateTimer.invalidate()
                    //print("Scheduling full screen update")
                    self.fullScreenUpdateTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(self.requestFullScreenUpdate(sender:)), userInfo: self.currInst, repeats: false)
                } else if !recurring {
                    self.partialScreenUpdateTimer.invalidate()
                    //print("Scheduling non-recurring partial screen update")
                    self.partialScreenUpdateTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(self.requestPartialScreenUpdate), userInfo: self.currInst, repeats: false)
                } else {
                    self.recurringPartialScreenUpdateTimer.invalidate()
                    //print("Scheduling recurring partial screen update")
                    self.recurringPartialScreenUpdateTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(self.requestRecurringPartialScreenUpdate), userInfo: self.currInst, repeats: false)
                }
            }
        }
    }
    
    func isiPhoneOrPad() -> Bool {
        return self.iPhoneOrPad
    }
    
    func isOnMacOs() -> Bool {
        return self.macOs 
    }
    
    func isiPadOnMacOs() -> Bool {
        return self.iPadOnMacOs
    }
    
    func isOnMacOsOriPadOnMacOs() -> Bool {
        return isOnMacOs() || isiPadOnMacOs()
    }
    
    override init() {
        #if targetEnvironment(macCatalyst)
            self.macOs = true
        #endif
        if #available(iOS 14.0, *) {
            if ProcessInfo.processInfo.isiOSAppOnMac {
                self.iPadOnMacOs = true
            }
        }
        self.iPhoneOrPad = !macOs && !iPadOnMacOs
        
        // Load settings for current connection
        interfaceButtons = [:]
        keyboardButtons = [:]
        modifierButtons = [:]
        topButtons = [:]
        cl = Array<UnsafeMutableRawPointer?>(
            repeating: UnsafeMutableRawPointer.allocate(byteCount: 0, alignment: MemoryLayout<UInt8>.alignment),
            count: maxClCapacity)

        super.init()
        connections = FilterableConnections(stateKeeper: self)
        physicalKeyboardHandler = PhysicalKeyboardHandler(stateKeeper: self)
        if Utils.isSpice() || Utils.isRdp() {
            self.keyboardLayouts = Utils.getResourcePathContents(path:
                                        Constants.LAYOUT_PATH)
        }
        self.clipboardMonitor = ClipboardMonitor(stateKeeper: self, repeated: self.isOnMacOs())
        self.onScreenKeysHidden = true
    }
    
    func connectIfConfigFileFound(_ destPath: String) -> Bool {
        let fileContents = Utils.getFileContents(path: destPath)
        var result = false
        if Utils.isSpice() && fileContents.starts(with: "[virt-viewer]") {
            log_callback_str(message: "\(#function): File at \(destPath) starts with [virt-viewer], connecting.")
            self.connectWithConsoleFile(consoleFile: destPath)
            result = true
        } else if Utils.isRdp() {
            log_callback_str(message: "\(#function): File at \(destPath) must be an RDP file, connecting.")
            self.connectWithConsoleFile(consoleFile: destPath)
            result = true
        } else {
            log_callback_str(message: "\(#function): File at \(destPath) not supported, ignoring.")
        }
        return result
    }
    
    func connectWithConsoleFile (consoleFile: String) {
        if Utils.isRdp() && self.remoteSession?.connected ?? false {
            log_callback_str(message: "\(#function): Connecting via RDP console file while connected is currently not supported")
            return
        }

        self.connectedWithConsoleFileOrUri = true
        var connection: [String: String] = self.connections.defaultSettings
        connection["consoleFile"] = consoleFile
        connection["id"] = ""
        self.connections.selectedConnection = connection
        self.connect(connection: connection)
    }

    convenience required init?(coder: NSCoder) {
        self.init()
    }

    func encode(with coder: NSCoder) {
    }
    
    var currentPage: String = "connectionsList" {
        didSet {
            self.objectWillChange.send(self)
        }
    }

    func selectAndConnect(connection: [String: String]) {
        log_callback_str(message: #function)
        self.connections.select(connection: connection)
        self.connect(connection: connection)
    }
    
    /**
     Used to connect with an index from the list of saved connections
     */
    func connectSaved(connection: [String: String]) {
        log_callback_str(message: #function)
        self.connectedWithConsoleFileOrUri = false
        self.selectAndConnect(connection: connection)
    }
    
    
    func selectSaveAndConnect(connection: [String: String]) {
        log_callback_str(message: #function)
        // Try to select the connection in order to not create duplicates
        self.connections.select(connection: connection)
        self.connections.overwriteOneConnectionAndNavigate(connection: connection)
        self.selectAndConnect(connection: connection)
    }
    
    fileprivate func constructRemoteSession(_ customResolution: Bool, _ customWidth: Int, _ customHeight: Int) -> RemoteSession {
        return RdpSession(instance: currInst, stateKeeper: self, customResolution: customResolution, customWidth: customWidth, customHeight: customHeight)
    }
    
    /**
     Used to connect with an individual connection, potentially specially crafted from a console file or URI
     */
    func connect(connection: [String: String]) {
        log_callback_str(message: #function)
        self.showConnectionInProgress()
        self.requestingCredentials = false
        self.requestingSshCredentials = false
        self.clipboardMonitor?.startMonitoring()
        self.receivedUpdate = false
        log_callback_str(message: "Connecting and navigating to the connection screen")
        self.yesNoDialogResponse = 0
        self.isKeptFresh = false
        self.clientLog = []
        self.clientLog.append("\n\n")
        self.registerForNotifications()
        self.allowZooming = connections.selectedConnectionAllowsZoomingOrPanning(setting: "allowZooming")
        self.allowPanning = connections.selectedConnectionAllowsZoomingOrPanning(setting: "allowPanning")
        globalWindow!.makeKeyAndVisible()
        self.currInst = (currInst + 1) % maxClCapacity
        self.isDrawing = true
        self.toggleModifiersIfDown()
        let customResolution = Bool(connection["customResolution"] ?? "false")!
        let customWidth = Utils.getResolutionWidth(connection["customWidth"])
        let customHeight = Utils.getResolutionHeight(connection["customHeight"])
        self.remoteSession = constructRemoteSession(customResolution, customWidth, customHeight)
        self.remoteSession!.connect(currentConnection: connection)
        createAndRepositionButtons()
    }
    
    func showConnectedSession() {
        UserInterface {
            self.currentPage = "connectedSession"
        }
    }
    
    func isAtConnectionsListPage() -> Bool {
        return self.currentPage == "connectionsList"
    }
    
    func isAtDisconnectionInProgressPage() -> Bool {
        return self.currentPage == "disconnectionInProgress"
    }

    fileprivate func setCaptureViewAndNullifyImageView() {
        self.captureImageView = imageView
        self.imageView = nil
    }
    
    func showConnectionInProgress() {
        setCaptureViewAndNullifyImageView()
        UserInterface {
            self.currentPage = "connectionInProgress"
        }
    }
    
    func reconnectIfDisconnectedDueToBackgrounding() {
        if disconnectedDueToBackgrounding && !self.connectedWithConsoleFileOrUri {
            log_callback_str(message: "Reconnecting after previous disconnect due to backgrounding")
            disconnectedDueToBackgrounding = false
            connectSaved(connection: self.connections.selectedConnection)
        }
    }
    
    func disconnectDueToBackgrounding() {
        if self.isDrawing && !self.connectedWithConsoleFileOrUri {
            log_callback_str(message: "Disconnecting due to backgrounding")
            disconnectedDueToBackgrounding = true
            let wasDrawing = self.isDrawing
            self.imageView?.disableTouch()
            self.isDrawing = false
            scheduleDisconnectTimer(interval: 0, wasDrawing: wasDrawing)
        }
    }

    @objc func lazyDisconnect() {
        log_callback_str(message: "Lazy disconnecting")
        self.clipboardMonitor?.stopMonitoring()
        self.imageView?.disableTouch()
        self.isDrawing = false
        self.deregisterFromNotifications()
        self.orientationTimer.invalidate()
        self.fullScreenUpdateTimer.invalidate()
        self.partialScreenUpdateTimer.invalidate()
        self.recurringPartialScreenUpdateTimer.invalidate()
    }

    @objc func disconnect(sender: Timer) {
        log_callback_str(message: "\(#function) called")
        let wasDrawing = (sender.userInfo as! Bool)
        self.disconnect(wasDrawing: wasDrawing)
    }

    func disconnect(wasDrawing: Bool) {
        log_callback_str(message: "\(#function) called")
        self.currInst = (currInst + 1) % maxClCapacity
        
        if !self.disconnectedDueToBackgrounding && self.receivedUpdate {
            _ = self.connections.saveImage(image: self.captureScreen(imageView: self.captureImageView))
        }
        UserInterface {
            self.toggleModifiersIfDown()
        }
        log_callback_str(message: "wasDrawing(): \(wasDrawing)")
        self.remoteSession?.disconnect()
        if (wasDrawing) {
            UserInterface {
                self.removeAllButtons()
                self.hideKeyboard()
                self.imageView?.disableTouch()
                self.imageView?.removeFromSuperview()
            }
        } else {
            log_callback_str(message: "\(#function) called but wasDrawing was already false")
        }
        if isAtDisconnectionInProgressPage() {
            showConnections()
        }
        StoreReviewHelper.checkAndAskForReview()
    }

    func disconnectFromCancelButton() {
        self.lazyDisconnect()
        self.disconnect(wasDrawing: false)
        self.showDisconnectionPage()
    }
    
    @objc func scheduleDisconnectTimerFromButton() {
        self.showDisconnectionPage()
        self.scheduleDisconnectTimer(interval: 1, wasDrawing: self.isDrawing)
    }

    @objc func scheduleDisconnectTimer(interval: Double = 1, wasDrawing: Bool) {
        UserInterface {
            log_callback_str(message: "Scheduling disconnect")
            self.lazyDisconnect()
            self.disconnectTimer.invalidate()
            self.disconnectTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(self.disconnect(sender:)), userInfo: wasDrawing, repeats: false)
        }
    }

    func hideKeyboard() {
        _ = (self.interfaceButtons["keyboardButton"] as? CustomTextInput)?.hideKeyboard()
    }
    
    func addNewConnection(connectionName: String) {
        log_callback_str(message: "Adding new connection and navigating to connection setup screen")
        self.connections.addNewConnection(connectionName: connectionName)
        UserInterface {
            self.currentPage = "addOrEditConnection"
        }
    }
    
    func editConnection(connection: Dictionary<String, String>) {
        log_callback_str(message: "Editing connection and navigating to setup screen")
        self.connections.edit(connection: connection)
        UserInterface {
            self.currentPage = "addOrEditConnection"
        }
    }
    
    func requestCredentialsForConnection() {
        log_callback_str(message: "Navigating to request credentials screen")
        UserInterface {
            self.isDrawing = false
            self.currentPage = "addOrEditConnection"
        }
    }
    
    func editDefaultSetting() {
        log_callback_str(message: "Editing default settings and navigating to setup screen")
        self.connections.editDefaultSettings()
        UserInterface {
            self.currentPage = "addOrEditConnection"
        }
    }
    
    func showHelp(messages: [ LocalizedStringKey ]) {
        log_callback_str(message: "Showing help screen")
        self.localizedMessages = messages
        UserInterface {
            self.currentPage = "helpDialog"
        }
    }
    
    func dismissHelp() {
        log_callback_str(message: "Dismissing help screen")
        if (self.connections.editedConnection.isEmpty) {
            self.showConnections()
        }
        else {
            self.addOrEditConnection()
        }
    }
    
    func addOrEditConnection() {
        log_callback_str(message: "Going to connection settings screen")
        UserInterface {
            self.currentPage = "addOrEditConnection"
        }
    }

    func setFieldOfCurrentConnection(field: String, value: String) {
        log_callback_str(message: "Setting field \(field) of current connection to value \(value)")
        connections.selectedConnection[field] = value
        connections.saveSelectedConnection()
    }
    
    func saveSettings() {
        log_callback_str(message: "Saving settings")
        connections.saveConnections()
    }
    
    @objc func showConnectionsSelector(sender: Timer) {
        self.showConnections()
    }
    
    func recreateMainPage() {
        self.mainPage = MainPage(stateKeeper: self,
                                      searchConnectionText: self.connections.getSearchConnectionText(),
                                      filteredConnections: self.connections.filteredConnections)
        globalWindow?.rootViewController = MyUIHostingController(rootView: self.mainPage)
        globalWindow?.makeKeyAndVisible()
    }
    
    func showDisconnectionPage() {
        setCaptureViewAndNullifyImageView()
        UserInterface {
            self.localizedTitle = ""
            self.message = ""
            self.currentPage = "disconnectionInProgress"
            self.recreateMainPage()
        }
    }
    
    func showConnections() {
        setCaptureViewAndNullifyImageView()
        UserInterface {
            self.connections.loadConnections()
            self.currentPage = "connectionsList"
            self.recreateMainPage()
        }
    }
    
    func showError(title: LocalizedStringKey, errorPage: String) {
        self.localizedTitle = title
        UserInterface {
            self.currentPage = errorPage
        }
    }

    func showLog(title: LocalizedStringKey, text: String) {
        self.localizedTitle = title
        self.message = text
        UserInterface {
            self.currentPage = "dismissableMessage"
        }
    }
    
    func sendCtrlAltDelIfDrawing() {
        if isDrawing {
            self.remoteSession?.sendUniDirectionalSpecialKeyByXKeySym(key: XK_Control_L, down: true)
            self.remoteSession?.sendUniDirectionalSpecialKeyByXKeySym(key: XK_Alt_L, down: true)
            self.remoteSession?.sendUniDirectionalSpecialKeyByXKeySym(key: XK_Delete, down: true)
            self.remoteSession?.sendUniDirectionalSpecialKeyByXKeySym(key: XK_Delete, down: false)
            self.remoteSession?.sendUniDirectionalSpecialKeyByXKeySym(key: XK_Alt_L, down: false)
            self.remoteSession?.sendUniDirectionalSpecialKeyByXKeySym(key: XK_Control_L, down: false)
        }
    }
    
    func toggleOnScreenButtonsIfDrawing() {
        self.onScreenKeysHidden = !self.onScreenKeysHidden
        self.setVisibilityOfOnScreenButtonsIfDrawing(hidden: self.onScreenKeysHidden)
    }

    func setVisibilityOfOnScreenButtonsIfDrawing(hidden: Bool) {
        if isDrawing {
            log_callback_str(message: "setVisibilityOfOnScreenButtonsIfDrawing hidden: \(hidden)")
            self.addButtons(buttons: self.interfaceButtons)
            self.addButtons(buttons: self.keyboardButtons)
            self.addButtons(buttons: self.modifierButtons)
            self.addButtons(buttons: self.topButtons)
            if !self.isOnMacOs() && !self.isiPhoneOrPad() {
                self.setButtonsVisibility(buttons: self.interfaceButtons, isHidden: hidden)
            }
            self.setButtonsVisibility(buttons: self.keyboardButtons, isHidden: hidden)
            self.setButtonsVisibility(buttons: self.modifierButtons, isHidden: hidden)
            self.setButtonsVisibility(buttons: self.topButtons, isHidden: hidden)
        }
    }
    
    func keyboardWillShow(withSize keyboardSize: CGSize) {
        log_callback_str(message: "Keyboard will be shown, height: \(self.keyboardHeight)")
        if !self.allowPanning {
            self.saveImageRect()
        }
        self.keyboardHeight = keyboardSize.height
        if isDrawing {
            setVisibilityOfOnScreenButtonsIfDrawing(hidden: false)
            self.createAndRepositionButtons()
        }
    }
    
    func keyboardWillHide() {
        log_callback_str(message: "Keyboard will be hidden, height: \(self.keyboardHeight)")
        if !self.allowPanning && self.originalImageRect != CGRect() {
            self.setImageRect(newRect: self.originalImageRect)
        }
        
        self.keyboardHeight = 0
        if isDrawing {
            self.createAndRepositionButtons()
            if self.isiPhoneOrPad() {
                self.setButtonsVisibility(buttons: keyboardButtons, isHidden: true)
                self.setButtonsVisibility(buttons: modifierButtons, isHidden: true)
                self.setButtonsVisibility(buttons: topButtons, isHidden: true)
            }
        }
    }
    
    func setButtonsVisibility(buttons: [String: UIControl], isHidden: Bool) {
        buttons.forEach() { button in
            button.value.isHidden = isHidden
        }
    }
    
    func registerForNotifications() {
        addKeyboardObservers(to: .default)
        NotificationCenter.default.addObserver(self, selector: #selector(self.orientationChanged),
            name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    func deregisterFromNotifications(){
        //removeKeyboardObservers(from: .default)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func orientationChanged(_ notification: NSNotification) {
        rescheduleOrientationTimer()
    }
    
    func rescheduleOrientationTimer() {
        self.remoteSession?.reDrawTimer.invalidate()
        if (self.isDrawing) {
            self.orientationTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(correctTopSpacingForOrientation), userInfo: nil, repeats: false)
        }
    }
    
    /**
     *
     * @return The smallest scale supported by the implementation; the scale at which
     * the bitmap would be smaller than the screen
     */
    func getMinimumScale() -> CGFloat {
        let windowWidth: CGFloat = globalWindow!.bounds.maxX
        let windowHeight: CGFloat = globalWindow!.bounds.maxY
        let width: CGFloat = fbW <= 0 ? windowWidth : fbW
        let height: CGFloat = fbH <= 0 ? windowHeight : fbH
        return min(windowWidth / width, windowHeight / height)
    }
    
    @objc func correctTopSpacingForOrientation() {
        minScale = getMinimumScale()

        let windowX = globalWindow?.frame.maxX ?? 0
        let windowY = globalWindow?.frame.maxY ?? 0
        //print ("windowX: \(windowX), windowY: \(windowY)")
        var newOrientation = 0
        if (windowX > windowY) {
            newOrientation = 1
        }
        
        if newOrientation == 0 {
            //log_callback_str(message: "New orientation is portrait")
            leftSpacing = 0
            topSpacing = max(StateKeeper.bH, (globalWindow!.bounds.maxY - self.fbH*minScale)/4)
            topButtonSpacing = 0
        } else if newOrientation == 1 {
            //log_callback_str(message: "New orientation is landscape")
            leftSpacing = (globalWindow!.bounds.maxX - self.fbW*minScale)/2
            topSpacing = min(StateKeeper.bH, (globalWindow!.bounds.maxY - self.fbH*minScale)/2)
            topButtonSpacing = 0
        }
        
        if (newOrientation != orientation) {
            orientation = newOrientation
            setImageRect(newRect: CGRect(x: leftSpacing, y: topSpacing, width: self.fbW*minScale, height: self.fbH*minScale))
            createAndRepositionButtons()
        } else {
            //log_callback_str(message: "Actual orientation appears not to have changed, not disturbing the displayed image or buttons.")
        }
    }
    
    func saveImageRect() {
        self.originalImageRect = imageView?.frame ?? CGRect()
    }
    
    func localizedString(
        for key: String, tableName: String = "OverrideLocalizable",
        bundle: Bundle = .main, comment: String = ""
    ) -> String {
        let defaultValue = NSLocalizedString(key, comment: comment)
        return NSLocalizedString(
            key, tableName: tableName, bundle: bundle,
            value: defaultValue, comment: comment
        )
    }
    
    func setImageRect(newRect: CGRect) {
        imageView?.frame = newRect
        log_callback_str(message: "Set image rect to: \(newRect)")
    }
    
    fileprivate func initializeKeyboardButtonIfNotInitialized() {
        guard let b: CustomTextInput = self.physicalKeyboardHandler?.textInput else {
            return
        }
        let keyboardButton = self.interfaceButtons["keyboardButton"]
        if (keyboardButton == nil) {
            log_callback_str(message: "\(#function) Initializing keyboard button")
            b.addTarget(b, action: #selector(b.toggleFirstResponder), for: .touchDown)
            if let imageName = interfaceButtonData["keyboardButton"]!["image"] {
                if let image = UIImage(systemName: imageName as! String) {
                    b.setImage(image, for: .normal)
                    b.tintColor = .white
                    b.backgroundColor = (UITraitCollection.current.userInterfaceStyle == .light ? lightbBG : darkbBG)
                }
            }
            self.interfaceButtons["keyboardButton"] = b
        } else {
            log_callback_str(message: "\(#function) Keyboard button already initialized")
        }
    }
    
    fileprivate func setUpFirstResponderDepedingOnOS() {
        UserInterface {
            if self.isOnMacOs() {
                log_callback_str(message: "\(#function) Running on MacOS, keyboardButton resigning first responder")
                self.interfaceButtons["keyboardButton"]?.resignFirstResponder()
            } else {
                log_callback_str(message: "\(#function) Running on iOS or Designed for iPad on MacOS, keyboardButton becoming first responder")
                self.interfaceButtons["keyboardButton"]?.becomeFirstResponder()
            }
        }
    }
    
    fileprivate func showOrHideKeyboardButtonDueToExternalKeyboard() {
        var externalKeyboardPresent = self.isOnMacOs()
        if #available(iOS 14.0, *) {
            log_callback_str(message: "\(#function) Checking GCKeyboard.coalesced: \(String(describing: GCKeyboard.coalesced))")
            externalKeyboardPresent = GCKeyboard.coalesced != nil
        }
        if externalKeyboardPresent {
            setUpFirstResponderDepedingOnOS()
            log_callback_str(message: "\(#function) Hiding keyboard button because external keyboard was found")
            self.interfaceButtons["keyboardButton"]?.isHidden = true
            self.setVisibilityOfOnScreenButtonsIfDrawing(hidden: self.onScreenKeysHidden)
        } else {
            log_callback_str(message: "\(#function) Showing keyboard button because external keyboard was not found")
            self.interfaceButtons["keyboardButton"]?.isHidden = false
        }
    }
    
    fileprivate func initAndShowOrHideKeyboardButtonDueToExternalKeyboard() {
        log_callback_str(message: "\(#function) Creating keyboard button")
        initializeKeyboardButtonIfNotInitialized()
        showOrHideKeyboardButtonDueToExternalKeyboard()
    }
    
    func overrideInterfaceButtonDataForMacOs() {
        if self.macOs {
            self.interfaceButtonData["keyboardButton"]?["lx"] = CGFloat(0.001)
            self.interfaceButtonData["keyboardButton"]?["ly"] = CGFloat(0.001)
        }
    }
    
    func overrideButtonVisibilityForMacOs() {
        if self.isiPadOnMacOs() {
            self.interfaceButtons["disconnectButton"]?.isHidden = true
            self.interfaceButtons["keyboardButton"]?.isHidden = true
        } else if self.isOnMacOs() {
            self.interfaceButtons["disconnectButton"]?.isHidden = true
            self.interfaceButtons["keyboardButton"]?.isHidden = false
        }
    }
    
    func createAndRepositionButtons() {
        log_callback_str(message: "Ensuring buttons are initialized, and positioning them where they should be")
        overrideInterfaceButtonDataForMacOs()
        initAndShowOrHideKeyboardButtonDueToExternalKeyboard()
        interfaceButtons = createButtonsFromData(populateDict: interfaceButtons, buttonData: interfaceButtonData, width: StateKeeper.bW, height: StateKeeper.bH, spacing: StateKeeper.bSp)
        interfaceButtons["disconnectButton"]?.addTarget(self, action: #selector(self.scheduleDisconnectTimerFromButton), for: .touchDown)

        topButtons = createButtonsFromData(populateDict: topButtons, buttonData: topButtonData, width: StateKeeper.tbW, height: StateKeeper.bH, spacing: StateKeeper.tbSp)
        modifierButtons = createButtonsFromData(populateDict: modifierButtons, buttonData: modifierButtonData, width: StateKeeper.bW, height: StateKeeper.bH, spacing: StateKeeper.bSp)
        keyboardButtons = createButtonsFromData(populateDict: keyboardButtons, buttonData: keyboardButtonData, width: StateKeeper.bW, height: StateKeeper.bH, spacing: StateKeeper.bSp)
        overrideButtonVisibilityForMacOs()
    }
    
    func createButtonsFromData(populateDict: [String: UIControl], buttonData: [ String: [ String: Any ] ], width: CGFloat, height: CGFloat, spacing: CGFloat ) -> [String: UIControl] {
        var newButtonDict: [ String: UIControl ] = [:]
        buttonData.forEach() { button in
            let b = button.value
            let title = b["title"] as! String
            let topButton = b["top"] as! Bool
            let rightButton = b["right"] as! Bool
            if populateDict[button.key] == nil {
                // Create the button only if not already in the dictionary
                let background = (UITraitCollection.current.userInterfaceStyle == .light ? lightbBG : darkbBG)
                let toSend = b["send"] as! Int32
                let toggle = b["tgl"] as! Bool
                let nb = ToggleButton(frame: CGRect(), title: title, background: background, stateKeeper: self, toSend: toSend, toggle: toggle)
                if let imageName = b["image"] {
                    if let image = UIImage(systemName: imageName as! String) {
                        nb.setTitle(nil, for: .normal)
                        nb.setImage(image, for: .normal)
                        nb.tintColor = .white
                    }
                }
                newButtonDict[button.key] = nb
            } else {
                // Otherwise, reuse the existing button.
                newButtonDict[button.key] = populateDict[button.key]
                newButtonDict[button.key]?.backgroundColor = (UITraitCollection.current.userInterfaceStyle == .light ? lightbBG : darkbBG)
            }
            
            // In either case, adjust the location of the button
            // Left and right buttons have different logic for calculating x position
            var locX = b["lx"] as! CGFloat
            
            // Adjust locX to be left of safe area
            locX = locX + (globalWindow?.safeAreaInsets.left ?? 0)
            
            // Establish the right border
            let rightBorder = (globalWindow?.safeAreaInsets.left ?? 0) + (globalWindow?.safeAreaLayoutGuide.layoutFrame.size.width ?? 0)

            if rightButton {
                locX = rightBorder - (b["lx"] as! CGFloat)
            }
            // Top and bottom buttons have different logic for when they go up and down.
            var locY = b["ly"] as! CGFloat + topButtonSpacing
            if !topButton {
                locY = (globalWindow?.safeAreaInsets.top ?? 0) + (globalWindow?.safeAreaLayoutGuide.layoutFrame.size.height ?? 0) - (b["ly"] as! CGFloat) - self.keyboardHeight
            }
            // Top buttons can wrap around and go a row down if they are out of horizontal space.
            let windowWidth = globalWindow?.safeAreaLayoutGuide.layoutFrame.size.width ?? 0
            if topButton {
                locY = locY + (globalWindow?.safeAreaInsets.top ?? 0)
            }
            if topButton && locX + width > rightBorder {
                //print ("Need to wrap button: \(title) to left and a row down")
                locY = locY + height + spacing
                locX = locX - windowWidth + width
            }
            newButtonDict[button.key]?.frame = CGRect(x: locX, y: locY, width: width, height: height)
        }
        return newButtonDict
    }
    
    func addAllButtons() {
        //log_callback_str(message: "Adding all buttons to superview")
        self.addButtons(buttons: self.interfaceButtons)
        self.addButtons(buttons: self.modifierButtons)
        self.addButtons(buttons: self.keyboardButtons)
        self.addButtons(buttons: self.topButtons)
    }

    func addButtons(buttons: [String: UIControl]) {
        buttons.forEach(){ button in
            globalWindow!.addSubview(button.value)
        }
    }

    func removeAllButtons() {
        //log_callback_str(message: "Removing all buttons from superview")
        self.removeButtons(buttons: self.interfaceButtons)
        self.removeButtons(buttons: self.modifierButtons)
        self.removeButtons(buttons: self.keyboardButtons)
        self.removeButtons(buttons: self.topButtons)
    }
    
    func removeButtons(buttons: [String: UIControl]) {
        buttons.forEach(){ button in
            button.value.removeFromSuperview()
        }
    }
    
    /*
     Indicates the user will need to answer yes / no at a dialog.
     */
    func yesNoResponseRequired(title: LocalizedStringKey, messages: [ LocalizedStringKey ], nonLocalizedMessage: String) -> Int32 {
        self.localizedTitle = title
        self.localizedMessages = messages
        self.message = nonLocalizedMessage
        
        // Make sure current thread does not hold the lock
        self.yesNoDialogLock.unlock()

        UserInterface {
            // Acquire the lock on the UI thread
            self.yesNoDialogLock.unlock()
            self.yesNoDialogLock.lock()

            self.yesNoDialogResponse = 0
            self.currentPage = "yesNoMessage"
        }
        
        // Allow some time for the UI thread to aquire the lock
        Thread.sleep(forTimeInterval: 1)
        // Wait for approval on a lock held by the UI thread.
        self.yesNoDialogLock.lock()
        // Release the lock
        self.yesNoDialogLock.unlock()
        
        return self.yesNoDialogResponse
    }
    
    /*
     Sets the user's response to to a yes / no dialog.
     */
    func setYesNoReponse(response: Bool, pageYes: String, pageNo: String) {
        var responseInt: Int32 = 0
        if response {
            responseInt = 1
        }
        UserInterface {
            self.yesNoDialogResponse = responseInt
            self.yesNoDialogLock.unlock()
            if response {
                self.currentPage = pageYes
            } else {
                self.currentPage = pageNo
            }
        }
    }
    
    @objc func pressModifier(modifier: Int32) {
        guard self.getCurrentInstance() != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        self.remoteSession?.sendModifier(modifier: modifier, down: true)
    }

    @objc func releaseModifier(modifier: Int32) {
        guard self.getCurrentInstance() != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        self.remoteSession?.sendModifier(modifier: modifier, down: false)
    }
    
    @objc func sendSpecialKeyByXKeySym(key: Int32) {
        guard self.getCurrentInstance() != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        self.remoteSession?.sendSpecialKeyByXKeySym(key: key)
    }
    
    func toggleModifiersIfDown() {
        self.modifierButtons.forEach() { button in
            //print ("Toggling \(button.key) if down")
            (button.value as! ToggleButton).sendUpIfToggled()
        }
    }
    
    func keepSessionRefreshed() {
        BackgroundLowPrio {
            if !self.isKeptFresh {
                log_callback_str(message: "Will keep session fresh")
                self.isKeptFresh = true
                self.rescheduleScreenUpdateRequest(timeInterval: 1, fullScreenUpdate: true, recurring: false)
                self.rescheduleScreenUpdateRequest(timeInterval: 2, fullScreenUpdate: false, recurring: true)
            }
        }
    }
    
    func captureScreen(imageView: UIImageView?) -> UIImage {
        let emptyImage = UIImage()
        guard let imageView = imageView else {
            return emptyImage
        }
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, UIScreen.main.scale)
        guard let currentContext = UIGraphicsGetCurrentContext() else { return emptyImage }
        imageView.layer.render(in: currentContext)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    func getCurrentInstance() -> UnsafeMutableRawPointer? {
        if (self.currInst >= 0 && self.cl.endIndex > self.currInst) {
            return self.cl[self.currInst]
        } else {
            return nil
        }
    }
    
    func setCurrentInstance(inst: UnsafeMutableRawPointer?) {
        self.cl[self.currInst] = inst
    }
    
    func resizeWindow() {
        if currInst >= 0 && isDrawing && self.imageView?.image != nil {
            resize_callback(instance: Int32(currInst), fbW: globalFb.fbW, fbH: globalFb.fbH)
        }

        if !(self.remoteSession?.customResolution ?? false) {
            self.remoteSession?.syncRemoteToLocalResolution()
        }
        createAndRepositionButtons()
    }
    
    func exitNow() {
        exit(0)
    }

    fileprivate func useMacOsUIImageView() -> Bool {
        return self.isOnMacOsOriPadOnMacOs()
    }

    fileprivate func useShortPressDragDropAndLongPressPan() -> Bool {
        return self.connections.selectedConnection["touchInputMethod"] == TouchInputMethod.directLongPressPan.rawValue
    }
    
    fileprivate func useSimulatedTouchpad() -> Bool {
        return self.connections.selectedConnection["touchInputMethod"] == TouchInputMethod.simulatedTouchpad.rawValue
    }
    
    fileprivate func setInputMethod(_ leftSpacing: CGFloat, _ topSpacing: CGFloat, _ minScale: CGFloat) {
        let imageFrame = CGRect(x: leftSpacing, y: topSpacing, width: self.fbW*minScale, height: self.fbH*minScale)
        if self.useMacOsUIImageView() {
            log_callback_str(message: "Using ShortTapDragNoPanUIImageView")
            self.imageView = MacOsUIImageView(frame: imageFrame, stateKeeper: self, fbW: self.fbW, fbH: self.fbH)
        } else if self.useShortPressDragDropAndLongPressPan() {
            log_callback_str(message: "Using ShortTapDragLongPressPanUIImageView")
            self.imageView = ShortTapDragLongPressPanUIImageView(frame: imageFrame, stateKeeper: self, fbW: self.fbW, fbH: self.fbH)

        } else if self.useSimulatedTouchpad() {
            log_callback_str(message: "Using SimulatedTouchpadUIImageView")
            self.imageView = SimulatedTouchpadUIImageView(frame: imageFrame, stateKeeper: self, fbW: self.fbW, fbH: self.fbH)
        } else {
            log_callback_str(message: "Using LongTapDragUIImageView")
            self.imageView = LongTapDragUIImageView(frame: imageFrame, stateKeeper: self, fbW: self.fbW, fbH: self.fbH)
        }
    }
    
    func remoteResized(fbW: Int32, fbH: Int32) {
        UserInterface {
            autoreleasepool {
                self.fbW = CGFloat(fbW)
                self.fbH = CGFloat(fbH)
                self.remoteSession?.data = nil
                self.remoteSession?.reDrawTimer.invalidate()
                self.receivedUpdate = true
                self.imageView?.removeFromSuperview()
                self.imageView?.image = nil
                self.imageView = nil
                let minScale = self.getMinimumScale()
                self.correctTopSpacingForOrientation()
                let leftSpacing = self.leftSpacing
                let topSpacing = self.topSpacing
                self.setInputMethod(leftSpacing, topSpacing, minScale)
                self.imageView?.enableGestures()
                self.imageView?.enableTouch()
                globalWindow!.addSubview(self.imageView!)
                self.createAndRepositionButtons()
                self.addButtons(buttons: self.interfaceButtons)
                self.showConnectedSession()
                self.keepSessionRefreshed()
                self.clipboardMonitor?.startMonitoring()
                self.remoteSession?.hasDrawnFirstFrame = true
                if (Utils.isSpice()) {
                    self.reDraw()
                }
            }
        }
    }
    
    func requestCredentials() {
        self.requestingCredentials = true
        self.requestCredentialsForConnection()
    }
    
    func requestSshCredentials() {
        self.requestingSshCredentials = true
        self.requestCredentialsForConnection()
    }
    
    func isCurrentSessionConnected() -> Bool {
        return self.remoteSession?.connected ?? false
    }

    func isCurrentSessionConnectedAndDrawing() -> Bool {
        return self.isDrawing && self.isCurrentSessionConnected()
    }
    
	/*
    // Used to simulate failure with signal_handler
    @objc func fail() {
        Background {
            signal_handler(13, nil, nil)
        }
    }
    var failureTimer: Timer?
    func rescheduleFailureTimer() {
        UserInterface {
            log_callback_str(message: "Scheduling failure timer.")
            self.failureTimer?.invalidate()
            self.failureTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.fail), userInfo: nil, repeats: false)
        }
    }
    */
}
