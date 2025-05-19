//
//  PointerData.swift
//  sCloudRDP
//
//  Created by Iordan Iordanov on 2025-01-04.
//  Copyright © 2025 iordan iordanov. All rights reserved.
//

import Foundation

class PointerData {
    private var pointerShape: UIImage?
    private var pointerWidth: Int = 0
    private var pointerHeight: Int = 0
    private var hotX: Int = 0
    private var hotY: Int = 0
    private var xLocation: Float = 0
    private var yLocation: Float = 0
    
    init(pixels: UnsafeMutablePointer<UInt8>?, width: Int, height: Int, hotX: Int, hotY: Int, x: Float, y: Float) {
        if (pixels != nil) {
            self.pointerShape = UIImage.imageFromARGB32Bitmap(
                pixels: pixels,
                withWidth: Int(width),
                withHeight: Int(height),
                alphaValue: CGImageAlphaInfo.premultipliedLast
            )
        }
        self.pointerWidth = width
        self.pointerHeight = height
        self.hotX = hotX
        self.hotY = hotY
        self.xLocation = x
        self.yLocation = y
    }
    
    func getPointerWidth() -> Int {
        return pointerWidth
    }
    
    func gointerHeight() -> Int {
        return pointerHeight
    }
    
    func getHotX() -> Int {
        return hotX
    }
    
    func getHotY() -> Int {
        return hotY
    }
    
    func setRemoteX(newX: Float) {
        xLocation = newX
    }
    
    func setRemoteY(newY: Float) {
        yLocation = newY
    }
    
    func getRemoteX() -> Float {
        return xLocation
    }
    
    func getRemoteY() -> Float {
        return yLocation
    }
    
    func drawIn(image: UIImage) -> UIImage {
        if let pointerShape = self.pointerShape {
            return image.image(
                byDrawingImage: pointerShape,
                inRect: CGRect(
                    origin: CGPoint(x: Double(xLocation - Float(hotX)), y: Double(yLocation - Float(hotY))),
                    size: CGSize(width: Double(pointerWidth), height: Double(pointerHeight))
                )
            )
        } else {
            return image
        }
    }
}
