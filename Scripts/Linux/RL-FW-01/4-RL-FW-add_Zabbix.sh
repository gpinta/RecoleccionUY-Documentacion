#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-FW-01
# Script: RL-FW-01-Zabbix.sh
#
# OBJETIVO:
#   Configurar politicas de firewalld para el monitoreo
#   Zabbix de WS-DC-01 y WS-DC-02 desde RL-MON-01.
#
# SERVIDORES:
#   RL-MON-01: 192.168.20.20
#   WS-DC-01:  192.168.10.20
#   WS-DC-02:  192.168.10.21
#
# COMUNICACIONES:
#   MON -> DC: TCP/10050 (consultas pasivas del agente).
#   DC -> MON: TCP/10051 (comprobaciones activas).
#
# SEGURIDAD:
#   - No modifica NAT ni politicas preexistentes ajenas.
#   - No modifica zonas, interfaces ni FORWARD global.
#   - Solo realiza reload con confirmacion explicita.\n#   - Nunca reinicia firewalld automaticamente.
#   - No habilita trafico general entre redes.
#   - Si una politica homonima es incompatible, aborta.\n#   - No elimina politicas ni reglas existentes.
#
# IMPORTANTE:
#   Requiere zonas de monitoreo y servicios distintas.
#   La autorizacion efectiva tambien depende de Docker,
#   firewalls locales y reglas previas de mayor prioridad.
# ============================================================


# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

readonly SERVER="RL-FW-01"

readonly MON_IP="192.168.20.20"
readonly DC1_IP="192.168.10.20"
readonly DC2_IP="192.168.10.21"

# Dejar vacias para deteccion por ruta; ajustar si la topologia lo exige.
ZONE_MON=""
ZONE_SERV=""

readonly POLICY_MON_DC="rec-zbx-mon-dc"
readonly POLICY_DC_MON="rec-zbx-dc-mon"


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

zone_for_ip() {
    local dev

    dev="$(ip -4 route get "$1" 2>/dev/null |
        sed -n 's/.* dev \([^ ]*\).*/\1/p' |
        head -n 1)"

    [[ -n "$dev" ]] || return 1
    firewall-cmd --get-zone-of-interface="$dev" 2>/dev/null
}

make_rule() {
    printf 'rule family="ipv4" source address="%s/32" destination address="%s/32" port port="%s" protocol="tcp" accept' \
        "$1" "$2" "$3"
}

# Las politicas nuevas se crean exclusivamente en permanente.
# Runtime solo se configura cuando la politica ya esta cargada.
policy_exists() {
    local scope="$1" policy="$2"
    local args=()

    [[ "$scope" == permanent ]] && args=(--permanent)

    firewall-cmd "${args[@]}" --get-policies |
        tr ' ' '\n' | grep -Fxq "$policy"
}

