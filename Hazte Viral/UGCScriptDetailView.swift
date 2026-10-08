//
//  UGCScriptDetailView.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import SwiftUI
import UIKit

struct UGCScriptDetailView: View {
    let script: UGCScript

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var tab: Tab = .script
    @State private var showTeleprompter = false
    @State private var copiedMessage: String?

    enum Tab: String, CaseIterable {
        case script = "Guion"
        case shots = "Tomas"
        case subtitles = "Subtítulos"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    actions

                    Picker("Sección", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .script: scriptContent
                    case .shots: shotsContent
                    case .subtitles: subtitlesContent
                    }
                }
                .padding()
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) { shareMenu }
            }
            .overlay(alignment: .bottom) { copiedToast }
        }
        .fullScreenCover(isPresented: $showTeleprompter) {
            TeleprompterView(script: script)
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(script.title)
                .font(.title2.bold())
                .foregroundStyle(Theme.primary(scheme))

            HStack(spacing: 8) {
                MetricPill(icon: "flame.fill", text: "Hook \(script.hookScore)", color: .orange)
                MetricPill(icon: "clock.fill", text: "~\(script.estimatedSeconds) s", color: .blue)
                MetricPill(icon: "camera.fill", text: "\(script.shotList.count) tomas", color: .purple)
            }

            Text("\(script.businessType) · \(script.targetAudience)")
                .font(.footnote)
                .foregroundStyle(Theme.secondary(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button { showTeleprompter = true } label: {
                Label("Teleprompter", systemImage: "play.rectangle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }

            Button { copy(ScriptExport.plainText(script), message: "Guion copiado") } label: {
                Label("Copiar", systemImage: "doc.on.doc")
                    .font(.headline)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Theme.primary(scheme))
            }
        }
    }

    private var shareMenu: some View {
        Menu {
            ShareLink(item: ScriptExport.plainText(script)) {
                Label("Guion (texto)", systemImage: "doc.text")
            }
            if !script.shotList.isEmpty {
                ShareLink(item: ScriptExport.shotList(script)) {
                    Label("Lista de tomas", systemImage: "camera")
                }
            }
            if !script.subtitles.isEmpty {
                ShareLink(item: SRTFile(script: script), preview: SharePreview("\(script.title).srt")) {
                    Label("Subtítulos (.srt)", systemImage: "captions.bubble")
                }
            }
            ShareLink(item: ScriptExport.fullReport(script)) {
                Label("Todo", systemImage: "doc.richtext")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Compartir")
    }

    // MARK: - Pestañas

    private var scriptContent: some View {
        VStack(spacing: 14) {
            ScriptSection(title: "Hook", subtitle: "Primeros 2-3 segundos", icon: "bolt.fill", color: .orange,
                          text: script.hook) { copy(script.hook, message: "Hook copiado") }

            ForEach(Array(script.body.enumerated()), id: \.offset) { index, paragraph in
                ScriptSection(title: "Parte \(index + 1)", subtitle: nil, icon: "text.alignleft",
                              color: Theme.accentEnd, text: paragraph) { copy(paragraph, message: "Texto copiado") }
            }

            ScriptSection(title: "Llamada a la acción", subtitle: nil, icon: "megaphone.fill", color: .green,
                          text: script.cta) { copy(script.cta, message: "CTA copiado") }
        }
    }

    @ViewBuilder
    private var shotsContent: some View {
        if script.shotList.isEmpty {
            emptyState("Este guion no tiene lista de tomas.")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(script.shotList) { ShotCard(shot: $0) }
            }
        }
    }

    @ViewBuilder
    private var subtitlesContent: some View {
        if script.subtitles.isEmpty {
            emptyState("Este guion no tiene subtítulos.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tiempos orientativos: ajústalos a tu vídeo en el editor.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary(scheme))
                LazyVStack(spacing: 8) {
                    ForEach(script.subtitles) { SubtitleCard(subtitle: $0) }
                }
            }
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.secondary(scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    // MARK: - Copiar

    @ViewBuilder
    private var copiedToast: some View {
        if let copiedMessage {
            Label(copiedMessage, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func copy(_ text: String, message: String) {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(duration: 0.3)) { copiedMessage = message }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.3)) {
                if copiedMessage == message { copiedMessage = nil }
            }
        }
    }
}

// MARK: - Componentes

private struct ScriptSection: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let text: String
    let onCopy: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                }
                Spacer()
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary(scheme))
                }
                .accessibilityLabel("Copiar \(title)")
            }
            Text(text)
                .font(.body)
                .foregroundStyle(Theme.primary(scheme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3).padding(.vertical, 14)
        }
    }
}

struct MetricPill: View {
    let icon: String
    let text: String
    let color: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.primary(scheme))
            .labelStyle(PillLabelStyle(color: color))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
    }

    private struct PillLabelStyle: LabelStyle {
        let color: Color
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 4) {
                configuration.icon.foregroundStyle(color)
                configuration.title
            }
        }
    }
}

struct ShotCard: View {
    let shot: ShotInstruction
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(shot.sequence)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.accentStart, in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(shot.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primary(scheme))

                HStack(spacing: 12) {
                    if !shot.duration.isEmpty {
                        Label(shot.duration, systemImage: "clock")
                    }
                    Label(shot.cameraAngle.rawValue, systemImage: "camera")
                }
                .font(.caption)
                .foregroundStyle(Theme.secondary(scheme))

                if !shot.notes.isEmpty {
                    Label(shot.notes, systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SubtitleCard: View {
    let subtitle: SubtitleSegment
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(subtitle.startTime, specifier: "%.1f")–\(subtitle.endTime, specifier: "%.1f") s")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.accentStart)
                .frame(width: 78, alignment: .leading)
            Text(subtitle.text)
                .font(.subheadline)
                .foregroundStyle(Theme.primary(scheme))
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    UGCScriptDetailView(script: UGCScript(
        id: UUID(),
        title: "Pizza Artesanal - Hook de Ingrediente Secreto",
        createdAt: Date(),
        businessType: "Restaurante italiano",
        productService: "Pizza artesanal",
        targetAudience: "Familias jóvenes",
        duration: .medium,
        hook: "¿Sabías que usamos masa madre de 48 horas?",
        body: ["La diferencia está en los detalles", "Cada pizza es una obra de arte"],
        cta: "Reserva tu mesa y descubre el sabor auténtico",
        subtitles: [SubtitleSegment(text: "¿Sabías que...?", startTime: 0, endTime: 2.5)],
        shotList: [ShotInstruction(sequence: 1, description: "Primer plano de la masa", duration: "2-3s", cameraAngle: .closeUp)],
        hookScore: 85,
        niche: "restaurant"
    ))
}
