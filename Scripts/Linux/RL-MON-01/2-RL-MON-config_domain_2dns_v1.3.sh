#!/bin/bash

# ============================================================
# Recolección UY
# Configuración Rocky Linux + Active Directory
#
# Funciones:
#   - Configura red estática
#   - Configura hostname
#   - Configura resolución DNS
#   - Une Rocky Linux al dominio neltek.uy
#   - Configura SSSD
#   - Habilita caché de credenciales para autenticación offline
#   - Configura creación automática de directorios HOME
#
# Este script NO:
#   - Instala paquetes
#   - Actualiza el sistema operativo
#   - Autoriza o restringe usuarios del dominio para SSH
#   - Configura grupos de Active Directory para acceso SSH
#   - Configura permisos sudo
#   - Modifica archivos sudoers
#   - Configura SSH
#
# Aplicable a:
#   RL-APP-01
#   RL-PROXY-01
#   RL-MON-01
#
# IMPORTANTE:
#   Los paquetes necesarios deben instalarse previamente mediante
#   el script update_RL-APP-01.sh.
#
#   Si se ejecuta remotamente y modifica realmente la IP del servidor,
#   la sesión SSH actual puede perderse.
# ============================================================


# ============================================================
# VARIABLES A CONFIGURAR SEGÚN EL SERVIDOR
# ============================================================

INTERFACE="ens33"

# ------------------------------------------------------------
# RL-MON-01
# Descomentar estas líneas y comentar las anteriores
# cuando el script se utilice en RL-MON-01.
# ------------------------------------------------------------

IPADDR="192.168.20.20"
HOSTNAME="RL-MON-01"

# ------------------------------------------------------------
# RL-APP-01
# Descomentar estas líneas y comentar las anteriores
# cuando el script se utilice en RL-APP-01.
# ------------------------------------------------------------

# IPADDR="192.168.30.20"
# HOSTNAME="RL-APP-01"

# ------------------------------------------------------------
# RL-PROXY-01
# Descomentar estas líneas y comentar las anteriores
# cuando el script se utilice en RL-PROXY-01.
# ------------------------------------------------------------

# IPADDR="192.168.50.20"
# HOSTNAME="RL-PROXY-01"


PREFIX="24"
GATEWAY="192.168.20.1"

# DNS / Domain Controllers
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

print_header "Validando configuración"

if [ -z "$INTERFACE" ]; then
    print_error "INTERFACE no puede estar vacía."
    exit 1
fi

if [ -z "$IPADDR" ]; then
    print_error "IPADDR no puede estar vacía."
    exit 1
fi

if [ -z "$HOSTNAME" ]; then
    print_error "HOSTNAME no puede estar vacío."
    exit 1
fi

if [ -z "$DC1_IP" ]; then
    print_error "DC1_IP no puede estar vacía."
    exit 1
fi

if [ -z "$DC2_IP" ] || [ "$DC2_IP" = "CAMBIAR_POR_IP_WS_DC_02" ]; then
    print_error "Debe configurar DC2_IP con la IP real de WS-DC-02."
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    print_error "DOMAIN no puede estar vacío."
    exit 1
fi

echo "Configuración:"
echo "  Interfaz: $INTERFACE"
echo "  IP:       $IPADDR/$PREFIX"
echo "  Gateway:  $GATEWAY"
echo "  Hostname: $HOSTNAME"
echo "  Dominio:  $DOMAIN"
echo "  DNS1:     $DNS1 ($DC1_NAME)"
echo "  DNS2:     $DNS2 ($DC2_NAME)"


# ============================================================
# VERIFICAR PAQUETES Y COMANDOS NECESARIOS
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

for COMMAND in "${REQUIRED_COMMANDS[@]}"; do

    if command -v "$COMMAND" >/dev/null 2>&1; then
        echo "[OK] $COMMAND"
    else
        echo "[ERROR] No se encontró el comando $COMMAND."
        DEPENDENCIES_OK="false"
    fi
done

if [ "$DEPENDENCIES_OK" != "true" ]; then
    print_error "Faltan dependencias necesarias para ejecutar este script."
    echo
    echo "Ejecute previamente:"
    echo "  ./update_RL-APP-01.sh"
    exit 1
fi

echo
echo "[OK] Dependencias verificadas correctamente."


# ============================================================
# VERIFICAR INTERFAZ DE RED
# ============================================================

print_header "Verificando interfaz de red"

if ! nmcli device status | awk '{print $1}' | grep -Fxq "$INTERFACE"; then
    print_error "No se encontró la interfaz de red $INTERFACE."
    echo
    echo "Interfaces disponibles:"
    nmcli device status
    exit 1
fi

echo "[OK] Interfaz encontrada: $INTERFACE"


