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
    private let session: URLSession
    
    init(session: URLSession = .shared) {
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
        print("[UGC] Enviando request para \(count) guiones...")
        let rawContent = try await BackendClient.post("scripts", body: [
            "businessType": request.businessType,
            "productService": request.productService,
            "targetAudience": request.targetAudience,
            "niche": request.niche,
            "duration": request.duration.rawValue,
            "hookType": request.hookType.rawValue,
            "hookTypeDescription": request.hookType.description,
            "tone": request.tone.rawValue,
            "keyBenefits": request.keyBenefits,
            "count": count
        ], session: session)
        
        print("[UGC] Respuesta recibida: \(rawContent.prefix(200))...")
        
        return try parseScriptsFromResponse(rawContent, request: request)
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