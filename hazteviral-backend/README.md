# Backend de Hazte Viral (Node.js)

Igual que `tipsoncontractor-backend`: la app no habla con Anthropic directamente, llama a este
servidor, que guarda la API key, los prompts y el modelo (`claude-haiku-4-5-20251001`), pide el
token de la app y limita las peticiones por IP. Puede usar la misma `ANTHROPIC_API_KEY` que Tipson Contractor.

| Endpoint | Body | Respuesta |
|---|---|---|
| `POST /api/analyze` | `{ title, frames: [jpeg base64] }` (6–10 frames) | `{ text }` (el JSON del análisis) |
| `POST /api/scripts` | `{ businessType, productService, targetAudience, niche, duration, hookType, hookTypeDescription, tone, keyBenefits, count }` | `{ text }` (array JSON de guiones) |

Todas las peticiones llevan el header `X-App-Token`. Los errores responden `{ error }`.

## Probar en tu Mac

```bash
cd hazteviral-backend
npm install
cp .env.example .env      # y rellena los valores
npm run dev
```

## Primer despliegue en el VPS

```bash
git clone <repo hazte-viral> /var/www/hazteviral
cd /var/www/hazteviral/hazteviral-backend
npm install --omit=dev
cp .env.example .env
nano .env                 # ANTHROPIC_API_KEY (la misma de tipsoncontractor) + APP_TOKEN (openssl rand -hex 32) + PORT libre + HOST=172.17.0.1
chmod 600 .env

pm2 start index.js --name hazteviral
pm2 save
```

Usa un `PORT` libre (`sudo ss -ltnp`); tipsoncontractor usa 3100, el ejemplo aquí usa 3200.

### HTTPS (Caddy)

Añade al final de `/opt/tipson/Caddyfile`:

```caddy
viral.elduverx.com {
    reverse_proxy 172.17.0.1:3200
}
```

```bash
docker exec tipson-caddy-1 caddy reload --config /etc/caddy/Caddyfile
```

El registro DNS `A` de `viral.elduverx.com` debe apuntar a la IP del VPS.

### App

- `Hazte Viral/AIService.swift`: `backendURL = "https://viral.elduverx.com/api"`.
- Xcode → target Hazte Viral → Build Settings → `APP_TOKEN`: el mismo valor que `APP_TOKEN` en `.env`
  (llega a la app vía `Info.plist` → `AppToken`).

## Actualizar

```bash
cd /var/www/hazteviral && git pull
cd hazteviral-backend && npm install --omit=dev
pm2 restart hazteviral
```

## Límites

`RATE_LIMIT_PER_HOUR` en `.env` (por IP). Como la API key es compartida con Tipson Contractor,
el límite de gasto en console.anthropic.com cubre ambas apps.

El `APP_TOKEN` va dentro de la app, así que alguien decidido puede extraerlo; el servidor fija
prompts, modelo y `max_tokens`, y limita por IP.
