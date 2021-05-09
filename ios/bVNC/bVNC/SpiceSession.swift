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
    
    class var LCONTROL: Int { return 29 }
    class var RCONTROL: Int { return 285 }
    class var LALT: Int { return 56 }
    class var RALT: Int { return 312 }
    class var LSHIFT: Int { return 42 }
    class var RSHIFT: Int { return 54 }
    class var LWIN: Int { return 347 }
    class var RWIN: Int { return 348 }
    
    var xKeySymToScanCode: [Int32: Int] = [
        XK_Super_L: SpiceSession.LWIN,
        XK_Super_R: SpiceSession.RWIN,
        XK_Control_L: SpiceSession.LCONTROL,
        XK_Control_R: SpiceSession.RCONTROL,
        XK_Alt_L: SpiceSession.LALT,
        XK_Alt_R: SpiceSession.RALT,
        XK_Shift_L: SpiceSession.LSHIFT,
        XK_Shift_R: SpiceSession.RSHIFT
    ]
    
    var specialXKeySymToUnicodeMap: [Int32: Int] = [
        XK_F1: 0xF704,
        XK_F2: 0xF705,
        XK_F3: 0xF706,
        XK_F4: 0xF707,
        XK_F5: 0xF708,
        XK_F6: 0xF709,
        XK_F7: 0xF70A,
        XK_F8: 0xF70B,
        XK_F9: 0xF70C,
        XK_F10: 0xF70D,
        XK_F11: 0xF70E,
        XK_F12: 0xF70F,
        XK_Escape: 0x001B,
        XK_Home: 0x21F1,
        XK_End: 0x21F2,
        XK_Page_Up: 0x21DE,
        XK_Page_Down: 0x21DF,
        XK_Up: 0x2191,
        XK_Down: 0x2193,
        XK_Left: 0x2190,
        XK_Right: 0x2192,
        XK_BackSpace: 0x0008,
    ]

    class var SCANCODE_SHIFT_MASK: Int { return 0x10000 }
    class var SCANCODE_ALTGR_MASK: Int { return 0x20000 }
    class var SCANCODE_CIRCUMFLEX_MASK: Int { return 0x40000 }
    class var SCANCODE_DIAERESIS_MASK: Int { return 0x80000 }
    class var UNICODE_MASK: Int { return 0x100000 }
    var layoutMap: [Int: [Int]] = [:]

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
        let port = currentConnection["port"] ?? ""
        let tlsPort = currentConnection["tlsPort"] ?? ""
        let address = currentConnection["address"] ?? ""
        let sshPassphrase = currentConnection["sshPassphrase"] ?? ""
        let sshPrivateKey = currentConnection["sshPrivateKey"] ?? ""
        let certSubject = currentConnection["certSubject"] ?? ""
        let certAuthority = currentConnection["certAuthority"] ?? ""
        let keyboardLayout = currentConnection["keyboardLayout"] ??
                                Constants.SPICE_DEFAULT_LAYOUT
        let certAuthorityFile = Utils.writeToFile(name: "ca.crt", text: certAuthority)

        let sshForwardPort = String(arc4random_uniform(30000) + 30000)
        layoutMap = Utils.loadStringOfIntArraysToMap(
                        source: Utils.getBundleFileContents(
                            name: Constants.SPICE_LAYOUT_PATH + keyboardLayout))
        
        if sshAddress != "" {
            self.stateKeeper.sshTunnelingStarted = false
            Background {
                self.stateKeeper.sshForwardingLock.unlock()
                self.stateKeeper.sshForwardingLock.lock()
                self.stateKeeper.sshTunnelingStarted = true
                log_callback_str(message: "Setting up SSH forwarding")
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
                    UnsafeMutablePointer<Int8>(mutating: (address as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (port as NSString).utf8String))
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
                    self.cl = initializeSpiceVv(Int32(self.instance), update_callback,
                                              resize_callback, failure_callback_swift,
                           log_callback, yes_no_dialog_callback,
                           UnsafeMutablePointer<Int8>(mutating: (consoleFile as NSString).utf8String),
                           true)
                } else {
                    log_callback_str(message: "\(#function): Connecting with selected connection parameters")
                    self.cl = initializeSpice(Int32(self.instance), update_callback,
                                              resize_callback, failure_callback_swift,
                           log_callback, yes_no_dialog_callback,
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
    
    func getButtonState(firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                        scrollUp: Bool, scrollDown: Bool) -> Int {
        var newButtonState: Int = 0
        if firstDown {
            newButtonState |= Int(SPICE_MOUSE_BUTTON_MASK_LEFT.rawValue)
        } else {
            newButtonState &= ~Int(SPICE_MOUSE_BUTTON_MASK_LEFT.rawValue)
        }
        if secondDown {
            newButtonState |= Int(SPICE_MOUSE_BUTTON_MASK_MIDDLE.rawValue)
        } else {
            newButtonState &= ~Int(SPICE_MOUSE_BUTTON_MASK_MIDDLE.rawValue)
        }
        if thirdDown {
            newButtonState |= Int(SPICE_MOUSE_BUTTON_MASK_RIGHT.rawValue)
        } else {
            newButtonState &= ~Int(SPICE_MOUSE_BUTTON_MASK_RIGHT.rawValue)
        }
        /*
        if scrollUp {
            newButtonState |= SpiceSession.SPICE_MOUSE_BUTTON_UP
        } else {
            newButtonState &= ~SpiceSession.SPICE_MOUSE_BUTTON_UP
        }
        if scrollDown {
            newButtonState |= SpiceSession.SPICE_MOUSE_BUTTON_DOWN
        } else {
            newButtonState &= ~SpiceSession.SPICE_MOUSE_BUTTON_DOWN
        }*/
        return newButtonState
    }
    
    func updateCurrentState(buttonId: Int, isDown: Bool) -> Bool {
        let currentState = buttonStateMap[buttonId]
        buttonStateMap[buttonId] = isDown
        return currentState != isDown
    }
    
    override func pointerEvent(totalX: Float, totalY: Float, x: Float, y: Float,
                               firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                               scrollUp: Bool, scrollDown: Bool) {
        let remoteX = Float(globalStateKeeper!.fbW) * x / totalX
        let remoteY = Float(globalStateKeeper!.fbH) * y / totalY
        
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

        let buttonState = getButtonState(firstDown: firstDown,
                                          secondDown: secondDown,
                                          thirdDown: thirdDown,
                                          scrollUp: scrollUp,
                                          scrollDown: scrollDown)
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

        print(message, "x:", remoteX, "y:", remoteY, "buttonId:", buttonId, "buttonState:", buttonState, "isDown:", isDown)
        sendPointerEvent(Int32(remoteX), Int32(remoteY),
                         Int32(buttonId),
                         Int32(buttonState),
                         Int32(stateChanged),
                         Int32(isDown))
    }
    
    func getScanCodes(key: Int32) -> [Int] {
        //print("sendSpecialKeyByXKeySym, key:", key)
        let char = (specialXKeySymToUnicodeMap[key] ?? 0) | SpiceSession.UNICODE_MASK
        //print("sendSpecialKeyByXKeySym, char", char)
        let scanCodes = self.layoutMap[char] ?? []
        //print("sendSpecialKeyByXKeySym, scancodes", scanCodes)
        return scanCodes
    }
    
    override func keyEvent(char: Unicode.Scalar) {
        let char = String(char.value)
        let scanCodes = self.layoutMap[Int(char)! | SpiceSession.UNICODE_MASK] ?? []
        //print("Unicode:", char, "converted to:", scanCodes)
        for scanCode in scanCodes {
            //Background {
                var scode = scanCode
                if scanCode & SpiceSession.SCANCODE_SHIFT_MASK != 0 {
                    //print("Found SCANCODE_SHIFT_MASK, sending Shift down")
                    SpiceGlibGlue_SpiceKeyEvent(1, Int32(SpiceSession.LSHIFT))
                    scode &= ~SpiceSession.SCANCODE_SHIFT_MASK
                }
                if scanCode & SpiceSession.SCANCODE_ALTGR_MASK != 0 {
                    //print("Found SCANCODE_ALTGR_MASK, sending AltGr down")
                    SpiceGlibGlue_SpiceKeyEvent(1, Int32(SpiceSession.RALT))
                    scode &= ~SpiceSession.SCANCODE_ALTGR_MASK
                }
                
                SpiceGlibGlue_SpiceKeyEvent(1, Int32(scode))
                SpiceGlibGlue_SpiceKeyEvent(0, Int32(scode))
                
                if scanCode & SpiceSession.SCANCODE_SHIFT_MASK != 0 {
                    //print("Found SCANCODE_SHIFT_MASK, sending Shift up")
                    SpiceGlibGlue_SpiceKeyEvent(0, Int32(SpiceSession.LSHIFT))
                }
                if scanCode & SpiceSession.SCANCODE_ALTGR_MASK != 0 {
                    //print("Found SCANCODE_ALTGR_MASK, sending AltGr up")
                    SpiceGlibGlue_SpiceKeyEvent(0, Int32(SpiceSession.RALT))
                }
            //}
        }
    }
    
    @objc override func sendModifierIfNotDown(modifier: Int32) {
        let scode = xKeySymToScanCode[modifier] ?? 0
        if scode != 0 && !self.stateKeeper.modifiers[modifier]! {
            self.stateKeeper.modifiers[modifier] = true
            //print("SpiceSession: Sending modifier scancode", scode)
            SpiceGlibGlue_SpiceKeyEvent(1, Int32(scode))
        }
    }

    @objc override func releaseModifierIfDown(modifier: Int32) {
        let scode = xKeySymToScanCode[modifier] ?? 0
        if scode != 0 && self.stateKeeper.modifiers[modifier]! {
            self.stateKeeper.modifiers[modifier] = false
            //print("SpiceSession: Releasing modifier scancode", scode)
            SpiceGlibGlue_SpiceKeyEvent(0, Int32(scode))
        }
    }
    
    @objc override func sendSpecialKeyByXKeySym(key: Int32) {
        let scanCodes = getScanCodes(key: key)
        for scanCode in scanCodes {
            //Background {
                SpiceGlibGlue_SpiceKeyEvent(1, Int32(scanCode))
                SpiceGlibGlue_SpiceKeyEvent(0, Int32(scanCode))
            //}
        }
    }
    
    @objc override func sendUniDirectionalSpecialKeyByXKeySym(key: Int32, down: Bool) {
        let scanCodes = getScanCodes(key: key)
        let d: Int16 = down ? 1 : 0
        for scanCode in scanCodes {
            //Background {
                SpiceGlibGlue_SpiceKeyEvent(d, Int32(scanCode))
            //}
        }
    }

    @objc override func sendScreenUpdateRequest(wholeScreen: Bool) {
        // Not used for SPICE
    }
}
