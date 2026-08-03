//
//  MockData.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/6/24.
//

import Foundation

struct MockData {
    static let sampleEqReport: EqReport = EqReport(id: "113019-2024-0403-075809", lat: 23.86, lon: 121.58, depth: 22.5, loc: "花蓮縣政府南南西方  14.9  公里 (位於花蓮縣壽豐鄉)", mag: 7.2, time: 1712102289000, trem: 1712102294611, int: 8, md5: "")
    
    static let sampleEarthquakes: Earthquake =
        Earthquake(
            EarthquakeNo: 113422,
            ReportType: "地震報告",
            ReportColor: "綠色",
            ReportContent: "06/18-11:46花蓮縣近海發生規模4.9有感地震，最大震度花蓮縣太魯閣4級。",
            ReportImageURI: "https://scweb.cwa.gov.tw/webdata/OLDEQ/202406/2024061811465849422_H.png",
            ReportRemark: "本報告係中央氣象署地震觀測網即時地震資料地震速報之結果。",
            Web: "https://scweb.cwa.gov.tw/zh-tw/earthquake/details/2024061811465849422",
            ShakemapImageURI: "https://scweb.cwa.gov.tw/webdata/drawTrace/plotContour/2024/2024422i.png",
            EarthquakeInfo: EarthquakeInfo(
                OriginTime: "2024-06-18 11:46:58",
                Source: "中央氣象署",
                FocalDepth: 12.4,
                Epicenter: Epicenter(
                    Location: "花蓮縣政府東北方  22.2  公里 (位於花蓮縣近海)",
                    EpicenterLatitude: 24.16,
                    EpicenterLongitude: 121.74
                ),
                EarthquakeMagnitude: EarthquakeMagnitude(
                    MagnitudeType: "芮氏規模",
                    MagnitudeValue: 4.9
                )
            ),
            Intensity: Intensity(
                ShakingArea: [
                    ShakingArea(
                        AreaDesc: "南投縣地區",
                        CountyName: "南投縣",
                        InfoStatus: "observe",
                        AreaIntensity: "3級",
                        EqStation: [
                            EqStation(
                                pga: PGA(unit: "gal", EWComponent: 9.42, NSComponent: 8.69, VComponent: 3.49, IntScaleValue: 10.28),
                                pgv: PGV(unit: "kine", EWComponent: 0.41, NSComponent: 0.4, VComponent: 0.21, IntScaleValue: 0.47),
                                StationName: "合歡山",
                                StationID: "WHF",
                                InfoStatus: "observe",
                                BackAzimuth: 88.12,
                                EpicenterDistance: 47.69,
                                SeismicIntensity: "3級",
                                StationLatitude: 24.143,
                                StationLongitude: 121.273,
                                WaveImageURI: "https://scweb.cwa.gov.tw/webdata/drawTrace/outcome/2024/2024422/3-WHF.gif"
                            )
                        ]
                    )
                ]
            )
        )
    
    static let sampleEqReportDetailed: EqReportDetailed = try! EqReportDetailed(
        id: "113403",
        lat: 24.10,
        lon: 121.65,
        depth: 20.5,
        loc: "花蓮縣政府東北方  30.0  公里 (位於花蓮縣近海)",
        mag: 7.2,
        time: 1712115600000,
        list: [
            "花蓮縣": EqReportDetailed.County(
                int: 5,
                town: [
                    "花蓮市": EqReportDetailed.County.Town(lat: 23.97, lon: 121.61, int: 5),
                    "新城鄉": EqReportDetailed.County.Town(lat: 24.07, lon: 121.62, int: 5)
                ]
            ),
            "台中市": EqReportDetailed.County(
                int: 4,
                town: [
                    "北屯區": EqReportDetailed.County.Town(lat: 24.18, lon: 120.69, int: 4)
                ]
            ),
            "南投縣": EqReportDetailed.County(
                int: 4,
                town: [
                    "魚池鄉": EqReportDetailed.County.Town(lat: 23.88, lon: 120.93, int: 4)
                ]
            )
        ],
        trem: 1712115605000
    )
}
