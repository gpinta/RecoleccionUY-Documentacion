#!/bin/bash

# ============================================================
# Recoleccion UY - Configuracion RL-PROXY-01
#
# Topologia:
#
#   RL-PROXY-01 : 192.168.50.20/24
#   Gateway     : 192.168.50.1
#
#   RL-APP-01   : 192.168.30.20
#
#   Ciudadana   : 192.168.30.20:8080
#   Admin       : 192.168.30.20:8081
#
#   DNS AD:
#       192.168.10.20
#       192.168.10.21
#
# Configura:
#
# - Nginx Reverse Proxy en Docker
# - dnsmasq en Docker
# - Firewalld para HTTP y DNS
#
# IMPORTANTE:
#
# RL-PROXY-01 tiene una unica NIC de datos en DMZ.
#
# Este script NO:
#
# - Configura una segunda NIC
# - Configura NAT
# - Publica directamente hacia WAN
#
# La publicacion WAN se controla desde RL-FW-01.
#
# ============================================================


set -Eeuo pipefail


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

PROXY_DIR="/opt/recoleccion-proxy"


PROXY_CONTAINER="recoleccion_proxy"
DNS_CONTAINER="recoleccion_dns"


PROXY_IP="192.168.50.20"
PROXY_PREFIX="24"

PROXY_GATEWAY="192.168.50.1"


APP_SERVER_IP="192.168.30.20"

CIUDADANA_PORT="8080"
ADMIN_PORT="8081"
CAMIONES_PORT="8082"


CIUDADANA_HOST="recoleccion.neltek.uy"
ADMIN_HOST="admin-recoleccion.neltek.uy"
CAMIONES_HOST="camiones-recoleccion.neltek.uy"


DOMAIN="neltek.uy"

DC1_NAME="WS-DC-01"
DC2_NAME="WS-DC-02"

DNS_UPSTREAM_1="192.168.10.20"
DNS_UPSTREAM_2="192.168.10.21"


DNS_PUBLISHED_IP="${PROXY_IP}"


TCP_TIMEOUT="5"
STARTUP_TIMEOUT="30"


# ============================================================
# 2. FUNCIONES GENERALES
# ============================================================

show_header()
{
    echo ""
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}


show_ok()
{
    echo "[OK] $1"
}


show_info()
{
    echo "[INFO] $1"
}


show_warning()
{
    echo "[ADVERTENCIA] $1"
}


show_error()
{
    echo "[ERROR] $1"
}


fail()
{
    echo ""
    show_error "$*"
    echo ""

    exit 1
}


# ============================================================
# 3. MANEJO GENERAL DE ERRORES
# ============================================================

error_handler()
{
    local exit_code=$?
    local line_number=$1

    echo ""
    echo "============================================================"
    echo "ERROR DURANTE LA EJECUCION"
    echo "============================================================"
    echo ""
    echo "Linea   : ${line_number}"
    echo "Comando : ${BASH_COMMAND}"
    echo "Codigo  : ${exit_code}"
    echo ""

    if [[ "${exit_code}" -eq 141 ]]; then

        echo "Detalle:"
        echo ""
        echo "  Codigo 141 corresponde a SIGPIPE."
        echo ""
        echo "  Un comando intento escribir sobre una tuberia cuyo"
        echo "  receptor ya habia terminado."
        echo ""
    fi

    exit "${exit_code}"
}


trap 'error_handler $LINENO' ERR


# ============================================================
# 4. VERIFICAR COMANDO
# ============================================================

require_command()
{
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then

        fail "No se encontro el comando '${command_name}'."
    fi
}


# ============================================================
# 5. DETECTAR INTERFAZ DEL PROXY
#
# IMPORTANTE:
#
# No utilizamos:
#
#   ip ... | awk '... { exit }'
#
# porque con pipefail puede producir SIGPIPE / codigo 141.
# Primero capturamos toda la salida de ip y despues la
# procesamos mediante awk.
# ============================================================

detectar_interfaz_proxy()
{
    local ip_output
    local interface


    ip_output="$(
        ip -o -4 addr show
    )"


    interface="$(
        awk \
            -v ip="${PROXY_IP}" '
            $4 ~ ("^" ip "/") && !found {
                print $2
                found=1
            }
            ' <<< "${ip_output}"
    )"


    printf '%s\n' "${interface}"
}


# ============================================================
# 6. COMPROBAR TCP
# ============================================================

