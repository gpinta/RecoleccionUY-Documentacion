#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-MON-01
# Script: 3-RL-MON-monitoreo.sh
#
# PASS: Administrador2026
#
# OBJETIVO:
#   Instalar y configurar:
#   - Prometheus
#   - Grafana
#   - Node Exporter local
#   - Dashboard Node Exporter Full ID 1860
#
# BASADO EN:
#   monitoreo_mv1.sh
#   monitoreo_mv2.sh
#
# SERVIDORES MONITOREADOS:
#   RL-MON-01    192.168.20.20
#   RL-APP-01    192.168.30.20
#   RL-PROXY-01  192.168.50.20
#
# PUERTOS:
#   Grafana       TCP/3000
#   Prometheus    TCP/9090 - solo localhost
#   Node Exporter TCP/9100
#
# IMPORTANTE:
#   - Ejecutar como root en RL-MON-01.
#   - Requiere Rocky Linux 9.
#   - No modifica la red.
#   - No modifica Active Directory.
#   - No modifica SSH.
#   - No utiliza tuneles SSH.
#   - No modifica firewalld.
#   - No modifica RL-FW-01.
#   - No instala componentes en otros servidores.
#   - No elimina contenedores existentes.
#   - No ejecuta docker compose down.
#   - No elimina volumenes Docker.
#
# CORRECCIONES:
#   - Validacion IPv4 compatible con pipefail.
#   - Verificacion de IP mediante salida capturada.
#   - Verificacion de puertos disponibles.
#   - Permisos de directorios de Grafana.
#   - Validacion de Docker y Compose.
#   - Verificacion de endpoints HTTP.
#   - Validacion de targets Prometheus.
#   - Proteccion de despliegues anteriores.
#
# REQUISITOS:
#   - Docker y Docker Compose.
#   - IP 192.168.20.20 configurada.
#   - Puertos locales disponibles.
#   - Conectividad al registro de imagenes Docker.
#
# NOTA:
#   RL-APP-01 y RL-PROXY-01 apareceran DOWN
#   hasta disponer de Node Exporter accesible.
#
#   El acceso remoto a Grafana y Node Exporter
#   dependera de las politicas de firewall.
# ============================================================

export LC_ALL=C

# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

readonly SERVER="RL-MON-01"

readonly MON_IP="192.168.20.20"
readonly APP_IP="192.168.30.20"
readonly PROXY_IP="192.168.50.20"

readonly BASE="/opt/recoleccion-uy/monitoring"

readonly DOCKER_REPO_URL="https://download.docker.com/linux/centos/docker-ce.repo"
readonly DOCKER_REPO_FILE="/etc/yum.repos.d/docker-ce.repo"

readonly DASHBOARD_URL="https://grafana.com/api/dashboards/1860/revisions/latest/download"

readonly -a BASIC_PACKAGES=(
    curl
    iproute
    python3
)

readonly -a DOCKER_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

readonly -a REQUIRED_PORTS=(
    3000
    9090
    9100
)

readonly -a REQUIRED_CONTAINERS=(
    prometheus
    grafana
    node-exporter
)

DASHBOARD_OK=false
ENDPOINT_ERROR=0

# ============================================================
# 2. FUNCIONES GENERALES
# ============================================================

show_header() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

show_ok() {
    echo "[OK] $1"
}

show_info() {
    echo "[INFO] $1"
}

show_warning() {
    echo "[ADVERTENCIA] $1" >&2
}

show_error() {
    echo "[ERROR] $1" >&2
}

die() {
    show_error "$1"
    exit 1
}

# ============================================================
# 3. MANEJO GENERAL DE ERRORES
# ============================================================

error_handler() {

    local status=$?
    local line="$1"

    trap - ERR

    echo
    show_header "ERROR DURANTE LA EJECUCION"

    show_error "Linea: $line"
    show_error "Codigo: $status"
    show_error "La instalacion no pudo completarse."

    echo
    echo "No se eliminaran volumenes ni contenedores."
    echo "Revisar el estado antes de reejecutar."

    exit "$status"
}

trap 'error_handler "$LINENO"' ERR

# ============================================================
# 4. VERIFICAR PRIVILEGIOS Y SERVIDOR
# ============================================================

show_header "Recoleccion UY - Monitoreo RL-MON-01"

[[ "$EUID" -eq 0 ]] ||
    die "Ejecutar como root."

[[ -r /etc/os-release ]] ||
    die "No se encuentra /etc/os-release."

# shellcheck source=/etc/os-release
source /etc/os-release

[[ "${ID:-}" == "rocky" ]] ||
    die "Se requiere Rocky Linux."

