#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-APP-01
# Script: Node Exporter - Metricas de la VM
#
# OBJETIVO:
#   Instalar Node Exporter para monitorear los recursos
#   del servidor fisico/virtual RL-APP-01.
#
# BASADO EN:
#   Scripts/Linux/RL-MON-01/monitoreo_mv2.sh
#
# ORIGEN AUTORIZADO:
#   RL-MON-01: 192.168.20.20
#
# SERVIDOR MONITOREADO:
#   RL-APP-01: 192.168.30.20
#
# SERVICIO:
#   Node Exporter TCP/9100
#
# FUNCIONES:
#   1. Verificar permisos y sistema operativo.
#   2. Verificar identidad e IP de RL-APP-01.
#   3. Verificar Docker y Docker Compose.
#   4. Detectar instalaciones anteriores.
#   5. Verificar puerto TCP/9100.
#   6. Identificar interfaz y zona firewalld.
#   7. Verificar reglas de acceso.
#   8. Crear directorio de instalacion.
#   9. Crear Docker Compose.
#  10. Descargar e iniciar Node Exporter.
#  11. Verificar metricas del servidor.
#  12. Agregar regla permanente limitada.
#  13. Agregar regla runtime sin reload.
#  14. Verificar configuracion final.
#
# SEGURIDAD:
#   - No modifica otros proyectos Docker.
#   - No modifica las aplicaciones Laravel.
#   - No elimina contenedores existentes.
#   - No elimina volumenes Docker.
#   - No utiliza tuneles SSH.
#   - No modifica configuracion SSH.
#   - No modifica RL-FW-01.
#   - No ejecuta firewall-cmd --reload.
#   - No reinicia firewalld.
#   - No abre TCP/9100 para toda la zona.
#   - Solo agrega una regla para RL-MON-01.
#
# IMPORTANTE:
#   Node Exporter utiliza network_mode: host.
#   Solo escucha en 192.168.30.20:9100.
#
#   La regla local permite a RL-MON-01 consultar
#   las metricas del servidor.
#
#   RL-FW-01 debe permitir adicionalmente el trafico
#   entre rec-monitoreo y rec-apps hacia TCP/9100.
#
#   Este script no configura dicho firewall central.
#
# REEJECUCION:
#   No sobrescribe instalaciones anteriores.
#   Una instalacion parcial requiere revision antes
#   de volver a ejecutar.
# ============================================================

export LC_ALL=C

# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

readonly SERVER="RL-APP-01"

readonly APP_IP="192.168.30.20"
readonly MON_IP="192.168.20.20"

readonly PORT="9100"

readonly DIR="/opt/recoleccion-uy/node-exporter"
readonly COMPOSE_FILE="$DIR/compose.yaml"

readonly CONTAINER="node-exporter"
readonly IMAGE="prom/node-exporter:v1.9.1"

readonly RULE="rule family=\"ipv4\" source address=\"${MON_IP}/32\" port port=\"${PORT}\" protocol=\"tcp\" accept"

IFACE=""
ZONE=""

PERMANENT_ADDED=false
RUNTIME_ADDED=false
COMPLETED=false

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

    show_header "ERROR DURANTE LA EJECUCION"

    show_error "Linea: $line"
    show_error "Codigo: $status"
    show_error "No fue posible completar la instalacion."

    echo
    show_warning "No se eliminaran contenedores ni archivos."
    show_warning "Revisar el estado antes de reejecutar."

    exit "$status"
}

trap 'error_handler "$LINENO"' ERR

# ============================================================
# 4. VERIFICAR PRIVILEGIOS Y SISTEMA
# ============================================================

show_header "Recoleccion UY - Node Exporter RL-APP-01"

[[ "$EUID" -eq 0 ]] ||
    die "Ejecutar como root."

[[ -r /etc/os-release ]] ||
    die "No se puede identificar el sistema operativo."

# shellcheck source=/etc/os-release
source /etc/os-release

[[ "${ID:-}" == "rocky" ]] ||
    die "Se requiere Rocky Linux."

[[ "${VERSION_ID%%.*}" == "9" ]] ||
    die "Se requiere Rocky Linux 9."

show_ok "Rocky Linux 9 verificado."

# ============================================================
# 5. VERIFICAR HERRAMIENTAS
# ============================================================

show_header "Verificando herramientas"

