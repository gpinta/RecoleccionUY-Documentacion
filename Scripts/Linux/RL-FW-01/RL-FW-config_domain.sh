#!/bin/bash

# ============================================================
# Recoleccion UY
# Configuracion Active Directory - RL-FW-01
#
# Basado en:
#
#   Scripts/Linux/config_domain_2dns_v1.3.sh
#
# Funciones:
#   - Verifica configuracion de red
#   - Verifica hostname
#   - Verifica /etc/hosts
#   - Verifica resolucion DNS
#   - Verifica registros SRV mediante host
#   - Une RL-FW-01 al dominio neltek.uy
#   - Configura SSSD
#   - Habilita cache de credenciales
#   - Configura creacion automatica de directorios HOME
#
# Este script NO:
#   - Modifica IP
#   - Modifica gateway
#   - Modifica rutas
#   - Configura NAT
#   - Configura firewalld
#   - Configura usuarios autorizados para SSH
#   - Configura grupos AD para SSH
#   - Configura sudo
#
# La configuracion de red debe haberse realizado previamente
# mediante:
#
#   ./config_rl_fw.sh
#
# ============================================================


# ============================================================
# VARIABLES
# ============================================================

INTERFACE="ens36"

IPADDR="192.168.10.1"

HOSTNAME="RL-FW-01"

PREFIX="24"


DC1_IP="192.168.10.20"
DC1_NAME="WS-DC-01"

DC2_IP="192.168.10.21"
DC2_NAME="WS-DC-02"


DNS1="$DC1_IP"
DNS2="$DC2_IP"


DOMAIN="neltek.uy"

REALM="NELTEK.UY"

NETBIOS_DOMAIN="NELTEK"


SSSD_CONF="/etc/sssd/sssd.conf"


HOSTS_BEGIN="# BEGIN RECOLECCION-UY MANAGED BLOCK"
HOSTS_END="# END RECOLECCION-UY MANAGED BLOCK"


TIMESTAMP="$(date +%Y%m%d_%H%M%S)"


# ============================================================
# FUNCIONES AUXILIARES
# ============================================================

print_header() {

    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}


print_warning() {

    echo
    echo "[ADVERTENCIA] $1"
}


print_error() {

    echo
    echo "[ERROR] $1"
}


# ============================================================
# COMPROBAR ROOT
# ============================================================

if [ "$EUID" -ne 0 ]; then

    print_error "Este script debe ejecutarse como root."
    exit 1
fi


# ============================================================
# VALIDAR VARIABLES
# ============================================================

print_header "Validando configuracion"


if [ -z "$INTERFACE" ]; then

    print_error "INTERFACE no puede estar vacia."
    exit 1
fi


if [ -z "$IPADDR" ]; then

    print_error "IPADDR no puede estar vacia."
    exit 1
fi


if [ -z "$HOSTNAME" ]; then

    print_error "HOSTNAME no puede estar vacio."
    exit 1
fi


if [ -z "$DC1_IP" ]; then

    print_error "DC1_IP no puede estar vacia."
    exit 1
fi


if [ -z "$DC2_IP" ]; then

    print_error "DC2_IP no puede estar vacia."
    exit 1
fi


if [ -z "$DOMAIN" ]; then

    print_error "DOMAIN no puede estar vacio."
    exit 1
fi


echo "Configuracion:"
echo
echo "  Interfaz: $INTERFACE"
echo "  IP:       $IPADDR/$PREFIX"
echo "  Hostname: $HOSTNAME"
echo "  Dominio:  $DOMAIN"
echo "  DNS1:     $DNS1 ($DC1_NAME)"
echo "  DNS2:     $DNS2 ($DC2_NAME)"


# ============================================================
# VERIFICAR PAQUETES Y COMANDOS
# ============================================================

print_header "Verificando dependencias necesarias"


REQUIRED_COMMANDS=(
    nmcli
    ip
    hostnamectl
    getent
    host
    realm
    sssctl
    authselect
    systemctl
)


