require('dotenv').config();
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const express = require('express');
const rateLimit = require('express-rate-limit');
const Anthropic = require('@anthropic-ai/sdk');

const PORT = process.env.PORT || 3200;
// Interfaz donde escucha. En el VPS: 172.17.0.1 (docker0), para que el proxy Caddy llegue sin exponerlo a internet.
const HOST = process.env.HOST || '127.0.0.1';
const APP_TOKEN = process.env.APP_TOKEN;

// Verifica que tengamos la configuración necesaria
if (!process.env.ANTHROPIC_API_KEY || !APP_TOKEN) {
    console.error("🚨 ERROR: Faltan ANTHROPIC_API_KEY o APP_TOKEN en el archivo .env");
    process.exit(1);
}

const CLAUDE_MODEL = "claude-haiku-4-5-20251001";
const MIN_FRAMES = 6;
const MAX_FRAMES = 10;
const MAX_FRAME_BASE64_CHARS = 2_000_000; // ~1.5 MB de JPEG por frame
const MAX_FIELD_CHARS = 500;
const MAX_SCRIPTS = 5;

// Lee ANTHROPIC_API_KEY del entorno
const anthropic = new Anthropic();

const app = express();
app.set('trust proxy', 1); // Detrás de Caddy: usar la IP real del cliente
app.use(express.json({ limit: '25mb' })); // Los frames del vídeo van en base64

