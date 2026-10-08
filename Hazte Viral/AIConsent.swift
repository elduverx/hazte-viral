//
//  AIConsent.swift
//  goviiral
//

import SwiftUI

/// Permiso del usuario para enviar datos a la IA (Anthropic). Apple lo exige antes del primer envío (guía 5.1.2).
enum AIConsent {
    private static let key = "aiDataConsentGiven"

    static var isGiven: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func grant() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

extension View {
    /// Si hay una acción pendiente y aún no hay permiso, muestra la hoja de consentimiento;
    /// al aceptar, guarda el permiso y ejecuta la acción.
    func aiConsentSheet(pendingAction: Binding<(() -> Void)?>) -> some View {
        sheet(isPresented: Binding(get: { pendingAction.wrappedValue != nil },
                                   set: { if !$0 { pendingAction.wrappedValue = nil } })) {
            AIConsentSheet(
                onAccept: {
                    AIConsent.grant()
                    let action = pendingAction.wrappedValue
                    pendingAction.wrappedValue = nil
                    // Esperar a que la hoja se cierre antes de presentar otra pantalla (p. ej. la carga del análisis)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { action?() }
                },
                onDecline: { pendingAction.wrappedValue = nil }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

/// Ejecuta `action` si ya hay permiso; si no, la deja pendiente para pedirlo primero.
@MainActor
func runWithAIConsent(_ pending: Binding<(() -> Void)?>, _ action: @escaping () -> Void) {
    if AIConsent.isGiven {
        action()
    } else {
        pending.wrappedValue = action
    }
}

private struct AIConsentSheet: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accentStart)

            Text("Antes de usar la IA")
                .font(.title2.bold())
                .foregroundStyle(Theme.primary(scheme))

            VStack(alignment: .leading, spacing: 10) {
                Text("Para analizar un vídeo, la app envía **8 fotogramas fijos** y su nombre a nuestro servidor, que los reenvía a **Anthropic** (proveedor de la IA Claude). El vídeo completo y el audio no salen de tu iPhone.")
                Text("Para crear guiones, se envía la información que escribes sobre tu negocio.")
                Text("No guardamos esos datos y Anthropic no los usa para entrenar sus modelos.")
            }
            .font(.subheadline)
            .foregroundStyle(Theme.secondary(scheme))

            Link("Leer la política de privacidad", destination: LegalLinks.privacy)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accentStart)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("Aceptar y continuar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
                Button("Ahora no", action: onDecline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondary(scheme))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
    }
}
