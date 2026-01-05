import PassKit
import StoreKit
import SwiftUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var textPrimary: Color {
        Theme.primary(scheme)
    }
    
    private var textSecondary: Color {
        Theme.secondary(scheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    benefitsCard
                    purchaseCard
                    errorMessageView
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

    private var benefitsCard: some View {
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
    }

    private var purchaseCard: some View {
        GlassCard { purchaseCardContent }
    }

    private var purchaseCardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            purchaseHeaderSection
            purchaseButtonSection
            purchaseFootnote
            restoreButtons
        }
    }

    private var purchaseHeaderSection: some View {
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
    }

    @ViewBuilder
    private var purchaseButtonSection: some View {
        VStack(spacing: 10) {
            Button(action: purchase) {
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
    }

    private var purchaseFootnote: some View {
        Text("Suscripción de 5€ al mes sin prueba gratuita. Cobro inmediato por Apple Pay/App Store, cancela cuando quieras desde Ajustes.")
            .font(.footnote)
            .foregroundStyle(textSecondary)
    }

    private var restoreButtons: some View {
        HStack(spacing: 12) {
            Button("Restaurar Compras", action: restorePurchases)
                .font(.subheadline.bold())
                .disabled(subscriptionManager.isProcessing)

            Button("Ya estoy suscrito") {
                #if DEBUG
                subscriptionManager.forceUnlockForDebug()
                #else
                restorePurchases()
                #endif
            }
            .font(.subheadline)
            .disabled(subscriptionManager.isProcessing)
        }
        .foregroundStyle(subscriptionManager.isProcessing ? Theme.accentStart.opacity(0.6) : Theme.accentStart)
    }

    @ViewBuilder
    private var errorMessageView: some View {
        if let error = subscriptionManager.errorMessage {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func purchase() {
        Task { await subscriptionManager.purchase() }
    }

    private func restorePurchases() {
        Task { await subscriptionManager.restorePurchases() }
    }
}