tcp_check()
{
    local host="$1"
    local port="$2"

    timeout "${TCP_TIMEOUT}" \
        bash -c "echo >/dev/tcp/${host}/${port}" \
        >/dev/null 2>&1
}


# ============================================================
# 7. ESPERAR CONTENEDOR
# ============================================================

wait_for_container()
{
    local container="$1"
    local waited=0
    local state


    while [[ "${waited}" -lt "${STARTUP_TIMEOUT}" ]]
    do

        state="$(
            docker inspect \
                -f '{{.State.Running}}' \
                "${container}" \
                2>/dev/null || true
        )"


        if [[ "${state}" == "true" ]]; then

            return 0
        fi


        sleep 1

        waited=$((waited + 1))

    done


    return 1
}


# ============================================================
# 8. ESPERAR PUERTO TCP
# ============================================================

wait_for_tcp()
{
    local host="$1"
    local port="$2"
    local waited=0


    while [[ "${waited}" -lt "${STARTUP_TIMEOUT}" ]]
    do

        if tcp_check "${host}" "${port}"; then

            return 0
        fi


        sleep 1

        waited=$((waited + 1))

    done


    return 1
}


# ============================================================
# 9. OBTENER PRIMER RESULTADO DNS
#
# Se evita:
#
#   dig ... | head -n 1
#
# para no provocar otro posible SIGPIPE con pipefail.
# ============================================================

get_first_dns_result()
{
    local dns_output
    local first_result


    dns_output="$(
        docker exec \
            "${DNS_CONTAINER}" \
            dig \
            +short \
            "@127.0.0.1" \
            "$1"
    )"


    first_result="$(
        awk '
            NF > 0 && !found {
                print
                found=1
            }
        ' <<< "${dns_output}"
    )"


    printf '%s\n' "${first_result}"
}


# ============================================================
# 10. INICIO
# ============================================================

show_header "Recoleccion UY - Configuracion RL-PROXY-01"


# ============================================================
# 11. VERIFICAR ROOT
# ============================================================

if [[ "$(id -u)" -ne 0 ]]; then

    fail "Debe ejecutar este script con sudo o como root."
fi


show_ok "Privilegios administrativos verificados."


# ============================================================
# 12. VERIFICAR DEPENDENCIAS
# ============================================================

show_header "1. Verificando dependencias"


REQUIRED_COMMANDS=(
    docker
    ip
    awk
    grep
    getent
    timeout
    systemctl
)


for command_name in "${REQUIRED_COMMANDS[@]}"
do

    require_command "${command_name}"

done


if systemctl is-active --quiet firewalld; then

    require_command firewall-cmd
fi


docker info >/dev/null 2>&1 \
    || fail "Docker esta instalado pero no esta funcionando."


docker compose version >/dev/null 2>&1 \
    || fail "Docker Compose v2 no esta disponible."


show_ok "Dependencias disponibles."
show_ok "Docker Engine operativo."
show_ok "Docker Compose v2 disponible."


# ============================================================
# 13. VERIFICAR IP E INTERFAZ
# ============================================================

show_header "2. Verificando interfaz DMZ"


PROXY_INTERFACE="$(
    detectar_interfaz_proxy
)"


if [[ -z "${PROXY_INTERFACE}" ]]; then

    fail "No se encontro ${PROXY_IP}/${PROXY_PREFIX} en ninguna interfaz."
fi


show_ok "Interfaz DMZ: ${PROXY_INTERFACE}"
show_ok "IP RL-PROXY-01: ${PROXY_IP}/${PROXY_PREFIX}"


# ============================================================
# 14. VERIFICAR RUTA DEFAULT
# ============================================================

show_header "3. Verificando gateway"


DEFAULT_ROUTES="$(
    ip -4 route show default
)"


DEFAULT_COUNT="$(
    awk '
        NF > 0 {
            count++
        }

        END {
            print count+0
        }
    ' <<< "${DEFAULT_ROUTES}"
)"


if [[ "${DEFAULT_COUNT}" -ne 1 ]]; then

    fail "Se esperaba una unica ruta default; se encontraron ${DEFAULT_COUNT}."
fi


echo "${DEFAULT_ROUTES}"


if [[ "${DEFAULT_ROUTES}" != *"via ${PROXY_GATEWAY}"* ]]; then

    fail "La ruta default no utiliza ${PROXY_GATEWAY}."
fi


if [[ "${DEFAULT_ROUTES}" != *"dev ${PROXY_INTERFACE}"* ]]; then

    fail "La ruta default no utiliza ${PROXY_INTERFACE}."
