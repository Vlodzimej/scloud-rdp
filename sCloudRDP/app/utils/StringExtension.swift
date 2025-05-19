//
//  StringExtension.swift
//  sCloudRDP
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

    func utf8DecodedStringWithEncoding(encoding: String.Encoding) -> String? {
        let data = self.data(using: .utf8)
        let message = String(data: data!, encoding: encoding) ?? nil
        return message
    }
}
