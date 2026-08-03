//
//  Legend.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/8.
//

import SwiftUI

struct Legend: View {
    let maxIntensityValue: Int
    func legendHeight() -> CGFloat {
        let totalBlock = 20 * maxIntensityValue
        let maxLable = 10
        let totalSpacing = 5 * (maxIntensityValue - 1)
        let padding = 5
        return CGFloat(totalBlock + maxLable + totalSpacing + padding)
    }
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .center)){
            RoundedRectangle(cornerRadius: 6)
                .frame(width: 28, height: legendHeight() + 3)      // +3 pixels for stroke
                .foregroundStyle(Color("EqInfoBoarder"))
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 25, height: legendHeight())
                .foregroundStyle(Color("Pad"))
            VStack(alignment: .center, spacing: 0){
                Text("Max")
                    .frame(height: 7, alignment: .center)
                    .font(.system(size: 9).monospaced().bold())
                    .padding(.bottom, 3)
                VStack(alignment: .center, spacing: 5){
                    ForEach((0...maxIntensityValue).reversed(), id: \.self) { intensity in
                        if intensity != 0 {
                            shindoBox(shindo: intensity)
                        }
                    }
                }
            }
        }
    }
}

struct shindoBox: View {
    let shindo: String
    
    init(shindo: Int){
        self.shindo = EEWService.intensityValueToString(int: shindo)
    }
    
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 3)
                .frame(width: 20, height: 20)
                .foregroundStyle(Color(shindo))
            if (Int(shindo.prefix(1))! == 5 || Int(shindo.prefix(1))! == 6) {
                HStack(alignment: .center ,spacing: 0){
                    Text(shindo.prefix(1))
                    Text(shindo.suffix(1).replacingOccurrences(of: "-", with: "–"))
                        .offset(y: -2)
                        
                }
                .font(.system(size: 12).bold())
                .foregroundStyle(.white)
            } else {
                Text(shindo)
                    .font(.system(size: 12).bold())
                    .foregroundStyle(Int(shindo.prefix(1))!>4 ? .white : .black)
            }
                
        }
    }
}

#Preview {
    Legend(maxIntensityValue: 3)
}
