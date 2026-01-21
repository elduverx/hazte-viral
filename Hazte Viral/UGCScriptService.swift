//
//  UGCScriptService.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import Foundation

protocol UGCScriptGenerating {
    func generateScript(request: ScriptGenerationRequest) async throws -> UGCScript
    func generateMultipleScripts(request: ScriptGenerationRequest, count: Int) async throws -> [UGCScript]
}

final class ClaudeUGCScriptService: UGCScriptGenerating {
    private let apiKey: String?
    private let model: String
    private let session: URLSession
    
    init(apiKey: String? = ClaudeConfig.apiKey, model: String = ClaudeConfig.model, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }
    
    func generateScript(request: ScriptGenerationRequest) async throws -> UGCScript {
        let scripts = try await generateMultipleScripts(request: request, count: 1)
        guard let script = scripts.first else {
            throw ScriptError.generationFailed
        }
        return script
    }
    
    func generateMultipleScripts(request: ScriptGenerationRequest, count: Int) async throws -> [UGCScript] {
        guard let apiKey else {
            throw AnalysisError.unauthorized
        }
        
        let urlRequest = try makeScriptRequest(apiKey: apiKey, request: request, count: count)
        print("[UGC] Enviando request para \(count) guiones...")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScriptError.generationFailed
        }
        
        print("[UGC] Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Error desconocido"
            throw AnalysisError.server(message: "Error \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let rawContent = claudeResponse.content.first?.text else {
            throw ScriptError.generationFailed
        }
        
        print("[UGC] Respuesta recibida: \(rawContent.prefix(200))...")
        
        return try parseScriptsFromResponse(rawContent, request: request)
    }
    
    private func makeScriptRequest(apiKey: String, request: ScriptGenerationRequest, count: Int) throws -> URLRequest {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ScriptError.generationFailed
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.timeoutInterval = 45
        
        let systemPrompt = createSystemPrompt()
        let userPrompt = createUserPrompt(request: request, count: count)
        
        let payload = ClaudeRequest(
            model: model,
            maxTokens: ClaudeConfig.maxTokens,
            temperature: 0.7,
            system: systemPrompt,
            messages: [ClaudeMessage(role: "user", content: [ClaudeTextBlock(text: userPrompt)])]
        )
        
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        
        return urlRequest
    }
    
    private func createSystemPrompt() -> String {
        return """
        Eres un experto copywriter especializado en UGC (User Generated Content) para redes sociales de negocios.
        Tu trabajo es crear guiones virales que conviertan visualizaciones en clientes.
        
        REGLAS CRÍTICAS:
        1. SIEMPRE responde en español de España
        2. Cada guión debe ser específico al negocio y producto mencionado
        3. Incluye números, datos o resultados cuando sea posible
        4. El hook DEBE ser irresistible y hacer scroll-stop
        5. El CTA debe ser claro y accionable
        6. Adapta el tono al público objetivo
        7. Respeta la duración especificada
        
        ESTRUCTURA OBLIGATORIA para cada guión:
        ```json
        {
          "title": "Título descriptivo del guión",
          "hook": "Primera frase que para el scroll (2-3 segundos)",
          "body": ["Párrafo 1 del desarrollo", "Párrafo 2 del desarrollo", "Párrafo 3 del desarrollo"],
          "cta": "Call to action final claro",
          "subtitles": [
            {"text": "Texto del subtítulo", "startTime": 0.0, "endTime": 3.0, "position": "bottom"},
            {"text": "Segundo subtítulo", "startTime": 3.0, "endTime": 6.0, "position": "bottom"}
          ],
          "shotList": [
            {"sequence": 1, "description": "Descripción de la toma", "duration": "2-3s", "cameraAngle": "closeUp", "notes": "Notas adicionales"},
            {"sequence": 2, "description": "Segunda toma", "duration": "3-4s", "cameraAngle": "mediumShot", "notes": ""}
          ],
          "hookScore": 85
        }
        ```
        
        IMPORTANTE: 
        - hookScore del 1-100 basado en potencial viral
        - shotList debe tener instrucciones claras de grabación
        - subtitles deben coincidir con la duración total
        - NO inventes datos falsos, usa ejemplos realistas
        """
    }
    
    private func createUserPrompt(request: ScriptGenerationRequest, count: Int) -> String {
        return """
        INFORMACIÓN DEL NEGOCIO:
        - Tipo de negocio: \(request.businessType)
        - Producto/Servicio: \(request.productService)
        - Público objetivo: \(request.targetAudience)
        - Nicho: \(request.niche)
        
        ESPECIFICACIONES DEL CONTENIDO:
        - Duración del reel: \(request.duration.rawValue)
        - Tipo de hook: \(request.hookType.rawValue) (\(request.hookType.description))
        - Tono deseado: \(request.tone.rawValue)
        - Beneficios clave: \(request.keyBenefits.joined(separator: ", "))
        
        TAREA:
        Genera \(count) guion\(count == 1 ? "" : "es") completamente diferente\(count == 1 ? "" : "s") para este negocio.
        
        REQUISITOS ESPECÍFICOS:
        1. Cada guión debe ser único y abordar diferentes ángulos del negocio
        2. Hooks completamente diferentes entre sí
        3. Adapta el lenguaje al público objetivo especificado
        4. Incluye detalles específicos del producto/servicio mencionado
        5. Los subtítulos deben ser legibles (máximo 8 palabras por línea)
        6. Las tomas deben ser factibles para una persona grabando sola
        
        Responde ÚNICAMENTE con un array JSON válido de \(count) guion\(count == 1 ? "" : "es"):
        [
          { guión 1 },
          { guión 2 },
          ...
        ]
        """
    }
    