# ============================================================
# IDENTIFICAR PERFIL DE NETWORKMANAGER
# ============================================================

CONNECTION_NAME="$(nmcli -g GENERAL.CONNECTION device show "$INTERFACE" 2>/dev/null | head -n1)"

if [ -z "$CONNECTION_NAME" ] || [ "$CONNECTION_NAME" = "--" ]; then

    CONNECTION_NAME="$(
        nmcli -t -f NAME,DEVICE connection show \
        | awk -F: -v dev="$INTERFACE" '$2 == dev {print $1; exit}'
    )"
fi

if [ -z "$CONNECTION_NAME" ]; then
    print_error "No se pudo identificar un perfil de NetworkManager asociado a $INTERFACE."
    echo
    echo "Perfiles disponibles:"
    nmcli connection show
    exit 1
fi

echo "Perfil de NetworkManager detectado:"
echo "  $CONNECTION_NAME"


# ============================================================
# CONFIGURAR RED
# ============================================================

print_header "Configurando red"

echo "Aplicando:"
echo "  Interfaz: $INTERFACE"
echo "  Perfil:   $CONNECTION_NAME"
echo "  IP:       $IPADDR/$PREFIX"
echo "  Gateway:  $GATEWAY"
echo "  DNS1:     $DNS1"
echo "  DNS2:     $DNS2"

nmcli connection modify "$CONNECTION_NAME" \
    connection.interface-name "$INTERFACE" \
    ipv4.addresses "$IPADDR/$PREFIX" \
    ipv4.gateway "$GATEWAY" \
    ipv4.dns "$DNS1 $DNS2" \
    ipv4.ignore-auto-dns yes \
    ipv4.method manual \
    ipv6.method disabled

if [ $? -ne 0 ]; then
    print_error "No se pudo modificar la configuración de red."
    exit 1
fi


# ============================================================
# APLICAR CONFIGURACIÓN DE RED
# ============================================================

echo
echo "Aplicando cambios de red..."

if nmcli device reapply "$INTERFACE" >/dev/null 2>&1; then

    echo "[OK] Configuración reaplicada sobre $INTERFACE sin desactivar la interfaz."

else

    print_warning "NetworkManager no pudo reaplicar los cambios directamente."
    echo "Intentando reactivar el perfil $CONNECTION_NAME..."

    nmcli connection up "$CONNECTION_NAME"

    if [ $? -ne 0 ]; then
        print_error "No se pudo activar el perfil de red $CONNECTION_NAME."
        exit 1
    fi

    echo "[OK] Perfil de red activado correctamente."
fi


# ============================================================
# VERIFICAR IP
# ============================================================

sleep 2

if ip -4 addr show dev "$INTERFACE" | grep -Fq "$IPADDR/$PREFIX"; then
    echo "[OK] IP $IPADDR/$PREFIX presente en $INTERFACE."
else
    print_warning "No se pudo confirmar $IPADDR/$PREFIX en $INTERFACE."
    echo
    ip -4 addr show dev "$INTERFACE"
fi


# ============================================================
# CONFIGURAR HOSTNAME
# ============================================================

print_header "Configurando hostname"

CURRENT_HOSTNAME="$(hostnamectl --static 2>/dev/null)"

if [ "$CURRENT_HOSTNAME" = "$HOSTNAME" ]; then

    echo "[OK] El hostname ya está configurado como $HOSTNAME."

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

# Eliminar posibles entradas de versiones anteriores
# correspondientes exclusivamente a las IP administradas
# por este script.
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
    print_error "No se pudo preparar la nueva configuración de /etc/hosts."
    exit 1
fi

# Asegurar separación antes del bloque administrado.
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
    echo "Se restauró el archivo anterior."
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
nmcli device show "$INTERFACE" | grep 'IP4.DNS' || true

echo
echo "Consultando dominio $DOMAIN..."

if getent hosts "$DOMAIN" >/dev/null 2>&1; then

    echo "[OK] El dominio $DOMAIN puede resolverse."

else

    print_warning "No se pudo resolver directamente $DOMAIN."
    echo "Esto no necesariamente implica un fallo de Active Directory,"
    echo "pero debe verificarse la resolución DNS."
fi


# ============================================================
# VERIFICAR REGISTROS SRV DE ACTIVE DIRECTORY
# ============================================================

echo
echo "Verificando registros SRV LDAP contra DNS1:"
echo "  $DC1_NAME - $DNS1"
echo

if host -t SRV "_ldap._tcp.$DOMAIN" "$DNS1" >/dev/null 2>&1; then

    host -t SRV "_ldap._tcp.$DOMAIN" "$DNS1" 2>/dev/null || true
    echo "[OK] DNS1 responde consultas SRV del dominio."

