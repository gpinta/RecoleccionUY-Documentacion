#!/bin/bash

# ============================================================
# Recoleccion UY
# Configuracion de red y firewall - RL-FW-01
#
# Funciones:
#   - Configura hostname
#   - Configura /etc/hosts
#   - Configura WAN
#   - Configura red SERVICIOS
#   - Configura red MONITOREO
#   - Configura red APLICACIONES
#   - Configura red DMZ
#   - Configura DNS de Active Directory
#   - Habilita IPv4 forwarding
#   - Configura firewalld
#   - Configura NAT hacia WAN
#   - Configura politicas inter-red
#   - Permite RL-PROXY -> RL-APP por TCP/8080, TCP/8081 y TCP/8082 (Camiones)
#   - Publica HTTP/HTTPS hacia RL-PROXY
#
# Topologia:
#
#   ens33 -> WAN
#            Bridged / DHCP
#
#   ens36 -> SERVICIOS
#            192.168.10.1/24
#
#   ens37 -> MONITOREO
#            192.168.20.1/24
#
#   ens38 -> APLICACIONES
#            192.168.30.1/24
#
#   ens39 -> DMZ
#            192.168.50.1/24
#
# Servidores:
#
#   WS-DC-01      192.168.10.20
#   WS-DC-02      192.168.10.21
#   RL-MON-01     192.168.20.20
#   RL-APP-01     192.168.30.20
#   RL-PROXY-01   192.168.50.20
#
# Este script NO:
#   - Une RL-FW-01 al dominio
#   - Configura SSSD
#   - Configura permisos de usuarios AD
#   - Habilita acceso SSH desde ninguna red
#
# Ejecutar despues:
#
#   ./RL-FW_config_domain.sh
#
# ============================================================


# ============================================================
# VARIABLES
# ============================================================

HOSTNAME="RL-FW-01"

DOMAIN="neltek.uy"


WAN_IF="ens33"

SERVICIOS_IF="ens36"
MONITOREO_IF="ens37"
APLICACIONES_IF="ens38"
DMZ_IF="ens39"


SERVICIOS_IP="192.168.10.1"
MONITOREO_IP="192.168.20.1"
APLICACIONES_IP="192.168.30.1"
DMZ_IP="192.168.50.1"

PREFIX="24"


DC1_IP="192.168.10.20"
DC1_NAME="WS-DC-01"

DC2_IP="192.168.10.21"
DC2_NAME="WS-DC-02"


MON_IP="192.168.20.20"
APP_IP="192.168.30.20"
PROXY_IP="192.168.50.20"


DNS1="$DC1_IP"
DNS2="$DC2_IP"


CON_SERVICIOS="REC-SERVICIOS"
CON_MONITOREO="REC-MONITOREO"
CON_APLICACIONES="REC-APLICACIONES"
CON_DMZ="REC-DMZ"


ZONE_WAN="rec-wan"
ZONE_SERVICIOS="rec-servicios"
ZONE_MONITOREO="rec-monitoreo"
ZONE_APLICACIONES="rec-apps"
ZONE_DMZ="rec-dmz"


POLICY_LAN_WAN="rec-lan-to-wan"

POLICY_APP_SERV="rec-app-to-serv"
POLICY_DMZ_SERV="rec-dmz-to-serv"

POLICY_DMZ_APP="rec-dmz-to-app"

POLICY_MON_APP="rec-mon-to-app"
POLICY_MON_DMZ="rec-mon-to-dmz"

POLICY_APP_MON="rec-app-to-mon"
POLICY_DMZ_MON="rec-dmz-to-mon"

POLICY_WAN_DMZ="rec-wan-to-dmz"


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


require_interface() {

    local INTERFACE="$1"

    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then

        print_error "No se encontro la interfaz $INTERFACE."
        exit 1
    fi
}


ensure_zone() {

    local ZONE="$1"

    if firewall-cmd --permanent --get-zones \
        | tr ' ' '\n' \
        | grep -Fxq "$ZONE"; then

        echo "[OK] Zona existente: $ZONE"

    else

        firewall-cmd \
            --permanent \
            --new-zone="$ZONE"

        if [ $? -ne 0 ]; then

            print_error "No se pudo crear la zona $ZONE."
            exit 1
        fi

        echo "[OK] Zona creada: $ZONE"
    fi
}


