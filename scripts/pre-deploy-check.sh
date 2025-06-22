#!/bin/bash

# ==================================================================
# SCRIPT DE VALIDACIÓN PREVIA AL DESPLIEGUE
# ==================================================================

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
ERRORS=0
WARNINGS=0

# Función para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((ERRORS++))
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Verificar variables de entorno requeridas
check_environment_variables() {
    log_step "Verificando variables de entorno..."
    
    local required_vars=(
        "NODE_ENV"
        "DATABASE_HOST"
        "DATABASE_PORT"
        "DATABASE_NAME"
        "DATABASE_USERNAME" 
        "DATABASE_PASSWORD"
        "APP_KEYS"
        "JWT_SECRET"
        "ADMIN_JWT_SECRET"
        "API_TOKEN_SALT"
        "TRANSFER_TOKEN_SALT"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Variable de entorno requerida faltante: $var"
        else
            log_info "✓ $var está configurada"
        fi
    done
    
    # Verificaciones específicas para producción
    if [ "$NODE_ENV" = "production" ]; then
        if [ "$DATABASE_SSL" != "true" ]; then
            log_warning "Se recomienda SSL para base de datos en producción"
        fi
        
        if [ "$UPLOAD_PROVIDER" = "local" ]; then
            log_warning "Se recomienda usar almacenamiento externo (S3) en producción"
        fi
    fi
}

# Verificar conectividad de base de datos
check_database_connectivity() {
    log_step "Verificando conectividad de base de datos..."
    
    if command -v pg_isready &> /dev/null; then
        if pg_isready -h "$DATABASE_HOST" -p "$DATABASE_PORT" -U "$DATABASE_USERNAME" >/dev/null 2>&1; then
            log_info "✓ Base de datos accesible"
        else
            log_error "✗ No se puede conectar a la base de datos"
        fi
    else
        log_warning "pg_isready no disponible, saltando verificación de conectividad"
    fi
}

# Verificar dependencias
check_dependencies() {
    log_step "Verificando dependencias..."
    
    # Verificar Node.js
    if command -v node &> /dev/null; then
        local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -ge 18 ]; then
            log_info "✓ Node.js versión válida: $(node --version)"
        else
            log_error "✗ Node.js versión inválida. Se requiere >= 18, encontrada: $(node --version)"
        fi
    else
        log_error "✗ Node.js no está instalado"
    fi
    
    # Verificar npm
    if command -v npm &> /dev/null; then
        log_info "✓ npm disponible: $(npm --version)"
    else
        log_error "✗ npm no está disponible"
    fi
    
    # Verificar package.json
    if [ -f "package.json" ]; then
        log_info "✓ package.json encontrado"
    else
        log_error "✗ package.json no encontrado"
    fi
}

