@echo off
REM Script para ejecutar Trivy en Windows
REM Uso: run_trivy_windows.bat <nombre-imagen>

if "%1"=="" (
    echo Error: Debe especificar el nombre de la imagen
    echo Uso: run_trivy_windows.bat ^<nombre-imagen^>
    exit /b 1
)

set IMAGE_NAME=%1
set OUTPUT_DIR=trivy-reports

echo [*] Creando directorio de reportes...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo [*] Ejecutando escaneo de Trivy...
echo [*] Generando reporte JSON...

docker run --rm -v "%CD%":/workspace aquasec/trivy:latest image --format json --output /workspace/%OUTPUT_DIR%/trivy-report.json %IMAGE_NAME%

if exist "%OUTPUT_DIR%\trivy-report.json" (
    echo [*] Reporte JSON generado exitosamente: %OUTPUT_DIR%\trivy-report.json
    for %%A in ("%OUTPUT_DIR%\trivy-report.json") do echo [*] Tamaño del archivo: %%~zA bytes
) else (
    echo [!] Error: No se pudo generar el reporte JSON
    exit /b 1
)

echo [*] Ejecutando escaneo con salida detallada (HIGH,CRITICAL)...
docker run --rm aquasec/trivy:latest image --severity HIGH,CRITICAL %IMAGE_NAME%

echo [*] Escaneo de Trivy completado
echo [*] Reportes disponibles en: %OUTPUT_DIR%\
