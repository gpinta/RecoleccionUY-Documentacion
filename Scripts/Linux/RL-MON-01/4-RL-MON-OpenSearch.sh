#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY
# RL-MON-01 - OpenSearch + Dashboards + Fluent Bit
#
# Rocky Linux 9
# Docker Compose
#
# OpenSearch:  192.168.20.20:9200
# Dashboards:  192.168.20.20:5601
#
# No modifica el monitoreo existente.
# No modifica firewalld.
# No elimina volumenes o contenedores existentes.
# ============================================================

readonly SERVER="RL-MON-01"
readonly SERVER_IP="192.168.20.20"
readonly BASE="/opt/recoleccion-uy/opensearch"

readonly OS_IMAGE="opensearchproject/opensearch:2.12.0"
readonly UI_IMAGE="opensearchproject/opensearch-dashboards:2.12.0"
readonly FB_IMAGE="fluent/fluent-bit:3.0.0"

info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

trap 'echo "[ERROR] Fallo en linea $LINENO" >&2' ERR

echo "==========================================="
echo " RECOLECCION UY - RL-MON-01"
echo " OpenSearch + Dashboards + Fluent Bit"
echo "==========================================="

# ------------------------------------------------------------
# 1. Verificar usuario y sistema
# ------------------------------------------------------------

[[ "$EUID" -eq 0 ]] ||
    die "Ejecutar como root."

source /etc/os-release

[[ "${ID:-}" == "rocky" ]] ||
    die "Sistema operativo incorrecto."

[[ "${VERSION_ID%%.*}" == "9" ]] ||
    die "Se requiere Rocky Linux 9."

# ------------------------------------------------------------
# 2. Verificar identidad del servidor
# ------------------------------------------------------------

ACTUAL_HOST="$(hostname -s)"

[[ "${ACTUAL_HOST,,}" == "rl-mon-01" ]] ||
    die "Hostname incorrecto: $ACTUAL_HOST"

ip -4 -o addr show | grep -Fq "inet ${SERVER_IP}/" ||
    die "IP incorrecta. Se requiere $SERVER_IP"

ok "Hostname e IP correctos."

# ------------------------------------------------------------
# 3. Verificar dependencias
# ------------------------------------------------------------

for CMD in docker curl ss sysctl ip awk df; do
    command -v "$CMD" >/dev/null ||
        die "Falta el comando $CMD"
done

docker info >/dev/null 2>&1 ||
    die "Docker no esta operativo."

docker compose version >/dev/null 2>&1 ||
    die "Docker Compose no esta disponible."

[[ -d /var/lib/docker/containers ]] ||
    die "No existe el directorio de logs Docker."

# Fluent Bit lee archivos *-json.log. No es compatible
# con contenedores que utilizan journald u otro driver.
LOG_DRIVER="$(docker info --format '{{.LoggingDriver}}')" ||
    die "No se pudo consultar el driver de logs Docker."

if [[ "$LOG_DRIVER" != "json-file" ]]; then
    info "ADVERTENCIA: driver por defecto $LOG_DRIVER."
    info "Fluent Bit solo recogera contenedores con driver json-file."
fi

while IFS= read -r CID; do
    [[ -n "$CID" ]] || continue
    DRIVER="$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' "$CID")" ||
        die "No se pudo consultar driver de logs de $CID"
    if [[ "$DRIVER" != "json-file" ]]; then
        info "ADVERTENCIA: contenedor $CID utiliza $DRIVER; sus logs no seran recolectados."
    fi
done < <(docker ps -q)

# ------------------------------------------------------------
# 4. Proteger instalaciones anteriores
# ------------------------------------------------------------

[[ ! -e "$BASE/compose.yaml" ]] ||
    die "Ya existe una instalacion en $BASE"

for CONTAINER in \
    recoleccion-opensearch \
    recoleccion-opensearch-dashboards \
    recoleccion-fluent-bit-mon
do
    if docker container inspect "$CONTAINER" \
        >/dev/null 2>&1; then

        die "Contenedor existente: $CONTAINER"
    fi
