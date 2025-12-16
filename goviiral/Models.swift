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
            return "Clave API faltante o inválida. Configura ANTHROPIC_API_KEY en las variables de entorno."
        case .server(let message):
            return message
        }
    }
}
