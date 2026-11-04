#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Recoleccion UY - RL-FW-01
# Script: 3-RL-FW-add_MON_AD.sh
#
# OBJETIVO:
#   Permitir comunicacion desde RL-MON-01 hacia los
#   controladores de dominio Active Directory.
#
# ORIGEN:
#   RL-MON-01: 192.168.20.20
#
# DESTINOS:
#   WS-DC-01: 192.168.10.20
#   WS-DC-02: 192.168.10.21
#
# POLITICA:
#   rec-mon-to-serv
#
# ZONAS:
#   Ingress: rec-monitoreo
#   Egress : rec-servicios
#
# FUNCIONES:
#   1. Verificar permisos y servidor.
#   2. Verificar Firewalld.
#   3. Verificar zonas existentes.
#   4. Crear politica cuando no exista.
#   5. Configurar asociaciones de zonas.
#   6. Verificar y agregar reglas permanentes.
#   7. Activar politica mediante reload controlado.
#   8. Reiniciar Firewalld si reload no activa la politica.
#   9. Verificar y agregar reglas runtime.
#  10. Verificar politica y reglas.
#  11. Revertir cambios ante errores previos a recarga.
#  12. Mostrar resultado final.
#
# SEGURIDAD:
#   - No ejecuta 2-RL-FW_config.sh.
#   - No recrea politicas existentes.
#   - No elimina reglas anteriores.
#   - No modifica interfaces.
#   - No modifica NAT.
#   - No cambia configuraciones SSH.
#   - No habilita trafico general entre zonas.
#   - Solo agrega reglas AD especificas.
#
# IMPORTANTE:
#   Una politica nueva se crea en permanente.
#
#   Si no existe en runtime:
#     1. Se solicita confirmacion.
#     2. Se ejecuta firewall-cmd --reload.
#     3. Se comprueba que la politica este activa.
#     4. Si no se activa, se ofrece reiniciar firewalld.
#     5. Se verifican zonas y reglas runtime.
#
#   El reinicio de firewalld se realiza mediante:
#     systemctl restart firewalld
#
#   Tanto reload como restart pueden afectar reglas
#   exclusivamente runtime y conexiones existentes.
#
#   Ejecutar desde consola de RL-FW-01 cuando se
#   necesite activar una politica nueva.
#
# REEJECUCION:
#   El script es idempotente.
#   No duplica reglas existentes.
#
# CODIGOS:
#   0 = Configuracion permanente y runtime verificadas.
#   1 = Error de ejecucion o validacion.
#   2 = Configuracion permanente preparada,
#       activacion pendiente.
# ============================================================

export LC_ALL=C

# ------------------------------------------------------------
# 1. Configuracion general
# ------------------------------------------------------------

readonly POLICY="rec-mon-to-serv"

readonly ZONE_SOURCE="rec-monitoreo"
readonly ZONE_DESTINATION="rec-servicios"

readonly MON_IP="192.168.20.20"

readonly DC1_IP="192.168.10.20"
readonly DC2_IP="192.168.10.21"

readonly -a DOMAIN_CONTROLLERS=(
    "$DC1_IP"
    "$DC2_IP"
)

readonly -a AD_PORTS=(
    "53 tcp"
    "53 udp"
    "88 tcp"
    "88 udp"
    "389 tcp"
    "389 udp"
    "636 tcp"
    "464 tcp"
    "464 udp"
    "123 udp"
    "3268 tcp"
    "3269 tcp"
    "445 tcp"
)

declare -a AD_RULES=()

declare -a PERMANENT_ADDED_RULES=()
declare -a RUNTIME_ADDED_RULES=()

POLICY_CREATED=false

INGRESS_ADDED=false
EGRESS_ADDED=false

RUNTIME_INGRESS_ADDED=false
RUNTIME_EGRESS_ADDED=false

RELOAD_REQUIRED=false
RELOAD_EXECUTED=false
RESTART_EXECUTED=false

ACTIVATION_ATTEMPTED=false
PRESERVE_PERMANENT=false

COMPLETED=false

# ------------------------------------------------------------
# 2. Funciones generales
# ------------------------------------------------------------

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

info() {
    echo "[INFO] $*"
}

ok() {
    echo "[OK] $*"
}

warning() {
    echo "[ADVERTENCIA] $*" >&2
}

section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

# ------------------------------------------------------------
# 3. Consultar politica
# ------------------------------------------------------------

