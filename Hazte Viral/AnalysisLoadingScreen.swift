//
//  AnalysisLoadingScreen.swift
//  goviiral
//

import SwiftUI
import AVFoundation
import UIKit

/// Pantalla completa mientras la IA analiza un vídeo: solo el vídeo y el progreso, sin nada alrededor.
struct AnalysisLoadingScreen: View {
    let videoURL: URL?
    let stage: AnalysisStage
    /// true durante el instante final, cuando el análisis ya terminó y se va a mostrar el resultado.
    let finished: Bool
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var stageStart = Date()

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer(minLength: 16)

                videoCard
                    .frame(height: min(geo.size.height * 0.5, 460))

                Spacer(minLength: 24)

                VStack(spacing: 20) {
                    progressBar

                    VStack(spacing: 6) {
                        Text(finished ? "Análisis listo" : stage.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                        Text(finished ? "Abriendo tu resultado…" : "Suele tardar entre 10 y 30 segundos")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .animation(.easeInOut(duration: 0.3), value: stage)
                    .animation(.easeInOut(duration: 0.3), value: finished)

                    AIStageList(stages: AnalysisStage.allCases.map(\.title),
                                currentStage: finished ? AnalysisStage.allCases.count : stage.rawValue)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 16)

                Button("Cancelar análisis", action: onCancel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(finished ? 0 : 0.7))
                    .disabled(finished)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: stage) { _, _ in stageStart = Date() }
        .sensoryFeedback(.impact(weight: .light), trigger: stage)
        .sensoryFeedback(.success, trigger: finished)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Partes

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                PulsingDot(paused: reduceMotion || finished)
                Text("IA analizando")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.1), in: Capsule())

            Spacer()

            ElapsedTimeText(since: startDate)
        }
    }

    private var videoCard: some View {
        ZStack {
            if let videoURL {
                LoopingVideoView(url: videoURL)
            } else {
                Color.white.opacity(0.05)
            }

            // Velo para que el escaneo destaque sobre cualquier vídeo
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)

            if !finished {
                ScanOverlay(paused: reduceMotion)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white, Theme.accentStart)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.12)))
        .overlay(ViewfinderCorners().stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round)).padding(-10))
        .shadow(color: Theme.accentEnd.opacity(0.35), radius: 40, y: 10)
        .animation(.spring(duration: 0.4), value: finished)
    }

    /// Barra de progreso estimado: avanza por etapas reales y, mientras la IA trabaja,
    /// se acerca poco a poco al final sin llegar nunca hasta que hay resultado.
    private var progressBar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: finished || reduceMotion)) { context in
            let value = progress(at: context.date)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(Theme.accent)
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 6)
        }
        .accessibilityHidden(true)
    }

    private func progress(at date: Date) -> CGFloat {
        if finished { return 1 }
        let elapsed = date.timeIntervalSince(stageStart)
        switch stage {
        case .extractingFrames: return 0.04 + 0.11 * (1 - exp(-elapsed / 1.5))
        case .uploading: return 0.15 + 0.15 * (1 - exp(-elapsed / 2))
        case .analyzing: return 0.30 + 0.65 * (1 - exp(-elapsed / 12))
        }
    }
}

// MARK: - Componentes

/// Línea de escaneo que recorre el vídeo de arriba abajo.
private struct ScanOverlay: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { context in
            GeometryReader { geo in
                let period = 2.4
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                let eased = 0.5 - 0.5 * cos(phase * 2 * .pi) // va y vuelve con suavidad
                let y = geo.size.height * eased

                ZStack(alignment: .top) {
                    LinearGradient(colors: [Theme.accentStart.opacity(0), Theme.accentStart.opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 90)
                        .offset(y: y - 90)
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(height: 2)
                        .offset(y: y)
                        .shadow(color: Theme.accentStart, radius: 6)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Esquinas de visor de cámara alrededor del vídeo.
private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.12
        var path = Path()
        // arriba-izquierda
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        // arriba-derecha
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        // abajo-derecha
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        // abajo-izquierda
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

private struct PulsingDot: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { context in
            let pulse = 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 4)
            Circle()
                .fill(Theme.accentStart)
                .frame(width: 8, height: 8)
                .opacity(paused ? 1 : 0.45 + 0.55 * pulse)
        }
    }
}

/// Vídeo en bucle, sin sonido y sin controles.
private struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        uiView.playerLayer.player?.pause()
        uiView.playerLayer.player = nil
        coordinator.looper = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looper: AVPlayerLooper?
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
