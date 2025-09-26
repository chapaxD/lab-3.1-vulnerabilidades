#!/bin/bash
# Script para ejecutar Trivy en Linux
# Uso: ./run_trivy.sh <nombre-imagen>

if [ $# -eq 0 ]; then
    echo "Error: Debe especificar el nombre de la imagen"
    echo "Uso: ./run_trivy.sh <nombre-imagen>"
    exit 1
fi

IMAGE_NAME=$1
OUTPUT_DIR="trivy-reports"

echo "[*] Creando directorio de reportes..."
mkdir -p "$OUTPUT_DIR"

echo "[*] Ejecutando escaneo de Trivy..."
echo "[*] Generando reporte JSON..."

docker run --rm -v "$(pwd)":/workspace aquasec/trivy:latest image --format json --output /workspace/$OUTPUT_DIR/trivy-report.json $IMAGE_NAME

if [ -f "$OUTPUT_DIR/trivy-report.json" ]; then
    echo "[*] Reporte JSON generado exitosamente: $OUTPUT_DIR/trivy-report.json"
    echo "[*] Tamaño del archivo: $(wc -c < $OUTPUT_DIR/trivy-report.json) bytes"
else
    echo "[!] Error: No se pudo generar el reporte JSON"
    exit 1
fi

echo "[*] Ejecutando escaneo con salida detallada (HIGH,CRITICAL)..."
docker run --rm aquasec/trivy:latest image --severity HIGH,CRITICAL $IMAGE_NAME

echo "[*] Escaneo de Trivy completado"
echo "[*] Reportes disponibles en: $OUTPUT_DIR/"
