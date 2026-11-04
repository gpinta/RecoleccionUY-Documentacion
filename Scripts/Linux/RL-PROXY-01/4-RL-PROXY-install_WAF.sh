#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-PROXY-01
# Script: instalar_waf_rl_proxy.sh
#
# OBJETIVO:
#   Instalar ModSecurity y OWASP CRS delante de Nginx.
#
# ARQUITECTURA:
#   Cliente -> WAF -> Nginx -> Laravel
#
# MODO:
#   DetectionOnly
#   Blocking Paranoia Level: 1
#   Detection Paranoia Level: 1
#
# APLICACIONES:
#   Ciudadana      -> 192.168.30.20:8080
#   Administrativa -> 192.168.30.20:8081
#   Camiones       -> 192.168.30.20:8082
#
# CORRECCIONES:
#   - Conserva el marcador de respaldo tras instalar.
#   - Preserva la configuracion base de Nginx y dnsmasq.
#   - Evita sobrescribir modificaciones incompatibles.
#   - Valida Compose antes de modificar produccion.
#   - Permite rollback posterior mediante script dedicado.
#
# NO MODIFICA:
#   - Aplicaciones Laravel.
#   - Base de datos MySQL.
#   - Configuracion de dnsmasq.
#   - RL-FW-01.
#   - Otros proyectos Docker.
#
# REQUISITO:
#   Docker Compose con soporte para !reset.
# ============================================================

export LC_ALL=C

# ------------------------------------------------------------
# 1. Configuracion general
# ------------------------------------------------------------

readonly PROXY_DIR="/opt/recoleccion-proxy"
readonly PROXY_IP="192.168.50.20"
readonly WAF_IMAGE="owasp/modsecurity-crs:4.25.1-nginx-lts"

readonly COMPOSE="$PROXY_DIR/docker-compose.yml"
readonly NGINX_CONF="$PROXY_DIR/nginx/conf.d/recoleccion.conf"

readonly WAF_DIR="$PROXY_DIR/waf"
readonly WAF_TEMPLATE="$WAF_DIR/default.conf.template"

readonly BACKUP_ROOT="$PROXY_DIR/backups-waf"
readonly STATE="$PROXY_DIR/.waf-install-backup"
readonly EVIDENCE_ROOT="$PROXY_DIR/waf-install-evidence"

readonly -a HOSTS=(
    "recoleccion.neltek.uy"
    "admin-recoleccion.neltek.uy"
    "camiones-recoleccion.neltek.uy"
)

readonly TEST_NET="recoleccion_waf_test_$$"
readonly TEST_BACKEND="recoleccion_test_backend_$$"
readonly TEST_WAF="recoleccion_test_waf_$$"

TMP_DIR=""
EVIDENCE=""
BACKUP=""

CHANGED=0
INSTALL_OK=0
ROLLBACK_OK=0

# ------------------------------------------------------------
# 2. Funciones
# ------------------------------------------------------------

log() {
    printf '[WAF] %s\n' "$*"
}

ok() {
    printf '[OK] %s\n' "$*"
}

