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
