//
//  ReportDispatcher.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/6/16.
//  * GPT-4o Generated!

import Foundation
import Combine
import os.log

class EarthquakeViewModel: ObservableObject {
    @Published var earthquakes: [EqReport] = []
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "EarthquakeViewModel")
    
    init() {
        // Start the timer to refetch data every 5 minutes
        fetchData()
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refetchData()
            }
    }
        
    deinit {
        timer?.cancel()
    }
    
    func fetchData() {
        fetchEarthquakes(limit: 50)
    }
    
    func refetchData() {
        self.earthquakes = []
        fetchData()
        timer?.cancel()
        startTimer()
    }
    
    // Method to fetch earthquakes from a default URL
    private func fetchEarthquakes(from urlString: String) {
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [EqReport].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self?.logger.error("Error fetching earthquakes: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] fetchedEarthquakes in
                self?.logger.info("Fetched \(fetchedEarthquakes.count) earthquakes")
                if let first = fetchedEarthquakes.first {
                    self?.logger.debug("First earthquake ID: \(first.id)")
                }
                self?.earthquakes = fetchedEarthquakes
            }
            .store(in: &cancellables)
    }
    
    func fetchEarthquakes(limit: Int) {
        fetchEarthquakes(from: "https://api-1.exptech.dev/api/v2/eq/report?limit=\(limit)")
    }
    
    @available(iOS 15.0, *)
    func fetchEarthquakeDetailed(earthquakeID: String) async throws -> EqReportDetailed {
        let urlString = "https://api-1.exptech.dev/api/v2/eq/report/\(earthquakeID)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let detailedReport = try JSONDecoder().decode(EqReportDetailed.self, from: data)
        return detailedReport
    }
    
}

