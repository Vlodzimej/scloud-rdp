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
import StoreKit

struct Utils {
    static func getBundleFileContents(name: String) -> String {
        if let fileURL = Bundle.main.url(forResource: name, withExtension: nil) {
            if let fileContents = try? String(contentsOf: fileURL) {
                return fileContents
            }
        }
        return ""
    }
    
    static func loadStringOfIntArraysToMap(source: String) -> [Int: [Int]] {
        var result: [Int: [Int]] = [:]
        let lines = source.split(separator: "\n")
        for l in lines {
            let intArray = l.split(separator: " ")
            result[Int(intArray[0]) ?? 0] = intArray[1...].map { Int($0) ?? 0 }
        }
        return result
    }
    
    static func getResourcePathContents(path: String) -> [String] {
        let fullPath = NSString.path(withComponents: [Bundle.main.resourcePath!, path])
        var fileList: [String] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: fullPath)
            fileList = files.map { String($0) }
        } catch {
            print("Error \(error) listing files at:", path)
        }
        return fileList
    }
    
    static func writeToFile(name: String, text: String) -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let filename = paths[0].appendingPathComponent(name)

        do {
            try text.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Error \(error) writing to file at:", filename)
        }
        return filename.path
    }
}