warn() {
    printf '[ADVERTENCIA] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

# ------------------------------------------------------------
# 3. Limpieza de recursos de laboratorio
# ------------------------------------------------------------

cleanup_test() {

    docker rm -f "$TEST_WAF" \
        >/dev/null 2>&1 || true

    docker rm -f "$TEST_BACKEND" \
        >/dev/null 2>&1 || true

    docker network rm "$TEST_NET" \
        >/dev/null 2>&1 || true
}

# ------------------------------------------------------------
# 4. Guardar evidencia
# ------------------------------------------------------------

save_test_logs() {

    [[ -n "$EVIDENCE" ]] || return 0

    docker logs "$TEST_WAF" \
        > "$EVIDENCE/test-waf.log" \
        2>&1 || true

    docker inspect "$TEST_WAF" \
        > "$EVIDENCE/test-waf-inspect.json" \
        2>&1 || true
}

save_production_logs() {

    [[ -n "$EVIDENCE" ]] || return 0

    docker logs recoleccion_waf \
        > "$EVIDENCE/production-waf.log" \
        2>&1 || true

    docker inspect recoleccion_waf \
        > "$EVIDENCE/production-waf-inspect.json" \
        2>&1 || true

    docker compose ps \
        > "$EVIDENCE/production-compose-ps.txt" \
        2>&1 || true
}

# ------------------------------------------------------------
# 5. Recuperacion ante fallo de instalacion
# ------------------------------------------------------------

rollback_installation() {

    warn "Intentando restaurar la configuracion original."

    [[ -n "$BACKUP" && -d "$BACKUP" ]] ||
        return 1

    # Restaurar archivos originales.
    cp -a "$BACKUP/docker-compose.yml" "$COMPOSE" ||
        return 1

    cp -a "$BACKUP/recoleccion.conf" "$NGINX_CONF" ||
        return 1

    docker compose config --quiet ||
        return 1

    # El WAF puede ocupar el puerto HTTP original.
    # Se retira exclusivamente el contenedor creado
    # por este instalador y perteneciente al proyecto.

    if docker container inspect recoleccion_waf \
        >/dev/null 2>&1; then

        local service
        local project
        local expected_project

        service="$(
            docker inspect \
                -f '{{index .Config.Labels "com.docker.compose.service"}}' \
                recoleccion_waf
        )"

        project="$(
            docker inspect \
                -f '{{index .Config.Labels "com.docker.compose.project"}}' \
                recoleccion_waf
        )"

        expected_project="$(
            docker compose config --format json |
                python3 -c \
                    'import json,sys; print(json.load(sys.stdin)["name"])'
        )" || return 1

        [[ "$service" == "waf" &&
           "$project" == "$expected_project" ]] ||
            return 1

        docker stop recoleccion_waf >/dev/null ||
            return 1
    fi

    docker compose up -d --force-recreate nginx dnsmasq ||
        return 1

    docker exec recoleccion_proxy nginx -t ||
        return 1

    local running
    local code

    running="$(
        docker inspect \
            -f '{{.State.Running}}' \
            recoleccion_dns 2>/dev/null || true
    )"

    [[ "$running" == "true" ]] || return 1

    code="$(
        curl -sS \
            --noproxy '*' \
            --max-time 15 \
            -o /dev/null \
            -w '%{http_code}' \
            -H "Host: ${HOSTS[0]}" \
            "http://${PROXY_IP}/" \
            2>/dev/null || true
    )"

    [[ "$code" =~ ^[1-4][0-9][0-9]$ ]] ||
        return 1

    # La configuracion original ya esta funcionando.
    # Ahora se puede retirar el WAF huerfano.

    if docker container inspect recoleccion_waf \
        >/dev/null 2>&1; then

        docker rm recoleccion_waf >/dev/null ||
            return 1
    fi

    rm -f "$STATE" || return 1

    ROLLBACK_OK=1

    ok "Configuracion original recuperada. HTTP $code."

    return 0
}

# ------------------------------------------------------------
# 6. Finalizacion y control de errores
# ------------------------------------------------------------

finish() {

    local result=$?

    trap - EXIT INT TERM

    if (( result != 0 )); then

        warn "Instalacion WAF interrumpida."

        save_test_logs

        if (( CHANGED == 1 )); then

            save_production_logs

            if ! rollback_installation; then
                warn "No se confirmo la recuperacion automatica."
                warn "Se conserva el marcador y los respaldos."
                warn "Revisar manualmente antes de reejecutar."
            fi
        fi

        if [[ -n "$EVIDENCE" ]]; then
            warn "Evidencia disponible en: $EVIDENCE"
        fi
    fi

    cleanup_test

    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf -- "$TMP_DIR"
    fi

    exit "$result"
}

trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ------------------------------------------------------------
# 7. Validaciones previas
# ------------------------------------------------------------

(( EUID == 0 )) ||
    die "Ejecutar como root."

