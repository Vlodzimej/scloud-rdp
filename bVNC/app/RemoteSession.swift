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

@discardableResult
public func synchronized<T>(_ lock: AnyObject, closure:() -> T) -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }

    return closure()
}

func Background(_ block: @escaping ()->Void) {
    DispatchQueue.global(qos: .userInteractive).async(execute: block)
}

func BackgroundLowPrio(_ block: @escaping ()->Void) {
    DispatchQueue.global(qos: .background).async(execute: block)
}

func UserInterface(_ block: @escaping ()->Void) {
    DispatchQueue.main.async(execute: block)
}

var lastUpdate: Double = 0.0
var isDrawing: Bool = false
var buttonStateMap: [Int: Bool] = [:]

func lock_write_tls_callback_swift(instance: Int32) -> Void {
    if (instance != globalStateKeeper!.currInst) {
        log_callback_str(message: "Current inst \(globalStateKeeper!.currInst) discarding lock_write_tls_callback_swift, inst \(instance)")
        return
    }
    globalStateKeeper?.globalWriteTlsLock.lock();
}

func unlock_write_tls_callback_swift(instance: Int32) -> Void {
    if (instance != globalStateKeeper!.currInst) {
        log_callback_str(message: "Current inst \(globalStateKeeper!.currInst) discarding unlock_write_tls_callback_swift, inst \(instance)")
        return
    }
    globalStateKeeper?.globalWriteTlsLock.unlock();
}

func ssh_forward_success() -> Void {
    log_callback_str(message: "SSH library is telling us we can proceed with the VNC connection")
    globalStateKeeper?.sshForwardingStatus = true
    globalStateKeeper?.sshForwardingLock.unlock()
}

func ssh_forward_failure() -> Void {
    log_callback_str(message: "SSH library is telling us it failed to set up SSH forwarding")
    globalStateKeeper?.sshForwardingStatus = false
    globalStateKeeper?.sshForwardingLock.unlock()
}

func failure_callback_str(instance: Int, title: String?, errorPage: String = "dismissableErrorMessage") {
    if (instance != globalStateKeeper!.currInst) {
        log_callback_str(message: "Current inst \(globalStateKeeper!.currInst) discarding failure_callback_str, inst \(instance)")
        return
    }
    
    let wasDrawing = globalStateKeeper?.isDrawing ?? false
    globalStateKeeper?.isDrawing = false
    globalStateKeeper?.imageView?.disableTouch()

    UserInterface {
        globalStateKeeper?.scheduleDisconnectTimer(interval: 0, wasDrawing: wasDrawing)
        if title != nil {
            log_callback_str(message: "Connection failure, showing error with title \(title!).")
            globalStateKeeper?.showError(title: LocalizedStringKey(title!), errorPage: errorPage)
        } else {
            log_callback_str(message: "Successful exit, no error was reported.")
            globalStateKeeper?.showConnections()
        }
    }
}

func failure_callback_swift(instance: Int32, message: UnsafeMutablePointer<UInt8>?) -> Void {
    if (instance != globalStateKeeper!.currInst) {
        log_callback_str(message: "Current inst \(globalStateKeeper!.currInst) discarding failure_callback_swift, inst \(instance)")
        return
    }
    let message_str = String(cString: message!)
    if message_str.contains("SSH_PASSWORD_AUTHENTICATION_FAILED_TITLE") {
        log_callback_str(message: "Detected SSH authentication failure, requesting SSH credentials")
        globalStateKeeper?.requestSshCredentials()
    } else if message_str.contains("AUTHENTICATION_FAILED_TITLE") {
        log_callback_str(message: "Detected authentication failure, requesting credentials")
        globalStateKeeper?.requestCredentials()
    } else if message != nil {
        log_callback_str(message: "Will show error dialog with title: \(String(cString: message!))")
        failure_callback_str(instance: Int(instance), title: String(cString: message!))
    } else {
        log_callback_str(message: "Will not show error dialog")
        failure_callback_str(instance: Int(instance), title: nil)
    }
}

