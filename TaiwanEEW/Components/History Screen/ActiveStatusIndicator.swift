//
//  ActiveStatusIndicator.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/3/27.
//

import Foundation
import SwiftUI

struct ActiveStatusIndicator: View{
    
    var body: some View {
        Capsule(style: .circular)
            .foregroundColor(.red)
            .frame(width: 110, height: 40)
            .overlay(
                HStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text("active-string")
                        .foregroundColor(.white)
                    Spacer()
                }
            )
    }
    
}

struct ActiveStatusIndicator_Preview: PreviewProvider {
    static var previews: some View {
        ActiveStatusIndicator()
    }
}