(( $# == 0 )) ||
    die "Este instalador no recibe parametros."

for cmd in \
    docker \
    python3 \
    curl \
    grep \
    mktemp \
    sed \
    cp \
    date
do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Falta dependencia: $cmd"
done

docker info >/dev/null 2>&1 ||
    die "Docker no disponible."

docker compose version >/dev/null 2>&1 ||
    die "Docker Compose no disponible."

[[ -d "$PROXY_DIR" && ! -L "$PROXY_DIR" ]] ||
    die "Directorio del proxy invalido."

[[ -f "$COMPOSE" && ! -L "$COMPOSE" ]] ||
    die "No existe Compose original valido."

[[ -f "$NGINX_CONF" && ! -L "$NGINX_CONF" ]] ||
    die "No existe configuracion Nginx."

[[ -f "$PROXY_DIR/dnsmasq/dnsmasq.conf" ]] ||
    die "No existe dnsmasq.conf."

[[ -f "$PROXY_DIR/dnsmasq/Dockerfile" ]] ||
    die "No existe Dockerfile de dnsmasq."

# El marcador se conserva tras una instalacion exitosa.
# Si existe, se requiere revisar o ejecutar rollback.

[[ ! -e "$STATE" && ! -L "$STATE" ]] ||
    die "Existe respaldo WAF registrado en $STATE. No se sobrescribe."

if docker container inspect recoleccion_waf \
    >/dev/null 2>&1; then

    die "Ya existe recoleccion_waf. No se sobrescribe."
fi

cd "$PROXY_DIR"

TMP_DIR="$(mktemp -d /tmp/recoleccion-waf.XXXXXXXX)"

chmod 700 "$TMP_DIR"

mkdir -p "$EVIDENCE_ROOT"

EVIDENCE="$EVIDENCE_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-$$"

mkdir -m 700 "$EVIDENCE"

docker compose config --quiet ||
    die "Compose base invalido."

docker compose config --format json \
    > "$TMP_DIR/base.json"

# ------------------------------------------------------------
# 8. Validar infraestructura base
# ------------------------------------------------------------

python3 - "$TMP_DIR/base.json" "$PROXY_IP" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)

services = data.get("services", {})
ip = sys.argv[2]

if set(services) != {"nginx", "dnsmasq"}:
    raise SystemExit(
        "Compose base debe contener nginx y dnsmasq solamente."
    )

if services["nginx"].get("container_name") != "recoleccion_proxy":
    raise SystemExit("Nombre Nginx inesperado.")

if services["dnsmasq"].get("container_name") != "recoleccion_dns":
    raise SystemExit("Nombre dnsmasq inesperado.")

def port_exists(service, published, target, protocol):
    for item in services[service].get("ports", []):
        if (
            str(item.get("host_ip", "")) == ip
            and int(item.get("published", 0)) == published
            and int(item.get("target", 0)) == target
            and item.get("protocol", "tcp") == protocol
        ):
            return True
    return False

if not port_exists("nginx", 80, 80, "tcp"):
    raise SystemExit("Puerto HTTP original inesperado.")

if not port_exists("dnsmasq", 53, 53, "tcp"):
    raise SystemExit("Puerto DNS TCP inesperado.")

if not port_exists("dnsmasq", 53, 53, "udp"):
    raise SystemExit("Puerto DNS UDP inesperado.")

if services["nginx"].get("network_mode") == "host":
    raise SystemExit("Nginx en host network no soportado.")

print("[OK] Configuracion base compatible.")
PY

for host in "${HOSTS[@]}"; do

    grep -Fq "server_name $host;" "$NGINX_CONF" ||
        die "Falta virtual host: $host"
done

for port in 8080 8081 8082; do

    grep -Fq \
        "proxy_pass http://192.168.30.20:${port};" \
        "$NGINX_CONF" ||
        die "Falta backend $port"
done

grep -Fq "client_max_body_size 35M;" "$NGINX_CONF" ||
    die "No se encontro limite Camiones 35M."

docker exec recoleccion_proxy nginx -t ||
    die "Nginx base invalido."

for container in recoleccion_proxy recoleccion_dns; do

    running="$(
        docker inspect \
            -f '{{.State.Running}}' \
            "$container" 2>/dev/null || true
    )"

    [[ "$running" == "true" ]] ||
        die "Contenedor base inactivo: $container"