[[ "${VERSION_ID%%.*}" == "9" ]] ||
    die "Se requiere Rocky Linux 9."

HOST_ACTUAL="$(hostname -s)"

[[ "${HOST_ACTUAL,,}" == "rl-mon-01" ]] ||
    die "Hostname incorrecto: $HOST_ACTUAL. Ejecutar en RL-MON-01."

command -v ip >/dev/null 2>&1 ||
    die "No se encuentra el comando ip."

# ------------------------------------------------------------
# CORRECCION DE VALIDACION IPv4
#
# No utilizar:
#
#   ip -4 -o addr show | grep -Fq ...
#
# Con pipefail, grep -q puede cerrar la tuberia antes
# de que ip termine de escribir, produciendo SIGPIPE.
#
# Se captura primero la salida completa y posteriormente
# se realiza la comparacion.
# ------------------------------------------------------------

show_info "Verificando direccion IPv4 del servidor..."

IP_CONFIGURADAS="$(
    ip -4 -o addr show
)" || die "No se pudieron consultar direcciones IPv4."

if grep -Fq "inet ${MON_IP}/" <<< "$IP_CONFIGURADAS"; then

    show_ok "Direccion IP $MON_IP encontrada."

else

    show_error "No se encuentra la IP $MON_IP."

    echo
    echo "Direcciones IPv4 detectadas:"
    echo "$IP_CONFIGURADAS"

    exit 1

fi

show_ok "Servidor RL-MON-01 verificado."
show_ok "Rocky Linux 9 detectado."

# ============================================================
# 5. VERIFICAR INSTALACIONES EXISTENTES
# ============================================================

show_header "Verificando instalaciones anteriores"

for FILE in \
    "$BASE/compose.yaml" \
    "$BASE/compose.yml" \
    "$BASE/docker-compose.yml" \
    "$BASE/prometheus.yml" \
    "$BASE/.grafana.env" \
    "$BASE/grafana/provisioning/datasources/prometheus.yml" \
    "$BASE/grafana/provisioning/dashboards/dashboard.yml" \
    "$BASE/grafana/dashboards/node-exporter-full.json" \
    "$BASE/grafana/dashboards/dashboard_basico.json"
do

    [[ ! -e "$FILE" ]] ||
        die "Ya existe $FILE. Revisar antes de sobrescribir."

done

if command -v docker >/dev/null 2>&1; then

    if docker info >/dev/null 2>&1; then

        for NAME in "${REQUIRED_CONTAINERS[@]}"; do

            if docker container inspect "$NAME" \
                >/dev/null 2>&1; then

                die "Ya existe el contenedor $NAME."

            fi

        done

    fi

fi

show_ok "No se detectaron archivos de despliegue anteriores."

# ============================================================
# 6. INSTALAR HERRAMIENTAS BASICAS
# ============================================================

show_header "Instalando herramientas basicas"

dnf install -y "${BASIC_PACKAGES[@]}"

show_ok "Herramientas basicas disponibles."

# ============================================================
# 7. VERIFICAR PUERTOS LOCALES
# ============================================================

show_header "Verificando puertos locales"

command -v ss >/dev/null 2>&1 ||
    die "No se encuentra el comando ss."

for PORT in "${REQUIRED_PORTS[@]}"; do

    PORT_LISTENERS="$(
        ss -H -ltn "sport = :$PORT"
    )" || die "No se pudo consultar TCP/$PORT."

    if [[ -n "$PORT_LISTENERS" ]]; then

        die "Puerto TCP/$PORT ocupado."

    fi

    show_ok "Puerto TCP/$PORT disponible."

done

# ============================================================
# 8. INSTALAR O VERIFICAR DOCKER
# ============================================================

show_header "Verificando Docker"

if ! command -v docker >/dev/null 2>&1 ||
   ! docker compose version >/dev/null 2>&1; then

    show_info "Instalando Docker y Docker Compose."

    dnf install -y dnf-plugins-core

    if [[ ! -f "$DOCKER_REPO_FILE" ]]; then

        dnf config-manager \
            --add-repo "$DOCKER_REPO_URL"

    fi

    dnf install -y "${DOCKER_PACKAGES[@]}"

fi

systemctl enable --now docker

docker info >/dev/null 2>&1 ||
    die "Docker Engine no responde."

docker compose version >/dev/null 2>&1 ||
    die "Docker Compose no esta disponible."

show_ok "Docker Engine disponible."
show_ok "Docker Compose disponible."

docker --version
docker compose version

# Verificar nuevamente contenedores una vez iniciado Docker.