DEPENDENCIES_OK="true"


for COMMAND in "${REQUIRED_COMMANDS[@]}"
do

    if command -v "$COMMAND" >/dev/null 2>&1; then

        echo "[OK] $COMMAND"

    else

        echo "[ERROR] No se encontro el comando $COMMAND."

        DEPENDENCIES_OK="false"
    fi

done


if [ "$DEPENDENCIES_OK" != "true" ]; then

    print_error "Faltan dependencias necesarias."

    echo
    echo "Ejecute previamente:"
    echo
    echo "  ./so_update_fw.sh"

    exit 1
fi


echo
echo "[OK] Dependencias verificadas correctamente."


# ============================================================
# VERIFICAR INTERFAZ DE RED
# ============================================================

print_header "Verificando interfaz de red"


if ! nmcli device status \
    | awk '{print $1}' \
    | grep -Fxq "$INTERFACE"; then

    print_error "No se encontro la interfaz $INTERFACE."

    echo
    echo "Interfaces disponibles:"
    echo

    nmcli device status

    exit 1
fi


echo "[OK] Interfaz encontrada: $INTERFACE"


# ============================================================
# IDENTIFICAR PERFIL NETWORKMANAGER
# ============================================================

CONNECTION_NAME="$(
    nmcli \
        -g GENERAL.CONNECTION \
        device show "$INTERFACE" \
        2>/dev/null \
        | head -n 1
)"


if [ -z "$CONNECTION_NAME" ] ||
   [ "$CONNECTION_NAME" = "--" ]; then

    CONNECTION_NAME="$(
        nmcli -t -f NAME,DEVICE connection show \
            | awk -F: -v dev="$INTERFACE" '
                $2 == dev {
                    print $1
                }
            ' \
            | head -n 1
    )"
fi


if [ -z "$CONNECTION_NAME" ]; then

    print_error "No se pudo identificar un perfil de NetworkManager asociado a $INTERFACE."

    echo
    echo "Perfiles disponibles:"
    echo

    nmcli connection show

    exit 1
fi


echo "Perfil de NetworkManager detectado:"
echo "  $CONNECTION_NAME"


# ============================================================
# VERIFICAR CONFIGURACION DE RED EXISTENTE
# ============================================================

print_header "Verificando configuracion de red"


echo "Esperado:"
echo
echo "  Interfaz: $INTERFACE"
echo "  IP:       $IPADDR/$PREFIX"
echo "  DNS1:     $DNS1"
echo "  DNS2:     $DNS2"
echo


if ip -4 addr show dev "$INTERFACE" \
    | grep -Fq "$IPADDR/$PREFIX"; then

    echo "[OK] IP $IPADDR/$PREFIX presente en $INTERFACE."

else

    print_error "No se encontro $IPADDR/$PREFIX en $INTERFACE."

    echo
    echo "Ejecute previamente:"
    echo
    echo "  ./config_rl_fw.sh"

    exit 1
fi


echo
echo "DNS configurados:"
echo

nmcli device show "$INTERFACE" \
    | grep 'IP4.DNS' \
    || true


# ============================================================
# CONFIGURAR HOSTNAME
# ============================================================

print_header "Configurando hostname"


CURRENT_HOSTNAME="$(hostnamectl --static 2>/dev/null)"


if [ "$CURRENT_HOSTNAME" = "$HOSTNAME" ]; then

    echo "[OK] El hostname ya esta configurado como $HOSTNAME."

else

    echo "Hostname actual: $CURRENT_HOSTNAME"
    echo "Nuevo hostname:  $HOSTNAME"

    hostnamectl set-hostname "$HOSTNAME"

    if [ $? -ne 0 ]; then

        print_error "No se pudo configurar el hostname."
        exit 1
    fi

    echo "[OK] Hostname configurado correctamente."
fi


# ============================================================
# CONFIGURAR /etc/hosts
# ============================================================

