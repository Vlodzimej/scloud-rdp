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
import UIKit
import GameController

let insetDimension: CGFloat = 0

extension UIImage {
    func imageWithInsets(insets: UIEdgeInsets) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: self.size.width + insets.left + insets.right,
                   height: self.size.height + insets.top + insets.bottom), false, self.scale)
        let _ = UIGraphicsGetCurrentContext()
        let origin = CGPoint(x: insets.left, y: insets.top)
        self.draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imageWithInsets
    }
}

extension UIImage {
    func image(byDrawingImage image: UIImage, inRect rect: CGRect) -> UIImage! {
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        image.draw(in: rect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}

extension UIImage {

    static func imageFromARGB32Bitmap(pixels: UnsafeMutableRawPointer?, withWidth: Int, withHeight: Int) -> UIImage {
        guard withWidth > 0 && withHeight > 0 else { return UIImage() }
        guard pixels != nil else { return UIImage() }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).union(.byteOrder32Big)
        let bitsPerComponent = 8
        guard let context: CGContext = CGContext(data: pixels, width: withWidth, height: withHeight, bitsPerComponent: bitsPerComponent, bytesPerRow: 4*withWidth, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            log_callback_str(message: "Could not create CGContext")
            return UIImage()
        }
        let cgImage = context.makeImage()
        return UIImage(cgImage: cgImage!)
        /*
        let bitsPerPixel = 32
        let data: NSData = NSData(bytes: pixels, length: withWidth*withHeight*4)
        let cgDataProvider = CGDataProvider(data: data)!
        let cgImage = CGImage(width: withWidth,
                                 height: withHeight,
                                 bitsPerComponent: bitsPerComponent,
                                 bitsPerPixel: bitsPerPixel,
                                 bytesPerRow: 4*withWidth,
                                 space: colorSpace,
                                 bitmapInfo: bitmapInfo,
                                 provider: cgDataProvider,
                                 decode: nil,
                                 shouldInterpolate: true,
                                 intent: .defaultIntent)
        return UIImage(cgImage: cgImage!)
        */
    }
}

extension UIBezierPath {

    class func arrow(from start: CGPoint, to end: CGPoint, tailWidth: CGFloat, headWidth: CGFloat, headLength: CGFloat) -> Self {
        let length = hypot(end.x - start.x, end.y - start.y)
        let tailLength = length - headLength

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { return CGPoint(x: x, y: y) }
        var points: [CGPoint] = [
            p(0, tailWidth / 2),
            p(tailLength, tailWidth / 2),
            p(tailLength, headWidth / 2),
            p(length, 0),
            p(tailLength, -headWidth / 2),
            p(tailLength, -tailWidth / 2),
            p(0, -tailWidth / 2)
        ]

        let cosine = (end.x - start.x) / length
        let sine = (end.y - start.y) / length
        var transform = CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: start.x, ty: start.y)

        let path = CGMutablePath()
        path.addLines(between: points, transform: transform)
        path.closeSubpath()

        return self.init(cgPath: path)
    }

}

class TouchEnabledUIImageView: UIImageView, UIContextMenuInteractionDelegate, UIPointerInteractionDelegate {
    var fingers = [UITouch?](repeating: nil, count:5)
    var width: CGFloat = 0.0
    var height: CGFloat = 0.0
    var lastX: CGFloat = 0.0
    var lastY: CGFloat = 0.0
    var newX: CGFloat = 0.0
    var newY: CGFloat = 0.0
    var remoteX: Float = 0.0
    var remoteY: Float = 0.0
    var newDoubleTapX: CGFloat = 0.0
    var newDoubleTapY: CGFloat = 0.0
    var pendingDoubleTap: Bool = false
    var viewTransform: CGAffineTransform = CGAffineTransform()
    var timeLast: Double = 0.0
    let timeThreshold: Double = 0.02
    var tapLast: Double = 0
    let doubleTapTimeThreshold: Double = 0.5
    let doubleTapDistanceThreshold: CGFloat = 20.0
    var touchEnabled: Bool = false
    var firstDown: Bool = false
    var secondDown: Bool = false
    var thirdDown: Bool = false
    let lock = NSLock()
    let fingerLock = NSLock()
    var panGesture: UIPanGestureRecognizer?
    var pinchGesture: UIPinchGestureRecognizer?
    var tapGesture: UITapGestureRecognizer?
    var primaryClickGesture: UITapGestureRecognizer?
    var secondaryClickGesture: UITapGestureRecognizer?
    var longTapGesture: UILongPressGestureRecognizer?
    var doubleTapDragGesture: UILongPressGestureRecognizer?
    var hoverGesture: UIHoverGestureRecognizer?
    var scrollWheelGesture: UIPanGestureRecognizer?
    var inLeftDragging = false
    var moveEventsSinceFingerDown = 0
    var inScrolling = false
    var inPanning = false
    var inPanDragging = false
    var panningToleranceEvents = 0
    
