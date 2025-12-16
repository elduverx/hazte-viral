import PassKit
import StoreKit
import SwiftUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Beneficios de la suscripción", systemImage: "seal.fill")
                                .font(.headline)
                                .foregroundStyle(textPrimary)

                            ForEach(benefits, id: \.self) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.accent)
                                    Text(item)
                                        .foregroundStyle(textSecondary)
                                }
                                .font(.subheadline)
                            }
                            Label("Acceso inmediato al plan Pro", systemImage: "bolt.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Go Viral Pro")
                                        .font(.headline)
                                        .foregroundStyle(textPrimary)
                                    Text("Suscripción mensual")
                                        .font(.caption)
                                        .foregroundStyle(textSecondary)
                                }
                                Spacer()
                                Text(subscriptionManager.priceDisplay)
                                    .font(.title3.bold())
                                    .foregroundStyle(Theme.accent)
                            }

                            VStack(spacing: 10) {
                                Button {
                                    Task { await subscriptionManager.purchase() }
                                } label: {
                                    HStack {
                                        Image(systemName: "applelogo")
                                        Text(subscriptionManager.isProcessing ? "Procesando..." : "Suscribirse ahora")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Theme.accent)
                                    .foregroundStyle(.white)
                                    .cornerRadius(14)
                                }
                                .opacity(subscriptionManager.isProcessing ? 0.7 : 1)
                                .disabled(subscriptionManager.isProcessing)

                                if subscriptionManager.isProcessing {
                                    ProgressView("Procesando con Apple Pay...")
                                        .font(.footnote)
                                }
                            }

                            Text("Suscripción de 5€ al mes sin prueba gratuita. Cobro inmediato por Apple Pay/App Store, cancela cuando quieras desde Ajustes.")
                                .font(.footnote)
                                .foregroundStyle(textSecondary)

                            HStack(spacing: 12) {
                                Button("Restaurar") {
                                    Task { await subscriptionManager.updateSubscriptionStatus() }
                                }
                                .font(.subheadline.bold())

                                Button("Ya estoy suscrito") {
                                    #if DEBUG
                                    subscriptionManager.forceUnlockForDebug()
                                    #else
                                    Task { await subscriptionManager.updateSubscriptionStatus() }
                                    #endif
                                }
                                .font(.subheadline)
                            }
                            .foregroundStyle(Theme.accent)
                        }
                    }

                    if let error = subscriptionManager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Suscripción")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(textPrimary)
                }
            }
        }
        .onChange(of: subscriptionManager.isSubscribed) { isActive in
            if isActive { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suscríbete por 5€ al mes")
                .font(.title2.bold())
                .foregroundStyle(textPrimary)
            Text("Desbloquea análisis ilimitados, IA prioritaria y métricas avanzadas.")
                .foregroundStyle(textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var benefits: [String] {
        [
            "Análisis ilimitados con IA",
            "Prioridad en procesamiento",
            "Predicciones detalladas y consejos pro",
            "Historial completo y sincronizado"
        ]
    }
}