func utf_decoding_clipboard_callback(clipboard: UnsafeMutablePointer<UInt8>?, size: Int) -> Void {
    log_callback_str(message: "utf_decoding_clipboard_callback")
    let string = String(cString: clipboard!)
    let clipboardContents = string.utf8DecodedString() ?? try_converting_utf_codepoints(clipboard: clipboard, size: size)
    UIPasteboard.general.string = clipboardContents
}

func clipboard_callback(clipboard: UnsafeMutablePointer<CChar>?) -> Void {
    log_callback_str(message: "clipboard_callback")
    let clipboardContents = String(cString: clipboard!)
    UIPasteboard.general.string = clipboardContents
}

func try_converting_utf_codepoints(clipboard: UnsafeMutablePointer<UInt8>?, size: Int) -> String? {
    log_callback_str(message: "try_converting_utf_codepoints")
    let a = UnsafeMutableBufferPointer(start: clipboard, count: Int(size))
    let byteArray: [UInt8] = Array(a)
    let unicodeScalars = byteArray.compactMap(Unicode.Scalar.init)
    let result = String(String.UnicodeScalarView(unicodeScalars))
    return result
}

func utf8_clipboard_callback(clipboard: UnsafeMutablePointer<UInt8>?, size: Int) -> Void {
    log_callback_str(message: "utf8_clipboard_callback")
    var clipboardContents = String(validatingUTF8: cast_uint8_to_cchar(clipboard!))
    if clipboardContents == nil {
        clipboardContents = try_converting_utf_codepoints(clipboard: clipboard, size: size)
    }
    UIPasteboard.general.string = clipboardContents
}


func log_callback(message: UnsafeMutablePointer<Int8>?) -> Void {
    let messageStr = String(cString: message!)
    log_callback_str(message: messageStr)
}

func log_callback_str(message: String) -> Void {
    UserInterface {
        print(message)
    }
    globalStateKeeper?.logLock.lock()
    if globalStateKeeper?.clientLog.count ?? 0 > 500 {
        globalStateKeeper?.clientLog.remove(at: 0)
    }
    globalStateKeeper?.clientLog.append(message + "\n")
    globalStateKeeper?.logLock.unlock()
}

func yes_no_dialog_callback(instance: Int32, title: UnsafeMutablePointer<Int8>?, message: UnsafeMutablePointer<Int8>?,
                            fingerPrint1: UnsafeMutablePointer<Int8>?, fingerPrint2: UnsafeMutablePointer<Int8>?,
                            type: UnsafeMutablePointer<Int8>?, valid: Int32) -> Int32 {
    if (instance != globalStateKeeper!.currInst) {
        log_callback_str(message: "Current inst \(globalStateKeeper!.currInst) discarding yes_no_dialog_callback, inst \(instance)")
        return 0
    }

    if (instance != globalStateKeeper!.currInst) { return 0 }

    let fingerprintType = String(cString: type!)
    let fingerPrint1Str = String(cString: fingerPrint1!)
    let fingerPrint2Str = String(cString: fingerPrint2!)
    
    // Check for a match
    if fingerprintType == "SSH" &&
        fingerPrint1Str == globalStateKeeper?.connections.selectedConnection["sshFingerprintSha256"] {
        print ("Found matching saved SHA256 SSH host key fingerprint, continuing.")
        return 1
    } else if fingerprintType == "X509" &&
       fingerPrint1Str == globalStateKeeper?.connections.selectedConnection["x509FingerprintSha256"] &&
       fingerPrint2Str == globalStateKeeper?.connections.selectedConnection["x509FingerprintSha512"] {
       print ("Found matching saved SHA256 and SHA512 X509 key fingerprints, continuing.")
       return 1
    }
    print ("Asking user to verify fingerprints \(String(cString: fingerPrint1!)) and \(String(cString: fingerPrint2!)) of type \(String(cString: type!))")

    let titleStr = LocalizedStringKey(String(cString: title!))
    var messages: [ LocalizedStringKey ] = []
    let additionalMessageStr = String(cString: message!)

    // Output the right message depending on key type
    if fingerprintType == "SSH" {
        messages.append("SSH_KEY_VERIFY_TEXT")
    } else if fingerprintType == "X509"  {
        messages.append("X509_KEY_VERIFY_TEXT")
        if valid == 0 {
            messages.append("X509_KEY_EXPIRED_TEXT")
        } else {
            messages.append("X509_KEY_NOT_EXPIRED_TEXT")
        }
    }

    // Check for a mismatch if keys were already set
    if fingerprintType == "SSH" &&
        globalStateKeeper?.connections.selectedConnection["sshFingerprintSha256"] != nil {
        messages.append("WARNING_SSH_KEY_CHANGED_TEXT")
    } else if fingerprintType == "X509" &&
       (globalStateKeeper?.connections.selectedConnection["x509FingerprintSha256"] != nil ||
        globalStateKeeper?.connections.selectedConnection["x509FingerprintSha512"] != nil) {
        messages.append("WARNING_X509_KEY_CHANGED_TEXT")
    }

    let res = globalStateKeeper?.yesNoResponseRequired(
        title: titleStr, messages: messages, nonLocalizedMessage: additionalMessageStr) ?? 0
    
    if res == 1 && fingerprintType == "SSH" {
        globalStateKeeper?.setFieldOfCurrentConnection(field: "sshFingerprintSha256", value: fingerPrint1Str)
    } else if res == 1 && fingerprintType == "X509" {
        globalStateKeeper?.setFieldOfCurrentConnection(field: "x509FingerprintSha256", value: fingerPrint1Str)
        globalStateKeeper?.setFieldOfCurrentConnection(field: "x509FingerprintSha512", value: fingerPrint2Str)
    }
    return res
}