// Política de privacidad pública (enlazada desde la app y App Store Connect)
const privacyHtml = fs.readFileSync(path.join(__dirname, 'privacy.html'), 'utf8')
    .replaceAll('{{CONTACT_EMAIL}}', (process.env.CONTACT_EMAIL || '').replace(/[<>"&]/g, ''));
app.get('/privacy', (req, res) => res.type('html').send(privacyHtml));

// Solo la app (con el token compartido) puede usar la API
app.use('/api', (req, res, next) => {
    const token = Buffer.from(req.get('X-App-Token') || '');
    const expected = Buffer.from(APP_TOKEN);
    if (token.length !== expected.length || !crypto.timingSafeEqual(token, expected)) {
        return res.status(401).json({ error: "No autorizado." });
    }
    next();
});

// Límite de peticiones por IP
app.use('/api', rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: Number(process.env.RATE_LIMIT_PER_HOUR) || 30,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: { error: "Demasiadas peticiones. Intenta más tarde." }
}));

// Devuelve el string recortado, o null si no es un string válido
function field(value, maxChars = MAX_FIELD_CHARS) {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    return trimmed ? trimmed.slice(0, maxChars) : null;
}

// Llama a Claude y devuelve el texto de la respuesta
async function askClaude({ system, messages, maxTokens, temperature }) {
    const message = await anthropic.messages.create({
        model: CLAUDE_MODEL,
        max_tokens: maxTokens,
        temperature,
        system,
        messages
    });
    const block = message.content.find(b => b.type === 'text');
    if (!block) throw new Error("Claude no devolvió texto");
    return block.text;
}

// Traduce errores de Anthropic a respuestas sin detalles internos
function handleError(res, route, error) {
    if (error instanceof Anthropic.RateLimitError) {
        return res.status(503).json({ error: "El servicio está ocupado. Intenta en un momento." });
    }
    if (error instanceof Anthropic.APIConnectionError) {
        console.error(`Error de conexión en ${route}:`, error.message);
        return res.status(502).json({ error: "No se pudo conectar con el servicio de IA." });
    }
    if (error instanceof Anthropic.APIError) {
        console.error(`Error de Anthropic en ${route} (${error.status}):`, error.message);
        return res.status(502).json({ error: "El servicio de IA devolvió un error." });
    }
    console.error(`Error en ${route}:`, error);
    res.status(500).json({ error: "Error interno del servidor." });
}

// 1. Endpoint para analizar un vídeo a partir de sus frames
const ANALYZE_SYSTEM_PROMPT = `No eres un chatbot conversacional. Eres un motor de análisis basado en evidencia.
Responde SIEMPRE en español (España) sin mezclar inglés.

REGLAS CRÍTICAS (OBLIGATORIAS):
1. VALIDACIÓN DE ENTRADA:
- Si frames.length < 6 → ERROR
- Si más del 40% de los frames son visualmente similares → advertencia
- Si todos los frames son iguales → ERROR
- Si duración < 3s → marcar como "insuficiente"

2. PROHIBICIONES ABSOLUTAS:
❌ No inventar información
❌ No asumir intención del creador
❌ No inferir CTA si no existe explícitamente
❌ No reutilizar análisis previos
- Toda conclusión debe basarse en frames o transcripción reales

3. MÉTODO DE ANÁLISIS (orden obligatorio):
- Hook (0–2s): Analiza SOLO los primeros frames. Puntúa 0–10
- Tema principal: Determina tema basándote únicamente en lo visible
- Emoción dominante: Detecta solo si hay evidencia clara
- Ritmo de edición: Determina según cortes y cambios de plano
- Texto en pantalla: Extrae texto visible e indica en qué frame
- Audio/Voz: Cita frases textuales clave si hay transcripción
- CTA: Detecta CTA solo si es explícito
- Diagnóstico: Evalúa potencial relativo con evidencias

4. REGLA FINAL (NO NEGOCIABLE):
Si no puedes justificar una conclusión con prueba visual o audible, NO LA INCLUYAS.`;

function analyzeUserPrompt(title, frameCount) {
    return `ENTRADAS RECIBIDAS:
- frames[]: ${frameCount} imágenes ordenadas cronológicamente (frame_1 = inicio)
- transcription: [vacío - no implementado aún]
- metadata: formato 9:16, título: "${title}"
- idioma de salida: SOLO español (España), sin inglés

VALIDACIÓN AUTOMÁTICA:
✓ frames.length >= 6: PASS
✓ duración suficiente: PASS (asumido)

INSTRUCCIONES DE ANÁLISIS:
Analiza estos ${frameCount} frames en orden cronológico siguiendo el método obligatorio:

1. Hook (0–2s): Evalúa SOLO frames 1-2
2. Tema principal: Basado únicamente en contenido visible
3. Emoción: Solo si hay evidencia clara en expresiones/contexto
4. Ritmo: Según cambios visuales entre frames
5. Texto: Extrae texto visible y especifica frame
6. CTA: Solo si es explícito y visible
7. Diagnóstico: Con evidencias específicas de los frames
8. Puntúa de 0 a 10, cada una con un motivo breve que cite frames concretos:
   - hook: fuerza de los frames 1-2 para detener el scroll
   - visual_quality: luz, encuadre, nitidez y composición
   - clarity: ¿se entiende de qué va el vídeo sin sonido en los primeros segundos?
   - pacing: cambios de plano y dinamismo entre frames

Devuelve EXACTAMENTE este JSON (sin texto adicional):

{
  "video_quality_score": número_0_10,
  "hook_score": número_0_10,
  "clarity_score": número_0_10,
  "pacing_score": número_0_10,
  "score_reasons": {
    "hook": "motivo_breve_citando_frames",
    "visual_quality": "motivo_breve_citando_frames",
    "clarity": "motivo_breve_citando_frames",
    "pacing": "motivo_breve_citando_frames"
  },
  "emotion_detected": "string_o_neutral",
  "main_topic": "tema_basado_en_frames_visibles",
  "editing_pace": "lento_medio_rapido",
  "on_screen_text": [
    {
      "text": "texto_exacto_visible",
      "frame": "frame_X"
    }
  ],
  "audio_key_phrases": [],
  "cta_detected": {
    "exists": boolean,
    "description": "descripcion_si_existe_o_vacio"
  },
  "why_it_works_or_not": "diagnostico_con_evidencias_visuales_especificas",
  "3_specific_improvements": [
    "mejora_1_basada_en_deficiencia_observable",
    "mejora_2_basada_en_frames_especificos",
    "mejora_3_basada_en_evidencia_visual"
  ],
  "evidence": {
    "frames_referenced": ["frame_1", "frame_3"],
    "audio_referenced": false
  }
}

AUTOCONTROL ANTES DE RESPONDER:
- ¿Este análisis sería distinto con otro vídeo?
- ¿He citado frames reales específicos?
- ¿He evitado frases genéricas?
- ¿Cada conclusión tiene evidencia visual?

Si alguna respuesta es NO → devuelve ERROR.`;
}

app.post('/api/analyze', async (req, res) => {
    const title = field(req.body?.title, 200) || "Video";
    const frames = req.body?.frames;
    if (!Array.isArray(frames) || frames.length < MIN_FRAMES || frames.length > MAX_FRAMES) {
        return res.status(400).json({ error: `Se necesitan entre ${MIN_FRAMES} y ${MAX_FRAMES} frames.` });
    }
    if (!frames.every(f => typeof f === 'string' && f.length > 0 && f.length <= MAX_FRAME_BASE64_CHARS)) {
        return res.status(400).json({ error: "Frames inválidos." });
    }

    const content = [
        { type: "text", text: analyzeUserPrompt(title, frames.length) },
        ...frames.map(data => ({ type: "image", source: { type: "base64", media_type: "image/jpeg", data } }))
    ];

    try {
        const result = await askClaude({
            system: ANALYZE_SYSTEM_PROMPT,
            messages: [{ role: "user", content }],
            maxTokens: 2000,
            temperature: 0.35
        });
        res.json({ text: result });
    } catch (error) {
        handleError(res, '/api/analyze', error);
    }
});

// 2. Endpoint para generar guiones UGC
const SCRIPTS_SYSTEM_PROMPT = `Eres un experto copywriter especializado en UGC (User Generated Content) para redes sociales de negocios.
Tu trabajo es crear guiones virales que conviertan visualizaciones en clientes.

REGLAS CRÍTICAS:
1. SIEMPRE responde en español de España
2. Cada guión debe ser específico al negocio y producto mencionado
3. Incluye números, datos o resultados cuando sea posible
4. El hook DEBE ser irresistible y hacer scroll-stop
5. El CTA debe ser claro y accionable
6. Adapta el tono al público objetivo
7. Respeta la duración especificada

ESTRUCTURA OBLIGATORIA para cada guión:
\`\`\`json
{
  "title": "Título descriptivo del guión",
  "hook": "Primera frase que para el scroll (2-3 segundos)",
  "body": ["Párrafo 1 del desarrollo", "Párrafo 2 del desarrollo", "Párrafo 3 del desarrollo"],
  "cta": "Call to action final claro",
  "subtitles": [
    {"text": "Texto del subtítulo", "startTime": 0.0, "endTime": 3.0, "position": "bottom"},
    {"text": "Segundo subtítulo", "startTime": 3.0, "endTime": 6.0, "position": "bottom"}
  ],
  "shotList": [
    {"sequence": 1, "description": "Descripción de la toma", "duration": "2-3s", "cameraAngle": "closeUp", "notes": "Notas adicionales"},
    {"sequence": 2, "description": "Segunda toma", "duration": "3-4s", "cameraAngle": "mediumShot", "notes": ""}
  ],
  "hookScore": 85
}
\`\`\`

IMPORTANTE:
- hookScore del 1-100 basado en potencial viral
- shotList debe tener instrucciones claras de grabación
- subtitles deben coincidir con la duración total
- NO inventes datos falsos, usa ejemplos realistas`;

function scriptsUserPrompt(r, count) {
    const plural = count === 1 ? "" : "es";
    const pluralS = count === 1 ? "" : "s";
    return `INFORMACIÓN DEL NEGOCIO:
- Tipo de negocio: ${r.businessType}
- Producto/Servicio: ${r.productService}
- Público objetivo: ${r.targetAudience}
- Nicho: ${r.niche}

ESPECIFICACIONES DEL CONTENIDO:
- Duración del reel: ${r.duration}
- Tipo de hook: ${r.hookType} (${r.hookTypeDescription})
- Tono deseado: ${r.tone}
- Beneficios clave: ${r.keyBenefits.join(", ")}

TAREA:
Genera ${count} guion${plural} completamente diferente${pluralS} para este negocio.

REQUISITOS ESPECÍFICOS:
1. Cada guión debe ser único y abordar diferentes ángulos del negocio
2. Hooks completamente diferentes entre sí
3. Adapta el lenguaje al público objetivo especificado
4. Incluye detalles específicos del producto/servicio mencionado
5. Los subtítulos deben ser legibles (máximo 8 palabras por línea)
6. Las tomas deben ser factibles para una persona grabando sola

Responde ÚNICAMENTE con un array JSON válido de ${count} guion${plural}:
[
  { guión 1 },
  { guión 2 },
  ...
]`;
}

app.post('/api/scripts', async (req, res) => {
    const body = req.body || {};
    const count = Number.isInteger(body.count) ? body.count : 1;
    if (count < 1 || count > MAX_SCRIPTS) {
        return res.status(400).json({ error: `Puedes pedir entre 1 y ${MAX_SCRIPTS} guiones.` });
    }

    const r = {
        businessType: field(body.businessType),
        productService: field(body.productService),
        targetAudience: field(body.targetAudience),
        niche: field(body.niche) || "",
        duration: field(body.duration, 50),
        hookType: field(body.hookType, 50),
        hookTypeDescription: field(body.hookTypeDescription) || "",
        tone: field(body.tone, 50),
        keyBenefits: Array.isArray(body.keyBenefits) ? body.keyBenefits.map(b => field(b)).filter(Boolean).slice(0, 10) : []
    };
    if (!r.businessType || !r.productService || !r.targetAudience || !r.duration || !r.hookType || !r.tone) {
        return res.status(400).json({ error: "Faltan datos del negocio o del guion." });
    }

    try {
        const result = await askClaude({
            system: SCRIPTS_SYSTEM_PROMPT,
            messages: [{ role: "user", content: scriptsUserPrompt(r, count) }],
            maxTokens: 2500 * count,
            temperature: 0.7
        });
        res.json({ text: result });
    } catch (error) {
        handleError(res, '/api/scripts', error);
    }
});

// Arrancar servidor (no expuesto a internet: el proxy publica la API con HTTPS)
const server = app.listen(PORT, HOST, () => {
    console.log(`🚀 Servidor backend Hazte Viral corriendo en http://${HOST}:${PORT}`);
});
server.requestTimeout = 180000;
