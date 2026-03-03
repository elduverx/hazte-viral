#!/bin/bash

echo "=== PRUEBA DE CONEXIÓN CON CLAUDE API ==="

# Verificar si la API key está configurada
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "❌ ANTHROPIC_API_KEY no está configurada"
    echo ""
    echo "Para configurarla:"
    echo "1. Obtén tu API key desde: https://console.anthropic.com/"
    echo "2. Ejecuta: export ANTHROPIC_API_KEY='tu_api_key_aquí'"
    echo "3. O añádela a tu ~/.zshrc:"
    echo "   echo 'export ANTHROPIC_API_KEY=\"tu_api_key_aquí\"' >> ~/.zshrc"
    echo "   source ~/.zshrc"
    exit 1
fi

echo "✅ API key encontrada: ${ANTHROPIC_API_KEY:0:8}..."

# Hacer una prueba simple con Claude API
echo ""
echo "🚀 Probando conexión con Claude API..."

response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  -X POST \
  "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20240620",
    "max_tokens": 50,
    "messages": [
      {
        "role": "user", 
        "content": "Responde solo: API funcionando"
      }
    ]
  }')

# Extraer código HTTP
http_status=$(echo $response | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
response_body=$(echo $response | sed 's/HTTPSTATUS:[0-9]*$//')

echo "📊 Status code: $http_status"

if [ "$http_status" = "200" ]; then
    echo "✅ API funcionando correctamente"
    echo "📄 Respuesta:"
    echo "$response_body" | jq '.'
else
    echo "❌ Error en API (código $http_status)"
    echo "📄 Respuesta de error:"
    echo "$response_body" | jq '.'
fi

echo ""
echo "==============================================="