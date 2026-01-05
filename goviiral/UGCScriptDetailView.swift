//
//  UGCScriptDetailView.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import SwiftUI

struct UGCScriptDetailView: View {
    let script: UGCScript
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var selectedTab: ScriptDetailTab = .script
    @State private var showExportSheet = false
    
    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }
    private var panel: Color { Theme.panel(scheme) }
    private var stroke: Color { Theme.subtleStroke(scheme) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        
                        switch selectedTab {
                        case .script:
                            scriptContent
                        case .shots:
                            shotListContent
                        case .subtitles:
                            subtitlesContent
                        }
                    }
                    .padding()
                }
                
                bottomTabBar
            }
            .background(Theme.background(scheme))
        }
        .sheet(isPresented: $showExportSheet) {
            ExportOptionsView(script: script)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
                    .foregroundStyle(textPrimary)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showExportSheet = true
                } label: {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(textPrimary)
            }
        }
    }
    
    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(script.title)
                            .font(.title2.bold())
                            .foregroundStyle(textPrimary)
                        
                        Text("\(script.businessType) • \(script.duration.displayName)")
                            .font(.subheadline)
                            .foregroundStyle(textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(script.hookScore)")
                                .font(.title3.bold())
                                .foregroundStyle(.orange)
                        }
                        
                        Text("Hook Score")
                            .font(.caption2)
                            .foregroundStyle(textSecondary)
                    }
                }
                
                // Metadata
                HStack(spacing: 16) {
                    MetricPill(
                        icon: "camera.fill",
                        text: "\(script.shotList.count) tomas",
                        color: .blue
                    )
                    
                    MetricPill(
                        icon: "text.bubble.fill", 
                        text: "\(script.subtitles.count) subtítulos",
                        color: .green
                    )
                    
                    MetricPill(
                        icon: "person.2.fill",
                        text: script.targetAudience,
                        color: .purple
                    )
                }
                
                Text("Generado el \(script.formattedDate)")
                    .font(.caption)
                    .foregroundStyle(textSecondary)
            }
        }
    }
    
    private var scriptContent: some View {
        VStack(spacing: 16) {
            // Hook Section
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Hook (Primeros 2-3 segundos)", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    
                    Text(script.hook)
                        .font(.body)
                        .foregroundStyle(textPrimary)
                        .padding()
                        .background(panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.3)))
                }
            }
            
            // Body Sections
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Desarrollo del contenido", systemImage: "text.alignleft")
                        .font(.headline)
                        .foregroundStyle(textPrimary)
                    
                    ForEach(Array(script.body.enumerated()), id: \.offset) { index, paragraph in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Parte \(index + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Theme.accentStart)
                                
                                Spacer()
                                
                                Text("~\(estimatedDuration(for: paragraph))s")
                                    .font(.caption)
                                    .foregroundStyle(textSecondary)
                            }
                            
                            Text(paragraph)
                                .font(.body)
                                .foregroundStyle(textPrimary)
                                .padding()
                                .background(panel.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        if index < script.body.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            
            // CTA Section  
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Call to Action", systemImage: "megaphone.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    
                    Text(script.cta)
                        .font(.body)
                        .foregroundStyle(textPrimary)
                        .padding()
                        .background(panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.green.opacity(0.3)))
                }
            }
        }
    }
    
    private var shotListContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Lista de tomas", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(textPrimary)
                
                LazyVStack(spacing: 12) {
                    ForEach(script.shotList) { shot in
                        ShotCard(shot: shot)
                    }
                }
            }
        }
    }
    
    private var subtitlesContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Subtítulos sincronizados", systemImage: "text.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(textPrimary)
                
                LazyVStack(spacing: 8) {
                    ForEach(script.subtitles) { subtitle in
                        SubtitleCard(subtitle: subtitle)
                    }
                }
            }
        }
    }
    
    private var bottomTabBar: some View {
        HStack(spacing: 10) {
            TabButton(
                tab: .script,
                icon: "doc.text.fill",
                title: "Guión",
                isSelected: selectedTab == .script
            ) {
                selectedTab = .script
            }
            
            TabButton(
                tab: .shots,
                icon: "camera.fill", 
                title: "Tomas",
                isSelected: selectedTab == .shots
            ) {
                selectedTab = .shots
            }
            
            TabButton(
                tab: .subtitles,
                icon: "text.bubble.fill",
                title: "Subtítulos", 
                isSelected: selectedTab == .subtitles
            ) {
                selectedTab = .subtitles
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(stroke.opacity(0.7)))
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.18), radius: 16, y: 10)
        .padding(.horizontal)
        .padding(.bottom, 18)
        .padding(.top, 6)
    }
    
    private func estimatedDuration(for text: String) -> Int {
        // Estimate ~3 words per second for comfortable reading
        let wordCount = text.split(separator: " ").count
        return max(2, wordCount / 3)
    }
}

