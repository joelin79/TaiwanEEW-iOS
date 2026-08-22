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
    @Environment(\.colorScheme) private var colorScheme
    /// Sized by the caller so the pair can share out the card's width rather than each
    /// claiming a fixed 170pt and leaving whatever is left as the margin.
    var size: CGFloat = AlertBlockMetrics.defaultSize
    var intensityValue: Int { EEWService.intensityStringToValue(str: intensity) }

    init(intensity: String, size: CGFloat = AlertBlockMetrics.defaultSize){
        self.intensity = intensity
        self.size = size
    }
    
    // Container
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
                .fill(Color("Pad"))
                .clipped()
                .overlay(content)
                // Draw border
                .overlay(RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
                    .stroke( intensityValue >= 4 ? .red : Color("EqInfoBoarder"), lineWidth: 2))
                .frame(width: size, height: size)
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
                        .font(.system(size: UIScreen.isZoomed ? 75 : 80, weight: .bold, design: .monospaced))
                        .foregroundColor(AlertIntensityTextColor.color(for: intensity,
                                                                       colorScheme: colorScheme))
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