policy_exists() {

    local mode="$1"
    local policies

    if [[ "$mode" == "permanent" ]]; then

        policies="$(
            firewall-cmd --permanent --get-policies
        )" || die "No se pudieron consultar politicas permanentes."

    else

        policies="$(
            firewall-cmd --get-policies
        )" || die "No se pudieron consultar politicas runtime."

    fi

    [[ " $policies " == *" $POLICY "* ]]
}

# ------------------------------------------------------------
# 4. Consultar zona
# ------------------------------------------------------------

zone_exists() {

    local mode="$1"
    local zone="$2"
    local zones

    if [[ "$mode" == "permanent" ]]; then

        zones="$(
            firewall-cmd --permanent --get-zones
        )" || die "No se pudieron consultar zonas permanentes."

    else

        zones="$(
            firewall-cmd --get-zones
        )" || die "No se pudieron consultar zonas runtime."

    fi

    [[ " $zones " == *" $zone "* ]]
}

# ------------------------------------------------------------
# 5. Reversion ante errores
# ------------------------------------------------------------

rollback() {

    local status=$?
    local rule
    local index
    local failed=false

    if [[ "$COMPLETED" == true ]]; then
        return 0
    fi

    # No revertir configuracion permanente validada
    # cuando el administrador pospone la activacion.

    if [[ "$PRESERVE_PERMANENT" == true ]]; then
        return 0
    fi

    # No efectuar rollback despues de intentar reload
    # o restart. La configuracion global de Firewalld
    # pudo cambiar y requiere revision administrativa.

    if [[ "$ACTIVATION_ATTEMPTED" == true ]]; then

        warning "Error despues de intentar activar Firewalld."
        warning "No se realiza reversion automatica."
        warning "Revisar configuracion permanente y runtime."

        return 0
    fi

    # No mostrar reversion si no hubo modificaciones.

    if [[ "$POLICY_CREATED" == false &&
          "$INGRESS_ADDED" == false &&
          "$EGRESS_ADDED" == false &&
          "$RUNTIME_INGRESS_ADDED" == false &&
          "$RUNTIME_EGRESS_ADDED" == false ]] &&
       (( ${#PERMANENT_ADDED_RULES[@]} == 0 &&
          ${#RUNTIME_ADDED_RULES[@]} == 0 )); then

        return 0
    fi

    section "Revirtiendo cambios de esta ejecucion"

    # Revertir reglas runtime agregadas.

    for ((index=${#RUNTIME_ADDED_RULES[@]}-1;
          index>=0;
          index--)); do

        rule="${RUNTIME_ADDED_RULES[$index]}"

        firewall-cmd \
            --policy="$POLICY" \
            --remove-rich-rule="$rule" \
            >/dev/null 2>&1 || failed=true

    done

    # Revertir asociaciones runtime agregadas.

    if [[ "$RUNTIME_EGRESS_ADDED" == true ]]; then

        firewall-cmd \
            --policy="$POLICY" \
            --remove-egress-zone="$ZONE_DESTINATION" \
            >/dev/null 2>&1 || failed=true

    fi

    if [[ "$RUNTIME_INGRESS_ADDED" == true ]]; then

        firewall-cmd \
            --policy="$POLICY" \
            --remove-ingress-zone="$ZONE_SOURCE" \
            >/dev/null 2>&1 || failed=true

    fi

    # Si la politica fue creada durante esta ejecucion,
    # revertirla completa sin afectar otras politicas.

    if [[ "$POLICY_CREATED" == true ]]; then

        firewall-cmd \
            --permanent \
            --delete-policy="$POLICY" \
            >/dev/null 2>&1 || failed=true

    else

        # Revertir solamente reglas permanentes nuevas.

        for ((index=${#PERMANENT_ADDED_RULES[@]}-1;
              index>=0;
              index--)); do

            rule="${PERMANENT_ADDED_RULES[$index]}"

            firewall-cmd \
                --permanent \
                --policy="$POLICY" \
                --remove-rich-rule="$rule" \
                >/dev/null 2>&1 || failed=true

        done

        if [[ "$EGRESS_ADDED" == true ]]; then

            firewall-cmd \
                --permanent \
                --policy="$POLICY" \
                --remove-egress-zone="$ZONE_DESTINATION" \
                >/dev/null 2>&1 || failed=true

        fi

        if [[ "$INGRESS_ADDED" == true ]]; then

            firewall-cmd \
                --permanent \
                --policy="$POLICY" \
                --remove-ingress-zone="$ZONE_SOURCE" \
                >/dev/null 2>&1 || failed=true

        fi

    fi

    if [[ "$failed" == true ]]; then

        warning "Reversion incompleta."
        warning "Revisar configuracion de Firewalld."

    else

        ok "Reversion finalizada."

    fi

    return 0
}

trap rollback EXIT

# ------------------------------------------------------------
# 6. Verificar requisitos
# ------------------------------------------------------------

section "Verificando requisitos"

(( EUID == 0 )) ||
    die "Ejecutar como root."

for CMD in \
    hostname \
    firewall-cmd \
    systemctl
do

    command -v "$CMD" >/dev/null 2>&1 ||
        die "Dependencia ausente: $CMD"

done

[[ -r /etc/os-release ]] ||
    die "No se puede identificar el sistema operativo."

# shellcheck source=/etc/os-release
source /etc/os-release

[[ "${ID:-}" == "rocky" ]] ||
    die "Se requiere Rocky Linux."

[[ "${VERSION_ID%%.*}" == "9" ]] ||
    die "Se requiere Rocky Linux 9."

HOST="$(hostname -s)"
HOST="${HOST,,}"

[[ "$HOST" == "rl-fw-01" ]] ||
    die "Servidor incorrecto: $HOST"

ok "Servidor verificado: RL-FW-01."
ok "Rocky Linux 9 verificado."

# ------------------------------------------------------------
# 7. Verificar Firewalld
# ------------------------------------------------------------

section "Verificando Firewalld"

firewall-cmd --state >/dev/null 2>&1 ||
    die "Firewalld no esta activo."

firewall-cmd --check-config >/dev/null ||
    die "Configuracion permanente invalida."

ok "Firewalld activo."
ok "Configuracion permanente valida."

# ------------------------------------------------------------
# 8. Verificar zonas
# ------------------------------------------------------------

section "Verificando zonas"

for ZONE in "$ZONE_SOURCE" "$ZONE_DESTINATION"; do

    zone_exists permanent "$ZONE" ||
        die "Falta zona permanente: $ZONE"

    zone_exists runtime "$ZONE" ||
        die "Falta zona runtime: $ZONE"

    ok "Zona disponible: $ZONE"

done

# ------------------------------------------------------------
# 9. Crear politica si no existe
# ------------------------------------------------------------

section "Verificando politica"

if policy_exists permanent; then

    ok "Politica permanente existente: $POLICY"

else

    info "Politica permanente no encontrada."
    info "Creando politica: $POLICY"

    firewall-cmd \
        --permanent \
        --new-policy="$POLICY" ||
        die "No se pudo crear la politica."

    POLICY_CREATED=true

    ok "Politica permanente creada."

fi

# ------------------------------------------------------------
# 10. Verificar target de politica
# ------------------------------------------------------------

section "Verificando target"

TARGET="$(
    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --get-target
)" || die "No se pudo consultar target."

[[ "$TARGET" == "CONTINUE" ]] ||
    die "Target permanente inesperado: $TARGET"

ok "Target permanente CONTINUE."

if policy_exists runtime; then

    RUNTIME_TARGET="$(
        firewall-cmd \
            --policy="$POLICY" \
            --get-target
    )" || die "No se pudo consultar target activo."

    [[ "$RUNTIME_TARGET" == "CONTINUE" ]] ||
        die "Target runtime inesperado: $RUNTIME_TARGET"

    ok "Target runtime CONTINUE."

else

    RELOAD_REQUIRED=true

    warning "Politica no cargada en runtime."
    info "Se preparara su activacion."

fi

# ------------------------------------------------------------
# 11. Configurar zonas permanentes
# ------------------------------------------------------------

section "Configurando zonas permanentes"

if firewall-cmd \
    --permanent \
    --policy="$POLICY" \
    --query-ingress-zone="$ZONE_SOURCE" \
    >/dev/null 2>&1; then

    ok "Ingress permanente existente."

else

    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --add-ingress-zone="$ZONE_SOURCE" ||
        die "No se pudo agregar ingress permanente."

    INGRESS_ADDED=true

    ok "Ingress permanente agregado."

fi

if firewall-cmd \
    --permanent \
    --policy="$POLICY" \
    --query-egress-zone="$ZONE_DESTINATION" \
    >/dev/null 2>&1; then

    ok "Egress permanente existente."

else

    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --add-egress-zone="$ZONE_DESTINATION" ||
        die "No se pudo agregar egress permanente."

    EGRESS_ADDED=true

    ok "Egress permanente agregado."

fi

# ------------------------------------------------------------
# 12. Preparar reglas AD
# ------------------------------------------------------------

section "Preparando reglas Active Directory"

for DC in "${DOMAIN_CONTROLLERS[@]}"; do

    for ENTRY in "${AD_PORTS[@]}"; do

        read -r PORT PROTOCOL <<< "$ENTRY"

        RULE="rule family=\"ipv4\" source address=\"${MON_IP}\" destination address=\"${DC}\" port port=\"${PORT}\" protocol=\"${PROTOCOL}\" accept"

        AD_RULES+=("$RULE")

    done

done

ok "Reglas preparadas: ${#AD_RULES[@]}"

# ------------------------------------------------------------
# 13. Mostrar configuracion
# ------------------------------------------------------------

section "Configuracion solicitada"

info "Servidor: RL-FW-01"
info "Origen: RL-MON-01 ($MON_IP)"
info "Destino DC1: $DC1_IP"
info "Destino DC2: $DC2_IP"
info "Politica: $POLICY"
info "Ingress: $ZONE_SOURCE"
info "Egress: $ZONE_DESTINATION"

echo
info "Puertos Active Directory:"

for ENTRY in "${AD_PORTS[@]}"; do

    read -r PORT PROTOCOL <<< "$ENTRY"

    info "  ${PROTOCOL^^}/$PORT"

done

# ------------------------------------------------------------
# 14. Configurar reglas permanentes
# ------------------------------------------------------------

section "Configurando reglas permanentes"

PERMANENT_EXISTING=0

for RULE in "${AD_RULES[@]}"; do

    if firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --query-rich-rule="$RULE" \
        >/dev/null 2>&1; then

        ((PERMANENT_EXISTING+=1))
        continue

    fi

    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --add-rich-rule="$RULE" ||
        die "Error agregando regla permanente."

    PERMANENT_ADDED_RULES+=("$RULE")

done

ok "Reglas existentes: $PERMANENT_EXISTING"
ok "Reglas agregadas: ${#PERMANENT_ADDED_RULES[@]}"

# ------------------------------------------------------------
# 15. Verificar configuracion permanente
# ------------------------------------------------------------

section "Verificando configuracion permanente"

firewall-cmd \
    --permanent \
    --policy="$POLICY" \
    --query-ingress-zone="$ZONE_SOURCE" \
    >/dev/null 2>&1 ||
    die "Ingress permanente no confirmado."

firewall-cmd \
    --permanent \
    --policy="$POLICY" \
    --query-egress-zone="$ZONE_DESTINATION" \
    >/dev/null 2>&1 ||
    die "Egress permanente no confirmado."

for RULE in "${AD_RULES[@]}"; do

    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --query-rich-rule="$RULE" \
        >/dev/null 2>&1 ||
        die "Falta una regla permanente."

done

firewall-cmd --check-config >/dev/null ||
    die "Configuracion permanente invalida."

ok "Politica permanente verificada."
ok "26 reglas permanentes verificadas."

# ------------------------------------------------------------
# 16. Activar politica nueva
# ------------------------------------------------------------

section "Verificando activacion de politica"

if [[ "$RELOAD_REQUIRED" == true ]]; then

    warning "La politica no existe en runtime."
    warning "Debe cargarse la configuracion permanente."

    echo
    echo "Politicas runtime:"
    firewall-cmd --get-policies

    echo
    echo "Politicas permanentes:"
    firewall-cmd --permanent --get-policies

    echo
    warning "Un reload puede descartar cambios runtime."
    warning "Puede afectar conexiones o reglas temporales."
    warning "Se recomienda ejecutar desde consola."

    echo
    echo "Verificar antes de continuar:"
    echo "  - Acceso administrativo a RL-FW-01."
    echo "  - Consola de recuperacion disponible."
    echo "  - Otras politicas permanentes verificadas."
    echo "  - Cambios runtime importantes respaldados."
    echo

    CONFIRM=""

    if [[ -t 0 ]]; then

        read -r -p \
            "Escriba SI para activar la politica: " \
            CONFIRM || true

    fi

    if [[ "$CONFIRM" != "SI" ]]; then

        warning "Activacion no autorizada."
        warning "Configuracion permanente conservada."
        warning "La politica sigue pendiente en runtime."

        PRESERVE_PERMANENT=true
        exit 2

    fi

    # Marcar antes de intentar cualquier activacion.
    # Desde este punto no se realiza rollback automatico.

    ACTIVATION_ATTEMPTED=true

    # --------------------------------------------------------
    # 16.1 Intentar reload
    # --------------------------------------------------------

    info "Ejecutando firewall-cmd --reload..."

    RELOAD_EXECUTED=true

    if firewall-cmd --reload; then

        ok "Reload ejecutado."

    else

        warning "Reload no finalizo correctamente."

    fi

    # --------------------------------------------------------
    # 16.2 Verificar resultado del reload
    # --------------------------------------------------------

    if firewall-cmd --state >/dev/null 2>&1 &&
       policy_exists runtime; then

        ok "Politica cargada mediante reload."

    else

        warning "La politica no se encuentra activa."
        warning "Se requiere reiniciar el servicio firewalld."

        # ----------------------------------------------------
        # 16.3 Reinicio controlado de Firewalld
        # ----------------------------------------------------

        echo
        warning "El reinicio del servicio puede interrumpir"
        warning "conexiones existentes y descartar reglas"
        warning "exclusivamente runtime."

        echo
        echo "Operacion propuesta:"
        echo "  systemctl restart firewalld"
        echo

        RESTART_CONFIRM=""

        if [[ -t 0 ]]; then

            read -r -p \
                "Escriba REINICIAR para continuar: " \
                RESTART_CONFIRM || true

        fi

        if [[ "$RESTART_CONFIRM" != "REINICIAR" ]]; then

            warning "Reinicio no autorizado."
            warning "Politica permanente conservada."
            warning "Activacion runtime pendiente."

            PRESERVE_PERMANENT=true
            exit 2

        fi

        info "Reiniciando servicio firewalld..."

        RESTART_EXECUTED=true

        systemctl restart firewalld ||
            die "No se pudo reiniciar firewalld."

        ok "Servicio firewalld reiniciado."

        # ----------------------------------------------------
        # 16.4 Verificar servicio despues del reinicio
        # ----------------------------------------------------

        systemctl is-active --quiet firewalld ||
            die "Firewalld no quedo activo."

        firewall-cmd --state >/dev/null 2>&1 ||
            die "Firewalld no responde despues del reinicio."

        policy_exists runtime ||
            die "La politica sigue sin estar activa."

        ok "Politica activada despues del reinicio."

    fi

fi

# ------------------------------------------------------------
# 17. Verificar politica runtime
# ------------------------------------------------------------

section "Verificando politica activa"

policy_exists runtime ||
    die "La politica no esta cargada en runtime."

ok "Politica activa: $POLICY"

RUNTIME_TARGET="$(
    firewall-cmd \
        --policy="$POLICY" \
        --get-target
)" || die "No se pudo consultar target runtime."

[[ "$RUNTIME_TARGET" == "CONTINUE" ]] ||
    die "Target runtime inesperado: $RUNTIME_TARGET"

ok "Target runtime CONTINUE."

# ------------------------------------------------------------
# 18. Configurar zonas runtime
# ------------------------------------------------------------

section "Configurando zonas runtime"

if firewall-cmd \
    --policy="$POLICY" \
    --query-ingress-zone="$ZONE_SOURCE" \
    >/dev/null 2>&1; then

    ok "Ingress runtime existente."

else

    firewall-cmd \
        --policy="$POLICY" \
        --add-ingress-zone="$ZONE_SOURCE" ||
        die "No se pudo agregar ingress runtime."

    RUNTIME_INGRESS_ADDED=true

    ok "Ingress runtime agregado."

fi

if firewall-cmd \
    --policy="$POLICY" \
    --query-egress-zone="$ZONE_DESTINATION" \
    >/dev/null 2>&1; then

    ok "Egress runtime existente."

else

    firewall-cmd \
        --policy="$POLICY" \
        --add-egress-zone="$ZONE_DESTINATION" ||
        die "No se pudo agregar egress runtime."

    RUNTIME_EGRESS_ADDED=true

    ok "Egress runtime agregado."

fi

# ------------------------------------------------------------
# 19. Configurar reglas runtime
# ------------------------------------------------------------

section "Configurando reglas activas"

RUNTIME_EXISTING=0

for RULE in "${AD_RULES[@]}"; do

    if firewall-cmd \
        --policy="$POLICY" \
        --query-rich-rule="$RULE" \
        >/dev/null 2>&1; then

        ((RUNTIME_EXISTING+=1))
        continue

    fi

    firewall-cmd \
        --policy="$POLICY" \
        --add-rich-rule="$RULE" ||
        die "No se pudo agregar una regla activa."

    RUNTIME_ADDED_RULES+=("$RULE")

done

ok "Reglas activas existentes: $RUNTIME_EXISTING"
ok "Reglas activas nuevas: ${#RUNTIME_ADDED_RULES[@]}"

# ------------------------------------------------------------
# 20. Verificar configuracion runtime
# ------------------------------------------------------------

section "Verificando configuracion activa"

firewall-cmd \
    --policy="$POLICY" \
    --query-ingress-zone="$ZONE_SOURCE" \
    >/dev/null 2>&1 ||
    die "Ingress runtime no confirmado."

firewall-cmd \
    --policy="$POLICY" \
    --query-egress-zone="$ZONE_DESTINATION" \
    >/dev/null 2>&1 ||
    die "Egress runtime no confirmado."

for RULE in "${AD_RULES[@]}"; do

    firewall-cmd \
        --policy="$POLICY" \
        --query-rich-rule="$RULE" \
        >/dev/null 2>&1 ||
        die "Falta una regla activa."

done

ok "Politica runtime verificada."
ok "26 reglas activas verificadas."

# ------------------------------------------------------------
# 21. Verificar integridad de Firewalld
# ------------------------------------------------------------

section "Verificando integridad de Firewalld"

firewall-cmd --check-config >/dev/null ||
    die "Configuracion permanente invalida."

firewall-cmd --state >/dev/null 2>&1 ||
    die "Firewalld no responde."

systemctl is-active --quiet firewalld ||
    die "Servicio firewalld inactivo."

policy_exists permanent ||
    die "Politica permanente desaparecida."

policy_exists runtime ||
    die "Politica runtime desaparecida."

ok "Firewalld activo."
ok "Configuracion permanente valida."
ok "Politica disponible en ambos modos."

# ------------------------------------------------------------
# 22. Confirmar finalizacion
# ------------------------------------------------------------

COMPLETED=true

# ------------------------------------------------------------
# 23. Resultado final
# ------------------------------------------------------------

section "CONFIGURACION FINALIZADA"

ok "Acceso Active Directory configurado."

echo
echo "Servidor:"
echo "  RL-FW-01"

echo
echo "Origen:"
echo "  RL-MON-01"
echo "  $MON_IP"

echo
echo "Destinos:"
echo "  WS-DC-01: $DC1_IP"
echo "  WS-DC-02: $DC2_IP"

echo
echo "Politica:"
echo "  $POLICY"

echo
echo "Zonas:"
echo "  Ingress: $ZONE_SOURCE"
echo "  Egress : $ZONE_DESTINATION"

echo
echo "Reglas:"
echo "  Total verificadas  : ${#AD_RULES[@]}"
echo "  Permanentes nuevas : ${#PERMANENT_ADDED_RULES[@]}"
echo "  Activas nuevas     : ${#RUNTIME_ADDED_RULES[@]}"

echo
echo "Estado:"
echo "  Politica permanente: OK"
echo "  Politica runtime   : OK"
echo "  Reglas permanentes : OK"
echo "  Reglas runtime     : OK"
echo "  Configuracion      : VALIDADA"

echo
echo "Activacion Firewalld:"

if [[ "$RESTART_EXECUTED" == true ]]; then

    echo "  RESTART - Servicio reiniciado."

elif [[ "$RELOAD_EXECUTED" == true ]]; then

    echo "  RELOAD - Configuracion recargada."

else

    echo "  NO REQUERIDA - Politica ya activa."

fi

echo
echo "Configuracion activa:"
firewall-cmd --policy="$POLICY" --list-all

echo
echo "Configuracion permanente:"
firewall-cmd --permanent --policy="$POLICY" --list-all

echo
echo "Seguridad:"
echo "  No se modificaron otras politicas directamente."
echo "  No se modificaron interfaces."
echo "  No se modifico NAT."
echo "  No se eliminaron reglas preexistentes."
echo "  No se ejecuto 2-RL-FW_config.sh."

echo
echo "IMPORTANTE:"
echo "Las reglas estan configuradas y activas en Firewalld."
echo "Esto no confirma conectividad real con los DC."
echo "Verificar DNS, Kerberos y LDAP desde RL-MON-01."

echo
ok "Script finalizado correctamente."