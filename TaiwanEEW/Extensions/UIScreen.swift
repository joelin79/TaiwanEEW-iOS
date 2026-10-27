//
//  UIScreen.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/3/26.
//

import Foundation
import SwiftUI

extension UIScreen{
    // Computed, not stored. These were `let` snapshots taken on first access, which is
    // fine for a phone whose display never changes size but wrong on iPhone Duo: opening
    // or closing the phone hands the app a window of a different size while it is running,
    // and every caller kept laying out against the display it launched on.
    static var screenWidth: CGFloat { UIScreen.main.bounds.size.width }
    static var screenHeight: CGFloat { UIScreen.main.bounds.size.height }
    static var screenSize: CGSize { UIScreen.main.bounds.size }
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
