//
//  ContentView.swift
//  goviiral
//
//  Created by duverney muriel on 8/12/25.
//

import AVKit
import PhotosUI
import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var viewModel = AnalyzerViewModel()
    @StateObject private var creditsManager = AnalysisCreditsManager.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var scheme
    @State private var activeReport: AnalysisReport?
    @State private var showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenTutorial")
    @State private var showPaywall = false
    @State private var hasPresentedPaywall = false
#if os(iOS)
    @State private var showLegacyVideoPicker = false
#endif
    private let subscriptionGateEnabled = AppMonetization.paymentsEnabled

    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }
    private var panel: Color { Theme.panel(scheme) }
    private var stroke: Color { Theme.subtleStroke(scheme) }

    var body: some View {
        CompatibleNavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()
                BackgroundGlow()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if !subscriptionManager.isSubscribed {
                            subscriptionBanner
                        }
                        preview
                        
                        if viewModel.selectedVideoURL != nil {
                            analyzeButton
                            
                            if let report = viewModel.report {
                                inlineResults(report)
                            }
                        } else {
                            videoPickerControl {
                                HStack {
                                    if viewModel.isLoadingVideo {
                                        ProgressView()
                                            .compatibleTint(.white)
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "plus")
                                    }
                                    Text(viewModel.isLoadingVideo ? "Subiendo..." : "Subir video")
                                        .fontWeight(.bold)
                                    Spacer()
                                }
                                .font(.title3)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Theme.recordRed)
                                .foregroundStyle(.white)
                                .cornerRadius(18)
                                .shadow(color: Color.red.opacity(0.3), radius: 16, y: 8)
                            }
                            .disabled(viewModel.isLoadingVideo)
                            .opacity(viewModel.isLoadingVideo ? 0.7 : 1)
                        }
                    }
                    .padding()
                }

                if viewModel.isAnalyzing {
                    LoadingOverlay()
                }
            }
        }
        .sheet(item: $activeReport) { report in
            ReportSheet(report: report)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
        .alert("Error", isPresented: $viewModel.showError, actions: {
            Button("Entendido", role: .cancel) {}
        }, message: {
            Text(viewModel.errorMessage ?? "Error inesperado")
        })
        .onChange(of: viewModel.report) { report in
            activeReport = report
        }
        .onChange(of: subscriptionManager.isSubscribed) { isActive in
            if isActive { showPaywall = false }
            if isActive { hasPresentedPaywall = true }
        }
        .onAppear { 
            Task { 
                await subscriptionManager.updateSubscriptionStatus()
                presentPaywallIfNeeded() 
            }
        }
        .onChange(of: showTutorial) { _ in 
            Task { 
                await subscriptionManager.updateSubscriptionStatus()
                presentPaywallIfNeeded() 
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showHistory = true
                } label: {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }
                .foregroundStyle(textPrimary)
            }
        }
        .sheet(isPresented: $viewModel.showHistory) {
            HistoryView(reports: viewModel.history) { report in
                activeReport = report
                viewModel.showHistory = false
            }
        }
#if os(iOS)
        .sheet(isPresented: $showLegacyVideoPicker) {
            LegacyVideoPicker { url in
                showLegacyVideoPicker = false
                guard let url else { return }
                viewModel.handleLegacySelection(with: url)
            }
        }
