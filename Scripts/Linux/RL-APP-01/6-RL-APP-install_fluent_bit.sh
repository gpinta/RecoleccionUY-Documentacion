#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-APP-01
# Instalador Fluent Bit
#
# Servidor: RL-APP-01
# IP:       192.168.30.20
# Destino:  192.168.20.20:9200
#
# Lua identifica nombres reales de contenedores.
# No modifica las aplicaciones Laravel.
# No modifica Docker ni firewalld.
# ============================================================

readonly SERVER="RL-APP-01"
readonly SERVER_IP="192.168.30.20"
readonly MON_IP="192.168.20.20"

readonly BASE="/opt/recoleccion-uy/fluent-bit"
readonly IMAGE="fluent/fluent-bit:3.0.0"
readonly CONTAINER="recoleccion-fluent-bit-app"

info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

trap 'echo "[ERROR] Fallo en linea $LINENO" >&2' ERR

echo "=========================================="
echo " RECOLECCION UY - RL-APP-01"
echo " Instalacion Fluent Bit"
echo "=========================================="

# ------------------------------------------------------------
# 1. Verificar usuario y sistema
# ------------------------------------------------------------

[[ "$EUID" -eq 0 ]] ||
    die "Ejecutar como root."

[[ -r /etc/os-release ]] ||
    die "No se encuentra /etc/os-release."

source /etc/os-release

[[ "${ID:-}" == "rocky" ]] ||
    die "Se requiere Rocky Linux."

[[ "${VERSION_ID%%.*}" == "9" ]] ||
    die "Se requiere Rocky Linux 9."

# ------------------------------------------------------------
# 2. Verificar hostname e IP
# ------------------------------------------------------------

ACTUAL_HOST="$(hostname -s)"

[[ "${ACTUAL_HOST,,}" == "rl-app-01" ]] ||
    die "Hostname incorrecto: $ACTUAL_HOST"

# Evitar que SIGPIPE de grep -q se interprete como IP ausente.
ip -4 -o addr show |
    grep -F "inet ${SERVER_IP}/" >/dev/null ||
    die "IP incorrecta. Se requiere $SERVER_IP."

ok "Servidor validado: $SERVER"

# ------------------------------------------------------------
# 3. Dependencias
# ------------------------------------------------------------

for CMD in docker curl ip python3 find stat grep; do
    command -v "$CMD" >/dev/null 2>&1 ||
        die "Falta el comando $CMD"
done

docker info >/dev/null 2>&1 ||
    die "Docker no esta disponible."

docker compose version >/dev/null 2>&1 ||
    die "Docker Compose no esta disponible."

[[ -d /var/lib/docker/containers ]] ||
    die "No existe el directorio de logs Docker."

# Este INPUT solo lee logs de Docker con controlador json-file.
LOG_DRIVER="$(docker info --format '{{.LoggingDriver}}')"
[[ "$LOG_DRIVER" == "json-file" ]] ||
    die "Docker utiliza '$LOG_DRIVER'; el instalador requiere json-file."

# Los contenedores existentes pueden usar otro driver.
# Impedir una instalacion que no recolectaria sus registros.
python3 - <<'PY'
import json
import subprocess
import sys

ids = subprocess.check_output(
    ["docker", "ps", "-aq"], text=True
).split()

if not ids:
    sys.exit(0)

result = subprocess.run(
    ["docker", "inspect", *ids],
    check=True, text=True, capture_output=True
)
containers = json.loads(result.stdout)
different = [
    (c.get("Name", "?"), c.get("HostConfig", {})
     .get("LogConfig", {}).get("Type"))
    for c in containers
    if c.get("HostConfig", {}).get("LogConfig", {})
        .get("Type") not in ("json-file", "")
]
if different:
    print("[ADVERTENCIA] Contenedores no compatibles con json-file:",
          file=sys.stderr)
    for name, driver in different:
        print(f"  {name}: {driver}", file=sys.stderr)
    sys.exit(1)
PY

# SELinux puede impedir acceso a /var/lib/docker/containers.
# No se cambia la etiqueta de esa carpeta, por seguridad.
if command -v getenforce >/dev/null 2>&1 &&
   [[ "$(getenforce)" == "Enforcing" ]]; then
    info "SELinux Enforcing: comprobar acceso al directorio Docker tras iniciar."
fi

# ------------------------------------------------------------
# 4. Prevenir instalaciones duplicadas
# ------------------------------------------------------------