fi


show_ok "Gateway DMZ: ${PROXY_GATEWAY}"
show_ok "Default route: ${PROXY_INTERFACE}"


# ============================================================
# 15. VERIFICAR DNS ACTIVE DIRECTORY
# ============================================================

show_header "4. Validando DNS de Active Directory"


for dns_server in \
    "${DNS_UPSTREAM_1}" \
    "${DNS_UPSTREAM_2}"
do

    if tcp_check "${dns_server}" 53; then

        show_ok "TCP/53 accesible: ${dns_server}"

    else

        fail "No hay TCP/53 hacia DNS ${dns_server}."
    fi

done


if ! getent hosts \
    "${DC1_NAME}.${DOMAIN}" \
    >/dev/null 2>&1; then

    fail "No se puede resolver ${DC1_NAME}.${DOMAIN}."
fi


if ! getent hosts \
    "${DC2_NAME}.${DOMAIN}" \
    >/dev/null 2>&1; then

    fail "No se puede resolver ${DC2_NAME}.${DOMAIN}."
fi


show_ok "DNS de Active Directory accesible."


# ============================================================
# 16. VERIFICAR RUTA HACIA RL-APP
# ============================================================

show_header "5. Verificando ruta hacia RL-APP-01"


APP_ROUTE="$(
    ip route get "${APP_SERVER_IP}"
)"


echo "${APP_ROUTE}"


if [[ "${APP_ROUTE}" != *"via ${PROXY_GATEWAY}"* ]]; then

    fail "La ruta hacia ${APP_SERVER_IP} no pasa por ${PROXY_GATEWAY}."
fi


show_ok "Ruta hacia RL-APP-01 correcta."


# ============================================================
# 17. VERIFICAR BACKENDS
# ============================================================

show_header "6. Verificando aplicaciones backend"


if tcp_check "${APP_SERVER_IP}" "${CIUDADANA_PORT}"; then

    show_ok "Ciudadana: ${APP_SERVER_IP}:${CIUDADANA_PORT}"

else

    fail "Ciudadana no responde en ${APP_SERVER_IP}:${CIUDADANA_PORT}."
fi


if tcp_check "${APP_SERVER_IP}" "${ADMIN_PORT}"; then

    show_ok "Admin: ${APP_SERVER_IP}:${ADMIN_PORT}"

else

    fail "Admin no responde en ${APP_SERVER_IP}:${ADMIN_PORT}."
fi

# Camiones debe estar iniciado antes de reconfigurar el proxy.
if tcp_check "${APP_SERVER_IP}" "${CAMIONES_PORT}"; then

    show_ok "Camiones: ${APP_SERVER_IP}:${CAMIONES_PORT}"

else

    fail "Camiones no responde en ${APP_SERVER_IP}:${CAMIONES_PORT}."
fi


# ============================================================
# 18. CREAR ESTRUCTURA
# ============================================================

show_header "7. Preparando estructura"


mkdir -p \
    "${PROXY_DIR}/nginx/conf.d" \
    "${PROXY_DIR}/dnsmasq"


show_ok "Directorio: ${PROXY_DIR}"


# ============================================================
# 19. CREAR BACKUP
# ============================================================

show_header "8. Creando respaldos"


TIMESTAMP="$(
    date +'%Y%m%d_%H%M%S'
)"


FILES_TO_BACKUP=(
    "${PROXY_DIR}/docker-compose.yml"
    "${PROXY_DIR}/nginx/conf.d/recoleccion.conf"
    "${PROXY_DIR}/dnsmasq/dnsmasq.conf"
    "${PROXY_DIR}/dnsmasq/Dockerfile"
)


for file in "${FILES_TO_BACKUP[@]}"
do

    if [[ -f "${file}" ]]; then

        cp -a \
            "${file}" \
            "${file}.backup_${TIMESTAMP}"

        show_ok "Backup: ${file}.backup_${TIMESTAMP}"
    fi

done


# ============================================================
# 20. CONFIGURAR NGINX
# ============================================================

show_header "9. Configurando Nginx"


cat > "${PROXY_DIR}/nginx/conf.d/recoleccion.conf" <<EOF
# Recoleccion UY - RL-PROXY-01

