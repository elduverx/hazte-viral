import Foundation

struct TrainingExample {
    let contentType: String
    let visualDescription: String
    let response: ExampleResponse
}

struct ExampleResponse {
    let title: String
    let predictedViews: Int
    let metrics: ExampleMetrics
    let highlights: [String]
    let recommendations: [String]
    let analysisDetails: ExampleAnalysisDetails
}

struct ExampleMetrics {
    let retentionScore: Int
    let hookStrength: Int
    let messageClarity: Int
    let pacing: Int
    let viralityProbability: Int
}

struct ExampleAnalysisDetails {
    let hookAnalysis: String
    let mainTopicIdentified: String
    let emotionDetected: String
    let editingPace: String
    let onScreenTextDetected: String
    let whyWorksOrNot: String
}

// MARK: - Training Dataset

class TrainingDataset {
    static let examples: [TrainingExample] = [
        // FITNESS - RUTINA DE EJERCICIOS
        TrainingExample(
            contentType: "fitness",
            visualDescription: "Frame 1: Mujer en ropa deportiva frente a espejo. Frame 2: Ejecutando sentadilla con forma perfecta. Frame 3: Mostrando músculos post-ejercicio. Texto visible: 'GLÚTEOS EN 30 DÍAS'",
            response: ExampleResponse(
                title: "Rutina de glúteos para principiantes",
                predictedViews: 180000,
                metrics: ExampleMetrics(retentionScore: 78, hookStrength: 85, messageClarity: 90, pacing: 75, viralityProbability: 82),
                highlights: [
                    "Hook efectivo: muestra inmediatamente el ejercicio con forma correcta en el primer frame",
                    "Texto claro y llamativo 'GLÚTEOS EN 30 DÍAS' genera expectativa inmediata",
                    "Progresión visual clara: preparación -> ejecución -> resultado motivacional"
                ],
                recommendations: [
                    "Añade contador visual (ej: '3/10 repeticiones') para mantener engagement",
                    "Incluye timer visible durante cada ejercicio para ritmo más dinámico",
                    "Agrega texto con músculos trabajados superpuesto en la imagen"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Apertura sólida mostrando la posición inicial del ejercicio con espejo de fondo - genera confianza en la técnica",
                    mainTopicIdentified: "Tutorial de ejercicio para glúteos con enfoque en forma correcta",
                    emotionDetected: "determinación y motivación",
                    editingPace: "medio - permite ver la técnica correctamente",
                    onScreenTextDetected: "GLÚTEOS EN 30 DÍAS - promesa específica y temporal",
                    whyWorksOrNot: "Funciona porque combina tutorial técnico con promesa de resultado específico en timeframe claro"
                )
            )
        ),
        
        // COCINA - RECETA RÁPIDA
        TrainingExample(
            contentType: "cocina",
            visualDescription: "Frame 1: Ingredientes ordenados en mesa (pasta, tomate, queso). Frame 2: Manos cortando tomate en cámara rápida. Frame 3: Plato final humeante con pasta perfecta. Texto: 'PASTA EN 8 MINUTOS'",
            response: ExampleResponse(
                title: "Pasta italiana express en 8 minutos",
                predictedViews: 95000,
                metrics: ExampleMetrics(retentionScore: 88, hookStrength: 75, messageClarity: 95, pacing: 85, viralityProbability: 78),
                highlights: [
                    "Ingredientes claramente visibles desde el frame 1 - permite seguir la receta",
                    "Movimientos rápidos y precisos en el corte - muestra habilidad culinaria",
                    "Resultado final apetitoso con vapor visible - genera deseo inmediato"
                ],
                recommendations: [
                    "Añade temporizador visible durante la cocción para enfatizar la velocidad",
                    "Incluye text overlay con cantidades exactas durante la preparación",
                    "Muestra el 'antes/después' más dramáticamente con split screen"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Setup perfecto mostrando todos los ingredientes organizados - promete simplicidad y organización",
                    mainTopicIdentified: "Receta rápida de pasta italiana con énfasis en velocidad",
                    emotionDetected: "urgencia positiva y satisfacción",
                    editingPace: "rápido - ideal para recetas express",
                    onScreenTextDetected: "PASTA EN 8 MINUTOS - promesa de rapidez específica",
                    whyWorksOrNot: "Funciona porque resuelve el problema común 'qué cocinar rápido' con resultado visualmente atractivo"
                )
            )
        ),
        
        // BELLEZA - MAKEUP TRANSFORMATION
        TrainingExample(
            contentType: "belleza",
            visualDescription: "Frame 1: Rostro natural sin maquillaje, buena iluminación. Frame 2: Aplicando base con esponja beauty blender. Frame 3: Look completo con ojos ahumados dramáticos. Texto: 'SMOKEY EYES FÁCIL'",
            response: ExampleResponse(
                title: "Transformation smokey eyes para principiantes",
                predictedViews: 220000,
                metrics: ExampleMetrics(retentionScore: 85, hookStrength: 90, messageClarity: 80, pacing: 78, viralityProbability: 88),
                highlights: [
                    "Contraste dramático entre estado inicial y final genera impacto visual fuerte",
                    "Técnica con beauty blender muestra herramientas profesionales accesibles",
                    "Resultado final sofisticado pero promete ser 'fácil' - reduce intimidación"
                ],
                recommendations: [
                    "Acelera la transición entre el frame 1 y 3 para más impacto viral",
                    "Añade nombres de productos usados con texto superpuesto",
                    "Incluye tips escritos durante la aplicación (ej: 'difumina en círculos')"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Cara limpia con buena iluminación establece baseline perfecto para mostrar la transformación",
                    mainTopicIdentified: "Tutorial de maquillaje con transformación dramática usando técnica smokey eyes",
                    emotionDetected: "asombro y aspiración",
                    editingPace: "medio-rápido - permite ver técnica pero mantiene dinamismo",
                    onScreenTextDetected: "SMOKEY EYES FÁCIL - desmitifica técnica avanzada",
                    whyWorksOrNot: "Funciona porque muestra transformación real con técnica específica y promesa de simplicidad"
                )
            )
        ),
        
        // LIFESTYLE - MORNING ROUTINE
        TrainingExample(
            contentType: "lifestyle",
            visualDescription: "Frame 1: Cama perfectamente ordenada en habitación luminosa. Frame 2: Persona haciendo yoga en balcón. Frame 3: Desayuno saludable con frutas coloridas. Texto: 'RUTINA 6AM'",
            response: ExampleResponse(
                title: "Rutina matutina productiva desde las 6AM",
                predictedViews: 150000,
                metrics: ExampleMetrics(retentionScore: 75, hookStrength: 70, messageClarity: 85, pacing: 68, viralityProbability: 72),
                highlights: [
                    "Secuencia aspiracional bien estructurada: orden -> ejercicio -> nutrición",
                    "Iluminación natural excelente en todos los frames transmite energía positiva",
                    "Elementos visuales Instagram-worthy en cada escena (cama, yoga, food styling)"
                ],
                recommendations: [
                    "Acelera las transiciones entre actividades para mantener atención",
                    "Añade time-stamps en cada actividad (6:00 cama, 6:15 yoga, 6:30 desayuno)",
                    "Incluye beneficios de cada hábito con texto overlay ('Yoga = energía', 'Frutas = vitaminas')"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Cama impecable sugiere orden y productividad desde el primer momento",
                    mainTopicIdentified: "Rutina matutina aspiracional enfocada en bienestar y productividad",
                    emotionDetected: "inspiración y motivación",
                    editingPace: "lento-medio - refleja la calma matutina pero podría ser más dinámico",
                    onScreenTextDetected: "RUTINA 6AM - horario específico genera curiosidad sobre el estilo de vida",
                    whyWorksOrNot: "Funciona moderadamente porque inspira pero le falta dinamismo para engagement masivo"
                )
            )
        ),
        
        // PETS - TRUCO CON PERRO
        TrainingExample(
            contentType: "mascotas",
            visualDescription: "Frame 1: Golden retriever sentado mirando a cámara. Frame 2: Dueña mostrando comando con la mano. Frame 3: Perro ejecutando 'high five' perfectamente. Texto: 'TRUCO EN 5 MINS'",
            response: ExampleResponse(
                title: "Enseña 'high five' a tu perro en 5 minutos",
                predictedViews: 320000,
                metrics: ExampleMetrics(retentionScore: 92, hookStrength: 88, messageClarity: 90, pacing: 85, viralityProbability: 95),
                highlights: [
                    "Golden retriever genera ternura instantánea - alta conexión emocional",
                    "Comando claro y visible permite replicar el entrenamiento inmediatamente",
                    "Ejecución perfecta del truco en frame final - satisfacción y motivación para intentarlo"
                ],
                recommendations: [
                    "Mantén el enfoque actual - el contenido de mascotas tiene alto potencial viral",
                    "Considera serie de trucos progresivos para crear expectativa de próximos videos",
                    "Añade texto con tips de refuerzo positivo durante el entrenamiento"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Perro mirando directamente a cámara crea conexión inmediata y anticipa interacción",
                    mainTopicIdentified: "Tutorial de entrenamiento canino con truco específico y timeframe definido",
                    emotionDetected: "ternura y satisfacción",
                    editingPace: "óptimo - permite ver el proceso pero mantiene dinamismo",
                    onScreenTextDetected: "TRUCO EN 5 MINS - promesa realista y específica para pet training",
                    whyWorksOrNot: "Altamente viral porque combina cute factor + utilidad práctica + resultado gratificante"
                )
            )
        ),
        
        // EDUCATIVO - DATO CURIOSO
        TrainingExample(
            contentType: "educativo",
            visualDescription: "Frame 1: Mapamundi con zoom en Japón. Frame 2: Persona comparando objetos de tamaño (moneda vs imagen). Frame 3: Gráfico sorprendente con números grandes. Texto: 'DATO QUE NO SABÍAS'",
            response: ExampleResponse(
                title: "Dato increíble sobre Japón que cambiará tu perspectiva",
                predictedViews: 280000,
                metrics: ExampleMetrics(retentionScore: 80, hookStrength: 85, messageClarity: 88, pacing: 82, viralityProbability: 83),
                highlights: [
                    "Hook de curiosidad efectivo con promesa de conocimiento exclusivo",
                    "Visualización clara con comparaciones tangibles (moneda como referencia de tamaño)",
                    "Gráfico impactante en frame final refuerza la sorpresa del dato"
                ],
                recommendations: [
                    "Acelera la revelación del dato principal para mantener el suspense más intenso",
                    "Añade countdown o progresión visual hacia la revelación",
                    "Incluye call-to-action sobre compartir el dato ('comparte si te sorprendió')"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Mapamundi inmediatamente establece contexto geográfico y despierta curiosidad sobre el lugar específico",
                    mainTopicIdentified: "Contenido educativo de datos curiosos con enfoque geográfico/cultural",
                    emotionDetected: "curiosidad y asombro",
                    editingPace: "bien balanceado - construye suspense adecuadamente",
                    onScreenTextDetected: "DATO QUE NO SABÍAS - genera FOMO y promete conocimiento exclusivo",
                    whyWorksOrNot: "Funciona bien porque satisface curiosidad humana básica con formato visualmente claro"
                )
            )
        ),
        
        // DANZA - COREOGRAFÍA VIRAL
        TrainingExample(
            contentType: "danza",
            visualDescription: "Frame 1: Persona en posición inicial, fondo colorido. Frame 2: Movimiento dinámico con brazos extendidos. Frame 3: Final de coreografía con pose signature. Audio: Trending sound actual",
            response: ExampleResponse(
                title: "Aprende esta coreografía viral en 30 segundos",
                predictedViews: 450000,
                metrics: ExampleMetrics(retentionScore: 95, hookStrength: 92, messageClarity: 75, pacing: 95, viralityProbability: 98),
                highlights: [
                    "Uso de trending sound maximiza alcance algorítmico automáticamente",
                    "Movimientos claros y replicables - fácil para audience seguir",
                    "Pose final signature crea momento memorable para shares"
                ],
                recommendations: [
                    "Perfecto como está - contenido de danza tiene máximo potencial viral",
                    "Considera slowmo en momentos clave para mejor comprensión de pasos",
                    "Añade texto con nombres de pasos para facilitar aprendizaje"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Posición inicial clara con fondo llamativo inmediatamente identifica contenido como danza/movimiento",
                    mainTopicIdentified: "Tutorial de coreografía usando trending sound con enfoque en viralidad",
                    emotionDetected: "energía y diversión",
                    editingPace: "muy rápido - perfecto para mantener energía del audio trending",
                    onScreenTextDetected: "ninguno visible pero el ritmo visual suple la necesidad",
                    whyWorksOrNot: "Máximo potencial viral por combinación de trending audio + movimiento replicable + energía positiva"
                )
            )
        ),
        
        // TECH/LIFE HACK
        TrainingExample(
            contentType: "lifehack",
            visualDescription: "Frame 1: Smartphone con cables desordenados. Frame 2: Manos doblando papel de forma específica. Frame 3: Cables perfectamente organizados con el 'hack'. Texto: 'HACK VIRAL'",
            response: ExampleResponse(
                title: "Life hack para organizar cables que nadie te enseñó",
                predictedViews: 380000,
                metrics: ExampleMetrics(retentionScore: 85, hookStrength: 80, messageClarity: 95, pacing: 78, viralityProbability: 90),
                highlights: [
                    "Problema universal identificable (cables desordenados) genera conexión inmediata",
                    "Solución simple usando materiales cotidianos (papel) - alta replicabilidad",
                    "Resultado final visualmente satisfactorio - orden vs caos inicial"
                ],
                recommendations: [
                    "Añade timer para enfatizar lo rápido de la solución",
                    "Muestra el hack funcionando con diferentes tipos de cables",
                    "Incluye texto con materiales necesarios desde el primer frame"
                ],
                analysisDetails: ExampleAnalysisDetails(
                    hookAnalysis: "Cables enredados inmediatamente evocan frustración compartida y necesidad de solución",
                    mainTopicIdentified: "Life hack para organización doméstica con enfoque en tecnología cotidiana",
                    emotionDetected: "satisfacción y alivio",
                    editingPace: "medio - permite seguir el proceso pero mantiene interés",
                    onScreenTextDetected: "HACK VIRAL - promesa de contenido trending y útil",
                    whyWorksOrNot: "Alto potencial porque soluciona problema real + resultado inmediatamente visible + fácil replicar"
                )
            )
        )
    ]
    
