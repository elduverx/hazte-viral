# Guía para testers – Go Viral

Breve checklist para compartir con testers de la app Go Viral.

## Objetivo
- Validar el flujo completo: subir video, lanzar análisis de IA, revisar resultados, consejos y estadísticas, además del historial y la pasarela de suscripción.

## Requisitos previos
- Dispositivo con iOS 17 o superior y buena conexión.
- Conceder permiso de Fotos al abrir el selector de videos.
- Build actual con paywall desactivado (`subscriptionGateEnabled = false`): se puede analizar sin pagar, pero abre la pasarela desde el banner para validar que carga.
- Si compilas con Xcode, añade las variables de entorno en el esquema Run para que el análisis real funcione:
  - `ANTHROPIC_API_KEY=tu_clave`
  - `ANTHROPIC_MODEL` (opcional, ejemplo: `claude-3-haiku-20240307`)
  - `ANTHROPIC_MAX_TOKENS` (opcional, ejemplo: `900`)

## Casos de prueba sugeridos
- **Onboarding**: confirmar que los 3 pasos se muestran y se pueden omitir.
- **Subida y preview**: elegir un video vertical desde Fotos, ver el preview enmarcado 9:16 y reproducirlo; probar cambiar el video con “Cambiar”.
- **Botón principal**: 
  - Sin video → “Subir video”.
  - Con video → “Iniciar análisis”.
  - Durante análisis → estado de carga y textos rotativos del overlay.
  - Tras análisis → “Ver resultado” abre el reporte.
- **Análisis**: al completar, se muestran hallazgos en la tarjeta inline y el botón abre la hoja de resultado.
- **Reporte (hoja “Resultado IA”)**:
  - Pestaña **Resultados**: métricas 0-100, highlights y “Acciones inmediatas”.
  - Pestaña **Consejos**: estrategias por tipo de contenido y optimización técnica.
  - Pestaña **Estadísticas**: tabla comparativa vs promedio y barra animada.
- **Historial**: abrir desde el icono de reloj y verificar que guarda y reabre análisis previos; repetir el mismo video debe reutilizar el resultado (cache por hash).
- **Suscripción**: abrir el banner “Suscripción Go Viral Pro” y comprobar que la pantalla de compra carga (usar Apple ID de sandbox si se va a probar la compra real).
- **Errores**: sin clave de Anthropic o sin red debe mostrarse un alerta con mensaje localizado.

## Qué enviar en feedback
- Video o captura de pantalla del problema.
- Pasos exactos realizados (incluye si el análisis se reutilizó desde historial).
- Tipo de dispositivo, versión de iOS y estado de red (Wi‑Fi/datos).
- Si hubo compra, confirma Apple ID de sandbox y resultado (éxito, cancelado, error).

## Limitaciones conocidas
- El análisis requiere `ANTHROPIC_API_KEY`; sin ella verás error de autorización.
- Solo se analiza contenido visual (no hay transcripción de audio todavía).
- Historial y caché viven en el dispositivo (no hay sync en cloud).
- El modelo actual usa 8 frames del video; clips muy cortos o con menos frames pueden fallar.
