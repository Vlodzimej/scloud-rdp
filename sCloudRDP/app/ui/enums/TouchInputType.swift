//
//  TouchInputMethod.swift
//  sCloudRDP
//
//  Created by Iordan Iordanov on 2024-11-04.
//  Copyright © 2024 iordan iordanov. All rights reserved.
//

import Foundation

enum TouchInputMethod: String, CaseIterable {
    case directSwipePan = "TOUCH_INPUT_METHOD_DIRECT_SWIPE_PAN"
    case simulatedTouchpad = "TOUCH_INPUT_METHOD_SIMULATED_TOUCHPAD"
    case directLongPressPan = "TOUCH_INPUT_METHOD_DIRECT_LONG_PRESS_PAN"

    init?(id : Int) {
        switch id {
        case 1: self = .directSwipePan
        case 2: self = .simulatedTouchpad
        case 3: self = .directLongPressPan
        default: return nil
        }
    }
}
