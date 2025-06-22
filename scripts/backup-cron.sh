#!/bin/bash

# ==================================================================
# SCRIPT DE BACKUP AUTOMÁTICO PARA POSTGRESQL
# ==================================================================
# Script ejecutado por cron para realizar backups automáticos

set -e

# Variables de entorno
DB_HOST=${POSTGRES_HOST:-postgres}
DB_NAME=${POSTGRES_DB:-cms_strapi_db}
DB_USER=${POSTGRES_USER:-strapi_user}
DB_PASS=${POSTGRES_PASSWORD}
BACKUP_DIR=${BACKUP_DIR:-/backups}
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Funciones de logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Verificar variables requeridas
check_requirements() {
    if [ -z "$DB_PASS" ]; then
        log_error "POSTGRES_PASSWORD no está definida"
        exit 1
    fi
    
    if ! command -v pg_dump &> /dev/null; then
        log_error "pg_dump no está disponible"
        exit 1
    fi
    
    # Crear directorio de backup si no existe
    mkdir -p "$BACKUP_DIR"
    
    log_info "Verificación de requisitos completada"
}

# Función principal de backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/backup_${DB_NAME}_${timestamp}.sql"
    local backup_file_compressed="$backup_file.gz"
    
    log_info "Iniciando backup de base de datos: $DB_NAME"
    log_info "Archivo de salida: $backup_file_compressed"
    
    # Verificar conectividad
    if ! PGPASSWORD="$DB_PASS" pg_isready -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
        log_error "No se puede conectar a la base de datos"
        exit 1
    fi
    
    # Crear backup
    log_info "Ejecutando pg_dump..."
    if PGPASSWORD="$DB_PASS" pg_dump \
        -h "$DB_HOST" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --verbose \
        --clean \
        --if-exists \
        --create \
        --format=plain \
        --no-owner \
        --no-privileges \
        > "$backup_file" 2>/dev/null; then
        
        log_info "Backup SQL creado exitosamente"
        
        # Comprimir backup
        log_info "Comprimiendo backup..."
        if gzip "$backup_file"; then
            log_info "Backup comprimido: $backup_file_compressed"
            
            # Verificar integridad del archivo comprimido
            if gzip -t "$backup_file_compressed"; then
                log_info "Verificación de integridad exitosa"
                
                # Mostrar información del archivo
                local file_size=$(du -h "$backup_file_compressed" | cut -f1)
                log_info "Tamaño del backup: $file_size"
                
                return 0
            else
                log_error "Error en la verificación de integridad"
                rm -f "$backup_file_compressed"
                return 1
            fi
        else
            log_error "Error al comprimir el backup"
            rm -f "$backup_file"
            return 1
        fi
    else
        log_error "Error al crear el backup SQL"
        rm -f "$backup_file"
        return 1
    fi
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    log_info "Limpiando backups antiguos (mayores a $RETENTION_DAYS días)"
    
    local deleted_count=0
    
    # Buscar y eliminar archivos antiguos
    while IFS= read -r -d '' file; do
        log_info "Eliminando backup antiguo: $(basename "$file")"
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    
    if [ $deleted_count -gt 0 ]; then
        log_info "$deleted_count backups antiguos eliminados"
    else
        log_info "No se encontraron backups antiguos para eliminar"
    fi
}

# Función para mostrar estadísticas
show_stats() {
    log_info "Estadísticas de backups:"
    
    local total_backups=$(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f 2>/dev/null | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local oldest_backup=$(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2-)
    local newest_backup=$(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    echo "  - Total de backups: $total_backups"
    echo "  - Tamaño total: $total_size"
    
    if [ -n "$oldest_backup" ]; then
        echo "  - Backup más antiguo: $(basename "$oldest_backup")"
    fi
    
    if [ -n "$newest_backup" ]; then
        echo "  - Backup más reciente: $(basename "$newest_backup")"
    fi
}

# Función para enviar notificaciones (opcional)
send_notification() {
    local status=$1
    local message=$2
    
    # Webhook de Slack (si está configurado)
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        local color
        case $status in
            "success") color="good" ;;
            "error") color="danger" ;;
            *) color="warning" ;;
        esac
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🗄️ Backup Database\", \"attachments\":[{\"color\":\"$color\", \"text\":\"$message\"}]}" \
            "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
    
    # Email (si está configurado)
    if [ -n "$NOTIFICATION_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Backup Database - $status" "$NOTIFICATION_EMAIL" || true
    fi
}

# Función principal
main() {
    log_info "=== INICIO DEL PROCESO DE BACKUP ==="
    
    local start_time=$(date +%s)
    
    # Verificar requisitos
    check_requirements
    
    # Crear backup
    if create_backup; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_info "Backup completado exitosamente en ${duration}s"
        
        # Limpiar backups antiguos
        cleanup_old_backups
        
        # Mostrar estadísticas
        show_stats
        
        # Notificar éxito
        send_notification "success" "Backup de base de datos completado exitosamente en ${duration}s"
        
        log_info "=== PROCESO DE BACKUP FINALIZADO ==="
        exit 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_error "Error en el proceso de backup después de ${duration}s"
        
        # Notificar error
        send_notification "error" "Error en el proceso de backup después de ${duration}s"
        
        log_error "=== PROCESO DE BACKUP FALLÓ ==="
        exit 1
    fi
}

# Función de ayuda
show_help() {
    echo "Script de Backup Automático para PostgreSQL"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  --test         Ejecutar en modo test (no crea cron job)"
    echo ""
    echo "Variables de entorno:"
    echo "  POSTGRES_HOST           Host de PostgreSQL (default: postgres)"
    echo "  POSTGRES_DB             Nombre de la base de datos"
    echo "  POSTGRES_USER           Usuario de PostgreSQL"
    echo "  POSTGRES_PASSWORD       Contraseña de PostgreSQL (requerida)"
    echo "  BACKUP_DIR              Directorio de backups (default: /backups)"
    echo "  BACKUP_RETENTION_DAYS   Días de retención (default: 7)"
    echo "  SLACK_WEBHOOK_URL       URL del webhook de Slack (opcional)"
    echo "  NOTIFICATION_EMAIL      Email para notificaciones (opcional)"
}

# Configurar cron job
setup_cron() {
    local schedule=${BACKUP_SCHEDULE:-"0 2 * * *"}  # 2 AM diario por defecto
    local cron_command="$0"
    
    log_info "Configurando cron job con schedule: $schedule"
    
    # Agregar variables de entorno al cron
    (
        echo "# Backup automático de base de datos"
        echo "POSTGRES_HOST=$DB_HOST"
        echo "POSTGRES_DB=$DB_NAME"
        echo "POSTGRES_USER=$DB_USER"
        echo "POSTGRES_PASSWORD=$DB_PASS"
        echo "BACKUP_DIR=$BACKUP_DIR"
        echo "BACKUP_RETENTION_DAYS=$RETENTION_DAYS"
        [ -n "$SLACK_WEBHOOK_URL" ] && echo "SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL"
        [ -n "$NOTIFICATION_EMAIL" ] && echo "NOTIFICATION_EMAIL=$NOTIFICATION_EMAIL"
        echo ""
        echo "$schedule $cron_command"
    ) | crontab -
    
    log_info "Cron job configurado exitosamente"
}

# Manejo de argumentos
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --test)
        log_info "Ejecutando en modo test"
        main
        ;;
    --setup-cron)
        setup_cron
        exit 0
        ;;
    *)
        # Si no hay argumentos, ejecutar backup normal
        main
        ;;
esac
