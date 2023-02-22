//
//  StringExtension.swift
//  bVNC
//
//  Created by iordan iordanov on 2023-02-22.
//  Copyright © 2023 iordan iordanov. All rights reserved.
//

import Foundation

extension String {
    func utf8DecodedString() -> String? {
        let data = self.data(using: .utf8)
        let message = String(data: data!, encoding: .nonLossyASCII) ?? nil
        return message
    }
}