#endif
        #if os(iOS)
        .fullScreenCover(isPresented: $showTutorial) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
                showTutorial = false
            }
        }
        #else
        .sheet(isPresented: $showTutorial) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
                showTutorial = false
            }
        }
        #endif
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Go Viral")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(textPrimary)
                Text("Sube tu video y deja que la IA analice su potencial viral.")
                    .font(.subheadline)
                    .foregroundStyle(textSecondary)
            }
            Spacer()
            Button {
                viewModel.showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .padding(10)
                    .background(panel, in: Circle())
            }
            .foregroundStyle(textPrimary)
        }
    }

    private var subscriptionBanner: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suscripción Go Viral Pro")
                        .font(.headline)
                        .foregroundStyle(textPrimary)
                    Text("Análisis ilimitados por 5€/mes. Usuarios gratuitos: 3 análisis mensuales.")
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }

                Spacer()

                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "applelogo")
                        Text("Suscribirse")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
                }
            }
        }
    }

    private var uploader: some View {
        Group {
            if viewModel.selectedVideoURL == nil {
                GlassCard {
                    Spacer()
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Subir video")
                            .font(.headline)
                            .foregroundStyle(textPrimary)
                        videoPickerControl {
                            HStack {
                                if viewModel.isLoadingVideo {
                                    ProgressView()
                                        .compatibleTint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "plus")
                                }
                                Text(viewModel.isLoadingVideo ? "Subiendo..." : "Subir video")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.recordRed)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                            .shadow(color: Color.red.opacity(0.35), radius: 16, y: 8)
                        }
                        .disabled(viewModel.isLoadingVideo)
                    }
                }
            }
        }
    }

    private var preview: some View {
        Group {
            if viewModel.player != nil {
                GlassCard(padding: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(viewModel.displayName)
                                .font(.headline)
                                .foregroundStyle(textPrimary)
                            Spacer()
                            videoPickerControl {
                                Text("Cambiar")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                viewModel.resetSelection()
                            })
                        }

                        GeometryReader { proxy in
                            let phoneWidth = min(proxy.size.width * 0.5, 220)
                            let phoneHeight = phoneWidth * 16 / 9
                            VStack {
                                Spacer(minLength: 4)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(panel)
                                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(stroke))
                                        .frame(width: phoneWidth, height: phoneHeight)

                                    if let player = viewModel.player {
                                        VideoPlayer(player: player)
                                            .frame(width: phoneWidth, height: phoneHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                            .overlay(
                                                LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                            )
                                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(stroke))
                                            .onAppear { player.play() }
                                            .onDisappear { player.pause() }
                                    }
                                }
                                Spacer(minLength: 4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 320)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func videoPickerControl<Label: View>(@ViewBuilder label: @escaping () -> Label) -> some View {
#if os(iOS)
        if #available(iOS 16.0, *) {
            PhotosPickerButton(viewModel: viewModel, label: label)
        } else {
            Button(action: presentLegacyPicker) {
                label()
            }
        }
#else
        if #available(macOS 13.0, *) {
            PhotosPickerButton(viewModel: viewModel, label: label)
        } else {
            label()
        }
#endif
    }

    private var analyzeButton: some View {
        Button {
            if let report = viewModel.report {
                activeReport = report
                return
            }

            // Verificar créditos para usuarios no suscritos
            if !subscriptionManager.isSubscribed && !creditsManager.canAnalyze() {
                showPaywall = true
                return
            }

            guard viewModel.selectedVideoURL != nil else { return }

            Task {
                await viewModel.analyze()
                if let report = viewModel.report { activeReport = report }
            }
        } label: {
            HStack {
                if viewModel.isAnalyzing {
                    ProgressView()
                        .compatibleTint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: viewModel.selectedVideoURL == nil ? "plus" : (viewModel.report == nil ? "sparkles" : "eye"))
                }
                
                Text(getButtonText())
                    .fontWeight(.bold)
                Spacer()
            }
            .font(.title3)
            .padding()
            .frame(maxWidth: .infinity)
            .background(viewModel.report == nil ? Theme.recordRed : Theme.accent)
            .foregroundStyle(.white)
            .cornerRadius(18)
            .shadow(color: Color.red.opacity(0.3), radius: 16, y: 8)
        }
        .disabled(viewModel.isAnalyzing || viewModel.isLoadingVideo)
        .opacity((viewModel.isAnalyzing || viewModel.isLoadingVideo) ? 0.7 : 1)
    }

    private func inlineResults(_ report: AnalysisReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Hallazgos del análisis", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(textPrimary)
                    Spacer()
                    Text("Actualizado")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.4)))
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Visualizaciones estimadas")
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                        Text("~" + report.predictedViews.formatted())
                            .font(.title3.bold())
                            .foregroundStyle(Theme.accent)
                    }

                    Divider().frame(height: 42)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Puntuación media")
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                        Text("\(Int(report.metrics.averageScore))/100")
                            .font(.title3.bold())
                            .foregroundStyle(self.getScoreColor(Int(report.metrics.averageScore)))
                    }
                }

                MetricInsightsView(metrics: report.metrics)

                BenchmarkContextView()
                if let caseStudy = TrainingDataset.examples.first {
                    ExampleCaseStudyView(example: caseStudy)
                }
              

                if let details = report.analysisDetails {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Análisis visual específico")
                            .font(.subheadline.bold())
                            .foregroundStyle(textPrimary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            AnalysisDetailRow(icon: "target", title: "Hook", content: details.hookAnalysis)
                            AnalysisDetailRow(icon: "film", title: "Tema", content: details.mainTopicIdentified)
                            AnalysisDetailRow(icon: "face.smiling", title: "Emoción", content: details.emotionDetected)
                            AnalysisDetailRow(icon: "speedometer", title: "Ritmo", content: details.editingPace)
                            if !details.onScreenTextDetected.isEmpty && details.onScreenTextDetected.lowercased() != "ninguno" {
                                AnalysisDetailRow(icon: "text.alignleft", title: "Texto en pantalla", content: details.onScreenTextDetected)
                            }
                            AnalysisDetailRow(icon: "chart.bar.doc.horizontal", title: "Diagnóstico", content: details.whyWorksOrNot)
                        }
                        .padding(12)
                        .background(Theme.panel(scheme).opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(stroke))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Análisis visual específico")
                            .font(.subheadline.bold())
                            .foregroundStyle(textPrimary)
                        Text("Ejecuta un análisis para ver el desglose visual y el diagnóstico en esta sección.")
                            .font(.footnote)
                            .foregroundStyle(textSecondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Acciones inmediatas")
                        .font(.subheadline.bold())
                        .foregroundStyle(textPrimary)
                    Text("Aplica estos ajustes antes de publicar para mejorar el rendimiento.")
                        .font(.caption)
                        .foregroundStyle(textSecondary)

                    ForEach(Array(report.recommendations.prefix(3).enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            let icon = index == 0 ? "arrow.up.right.circle.fill" : index == 1 ? "wand.and.stars" : "bolt.fill"
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 16)
                            Text(item)
                                .font(.footnote)
                                .foregroundStyle(textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Theme.panel(scheme).opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(stroke.opacity(0.8)))
                    }
                }
            }
        }
    }

    private struct BenchmarkContextView: View {
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Label("Comparativa real", systemImage: "chart.bar.doc.horizontal")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primary(scheme))
                Text("Estas métricas se contrastan con \(TrainingDataset.examples.count.formatted()) reels auditados en nichos fitness, cocina, belleza y más. Actualizamos el benchmark cada semana con nuevos casos reales.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }
            .padding(12)
            .background(Theme.panel(scheme).opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.subtleStroke(scheme).opacity(0.8)))
        }
    }

    private struct ExampleCaseStudyView: View {
        let example: TrainingExample
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Caso real \(example.contentType.capitalized)", systemImage: "quote.bubble.fill")
                        .foregroundStyle(Theme.primary(scheme))
                        .font(.headline)
                    Spacer()
                    Text("~\(example.response.predictedViews.formatted()) views")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.accent)
                }

                Text(example.visualDescription)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))

                if let highlight = example.response.highlights.first {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.accent)
                        Text(highlight)
                            .font(.footnote)
                            .foregroundStyle(Theme.primary(scheme))
                    }
                }

                Text("Fuente: dataset interno con clips analizados manualmente. Usamos estos patrones como referencia para tus diagnósticos.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondary(scheme))
            }
            .padding(14)
            .background(Theme.panel(scheme).opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.subtleStroke(scheme)))
        }
    }

    private func getButtonText() -> String {
        if viewModel.isAnalyzing {
            return "La IA está trabajando..."
        } else if viewModel.report != nil {
            return "Ver resultado"
        } else if viewModel.selectedVideoURL == nil {
            return "Subir video"
        } else if !subscriptionManager.isSubscribed {
            let remaining = creditsManager.remainingAnalyses
            if remaining > 0 {
                return "Analizar (\(remaining)/3 restantes)"
            } else {
                return "Suscríbete para continuar"
            }
        } else {
            return "Iniciar análisis"
        }
    }

    private func presentPaywallIfNeeded() {
        guard subscriptionGateEnabled else { return }
        guard !subscriptionManager.isSubscribed, !hasPresentedPaywall else { return }
        if !showTutorial {
            showPaywall = true
            hasPresentedPaywall = true
        }
    }

    private func presentLegacyPicker() {
#if os(iOS)
        showLegacyVideoPicker = true
#endif
    }

    private func getScoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .blue }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// MARK: - Report Sheet

