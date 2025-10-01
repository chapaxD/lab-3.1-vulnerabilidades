#!/bin/bash
# Script para ejecutar OWASP ZAP y generar solo reporte JSON
# Uso: ./run_zap_json.sh <url-target>

if [ $# -eq 0 ]; then
    echo "Error: Debe especificar la URL objetivo"
    echo "Uso: ./run_zap_json.sh <url-target>"
    exit 1
fi

TARGET_URL=$1
OUTPUT_DIR="zap-reports"
JSON_FILE="$OUTPUT_DIR/zap-report.json"

echo "[*] Ejecutando OWASP ZAP (DAST) contra: $TARGET_URL"
echo "[*] Generando solo reporte JSON..."

# Crear directorio de reportes si no existe
mkdir -p "$OUTPUT_DIR"

# Ejecutar OWASP ZAP solo con JSON
docker run --rm \
  -v "$(pwd)":/zap/wrk:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t "$TARGET_URL" \
  -J "$JSON_FILE"

# Verificar que se generó el reporte JSON
if [ -f "$JSON_FILE" ]; then
    echo "[*] Análisis DAST completado exitosamente"
    echo "[*] Reporte JSON guardado en: $JSON_FILE"
    echo "[*] Tamaño del archivo: $(wc -c < $JSON_FILE) bytes"
    
    # Mostrar resumen básico del JSON
    if command -v jq &> /dev/null; then
        echo "[*] Resumen del reporte:"
        echo "    - Vulnerabilidades encontradas: $(jq '.site[0].alerts | length' $JSON_FILE 2>/dev/null || echo 'N/A')"
        echo "    - URLs escaneadas: $(jq '.site | length' $JSON_FILE 2>/dev/null || echo 'N/A')"
    else
        echo "[*] Instala 'jq' para ver resúmenes del reporte JSON"
    fi
else
    echo "[!] Error: No se pudo generar el reporte JSON de ZAP"
    exit 1
fi

echo "[*] Análisis DAST completado contra: $TARGET_URL"