server {
    listen 80;
    server_name ${CIUDADANA_HOST};

    client_max_body_size 25M;

    location / {
        proxy_pass http://${APP_SERVER_IP}:${CIUDADANA_PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Connection "";

        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}


server {
    listen 80;
    server_name ${ADMIN_HOST};

    client_max_body_size 25M;

    location / {
        proxy_pass http://${APP_SERVER_IP}:${ADMIN_PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Connection "";

        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# Aplicacion Camiones - servicio Laravel independiente.
server {
    listen 80;
    server_name ${CAMIONES_HOST};

    client_max_body_size 35M;

    location / {
        proxy_pass http://${APP_SERVER_IP}:${CAMIONES_PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Connection "";

        proxy_connect_timeout 10s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF


show_ok "Configuracion Nginx creada."


# ============================================================
# 21. CONFIGURAR DNSMASQ
# ============================================================

show_header "10. Configurando dnsmasq"


cat > "${PROXY_DIR}/dnsmasq/Dockerfile" <<'EOF'
FROM alpine:3.20

RUN apk add --no-cache \
    dnsmasq \
    bind-tools

CMD ["dnsmasq", "--no-daemon", "--conf-file=/etc/dnsmasq.conf"]
EOF


cat > "${PROXY_DIR}/dnsmasq/dnsmasq.conf" <<EOF
# Recoleccion UY - DNS RL-PROXY-01

port=53

no-resolv

# DNS de Active Directory.

server=${DNS_UPSTREAM_1}
server=${DNS_UPSTREAM_2}

# Aplicaciones publicadas por RL-PROXY-01.

address=/${CIUDADANA_HOST}/${DNS_PUBLISHED_IP}
address=/${ADMIN_HOST}/${DNS_PUBLISHED_IP}
address=/${CAMIONES_HOST}/${DNS_PUBLISHED_IP}

cache-size=1000

log-queries
log-facility=-
EOF


show_ok "Configuracion dnsmasq creada."


# ============================================================
# 22. CONFIGURAR DOCKER COMPOSE
# ============================================================

show_header "11. Configurando Docker Compose"


cat > "${PROXY_DIR}/docker-compose.yml" <<EOF
services:

  nginx:
    image: nginx:alpine
    container_name: ${PROXY_CONTAINER}

    restart: unless-stopped

    ports:
      - "${PROXY_IP}:80:80"

    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro


  dnsmasq:
    build:
      context: ./dnsmasq

    container_name: ${DNS_CONTAINER}

    restart: unless-stopped

    ports:
      - "${PROXY_IP}:53:53/udp"
      - "${PROXY_IP}:53:53/tcp"

    volumes:
      - ./dnsmasq/dnsmasq.conf:/etc/dnsmasq.conf:ro
EOF


cd "${PROXY_DIR}"


docker compose config >/dev/null


show_ok "docker-compose.yml valido."


# ============================================================
# 23. CONFIGURAR FIREWALLD
#
# Se configura ANTES de recrear los contenedores.
#
# No se ejecutara firewall-cmd --reload despues de Docker.
# ============================================================

show_header "12. Configurando Firewalld"


if systemctl is-active --quiet firewalld; then

    FIREWALL_ZONE="$(
        firewall-cmd \
            --get-zone-of-interface="${PROXY_INTERFACE}" \
            2>/dev/null || true
    )"


    if [[ -z "${FIREWALL_ZONE}" ]] ||
       [[ "${FIREWALL_ZONE}" == "no zone" ]]; then

        show_warning "${PROXY_INTERFACE} no tiene zona Firewalld asociada."
        show_warning "No se modificara Firewalld automaticamente."

    else

        show_info "Zona detectada: ${FIREWALL_ZONE}"


        firewall-cmd \
            --permanent \
            --zone="${FIREWALL_ZONE}" \
            --add-service=http \
            >/dev/null


        firewall-cmd \
            --permanent \
            --zone="${FIREWALL_ZONE}" \
            --add-service=dns \
            >/dev/null


        firewall-cmd --reload >/dev/null


        HTTP_FIREWALL="$(
            firewall-cmd \
                --zone="${FIREWALL_ZONE}" \
                --query-service=http
        )"


        DNS_FIREWALL="$(
            firewall-cmd \
                --zone="${FIREWALL_ZONE}" \
                --query-service=dns
        )"


        if [[ "${HTTP_FIREWALL}" != "yes" ]]; then

            fail "HTTP no quedo habilitado en ${FIREWALL_ZONE}."
        fi


        if [[ "${DNS_FIREWALL}" != "yes" ]]; then

            fail "DNS no quedo habilitado en ${FIREWALL_ZONE}."
        fi


        show_ok "HTTP habilitado en ${FIREWALL_ZONE}."
        show_ok "DNS habilitado en ${FIREWALL_ZONE}."
        show_ok "Firewalld recargado antes de iniciar Docker."
    fi

else

    show_warning "Firewalld no esta activo."
fi


# ============================================================
# 24. PREPARAR IMAGENES
# ============================================================

show_header "13. Preparando imagenes Docker"


docker compose pull nginx

docker compose build dnsmasq


show_ok "Imagenes preparadas."


# ============================================================
# 25. DETENER CONTENEDORES ANTERIORES
# ============================================================

show_header "14. Preparando recreacion de contenedores"


docker compose down \
    --remove-orphans \
    >/dev/null 2>&1 || true


show_ok "Contenedores anteriores detenidos."


# ============================================================
# 26. LEVANTAR SERVICIOS
# ============================================================

show_header "15. Levantando servicios"


docker compose up \
    -d \
    --force-recreate


# ============================================================
# 27. ESPERAR NGINX
# ============================================================

show_info "Esperando Nginx."


if wait_for_container "${PROXY_CONTAINER}"; then

    show_ok "${PROXY_CONTAINER} esta ejecutandose."

else

    docker compose logs nginx || true

    fail "Nginx no quedo ejecutandose."
fi


# ============================================================
# 28. ESPERAR DNSMASQ
# ============================================================

show_info "Esperando dnsmasq."


if wait_for_container "${DNS_CONTAINER}"; then

    show_ok "${DNS_CONTAINER} esta ejecutandose."

else

    docker compose logs dnsmasq || true

    fail "dnsmasq no quedo ejecutandose."
fi


# ============================================================
# 29. VERIFICAR CONFIGURACION NGINX
# ============================================================

show_header "16. Verificando Nginx"


docker exec \
    "${PROXY_CONTAINER}" \
    nginx -t


show_ok "Configuracion Nginx valida."


# ============================================================
# 30. VERIFICAR PUERTO HTTP
# ============================================================

if wait_for_tcp "${PROXY_IP}" 80; then

    show_ok "${PROXY_IP}:80 disponible."

else

    docker compose logs nginx || true

    fail "Nginx no responde en ${PROXY_IP}:80."
fi


# ============================================================
# 31. VERIFICAR PUERTO DNS
# ============================================================

show_header "17. Verificando dnsmasq"


if wait_for_tcp "${PROXY_IP}" 53; then

    show_ok "${PROXY_IP}:53/TCP disponible."

else

    docker compose logs dnsmasq || true

    fail "dnsmasq no responde en ${PROXY_IP}:53/TCP."
fi


# ============================================================
# 32. VERIFICAR DNS CIUDADANA
# ============================================================

DNS_RESULT_CIUDADANA="$(
    get_first_dns_result "${CIUDADANA_HOST}"
)"


if [[ "${DNS_RESULT_CIUDADANA}" != "${DNS_PUBLISHED_IP}" ]]; then

    fail "${CIUDADANA_HOST} resolvio '${DNS_RESULT_CIUDADANA:-NINGUNA}' en lugar de ${DNS_PUBLISHED_IP}."
fi


show_ok "${CIUDADANA_HOST} -> ${DNS_PUBLISHED_IP}"


# ============================================================
# 33. VERIFICAR DNS ADMIN
# ============================================================

DNS_RESULT_ADMIN="$(
    get_first_dns_result "${ADMIN_HOST}"
)"


