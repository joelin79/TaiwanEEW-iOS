//
//  HistoryView.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/2/14.
//

import SwiftUI

struct HistoryView: View {
    @StateObject var viewModel: EarthquakeViewModel
    @State var pinnedEventID: String? = "113019-2024-0403-075809"
    @Environment(\.colorScheme) var colorScheme
    @State private var showTabBar = true
    let scrollViewVerticalOffset: CGFloat = 115
    let opacityGradientHeight: CGFloat = 20
    let backgroundColor: Color = Color("Background")
    var titleBarColor: Color { backgroundColor.opacity(0.95) }
    
    init(viewModel: EarthquakeViewModel, pinnedEventID: String? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.pinnedEventID = "113019-2024-0403-075809"
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }
            .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
        } else {
            NavigationView { content }
        }
        
    }
    
    // MARK: - Helper Functions
    private func getPinnedEvent() -> EqReport? {
        // Return the specific pinned earthquake from MockData
        return MockData.sampleEqReport
    }
    
    var content: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            VStack(alignment: .leading) {
                Spacer().frame(height: 30)
                ScrollView {
                    LazyVStack {
                        Spacer().frame(height: scrollViewVerticalOffset)
                        
                        
                        // Show pinned event if available
                        if let pinnedEvent = getPinnedEvent() {
                            PinnedEventBlock(e: pinnedEvent, viewModel: viewModel)
                                .frame(maxWidth: .infinity)
                        }
                        
                        ForEach(viewModel.earthquakes) { earthquake in
                            if #available(iOS 17, *) {
                                NavigationLink(
                                    destination:
                                        HistoryDetailsView(initialEarthquake: earthquake, viewModel: viewModel)
                                        .onAppear{
                                            withAnimation {
                                                showTabBar = false
                                            }
                                        }
                                        .onDisappear(){
                                            withAnimation {
                                                showTabBar = true
                                            }
                                        }
                                ) {
                                    EarthquakeInfoBlock(e: earthquake)
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                }
                            } else {
                                // Fallback on earlier versions, no details page
                                EarthquakeInfoBlock(e: earthquake)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        LinkCWAHistoryButton()
                            .frame(maxWidth: .infinity)
                        Spacer().frame(height: scrollViewVerticalOffset)
                    }
                }
                .refreshable {
                    viewModel.refetchData()
                }
            }
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("地震報告")
                    .font(.largeTitle)
                    .bold()
                    .padding([.leading, .trailing, .top])
                    .padding(.bottom, 10.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(titleBarColor)
                
                Rectangle()
                    .frame(maxWidth: .infinity, maxHeight: opacityGradientHeight)
                    .foregroundStyle(titleBarColor)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [titleBarColor, backgroundColor.opacity(0)]), startPoint: .top, endPoint: .bottom)
                    )
            }
        }
    }
}



#Preview {
    let vm = EarthquakeViewModel()
    return HistoryView(viewModel: vm, pinnedEventID: "113019-2024-0403-075809")
}
