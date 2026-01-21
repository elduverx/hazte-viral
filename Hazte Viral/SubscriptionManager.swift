import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var product: Product?
    @Published private(set) var isSubscribed = false
    @Published private(set) var isProcessing = false
    @Published private(set) var priceDisplay = "Cargando..."
    @Published var errorMessage: String?

    private let productIdentifiers = ["com.goviiral.subscription.monthly"]

    init() {
        Task { await refreshProducts() }
        Task { await listenForTransactions() }
    }

    func refreshProducts() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let products = try await Product.products(for: productIdentifiers)
            product = products.first
            if let product = product {
                priceDisplay = "\(product.displayPrice)/mes"
            } else {
                priceDisplay = "No disponible"
                errorMessage = "Producto no encontrado en App Store"
            }
            await updateSubscriptionStatus()
        } catch {
            priceDisplay = "Error al cargar"
            errorMessage = "No se pudo cargar la suscripción: \(error.localizedDescription)"
        }
    }

    func purchase() async {
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
        await updateSubscriptionStatus()
    }
    
    func updateSubscriptionStatus() async {
        var active = false
        
        do {
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
        } catch {
            errorMessage = "Error al verificar suscripción: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    func forceUnlockForDebug() {
        isSubscribed = true
    }
    #endif

    private func listenForTransactions() async {
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