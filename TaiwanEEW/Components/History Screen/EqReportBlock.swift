//
//  EarthquakeInfoBlock.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/6/25.
//

import SwiftUI

struct EarthquakeInfoBlock: View {
    @Environment(\.colorScheme) var colorScheme
    var e: EqReport
    let cornerRad: CGFloat = 20
    
    
    // MARK: - Displayed Info
    var earthquakeNo: Int { e.getEqNumber() }
    var maxIntensity: String { e.getMaxIntensity() ?? "未知" }
    var location: String { e.getLocationDesc() ?? "未知" }
    var depth: Float { Float(e.depth) }
    var magnitude: Float {
        Float(e.mag)
    }
    
    var originTime: Date {e.getDate()}
    var originTimeFormattedStr: String {
        let dateFormatter = DateFormatter()
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let eventYear = Calendar.current.component(.year, from: originTime)
        
        if currentYear == eventYear {
            dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        } else {
            dateFormatter.dateFormat = "yyyy MM/dd HH:mm:ss"
        }
        return dateFormatter.string(from: originTime)
    }
    
    var isRecent: Bool {
        return originTime > Date().addingTimeInterval(-12 * 60 * 60)
    }
    
    // MARK: Displayed Info -
    
    var body: some View{
        
        Rectangle()
            .frame(width: UIScreen.screenWidth - UIScreen.baseLine-10, height: 90)
            .foregroundColor( Color("Pad") )
            .overlay(
                
                HStack(spacing: 0){
                    
                    // MARK: - Left
                    Spacer().frame(width: 28)
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .frame(width: 50, height: 50)
                            .foregroundStyle( Color(maxIntensity) )
                        // MARK: 最大震度
                        Text(maxIntensity)
                            .font(.system(size: 32))
                            .bold()
                            .foregroundStyle( maxIntensity == "7" || maxIntensity == "6+" || maxIntensity == "6-" || maxIntensity == "5+" ? .white : .black)
                    }
                    .frame(width: 50)
                    
                    // MARK: - Middle
                    Spacer().frame(width: 22)
                    VStack (alignment: .leading){
                        Spacer()
                        // MARK: 震央
                        HStack(spacing: 5){
                            if isRecent {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .yellow)
                            }
                            Text(location)
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor( colorScheme == .dark ? .white : .black)
                        }
                        Spacer().frame(height: 3)
                        // MARK: 時間
                        Text("\(originTimeFormattedStr)")
                            .font(.system(size: 17))
                            .fontWeight(.regular)
                            .foregroundStyle( Color("DescText") )
                            
                            
                        
                        // MARK: 深度
                        Text( String(format: "深度  %.1f  km", depth) )
                            .font(.system(size: 17))
                            .foregroundStyle( Color("DescText") )
                        
                        Spacer()
                    }
                    .frame(width: 170.0, alignment: .leading)
                    
                    // MARK: - Right
                    Spacer().frame(width: 15)
                    VStack(spacing: 2){
                        
                        // MARK: 規模
                        Text( String(format: "M%.1f", magnitude) )
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor( magnitude >= 7 ? .purple : magnitude >= 6 ? .red : magnitude >= 5 ? .orange : colorScheme == .dark ? .white : .black)
                        
                        // MARK: 編號
                        if (earthquakeNo%1000 != 0) {
                            ZStack {
                                Capsule()
                                    .frame(width: 52, height: 22)
                                    .foregroundStyle( Color("Highlighter") )
                                HStack(spacing: 2) {
                                    Image(systemName: "number")
                                        .font(.system(size: 12))
                                    Text(verbatim: "\(earthquakeNo%1000)")
                                        .font(.system(size: 12))
                                }
                            }
                        }
                    }
                    .frame(width: 50)
                    Spacer()
                    
                }
                
                
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRad))
            // Clip rectangle into rounded rectangle
        
            // Draw border
            .overlay(RoundedRectangle(cornerRadius: cornerRad)
                .stroke(Color("EqInfoBoarder"), lineWidth: 1))

    }
}

#Preview {
    EarthquakeInfoBlock(e: MockData.sampleEqReport)
}