REQUIRED_COMMANDS=(
    ip
    hostname
    docker
    curl
    firewall-cmd
    systemctl
    ss
)

for CMD in "${REQUIRED_COMMANDS[@]}"; do

    command -v "$CMD" >/dev/null 2>&1 ||
        die "Falta herramienta: $CMD"

    show_ok "$CMD disponible."

done

# ============================================================
# 6. VERIFICAR SERVIDOR E IP
# ============================================================

show_header "Verificando RL-APP-01"

HOST_ACTUAL="$(hostname -s)"
HOST_ACTUAL="${HOST_ACTUAL,,}"

[[ "$HOST_ACTUAL" == "rl-app-01" ]] ||
    die "Servidor incorrecto: $HOST_ACTUAL"

IP_CONFIGURADAS="$(
    ip -4 -o addr show
)" || die "No se pudieron consultar direcciones IPv4."

if ! grep -Fq "inet ${APP_IP}/" \
    <<< "$IP_CONFIGURADAS"; then

    show_error "No se encuentra la IP $APP_IP."

    echo
    echo "Direcciones detectadas:"
    echo "$IP_CONFIGURADAS"

    exit 1

fi

show_ok "Servidor verificado: RL-APP-01."
show_ok "Direccion IP encontrada: $APP_IP."

# ============================================================
# 7. DETECTAR INTERFAZ DE RED
# ============================================================

show_header "Identificando interfaz"

IFACE="$(
    ip -4 -o addr show |
        awk -v target="$APP_IP" '
        {
            split($4, address, "/")
            if (address[1] == target) {
                print $2
                exit
            }
        }'
)"

[[ -n "$IFACE" ]] ||
    die "No se pudo identificar interfaz de $APP_IP."

show_ok "Interfaz detectada: $IFACE"

# ============================================================
# 8. VERIFICAR DOCKER
# ============================================================

show_header "Verificando Docker"

systemctl is-active --quiet docker ||
    die "Docker no esta activo."

docker info >/dev/null 2>&1 ||
    die "Docker Engine no responde."

docker compose version >/dev/null 2>&1 ||
    die "Falta Docker Compose plugin."

show_ok "Docker Engine disponible."
show_ok "Docker Compose disponible."

docker --version
docker compose version

# ============================================================
# 9. VERIFICAR FIREWALLD
# ============================================================

show_header "Verificando Firewalld"

systemctl is-active --quiet firewalld ||
    die "Firewalld no esta activo."

firewall-cmd --state >/dev/null 2>&1 ||
    die "Firewalld no responde."

show_ok "Firewalld activo."

# ============================================================
# 10. DETECTAR ZONA DE FIREWALL
# ============================================================

show_header "Identificando zona de firewall"

ZONE="$(
    firewall-cmd \
        --get-zone-of-interface="$IFACE" 2>/dev/null
)" || true

if [[ -z "$ZONE" || "$ZONE" == "no zone" ]]; then

    ZONE="$(
        firewall-cmd --get-default-zone
    )" || die "No se pudo consultar zona predeterminada."

    show_warning "Interfaz sin zona especifica."
    show_warning "Se utilizara zona predeterminada: $ZONE"

fi

[[ -n "$ZONE" ]] ||
    die "No se pudo identificar zona."

show_ok "Zona activa: $ZONE"

# ============================================================
# 11. VERIFICAR INSTALACIONES ANTERIORES
# ============================================================

show_header "Verificando instalaciones anteriores"

if [[ -e "$DIR" ]]; then

    die "Ya existe $DIR. No se sobrescribe."

fi

if docker container inspect "$CONTAINER" \
    >/dev/null 2>&1; then

    die "Ya existe el contenedor $CONTAINER."

fi

show_ok "No se detectaron instalaciones anteriores."

# ============================================================
# 12. VERIFICAR PUERTO TCP/9100
# ============================================================

show_header "Verificando puerto TCP/$PORT"

PORT_LISTENERS="$(
    ss -H -ltn "sport = :$PORT"
)" || die "No se pudo consultar el puerto."

if [[ -n "$PORT_LISTENERS" ]]; then

    show_error "El puerto TCP/$PORT esta ocupado."

    echo
    echo "$PORT_LISTENERS"

    exit 1

fi

show_ok "Puerto TCP/$PORT disponible."

