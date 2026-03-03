import Foundation
import StoreKit
import SwiftUI
import Combine

enum AppMonetization {
    static let paymentsEnabled = false
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var product: Product?
    @Published private(set) var isSubscribed = false
    @Published private(set) var isProcessing = false
    @Published private(set) var priceDisplay = "Cargando..."
    @Published var errorMessage: String?

    private let productIdentifiers: [String]

    init(productIdentifiers: [String]? = nil) {
        self.productIdentifiers = productIdentifiers ?? SubscriptionManager.loadProductIdentifiers()
        guard AppMonetization.paymentsEnabled else {
            isSubscribed = true
            priceDisplay = "Gratis"
            return
        }
        Task { await refreshProducts() }
        Task { await listenForTransactions() }
    }

    private static func loadProductIdentifiers() -> [String] {
        if let ids = Bundle.main.object(forInfoDictionaryKey: "SubscriptionProductIdentifiers") as? [String],
           !ids.isEmpty {
            return ids
        }
        return ["goviralpro1"]
    }

    func refreshProducts() async {
        guard AppMonetization.paymentsEnabled else {
            isSubscribed = true
            priceDisplay = "Gratis"
            errorMessage = nil
            return
        }

        isProcessing = true
        defer { isProcessing = false }
        
        do {
            print("[StoreKit] Buscando productos para IDs: \(productIdentifiers)")
            let products = try await Product.products(for: productIdentifiers)
            print("[StoreKit] Productos encontrados: \(products.count)")
            product = products.first
            if let product = product {
                print("[StoreKit] Producto cargado: \(product.displayName) - \(product.displayPrice)")
                priceDisplay = "\(product.displayPrice)/mes"
            } else {
                print("[StoreKit] ERROR: Ningún producto coincide con los IDs proporcionados.")
                priceDisplay = "No disponible"
                errorMessage = "Producto no encontrado en App Store (IDs: \(productIdentifiers.joined(separator: ", ")))"
            }
            await updateSubscriptionStatus()
        } catch {
            priceDisplay = "Error al cargar"
            errorMessage = "No se pudo cargar la suscripción: \(error.localizedDescription)"
        }
    }

    func purchase() async {
        guard AppMonetization.paymentsEnabled else {
            isSubscribed = true
            errorMessage = nil
            return
        }

        guard let product else {
            errorMessage = "Producto no disponible. Intenta refrescar."
            await refreshProducts()
            return
        }
        
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    if productIdentifiers.contains(transaction.productID) {
                        isSubscribed = transaction.revocationDate == nil
                        if isSubscribed {
                            await transaction.finish()
                        }
                    }
                } catch {
                    errorMessage = "Error al verificar la compra: \(error.localizedDescription)"
                }
            case .pending:
                errorMessage = "Compra pendiente. Revisa tu configuración de pagos."
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "Resultado de compra desconocido"
                break
            }
        } catch {
            errorMessage = "No se pudo completar la compra: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        guard AppMonetization.paymentsEnabled else {
            isSubscribed = true
            errorMessage = nil
            return
        }

        await updateSubscriptionStatus()
    }
    
    func updateSubscriptionStatus() async {
        guard AppMonetization.paymentsEnabled else {
            isSubscribed = true
            errorMessage = nil
            return
        }

        var active = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if productIdentifiers.contains(transaction.productID), transaction.revocationDate == nil {
                    active = true
                    break
                }
            } catch {
                continue
            }
        }
        isSubscribed = active
    }

    #if DEBUG
    func forceUnlockForDebug() {
        isSubscribed = true
    }
    #endif

    private func listenForTransactions() async {
        guard AppMonetization.paymentsEnabled else { return }

        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            if productIdentifiers.contains(transaction.productID) {
                isSubscribed = transaction.revocationDate == nil
                await transaction.finish()
            }
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