/**
 *
 * @return The smallest scale supported by the implementation; the scale at which
 * the bitmap would be smaller than the screen
 */
func getMinimumScale(fbW: CGFloat, fbH: CGFloat) -> CGFloat {
    return min(globalWindow!.bounds.maxX / fbW, globalWindow!.bounds.maxY / fbH);
}

func widthRatioLessThanHeightRatio(fbW: CGFloat, fbH: CGFloat) -> Bool {
    return globalWindow!.bounds.maxX / fbW < globalWindow!.bounds.maxY / fbH;
}

func resize_callback(instance: Int32, fbW: Int32, fbH: Int32) -> Void {
    if (instance != globalStateKeeper!.currInst) {
        log_callback_str(message: "Current inst \(globalStateKeeper!.currInst) discarding resize_callback, inst \(instance)")
        return
    }

    globalStateKeeper?.remoteResized(fbW: fbW, fbH: fbH)
}

func update_callback(instance: Int32, data: UnsafeMutablePointer<UInt8>?, fbW: Int32, fbH: Int32, x: Int32, y: Int32, w: Int32, h: Int32) -> Bool {
    if (instance != globalStateKeeper!.currInst) {
        log_callback_str(message: "Current inst \(globalStateKeeper!.currInst) discarding update_callback, inst \(instance)")
        return false
    }
    if (!(globalStateKeeper?.isDrawing ?? false)) {
        log_callback_str(message: "Not drawing, discard update.")
        return false
    }
    
    let timeNow = CACurrentMediaTime()
    if (timeNow - lastUpdate < 0.032) {
        //print("Last frame drawn less than 50ms ago, discarding frame, scheduling redraw")
        globalStateKeeper?.rescheduleReDrawTimer(data: data, fbW: fbW, fbH: fbH)
    } else {
        //print("Drawing a frame normally.")
        globalStateKeeper?.draw(data: data, fbW: fbW, fbH: fbH)
        lastUpdate = CACurrentMediaTime()
    }
    return true
}

class RemoteSession {
    let stateKeeper: StateKeeper
    var instance: Int
    var width: Int
    var height: Int
    var cl: UnsafeMutableRawPointer?
    
    class var LCONTROL: Int { return 29 }
    class var RCONTROL: Int { return 285 }
    class var LALT: Int { return 56 }
    class var RALT: Int { return 312 }
    class var LSHIFT: Int { return 42 }
    class var RSHIFT: Int { return 54 }
    class var LWIN: Int { return 347 }
    class var RWIN: Int { return 348 }
    class var PAGE_UP: Int { return 73 }
    class var PAGE_DOWN: Int { return 81 }
    class var HOME: Int { return 327 }
    class var END: Int { return 335 }
    class var DEL: Int { return 83 }