else

    print_warning "DNS1 no respondió correctamente a la consulta SRV."
fi

echo
echo "Verificando registros SRV LDAP contra DNS2:"
echo "  $DC2_NAME - $DNS2"
echo

if host -t SRV "_ldap._tcp.$DOMAIN" "$DNS2" >/dev/null 2>&1; then

    host -t SRV "_ldap._tcp.$DOMAIN" "$DNS2" 2>/dev/null || true
    echo "[OK] DNS2 responde consultas SRV del dominio."

else

    print_warning "DNS2 no respondió correctamente a la consulta SRV."
fi


# ============================================================
# COMPROBAR SI EL EQUIPO YA PERTENECE AL DOMINIO
# ============================================================

print_header "Comprobando estado del dominio"

ALREADY_JOINED="false"

if realm list 2>/dev/null \
    | grep -qiE "^[[:space:]]*domain-name:[[:space:]]*$DOMAIN[[:space:]]*$"; then

    ALREADY_JOINED="true"

    echo "[OK] El servidor ya pertenece al dominio $DOMAIN."
    echo "No se ejecutará realm join nuevamente."

else

    echo "El servidor todavía no figura unido al dominio $DOMAIN."
fi


# ============================================================
# DESCUBRIR DOMINIO ACTIVE DIRECTORY
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
        echo "se intentará realizar una nueva unión."
        echo
        echo "Esto puede indicar una interrupción temporal de:"
        echo "  - DNS"
        echo "  - Active Directory"
        echo "  - conectividad hacia los controladores de dominio"
        echo
        echo "Se continuará con las validaciones locales."

    else

        print_warning "No fue posible descubrir previamente el dominio $DOMAIN."
        echo
        echo "Se continuará con realm join para que realmd realice"
        echo "su propia detección durante el intento de unión."
        echo
        echo "Si realm join falla, verifique:"
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

    print_header "Unión al dominio $DOMAIN"

    read -r -p "Usuario con permisos para unir equipos al dominio: " ADMIN_USER

    if [ -z "$ADMIN_USER" ]; then
        print_error "Debe indicar un usuario."
        exit 1
    fi

    echo
    echo "Se solicitará la contraseña directamente por realm."
    echo "La contraseña NO será almacenada por este script."
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

    print_header "Unión al dominio"

    echo "El servidor ya pertenece a $DOMAIN."
    echo "Se omite realm join."

fi


# ============================================================
# VERIFICAR SSSD.CONF
# ============================================================

print_header "Verificando configuración de SSSD"

if [ ! -f "$SSSD_CONF" ]; then
    print_error "No se encontró $SSSD_CONF."
    exit 1
fi

if ! grep -Fqx "[domain/$DOMAIN]" "$SSSD_CONF"; then
    print_error "No existe la sección [domain/$DOMAIN] en $SSSD_CONF."
    echo
    echo "No se modificará SSSD."
    echo
    echo "Contenido de las secciones detectadas:"
    grep -E '^\[.*\]$' "$SSSD_CONF" || true
    exit 1
fi

echo "[OK] Se encontró la sección [domain/$DOMAIN]."


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

# Al comenzar una nueva sección:
# si estábamos dentro del dominio administrado, insertar
# nuestra configuración antes de la siguiente sección.
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

# Dentro de nuestra sección, eliminar valores anteriores
# de las opciones que administramos para evitar duplicados.
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
    print_error "No se pudo generar la nueva configuración de SSSD."
    exit 1
fi

cp "$SSSD_TMP" "$SSSD_CONF"
RESULT=$?

rm -f "$SSSD_TMP"

if [ $RESULT -ne 0 ]; then

    print_error "No se pudo escribir $SSSD_CONF."
    cp -a "$SSSD_BACKUP" "$SSSD_CONF"
    echo "Se restauró la configuración anterior."
    exit 1
fi

chmod 600 "$SSSD_CONF"
chown root:root "$SSSD_CONF"


# ============================================================
# VALIDAR SSSD ANTES DE REINICIAR
# ============================================================

print_header "Validando sssd.conf"

sssctl config-check

if [ $? -ne 0 ]; then

    print_error "La nueva configuración de SSSD no superó la validación."
    echo
    echo "Restaurando:"
    echo "  $SSSD_BACKUP"

    cp -a "$SSSD_BACKUP" "$SSSD_CONF"

    chmod 600 "$SSSD_CONF"
    chown root:root "$SSSD_CONF"

    echo
    echo "Configuración anterior restaurada."
    echo "SSSD NO será reiniciado con la configuración inválida."

    exit 1
fi

echo
echo "[OK] sssd.conf superó la validación."


