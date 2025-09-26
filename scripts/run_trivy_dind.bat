@echo off
setlocal enabledelayedexpansion

REM Script para ejecutar Trivy con Docker-in-Docker
REM Uso: run_trivy_dind.bat <nombre-imagen>

if "%1"=="" (
    echo Error: Debe especificar el nombre de la imagen
    echo Uso: run_trivy_dind.bat ^<nombre-imagen^>
    exit /b 1
)

set IMAGE_NAME=%1
set OUTPUT_DIR=trivy-reports

echo [*] Creando directorio de reportes...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo [*] Limpiando contenedores DinD anteriores...
docker stop dind-scanner 2>nul
docker rm dind-scanner 2>nul

echo [*] Iniciando Docker-in-Docker...
docker run -d --name dind-scanner --privileged --network host docker:dind

echo [*] Esperando que DinD esté listo...
timeout /t 15 /nobreak >nul

echo [*] Verificando que DinD esté funcionando...
docker run --rm --network host -e DOCKER_HOST=tcp://localhost:2375 docker:latest version >nul 2>&1
if errorlevel 1 (
    echo [!] Error: DinD no está funcionando correctamente
    goto :cleanup
)
echo [*] DinD está listo y funcionando

echo [*] Ejecutando escaneo de Trivy con DinD...
echo [*] Generando reporte JSON...

REM Ejecutar Trivy con DinD
echo [*] Ejecutando: trivy image --format json --output /workspace/%OUTPUT_DIR%/trivy-report.json %IMAGE_NAME%
docker run --rm --network host -v "%CD%":/workspace -e DOCKER_HOST=tcp://localhost:2375 aquasec/trivy:latest image --format json --output /workspace/%OUTPUT_DIR%/trivy-report.json %IMAGE_NAME%

if exist "%OUTPUT_DIR%\trivy-report.json" (
    echo [*] Reporte JSON generado exitosamente: %OUTPUT_DIR%\trivy-report.json
    for %%A in ("%OUTPUT_DIR%\trivy-report.json") do echo [*] Tamaño del archivo: %%~zA bytes
) else (
    echo [!] Error: No se pudo generar el reporte JSON
    echo [!] Verificando si la imagen existe...
    docker run --rm --network host -e DOCKER_HOST=tcp://localhost:2375 docker:latest images %IMAGE_NAME%
    goto :cleanup
)

echo [*] Ejecutando escaneo con salida detallada (HIGH,CRITICAL)...
echo [*] Ejecutando: trivy image --severity HIGH,CRITICAL %IMAGE_NAME%
docker run --rm --network host -e DOCKER_HOST=tcp://localhost:2375 aquasec/trivy:latest image --severity HIGH,CRITICAL %IMAGE_NAME%

:cleanup
echo [*] Limpiando contenedor DinD...
docker stop dind-scanner 2>nul
docker rm dind-scanner 2>nul

echo [*] Escaneo de Trivy con DinD completado
echo [*] Reportes disponibles en: %OUTPUT_DIR%\

REM Verificar que el reporte se generó correctamente
if exist "%OUTPUT_DIR%\trivy-report.json" (
    echo [*] SUCCESS: Reporte de Trivy generado exitosamente
    exit /b 0
) else (
    echo [!] ERROR: No se pudo generar el reporte de Trivy
    exit /b 1
)
