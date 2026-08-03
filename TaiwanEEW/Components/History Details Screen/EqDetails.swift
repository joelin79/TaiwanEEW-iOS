//
//  EqDetails.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/16.
//

import SwiftUI

@available(iOS 17, *)
struct EqDetails: View {
    @EnvironmentObject var uiModel: UIModel
    @StateObject var viewModel: HistoryDetailsViewModel
    @State private var previousScrollOffset: CGFloat = 0
    @State private var closeOpacity: Double = 0
    @Binding var sheetPresented: Bool
    let minimumOffset: CGFloat = 5
    
    var body: some View {
        ScrollView(){
            LazyVStack(alignment: .leading, pinnedViews: [.sectionHeaders]) {
                Section {
                    RoundedRectangle(cornerRadius: 15.0)
                        .frame(width: UIScreen.screenWidth - UIScreen.baseLine * 2, height: 100)
                        .foregroundStyle(Color(viewModel.maxInt))
                        .overlay {
                            HStack(alignment: .bottom, spacing: 0){
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("最大震度")
                                        .font(.system(size: 20))
                                        .fontWeight(.bold)
                                    Text("Max Intensity")
                                        .font(.system(size: 14))
                                        .fontWeight(.light)
                                        .frame(height: 12)
                                }
                                Spacer().frame(width: 10)
                                Text(viewModel.maxInt.prefix(1))
                                    .font(.custom("JetBrainsMono-Bold", size: 60))
                                    .fontWeight(.bold)
                                    .frame(height: 45)
                                if viewModel.maxIntVal >= 5 {
                                    Text(String(viewModel.maxInt.suffix(1))
                                        .replacingOccurrences(of: "-", with: "弱")
                                        .replacingOccurrences(of: "+", with: "強"))
                                    .font(.system(size: 24))
                                    .fontWeight(.bold)
                                }
                                
                                
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("規模")
                                        .font(.system(size: 20))
                                        .fontWeight(.bold)
                                    Text("Magnitude")
                                        .font(.system(size: 14))
                                        .fontWeight(.light)
                                        .frame(height: 12)
                                }
                                Spacer().frame(width: 10)
                                HStack(alignment: .firstTextBaseline, spacing: 0){
                                    let numberString = String(viewModel.mag)
                                    if let firstCharacter = numberString.first, let _ = Int(String(firstCharacter)) {
                                        Text("\(firstCharacter)")
                                            .font(.custom("JetBrainsMono-Bold", size: 60))
                                            .frame(height: 45)
                                        Rectangle()
                                            .frame(width: 7, height: 7)
                                    }
                                    if let decimalIndex = numberString.firstIndex(of: ".") {
                                        let firstDecimalIndex = numberString.index(after: decimalIndex)
                                        if firstDecimalIndex < numberString.endIndex, let firstDecimalDigit = Int(String(numberString[firstDecimalIndex])) {
                                            Text("\(firstDecimalDigit)")
                                                .font(.custom("JetBrainsMono-Bold", size: 60))
                                                .frame(height: 45)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .foregroundStyle(viewModel.maxIntVal >= 6 ? .white : .black)
                        }
                    Spacer().frame(height: 20)
                    
                    DescText(title: "震源地", subtitle: "Origin", val: viewModel.origin, unit: "", widthRatio: 0.9, smallText: true)
                    Spacer().frame(height: 20)
                    DescText(title: "深度", subtitle: "Depth", val: viewModel.depth, unit: "km", widthRatio: 0.9, smallText: false)
                    Spacer().frame(height: 20)
                    Rectangle()
                        .frame(width: UIScreen.screenWidth * 0.9, height: 1)
                        .foregroundStyle(Color("SecondaryField"))
                    Spacer().frame(height: 20)
                    if let detailedEarthquake = viewModel.detailedEarthquake {
                        CountyIntensityListView(earthquakeData: detailedEarthquake)
                    } else {
                        HStack{
                            ProgressView()
                                .padding(5)
                            Text("Loading")
                                .font(.custom("JetBrainsMono-Regular", size: 16))
                        }
                    }
                } header: {
                    header
                        .zIndex(1)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ViewOffsetKey.self, value: -proxy.frame(in: .named("container")).origin.y)
            })
            .onPreferenceChange(ViewOffsetKey.self) { currentOffset in
                let offsetDifference: CGFloat = self.previousScrollOffset - currentOffset
                if (abs(offsetDifference) > minimumOffset) {
                    self.previousScrollOffset = currentOffset
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
        .frame(width: UIScreen.screenWidth)
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "container")
        
        
    }
    
    var header: some View {
        VStack(alignment: .leading){
            HStack(alignment: .bottom) {
                Text("各地震度情報")
                    .font(.system(size: 28).bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("\(viewModel.originTimeFormattedStr) 發生")
                .foregroundStyle(Color("TimeText"))
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 17)
        .padding(.bottom, 10)
        .background(Rectangle().fill(.background))
        
        // The division bar under header
        .overlay(
            Rectangle()
                .frame(width: nil, height: 0.5, alignment: .top)
                .foregroundColor(Color("lightGrey").opacity((previousScrollOffset - minimumOffset) / Double(10))),
        alignment: .bottom)
        .onChange(of: uiModel.selectedDetent) {
            withAnimation(.easeOut(duration: 0.2)) {
                closeOpacity = uiModel.selectedDetent == .height(200) ? 0 : 1
            }
        }
    }
    
    
    struct CountyIntensityListView: View {
        let earthquakeData: EqReportDetailed
        let columnsCount = 3
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sortedCounties, id: \.key) { county, countyData in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(county)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let sortedTowns = sortedTowns(for: countyData)
                        ForEach(0..<(sortedTowns.count + columnsCount - 1) / columnsCount, id: \.self) { rowIndex in
                            HStack(spacing: 3) {
                                ForEach(0..<columnsCount, id: \.self) { columnIndex in
                                    let index = rowIndex * columnsCount + columnIndex
                                    if index < sortedTowns.count {
                                        let (town, townData) = sortedTowns[index]
                                        TownIntensityView(town: town, intensity: townData.int)
                                    } else {
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(width: UIScreen.screenWidth-UIScreen.baseLine*2)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            }
        }
        
        private var sortedCounties: [(key: String, value: EqReportDetailed.County)] {
            earthquakeData.list.sorted { $0.value.int > $1.value.int }
        }
        
        private func sortedTowns(for county: EqReportDetailed.County) -> [(key: String, value: EqReportDetailed.County.Town)] {
            county.town.sorted { $0.value.int > $1.value.int }
        }
    }

    struct TownIntensityView: View {
        let town: String
        let intensity: Int
        
        var body: some View {
            HStack(spacing: 3){
                Text(town)
                    .font(.subheadline)
                    .lineLimit(1)
                IntensityBadge(intensity: intensity)
            }
            .frame(maxWidth: .infinity)
        }
    }

    struct IntensityBadge: View {
        let intensity: Int
        
        var body: some View {
            Text(intensityString)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(intensityColor)
                .foregroundStyle(intensity >= 5 ? .white : .black)
                .clipShape(Capsule())
        }
        
        private var intensityString: String {
            switch intensity {
            case 0: return "0"
            case 1: return "1"
            case 2: return "2"
            case 3: return "3"
            case 4: return "4"
            case 5: return "5⁻"
            case 6: return "5⁺"
            case 7: return "6⁻"
            case 8: return "6⁺"
            case 9: return "7"
            default: return "?"
            }
        }
        
        private var intensityColor: Color {
            switch intensity {
            case 0: return .gray
            case 1: return Color("1")
            case 2: return Color("2")
            case 3: return Color("3")
            case 4: return Color("4")
            case 5: return Color("5-")
            case 6: return Color("5+")
            case 7: return Color("6-")
            case 8: return Color("6+")
            case 9: return Color("7")
            default: return .gray
            }
        }
    }

    
    private struct DescText: View {
        let title: String
        let subtitle: String
        let val: String
        let unit: String
        let widthRatio: CGFloat
        let smallText: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0){
                HStack {
                    HStack{
                        VStack(alignment: .leading) {
                            Text(title)
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                            Text(subtitle)
                                .font(.system(size: 12))
                                .fontWeight(.light)
                        }.frame(width: 70, alignment: .leading)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 5){
                            Text(val)
                                .font(.system(size: smallText ? 28 : 30))
                            Text(unit)
                                .font(.system(size: 30))
                                .frame(height: 10)
                        }
                        
                    }
                }
                .frame(height: 35)
            }
        }
    }
    
    struct ViewOffsetKey: PreferenceKey {
        typealias Value = CGFloat
        static var defaultValue = CGFloat.zero
        static func reduce(value: inout Value, nextValue: () -> Value) {
            value += nextValue()
        }
    }
}


#Preview {
    if #available(iOS 17, *) {
//        EqDetails.CountyIntensityListView(earthquakeData: PreviewData.createSampleData())
        EqDetails(viewModel: HistoryDetailsViewModel(initialEarthquake: EqReport(id: "113019-2024-0403-075809", lat: 23.86, lon: 121.58, depth: 22.5, loc: "花蓮縣政府南南西方  14.9  公里 (位於花蓮縣壽豐鄉)", mag: 6.2, time: 1712102289000, trem: 1712102294611, int: 8, md5: ""), earthquakeViewModel: EarthquakeViewModel()), sheetPresented: .constant(true))
            .environmentObject(UIModel())
    } else {
        // Fallback on earlier versions
    }
}

// Create sample data struct
private struct PreviewData {
    static let hualienTowns: [String: EqReportDetailed.County.Town] = [
        "壽豐鄉": .init(lat: 23.86, lon: 121.58, int: 8),
        "花蓮市": .init(lat: 23.97, lon: 121.60, int: 7),
        "吉安鄉": .init(lat: 23.95, lon: 121.58, int: 7)
    ]
    
    static let yilanTowns: [String: EqReportDetailed.County.Town] = [
        "南澳鄉": .init(lat: 24.46, lon: 121.80, int: 6),
        "蘇澳鎮": .init(lat: 24.59, lon: 121.85, int: 5),
        "冬山鄉": .init(lat: 24.63, lon: 121.79, int: 4)
    ]
    
    static let taipeiTowns: [String: EqReportDetailed.County.Town] = [
        "信義區": .init(lat: 25.03, lon: 121.57, int: 4),
        "大安區": .init(lat: 25.02, lon: 121.54, int: 3),
        "中正區": .init(lat: 25.03, lon: 121.52, int: 3)
    ]
    
    static let countyList: [String: EqReportDetailed.County] = [
        "花蓮縣": .init(int: 8, town: hualienTowns),
        "宜蘭縣": .init(int: 6, town: yilanTowns),
        "台北市": .init(int: 4, town: taipeiTowns)
    ]
    
    static func createSampleData() -> EqReportDetailed {
        let jsonData = """
        {
            "id": "sample-001",
            "lat": 23.86,
            "lon": 121.58,
            "depth": 22.5,
            "loc": "花蓮縣政府南南西方 14.9 公里 (位於花蓮縣壽豐鄉)",
            "mag": 6.2,
            "time": 1712102289000,
            "list": \(try! JSONSerialization.data(withJSONObject: countyList).toString()),
            "trem": 1712102294611
        }
        """.data(using: .utf8)!
        
        return try! JSONDecoder().decode(EqReportDetailed.self, from: jsonData)
    }
}

extension Data {
    func toString() -> String {
        return String(data: self, encoding: .utf8) ?? "{}"
    }
}
