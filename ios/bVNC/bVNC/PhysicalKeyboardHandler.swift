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

var globalTextInput: CustomTextInput?

class PhysicalKeyboardHandler {
    var specialKeyToXKeySymMap: [String: Int32]
    var keyCodeWithShiftModifierToString: [Int: String]
    var stateKeeper = StateKeeper()
    var textInput: CustomTextInput?
    var commands: [UIKeyCommand]?

    init(stateKeeper: StateKeeper) {
        self.stateKeeper = stateKeeper
        self.textInput = CustomTextInput(stateKeeper: stateKeeper)
        globalTextInput = textInput

        if #available(iOS 13.4, *) {
            self.specialKeyToXKeySymMap = [
                UIKeyCommand.f1: XK_F1,
                UIKeyCommand.f2: XK_F2,
                UIKeyCommand.f3: XK_F3,
                UIKeyCommand.f4: XK_F4,
                UIKeyCommand.f5: XK_F5,
                UIKeyCommand.f6: XK_F6,
                UIKeyCommand.f7: XK_F7,
                UIKeyCommand.f8: XK_F8,
                UIKeyCommand.f9: XK_F9,
                UIKeyCommand.f10: XK_F10,
                UIKeyCommand.f11: XK_F11,
                UIKeyCommand.f12: XK_F12,
                UIKeyCommand.inputEscape: XK_Escape,
                UIKeyCommand.inputHome: XK_Home,
                UIKeyCommand.inputEnd: XK_End,
                UIKeyCommand.inputPageUp: XK_Page_Up,
                UIKeyCommand.inputPageDown: XK_Page_Down,
                UIKeyCommand.inputUpArrow: XK_Up,
                UIKeyCommand.inputDownArrow: XK_Down,
                UIKeyCommand.inputLeftArrow: XK_Left,
                UIKeyCommand.inputRightArrow: XK_Right,
            ]

            self.keyCodeWithShiftModifierToString = [
                UIKeyboardHIDUsage.keyboardEqualSign.rawValue: "+",
                UIKeyboardHIDUsage.keyboardHyphen.rawValue: "_",
                UIKeyboardHIDUsage.keyboard0.rawValue: ")",
                UIKeyboardHIDUsage.keyboard9.rawValue: "(",
                UIKeyboardHIDUsage.keyboard8.rawValue: "*",
                UIKeyboardHIDUsage.keyboard7.rawValue: "&",
                UIKeyboardHIDUsage.keyboard6.rawValue: "^",
                UIKeyboardHIDUsage.keyboard5.rawValue: "%",
                UIKeyboardHIDUsage.keyboard4.rawValue: "$",
                UIKeyboardHIDUsage.keyboard3.rawValue: "#",
                UIKeyboardHIDUsage.keyboard2.rawValue: "@",
                UIKeyboardHIDUsage.keyboard1.rawValue: "!",
                UIKeyboardHIDUsage.keyboardGraveAccentAndTilde.rawValue: "~",
                UIKeyboardHIDUsage.keyboardCloseBracket.rawValue: "}",
                UIKeyboardHIDUsage.keyboardOpenBracket.rawValue: "{",
                UIKeyboardHIDUsage.keyboardQuote.rawValue: "\"",
                UIKeyboardHIDUsage.keyboardSemicolon.rawValue: ":",
                UIKeyboardHIDUsage.keyboardSlash.rawValue: "?",
                UIKeyboardHIDUsage.keyboardPeriod.rawValue: ">",
                UIKeyboardHIDUsage.keyboardComma.rawValue: "<",
                UIKeyboardHIDUsage.keyboardBackslash.rawValue: "|"
            ]
            
        } else {
            self.specialKeyToXKeySymMap = [:]
            self.keyCodeWithShiftModifierToString = [:]
        }
    }
    
    func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for p in presses {
            guard let key = p.key else {
                continue
            }
            var shiftDown = false
            var altOrCtrlDown = false
            if key.modifierFlags.contains(.control) {
                altOrCtrlDown = true
                self.stateKeeper.sendModifierIfNotDown(modifier: XK_Control_L)
            }
            if key.modifierFlags.contains(.alternate) {
                altOrCtrlDown = true
                self.stateKeeper.sendModifierIfNotDown(modifier: XK_Alt_L)
            }
            if key.modifierFlags.contains(.shift) {
                shiftDown = true
                self.stateKeeper.sendModifierIfNotDown(modifier: XK_Shift_L)
            }
            if key.modifierFlags.contains(.alphaShift) {
                shiftDown = true
            }

            if key.characters != "" {
                var text = ""

                if shiftDown && !altOrCtrlDown {
                    text = key.characters
                } else if shiftDown {
                    if self.keyCodeWithShiftModifierToString[key.keyCode.rawValue] != nil {
                        text = self.keyCodeWithShiftModifierToString[key.keyCode.rawValue]!
                    } else {
                        // TODO: This means we can't send Ctrl/Alt+Shift+[:non-alpha:] that are not in the
                        // keyCodeWithShiftModifierToString map.
                        // Try implementing .control and .alternate UIKeyCommand keyCommands to avoid this limitation.
                        text = key.charactersIgnoringModifiers.uppercased()
                    }
                } else {
                    text = key.charactersIgnoringModifiers
                }
                if self.specialKeyToXKeySymMap[text] != nil {
                    let xKeySym = self.specialKeyToXKeySymMap[text] ?? 0
                    self.stateKeeper.sendSpecialKeyByXKeySym(key: xKeySym)
                } else {
                    textInput?.insertText(text)
                }
            }
        }
    }

    func pressesEnded(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        for p in presses {
            guard let key = p.key else {
                continue
            }
            if key.modifierFlags.contains(.control) {
                self.stateKeeper.releaseModifierIfDown(modifier: XK_Control_L)
            }
            if key.modifierFlags.contains(.alternate) {
                self.stateKeeper.releaseModifierIfDown(modifier: XK_Alt_L)
            }
            if key.modifierFlags.contains(.shift) {
                self.stateKeeper.releaseModifierIfDown(modifier: XK_Shift_L)
            }
        }
    }


    func pressesCancelled(_ presses: Set<UIPress>,
                                   with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }
    
    var keyCommands: [UIKeyCommand]? {
        if self.commands != nil {
            return self.commands
        }
        self.commands = (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command], action: #selector(captureCmd))})
        commands! += (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command, .shift], action: #selector(captureCmd))})
        commands! += (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command, .alternate], action: #selector(captureCmd))})
        commands! += (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command, .control], action: #selector(captureCmd))})
        commands! += (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command, .shift, .alternate], action: #selector(captureCmd))})
        commands! += (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command, .shift, .control], action: #selector(captureCmd))})
        commands! += (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command, .control, .alternate], action: #selector(captureCmd))})
        commands! += (0...255).map({UIKeyCommand(input: String(UnicodeScalar($0)), modifierFlags: [.command, .control, .alternate, .shift], action: #selector(captureCmd))})
        commands! += [
            //UIKeyCommand(input: "", modifierFlags: [.command], action: #selector(captureCmd)),
            UIKeyCommand(input: "", modifierFlags: [.command, .shift], action: #selector(captureCmd)),
            UIKeyCommand(input: "", modifierFlags: [.command, .alternate], action: #selector(captureCmd)),
            UIKeyCommand(input: "", modifierFlags: [.command, .control], action: #selector(captureCmd)),
            UIKeyCommand(input: "", modifierFlags: [.command, .control, .shift], action: #selector(captureCmd)),
            UIKeyCommand(input: "", modifierFlags: [.command, .control, .alternate], action: #selector(captureCmd)),
            UIKeyCommand(input: "", modifierFlags: [.command, .alternate, .shift], action: #selector(captureCmd)),
            UIKeyCommand(input: "", modifierFlags: [.command, .control, .alternate, .shift], action: #selector(captureCmd))
        ]
        return self.commands
    }
    
    @objc func captureCmd(sender: UIKeyCommand) {
        var anotherModifier = false
        if sender.modifierFlags.contains(.control) {
            self.stateKeeper.sendModifierIfNotDown(modifier: XK_Control_L)
            anotherModifier = true
        }
        if sender.modifierFlags.contains(.alternate) {
            self.stateKeeper.sendModifierIfNotDown(modifier: XK_Alt_L)
            anotherModifier = true
        }
        if sender.modifierFlags.contains(.shift) {
            self.stateKeeper.modifiers[XK_Shift_L] = true
            anotherModifier = true
        }

        /*
        // This implementation is able to send a single Start/Super key command, but
        // causes stray Start/Super key to be sent when Command-Tabbing away from the app.
        // UIKeyCommand(input: "", modifierFlags: [.command], action: #selector(captureCmd))
        // needs to be added above
        if sender.modifierFlags.contains(.command) {
            self.stateKeeper.sendModifierIfNotDown(modifier: XK_Super_L)
            self.stateKeeper.rescheduleSuperKeyUpTimer()
        }
        
        if sender.input != "" {
            if self.stateKeeper.modifiers[XK_Shift_L]! {
                textInput?.insertText(sender.input!.uppercased())
            } else {
                textInput?.insertText(sender.input!.lowercased())
            }
        } else if sender.input == "" && !anotherModifier {
            self.stateKeeper.releaseModifierIfDown(modifier: XK_Control_L)
            self.stateKeeper.releaseModifierIfDown(modifier: XK_Alt_L)
            self.stateKeeper.modifiers[XK_Shift_L] = false
        }
        */
        
        if sender.input != "" || anotherModifier {
            if !self.stateKeeper.modifiers[XK_Super_L]! {
                print("Super/command key not down and sent with a different modifier or key, sending Super down")
                self.stateKeeper.sendModifierIfNotDown(modifier: XK_Super_L)
            }
            if sender.input != "" {
                if self.stateKeeper.modifiers[XK_Shift_L]! {
                    textInput?.insertText(sender.input!.uppercased())
                } else {
                    textInput?.insertText(sender.input!.lowercased())
                }
            }
        }

        if sender.input == "" && !anotherModifier {
            if self.stateKeeper.modifiers[XK_Super_L]! {
                print("Super/command key was previously marked as down, sending Super up")
                self.stateKeeper.releaseModifierIfDown(modifier: XK_Super_L)
                self.stateKeeper.releaseModifierIfDown(modifier: XK_Control_L)
                self.stateKeeper.releaseModifierIfDown(modifier: XK_Alt_L)
                self.stateKeeper.modifiers[XK_Shift_L] = false
            }
        }
    }
}