print_header "Configurando /etc/hosts"


HOSTS_BACKUP="/etc/hosts.bak.$TIMESTAMP"


cp -a /etc/hosts "$HOSTS_BACKUP"


if [ $? -ne 0 ]; then

    print_error "No se pudo crear una copia de seguridad de /etc/hosts."
    exit 1
fi


echo "Backup:"
echo "  $HOSTS_BACKUP"


HOSTS_TMP="$(mktemp)"


awk \
    -v begin="$HOSTS_BEGIN" \
    -v end="$HOSTS_END" \
    -v server_ip="$IPADDR" \
    -v dc1_ip="$DC1_IP" \
    -v dc2_ip="$DC2_IP" \
'
BEGIN {
    in_managed_block = 0
}

$0 == begin {
    in_managed_block = 1
    next
}

$0 == end {
    in_managed_block = 0
    next
}

in_managed_block {
    next
}

$1 == server_ip {
    next
}

$1 == dc1_ip {
    next
}

$1 == dc2_ip {
    next
}

{
    print
}
' /etc/hosts > "$HOSTS_TMP"


if [ $? -ne 0 ]; then

    rm -f "$HOSTS_TMP"

    print_error "No se pudo preparar la nueva configuracion de /etc/hosts."
    exit 1
fi


echo >> "$HOSTS_TMP"


cat >> "$HOSTS_TMP" <<EOF
$HOSTS_BEGIN
$IPADDR     $HOSTNAME.$DOMAIN $HOSTNAME
$DC1_IP     $DC1_NAME.$DOMAIN $DC1_NAME
$DC2_IP     $DC2_NAME.$DOMAIN $DC2_NAME
$HOSTS_END
EOF


cp "$HOSTS_TMP" /etc/hosts

RESULT=$?


rm -f "$HOSTS_TMP"


if [ $RESULT -ne 0 ]; then

    print_error "No se pudo actualizar /etc/hosts."

    cp -a "$HOSTS_BACKUP" /etc/hosts

    echo "Se restauro el archivo anterior."

    exit 1
fi


chmod 644 /etc/hosts
chown root:root /etc/hosts


echo "[OK] /etc/hosts actualizado sin reemplazar entradas externas."


# ============================================================
# VERIFICAR DNS
# ============================================================

print_header "Verificando DNS"


echo "Servidores DNS configurados para $INTERFACE:"
echo

nmcli device show "$INTERFACE" \
    | grep 'IP4.DNS' \
    || true


echo
echo "Consultando dominio $DOMAIN..."
echo


if getent hosts "$DOMAIN" >/dev/null 2>&1; then

    echo "[OK] El dominio $DOMAIN puede resolverse."

else

    print_warning "No se pudo resolver directamente $DOMAIN."

    echo
    echo "Esto no necesariamente implica un fallo de Active Directory,"
    echo "pero debe verificarse la resolucion DNS."
fi


# ============================================================
# VERIFICAR REGISTROS SRV DE ACTIVE DIRECTORY
# ============================================================

echo
echo "Verificando registros SRV LDAP contra DNS1:"
echo "  $DC1_NAME - $DNS1"
echo


if host \
    -t SRV \
    "_ldap._tcp.$DOMAIN" \
    "$DNS1" \
    >/dev/null 2>&1; then

    host \
        -t SRV \
        "_ldap._tcp.$DOMAIN" \
        "$DNS1" \
        2>/dev/null \
        || true

    echo "[OK] DNS1 responde consultas SRV del dominio."

else

    print_warning "DNS1 no respondio correctamente a la consulta SRV."
fi


echo
echo "Verificando registros SRV LDAP contra DNS2:"
echo "  $DC2_NAME - $DNS2"
echo


if host \
    -t SRV \
    "_ldap._tcp.$DOMAIN" \
    "$DNS2" \
    >/dev/null 2>&1; then

    host \
        -t SRV \
        "_ldap._tcp.$DOMAIN" \
        "$DNS2" \
        2>/dev/null \
        || true

    echo "[OK] DNS2 responde consultas SRV del dominio."

