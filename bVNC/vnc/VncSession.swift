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


class VncSession: RemoteSession {
    
    fileprivate func startVncSessionOnBackgroundThread() {        
        Background {
            // Make it highly probable the SSH thread would obtain the lock before the VNC one does.
            self.stateKeeper.yesNoDialogLock.unlock()
            var title = ""
            var continueConnecting = true
            self.determineSshTunnelingStatusIfEnabled(sshAddress: self.sshAddress, &continueConnecting, &title)
            if continueConnecting {
                let addressAndPort = self.address + ":" + self.port
                log_callback_str(message: "Connecting VNC Session to \(addressAndPort)")
                self.cl = initializeVnc(
                    Int32(self.instance),
                    update_callback,
                    resize_callback,
                    failure_callback_swift,
                    log_callback,
                    utf_decoding_clipboard_callback,
                    lock_write_tls_callback_swift,
                    unlock_write_tls_callback_swift,
                    yes_no_dialog_callback,
                    UnsafeMutablePointer<Int8>(mutating: (addressAndPort as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (self.user as NSString).utf8String),
                    UnsafeMutablePointer<Int8>(mutating: (self.pass as NSString).utf8String)
                )
                if self.cl != nil {
                    self.stateKeeper.setCurrentInstance(inst: self.cl)
                    connectVnc(self.cl)
                } else if (!self.stateKeeper.requestingCredentials) {
                    title = "VNC_CONNECTION_FAILURE_TITLE"
                    failure_callback_str(instance: self.instance, title: title)
                }
            } else {
                failure_callback_str(instance: self.instance, title: title)
            }
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

        self.sshForwardPort = String(arc4random_uniform(30000) + 30000)
        
        if sshAddress != "" {
            self.stateKeeper.sshTunnelingStarted = false
            let forwardToAddress = self.address
            let forwardToPort = self.port
            self.address = "127.0.0.1"
            self.port = self.sshForwardPort
            startSshForwardingOnBackgroundThread(forwardToAddress, forwardToPort)
        }
        
        self.user = currentConnection["username"] ?? ""
        self.pass = currentConnection["password"] ?? ""
        
        startVncSessionOnBackgroundThread()
        super.connect(currentConnection: currentConnection)
    }
        
    override func disconnect() {
        Background {
            disconnectVnc(self.cl)
        }
        super.disconnect()
    }
    
    override func pointerEvent(remoteX: Float, remoteY: Float,
                               firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                               scrollUp: Bool, scrollDown: Bool) {
        sendPointerEventToServer(self.cl, remoteX, remoteY, firstDown, secondDown, thirdDown, scrollUp, scrollDown)
    }
    
    override func keyEvent(char: Unicode.Scalar) {
        if !sendKeyEventInt(self.cl, Int32(String(char.value))!) {
            sendKeyEvent(self.cl, String(char))
        }
    }
    
    @objc override func sendModifier(modifier: Int32, down: Bool) {
        self.stateKeeper.modifiers[modifier] = down
        log_callback_str(message: "VncSession: sendModifier, scancode: \(modifier), down: \(down)")
        sendUniDirectionalKeyEventWithKeySym(self.cl, modifier, down)
    }
    
    @objc override func sendSpecialKeyByXKeySym(key: Int32) {
        sendKeyEventWithKeySym(self.cl, key)
    }
    
    @objc override func sendUniDirectionalSpecialKeyByXKeySym(key: Int32, down: Bool) {
        Background {
            sendUniDirectionalKeyEventWithKeySym(self.cl, key, down)
        }
    }
    
    @objc override func sendScreenUpdateRequest(incrementalUpdate: Bool) {
        sendWholeScreenUpdateRequest(self.cl, incrementalUpdate)
    }
    
    override func syncRemoteToLocalResolution() {
        // Not used
    }
    
    override func requestRemoteResolution(x: Int, y: Int) {
        self.stateKeeper.reDraw()
    }
}
