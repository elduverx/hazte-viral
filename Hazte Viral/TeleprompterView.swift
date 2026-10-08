//
//  TeleprompterView.swift
//  goviiral
//

import SwiftUI
import UIKit

/// Teleprompter a pantalla completa para leer el guion mientras se graba.
/// El desplazamiento se calcula a partir del tiempo (no se acumula frame a frame), así que
/// va suave a cualquier tasa de refresco y no consume nada mientras está en pausa.
struct TeleprompterView: View {
    let script: UGCScript

    @Environment(\.dismiss) private var dismiss
    @AppStorage("teleprompter.speed") private var speed: Double = 45      // puntos por segundo
    @AppStorage("teleprompter.fontSize") private var fontSize: Double = 34
    @AppStorage("teleprompter.mirrored") private var mirrored = false

    @State private var isPlaying = false
    @State private var playStart = Date()
    @State private var baseOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var showSettings = false

    private let readingLine: CGFloat = 0.32 // posición de la línea de lectura (fracción de la altura)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                TimelineView(.animation(paused: !isPlaying)) { context in
                    let offset = currentOffset(at: context.date)
                    scrollingText(width: geo.size.width)
                        .offset(y: geo.size.height * readingLine - offset)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
                .overlay(alignment: .top) { readingGuide(height: geo.size.height) }
                .overlay(alignment: .bottom) {
                    // Fundido para que el texto no compita con los controles
                    LinearGradient(stops: [.init(color: .black.opacity(0), location: 0),
                                           .init(color: .black.opacity(0.9), location: 0.45),
                                           .init(color: .black, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 320)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .onTapGesture { togglePlay() }
            }
            .clipped()

            if let countdown {
                Text("\(countdown)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .transition(.opacity)
            }

            VStack {
                topBar
                Spacer()
                if showSettings { settingsPanel.transition(.move(edge: .bottom).combined(with: .opacity)) }
                controls
            }
            .opacity(isPlaying ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.25), value: isPlaying)
        }
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            countdownTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: speed) { oldSpeed, _ in
            // Consolidar lo recorrido con la velocidad anterior para que no salte.
            guard isPlaying else { return }
            let now = Date()
            baseOffset = clamp(baseOffset + CGFloat(oldSpeed * now.timeIntervalSince(playStart)))
            playStart = now
        }
    }

    // MARK: - Texto

    private func scrollingText(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: fontSize * 0.9) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(fontSize * 0.25)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Color.clear.frame(height: 400) // margen para que la última línea llegue a la guía
        }
        .padding(.horizontal, 28)
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true) // el texto ocupa toda la altura que necesite
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { contentHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, height in contentHeight = height }
        })
    }

    private var paragraphs: [String] {
        [script.hook] + script.body + [script.cta]
    }

    private func readingGuide(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: height * readingLine - 20)
            Rectangle()
                .fill(Theme.accentStart.opacity(0.18))
                .frame(height: fontSize * 1.6)
                .overlay(alignment: .leading) {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accentStart)
                        .padding(.leading, 8)
                }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Desplazamiento

    private var maxOffset: CGFloat { max(0, contentHeight - 400) }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(0, value), maxOffset)
    }

    private func currentOffset(at date: Date) -> CGFloat {
        let running = isPlaying ? CGFloat(speed * date.timeIntervalSince(playStart)) : 0
        return clamp(baseOffset + running - dragTranslation)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isPlaying { pause() }
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                baseOffset = clamp(baseOffset - value.translation.height)
                dragTranslation = 0
            }
    }

    private func togglePlay() {
        if isPlaying || countdown != nil {
            pause()
        } else if baseOffset == 0 {
            startCountdown()
        } else {
            play()
        }
    }

    private func play() {
        if baseOffset >= maxOffset { baseOffset = 0 }
        playStart = Date()
        isPlaying = true
    }

    private func pause() {
        countdownTask?.cancel()
        countdown = nil
        guard isPlaying else { return }
        baseOffset = currentOffset(at: Date())
        isPlaying = false
    }

    private func restart() {
        pause()
        baseOffset = 0
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                withAnimation { countdown = value }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            withAnimation { countdown = nil }
            play()
        }
    }

    // MARK: - Controles

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Cerrar teleprompter")
            Spacer()
            Label("~\(script.estimatedSeconds) s", systemImage: "clock")
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var controls: some View {
        HStack(spacing: 36) {
            Button(action: restart) {
                Image(systemName: "backward.end.fill").font(.title2)
            }
            .accessibilityLabel("Volver al principio")

            Button(action: togglePlay) {
                Image(systemName: isPlaying || countdown != nil ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 72, height: 72)
                    .background(Theme.accent, in: Circle())
            }
            .accessibilityLabel(isPlaying ? "Pausar" : "Reproducir")

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showSettings.toggle() }
            } label: {
                Image(systemName: "slider.horizontal.3").font(.title2)
            }
            .accessibilityLabel("Ajustes")
        }
        .foregroundStyle(.white)
        .padding(.bottom, 24)
    }

    private var settingsPanel: some View {
        VStack(spacing: 16) {
            settingRow(icon: "hare.fill", title: "Velocidad") {
                Slider(value: $speed, in: 15...120)
            }
            settingRow(icon: "textformat.size", title: "Tamaño") {
                Slider(value: $fontSize, in: 22...60, step: 2)
            }
            Toggle(isOn: $mirrored) {
                Label("Modo espejo", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
        }
        .tint(Theme.accentStart)
        .foregroundStyle(.white)
        .padding(20)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func settingRow<Control: View>(icon: String, title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24)
            Text(title).frame(width: 80, alignment: .leading)
            control()
        }
        .font(.subheadline)
    }
}