    var layoutMap: [Int: [Int]] = [:]
    class var UNICODE_MASK: Int { return 0x100000 }
    class var SCANCODE_SHIFT_MASK: Int { return 0x10000 }
    class var SCANCODE_ALTGR_MASK: Int { return 0x20000 }
    class var SCANCODE_CIRCUMFLEX_MASK: Int { return 0x40000 }
    class var SCANCODE_DIAERESIS_MASK: Int { return 0x80000 }

    var specialXKeySymToLayoutMapKey: [Int32: Int] = [
        XK_F1: 0xF704 | RemoteSession.UNICODE_MASK,
        XK_F2: 0xF705 | RemoteSession.UNICODE_MASK,
        XK_F3: 0xF706 | RemoteSession.UNICODE_MASK,
        XK_F4: 0xF707 | RemoteSession.UNICODE_MASK,
        XK_F5: 0xF708 | RemoteSession.UNICODE_MASK,
        XK_F6: 0xF709 | RemoteSession.UNICODE_MASK,
        XK_F7: 0xF70A | RemoteSession.UNICODE_MASK,
        XK_F8: 0xF70B | RemoteSession.UNICODE_MASK,
        XK_F9: 0xF70C | RemoteSession.UNICODE_MASK,
        XK_F10: 0xF70D | RemoteSession.UNICODE_MASK,
        XK_F11: 0xF70E | RemoteSession.UNICODE_MASK,
        XK_F12: 0xF70F | RemoteSession.UNICODE_MASK,
        XK_Escape: 0x001B | RemoteSession.UNICODE_MASK,
        XK_Tab: 0x0009 | RemoteSession.UNICODE_MASK,
        XK_Home: 0x21F1 | RemoteSession.UNICODE_MASK,
        XK_End: 0x21F2 | RemoteSession.UNICODE_MASK,
        XK_Page_Up: 0x21DE | RemoteSession.UNICODE_MASK,
        XK_Page_Down: 0x21DF | RemoteSession.UNICODE_MASK,
        XK_Up: 19,
        XK_Down: 20,
        XK_Left: 21,
        XK_Right: 22,
        XK_BackSpace: 0x0008 | RemoteSession.UNICODE_MASK,
    ]
    
    var xKeySymToScanCode: [Int32: Int] = [
        XK_Super_L: RemoteSession.LWIN,
        XK_Super_R: RemoteSession.RWIN,
        XK_Control_L: RemoteSession.LCONTROL,
        XK_Control_R: RemoteSession.RCONTROL,
        XK_Alt_L: RemoteSession.LALT,
        XK_Alt_R: RemoteSession.RALT,
        XK_Shift_L: RemoteSession.LSHIFT,
        XK_Shift_R: RemoteSession.RSHIFT,
        XK_Page_Up: RemoteSession.PAGE_UP,
        XK_Page_Down: RemoteSession.PAGE_DOWN,
        XK_Home: RemoteSession.HOME,
        XK_End: RemoteSession.END,
        XK_Delete: RemoteSession.DEL
    ]
    
    init(instance: Int, stateKeeper: StateKeeper) {
        log_callback_str(message: "Initializing Remote Session instance: \(instance)")
        self.instance = instance
        self.stateKeeper = stateKeeper
        self.width = 0
        self.height = 0
        self.cl = nil

        let res = self.resolution()
        self.width = res[0]
        self.height = res[1]
    }
    
