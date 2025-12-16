//
//  AIService.swift
//  goviiral
//
//  Created by OpenAI Assistant on 8/12/25.
//

import Foundation
import UIKit

protocol AIAnalysisProviding {
    func analyze(videoURL: URL, title: String?, videoHash: String?) async throws -> AnalysisReport
}

final class ClaudeAIService: AIAnalysisProviding {
    private let apiKey: String?
    private let model: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(apiKey: String? = ClaudeConfig.apiKey, model: String = ClaudeConfig.model, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    func analyze(videoURL: URL, title: String?, videoHash: String?) async throws -> AnalysisReport {
        // Verificar API key
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("[Error] API key de Anthropic no encontrada")
            print("   Verifica que ANTHROPIC_API_KEY esté configurada en el environment")
            throw AnalysisError.unauthorized
        }
        
        print("[Info] API key encontrada: \(String(apiKey.prefix(8)))...")

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("[Error] Video no encontrado en \(videoURL.path)")
            throw AnalysisError.invalidVideo
        }
        
        print("[Info] Video encontrado: \(videoURL.lastPathComponent)")

        print("[Info] Análisis real con Claude usando modelo: \(model)")

        // Extract frames from video for visual analysis
        print("[Frames] Extrayendo frames del video...")
        let frames = try await VideoFrameExtractor.extractFrames(from: videoURL, frameCount: 8)
        print("[Frames] Extraídos \(frames.count) frames del video")
        
        print("[Request] Preparando request para Claude API...")
        let request = try makeRequest(apiKey: apiKey, title: title ?? videoURL.lastPathComponent, frames: frames)
        
        print("[Network] Enviando request a Claude API...")
        let (data, response) = try await session.data(for: request)
        
        print("[Network] Respuesta recibida de Claude API")
        try validate(response: response, data: data)
        
        print("[Parse] Parseando respuesta de Claude...")
        let payload = try parseAnalysis(from: data)
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