delete_policy_if_exists() {

    local POLICY="$1"

    if firewall-cmd --permanent --get-policies \
        | tr ' ' '\n' \
        | grep -Fxq "$POLICY"; then

        firewall-cmd \
            --permanent \
            --delete-policy="$POLICY" \
            >/dev/null

        echo "[OK] Politica anterior eliminada: $POLICY"
    fi
}


create_policy() {

    local POLICY="$1"
    local INGRESS="$2"
    local EGRESS="$3"

    firewall-cmd \
        --permanent \
        --new-policy="$POLICY"

    if [ $? -ne 0 ]; then

        print_error "No se pudo crear la politica $POLICY."
        exit 1
    fi


    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --add-ingress-zone="$INGRESS"


    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --add-egress-zone="$EGRESS"
}


add_rich_rule() {

    local POLICY="$1"
    local RULE="$2"

    firewall-cmd \
        --permanent \
        --policy="$POLICY" \
        --add-rich-rule="$RULE"

    if [ $? -ne 0 ]; then

        print_error "No se pudo agregar una regla a $POLICY."
        exit 1
    fi
}


# ============================================================
# CONFIGURAR INTERFAZ LAN
# ============================================================

configure_lan() {

    local INTERFACE="$1"
    local CONNECTION="$2"
    local ADDRESS="$3"
    local ZONE="$4"


    echo
    echo "Configurando:"
    echo "  Interfaz : $INTERFACE"
    echo "  Perfil   : $CONNECTION"
    echo "  IP       : $ADDRESS/$PREFIX"
    echo "  Zona     : $ZONE"


    # --------------------------------------------------------
    # Deshabilitar perfiles anteriores asociados a la NIC.
    # No se eliminan para permitir recuperacion.
    # --------------------------------------------------------

    while IFS=: read -r PROFILE DEVICE
    do

        if [ "$DEVICE" = "$INTERFACE" ] &&
           [ "$PROFILE" != "$CONNECTION" ]; then

            nmcli connection modify \
                "$PROFILE" \
                connection.autoconnect no \
                >/dev/null 2>&1 || true

            echo "[OK] Autoconexion deshabilitada: $PROFILE"
        fi

    done < <(
        nmcli -t -f NAME,DEVICE connection show
    )


    # --------------------------------------------------------
    # Crear perfil si no existe
    # --------------------------------------------------------

    if nmcli -t -f NAME connection show \
        | grep -Fxq "$CONNECTION"; then

        echo "[OK] Perfil existente: $CONNECTION"

    else

        nmcli connection add \
            type ethernet \
            ifname "$INTERFACE" \
            con-name "$CONNECTION"

        if [ $? -ne 0 ]; then

            print_error "No se pudo crear $CONNECTION."
            exit 1
        fi

        echo "[OK] Perfil creado: $CONNECTION"
    fi


    # --------------------------------------------------------
    # Configuracion definitiva LAN
    # --------------------------------------------------------

    nmcli connection modify "$CONNECTION" \
        connection.interface-name "$INTERFACE" \
        connection.autoconnect yes \
        connection.autoconnect-priority 100 \
        connection.zone "$ZONE" \
        ipv4.method manual \
        ipv4.addresses "$ADDRESS/$PREFIX" \
        ipv4.gateway "" \
        ipv4.never-default yes \
        ipv4.ignore-auto-dns yes \
        ipv6.method disabled

    if [ $? -ne 0 ]; then

        print_error "No se pudo configurar $CONNECTION."
        exit 1
    fi


    nmcli connection up "$CONNECTION"

    if [ $? -ne 0 ]; then

        print_error "No se pudo activar $CONNECTION."
        exit 1
    fi


    echo "[OK] $INTERFACE -> $ADDRESS/$PREFIX"
}


# ============================================================
# REGLAS DE ACCESO A ACTIVE DIRECTORY
# ============================================================

