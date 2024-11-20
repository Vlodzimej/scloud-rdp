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


class RdpSession: RemoteSession {
    var gatewayEnabled: Bool = false
    var gatewayAddress: String = ""
    var gatewayPort: String = ""
    var gatewayDomain: String = ""
    var gatewayUser: String = ""
    var gatewayPass: String = ""
    var configFile: String = ""
    var desktopScaleFactor: Int = Constants.DEFAULT_DESKTOP_SCALE_FACTOR

    class var KBD_FLAGS_EXTENDED: Int { return 0x0100 }
    class var KBD_FLAGS_EXTENDED1: Int { return 0x0200 }
    class var KBD_FLAGS_DOWN: Int { return 0x4000 }
    class var KBD_FLAGS_RELEASE: Int { return 0x8000 }

    class var PTRFLAGS_WHEEL: Int { return 0x0200 }
    class var PTRFLAGS_WHEEL_NEGATIVE: Int { return 0x0100 }
    class var PTRFLAGS_DOWN: Int { return 0x8000 }
    
    class var MOUSE_BUTTON_NONE: Int { return 0x0000 }
    class var MOUSE_BUTTON_MOVE: Int { return 0x0800 }
    class var MOUSE_BUTTON_LEFT: Int { return 0x1000 }
    class var MOUSE_BUTTON_RIGHT: Int { return 0x2000 }
    
    class var MOUSE_BUTTON_MIDDLE: Int { return 0x4000 }
    class var MOUSE_BUTTON_SCROLL_UP: Int { return PTRFLAGS_WHEEL|0x0078 }
    class var MOUSE_BUTTON_SCROLL_DOWN: Int { return PTRFLAGS_WHEEL|PTRFLAGS_WHEEL_NEGATIVE|0x0088 }
    
    var buttonStateMap: [Int: Bool] = [
        MOUSE_BUTTON_LEFT: false,
        MOUSE_BUTTON_MIDDLE: false,
        MOUSE_BUTTON_RIGHT: false,
        MOUSE_BUTTON_SCROLL_UP: false,
        MOUSE_BUTTON_SCROLL_DOWN: false,
    ]
    
    override class var LCONTROL: Int { return 0xA2 }
    override class var RCONTROL: Int { return 0xA3 }
    override class var LALT: Int { return 0xA4 }
    override class var RALT: Int { return 0xA5 | KBD_FLAGS_EXTENDED }
    override class var LSHIFT: Int { return 0xA0 }
    override class var RSHIFT: Int { return 0xA1 }
    override class var LWIN: Int { return 0x5B }
    override class var RWIN: Int { return 0x5C }
    override class var PAGE_UP: Int { return 0x21 }
    override class var PAGE_DOWN: Int { return 0x22 }
    override class var HOME: Int { return 0x24 }
    override class var END: Int { return 0x23 }
    override class var DEL: Int { return 0x2E }
    
    // FIXME: Make a configuration value
    var preferSendingUnicode = false
    
    var xKeySymToKeyCode: [Int32: Int] = [
        XK_Super_L: RdpSession.LWIN,
        XK_Super_R: RdpSession.RWIN,
        XK_Control_L: RdpSession.LCONTROL,
        XK_Control_R: RdpSession.RCONTROL,
        XK_Alt_L: RdpSession.LALT,
        XK_Alt_R: RdpSession.RALT,
        XK_Shift_L: RdpSession.LSHIFT,
        XK_Shift_R: RdpSession.RSHIFT,
        XK_Page_Up: RdpSession.PAGE_UP,
        XK_Page_Down: RdpSession.PAGE_DOWN,
        XK_Home: RdpSession.HOME,
        XK_End: RdpSession.END,
        XK_Delete: RdpSession.DEL
    ]
    
    fileprivate func getUnsafeMutablePointerAsString(_ str: String) -> UnsafeMutablePointer<Int8>? {
        return UnsafeMutablePointer<Int8>(mutating: (str as NSString).utf8String)
    }
    
    fileprivate func getForwardToAddress(_ gatewayEnabled: Bool, _ gatewayAddress: String, _ address: String) -> String {
        return gatewayEnabled ? gatewayAddress : address
    }
    
    fileprivate func getForwardToPort(_ gatewayEnabled: Bool, _ gatewayPort: String, _ port: String) -> String {
        return gatewayEnabled ? gatewayPort : port
    }
    
    fileprivate func getRdpServerAddress(_ gatewayEnabled: Bool, _ address: String) -> String {
        return gatewayEnabled ? address : "127.0.0.1"
    }
    
    fileprivate func getRdpServerPort(_ gatewayEnabled: Bool, _ port: String, _ sshForwardPort: String) -> String {
        return gatewayEnabled ? port : sshForwardPort
    }
    
