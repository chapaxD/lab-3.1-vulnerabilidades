#!/bin/bash
# Script de prueba para simular fallo en Trivy
# Uso: ./scan_trivy_fail.sh <nombre-imagen>

if [ $# -eq 0 ]; then
    echo "Error: Debe especificar el nombre de la imagen"
    echo "Uso: ./scan_trivy_fail.sh <nombre-imagen>"
    exit 1
fi

IMAGE_NAME=$1
OUTPUT_DIR="trivy-reports"

echo "[*] Simulando fallo en escaneo de Trivy..."
echo "[!] Error simulado: No se puede encontrar la imagen $IMAGE_NAME"
echo "[!] Error simulado: No se puede conectar al daemon de Docker"
echo "[!] Este script simula un fallo para pruebas de pipeline"

# Crear directorio de reportes si no existe
mkdir -p "$OUTPUT_DIR"

# Simular archivo de reporte vacío o con error
echo '{"error": "Simulated failure for testing purposes"}' > "$OUTPUT_DIR/trivy-report.json"

echo "[*] Script de prueba completado - Simulando fallo"
exit 1
