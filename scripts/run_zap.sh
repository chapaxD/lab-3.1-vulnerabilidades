#!/bin/bash
# Script para ejecutar OWASP ZAP
# Uso: ./run_zap.sh <url-target>

if [ $# -eq 0 ]; then
    echo "Error: Debe especificar la URL objetivo"
    echo "Uso: ./run_zap.sh <url-target>"
    exit 1
fi

TARGET_URL=$1
OUTPUT_DIR="zap-reports"

echo "[*] Ejecutando OWASP ZAP (DAST) contra: $TARGET_URL"

# Crear directorio de reportes si no existe
mkdir -p "$OUTPUT_DIR"

# Ejecutar OWASP ZAP
docker run --rm \
  -v "$(pwd)":/zap/wrk:rw \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t "$TARGET_URL" \
  -r "$OUTPUT_DIR/zap-report.html"

if [ -f "$OUTPUT_DIR/zap-report.html" ]; then
    echo "[*] Análisis DAST completado"
    echo "[*] Resultados guardados en: $OUTPUT_DIR/zap-report.html"
    echo "[*] Tamaño del archivo: $(wc -c < $OUTPUT_DIR/zap-report.html) bytes"
else
    echo "[!] Error: No se pudo generar el reporte de ZAP"
    exit 1
fi

echo "[*] Análisis DAST completado contra: $TARGET_URL"