    fileprivate func getRdpGatewayAddress(_ gatewayEnabled: Bool, _ gatewayAddress: String) -> String {
        return gatewayEnabled ? "127.0.0.1" : gatewayAddress
    }
    
    fileprivate func getRdpGatewayPort(_ gatewayEnabled: Bool, _ sshForwardPort: String, _ gatewayPort: String) -> String {
        return gatewayEnabled ? sshForwardPort : gatewayPort
    }
    
    fileprivate func connectRdpOrShowError(_ continueConnecting: Bool, _ errorTitle: inout String) {
        if self.cl != nil {
            self.stateKeeper.cl[self.stateKeeper.currInst] = self.cl
            connectRdpInstance(self.cl)
        } else {
            if continueConnecting {
                // The failure to initiate RDP connection was not due to SSH forwarding failure
                errorTitle = "APP_MUST_EXIT_TITLE"
                failure_callback_str(instance: self.instance, title: errorTitle, errorPage: "mustExitErrorMessage")
            } else {
                failure_callback_str(instance: self.instance, title: errorTitle)
            }
        }
    }
    
    fileprivate func startRdpSessionOnBackgroundThread() {
        Background {
            self.stateKeeper.yesNoDialogLock.unlock()
            var errorTitle = ""
            var continueConnecting = true
            self.determineSshTunnelingStatusIfEnabled(sshAddress: self.sshAddress, &continueConnecting, &errorTitle)
            
            if continueConnecting {
                log_callback_str(message: "Connecting RDP Session to \(self.address):\(self.port) or file \(self.configFile)")
                log_callback_str(message: "RDP Session width: \(self.width), height: \(self.height)")
                
                self.cl = initializeRdp(
                    Int32(self.instance),
                    Int32(self.width),
                    Int32(self.height),
                    Int32(self.desktopScaleFactor),
                    update_callback,
                    resize_callback,
                    failure_callback_swift,
                    log_callback,
                    utf8_clipboard_callback,
                    yes_no_dialog_callback,
                    self.getUnsafeMutablePointerAsString(self.configFile),
                    self.getUnsafeMutablePointerAsString(self.address),
                    self.getUnsafeMutablePointerAsString(self.port),
                    self.getUnsafeMutablePointerAsString(self.domain),
                    self.getUnsafeMutablePointerAsString(self.user),
                    self.getUnsafeMutablePointerAsString(self.pass),
                    self.audioEnabled,
                    self.getUnsafeMutablePointerAsString(self.gatewayAddress),
                    self.getUnsafeMutablePointerAsString(self.gatewayPort),
                    self.getUnsafeMutablePointerAsString(self.gatewayDomain),
                    self.getUnsafeMutablePointerAsString(self.gatewayUser),
                    self.getUnsafeMutablePointerAsString(self.gatewayPass),
                    self.gatewayEnabled
                )
            }
            
            self.connectRdpOrShowError(continueConnecting, &errorTitle)
        }
    }
    
    override func connect(currentConnection: [String:String]) {
        self.sshAddress = currentConnection["sshAddress"] ?? ""
        self.sshPort = currentConnection["sshPort"] ?? ""
        self.sshUser = currentConnection["sshUser"] ?? ""
        self.sshPass = currentConnection["sshPass"] ?? ""
        self.port = currentConnection["port"] ?? ""
        self.address = currentConnection["address"] ?? ""
        self.sshPassphrase = currentConnection["sshPassphrase"] ?? ""
        self.sshPrivateKey = currentConnection["sshPrivateKey"] ?? ""
        self.keyboardLayout = currentConnection["keyboardLayout"] ??
                                Constants.DEFAULT_LAYOUT
        self.audioEnabled = Bool(currentConnection["audioEnabled"] ?? "false")!
        self.gatewayEnabled = Bool(currentConnection["rdpGatewayEnabled"] ?? "false")!
        self.gatewayAddress = currentConnection["rdpGatewayAddress"] ?? ""
        self.gatewayPort = currentConnection["rdpGatewayPort"] ?? ""
        self.configFile = currentConnection["consoleFile"] ?? ""
        self.desktopScaleFactor = Utils.getScaleFactor(currentConnection["desktopScaleFactor"])

        self.sshForwardPort = String(arc4random_uniform(30000) + 30000)
        
        self.layoutMap = Utils.loadStringOfIntArraysToMap(
                        source: Utils.getBundleFileContents(
                            name: Constants.LAYOUT_PATH + keyboardLayout))
        
        if sshAddress != "" {
            self.stateKeeper.sshTunnelingStarted = false
            let forwardToAddress = getForwardToAddress(gatewayEnabled, gatewayAddress, address)
            let forwardToPort = getForwardToPort(gatewayEnabled, gatewayPort, port)
            address = getRdpServerAddress(gatewayEnabled, address)
            port = getRdpServerPort(gatewayEnabled, port, sshForwardPort)
            gatewayAddress = getRdpGatewayAddress(gatewayEnabled, gatewayAddress)
            gatewayPort = getRdpGatewayPort(gatewayEnabled, sshForwardPort, gatewayPort)
            startSshForwardingOnBackgroundThread(forwardToAddress, forwardToPort)
        }
        
        self.domain = currentConnection["domain"] ?? ""
        self.user = currentConnection["username"] ?? ""
        self.pass = currentConnection["password"] ?? ""
        self.gatewayDomain = currentConnection["rdpGatewayDomain"] ?? ""
        self.gatewayUser = currentConnection["rdpGatewayUser"] ?? ""
        self.gatewayPass = currentConnection["rdpGatewayPass"] ?? ""

        startRdpSessionOnBackgroundThread()
        super.connect(currentConnection: currentConnection)
    }
        
