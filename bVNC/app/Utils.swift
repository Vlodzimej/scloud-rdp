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
    static let bundleID = Bundle.main.bundleIdentifier ?? Constants.DEFAULT_BUNDLE_ID

    static func getFileContents(path: String) -> String {
        let url = URL(string: "file://" + path)!
        log_callback_str(message: "\(#function): url \(url)")
        let contents = try? String(contentsOf: url, encoding: .utf8)
        return contents ?? ""
    }
    
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
    
    static func deleteFile(name: String?) -> Bool {
        guard let name = name else {
            log_callback_str(message: "\(#function) invalid file name")
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            try FileManager.default.removeItem(at: directory.appendingPathComponent(name)!)
            return true
        } catch {
            log_callback_str(message: error.localizedDescription)
            return false
        }
    }
    
    static func moveUrlToDestinationIfPossible(_ url: URL, _ destPath: String) -> Bool {
        do {
            log_callback_str(message: "\(#function): Trying to copy \(url) to \(destPath)")
            Utils.deletePathIfNeeded(destPath)
            try FileManager.default.copyItem(atPath: url.path, toPath: destPath)
            log_callback_str(message: "\(#function): Copied \(url) to \(destPath)")
            Utils.deletePathIfNeeded(url.path)
            return true
        } catch (let error) {
            log_callback_str(message: "\(#function): Cannot copy item at \(url) to \(destPath): \(error)")
        }
        return false
    }
    
    static func deletePathIfNeeded(_ destPath: String) {
        log_callback_str(message: "\(#function): Removing \(destPath) if there")
        try? FileManager.default.removeItem(atPath: destPath)
        log_callback_str(message: "\(#function): Removed \(destPath)")
    }
    
    static func isSpice() -> Bool {
        return self.bundleID.lowercased().contains("spice")
    }

    static func isVnc() -> Bool {
        return self.bundleID.lowercased().contains("vnc")
    }

    static func isRdp() -> Bool {
        return self.bundleID.lowercased().contains("rdp")
    }
    
    static func getDefaultPort() -> String {
        return isRdp() ? "3389" : "5900"
    }
    
    static func getDefaultSshPort() -> String {
        return "22"
    }
    
    static func getDefaultAddress() -> String {
        return "127.0.0.1"
    }

    static func getTunneledProtocol() -> String {
        var tunneledProtocol = "VNC"
        if isRdp() {
            tunneledProtocol = "RDP"
        } else if isSpice() {
            tunneledProtocol = "SPICE"
        }
        return tunneledProtocol
    }
}
