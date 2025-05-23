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


class CustomTextInput: UIButton, UIKeyInput {
    public var hasText: Bool { return false }
    var stateKeeper: StateKeeper?
    
    init(stateKeeper: StateKeeper?) {
        super.init(frame: CGRect())
        self.stateKeeper = stateKeeper
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func insertText(_ text: String) {
        guard let currentInstance = self.stateKeeper?.getCurrentInstance() else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        
        //print("Sending: " + text + ", number of characters: " + String(text.count))
        for char in text.unicodeScalars {
            Background {
                self.stateKeeper?.remoteSession?.keyEvent(char: char)
                self.stateKeeper?.toggleModifiersIfDown()
            }
            self.stateKeeper?.rescheduleScreenUpdateRequest(timeInterval: 0.5, fullScreenUpdate: false, recurring: false)
        }
    }
    
    public func deleteBackward() {
        guard let currentInstance = self.stateKeeper?.getCurrentInstance() else {
            log_callback_str(message: "No currently connected instance, ignoring \(#function)")
            return
        }
        
        Background {
            self.stateKeeper?.remoteSession?.sendSpecialKeyByXKeySym(key: XK_BackSpace)
            self.stateKeeper?.toggleModifiersIfDown()
        }
        self.stateKeeper?.rescheduleScreenUpdateRequest(timeInterval: 0.5, fullScreenUpdate: false, recurring: false)
    }
    
    @objc func toggleFirstResponder() -> Bool {
        if (self.isFirstResponder) {
            log_callback_str(message: "Keyboard should be showing already, hiding it.")
            return hideKeyboard()
        } else {
            return showKeyboard()
        }
    }

    @objc func hideKeyboard() -> Bool {
        log_callback_str(message: "Hiding keyboard.")
        becomeFirstResponder()
        return resignFirstResponder()
    }

    @objc func showKeyboardFunction() -> Bool {
        log_callback_str(message: "showKeyboardFunction called")
        resignFirstResponder()
        return becomeFirstResponder()
    }

    
    @objc func showKeyboard() -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let _ = self.showKeyboardFunction()
        }
        log_callback_str(message: "Showing keyboard with delay")
        return true
    }
    
    override func pressesBegan(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        self.stateKeeper?.physicalKeyboardHandler?.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        self.stateKeeper?.physicalKeyboardHandler?.pressesEnded(presses, with: event)
    }


    override func pressesCancelled(_ presses: Set<UIPress>,
                                   with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }

    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []
        for char in self.stateKeeper?.physicalKeyboardHandler?.specialChars ?? [] {
            let command = UIKeyCommand(input: char, modifierFlags: [], action: #selector(captureCmd))
            commands += [command]
            if #available(iOS 15.0, *) {
                command.wantsPriorityOverSystemBehavior = true
            }
        }
        return (self.stateKeeper?.physicalKeyboardHandler?.keyCommands ?? []) + commands
    }

    @objc func captureCmd(sender: UIKeyCommand) {
        self.stateKeeper?.physicalKeyboardHandler?.captureCmd(sender: sender)
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var canBecomeFocused: Bool {
        return true
    }
}