for NAME in "${REQUIRED_CONTAINERS[@]}"; do

    if docker container inspect "$NAME" \
        >/dev/null 2>&1; then

        die "Ya existe contenedor $NAME. No se sobrescribe."

    fi

done

# ============================================================
# 9. CONFIGURAR CREDENCIALES DE GRAFANA
# ============================================================

show_header "Configurando credenciales de Grafana"

[[ -t 0 ]] ||
    die "Se requiere consola interactiva."

echo
echo "Definir contrasena inicial del administrador Grafana."
echo "Longitud minima: 12 caracteres."
echo "Caracteres admitidos:"
echo "Letras, numeros y @ _ + = . , : ! -"
echo

GRAFANA_PASSWORD=""

read -r -s -p "Contrasena Grafana: " \
    GRAFANA_PASSWORD

echo

if [[ ${#GRAFANA_PASSWORD} -lt 12 ]] ||
   [[ ! "$GRAFANA_PASSWORD" =~ ^[a-zA-Z0-9@_+=.,:!-]+$ ]]; then

    unset GRAFANA_PASSWORD
    die "Contrasena no cumple los requisitos."

fi

show_ok "Contrasena validada."

# ============================================================
# 10. CREAR DIRECTORIOS
# ============================================================

show_header "Creando estructura de monitoreo"

install -d -m 0755 \
    "$BASE" \
    "$BASE/grafana" \
    "$BASE/grafana/provisioning" \
    "$BASE/grafana/provisioning/datasources" \
    "$BASE/grafana/provisioning/dashboards" \
    "$BASE/grafana/dashboards"

# Grafana utiliza un usuario no root.
# Sus directorios de configuracion requieren lectura.
# El archivo de credenciales permanece restringido.

printf 'GF_SECURITY_ADMIN_USER=admin\nGF_SECURITY_ADMIN_PASSWORD=%s\n' \
    "$GRAFANA_PASSWORD" > "$BASE/.grafana.env"

chmod 600 "$BASE/.grafana.env"

unset GRAFANA_PASSWORD

show_ok "Directorios y credenciales preparados."

# ============================================================
# 11. CONFIGURAR PROMETHEUS
# ============================================================

show_header "Configurando Prometheus"

cat > "$BASE/prometheus.yml" <<'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: prometheus
    static_configs:
      - targets:
          - localhost:9090

  - job_name: node
    static_configs:

      - targets:
          - 192.168.20.20:9100
        labels:
          servidor: RL-MON-01

      - targets:
          - 192.168.30.20:9100
        labels:
          servidor: RL-APP-01

      - targets:
          - 192.168.50.20:9100
        labels:
          servidor: RL-PROXY-01
YAML

chmod 644 "$BASE/prometheus.yml"

show_ok "Prometheus configurado."

# ============================================================
# 12. CONFIGURAR DATASOURCE DE GRAFANA
# ============================================================

show_header "Configurando datasource Grafana"

cat > "$BASE/grafana/provisioning/datasources/prometheus.yml" <<'YAML'
apiVersion: 1

datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
YAML

chmod 644 \
    "$BASE/grafana/provisioning/datasources/prometheus.yml"

show_ok "Datasource Prometheus configurado."

# ============================================================
# 13. CONFIGURAR PROVIDER DE DASHBOARDS
# ============================================================

show_header "Configurando dashboards"

cat > "$BASE/grafana/provisioning/dashboards/dashboard.yml" <<'YAML'
apiVersion: 1

providers:
  - name: Node Exporter
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
YAML

chmod 644 \
    "$BASE/grafana/provisioning/dashboards/dashboard.yml"

show_ok "Provider de dashboards configurado."

# ============================================================
# 14. DESCARGAR DASHBOARD NODE EXPORTER FULL
# ============================================================

show_header "Instalando dashboard Node Exporter Full"

DASHBOARD_FILE="$BASE/grafana/dashboards/node-exporter-full.json"

if timeout 30 curl \
    --connect-timeout 10 \
    -fsSL \
    "$DASHBOARD_URL" \
    -o "$DASHBOARD_FILE"; then

    if python3 - "$DASHBOARD_FILE" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as f:
    data = json.load(f)

if not isinstance(data, dict) or "panels" not in data:
    raise ValueError("El JSON no es un dashboard valido")

def normalize(obj):
    if isinstance(obj, dict):
        for key, value in list(obj.items()):
            if key == "datasource":
                if isinstance(value, str):
                    if value.startswith("${DS_") or value == "Prometheus":
                        obj[key] = {
                            "type": "prometheus",
                            "uid": "prometheus"
                        }
                elif isinstance(value, dict):
                    uid = value.get("uid")
                    if isinstance(uid, str) and (
                        uid.startswith("${DS_") or uid == "Prometheus"
                    ):
                        value["type"] = "prometheus"
                        value["uid"] = "prometheus"
            normalize(obj[key])

    elif isinstance(obj, list):
        for item in obj:
            normalize(item)

normalize(data)

data.pop("__inputs", None)
data.pop("id", None)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PY
    then

        DASHBOARD_OK=true

        chmod 644 "$DASHBOARD_FILE"

        show_ok "Dashboard 1860 descargado y adaptado."

    else

        show_warning "El dashboard descargado no pudo adaptarse."

    fi

else

    show_warning "No se pudo descargar dashboard 1860."

fi

# ============================================================
# 15. DASHBOARD BASICO DE RESPALDO
# ============================================================

if [[ "$DASHBOARD_OK" != true ]]; then

    show_header "Creando dashboard basico"

    rm -f "$DASHBOARD_FILE"

    cat > "$BASE/grafana/dashboards/dashboard_basico.json" <<'JSON'
{
  "title": "Monitoreo Recoleccion UY",
  "uid": "recoleccion-uy-basico",
  "schemaVersion": 39,
  "version": 1,
  "tags": ["RecoleccionUY"],
  "panels": [
    {
      "type": "text",
      "title": "Monitoreo Recoleccion UY",
      "gridPos": {
        "h": 6,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "options": {
        "mode": "markdown",
        "content": "Dashboard basico. Importar Node Exporter Full ID 1860 cuando exista conectividad."
      }
    }
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  }
}
JSON

    chmod 644 \
        "$BASE/grafana/dashboards/dashboard_basico.json"

    show_ok "Dashboard basico creado."

fi

# ============================================================
# 16. CREAR DOCKER COMPOSE
# ============================================================

show_header "Creando Docker Compose"

cat > "$BASE/compose.yaml" <<'YAML'
name: recoleccion-monitoring

services:

  # ----------------------------------------------------------
  # NODE EXPORTER - RL-MON-01
  # ----------------------------------------------------------

  node-exporter:
    image: prom/node-exporter:v1.9.1
    restart: unless-stopped
    network_mode: host
    pid: host

    volumes:
      - /:/host:ro,rslave

    command:
      - --path.rootfs=/host
      - --web.listen-address=192.168.20.20:9100
      - '--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)'

  # ----------------------------------------------------------
  # PROMETHEUS
  # ----------------------------------------------------------

  prometheus:
    image: prom/prometheus:v3.4.2
    restart: unless-stopped

    ports:
      - "127.0.0.1:9090:9090"

    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro,Z
      - prometheus_data:/prometheus

    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=15d

  # ----------------------------------------------------------
  # GRAFANA
  # ----------------------------------------------------------

  grafana:
    image: grafana/grafana:12.0.2
    restart: unless-stopped

    depends_on:
      - prometheus

    env_file:
      - .grafana.env

    ports:
      - "192.168.20.20:3000:3000"

    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro,Z
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro,Z

volumes:
  prometheus_data:
  grafana_data:
YAML

chmod 644 "$BASE/compose.yaml"

show_ok "Docker Compose creado."

# ============================================================
# 17. VALIDAR DOCKER COMPOSE
# ============================================================

show_header "Validando Docker Compose"

cd "$BASE"

docker compose config --quiet ||
    die "La configuracion Compose no es valida."

show_ok "Docker Compose validado."

# ============================================================
# 18. DESCARGAR IMAGENES
# ============================================================

show_header "Descargando imagenes Docker"

docker compose pull

show_ok "Imagenes descargadas."

# ============================================================
# 19. INICIAR SERVICIOS
# ============================================================

show_header "Iniciando servicios de monitoreo"

docker compose up -d

show_ok "Despliegue Docker iniciado."

# ============================================================
# 20. VERIFICAR CONTENEDORES
# ============================================================

show_header "Verificando contenedores"

docker compose ps

for SERVICE in \
    prometheus \
    grafana \
    node-exporter
do

    CONTAINER_ID="$(
        docker compose ps -q "$SERVICE"
    )"

    [[ -n "$CONTAINER_ID" ]] ||
        die "No existe el contenedor de $SERVICE."

    STATE="$(
        docker inspect \
            -f '{{.State.Status}}' \
            "$CONTAINER_ID"
    )"

    [[ "$STATE" == "running" ]] ||
        die "Contenedor $SERVICE no esta ejecutandose."

    show_ok "$SERVICE ejecutandose."

done

# ============================================================
# 21. VERIFICAR ENDPOINTS HTTP
# ============================================================

show_header "Verificando servicios HTTP"

check_endpoint() {

    local name="$1"
    local url="$2"
    local attempts=15
    local i

    for ((i=1; i<=attempts; i++)); do

        if curl \
            --noproxy '*' \
            --connect-timeout 2 \
            --max-time 4 \
            -fsS \
            "$url" \
            >/dev/null 2>&1; then

            show_ok "$name responde correctamente."
            return 0

        fi

        sleep 2

    done

    show_warning "$name no responde: $url"
    return 1
}

check_endpoint \
    "Prometheus" \
    "http://127.0.0.1:9090/-/healthy" ||
    ENDPOINT_ERROR=1

check_endpoint \
    "Node Exporter" \
    "http://${MON_IP}:9100/metrics" ||
    ENDPOINT_ERROR=1

check_endpoint \
    "Grafana" \
    "http://${MON_IP}:3000/api/health" ||
    ENDPOINT_ERROR=1

# ============================================================
# 22. VERIFICAR TARGETS PROMETHEUS
# ============================================================

show_header "Verificando targets Prometheus"

TARGETS_FILE="$(mktemp)"

if curl \
    --noproxy '*' \
    -fsS \
    --max-time 10 \
    "http://127.0.0.1:9090/api/v1/targets" \
    -o "$TARGETS_FILE"; then

    python3 - "$TARGETS_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

targets = data.get("data", {}).get("activeTargets", [])

if not targets:
    print("[ADVERTENCIA] Todavia no hay targets activos.")
else:
    for target in targets:
        labels = target.get("labels", {})
        name = labels.get(
            "servidor",
            labels.get("job", "desconocido")
        )
        endpoint = target.get("scrapeUrl", "")
        state = target.get("health", "unknown")

        print(f"[TARGET] {name}: {state} - {endpoint}")
PY

else

    show_warning "No fue posible consultar targets de Prometheus."

fi

rm -f "$TARGETS_FILE"

# ============================================================
# 23. VERIFICAR SELINUX
# ============================================================

show_header "Verificando SELinux"

if command -v getenforce >/dev/null 2>&1; then

    SELINUX_STATUS="$(getenforce)"

    echo "Estado SELinux: $SELINUX_STATUS"

    case "$SELINUX_STATUS" in

        Enforcing)
            show_ok "SELinux Enforcing."
            ;;

        Permissive)
            show_warning "SELinux Permissive."
            ;;

        Disabled)
            show_warning "SELinux deshabilitado."
            ;;

        *)
            show_warning "Estado SELinux desconocido."
            ;;

    esac

