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
        // TODO: We need a local pointer, especially for RDP protocol
    }
            
    fileprivate func panToKeepPointerVisible(_ view: UIView, _ sender: UIPanGestureRecognizer) {
        let scaleX = view.transform.a
        let scaleY = view.transform.d
        let marginX = CGFloat(100)
        let marginY = CGFloat(100)
        
        let frameMinX = -1 * view.frame.minX / scaleX
        let frameMinY = -1 * view.frame.minY / scaleY
        let frameMaxX = view.frame.maxX / scaleX + frameMinX
        let frameMaxY = view.frame.maxY / scaleY + frameMinY

        let pointerX = newX
        let pointerY = newY

        let minX = frameMinX + marginX
        let maxX = frameMaxX - marginX
        let minY = frameMinY + marginY
        let maxY = frameMaxY - marginY
        print("panToKeepPointerVisible, bounds: \(minX), \(minY), \(maxX), \(maxY), pointer: \(pointerX) x \(pointerY)")
        if diffX > 0 && pointerX < minX ||
            diffY > 0 && pointerY < minY ||
            diffX < 0 && pointerX > maxX ||
            diffY < 0 && pointerY > maxY {
            let newCenterX = view.center.x + diffX
            let newCenterY = view.center.y + diffY
            panView(sender: sender, newCX: newCenterX, newCY: newCenterY)
        }
    }
    
    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
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
                log_callback_str(message: "\(#function), scrolled at \(newX)x\(newY)")
            } else if self.secondDown || self.thirdDown {
                self.inPanDragging = true
                let moving = !(sender.state == .ended)
                log_callback_str(message: "\(#function), second or third button dragging to \(newX)x\(newY)")
                self.sendDownThenUpEvent(scrolling: false, moving: moving, firstDown: self.firstDown, secondDown: self.secondDown,
                                         thirdDown: self.thirdDown, fourthDown: false, fifthDown: false)
            } else {
                log_callback_str(message: "\(#function), moving the mouse pointer to \(newX)x\(newY)")
                self.sendPointerEvent(scrolling: false, moving: true, firstDown: false, secondDown: false, thirdDown: false, fourthDown: false, fifthDown: false)
            }
            panToKeepPointerVisible(view, sender)
        }
    }
    
    @objc private func handleLongTap(_ sender: UILongPressGestureRecognizer) {
        if let touchView = sender.view {
            if sender.state == .began {
                AudioServicesPlaySystemSound(1100);
                self.inLeftDragging = true
            } else if sender.state == .ended {
                self.inLeftDragging = false
            }
            self.setViewParameters(point: sender.location(in: touchView), touchView: touchView)
            self.firstDown = !(sender.state == .ended)
            let moving = self.firstDown
            self.secondDown = false
            self.thirdDown = false
            self.sendDownThenUpEvent(scrolling: false, moving: moving, firstDown: self.firstDown, secondDown: self.secondDown, thirdDown: self.thirdDown, fourthDown: false, fifthDown: false)
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
        
        diffX = (prevTouchX - touchX)*scaleX
        diffY = (prevYouchY - touchY)*scaleY
        prevTouchX = touchX
        prevYouchY = touchY
        
        var rX = lastX - diffX
        var rY = lastY - diffY
        
        // TODO: Can we get rid of one of fbW and width and fbH and height?
        let fbW = CGFloat(self.stateKeeper?.remoteSession?.fbW ?? 0)
        let fbH = CGFloat(self.stateKeeper?.remoteSession?.fbH ?? 0)
        let newRemoteX = CGFloat(fbW * rX / self.width)
        let newRemoteY = CGFloat(fbH * rY / self.height)

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
        //print("setViewParameters, new remote coords: \(newRemoteX)x\(newRemoteY), new coords: \(newX)x\(newY), fbWxfbH: \(fbW)x\(fbH)")

        if setDoubleTapCoordinates {
            self.pendingDoubleTap = true
            newDoubleTapX = newX
            newDoubleTapY = newY
        }
    }
}