struct ReportSheet: View {
    let report: AnalysisReport
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var tab: ReportTab = .results

    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }

    var body: some View {
        CompatibleNavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        switch tab {
                        case .results:
                            ReportView(report: report)
                        case .tips:
                            tipsSection
                        case .improvements:
                            improvementsSection
                        }
                    }
                    .padding()
                }

                bottomTabBar
            }
            .navigationTitle("Resultado IA")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var bottomTabBar: some View {
        let shape = Capsule()

        return HStack(spacing: 10) {
            tabButton(.results, icon: "sparkles", title: "Resultados")
            tabButton(.tips, icon: "lightbulb.max.fill", title: "Consejos")
            tabButton(.improvements, icon: "chart.bar.fill", title: "Estadísticas")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: shape)
        .overlay(
            shape
                .stroke(Theme.subtleStroke(scheme).opacity(0.7))
        )
        .overlay(
            shape
                .stroke(
                    LinearGradient(
                        colors: [Theme.accentStart.opacity(0.34), Theme.accentEnd.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
        )
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.18), radius: 16, y: 10)
        .padding(.horizontal)
        .padding(.bottom, 18)
        .padding(.top, 6)
    }

    private func tabButton(_ target: ReportTab, icon: String, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                tab = target
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(tab == target ? Theme.accentStart : textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tab == target ? Theme.accentStart.opacity(0.16) : Color.clear)
            )
        }
    }

    private var tipsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Consejos de Creator Pro", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundStyle(textPrimary)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Content Strategy
                    TipCategory(
                        icon: "play.rectangle.on.rectangle",
                        title: "Estrategia de Contenido",
                        tips: getContentTips(from: report.metrics, analysisDetails: report.analysisDetails)
                    )
                    
                    Divider().background(Theme.subtleStroke(scheme))
                    
                    // Technical Tips
                    TipCategory(
                        icon: "wrench.and.screwdriver",
                        title: "Optimización Técnica",
                        tips: getTechnicalTips(from: report.metrics)
                    )
                    
                    Divider().background(Theme.subtleStroke(scheme))
                    
                    // Algorithm Hacks
                    TipCategory(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Trucos del Algoritmo",
                        tips: getAlgorithmTips(from: report.metrics)
                    )
                }
            }
        }
    }
    
    private func getContentTips(from metrics: EngagementMetrics, analysisDetails: AnalysisDetails? = nil) -> [String] {
        var tips: [String] = []
        
        if let details = analysisDetails {
            tips.append("Frames 1-2: muestra \(details.mainTopicIdentified.lowercased()) en primer plano con texto de 3 palabras en mayúsculas")
            tips.append(details.emotionDetected.lowercased() == "neutral" ? "Añade gesto claro o micro-reacción en el segundo 1 para anclar emoción" : "Refuerza la emoción \(details.emotionDetected.lowercased()) con un close-up rápido al inicio")
            tips.append(details.editingPace.contains("lento") ? "Haz cortes cada 2-3s en los primeros 10s y usa jump-cuts para acelerar" : "Equilibra el ritmo: deja 0.5s extra en el momento clave para que el mensaje se procese")
            return tips
        }
        
        if metrics.hookStrength < 70 {
            tips.append("Hook más directo: empieza con el resultado final y luego revela el proceso")
        }
        if metrics.retentionScore < 65 {
            tips.append("Divide el video en mini-hitos con texto '1/3', '2/3', '3/3' para retener")
        }
        tips.append("Cierra con CTA visual ('Guarda esto', 'Pruébalo hoy') en los últimos 2s")
        
        return Array(tips.prefix(3))
    }
    
    private func getTechnicalTips(from metrics: EngagementMetrics) -> [String] {
        var tips: [String] = []
        
        if metrics.messageClarity < 75 {
            tips.append("Texto nítido: usa 26-32pt, sombra suave y fondo negro 30% opacidad para legibilidad")
        }
        if metrics.pacing < 70 {
            tips.append("Ritmo: cortes cada 2.5s y planos alternos (close-up / plano medio) para mantener dinamismo")
        }
        tips.append("Audio limpio: reduce ruido con filtro de voz y sube música -6 dB por debajo de la voz")
        
        return Array(tips.prefix(3))
    }
    
    private func getAlgorithmTips(from metrics: EngagementMetrics) -> [String] {
        return [
            "Publica justo después de grabar: primeras 2h son críticas para impulso algorítmico",
            "Usa CTA de interacción: pregunta corta en pantalla y responde los 5 primeros comentarios",
            "Hashtags: 1 amplio (#viral), 2 de nicho y 1 geolocalizado; evita más de 5"
        ]
    }

    private var improvementsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                Label("Estadísticas de Rendimiento", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(textPrimary)
                
                AnimatedStatTableView(metrics: report.metrics)
                SparklineTableView(metrics: report.metrics)

                // Resumen de Predicción
                VStack(alignment: .leading, spacing: 12) {
                    Label("Predicción de Rendimiento", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.bold())

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Visualizaciones Estimadas")
                                .font(.caption)
                                .foregroundStyle(textSecondary)
                            Text("~\(report.predictedViews.formatted())")
                                .font(.title2.bold())
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Puntuación General")
                                .font(.caption)
                                .foregroundStyle(textSecondary)
                            Text("\(Int(report.metrics.averageScore))/100")
                                .font(.title2.bold())
                                .foregroundStyle(self.getScoreColor(Int(report.metrics.averageScore)))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func getScoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .blue }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

enum ReportTab: String, CaseIterable {
    case results = "Resultados"
    case tips = "Consejos Pro"
    case improvements = "Estadísticas"
}

// MARK: - Components

struct ReportView: View {
    let report: AnalysisReport
    @Environment(\.colorScheme) private var scheme

    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }
    private var panel: Color { Theme.panel(scheme) }
    private var stroke: Color { Theme.subtleStroke(scheme) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.title)
                            .font(.headline)
                        Text(report.formattedDate)
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Visualizaciones estimadas")
                            .font(.caption2)
                            .foregroundStyle(textSecondary)
                        Text("~" + report.predictedViews.formatted())
                            .font(.title3.bold())
                    }
                }
                .foregroundStyle(textPrimary)

                MetricsGrid(metrics: report.metrics)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Resumen rápido", systemImage: "sparkles.tv.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(textPrimary)

                    ForEach(Array(report.highlights.prefix(3).enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: index == 0 ? "scope" : index == 1 ? "eye.fill" : "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.accent)
                            Text(item)
                                .font(.footnote)
                                .foregroundStyle(textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.square.fill")
                            .foregroundStyle(Theme.accent)
                        Text("Los hallazgos detallados y las acciones inmediatas ahora aparecen justo bajo tu video.")
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                    }
                    .padding(10)
                    .background(Theme.panel(scheme).opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

struct MetricsGrid: View {
    let metrics: EngagementMetrics
    @Environment(\.colorScheme) private var scheme

    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }
    private var panel: Color { Theme.panel(scheme) }
    private var stroke: Color { Theme.subtleStroke(scheme) }

    var body: some View {
        let items: [(title: String, value: Double, icon: String)] = [
            ("Retención", metrics.retentionScore, "sparkles.tv"),
            ("Hook", metrics.hookStrength, "flame"),
            ("Claridad", metrics.messageClarity, "bubble.left.and.bubble.right"),
            ("Ritmo", metrics.pacing, "metronome"),
            ("Viralidad", metrics.viralityProbability, "chart.line.uptrend.xyaxis")
        ]

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(items.indices, id: \.self) { index in
                let metric = items[index]
                VStack(alignment: .leading, spacing: 10) {
                    Label(metric.title, systemImage: metric.icon)
                        .foregroundStyle(textPrimary)
                        .font(.caption.bold())
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Int(metric.value).formatted())
                            .font(.title3.bold())
                        Text("/100")
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                    }
                    MetricBar(value: metric.value)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(stroke))
            }
        }
    }
}