    var tapGestureDetected = false
    
    var stateKeeper: StateKeeper?
    var physicalMouseAttached = false
    var indexes = 0
    var contextMenuDetected = false

    var prevActionedTranslationX: CGFloat = 0
    var prevActionedTranslationY: CGFloat = 0
    var prevTranslationX: CGFloat = 0
    var prevTranslationY: CGFloat = 0
    var directionUp = false
    var directionDown = false
    let pointerLayer = CAShapeLayer()
    
    func initialize() {
        isMultipleTouchEnabled = true
        self.width = self.frame.width
        self.height = self.frame.height
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture?.numberOfTapsRequired = 1
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleZooming(_:)))
        hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(handleHovering(_:)))
        if #available(iOS 14.0, *) {
            physicalMouseAttached = GCMouse.current != nil
        }
        if #available(iOS 13.4, *) {
            /*
            // Primary and secondary click gesture
            primaryClickGesture = UITapGestureRecognizer(target: self, action: #selector(handlePrimaryClick(_:)))
            primaryClickGesture?.buttonMaskRequired = UIEvent.ButtonMask.primary
            secondaryClickGesture = UITapGestureRecognizer(target: self, action: #selector(handleSecondaryClick(_:)))
            secondaryClickGesture?.buttonMaskRequired = UIEvent.ButtonMask.secondary
            */
            // Pan gesture to recognize mouse-wheel scrolling
            scrollWheelGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScroll(_:)))
            scrollWheelGesture?.allowedScrollTypesMask = UIScrollTypeMask.all
            scrollWheelGesture?.maximumNumberOfTouches = 0;
        }
        
        doubleTapDragGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        doubleTapDragGesture?.minimumPressDuration = 0.05
        doubleTapDragGesture?.numberOfTapsRequired = 1
        
        // Method of detecting two-finger tap/click on trackpad. Not adding unless this is running on a Mac
        // because it also captures long-taps on a touch screen
        if physicalMouseAttached || self.stateKeeper?.isOnMacOsOriPadOnMacOs() == true {
            let interaction = UIContextMenuInteraction(delegate: self)
            self.addInteraction(interaction)
        }
        if self.stateKeeper?.isiPhoneOrPad() ?? false {
            customPointerInteraction(on: self, pointerInteractionDelegate: self)
        }
    }
    
    func customPointerInteraction(on view: UIView, pointerInteractionDelegate: UIPointerInteractionDelegate) {
        let pointerInteraction = UIPointerInteraction(delegate: pointerInteractionDelegate)
        view.addInteraction(pointerInteraction)
    }
    
    fileprivate func mousePointer(fromX: CGFloat, fromY: CGFloat, toX: CGFloat, toY: CGFloat) -> UIBezierPath {
        return UIBezierPath.arrow(
            from: CGPointMake(fromX, fromY),
            to: CGPointMake(toX, toY),
            tailWidth: 3,
            headWidth: 10,
            headLength: 14
        )
    }
    
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var pointerStyle: UIPointerStyle? = nil
        let bezierPath = mousePointer(fromX: 15, fromY: 15, toX: 0, toY: 0)
        pointerStyle = UIPointerStyle(shape: UIPointerShape.path(bezierPath))
        return pointerStyle
    }
    
    func handleScroll(translationX: CGFloat, translationY: CGFloat, threshhold: CGFloat) {
        if prevTranslationY - translationY < 0 {
            if directionDown {
                resetScrollParameters()
            }
            directionUp = true
        } else if prevTranslationY - translationY > 0 {
            if directionUp {
                resetScrollParameters()
            }
            directionDown = true
        }
        prevTranslationY = translationY
        if abs(prevActionedTranslationY - translationY) >= threshhold {
            prevActionedTranslationY = translationY
            sendDownThenUpEvent(scrolling: true, moving: false, firstDown: false, secondDown: false, thirdDown: false,
                                fourthDown: directionUp, fifthDown: directionDown)
        }
    }
    
    @objc func handleScroll(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: sender.view)
        self.handleScroll(translationX: translation.x, translationY: translation.y, threshhold: 40)
    }

    override init(image: UIImage?) {
        super.init(image: image)
        initialize()
    }
    
    init(frame: CGRect, stateKeeper: StateKeeper?) {
        super.init(frame: frame)
        self.stateKeeper = stateKeeper
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    func enableTouch() {
        touchEnabled = true
    }
    
    func disableTouch() {
        touchEnabled = false
    }
    
    func isOutsideImageBoundaries(touch: UITouch, touchView: UIView) -> Bool {
        if (!touch.view!.isKind(of: UIImageView.self)) {
            return false
        }
        return true
    }
    
    func setViewParameters(point: CGPoint, touchView: UIView, setDoubleTapCoordinates: Bool=false, gestureBegan: Bool=false) {
        //log_callback_str(message: #function)
        self.width = touchView.frame.width
        self.height = touchView.frame.height
        self.viewTransform = touchView.transform
        //let sDx = (touchView.center.x - self.point.x)/self.width
        //let sDy = (touchView.center.y - self.point.y)/self.height
        self.newX = (point.x)*viewTransform.a + insetDimension/viewTransform.a
        self.newY = (point.y)*viewTransform.d + insetDimension/viewTransform.d
        if setDoubleTapCoordinates {
            self.pendingDoubleTap = true
            newDoubleTapX = newX
            newDoubleTapY = newY
        }
    }
    
    func sendDownThenUpEvent(scrolling: Bool, moving: Bool, firstDown: Bool, secondDown: Bool, thirdDown: Bool, fourthDown: Bool, fifthDown: Bool) {
        if (self.touchEnabled) {
            Background {
                let timeNow = CACurrentMediaTime()
                let timeDiff = timeNow - self.timeLast
                if ((!moving && !scrolling) || (moving || scrolling) && timeDiff >= self.timeThreshold) {
                    self.sendPointerEvent(scrolling: scrolling, moving: moving, firstDown: firstDown, secondDown: secondDown, thirdDown: thirdDown, fourthDown: fourthDown, fifthDown: fifthDown)
                    if (!moving) {
                        //log_callback_str(message: "Sleeping \(self.timeThreshhold)s before sending up event.")
                        Thread.sleep(forTimeInterval: self.timeThreshold)
                        self.sendPointerEvent(scrolling: scrolling, moving: moving, firstDown: false, secondDown: false, thirdDown: false, fourthDown: false, fifthDown: false)
                    }
                    self.timeLast = CACurrentMediaTime()
                }
            }
        }
    }
    
    func synced(_ lock: Any, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    fileprivate func repositionPointerIfScrolling(fourthDown: Bool, fifthDown: Bool) {
        if fourthDown || fifthDown {
            stateKeeper?.remoteSession?.pointerEvent(
                remoteX: self.remoteX, remoteY: self.remoteY,
                firstDown: false, secondDown: false, thirdDown: false,
                scrollUp: false, scrollDown: false)
        }
    }
    
    func sendPointerEvent(scrolling: Bool, moving: Bool, firstDown: Bool, secondDown: Bool, thirdDown: Bool, fourthDown: Bool, fifthDown: Bool) {
        guard (self.stateKeeper?.getCurrentInstance()) != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        
        if !moving || (abs(self.lastX - self.newX) > 0 || abs(self.lastY - self.newY) > 0) {
            synced(self) {
                //log_callback_str(message: "sendPointerEvent: x: \(newX), y: \(newY), scrolling: \(scrolling), moving: \(moving), firstDown: \(firstDown), secondDown: \(secondDown), thirdDown: \(thirdDown), fourthDown: \(fourthDown), fifthDown: \(fifthDown)")
                repositionPointerIfScrolling(fourthDown: fourthDown, fifthDown: fifthDown)
                let hasDrawnFirstFrame = stateKeeper?.hasDrawnFirstFrame ?? false
                
                self.remoteX = Float(CGFloat(self.stateKeeper?.remoteSession?.fbW ?? 0) * self.newX / self.width)
                self.remoteY = Float(CGFloat(self.stateKeeper?.remoteSession?.fbH ?? 0) * self.newY / self.height)

                if hasDrawnFirstFrame {
                    stateKeeper?.remoteSession?.pointerEvent(
                        remoteX: remoteX, remoteY: remoteY,
                        firstDown: firstDown, secondDown: secondDown, thirdDown: thirdDown,
                        scrollUp: fourthDown, scrollDown: fifthDown)
                }
            }
            self.lastX = self.newX
            self.lastY = self.newY
            self.stateKeeper?.rescheduleScreenUpdateRequest(timeInterval: 0.3, fullScreenUpdate: false, recurring: false)
        }
    }
        
    func enableGestures() {
        isUserInteractionEnabled = true
        if let pinchGesture = pinchGesture { addGestureRecognizer(pinchGesture) }
        if let panGesture = panGesture {
            addGestureRecognizer(panGesture)
            if #available(iOS 13.4, *) {
                panGesture.allowedScrollTypesMask = UIScrollTypeMask.continuous
            }
        }
        if let tapGesture = tapGesture { addGestureRecognizer(tapGesture) }
        if let longTapGesture = longTapGesture { addGestureRecognizer(longTapGesture) }
        if let hoverGesture = hoverGesture { addGestureRecognizer(hoverGesture) }
        if let scrollWheelGesture = scrollWheelGesture { addGestureRecognizer(scrollWheelGesture) }
        if let doubleTapDragGesture = doubleTapDragGesture { addGestureRecognizer(doubleTapDragGesture) }

        /*
        if let primaryClickGesture = primaryClickGesture { addGestureRecognizer(primaryClickGesture) }
        if let secondaryClickGesture = secondaryClickGesture { addGestureRecognizer(secondaryClickGesture) }
        */
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        log_callback_str(message: #function)
        super.touchesBegan(touches, with: event)
        for touch in touches {
            if let touchView = touch.view {
                if !isOutsideImageBoundaries(touch: touch, touchView: touchView) {
                    log_callback_str(message: "Touch is outside image, ignoring.")
                    continue
                }
            } else {
                log_callback_str(message: "Could not unwrap touch.view, sending event at last coordinates.")
            }
            
            self.moveEventsSinceFingerDown = 0
            for (index, finger)  in self.fingers.enumerated() {
                indexes = index + 1
                if finger == nil {
                    self.fingerLock.lock()
                    self.fingers[index] = touch
                    self.fingerLock.unlock()
                    if self.thirdDown {
                        self.inScrolling = false
                        self.inPanning = false
                        log_callback_str(message: "Right-click already initiated, skipping first and second index detection")
                    }
                    if index == 0 && !self.contextMenuDetected {
                        self.inScrolling = false
                        self.inPanning = false
                        log_callback_str(message: "Single index detected, marking this a left-click")
                        resetButtonState()
                        self.firstDown = true
                        // Record location only for first index
                        if let touchView = touch.view {
                            self.setViewParameters(point: touch.location(in: touchView), touchView: touchView, gestureBegan: true)
                        }
                    }
                    if index == 1 && !self.thirdDown {
                        log_callback_str(message: "Two indexes detected, marking this a right-click")
                        resetButtonState()
                        self.thirdDown = true
                    }
                    if index == 2 {
                        log_callback_str(message: "Three indexes detected, marking this a middle-click")
                        resetButtonState()
                        self.secondDown = true
                    }
                    break
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //log_callback_str(message: #function)
        super.touchesMoved(touches, with: event)
        for touch in touches {
            if let touchView = touch.view {
                if !isOutsideImageBoundaries(touch: touch, touchView: touchView) {
                    log_callback_str(message: "Touch is outside image, ignoring.")
                    continue
                }
            } else {
                log_callback_str(message: "Could not unwrap touch.view, sending event at last coordinates.")
            }
            
            for (index, finger) in self.fingers.enumerated() {
                if let finger = finger, finger == touch {
                    if index == 0 {
                        if stateKeeper!.isOnMacOsOriPadOnMacOs() || moveEventsSinceFingerDown >= 12 {
                            //log_callback_str(message: "\(#function) +\(self.firstDown) + \(self.secondDown) + \(self.thirdDown)")
                            self.inPanDragging = true
                            self.sendDownThenUpEvent(scrolling: false, moving: true, firstDown: self.firstDown, secondDown:     self.secondDown, thirdDown: self.thirdDown, fourthDown: false, fifthDown: false)
                        } else {
                            log_callback_str(message: "Discarding some touch events")
                            moveEventsSinceFingerDown += 1
                        }
                        // Record location only for first index
                        if let touchView = touch.view {
                            self.setViewParameters(point: touch.location(in: touchView), touchView: touchView)
                        }
                    }
                    break
                }
            }
        }
    }
    
    func resetButtonState() {
        self.firstDown = false
        self.secondDown = false
        self.thirdDown = false
        self.contextMenuDetected = false
    }
    
    func sendMouseEventsAndResetButtonState() {
        self.sendDownThenUpEvent(scrolling: false, moving: false, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown, fourthDown: false, fifthDown: false)
        resetButtonState()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        log_callback_str(message: #function)
        super.touchesEnded(touches, with: event)
        for touch in touches {
            if let touchView = touch.view {
                if !isOutsideImageBoundaries(touch: touch, touchView: touchView) {
                    log_callback_str(message: "Touch is outside image, ignoring.")
                    continue
                }
            } else {
                log_callback_str(message: "Could not unwrap touch.view, sending event at last coordinates.")
            }
            
            for (index, finger) in self.fingers.enumerated() {
                if let finger = finger, finger == touch {
                    self.fingerLock.lock()
                    self.fingers[index] = nil
                    self.fingerLock.unlock()
                    if (index == 0) {
                        if (self.inLeftDragging) {
                            log_callback_str(message: "Currently left-dragging and first finger lifted, not sending mouse events")
                        } else if (self.tapGestureDetected && !self.secondDown) {
                            log_callback_str(message: "Currently single or double-tapping, not middle-clicking and first finger lifted, not sending mouse events")
                        } else if (self.panGesture?.state == .began) {
                            log_callback_str(message: "Currently panning and first finger lifted, not sending mouse events")
                        } else if (self.pinchGesture?.state == .began) {
                            resetButtonState()
                            log_callback_str(message: "Currently zooming, not sending mouse events, resetting button state")
                        } else {
                            log_callback_str(message: "Not panning or zooming and first finger lifted, sending mouse events")
                            sendMouseEventsAndResetButtonState()
                        }
                        self.tapGestureDetected = false
                    } else {
                        log_callback_str(message: "Fingers other than first lifted, not sending mouse events.")
                    }
                    break
                }
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        log_callback_str(message: #function)
        super.touchesCancelled(touches!, with: event)
        guard let touches = touches else { return }
        self.touchesEnded(touches, with: event)
    }
    
    @objc func handleHovering(_ sender: UIHoverGestureRecognizer) {
        //log_callback_str(message: "\(#function) scrolling: false, moving: true, firstDown: \(self.firstDown), secondDown: \(self.secondDown), thirdDown: \(self.thirdDown), fourthDown: false, fifthDown: false, inLeftDragging: \(self.inLeftDragging)")
        sendPointerEvent(scrolling: false, moving: true, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown, fourthDown: false, fifthDown: false)
        if let touchView = sender.view {
            self.setViewParameters(point: sender.location(in: touchView), touchView: touchView)
        } else {
            return
        }
    }

    @objc func handleZooming(_ sender: UIPinchGestureRecognizer) {
        log_callback_str(message: #function)
        if (self.stateKeeper?.allowZooming != true || self.secondDown || self.inScrolling || self.inPanning) {
            return
        }
        let scale = sender.scale
        if sender.scale < 0.95 || sender.scale > 1.05 {
            log_callback_str(message: "Preventing large skips in scale.")
        }
        let transformResult = sender.view?.transform.scaledBy(x: sender.scale, y: sender.scale)
        guard let newTransform = transformResult, newTransform.a > 1, newTransform.d > 1 else { return }

        if let view = sender.view {
            let scaledWidth = sender.view!.frame.width/scale
            let scaledHeight = sender.view!.frame.height/scale
            if view.center.x/scale < -20 { view.center.x = -20*scale }
            if view.center.y/scale < -20 { view.center.y = -20*scale }
            if view.center.x/scale > scaledWidth/2 + 20 { view.center.x = (scaledWidth/2 + 20)*scale }
            if view.center.y/scale > scaledHeight/2 + 20 { view.center.y = (scaledHeight/2 + 20)*scale }
        }
        sender.view?.transform = newTransform
        sender.scale = 1
        self.stateKeeper?.rescheduleScreenUpdateRequest(timeInterval: 0.5, fullScreenUpdate: false, recurring: false)
    }
    
    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        log_callback_str(message: #function)
        if !self.secondDown && !self.thirdDown {
            self.tapGestureDetected = true
            resetButtonState()
            self.firstDown = true
            if let touchView = sender.view {
                let timeNow = CACurrentMediaTime()
                if timeNow - tapLast > doubleTapTimeThreshold {
                    log_callback_str(message: "Single tap detected.")
                    self.setViewParameters(point: sender.location(in: touchView), touchView: touchView, setDoubleTapCoordinates: true, gestureBegan: true)
                } else if self.pendingDoubleTap {
                    log_callback_str(message: "Potential double tap detected.")
                    self.pendingDoubleTap = false
                    self.setViewParameters(point: sender.location(in: touchView), touchView: touchView)
                    let distance = abs(lastX - newX) + abs(lastY - newY)
                    if distance < doubleTapDistanceThreshold {
                        log_callback_str(message: "Second tap was \(distance) away from first, sending click at previous coordinates.")
                        newX = newDoubleTapX
                        newY = newDoubleTapY
                    } else {
                        log_callback_str(message: "Second tap was \(distance) away from first, threshhold: \(doubleTapDistanceThreshold).")
                    }
                }
                self.tapLast = timeNow
                self.sendDownThenUpEvent(scrolling: false, moving: false, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown, fourthDown: false, fifthDown: false)
                resetButtonState()
            }
        } else {
            log_callback_str(message: "Other fingers were down, not acting on single tap")
        }
    }

    func panView(sender: UIPanGestureRecognizer, newCX: CGFloat? = nil, newCY: CGFloat? = nil) -> Void {
        //log_callback_str(message: #function)
        var tempVerticalOnlyPan = false
        if !self.stateKeeper!.allowPanning && !(self.stateKeeper!.keyboardHeight > 0) {
            // Panning is disallowed and keyboard is not up, not doing anything
            return
        } else if !self.stateKeeper!.allowPanning && self.stateKeeper!.keyboardHeight > 0 {
            // Panning is disallowed but keyboard is up so we allow vertical panning temporarily
            tempVerticalOnlyPan = true
        }
        
        if let view = sender.view {
            let scaleX = sender.view!.transform.a
            let scaleY = sender.view!.transform.d
            let translation = sender.translation(in: sender.view)

            //log_callback_str(message: "\(#function), panning")
            self.inPanning = true
            var newCenterX = view.center.x + scaleX*translation.x
            var newCenterY = view.center.y + scaleY*translation.y
            if (newCX != nil && newCY != nil) {
                newCenterX = newCX!
                newCenterY = newCY!
            }
            let scaledWidth = sender.view!.frame.width/scaleX
            let scaledHeight = sender.view!.frame.height/scaleY
            
            if sender.view!.frame.minX/scaleX >= 50/scaleX && view.center.x - newCenterX < 0 {
                newCenterX = view.center.x
            }
            if sender.view!.frame.minY/scaleY >= 50/scaleY + globalStateKeeper!.topSpacing/scaleY && view.center.y - newCenterY < 0 {
                newCenterY = view.center.y
            }
            if sender.view!.frame.minX/scaleX <= -50/scaleX - (scaleX-1.0)*scaledWidth/scaleX && newCenterX - view.center.x < 0 {
                newCenterX = view.center.x
            }
            if sender.view!.frame.minY/scaleY <= -50/scaleY - globalStateKeeper!.keyboardHeight/scaleY - (scaleY-1.0)*scaledHeight/scaleY && newCenterY - view.center.y < 0 {
                newCenterY = view.center.y
            }
            
            if tempVerticalOnlyPan {
                // Do not allow panning sideways if this is a temporary vertical pan
                newCenterX = view.center.x
            }
            view.center = CGPoint(x: newCenterX, y: newCenterY)
            sender.setTranslation(CGPoint.zero, in: view)
            self.stateKeeper?.rescheduleScreenUpdateRequest(timeInterval: 0.5, fullScreenUpdate: false, recurring: false)
        }
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        log_callback_str(message: #function)
        if self.firstDown {
            return nil
        }
        if let view = interaction.view {
            self.setViewParameters(point: interaction.location(in: view), touchView: view, setDoubleTapCoordinates: true)
            if stateKeeper?.isOnMacOsOriPadOnMacOs() == true {
                self.sendDownThenUpEvent(scrolling: false, moving: false, firstDown: false, secondDown: false, thirdDown: true, fourthDown: false, fifthDown: false)
            } else {
                self.contextMenuDetected = true
                self.thirdDown = true
            }
        } else {
            log_callback_str(message: "Could not unwrap interaction.view, sending event at last coordinates.")
        }
        return nil
    }

    @objc func handleDrag(_ sender: UILongPressGestureRecognizer) {
        log_callback_str(message: #function)
        if let view = sender.view {
            self.setViewParameters(point: sender.location(in: view), touchView: view, setDoubleTapCoordinates: false)
            switch sender.state {
            case .began, .changed:
                self.sendPointerEvent(scrolling: false, moving: false, firstDown: true, secondDown: false, thirdDown: false, fourthDown: false, fifthDown: false)
                break
            case .ended, .cancelled, .failed:
                self.setViewParameters(point: sender.location(in: view), touchView: view, setDoubleTapCoordinates: false)
                self.sendPointerEvent(scrolling: false, moving: false, firstDown: false, secondDown: false, thirdDown: false, fourthDown: false, fifthDown: false)
                break
            case .possible:
                log_callback_str(message: "Ignoring possible state in UILongPressGestureRecognizer")
            @unknown default:
                log_callback_str(message: "Ignoring unknown state in UILongPressGestureRecognizer")
            }
        } else {
            log_callback_str(message: "Could not unwrap interaction.view, sending event at last coordinates.")
        }
    }

    @objc private func handlePrimaryClick(_ sender: UITapGestureRecognizer) {
        log_callback_str(message: #function)
    }

    @objc private func handleSecondaryClick(_ sender: UITapGestureRecognizer) {
        log_callback_str(message: #function)
    }
    
    func resetScrollParameters() {
        log_callback_str(message: #function)
        self.prevActionedTranslationX = 0
        self.prevActionedTranslationY = 0
        self.prevTranslationX = 0
        self.prevTranslationY = 0
        self.directionUp = false
        self.directionDown = false
    }
    
    func scroll(touchView: UIView, translation: CGPoint, viewTransform: CGAffineTransform, scaleX: CGFloat, scaleY: CGFloat, gesturePoint: CGPoint, restorePointerPosition: Bool) -> Bool {

        let yTranslation = abs(scaleY*translation.y)
        let xTranslation = abs(scaleX*translation.x)
        var translationRatio = 0.0
        if xTranslation > 0.0 && yTranslation > 0.0 {
            translationRatio = yTranslation/xTranslation
        } else {
            // Consume event but don't take action if translation in x and y are exactly zero
            return true
        }

        var consumed = false
        if (
            !self.inPanDragging && !self.inPanning && self.thirdDown &&
            (self.inScrolling || translationRatio >= Constants.SCROLL_TOLERANCE)
        ) {
            consumed = true

            // If tolerance for scrolling was just exceeded, begin scroll event
            if (!self.inScrolling) {
                self.inScrolling = true
                self.viewTransform = viewTransform
                self.setViewParameters(point: gesturePoint, touchView: touchView)
                resetScrollParameters()
            }
            
            let oX = lastX
            let oY = lastY
            
            self.handleScroll(translationX: translation.x, translationY: translation.y, threshhold: 40)
            
            if restorePointerPosition {
                // keep pointer where it was when the scroll event started
                lastX = oX
                lastY = oY
                newX = oX
                newY = oY
            }
        }
        return consumed
    }
    
    func drawPointer(x: CGFloat, y: CGFloat, inView view: UIView) {
        pointerLayer.removeFromSuperlayer()
        let path = mousePointer(fromX: x + 15, fromY: y + 15, toX: x, toY: y)
        pointerLayer.path = path.cgPath
        pointerLayer.opacity = 0.8
        pointerLayer.fillColor = UIColor.white.cgColor
        pointerLayer.strokeColor = UIColor.black.cgColor
        view.layer.addSublayer(pointerLayer)
    }
}