add_ad_access_rules() {

    local POLICY="$1"
    local SOURCE_IP="$2"


    for DC_IP in "$DC1_IP" "$DC2_IP"
    do

        # DNS TCP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"53\" protocol=\"tcp\" accept"

        # DNS UDP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"53\" protocol=\"udp\" accept"


        # Kerberos TCP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"88\" protocol=\"tcp\" accept"

        # Kerberos UDP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"88\" protocol=\"udp\" accept"


        # LDAP TCP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"389\" protocol=\"tcp\" accept"

        # LDAP UDP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"389\" protocol=\"udp\" accept"


        # LDAPS
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"636\" protocol=\"tcp\" accept"


        # Kerberos Password TCP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"464\" protocol=\"tcp\" accept"

        # Kerberos Password UDP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"464\" protocol=\"udp\" accept"


        # NTP
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"123\" protocol=\"udp\" accept"


        # Global Catalog
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"3268\" protocol=\"tcp\" accept"

        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"3269\" protocol=\"tcp\" accept"


        # SMB
        add_rich_rule "$POLICY" \
            "rule family=\"ipv4\" source address=\"$SOURCE_IP\" destination address=\"$DC_IP\" port port=\"445\" protocol=\"tcp\" accept"

    done
}


# ============================================================
# COMPROBAR ROOT
# ============================================================

if [ "$EUID" -ne 0 ]; then

    print_error "Este script debe ejecutarse como root."
    exit 1
fi


# ============================================================
# VERIFICAR INTERFACES
# ============================================================

print_header "Verificando interfaces"

require_interface "$WAN_IF"
require_interface "$SERVICIOS_IF"
require_interface "$MONITOREO_IF"
require_interface "$APLICACIONES_IF"
require_interface "$DMZ_IF"

echo "[OK] $WAN_IF - WAN"
echo "[OK] $SERVICIOS_IF - SERVICIOS"
echo "[OK] $MONITOREO_IF - MONITOREO"
echo "[OK] $APLICACIONES_IF - APLICACIONES"
echo "[OK] $DMZ_IF - DMZ"


# ============================================================
# VERIFICAR SERVICIOS
# ============================================================

print_header "Verificando servicios"

systemctl enable --now NetworkManager
systemctl enable --now firewalld
systemctl enable --now sshd

echo "[OK] NetworkManager"
echo "[OK] firewalld"
echo "[OK] sshd activo (sin acceso habilitado en firewalld)"


# ============================================================
# BACKUP
# ============================================================

print_header "Creando respaldo"

BACKUP_DIR="/root/recoleccion-fw-backup-$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

cp -a /etc/hosts \
    "$BACKUP_DIR/hosts"


if [ -d /etc/firewalld ]; then

    cp -a /etc/firewalld \
        "$BACKUP_DIR/firewalld"
fi


nmcli connection show \
    > "$BACKUP_DIR/nmcli-connections.txt"


ip address \
    > "$BACKUP_DIR/ip-address.txt"


ip route \
    > "$BACKUP_DIR/ip-route.txt"


echo "[OK] Backup:"
echo "  $BACKUP_DIR"


# ============================================================
# CONFIGURAR HOSTNAME
# ============================================================

print_header "Configurando hostname"

CURRENT_HOSTNAME="$(hostnamectl --static 2>/dev/null)"


if [ "$CURRENT_HOSTNAME" = "$HOSTNAME" ]; then

    echo "[OK] Hostname ya configurado como $HOSTNAME."

else

    hostnamectl set-hostname "$HOSTNAME"

    if [ $? -ne 0 ]; then

        print_error "No se pudo configurar el hostname."
        exit 1
    fi

    echo "[OK] Hostname configurado: $HOSTNAME"
fi


# ============================================================
# CONFIGURAR /etc/hosts
# ============================================================

print_header "Configurando /etc/hosts"

HOSTS_BACKUP="/etc/hosts.bak.$TIMESTAMP"

cp -a /etc/hosts "$HOSTS_BACKUP"

HOSTS_TMP="$(mktemp)"


awk \
    -v begin="$HOSTS_BEGIN" \
    -v end="$HOSTS_END" \
    -v server_ip="$SERVICIOS_IP" \
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

    print_error "No se pudo preparar /etc/hosts."
    exit 1
fi


echo >> "$HOSTS_TMP"


cat >> "$HOSTS_TMP" <<EOF
$HOSTS_BEGIN
$SERVICIOS_IP     $HOSTNAME.$DOMAIN $HOSTNAME
$DC1_IP           $DC1_NAME.$DOMAIN $DC1_NAME
$DC2_IP           $DC2_NAME.$DOMAIN $DC2_NAME
$HOSTS_END
EOF


cp "$HOSTS_TMP" /etc/hosts

RESULT=$?

rm -f "$HOSTS_TMP"


if [ $RESULT -ne 0 ]; then

    print_error "No se pudo actualizar /etc/hosts."

    cp -a "$HOSTS_BACKUP" /etc/hosts

    exit 1
