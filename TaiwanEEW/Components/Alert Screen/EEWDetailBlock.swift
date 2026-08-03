//
//  EEWDetailBlock.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/5.
//

import SwiftUI
import XMLCoder
import CoreLocation
import os.log

struct EEWDetailBlock: View {
    let cornerRad: CGFloat = 10
    @ObservedObject var eventManager: EventDispatcher
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "EEWDetailBlock")
    
    
    var originTime: Date {eventManager.originTime}
    var publishedTime: Date {eventManager.publishedTime}
    var arrivalTime: Date {eventManager.arrivalTime}
    var status: String? {eventManager.event.last?.status.lowercased()}
    var msgType: String? {eventManager.event.last?.msgType.lowercased()}
    
    @State private var locationName: String? = nil
    var maxInt: String {eventManager.maxIntensity}
    var magnitude: Double {eventManager.magnitude}
    var depth: Double {eventManager.depth}
    var intensity: String {eventManager.intensity}
    var eqSeq: Int {eventManager.eqSeq}
    var lonB: Double {eventManager.lonB}
    var latB: Double {eventManager.latB}
    var pgaAdj: Double {eventManager.pgaAdj}
    
    var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        return formatter
    }()
    
    var originTimeFormattedStr: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let eventYear = Calendar.current.component(.year, from: originTime)
        
        if currentYear == eventYear {
            dateFormatter.dateFormat = "MM/dd HH:mm:ss"
        } else {
            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        }
        return dateFormatter.string(from: originTime)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            if Device.deviceType == .ipad {
                Spacer()
            }
            pageTitle
            AlertStatusBar(arrivalTime: arrivalTime, intensity: intensity)
                .padding(.top, 10)
                .padding(.horizontal, UIScreen.baseLine)
            alertInfo
                .padding(.top, 10)
//            EEWDetailBlock(eventManager: eventManager)
//                .padding(.bottom, 10)
            
            
//                arrivalClockTimeBar.offset(x:UIScreen.baseLine)   TODO: Remove
            Spacer()
