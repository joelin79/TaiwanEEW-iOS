//
//  EventInfoBlock.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/2/15.
//  NOT USED

import SwiftUI

@available(*, deprecated, message: "Future versions no longer show EEW records.")
struct EventInfoBlock: View{
    
    @Environment(\.colorScheme) var colorScheme
    var e: Event
    
    
    var body: some View{
        RoundedRectangle(cornerRadius: 10)
            .frame(width: UIScreen.screenWidth - UIScreen.baseLine-10, height: 100)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            
        // side color bar
            .overlay(
                Rectangle().frame(width: 15, height: 100).foregroundColor(Color(e.intensity)), alignment: .leading
            )
        
        // text
            .overlay(
                
                HStack{
                    Spacer()
                    VStack {
                        Text("est-intensity-string").foregroundColor(.secondary)
                            .bold()
                        Text(e.intensity)
                            .font(.system(size: 32))
                        .bold()
                    }
                    Spacer()
                    Divider().overlay(.gray).frame(height: 70)
                    Spacer()
                    
                    VStack (alignment: .leading){
                        Spacer()
                        Text("time-string").foregroundColor(.secondary)
                        Text(e.eventTime.formatted())
                        Spacer()
                        HStack {
                            Text("est-countdown-string").foregroundColor(.secondary)
                            Text(String(e.seconds))
                        }
                        Spacer()
                    }
                    Spacer()
                    
                }
                
                
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        
        // border
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray3), lineWidth: 1))

    }
}

struct EventInfoBlock_Preview: PreviewProvider{
    static var previews: some View {
        EventInfoBlock(e: Event(id: "testerS", intensity: "4", seconds: 66, eventTime: Date()))
        EventInfoBlock(e: Event(id: "testerS", intensity: "4", seconds: 66, eventTime: Date())).environment(\.locale, Locale.init(identifier: "zh-Hant"))
    }
    
}