if [[ "${DNS_RESULT_ADMIN}" != "${DNS_PUBLISHED_IP}" ]]; then

    fail "${ADMIN_HOST} resolvio '${DNS_RESULT_ADMIN:-NINGUNA}' en lugar de ${DNS_PUBLISHED_IP}."
fi


show_ok "${ADMIN_HOST} -> ${DNS_PUBLISHED_IP}"


# ============================================================
# 33A. VERIFICAR DNS CAMIONES
# ============================================================

DNS_RESULT_CAMIONES="$(
    get_first_dns_result "${CAMIONES_HOST}"
)"

if [[ "${DNS_RESULT_CAMIONES}" != "${DNS_PUBLISHED_IP}" ]]; then
    fail "${CAMIONES_HOST} resolvio '${DNS_RESULT_CAMIONES:-NINGUNA}' en lugar de ${DNS_PUBLISHED_IP}."
fi

show_ok "${CAMIONES_HOST} -> ${DNS_PUBLISHED_IP}"


# ============================================================
# 34. VERIFICAR REVERSE PROXY CIUDADANA
# ============================================================

show_header "18. Verificando Reverse Proxy"


CIUDADANA_RESPONSE="$(
    docker exec \
        "${PROXY_CONTAINER}" \
        wget \
        -S \
        -O /dev/null \
        --header="Host: ${CIUDADANA_HOST}" \
        "http://127.0.0.1/" \
        2>&1 || true
)"


