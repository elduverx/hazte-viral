//
//  AIProcessingView.swift
//  goviiral
//

import SwiftUI

/// Pantalla de carga de la IA. Muestra las etapas reales del trabajo (no mensajes en bucle)
/// y el tiempo transcurrido. La animación se dibuja con TimelineView a 30 fps, sin blur,
/// se pausa con "Reducir movimiento" y deja de dibujarse cuando la vista desaparece.
struct AIProcessingView: View {
    let title: String
    let stages: [String]
    /// Índice de la etapa en curso dentro de `stages`.
    let currentStage: Int
    var onCancel: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    var body: some View {
        ZStack {
            Color.black.opacity(scheme == .dark ? 0.6 : 0.35)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                AIOrb(paused: reduceMotion)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.primary(scheme))
                        .multilineTextAlignment(.center)

                    ElapsedTimeText(since: startDate)
                }

                AIStageList(stages: stages, currentStage: currentStage)

                if let onCancel {
                    Button("Cancelar", action: onCancel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.secondary(scheme))
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.subtleStroke(scheme)))
            .padding(24)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(stages[safe: currentStage] ?? "")")
    }
}

/// Lista de etapas: hechas (✓), en curso (spinner) y pendientes.
struct AIStageList: View {
    let stages: [String]
    let currentStage: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                StageRow(text: stage, state: index < currentStage ? .done : index == currentStage ? .active : .pending)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: currentStage)
    }
}

/// "12 s" que se actualiza solo una vez por segundo.
struct ElapsedTimeText: View {
    let since: Date
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { context in
            let seconds = max(0, Int(context.date.timeIntervalSince(since)))
            Text(seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min \(seconds % 60) s")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.secondary(scheme))
        }
    }
}

struct StageRow: View {
    enum State { case done, active, pending }

    let text: String
    let state: State
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accentStart)
                        .transition(.scale.combined(with: .opacity))
                case .active:
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.accentStart)
                case .pending:
                    Circle()
                        .stroke(Theme.subtleStroke(scheme), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }
            }
            .frame(width: 20, height: 20)

            Text(text)
                .font(.subheadline.weight(state == .active ? .semibold : .regular))
                .foregroundStyle(state == .pending ? Theme.secondary(scheme).opacity(0.6) : Theme.primary(scheme))
        }
    }
}

/// Anillo con degradado que gira y un núcleo que respira. Un solo Canvas por frame.
struct AIOrb: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let radius = min(size.width, size.height) / 2
                let lineWidth: CGFloat = 5

                // Pista del anillo
                let track = Path(ellipseIn: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
                ctx.stroke(track, with: .color(Theme.accentStart.opacity(0.12)), lineWidth: lineWidth)

                // Arco que gira: cola transparente en violeta que termina en rosa intenso.
                // Se dibuja por segmentos para controlar color y opacidad a lo largo del arco.
                let segments = 36
                let sweep = 250.0
                let start = t * 140 // grados
                for i in 0..<segments {
                    let f = Double(i) / Double(segments - 1)
                    var segment = Path()
                    segment.addArc(center: center, radius: radius - lineWidth / 2,
                                   startAngle: .degrees(start + sweep * Double(i) / Double(segments)),
                                   endAngle: .degrees(start + sweep * Double(i + 1) / Double(segments)),
                                   clockwise: false)
                    let color = Color(red: 0.4 + 0.6 * f, green: 0.2, blue: 1 - 0.5 * f) // accentEnd → accentStart
                    ctx.stroke(segment, with: .color(color.opacity(f)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: i == segments - 1 ? .round : .butt))
                }

                // Núcleo que respira
                let pulse = 0.5 + 0.5 * sin(t * 2.2)
                let coreRadius = radius * (0.42 + 0.06 * pulse)
                let core = Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius,
                                                  width: coreRadius * 2, height: coreRadius * 2))
                ctx.fill(core, with: .radialGradient(
                    Gradient(colors: [Theme.accentStart.opacity(0.95), Theme.accentEnd.opacity(0.75)]),
                    center: center, startRadius: 0, endRadius: coreRadius))

                // Halo suave alrededor del núcleo (sin blur: un degradado radial)
                let haloRadius = coreRadius * 1.6
                let halo = Path(ellipseIn: CGRect(x: center.x - haloRadius, y: center.y - haloRadius,
                                                  width: haloRadius * 2, height: haloRadius * 2))
                ctx.fill(halo, with: .radialGradient(
                    Gradient(colors: [Theme.accentStart.opacity(0.25 * pulse), .clear]),
                    center: center, startRadius: coreRadius, endRadius: haloRadius))
            }
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    AIProcessingView(
        title: "Analizando tu vídeo",
        stages: ["Extrayendo fotogramas", "Enviando a la IA", "Analizando hook, ritmo y mensaje"],
        currentStage: 1,
        onCancel: {}
    )
}
