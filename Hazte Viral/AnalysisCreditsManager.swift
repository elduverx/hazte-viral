//
//  AnalysisCreditsManager.swift
//  Hazte Viral
//
//  Created by Claude Code on 19/1/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AnalysisCreditsManager: ObservableObject {
    static let shared = AnalysisCreditsManager()

    // MARK: - Published Properties
    @Published var monthlyUsage: Int = 0
    @Published var lastResetDate: Date = Date()

    // MARK: - Constants
    private let freeMonthlyLimit = 3
    private let userDefaults = UserDefaults.standard

    // MARK: - UserDefaults Keys
    private let monthlyUsageKey = "analysis_monthly_usage"
    private let lastResetKey = "analysis_last_reset"

    // MARK: - Initialization
    init() {
        loadCreditsData()
        checkMonthlyReset()
    }

    // MARK: - Public Interface

    /// Calcula cuántos análisis quedan disponibles
    var remainingAnalyses: Int {
        if SubscriptionManager.shared.isSubscribed {
            return Int.max // Ilimitado para suscritos
        }
        return max(freeMonthlyLimit - monthlyUsage, 0)
    }

    /// Verifica si el usuario puede realizar un análisis
    func canAnalyze() -> Bool {
        if SubscriptionManager.shared.isSubscribed {
            return true
        }
        return monthlyUsage < freeMonthlyLimit
    }

    /// Consume un crédito de análisis
    func consumeAnalysis() {
        // Los usuarios suscritos no consumen créditos
        if SubscriptionManager.shared.isSubscribed {
            return
        }

        monthlyUsage += 1
        saveCreditsData()
    }

    /// Fuerza un reset manual (útil para testing)
    func forceReset() {
        monthlyUsage = 0
        lastResetDate = Date()
        saveCreditsData()
    }

    // MARK: - Private Methods

    private func checkMonthlyReset() {
        let calendar = Calendar.current

        // Si no estamos en el mismo mes, resetear contadores
        if !calendar.isDate(lastResetDate, equalTo: Date(), toGranularity: .month) {
            print("[AnalysisCredits] Nuevo mes detectado - reseteando contador")
            monthlyUsage = 0
            lastResetDate = Date()
            saveCreditsData()
        }
    }

    private func loadCreditsData() {
        monthlyUsage = userDefaults.integer(forKey: monthlyUsageKey)

        if let resetDate = userDefaults.object(forKey: lastResetKey) as? Date {
            lastResetDate = resetDate
        } else {
            // Primera vez: inicializar fecha
            lastResetDate = Date()
            saveCreditsData()
        }

        print("[AnalysisCredits] Datos cargados - Uso mensual: \(monthlyUsage)/\(freeMonthlyLimit)")
    }

    private func saveCreditsData() {
        userDefaults.set(monthlyUsage, forKey: monthlyUsageKey)
        userDefaults.set(lastResetDate, forKey: lastResetKey)

        print("[AnalysisCredits] Datos guardados - Uso mensual: \(monthlyUsage)/\(freeMonthlyLimit)")
    }
}
