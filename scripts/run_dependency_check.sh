#!/bin/bash
# Script para ejecutar OWASP Dependency Check
# Uso: ./run_dependency_check.sh

echo "[*] Ejecutando OWASP Dependency Check (SCA)..."

# Crear directorio de reportes si no existe
mkdir -p dependency-check-reports

# Ejecutar Dependency Check
docker run --rm \
  -v "$(pwd)":/src \
  -v odc_cache:/usr/share/dependency-check/data \
  -e NVD_API_KEY="" \
  owasp/dependency-check:latest \
  dependency-check \
  --project "devsecops-labs" \
  --scan /src \
  --format JSON \
  --out /src/dependency-check-reports

if [ -f "dependency-check-reports/dependency-check-report.json" ]; then
    echo "[*] Análisis SCA completado"
    echo "[*] Resultados guardados en: dependency-check-reports/"
    echo "[*] Tamaño del archivo: $(wc -c < dependency-check-reports/dependency-check-report.json) bytes"
else
    echo "[!] Error: No se pudo generar el reporte de Dependency Check"
    exit 1
fi

echo "[*] Mostrando resumen de vulnerabilidades..."
if command -v jq &> /dev/null; then
    cat dependency-check-reports/dependency-check-report.json | jq '.dependencies | length' 2>/dev/null || echo "No se pudo parsear el JSON"
else
    echo "Instalar 'jq' para ver resúmenes detallados"
fi