//                testflightReminder.padding()
        }
        .onAppear {
            updateLocationName()
        }.onChange(of: [lonB, latB]) { _ in
            updateLocationName()
        }
    }
    
    
    private var pageTitle: some View {
        VStack(alignment: .leading, spacing: 0){
            HStack(alignment: .lastTextBaseline){
                var title: String {
                    if(status == "exercise"){
                        return "演練 Drill"
                    } else if(status == "test" && !TaiwanEEWApp.DEBUG){
                        return "測試中 Testing"
                    } else if (msgType == "system") {
                        return "系統 System"
                    } else if(msgType == "cancel"){
                        return "預警取消 Canceled"
                    } else if(msgType == "error"){
                        return "預警錯誤 Error"
                    } else {
                        return NSLocalizedString("地震速報", comment: "")     // localize "alert-title-string"
                    }
                }
                Text(title).font(.system(size: UIScreen.isZoomed ? 23 : 28).bold())
                    .frame(height: 25)
                Text("/ 第\(eqSeq)報")
                    .foregroundStyle(Color("TimeText"))
                    .font(.system(size: UIScreen.isZoomed ? 12 : 18))
                Spacer()
                HStack(spacing: 0){
                    Image(systemName: "water.waves.and.arrow.down")
                        .font(.system(size: UIScreen.isZoomed ? 20 : 10))
                        .foregroundStyle(Color("TimeText"))
                    Text("\(String(format: "%.1f", depth))km")
                        .font(.system(size: UIScreen.isZoomed ? 12 : 14).monospaced())
                        .foregroundStyle(Color("TimeText"))
                }.frame(height: 0)
                HStack(spacing: 0){
                    Text("M\(String(format: "%.1f", magnitude))").bold().foregroundStyle( magnitude >= 7 ? .purple : magnitude >= 6.5 ? .red : magnitude > 5.5 ? .orange : .primary)
                        .font(.system(size: UIScreen.isZoomed ? 17 : 22).monospaced().bold())
                }.frame(height: 0)
                
//                Spacer()
//                LocationBlock(districtStr: Location.cities[subscribedCityIndex].district[subscribedDistrictIndex].districtName)
            }
            
            HStack(alignment: .firstTextBaseline){
                Text("\(originTimeFormattedStr) 發生")
//                    .offset(y:3)
                    .foregroundStyle(Color("TimeText"))
                    .font(.system(size: UIScreen.isZoomed ? 12 : 18))
                Spacer()
                HStack(spacing:2){
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: UIScreen.isZoomed ? 13 : 21))
                    Text(locationName ?? fetchOceanData(lat: latB, lon: lonB))
                        .font(.system(size: UIScreen.isZoomed ? 14 : 20).bold())
                }
            }
            
        }
        .padding(.horizontal, UIScreen.baseLine)
    }
    
    var alertInfo: some View {
        Group {
            HStack {
                Spacer()
                IntensityBlock(intensity: intensity)
                Spacer()
                TimeBlock(arrivalTime: arrivalTime)
                Spacer()
            }
        }
    }
    
    var arrivalClockTimeBar: some View {
        Group {
            HStack (alignment: .center) {
                ZStack {
                    Rectangle().frame(width: 170.0, height: 40.0).clipped().cornerRadius(/*@START_MENU_TOKEN@*/7.0/*@END_MENU_TOKEN@*/).foregroundColor(Color("Pad"))
                    Text("est-arrival-time-string").font(.system(size:20))
                }
                Text(dateFormatter.string(from: arrivalTime)).font(.system(size: 20))
            }
        }
    }
    
    private func updateLocationName() {
        Task {
            locationName = await fetchLocationName(lat: latB, lon: lonB)
        }
    }
    
    func fetchLocationName(lat: Double, lon: Double) async -> String? {
        let geoCoder = CLGeocoder()
        let twLocale = Locale(identifier: "zh-Hant")
        
        // TODO: temporary Manderin placeholder for all languages before next localization update.
        let location = CLLocation(latitude: lat, longitude: lon)
        
        do {
            let placemarks = try await geoCoder.reverseGeocodeLocation(location, preferredLocale: twLocale)
            if let placemark = placemarks.first,
               let locality = placemark.administrativeArea,
               let subLocality = placemark.locality {
                return "\(locality)\(subLocality)"
            } else {
                return fetchOceanData(lat: lat, lon: lon)
            }
        } catch {
            logger.error("Geocoding error: \(error.localizedDescription)")
            return fetchOceanData(lat: lat, lon: lon)
        }
        

    }
    
    func fetchOceanData(lat: Double, lon: Double)-> String {
        if(lat >= 24.31343 && lon >= 121.76857){
            return "東北部海域"
        }
        if(lat >= 23.43494 && lat <= 24.31343 && lon >= 121){
            return "東部海域"
        }
        if(lat >= 22.24595 && lat <= 23.43494 && lon >= 120.79958){
            return "東南部海域"
        }
        if(lat >= 24.73429 && lon <= 121.76857){
            return "北部海域"
        }
        if(lat >= 23.53352 && lat <= 24.73429 && lon <= 121){
            return "中部海域"
        }
        return "南部海域"
    }
}

//private struct DescText: View {
//    let title: String
//    let subtitle: String
//    let val: String
//    let unit: String
//    let widthRatio: CGFloat
//    let smallText: Bool
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0){
//            HStack {
//                Rectangle()
//                    .frame(width: 3, height: 35)
//                    .foregroundStyle(Color("SecondaryField"))
//                HStack{
//                    VStack(alignment: .leading) {
//                        Text(title)
//                            .font(.system(size: 12))
//                            .fontWeight(.bold)
//                        Text(subtitle)
//                            .font(.system(size: 10))
//                            .fontWeight(.light)
//                    }
//                    Spacer()
//                    HStack(alignment: .firstTextBaseline, spacing: 5){
//                        Text(val)
//                            .font(.system(size: smallText ? 20 : 28))
//                        Text(unit)
//                            .font(.system(size: 18))
//                            .frame(height: 10)
//                    }
//                    
//                }
//            }
//            .frame(width: UIScreen.screenWidth * widthRatio, height: 35)
//            Rectangle()
//                .frame(width: UIScreen.screenWidth * widthRatio, height: 1)
//                .foregroundStyle(Color("SecondaryField"))
//        }
//    }
//}

#Preview {
    VStack {
        // Preview with default values
//        EEWDetailBlock(eventManager: EventDispatcher(subscribedCityIndex: .constant(0), subscribedDistrictIndex: .constant(0)))
        
        // iPad Component
        VStack {
            Spacer()
            EEWDetailBlock(eventManager: EventDispatcher(subscribedCityIndex: .constant(0), subscribedDistrictIndex: .constant(0)))
            Spacer()
        }
        .frame(width: 400, height: 310)
        .background(
            RoundedRectangle(cornerRadius: 35)
                .stroke(Color.blue, lineWidth: 1)
        )
    }
}