struct MetricBar: View {
    let value: Double
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(value / 100, 0), 1)
            let width = proxy.size.width * clamped
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.subtleStroke(scheme).opacity(0.6))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: width)
            }
        }
        .frame(height: 8)
    }
}

struct AnimatedStatTableView: View {
    let metrics: EngagementMetrics
    @Environment(\.colorScheme) private var scheme
    @State private var pulse = false

    private var rows: [(label: String, icon: String, value: Double, average: Double)] {
        [
            ("Retención", "sparkles.tv", metrics.retentionScore, 45),
            ("Hook", "bolt.heart", metrics.hookStrength, 60),
            ("Claridad", "textformat", metrics.messageClarity, 55),
            ("Ritmo", "metronome", metrics.pacing, 50),
            ("Viralidad", "chart.line.uptrend.xyaxis", metrics.viralityProbability, 35)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Barras dinámicas", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primary(scheme))
                Spacer()
                Text("Oscilación en tiempo real")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    AnimatedBarRow(row: row, pulse: pulse)
                    if index != rows.count - 1 {
                        Divider().padding(.horizontal, 10)
                    }
                }
            }
            .background(Theme.panel(scheme).opacity(0.12))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.subtleStroke(scheme)))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

struct AnimatedBarRow: View {
    let row: (label: String, icon: String, value: Double, average: Double)
    let pulse: Bool
    @Environment(\.colorScheme) private var scheme

