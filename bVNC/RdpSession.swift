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
    
    class var PTRFLAGS_WHEEL: Int32 { return 0x0200 }
    class var PTRFLAGS_WHEEL_NEGATIVE: Int32 { return 0x0100 }
    class var PTRFLAGS_DOWN: Int32 { return 0x8000 }
    
    class var MOUSE_BUTTON_NONE: Int32 { return 0x0000 }
    class var MOUSE_BUTTON_MOVE: Int32 { return 0x0800 }
    class var MOUSE_BUTTON_LEFT: Int32 { return 0x1000 }
    class var MOUSE_BUTTON_RIGHT: Int32 { return 0x2000 }
    
    class var MOUSE_BUTTON_MIDDLE: Int32 { return 0x4000 }
    class var MOUSE_BUTTON_SCROLL_UP: Int32 { return PTRFLAGS_WHEEL|0x0078 }
    class var MOUSE_BUTTON_SCROLL_DOWN: Int32 { return PTRFLAGS_WHEEL|PTRFLAGS_WHEEL_NEGATIVE|0x0088 }
    
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
        // FIXME: Handle different pointer events properly.
        // FIXME: Send modifier keys when appropriate.
        cursorEvent(self.cl, Int32(x), Int32(y), RdpSession.MOUSE_BUTTON_MOVE|RdpSession.PTRFLAGS_DOWN)
    }
    
    override func keyEvent(char: Unicode.Scalar) {
        // FIXME: Send key events mapped to vkcodes
        // FIXME: If send unicode setting is enabled, send unicode instead
        let char = String(char.value)
        let unicodeInt = Int(char)!
        unicodeKeyEvent(self.cl, 0, Int32(unicodeInt))
   }
    
    @objc override func sendModifierIfNotDown(modifier: Int32) {
        // FIXME: Implement
    }

    @objc override func releaseModifierIfDown(modifier: Int32) {
        // FIXME: Implement
    }
    
    @objc override func sendSpecialKeyByXKeySym(key: Int32) {

    }
    
    @objc override func sendUniDirectionalSpecialKeyByXKeySym(key: Int32, down: Bool) {

    }
    
    @objc override func sendScreenUpdateRequest(incrementalUpdate: Bool) {
        // Not used for RDP
    }
}
