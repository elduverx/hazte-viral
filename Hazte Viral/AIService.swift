//
//  AIService.swift
//  goviiral
//
//  Created by OpenAI Assistant on 8/12/25.
//

import Foundation
import CoreGraphics

protocol AIAnalysisProviding {
    func analyze(videoURL: URL, title: String?, videoHash: String?) async throws -> AnalysisReport
}

// MARK: - Backend

/// Cliente del backend propio (carpeta hazteviral-backend/ del repo). La API key de Anthropic vive solo en el servidor.
enum BackendClient {
    private static let backendURL = "https://viral.elduverx.com/api"

    /// Debe coincidir con APP_TOKEN en el .env del backend. Se inyecta con el build setting APP_TOKEN (Info.plist → AppToken).
    private static var appToken: String? {
        guard let raw = Bundle.main.infoDictionary?["AppToken"] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private struct ProxyResponse: Decodable {
        let text: String?
        let error: String?
    }

    /// Envía `body` al endpoint del backend y devuelve el texto de Claude.
    static func post(_ endpoint: String, body: [String: Any], session: URLSession = .shared) async throws -> String {
        guard let appToken else {
            print("[Error] APP_TOKEN no configurado en Build Settings")
            throw AnalysisError.unauthorized
        }
        guard let url = URL(string: "\(backendURL)/\(endpoint)") else {
            throw AnalysisError.server(message: "URL del servidor inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.server(message: "Respuesta del servidor inválida")
        }

        print("[Network] /\(endpoint) status: \(httpResponse.statusCode)")

        let decoded = try? JSONDecoder().decode(ProxyResponse.self, from: data)
        guard httpResponse.statusCode == 200, let text = decoded?.text else {
            if httpResponse.statusCode == 401 { throw AnalysisError.unauthorized }
            throw AnalysisError.server(message: decoded?.error ?? "Error del servidor (\(httpResponse.statusCode)).")
        }
        return text
    }
}

// MARK: - Analysis

final class ClaudeAIService: AIAnalysisProviding {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    func analyze(videoURL: URL, title: String?, videoHash: String?) async throws -> AnalysisReport {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("[Error] Video no encontrado en \(videoURL.path)")
            throw AnalysisError.invalidVideo
        }

        print("[Info] Video encontrado: \(videoURL.lastPathComponent)")

        // Extract frames from video for visual analysis
        print("[Frames] Extrayendo frames del video...")
        let frames = try await VideoFrameExtractor.extractFrames(from: videoURL, frameCount: 8)
        print("[Frames] Extraídos \(frames.count) frames del video")

        let base64Frames = frames.compactMap { VideoFrameExtractor.imageToBase64(image: $0) }
        print("[Frames] \(base64Frames.count)/\(frames.count) frames convertidos a base64")

        print("[Network] Enviando frames al backend...")
        let text = try await BackendClient.post("analyze", body: [
            "title": title ?? videoURL.lastPathComponent,
            "frames": base64Frames
        ], session: session)

        print("[Parse] Parseando respuesta de Claude...")
        let payload = try parseAnalysis(from: text)
        print("[Success] Análisis completado exitosamente")

        // Convertir scores del nuevo formato (0-10) a métricas (0-100)
        let metrics = EngagementMetrics(
            retentionScore: Double(payload.videoQualityScore * 10),
            hookStrength: Double(payload.hookScore * 10),
            messageClarity: payload.editingPace == "rápido" ? 85.0 : payload.editingPace == "medio" ? 70.0 : 55.0,
            pacing: payload.editingPace == "rápido" ? 90.0 : payload.editingPace == "medio" ? 70.0 : 50.0,
            viralityProbability: Double((payload.videoQualityScore + payload.hookScore) * 5)
        )

        // Generar highlights basados en evidencias
        let highlights = [
            "Análisis del hook: \(payload.emotionDetected != "neutral" ? "Emoción \(payload.emotionDetected) detectada" : "Hook sin emoción clara visible")",
            "Contenido identificado: \(payload.mainTopic)",
            "Ritmo de edición: \(payload.editingPace) - \(payload.evidence.framesReferenced.count) frames analizados"
        ]

        let predicted = predictViews(from: payload)

        return AnalysisReport(
            id: UUID(),
            title: payload.mainTopic.isEmpty ? (title ?? "Video") : payload.mainTopic,
            createdAt: Date(),
            predictedViews: predicted,
            metrics: metrics,
            highlights: highlights,
            recommendations: Array(payload.threeSpecificImprovements.prefix(3)),
            analysisDetails: AnalysisDetails(
                hookAnalysis: "Puntuación hook: \(payload.hookScore)/10",
                mainTopicIdentified: payload.mainTopic,
                emotionDetected: payload.emotionDetected,
                editingPace: payload.editingPace,
                onScreenTextDetected: payload.onScreenText.map { "\($0.text) (Frame \($0.frame))" }.joined(separator: ", "),
                whyWorksOrNot: payload.whyItWorksOrNot
            ),
            videoHash: videoHash
        )
    }

    private func parseAnalysis(from text: String) throws -> ClaudeAnalysisPayload {
        print("[Debug] Contenido de texto encontrado:")
        print("--- INICIO TEXTO ---")
        print(text)
        print("--- FIN TEXTO ---")

        guard let contentData = text.data(using: .utf8) else {
            print("[Error] No se puede convertir el texto a data")
            throw AnalysisError.server(message: "No se puede leer el contenido de Claude")
        }

        do {
            let payload = try decoder.decode(ClaudeAnalysisPayload.self, from: contentData)
            print("[Debug] JSON parseado correctamente")
            return payload
        } catch {
            print("[Error] Error parseando JSON: \(error)")
            print("[Recovery] Intentando encontrar JSON en el texto...")

            // Buscar JSON en el texto (en caso de que haya texto adicional)
            if let jsonStart = text.range(of: "{"),
               let jsonEnd = text.range(of: "}", options: .backwards) {
                let jsonText = String(text[jsonStart.lowerBound...jsonEnd.upperBound])
                print("[Recovery] JSON extraído:")
                print(jsonText)

                if let jsonData = jsonText.data(using: .utf8) {
                    return try decoder.decode(ClaudeAnalysisPayload.self, from: jsonData)
                }
            }

            // Intentar recuperar JSON truncado completando llaves y corchetes
            if let recovered = try? recoverTruncatedPayload(from: text) {
                return recovered
            }

            throw AnalysisError.server(message: "El servicio devolvió un mensaje no estructurado: \(text)")
        }
    }

    private func clampScore(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private func predictViews(from payload: ClaudeAnalysisPayload) -> Int {
        // Estimación con techo dinámico para no capar videos virales
        let raw = (Double(payload.videoQualityScore) * 0.55) + (Double(payload.hookScore) * 0.45)
        let paceAdjustment: Double
        if payload.editingPace.lowercased().contains("ráp") {
            paceAdjustment = 0.12
        } else if payload.editingPace.lowercased().contains("lento") {
            paceAdjustment = -0.08
        } else {
            paceAdjustment = 0.0
        }

        let emotionAdjustment: Double = payload.emotionDetected.lowercased() == "neutral" ? -0.05 : 0.04

        // Score normalizado 0-10 con ajustes
        let normalized = max(0, min(10, (raw / 10.0) + paceAdjustment + emotionAdjustment))

        // Techo dinámico: si hook/calidad son altos, permitir rangos de millones
        let viralityCeiling: Double
        if payload.videoQualityScore >= 9 && payload.hookScore >= 9 {
            viralityCeiling = 5_000_000
        } else if payload.videoQualityScore >= 8 && payload.hookScore >= 8 {
            viralityCeiling = 2_500_000
        } else if payload.videoQualityScore >= 7 && payload.hookScore >= 7 {
            viralityCeiling = 900_000
        } else {
            viralityCeiling = 220_000
        }

        let floor: Double = 1_200
        let logistic = 1.0 / (1.0 + exp(-(normalized - 5.0) / 1.05))
        let estimated = floor + logistic * (viralityCeiling - floor)

        return Int(estimated.rounded())
    }

    private func recoverTruncatedPayload(from text: String) throws -> ClaudeAnalysisPayload {
        guard let start = text.firstIndex(of: "{") else {
            throw AnalysisError.server(message: "Respuesta de Claude inválida")
        }

        var balanced = String(text[start...])
        var stack: [Character] = []

        for char in balanced {
            if char == "{" || char == "[" {
                stack.append(char)
            } else if char == "}" {
                if stack.last == "{" { stack.removeLast() }
            } else if char == "]" {
                if stack.last == "[" { stack.removeLast() }
            }
        }

        while let last = stack.popLast() {
            balanced.append(last == "{" ? "}" : "]")
        }

        guard let data = balanced.data(using: .utf8) else {
            throw AnalysisError.server(message: "No se pudo recuperar JSON de Claude")
        }

        do {
            let payload = try decoder.decode(ClaudeAnalysisPayload.self, from: data)
            print("✅ JSON recuperado tras completar llaves faltantes")
            return payload
        } catch {
            print("❌ Falló la recuperación de JSON: \(error)")
            throw error
        }
    }
}

// MARK: - Response Models

private struct ClaudeAnalysisPayload: Decodable {
    struct OnScreenText: Decodable {
        let text: String
        let frame: String
    }
    
    struct CTADetected: Decodable {
        let exists: Bool
        let description: String
    }
    
    struct Evidence: Decodable {
        let framesReferenced: [String]
        let audioReferenced: Bool

        enum CodingKeys: String, CodingKey {
            case framesReferenced = "frames_referenced"
            case audioReferenced = "audio_referenced"
        }
    }

    let videoQualityScore: Int
    let hookScore: Int
    let emotionDetected: String
    let mainTopic: String
    let editingPace: String
    let onScreenText: [OnScreenText]
    let audioKeyPhrases: [String]
    let ctaDetected: CTADetected
    let whyItWorksOrNot: String
    let threeSpecificImprovements: [String]
    let evidence: Evidence
    
    enum CodingKeys: String, CodingKey {
        case videoQualityScore = "video_quality_score"
        case hookScore = "hook_score"
        case emotionDetected = "emotion_detected"
        case mainTopic = "main_topic"
        case editingPace = "editing_pace"
        case onScreenText = "on_screen_text"
        case audioKeyPhrases = "audio_key_phrases"
        case ctaDetected = "cta_detected"
        case whyItWorksOrNot = "why_it_works_or_not"
        case threeSpecificImprovements = "3_specific_improvements"
        case evidence = "evidence"
    }
}