fi


chmod 644 /etc/hosts
chown root:root /etc/hosts


echo "[OK] /etc/hosts actualizado."


# ============================================================
# CREAR ZONAS FIREWALLD
# ============================================================

print_header "Configurando zonas firewalld"

ensure_zone "$ZONE_WAN"
ensure_zone "$ZONE_SERVICIOS"
ensure_zone "$ZONE_MONITOREO"
ensure_zone "$ZONE_APLICACIONES"
ensure_zone "$ZONE_DMZ"


firewall-cmd --reload


# ============================================================
# CONFIGURAR WAN
# ============================================================

print_header "Configurando WAN"


WAN_CONNECTION="$(
    nmcli -g GENERAL.CONNECTION \
        device show "$WAN_IF" 2>/dev/null
)"


if [ -z "$WAN_CONNECTION" ] ||
   [ "$WAN_CONNECTION" = "--" ]; then

    print_error "$WAN_IF no tiene un perfil NetworkManager activo."
    exit 1
fi


echo "Perfil WAN:"
echo "  $WAN_CONNECTION"


nmcli connection modify "$WAN_CONNECTION" \
    connection.interface-name "$WAN_IF" \
    connection.autoconnect yes \
    connection.zone "$ZONE_WAN" \
    ipv4.method auto \
    ipv4.never-default no \
    ipv4.ignore-auto-dns yes \
    ipv6.method disabled


if [ $? -ne 0 ]; then

    print_error "No se pudo configurar WAN."
    exit 1
fi


nmcli connection up "$WAN_CONNECTION"


if [ $? -ne 0 ]; then

    print_error "No se pudo activar WAN."
    exit 1
fi


echo "[OK] WAN activa."


# ============================================================
# CONFIGURAR REDES INTERNAS
# ============================================================

print_header "Configurando redes internas"


configure_lan \
    "$SERVICIOS_IF" \
    "$CON_SERVICIOS" \
    "$SERVICIOS_IP" \
    "$ZONE_SERVICIOS"


configure_lan \
    "$MONITOREO_IF" \
    "$CON_MONITOREO" \
    "$MONITOREO_IP" \
    "$ZONE_MONITOREO"


configure_lan \
    "$APLICACIONES_IF" \
    "$CON_APLICACIONES" \
    "$APLICACIONES_IP" \
    "$ZONE_APLICACIONES"


configure_lan \
    "$DMZ_IF" \
    "$CON_DMZ" \
    "$DMZ_IP" \
    "$ZONE_DMZ"


# ============================================================
# CONFIGURAR DNS ACTIVE DIRECTORY
# ============================================================

print_header "Configurando DNS Active Directory"


nmcli connection modify "$CON_SERVICIOS" \
    ipv4.dns "$DNS1 $DNS2" \
    ipv4.ignore-auto-dns yes \
    ipv4.never-default yes


if [ $? -ne 0 ]; then

    print_error "No se pudo configurar DNS."
    exit 1
fi


if nmcli device reapply "$SERVICIOS_IF" >/dev/null 2>&1; then

    echo "[OK] DNS reaplicado sobre $SERVICIOS_IF."

else

    nmcli connection up "$CON_SERVICIOS"

    if [ $? -ne 0 ]; then

        print_error "No se pudo activar DNS en SERVICIOS."
        exit 1
    fi
fi


echo "[OK] DNS1: $DNS1"
echo "[OK] DNS2: $DNS2"


# ============================================================
# CONFIGURAR IPv4 FORWARDING
# ============================================================

print_header "Configurando IPv4 forwarding"


SYSCTL_FILE="/etc/sysctl.d/99-recoleccion-fw.conf"


cat > "$SYSCTL_FILE" <<'EOF'
# Recoleccion UY - RL-FW-01

net.ipv4.ip_forward = 1

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF


sysctl --system >/dev/null


if [ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]; then

    print_error "IPv4 forwarding no quedo habilitado."
    exit 1
fi


echo "[OK] IPv4 forwarding habilitado."


# ============================================================
# NAT
# ============================================================

print_header "Configurando NAT"


firewall-cmd \
    --permanent \
    --zone="$ZONE_WAN" \
    --add-masquerade


if [ $? -ne 0 ]; then

    print_error "No se pudo habilitar masquerade."
    exit 1
fi


echo "[OK] NAT habilitado en WAN."


# ============================================================
# NOTA SOBRE SSH
# ============================================================

