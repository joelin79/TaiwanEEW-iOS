//
//  Device.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2024/11/18.
//  https://fatbobman.com/en/posts/swiftui-ipad/

import UIKit

enum Device {
    //MARK: Current device type: iPhone, iPad, Mac
    enum Devicetype{
        case iphone,ipad,mac
    }
    
    static var deviceType:Devicetype{
#if os(macOS)
        return .mac
#else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .ipad
        }
        else {
            return .iphone
        }
#endif
    }
 }