else

    print_warning "DNS2 no respondio correctamente a la consulta SRV."
fi


# ============================================================
# COMPROBAR SI YA PERTENECE AL DOMINIO
# ============================================================

print_header "Comprobando estado del dominio"


ALREADY_JOINED="false"


if realm list 2>/dev/null \
    | grep -qiE "^[[:space:]]*domain-name:[[:space:]]*$DOMAIN[[:space:]]*$"; then

    ALREADY_JOINED="true"

    echo "[OK] El servidor ya pertenece al dominio $DOMAIN."
    echo "No se ejecutara realm join nuevamente."

else

    echo "El servidor todavia no figura unido al dominio $DOMAIN."
fi


# ============================================================
# DESCUBRIR ACTIVE DIRECTORY
# ============================================================

print_header "Descubriendo dominio Active Directory"


if realm discover \
    --server-software=active-directory \
    "$DOMAIN"; then

    echo
    echo "[OK] Dominio $DOMAIN descubierto correctamente."

else

    echo

    if [ "$ALREADY_JOINED" = "true" ]; then

        print_warning "No fue posible descubrir $DOMAIN en este momento."

        echo
        echo "El servidor ya figura unido al dominio, por lo que no"
        echo "se intentara realizar una nueva union."
        echo
        echo "Se continuara con las validaciones locales."

    else

        print_warning "No fue posible descubrir previamente el dominio $DOMAIN."

        echo
        echo "Se continuara con realm join para que realmd realice"
        echo "su propia deteccion durante el intento de union."
        echo
        echo "Si realm join falla, verifique:"
        echo
        echo "  - DNS1: $DNS1 ($DC1_NAME)"
        echo "  - DNS2: $DNS2 ($DC2_NAME)"
        echo "  - registros SRV de Active Directory"
        echo "  - conectividad con los controladores de dominio"
        echo "  - fecha y hora del servidor"
        echo "  - servicios DNS / Active Directory"
    fi
fi


# ============================================================
# UNIR EQUIPO AL DOMINIO
# ============================================================

if [ "$ALREADY_JOINED" != "true" ]; then

    print_header "Union al dominio $DOMAIN"


    read -r -p "Usuario con permisos para unir equipos al dominio: " ADMIN_USER


    if [ -z "$ADMIN_USER" ]; then

        print_error "Debe indicar un usuario."
        exit 1
    fi


    echo
    echo "Se solicitara la contrasena directamente por realm."
    echo "La contrasena NO sera almacenada por este script."
    echo


    realm join \
        --server-software=active-directory \
        --client-software=sssd \
        --user="$ADMIN_USER" \
        "$DOMAIN" \
        --verbose


    if [ $? -ne 0 ]; then

        print_error "No fue posible unir el servidor al dominio."
        exit 1
    fi


    echo
    echo "[OK] Servidor unido correctamente al dominio $DOMAIN."

else

    print_header "Union al dominio"

    echo "El servidor ya pertenece a $DOMAIN."
    echo "Se omite realm join."
fi


# ============================================================
# VERIFICAR SSSD.CONF
# ============================================================

print_header "Verificando configuracion de SSSD"


if [ ! -f "$SSSD_CONF" ]; then

    print_error "No se encontro $SSSD_CONF."
    exit 1
fi


if ! grep -Fqx "[domain/$DOMAIN]" "$SSSD_CONF"; then

    print_error "No existe la seccion [domain/$DOMAIN] en $SSSD_CONF."

    echo
    echo "No se modificara SSSD."
    echo
    echo "Secciones detectadas:"
    echo

    grep -E '^\[.*\]$' "$SSSD_CONF" || true

    exit 1
fi


echo "[OK] Se encontro la seccion [domain/$DOMAIN]."


