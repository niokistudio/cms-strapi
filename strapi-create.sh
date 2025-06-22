#!/bin/bash

# ==================================================================
# SCRIPT DE CREACIÓN E INICIALIZACIÓN DE STRAPI 5
# ==================================================================
# Este script automatiza la creación de un nuevo proyecto Strapi 5
# con TypeScript y configuraciones optimizadas

set -e  # Salir si algún comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Verificar dependencias
check_dependencies() {
    print_step "Verificando dependencias..."
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js no está instalado. Instala Node.js 18 o superior."
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm no está instalado."
        exit 1
    fi
    
    # Verificar versión de Node
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Se requiere Node.js 18 o superior. Versión actual: $(node --version)"
        exit 1
    fi
    
    print_message "✓ Dependencias verificadas correctamente"
}

# Función principal de creación
create_strapi_project() {
    print_step "Creando proyecto Strapi 5 con TypeScript..."
    
    # Verificar si ya existe la carpeta cms
    if [ -d "cms" ]; then
        print_warning "La carpeta 'cms' ya existe."
        read -p "¿Deseas eliminarla y crear un nuevo proyecto? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf cms
            print_message "Carpeta 'cms' eliminada"
        else
            print_message "Operación cancelada"
            exit 0
        fi
    fi
    
    # Crear el proyecto Strapi
    print_step "Ejecutando create-strapi-app..."
    npx create-strapi-app@latest cms \
        --typescript \
        --skip-cloud \
        --no-example-content \
        --quickstart=false
    
    if [ $? -ne 0 ]; then
        print_error "Error al crear el proyecto Strapi"
        exit 1
    fi
    
    print_message "✓ Proyecto Strapi creado exitosamente"
}

# Configurar plugins esenciales
setup_plugins() {
    print_step "Configurando plugins esenciales..."
    
    cd cms
    
    # Instalar plugins de internacionalización
    print_message "Instalando plugin de internacionalización..."
    npm install @strapi/plugin-i18n
    
    # Instalar plugin de documentación (Swagger)
    print_message "Instalando plugin de documentación..."
    npm install @strapi/plugin-documentation
    
    # Instalar plugins de seguridad y utilidades
    print_message "Instalando plugins de utilidades..."
    npm install @strapi/plugin-graphql
    npm install strapi-plugin-helmet
    
    cd ..
    
    print_message "✓ Plugins esenciales instalados"
}

# Configurar estructura de carpetas
setup_project_structure() {
    print_step "Configurando estructura del proyecto..."
    
    # Crear carpetas necesarias
    mkdir -p cms/src/api
    mkdir -p cms/src/components
    mkdir -p cms/src/extensions
    mkdir -p cms/src/middlewares
    mkdir -p cms/src/policies
    mkdir -p cms/config/env/development
    mkdir -p cms/config/env/production
    mkdir -p uploads
    mkdir -p backups
    mkdir -p scripts
    mkdir -p tests
    mkdir -p ci
    
    print_message "✓ Estructura de carpetas creada"
}

# Aplicar configuraciones personalizadas
apply_custom_configs() {
    print_step "Aplicando configuraciones personalizadas..."
    
    # Configurar package.json con scripts personalizados
    cd cms
    
    # Backup del package.json original
    cp package.json package.json.bak
    
    # Agregar scripts personalizados usando node
    node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        
        pkg.scripts = {
            ...pkg.scripts,
            'setup': 'npm install && npm run build',
            'dev': 'strapi develop --watch-admin',
            'start:dev': 'strapi develop',
            'build:admin': 'strapi build --clean',
            'start:prod': 'NODE_ENV=production strapi start',
            'lint': 'eslint src --ext .ts,.js --fix',
            'lint:check': 'eslint src --ext .ts,.js',
            'format': 'prettier --write src/**/*.{ts,js,json}',
            'format:check': 'prettier --check src/**/*.{ts,js,json}',
            'test': 'jest',
            'test:watch': 'jest --watch',
            'test:coverage': 'jest --coverage',
            'strapi:console': 'strapi console',
            'strapi:ts': 'strapi ts:generate-types'
        };
        
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
    "
    
    cd ..
    
    print_message "✓ Configuraciones personalizadas aplicadas"
}

# Configurar variables de entorno
setup_environment() {
    print_step "Configurando variables de entorno..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            print_message "Archivo .env creado desde .env.example"
            print_warning "Recuerda configurar las variables en el archivo .env"
        else
            print_warning "No se encontró .env.example. Crea manualmente el archivo .env"
        fi
    else
        print_message "El archivo .env ya existe"
    fi
}

# Generar claves de seguridad
generate_security_keys() {
    print_step "Generando claves de seguridad..."
    
    if command -v node &> /dev/null; then
        print_message "Generando claves de seguridad..."
        
        APP_KEY1=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        APP_KEY2=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        APP_KEY3=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        APP_KEY4=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        ADMIN_JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        API_TOKEN_SALT=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        TRANSFER_TOKEN_SALT=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
        
        print_message "Claves generadas:"
        echo "APP_KEYS=\"$APP_KEY1,$APP_KEY2,$APP_KEY3,$APP_KEY4\""
        echo "JWT_SECRET=\"$JWT_SECRET\""
        echo "ADMIN_JWT_SECRET=\"$ADMIN_JWT_SECRET\""
        echo "API_TOKEN_SALT=\"$API_TOKEN_SALT\""
        echo "TRANSFER_TOKEN_SALT=\"$TRANSFER_TOKEN_SALT\""
        
        print_warning "Copia estas claves a tu archivo .env"
    fi
}

# Función principal
main() {
    print_message "🚀 Iniciando configuración de proyecto Strapi 5"
    print_message "================================================="
    
    check_dependencies
    create_strapi_project
    setup_project_structure
    setup_plugins
    apply_custom_configs
    setup_environment
    generate_security_keys
    
    print_message ""
    print_message "🎉 ¡Proyecto Strapi 5 creado exitosamente!"
    print_message "================================================="
    print_message ""
    print_message "Próximos pasos:"
    print_message "1. Configura las variables en el archivo .env"
    print_message "2. Ejecuta: make setup"
    print_message "3. Ejecuta: make start"
    print_message "4. Visita: http://localhost:1337/admin"
    print_message ""
    print_warning "No olvides configurar las claves de seguridad en .env"
}

# Ejecutar función principal
main "$@"
