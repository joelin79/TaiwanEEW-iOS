//
//  LocationBlock.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/2/16.
//

import SwiftUI

@available(*, deprecated)
struct LocationBlock: View {
    var districtStr: String
    @State var blockWidth: CGFloat = 100
    
    var body: some View {
        ZStack {
            
            Rectangle()
                .frame(width: blockWidth, height: 27.0)
                .clipped()
                .cornerRadius(10.0)
            Text(districtStr)
                .font(Font.system(size: 12, design: .default).weight(.medium))
                .foregroundColor(Color(.systemGray6))
                .overlay(
                    GeometryReader { geometry in
                    Text(districtStr)
                            .font(Font.system(size: 12, design: .default).weight(.medium))
                            .foregroundColor(Color(.systemGray6))
                        .onAppear {
                            blockWidth = geometry.size.width + 15
                        }
                }
                )
        }
        
    }
    
}

struct LocationBlock_Previews: PreviewProvider {
    static var previews: some View {
        LocationBlock(districtStr: "test")
    }
}
