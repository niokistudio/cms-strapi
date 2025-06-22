# ==================================================================
# MAKEFILE PARA CMS STRAPI 5
# ==================================================================
# Comandos simplificados para gestión del proyecto

# Variables
DOCKER_COMPOSE = docker-compose
STRAPI_CONTAINER = cms-strapi-app
DB_CONTAINER = cms-strapi-db
BACKUP_DIR = ./backups

# Colores para output
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help setup start stop restart logs shell shell-db migrate seed backup-db restore-db clean install test lint format

# Comando por defecto
help:
	@echo "$(GREEN)CMS Strapi 5 - Comandos Disponibles$(NC)"
	@echo "=================================="
	@echo ""
	@echo "$(YELLOW)Configuración:$(NC)"
	@echo "  setup         - Configuración inicial completa"
	@echo "  install       - Instalar dependencias"
	@echo ""
	@echo "$(YELLOW)Desarrollo:$(NC)"
	@echo "  start         - Iniciar todos los servicios"
	@echo "  stop          - Detener todos los servicios"
	@echo "  restart       - Reiniciar todos los servicios"
	@echo "  logs          - Mostrar logs de todos los servicios"
	@echo "  logs-strapi   - Mostrar logs solo de Strapi"
	@echo "  logs-db       - Mostrar logs solo de la base de datos"
	@echo ""
	@echo "$(YELLOW)Acceso a contenedores:$(NC)"
	@echo "  shell         - Acceder al contenedor de Strapi"
	@echo "  shell-db      - Acceder al contenedor de PostgreSQL"
	@echo ""
	@echo "$(YELLOW)Base de datos:$(NC)"
	@echo "  migrate       - Ejecutar migraciones"
	@echo "  seed          - Cargar datos de prueba"
	@echo "  backup-db     - Crear backup de la base de datos"
	@echo "  restore-db    - Restaurar backup (usar BACKUP_FILE=archivo.sql)"
	@echo ""
	@echo "$(YELLOW)Desarrollo y calidad:$(NC)"
	@echo "  test          - Ejecutar tests"
	@echo "  test-watch    - Ejecutar tests en modo watch"
	@echo "  test-coverage - Ejecutar tests con coverage"
	@echo "  lint          - Análisis de código"
	@echo "  lint-fix      - Corregir problemas de linting"
	@echo "  format        - Formatear código"
	@echo ""
	@echo "$(YELLOW)Utilidades:$(NC)"
	@echo "  clean         - Limpiar contenedores e imágenes"
	@echo "  reset         - Reset completo del proyecto"
	@echo "  status        - Mostrar estado de los servicios"
	@echo ""

# ==================================================================
# CONFIGURACIÓN INICIAL
# ==================================================================

setup: check-env create-strapi install start-db wait-db
	@echo "$(GREEN)✓ Configuración inicial completada$(NC)"
	@echo "$(YELLOW)Próximos pasos:$(NC)"
	@echo "  1. Ejecuta: make start"
	@echo "  2. Visita: http://localhost:1337/admin"

check-env:
	@echo "$(YELLOW)Verificando configuración...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creando archivo .env desde .env.example$(NC)"; \
		cp .env.example .env; \
		echo "$(RED)⚠️  Configura las variables en el archivo .env$(NC)"; \
	fi

create-strapi:
	@if [ ! -d "cms" ]; then \
		echo "$(YELLOW)Creando proyecto Strapi...$(NC)"; \
		chmod +x ./strapi-create.sh; \
		./strapi-create.sh; \
	else \
		echo "$(GREEN)✓ Proyecto Strapi ya existe$(NC)"; \
	fi

install:
	@echo "$(YELLOW)Instalando dependencias...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm install; \
	fi

# ==================================================================
# GESTIÓN DE SERVICIOS
# ==================================================================

start:
	@echo "$(YELLOW)Iniciando servicios...$(NC)"
	$(DOCKER_COMPOSE) up
	@echo "$(GREEN)✓ Servicios iniciados$(NC)"
	@echo "$(YELLOW)URLs disponibles:$(NC)"
	@echo "  - Strapi Admin: http://localhost:1337/admin"
	@echo "  - Strapi API: http://localhost:1337/api"
	@echo "  - Adminer: http://localhost:8080"

