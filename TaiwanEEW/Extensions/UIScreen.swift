//
//  UIScreen.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/3/26.
//

import Foundation
import SwiftUI

extension UIScreen{
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height
    static let screenSize = UIScreen.main.bounds.size
    static var baseLine: CGFloat {
        if(Device.deviceType == .iphone){
            isZoomed ? (screenWidth-280)/3 : (screenWidth-340)/3
        } else {
            20
        }
    }
    
    static var isZoomed: Bool {
        UIScreen.main.scale < UIScreen.main.nativeScale
    }
}
