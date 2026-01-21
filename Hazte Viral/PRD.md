# Go Viral - PRD (Product Requirements Document)

## 📱 Resumen del Producto

**Go Viral** es una aplicación iOS nativa que utiliza inteligencia artificial avanzada para analizar videos cortos y predecir su potencial viral en plataformas como TikTok e Instagram Reels. La app proporciona análisis visual real del contenido, métricas de engagement específicas y consejos personalizados para maximizar el alcance viral.

---

## 🎯 Objetivos del Producto

### Objetivo Principal
Ayudar a creadores de contenido a optimizar sus videos cortos para maximizar su potencial viral mediante análisis de IA basado en contenido visual real.

### Objetivos Secundarios
- Proporcionar feedback específico según el tipo de contenido (fitness, cocina, lifestyle, etc.)
- Ofrecer métricas cuantificables de rendimiento predictivo
- Educar a los usuarios sobre mejores prácticas de contenido viral
- Mantener historial de análisis para seguimiento de mejoras

---

## 👥 Usuarios Objetivo

### Usuario Primario: Creator Aspiracional
- **Demografía**: 18-35 años, creadores de contenido emergentes
- **Comportamiento**: Publican contenido regularmente pero luchan por conseguir views
- **Necesidades**: Feedback objetivo sobre calidad de contenido, consejos específicos
- **Pain Points**: No saben por qué algunos videos funcionan y otros no

### Usuario Secundario: Creator Experimentado  
- **Demografía**: 25-45 años, influencers establecidos
- **Comportamiento**: Buscan optimización constante y datos específicos
- **Necesidades**: Análisis técnico profundo, comparativas con benchmarks
- **Pain Points**: Necesitan datos cuantitativos para mejorar estrategia

---

## ✨ Funcionalidades Implementadas

### 🎬 Core Features

#### 1. Subida y Preview de Video
- **Descripción**: Selección de videos desde la galería con preview inmediato
- **Implementación**: 
  - PhotosPicker nativo de iOS
  - Reproducción automática en formato 9:16
  - Botón único que cambia según el estado ("Subir video" → "Iniciar análisis")
  - Indicador visual de carga durante subida
- **UX**: Interfaz simplificada con un solo flujo principal

#### 2. Análisis Visual de IA con Claude
- **Descripción**: Análisis real del contenido visual usando Claude Vision
- **Implementación**:
  - Extracción de 3 frames del video (inicio, medio, final)
  - Envío de imágenes a Claude API con análisis visual
  - Identificación automática del tipo de contenido (fitness, cocina, lifestyle, etc.)
  - Prompts en español optimizados para feedback específico
- **Capacidades**:
  - Reconoce contenido visual específico (personas, objetos, texto, animales)
  - Analiza iluminación, composición y calidad técnica
  - Evalúa elementos de engagement (caras, movimiento, colores)

#### 3. Sistema de Métricas Avanzado
- **Métricas Principales**:
  - **Retención** (0-100): Capacidad de mantener atención
  - **Fuerza del Hook** (0-100): Impacto de los primeros 3 segundos  
  - **Claridad del Mensaje** (0-100): Legibilidad y comprensión
  - **Ritmo** (0-100): Velocidad y fluidez del contenido
  - **Potencial Viral** (0-100): Probabilidad de engagement masivo
- **Predicciones**: Visualizaciones estimadas (1K-2M range)
- **Comparativas**: Benchmarking contra promedios de TikTok

### 📊 Interfaz de Resultados

#### 1. Pestaña "Resultados"
- **Resumen visual** con métricas en grid
- **"✨ Lo que Destacó la IA"**: 3 observaciones específicas del contenido visual
- **"🚀 Acciones Inmediatas"**: 3 mejoras concretas basadas en lo observado
- **Información básica**: Fecha, título, predicción de views

#### 2. Pestaña "Consejos Pro" 
- **🎬 Estrategia de Contenido**: Tips específicos por tipo de video
  - Para vlogs: "Si es un vlog personal, comienza con 'No vas a creer lo que me pasó...'"
  - Para fitness: "Si es rutina fitness, muestra el 'antes/después' al inicio"
  - Para recetas: "Si es receta, enseña el resultado final primero"