    // MARK: - Helper Methods
    
    static func getExamplesByType(_ contentType: String) -> [TrainingExample] {
        return examples.filter { $0.contentType.lowercased() == contentType.lowercased() }
    }
    
    static func getRandomExamples(count: Int = 3) -> [TrainingExample] {
        return Array(examples.shuffled().prefix(count))
    }
    
    static func getAllContentTypes() -> [String] {
        return Array(Set(examples.map { $0.contentType }))
    }
    
    static func formatExampleForPrompt(_ example: TrainingExample) -> String {
        let metrics = example.response.metrics
        let details = example.response.analysisDetails
        
        return """
        EJEMPLO DE ANÁLISIS REAL:
        
        Descripción visual: \(example.visualDescription)
        
        Respuesta JSON esperada:
        {
          "title": "\(example.response.title)",
          "predicted_views": \(example.response.predictedViews),
          "metrics": {
            "retention_score": \(metrics.retentionScore),
            "hook_strength": \(metrics.hookStrength),
            "message_clarity": \(metrics.messageClarity),
            "pacing": \(metrics.pacing),
            "virality_probability": \(metrics.viralityProbability)
          },
          "highlights": [
            "\(example.response.highlights[0])",
            "\(example.response.highlights[1])",
            "\(example.response.highlights[2])"
          ],
          "recommendations": [
            "\(example.response.recommendations[0])",
            "\(example.response.recommendations[1])",
            "\(example.response.recommendations[2])"
          ],
          "analysis_details": {
            "hook_analysis": "\(details.hookAnalysis)",
            "main_topic_identified": "\(details.mainTopicIdentified)",
            "emotion_detected": "\(details.emotionDetected)",
            "editing_pace": "\(details.editingPace)",
            "on_screen_text_detected": "\(details.onScreenTextDetected)",
            "why_works_or_not": "\(details.whyWorksOrNot)"
          }
        }
        
        ---
        """
    }
}