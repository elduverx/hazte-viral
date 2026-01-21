# Respuesta a Apple App Review - Hazte Viral

## Estado del Rechazo
- **Submission ID**: cc2958b7-28ee-4bca-9b9d-dee10a80a807
- **Fecha de revisión**: 21 de enero, 2026
- **Versión revisada**: 1.0
- **Build**: 1.0.5 (4)

## Problemas Identificados y Solucionados

### 1. Guideline 2.1 - PassKit Framework (Apple Pay)

**Problema**: Apple detectó el framework PassKit en el binario pero no encontró integración funcional.

**Causa**:
- Import innecesario de PassKit en `SubscriptionPaywallView.swift`
- Capability `com.apple.developer.in-app-payments` configurada erróneamente en entitlements

**Solución Implementada**:
- ✅ Removido `import PassKit` de `SubscriptionPaywallView.swift`
- ✅ Removida capability de Apple Pay de `goviiral.entitlements`
- ✅ Eliminadas referencias confusas a "Apple Pay" en la UI

**Respuesta para Apple**:
```
La app NO utiliza Apple Pay. El framework PassKit fue removido del código y la
capability de in-app-payments fue eliminada de los entitlements. La app utiliza
exclusivamente In-App Purchase (StoreKit) para suscripciones digitales.
```

---

### 2. Guideline 3.1.1 - In-App Purchase

**Problema**: Apple indica que la app accede a contenido digital pagado sin usar IAP correctamente.

**Estado Actual**:
- ✅ La app YA implementa StoreKit 2 correctamente
- ✅ Product ID configurado: `com.elduverx.hazteviral`
- ✅ Verificación de transacciones implementada
- ✅ Restauración de compras implementada

**Lo que FALTA hacer en App Store Connect**:

#### Paso 1: Configurar el producto IAP
1. Ve a App Store Connect → Tu app → Features → In-App Purchases
2. Crea un producto de tipo **Auto-Renewable Subscription**
3. Configura:
   - **Product ID**: `com.elduverx.hazteviral` (DEBE coincidir exactamente)
   - **Reference Name**: Go Viral Pro Monthly
   - **Subscription Duration**: 1 Month
   - **Price**: 5,00 € (Tier que corresponda)

#### Paso 2: Crear un Subscription Group
1. Ve a Subscriptions → Create Subscription Group
2. Nombre: "Go Viral Pro"
3. Añade el producto `com.elduverx.hazteviral` a este grupo

#### Paso 3: Configurar Metadata del Producto
Completa toda la información requerida:
- **Display Name**: Suscripción Pro
- **Description**:
  ```
  Desbloquea análisis ilimitados con IA, procesamiento prioritario,
  predicciones detalladas y historial completo sincronizado.
  ```

#### Paso 4: Marcar el Producto como "Ready to Submit"
- Completa toda la información requerida
- Asegúrate de que el estado sea "Ready to Submit" antes de enviar el build

#### Paso 5: Configurar Paid Apps Agreement
1. Ve a Agreements, Tax, and Banking
2. Completa el "Paid Applications Schedule"
3. Añade información bancaria y fiscal

#### Paso 6: Sandbox Testing
1. Ve a App Store Connect → Users and Access → Sandbox Testers
2. Crea usuarios de prueba para verificar las compras

**Respuesta para Apple**:
```
La app utiliza In-App Purchase (StoreKit 2) para todas las suscripciones digitales.
El producto ID "com.elduverx.hazteviral" está configurado como Auto-Renewable
Subscription en App Store Connect.

Características de la suscripción:
- Los usuarios gratuitos tienen límite de 3 análisis mensuales
- La suscripción Pro (5€/mes) desbloquea análisis ilimitados
- Todo el contenido digital se accede únicamente mediante IAP
- La verificación de suscripción se realiza mediante Transaction.currentEntitlements
- Implementa restauración de compras según las guías de Apple

Ubicación en la app donde se integra IAP:
1. Tap en "Analizar Video" cuando se alcanza el límite gratuito
2. Aparece SubscriptionPaywallView con el botón "Suscribirse ahora"
3. La compra se procesa mediante StoreKit 2 (Product.purchase())
4. Los usuarios pueden restaurar compras desde el paywall
```

---

## Cambios Realizados en el Código

### Archivos Modificados:

1. **SubscriptionPaywallView.swift**
   - Removido `import PassKit`
   - Cambiado "Procesando con Apple Pay..." → "Procesando compra..."
   - Cambiado texto de footenote para clarificar que es compra via App Store

2. **goviiral.entitlements**
   - Removida capability `com.apple.developer.in-app-payments`
   - Archivo limpio (dict vacío) - las IAP no requieren entitlements especiales

### Código IAP Existente (NO modificado, ya está correcto):

- **SubscriptionManager.swift**: Implementación completa de StoreKit 2
- **AnalysisCreditsManager.swift**: Sistema de límites que respeta suscripciones
- **Info.plist**: Product ID configurado

---

## Checklist para Resubmit

Antes de enviar la nueva versión:

- [ ] Incrementar build number (ej: 1.0.5 (5))
- [ ] Verificar que el producto IAP existe en App Store Connect
- [ ] Verificar que el producto está "Ready to Submit"
- [ ] Verificar Paid Apps Agreement completado
- [ ] Build en Xcode con los cambios aplicados
- [ ] Upload a App Store Connect
- [ ] En "App Review Information", añadir nota:

```
TESTING NOTES FOR REVIEW:

To test In-App Purchase:
1. Launch the app
2. Tap "Analizar Video" on the Analyzer tab
3. After 3 free analyses, the subscription paywall will appear
4. The subscription "com.elduverx.hazteviral" (5€/month) unlocks unlimited analyses
5. Use a Sandbox test account to complete the purchase

IMPORTANT: This app uses StoreKit for In-App Purchase, NOT Apple Pay.
The PassKit framework and Apple Pay capability have been completely removed from this build.
```

---

## Referencias

- [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [In-App Purchase Guidelines](https://developer.apple.com/app-store/review/guidelines/#payments)
- [Configuring In-App Purchases](https://help.apple.com/app-store-connect/#/devb57be10e7)

---

## Próximos Pasos

1. **Aplicar cambios en Xcode** (YA HECHO ✅)
2. **Configurar IAP en App Store Connect** (PENDIENTE - usuario debe hacer)
3. **Incrementar build number**
4. **Archive y subir nuevo build**
5. **Añadir testing notes en App Review Information**
6. **Resubmit para revisión**
