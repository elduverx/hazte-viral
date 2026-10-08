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
    /// Puntuaciones medidas por la IA con su motivo. nil en informes antiguos.
    var scores: [ScoreDimension]? = nil

    /// Puntuaciones a mostrar: las de la IA o, en informes antiguos, las dos que sí se midieron.
    var dimensionScores: [ScoreDimension] {
        if let scores, !scores.isEmpty { return scores }
        return [
            ScoreDimension(kind: .hook, score: Int((metrics.hookStrength / 10).rounded()), reason: ""),
            ScoreDimension(kind: .visualQuality, score: Int((metrics.retentionScore / 10).rounded()), reason: "")
        ]
    }

    /// Media de 0 a 10 de lo que la IA ha medido.
    var overallScore: Double {
        let values = dimensionScores.map { Double($0.score) }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    var potential: PotentialLevel { PotentialLevel(score: overallScore) }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

/// Una dimensión que la IA puntúa de 0 a 10 mirando los fotogramas.
struct ScoreDimension: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case hook, visualQuality, clarity, pacing

        var title: String {
            switch self {
            case .hook: return "Hook"
            case .visualQuality: return "Calidad visual"
            case .clarity: return "Claridad"
            case .pacing: return "Ritmo"
            }
        }

        var icon: String {
            switch self {
            case .hook: return "bolt.fill"
            case .visualQuality: return "camera.aperture"
            case .clarity: return "text.bubble.fill"
            case .pacing: return "metronome.fill"
            }
        }

        /// Qué mide, en palabras del usuario.
        var question: String {
            switch self {
            case .hook: return "¿Los primeros 2 segundos detienen el scroll?"
            case .visualQuality: return "Luz, encuadre y nitidez"
            case .clarity: return "¿Se entiende sin sonido?"
            case .pacing: return "Cambios de plano y dinamismo"
            }
        }
    }

    let kind: Kind
    let score: Int // 0-10
    let reason: String

    var id: Kind { kind }
}

/// Valoración cualitativa del vídeo. No es una predicción de visualizaciones.
enum PotentialLevel {
    case needsWork, promising, strong, veryStrong

    init(score: Double) {
        switch score {
        case ..<5: self = .needsWork
        case ..<7: self = .promising
        case ..<8.5: self = .strong
        default: self = .veryStrong
        }
    }

    var title: String {
        switch self {
        case .needsWork: return "Necesita trabajo"
        case .promising: return "Prometedor"
        case .strong: return "Sólido"
        case .veryStrong: return "Muy sólido"
        }
    }

    var summary: String {
        switch self {
        case .needsWork: return "Hay puntos básicos que mejorar antes de publicar."
        case .promising: return "Buena base; con los ajustes de abajo puede rendir bastante mejor."
        case .strong: return "Bien construido. Pule los detalles y publícalo."
        case .veryStrong: return "Cumple lo que suele funcionar en vídeos cortos."
        }
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
            return "La app no está autorizada en el servidor. Revisa APP_TOKEN en Build Settings."
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
        BusinessNiche(id: "education", name: "Educación", icon: "graduationcap.fill", description: "Cursos, formaciones, skills"),
        BusinessNiche(id: "health", name: "Salud & Clínicas", icon: "cross.case.fill", description: "Dentistas, fisios, nutrición"),
        BusinessNiche(id: "services", name: "Servicios profesionales", icon: "briefcase.fill", description: "Abogados, asesorías, consultoría"),
        BusinessNiche(id: "home", name: "Hogar & Reformas", icon: "hammer.fill", description: "Reformas, limpieza, decoración"),
        BusinessNiche(id: "pets", name: "Mascotas", icon: "pawprint.fill", description: "Veterinarias, peluquería, tiendas"),
        BusinessNiche(id: "travel", name: "Viajes & Turismo", icon: "airplane", description: "Hoteles, experiencias, agencias"),
        BusinessNiche(id: "events", name: "Eventos", icon: "party.popper.fill", description: "Bodas, fiestas, catering"),
        BusinessNiche(id: "creator", name: "Creador / Marca personal", icon: "person.crop.circle.fill", description: "Tu propia marca, comunidad, infoproductos"),
        BusinessNiche(id: "entertainment", name: "Música & Entretenimiento", icon: "music.note", description: "Artistas, gaming, ocio")
    ]

    /// Opción libre: el usuario escribe su propio nicho.
    static let otherID = "other"

    static func named(_ id: String) -> BusinessNiche? {
        allCases.first { $0.id == id }
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

    var shortName: String {
        switch self {
        case .short: return "Corto"
        case .medium: return "Medio"
        case .long: return "Largo"
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

    var icon: String {
        switch self {
        case .question: return "questionmark.bubble.fill"
        case .problem: return "exclamationmark.triangle.fill"
        case .result: return "chart.line.uptrend.xyaxis"
        case .controversy: return "flame.fill"
        case .story: return "book.fill"
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
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var fullScript: String {
        ([hook] + body + [cta]).joined(separator: "\n\n")
    }

    /// Duración de lectura estimada a ~2,5 palabras por segundo.
    var estimatedSeconds: Int {
        let words = fullScript.split(whereSeparator: \.isWhitespace).count
        return max(5, Int((Double(words) / 2.5).rounded()))
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

enum ScriptTone: String, CaseIterable, Codable {
    case professional = "Profesional"
    case casual = "Casual"
    case energetic = "Energético"
    case authentic = "Auténtico"
    case educational = "Educativo"
}

enum ScriptError: LocalizedError {
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Error al generar el guión. Inténtalo de nuevo."
        }
    }
}
