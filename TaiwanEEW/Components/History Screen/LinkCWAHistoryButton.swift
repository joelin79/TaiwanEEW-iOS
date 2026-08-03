//
//  LinkCWAHistoryButton.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/6/26.
//

import SwiftUI

struct LinkCWAHistoryButton: View {
    let cornerRad: CGFloat = 20
    let url: String = "https://scweb.cwa.gov.tw/zh-tw/earthquake/data/"
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            RoundedRectangle(cornerRadius: cornerRad)
                .frame(width: UIScreen.screenWidth - UIScreen.baseLine-10, height: 45)
                .foregroundColor( Color("Pad") )
                .overlay {
                    HStack{
                        Image(systemName: "arrow.up.forward.app")
                        Text("查看更多地震報告")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.blue)
                }
            // Draw border
            .overlay(RoundedRectangle(cornerRadius: cornerRad)
                .stroke(Color("EqInfoBoarder"), lineWidth: 1))
        }
    }
}

#Preview {
    LinkCWAHistoryButton()
}