# ============================================================
# 13. VERIFICAR REGLAS EXISTENTES
# ============================================================

show_header "Verificando reglas de acceso"

# No agregar una regla especifica si el puerto
# ya esta abierto para toda la zona.

if firewall-cmd \
    --zone="$ZONE" \
    --query-port="${PORT}/tcp" \
    >/dev/null 2>&1; then

    die "TCP/$PORT ya esta abierto para toda la zona."

fi

if firewall-cmd \
    --permanent \
    --zone="$ZONE" \
    --query-port="${PORT}/tcp" \
    >/dev/null 2>&1; then

    die "TCP/$PORT ya esta abierto permanentemente para toda la zona."

fi

show_ok "No se detecto apertura general directa TCP/$PORT."

# Esta comprobacion no descarta accesos otorgados
# por otras reglas, servicios o politicas existentes.
# No se modifica ninguno de ellos.

# ============================================================
# 14. MOSTRAR CONFIGURACION
# ============================================================

show_header "Configuracion solicitada"

show_info "Servidor: $SERVER"
show_info "IP: $APP_IP"
show_info "Interfaz: $IFACE"
show_info "Zona: $ZONE"
show_info "Contenedor: $CONTAINER"
show_info "Imagen: $IMAGE"
show_info "Puerto: TCP/$PORT"
show_info "Origen autorizado por nueva regla: $MON_IP"

echo
show_info "No se modificaran otros proyectos Docker."
show_info "No se modificara RL-FW-01."

# ============================================================
# 15. CREAR DIRECTORIO
# ============================================================

show_header "Preparando directorio"

mkdir -p "$DIR"

chmod 755 "$DIR"

show_ok "Directorio creado: $DIR"

# ============================================================
# 16. CREAR DOCKER COMPOSE
# ============================================================

show_header "Creando Docker Compose"

cat > "$COMPOSE_FILE" <<EOF
name: recoleccion-node-exporter-app

services:

  node-exporter:

    image: ${IMAGE}

    container_name: ${CONTAINER}

    restart: unless-stopped

    network_mode: host
    pid: host

    volumes:
      - /:/host:ro,rslave

    command:
      - --path.rootfs=/host
      - --web.listen-address=${APP_IP}:${PORT}
      - '--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)'
EOF

chmod 644 "$COMPOSE_FILE"

show_ok "Docker Compose creado."

# ============================================================
# 17. VALIDAR DOCKER COMPOSE
# ============================================================

show_header "Validando configuracion Docker"

docker compose \
    -f "$COMPOSE_FILE" \
    config --quiet ||
    die "Configuracion Compose invalida."

show_ok "Docker Compose validado."

# ============================================================
# 18. DESCARGAR IMAGEN
# ============================================================

show_header "Descargando Node Exporter"

docker compose \
    -f "$COMPOSE_FILE" \
    pull

show_ok "Imagen descargada."

# ============================================================
# 19. INICIAR NODE EXPORTER
# ============================================================

show_header "Iniciando Node Exporter"

docker compose \
    -f "$COMPOSE_FILE" \
    up -d

show_ok "Despliegue iniciado."

# ============================================================
# 20. VERIFICAR CONTENEDOR
# ============================================================

show_header "Verificando contenedor"

CONTAINER_ID="$(
    docker compose \
        -f "$COMPOSE_FILE" \
        ps -q node-exporter
)"

[[ -n "$CONTAINER_ID" ]] ||
    die "No se encontro contenedor Node Exporter."

STATE="$(
    docker inspect \
        -f '{{.State.Status}}' \
        "$CONTAINER_ID"
)"

[[ "$STATE" == "running" ]] ||
    die "Node Exporter no esta ejecutandose."

docker compose \
    -f "$COMPOSE_FILE" \
    ps

show_ok "Node Exporter ejecutandose."

# ============================================================
# 21. VERIFICAR METRICAS LOCALES
# ============================================================

show_header "Verificando endpoint de metricas"

METRICS_OK=false

for ATTEMPT in {1..15}; do

    if curl \
        --noproxy '*' \
        --connect-timeout 2 \
        --max-time 5 \
        -fsS \
        "http://${APP_IP}:${PORT}/metrics" \
        -o /dev/null; then

        METRICS_OK=true
        break

    fi

    sleep 2

done

