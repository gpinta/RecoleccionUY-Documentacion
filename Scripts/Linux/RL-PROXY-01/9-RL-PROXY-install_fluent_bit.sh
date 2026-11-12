#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-PROXY-01
# Instalador Fluent Bit
#
# Servidor: RL-PROXY-01
# IP:       192.168.50.20
# Destino:  192.168.20.20:9200
#
# Recolecta logs Docker.
# Lua identifica nombres reales de contenedores.
#
# No modifica Nginx, WAF ni firewalld.
# ============================================================

readonly SERVER="RL-PROXY-01"
readonly SERVER_IP="192.168.50.20"
readonly MON_IP="192.168.20.20"

readonly BASE="/opt/recoleccion-uy/fluent-bit"
readonly IMAGE="fluent/fluent-bit:3.0.0"
readonly CONTAINER="recoleccion-fluent-bit-proxy"

info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }
warn() { echo "[ADVERTENCIA] $*" >&2; }

trap 'echo "[ERROR] Fallo en linea $LINENO" >&2' ERR

echo "=========================================="
echo " RECOLECCION UY - RL-PROXY-01"
echo " Instalacion Fluent Bit"
echo "=========================================="

# ------------------------------------------------------------
# 1. Validar usuario y sistema operativo
# ------------------------------------------------------------

[[ "$EUID" -eq 0 ]] ||
    die "Ejecutar como root."

