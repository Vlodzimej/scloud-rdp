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


class ClipboardMonitor {
    let stateKeeper: StateKeeper
    var clipboardTextContents: String?
    var timer: Timer?
    var repeated: Bool = false
    
    init(stateKeeper: StateKeeper, repeated: Bool) {
        self.stateKeeper = stateKeeper
        self.repeated = repeated
    }
    
    func startMonitoring() {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(timeInterval: 2, target: self,
                                          selector: #selector(self.checkAndSendContents),
                                          userInfo: nil, repeats: repeated)
    }
    
    func stopMonitoring() {
        self.timer?.invalidate()
    }
    
    @objc func checkAndSendContents() {
        if UIPasteboard.general.hasStrings {
            let currentTextContents = UIPasteboard.general.string
            if clipboardTextContents != currentTextContents {
                clipboardTextContents = currentTextContents
                if self.stateKeeper.remoteSession?.connected ?? false {
                    self.stateKeeper.remoteSession?.clientCutTextInSession(clientClipboardContents: clipboardTextContents)
                }
            }
        }
    }
}