- **⚙️ Optimización Técnica**: Mejoras técnicas inmediatas
- **🚀 Trucos del Algoritmo**: Estrategias de posting y engagement

#### 3. Pestaña "Estadísticas"
- **Tabla estadística profesional**:
  - Columnas: Métrica | Tu Video | Promedio | Estado
  - Estados: "Excelente", "Sobre Promedio", "Puede Mejorar", "Necesita Trabajo"
  - Comparación con benchmarks de TikTok
- **Predicción de rendimiento** con visualizaciones estimadas
- **Puntuación general** codificada por colores

### 🎨 Experiencia de Usuario

#### 1. Onboarding
- **3 pasos educativos**:
  1. "Sube un video vertical"
  2. "Reproducción + botón IA" 
  3. "Resultados y consejos"
- **Skip option** para usuarios experimentados

#### 2. Loading States
- **Subida de video**: "Subiendo..." con spinner
- **Análisis de IA**: Mensajes rotativos cada 2 segundos:
  - "🧠 La IA está analizando tu contenido..."
  - "✨ Detectando potencial viral..."
  - "🎯 Calculando métricas de engagement..."
  - "🚀 Prediciendo cantidad de visualizaciones..."
  - "📊 Generando insights..."
  - "🎬 Casi listo, finalizando resultados..."

#### 3. Historial
- **Persistencia local** de todos los análisis
- **Lista cronológica** con preview rápido
- **Métricas resumidas** por análisis

---

## 🏗️ Arquitectura Técnica

### Stack Tecnológico
- **Framework**: SwiftUI (iOS 15+)
- **IA Provider**: Anthropic Claude Vision API
- **Video Processing**: AVFoundation para extracción de frames
- **Persistencia**: Local storage con Codable
- **UI Framework**: Nativo de iOS con Material Glass design

### Arquitectura de Servicios

#### 1. AIService Layer
```swift
protocol AIAnalysisProviding {
    func analyze(videoURL: URL, title: String?) async throws -> AnalysisReport
}
```

#### 2. Implementaciones
- **ClaudeAIService**: Análisis real con Claude Vision
  - Extracción de frames con AVFoundation
  - Conversión a base64 para API
  - Prompts optimizados en español
- **MockAIService**: Datos simulados para desarrollo/testing

#### 3. Modelos de Datos
```swift
struct AnalysisReport {
    let id: UUID
    let title: String
    let createdAt: Date
    let predictedViews: Int
    let metrics: EngagementMetrics
    let highlights: [String]
    let recommendations: [String]
}
```

### Flujo de Análisis
1. **Usuario selecciona video** → PhotosPicker
2. **Extracción de frames** → VideoFrameExtractor (3 frames)
3. **Envío a Claude** → ClaudeAIService con imágenes
4. **Procesamiento** → Claude analiza contenido visual real
5. **Resultados** → Parsing y presentación en UI
6. **Persistencia** → HistoryStore guarda localmente

---

## 🔧 Configuración y Setup

### Variables de Entorno
```bash
export ANTHROPIC_API_KEY="sk-ant-api03-..."
export ANTHROPIC_MODEL="claude-3-5-sonnet-20240620"  # Opcional
export ANTHROPIC_MAX_TOKENS="400"  # Opcional
```

### Fallback Strategy
- **Con API key**: ClaudeAIService (análisis real)
- **Sin API key**: MockAIService (datos simulados)

---

## 📱 Estados de la Aplicación

### Estados del Botón Principal
1. **Sin video**: "Subir video" (PhotosPicker trigger)
2. **Video cargando**: "Subiendo..." (con spinner)
3. **Video listo**: "Iniciar análisis"
4. **Analizando**: "La IA está trabajando..." (disabled)
5. **Completo**: "Ver resultado"

### Manejo de Errores
- **Video inválido**: "No se pudo leer el video"
- **Sin API key**: "Clave API faltante o inválida"
- **Error de red**: Mensaje específico del servidor
- **Timeout**: Manejo automático con retry

---

## 🌐 Localización

