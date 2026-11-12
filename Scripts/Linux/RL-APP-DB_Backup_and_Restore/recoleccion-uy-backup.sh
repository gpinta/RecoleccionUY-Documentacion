#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-APP-01
# Script: recoleccion-uy-backup.sh
#
# OBJETIVO:
#   Respaldar la base MySQL compartida y las fotografias.
#
# APLICACIONES:
#   - Ciudadana
#   - Backend Administrativo
#   - Camiones
#
# ARCHIVOS GENERADOS:
#   - database.sql.gz
#   - fotos.tar.gz
#   - SHA256SUMS
#
# SEGURIDAD:
#   - No modifica las aplicaciones Laravel.
#   - No elimina fotografias ni bases de datos.
#   - No guarda credenciales en el host.
#   - Utiliza el mismo bloqueo que la restauracion.
#   - Publica el respaldo solo si finaliza correctamente.
#
# IMPORTANTE:
#   Este script no detiene las escrituras de las aplicaciones.
#   Para garantizar consistencia entre MySQL y fotografias,
#   realizar el respaldo durante una ventana sin escrituras
#   en las tres aplicaciones y sus workers/colas.
# ============================================================


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

CONTAINER="recoleccion_db"
DATABASE="recoleccion"
PHOTOS_PARENT="/srv/recoleccion-data"
PHOTOS="$PHOTOS_PARENT/fotos"
BACKUP_ROOT="/var/backups/recoleccion-uy"

WORK=""
complete=0


# ============================================================
# 2. FUNCIONES AUXILIARES
# ============================================================

log() {
    printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

die() {
    log "[ERROR] $*" >&2
    exit 1
}

cleanup() {
    local exit_code=$?

    trap - EXIT

    if [[ "$complete" -eq 0 && -n "$WORK" && -d "$WORK" ]]; then
        log "[ADVERTENCIA] Respaldo incompleto; eliminando archivos temporales."
        rm -rf -- "$WORK"
    fi

    exit "$exit_code"
}

trap cleanup EXIT


# ============================================================
# 3. VERIFICAR REQUISITOS
# ============================================================

[[ "$EUID" -eq 0 ]] || die "Ejecutar como root."

for cmd in docker gzip tar sha256sum flock mktemp date chmod mkdir mv; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Falta el comando: $cmd"
done

[[ -d "$PHOTOS_PARENT" && ! -L "$PHOTOS_PARENT" ]] ||
    die "No existe un directorio valido: $PHOTOS_PARENT"

[[ -d "$PHOTOS" && ! -L "$PHOTOS" ]] ||
    die "No existe un directorio valido de fotografias: $PHOTOS"

if [[ -e "$BACKUP_ROOT" || -L "$BACKUP_ROOT" ]]; then
    [[ -d "$BACKUP_ROOT" && ! -L "$BACKUP_ROOT" ]] ||
        die "La ruta de respaldos no es un directorio valido."
else
    mkdir -m 700 -p -- "$BACKUP_ROOT"
fi

chmod 700 -- "$BACKUP_ROOT"

docker info >/dev/null 2>&1 ||
    die "No se pudo conectar con Docker."

docker inspect "$CONTAINER" >/dev/null 2>&1 ||
    die "No existe el contenedor $CONTAINER."

[[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER")" == "true" ]] ||
    die "El contenedor MySQL no esta en ejecucion."


# ============================================================
# 4. BLOQUEO DE RESPALDO Y RESTAURACION
# ============================================================

exec 9>"$BACKUP_ROOT/.backup.lock"

flock -n 9 ||
    die "Hay un respaldo o una restauracion en ejecucion."


# ============================================================
# 5. PREPARAR DIRECTORIO TEMPORAL
# ============================================================

STAMP="$(date +%Y-%m-%d_%H%M%S)"
FINAL="$BACKUP_ROOT/backup_$STAMP"

[[ ! -e "$FINAL" && ! -L "$FINAL" ]] ||
    die "El destino del respaldo ya existe: $FINAL"

WORK="$(mktemp -d "$BACKUP_ROOT/.incompleto_${STAMP}_XXXXXX")"


# ============================================================
# 6. RESPALDAR BASE DE DATOS MYSQL
# ============================================================

log "[INFO] Iniciando respaldo de MySQL: $DATABASE"

# Se leen las credenciales desde el entorno existente del contenedor.
# No se copian contrasenas a archivos del host ni se imprimen en logs.
docker exec "$CONTAINER" sh -c '
    set -eu
    : "${MYSQL_USER:?No definido MYSQL_USER}"
    : "${MYSQL_PASSWORD:?No definido MYSQL_PASSWORD}"
    export MYSQL_PWD="$MYSQL_PASSWORD"
    exec mysqldump --user="$MYSQL_USER" \
        --single-transaction --quick \
        --routines --triggers --events \
        --no-tablespaces --set-gtid-purged=OFF \
        --databases recoleccion
' | gzip -c > "$WORK/database.sql.gz"

[[ -s "$WORK/database.sql.gz" ]] ||
    die "El respaldo SQL esta vacio."

gzip -t "$WORK/database.sql.gz" ||
    die "El respaldo SQL esta danado."


# ============================================================
# 7. RESPALDAR FOTOGRAFIAS
# ============================================================

log "[INFO] Comprimiendo fotografias."

tar -C "$PHOTOS_PARENT" -czf "$WORK/fotos.tar.gz" fotos ||
    die "No se pudo generar el archivo de fotografias."

[[ -s "$WORK/fotos.tar.gz" ]] ||
    die "El archivo de fotografias esta vacio."

gzip -t "$WORK/fotos.tar.gz" ||
    die "El archivo comprimido de fotografias esta danado."

tar -tzf "$WORK/fotos.tar.gz" >/dev/null ||
    die "No se pudo leer el contenido del archivo de fotografias."


# ============================================================
# 8. VERIFICAR INTEGRIDAD Y PUBLICAR RESPALDO
# ============================================================

(
    cd "$WORK"
    sha256sum database.sql.gz fotos.tar.gz > SHA256SUMS
    sha256sum -c SHA256SUMS
) || die "Fallo la verificacion SHA-256."

[[ ! -e "$FINAL" && ! -L "$FINAL" ]] ||
    die "El destino ya existe: $FINAL"

mv -T -- "$WORK" "$FINAL" ||
    die "No se pudo publicar el respaldo."

complete=1


# ============================================================
# 9. MOSTRAR RESULTADO DEL RESPALDO
# ============================================================

printf '\n'
printf '%s\n' '============================================================'
log "[OK] RESPALDO FINALIZADO CORRECTAMENTE"
printf '%s\n' '============================================================'
printf '\n'
printf 'Ruta del respaldo:\n  %s\n' "$FINAL"
printf '\n'
printf '%s\n' 'Archivos respaldados:'
printf '%s\n' '  - database.sql.gz'
printf '%s\n' '  - fotos.tar.gz'
printf '%s\n' '  - SHA256SUMS'
printf '\n'
printf '%s\n' '============================================================'
log "[ADVERTENCIA] Verificar consistencia funcional entre MySQL y fotografias antes de utilizarlo para restaurar."
printf '%s\n' '============================================================'