    override func disconnect() {
        if self.connected {
            super.disconnect()
            self.connected = false
            synchronized(self) {
                disconnectRdp(self.cl)
                self.cl = nil
            }
        }
    }
    
    fileprivate func sendCursorEventIfConnected(_ remoteX: Float, _ remoteY: Float, _ buttonId: Int) {
        if (self.connected && self.hasDrawnFirstFrame && self.cl != nil) {
            cursorEvent(self.cl, Int32(remoteX), Int32(remoteY), Int32(buttonId))
        }
    }
    
    override func pointerEvent(remoteX: Float, remoteY: Float,
                               firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                               scrollUp: Bool, scrollDown: Bool) {
        // TODO: Try implementing composite button support.
        var buttonId = RdpSession.MOUSE_BUTTON_MOVE
        
        let firstStateChanged = updateCurrentState(
            buttonId: RdpSession.MOUSE_BUTTON_LEFT, isDown: firstDown)
        let secondStateChanged = updateCurrentState(
            buttonId: RdpSession.MOUSE_BUTTON_MIDDLE, isDown: secondDown)
        let thirdStateChanged = updateCurrentState(
            buttonId: RdpSession.MOUSE_BUTTON_RIGHT, isDown: thirdDown)
        let scrollUpStateChanged = updateCurrentState(
            buttonId: RdpSession.MOUSE_BUTTON_SCROLL_UP, isDown: scrollUp)
        let scrollDownStateChanged = updateCurrentState(
            buttonId: RdpSession.MOUSE_BUTTON_SCROLL_DOWN, isDown: scrollDown)
        
        if firstStateChanged {
            buttonId = RdpSession.MOUSE_BUTTON_LEFT
            if (firstDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if secondStateChanged {
            buttonId = RdpSession.MOUSE_BUTTON_MIDDLE
            if (secondDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if thirdStateChanged {
            buttonId = RdpSession.MOUSE_BUTTON_RIGHT
            if (thirdDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if scrollUpStateChanged {
            buttonId = RdpSession.MOUSE_BUTTON_SCROLL_UP
            if (scrollUp) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if scrollDownStateChanged {
            buttonId = RdpSession.MOUSE_BUTTON_SCROLL_DOWN
            if (scrollDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        
        // FIXME: Send modifier keys when appropriate.
        sendCursorEventIfConnected(remoteX, remoteY, buttonId)
    }
    
    override func keyEvent(char: Unicode.Scalar) {
        // FIXME: Do not send keyboard events for any protocol unless connection is ongoing.
        let char = String(char.value)
        let unicodeInt = Int(char)!
        // FIXME: Do not send unicode when Control key is pressed in order to be able to send control characters
        if (preferSendingUnicode) {
            unicodeKeyEvent(self.cl, 0, Int32(unicodeInt))
        } else {
            sendUnicodeKeyEvent(char: unicodeInt | RemoteSession.UNICODE_MASK)
        }
    }
    
    fileprivate func getKeyFlagsForScanCode(_ virtualScanCode: Int32, down: Bool) -> Int32 {
        var keyFlags = down ? RdpSession.KBD_FLAGS_DOWN : RdpSession.KBD_FLAGS_RELEASE
        keyFlags |= ((Int(virtualScanCode) & RdpSession.KBD_FLAGS_EXTENDED) != 0) ? RdpSession.KBD_FLAGS_EXTENDED : 0
        return Int32(keyFlags)
    }
    
    fileprivate func sendVkKeyEventIfConnected(_ flags: Int32, _ code: Int32) {
        if (self.connected && self.hasDrawnFirstFrame && self.cl != nil) {
            vkKeyEvent(self.cl, flags, code)
        }
    }
    
    override func sendUnicodeKeyEvent(char: Int) {
        let scanCodes = getScanCodesForKeyCodeChar(char: char)
        for scanCode in scanCodes {
            var scode = scanCode
            if scanCode & RemoteSession.SCANCODE_SHIFT_MASK != 0 {
                log_callback_str(message: "Found SCANCODE_SHIFT_MASK, sending Shift down")
                sendVkKeyEventIfConnected(Int32(RdpSession.KBD_FLAGS_DOWN), getVirtualScanCode(code: RdpSession.LSHIFT))
                scode &= ~RemoteSession.SCANCODE_SHIFT_MASK
            }
            if scanCode & RemoteSession.SCANCODE_ALTGR_MASK != 0 {
                let virtualScanCode = getVirtualScanCode(code: RdpSession.RALT)
                let keyFlags = getKeyFlagsForScanCode(virtualScanCode, down: true)
                log_callback_str(message: "Found SCANCODE_ALTGR_MASK, sending AltGr down")
                sendVkKeyEventIfConnected(keyFlags, virtualScanCode)
                scode &= ~RemoteSession.SCANCODE_ALTGR_MASK
            }
        
            //log_callback_str(message: "RdpSession: sendUnicodeKeyEvent: \(scode)")
            sendVkKeyEventIfConnected(Int32(RdpSession.KBD_FLAGS_DOWN), Int32(scode))
            sendVkKeyEventIfConnected(Int32(RdpSession.KBD_FLAGS_RELEASE), Int32(scode))
            
            if scanCode & RemoteSession.SCANCODE_SHIFT_MASK != 0 {
                log_callback_str(message: "Found SCANCODE_SHIFT_MASK, sending Shift up")
                sendVkKeyEventIfConnected(Int32(RdpSession.KBD_FLAGS_RELEASE), getVirtualScanCode(code: RdpSession.LSHIFT))
            }
            if scanCode & RemoteSession.SCANCODE_ALTGR_MASK != 0 {
                let virtualScanCode = getVirtualScanCode(code: RdpSession.RALT)
                let keyFlags = getKeyFlagsForScanCode(virtualScanCode, down: false)
                log_callback_str(message: "Found SCANCODE_ALTGR_MASK, sending AltGr up")
                sendVkKeyEventIfConnected(keyFlags, virtualScanCode)
            }
        }
    }
    
    func getVirtualScanCode(code: Int) -> Int32 {
        var scode: Int32 = 0
        struct Holder {
            static var timesCalled = 0
        }
        if code == RdpSession.LWIN {
            scode = 347
        } else if code == RdpSession.RWIN {
            scode = 236
        } else if code == RdpSession.RALT {
            scode = 312
        } else {
            // FIXME: Replace call to GetVirtualScanCodeFromVirtualKeyCode with implementation using layoutMap
            scode = Int32(GetVirtualScanCodeFromVirtualKeyCode(DWORD(code), 4) & 0xFF)
        }
        return scode
    }
    
    @objc override func sendModifier(modifier: Int32, down: Bool) {
        let code = xKeySymToKeyCode[modifier] ?? 0
        if code != 0 {
            self.stateKeeper.modifiers[modifier] = down
            let scode = getVirtualScanCode(code: code)
            let keyFlags = getKeyFlagsForScanCode(Int32(scode), down: down)
            log_callback_str(message: "RdpSession: sendModifier, modifier: \(modifier), code: \(code), scode: \(scode), down: \(down)")
            sendVkKeyEventIfConnected(Int32(keyFlags), Int32(scode))
        }
    }
    
    @objc override func sendSpecialKeyByXKeySym(key: Int32) {
        let scanCodes = getScanCodesOrSendKeyIfUnicode(key: key)
        for scode in scanCodes {
            sendVkKeyEventIfConnected(Int32(RdpSession.KBD_FLAGS_DOWN), Int32(scode))
            sendVkKeyEventIfConnected(Int32(RdpSession.KBD_FLAGS_RELEASE), Int32(scode))
        }
    }
    
    @objc override func sendUniDirectionalSpecialKeyByXKeySym(key: Int32, down: Bool) {
        let scanCodes = getScanCodesOrSendKeyIfUnicode(key: key)
        let d: Int = down ? RdpSession.KBD_FLAGS_DOWN : RdpSession.KBD_FLAGS_RELEASE
        for scode in scanCodes {
            log_callback_str(message: "RdpSession: sendSpecialKeyByXKeySym: \(scode)")
            sendVkKeyEventIfConnected(Int32(d), Int32(scode))
        }
    }
    
    @objc override func sendScreenUpdateRequest(incrementalUpdate: Bool) {
        // Not used for RDP
    }
    
    override func requestRemoteResolution(x: Int, y: Int) {
        log_callback_str(message: "Requesting remote resolution to be \(x)x\(y)")
        Background {
            resizeRemoteRdpDesktop(self.cl, Int32(x), Int32(y))
            self.stateKeeper.reDraw()
        }
    }
}
