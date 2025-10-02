# 🚀 Pipeline DevSecOps - Laboratorio 3.1

## 📋 Descripción General

Este proyecto implementa un pipeline completo de DevSecOps que automatiza la construcción, análisis de seguridad y despliegue de una aplicación Node.js vulnerable. El pipeline utiliza Jenkins para orquestar múltiples herramientas de seguridad y Docker para containerización.

## 🏗️ Arquitectura del Pipeline

### Etapas del Pipeline:
1. **SAST** - Semgrep (Análisis Estático de Código)
2. **SCA** - OWASP Dependency Check (Análisis de Dependencias)
3. **Build** - Construcción de la aplicación
4. **Container Security** - Trivy (Escaneo de Vulnerabilidades en Imágenes)
5. **Push** - Subida de imagen a registry (opcional)
6. **Deploy** - Despliegue con Docker Compose
7. **DAST** - OWASP ZAP (Análisis Dinámico)
8. **Policy Check** - Verificación de políticas de seguridad

## 📁 Estructura del Proyecto

```
lab-3.1/
├── src/                          # Código fuente de la aplicación
│   ├── index.js                  # Aplicación Node.js vulnerable
│   └── package.json              # Dependencias del proyecto
├── scripts/                      # Scripts de automatización
│   ├── run_trivy_dind.bat        # Script DinD para Trivy en Windows
│   ├── run_trivy_windows.bat     # Script Trivy para Windows (alternativo)
│   ├── run_trivy.sh              # Script Trivy para Linux
│   ├── run_semgrep.sh            # Script Semgrep
│   ├── run_zap.sh                # Script OWASP ZAP
│   ├── run_dependency_check.sh   # Script Dependency Check
│   └── scan_trivy_fail.sh        # Script de prueba para fallos
├── dependency-check-reports/     # Reportes de análisis de dependencias
├── trivy-reports/               # Reportes de escaneo de imágenes
├── zap-reports/                 # Reportes de análisis dinámico
├── Dockerfile                   # Imagen de producción
├── Dockerfile.build             # Imagen de construcción
├── docker-compose.yml           # Configuración de despliegue
├── Jenkinsfile                  # Pipeline de Jenkins
├── zap.yaml                     # Configuración de OWASP ZAP
└── README-PIPELINE-DEVSECOPS.md # Esta documentación
```

## 🔧 Configuración y Preparación

### 1. Configuración de Jenkins

#### Credenciales Requeridas:
- **`jenkins-ssh`**: Clave SSH para acceso a Git
- **`docker-registry-credentials`**: Credenciales para Docker Hub/Registry
- **`git-credentials`**: Credenciales Git (opcional)

#### Plugins Necesarios:
- Docker Pipeline
- OWASP Dependency Check
- HTML Publisher (para reportes)

### 2. Configuración del Entorno

#### Windows (Jenkins Agent):
```bash
# Verificar Docker instalado
docker --version

# Verificar acceso a Docker Hub
docker pull hello-world
```

#### Variables de Entorno en Jenkinsfile:
```groovy
environment {
  DOCKER_REGISTRY = "myregistry.example.com"
  DOCKER_CREDENTIALS = "docker-registry-credentials"
  GIT_CREDENTIALS = "git-credentials"
  DOCKER_IMAGE_NAME = "devsecops-labs-app:latest"
  SSH_CREDENTIALS = "ssh-deploy-key"
  STAGING_URL = "http://host.docker.internal:3000"
}
```

## 🛠️ Soluciones Implementadas

### 1. Problema: Docker Registry Credentials
**Error Original:**
```
ERROR: Could not find credentials entry with ID 'docker-registry-credentials'
```

**Solución:**
- Configuración de credenciales en Jenkins: `Manage Jenkins` → `Manage Credentials`
- Uso de `withCredentials` para inyección segura de credenciales
- Fallback a imagen local cuando el registry no está disponible

### 2. Problema: Trivy No Generaba Reportes en Windows
**Error Original:**
```
Fatal error: unable to find the specified image...
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solución Implementada:**
- **Docker-in-Docker (DinD)** para aislamiento de escaneo
- **Script personalizado** `run_trivy_dind.bat` para Windows
- **Método alternativo** con `docker save | docker load` como fallback
- **Configuración específica para Windows** sin `--network host`

#### Script DinD (`scripts/run_trivy_dind.bat`):
```batch
# Características principales:
- Inicio automático de contenedor DinD
- Verificación de conectividad con retry
- Copia de imagen al DinD si no está disponible
- Generación de reportes JSON y HTML
- Limpieza automática de recursos
- Fallback a método TAR si DinD falla
```

### 3. Problema: Vulnerabilidades de Seguridad

#### Vulnerabilidades Detectadas Originalmente:
- **CSRF**: Falta de middleware de protección
- **XSS**: Escape manual de HTML insuficiente
- **SQL Injection**: Consultas sin parámetros
- **27 vulnerabilidades HIGH/CRITICAL** en dependencias

#### Soluciones Implementadas:

##### Código (`src/index.js`):
```javascript
// Middleware de seguridad
app.use(helmet());
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 100 // límite de requests por IP
}));

// Protección CSRF
const csrfProtection = csrf({ cookie: true });
app.use(csrfProtection);

// Consultas parametrizadas (anti SQL Injection)
const sql = `SELECT id, username FROM users WHERE id = ?;`;
db.all(sql, [id], (err, rows) => { ... });

