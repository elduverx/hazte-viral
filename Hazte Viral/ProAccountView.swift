//
//  ProAccountView.swift
//  goviiral
//

import SwiftUI
import StoreKit

/// "Tu plan Pro": estado de la suscripción, lo que el usuario ha hecho con Pro y,
/// antes de cancelar, un paso de retención. La cancelación siempre queda a un toque más
/// (Apple exige que no se obstaculice).
struct ProAccountView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var library = ScriptLibrary.shared
    @StateObject private var history = HistoryStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var showManage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    statusCard
                    usageCard
                    if subscriptionManager.isOnMonthlyPlan, subscriptionManager.yearly != nil {
                        YearlyUpgradeCard()
                    }
                    benefitsCard
                    footer
                }
                .padding()
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("Tu plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .task { await subscriptionManager.refreshProducts() }
    }

    // MARK: - Secciones

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("Eres Pro")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.primary(scheme))
            if let product = subscriptionManager.activeProduct {
                Text("\(product.isYearly ? "Plan anual" : "Plan mensual") · \(product.displayPrice) \(product.periodText)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary(scheme))
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var statusCard: some View {
        if let date = subscriptionManager.renewalDate {
            let dateText = date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_ES")))
            HStack(spacing: 12) {
                Image(systemName: subscriptionManager.willAutoRenew ? "arrow.triangle.2.circlepath" : "exclamationmark.circle.fill")
                    .foregroundStyle(subscriptionManager.willAutoRenew ? Theme.accentStart : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscriptionManager.willAutoRenew ? "Se renueva el \(dateText)" : "Cancelada: Pro hasta el \(dateText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary(scheme))
                    if !subscriptionManager.willAutoRenew {
                        Text("Después volverás al plan gratis.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondary(scheme))
                    }
                }
                Spacer()
                if !subscriptionManager.willAutoRenew {
                    Button("Reactivar") { showManage = true }
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.accentStart)
                }
            }
            .padding(16)
            .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var usageCard: some View {
        HStack(spacing: 12) {
            UsageStat(value: history.reports.count,
                      label: history.reports.count == 1 ? "vídeo analizado" : "vídeos analizados", icon: "film.stack")
            UsageStat(value: library.scripts.count,
                      label: library.scripts.count == 1 ? "guion creado" : "guiones creados", icon: "doc.text.fill")
        }
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Incluido en tu plan")
                .font(.headline)
                .foregroundStyle(Theme.primary(scheme))
            ForEach(ProBenefit.all, id: \.title) { benefit in
                Label {
                    Text(benefit.title).foregroundStyle(Theme.primary(scheme))
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentStart)
                }
                .font(.subheadline)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if subscriptionManager.willAutoRenew {
                NavigationLink {
                    CancelRetentionView(analysesCount: history.reports.count,
                                        scriptsCount: library.scripts.count,
                                        onKeep: { dismiss() },
                                        onContinueCancel: { showManage = true })
                } label: {
                    Text("Cancelar suscripción")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.secondary(scheme))
                }
            }
            HStack(spacing: 16) {
                Button("Restaurar compras") { Task { await subscriptionManager.restorePurchases() } }
                Link("Términos", destination: LegalLinks.terms)
                Link("Privacidad", destination: LegalLinks.privacy)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.accentStart)
        }
        .padding(.top, 8)
    }
}

// MARK: - Retención

/// Paso previo a la cancelación: recuerda lo que se pierde, pregunta el motivo y
/// ofrece una alternativa según la respuesta. "Continuar con la cancelación" abre la gestión de Apple.
struct CancelRetentionView: View {
    let analysesCount: Int
    let scriptsCount: Int
    let onKeep: () -> Void
    let onContinueCancel: () -> Void

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var scheme
    @State private var reason: CancelReason?

    enum CancelReason: String, CaseIterable {
        case price = "Es demasiado caro"
        case usage = "No lo uso lo suficiente"
        case results = "Los resultados no me convencen"
        case other = "Otro motivo"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Antes de irte…")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.primary(scheme))
                    Text(lossIntro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary(scheme))
                }

                VStack(alignment: .leading, spacing: 12) {
                    LossRow(title: "Análisis de vídeo", from: "Ilimitados", to: "\(AnalysisCreditsManager.freeMonthlyLimit) al mes")
                    LossRow(title: "Guiones con IA", from: "Ilimitados", to: "\(ScriptQuota.freeMonthlyGenerations) generaciones al mes")
                    if analysesCount + scriptsCount > 0 {
                        Label("Tus \(analysesCount) análisis y \(scriptsCount) guiones se quedan guardados en tu iPhone.",
                              systemImage: "checkmark.shield.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondary(scheme))
                    }
                }
                .padding(18)
                .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("¿Por qué quieres cancelar?")
                        .font(.headline)
                        .foregroundStyle(Theme.primary(scheme))
                    ForEach(CancelReason.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.snappy(duration: 0.25)) { reason = option }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.primary(scheme))
                                Spacer()
                                Image(systemName: reason == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(reason == option ? Theme.accentStart : Theme.subtleStroke(scheme))
                            }
                            .padding(14)
                            .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let reason {
                    reasonResponse(reason)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VStack(spacing: 12) {
                    Button(action: onKeep) {
                        Text("Quedarme en Pro")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    Button("Continuar con la cancelación", action: onContinueCancel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.secondary(scheme))
                }
            }
            .padding()
        }
        .background(Theme.background(scheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lossIntro: String {
        if let date = subscriptionManager.renewalDate {
            let dateText = date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "es_ES")))
            return "Si cancelas, mantienes Pro hasta el \(dateText). Después vuelves al plan gratis:"
        }
        return "Si cancelas, al terminar tu periodo vuelves al plan gratis:"
    }

    @ViewBuilder
    private func reasonResponse(_ reason: CancelReason) -> some View {
        switch reason {
        case .price:
            if subscriptionManager.isOnMonthlyPlan, subscriptionManager.yearly != nil {
                YearlyUpgradeCard()
            } else {
                ResponseCard(icon: "eurosign.circle.fill",
                             text: "Ya tienes el plan anual, el precio más bajo por mes. Si lo mantienes, sigues sin límites hasta tu próxima renovación.")
            }
        case .usage:
            ResponseCard(icon: "lightbulb.fill",
                         text: "Una idea: dedica 10 minutos a crear los guiones de la semana en Script Maker y grábalos con el teleprompter. Con Pro no tienes límite de generaciones.")
        case .results:
            ResponseCard(icon: "wand.and.stars",
                         text: "Prueba a analizar el mismo vídeo tras aplicar las 3 mejoras del resultado: verás qué cambia en hook, claridad y ritmo. Los guiones mejoran cuanto más concretos son los beneficios que escribes.")
        case .other:
            ResponseCard(icon: "heart.fill",
                         text: "Gracias por haber probado Go Viral Pro. Si cambias de idea, puedes volver cuando quieras.")
        }
    }
}