start-db:
	@echo "$(YELLOW)Iniciando base de datos...$(NC)"
	$(DOCKER_COMPOSE) up -d postgres
	@echo "$(GREEN)✓ Base de datos iniciada$(NC)"

stop:
	@echo "$(YELLOW)Deteniendo servicios...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Servicios detenidos$(NC)"

restart:
	@echo "$(YELLOW)Reiniciando servicios...$(NC)"
	$(DOCKER_COMPOSE) restart
	@echo "$(GREEN)✓ Servicios reiniciados$(NC)"

status:
	@echo "$(YELLOW)Estado de los servicios:$(NC)"
	$(DOCKER_COMPOSE) ps

# ==================================================================
# LOGS Y DEBUGGING
# ==================================================================

logs:
	$(DOCKER_COMPOSE) logs -f

logs-strapi:
	$(DOCKER_COMPOSE) logs -f $(STRAPI_CONTAINER)

logs-db:
	$(DOCKER_COMPOSE) logs -f $(DB_CONTAINER)

shell:
	@echo "$(YELLOW)Accediendo al contenedor de Strapi...$(NC)"
	$(DOCKER_COMPOSE) exec $(STRAPI_CONTAINER) /bin/bash

shell-db:
	@echo "$(YELLOW)Accediendo al contenedor de PostgreSQL...$(NC)"
	$(DOCKER_COMPOSE) exec $(DB_CONTAINER) psql -U strapi_user -d cms_strapi_db

# ==================================================================
# BASE DE DATOS
# ==================================================================

wait-db:
	@echo "$(YELLOW)Esperando que la base de datos esté lista...$(NC)"
	@for i in $$(seq 1 15); do \
		if docker exec cms-strapi-db pg_isready -h localhost -p 5432 >/dev/null 2>&1; then \
			echo "$(GREEN)✓ Base de datos lista$(NC)"; \
			exit 0; \
		fi; \
		echo "Esperando PostgreSQL... ($$i/15)"; \
		sleep 2; \
	done; \
	echo "$(RED)Error: Timeout esperando PostgreSQL$(NC)"; \
	exit 1

migrate:
	@echo "$(YELLOW)Ejecutando migraciones...$(NC)"
	$(DOCKER_COMPOSE) exec $(STRAPI_CONTAINER) npm run strapi:ts
	@echo "$(GREEN)✓ Migraciones completadas$(NC)"

seed:
	@echo "$(YELLOW)Cargando datos de prueba...$(NC)"
	@if [ -f "scripts/seed.js" ]; then \
		$(DOCKER_COMPOSE) exec $(STRAPI_CONTAINER) node scripts/seed.js; \
	else \
		echo "$(RED)No se encontró el archivo scripts/seed.js$(NC)"; \
	fi

backup-db:
	@echo "$(YELLOW)Creando backup de la base de datos...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	@BACKUP_FILE=$(BACKUP_DIR)/backup_$$(date +%Y%m%d_%H%M%S).sql; \
	$(DOCKER_COMPOSE) exec $(DB_CONTAINER) pg_dump -U strapi_user -d cms_strapi_db > $$BACKUP_FILE; \
	echo "$(GREEN)✓ Backup creado: $$BACKUP_FILE$(NC)"

restore-db:
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Error: Especifica el archivo de backup con BACKUP_FILE=archivo.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restaurando backup: $(BACKUP_FILE)$(NC)"
	@$(DOCKER_COMPOSE) exec -T $(DB_CONTAINER) psql -U strapi_user -d cms_strapi_db < $(BACKUP_FILE)
	@echo "$(GREEN)✓ Backup restaurado$(NC)"

# ==================================================================
# DESARROLLO Y CALIDAD
# ==================================================================

test:
	@echo "$(YELLOW)Ejecutando tests...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm test; \
	else \
		echo "$(RED)Error: Directorio cms no existe$(NC)"; \
	fi

test-watch:
	@echo "$(YELLOW)Ejecutando tests en modo watch...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm run test:watch; \
	else \
		echo "$(RED)Error: Directorio cms no existe$(NC)"; \
	fi

