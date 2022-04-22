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
    override class var RALT: Int { return 0xA5 }
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
    var preferSendingUnicode = true
    
    var xKeySymToProtocolCode: [Int32: Int] = [
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
    
    override func connect(currentConnection: [String:String]) {
        let sshAddress = currentConnection["sshAddress"] ?? ""
        let sshPort = currentConnection["sshPort"] ?? ""
        let sshUser = currentConnection["sshUser"] ?? ""
        let sshPass = currentConnection["sshPass"] ?? ""
        let port = currentConnection["port"] ?? ""
        let address = currentConnection["address"] ?? ""
        let sshPassphrase = currentConnection["sshPassphrase"] ?? ""
        let sshPrivateKey = currentConnection["sshPrivateKey"] ?? ""

        let sshForwardPort = String(arc4random_uniform(30000) + 30000)
        
        var addressAndPort = address + ":" + port

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
            addressAndPort = "127.0.0.1" + ":" + sshForwardPort
        }
        
        let user = currentConnection["username"] ?? ""
        let pass = currentConnection["password"] ?? ""
        // TODO: Write out CA to a file if keeping it
        //let cert = currentConnection["cert"] ?? ""

        Background {
            // Make it highly probable the SSH thread would obtain the lock before the RDP one does.
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
                log_callback_str(message: "Connecting RDP Session in the background...")
                log_callback_str(message: "RDP Session width: \(self.width), height: \(self.height)")
                
                self.cl = initializeRdp(Int32(self.instance),
                                        Int32(self.width), Int32(self.height),
                                        update_callback,
                                        resize_callback,
                                        failure_callback_swift,
                                        log_callback,
                                        yes_no_dialog_callback,
                                        UnsafeMutablePointer<Int8>(mutating: (address as NSString).utf8String),
                                        UnsafeMutablePointer<Int8>(mutating: (port as NSString).utf8String),
                                        UnsafeMutablePointer<Int8>(mutating: (user as NSString).utf8String),
                                        UnsafeMutablePointer<Int8>(mutating: (pass as NSString).utf8String),
                                        true)
            }
            if self.cl != nil {
                self.stateKeeper.cl[self.stateKeeper.currInst] = self.cl
                connectRdpInstance(self.cl)
            } else {
                // FIXME: Show RDP failure when a failure callback is called, not when
                // FIXME: Initialization failed.
                title = "RDP_CONNECTION_FAILURE_TITLE"
                failure_callback_str(instance: self.instance, title: title)
            }
        }
    }
        
    override func disconnect() {
        Background {
            disconnectRdp(self.cl)
        }
    }
    
    override func pointerEvent(totalX: Float, totalY: Float, x: Float, y: Float,
                               firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                               scrollUp: Bool, scrollDown: Bool) {
        // TODO: Try implementing composite button support.
        
        let remoteX = Float(self.stateKeeper.fbW) * x / totalX
        let remoteY = Float(self.stateKeeper.fbH) * y / totalY
        
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
        
        var message = "Motion event"
        if firstStateChanged {
            message = "Left button"
            buttonId = RdpSession.MOUSE_BUTTON_LEFT
            if (firstDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if secondStateChanged {
            message = "Middle button"
            buttonId = RdpSession.MOUSE_BUTTON_MIDDLE
            if (secondDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if thirdStateChanged {
            message = "Right button"
            buttonId = RdpSession.MOUSE_BUTTON_RIGHT
            if (thirdDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if scrollUpStateChanged {
            message = "ScrollUp action"
            buttonId = RdpSession.MOUSE_BUTTON_SCROLL_UP
            if (scrollUp) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }
        if scrollDownStateChanged {
            message = "ScrollDown action"
            buttonId = RdpSession.MOUSE_BUTTON_SCROLL_DOWN
            if (scrollDown) {
                buttonId |= RdpSession.PTRFLAGS_DOWN
            }
        }

        print(message, "x:", remoteX, "y:", remoteY, "buttonId:", buttonId)
        
        // FIXME: Send modifier keys when appropriate.
        cursorEvent(self.cl, Int32(remoteX), Int32(remoteY), Int32(buttonId))

    }
    
    override func keyEvent(char: Unicode.Scalar) {
        // FIXME: Send unicode only if a preferSendingUnicode setting is enabled
        // FIXME: Implement support for sending key events mapped to vkcodes
        if (preferSendingUnicode) {
            let char = String(char.value)
            let unicodeInt = Int(char)!
            unicodeKeyEvent(self.cl, 0, Int32(unicodeInt))
        } else {
            log_callback_str(message: "Sending virtual keycodes not supported yet")
        }
        
   }
    
    @objc override func sendModifierIfNotDown(modifier: Int32) {
        let code = xKeySymToProtocolCode[modifier] ?? 0
        if code != 0 && !self.stateKeeper.modifiers[modifier]! {
            self.stateKeeper.modifiers[modifier] = true
            let scode = GetVirtualScanCodeFromVirtualKeyCode(DWORD(code), 4) & 0xFF
            var keyFlags = RdpSession.KBD_FLAGS_DOWN
            keyFlags |= ((Int(scode) & RdpSession.KBD_FLAGS_EXTENDED) != 0) ? RdpSession.KBD_FLAGS_EXTENDED : 0
            print("RdpSession: sendModifierIfNotDown: ", scode)
            vkKeyEvent(self.cl, Int32(keyFlags), Int32(scode))
        }
    }

    @objc override func releaseModifierIfDown(modifier: Int32) {
        let code = xKeySymToProtocolCode[modifier] ?? 0
        if code != 0 && self.stateKeeper.modifiers[modifier]! {
            self.stateKeeper.modifiers[modifier] = false
            let scode = GetVirtualScanCodeFromVirtualKeyCode(DWORD(code), 4) & 0xFF
            var keyFlags = RdpSession.KBD_FLAGS_RELEASE
            keyFlags |= ((Int(scode) & RdpSession.KBD_FLAGS_EXTENDED) != 0) ? RdpSession.KBD_FLAGS_EXTENDED : 0
            print("RdpSession: releaseModifierIfDown: ", scode)
            vkKeyEvent(self.cl, Int32(keyFlags), Int32(scode))
        }
    }
    
    @objc override func sendSpecialKeyByXKeySym(key: Int32) {
        let code = xKeySymToProtocolCode[key] ?? 0
        if code != 0 {
            let scode = GetVirtualScanCodeFromVirtualKeyCode(DWORD(code), 4) & 0xFF
            let keyFlags = ((Int(scode) & RdpSession.KBD_FLAGS_EXTENDED) != 0) ? RdpSession.KBD_FLAGS_EXTENDED : 0
            print("RdpSession: sendSpecialKeyByXKeySym: ", scode)
            vkKeyEvent(self.cl, Int32(keyFlags|RdpSession.KBD_FLAGS_DOWN), Int32(scode))
            vkKeyEvent(self.cl, Int32(keyFlags|RdpSession.KBD_FLAGS_RELEASE), Int32(scode))
        }
    }
    
    @objc override func sendUniDirectionalSpecialKeyByXKeySym(key: Int32, down: Bool) {
        let code = xKeySymToProtocolCode[key] ?? 0
        if code != 0 {
            let scode = GetVirtualScanCodeFromVirtualKeyCode(DWORD(code), 4) & 0xFF
            var keyFlags = ((Int(scode) & RdpSession.KBD_FLAGS_EXTENDED) != 0) ? RdpSession.KBD_FLAGS_EXTENDED : 0
            if down {
                keyFlags |= RdpSession.KBD_FLAGS_DOWN
            } else {
                keyFlags |= RdpSession.KBD_FLAGS_RELEASE
            }
            vkKeyEvent(self.cl, Int32(keyFlags), Int32(scode))
        }
    }
    
    @objc override func sendScreenUpdateRequest(incrementalUpdate: Bool) {
        // Not used for RDP
    }
}
