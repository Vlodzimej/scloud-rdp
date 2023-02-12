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


class PhysicalKeyboardHandler {
    var specialKeyToXKeySymMap: [String: Int32]
    var keyCodeWithShiftModifierToString: [Int: String]
    var stateKeeper: StateKeeper?
    var textInput: CustomTextInput?
    var commands: [UIKeyCommand]?

    init(stateKeeper: StateKeeper) {
        self.stateKeeper = stateKeeper
        self.textInput = CustomTextInput(stateKeeper: stateKeeper)

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
                "\u{1E}": XK_Pointer_Up,
                "\u{1F}": XK_Pointer_Down,
                "\u{1C}": XK_Pointer_Left,
                "\u{1D}": XK_Pointer_Right,
                "\t": XK_Tab,
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
        guard self.stateKeeper?.getCurrentInstance() != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }

        for p in presses {
            print (#function, p.key)
            guard let key = p.key else {
                continue
            }
            var shiftDown = false
            var altOrCtrlDown = false
            if key.modifierFlags.contains(.control) {
                altOrCtrlDown = true
                print(#function, "Control")
                self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Control_L)
            }
            if key.keyCode == .keyboardRightAlt {
                altOrCtrlDown = true
                print(#function, "RAlt")
                self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Alt_R)
            } else if key.keyCode == .keyboardLeftAlt {
                altOrCtrlDown = true
                print(#function, "LAlt")
                self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Alt_L)
            }
            if key.modifierFlags.contains(.shift) {
                shiftDown = true
                print(#function, "Shift")
                self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Shift_L)
            }
            if key.modifierFlags.contains(.command) {
                print(#function, "Super")
                self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Super_L)
            }
            if key.modifierFlags.contains(.alphaShift) {
                print(#function, "CapsLock")
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
                print(#function, "Text extracted from event: \(text)")
                if self.specialKeyToXKeySymMap[text] != nil {
                    let xKeySym = self.specialKeyToXKeySymMap[text] ?? 0
                    print(#function, "Sending text \(text) converted to xKeySym \(xKeySym) with specialKeyToXKeySymMap")
                    self.stateKeeper?.sendSpecialKeyByXKeySym(key: xKeySym)
                } else {
                    print(#function, "Sending text: \(text)")
                    textInput?.insertText(text)
                }
            }
        }
    }

    func pressesEnded(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        guard self.stateKeeper?.getCurrentInstance() != nil else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        
        for p in presses {
            guard let key = p.key else {
                continue
            }
            // Only if the press ending is with just the modifier do we release modifiers
            // to allow multiple modified characters to be sent with a single modifier press.
            if (key.characters != "") {
                continue
            }
            if key.modifierFlags.contains(.control) {
                print(#function, "Control")
                self.stateKeeper?.releaseModifierIfDown(modifier: XK_Control_L)
            }
            if key.keyCode == .keyboardRightAlt {
                print(#function, "RAlt")
                self.stateKeeper?.releaseModifierIfDown(modifier: XK_Alt_R)
            } else if key.keyCode == .keyboardLeftAlt {
                print(#function, "LAlt")
                self.stateKeeper?.releaseModifierIfDown(modifier: XK_Alt_L)
            }
            if key.modifierFlags.contains(.shift) {
                print(#function, "Shift")
                self.stateKeeper?.releaseModifierIfDown(modifier: XK_Shift_L)
            }
            if key.modifierFlags.contains(.command) {
                print(#function, "Super")
                self.stateKeeper?.releaseModifierIfDown(modifier: XK_Super_L)
            }
        }
    }

    func pressesCancelled(_ presses: Set<UIPress>,
                                   with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }
    
    func isiOSAppOnMac() -> Bool {
        return self.stateKeeper?.macOs ?? false
    }
    
    var keyCommands: [UIKeyCommand]? {
        // Do not capture all permutations on iOS devices because it causes soft keyboard lag
        if !isiOSAppOnMac() || self.commands != nil {
            return self.commands
        }

        var chars = (0...255).map({String(UnicodeScalar($0))})
        // This implementation is able to send a single Start/Super key command, but
        // causes stray Start/Super key to be sent when Command-Tabbing away from the app.
        // adding "" to chars enables this behavior.
        chars += [
            UIKeyCommand.inputUpArrow,
            UIKeyCommand.inputDownArrow,
            UIKeyCommand.inputLeftArrow,
            UIKeyCommand.inputRightArrow,
            UIKeyCommand.f1,
            UIKeyCommand.f2,
            UIKeyCommand.f3,
            UIKeyCommand.f4,
            UIKeyCommand.f5,
            UIKeyCommand.f6,
            UIKeyCommand.f7,
            UIKeyCommand.f8,
            UIKeyCommand.f9,
            UIKeyCommand.f10,
            UIKeyCommand.f11,
            UIKeyCommand.f12,
            UIKeyCommand.inputHome,
            UIKeyCommand.inputEnd,
            UIKeyCommand.inputEscape,
            UIKeyCommand.inputPageUp,
            UIKeyCommand.inputPageDown,
            "\u{0009}" // tab
        ]
        if #available(iOS 15.0, *) {
            chars += [
                UIKeyCommand.inputDelete,
            ]
        }
        
        let modifierPermutations: [UIKeyModifierFlags] = [
            [UIKeyModifierFlags.control],
            [UIKeyModifierFlags.alternate],
            [UIKeyModifierFlags.alternate, UIKeyModifierFlags.shift],
            [UIKeyModifierFlags.control, UIKeyModifierFlags.shift],
            [UIKeyModifierFlags.control, UIKeyModifierFlags.alternate],
            [UIKeyModifierFlags.shift],
            [UIKeyModifierFlags.command],
            [UIKeyModifierFlags.command, UIKeyModifierFlags.shift],
            [UIKeyModifierFlags.command, UIKeyModifierFlags.alternate],
            [UIKeyModifierFlags.command, UIKeyModifierFlags.control],
        ]
        
        commands = []
        for mods in modifierPermutations {
            commands! += chars.map({UIKeyCommand(input: $0, modifierFlags: mods, action: #selector(captureCmd))})
        }
        
        for command in commands! {
            if #available(iOS 15, *), ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15 {
                command.wantsPriorityOverSystemBehavior = true
            }
        }
        return self.commands
    }
    
    @objc func captureCmd(sender: UIKeyCommand) {
        let text = sender.input!
        var modifiers = [ false, false, false, false ]
        if sender.modifierFlags.contains(.control) {
            print(#function, "Control")
            self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Control_L)
            modifiers[0] = true
        }
        if sender.modifierFlags.contains(.alternate) {
            print(#function, "Alt")
            self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Alt_L)
            modifiers[1] = true
        }
        if sender.modifierFlags.contains(.shift) {
            print(#function, "Shift")
            self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Shift_L)
            modifiers[2] = true
        }
        if sender.modifierFlags.contains(.command) {
            print(#function, "Super")
            self.stateKeeper?.sendModifierIfNotDown(modifier: XK_Super_L)
            modifiers[3] = true
        }
        
        usleep(5000)
        if self.specialKeyToXKeySymMap[text] != nil {
            let xKeySym = self.specialKeyToXKeySymMap[text] ?? 0
            print(#function, "sending xKeySym converted from text:", xKeySym)
            self.stateKeeper?.sendSpecialKeyByXKeySym(key: xKeySym)
        } else {
            let isShiftDown = self.stateKeeper?.modifiers[XK_Shift_L] ?? false
            if (isShiftDown) {
                textInput?.insertText(text.uppercased())
                print(#function, "sending text uppercased:", text.uppercased())
            } else {
                textInput?.insertText(text.lowercased())
                print(#function, "sending text lowercased:", text.lowercased())
            }
        }
        usleep(5000)

        if (modifiers[0]) {
            print(#function, "Releasing Control")
            self.stateKeeper?.releaseModifierIfDown(modifier: XK_Control_L)
        }
        if (modifiers[1]) {
            print(#function, "Releasing Alt")
            self.stateKeeper?.releaseModifierIfDown(modifier: XK_Alt_L)
        }
        if (modifiers[2]) {
            print(#function, "Releasing Shift")
            self.stateKeeper?.releaseModifierIfDown(modifier: XK_Shift_L)
        }
        if (modifiers[3]) {
            print(#function, "Releasing Super")
            self.stateKeeper?.releaseModifierIfDown(modifier: XK_Super_L)
        }
    }
}
