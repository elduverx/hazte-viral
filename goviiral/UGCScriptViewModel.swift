//
//  UGCScriptViewModel.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class UGCScriptViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var generatedScripts: [UGCScript] = []
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showScriptDetail = false
    @Published var selectedScript: UGCScript?
    
    // Form inputs
    @Published var selectedNiche: BusinessNiche = BusinessNiche.allCases[0]
    @Published var businessType = ""
    @Published var productService = ""
    @Published var targetAudience = ""
    @Published var selectedDuration: ScriptDuration = .medium
    @Published var selectedHookType: HookType = .question
    @Published var selectedTone: ScriptTone = .professional
    @Published var keyBenefits: [String] = ["", "", ""]
    @Published var scriptCount = 3
    
    // MARK: - Services
    private let scriptService: UGCScriptGenerating
    let creditsManager: CreditsManager
    
    init(scriptService: UGCScriptGenerating = ClaudeUGCScriptService(), creditsManager: CreditsManager = CreditsManager.shared) {
        self.scriptService = scriptService
        self.creditsManager = creditsManager
    }
    
    // MARK: - Actions
    func generateScripts() async {
        guard validateInputs() else { return }
        
        // Check credits/subscription
        guard await creditsManager.canGenerateScripts(count: scriptCount) else {
            if creditsManager.availableCredits < scriptCount {
                errorMessage = "No tienes suficientes créditos. Necesitas \(scriptCount) créditos."
            } else {
                errorMessage = "Suscríbete para generar más de 3 guiones al mes."
            }
            showError = true
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            let request = ScriptGenerationRequest(
                businessType: businessType,
                productService: productService,
                targetAudience: targetAudience,
                duration: selectedDuration,
                hookType: selectedHookType,
                tone: selectedTone,
                keyBenefits: keyBenefits.filter { !$0.isEmpty },
                niche: selectedNiche.id
            )
            
            let scripts = try await scriptService.generateMultipleScripts(request: request, count: scriptCount)
            
            await creditsManager.consumeCredits(scriptCount)
            generatedScripts = scripts
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isGenerating = false
    }
    
    func selectScript(_ script: UGCScript) {
        selectedScript = script
        showScriptDetail = true
    }
    
    func addBenefit() {
        if keyBenefits.count < 5 {
            keyBenefits.append("")
        }
    }
    
    func removeBenefit(at index: Int) {
        if keyBenefits.count > 1 {
            keyBenefits.remove(at: index)
        }
    }
    
    func clearForm() {
        businessType = ""
        productService = ""
        targetAudience = ""
        keyBenefits = ["", "", ""]
        generatedScripts = []
        selectedScript = nil
    }
    
    // MARK: - Private Methods
    private func validateInputs() -> Bool {
        if businessType.isEmpty {
            errorMessage = "Especifica el tipo de negocio"
            showError = true
            return false
        }
        
        if productService.isEmpty {
            errorMessage = "Describe tu producto o servicio"
            showError = true
            return false
        }
        
        if targetAudience.isEmpty {
            errorMessage = "Define tu público objetivo"
            showError = true
            return false
        }
        
        if keyBenefits.allSatisfy({ $0.isEmpty }) {
            errorMessage = "Añade al menos un beneficio clave"
            showError = true
            return false
        }
        
        return true
    }
}

// MARK: - Credits Manager
@MainActor
final class CreditsManager: ObservableObject {
    static let shared = CreditsManager()
    
    @Published var availableCredits: Int = 0
    @Published var monthlyUsage: Int = 0
    @Published var lastResetDate: Date = Date()
    