print_header "Acceso SSH"


echo "[INFO] sshd permanece activo."
echo "[INFO] Este script NO habilita SSH en ninguna zona firewalld."
echo "[INFO] El acceso administrativo se habilitara posteriormente"
echo "       desde la red o IP que se defina."


# ============================================================
# RECREAR POLITICAS
# ============================================================

print_header "Recreando politicas firewalld"


for POLICY in \
    "$POLICY_LAN_WAN" \
    "$POLICY_APP_SERV" \
    "$POLICY_DMZ_SERV" \
    "$POLICY_DMZ_APP" \
    "$POLICY_MON_APP" \
    "$POLICY_MON_DMZ" \
    "$POLICY_APP_MON" \
    "$POLICY_DMZ_MON" \
    "$POLICY_WAN_DMZ"
do

    delete_policy_if_exists "$POLICY"

done


# ============================================================
# REDES INTERNAS -> WAN
# ============================================================

print_header "Configurando redes internas -> WAN"


firewall-cmd \
    --permanent \
    --new-policy="$POLICY_LAN_WAN"


firewall-cmd \
    --permanent \
    --policy="$POLICY_LAN_WAN" \
    --add-ingress-zone="$ZONE_SERVICIOS"


firewall-cmd \
    --permanent \
    --policy="$POLICY_LAN_WAN" \
    --add-ingress-zone="$ZONE_MONITOREO"


firewall-cmd \
    --permanent \
    --policy="$POLICY_LAN_WAN" \
    --add-ingress-zone="$ZONE_APLICACIONES"


firewall-cmd \
    --permanent \
    --policy="$POLICY_LAN_WAN" \
    --add-ingress-zone="$ZONE_DMZ"


firewall-cmd \
    --permanent \
    --policy="$POLICY_LAN_WAN" \
    --add-egress-zone="$ZONE_WAN"


firewall-cmd \
    --permanent \
    --policy="$POLICY_LAN_WAN" \
    --set-target=ACCEPT


echo "[OK] Redes internas -> WAN."


# ============================================================
# APLICACIONES -> SERVICIOS
# ============================================================

print_header "Configurando APLICACIONES -> SERVICIOS"


create_policy \
    "$POLICY_APP_SERV" \
    "$ZONE_APLICACIONES" \
    "$ZONE_SERVICIOS"


add_ad_access_rules \
    "$POLICY_APP_SERV" \
    "$APP_IP"


echo "[OK] RL-APP -> Active Directory."


# ============================================================
# DMZ -> SERVICIOS
# ============================================================

print_header "Configurando DMZ -> SERVICIOS"


create_policy \
    "$POLICY_DMZ_SERV" \
    "$ZONE_DMZ" \
    "$ZONE_SERVICIOS"


add_ad_access_rules \
    "$POLICY_DMZ_SERV" \
    "$PROXY_IP"


echo "[OK] RL-PROXY -> Active Directory."


# ============================================================
# DMZ -> APLICACIONES
# ============================================================

print_header "Configurando DMZ -> APLICACIONES"


create_policy \
    "$POLICY_DMZ_APP" \
    "$ZONE_DMZ" \
    "$ZONE_APLICACIONES"


add_rich_rule "$POLICY_DMZ_APP" \
    "rule family=\"ipv4\" source address=\"$PROXY_IP\" destination address=\"$APP_IP\" port port=\"8080\" protocol=\"tcp\" accept"


add_rich_rule "$POLICY_DMZ_APP" \
    "rule family=\"ipv4\" source address=\"$PROXY_IP\" destination address=\"$APP_IP\" port port=\"8081\" protocol=\"tcp\" accept"


# ------------------------------------------------------------
# Recoleccion Camiones - TCP/8082
# Origen: RL-PROXY-01 ($PROXY_IP)
# Destino: RL-APP-01 ($APP_IP)
# Politica: rec-dmz-to-app
# ------------------------------------------------------------

add_rich_rule "$POLICY_DMZ_APP" \
    "rule family=\"ipv4\" source address=\"$PROXY_IP\" destination address=\"$APP_IP\" port port=\"8082\" protocol=\"tcp\" accept"


echo "[OK] RL-PROXY -> RL-APP:8080/8081/8082."


# ============================================================
# MONITOREO -> APLICACIONES
# ============================================================

print_header "Configurando MONITOREO -> APLICACIONES"


