#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-MON-01
# Script: RL-MON-01-Zabbix.sh
#
# OBJETIVO:
#   Desplegar Zabbix 7.0 mediante Docker Compose para
#   monitorear WS-DC-01 y WS-DC-02.
#
# SERVIDORES:
#   RL-MON-01: 192.168.20.20
#   WS-DC-01:  192.168.10.20
#   WS-DC-02:  192.168.10.21
#
# SERVICIOS:
#   - MySQL exclusivo de Zabbix.
#   - Zabbix Server TCP/10051 (agentes).
#   - Zabbix Web HTTP en 192.168.20.20:8088 (acceso por navegador).
#
# SEGURIDAD:
#   - No modifica pilas Docker ajenas.
#   - No elimina volumenes ni secretos existentes.
#   - No realiza reload de firewalld.
#   - No habilita el acceso web indiscriminadamente.
#   - No genera archivo .env; configuracion en el script.
#   - Se requiere verificar el control real de acceso
#     a puertos publicados por Docker.
#
# IMPORTANTE:
#   La web se publica en MON_IP:WEB_PORT, sin SSH.
#   Las reglas de acceso web deben autorizarse por separado.
#   Las imagenes se mantienen fijadas por digest como
#   en el script recibido; validar dichos digest antes
#   del primer despliegue y su version efectiva 7.0.
# ============================================================


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

readonly MON_IP="192.168.20.20"
readonly DC1_IP="192.168.10.20"
readonly DC2_IP="192.168.10.21"
readonly WEB_PORT="8088"

# Ajustar aqui la interfaz o zona real del servidor.
readonly MON_INTERFACE="ens33"
MON_ZONE=""

readonly SERVER="RL-MON-01"
readonly TARGET="/opt/recoleccionuy-zabbix/independiente-v1"
readonly PROJECT="recoleccion-zbx"

# UID confirmado para las imagenes Zabbix actualmente fijadas.
# No modificar sin comprobar la identidad de ambas imagenes.
readonly ZBX_UID="1997"


# ============================================================
# 2. FUNCIONES AUXILIARES
# ============================================================