ensure_policy() {
    local scope="$1" policy="$2" ingress="$3" egress="$4" port="$5"
    shift 5

    local args=() target priority zones src dst rule
    [[ "$scope" == permanent ]] && args=(--permanent)

    if ! policy_exists "$scope" "$policy"; then
        if [[ "$scope" == runtime ]]; then
            die "Politica no cargada en runtime: $policy. Se requiere activacion autorizada."
        fi

        firewall-cmd --permanent --new-policy="$policy" >/dev/null ||
            die "No se pudo crear la politica permanente: $policy"

        firewall-cmd --permanent --policy="$policy" --add-ingress-zone="$ingress" >/dev/null ||
            die "No se pudo configurar ingress permanente: $policy"

        firewall-cmd --permanent --policy="$policy" --add-egress-zone="$egress" >/dev/null ||
            die "No se pudo configurar egress permanente: $policy"

        firewall-cmd --permanent --policy="$policy" --set-target=CONTINUE >/dev/null ||
            die "No se pudo configurar target permanente: $policy"

        firewall-cmd --permanent --policy="$policy" --set-priority=-2 >/dev/null ||
            die "No se pudo configurar prioridad permanente: $policy"
    fi

    target="$(firewall-cmd "${args[@]}" --policy="$policy" --get-target)" ||
        die "No se pudo consultar target de $policy ($scope)"

    priority="$(firewall-cmd "${args[@]}" --policy="$policy" --get-priority)" ||
        die "No se pudo consultar prioridad de $policy ($scope)"

    [[ "$target" == CONTINUE && "$priority" == -2 ]] ||
        die "Politica existente incompatible ($scope): $policy"

    zones="$(firewall-cmd "${args[@]}" --policy="$policy" --list-ingress-zones)" ||
        die "No se pudo consultar ingress de $policy ($scope)"

    [[ "$zones" == "$ingress" ]] ||
        die "Ingress incompatible en $policy ($scope): $zones"

    zones="$(firewall-cmd "${args[@]}" --policy="$policy" --list-egress-zones)" ||
        die "No se pudo consultar egress de $policy ($scope)"

    [[ "$zones" == "$egress" ]] ||
        die "Egress incompatible en $policy ($scope): $zones"

    while (( $# )); do
        src="$1"
        dst="$2"
        shift 2

        rule="$(make_rule "$src" "$dst" "$port")"

        if ! firewall-cmd "${args[@]}" --policy="$policy" --query-rich-rule="$rule" >/dev/null 2>&1; then
            firewall-cmd "${args[@]}" --policy="$policy" --add-rich-rule="$rule" >/dev/null ||
                die "No se pudo agregar regla en $policy ($scope)"
        fi

        firewall-cmd "${args[@]}" --policy="$policy" --query-rich-rule="$rule" >/dev/null 2>&1 ||
            die "No se pudo verificar regla en $policy ($scope)"
    done

    ok "$scope: $policy"
}


# ============================================================
# 3. VERIFICAR REQUISITOS Y SERVIDOR
# ============================================================

[[ $# -eq 0 ]] || die "Ejecutar sin parametros."
[[ "$EUID" -eq 0 ]] || die "Ejecutar como root."

for cmd in firewall-cmd ip sed head tr grep hostname; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Falta el comando: $cmd"
done

[[ "$(hostname -s | tr '[:upper:]' '[:lower:]')" == "rl-fw-01" ]] ||
    die "El script debe ejecutarse en $SERVER."

firewall-cmd --state >/dev/null 2>&1 ||
    die "Firewalld no esta activo."

for addr in "$MON_IP" "$DC1_IP" "$DC2_IP"; do
    valid_ip "$addr" || die "IPv4 no valida: $addr"
done


# ============================================================
# 4. DETECTAR Y VALIDAR ZONAS
# ============================================================

[[ -n "$ZONE_MON" ]] || ZONE_MON="$(zone_for_ip "$MON_IP" || true)"
[[ -n "$ZONE_SERV" ]] || ZONE_SERV="$(zone_for_ip "$DC1_IP" || true)"

[[ -n "$ZONE_MON" && -n "$ZONE_SERV" && "$ZONE_MON" != "$ZONE_SERV" ]] ||
    die "No se detectaron zonas distintas. Configurar ZONE_MON y ZONE_SERV."

for zone in "$ZONE_MON" "$ZONE_SERV"; do
    firewall-cmd --get-zones | tr ' ' '\n' | grep -Fxq "$zone" ||
        die "Zona inexistente: $zone"
done

# Evitar configurar zonas de salida basadas en interfaces equivocadas.
[[ "$(zone_for_ip "$MON_IP" || true)" == "$ZONE_MON" ]] ||
    die "ZONE_MON no coincide con la ruta a $MON_IP."

[[ "$(zone_for_ip "$DC1_IP" || true)" == "$ZONE_SERV" ]] ||
    die "ZONE_SERV no coincide con la ruta a $DC1_IP."

[[ "$(zone_for_ip "$DC2_IP" || true)" == "$ZONE_SERV" ]] ||
    die "DC2 no se enruta por la zona de servicios."

info "Zona monitoreo: $ZONE_MON"
info "Zona servicios: $ZONE_SERV"


# ============================================================
# 5. CONFIGURAR POLITICAS PERMANENTES
# ============================================================

ensure_policy permanent "$POLICY_MON_DC" "$ZONE_MON" "$ZONE_SERV" 10050 \
    "$MON_IP" "$DC1_IP" "$MON_IP" "$DC2_IP"

ensure_policy permanent "$POLICY_DC_MON" "$ZONE_SERV" "$ZONE_MON" 10051 \
    "$DC1_IP" "$MON_IP" "$DC2_IP" "$MON_IP"

firewall-cmd --check-config >/dev/null ||
    die "Configuracion permanente de firewalld invalida."


# ============================================================
# 6. ACTIVAR POLITICAS NUEVAS EN RUNTIME
# ============================================================

# Se utiliza el mismo procedimiento de 3-RL-FW-add_MON_AD.sh.
# Un reload puede descartar configuraciones exclusivamente runtime.
# Nunca se recarga firewalld sin autorizacion del operador.

if ! policy_exists runtime "$POLICY_MON_DC" ||
   ! policy_exists runtime "$POLICY_DC_MON"; then

    info "Una o ambas politicas Zabbix no estan cargadas en runtime."
    info "Se conservaron las politicas y reglas permanentes."
    info "Para activarlas se requiere firewall-cmd --reload."
    info "Un reload puede eliminar cambios exclusivamente runtime."

    [[ -t 0 ]] ||
        die "Activacion pendiente: se requiere una terminal interactiva."

    CONFIRM=""
    read -r -p "Escriba SI para ejecutar firewall-cmd --reload: " CONFIRM || true

    if [[ "$CONFIRM" != "SI" ]]; then
        info "Activacion cancelada. La configuracion permanente queda conservada."
        exit 2
    fi

    firewall-cmd --reload ||
        die "Fallo el reload. Revisar firewalld antes de continuar."

    firewall-cmd --state >/dev/null 2>&1 ||
        die "Firewalld no responde despues del reload."

    policy_exists runtime "$POLICY_MON_DC" ||
        die "La politica $POLICY_MON_DC no quedo activa."

    policy_exists runtime "$POLICY_DC_MON" ||
        die "La politica $POLICY_DC_MON no quedo activa."
fi


# ============================================================
# 7. CONFIGURAR Y VERIFICAR POLITICAS RUNTIME
# ============================================================

ensure_policy runtime "$POLICY_MON_DC" "$ZONE_MON" "$ZONE_SERV" 10050 \
    "$MON_IP" "$DC1_IP" "$MON_IP" "$DC2_IP"

ensure_policy runtime "$POLICY_DC_MON" "$ZONE_SERV" "$ZONE_MON" 10051 \
    "$DC1_IP" "$MON_IP" "$DC2_IP"


# ============================================================
# 8. VERIFICACION FINAL
# ============================================================

firewall-cmd --check-config >/dev/null ||
    die "Configuracion permanente de firewalld invalida."

ok "Politicas Zabbix verificadas en permanente y runtime."
info "No se reinicio el servicio firewalld."
info "Verificar conectividad TCP/10050 y TCP/10051 extremo a extremo."
