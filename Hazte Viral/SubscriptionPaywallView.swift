import StoreKit
import SwiftUI

/// Enlaces legales que exige Apple en una suscripción.
enum LegalLinks {
    /// EULA estándar de Apple (es el que aplica si no subes uno propio en App Store Connect).
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://viral.elduverx.com/privacy")!
}

struct SubscriptionPaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var selectedID: String?

    private var selected: Product? {
        subscriptionManager.products.first { $0.id == selectedID } ?? subscriptionManager.products.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    benefits
                    plans
                    purchaseButton
                    disclosure
                    footerLinks
                }
                .padding()
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .task {
            if subscriptionManager.products.isEmpty { await subscriptionManager.refreshProducts() }
        }
        .onChange(of: subscriptionManager.isSubscribed) { _, isActive in
            if isActive { dismiss() }
        }
    }

    // MARK: - Secciones

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("Go Viral Pro")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.primary(scheme))
            Text("Analiza tus vídeos y crea guiones sin límite mensual.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary(scheme))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenefitRow(icon: "film.stack", title: "Análisis de vídeo ilimitados",
                       detail: "Gratis: \(AnalysisCreditsManager.freeMonthlyLimit) al mes")
            BenefitRow(icon: "doc.text.fill", title: "Guiones con IA ilimitados",
                       detail: "Gratis: \(ScriptQuota.freeMonthlyGenerations) generaciones al mes")
            BenefitRow(icon: "xmark.circle", title: "Cancela cuando quieras",
                       detail: "Desde Ajustes de tu iPhone, sin permanencia")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        if subscriptionManager.products.isEmpty {
            VStack(spacing: 12) {
                if subscriptionManager.isLoadingProducts {
                    ProgressView()
                } else {
                    Text(subscriptionManager.errorMessage ?? "Planes no disponibles.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary(scheme))
                        .multilineTextAlignment(.center)
                    Button("Reintentar") { Task { await subscriptionManager.refreshProducts() } }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140)
        } else {
            VStack(spacing: 12) {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    PlanCard(product: product,
                             isSelected: product.id == selected?.id,
                             savingsPercent: product.id == subscriptionManager.yearly?.id ? subscriptionManager.yearlySavingsPercent : nil) {
                        selectedID = product.id
                    }
                }
            }
        }
    }

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button {
                guard let selected else { return }
                Task { await subscriptionManager.purchase(selected) }
            } label: {
                Group {
                    if subscriptionManager.isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continuar")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(selected == nil || subscriptionManager.isProcessing)
            .opacity(selected == nil ? 0.5 : 1)

            if let error = subscriptionManager.errorMessage, !subscriptionManager.products.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Texto de renovación automática que exige la App Store (guía 3.1.2).
    @ViewBuilder
    private var disclosure: some View {
        if let selected {
            Text("\(selected.displayPrice) \(selected.periodText). La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes de que termine el periodo. El cobro se hace en tu cuenta de Apple al confirmar la compra. Puedes gestionarla o cancelarla en Ajustes > tu nombre > Suscripciones.")
                .font(.caption2)
                .foregroundStyle(Theme.secondary(scheme))
                .multilineTextAlignment(.center)
        }
    }

    private var footerLinks: some View {
        HStack(spacing: 16) {
            Button("Restaurar compras") { Task { await subscriptionManager.restorePurchases() } }
                .disabled(subscriptionManager.isProcessing)
            Link("Términos", destination: LegalLinks.terms)
            Link("Privacidad", destination: LegalLinks.privacy)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Theme.accentStart)
        .padding(.bottom, 8)
    }
}

// MARK: - Componentes

private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accentStart)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary(scheme))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }
        }
    }
}

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let savingsPercent: Int?
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var isYearly: Bool { product.subscription?.subscriptionPeriod.unit == .year }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accentStart : Theme.secondary(scheme))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Anual" : "Mensual")
                            .font(.headline)
                            .foregroundStyle(Theme.primary(scheme))
                        if let savingsPercent {
                            Text("Ahorra \(savingsPercent)%")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.accent, in: Capsule())
                        }
                    }
                    if isYearly {
                        Text("Equivale a \(product.monthlyEquivalent) al mes")
                            .font(.caption)
                            .foregroundStyle(Theme.secondary(scheme))
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(Theme.primary(scheme))
            }
            .padding(16)
            .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.subtleStroke(scheme)),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension Product {
    /// "al año" / "al mes" para el texto de renovación.
    var periodText: String {
        switch subscription?.subscriptionPeriod.unit {
        case .year: return "al año"
        case .month: return "al mes"
        case .week: return "a la semana"
        case .day: return "al día"
        default: return ""
        }
    }

    /// Precio anual dividido entre 12, con el formato de moneda de la tienda.
    var monthlyEquivalent: String {
        (price / 12).formatted(priceFormatStyle)
    }
}

/// Arriba a la derecha: "PRO" si hay suscripción activa; si no, "Probar Pro" para abrir el paywall.
struct ProStatusButton: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let onUpgrade: () -> Void
    @State private var showManage = false

    var body: some View {
        Group {
            if subscriptionManager.isSubscribed {
                Button { showManage = true } label: {
                    Label("PRO", systemImage: "crown.fill")
                        .font(.caption.weight(.heavy))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Suscripción Pro activa. Ver tu plan")
                .sheet(isPresented: $showManage) { ProAccountView() }
            } else {
                Button(action: onUpgrade) {
                    Text("Probar Pro")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(Capsule().stroke(Theme.accent, lineWidth: 1.5))
                        .foregroundStyle(Theme.accentStart)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