done

ok "Infraestructura original validada."

# ------------------------------------------------------------
# 9. Preparar imagen WAF y plantilla
# ------------------------------------------------------------

log "Preparando imagen WAF."

docker image inspect "$WAF_IMAGE" >/dev/null 2>&1 ||
    docker pull "$WAF_IMAGE" ||
    die "No se pudo obtener imagen WAF."

EXTRACT_ID="$(docker create "$WAF_IMAGE")" ||
    die "No se pudo crear contenedor de extraccion."

if ! docker cp \
    "$EXTRACT_ID:/etc/nginx/templates/conf.d/default.conf.template" \
    "$TMP_DIR/default.conf.template"; then

    docker rm -f "$EXTRACT_ID" >/dev/null 2>&1 || true

    die "No se pudo extraer plantilla OWASP."
fi

docker rm "$EXTRACT_ID" >/dev/null

# ------------------------------------------------------------
# 10. Adaptar plantilla HTTP
# ------------------------------------------------------------

python3 - "$TMP_DIR/default.conf.template" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = path.read_text(encoding="utf-8")

for marker in ("HTTP3_CONFIG", "PROXY_SSL_CONFIG"):

    pattern = rf"^[ \t]*{marker}[ \t]*$"

    data, count = re.subn(
        pattern,
        "",
        data,
        flags=re.MULTILINE,
    )

    if count == 0:
        raise SystemExit(
            f"No se encontro marcador {marker}."
        )

    print(f"[OK] {marker}: {count} sustituciones.")

path.write_text(data, encoding="utf-8")
PY

# ------------------------------------------------------------
# 11. Crear entorno temporal de pruebas
# ------------------------------------------------------------

log "Preparando entorno de pruebas aislado."

docker network create "$TEST_NET" >/dev/null ||
    die "No se pudo crear red temporal."

docker run -d \
    --name "$TEST_BACKEND" \
    --network "$TEST_NET" \
    --network-alias nginx \
    nginx:alpine >/dev/null ||
    die "No se pudo iniciar backend temporal."

# ------------------------------------------------------------
# 12. Validar Nginx y ModSecurity
# ------------------------------------------------------------

log "Validando configuracion WAF con nginx -T."

if ! docker run --rm \
    --network "$TEST_NET" \
    -v "$TMP_DIR/default.conf.template:/etc/nginx/templates/conf.d/default.conf.template:ro,Z" \
    -e BACKEND="http://nginx:80" \
    -e PORT="8080" \
    -e MODSEC_RULE_ENGINE="DetectionOnly" \
    -e BLOCKING_PARANOIA="1" \
    -e DETECTION_PARANOIA="1" \
    -e MODSEC_AUDIT_ENGINE="RelevantOnly" \
    -e MODSEC_AUDIT_LOG_FORMAT="JSON" \
    -e MODSEC_REQ_BODY_LIMIT="36700160" \
    -e MODSEC_REQ_BODY_NOFILES_LIMIT="131072" \
    -e MODSEC_RESP_BODY_ACCESS="Off" \
    "$WAF_IMAGE" nginx -T \
    > "$EVIDENCE/nginx-expanded.txt" 2>&1; then

    tail -n 60 "$EVIDENCE/nginx-expanded.txt"

    die "Fallo nginx -T durante prevalidacion."
fi

grep -Fq "syntax is ok" \
    "$EVIDENCE/nginx-expanded.txt" ||
    die "No se confirmo sintaxis Nginx."

grep -Eq \
    '^[[:space:]]*modsecurity[[:space:]]+on;' \
    "$EVIDENCE/nginx-expanded.txt" ||
    die "ModSecurity no figura habilitado."

grep -Eq \
    'rules loaded inline/local/remote:' \
    "$EVIDENCE/nginx-expanded.txt" ||
    die "No se confirmo carga de reglas CRS."

ok "Nginx, ModSecurity y CRS prevalidados."

# ------------------------------------------------------------
# 13. Verificar WAF HTTP aislado
# ------------------------------------------------------------

log "Probando WAF HTTP aislado."

