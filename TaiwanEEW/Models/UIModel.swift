//
//  UIModel.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2024/12/15.
//

import Foundation
import SwiftUI

// Simple model for synchronizing the state of the UI across the app.
@available(iOS 16.0, *)
class UIModel: ObservableObject {
    @Published var selectedDetent: PresentationDetent = .fraction(0.4)
}