done

for PORT in 9200 5601; do
    if ss -H -ltn "( sport = :$PORT )" |
        grep -q .; then

        die "Puerto $PORT ocupado."
    fi
done

# ------------------------------------------------------------
# 5. Verificar memoria y almacenamiento
# ------------------------------------------------------------

MEM_KB="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"

(( MEM_KB >= 4 * 1024 * 1024 )) ||
    die "Memoria total inferior a 4 GiB."

AVAILABLE_KB="$(df -Pk /var/lib/docker |
    awk 'NR==2 {print $4}')"

(( AVAILABLE_KB >= 10 * 1024 * 1024 )) ||
    die "Menos de 10 GiB disponibles en Docker."

info "Revisar adicionalmente la memoria usada por Grafana y Prometheus."

# ------------------------------------------------------------
# 6. Ajustar vm.max_map_count
# ------------------------------------------------------------

CURRENT_MAP="$(sysctl -n vm.max_map_count)"

if (( CURRENT_MAP < 262144 )); then

    cat > /etc/sysctl.d/99-recoleccion-opensearch.conf <<'EOF'
vm.max_map_count=262144
EOF

    sysctl -p \
        /etc/sysctl.d/99-recoleccion-opensearch.conf
fi

# ------------------------------------------------------------
# 7. Crear directorios
# ------------------------------------------------------------

mkdir -p "$BASE/fluent-bit/storage"

chmod 750 "$BASE" "$BASE/fluent-bit"
chmod 770 "$BASE/fluent-bit/storage"

# ------------------------------------------------------------
# 8. Parser de logs Docker
# ------------------------------------------------------------

cat > "$BASE/fluent-bit/parsers.conf" <<'EOF'
[PARSER]
    Name          docker_custom
    Format        json
    Time_Key      time
    Time_Format   %Y-%m-%dT%H:%M:%S.%L
    Time_Keep     On
EOF

# ------------------------------------------------------------
# 9. Lua - Identificacion de contenedores
# ------------------------------------------------------------

cat > "$BASE/fluent-bit/docker_metadata.lua" <<'EOF'
-- RECOLECCION UY - Docker container metadata
-- Lectura de config.v2.json sin utilizar docker.sock

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
# 10. Configuracion Fluent Bit
# ------------------------------------------------------------

cat > "$BASE/fluent-bit/fluent-bit.conf" <<'EOF'
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
    Tag                   docker.mon
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
    Record                host RL-MON-01
    Record                server_ip 192.168.20.20
    Record                environment recoleccion-uy

[OUTPUT]
    Name                  opensearch
    Match                 docker.*
    Host                  opensearch
    Port                  9200
    TLS                   Off
    Logstash_Format       On
    Logstash_Prefix       rl-mon-01-logs
    Suppress_Type_Name    On
    Generate_ID           On
    Replace_Dots          On
    Retry_Limit           False
EOF

# ------------------------------------------------------------
# 11. Docker Compose integrado
# ------------------------------------------------------------

cat > "$BASE/compose.yaml" <<'EOF'
name: recoleccion-opensearch

services:

  opensearch:
    image: opensearchproject/opensearch:2.12.0
    container_name: recoleccion-opensearch

    environment:
      - discovery.type=single-node
      - DISABLE_SECURITY_PLUGIN=true
      - DISABLE_INSTALL_DEMO_CONFIG=true
      - OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536

    volumes:
      - opensearch-data:/usr/share/opensearch/data

    ports:
      - "192.168.20.20:9200:9200"

    restart: unless-stopped

    networks:
      - logs-net

  dashboards:
    image: opensearchproject/opensearch-dashboards:2.12.0
    container_name: recoleccion-opensearch-dashboards

    environment:
      - 'OPENSEARCH_HOSTS=["http://opensearch:9200"]'
      - DISABLE_SECURITY_DASHBOARDS_PLUGIN=true

    depends_on:
      - opensearch

    ports:
      - "192.168.20.20:5601:5601"

    restart: unless-stopped

    networks:
      - logs-net

  fluent-bit:
    image: fluent/fluent-bit:3.0.0
    container_name: recoleccion-fluent-bit-mon

    user: "0:0"

    volumes:
      - ./fluent-bit/fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro
      - ./fluent-bit/parsers.conf:/fluent-bit/etc/parsers.conf:ro
      - ./fluent-bit/docker_metadata.lua:/fluent-bit/etc/docker_metadata.lua:ro
      - ./fluent-bit/storage:/fluent-bit/storage
      - /var/lib/docker/containers:/var/lib/docker/containers:ro

    depends_on:
      - opensearch

    restart: unless-stopped

    networks:
      - logs-net

