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
    
    override func connect(currentConnection: [String:String]) {
        let consoleFile = currentConnection["consoleFile"] ?? ""
        let sshAddress = currentConnection["sshAddress"] ?? ""
        let sshPort = currentConnection["sshPort"] ?? ""
        let sshUser = currentConnection["sshUser"] ?? ""
        let sshPass = currentConnection["sshPass"] ?? ""
        var port = currentConnection["port"] ?? ""
        let tlsPort = currentConnection["tlsPort"] ?? ""
        var address = currentConnection["address"] ?? ""
        let sshPassphrase = currentConnection["sshPassphrase"] ?? ""
        let sshPrivateKey = currentConnection["sshPrivateKey"] ?? ""
        let certSubject = currentConnection["certSubject"] ?? ""
        let certAuthority = currentConnection["certAuthority"] ?? ""
        let keyboardLayout = currentConnection["keyboardLayout"] ??
                                Constants.DEFAULT_LAYOUT
        let certAuthorityFile = Utils.writeToFile(name: "ca.crt", text: certAuthority)

        let sshForwardPort = String(arc4random_uniform(30000) + 30000)
        layoutMap = Utils.loadStringOfIntArraysToMap(
                        source: Utils.getBundleFileContents(
                            name: Constants.LAYOUT_PATH + keyboardLayout))
        
        if sshAddress != "" {
            self.stateKeeper.sshTunnelingStarted = false
            Background {
                self.stateKeeper.sshForwardingLock.unlock()
                self.stateKeeper.sshForwardingLock.lock()
                self.stateKeeper.sshTunnelingStarted = true
                log_callback_str(message: "Setting up SSH forwarding")
                
                // FIXME: Forward to whichever port is not -1 preferring TLS port
                // FIXME: Forward to both ports if both are not -1
                let forwardToAddress = address
                let forwardToPort = port
                address = "127.0.0.1"
                port = sshForwardPort
                setupSshPortForward(
                    Int32(self.stateKeeper.currInst),
                    ssh_forward_success,
                    ssh_forward_failure,
                    log_callback,
                    yes_no_dialog_callback,
                    UnsafeMutablePointer<Int8>(mutating: (sshAddress as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (sshPort as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (sshUser as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (sshPass as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (sshPassphrase as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (sshPrivateKey as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: ("127.0.0.1" as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (sshForwardPort as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (forwardToAddress as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (forwardToPort as NSString).utf8String))
            }
        }
        
        let pass = currentConnection["password"] ?? ""

        Background {
            // Make it highly probable the SSH thread would obtain the lock before the SPICE one does.
            self.stateKeeper.yesNoDialogLock.unlock()
            var title = ""
            var continueConnecting = true
            if sshAddress != "" {
                // Wait until the SSH tunnel lock is obtained by the thread which sets up ssh tunneling.
                while self.stateKeeper.sshTunnelingStarted != true {
                    log_callback_str(message: "Waiting for SSH thread to start work")
                    sleep(1)
                }
                log_callback_str(message: "Waiting for SSH forwarding to complete successfully")
                // Wait for SSH Tunnel to be established for 60 seconds
                continueConnecting = self.stateKeeper.sshForwardingLock.lock(before: Date(timeIntervalSinceNow: 60))
                if !continueConnecting {
                    title = "SSH_TUNNEL_TIMEOUT_TITLE"
                } else if (self.stateKeeper.sshForwardingStatus != true) {
                    title = "SSH_TUNNEL_CONNECTION_FAILURE_TITLE"
                    continueConnecting = false
                } else {
                    log_callback_str(message: "SSH Tunnel indicated to be successful")
                    self.stateKeeper.sshForwardingLock.unlock()
                }
            }
            if continueConnecting {
                log_callback_str(message: "Connecting SPICE Session in the background...")
                if (consoleFile != "") {
                    log_callback_str(message: "\(#function): Connecting with console file \(consoleFile)")
                    self.cl = initializeSpiceVv(Int32(self.instance),
                                                Int32(self.width),
                                                Int32(self.height),
                                                update_callback,
                                                resize_callback,
                                                failure_callback_swift,
                                                log_callback,
                                                clipboard_callback,
                                                yes_no_dialog_callback,
                                                UnsafeMutablePointer<Int8>(mutating: (consoleFile as NSString).utf8String),
                                                true)
                } else {
                    log_callback_str(message: "\(#function): Connecting with selected connection parameters")
                    self.cl = initializeSpice(Int32(self.instance),
                                              Int32(self.width),
                                              Int32(self.height),
                                              update_callback,
                                              resize_callback,
                                              failure_callback_swift,
                                              log_callback,
                                              clipboard_callback,
                                              yes_no_dialog_callback,
                                              UnsafeMutablePointer<Int8>(mutating: (address as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (port as NSString).utf8String),
                                              nil,
                                              UnsafeMutablePointer<Int8>(mutating: (tlsPort as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (pass as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (certAuthorityFile as NSString).utf8String),
                                              UnsafeMutablePointer<Int8>(mutating: (certSubject as NSString).utf8String),
                                              true)
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
        
    override func disconnect() {
        Background {
            disconnectSpice()
        }
    }
    
    override func pointerEvent(totalX: Float, totalY: Float, x: Float, y: Float,
                               firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                               scrollUp: Bool, scrollDown: Bool) {
        let remoteX = Float(self.stateKeeper.fbW) * x / totalX
        let remoteY = Float(self.stateKeeper.fbH) * y / totalY
        
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
    
    @objc override func sendModifierIfNotDown(modifier: Int32) {
        let scode = xKeySymToScanCode[modifier] ?? 0
        if scode != 0 && !self.stateKeeper.modifiers[modifier]! {
            self.stateKeeper.modifiers[modifier] = true
            log_callback_str(message: "SpiceSession: Sending modifier scancode \(scode)")
            spiceKeyEvent(1, Int32(scode))
        }
    }

    @objc override func releaseModifierIfDown(modifier: Int32) {
        let scode = xKeySymToScanCode[modifier] ?? 0
        if scode != 0 && self.stateKeeper.modifiers[modifier]! {
            self.stateKeeper.modifiers[modifier] = false
            log_callback_str(message: "SpiceSession: Releasing modifier scancode \(scode)")
            spiceKeyEvent(0, Int32(scode))
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
        // Not used for SPICE
    }
    
    override func requestRemoteResolution(x: Int, y: Int) {
        log_callback_str(message: "Requesting remote resolution to be \(x)x\(y)")
        requestResolution(Int32(x), Int32(y));
    }
    
    override func clientCutText(clientClipboardContents: String?) {
        guard (self.stateKeeper.getCurrentInstance()) != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        let clipboardStr = clientClipboardContents ?? ""
        let clientClipboardContentsPtr = UnsafeMutablePointer<Int8>(mutating: (clipboardStr as NSString).utf8String)
        let length = clipboardStr.lengthOfBytes(using: .utf8)
        setHostClipboard(clientClipboardContentsPtr, Int32(length))
    }
}
