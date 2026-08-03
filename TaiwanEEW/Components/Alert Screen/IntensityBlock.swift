//
//  IntensityBlock.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/8/18.
//

import SwiftUI

struct IntensityBlock: View {
    let cornerRad: CGFloat = 20
    var intensity: String
    var intensityValue: Int { EEWService.intensityStringToValue(str: intensity) }
    
    init(intensity: String){
        self.intensity = intensity
    }
    
    // Container
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
                .fill(Color("Pad"))
                .clipped()
                .overlay(content)
                // Draw border
                .overlay(RoundedRectangle(cornerRadius: cornerRad)
                    .stroke( intensityValue >= 4 ? .red : Color("EqInfoBoarder"), lineWidth: 2))
                .if(UIScreen.isZoomed) { view in
                    view.frame(width: 140, height: 140)
                }
                .if(!UIScreen.isZoomed) { view in
                    view.frame(width: 170, height: 170)
                }
        }
        
    }
    
    // Content inside container
    var content: some View {
        Group {
            VStack{
                Text("intensity-string")
                    .font(.system(size: UIScreen.isZoomed ? 30 : 34).weight(.medium))
                HStack(alignment: .bottom){
                    Text(intensity)
                        .font(.system(size: UIScreen.isZoomed ? 75 : 80, weight: .bold, design: .monospaced)).foregroundColor(Color(intensity))
                    // TODO: Fix the subscript translation
//                    if !"intensity-sub-string".isEmpty {
                        Text(String(localized:"intensity-sub-string"))
                            .font(.system(size: UIScreen.isZoomed ? 28 : 30, weight: .bold, design: .monospaced))
//                    }
                }
            }
        }
    }
}

struct IntensityBlock_Previews: PreviewProvider {
    static var previews: some View {
        IntensityBlock(intensity: "7").environment(\.locale, Locale.init(identifier: "zh-Hant")).environment(\.colorScheme, .dark)
    }
}
