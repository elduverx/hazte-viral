//
//  UGCScriptService.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import Foundation

/// Etapas reales de la generación, para la pantalla de carga.
enum ScriptGenerationStage: Int, CaseIterable {
    case sending, writing, finishing

    var title: String {
        switch self {
        case .sending: return "Enviando tu brief"
        case .writing: return "La IA está escribiendo los guiones"
        case .finishing: return "Preparando tomas y subtítulos"
        }
    }
}

protocol UGCScriptGenerating {
    func generateScripts(request: ScriptGenerationRequest, count: Int,
                         onStage: @escaping @MainActor (ScriptGenerationStage) -> Void) async throws -> [UGCScript]
}

final class ClaudeUGCScriptService: UGCScriptGenerating {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateScripts(request: ScriptGenerationRequest, count: Int,
                         onStage: @escaping @MainActor (ScriptGenerationStage) -> Void) async throws -> [UGCScript] {
        await onStage(.sending)
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
        ], session: session, onUploaded: { onStage(.writing) })

        await onStage(.finishing)
        let scripts = try parseScripts(from: rawContent, request: request)
        print("[UGC] \(scripts.count) guiones parseados")
        return scripts
    }

    private func parseScripts(from response: String, request: ScriptGenerationRequest) throws -> [UGCScript] {
        // Claude puede envolver el JSON en ```json ... ```: nos quedamos con el array.
        guard let start = response.firstIndex(of: "["),
              let end = response.lastIndex(of: "]"),
              start < end,
              let data = String(response[start...end]).data(using: .utf8) else {
            print("[UGC] La respuesta no contiene un array JSON: \(response.prefix(300))")
            throw ScriptError.generationFailed
        }

        let decoded: [ScriptResponse]
        do {
            decoded = try JSONDecoder().decode([ScriptResponse].self, from: data)
        } catch {
            print("[UGC] Error decodificando guiones: \(error)")
            throw ScriptError.generationFailed
        }
        guard !decoded.isEmpty else { throw ScriptError.generationFailed }

        let now = Date()
        return decoded.map { item in
            UGCScript(
                id: UUID(),
                title: Self.cleanTitle(item.title),
                createdAt: now,
                businessType: request.businessType,
                productService: request.productService,
                targetAudience: request.targetAudience,
                duration: request.duration,
                hook: item.hook,
                body: item.body,
                cta: item.cta,
                subtitles: item.subtitles.map {
                    SubtitleSegment(text: $0.text, startTime: $0.startTime, endTime: $0.endTime,
                                    position: SubtitlePosition(rawValue: $0.position ?? "") ?? .bottom)
                },
                shotList: item.shotList.map {
                    ShotInstruction(sequence: $0.sequence, description: $0.description, duration: $0.duration ?? "",
                                    cameraAngle: CameraAngle(rawValue: $0.cameraAngle ?? "") ?? .mediumShot,
                                    notes: $0.notes ?? "")
                },
                hookScore: min(max(item.hookScore ?? 0, 0), 100),
                niche: request.niche
            )
        }
    }
}

extension ClaudeUGCScriptService {
    /// Quita prefijos como "Guión 1:" o "Guion 2 -" que a veces añade la IA.
    static func cleanTitle(_ title: String) -> String {
        let cleaned = title.replacingOccurrences(of: #"^\s*gui[oó]n\s*\d+\s*[:.\-–—]\s*"#, with: "",
                                                 options: [.regularExpression, .caseInsensitive])
        return cleaned.isEmpty ? title : cleaned
    }
}

// MARK: - Respuesta de Claude

/// Solo título, hook, cuerpo y CTA son obligatorios; el resto tiene valores por defecto
/// para que un campo mal formado no tire todo el guion.
private struct ScriptResponse: Decodable {
    let title: String
    let hook: String
    let body: [String]
    let cta: String
    let subtitles: [SubtitleResponse]
    let shotList: [ShotResponse]
    let hookScore: Int?

    enum CodingKeys: String, CodingKey {
        case title, hook, body, cta, subtitles, shotList, hookScore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        hook = try c.decode(String.self, forKey: .hook)
        body = try c.decode([String].self, forKey: .body)
        cta = try c.decode(String.self, forKey: .cta)
        subtitles = (try? c.decode([SubtitleResponse].self, forKey: .subtitles)) ?? []
        shotList = (try? c.decode([ShotResponse].self, forKey: .shotList)) ?? []
        hookScore = try? c.decode(Int.self, forKey: .hookScore)
    }
}

private struct SubtitleResponse: Decodable {
    let text: String
    let startTime: Double
    let endTime: Double
    let position: String?
}

private struct ShotResponse: Decodable {
    let sequence: Int
    let description: String
    let duration: String?
    let cameraAngle: String?
    let notes: String?
}