    private var animatedValue: Double {
        let wobble: Double = pulse ? 4 : -4
        return min(max(row.value + wobble, 0), 100)
    }

    private var comparisonColor: Color {
        row.value >= row.average ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: row.icon)
                Text(row.label)
                    .font(.caption.bold())
            }
            .foregroundStyle(Theme.primary(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(Int(row.value))%")
                        .font(.caption.bold())
                    Text("frente a \(Int(row.average))%")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondary(scheme))
                }

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let maxWidth = width
                    let normalized = max(min(animatedValue / 100, 1), 0)
                    let barWidth = maxWidth * normalized

                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.subtleStroke(scheme).opacity(0.5))
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.accentStart.opacity(0.8), comparisonColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: barWidth)
                            .shadow(color: comparisonColor.opacity(0.25), radius: 6, y: 3)

                        let avgX = width * max(min(row.average / 100, 1), 0)
                        Rectangle()
                            .fill(comparisonColor)
                            .frame(width: 2)
                            .offset(x: avgX - 1)
                            .opacity(0.7)
                    }
                }
                .frame(height: 12)
            }
            .frame(width: 180)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

struct SparklineTableView: View {
    let metrics: EngagementMetrics
    @Environment(\.colorScheme) private var scheme
    @State private var phase = false