[[ ! -e "$BASE/compose.yaml" && ! -L "$BASE/compose.yaml" ]] ||
    die "Ya existe una instalacion en $BASE"

if docker container inspect "$CONTAINER" \
    >/dev/null 2>&1; then

    die "Ya existe el contenedor $CONTAINER."
fi

# ------------------------------------------------------------
# 5. Verificar OpenSearch
# ------------------------------------------------------------

info "Comprobando OpenSearch en RL-MON-01..."

curl --noproxy '*' -fsS --max-time 5 \
    "http://${MON_IP}:9200" \
    >/dev/null ||
    die "No se puede conectar a OpenSearch."

# El endpoint raiz responde aun cuando el cluster no puede
# aceptar escrituras; comprobar su salud por separado.
HEALTH="$(curl --noproxy '*' -fsS --max-time 5 \
    "http://${MON_IP}:9200/_cluster/health")" ||
    die "No se puede consultar la salud de OpenSearch."

python3 - "$HEALTH" <<'PY'
import json
import sys
try:
    result = json.loads(sys.argv[1])
    status = result.get("status")
except (ValueError, TypeError) as exc:
    raise SystemExit(f"Respuesta de salud invalida: {exc}")
if status not in ("green", "yellow"):
    raise SystemExit(f"OpenSearch no esta listo: {status}")
print(f"[OK] Salud OpenSearch: {status}")
PY

ok "OpenSearch accesible."

# ------------------------------------------------------------
# 6. Crear directorios
# ------------------------------------------------------------

# No alterar una instalacion preexistente no identificada.
[[ ! -e "$BASE/fluent-bit.conf" && ! -e "$BASE/parsers.conf" &&
   ! -e "$BASE/docker_metadata.lua" ]] ||
    die "Ya existen archivos Fluent Bit; revisar antes."

mkdir -p "$BASE/storage"

chmod 750 "$BASE"
chmod 770 "$BASE/storage"

# ------------------------------------------------------------
# 7. Configuracion del parser
# ------------------------------------------------------------

cat > "$BASE/parsers.conf" <<'EOF'
[PARSER]
    Name          docker_custom
    Format        json
    Time_Key      time
    Time_Format   %Y-%m-%dT%H:%M:%S.%L
    Time_Keep     On
EOF

# ------------------------------------------------------------
# 8. Lua - Identificacion Docker
# ------------------------------------------------------------

cat > "$BASE/docker_metadata.lua" <<'EOF'
-- RECOLECCION UY - RL-APP-01
-- Resolver nombres Docker mediante config.v2.json

local cache = {}

function add_container_name(tag, timestamp, record)

    local path = record["filepath"]

    if type(path) ~= "string" then
        return 1, timestamp, record
    end

    local id = string.match(
        path,
        "^/var/lib/docker/containers/([a-f0-9]+)/"
    )

    if not id then
        return 1, timestamp, record
    end

    record["container_id"] = id

    if cache[id] then
        record["container_name"] = cache[id]
        return 1, timestamp, record
    end

    local filename =
        "/var/lib/docker/containers/" ..
        id .. "/config.v2.json"

    local file = io.open(filename, "r")

    if not file then
        record["container_name"] = "unknown"
        return 1, timestamp, record
    end

    local content = file:read("*a")
    file:close()

    if not content then
        record["container_name"] = "unknown"
        return 1, timestamp, record
    end

    local name = string.match(
        content,
        '"Name"%s*:%s*"/([^"]+)"'
    )

    if name and name ~= "" then
        cache[id] = name
        record["container_name"] = name
    else
        record["container_name"] = "unknown"
    end

    return 1, timestamp, record

end
EOF

# ------------------------------------------------------------
# 9. Configuracion Fluent Bit
# ------------------------------------------------------------

cat > "$BASE/fluent-bit.conf" <<'EOF'
[SERVICE]
    Flush                 1
    Daemon                Off
    Log_Level             info
    Parsers_File          /fluent-bit/etc/parsers.conf
    storage.path          /fluent-bit/storage
    storage.sync          normal
    storage.checksum      On
    storage.max_chunks_up 128