networks:
  logs-net:
    driver: bridge

volumes:
  opensearch-data:
EOF

chmod 640 "$BASE/compose.yaml"
chmod 640 "$BASE/fluent-bit/"*.conf
chmod 640 "$BASE/fluent-bit/docker_metadata.lua"

# ------------------------------------------------------------
# 12. Validar configuracion
# ------------------------------------------------------------

cd "$BASE"

docker compose config --quiet ||
    die "Docker Compose invalido."

# ------------------------------------------------------------
# 13. Instalar e iniciar
# ------------------------------------------------------------

info "Descargando imagenes..."
docker compose pull

info "Iniciando OpenSearch..."
docker compose up -d --no-build opensearch

info "Esperando respuesta de OpenSearch..."

READY=false

for ATTEMPT in $(seq 1 60); do

    if curl --noproxy '*' -fsS --max-time 3 \
        "http://${SERVER_IP}:9200" \
        >/dev/null 2>&1; then

        READY=true
        break
    fi

    sleep 2
done

[[ "$READY" == true ]] ||
    die "OpenSearch no responde. Revisar los logs."

info "Iniciando Dashboards y Fluent Bit..."

docker compose up -d --no-build dashboards fluent-bit

# Comprobar que los tres contenedores se mantienen activos.
for CONTAINER in \
    recoleccion-opensearch \
    recoleccion-opensearch-dashboards \
    recoleccion-fluent-bit-mon
do
    RUNNING="$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)"
    [[ "$RUNNING" == "true" ]] ||
        die "Contenedor inactivo despues de instalar: $CONTAINER"
done

# Comprobar Dashboards, no solo OpenSearch.
DASHBOARDS_READY=false
for ATTEMPT in $(seq 1 60); do
    CODE="$(curl --noproxy '*' -sS --max-time 3 \
        -o /dev/null -w '%{http_code}' \
        "http://${SERVER_IP}:5601/" 2>/dev/null || true)"
    if [[ "$CODE" =~ ^[23][0-9][0-9]$ ]]; then
        DASHBOARDS_READY=true
        break
    fi
    sleep 2
done
[[ "$DASHBOARDS_READY" == true ]] ||
    die "Dashboards no responde correctamente. Revisar sus logs."

# Un contenedor activo no demuestra que Fluent Bit pueda
# leer archivos Docker ni escribir documentos en OpenSearch.
info "Verificar la ingestion real y los permisos SELinux de Fluent Bit."
info "La recoleccion abarca solamente logs Docker locales de RL-MON-01."

# ------------------------------------------------------------
# 14. Resultado
# ------------------------------------------------------------

docker compose ps

echo
echo "==========================================="
echo " INSTALACION FINALIZADA"
echo "==========================================="
echo
echo "Servidor: $SERVER"
echo
echo "OpenSearch:"
echo " http://${SERVER_IP}:9200"
echo
echo "Dashboards:"
echo " http://${SERVER_IP}:5601"
echo
echo "Fluent Bit:"
echo " Recolectando logs locales de $SERVER"
echo
echo "Indice:"
echo " recoleccion-logs-AAAA.MM.DD"
echo
echo "Verificacion:"
echo " cd $BASE"
echo " docker compose ps"
echo " docker compose logs --tail=50"
echo
echo "IMPORTANTE:"
echo " HTTP sin autenticacion."
echo " Restringir acceso mediante firewall."
echo "==========================================="