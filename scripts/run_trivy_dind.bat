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
REM Cambiar: usar solo -p sin --network host para Windows
docker run -d --name dind-scanner --privileged -p 2375:2375 docker:dind --host=tcp://0.0.0.0:2375

echo [*] Esperando que DinD esté listo...
REM Usar ping en lugar de timeout para evitar problemas de redirección
ping 127.0.0.1 -n 16 >nul

echo [*] Verificando que DinD esté funcionando...
REM Verificar múltiples veces con retry
set /a RETRY_COUNT=0
:verify_dind
set /a RETRY_COUNT+=1
echo [*] Intento %RETRY_COUNT% de verificación DinD...
echo [*] Verificando conectividad al puerto 2375...
REM Primero verificar que el puerto esté abierto
netstat -an | findstr ":2375" >nul 2>&1
if errorlevel 1 (
    echo [!] Puerto 2375 no está abierto
    if %RETRY_COUNT% LSS 3 (
        echo [*] Esperando más tiempo para que DinD se inicie...
        ping 127.0.0.1 -n 6 >nul
        goto :verify_dind
    ) else (
        echo [!] Error: Puerto 2375 no se abrió después de 3 intentos
        goto :cleanup
    )
)

echo [*] Puerto 2375 está abierto, verificando DinD...
REM Cambiar: usar localhost:2375 en lugar de --network host
docker run --rm -e DOCKER_HOST=tcp://localhost:2375 docker:latest version >nul 2>&1
if errorlevel 1 (
    if %RETRY_COUNT% LSS 3 (
        echo [*] DinD aún no está listo, esperando 5 segundos más...
        ping 127.0.0.1 -n 6 >nul
        goto :verify_dind
    ) else (
        echo [!] Error: DinD no está funcionando correctamente después de 3 intentos
        echo [!] Verificando logs del contenedor DinD:
        docker logs dind-scanner
        echo [!] Intentando método alternativo sin DinD...
        goto :alternative_scan
    )
)
echo [*] DinD está listo y funcionando

echo [*] Verificando que la imagen esté disponible en DinD...
REM Cambiar: usar localhost:2375 en lugar de --network host
docker run --rm -e DOCKER_HOST=tcp://localhost:2375 docker:latest images %IMAGE_NAME% >nul 2>&1
if errorlevel 1 (
    echo [!] La imagen %IMAGE_NAME% no está disponible en DinD
    echo [*] Copiando imagen al DinD...
    REM Cambiar: usar localhost:2375 en lugar de --network host
    docker run --rm -e DOCKER_HOST=tcp://localhost:2375 -v /var/run/docker.sock:/var/run/docker.sock docker:latest sh -c "docker save %IMAGE_NAME% | docker load"
    if errorlevel 1 (
        echo [!] Error: No se pudo copiar la imagen al DinD
        goto :cleanup
    )
    echo [*] Imagen copiada exitosamente al DinD
) else (
    echo [*] La imagen ya está disponible en DinD
)

echo [*] Ejecutando escaneo de Trivy con DinD...
echo [*] Generando reporte JSON...

REM Ejecutar Trivy con DinD
echo [*] Ejecutando: trivy image --format json --output /workspace/%OUTPUT_DIR%/trivy-report.json %IMAGE_NAME%
REM Cambiar: usar localhost:2375 en lugar de --network host
docker run --rm -v "%CD%":/workspace -e DOCKER_HOST=tcp://localhost:2375 aquasec/trivy:latest image --format json --output /workspace/%OUTPUT_DIR%/trivy-report.json %IMAGE_NAME%

if exist "%OUTPUT_DIR%\trivy-report.json" (
    echo [*] Reporte JSON generado exitosamente: %OUTPUT_DIR%\trivy-report.json
    for %%A in ("%OUTPUT_DIR%\trivy-report.json") do echo [*] Tamaño del archivo: %%~zA bytes
) else (
    echo [!] Error: No se pudo generar el reporte JSON
    echo [!] Verificando si la imagen existe...
    echo [*] Listando imágenes disponibles en DinD:
    REM Cambiar: usar localhost:2375 en lugar de --network host
    docker run --rm -e DOCKER_HOST=tcp://localhost:2375 docker:latest images
    echo [!] Imagen buscada: %IMAGE_NAME%
    goto :cleanup
)

echo [*] Ejecutando escaneo con salida detallada (HIGH,CRITICAL)...
echo [*] Ejecutando: trivy image --severity HIGH,CRITICAL %IMAGE_NAME%
REM Cambiar: usar localhost:2375 en lugar de --network host
docker run --rm -e DOCKER_HOST=tcp://localhost:2375 aquasec/trivy:latest image --severity HIGH,CRITICAL %IMAGE_NAME%
goto :cleanup

:alternative_scan
echo [*] Método alternativo: Escaneando imagen como archivo TAR...
echo [*] Guardando imagen como TAR...
docker save %IMAGE_NAME% -o "%OUTPUT_DIR%\image.tar"
if not exist "%OUTPUT_DIR%\image.tar" (
    echo [!] Error: No se pudo guardar la imagen como TAR
    goto :cleanup
)

echo [*] Escaneando archivo TAR con Trivy...
docker run --rm -v "%CD%":/workspace aquasec/trivy:latest image --format json --output /workspace/%OUTPUT_DIR%/trivy-report.json --input /workspace/%OUTPUT_DIR%/image.tar

if exist "%OUTPUT_DIR%\trivy-report.json" (
    echo [*] Reporte JSON generado exitosamente: %OUTPUT_DIR%\trivy-report.json
    for %%A in ("%OUTPUT_DIR%\trivy-report.json") do echo [*] Tamaño del archivo: %%~zA bytes
) else (
    echo [!] Error: No se pudo generar el reporte JSON con método alternativo
    goto :cleanup
)

echo [*] Ejecutando escaneo con salida detallada (HIGH,CRITICAL)...
docker run --rm -v "%CD%":/workspace aquasec/trivy:latest image --severity HIGH,CRITICAL --input /workspace/%OUTPUT_DIR%/image.tar

echo [*] Limpiando archivo TAR temporal...
del "%OUTPUT_DIR%\image.tar" 2>nul

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