    private var rows: [(label: String, icon: String, points: [Double])] {
        [
            ("Engagement", "waveform.path", sparkline(for: metrics.retentionScore)),
            ("Hook", "bolt", sparkline(for: metrics.hookStrength)),
            ("Claridad", "text.justify", sparkline(for: metrics.messageClarity)),
            ("Ritmo", "metronome", sparkline(for: metrics.pacing)),
            ("Viralidad", "flame", sparkline(for: metrics.viralityProbability))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Sparklines dinámicos", systemImage: "waveform.path.ecg")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primary(scheme))
                Spacer()
                Text("Mini tendencias animadas")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    SparklineRow(row: row, phase: phase)
                    if index != rows.count - 1 {
                        Divider().padding(.horizontal, 10)
                    }
                }
            }
            .background(Theme.panel(scheme).opacity(0.12))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.subtleStroke(scheme)))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                phase.toggle()
            }
        }
    }

    private func sparkline(for value: Double) -> [Double] {
        let base = max(min(value, 100), 0)
        return [0.6, 0.75, 0.5, 0.8, 0.65, 0.9, 0.7].map { $0 * (base / 100) }
    }
}

struct SparklineRow: View {
    let row: (label: String, icon: String, points: [Double])
    let phase: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: row.icon)
                Text(row.label)
                    .font(.caption.bold())
            }
            .foregroundStyle(Theme.primary(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)

            Sparkline(points: row.points, phase: phase)
                .frame(width: 180, height: 40)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

struct Sparkline: View {
    let points: [Double]
    let phase: Bool
    @Environment(\.colorScheme) private var scheme

    private var animatedPoints: [Double] {
        points.enumerated().map { idx, val in
            let offset = phase ? 0.06 : -0.06
            return max(min(val + offset * (idx.isMultiple(of: 2) ? 1 : -1), 1), 0)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let data = animatedPoints
            let step = data.count > 1 ? width / CGFloat(data.count - 1) : 0

            Path { path in
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * step
                    let y = height - (CGFloat(value) * height)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(LinearGradient(colors: [Theme.accentStart, Theme.accentEnd.opacity(0.5)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: Theme.accentStart.opacity(0.25), radius: 4, y: 2)

            if let last = data.last {
                let x = width
                let y = height - (CGFloat(last) * height)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .position(x: x, y: y)
            }
        }
    }
}

struct MetricInsightsView: View {
    let metrics: EngagementMetrics
    @Environment(\.colorScheme) private var scheme
    @State private var selected: MetricKind = .retention
    @State private var phase = false

    private var detail: MetricDetail {
        metricDetail(for: selected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Deep dive por métrica", systemImage: "slider.horizontal.3")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primary(scheme))
                Spacer()
                Text("Toca una métrica para ver mejoras")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }

            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MetricKind.allCases, id: \.self) { kind in
                    let item = metricDetail(for: kind)
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selected = kind
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: kind.icon)
                                Text(kind.label)
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(Theme.primary(scheme))

                            Text("\(Int(item.value))%")
                                .font(.headline.bold())
                                .foregroundStyle(Theme.primary(scheme))

                            Text("Objetivo: \(Int(item.goal))%")
                                .font(.caption)
                                .foregroundStyle(Theme.secondary(scheme))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected == kind ? Theme.panel(scheme).opacity(0.5) : Theme.panel(scheme).opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected == kind ? Theme.accentStart.opacity(0.6) : Theme.subtleStroke(scheme)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)

            MetricInsightChart(points: chartPoints(for: detail), color: detail.color, phase: phase)
                .frame(height: 140)
                .background(Theme.panel(scheme).opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.subtleStroke(scheme)))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Actual vs objetivo")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.primary(scheme))
                    Spacer()
                    Text("\(Int(detail.value))% / \(Int(detail.goal))%")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                }

                MetricProgressBar(value: detail.value, goal: detail.goal, color: detail.color)

                Text(detail.gapText)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Parámetros clave para subir la métrica")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.primary(scheme))

                ForEach(detail.levers, id: \.self) { lever in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.caption)
                            .foregroundStyle(detail.color)
                        Text(lever)
                            .font(.footnote)
                            .foregroundStyle(Theme.primary(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Theme.panel(scheme).opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.subtleStroke(scheme)))
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                phase.toggle()
            }
        }
    }

    private func chartPoints(for detail: MetricDetail) -> [Double] {
        let normalized = max(min(detail.value / 100, 1), 0)
        let base: [Double] = [0.5, 0.6, 0.55, 0.65, 0.62, 0.7, 0.75]
        return base.enumerated().map { idx, val in
            let wobble = phase ? 0.035 : -0.035
            return max(min(val * normalized + wobble * (idx.isMultiple(of: 2) ? 1 : -1), 1), 0)
        }
    }

    private func metricDetail(for kind: MetricKind) -> MetricDetail {
        switch kind {
        case .retention:
            return MetricDetail(label: "Retención", icon: kind.icon, value: metrics.retentionScore, goal: 65, color: .blue, levers: [
                "Cortes cada 2-3s en los primeros 8s",
                "Texto en pantalla de 3-5 palabras con contraste alto",
                "Muestra resultado/beneficio antes del segundo 4"
            ])
        case .hook:
            return MetricDetail(label: "Hook", icon: kind.icon, value: metrics.hookStrength, goal: 70, color: .orange, levers: [
                "Empieza con la promesa final en 1 frase",
                "Incluye gesto o close-up al decir la frase clave",
                "Usa subtítulos grandes en la primera línea"
            ])
        case .clarity:
            return MetricDetail(label: "Claridad", icon: kind.icon, value: metrics.messageClarity, goal: 72, color: .teal, levers: [
                "Un mensaje principal por escena, sin desvíos",
                "Texto alineado a un lado, no sobre la cara",
                "Contraste alto entre fondo y tipografía"
            ])
        case .pacing:
            return MetricDetail(label: "Ritmo", icon: kind.icon, value: metrics.pacing, goal: 68, color: .purple, levers: [
                "Alterna planos cada 1.5-2.5s al inicio",
                "Inserta b-roll rápido para cada afirmación",
                "Silencios < 0.8s; rellena con texto o efecto"
            ])
        case .virality:
            return MetricDetail(label: "Viralidad", icon: kind.icon, value: metrics.viralityProbability, goal: 60, color: .pink, levers: [
                "Cierra con un CTA guardable o retador",
                "Usa contraste de emoción entre inicio y cierre",
                "Títulos con número o promesa concreta (\"Antes/Después\", \"En 3 pasos\")"
            ])
        }
    }
}