// MARK: - Componentes

private enum ProBenefit {
    static let all: [(title: String, icon: String)] = [
        ("Análisis de vídeo ilimitados", "film.stack"),
        ("Guiones con IA ilimitados", "doc.text.fill"),
        ("Sin permanencia", "xmark.circle")
    ]
}

/// Ofrece pasar del mensual al anual (Apple lo gestiona como cambio de plan dentro del mismo grupo).
private struct YearlyUpgradeCard: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let yearly = subscriptionManager.yearly {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Pásate al anual")
                        .font(.headline)
                        .foregroundStyle(Theme.primary(scheme))
                    if let savings = subscriptionManager.yearlySavingsPercent {
                        Text("Ahorra \(savings)%")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                Text("\(yearly.displayPrice) al año: equivale a \(yearly.monthlyEquivalent) al mes. El cambio se aplica en tu próxima renovación.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary(scheme))
                Button {
                    Task { await subscriptionManager.purchase(yearly) }
                } label: {
                    Text(subscriptionManager.isProcessing ? "Procesando…" : "Cambiar a anual")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.accent, lineWidth: 1.5))
                        .foregroundStyle(Theme.accentStart)
                }
                .disabled(subscriptionManager.isProcessing)
            }
            .padding(16)
            .background(Theme.accentStart.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct UsageStat: View {
    let value: Int
    let label: String
    let icon: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accentStart)
            Text("\(value)")
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(Theme.primary(scheme))
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondary(scheme))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LossRow: View {
    let title: String
    let from: String
    let to: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary(scheme))
            Spacer()
            Text(from)
                .font(.caption)
                .strikethrough()
                .foregroundStyle(Theme.secondary(scheme))
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(Theme.secondary(scheme))
            Text(to)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }
}

private struct ResponseCard: View {
    let icon: String
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accentStart)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.primary(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentStart.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension Product {
    var isYearly: Bool { subscription?.subscriptionPeriod.unit == .year }
}