enum ScriptDetailTab {
    case script, shots, subtitles
}

struct MetricPill: View {
    let icon: String
    let text: String
    let color: Color
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.primary(scheme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3)))
    }
}

struct ShotCard: View {
    let shot: ShotInstruction
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Sequence number
            Text("\(shot.sequence)")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.accentStart, in: Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                // Shot description
                Text(shot.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primary(scheme))
                
                // Duration and angle
                HStack {
                    Label(shot.duration, systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Label(shot.cameraAngle.rawValue, systemImage: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                
                if !shot.notes.isEmpty {
                    Text("💡 \(shot.notes)")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                        .italic()
                }
            }
        }
        .padding()
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.subtleStroke(scheme)))
    }
}

struct SubtitleCard: View {
    let subtitle: SubtitleSegment
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Timeline
            VStack(spacing: 4) {
                Text("\(subtitle.startTime, specifier: "%.1f")s")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.accentStart)
                
                Rectangle()
                    .fill(Theme.accentStart)
                    .frame(width: 2, height: 20)
                
                Text("\(subtitle.endTime, specifier: "%.1f")s")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.accentStart)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle.text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.primary(scheme))
                
                HStack {
                    Label(subtitle.position.rawValue.capitalized, systemImage: "text.aligncenter")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                    
                    Spacer()
                    
                    Text("Duración: \(subtitle.endTime - subtitle.startTime, specifier: "%.1f")s")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                }
            }
        }
        .padding()
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.subtleStroke(scheme)))
    }
}

struct TabButton: View {
    let tab: ScriptDetailTab
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Theme.accentStart : Theme.secondary(scheme))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.accentStart.opacity(0.16) : Color.clear)
            )
        }
    }
}

struct ExportOptionsView: View {
    let script: UGCScript
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var selectedFormats: Set<ExportFormat> = [.text]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Exportar guión")
                    .font(.title2.bold())
                    .padding()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Selecciona los formatos:")
                        .font(.headline)
                        .foregroundStyle(Theme.primary(scheme))
                    
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        HStack {
                            Button {
                                if selectedFormats.contains(format) {
                                    selectedFormats.remove(format)
                                } else {
                                    selectedFormats.insert(format)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedFormats.contains(format) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selectedFormats.contains(format) ? Theme.accentStart : Theme.secondary(scheme))
                                    
                                    VStack(alignment: .leading) {
                                        Text(format.displayName)
                                            .foregroundStyle(Theme.primary(scheme))
                                        Text(format.description)
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondary(scheme))
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                Button {
                    exportScript()
                } label: {
                    Text("Exportar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accentStart)
                        .foregroundStyle(.white)
                        .cornerRadius(14)
                }
                .disabled(selectedFormats.isEmpty)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    private func exportScript() {
        // Implementation for export functionality
        dismiss()
    }
}

enum ExportFormat: CaseIterable {
    case text, srt, shotList, fullReport
    
    var displayName: String {
        switch self {
        case .text: return "Texto plano"
        case .srt: return "Subtítulos SRT"  
        case .shotList: return "Lista de tomas"
        case .fullReport: return "Informe completo"
        }
    }
    
    var description: String {
        switch self {
        case .text: return "Solo el guión en formato texto"
        case .srt: return "Archivo de subtítulos para edición"
        case .shotList: return "Instrucciones de grabación"
        case .fullReport: return "Documento completo con todo"
        }
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
        subtitles: [],
        shotList: [],
        hookScore: 85,
        niche: "restaurant"
    ))
}