if grep -Eq \
    'HTTP/[0-9.]+ [12345][0-9][0-9]' \
    <<< "${CIUDADANA_RESPONSE}"; then

    show_ok "Nginx responde para ${CIUDADANA_HOST}."

else

    echo "${CIUDADANA_RESPONSE}"

    fail "Nginx no responde correctamente para ${CIUDADANA_HOST}."
fi


# ============================================================
# 35. VERIFICAR REVERSE PROXY ADMIN
# ============================================================

ADMIN_RESPONSE="$(
    docker exec \
        "${PROXY_CONTAINER}" \
        wget \
        -S \
        -O /dev/null \
        --header="Host: ${ADMIN_HOST}" \
        "http://127.0.0.1/" \
        2>&1 || true
)"


if grep -Eq \
    'HTTP/[0-9.]+ [12345][0-9][0-9]' \
    <<< "${ADMIN_RESPONSE}"; then

    show_ok "Nginx responde para ${ADMIN_HOST}."

else

    echo "${ADMIN_RESPONSE}"

    fail "Nginx no responde correctamente para ${ADMIN_HOST}."
fi


# ============================================================
# 35A. VERIFICAR REVERSE PROXY CAMIONES
# ============================================================

CAMIONES_RESPONSE="$(
    docker exec \
        "${PROXY_CONTAINER}" \
        wget \
        -S \
        -O /dev/null \
        --header="Host: ${CAMIONES_HOST}" \
        "http://127.0.0.1/" \
        2>&1 || true
)"

if grep -Eq \
    'HTTP/[0-9.]+ [12345][0-9][0-9]' \
    <<< "${CAMIONES_RESPONSE}"; then

    show_ok "Nginx responde para ${CAMIONES_HOST}."

else
    echo "${CAMIONES_RESPONSE}"
    fail "Nginx no responde correctamente para ${CAMIONES_HOST}."
fi


# ============================================================
# 36. ESTADO FINAL
# ============================================================

show_header "19. Estado final Docker"


docker compose ps


# ============================================================
# 37. RESULTADO FINAL
# ============================================================

show_header "RL-PROXY-01 CONFIGURADO CORRECTAMENTE"


echo ""
echo "DMZ:"
echo ""
echo "  ${PROXY_IP}/${PROXY_PREFIX}"
echo ""

echo "Gateway:"
echo ""
echo "  ${PROXY_GATEWAY}"
echo ""

echo "Reverse Proxy:"
echo ""
echo "  ${CIUDADANA_HOST}"
echo "      -> ${APP_SERVER_IP}:${CIUDADANA_PORT}"
echo ""
echo "  ${ADMIN_HOST}"
echo "      -> ${APP_SERVER_IP}:${ADMIN_PORT}"
echo ""
echo "  ${CAMIONES_HOST}"
echo "      -> ${APP_SERVER_IP}:${CAMIONES_PORT}"
echo ""

echo "DNS local:"
echo ""
echo "  ${CIUDADANA_HOST}"
echo "      -> ${DNS_PUBLISHED_IP}"
echo ""
echo "  ${ADMIN_HOST}"
echo "      -> ${DNS_PUBLISHED_IP}"
echo ""
echo "  ${CAMIONES_HOST}"
echo "      -> ${DNS_PUBLISHED_IP}"
echo ""

echo "DNS upstream:"
echo ""
echo "  ${DNS_UPSTREAM_1}"
echo "  ${DNS_UPSTREAM_2}"
echo ""

echo "Contenedores:"
echo ""
echo "  ${PROXY_CONTAINER}"
echo "  ${DNS_CONTAINER}"
echo ""

echo "IMPORTANTE:"
echo ""
echo "  La publicacion desde WAN debe continuar"
echo "  controlandose exclusivamente desde RL-FW-01."
echo ""

echo "============================================================"
echo " FIN DE CONFIGURACION RL-PROXY-01"
echo "============================================================"
echo ""