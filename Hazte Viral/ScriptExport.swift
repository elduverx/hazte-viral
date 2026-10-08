//
//  ScriptExport.swift
//  goviiral
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Formatos de exportación de un guion.
enum ScriptExport {
    static func plainText(_ script: UGCScript) -> String {
        """
        \(script.title)

        HOOK
        \(script.hook)

        DESARROLLO
        \(script.body.joined(separator: "\n\n"))

        CTA
        \(script.cta)
        """
    }

    static func shotList(_ script: UGCScript) -> String {
        let shots = script.shotList.map { shot in
            var line = "\(shot.sequence). \(shot.description)"
            let meta = [shot.duration, shot.cameraAngle.rawValue].filter { !$0.isEmpty }
            if !meta.isEmpty { line += " (\(meta.joined(separator: " · ")))" }
            if !shot.notes.isEmpty { line += "\n   Nota: \(shot.notes)" }
            return line
        }
        return "TOMAS — \(script.title)\n\n" + shots.joined(separator: "\n")
    }

    static func srt(_ script: UGCScript) -> String {
        script.subtitles.enumerated().map { index, subtitle in
            "\(index + 1)\n\(timestamp(subtitle.startTime)) --> \(timestamp(subtitle.endTime))\n\(subtitle.text)\n"
        }
        .joined(separator: "\n")
    }

    static func fullReport(_ script: UGCScript) -> String {
        var parts = [plainText(script)]
        if !script.shotList.isEmpty { parts.append(shotList(script)) }
        if !script.subtitles.isEmpty { parts.append("SUBTÍTULOS\n\n" + srt(script)) }
        return parts.joined(separator: "\n\n———\n\n")
    }

    private static func timestamp(_ seconds: Double) -> String {
        let totalMs = Int((max(0, seconds) * 1000).rounded())
        let h = totalMs / 3_600_000
        let m = (totalMs / 60_000) % 60
        let s = (totalMs / 1000) % 60
        let ms = totalMs % 1000
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}

/// Archivo .srt para compartir con ShareLink (se genera al compartir, no al pintar la vista).
struct SRTFile: Transferable {
    let script: UGCScript

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: UTType(filenameExtension: "srt") ?? .plainText) { file in
            Data(ScriptExport.srt(file.script).utf8)
        }
        .suggestedFileName { file in "\(file.script.title).srt" }
    }
}