    func resolution() -> [Int] {
        let screenWidth = (globalWindow?.frame.size.width ?? 0)
        let screenHeight = (globalWindow?.frame.size.height ?? 0)
        log_callback_str(message: "Device reports screen resolution \(screenWidth)x\(screenHeight)")
        
        var newScreenWidth = screenWidth
        var newScreenHeight = screenHeight
        
        if self.stateKeeper.macOs {
            #if targetEnvironment(macCatalyst)
            globalWindow?.windowScene?.titlebar?.titleVisibility = .hidden
            #endif
        } else {
            log_callback_str(message: "Device reports screen resolution \(screenWidth)x\(screenHeight)")
            if (screenWidth > Constants.MAX_RESOLUTION_FOR_AUTO_SCALE_UP_IOS ||
                screenHeight > Constants.MAX_RESOLUTION_FOR_AUTO_SCALE_UP_IOS) {
                log_callback_str(message: "Not scaling resolution up. At least one side is > \(Constants.MAX_RESOLUTION_FOR_AUTO_SCALE_UP_IOS)")
            } else {
                // If width or height are too small, scale dimensions up when requesting remote resolution
                newScreenWidth = screenWidth * Constants.MIN_RESOLUTION_SCALE_UP_FACTOR
                newScreenHeight = screenHeight * Constants.MIN_RESOLUTION_SCALE_UP_FACTOR
                log_callback_str(message: "Automatically scaled iOS resolution up to \(newScreenWidth)x\(newScreenHeight)")
            }
        }
        return [Int(newScreenWidth), Int(newScreenHeight)]
    }
    
    func updateCurrentState(buttonId: Int, isDown: Bool) -> Bool {
        let currentState = buttonStateMap[buttonId]
        buttonStateMap[buttonId] = isDown
        return currentState != isDown
    }
    
    func getScanCodesOrSendKeyIfUnicode(key: Int32) -> [Int] {
        var scanCodes: [Int] = []
        let modifierScanCode = xKeySymToScanCode[key] ?? 0
        if (modifierScanCode > 0) {
            scanCodes = [modifierScanCode]
            print("getScanCodesOrSendKeyIfUnicode, modifier scancodes", scanCodes)
        } else {
            print("getScanCodesOrSendKeyIfUnicode, key:", key)
            let layoutMapKey = specialXKeySymToLayoutMapKey[key] ?? 0
            print("getScanCodesOrSendKeyIfUnicode, char:", layoutMapKey)
            sendUnicodeKeyEvent(char: layoutMapKey)
            scanCodes = []
        }
        return scanCodes
    }
    
    func syncRemoteToLocalResolution() {
        let res = self.resolution()
        self.width = res[0]
        self.height = res[1]
        requestRemoteResolution(x: self.width, y: self.height)
    }
    
    func requestRemoteResolution(x: Int, y: Int) {
        preconditionFailure("This method must be overridden")
    }
    
    func connect(currentConnection: [String:String]) {
        preconditionFailure("This method must be overridden") 
    }
    
    func disconnect() {
        preconditionFailure("This method must be overridden")
    }

    func pointerEvent(totalX: Float, totalY: Float, x: Float, y: Float,
                      firstDown: Bool, secondDown: Bool, thirdDown: Bool,
                      scrollUp: Bool, scrollDown: Bool) {
        preconditionFailure("This method must be overridden")
    }
    
    func sendUnicodeKeyEvent(char: Int) {
        preconditionFailure("This method must be overridden")
    }
    
    func keyEvent(char: Unicode.Scalar) {
        preconditionFailure("This method must be overridden")
    }
    
    @objc func sendModifier(modifier: Int32, down: Bool) {
        preconditionFailure("This method must be overridden")
    }
    
    @objc func sendSpecialKeyByXKeySym(key: Int32) {
        preconditionFailure("This method must be overridden")
    }
    
    @objc func sendUniDirectionalSpecialKeyByXKeySym(key: Int32, down: Bool) {
        preconditionFailure("This method must be overridden")
    }
    
    @objc func sendScreenUpdateRequest(incrementalUpdate: Bool) {
        preconditionFailure("This method must be overridden")
    }
    
    func getScanCodesForKeyCodeChar(char: Int)-> [Int] {
        let scanCodes = self.layoutMap[char] ?? []
        print("getScanCodesForKeyCodeChar: \(char) looked up to scanCodes: \(scanCodes)")
        return scanCodes
    }
    
    func clientCutTextInSession(clientClipboardContents: String?) {
        guard (self.stateKeeper.getCurrentInstance()) != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        let clipboardStr = clientClipboardContents ?? ""
        let clientClipboardContentsPtr = UnsafeMutablePointer<Int8>(mutating: (clipboardStr as NSString).utf8String)
        let length = clipboardStr.lengthOfBytes(using: .utf8)
        clientCutText(stateKeeper.getCurrentInstance(), clientClipboardContentsPtr, Int32(length))
    }
}