test-coverage:
	@echo "$(YELLOW)Ejecutando tests con coverage...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm run test:coverage; \
	else \
		echo "$(RED)Error: Directorio cms no existe$(NC)"; \
	fi

lint:
	@echo "$(YELLOW)Ejecutando análisis de código...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm run lint:check; \
	else \
		echo "$(RED)Error: Directorio cms no existe$(NC)"; \
	fi

lint-fix:
	@echo "$(YELLOW)Corrigiendo problemas de linting...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm run lint; \
	else \
		echo "$(RED)Error: Directorio cms no existe$(NC)"; \
	fi

format:
	@echo "$(YELLOW)Formateando código...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm run format; \
	else \
		echo "$(RED)Error: Directorio cms no existe$(NC)"; \
	fi

format-check:
	@echo "$(YELLOW)Verificando formato de código...$(NC)"
	@if [ -d "cms" ]; then \
		cd cms && npm run format:check; \
	else \
		echo "$(RED)Error: Directorio cms no existe$(NC)"; \
	fi

# ==================================================================
# UTILIDADES
# ==================================================================

clean:
	@echo "$(YELLOW)Limpiando contenedores e imágenes...$(NC)"
	$(DOCKER_COMPOSE) down -v --rmi all --remove-orphans
	@echo "$(GREEN)✓ Limpieza completada$(NC)"

reset: clean
	@echo "$(RED)⚠️  Realizando reset completo del proyecto...$(NC)"
	@read -p "¿Estás seguro? Esto eliminará todos los datos (y/N): " confirm && [ "$$confirm" = "y" ]
	rm -rf cms/node_modules
	rm -rf uploads/*
	rm -rf backups/*
	docker system prune -f
	@echo "$(GREEN)✓ Reset completado$(NC)"

# ==================================================================
# COMANDOS DE STRAPI
# ==================================================================

strapi-console:
	@echo "$(YELLOW)Abriendo consola de Strapi...$(NC)"
	$(DOCKER_COMPOSE) exec $(STRAPI_CONTAINER) npm run strapi:console

strapi-build:
	@echo "$(YELLOW)Construyendo admin panel...$(NC)"
	$(DOCKER_COMPOSE) exec $(STRAPI_CONTAINER) npm run build:admin

strapi-develop:
	@echo "$(YELLOW)Iniciando Strapi en modo desarrollo...$(NC)"
	$(DOCKER_COMPOSE) exec $(STRAPI_CONTAINER) npm run dev

# ==================================================================
# COMANDOS ESPECÍFICOS DE ENTORNO
# ==================================================================

dev: start logs-strapi

prod-build:
	@echo "$(YELLOW)Construyendo imagen de producción...$(NC)"
	docker build --target production -t cms-strapi:latest .
	@echo "$(GREEN)✓ Imagen de producción construida$(NC)"

# ==================================================================
# VALIDACIONES
# ==================================================================

health-check:
	@echo "$(YELLOW)Verificando salud de los servicios...$(NC)"
	@curl -f http://localhost:1337/_health 2>/dev/null && echo "$(GREEN)Strapi OK$(NC)" || echo "$(RED)Strapi no responde$(NC)"
	@docker exec $(DB_CONTAINER) pg_isready -U strapi_user -d cms_strapi_db >/dev/null 2>&1 && echo "$(GREEN)PostgreSQL OK$(NC)" || echo "$(RED)PostgreSQL no responde$(NC)"

# ==================================================================
# INFORMACIÓN DEL PROYECTO
# ==================================================================

info:
	@echo "$(GREEN)Información del Proyecto$(NC)"
	@echo "========================"
	@echo "Proyecto: CMS Strapi 5"
	@echo "Base de datos: PostgreSQL"
	@echo "Puerto Strapi: 1337"
	@echo "Puerto Adminer: 8080"
	@echo "Puerto PostgreSQL: 5432"
	@echo ""
	@echo "$(YELLOW)URLs:$(NC)"
	@echo "- Admin: http://localhost:1337/admin"
	@echo "- API: http://localhost:1337/api"
	@echo "- Docs: http://localhost:1337/documentation"
	@echo "- Adminer: http://localhost:8080"