    private let freeMonthlyLimit = 3
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadCreditsData()
        checkMonthlyReset()
    }
    
    func canGenerateScripts(count: Int) async -> Bool {
        // If subscribed, always allow
        if await SubscriptionManager.shared.isSubscribed {
            return true
        }
        
        // Check monthly free limit
        return monthlyUsage + count <= freeMonthlyLimit
    }
    
    func consumeCredits(_ count: Int) async {
        if await SubscriptionManager.shared.isSubscribed {
            // Subscribers don't consume credits
            return
        }
        
        monthlyUsage += count
        saveCreditsData()
    }
    
    func purchaseCredits(_ count: Int) {
        availableCredits += count
        saveCreditsData()
    }
    
    private func checkMonthlyReset() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, equalTo: Date(), toGranularity: .month) {
            monthlyUsage = 0
            lastResetDate = Date()
            saveCreditsData()
        }
    }
    
    private func loadCreditsData() {
        availableCredits = userDefaults.integer(forKey: "ugc_credits")
        monthlyUsage = userDefaults.integer(forKey: "ugc_monthly_usage")
        if let resetDate = userDefaults.object(forKey: "ugc_last_reset") as? Date {
            lastResetDate = resetDate
        }
    }
    
    private func saveCreditsData() {
        userDefaults.set(availableCredits, forKey: "ugc_credits")
        userDefaults.set(monthlyUsage, forKey: "ugc_monthly_usage")
        userDefaults.set(lastResetDate, forKey: "ugc_last_reset")
    }
}

// MARK: - Script Templates
extension UGCScriptViewModel {
    static let predefinedTemplates: [String: [ScriptTemplate]] = [
        "restaurant": [
            ScriptTemplate(
                title: "Plato Signature",
                structure: "Hook: Ingrediente secreto → Proceso → Resultado → CTA",
                niche: "restaurant",
                duration: .medium,
                hookType: .question,
                cta: "Reserva tu mesa"
            ),
            ScriptTemplate(
                title: "Experiencia Gastronómica",
                structure: "Hook: Momento wow → Ambiente → Sabores → CTA",
                niche: "restaurant",
                duration: .long,
                hookType: .result,
                cta: "Vive la experiencia"
            )
        ],
        "beauty": [
            ScriptTemplate(
                title: "Transformación",
                structure: "Hook: Antes → Proceso → Después → CTA",
                niche: "beauty",
                duration: .medium,
                hookType: .result,
                cta: "Reserva tu cita"
            ),
            ScriptTemplate(
                title: "Tratamiento Exclusivo",
                structure: "Hook: Problema común → Solución única → Beneficios → CTA",
                niche: "beauty",
                duration: .short,
                hookType: .problem,
                cta: "Descubre el tratamiento"
            )
        ],
        "vtc": [
            ScriptTemplate(
                title: "Viaje Premium",
                structure: "Hook: Experiencia VIP → Comodidades → Diferencias → CTA",
                niche: "vtc",
                duration: .medium,
                hookType: .question,
                cta: "Reserva tu viaje"
            )
        ],
        "realestate": [
            ScriptTemplate(
                title: "Tour Virtual",
                structure: "Hook: Propiedad única → Tour → Características → CTA",
                niche: "realestate",
                duration: .long,
                hookType: .result,
                cta: "Programa tu visita"
            )
        ],
        "fitness": [
            ScriptTemplate(
                title: "Transformación Fitness",
                structure: "Hook: Resultado → Proceso → Método → CTA",
                niche: "fitness",
                duration: .medium,
                hookType: .result,
                cta: "Inicia tu transformación"
            )
        ],
        "fashion": [
            ScriptTemplate(
                title: "Look del Día",
                structure: "Hook: Tendencia → Combinaciones → Styling → CTA",
                niche: "fashion",
                duration: .short,
                hookType: .question,
                cta: "Descubre tu estilo"
            )
        ],
        "tech": [
            ScriptTemplate(
                title: "Problema-Solución",
                structure: "Hook: Pain Point → Demo → Beneficios → CTA",
                niche: "tech",
                duration: .medium,
                hookType: .problem,
                cta: "Prueba gratis"
            )
        ],
        "education": [
            ScriptTemplate(
                title: "Tip Educativo",
                structure: "Hook: Stat sorprendente → Explicación → Aplicación → CTA",
                niche: "education",
                duration: .short,
                hookType: .question,
                cta: "Aprende más"
            )
        ]
    ]
    
    func getTemplatesForNiche(_ niche: String) -> [ScriptTemplate] {
        return Self.predefinedTemplates[niche] ?? []
    }
}