docker run -d \
    --name "$TEST_WAF" \
    --network "$TEST_NET" \
    -v "$TMP_DIR/default.conf.template:/etc/nginx/templates/conf.d/default.conf.template:ro,Z" \
    -e BACKEND="http://nginx:80" \
    -e PORT="8080" \
    -e MODSEC_RULE_ENGINE="DetectionOnly" \
    -e BLOCKING_PARANOIA="1" \
    -e DETECTION_PARANOIA="1" \
    -e MODSEC_AUDIT_ENGINE="RelevantOnly" \
    -e MODSEC_AUDIT_LOG_FORMAT="JSON" \
    -e MODSEC_REQ_BODY_LIMIT="36700160" \
    -e MODSEC_REQ_BODY_NOFILES_LIMIT="131072" \
    -e MODSEC_RESP_BODY_ACCESS="Off" \
    "$WAF_IMAGE" >/dev/null ||
    die "No se pudo iniciar WAF temporal."

HTTP_OK=0

for attempt in $(seq 1 40); do

    running="$(
        docker inspect \
            -f '{{.State.Running}}' \
            "$TEST_WAF" 2>/dev/null || true
    )"

    [[ "$running" == "true" ]] || break

    code="$(
        docker exec "$TEST_WAF" \
            curl -sS \
            --noproxy '*' \
            --max-time 4 \
            -o /dev/null \
            -w '%{http_code}' \
            -H "Host: recoleccion.neltek.uy" \
            "http://127.0.0.1:8080/" \
            2>/dev/null || true
    )"

    if [[ "$code" == "200" ]]; then
        HTTP_OK=1
        break
    fi

    sleep 2
done

if (( HTTP_OK != 1 )); then
    save_test_logs
    die "WAF aislado no respondio HTTP 200."
fi

ok "WAF aislado funcional."

save_test_logs
cleanup_test

# ------------------------------------------------------------
# 14. Crear respaldo original
# ------------------------------------------------------------

log "Creando respaldo de produccion."

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"

BACKUP="$BACKUP_ROOT/$STAMP"

[[ ! -e "$BACKUP" ]] ||
    die "Ya existe respaldo $BACKUP."

mkdir -p "$BACKUP"

cp -a "$COMPOSE" "$BACKUP/docker-compose.yml"

cp -a "$NGINX_CONF" "$BACKUP/recoleccion.conf"

cp -a "$PROXY_DIR/dnsmasq" "$BACKUP/dnsmasq"

# ------------------------------------------------------------
# 15. Generar configuracion candidata
# ------------------------------------------------------------

log "Preparando Compose preservando servicios existentes."

cat > "$TMP_DIR/waf.override.yml" <<EOF
services:

  nginx:
    ports: !reset []
    networks:
      - proxy_internal

  waf:
    image: ${WAF_IMAGE}
    container_name: recoleccion_waf
    restart: unless-stopped

    ports:
      - "${PROXY_IP}:80:8080"

    environment:
      BACKEND: "http://nginx:80"
      PORT: "8080"
      MODSEC_RULE_ENGINE: "DetectionOnly"
      BLOCKING_PARANOIA: "1"
      DETECTION_PARANOIA: "1"
      MODSEC_AUDIT_ENGINE: "RelevantOnly"
      MODSEC_AUDIT_LOG_FORMAT: "JSON"
      MODSEC_REQ_BODY_LIMIT: "36700160"
      MODSEC_REQ_BODY_NOFILES_LIMIT: "131072"
      MODSEC_RESP_BODY_ACCESS: "Off"

    volumes:
      - ./waf/default.conf.template:/etc/nginx/templates/conf.d/default.conf.template:ro,Z

    depends_on:
      - nginx

    networks:
      - proxy_internal

networks:
  proxy_internal:
    driver: bridge
EOF

# Compose combina el original con la configuracion WAF.
# La salida normalizada mantiene las opciones existentes
# de nginx y dnsmasq que no requieren modificacion.

docker compose \
    -f "$COMPOSE" \
    -f "$TMP_DIR/waf.override.yml" \
    --project-directory "$PROXY_DIR" \
    config --format yaml \
    > "$TMP_DIR/docker-compose.waf.yml" ||
    die "No fue posible combinar Docker Compose."

