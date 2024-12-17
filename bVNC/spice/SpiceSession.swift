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

class SpiceSession: RemoteSession {
    var consoleFile: String = ""
    var tlsPort: String = ""
    var certSubject: String = ""
    var certAuthority: String = ""
    var certAuthorityFile: String = ""

    class var SPICE_MOUSE_BUTTON_MOVE: Int { return 0 }
    class var SPICE_MOUSE_BUTTON_LEFT: Int { return 1 }
    class var SPICE_MOUSE_BUTTON_MIDDLE: Int { return 2 }
    class var SPICE_MOUSE_BUTTON_RIGHT: Int { return 3 }
    class var SPICE_MOUSE_BUTTON_UP: Int { return 4 }
    class var SPICE_MOUSE_BUTTON_DOWN: Int { return 5 }
    var buttonState: Int = 0
    var buttonStateMap: [Int: Bool] = [
        SPICE_MOUSE_BUTTON_LEFT: false,
        SPICE_MOUSE_BUTTON_MIDDLE: false,
        SPICE_MOUSE_BUTTON_RIGHT: false,
        SPICE_MOUSE_BUTTON_UP: false,
        SPICE_MOUSE_BUTTON_DOWN: false,
    ]
    
    fileprivate func startSpiceSessionOnBackgroundThread() {
        Background {
            self.stateKeeper.yesNoDialogLock.unlock()
            var title = ""
            var continueConnecting = true
            self.determineSshTunnelingStatusIfEnabled(sshAddress: self.sshAddress, &continueConnecting, &title)
            
            if continueConnecting {
                if (self.consoleFile != "") {
                    log_callback_str(message: "\(#function): Connecting SPICE session with console file \(self.consoleFile)")
                    self.cl = initializeSpiceVv(Int32(self.instance),
                                                Int32(self.width),
                                                Int32(self.height),
                                                update_callback,
                                                resize_callback,
                                                failure_callback_swift,
                                                log_callback,
                                                clipboard_callback,
                                                yes_no_dialog_callback,
                                                UnsafeMutablePointer<Int8>(mutating: (self.consoleFile as NSString).utf8String),
                                                self.audioEnabled)
                } else {
                    log_callback_str(message: "Connecting SPICE Session to \(self.address), port: \(self.port), tlsPort: \(self.tlsPort)")
                    self.cl = initializeSpice(Int32(self.instance),
                                              Int32(self.width),
                                              Int32(self.height),
                                              update_callback,
                                              resize_callback,
                                              failure_callback_swift,
                                              log_callback,
                                              clipboard_callback,
                                              yes_no_dialog_callback,
                                              UnsafeMutablePointer<Int8>(mutating: (self.address as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (self.port as NSString).utf8String),
                                              nil,
                                              UnsafeMutablePointer<Int8>(mutating: (self.tlsPort as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (self.pass as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (self.certAuthorityFile as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (self.certSubject as NSString).utf8String),
                                              self.audioEnabled)
                }
                if self.cl != nil {
                    self.stateKeeper.cl[self.stateKeeper.currInst] = self.cl
                } else {
                    title = "SPICE_CONNECTION_FAILURE_TITLE"
                    failure_callback_str(instance: self.instance, title: title)
                }
            } else {
                failure_callback_str(instance: self.instance, title: title)
            }
        }
    }
    
    override func connect(currentConnection: [String:String]) {
        self.consoleFile = currentConnection["consoleFile"] ?? ""
        self.sshAddress = currentConnection["sshAddress"] ?? ""
        self.sshPort = currentConnection["sshPort"] ?? ""
        self.sshUser = currentConnection["sshUser"] ?? ""
        self.sshPass = currentConnection["sshPass"] ?? ""
        self.port = currentConnection["port"] ?? ""
        self.tlsPort = currentConnection["tlsPort"] ?? ""
        self.address = currentConnection["address"] ?? ""
        self.sshPassphrase = currentConnection["sshPassphrase"] ?? ""
        self.sshPrivateKey = currentConnection["sshPrivateKey"] ?? ""
        self.certSubject = currentConnection["certSubject"] ?? ""
        self.certAuthority = currentConnection["certAuthority"] ?? ""
        self.keyboardLayout = currentConnection["keyboardLayout"] ??
                                Constants.DEFAULT_LAYOUT
        self.audioEnabled = Bool(currentConnection["audioEnabled"] ?? "true")!

        self.certAuthorityFile = Utils.writeToFile(name: "ca.crt", text: certAuthority)

        self.sshForwardPort = String(arc4random_uniform(30000) + 30000)
        
        layoutMap = Utils.loadStringOfIntArraysToMap(
                        source: Utils.getBundleFileContents(
                            name: Constants.LAYOUT_PATH + keyboardLayout))
        
        if sshAddress != "" {
            self.stateKeeper.sshTunnelingStarted = false
            // FIXME: Forward to whichever port is not -1 preferring TLS port
            // FIXME: Forward to both ports if both are not -1
            let forwardToAddress = self.address
            let forwardToPort = self.port
            self.address = "127.0.0.1"
            self.port = self.sshForwardPort
            startSshForwardingOnBackgroundThread(forwardToAddress, forwardToPort)
        }
        
        self.pass = currentConnection["password"] ?? ""

        startSpiceSessionOnBackgroundThread()
        super.connect(currentConnection: currentConnection)
    }
        
    override func disconnect() {
        if self.connected {
            super.disconnect()
            Background {
                disconnectSpice()
            }
        }
    }
    
    override func pointerEvent(remoteX: Float, remoteY: Float,
                               firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                               scrollUp: Bool, scrollDown: Bool) {
        var isDown = 0
        var buttonId = 0
        var stateChanged = 0
        
        let firstStateChanged = updateCurrentState(
            buttonId: SpiceSession.SPICE_MOUSE_BUTTON_LEFT, isDown: firstDown)
        let secondStateChanged = updateCurrentState(
            buttonId: SpiceSession.SPICE_MOUSE_BUTTON_MIDDLE, isDown: secondDown)
        let thirdStateChanged = updateCurrentState(
            buttonId: SpiceSession.SPICE_MOUSE_BUTTON_RIGHT, isDown: thirdDown)
        let scrollUpStateChanged = updateCurrentState(
            buttonId: SpiceSession.SPICE_MOUSE_BUTTON_UP, isDown: scrollUp)
        let scrollDownStateChanged = updateCurrentState(
            buttonId: SpiceSession.SPICE_MOUSE_BUTTON_DOWN, isDown: scrollDown)

        let buttonState = getButtonState(firstDown, secondDown, thirdDown, scrollUp, scrollDown)
        
        var message = "Motion event"
        if firstStateChanged {
            message = "Left button"
            stateChanged = 1
            isDown = firstDown ? 1 : 0
            buttonId = SpiceSession.SPICE_MOUSE_BUTTON_LEFT
        }
        if secondStateChanged {
            message = "Middle button"
            stateChanged = 1
            isDown = secondDown ? 1 : 0
            buttonId = SpiceSession.SPICE_MOUSE_BUTTON_MIDDLE
        }
        if thirdStateChanged {
            message = "Right button"
            stateChanged = 1
            isDown = thirdDown ? 1 : 0
            buttonId = SpiceSession.SPICE_MOUSE_BUTTON_RIGHT
        }
        if scrollUpStateChanged {
            message = "ScrollUp action"
            stateChanged = 1
            isDown = scrollUp ? 1 : 0
            buttonId = SpiceSession.SPICE_MOUSE_BUTTON_UP
        }
        if scrollDownStateChanged {
            message = "ScrollDown action"
            stateChanged = 1
            isDown = scrollDown ? 1 : 0
            buttonId = SpiceSession.SPICE_MOUSE_BUTTON_DOWN
        }

        //print(message, "x:", remoteX, "y:", remoteY, "buttonId:", buttonId, "buttonState:", buttonState, "isDown:", isDown)

        // FIXME: Send modifier keys when appropriate.
        sendPointerEvent(Int32(remoteX), Int32(remoteY),
                         Int32(buttonId),
                         Int32(buttonState),
                         Int32(stateChanged),
                         Int32(isDown))
    }
    
    override func keyEvent(char: Unicode.Scalar) {
        let char = String(char.value)
        let unicodeInt = Int(char)!
        sendUnicodeKeyEvent(char: unicodeInt | RemoteSession.UNICODE_MASK)
    }
    
    override func sendUnicodeKeyEvent(char: Int) {
        let scanCodes = getScanCodesForKeyCodeChar(char: char)
        for scanCode in scanCodes {
            var scode = scanCode
            if scanCode & RemoteSession.SCANCODE_SHIFT_MASK != 0 {
                log_callback_str(message: "Found SCANCODE_SHIFT_MASK, sending Shift down")
                spiceKeyEvent(1, Int32(SpiceSession.LSHIFT))
                scode &= ~RemoteSession.SCANCODE_SHIFT_MASK
            }
            if scanCode & RemoteSession.SCANCODE_ALTGR_MASK != 0 {
                log_callback_str(message: "Found SCANCODE_ALTGR_MASK, sending AltGr down")
                spiceKeyEvent(1, Int32(SpiceSession.RALT))
                scode &= ~RemoteSession.SCANCODE_ALTGR_MASK
            }
            
            spiceKeyEvent(1, Int32(scode))
            spiceKeyEvent(0, Int32(scode))
            
            if scanCode & RemoteSession.SCANCODE_SHIFT_MASK != 0 {
                log_callback_str(message: "Found SCANCODE_SHIFT_MASK, sending Shift up")
                spiceKeyEvent(0, Int32(SpiceSession.LSHIFT))
            }
            if scanCode & RemoteSession.SCANCODE_ALTGR_MASK != 0 {
                log_callback_str(message: "Found SCANCODE_ALTGR_MASK, sending AltGr up")
                spiceKeyEvent(0, Int32(SpiceSession.RALT))
            }
        }
    }
    
    @objc override func sendModifier(modifier: Int32, down: Bool) {
        let scode = xKeySymToScanCode[modifier] ?? 0
        if scode != 0 {
            self.stateKeeper.modifiers[modifier] = down
            log_callback_str(message: "SpiceSession: sendModifier, scancode: \(scode), down: \(down)")
            let keyDirection: Int16 = down ? 1 : 0
            spiceKeyEvent(keyDirection, Int32(scode))
        }
    }
    
    @objc override func sendSpecialKeyByXKeySym(key: Int32) {
        let scanCodes = getScanCodesOrSendKeyIfUnicode(key: key)
        for scanCode in scanCodes {
            spiceKeyEvent(1, Int32(scanCode))
            spiceKeyEvent(0, Int32(scanCode))
        }
    }
    
    @objc override func sendUniDirectionalSpecialKeyByXKeySym(key: Int32, down: Bool) {
        let scanCodes = getScanCodesOrSendKeyIfUnicode(key: key)
        let d: Int16 = down ? 1 : 0
        for scanCode in scanCodes {
            spiceKeyEvent(d, Int32(scanCode))
        }
    }

    @objc override func sendScreenUpdateRequest(incrementalUpdate: Bool) {
        reDraw()
    }
    
    override func requestRemoteResolution(x: Int, y: Int) {
        log_callback_str(message: "Requesting remote resolution to be \(x)x\(y)")
        resetDesiredResolution(Int32(x), Int32(y));
        requestResolution(Int32(x), Int32(y));
    }
}
