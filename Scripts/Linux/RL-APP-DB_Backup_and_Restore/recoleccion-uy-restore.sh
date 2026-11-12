#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-APP-01
# Script: recoleccion-uy-restore.sh
#
# OBJETIVO:
#   Restaurar la base MySQL compartida y las fotografias
#   a partir de un respaldo validado.
#
# APLICACIONES AFECTADAS:
#   - Ciudadana
#   - Backend Administrativo
#   - Camiones
#
# SEGURIDAD:
#   - Verifica SHA-256 y archivos comprimidos.
#   - Rechaza enlaces y rutas peligrosas del TAR.
#   - Exige confirmacion interactiva para restaurar.
#   - Comparte bloqueo con el script de respaldo.
#   - Conserva una copia SQL y las fotografias anteriores.
#
# IMPORTANTE:
#   Detener las tres aplicaciones y TODOS sus workers/colas
#   antes de utilizar --apply. El script no los detiene.
#   No iniciar aplicaciones si una restauracion falla.
# ============================================================


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

CONTAINER="recoleccion_db"
DATABASE="recoleccion"
BACKUP_ROOT="/var/backups/recoleccion-uy"
PHOTOS_PARENT="/srv/recoleccion-data"
PHOTOS="$PHOTOS_PARENT/fotos"
TIMER="recoleccion-uy-backup.timer"

BACKUP=""
APPLY=0
MAINTENANCE=0
LATEST=0
STAGE=""

# ============================================================
# 2. FUNCIONES AUXILIARES
# ============================================================

log() { printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Uso:
  sudo recoleccion-uy-restore.sh --list
  sudo recoleccion-uy-restore.sh --backup /var/backups/recoleccion-uy/backup_AAAA-MM-DD_HHMMSS
  sudo recoleccion-uy-restore.sh --backup RUTA --apply --maintenance-confirmed
  sudo recoleccion-uy-restore.sh --latest --apply --maintenance-confirmed

Sin --apply: solamente verifica el respaldo y muestra el plan.
--maintenance-confirmed certifica que las TRES aplicaciones Laravel y
sus workers/colas han dejado de escribir en MySQL y en fotos.
Para aplicar se exige además escribir una confirmación por teclado.
HELP
}
cleanup() {
  local exit_code=$?
  trap - EXIT
  if [[ -n "$STAGE" && -d "$STAGE" ]]; then
    rm -rf -- "$STAGE"
  fi
  exit "$exit_code"
}
trap cleanup EXIT

# ============================================================
# 3. INTERPRETAR PARAMETROS
# ============================================================

