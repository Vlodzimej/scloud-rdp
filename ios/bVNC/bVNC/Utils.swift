//
//  Utils.swift
//  bVNC
//
//  Created by iordan iordanov on 2021-03-27.
//  Copyright © 2021 iordan iordanov. All rights reserved.
//

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
    
    static func listFileTree(path: String, depth: Int) {
        let fullPath = String(cString: realpath(path, nil))
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: fullPath)
            for f in files {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: f, isDirectory: &isDir) {
                    if isDir.boolValue {
                        listFileTree(path: NSString.path(withComponents: [fullPath, f]), depth: depth + 1)
                    }
                    else {
                        let indentation = String(repeating: "\t", count: depth)
                        print(indentation, f)
                    }
                }
            }
        } catch {
            print("Error \(error) listing files at:", fullPath)
            return
        }
    }
}