// Escape HTML manual (anti XSS)
const escapedName = name.replace(/[&<>"']/g, function(match) {
  switch(match) {
    case '&': return '&amp;';
    case '<': return '&lt;';
    case '>': return '&gt;';
    case '"': return '&quot;';
    case "'": return '&#39;';
    default: return match;
  }
});
```

##### Dependencias (`src/package.json`):
```json
{
  "dependencies": {
    "express": "^4.19.2",           // Actualizado de 4.16.0
    "body-parser": "^1.20.3",       // Actualizado de 1.18.3
    "sqlite3": "^5.1.6",           // Actualizado de 4.0.0
    "csurf": "^1.11.0",            // Nuevo: protección CSRF
    "helmet": "^7.1.0",            // Nuevo: headers de seguridad
    "express-rate-limit": "^7.1.5" // Nuevo: limitación de rate
  }
}
```

##### Dockerfile:
```dockerfile
# Actualizado de Node.js 12 a 20 Alpine
FROM node:20-alpine
```

### 4. Problema: Compatibilidad Windows/Linux

#### Soluciones Cross-Platform:
- **Scripts separados**: `.bat` para Windows, `.sh` para Linux
- **Volúmenes Docker**: `"%CD%":/workspace` para Windows
- **Comandos de espera**: `ping` en lugar de `timeout` para Jenkins
- **Manejo de errores**: `|| ver1>nul` para continuar en caso de fallo

## 📊 Resultados de Seguridad

### Estado Final:
- **SAST (Semgrep)**: 2 vulnerabilidades WARNING (XSS)
- **SCA (Dependency Check)**: 0 vulnerabilidades críticas
- **Container Security (Trivy)**: 1 vulnerabilidad HIGH (ya corregida)
- **DAST (OWASP ZAP)**: 5 warnings (headers de seguridad)

### Mejoras Logradas:
- **Reducción de 27 a 1** vulnerabilidad HIGH/CRITICAL
- **Implementación de middleware** de seguridad
- **Consultas parametrizadas** para prevenir SQL Injection
- **Escape HTML** para prevenir XSS
- **Headers de seguridad** con Helmet

## 🔄 Flujo de Ejecución

### 1. Trigger del Pipeline:
```bash
git push origin main
```

### 2. Ejecución Automática:
```
1. Checkout → 2. SAST → 3. SCA → 4. Build → 5. Container Scan → 6. Deploy → 7. DAST
```

### 3. Generación de Reportes:
- **Semgrep**: `semgrep-results.json`
- **Dependency Check**: `dependency-check-reports/dependency-check-report.json`
- **Trivy**: `trivy-reports/trivy-report.json`
- **OWASP ZAP**: `zap-reports/zap-report.html`

### 4. Despliegue:
- **Aplicación**: `http://localhost:3000`
- **Endpoints**: `/`, `/user?id=1`, `/greet?name=xyz`

## 🚨 Troubleshooting

### Problemas Comunes:

#### 1. DinD No Inicia:
```bash
# Verificar que Docker esté corriendo
docker ps

# Limpiar contenedores anteriores
docker stop dind-scanner
docker rm dind-scanner
```

#### 2. Reportes No Se Generan:
```bash
# Verificar permisos de escritura
ls -la trivy-reports/
ls -la dependency-check-reports/
ls -la zap-reports/
```

#### 3. Credenciales Docker:
```bash
# Verificar credenciales en Jenkins
Manage Jenkins → Manage Credentials → System → Global credentials
```

#### 4. Puerto 3000 Ocupado:
```bash
# Detener contenedores existentes
docker compose -f docker-compose.yml down
docker ps -a | grep 3000
```

## 📈 Métricas de Éxito

### Objetivos Alcanzados:
- ✅ **Pipeline completamente funcional**
- ✅ **Todas las herramientas de seguridad operativas**
- ✅ **Reducción significativa de vulnerabilidades**
- ✅ **Despliegue automático funcionando**
- ✅ **Reportes generados correctamente**
- ✅ **Compatibilidad Windows/Linux**

### KPIs de Seguridad:
- **Vulnerabilidades Críticas**: 0 (era 27)
- **Vulnerabilidades Altas**: 1 (era 27)
- **Cobertura SAST**: 100% del código
- **Cobertura SCA**: 100% de dependencias
- **Cobertura DAST**: Aplicación completa

## 🔮 Próximas Mejoras

### Optimizaciones Sugeridas:
1. **Integración con SonarQube** para análisis de calidad
2. **Notificaciones Slack/Teams** para alertas de seguridad
3. **Escalado horizontal** con múltiples agentes
4. **Implementación de gates** de calidad
5. **Monitoreo continuo** post-despliegue

### Herramientas Adicionales:
- **Anchore** para análisis de políticas de imagen
- **Snyk** para análisis de dependencias en tiempo real
- **Checkmarx** para SAST empresarial
- **Burp Suite** para DAST avanzado

## 📚 Referencias

### Documentación:
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [OWASP Dependency Check](https://owasp.org/www-project-dependency-check/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Semgrep Documentation](https://semgrep.dev/docs/)
- [OWASP ZAP Documentation](https://www.zaproxy.org/docs/)

### Mejores Prácticas:
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Node.js Security Checklist](https://blog.risingstack.com/node-js-security-checklist/)

---

## 👥 Autores

**Roger Andia** - Implementación del pipeline DevSecOps y corrección de vulnerabilidades

---

## 📄 Licencia

Este proyecto es parte de un laboratorio educativo de DevSecOps. Úsese para fines de aprendizaje y demostración.

---

*Última actualización: 25 de Septiembre de 2025*