create_policy \
    "$POLICY_MON_APP" \
    "$ZONE_MONITOREO" \
    "$ZONE_APLICACIONES"


add_rich_rule "$POLICY_MON_APP" \
    "rule family=\"ipv4\" source address=\"$MON_IP\" destination address=\"$APP_IP\" port port=\"9100\" protocol=\"tcp\" accept"


echo "[OK] RL-MON -> RL-APP:9100."


# ============================================================
# MONITOREO -> DMZ
# ============================================================

print_header "Configurando MONITOREO -> DMZ"


create_policy \
    "$POLICY_MON_DMZ" \
    "$ZONE_MONITOREO" \
    "$ZONE_DMZ"


add_rich_rule "$POLICY_MON_DMZ" \
    "rule family=\"ipv4\" source address=\"$MON_IP\" destination address=\"$PROXY_IP\" port port=\"9100\" protocol=\"tcp\" accept"


echo "[OK] RL-MON -> RL-PROXY:9100."


# ============================================================
# APLICACIONES -> MONITOREO
# ============================================================

print_header "Configurando APLICACIONES -> MONITOREO"


create_policy \
    "$POLICY_APP_MON" \
    "$ZONE_APLICACIONES" \
    "$ZONE_MONITOREO"


add_rich_rule "$POLICY_APP_MON" \
    "rule family=\"ipv4\" source address=\"$APP_IP\" destination address=\"$MON_IP\" port port=\"9200\" protocol=\"tcp\" accept"


echo "[OK] RL-APP -> RL-MON:9200."


# ============================================================
# DMZ -> MONITOREO
# ============================================================

print_header "Configurando DMZ -> MONITOREO"


create_policy \
    "$POLICY_DMZ_MON" \
    "$ZONE_DMZ" \
    "$ZONE_MONITOREO"


add_rich_rule "$POLICY_DMZ_MON" \
    "rule family=\"ipv4\" source address=\"$PROXY_IP\" destination address=\"$MON_IP\" port port=\"9200\" protocol=\"tcp\" accept"


echo "[OK] RL-PROXY -> RL-MON:9200."


# ============================================================
# WAN -> DMZ
# ============================================================

print_header "Configurando WAN -> DMZ"


firewall-cmd \
    --permanent \
    --zone="$ZONE_WAN" \
    --remove-forward-port="port=80:proto=tcp:toport=80:toaddr=$PROXY_IP" \
    >/dev/null 2>&1 || true


firewall-cmd \
    --permanent \
    --zone="$ZONE_WAN" \
    --remove-forward-port="port=443:proto=tcp:toport=443:toaddr=$PROXY_IP" \
    >/dev/null 2>&1 || true


firewall-cmd \
    --permanent \
    --zone="$ZONE_WAN" \
    --add-forward-port="port=80:proto=tcp:toport=80:toaddr=$PROXY_IP"


firewall-cmd \
    --permanent \
    --zone="$ZONE_WAN" \
    --add-forward-port="port=443:proto=tcp:toport=443:toaddr=$PROXY_IP"


create_policy \
    "$POLICY_WAN_DMZ" \
    "$ZONE_WAN" \
    "$ZONE_DMZ"


add_rich_rule "$POLICY_WAN_DMZ" \
    "rule family=\"ipv4\" destination address=\"$PROXY_IP\" port port=\"80\" protocol=\"tcp\" accept"


add_rich_rule "$POLICY_WAN_DMZ" \
    "rule family=\"ipv4\" destination address=\"$PROXY_IP\" port port=\"443\" protocol=\"tcp\" accept"


echo "[OK] WAN:80/443 -> RL-PROXY."


# ============================================================
# APLICAR FIREWALL
# ============================================================

print_header "Aplicando firewalld"


firewall-cmd --reload


if [ $? -ne 0 ]; then

    print_error "No se pudo recargar firewalld."
    exit 1
fi


echo "[OK] Firewalld aplicado."


# ============================================================
# VERIFICACION DE INTERFACES
# ============================================================

print_header "Verificando interfaces"


ip -brief address


# ============================================================
# VERIFICACION DE RUTAS
# ============================================================

print_header "Verificando rutas"


ip -4 route


DEFAULT_ROUTES="$(
    ip -4 route show default \
        | wc -l
)"


if [ "$DEFAULT_ROUTES" -eq 1 ]; then

    echo "[OK] Existe una unica ruta por defecto."

