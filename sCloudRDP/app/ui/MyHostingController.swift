//
//  MyHostingController.swift
//  RDP
//
//  Created by Владимир Амелькин on 04.06.2025.
//  Copyright © 2025 iordan iordanov. All rights reserved.
//

import SwiftUI

class MyUIHostingController<Content> : UIHostingController<Content> where Content : View {
  override var prefersStatusBarHidden: Bool {
    return true
  }
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    log_callback_str(message: "Received a memory warning.")
  }
}