private enum MetricKind: CaseIterable {
    case retention, hook, clarity, pacing, virality

    var label: String {
        switch self {
        case .retention: return "Retención"
        case .hook: return "Hook"
        case .clarity: return "Claridad"
        case .pacing: return "Ritmo"
        case .virality: return "Viralidad"
        }
    }

    var icon: String {
        switch self {
        case .retention: return "sparkles.tv"
        case .hook: return "bolt.heart"
        case .clarity: return "text.alignleft"
        case .pacing: return "speedometer"
        case .virality: return "chart.line.uptrend.xyaxis"
        }
    }
}

private struct MetricDetail {
    let label: String
    let icon: String
    let value: Double
    let goal: Double
    let color: Color
    let levers: [String]

    var gapText: String {
        let gap = max(goal - value, 0)
        if gap <= 0 { return "Ya alcanzaste el objetivo de \(label.lowercased())." }
        return "Faltan ~\(Int(gap)) puntos para el objetivo de \(Int(goal))%."
    }
}

private struct MetricInsightChart: View {
    let points: [Double]
    let color: Color
    let phase: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let step = points.count > 1 ? width / CGFloat(points.count - 1) : 0

            let clamped = points.map { max(min($0, 1), 0) }

            Path { path in
                guard let first = clamped.first else { return }
                path.move(to: CGPoint(x: 0, y: height - CGFloat(first) * height))
                for (index, value) in clamped.enumerated() where index > 0 {
                    let x = CGFloat(index) * step
                    let y = height - CGFloat(value) * height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.25), radius: 6, y: 3)

            Path { path in
                guard let first = clamped.first else { return }
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: 0, y: height - CGFloat(first) * height))
                for (index, value) in clamped.enumerated() where index > 0 {
                    let x = CGFloat(index) * step
                    let y = height - CGFloat(value) * height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [color.opacity(0.25), color.opacity(0.05)], startPoint: .top, endPoint: .bottom))

            if let last = clamped.last {
                let x = width
                let y = height - CGFloat(last) * height
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .position(x: x, y: y)
            }
        }
    }
}

private struct MetricProgressBar: View {
    let value: Double
    let goal: Double
    let color: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let normalizedValue = max(min(value / 100, 1), 0)
            let normalizedGoal = max(min(goal / 100, 1), 0)
            let valueWidth = width * normalizedValue
            let goalX = width * normalizedGoal