### Idioma Principal: Español
- **100% de la interfaz** en español
- **Prompts de Claude** optimizados en español  
- **Mensajes de error** localizados
- **Consejos específicos** para audiencia hispana

### Ejemplos de Localización
- Horarios optimizados: "Si tu audiencia es latina, publica 7-9 PM"
- Hashtags regionales: Combinación de hashtags globales y locales
- Referencias culturales: Adaptado al mercado hispanohablante

---

## 📊 Métricas de Éxito

### KPIs Principales
1. **Engagement Rate**: Tiempo promedio en resultados
2. **Retention**: Usuarios que analizan múltiples videos
3. **Accuracy Perception**: Satisfacción con consejos (feedback cualitativo)
4. **Feature Usage**: Distribución entre pestañas de resultados

### Métricas Técnicas
1. **Analysis Success Rate**: % de análisis completados exitosamente
2. **Response Time**: Tiempo promedio de análisis (<30s objetivo)
3. **Frame Extraction Rate**: % de videos procesados correctamente
4. **API Reliability**: Uptime de servicios de Claude

---

## 🚀 Roadmap Futuro

### v1.1 - Mejoras Inmediatas
- [ ] Soporte para videos más largos (>60s)
- [ ] Análisis de audio/música
- [ ] Exportación de reportes
- [ ] Comparativas entre análisis

### v1.2 - Features Avanzadas  
- [ ] Análisis de tendencias
- [ ] Recomendaciones de hashtags dinámicas
- [ ] Integración con redes sociales
- [ ] Tracking de performance real

### v2.0 - Expansión
- [ ] Soporte multi-idioma
- [ ] Análisis colaborativo
- [ ] Dashboard web
- [ ] API para terceros

---

## 🔍 Casos de Uso Principales

### Caso 1: Creator Novato
**Situación**: Primera vez creando contenido para TikTok
**Flujo**: 
1. Sube video de prueba
2. Recibe análisis detallado con tipo de contenido identificado
3. Sigue consejos específicos de "Estrategia de Contenido"
4. Mejora video basado en "Acciones Inmediatas"

### Caso 2: Influencer Establecido
**Situación**: Optimización de contenido existente
**Flujo**:
1. Analiza múltiples videos del mismo tipo
2. Compara métricas en "Estadísticas"
3. Identifica patrones en historial
4. Aplica "Trucos del Algoritmo" para maximizar alcance

### Caso 3: Agencia de Marketing
**Situación**: Análisis de contenido para clientes
**Flujo**:
1. Análisis sistemático de diferentes tipos de contenido
2. Benchmarking contra competencia usando métricas
3. Recomendaciones específicas por vertical
4. Seguimiento de mejoras en el tiempo

---

## 💡 Diferenciadores Clave

### vs Competitors
1. **Análisis Visual Real**: No solo metadata, ve el contenido actual
2. **Consejos Específicos**: Adaptados al tipo de contenido detectado
3. **Interfaz en Español**: Completamente localizada
4. **Métricas Cuantificables**: Puntuaciones específicas vs feedback genérico
5. **Tabla Estadística**: Comparación directa con benchmarks

### Ventajas Técnicas
1. **Claude Vision**: Análisis de imagen más avanzado que OCR básico
2. **Frame Extraction**: Análisis de múltiples momentos del video
3. **Prompt Engineering**: Optimizado para feedback accionable
4. **Arquitectura Modular**: Fácil integración de nuevos AI providers

---

## 📋 Notas de Implementación

### Consideraciones de Privacidad
- **Procesamiento local** de extracción de frames
- **No almacenamiento** de videos en servidores externos
- **Datos mínimos** enviados a Claude (solo 3 frames)
- **Historial local** sin sincronización cloud

### Performance
- **Compresión de imágenes** antes de envío a API
- **Timeout handling** para análisis largos
- **Background processing** para extracción de frames
- **Cache local** de resultados

### Escalabilidad
- **Rate limiting** para API calls
- **Queue system** para múltiples análisis
- **Graceful degradation** a MockAIService
- **Configuración flexible** por entorno

---

**Última actualización**: Diciembre 2025 
**Versión del documento**: 2.0  
**Estado del proyecto**: Completamente funcional con análisis visual real