# ============================================================
# BACKUP DE SSSD
# ============================================================

SSSD_BACKUP="${SSSD_CONF}.bak.$TIMESTAMP"


cp -a "$SSSD_CONF" "$SSSD_BACKUP"


if [ $? -ne 0 ]; then

    print_error "No se pudo crear el backup de $SSSD_CONF."
    exit 1
fi


echo "Backup:"
echo "  $SSSD_BACKUP"


# ============================================================
# CONFIGURAR SSSD
# ============================================================

print_header "Configurando SSSD"


SSSD_TMP="$(mktemp)"


awk \
    -v target_domain="$DOMAIN" \
'
BEGIN {
    in_target = 0
}

function print_managed_settings() {
    print "use_fully_qualified_names = False"
    print "fallback_homedir = /home/%u"
    print "cache_credentials = True"
}

$0 ~ /^\[/ {

    if (in_target) {
        print_managed_settings()
        in_target = 0
    }

    if ($0 == "[domain/" target_domain "]") {
        in_target = 1
        print
        next
    }
}

in_target &&
$0 ~ /^[[:space:]]*(use_fully_qualified_names|fallback_homedir|cache_credentials)[[:space:]]*=/ {
    next
}

{
    print
}

END {
    if (in_target) {
        print_managed_settings()
    }
}
' "$SSSD_CONF" > "$SSSD_TMP"


if [ $? -ne 0 ]; then

    rm -f "$SSSD_TMP"

    print_error "No se pudo generar la nueva configuracion de SSSD."
    exit 1
fi


cp "$SSSD_TMP" "$SSSD_CONF"

RESULT=$?


rm -f "$SSSD_TMP"


if [ $RESULT -ne 0 ]; then

    print_error "No se pudo escribir $SSSD_CONF."

    cp -a "$SSSD_BACKUP" "$SSSD_CONF"

    echo "Se restauro la configuracion anterior."

    exit 1
fi


chmod 600 "$SSSD_CONF"
chown root:root "$SSSD_CONF"


# ============================================================
# VALIDAR SSSD
# ============================================================

print_header "Validando sssd.conf"


sssctl config-check


if [ $? -ne 0 ]; then

    print_error "La nueva configuracion de SSSD no supero la validacion."

    echo
    echo "Restaurando:"
    echo "  $SSSD_BACKUP"


    cp -a "$SSSD_BACKUP" "$SSSD_CONF"


    chmod 600 "$SSSD_CONF"
    chown root:root "$SSSD_CONF"


    echo
    echo "Configuracion anterior restaurada."
    echo "SSSD NO sera reiniciado con una configuracion invalida."

    exit 1
fi


echo
echo "[OK] sssd.conf supero la validacion."


# ============================================================
# HABILITAR Y REINICIAR SSSD
# ============================================================

print_header "Iniciando SSSD"


systemctl enable sssd >/dev/null 2>&1

systemctl restart sssd


if [ $? -ne 0 ]; then

    print_error "SSSD no pudo iniciarse correctamente."

    echo
    echo "Restaurando configuracion anterior..."


    cp -a "$SSSD_BACKUP" "$SSSD_CONF"


    chmod 600 "$SSSD_CONF"
    chown root:root "$SSSD_CONF"


    systemctl restart sssd


    echo
    echo "Estado de SSSD:"
    echo

    systemctl status sssd --no-pager

    exit 1
fi


echo "[OK] SSSD iniciado correctamente."


# ============================================================
# CONFIGURAR HOME AUTOMATICO
# ============================================================

print_header "Configurando creacion automatica de directorios HOME"


systemctl enable oddjobd >/dev/null 2>&1

systemctl restart oddjobd


if [ $? -ne 0 ]; then

    print_error "oddjobd no pudo iniciarse correctamente."

    systemctl status oddjobd --no-pager

    exit 1
fi


echo "[OK] oddjobd activo."


echo
echo "Habilitando with-mkhomedir mediante authselect..."
echo


if authselect enable-feature with-mkhomedir \
    >/dev/null 2>&1; then

    echo "[OK] with-mkhomedir habilitado."

else

    print_warning "authselect no pudo habilitar with-mkhomedir."

    echo
    echo "Verifique manualmente:"
    echo
    echo "  authselect current"
fi


# ============================================================
# VALIDACION FINAL SSSD
# ============================================================

print_header "Validacion final de SSSD"


sssctl config-check


if [ $? -ne 0 ]; then

    print_error "SSSD presenta errores de configuracion."
    exit 1
fi


echo "[OK] Configuracion de SSSD valida."


# ============================================================
# VERIFICACIONES FINALES
# ============================================================

print_header "VERIFICACION FINAL"


echo
echo "------------------------------------------------------------"
echo " Informacion del dominio"
echo "------------------------------------------------------------"
echo

realm list


echo
echo "------------------------------------------------------------"
echo " Estado de SSSD"
echo "------------------------------------------------------------"
echo


if systemctl is-active --quiet sssd; then

    echo "[OK] sssd esta activo."

else

    echo "[ERROR] sssd NO esta activo."
fi


echo
echo "------------------------------------------------------------"
echo " Estado de oddjobd"
echo "------------------------------------------------------------"
echo


if systemctl is-active --quiet oddjobd; then

    echo "[OK] oddjobd esta activo."

else

    echo "[ERROR] oddjobd NO esta activo."
fi


echo
echo "------------------------------------------------------------"
echo " Configuracion SSSD para $DOMAIN"
echo "------------------------------------------------------------"
echo


awk \
    -v target="[domain/$DOMAIN]" \
'
$0 == target {
    show = 1
    print
    next
}

show && /^\[/ {
    exit
}

show {
    if ($0 ~ /^[[:space:]]*(use_fully_qualified_names|fallback_homedir|cache_credentials)[[:space:]]*=/) {
        print
    }
}
' "$SSSD_CONF"


echo
echo "------------------------------------------------------------"
echo " Resolucion de controladores"
echo "------------------------------------------------------------"
echo


getent hosts "$DC1_NAME.$DOMAIN" || \
    print_warning "No se pudo resolver $DC1_NAME.$DOMAIN"


getent hosts "$DC2_NAME.$DOMAIN" || \
    print_warning "No se pudo resolver $DC2_NAME.$DOMAIN"


# ============================================================
# RESULTADO FINAL
# ============================================================

print_header "CONFIGURACION FINALIZADA"


echo
echo "Servidor:"
echo "  Hostname: $HOSTNAME"
echo "  Interfaz: $INTERFACE"
echo "  IP:       $IPADDR/$PREFIX"

echo
echo "Dominio:"
echo "  $DOMAIN"

echo
echo "DNS:"
echo "  DNS1: $DNS1 ($DC1_NAME)"
echo "  DNS2: $DNS2 ($DC2_NAME)"

echo
echo "Configuracion realizada:"
echo "  - Configuracion de red verificada."
echo "  - Hostname configurado/verificado."
echo "  - DNS de Active Directory verificados."
echo "  - /etc/hosts actualizado."
echo "  - Servidor unido/verificado en $DOMAIN."
echo "  - SSSD configurado y validado."
echo "  - cache_credentials = True habilitado."
echo "  - Creacion automatica de HOME habilitada."

echo
echo "Este script NO configura:"
echo "  - Usuarios autorizados para iniciar sesion por SSH."
echo "  - Grupos autorizados para SSH."
echo "  - realm permit / realm deny."
echo "  - Privilegios sudo."
echo "  - /etc/sudoers.d/."
echo "  - Configuracion de sshd."

echo
echo "Pruebas recomendadas:"
echo
echo "  realm list"
echo "  sssctl config-check"
echo "  systemctl status sssd"
echo "  systemctl status oddjobd"
echo "  sssctl domain-list"

echo
echo "============================================================"