# Verificar configuración de Strapi
check_strapi_config() {
    log_step "Verificando configuración de Strapi..."
    
    if [ -d "cms" ]; then
        log_info "✓ Directorio cms encontrado"
        
        if [ -f "cms/package.json" ]; then
            log_info "✓ package.json de Strapi encontrado"
            
            # Verificar versión de Strapi
            local strapi_version=$(grep '"@strapi/strapi"' cms/package.json | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
            if [ -n "$strapi_version" ]; then
                log_info "✓ Strapi versión: $strapi_version"
                
                # Verificar que sea Strapi 5+
                local major_version=$(echo "$strapi_version" | cut -d'.' -f1)
                if [ "$major_version" -ge 5 ]; then
                    log_info "✓ Versión de Strapi compatible (5+)"
                else
                    log_error "✗ Versión de Strapi no compatible. Se requiere 5+"
                fi
            else
                log_error "✗ No se pudo determinar la versión de Strapi"
            fi
        else
            log_error "✗ package.json de Strapi no encontrado"
        fi
        
        # Verificar archivos de configuración
        local config_files=(
            "cms/config/database.ts"
            "cms/config/server.ts"
            "cms/config/admin.ts"
        )
        
        for config_file in "${config_files[@]}"; do
            if [ -f "$config_file" ]; then
                log_info "✓ $config_file encontrado"
            else
                log_warning "$config_file no encontrado"
            fi
        done
    else
        log_error "✗ Directorio cms no encontrado"
    fi
}

# Verificar Docker
check_docker() {
    log_step "Verificando Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "✓ Docker disponible: $(docker --version)"
        
        # Verificar que Docker esté corriendo
        if docker info >/dev/null 2>&1; then
            log_info "✓ Docker daemon está corriendo"
        else
            log_error "✗ Docker daemon no está corriendo"
        fi
        
        # Verificar Dockerfile
        if [ -f "Dockerfile" ]; then
            log_info "✓ Dockerfile encontrado"
        else
            log_error "✗ Dockerfile no encontrado"
        fi
        
        # Verificar docker-compose.yml
        if [ -f "docker-compose.yml" ]; then
            log_info "✓ docker-compose.yml encontrado"
            
            # Validar sintaxis
            if docker-compose config >/dev/null 2>&1; then
                log_info "✓ docker-compose.yml válido"
            else
                log_error "✗ docker-compose.yml tiene errores de sintaxis"
            fi
        else
            log_error "✗ docker-compose.yml no encontrado"
        fi
    else
        log_error "✗ Docker no está instalado"
    fi
}

# Verificar tests
check_tests() {
    log_step "Verificando tests..."
    
    if [ -d "tests" ]; then
        log_info "✓ Directorio de tests encontrado"
        
        local test_files=$(find tests -name "*.test.*" -o -name "*.spec.*" | wc -l)
        if [ "$test_files" -gt 0 ]; then
            log_info "✓ $test_files archivos de test encontrados"
        else
            log_warning "No se encontraron archivos de test"
        fi
    else
        log_warning "Directorio de tests no encontrado"
    fi
    
    # Verificar configuración de Jest
    if [ -f "jest.config.ts" ] || [ -f "jest.config.js" ]; then
        log_info "✓ Configuración de Jest encontrada"
    else
        log_warning "Configuración de Jest no encontrada"
    fi
}

# Verificar seguridad
check_security() {
    log_step "Verificando configuración de seguridad..."
    
    # Verificar que las claves no sean valores por defecto
    local security_vars=("APP_KEYS" "JWT_SECRET" "ADMIN_JWT_SECRET")
    
    for var in "${security_vars[@]}"; do
        local value="${!var}"
        if [ -n "$value" ]; then
            if [[ "$value" == *"TODO"* ]] || [[ "$value" == *"test"* ]] || [[ "$value" == *"default"* ]]; then
                log_error "✗ $var parece contener un valor por defecto o de prueba"
            else
                log_info "✓ $var configurada con valor personalizado"
            fi
        fi
    done
    
    # Verificar archivo .env
    if [ -f ".env" ]; then
        if grep -q "TODO" .env; then
            log_error "✗ Archivo .env contiene valores TODO"
        else
            log_info "✓ Archivo .env no contiene valores TODO"
        fi
    else
        log_error "✗ Archivo .env no encontrado"
    fi
    
    # Verificar .gitignore
    if [ -f ".gitignore" ]; then
        if grep -q ".env" .gitignore; then
            log_info "✓ .env está en .gitignore"
        else
            log_warning ".env no está en .gitignore"
        fi
    else
        log_warning ".gitignore no encontrado"
    fi
}

# Verificar configuración de CI/CD
check_cicd() {
    log_step "Verificando configuración de CI/CD..."
    
    # Verificar GitHub Actions
    if [ -f ".github/workflows/ci.yml" ] || [ -f "ci/ci.yml" ]; then
        log_info "✓ Configuración de GitHub Actions encontrada"
    else
        log_warning "Configuración de GitHub Actions no encontrada"
    fi
    
    # Verificar GitLab CI
    if [ -f ".gitlab-ci.yml" ]; then
        log_info "✓ Configuración de GitLab CI encontrada"
    else
        log_warning "Configuración de GitLab CI no encontrada"
    fi
}

# Verificar performance y recursos
check_performance() {
    log_step "Verificando configuración de performance..."
    
    # Verificar configuración de pool de base de datos
    if [ -f "cms/config/database.ts" ]; then
        if grep -q "pool" cms/config/database.ts; then
            log_info "✓ Configuración de pool de BD encontrada"
        else
            log_warning "Configuración de pool de BD no encontrada"
        fi
    fi
    
    # Verificar límites de memoria en Docker
    if [ -f "docker-compose.yml" ]; then
        if grep -q "mem_limit" docker-compose.yml; then
            log_info "✓ Límites de memoria configurados"
        else
            log_warning "Límites de memoria no configurados"
        fi
    fi
}

# Resumen final
print_summary() {
    echo ""
    echo "========================================"
    echo "RESUMEN DE VALIDACIÓN PRE-DEPLOY"
    echo "========================================"
    echo ""
    
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        log_info "✅ Todas las verificaciones pasaron exitosamente"
        echo -e "${GREEN}🚀 El proyecto está listo para ser desplegado${NC}"
        return 0
    elif [ $ERRORS -eq 0 ]; then
        log_warning "⚠️  Se encontraron $WARNINGS advertencias"
        echo -e "${YELLOW}📋 Revisa las advertencias antes de desplegar${NC}"
        return 0
    else
        log_error "❌ Se encontraron $ERRORS errores y $WARNINGS advertencias"
        echo -e "${RED}🛑 CORRIGE LOS ERRORES ANTES DE DESPLEGAR${NC}"
        return 1
    fi
}

# Función principal
main() {
    echo -e "${BLUE}🔍 VALIDACIÓN PRE-DEPLOY - CMS STRAPI${NC}"
    echo "========================================"
    echo ""
    
    # Cargar variables de entorno si existe .env
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        log_info "Variables de entorno cargadas desde .env"
    fi
    
    # Ejecutar verificaciones
    check_environment_variables
    check_dependencies
    check_strapi_config
    check_docker
    check_database_connectivity
    check_tests
    check_security
    check_cicd
    check_performance
    
    # Mostrar resumen
    print_summary
}

# Verificar argumentos
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Script de validación pre-deploy para CMS Strapi"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help    Mostrar esta ayuda"
    echo "  --fix         Intentar corregir problemas automáticamente"
    echo ""
    exit 0
fi

# Ejecutar validaciones
main "$@"