while (($#)); do
  case "$1" in
    --list)
      [[ $# -eq 1 ]] || die "--list no admite otros parámetros."
      [[ -d "$BACKUP_ROOT" ]] || die "No existe $BACKUP_ROOT"
      find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'backup_*' -printf '%f\n' | sort
      exit 0 ;;
    --backup)
      (($# >= 2)) || die "Falta la ruta de --backup."
      BACKUP="$2"; shift 2 ;;
    --latest) LATEST=1; shift ;;
    --apply) APPLY=1; shift ;;
    --maintenance-confirmed) MAINTENANCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "Opción desconocida: $1" ;;
  esac
done

# ============================================================
# 4. VERIFICAR REQUISITOS Y SELECCIONAR RESPALDO
# ============================================================

[[ "$EUID" -eq 0 ]] || die "Ejecutar como root."
for cmd in docker tar gzip sha256sum flock python3 realpath mktemp date systemctl mv mkdir; do
  command -v "$cmd" >/dev/null || die "Falta el comando: $cmd"
done
[[ -d "$BACKUP_ROOT" && ! -L "$BACKUP_ROOT" ]] ||
  die "No existe un directorio de respaldos valido."
[[ -d "$PHOTOS_PARENT" ]] || die "No existe $PHOTOS_PARENT"
(( LATEST == 0 )) || [[ -z "$BACKUP" ]] || die "Elegir --latest o --backup, no ambos."

if (( LATEST )); then
  BACKUP="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'backup_*' -printf '%f\n' | sort | tail -n 1)"
  [[ -n "$BACKUP" ]] || die "No hay respaldos para seleccionar."
  BACKUP="$BACKUP_ROOT/$BACKUP"
fi
[[ -n "$BACKUP" ]] || { usage; die "Indicá --backup o --latest."; }
[[ -d "$BACKUP" && ! -L "$BACKUP" ]] || die "Carpeta de respaldo no válida."
ROOT_CANON="$(realpath -e -- "$BACKUP_ROOT")"
BACKUP="$(realpath -e -- "$BACKUP")"
[[ "$(dirname "$BACKUP")" == "$ROOT_CANON" && "$(basename "$BACKUP")" == backup_* ]] \
  || die "El respaldo debe ser una carpeta backup_* directamente dentro de $BACKUP_ROOT"

# ============================================================
# 5. VERIFICAR INTEGRIDAD DEL RESPALDO
# ============================================================

for f in database.sql.gz fotos.tar.gz SHA256SUMS; do
  [[ -f "$BACKUP/$f" && ! -L "$BACKUP/$f" ]] || die "Falta archivo normal: $BACKUP/$f"
done
# Solo se aceptan las dos entradas generadas por el script
# oficial de respaldo; no se verifican rutas externas.
python3 - "$BACKUP/SHA256SUMS" <<'PY'
import pathlib
import re
import sys

lines = pathlib.Path(sys.argv[1]).read_text(encoding="ascii").splitlines()
expected = {"database.sql.gz", "fotos.tar.gz"}
found = set()

for line in lines:
    match = re.fullmatch(r"([0-9a-fA-F]{64})  (database\.sql\.gz|fotos\.tar\.gz)", line)
    if match is None or match.group(2) in found:
        raise SystemExit("SHA256SUMS contiene una entrada no admitida o repetida.")
    found.add(match.group(2))

if found != expected:
    raise SystemExit("SHA256SUMS no contiene exactamente los dos archivos esperados.")
PY

log "Comprobando sumas SHA-256: $BACKUP"
( cd "$BACKUP" && sha256sum -c SHA256SUMS ) || die "Falla la integridad SHA-256."
gzip -t "$BACKUP/database.sql.gz" || die "SQL comprimido inválido."
gzip -t "$BACKUP/fotos.tar.gz" || die "Fotos comprimidas inválidas."

# Impedir extracción de rutas peligrosas, enlaces y archivos especiales.
python3 - "$BACKUP/fotos.tar.gz" <<'PY'
import pathlib, sys, tarfile
path = sys.argv[1]
has_root = False
with tarfile.open(path, "r:gz") as archive:
    for item in archive:
        raw = item.name
        p = pathlib.PurePosixPath(raw)
        if raw.startswith("/") or ".." in p.parts or not p.parts or p.parts[0] != "fotos":
            raise SystemExit(f"Entrada fuera de fotos/: {raw}")
        if not (item.isfile() or item.isdir()):
            raise SystemExit(f"Entrada no admitida (enlace/especial): {raw}")
        if p.parts == ("fotos",) and item.isdir():
            has_root = True
if not has_root:
    raise SystemExit("El archivo no contiene la carpeta fotos/.")
PY
# ============================================================
# 6. MOSTRAR PLAN Y SOLICITAR CONFIRMACION
# ============================================================

log "Verificación previa correcta."
log "Base: $DATABASE, contenedor: $CONTAINER; fotografías: $PHOTOS"
if (( APPLY == 0 )); then
  log "MODO VERIFICACIÓN: no se modificó ningún dato."
  log "Para restaurar: agregar --apply --maintenance-confirmed."
  exit 0
fi

(( MAINTENANCE == 1 )) || die "Falta --maintenance-confirmed."
[[ -t 0 ]] || die "La restauración exige confirmación interactiva desde una terminal."
[[ -d "$PHOTOS" && ! -L "$PHOTOS" ]] || die "La carpeta actual de fotos no existe o es enlace."
docker inspect "$CONTAINER" >/dev/null 2>&1 || die "No existe el contenedor $CONTAINER."
[[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER")" == true ]] \
  || die "El contenedor de MySQL está detenido."
docker exec "$CONTAINER" sh -c 'test -n "${MYSQL_ROOT_PASSWORD:-}"' \
  || die "MYSQL_ROOT_PASSWORD no está disponible en el entorno del contenedor."
docker exec "$CONTAINER" sh -c '
  export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:?}"
  mysql -uroot -Nse "SELECT 1" recoleccion
' >/dev/null || die "No se pudo acceder a MySQL como root."

cat <<EOF
ATENCIÓN: SE REEMPLAZARÁ LA BASE DE DATOS $DATABASE Y LA CARPETA $PHOTOS.
Verificá que Ciudadana, Administrativo, Camiones y TODOS los workers
estén DETENIDOS y que no haya escrituras.
Respaldo elegido: $BACKUP
Se creará un respaldo SQL de emergencia antes de modificar la base.
La carpeta actual de fotos se conservará renombrada.
EOF
read -r -p "Escribí exactamente RESTAURAR recoleccion para continuar: " ANSWER
[[ "$ANSWER" == "RESTAURAR recoleccion" ]] || die "Cancelado por el operador."

