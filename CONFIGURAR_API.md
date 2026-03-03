# Configuración de la API de Claude para Go Viral

## 🔑 Obtener tu API Key

1. Ve a [https://console.anthropic.com/](https://console.anthropic.com/)
2. Crea una cuenta o inicia sesión
3. Ve a "API Keys" en el menú lateral
4. Crea una nueva API key
5. Copia la clave (comienza con `sk-ant-`)

## ⚙️ Configurar la API Key en Xcode

### Opción 1: Variables de Entorno del Sistema (Recomendado)

1. Abre Terminal
2. Edita tu archivo de configuración del shell:
   ```bash
   # Para zsh (macOS Monterey+)
   nano ~/.zshrc
   
   # Para bash (versiones anteriores de macOS)
   nano ~/.bash_profile
   ```

3. Añade al final del archivo:
   ```bash
   export ANTHROPIC_API_KEY="sk-ant-tu_clave_aqui"
   ```

4. Guarda el archivo (`Ctrl+O`, luego `Ctrl+X` en nano)

5. Recarga la configuración:
   ```bash
   source ~/.zshrc
   # o
   source ~/.bash_profile
   ```

6. **IMPORTANTE**: Reinicia Xcode completamente para que tome las variables

### Opción 2: Variables en el Esquema de Xcode

1. En Xcode, ve a **Product → Scheme → Edit Scheme...**
2. En la pestaña **Run** (lado izquierdo)
3. Selecciona **Environment Variables**
4. Haz clic en el botón **+**
5. Añade:
   - Name: `ANTHROPIC_API_KEY`
   - Value: `sk-ant-tu_clave_aqui`
6. Marca la casilla **Active**
7. Haz clic en **Close**

## 🧪 Verificar la Configuración

### Opción A: Usando el Script de Prueba

```bash
# Ve al directorio del proyecto
cd /path/to/goviiral

# Ejecuta el script de prueba
./test_claude_api.sh
```

### Opción B: En la App

1. Ejecuta la app en el simulador
2. Mira la consola de Xcode (View → Debug Area → Show Debug Area)
3. Busca estos logs al iniciar la app:
   ```
   🏗️ Inicializando AnalyzerViewModel...
   🌟 Usando ClaudeAIService con API key: sk-ant-xx...
   ```

4. Si ves esto, significa que está usando el MockAIService:
   ```
   🎭 API key no encontrada, usando MockAIService
   ```

## 🔍 Diagnóstico de Problemas

### 1. API Key no encontrada
**Síntomas**: App usa MockAIService
**Solución**: 
- Verifica que la variable esté configurada: `echo $ANTHROPIC_API_KEY`
- Reinicia Xcode completamente
- Usa la Opción 2 (esquema de Xcode)

### 2. Error de autenticación (401)
**Síntomas**: Status code 401 en logs
**Solución**:
- Verifica que la API key sea correcta
- Asegúrate de que la clave no haya expirado
- Verifica que tengas créditos en tu cuenta de Anthropic

### 3. Error de parsing JSON
**Síntomas**: Error parseando respuesta de Claude
**Solución**:
- Revisa los logs completos en la consola
- Puede ser un problema temporal de la API
- Verifica que estés usando el modelo correcto

## 📊 Logs de Debug

Una vez configurado, deberías ver estos logs al usar la app:

```
✅ API key encontrada: sk-ant-xx...
✅ Video encontrado: mi_video.mov
🎬 Extrayendo frames del video...
✅ Extraídos 8 frames del video
🖼️ Convirtiendo 8 frames a base64...
📡 Preparando request para Claude API...
🚀 Enviando request a Claude API...
📥 Respuesta recibida de Claude API
📊 Status code: 200
✅ Respuesta válida recibida
🔍 Parseando respuesta de Claude...
✅ JSON parseado correctamente
✅ Análisis completado exitosamente
```

## ❓ Problemas Frecuentes

### "Variable not found" 
- Reinicia Terminal y Xcode
- Verifica el nombre exacto: `ANTHROPIC_API_KEY`

### "403 Forbidden"
- Tu API key no tiene permisos
- Verifica en la consola de Anthropic

### "Rate limit exceeded"
- Has superado el límite de requests
- Espera unos minutos y prueba de nuevo

### "Model not found"
- El modelo puede haber cambiado
- Verifica que uses: `claude-3-5-sonnet-20240620`

## 💡 Consejos

1. **Nunca** pongas tu API key directamente en el código
2. Añade `*.env` y archivos con claves a `.gitignore`
3. Usa diferentes claves para desarrollo y producción
4. Monitorea tu uso en la consola de Anthropic