# Validar la configuracion resultante.

docker compose \
    -f "$TMP_DIR/docker-compose.waf.yml" \
    --project-directory "$PROXY_DIR" \
    config --quiet ||
    die "Compose WAF invalido."

docker compose \
    -f "$TMP_DIR/docker-compose.waf.yml" \
    --project-directory "$PROXY_DIR" \
    config --format json \
    > "$TMP_DIR/waf.json"

# Comprobar que dnsmasq conserva sus opciones
# y que nginx solo cambia la publicacion de puertos
# y su conexion a la nueva red del WAF.

python3 - "$TMP_DIR/base.json" "$TMP_DIR/waf.json" "$PROXY_IP" <<'PY'
import copy
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    original = json.load(f)

with open(sys.argv[2], encoding="utf-8") as f:
    updated = json.load(f)

ip = sys.argv[3]

before = original.get("services", {})
after = updated.get("services", {})

if set(after) != {"nginx", "dnsmasq", "waf"}:
    raise SystemExit("Servicios Compose inesperados.")

if before["dnsmasq"] != after["dnsmasq"]:
    raise SystemExit(
        "La configuracion efectiva de dnsmasq cambio."
    )

nginx_before = copy.deepcopy(before["nginx"])
nginx_after = copy.deepcopy(after["nginx"])

nginx_before.pop("ports", None)
nginx_after.pop("ports", None)

nginx_before.pop("networks", None)
nginx_after.pop("networks", None)

if nginx_before != nginx_after:
    raise SystemExit(
        "Existen modificaciones no previstas en Nginx."
    )

if after["nginx"].get("ports"):
    raise SystemExit(
        "Nginx interno todavia publica puertos."
    )

if "proxy_internal" not in after["nginx"].get("networks", {}):
    raise SystemExit(
        "Nginx no pertenece a proxy_internal."
    )

if "proxy_internal" not in after["waf"].get("networks", {}):
    raise SystemExit(
        "El WAF no pertenece a proxy_internal."
    )

waf_ports = after["waf"].get("ports", [])

if not any(
    str(item.get("host_ip", "")) == ip
    and int(item.get("published", 0)) == 80
    and int(item.get("target", 0)) == 8080
    for item in waf_ports
):
    raise SystemExit(
        "El WAF no publica el puerto HTTP esperado."
    )

print("[OK] dnsmasq conservado.")
print("[OK] Configuracion restante de Nginx conservada.")
print("[OK] Puertos y red WAF verificados.")
PY

ok "Compose compatible y validado."

# ------------------------------------------------------------
# 16. Preparar archivos WAF de produccion
# ------------------------------------------------------------

# El archivo candidato ya se valido antes de
# modificar la configuracion activa.

mkdir -p "$WAF_DIR"

cp "$TMP_DIR/default.conf.template" "$WAF_TEMPLATE"

chmod 644 "$WAF_TEMPLATE"

# El marcador se conserva incluso cuando la
# instalacion termina correctamente.

printf '%s\n' "$BACKUP" > "$STATE"
chmod 600 "$STATE"

# ------------------------------------------------------------
# 17. Instalar WAF
# ------------------------------------------------------------

log "Instalando WAF."
warn "El acceso HTTP puede interrumpirse brevemente."

CHANGED=1

cp "$TMP_DIR/docker-compose.waf.yml" "$COMPOSE"

docker compose config --quiet ||
    die "Compose definitivo invalido."

# Recrear solamente el Nginx del proyecto.
# Conserva dnsmasq y otros proyectos Docker.

docker compose up -d \
    --no-deps \
    --force-recreate nginx ||
    die "No se pudo recrear Nginx."

# WAF ocupa la publicacion HTTP original.

docker compose up -d \
    --no-deps waf ||
    die "No se pudo iniciar WAF."

# ------------------------------------------------------------
# 18. Verificar Nginx y WAF
# ------------------------------------------------------------

docker exec recoleccion_proxy nginx -t ||
    die "Nginx interno invalido."