# ============================================================
# HABILITAR Y REINICIAR SSSD
# ============================================================

print_header "Iniciando SSSD"

systemctl enable sssd >/dev/null 2>&1

systemctl restart sssd

if [ $? -ne 0 ]; then

    print_error "SSSD no pudo iniciarse correctamente."

    echo
    echo "Restaurando configuración anterior..."

    cp -a "$SSSD_BACKUP" "$SSSD_CONF"

    chmod 600 "$SSSD_CONF"
    chown root:root "$SSSD_CONF"

    systemctl restart sssd

    echo
    echo "Estado de SSSD:"
    systemctl status sssd --no-pager

    exit 1
fi

echo "[OK] SSSD iniciado correctamente."


# ============================================================
# CONFIGURAR CREACIÓN AUTOMÁTICA DEL HOME
# ============================================================

print_header "Configurando creación automática de directorios HOME"

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

if authselect enable-feature with-mkhomedir >/dev/null 2>&1; then

    echo "[OK] with-mkhomedir habilitado."

else

    print_warning "authselect no pudo habilitar with-mkhomedir."
    echo "Verifique manualmente:"
    echo
    echo "  authselect current"
    echo
fi


# ============================================================
# VALIDACIÓN FINAL DE SSSD
# ============================================================

print_header "Validación final de SSSD"

sssctl config-check

if [ $? -ne 0 ]; then
    print_error "SSSD presenta errores de configuración."
    exit 1
fi

echo "[OK] Configuración de SSSD válida."


# ============================================================
# VERIFICACIONES FINALES
# ============================================================

print_header "VERIFICACIÓN FINAL"


# ------------------------------------------------------------
# Información del dominio
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo " Información del dominio"
echo "------------------------------------------------------------"
echo

realm list


# ------------------------------------------------------------
# Estado de SSSD
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo " Estado de SSSD"
echo "------------------------------------------------------------"
echo

if systemctl is-active --quiet sssd; then
    echo "[OK] sssd está activo."
else
    echo "[ERROR] sssd NO está activo."
fi


# ------------------------------------------------------------
# Estado de oddjobd
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo " Estado de oddjobd"
echo "------------------------------------------------------------"
echo

if systemctl is-active --quiet oddjobd; then
    echo "[OK] oddjobd está activo."
else
    echo "[ERROR] oddjobd NO está activo."
fi


# ------------------------------------------------------------
# Configuración relevante de SSSD
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo " Configuración SSSD para $DOMAIN"
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


# ------------------------------------------------------------
# Resolución de controladores de dominio
# ------------------------------------------------------------

echo
echo "------------------------------------------------------------"
echo " Resolución DNS de controladores"
echo "------------------------------------------------------------"
echo

getent hosts "$DC1_NAME.$DOMAIN" || \
    print_warning "No se pudo resolver $DC1_NAME.$DOMAIN"

getent hosts "$DC2_NAME.$DOMAIN" || \
    print_warning "No se pudo resolver $DC2_NAME.$DOMAIN"


# ============================================================
# RESULTADO FINAL
# ============================================================

print_header "CONFIGURACIÓN FINALIZADA"

echo
echo "Servidor:"
echo "  Hostname:  $HOSTNAME"
echo "  Interfaz:  $INTERFACE"
echo "  IP:        $IPADDR/$PREFIX"
echo "  Gateway:   $GATEWAY"

echo
echo "Dominio:"
echo "  $DOMAIN"

echo
echo "DNS:"
echo "  DNS1: $DNS1 ($DC1_NAME)"
echo "  DNS2: $DNS2 ($DC2_NAME)"

echo
echo "Configuración realizada:"
echo "  - Red estática configurada."
echo "  - Hostname configurado."
echo "  - DNS de Active Directory configurados."
echo "  - /etc/hosts actualizado de forma no destructiva."
echo "  - Servidor unido/verificado en el dominio $DOMAIN."
echo "  - SSSD configurado y validado."
echo "  - cache_credentials = True habilitado."
echo "  - Creación automática de directorios HOME habilitada."

echo
echo "Este script NO configura:"
echo "  - Usuarios autorizados para iniciar sesión por SSH."
echo "  - Grupos autorizados para SSH."
echo "  - realm permit / realm deny."
echo "  - Privilegios sudo."
echo "  - Archivos /etc/sudoers.d/."
echo "  - Configuración de sshd."

echo
echo "Pruebas recomendadas:"
echo
echo "  realm list"
echo "  sssctl config-check"
echo "  systemctl status sssd"
echo "  systemctl status oddjobd"
echo "  sssctl domain-list"

echo
echo "Para probar posteriormente un usuario del dominio:"
echo
echo "  id usuario"
echo "  getent passwd usuario"

echo
echo "============================================================"