fi

# ============================================================
# 24. RESULTADO FINAL
# ============================================================

show_header "RESULTADO FINAL"

echo
echo "Servidor:"
echo "  RL-MON-01"
echo "  $MON_IP"

echo
echo "Directorio:"
echo "  $BASE"

echo
echo "Servicios:"
echo "  Prometheus"
echo "  Grafana"
echo "  Node Exporter"

echo
echo "Accesos:"
echo
echo "Grafana:"
echo "  http://${MON_IP}:3000"
echo
echo "Prometheus local:"
echo "  http://127.0.0.1:9090"
echo
echo "Node Exporter:"
echo "  http://${MON_IP}:9100/metrics"

echo
echo "Administracion:"
echo
echo "  cd $BASE"
echo "  docker compose ps"
echo "  docker compose logs"
echo "  docker compose restart"

echo
echo "Targets configurados:"
echo
echo "  RL-MON-01    ${MON_IP}:9100"
echo "  RL-APP-01    ${APP_IP}:9100"
echo "  RL-PROXY-01  ${PROXY_IP}:9100"

echo
echo "Seguridad:"
echo "  No se modifico SSH."
echo "  No se modifico firewalld."
echo "  No se modifico RL-FW-01."
echo "  No se configuraron tuneles SSH."
echo "  No se eliminaron volumenes."
echo "  Prometheus solo publica en localhost."

echo
echo "IMPORTANTE:"
echo "  RL-APP-01 y RL-PROXY-01 requieren Node Exporter."
echo "  El acceso remoto requiere permisos de firewall."
echo "  Grafana se publica por HTTP."
echo "  Restringir el acceso o implementar HTTPS."

echo
echo "Dashboard:"

if [[ "$DASHBOARD_OK" == true ]]; then

    echo "  Node Exporter Full ID 1860"

else

    echo "  Dashboard basico de respaldo"

fi

echo

if [[ "$ENDPOINT_ERROR" -ne 0 ]]; then

    show_warning "Instalacion iniciada con verificaciones pendientes."
    show_warning "Revisar docker compose ps y logs."

    exit 1

fi

show_ok "Instalacion de monitoreo finalizada."

echo