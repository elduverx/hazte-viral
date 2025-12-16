//
//  HistoryStore.swift
//  goviiral
//
//  Created by OpenAI Assistant on 8/12/25.
//

import Foundation
import Combine

final class HistoryStore: ObservableObject {
    @Published private(set) var reports: [AnalysisReport] = []

    private let storageKey = "analysis_history"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        load()
    }

    func add(_ report: AnalysisReport) {
        reports.insert(report, at: 0)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? decoder.decode([AnalysisReport].self, from: data) {
            reports = decoded
        }
    }

    private func persist() {
        let data = try? encoder.encode(reports)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
