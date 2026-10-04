# Configuración de la IA

La app ya no lleva la API key de Anthropic. Usa el mismo esquema que Tipson Contractor:
un backend propio en el VPS (`hazteviral-backend/`) guarda la key y la app lo llama con `X-App-Token`.

Instrucciones de despliegue y configuración: [hazteviral-backend/README.md](hazteviral-backend/README.md).