WAF_READY=0

for attempt in $(seq 1 60); do

    running="$(
        docker inspect \
            -f '{{.State.Running}}' \
            recoleccion_waf 2>/dev/null || true
    )"

    health="$(
        docker inspect \
            -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
            recoleccion_waf 2>/dev/null || true
    )"

    if [[ "$running" == "true" &&
          "$health" == "healthy" ]]; then

        WAF_READY=1
        break
    fi

    sleep 2
done

(( WAF_READY == 1 )) ||
    die "El WAF no alcanzo estado healthy."

docker exec recoleccion_waf nginx -t ||
    die "Nginx WAF invalido."

ok "WAF operativo."

# ------------------------------------------------------------
# 19. Verificar puertos
# ------------------------------------------------------------

WAF_PORTS="$(
    docker port recoleccion_waf 8080/tcp
)" || die "No se pudieron consultar puertos WAF."

[[ "$WAF_PORTS" == *"${PROXY_IP}:80"* ]] ||
    die "WAF no publica ${PROXY_IP}:80."

PROXY_PORTS="$(
    docker port recoleccion_proxy
)" || die "No se pudieron consultar puertos Nginx."

[[ -z "$PROXY_PORTS" ]] ||
    die "Nginx interno publica puertos inesperados."

ok "Publicacion HTTP exclusiva del WAF."

# ------------------------------------------------------------
# 20. Verificar DNS
# ------------------------------------------------------------

running="$(
    docker inspect \
        -f '{{.State.Running}}' \
        recoleccion_dns 2>/dev/null || true
)"

[[ "$running" == "true" ]] ||
    die "dnsmasq no esta ejecutandose."

ok "dnsmasq operativo."

# ------------------------------------------------------------
# 21. Verificar virtual hosts
# ------------------------------------------------------------

log "Verificando aplicaciones."

for host in "${HOSTS[@]}"; do

    code="$(
        curl -sS \
            --noproxy '*' \
            --max-time 15 \
            -o /dev/null \
            -w '%{http_code}' \
            -H "Host: $host" \
            "http://${PROXY_IP}/" \
            2>/dev/null || true
    )"

    if [[ "$code" =~ ^[1-4][0-9][0-9]$ ]]; then
        ok "$host -> HTTP $code"
    else
        die "$host -> HTTP $code"
    fi
done

# ------------------------------------------------------------
# 22. Confirmar instalacion
# ------------------------------------------------------------

CHANGED=0
INSTALL_OK=1

# IMPORTANTE:
# NO ELIMINAR STATE.
#
# rollback_waf_rl_proxy.sh necesita este archivo
# para identificar el respaldo original.
#
# El marcador solo se elimina cuando el rollback
# finaliza correctamente.

[[ -f "$STATE" ]] ||
    die "No se conservo el marcador de respaldo."

echo
echo "============================================================"
echo " RECOLECCION UY - WAF INSTALADO"
echo "============================================================"

echo
echo "Arquitectura:"
echo "  Cliente -> WAF -> Nginx -> Laravel"

echo
echo "Contenedor:"
echo "  recoleccion_waf"

echo
echo "Imagen:"
echo "  $WAF_IMAGE"

echo
echo "Modo:"
echo "  DetectionOnly"

echo
echo "Aplicaciones:"
printf '  %s\n' "${HOSTS[@]}"

echo
echo "Respaldo:"
echo "  $BACKUP"

echo
echo "Marcador de rollback:"
echo "  $STATE"

echo
echo "Evidencia:"
echo "  $EVIDENCE"

echo
echo "IMPORTANTE:"
echo "  El marcador se conserva para permitir rollback."
echo "  No se modificaron las aplicaciones Laravel."
echo "  No se modifico dnsmasq."
echo "  No se modifico RL-FW-01."
echo "  HTTPS no configurado."

echo
echo "Verificacion recomendada:"
echo "  sudo ./verificar_waf_rl_proxy.sh"
echo "  sudo ./test_waf_rl_proxy.sh --guardar-evidencia"

echo
ok "Instalacion WAF finalizada correctamente."