    private func parseScriptsFromResponse(_ response: String, request: ScriptGenerationRequest) throws -> [UGCScript] {
        let cleanedResponse = extractJSONFromResponse(response)
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            print("[UGC] Failed to convert cleaned response to data")
            throw ScriptError.generationFailed
        }
        
        do {
            let scriptResponses = try JSONDecoder().decode([ScriptResponse].self, from: data)
            
            return scriptResponses.map { scriptResponse in
                UGCScript(
                    id: UUID(),
                    title: scriptResponse.title,
                    createdAt: Date(),
                    businessType: request.businessType,
                    productService: request.productService,
                    targetAudience: request.targetAudience,
                    duration: request.duration,
                    hook: scriptResponse.hook,
                    body: scriptResponse.body,
                    cta: scriptResponse.cta,
                    subtitles: scriptResponse.subtitles.map { subtitle in
                        SubtitleSegment(
                            text: subtitle.text,
                            startTime: subtitle.startTime,
                            endTime: subtitle.endTime,
                            position: SubtitlePosition(rawValue: subtitle.position) ?? .bottom
                        )
                    },
                    shotList: scriptResponse.shotList.map { shot in
                        ShotInstruction(
                            sequence: shot.sequence,
                            description: shot.description,
                            duration: shot.duration,
                            cameraAngle: CameraAngle(rawValue: shot.cameraAngle) ?? .mediumShot,
                            notes: shot.notes
                        )
                    },
                    hookScore: scriptResponse.hookScore,
                    niche: request.niche
                )
            }
            
        } catch let decodingError as DecodingError {
            print("[UGC] Decoding error: \(decodingError)")
            print("[UGC] Cleaned response length: \(cleanedResponse.count)")
            print("[UGC] Cleaned response: \(cleanedResponse)")
            
            if cleanedResponse.isEmpty {
                print("[UGC] Response is empty after cleaning")
            } else if !cleanedResponse.hasPrefix("[") {
                print("[UGC] Response doesn't start with '[' - not a JSON array")
            } else if !cleanedResponse.hasSuffix("]") {
                print("[UGC] Response doesn't end with ']' - possibly truncated")
                print("[UGC] Last 100 characters: \(String(cleanedResponse.suffix(100)))")
            }
            
            throw ScriptError.generationFailed
        } catch {
            print("[UGC] Unexpected error parsing JSON: \(error)")
            print("[UGC] Response: \(cleanedResponse)")
            throw ScriptError.generationFailed
        }
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First, try to find JSON array boundaries
        if let startIndex = trimmedResponse.firstIndex(of: "["),
           let endIndex = trimmedResponse.lastIndex(of: "]") {
            
            let jsonSubstring = String(trimmedResponse[startIndex...endIndex])
            
            // Validate that we have proper JSON structure
            if isValidJSONStructure(jsonSubstring) {
                print("[UGC] Successfully extracted JSON array")
                return jsonSubstring
            } else {
                print("[UGC] Extracted substring is not valid JSON structure")
            }
        }
        
        // Fallback: try line-by-line extraction
        let lines = response.components(separatedBy: .newlines)
        var jsonLines: [String] = []
        var inJsonBlock = false
        var arrayDepth = 0
        var objectDepth = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("[") {
                inJsonBlock = true
                arrayDepth = 1
                objectDepth = 0
                jsonLines.append(trimmedLine)
            } else if inJsonBlock {
                jsonLines.append(trimmedLine)
                
                // Count brackets more carefully
                for char in trimmedLine {
                    switch char {
                    case "[":
                        arrayDepth += 1
                    case "]":
                        arrayDepth -= 1
                    case "{":
                        objectDepth += 1
                    case "}":
                        objectDepth -= 1
                    default:
                        break
                    }
                }
                
                // If we've closed the main array, we're done
                if arrayDepth == 0 {
                    break
                }
            }
        }
        
        let result = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if result.isEmpty || !result.hasPrefix("[") {
            print("[UGC] Fallback: returning original response")
            return trimmedResponse
        }
        
        return result
    }
    
    private func isValidJSONStructure(_ jsonString: String) -> Bool {
        guard jsonString.hasPrefix("[") && jsonString.hasSuffix("]") else {
            return false
        }
        
        var arrayDepth = 0
        var objectDepth = 0
        var inString = false
        var escapeNext = false
        
        for char in jsonString {
            if escapeNext {
                escapeNext = false
                continue
            }
            
            switch char {
            case "\\":
                if inString {
                    escapeNext = true
                }
            case "\"":
                inString.toggle()
            case "[" where !inString:
                arrayDepth += 1
            case "]" where !inString:
                arrayDepth -= 1
            case "{" where !inString:
                objectDepth += 1
            case "}" where !inString:
                objectDepth -= 1
            default:
                break
            }
        }
        
        return arrayDepth == 0 && objectDepth == 0 && !inString
    }
}

private struct ScriptResponse: Codable {
    let title: String
    let hook: String
    let body: [String]
    let cta: String
    let subtitles: [SubtitleResponse]
    let shotList: [ShotResponse]
    let hookScore: Int
}

private struct SubtitleResponse: Codable {
    let text: String
    let startTime: Double
    let endTime: Double
    let position: String
}

private struct ShotResponse: Codable {
    let sequence: Int
    let description: String
    let duration: String
    let cameraAngle: String
    let notes: String
}