    private func makeRequest(apiKey: String, title: String, frames: [UIImage]) throws -> URLRequest {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AnalysisError.server(message: "URL de API inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        print("[Config] Endpoint de Claude: \(url.absoluteString)")
        print("[Config] Modelo: \(model) | Max tokens: \(ClaudeConfig.maxTokens)")

        let systemPrompt = """
        No eres un chatbot conversacional. Eres un motor de análisis basado en evidencia.
        Responde SIEMPRE en español (España) sin mezclar inglés.
        
        REGLAS CRÍTICAS (OBLIGATORIAS):
        1. VALIDACIÓN DE ENTRADA:
        - Si frames.length < 6 → ERROR
        - Si más del 40% de los frames son visualmente similares → advertencia
        - Si todos los frames son iguales → ERROR
        - Si duración < 3s → marcar como "insuficiente"
        
        2. PROHIBICIONES ABSOLUTAS:
        ❌ No inventar información
        ❌ No asumir intención del creador
        ❌ No inferir CTA si no existe explícitamente
        ❌ No reutilizar análisis previos
        - Toda conclusión debe basarse en frames o transcripción reales
        
        3. MÉTODO DE ANÁLISIS (orden obligatorio):
        - Hook (0–2s): Analiza SOLO los primeros frames. Puntúa 0–10
        - Tema principal: Determina tema basándote únicamente en lo visible
        - Emoción dominante: Detecta solo si hay evidencia clara
        - Ritmo de edición: Determina según cortes y cambios de plano
        - Texto en pantalla: Extrae texto visible e indica en qué frame
        - Audio/Voz: Cita frases textuales clave si hay transcripción
        - CTA: Detecta CTA solo si es explícito
        - Diagnóstico: Evalúa potencial relativo con evidencias
        
        4. REGLA FINAL (NO NEGOCIABLE):
        Si no puedes justificar una conclusión con prueba visual o audible, NO LA INCLUYAS.
        """

        let userPrompt = """
        ENTRADAS RECIBIDAS:
        - frames[]: \(frames.count) imágenes ordenadas cronológicamente (frame_1 = inicio)
        - transcription: [vacío - no implementado aún]
        - metadata: formato 9:16, título: "\(title)"
        - idioma de salida: SOLO español (España), sin inglés
        
        VALIDACIÓN AUTOMÁTICA:
        ✓ frames.length >= 6: \(frames.count >= 6 ? "PASS" : "ERROR")
        ✓ duración suficiente: PASS (asumido)
        
        INSTRUCCIONES DE ANÁLISIS:
        Analiza estos \(frames.count) frames en orden cronológico siguiendo el método obligatorio:
        
        1. Hook (0–2s): Evalúa SOLO frames 1-2
        2. Tema principal: Basado únicamente en contenido visible
        3. Emoción: Solo si hay evidencia clara en expresiones/contexto
        4. Ritmo: Según cambios visuales entre frames
        5. Texto: Extrae texto visible y especifica frame
        6. CTA: Solo si es explícito y visible
        7. Diagnóstico: Con evidencias específicas de los frames
        
        Devuelve EXACTAMENTE este JSON (sin texto adicional):
        
        {
          "video_quality_score": número_0_10,
          "hook_score": número_0_10,
          "emotion_detected": "string_o_neutral",
          "main_topic": "tema_basado_en_frames_visibles",
          "editing_pace": "lento_medio_rapido",
          "on_screen_text": [
            {
              "text": "texto_exacto_visible",
              "frame": "frame_X"
            }
          ],
          "audio_key_phrases": [],
          "cta_detected": {
            "exists": boolean,
            "description": "descripcion_si_existe_o_vacio"
          },
          "why_it_works_or_not": "diagnostico_con_evidencias_visuales_especificas",
          "3_specific_improvements": [
            "mejora_1_basada_en_deficiencia_observable",
            "mejora_2_basada_en_frames_especificos",
            "mejora_3_basada_en_evidencia_visual"
          ],
          "evidence": {
            "frames_referenced": ["frame_1", "frame_3"],
            "audio_referenced": false
          }
        }
        
        AUTOCONTROL ANTES DE RESPONDER:
        - ¿Este análisis sería distinto con otro vídeo?
        - ¿He citado frames reales específicos?
        - ¿He evitado frases genéricas?
        - ¿Cada conclusión tiene evidencia visual?
        
        Si alguna respuesta es NO → devuelve ERROR.
        """

        // Convert frames to base64
        var contentBlocks: [ClaudeContentBlock] = [ClaudeTextBlock(text: userPrompt)]
        
        print("[Frames] Convirtiendo \(frames.count) frames a base64...")
        var successfulFrames = 0
        
        for (_, frame) in frames.enumerated() {
            if let base64 = VideoFrameExtractor.imageToBase64(image: frame) {
                contentBlocks.append(ClaudeImageBlock(
                    source: ClaudeImageSource(
                        type: "base64",
                        mediaType: "image/jpeg",
                        data: base64
                    )
                ))
                successfulFrames += 1
                print("  [Frames] Frame \(successfulFrames) convertido (\(base64.count) chars)")
            } else {
                print("  [Error] Error convirtiendo frame \(successfulFrames + 1)")
            }
        }
        
        print("[Frames] \(successfulFrames)/\(frames.count) frames convertidos exitosamente")
        print("[Payload] Total content blocks: \(contentBlocks.count) (1 texto + \(successfulFrames) imágenes)")
        
        let payload = ClaudeRequest(
            model: model,
            maxTokens: ClaudeConfig.maxTokens,
            temperature: 0.35,
            system: systemPrompt,
            messages: [
                ClaudeMessage(role: "user", content: contentBlocks)
            ]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        if let bodySize = request.httpBody?.count {
            print("[Payload] Payload preparado: \(bodySize) bytes")
        }
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[Error] Respuesta del servidor inválida")
            throw AnalysisError.server(message: "Respuesta del servidor inválida")
        }

        print("[Network] Status code: \(httpResponse.statusCode)")
        print("[Network] Tamaño de respuesta: \(data.count) bytes")
        
        guard 200..<300 ~= httpResponse.statusCode else {
            var message = String(data: data, encoding: .utf8) ?? "Error del servidor \(httpResponse.statusCode)"
            if httpResponse.statusCode == 404 && message.contains("model") {
                message = "Modelo no encontrado por Anthropic. Ajusta ANTHROPIC_MODEL (ej. claude-3-5-sonnet-latest). Detalle: \(message)"
            }
            print("[Error] Error del servidor (\(httpResponse.statusCode)): \(message)")
            throw AnalysisError.server(message: message)
        }
        
        print("[Network] Respuesta válida recibida")
    }

    private func parseAnalysis(from data: Data) throws -> ClaudeAnalysisPayload {
        // Primero mostrar la respuesta raw para debug
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("[Debug] Respuesta completa de Claude:")
            print("--- INICIO RESPUESTA ---")
            print(rawResponse)
            print("--- FIN RESPUESTA ---")
        }
        
        let response = try decoder.decode(ClaudeResponse.self, from: data)
        print("[Debug] Response decodificado. Content blocks: \(response.content.count)")
        
        guard let text = response.content.first(where: { $0.type == "text" })?.text else {
            print("[Error] No se encontró contenido de texto en la respuesta")
            throw AnalysisError.server(message: "Respuesta vacía de Claude")
        }

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

// MARK: - Configuration

enum ClaudeConfig {
    // Modelo básico disponible para todas las cuentas
    private static let defaultModel = "claude-3-haiku-20240307"
    private static let defaultMaxTokens = 900

    static var apiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        return nil
    }

    static var model: String {
        if let override = sanitizedModel(ProcessInfo.processInfo.environment["ANTHROPIC_MODEL"]) {
            return override
        }

        return defaultModel
    }

    static var maxTokens: Int {
        if let override = sanitizedInt(ProcessInfo.processInfo.environment["ANTHROPIC_MAX_TOKENS"]) {
            return override
        }

        return defaultMaxTokens
    }

    private static func sanitizedModel(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let normalized = cleaned
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        // Return nil for invalid model names to use default
        let validModels = ["claude-3-5-sonnet-20241022", "claude-3-5-sonnet-latest", "claude-3-haiku-20240307"]
        if !validModels.contains(normalized) && !normalized.hasPrefix("claude-3") {
            return nil
        }

        return normalized
    }

    private static func sanitizedInt(_ raw: String?) -> Int? {
        guard let raw, let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
            return nil
        }
        return min(value, 4000)
    }
}

// MARK: - Claude API Models

protocol ClaudeContentBlock: Encodable {}

private struct ClaudeTextBlock: ClaudeContentBlock {
    let type = "text"
    let text: String
}

private struct ClaudeImageBlock: ClaudeContentBlock {
    let type = "image"
    let source: ClaudeImageSource
}

private struct ClaudeImageSource: Encodable {
    let type: String
    let mediaType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

private struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let temperature: Double
    let system: String
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case temperature
        case system
        case messages
    }
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: [ClaudeContentBlock]
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content.map { AnyEncodable($0) }, forKey: .content)
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init<T: Encodable>(_ value: T) {
        _encode = value.encode(to:)
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

private struct ClaudeResponse: Decodable {
    let content: [ClaudeContent]
}

private struct ClaudeContent: Decodable {
    let type: String
    let text: String?
}

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
