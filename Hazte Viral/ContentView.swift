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
    @State private var showAnalysisScreen = false
    @State private var pendingAIAction: (() -> Void)?
    @State private var analysisFinished = false
    @State private var hasPresentedPaywall = false
#if os(iOS)
    @State private var showLegacyVideoPicker = false
#endif
    private let subscriptionGateEnabled = AppMonetization.paymentsEnabled

    /// El error se muestra cuando ya no está la pantalla de carga encima.
    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { viewModel.showError && !showAnalysisScreen },
                set: { viewModel.showError = $0 })
    }

    private func presentAnalysisResult() {
        guard analysisFinished else { return }
        analysisFinished = false
        activeReport = viewModel.report
    }

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

            }
        }
        .fullScreenCover(isPresented: $showAnalysisScreen, onDismiss: presentAnalysisResult) {
            AnalysisLoadingScreen(
                videoURL: viewModel.selectedVideoURL,
                stage: viewModel.analysisStage,
                finished: analysisFinished,
                onCancel: { viewModel.cancelAnalysis() }
            )
        }
        .onChange(of: viewModel.isAnalyzing) { _, analyzing in
            if analyzing {
                analysisFinished = false
                viewModel.player?.pause()
                showAnalysisScreen = true
            } else if viewModel.report != nil {
                // Un instante de "Análisis listo" antes de abrir el resultado
                analysisFinished = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    showAnalysisScreen = false
                }
            } else {
                showAnalysisScreen = false
            }
        }
        .sheet(item: $activeReport) { report in
            ReportSheet(report: report)
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
        .aiConsentSheet(pendingAction: $pendingAIAction)
        .alert("Error", isPresented: errorAlertBinding, actions: {
            Button("Entendido", role: .cancel) {}
        }, message: {
            Text(viewModel.errorMessage ?? "Error inesperado")
        })
        .onChange(of: viewModel.report) { _, report in
            // Tras un análisis, el resultado se abre al cerrar la pantalla de carga
            guard !showAnalysisScreen else { return }
            activeReport = report
        }
        .onChange(of: subscriptionManager.isSubscribed) { _, isActive in
            if isActive { showPaywall = false }
            if isActive { hasPresentedPaywall = true }
        }
        .onAppear { 
            Task { 
                if subscriptionManager.products.isEmpty { await subscriptionManager.refreshProducts() }
                await subscriptionManager.updateSubscriptionStatus()
                presentPaywallIfNeeded() 
            }
        }
        .onChange(of: showTutorial) { _, _ in 
            Task { 
                if subscriptionManager.products.isEmpty { await subscriptionManager.refreshProducts() }
                await subscriptionManager.updateSubscriptionStatus()
                presentPaywallIfNeeded() 
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
            HStack(spacing: 10) {
                ProStatusButton { showPaywall = true }
                Button {
                    viewModel.showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .padding(10)
                        .background(panel, in: Circle())
                }
                .foregroundStyle(textPrimary)
                .accessibilityLabel("Historial")
            }
        }
    }

    private var subscriptionBanner: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Go Viral Pro")
                        .font(.headline)
                        .foregroundStyle(textPrimary)
                    Text("Te quedan \(creditsManager.remainingAnalyses) de \(AnalysisCreditsManager.freeMonthlyLimit) análisis gratis este mes. Con Pro, análisis y guiones sin límite.")
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }

                Spacer()

                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                        Text("Ver Pro")
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

            runWithAIConsent($pendingAIAction) {
                Task {
                    await viewModel.analyze()
                    if !showAnalysisScreen, let report = viewModel.report { activeReport = report }
                }
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

                PotentialCard(report: report)
                DimensionScoresView(report: report)

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
        // Si la App Store no devuelve los planes, no abrimos un paywall vacío al arrancar.
        guard !subscriptionManager.products.isEmpty else { return }
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
}

enum ReportTab: String, CaseIterable {
    case results = "Resultados"
    case tips = "Consejos Pro"
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
                            .lineLimit(2)
                        Text(report.formattedDate)
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(textPrimary)

                PotentialCard(report: report)
                DimensionScoresView(report: report)

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
            OnboardingStep(title: "Resultados y consejos", description: "Ve qué funciona, qué mejorar y por qué, frame a frame. El historial se guarda.", icon: "chart.line.uptrend.xyaxis")
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
                                Label(report.potential.title, systemImage: "sparkles")
                                Spacer()
                                Text("\(report.overallScore, format: .number.precision(.fractionLength(1)))/10")
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
