//
//  View.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/9/7.
//  https://fatbobman.com/en/posts/swiftui-ipad/

import Foundation
import SwiftUI
extension View {
//    /// Applies the given transform if the given condition evaluates to `true`.
//    /// - Parameters:
//    ///   - condition: The condition to evaluate.
//    ///   - transform: The transform to apply to the source `View`.
//    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
//    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
//        if condition {
//            transform(self)
//        } else {
//            self
//        }
//    }
    
    @ViewBuilder func `if`<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T: View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder func ifElse<T:View,V:View>( _ condition:Bool,isTransform:(Self) -> T,elseTransform:(Self) -> V) -> some View {
        if condition {
            isTransform(self)
        } else {
            elseTransform(self)
        }
    }
    
    @ViewBuilder func ifAvailable16<T>(transform: (Self) -> T) -> some View where T: View {
        if #available (iOS 16, *) {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder func ifAvailable17<T>(transform: (Self) -> T) -> some View where T: View {
        if #available (iOS 17, *) {
            transform(self)
        } else {
            self
        }
    }
    
}