info() { echo "[INFO] $*"; }
ok()   { echo "[OK] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

valid_ip() {
    local ip="$1" a b c d n
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS=. read -r a b c d <<< "$ip"
    for n in "$a" "$b" "$c" "$d"; do
        (( 10#$n <= 255 )) || return 1
    done
}

rule() {
    printf 'rule family="ipv4" source address="%s/32" port port="10051" protocol="tcp" accept' "$1"
}


# ============================================================
# 3. VERIFICAR REQUISITOS Y SERVIDOR
# ============================================================

[[ $# -eq 0 ]] || die "Ejecutar sin parametros."
[[ "$EUID" -eq 0 ]] || die "Ejecutar como root."

for cmd in docker ip ss openssl firewall-cmd curl awk grep sed hostname sleep setfacl getfacl stat; do
    command -v "$cmd" >/dev/null 2>&1 || die "Falta el comando: $cmd"
done

[[ "$(hostname -s | tr '[:upper:]' '[:lower:]')" == "rl-mon-01" ]] ||
    die "El script debe ejecutarse en $SERVER."

[[ "$(uname -m)" == x86_64 ]] ||
    die "El despliegue requiere arquitectura linux/amd64."

docker info >/dev/null 2>&1 || die "Docker no esta operativo."
docker compose version >/dev/null 2>&1 || die "Se requiere Docker Compose v2."

for addr in "$MON_IP" "$DC1_IP" "$DC2_IP"; do
    valid_ip "$addr" || die "IPv4 no valida: $addr"
done

[[ "$WEB_PORT" =~ ^[0-9]+$ ]] &&
    (( 10#$WEB_PORT >= 1024 && 10#$WEB_PORT <= 65535 )) ||
    die "Puerto web no valido."

ip -o -4 addr | grep -Fq " $MON_IP/" ||
    die "MON_IP no esta configurada en este servidor: $MON_IP"

firewall-cmd --state >/dev/null 2>&1 ||
    die "Firewalld no esta activo."

ZONE="$MON_ZONE"
[[ -n "$ZONE" ]] || ZONE="$(firewall-cmd --get-zone-of-interface="$MON_INTERFACE" 2>/dev/null || true)"

[[ -n "$ZONE" && "$ZONE" != "no zone" ]] ||
    die "Definir MON_ZONE segun la interfaz de monitoreo."

firewall-cmd --get-zones | tr ' ' '\n' | grep -Fxq "$ZONE" ||
    die "Zona firewalld inexistente: $ZONE"

info "Zona Zabbix: $ZONE"


# ============================================================
# 4. GENERAR COMPOSE EN INSTALACION NUEVA
# ============================================================

write_compose() {
cat > "$TARGET/compose.yaml" <<'YAML'
name: recoleccion-zbx
services:
  mysql-server:
    image: mysql@sha256:7dcddc01f13bab2f15cde676d44d01f61fc9f99fe7785e86196dfc07d358ae2b
    platform: linux/amd64
    restart: unless-stopped
    command: ['--character-set-server=utf8mb4','--collation-server=utf8mb4_bin','--log-bin-trust-function-creators=1']
    environment:
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD_FILE: /run/secrets/MYSQL_PASSWORD
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/MYSQL_ROOT_PASSWORD
    secrets: [MYSQL_PASSWORD, MYSQL_ROOT_PASSWORD]
    volumes: [zbx_mysql:/var/lib/mysql]
    healthcheck:
      test: ['CMD-SHELL','mysqladmin ping -h 127.0.0.1 --silent']
      interval: 15s
      timeout: 5s
      retries: 20
    networks: [zbx_private]
  zabbix-server:
    image: zabbix/zabbix-server-mysql@sha256:3f25a179fa9d933d403529e68ae02499d4401f6aae840b77638ece0eef7d7a57
    platform: linux/amd64
    restart: unless-stopped
    environment:
      DB_SERVER_HOST: mysql-server
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD_FILE: /run/secrets/MYSQL_PASSWORD
      ZBX_STARTPOLLERS: '5'
    secrets: [MYSQL_PASSWORD]
    depends_on:
      mysql-server: {condition: service_healthy}
    ports: ['__MON_IP__:10051:10051']
    networks: [zbx_private]
  zabbix-web:
    image: zabbix/zabbix-web-nginx-mysql@sha256:197e4607b5ec6aa4291bd6954843207e6c9ac85ba877b17cf9e6050113ab385b
    platform: linux/amd64
    restart: unless-stopped
    environment:
      DB_SERVER_HOST: mysql-server
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD_FILE: /run/secrets/MYSQL_PASSWORD
      ZBX_SERVER_HOST: zabbix-server
      PHP_TZ: America/Montevideo
    secrets: [MYSQL_PASSWORD]
    ports: ['__MON_IP__:__WEB_PORT__:8080']
    depends_on:
      mysql-server: {condition: service_healthy}
    networks: [zbx_private]
volumes:
  zbx_mysql: {}
networks:
  zbx_private: {driver: bridge}
secrets:
  MYSQL_PASSWORD: {file: './secrets/MYSQL_PASSWORD'}
  MYSQL_ROOT_PASSWORD: {file: './secrets/MYSQL_ROOT_PASSWORD'}
YAML

    # Solo se sustituyen IP y puerto configurados en este script.
    # No se genera ni se utiliza un archivo .env.
    sed -i -e "s/__MON_IP__/$MON_IP/g" \
           -e "s/__WEB_PORT__/$WEB_PORT/g" "$TARGET/compose.yaml"
}


# ============================================================
# 5. INSTALAR O REUTILIZAR PILA EXISTENTE
# ============================================================

[[ -d "$TARGET" && ! -f "$TARGET/compose.yaml" ]] && die "Directorio $TARGET preexistente sin Compose: revisar manualmente"
new_install=0
if [[ ! -f "$TARGET/compose.yaml" ]]; then
  new_install=1
  # No reutilizar un proyecto homonimo de otra ruta.
  if docker compose ls --all --format json 2>/dev/null | grep -Eq '"Name"[[:space:]]*:[[:space:]]*"recoleccion-zbx"'; then
    die "Existe un proyecto Docker $PROJECT ajeno a $TARGET. No se modifica."
  fi
  for p in 10051 "$WEB_PORT"; do
    if ss -H -lnt | awk '{print $4}' | grep -Eq ":${p}$"; then
      die "Puerto ocupado: $p"
    fi
  done
  install -d -m 700 "$TARGET/secrets"
  # Los secretos solo se crean en una instalacion nueva.
  openssl rand -hex 32 > "$TARGET/secrets/MYSQL_PASSWORD"
  openssl rand -hex 32 > "$TARGET/secrets/MYSQL_ROOT_PASSWORD"
  write_compose
  chmod 600 "$TARGET/compose.yaml" "$TARGET/secrets/"*
  ok "Nueva pila aislada preparada en $TARGET"
else
  # Un despliegue anterior puede depender de .env. No migrarlo
  # automaticamente para no alterar una instalacion en servicio.
  if [[ -e "$TARGET/.env" || -L "$TARGET/.env" ]]; then
    die "Instalacion anterior con .env detectada. Requiere migracion revisada manualmente; no se modifico."
  fi

  for f in "$TARGET/secrets/MYSQL_PASSWORD" "$TARGET/secrets/MYSQL_ROOT_PASSWORD"; do
    [[ -s "$f" && ! -L "$f" ]] || die "Falta secreto valido: $f"
  done

  # Verificar que la configuracion existente use los valores de este script.
  grep -Fq "'$MON_IP':10051:10051" "$TARGET/compose.yaml" ||
    grep -Fq "$MON_IP:10051:10051" "$TARGET/compose.yaml" ||
    die "La IP de Zabbix existente no coincide con MON_IP. Revisar Compose."
  grep -Fq "$MON_IP:$WEB_PORT:8080" "$TARGET/compose.yaml" ||
    die "La web existente no utiliza $MON_IP:$WEB_PORT. Revisar Compose antes de migrar; no se modifica automaticamente."
  if grep -Fq '${MON_IP}' "$TARGET/compose.yaml" || grep -Fq '${WEB_PORT}' "$TARGET/compose.yaml"; then
    die "Compose depende de variables externas. Revisar instalacion antes de continuar."
  fi
  ok "Instalacion existente detectada; se conservan Compose, volumenes y secretos"
fi


# ============================================================
# 6. PREPARAR PERMISOS DE SECRETOS Y ARRANCAR ZABBIX
# ============================================================

cd "$TARGET"
docker compose config -q || die 'Configuracion Compose invalida'

# Las imagenes Zabbix utilizan UID 1997, que debe leer MYSQL_PASSWORD.
# Docker Compose monta los secretos basados en archivos desde el host:
# uid/gid/mode en la declaracion secrets NO reasignan el propietario.
# Se mantiene root:root y modo 0600, con lectura ACL solo para UID 1997.
# La contraseña root de MySQL NO se concede a Zabbix.

prepare_secrets() {
  local secret="$TARGET/secrets/MYSQL_PASSWORD"
  local root_secret="$TARGET/secrets/MYSQL_ROOT_PASSWORD"
  local uid

  for f in "$secret" "$root_secret"; do
    [[ -f "$f" && -s "$f" && ! -L "$f" ]] ||
      die "Falta un secreto regular valido: $f"
    [[ "$(stat -c '%u' "$f")" == 0 ]] ||
      die "El secreto no pertenece a root: $f"
  done

  # Antes de asignar permisos, comprobar el UID real de las imagenes.
  # Compose reutiliza las imagenes locales si ya estan disponibles.

  for svc in zabbix-server zabbix-web; do
    uid="$(docker compose run --rm --no-deps -T --entrypoint id "$svc" -u 2>/dev/null)" ||
      die "No se pudo determinar el UID de $svc"
    [[ "$uid" == "$ZBX_UID" ]] ||
      die "UID inesperado para $svc ($uid); revisar version de la imagen antes de cambiar permisos."
  done

  chmod 600 "$secret" "$root_secret" ||
    die "No se pudieron ajustar permisos de secretos"
  setfacl -m "u:${ZBX_UID}:r--" "$secret" ||
    die "No se pudo conceder lectura al UID $ZBX_UID"
  getfacl -cp "$secret" | grep -Fxq "user:${ZBX_UID}:r--" ||
    die "No se pudo verificar ACL de MYSQL_PASSWORD"

  # SELinux en Rocky Linux: etiquetar solo el archivo compartido
  # por los contenedores, sin desactivar SELinux globalmente.
  if command -v getenforce >/dev/null 2>&1 &&
     [[ "$(getenforce)" == Enforcing ]]; then
    command -v chcon >/dev/null 2>&1 ||
      die "SELinux esta activo y falta chcon"
    chcon -t container_file_t "$secret" ||
      die "No se pudo etiquetar MYSQL_PASSWORD para contenedores"
  fi

  ok "MYSQL_PASSWORD habilitado exclusivamente para root y UID ${ZBX_UID}"
}

prepare_secrets

# Solo inicia/actualiza este proyecto; conserva volumenes y contraseñas.
docker compose up -d --no-build ||
  die 'No se pudo iniciar la pila Zabbix'


# ============================================================
# 7. CONFIGURAR FIREWALL LOCAL
# ============================================================

# IMPORTANTE: los puertos publicados por Docker pueden atravesar
# reglas distintas de las reglas INPUT de firewalld. Validar desde
# redes no autorizadas que TCP/10051 no quede expuesto.

for src in "$DC1_IP" "$DC2_IP"; do
  r="$(rule "$src")"
  if ! firewall-cmd --permanent --zone="$ZONE" --query-rich-rule="$r" >/dev/null; then
    firewall-cmd --permanent --zone="$ZONE" --add-rich-rule="$r" >/dev/null
  fi
  if ! firewall-cmd --zone="$ZONE" --query-rich-rule="$r" >/dev/null; then
    firewall-cmd --zone="$ZONE" --add-rich-rule="$r" >/dev/null
  fi
done


# ============================================================
# 8. VERIFICAR SERVICIOS Y REGLAS
# ============================================================

for (( n=1; n<=60; n++ )); do
  id="$(docker compose ps -q mysql-server)"
  if [[ -n "$id" && "$(docker inspect -f '{{.State.Health.Status}}' "$id" 2>/dev/null || true)" == healthy ]]; then break; fi
  sleep 3
done

# Esperar a que Zabbix complete el arranque. El bucle evita interpretar
# un contenedor en reinicio como un despliegue exitoso.

stable_checks=0
for (( n=1; n<=60; n++ )); do
  all_up=1
  for svc in mysql-server zabbix-server zabbix-web; do
    id="$(docker compose ps -q "$svc")"
    if [[ -z "$id" ]] ||
       [[ "$(docker inspect -f '{{.State.Running}} {{.State.Restarting}}' "$id" 2>/dev/null || true)" != "true false" ]]; then
      all_up=0
      break
    fi
  done
  if (( all_up )); then
    (( stable_checks += 1 ))
    (( stable_checks >= 3 )) && break
  else
    stable_checks=0
  fi
  sleep 3
done
(( stable_checks >= 3 )) ||
  die "Zabbix no pudo mantenerse en ejecucion. Revisar los registros del proyecto."
[[ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q mysql-server)")" == healthy ]] || die 'MySQL Zabbix no saludable'
for src in "$DC1_IP" "$DC2_IP"; do
  r="$(rule "$src")"
  firewall-cmd --permanent --zone="$ZONE" --query-rich-rule="$r" >/dev/null || die "Regla permanente faltante: $src"
  firewall-cmd --zone="$ZONE" --query-rich-rule="$r" >/dev/null || die "Regla runtime faltante: $src"
done
ok 'Servicios Docker y reglas locales preparados.'
info "Interfaz Zabbix Web: http://${MON_IP}:${WEB_PORT}/ (acceso directo desde navegador)."
info "El script no abre TCP/${WEB_PORT} en firewalld; autorizar exclusivamente los origenes previstos antes de utilizar la web."
info 'Confirmar recepcion de eventos y estado de los hosts en la interfaz Zabbix.'
info 'Comprobar aislamiento del puerto Docker TCP/10051 desde redes ajenas a los DC.'