else

    print_warning "Se esperaba una unica ruta por defecto."
    echo "Detectadas: $DEFAULT_ROUTES"
fi


DEFAULT_IF="$(
    ip -4 route show default \
        | awk 'NR == 1 {print $5}'
)"


if [ "$DEFAULT_IF" = "$WAN_IF" ]; then

    echo "[OK] Default route -> $WAN_IF"

else

    print_warning "Default route detectada en: ${DEFAULT_IF:-NINGUNA}"
fi


# ============================================================
# VERIFICACION DE DNS
# ============================================================

print_header "Verificando DNS"


echo "DNS de $SERVICIOS_IF:"
echo

nmcli device show "$SERVICIOS_IF" \
    | grep 'IP4.DNS' \
    || true


echo
echo "/etc/resolv.conf:"
echo

cat /etc/resolv.conf


# ============================================================
# VERIFICACION DE HOSTNAME
# ============================================================

print_header "Verificando hostname"


echo "Hostname:"
echo "  $(hostnamectl --static)"

echo
echo "FQDN esperado:"
echo "  $HOSTNAME.$DOMAIN"


# ============================================================
# VERIFICACION FIREWALL
# ============================================================

print_header "Verificando firewalld"


echo "Zonas:"
echo

firewall-cmd --get-active-zones


echo
echo "Politicas:"
echo

firewall-cmd --get-active-policies


echo
echo "Masquerade WAN:"
echo

firewall-cmd \
    --zone="$ZONE_WAN" \
    --query-masquerade


# ============================================================
# VERIFICACION RECOLECCION CAMIONES - TCP/8082
# ============================================================

print_header "Verificando regla Recoleccion Camiones TCP/8082"


# ------------------------------------------------------------
# Comprobar regla permanente
# ------------------------------------------------------------

CAMIONES_RULE="rule family=\"ipv4\" source address=\"$PROXY_IP\" destination address=\"$APP_IP\" port port=\"8082\" protocol=\"tcp\" accept"

if firewall-cmd \
    --permanent \
    --policy="$POLICY_DMZ_APP" \
    --query-rich-rule="$CAMIONES_RULE" \
    >/dev/null 2>&1; then

    echo "[OK] Regla permanente TCP/8082 confirmada."

else

    print_error "No se encontro la regla permanente TCP/8082."
    exit 1
fi


# ------------------------------------------------------------
# Comprobar regla activa despues de firewall-cmd --reload
# ------------------------------------------------------------

if firewall-cmd \
    --policy="$POLICY_DMZ_APP" \
    --query-rich-rule="$CAMIONES_RULE" \
    >/dev/null 2>&1; then

    echo "[OK] Regla activa TCP/8082 confirmada."

else

    print_error "No se encontro la regla activa TCP/8082."
    exit 1
fi


# ============================================================
# VERIFICACION FORWARDING
# ============================================================

print_header "Verificando IPv4 forwarding"


echo "net.ipv4.ip_forward = $(sysctl -n net.ipv4.ip_forward)"


# ============================================================
# RESULTADO FINAL
# ============================================================

print_header "CONFIGURACION RL-FW-01 FINALIZADA"


echo
echo "Servidor:"
echo "  Hostname: $HOSTNAME"

echo
echo "WAN:"
echo "  $WAN_IF"

echo
echo "SERVICIOS:"
echo "  $SERVICIOS_IF"
echo "  $SERVICIOS_IP/$PREFIX"

echo
echo "MONITOREO:"
echo "  $MONITOREO_IF"
echo "  $MONITOREO_IP/$PREFIX"

echo
echo "APLICACIONES:"
echo "  $APLICACIONES_IF"
echo "  $APLICACIONES_IP/$PREFIX"

echo
echo "DMZ:"
echo "  $DMZ_IF"
echo "  $DMZ_IP/$PREFIX"

echo
echo "DNS:"
echo "  $DNS1 ($DC1_NAME)"
echo "  $DNS2 ($DC2_NAME)"

echo
echo "SSH:"
echo "  sshd activo"
echo "  Sin acceso habilitado en firewalld"

echo
echo "Recoleccion Camiones:"
echo "  RL-PROXY-01 ($PROXY_IP) -> RL-APP-01 ($APP_IP)"
echo "  TCP/8082 - Permanente y activa"

echo
echo "Siguiente paso:"
echo
echo "  ./RL-FW_config_domain.sh"

echo
echo "============================================================"