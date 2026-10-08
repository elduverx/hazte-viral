//
//  AIService.swift
//  goviiral
//
//  Created by OpenAI Assistant on 8/12/25.
//

import Foundation
import CoreGraphics

/// Etapas reales del análisis, para la pantalla de carga.
enum AnalysisStage: Int, CaseIterable {
    case extractingFrames, uploading, analyzing

    var title: String {
        switch self {
        case .extractingFrames: return "Extrayendo fotogramas"
        case .uploading: return "Enviando a la IA"
        case .analyzing: return "Analizando hook, ritmo y mensaje"
        }
    }
}

protocol AIAnalysisProviding {
    func analyze(videoURL: URL, title: String?, videoHash: String?,
                 onStage: @escaping @MainActor (AnalysisStage) -> Void) async throws -> AnalysisReport
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
    /// `onUploaded` se llama cuando el cuerpo de la petición ya se ha enviado y solo queda esperar a la IA.
    static func post(_ endpoint: String, body: [String: Any], session: URLSession = .shared,
                     onUploaded: (@MainActor () -> Void)? = nil) async throws -> String {
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

        let delegate = onUploaded.map(UploadProgressDelegate.init)
        let (data, response) = try await session.data(for: request, delegate: delegate)

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

/// Avisa una sola vez cuando se ha terminado de subir el cuerpo de la petición.
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let onUploaded: @MainActor () -> Void
    private var notified = false

    init(onUploaded: @escaping @MainActor () -> Void) {
        self.onUploaded = onUploaded
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard !notified, totalBytesSent >= totalBytesExpectedToSend else { return }
        notified = true
        Task { @MainActor [onUploaded] in onUploaded() }
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

    func analyze(videoURL: URL, title: String?, videoHash: String?,
                 onStage: @escaping @MainActor (AnalysisStage) -> Void) async throws -> AnalysisReport {
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("[Error] Video no encontrado en \(videoURL.path)")
            throw AnalysisError.invalidVideo
        }

        print("[Info] Video encontrado: \(videoURL.lastPathComponent)")

        // Extract frames from video for visual analysis
        await onStage(.extractingFrames)
        print("[Frames] Extrayendo frames del video...")
        let frames = try await VideoFrameExtractor.extractFrames(from: videoURL, frameCount: 8)
        print("[Frames] Extraídos \(frames.count) frames del video")

        let base64Frames = frames.compactMap { VideoFrameExtractor.imageToBase64(image: $0) }
        print("[Frames] \(base64Frames.count)/\(frames.count) frames convertidos a base64")

        try Task.checkCancellation()
        await onStage(.uploading)
        print("[Network] Enviando frames al backend...")
        let text = try await BackendClient.post("analyze", body: [
            "title": title ?? videoURL.lastPathComponent,
            "frames": base64Frames
        ], session: session, onUploaded: { onStage(.analyzing) })

        print("[Parse] Parseando respuesta de Claude...")
        let payload = try parseAnalysis(from: text)
        print("[Success] Análisis completado exitosamente")

        // Solo lo que la IA ha medido. Claridad y ritmo vienen del backend nuevo; si faltan, no se inventan.
        var scores = [
            ScoreDimension(kind: .hook, score: clamp10(payload.hookScore), reason: payload.scoreReasons?.hook ?? ""),
            ScoreDimension(kind: .visualQuality, score: clamp10(payload.videoQualityScore),
                           reason: payload.scoreReasons?.visualQuality ?? "")
        ]
        if let clarity = payload.clarityScore {
            scores.append(ScoreDimension(kind: .clarity, score: clamp10(clarity), reason: payload.scoreReasons?.clarity ?? ""))
        }
        if let pacing = payload.pacingScore {
            scores.append(ScoreDimension(kind: .pacing, score: clamp10(pacing), reason: payload.scoreReasons?.pacing ?? ""))
        }
        func value(_ kind: ScoreDimension.Kind) -> Double? {
            scores.first { $0.kind == kind }.map { Double($0.score * 10) }
        }
        let average = scores.map { Double($0.score) }.reduce(0, +) / Double(scores.count) * 10

        // Métricas internas (0-100) para los consejos; ya no se muestran como porcentajes.
        let metrics = EngagementMetrics(
            retentionScore: value(.visualQuality) ?? 0,
            hookStrength: value(.hook) ?? 0,
            messageClarity: value(.clarity) ?? average,
            pacing: value(.pacing) ?? average,
            viralityProbability: average
        )

        let highlights = [
            "Tema: \(payload.mainTopic)",
            payload.emotionDetected.lowercased() == "neutral" ? "Sin una emoción clara en el inicio" : "Emoción detectada: \(payload.emotionDetected)",
            "Ritmo de edición: \(payload.editingPace)"
        ]

        return AnalysisReport(
            id: UUID(),
            title: payload.mainTopic.isEmpty ? (title ?? "Video") : payload.mainTopic,
            createdAt: Date(),
            predictedViews: 0, // Ya no se estiman visualizaciones (no se pueden predecir desde el vídeo)
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
            videoHash: videoHash,
            scores: scores
        )
    }

    private func clamp10(_ value: Int) -> Int {
        min(max(value, 0), 10)
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

    struct ScoreReasons: Decodable {
        let hook: String?
        let visualQuality: String?
        let clarity: String?
        let pacing: String?

        enum CodingKeys: String, CodingKey {
            case hook, clarity, pacing
            case visualQuality = "visual_quality"
        }
    }

    let videoQualityScore: Int
    let hookScore: Int
    let clarityScore: Int?
    let pacingScore: Int?
    let scoreReasons: ScoreReasons?
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
        case clarityScore = "clarity_score"
        case pacingScore = "pacing_score"
        case scoreReasons = "score_reasons"
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
