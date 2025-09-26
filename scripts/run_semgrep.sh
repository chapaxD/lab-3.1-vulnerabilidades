#!/bin/bash
# Script para ejecutar Semgrep
# Uso: ./run_semgrep.sh

echo "[*] Ejecutando Semgrep (SAST)..."

# Crear directorio de resultados si no existe
mkdir -p .

# Ejecutar Semgrep
docker run --rm -v "$(pwd)":/src returntocorp/semgrep:latest semgrep --config=auto /src/src --json > semgrep-results.json 2>/dev/null

if [ -f "semgrep-results.json" ]; then
    echo "[*] Análisis SAST completado"
    echo "[*] Resultados guardados en: semgrep-results.json"
    echo "[*] Tamaño del archivo: $(wc -c < semgrep-results.json) bytes"
else
    echo "[!] Error: No se pudo generar el reporte de Semgrep"
    exit 1
fi

echo "[*] Mostrando resumen de resultados..."
cat semgrep-results.json | jq '.results | length' 2>/dev/null || echo "No se pudo parsear el JSON"
