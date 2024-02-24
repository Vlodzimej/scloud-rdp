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
    var lX: CGFloat = 0.0
    var lY: CGFloat = 0.0
    var cX: CGFloat = 0.0
    var cY: CGFloat = 0.0
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
            /* TODO: Implement panning the screen if cX or cY are close to the visible edge of the screen.
            let newCenterX = view.center.x + diffX
            let newCenterY = view.center.y + diffY
            panView(sender: sender, newCX: newCenterX, newCY: newCenterY)
             */
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
        
        let scaleX = touchView.transform.a
        let scaleY = touchView.transform.d
        
        cX = point.x
        cY = point.y
        if gestureBegan {
            print("setViewParameters: gestureBegan")
            lX = cX
            lY = cY
        }
        
        diffX = (lX - cX)*scaleX
        diffY = (lY - cY)*scaleY
        lX = cX
        lY = cY
        
        var rX = lastX - diffX
        var rY = lastY - diffY
        
        let rW = CGFloat(self.stateKeeper?.remoteSession?.width ?? 0)
        let rH = CGFloat(self.stateKeeper?.remoteSession?.height ?? 0)
        
        if rX < 0 {
            rX = 0
        }
        if rX > rW {
            rX = rW
        }
        if rY < 0 {
            rY = 0
        }
        if rY > rH {
            rY = rH
        }

        newX = rX
        newY = rY
        print("setViewParameters, diffs: \(diffX)x\(diffY), new coords: \(newX)x\(newY)")

        self.width = touchView.frame.width
        self.height = touchView.frame.height
        if setDoubleTapCoordinates {
            self.pendingDoubleTap = true
            newDoubleTapX = newX
            newDoubleTapY = newY
        }
    }
}
