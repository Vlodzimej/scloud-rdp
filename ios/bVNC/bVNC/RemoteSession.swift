//
//  RemoteSession.swift
//  bVNC
//
//  Created by iordan iordanov on 2021-03-15.
//  Copyright © 2021 iordan iordanov. All rights reserved.
//

import UIKit
import SwiftUI

func Background(_ block: @escaping ()->Void) {
    DispatchQueue.global(qos: .userInteractive).async(execute: block)
}

func BackgroundLowPrio(_ block: @escaping ()->Void) {
    DispatchQueue.global(qos: .background).async(execute: block)
}

func UserInterface(_ block: @escaping ()->Void) {
    DispatchQueue.main.async(execute: block)
}

var globalContentView: Image?
var globalImageView: TouchEnabledUIImageView?
var lastUpdate: Double = 0.0
var isDrawing: Bool = false

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

func failure_callback_str(instance: Int, title: String?) {
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
            globalStateKeeper?.showError(title: LocalizedStringKey(title!))
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
    
    if message != nil {
        log_callback_str(message: "Will show error dialog with title: \(String(cString: message!))")
        failure_callback_str(instance: Int(instance), title: String(cString: message!))
    } else {
        log_callback_str(message: "Will not show error dialog")
        failure_callback_str(instance: Int(instance), title: nil)
    }
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
       fingerPrint1Str == globalStateKeeper?.selectedConnection["sshFingerprintSha256"] {
        print ("Found matching saved SHA256 SSH host key fingerprint, continuing.")
        return 1
    } else if fingerprintType == "X509" &&
       fingerPrint1Str == globalStateKeeper?.selectedConnection["x509FingerprintSha256"] &&
       fingerPrint2Str == globalStateKeeper?.selectedConnection["x509FingerprintSha512"] {
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
        globalStateKeeper?.selectedConnection["sshFingerprintSha256"] != nil {
        messages.append("WARNING_SSH_KEY_CHANGED_TEXT")
    } else if fingerprintType == "X509" &&
       (globalStateKeeper?.selectedConnection["sshFingerprintSha256"] != nil ||
        globalStateKeeper?.selectedConnection["sshFingerprintSha512"] != nil) {
        messages.append("WARNING_X509_KEY_CHANGED_TEXT")
    }

    let res = globalStateKeeper?.yesNoResponseRequired(
        title: titleStr, messages: messages, nonLocalizedMessage: additionalMessageStr) ?? 0
    
    if res == 1 && fingerprintType == "SSH" {
        globalStateKeeper?.selectedConnection["sshFingerprintSha256"] = fingerPrint1Str
        globalStateKeeper?.saveSettings()
    } else if res == 1 && fingerprintType == "X509" {
        globalStateKeeper?.selectedConnection["x509FingerprintSha256"] = fingerPrint1Str
        globalStateKeeper?.selectedConnection["x509FingerprintSha512"] = fingerPrint2Str
        globalStateKeeper?.saveSettings()
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
    globalStateKeeper?.fbW = fbW
    globalStateKeeper?.fbH = fbH
    UserInterface {
        autoreleasepool {
            globalStateKeeper?.imageView?.removeFromSuperview()
            globalStateKeeper?.imageView?.image = nil
            globalStateKeeper?.imageView = nil
            let minScale = getMinimumScale(fbW: CGFloat(fbW), fbH: CGFloat(fbH))
            globalStateKeeper?.correctTopSpacingForOrientation()
            let leftSpacing = globalStateKeeper?.leftSpacing ?? 0
            let topSpacing = globalStateKeeper?.topSpacing ?? 0
            if globalStateKeeper?.macOs == true {
                log_callback_str(message: "Running on MacOS")
                globalStateKeeper?.imageView = ShortTapDragUIImageView(frame: CGRect(x: leftSpacing, y: topSpacing, width: CGFloat(fbW)*minScale, height: CGFloat(fbH)*minScale), stateKeeper: globalStateKeeper)
            } else {
                log_callback_str(message: "Running on iOS")
                globalStateKeeper?.imageView = LongTapDragUIImageView(frame: CGRect(x: leftSpacing, y: topSpacing, width: CGFloat(fbW)*minScale, height: CGFloat(fbH)*minScale), stateKeeper: globalStateKeeper)
            }
            //globalStateKeeper?.imageView?.backgroundColor = UIColor.gray
            globalStateKeeper?.imageView?.enableGestures()
            globalStateKeeper?.imageView?.enableTouch()
            globalWindow!.addSubview(globalStateKeeper!.imageView!)
            globalStateKeeper?.createAndRepositionButtons()
            if !(globalStateKeeper?.macOs ?? false) {
                globalStateKeeper?.addButtons(buttons: globalStateKeeper?.interfaceButtons ?? [:])
            }
            globalStateKeeper?.showConnectedSession()
        }
    }
    globalStateKeeper?.keepSessionRefreshed()
}

func draw(data: UnsafeMutablePointer<UInt8>?, fbW: Int32, fbH: Int32, x: Int32, y: Int32, w: Int32, h: Int32) {
    UserInterface {
        autoreleasepool {
            globalStateKeeper?.imageView?.image = UIImage(cgImage: imageFromARGB32Bitmap(pixels: data, withWidth: Int(fbW), withHeight: Int(fbH))!)
            lastUpdate = CACurrentMediaTime()
        }
    }
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
        globalStateKeeper!.rescheduleReDrawTimer(data: data, fbW: fbW, fbH: fbH)
    } else {
        //print("Drawing a frame normally.")
        draw(data: data, fbW: fbW, fbH: fbH, x: x, y: y, w: w, h: h)
    }
    return true
}

func imageFromARGB32Bitmap(pixels: UnsafeMutablePointer<UInt8>?, withWidth: Int, withHeight: Int) -> CGImage? {
    guard withWidth > 0 && withHeight > 0 else { return nil }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).union(.byteOrder32Big)
    let bitsPerComponent = 8

    guard let context: CGContext = CGContext(data: pixels, width: withWidth, height: withHeight, bitsPerComponent: bitsPerComponent, bytesPerRow: 4*withWidth, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
        log_callback_str(message: "Could not create CGContext")
        return nil
    }
    return context.makeImage()
    /*
    let bitsPerPixel = 32
    return CGImage(width: withWidth,
                             height: withHeight,
                             bitsPerComponent: bitsPerComponent,
                             bitsPerPixel: bitsPerPixel,
                             bytesPerRow: 4*withWidth,
                             space: colorSpace,
                             bitmapInfo: bitmapInfo,
                             provider: CGDataProvider(data: NSData(bytes: pixels, length: withWidth*withHeight*4))!,
                             decode: nil,
                             shouldInterpolate: true,
                             intent: .defaultIntent)
     */
}

class RemoteSession {
    let stateKeeper: StateKeeper
    var instance: Int
    var cl: UnsafeMutableRawPointer?
    
    init(instance: Int, stateKeeper: StateKeeper) {
        log_callback_str(message: "Initializing VNC Session instance: \(instance)")
        self.instance = instance
        self.stateKeeper = stateKeeper
        self.cl = nil
    }
        
    func loadTextFile(path: String) -> String {
        var contents = "Not Loaded"
        do { contents = try String(contentsOfFile: path, encoding: String.Encoding.utf8) }
            catch { log_callback_str(message: "Error loading file") }
        return contents
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
}
