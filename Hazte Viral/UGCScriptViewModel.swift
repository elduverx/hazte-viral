//
//  UGCScriptViewModel.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import Foundation
import SwiftUI
import Combine

/// Lo que el usuario rellena en el formulario. Se guarda como borrador para no perderlo.
struct ScriptBrief: Codable, Equatable {
    var nicheID = BusinessNiche.allCases[0].id
    /// Lo que escribe el usuario al elegir "Otro".
    var customNiche = ""
    var businessType = ""
    var productService = ""
    var targetAudience = ""
    var benefits: [String] = [""]
    var duration: ScriptDuration = .medium
    var hookType: HookType = .question
    var tone: ScriptTone = .authentic
    var count = 2

    init() {}

    // Decodificación tolerante: los borradores guardados antes de añadir un campo siguen sirviendo.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ScriptBrief()
        nicheID = (try? c.decode(String.self, forKey: .nicheID)) ?? defaults.nicheID
        customNiche = (try? c.decode(String.self, forKey: .customNiche)) ?? ""
        businessType = (try? c.decode(String.self, forKey: .businessType)) ?? ""
        productService = (try? c.decode(String.self, forKey: .productService)) ?? ""
        targetAudience = (try? c.decode(String.self, forKey: .targetAudience)) ?? ""
        benefits = (try? c.decode([String].self, forKey: .benefits)) ?? defaults.benefits
        duration = (try? c.decode(ScriptDuration.self, forKey: .duration)) ?? defaults.duration
        hookType = (try? c.decode(HookType.self, forKey: .hookType)) ?? defaults.hookType
        tone = (try? c.decode(ScriptTone.self, forKey: .tone)) ?? defaults.tone
        count = (try? c.decode(Int.self, forKey: .count)) ?? defaults.count
    }

    static let maxBenefits = 5
    static let countRange = 1...3

    var filledBenefits: [String] {
        benefits.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var isCustomNiche: Bool { nicheID == BusinessNiche.otherID }

    /// Nombre legible del nicho que se envía a la IA.
    var nicheName: String {
        isCustomNiche ? customNiche.trimmed : (BusinessNiche.named(nicheID)?.name ?? nicheID)
    }

    /// Qué falta del paso 1, o nil si está completo.
    var missingBusinessField: String? {
        if isCustomNiche && customNiche.trimmed.isEmpty { return "tu nicho" }
        if businessType.trimmed.isEmpty { return "el tipo de negocio" }
        if productService.trimmed.isEmpty { return "el producto o servicio" }
        if targetAudience.trimmed.isEmpty { return "el público objetivo" }
        if filledBenefits.isEmpty { return "al menos un beneficio" }
        return nil
    }

    var request: ScriptGenerationRequest {
        ScriptGenerationRequest(
            businessType: businessType.trimmed,
            productService: productService.trimmed,
            targetAudience: targetAudience.trimmed,
            duration: duration,
            hookType: hookType,
            tone: tone,
            keyBenefits: filledBenefits,
            niche: nicheName
        )
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

@MainActor
final class UGCScriptViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case business, style, results

        var title: String {
            switch self {
            case .business: return "Negocio"
            case .style: return "Estilo"
            case .results: return "Guiones"
            }
        }
    }

    @Published var brief: ScriptBrief { didSet { saveDraft() } }
    @Published var step: Step = .business
    @Published private(set) var results: [UGCScript] = []
    @Published private(set) var isGenerating = false
    @Published private(set) var generationStage: ScriptGenerationStage = .sending
    @Published var errorMessage: String?
    @Published var showPaywall = false

    let library: ScriptLibrary
    let quota: ScriptQuota
    private let scriptService: UGCScriptGenerating
    private let subscription: SubscriptionManager
    private var generationTask: Task<[UGCScript], Error>?

    private static let draftKey = "ugc_brief_draft"

    init(scriptService: UGCScriptGenerating? = nil,
         library: ScriptLibrary? = nil,
         quota: ScriptQuota? = nil,
         subscription: SubscriptionManager? = nil) {
        self.scriptService = scriptService ?? ClaudeUGCScriptService()
        self.library = library ?? .shared
        self.quota = quota ?? .shared
        self.subscription = subscription ?? .shared
        if let data = UserDefaults.standard.data(forKey: Self.draftKey),
           let draft = try? JSONDecoder().decode(ScriptBrief.self, from: data) {
            brief = draft
        } else {
            brief = ScriptBrief()
        }
    }

    var isSubscribed: Bool { subscription.isSubscribed }

    // MARK: - Navegación

    func continueToStyle() {
        if let missing = brief.missingBusinessField {
            errorMessage = "Falta \(missing)."
            return
        }
        step = .style
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func startOver() {
        results = []
        step = .business
    }

    // MARK: - Beneficios

    func addBenefit() {
        guard brief.benefits.count < ScriptBrief.maxBenefits else { return }
        brief.benefits.append("")
    }

    func removeBenefit(at index: Int) {
        guard brief.benefits.indices.contains(index), brief.benefits.count > 1 else { return }
        brief.benefits.remove(at: index)
    }

    // MARK: - Generación

    func generate() async {
        if let missing = brief.missingBusinessField {
            errorMessage = "Falta \(missing)."
            step = .business
            return
        }
        guard quota.canGenerate(isSubscribed: isSubscribed) else {
            showPaywall = true
            return
        }

        generationStage = .sending
        isGenerating = true
        defer {
            isGenerating = false
            generationTask = nil
        }

        let service = scriptService
        let request = brief.request
        let count = brief.count
        let task = Task {
            try await service.generateScripts(request: request, count: count) { [weak self] stage in
                self?.generationStage = stage
            }
        }
        generationTask = task

        do {
            let scripts = try await task.value
            quota.recordGeneration(isSubscribed: isSubscribed)
            library.add(scripts)
            results = scripts
            step = .results
        } catch is CancellationError {
            // Cancelado por el usuario: no consume cuota.
        } catch let error as URLError where error.code == .cancelled {
            // Ídem.
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
    }

    // MARK: - Borrador

    private func saveDraft() {
        guard let data = try? JSONEncoder().encode(brief) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftKey)
    }
}
