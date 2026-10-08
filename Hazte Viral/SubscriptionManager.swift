import Foundation
import StoreKit
import SwiftUI
import Combine

enum AppMonetization {
    static let paymentsEnabled = true
}

/// IDs de los productos de App Store Connect (grupo de suscripción "Go Viral Pro").
enum ProProduct {
    static let monthly = "goviral1"
    static let yearly = "goviralpro_anual"
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// Planes disponibles, el anual primero.
    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed = false
    @Published private(set) var isProcessing = false
    @Published private(set) var isLoadingProducts = false
    @Published var errorMessage: String?

    // Plan activo (para la página "Tu plan Pro")
    @Published private(set) var activeProductID: String?
    @Published private(set) var renewalDate: Date?
    @Published private(set) var willAutoRenew = true

    private let productIdentifiers: [String]
    private var updatesTask: Task<Void, Never>?

    init(productIdentifiers: [String]? = nil) {
        self.productIdentifiers = productIdentifiers ?? SubscriptionManager.loadProductIdentifiers()
        guard AppMonetization.paymentsEnabled else {
            isSubscribed = true
            return
        }
        updatesTask = Task { await listenForTransactions() }
        Task { await refreshProducts() }
    }

    private static func loadProductIdentifiers() -> [String] {
        if let ids = Bundle.main.object(forInfoDictionaryKey: "SubscriptionProductIdentifiers") as? [String],
           !ids.isEmpty {
            return ids
        }
        return [ProProduct.monthly, ProProduct.yearly]
    }

    // MARK: - Productos

    var activeProduct: Product? { products.first { $0.id == activeProductID } }
    var isOnMonthlyPlan: Bool { activeProduct?.subscription?.subscriptionPeriod.unit == .month }

    var monthly: Product? { products.first { $0.subscription?.subscriptionPeriod.unit == .month } }
    var yearly: Product? { products.first { $0.subscription?.subscriptionPeriod.unit == .year } }

    /// Ahorro del anual frente a 12 meses del mensual, en porcentaje entero (p. ej. 37).
    var yearlySavingsPercent: Int? {
        guard let monthly, let yearly, monthly.price > 0 else { return nil }
        let twelveMonths = monthly.price * 12
        let savings = (twelveMonths - yearly.price) / twelveMonths * 100
        let value = NSDecimalNumber(decimal: savings).intValue
        return value > 0 ? value : nil
    }

    func refreshProducts() async {
        guard AppMonetization.paymentsEnabled else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: productIdentifiers)
            // Anual primero: es el plan que se preselecciona.
            products = loaded.sorted { lhs, rhs in
                (lhs.subscription?.subscriptionPeriod.unit == .year ? 0 : 1) <
                (rhs.subscription?.subscriptionPeriod.unit == .year ? 0 : 1)
            }
            if products.isEmpty {
                print("[StoreKit] Ningún producto coincide con \(productIdentifiers)")
                errorMessage = "Los planes no están disponibles ahora mismo. Inténtalo más tarde."
            } else {
                errorMessage = nil
            }
            await updateSubscriptionStatus()
        } catch {
            print("[StoreKit] Error cargando productos: \(error)")
            errorMessage = "No se pudieron cargar los planes. Revisa tu conexión."
        }
    }

    // MARK: - Compra

    func purchase(_ product: Product) async {
        guard AppMonetization.paymentsEnabled else { return }

        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
            case .pending:
                // Ej. "Pedir la compra" o aprobación del banco: llegará por Transaction.updates.
                errorMessage = "Compra pendiente de aprobación. Se activará automáticamente."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "No se pudo completar la compra: \(error.localizedDescription)"
        }
    }

    /// Restaurar: sincroniza con la App Store (puede pedir iniciar sesión) y vuelve a comprobar.
    func restorePurchases() async {
        guard AppMonetization.paymentsEnabled else { return }

        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "No se pudieron restaurar las compras: \(error.localizedDescription)"
        }
        await updateSubscriptionStatus()
        if !isSubscribed && errorMessage == nil {
            errorMessage = "No hay ninguna suscripción activa en esta cuenta de Apple."
        }
    }

    func updateSubscriptionStatus() async {
        guard AppMonetization.paymentsEnabled else {
            isSubscribed = true
            return
        }

        var activeTransaction: StoreKit.Transaction?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if productIdentifiers.contains(transaction.productID), transaction.revocationDate == nil {
                activeTransaction = transaction
                break
            }
        }
        isSubscribed = activeTransaction != nil
        activeProductID = activeTransaction?.productID
        renewalDate = activeTransaction?.expirationDate
        willAutoRenew = await autoRenewStatus(for: activeTransaction?.productID)
    }

    /// Si la renovación automática sigue activa (false = el usuario ya canceló y caduca en `renewalDate`).
    private func autoRenewStatus(for productID: String?) async -> Bool {
        guard let productID,
              let product = products.first(where: { $0.id == productID }),
              let statuses = try? await product.subscription?.status else { return true }
        for status in statuses {
            if case .verified(let renewal) = status.renewalInfo, renewal.currentProductID == productID {
                return renewal.willAutoRenew
            }
        }
        return true
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            await transaction.finish()
            await updateSubscriptionStatus()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

enum SubscriptionError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "No se pudo verificar la compra."
        }
    }
}