            ZStack(alignment: .leading) {
                Capsule().fill(Theme.subtleStroke(scheme).opacity(0.6))
                Capsule()
                    .fill(color)
                    .frame(width: valueWidth)

                Rectangle()
                    .fill(color.opacity(0.9))
                    .frame(width: 2)
                    .offset(x: goalX - 1)
            }
        }
        .frame(height: 10)
    }
}

struct LoadingOverlay: View {
    @Environment(\.colorScheme) private var scheme
    @State private var currentMessage = 0
    @State private var timer: Timer?
    
    private let messages: [(icon: String, text: String)] = [
        ("brain.head.profile", "La IA está analizando tu contenido..."),
        ("sparkles", "Detectando potencial viral..."),
        ("target", "Calculando métricas de engagement..."),
        ("rocket.fill", "Prediciendo cantidad de visualizaciones..."),
        ("chart.bar.xaxis", "Generando insights..."),
        ("film.fill", "Casi listo, finalizando resultados...")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    ProgressView()
                        .compatibleTint(Theme.accentStart)
                        .scaleEffect(1.5)
                }
                
                VStack(spacing: 8) {
                    Label(messages[currentMessage].text, systemImage: messages[currentMessage].icon)
                        .font(.headline)
                        .foregroundStyle(Theme.primary(scheme))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.5), value: currentMessage)
                        .labelStyle(.titleAndIcon)
                        .compatibleTint(Theme.accentStart)
                    
                    Text("Esto puede tomar unos segundos")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .onAppear {
            startMessageRotation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startMessageRotation() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentMessage = (currentMessage + 1) % messages.count
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var content: () -> Content
    @Environment(\.colorScheme) private var scheme

    init(padding: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.subtleStroke(scheme)))
            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 12)
    }
}

struct BackgroundGlow: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent)
                .blur(radius: 140)
                .offset(x: -120, y: -260)
                .opacity(0.6)
            Circle()
                .fill(Color.purple)
                .blur(radius: 160)
                .offset(x: 160, y: 180)
                .opacity(0.35)
        }
        .ignoresSafeArea()
    }
}

struct OnboardingView: View {
    let onDone: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var index = 0

    private var steps: [OnboardingStep] {
        [
            OnboardingStep(title: "Sube un video vertical", description: "Selecciona tu video MP4/MOV y previéwalo en formato 9:16 instantáneamente.", icon: "video.fill"),
            OnboardingStep(title: "Reproducción + botón IA", description: "Revisa la vista previa y toca \"Iniciar análisis\" para enviarlo a la IA.", icon: "sparkles"),
            OnboardingStep(title: "Resultados y consejos", description: "Ve puntuaciones, visualizaciones predichas y sugerencias. El historial se guarda.", icon: "chart.line.uptrend.xyaxis")
        ]
    }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()
            BackgroundGlow()

            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    Button("Omitir") { finish() }
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.primary(scheme))
                }
                .padding(.horizontal)

                Spacer()

                TabView(selection: $index) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        stepView(step)
                            .tag(idx)
                            .padding(.horizontal)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 260)

                HStack {
                    ForEach(steps.indices, id: \.self) { idx in
                        let color = idx == index ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.subtleStroke(scheme))
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                    }
                }

                Button(action: advance) {
                    Text(index == steps.count - 1 ? "Listo" : "Siguiente")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.recordRed)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .shadow(color: Color.red.opacity(0.3), radius: 12, y: 6)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical, 40)
        }
    }

    @ViewBuilder
    private func stepView(_ step: OnboardingStep) -> some View {
        VStack(spacing: 16) {
            Image(systemName: step.icon)
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
            Text(step.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.primary(scheme))
            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondary(scheme))
                .padding(.horizontal)
        }
    }

    private func advance() {
        if index < steps.count - 1 {
            withAnimation { index += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        onDone()
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
}

struct HistoryView: View {
    let reports: [AnalysisReport]
    var onSelect: (AnalysisReport) -> Void

    var body: some View {
        CompatibleNavigationStack {
            List {
                ForEach(reports) { report in
                    Button {
                        onSelect(report)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.title)
                                .font(.headline)
                            Text(report.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Label("Puntuación \(Int(report.metrics.averageScore))", systemImage: "star.fill")
                                Spacer()
                                Label("~\(report.predictedViews.formatted()) vistas", systemImage: "eye")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Historial")
        }
    }
}

#Preview {
    ContentView()
}

#if canImport(PhotosUI)
@available(iOS 16.0, macOS 13.0, *)
private struct PhotosPickerButton<Label: View>: View {
    @ObservedObject var viewModel: AnalyzerViewModel
    let label: () -> Label
    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .videos) {
            label()
        }
        .task(id: selection) {
            guard let selection else { return }
            await viewModel.loadVideo(from: selection)
            await MainActor.run { self.selection = nil }
        }
    }
}
#endif
