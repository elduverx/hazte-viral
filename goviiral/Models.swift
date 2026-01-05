//
//  Models.swift
//  goviiral
//
//  Created by OpenAI Assistant on 8/12/25.
//

import Foundation

struct EngagementMetrics: Codable, Hashable {
    let retentionScore: Double
    let hookStrength: Double
    let messageClarity: Double
    let pacing: Double
    let viralityProbability: Double

    var averageScore: Double {
        (retentionScore + hookStrength + messageClarity + pacing + viralityProbability) / 5
    }
}

struct AnalysisReport: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let createdAt: Date
    let predictedViews: Int
    let metrics: EngagementMetrics
    let highlights: [String]
    let recommendations: [String]
    let analysisDetails: AnalysisDetails?
    let videoHash: String?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

struct AnalysisDetails: Codable, Hashable {
    let hookAnalysis: String
    let mainTopicIdentified: String
    let emotionDetected: String
    let editingPace: String
    let onScreenTextDetected: String
    let whyWorksOrNot: String
}

enum AnalysisError: LocalizedError {
    case invalidVideo
    case uploadFailed
    case unauthorized
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "No se pudo leer el video."
        case .uploadFailed:
            return "Error al subir el video al analizador."
        case .unauthorized:
            return "Clave API faltante o inválida. Define ANTHROPIC_API_KEY en el entorno o en Info.plist."
        case .server(let message):
            return message
        }
    }
}

// MARK: - UGC Script Maker Models

struct BusinessNiche: Identifiable, Codable, CaseIterable {
    let id: String
    let name: String
    let icon: String
    let description: String
    
    static let allCases: [BusinessNiche] = [
        BusinessNiche(id: "restaurant", name: "Restaurantes", icon: "fork.knife", description: "Platos, ambiente, experiencias gastronómicas"),
        BusinessNiche(id: "beauty", name: "Estética & Belleza", icon: "sparkles", description: "Tratamientos, antes/después, rutinas"),
        BusinessNiche(id: "vtc", name: "VTC & Transporte", icon: "car.fill", description: "Servicios, comodidad, experiencia de viaje"),
        BusinessNiche(id: "realestate", name: "Inmobiliaria", icon: "house.fill", description: "Propiedades, tours, inversiones"),
        BusinessNiche(id: "fitness", name: "Fitness & Deporte", icon: "figure.gymnastics", description: "Entrenamientos, transformaciones, motivación"),
        BusinessNiche(id: "fashion", name: "Moda & Retail", icon: "tshirt.fill", description: "Outfits, tendencias, estilismo"),
        BusinessNiche(id: "tech", name: "Tech & SaaS", icon: "laptopcomputer", description: "Software, apps, soluciones digitales"),
        BusinessNiche(id: "education", name: "Educación", icon: "graduationcap.fill", description: "Cursos, formaciones, skills")
    ]
}

struct ScriptTemplate: Identifiable, Codable {
    let id: UUID
    let title: String
    let structure: String
    let niche: String
    let duration: ScriptDuration
    let hookType: HookType
    let cta: String
    
    init(id: UUID = UUID(), title: String, structure: String, niche: String, duration: ScriptDuration, hookType: HookType, cta: String) {
        self.id = id
        self.title = title
        self.structure = structure
        self.niche = niche
        self.duration = duration
        self.hookType = hookType
        self.cta = cta
    }
}

enum ScriptDuration: String, CaseIterable, Codable {
    case short = "15-30s"
    case medium = "30-60s" 
    case long = "60-90s"
    
    var displayName: String {
        switch self {
        case .short: return "Reel Corto (15-30s)"
        case .medium: return "Reel Medio (30-60s)"
        case .long: return "Reel Largo (60-90s)"
        }
    }
}

enum HookType: String, CaseIterable, Codable {
    case question = "Pregunta"
    case problem = "Problema"
    case result = "Resultado"
    case controversy = "Controversia"
    case story = "Historia"
    
    var description: String {
        switch self {
        case .question: return "¿Sabías que...? ¿Qué pasaría si...?"
        case .problem: return "El mayor error que cometes..."
        case .result: return "Conseguí X en Y tiempo..."
        case .controversy: return "Nadie te dice la verdad sobre..."
        case .story: return "Mi cliente me preguntó..."
        }
    }
}

struct UGCScript: Identifiable, Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let businessType: String
    let productService: String
    let targetAudience: String
    let duration: ScriptDuration
    let hook: String
    let body: [String]
    let cta: String
    let subtitles: [SubtitleSegment]
    let shotList: [ShotInstruction]
    let hookScore: Int
    let niche: String
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var fullScript: String {
        ([hook] + body + [cta]).joined(separator: "\n\n")
    }
}

struct SubtitleSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let startTime: Double
    let endTime: Double
    let position: SubtitlePosition
    
    init(id: UUID = UUID(), text: String, startTime: Double, endTime: Double, position: SubtitlePosition = .bottom) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.position = position
    }
}

enum SubtitlePosition: String, Codable {
    case top = "top"
    case center = "center"
    case bottom = "bottom"
}

struct ShotInstruction: Identifiable, Codable {
    let id: UUID
    let sequence: Int
    let description: String
    let duration: String
    let cameraAngle: CameraAngle
    let notes: String
    
    init(id: UUID = UUID(), sequence: Int, description: String, duration: String, cameraAngle: CameraAngle, notes: String = "") {
        self.id = id
        self.sequence = sequence
        self.description = description
        self.duration = duration
        self.cameraAngle = cameraAngle
        self.notes = notes
    }
}

enum CameraAngle: String, CaseIterable, Codable {
    case closeUp = "Close-up"
    case mediumShot = "Plano medio"
    case wideShot = "Plano general"
    case overShoulder = "Por encima del hombro"
    case handHeld = "Cámara en mano"
    case topDown = "Cenital"
}

struct ScriptGenerationRequest {
    let businessType: String
    let productService: String
    let targetAudience: String
    let duration: ScriptDuration
    let hookType: HookType
    let tone: ScriptTone
    let keyBenefits: [String]
    let niche: String
}

enum ScriptTone: String, CaseIterable {
    case professional = "Profesional"
    case casual = "Casual"
    case energetic = "Energético"
    case authentic = "Auténtico"
    case educational = "Educativo"
}

enum ScriptError: LocalizedError {
    case missingInformation
    case generationFailed
    case insufficientCredits
    case subscriptionRequired
    
    var errorDescription: String? {
        switch self {
        case .missingInformation:
            return "Faltan datos del negocio para generar el guión"
        case .generationFailed:
            return "Error al generar el guión. Inténtalo de nuevo."
        case .insufficientCredits:
            return "No tienes suficientes créditos. Compra más o suscríbete."
        case .subscriptionRequired:
            return "Necesitas una suscripción para generar más de 3 guiones al mes"
        }
    }
}
