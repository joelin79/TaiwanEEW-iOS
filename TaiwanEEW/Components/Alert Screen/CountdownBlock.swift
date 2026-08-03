//
//  TimeBlock.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2022/8/18.
//

import SwiftUI

struct TimeBlock: View {
    let cornerRad: CGFloat = 20
    var arrivalTime: Date
    
    @State private var text: String = ""
    func calcEstTime () -> Int {
        return -Int(Date().timeIntervalSince(arrivalTime))
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRad, style: .continuous)
            .fill(Color("Pad"))
            .clipped()
            .overlay(content)
            // Draw border
            .overlay(RoundedRectangle(cornerRadius: cornerRad)
                .stroke(Color("EqInfoBoarder"), lineWidth: 2))
            .if(UIScreen.isZoomed) { view in
                view.frame(width: 140, height: 140)
            }
            .if(!UIScreen.isZoomed) { view in
                view.frame(width: 170, height: 170)
            }
    }
    
    var content: some View {
        VStack{
            Text("arrival-string")
                .font(.system(size: UIScreen.isZoomed ? 30 : 34).weight(.medium))
            HStack(alignment: .bottom){
                Text( (calcEstTime()>0) ? String(text) : "0")
                    .font(.system(size: (calcEstTime()>99) ? 45 : UIScreen.isZoomed ? 75 : 80, weight: .bold, design: .monospaced))
                    .onReceive(
                        Timer.publish(every: 1, on: .main, in: .common).autoconnect(),
                        perform: { _ in
                            self.text = String(calcEstTime())
                        }
                    )
                Text("seconds-string")
                    .font(.system(size: UIScreen.isZoomed ? 28 : 30, weight: .bold, design: .monospaced ))
            }
        }
    }
}

struct TimeBlock_Previews: PreviewProvider {
    static var previews: some View {
        TimeBlock(arrivalTime: Date())
    }
}