(( $# == 0 )) ||
    die "Este script no acepta parametros."

[[ -r /etc/os-release ]] ||
    die "No se puede leer /etc/os-release."

source /etc/os-release

[[ "${ID:-}" == "rocky" ]] ||
    die "Se requiere Rocky Linux."

[[ "${VERSION_ID%%.*}" == "9" ]] ||
    die "Se requiere Rocky Linux 9."

# ------------------------------------------------------------
# 2. Validar identidad del servidor
# ------------------------------------------------------------

ACTUAL_HOST="$(hostname -s)"

[[ "${ACTUAL_HOST,,}" == "rl-proxy-01" ]] ||
    die "Hostname incorrecto: $ACTUAL_HOST"

# Evitar SIGPIPE por grep -q bajo pipefail.
ip -4 -o addr show |
    grep -F "inet ${SERVER_IP}/" >/dev/null ||
    die "IP incorrecta. Se requiere $SERVER_IP."

ok "Servidor validado: $SERVER"

# ------------------------------------------------------------
# 3. Verificar dependencias
# ------------------------------------------------------------

for CMD in docker curl ip python3 grep find stat sleep; do
    command -v "$CMD" >/dev/null 2>&1 ||
        die "Falta el comando $CMD"
done

docker info >/dev/null 2>&1 ||
    die "Docker no esta disponible."

docker compose version >/dev/null 2>&1 ||
    die "Docker Compose no esta disponible."

[[ -d /var/lib/docker/containers && ! -L /var/lib/docker/containers ]] ||
    die "No existe el directorio esperado de logs Docker."

# El input Tail lee archivos *-json.log y no funciona con
# controladores Docker locales diferentes a json-file.
LOG_DRIVER="$(docker info --format '{{.LoggingDriver}}')" ||
    die "No se pudo consultar el controlador de logs Docker."

if [[ "$LOG_DRIVER" != "json-file" ]]; then
    warn "Controlador por defecto: $LOG_DRIVER."
    warn "Se revisaran los contenedores existentes individualmente."
fi

JSON_CONTAINERS=0
OTHER_CONTAINERS=0
while IFS= read -r CID; do
    [[ -n "$CID" ]] || continue
    DRIVER="$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$CID")" ||
        die "No se pudo inspeccionar Docker: $CID"
    if [[ "$DRIVER" == "json-file" ]]; then
        JSON_CONTAINERS=$((JSON_CONTAINERS + 1))
    else
        OTHER_CONTAINERS=$((OTHER_CONTAINERS + 1))
    fi
done < <(docker ps -aq)

(( JSON_CONTAINERS > 0 )) ||
    die "No hay contenedores con logs json-file; el input Tail no tendria origen."

if (( OTHER_CONTAINERS > 0 )); then
    warn "$OTHER_CONTAINERS contenedores usan otro controlador; sus logs no se recogeran."
fi
ok "Contenedores json-file encontrados: $JSON_CONTAINERS."

# Verificar que los archivos de logs esperados existen, sin leer secretos.
if ! find /var/lib/docker/containers -type f -name '*-json.log' \
    -print -quit | grep -q .; then
    die "No se encontraron archivos *-json.log en Docker."
fi

# ------------------------------------------------------------
# 4. Proteger instalaciones existentes
# ------------------------------------------------------------

[[ ! -e "$BASE" && ! -L "$BASE" ]] ||
    die "Ya existe un directorio en $BASE; no se sobrescribe."

if docker container inspect "$CONTAINER" \
    >/dev/null 2>&1; then

    die "Ya existe el contenedor $CONTAINER."
fi

# ------------------------------------------------------------
# 5. Verificar conectividad con OpenSearch
# ------------------------------------------------------------

info "Comprobando OpenSearch en RL-MON-01..."

curl --noproxy '*' -fsS --connect-timeout 3 --max-time 8 \
    "http://${MON_IP}:9200" \
    >/dev/null ||
    die "OpenSearch no responde desde RL-PROXY-01."

CLUSTER_JSON="$(curl --noproxy '*' -fsS \
    --connect-timeout 3 --max-time 8 \
    "http://${MON_IP}:9200/_cluster/health")" ||
    die "No se pudo consultar la salud de OpenSearch."

printf '%s' "$CLUSTER_JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin)
status=d.get("status")
if status not in ("green","yellow"):
    raise SystemExit("OpenSearch no esta en estado green/yellow: "+str(status))
print("[OK] Estado del cluster OpenSearch:",status)
' || die "OpenSearch no esta operativo."

ok "Conexion con OpenSearch correcta."

# ------------------------------------------------------------
# 6. Crear directorios
# ------------------------------------------------------------

mkdir -p "$BASE/storage"

chmod 750 "$BASE"
chmod 770 "$BASE/storage"

# ------------------------------------------------------------
# 7. Parser Docker
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
# 8. Lua - Obtener nombre de contenedor Docker
# ------------------------------------------------------------

cat > "$BASE/docker_metadata.lua" <<'EOF'
-- RECOLECCION UY - RL-PROXY-01
-- Identificacion de contenedores Docker
-- Fuente: /var/lib/docker/containers/*/config.v2.json

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
    Tag                   docker.proxy
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
    Record                host RL-PROXY-01
    Record                server_ip 192.168.50.20
    Record                environment recoleccion-uy

[OUTPUT]
    Name                  opensearch
    Match                 docker.*
    Host                  192.168.20.20
    Port                  9200
    TLS                   Off
    Logstash_Format       On
    Logstash_Prefix       rl-proxy-01-logs
    Suppress_Type_Name    On
    Generate_ID           On
    Replace_Dots          On
    Retry_Limit           False
EOF

# ------------------------------------------------------------
# 10. Docker Compose
# ------------------------------------------------------------

cat > "$BASE/compose.yaml" <<'EOF'
name: recoleccion-fluent-bit-proxy

services:

  fluent-bit:
    image: fluent/fluent-bit:3.0.0
    container_name: recoleccion-fluent-bit-proxy

    hostname: RL-PROXY-01
    user: "0:0"

    volumes:
      - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro,Z
      - ./parsers.conf:/fluent-bit/etc/parsers.conf:ro,Z
      - ./docker_metadata.lua:/fluent-bit/etc/docker_metadata.lua:ro,Z
      - ./storage:/fluent-bit/storage:Z
      # No relabelar el directorio interno de Docker.
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
    die "Docker Compose invalido."

info "Validando configuracion Fluent Bit con la imagen seleccionada..."
docker image inspect "$IMAGE" >/dev/null 2>&1 ||
    docker pull "$IMAGE" ||
    die "No se pudo descargar la imagen Fluent Bit."

# El dry-run no inicia la recoleccion ni modifica ningun backend.
if ! docker compose run --rm --no-deps \
    --entrypoint /fluent-bit/bin/fluent-bit \
    fluent-bit --dry-run -c /fluent-bit/etc/fluent-bit.conf \
    > "$BASE/dry-run.log" 2>&1; then
    cat "$BASE/dry-run.log" >&2
    die "Configuracion Fluent Bit invalida."
fi
ok "Configuracion Fluent Bit prevalida."

# SELinux: evitar relabel de /var/lib/docker. Si el contenedor
# no puede leer logs por politica SELinux, reportarlo y
# no deshabilitar SELinux ni cambiar etiquetas del host.
if command -v getenforce >/dev/null 2>&1; then
    SELINUX_MODE="$(getenforce || true)"
    info "SELinux: ${SELINUX_MODE:-desconocido}."
fi

# ------------------------------------------------------------
# 12. Instalar Fluent Bit
# ------------------------------------------------------------

info "Descargando Fluent Bit..."

docker compose pull

info "Iniciando Fluent Bit..."

docker compose up -d --no-build

# ------------------------------------------------------------
# 13. Comprobar estado
# ------------------------------------------------------------

docker compose ps

for ATTEMPT in 1 2 3 4 5; do
    if [[ "$(docker inspect -f '{{.State.Running}}' \
        "$CONTAINER" 2>/dev/null || true)" == "true" ]]; then
        sleep 2
    else
        die "Fluent Bit se detuvo despues de iniciarse."
    fi
done

# Comprobar acceso efectivo al bind mount. La imagen
# puede carecer de shell: usar el binario Fluent Bit no
# sustituye la validacion de ingestion en OpenSearch.
LOGS="$(docker logs --tail 120 "$CONTAINER" 2>&1 || true)"
if grep -Ei \
    'permission denied|cannot open|failed to open|no such file|connection refused|failed to flush' \
    <<< "$LOGS" >/dev/null; then
    warn "Los logs contienen posibles errores de lectura o envio:"
    printf '%s\n' "$LOGS" | tail -n 35
    die "Revisar permisos SELinux o conectividad antes de dar por correcta la instalacion."
fi

ok "Fluent Bit permanece activo."
info "La entrega real de documentos debe verificarse en OpenSearch."

echo
echo "=========================================="
echo " INSTALACION FINALIZADA - RL-PROXY-01"
echo "=========================================="
echo
echo "Servidor: $SERVER"
echo "IP: $SERVER_IP"
echo
echo "Destino:"
echo " http://${MON_IP}:9200"
echo
echo "Identificacion:"
echo " host = RL-PROXY-01"
echo " container_name = obtenido con Lua"
echo
echo "Verificacion:"
echo " cd $BASE"
echo " docker compose ps"
echo " docker compose logs --tail=50"
echo
echo "Nginx y WAF no fueron modificados."
echo "firewalld no fue modificado."
echo "==========================================="