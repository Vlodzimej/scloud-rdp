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
import AudioToolbox

class SimulatedTouchpadUIImageView: TouchEnabledUIImageView {
    var prevTouchX: CGFloat = 0.0
    var prevYouchY: CGFloat = 0.0
    var touchX: CGFloat = 0.0
    var touchY: CGFloat = 0.0
    var diffX: CGFloat = 0.0
    var diffY: CGFloat = 0.0
    
    override func initialize() {
        super.initialize()
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture?.minimumNumberOfTouches = 1
        panGesture?.maximumNumberOfTouches = 2
        longTapGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap(_:)))
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleZooming(_:)))
    }
    
    fileprivate func panToKeepPointerVisible(_ view: UIView, _ sender: UIPanGestureRecognizer) {
        let scaleX = view.transform.a
        let scaleY = view.transform.d
        
        let frameMinX = view.frame.minX
        let frameMinY = view.frame.minY
        
        let frameW = view.frame.width
        let frameH = view.frame.height
        
        let pointerX = newX
        let pointerY = newY
        
        let visibleMinX = 0 - frameMinX + 20
        let visibleMaxX = frameW / scaleX - frameMinX - 20
        let visibleMinY = 0 - frameMinY + 20
        let visibleMaxY = frameH / scaleY - frameMinY - 20
        
        //print("panToKeepPointerVisible: x: \(round(visibleMinX)) to \(round(visibleMaxX)) / y : \(round(visibleMinY)) to \(round(visibleMaxY)), pointer: \(round(pointerX)) x \(round(pointerY))")
        
        let centerX = view.center.x
        let centerY = view.center.y
        var newCenterX = centerX
        var newCenterY = centerY
        
        if diffX > 0 && pointerX < visibleMinX {
            newCenterX = centerX + min(diffX, 20)
        }
        if diffX < 0 && pointerX > visibleMaxX {
            newCenterX = centerX + min(diffX, 20)
        }
        if diffY > 0 && pointerY < visibleMinY {
            newCenterY = centerY + min(diffY, 20)
        }
        if diffY < 0 && pointerY > visibleMaxY {
            newCenterY = centerY + min(diffY, 20)
        }
        panView(sender: sender, newCX: newCenterX, newCY: newCenterY)
    }
    
    @objc override func handlePan(_ sender: UIPanGestureRecognizer) {
        if sender.state == .ended {
            self.inPanDragging = false
            if !inPanning {
                // If there was actual pointer interaction to the server, request a refresh
                self.stateKeeper?.rescheduleScreenUpdateRequest(timeInterval: 0.5, fullScreenUpdate: false, recurring: false)
            }
        }
        
        if let view = sender.view {
            let scaleX = sender.view!.transform.a
            let scaleY = sender.view!.transform.d
            self.setViewParameters(point: sender.location(in: view), touchView: view)
            
            // self.thirdDown (which marks a right click) helps ensure this mode does not scroll with one finger
            let translation = sender.translation(in: sender.view)
            if (scroll(touchView: view, translation: translation, viewTransform: view.transform, scaleX: scaleX, scaleY: scaleY,
                       gesturePoint: sender.location(in: view), restorePointerPosition: true)) {
                //log_callback_str(message: "\(#function), scrolled at \(newX)x\(newY)")
                return
            } else if self.secondDown || self.thirdDown {
                self.inPanDragging = true
                let moving = !(sender.state == .ended)
                log_callback_str(message: "\(#function), second or third button dragging to \(newX)x\(newY)")
                self.sendDownThenUpEvent(scrolling: false, moving: moving, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown, fourthDown: false, fifthDown: false)
            } else {
                //log_callback_str(message: "\(#function), moving the mouse pointer to \(newX)x\(newY)")
                self.sendPointerEvent(scrolling: false, moving: true, firstDown: false, secondDown: false, thirdDown: false, fourthDown: false, fifthDown: false)
            }
            panToKeepPointerVisible(view, sender)
        }
    }

    override func setViewParameters(point: CGPoint, touchView: UIView, setDoubleTapCoordinates: Bool=false, gestureBegan: Bool=false) {
        self.width = touchView.frame.width
        self.height = touchView.frame.height
        
        let scaleX = touchView.transform.a
        let scaleY = touchView.transform.d
        
        touchX = point.x
        touchY = point.y
        if gestureBegan {
            print("setViewParameters: gestureBegan")
            prevTouchX = touchX
            prevYouchY = touchY
        }
        
        diffX = (prevTouchX - touchX) * scaleX
        diffY = (prevYouchY - touchY) * scaleY
        prevTouchX = touchX
        prevYouchY = touchY
        
        var rX = lastX - diffX
        var rY = lastY - diffY
        
        let newRemoteX = CGFloat(self.fbW * rX / self.width)
        let newRemoteY = CGFloat(self.fbH * rY / self.height)
        
        if newRemoteX <= 0 {
            rX = 0
        }
        if newRemoteX >= fbW {
            rX = width
        }
        if newRemoteY <= 0 {
            rY = 0
        }
        if newRemoteY >= fbH {
            rY = height
        }
        
        newX = rX
        newY = rY
        //print("setViewParameters, new remote coords: \(newRemoteX)x\(newRemoteY), new coords: \(newX)x\(newY), frame wxh: \(width)x\(height)")
        drawPointer(x: newX/scaleX, y: newY/scaleY, inView: self)
        
        if setDoubleTapCoordinates {
            self.pendingDoubleTap = true
            newDoubleTapX = newX
            newDoubleTapY = newY
        }
    }
}
