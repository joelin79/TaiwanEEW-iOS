//
//  ConnectionStatusButton.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/7/28.
//  About LocalizedStringKey.toString() https://stackoverflow.com/questions/64429554/how-to-get-string-value-from-localizedstringkey

import SwiftUI

struct ConnectionStatusButton: View {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var monitor = NetworkMonitor()
    @State private var isConnectedToInternet = false
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    func timeString(date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600) // Set time zone to GMT+8
            formatter.dateFormat = "MM/dd HH:mm:ss"
            return formatter.string(from: date)
        }
    
    var fontColor: Color {
        colorScheme == .light
        ? Color(hue: 1.0, saturation: 0.0, brightness: 0.167)
        : Color(hue: 1.0, saturation: 0.0, brightness: 0.833)
        
    }
    var panelFill: Color {
        colorScheme == .light ? .white : Color("Pad")
    }
    let fontSize = 12
    let todayStr = LocalizedStringKey("today-string").toString()
    var lastPingTime: Date
    var subtext: String
    
    init(lastPingTime: Date) {
        self.lastPingTime = lastPingTime
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600) // Set time zone to GMT+8

        if Calendar.current.isDateInToday(lastPingTime) {
            dateFormatter.dateFormat = " HH:mm"
            self.subtext = todayStr + dateFormatter.string(from: lastPingTime)
        } else {
            dateFormatter.dateFormat = "MM/dd HH:mm"
            self.subtext = dateFormatter.string(from: lastPingTime)
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(Color("EqInfoBoarder"))
                )
                .clipped()
            VStack (alignment: .trailing) {
                if !monitor.isConnected {
                    negativeConnection
                } else if (Date().timeIntervalSince(lastPingTime) < 65) {
                    positive
                } else {
                    negativeServer
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
        }
        .frame(width: 150, height: 20)
    }

    var positive: some View {
        NavigationLink {
            ConnectionStatusView()
        } label: {
            HStack(alignment: .center, spacing: 5){
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                Text(timeString(date: currentTime))
                    .font(Font.system(size: CGFloat(fontSize), design: .monospaced))
                    .foregroundColor(fontColor)
                    .onReceive(timer) { input in
                        currentTime = input
                    }
            }
        }
    }
    var negativeServer: some View {
        NavigationLink {
            ConnectionStatusView()
        } label: {
            HStack(alignment: .center, spacing: 5){
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .symbolRenderingMode(.hierarchical)
                Text(subtext)
                    .font(Font.system(size: CGFloat(fontSize), design: .default).weight(.medium))
                .foregroundColor(fontColor)
            }
        }
    }
    var negativeConnection: some View {
        NavigationLink {
            ConnectionStatusView()
        } label: {
            HStack {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .symbolRenderingMode(.hierarchical)
                Text("internet-err-string")
                    .font(Font.system(size: CGFloat(fontSize), design: .default).weight(.medium))
                .foregroundColor(fontColor)
            }
        }
    }
}

struct ConnectionStatusButton_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionStatusButton(lastPingTime: Date())
    }
}

extension LocalizedStringKey {

    /**
     Return localized value of this LocalizedStringKey
     */
    public func toString() -> String {
        //use reflection
        let mirror = Mirror(reflecting: self)
        
        //try to find 'key' attribute value
        let attributeLabelAndValue = mirror.children.first { (arg0) -> Bool in
            let (label, _) = arg0
            if(label == "key"){
                return true;
            }
            return false;
        }
        
        if(attributeLabelAndValue != nil) {
            //ask for localization of found key via NSLocalizedString
            return String.localizedStringWithFormat(NSLocalizedString(attributeLabelAndValue!.value as! String, comment: ""));
        }
        else {
            return "Swift LocalizedStringKey signature must have changed. @see Apple documentation."
        }
    }
}