[INPUT]
    Name                  tail
    Tag                   docker.app
    Path                  /var/lib/docker/containers/*/*-json.log
    Parser                docker_custom
    Path_Key              filepath
    DB                    /fluent-bit/storage/docker.db
    DB.Sync               Normal
    Read_From_Head        Off
    Mem_Buf_Limit         50MB
    Skip_Long_Lines       On
    Refresh_Interval      5
    Rotate_Wait           30
    storage.type          filesystem

[FILTER]
    Name                  lua
    Match                 docker.*
    script                /fluent-bit/etc/docker_metadata.lua
    call                  add_container_name

[FILTER]
    Name                  record_modifier
    Match                 docker.*
    Record                host RL-APP-01
    Record                server_ip 192.168.30.20
    Record                environment recoleccion-uy

[OUTPUT]
    Name                  opensearch
    Match                 docker.*
    Host                  192.168.20.20
    Port                  9200
    TLS                   Off
    Logstash_Format       On
    Logstash_Prefix       rl-app-01-logs
    Suppress_Type_Name    On
    Generate_ID           On
    Replace_Dots          On
    Retry_Limit           False
EOF

# ------------------------------------------------------------
# 10. Docker Compose
# ------------------------------------------------------------

cat > "$BASE/compose.yaml" <<'EOF'
name: recoleccion-fluent-bit-app

services:

  fluent-bit:
    image: fluent/fluent-bit:3.0.0
    container_name: recoleccion-fluent-bit-app

    hostname: RL-APP-01
    user: "0:0"

    volumes:
      - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro,Z
      - ./parsers.conf:/fluent-bit/etc/parsers.conf:ro,Z
      - ./docker_metadata.lua:/fluent-bit/etc/docker_metadata.lua:ro,Z
      - ./storage:/fluent-bit/storage:Z
      - /var/lib/docker/containers:/var/lib/docker/containers:ro

    restart: unless-stopped
EOF

chmod 640 "$BASE/compose.yaml"
chmod 640 "$BASE/"*.conf
chmod 640 "$BASE/docker_metadata.lua"

# ------------------------------------------------------------
# 11. Validar Compose
# ------------------------------------------------------------

cd "$BASE"

docker compose config --quiet ||
    die "Configuracion Docker Compose invalida."

# ------------------------------------------------------------
# 12. Instalar Fluent Bit
# ------------------------------------------------------------

info "Descargando imagen Fluent Bit..."

docker compose pull

# Validar la configuracion Fluent Bit antes del despliegue.
# La imagen real proporciona el parser de plugins.
docker compose run --rm --no-deps \
    fluent-bit /fluent-bit/bin/fluent-bit --dry-run -c /fluent-bit/etc/fluent-bit.conf ||
    die "Configuracion Fluent Bit invalida."

info "Iniciando Fluent Bit..."

docker compose up -d --no-build

# ------------------------------------------------------------
# 13. Verificar resultado
# ------------------------------------------------------------

docker compose ps

RUNNING="$(docker inspect \
    -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)"

[[ "$RUNNING" == true ]] ||
    die "Fluent Bit no esta ejecutandose."

# Verificar que el proceso permanezca activo y revisar errores.
sleep 5

RUNNING="$(docker inspect \
    -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)"

[[ "$RUNNING" == true ]] ||
    die "Fluent Bit se detuvo durante el inicio."

CONTAINER_LOGS="$(docker logs --tail 80 "$CONTAINER" 2>&1 || true)"

if grep -Ei \
    'permission denied|cannot open|error.*opensearch|configuration error' \
    <<< "$CONTAINER_LOGS" >/dev/null; then
    printf '%s\n' "$CONTAINER_LOGS" >&2
    die "Fluent Bit informa errores de lectura o salida."
fi

# Confirmar que existe al menos un archivo de log de tipo json-file.
if ! find /var/lib/docker/containers \
    -type f -name '*-json.log' -print -quit |
    grep -q .; then
    die "No hay archivos json-file que Fluent Bit pueda leer."
fi

echo
echo "=========================================="
echo " INSTALACION FINALIZADA - RL-APP-01"
echo "=========================================="
echo
echo "Servidor: $SERVER"
echo "IP: $SERVER_IP"
echo
echo "Destino OpenSearch:"
echo " http://${MON_IP}:9200"
echo
echo "Identificacion:"
echo " host = RL-APP-01"
echo " container_name = obtenido con Lua"
echo
echo "Comprobar Fluent Bit:"
echo " cd $BASE"
echo " docker compose ps"
echo " docker compose logs --tail=50"
echo
echo "No se modificaron las aplicaciones Laravel."
echo "No se modifico firewalld."
echo "==========================================="