if [[ "$METRICS_OK" != true ]]; then

    show_error "Node Exporter no responde."

    echo
    echo "Consultar registros:"
    echo "  docker logs $CONTAINER"

    exit 1

fi

show_ok "Node Exporter entrega metricas."

# ============================================================
# 22. CONFIGURAR REGLA PERMANENTE
# ============================================================

show_header "Configurando Firewall permanente"

if firewall-cmd \
    --permanent \
    --zone="$ZONE" \
    --query-rich-rule="$RULE" \
    >/dev/null 2>&1; then

    show_ok "Regla permanente existente."

else

    firewall-cmd \
        --permanent \
        --zone="$ZONE" \
        --add-rich-rule="$RULE" ||
        die "No se pudo agregar regla permanente."

    PERMANENT_ADDED=true

    show_ok "Regla permanente agregada."

fi

# ============================================================
# 23. CONFIGURAR REGLA RUNTIME
# ============================================================

show_header "Configurando Firewall runtime"

if firewall-cmd \
    --zone="$ZONE" \
    --query-rich-rule="$RULE" \
    >/dev/null 2>&1; then

    show_ok "Regla runtime existente."

else

    firewall-cmd \
        --zone="$ZONE" \
        --add-rich-rule="$RULE" ||
        die "No se pudo agregar regla runtime."

    RUNTIME_ADDED=true

    show_ok "Regla runtime agregada."

fi

# ============================================================
# 24. VERIFICAR REGLAS
# ============================================================

show_header "Verificando reglas de Firewall"

firewall-cmd \
    --permanent \
    --zone="$ZONE" \
    --query-rich-rule="$RULE" \
    >/dev/null 2>&1 ||
    die "Regla permanente no confirmada."

firewall-cmd \
    --zone="$ZONE" \
    --query-rich-rule="$RULE" \
    >/dev/null 2>&1 ||
    die "Regla runtime no confirmada."

firewall-cmd --check-config >/dev/null ||
    die "Configuracion Firewalld invalida."

show_ok "Regla permanente confirmada."
show_ok "Regla runtime confirmada."
show_ok "Firewalld validado."

# ============================================================
# 25. VERIFICACION FINAL
# ============================================================

show_header "Verificando estado final"

docker compose \
    -f "$COMPOSE_FILE" \
    ps

curl \
    --noproxy '*' \
    --connect-timeout 2 \
    --max-time 8 \
    -fsS \
    "http://${APP_IP}:${PORT}/metrics" \
    -o /dev/null ||
    die "Node Exporter dejo de responder."

show_ok "Node Exporter operativo."

COMPLETED=true

# ============================================================
# 26. RESULTADO FINAL
# ============================================================

show_header "CONFIGURACION FINALIZADA"

echo
echo "Servidor:"
echo "  RL-APP-01"
echo "  $APP_IP"

echo
echo "Interfaz:"
echo "  $IFACE"

echo
echo "Firewall:"
echo "  Zona: $ZONE"
echo "  Origen permitido por regla: $MON_IP"
echo "  Puerto: TCP/$PORT"

echo
echo "Contenedor:"
echo "  $CONTAINER"

echo
echo "Imagen:"
echo "  $IMAGE"

echo
echo "Endpoint:"
echo "  http://${APP_IP}:${PORT}/metrics"

echo
echo "Directorio:"
echo "  $DIR"

echo
echo "Reglas:"
echo "  Permanente agregada: $PERMANENT_ADDED"
echo "  Runtime agregada   : $RUNTIME_ADDED"

echo
echo "Administracion:"
echo "  docker compose -f $COMPOSE_FILE ps"
echo "  docker compose -f $COMPOSE_FILE logs"
echo "  docker compose -f $COMPOSE_FILE restart"

echo
echo "IMPORTANTE:"
echo "  RL-MON-01 debe consultar TCP/$PORT."
echo "  RL-FW-01 debe permitir rec-monitoreo -> rec-apps."
echo "  Verificar el permiso correspondiente en RL-FW-01."
echo "  Este script no configura el firewall central."

echo
echo "Seguridad:"
echo "  No se modificaron otros contenedores."
echo "  No se modificaron aplicaciones Laravel."
echo "  No se modifico SSH."
echo "  No se realizaron tuneles."
echo "  No se ejecuto firewall-cmd --reload."
echo "  No se reinicio Firewalld."

echo
show_ok "Node Exporter instalado correctamente."
echo