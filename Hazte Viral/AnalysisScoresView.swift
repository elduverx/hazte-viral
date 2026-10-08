//
//  AnalysisScoresView.swift
//  goviiral
//

import SwiftUI

/// Valoración global del vídeo. Deja claro que no es una predicción de visualizaciones.
struct PotentialCard: View {
    let report: AnalysisReport
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let potential = report.potential
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Potencial del vídeo")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondary(scheme))
                    Text(potential.title)
                        .font(.title2.bold())
                        .foregroundStyle(potential.tint)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(report.overallScore, format: .number.precision(.fractionLength(1)))
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(Theme.primary(scheme))
                    Text("/10")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary(scheme))
                }
            }

            Text(potential.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.primary(scheme))

            Label {
                Text("Valora cómo está hecho el vídeo, no predice visualizaciones: el alcance depende de tu cuenta, tu audiencia, cuándo publicas y el algoritmo.")
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(Theme.secondary(scheme))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(potential.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(potential.tint.opacity(0.3)))
    }
}

/// Las puntuaciones que la IA ha medido, cada una con su motivo.
struct DimensionScoresView: View {
    let report: AnalysisReport
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Qué ha medido la IA")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.primary(scheme))

            ForEach(report.dimensionScores) { dimension in
                DimensionRow(dimension: dimension)
            }

            if report.scores == nil {
                Text("Análisis anterior: solo incluye hook y calidad visual. Vuelve a analizar el vídeo para ver claridad y ritmo con sus motivos.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }
        }
    }
}

private struct DimensionRow: View {
    let dimension: ScoreDimension
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: dimension.kind.icon)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accentStart)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(dimension.kind.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary(scheme))
                    Text(dimension.kind.question)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                }
                Spacer()
                Text("\(dimension.score)/10")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.primary(scheme))
            }

            SegmentedScoreBar(score: dimension.score)

            if !dimension.reason.isEmpty {
                Text(dimension.reason)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// 10 segmentos: se lee como "7 de 10", no como un porcentaje preciso.
private struct SegmentedScoreBar: View {
    let score: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .fill(index < score ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.subtleStroke(scheme)))
                    .frame(height: 6)
            }
        }
    }
}

extension PotentialLevel {
    var tint: Color {
        switch self {
        case .needsWork: return .orange
        case .promising: return .yellow
        case .strong: return .green
        case .veryStrong: return .mint
        }
    }
}
