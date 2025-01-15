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

class ShortTapDragLongPressPanUIImageView: TouchEnabledUIImageView {
    
    var longPressPreviousX: CGFloat = 0.0
    var longPressPreviousY: CGFloat = 0.0
    var longPressX: CGFloat = 0.0
    var longPressY: CGFloat = 0.0

    fileprivate func setLongPressXY(_ sender: UILongPressGestureRecognizer, _ view: UIView) {
        longPressX = sender.location(in: view).x
        longPressY = sender.location(in: view).y
    }
    
    fileprivate func setPreviousLongPressXY() {
        longPressPreviousX = longPressX
        longPressPreviousY = longPressY
    }
    
    fileprivate func setNewCenterXY(_ view: UIView) {
        let currentCenterX = view.center.x
        let currentCenterY = view.center.y
        let diffX = currentCenterX + (longPressX - longPressPreviousX)
        let diffY = currentCenterY + (longPressY - longPressPreviousY)
        log_callback_str(message: "\(#function): Setting view.center to \(diffX)x\(diffY)")
        view.center = CGPoint(x: diffX, y: diffY)
    }
    
    @objc private func handleLongPressPan(_ sender: UILongPressGestureRecognizer) {
        //self.inPanning = true
        if let view = sender.view {
            if sender.state == .began {
                log_callback_str(message: "\(#function): State began")
                setLongPressXY(sender, view)
                setPreviousLongPressXY()
                return
            }
            if sender.state == .ended {
                log_callback_str(message: "\(#function): State ended")
                self.inPanning = false
                return
            }
            setPreviousLongPressXY()
            setLongPressXY(sender, view)
            setNewCenterXY(view)
        }
    }
    
    override func initialize() {
        super.initialize()
        numEventsToDrop = 0
        panViaPanGestureDetector = false
        if self.stateKeeper?.allowPanning ?? true {
            longTapGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressPan(_:)))
        }
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture?.minimumNumberOfTouches = 2
        panGesture?.maximumNumberOfTouches = 2
    }
}