# Exclusión mutua con el script de respaldo, que usa el mismo lock.
# ============================================================
# 7. BLOQUEAR RESPALDOS Y DETENER TEMPORIZADOR
# ============================================================

exec 9>"$BACKUP_ROOT/.backup.lock"
flock -n 9 || die "Hay otro proceso de respaldo/restauración activo."
if systemctl is-active --quiet "$TIMER"; then
  systemctl stop "$TIMER" || die "No se pudo detener el temporizador."
fi

# ============================================================
# 8. CREAR RESPALDO SQL DE EMERGENCIA
# ============================================================

STAMP="$(date +%Y-%m-%d_%H%M%S)"
EMERGENCY="$BACKUP_ROOT/pre_restauracion_$STAMP"
mkdir -m 700 -- "$EMERGENCY"
PHOTOS_OLD="$PHOTOS_PARENT/fotos.pre-restauracion_$STAMP"
[[ ! -e "$PHOTOS_OLD" ]] || die "Ya existe $PHOTOS_OLD"

log "Creando volcado SQL de emergencia en $EMERGENCY"
docker exec "$CONTAINER" sh -c '
  export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:?}"
  exec mysqldump -uroot --single-transaction --quick \
    --routines --triggers --events --no-tablespaces \
    --set-gtid-purged=OFF --databases recoleccion
' | gzip -c > "$EMERGENCY/database-antes.sql.gz"
gzip -t "$EMERGENCY/database-antes.sql.gz" ||
  die "El respaldo SQL de emergencia no supera la prueba gzip."
[[ -s "$EMERGENCY/database-antes.sql.gz" ]] || die "SQL de emergencia vacío."

# ============================================================
# 9. PREPARAR FOTOGRAFIAS EN DIRECTORIO TEMPORAL
# ============================================================

log "Extrayendo fotografías en carpeta temporal (sin tocar las actuales)."
STAGE="$(mktemp -d "$PHOTOS_PARENT/.restauracion_fotos_XXXXXX")"
tar -xzpf "$BACKUP/fotos.tar.gz" -C "$STAGE"
[[ -d "$STAGE/fotos" ]] || die "No se extrajo fotos/ correctamente."

# ============================================================
# 10. RESTAURAR BASE DE DATOS MYSQL
# ============================================================

log "Se va a sustituir la base de datos."
printf 'DROP DATABASE IF EXISTS `%s`;\n' "$DATABASE" |
  docker exec -i "$CONTAINER" sh -c '
    export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:?}"
    exec mysql -uroot
  ' || die "Falló el borrado de la base. Revisar copia de emergencia."

log "Importando SQL (puede requerir tiempo según el volumen)."
if ! (gzip -dc "$BACKUP/database.sql.gz" |
  docker exec -i "$CONTAINER" sh -c '
    export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:?}"
    exec mysql -uroot
  '); then
  die "Falló la importación. La base podría estar incompleta. NO reiniciar aplicaciones. SQL de emergencia: $EMERGENCY/database-antes.sql.gz"
fi
docker exec "$CONTAINER" sh -c '
  export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:?}"
  exec mysql -uroot -Nse "SHOW TABLES" recoleccion
' >/dev/null || die "No se pudo verificar la base restaurada. No iniciar aplicaciones."

# ============================================================
# 11. RESTAURAR FOTOGRAFIAS
# ============================================================

log "Reemplazando fotografías; se conserva la carpeta anterior."
mv -- "$PHOTOS" "$PHOTOS_OLD" || die "No se pudo conservar la carpeta de fotos anterior."
if ! mv -- "$STAGE/fotos" "$PHOTOS"; then
  mv -- "$PHOTOS_OLD" "$PHOTOS" || log "ERROR: restaurar manualmente la carpeta $PHOTOS_OLD"
  die "Falló la instalación de las nuevas fotos."
fi
# ============================================================
# 12. INFORMAR RESULTADO
# ============================================================

log "Restauración completada."
log "SQL de emergencia: $EMERGENCY/database-antes.sql.gz"
log "Fotografías anteriores: $PHOTOS_OLD"
log "Comprobar propietarios, permisos y contexto SELinux de la carpeta $PHOTOS."
log "Verificar MySQL, fotos y las tres aplicaciones antes de reabrir el servicio."
log "El temporizador queda detenido si estaba activo. Reactivarlo tras verificar: systemctl start $TIMER"
