#!/bin/bash

# ==========================================================
# Recoleccion UY - Preparacion del sistema RL-FW
#
# Funciones:
# - Verifica que el sistema sea Rocky Linux
# - Actualiza Rocky Linux
# - Instala herramientas basicas
# - Instala herramientas de red y diagnostico
# - Instala NetworkManager
# - Instala OpenSSH
# - Instala Firewalld
# - Instala componentes SELinux
# - Instala componentes necesarios para Active Directory
# - Habilita IPv4 forwarding
# - Aplica parametros basicos seguros para routing IPv4
# - Habilita servicios base
# - Verifica servicios, paquetes, interfaces y routing
#
# IMPORTANTE:
#
# Este script NO configura:
#
# - Direcciones IP
# - Interfaces LAN/WAN
# - Gateways
# - NAT
# - Zonas de Firewalld
# - Reglas inter-red
# - Politicas inter-VLAN
# - Union al dominio
# - SSSD
#
# Despues de este script deben ejecutarse:
#
#   1. config_rl_fw.sh
#   2. config_domain_rl_fw.sh
#
# Compatible con:
# - Rocky Linux 9
#
# Ejecutar como:
#
#   sudo ./so_update_fw.sh
#
# ==========================================================


set -Eeuo pipefail


# ==========================================================
# 1. CONFIGURACION GENERAL
# ==========================================================

SYSCTL_FILE="/etc/sysctl.d/99-recoleccion-fw.conf"


BASIC_PACKAGES=(
    nano
    vim-minimal
    sudo
    bash-completion
    dnf-plugins-core
    wget
    curl
    tar
    unzip
)


NETWORK_PACKAGES=(
    NetworkManager
    iproute
    iputils
    bind-utils
    traceroute
    tcpdump
    nmap-ncat
    ethtool
    net-tools
)


SECURITY_PACKAGES=(
    openssh-server
    openssh-clients
    firewalld
    policycoreutils
    policycoreutils-python-utils
)


AD_PACKAGES=(
    realmd
    sssd
    sssd-tools
    oddjob
    oddjob-mkhomedir
    adcli
    krb5-workstation
    samba-common-tools
    openldap-clients
)


REQUIRED_SERVICES=(
    NetworkManager
    sshd
    firewalld
    oddjobd
)


AD_COMMANDS=(
    realm
    adcli
    kinit
    ldapsearch
)


# ==========================================================
# 2. FUNCIONES GENERALES
# ==========================================================

log()
{
    echo ""
    echo "=========================================================="
    echo "$1"
    echo "=========================================================="
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


# ==========================================================
# 3. MANEJO GENERAL DE ERRORES
# ==========================================================

error_handler()
{
    local exit_code=$?
    local line_number=$1

    echo ""
    echo "=========================================================="
    echo "ERROR DURANTE LA EJECUCION"
    echo "=========================================================="
    echo ""
    echo "Linea   : ${line_number}"
    echo "Comando : ${BASH_COMMAND}"
    echo "Codigo  : ${exit_code}"
    echo ""
    echo "La preparacion de RL-FW no pudo completarse."
    echo ""
    echo "Revise los mensajes anteriores."
    echo "=========================================================="

    exit "${exit_code}"
}


trap 'error_handler $LINENO' ERR


# ==========================================================
# 4. VERIFICAR PRIVILEGIOS
# ==========================================================

log "Recoleccion UY - Preparacion RL-FW"


if [[ "${EUID}" -ne 0 ]]; then

    show_error "Debe ejecutar este script como root."

    echo ""
    echo "Ejemplo:"
    echo ""
    echo "  sudo ./so_update_fw.sh"
    echo ""

    exit 1
fi


show_ok "Privilegios administrativos verificados."


# ==========================================================
# 5. VERIFICAR SISTEMA OPERATIVO
# ==========================================================

log "Verificando sistema operativo"


if [[ ! -f /etc/os-release ]]; then

    show_error "No fue posible identificar el sistema operativo."

    exit 1
fi


source /etc/os-release


if [[ "${ID:-}" != "rocky" ]]; then

    show_error "Este script esta preparado para Rocky Linux."

    echo ""
    echo "Sistema detectado:"
    echo ""
    echo "  ID         : ${ID:-desconocido}"
    echo "  VERSION_ID : ${VERSION_ID:-desconocido}"
    echo ""

    exit 1
fi


show_ok "Rocky Linux detectado."

echo ""
echo "Sistema : ${PRETTY_NAME:-Rocky Linux}"


# ==========================================================
# 6. VERIFICAR DNF
# ==========================================================

if ! command -v dnf >/dev/null 2>&1; then

    show_error "DNF no esta disponible."

    exit 1
fi


show_ok "DNF disponible."


# ==========================================================
# 7. ACTUALIZAR SISTEMA
# ==========================================================

log "1. Actualizando Rocky Linux"


dnf upgrade -y


show_ok "Sistema actualizado."


# ==========================================================
# 8. INSTALAR HERRAMIENTAS BASICAS
# ==========================================================

log "2. Instalando herramientas basicas"


dnf install -y "${BASIC_PACKAGES[@]}"


show_ok "Herramientas basicas instaladas."


# ==========================================================
# 9. INSTALAR HERRAMIENTAS DE RED
# ==========================================================

log "3. Instalando herramientas de red"


dnf install -y "${NETWORK_PACKAGES[@]}"


show_ok "Herramientas de red instaladas."


# ==========================================================
# 10. INSTALAR SSH / FIREWALL / SELINUX
# ==========================================================

log "4. Instalando componentes de seguridad"


dnf install -y "${SECURITY_PACKAGES[@]}"


show_ok "Componentes de seguridad instalados."


# ==========================================================
# 11. INSTALAR ACTIVE DIRECTORY / SSSD
# ==========================================================

log "5. Instalando componentes para Active Directory"


dnf install -y "${AD_PACKAGES[@]}"


show_ok "Componentes de Active Directory instalados."


# ==========================================================
# 12. CONFIGURAR IPv4 FORWARDING
# ==========================================================

log "6. Configurando IPv4 forwarding"


cat > "${SYSCTL_FILE}" <<'EOF'
# ==========================================================
# Recoleccion UY - RL-FW
# Parametros IPv4 del router/firewall
# ==========================================================

# Permitir forwarding IPv4.
net.ipv4.ip_forward = 1

# No aceptar ICMP redirects.
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# No enviar ICMP redirects.
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# No aceptar source routing.
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF


show_ok "Archivo sysctl creado:"
echo "     ${SYSCTL_FILE}"


# ==========================================================
# 13. APLICAR CONFIGURACION SYSCTL
# ==========================================================

show_info "Aplicando configuracion IPv4 de RL-FW."


sysctl -p "${SYSCTL_FILE}"


# ==========================================================
# 14. VERIFICAR IPv4 FORWARDING
# ==========================================================

if [[ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]]; then

    show_error "No fue posible habilitar IPv4 forwarding."

    exit 1
fi


show_ok "net.ipv4.ip_forward = 1"


# ==========================================================
# 15. HABILITAR SERVICIOS BASE
# ==========================================================

log "7. Habilitando servicios base"


systemctl enable --now NetworkManager

show_ok "NetworkManager habilitado."


systemctl enable --now sshd

show_ok "SSHD habilitado."


echo ""
show_warning "Firewalld sera iniciado."
show_warning "Este script NO crea zonas ni reglas especificas."
echo ""


systemctl enable --now firewalld

show_ok "Firewalld habilitado."


systemctl enable --now oddjobd

show_ok "Oddjobd habilitado."


# ==========================================================
# 16. VERIFICAR SERVICIOS
# ==========================================================

log "8. Verificando servicios"


ERROR_SERVICIO=0


for SERVICIO in "${REQUIRED_SERVICES[@]}"
do

    if systemctl is-active --quiet "${SERVICIO}"; then

        show_ok "${SERVICIO} esta activo."

    else

        show_error "${SERVICIO} no esta activo."

        ERROR_SERVICIO=1
    fi

done


# ==========================================================
# 17. VERIFICAR SSSD
# ==========================================================

echo ""

show_info "Verificando estado de SSSD."


if systemctl is-active --quiet sssd; then

    show_warning "SSSD esta activo."
    echo ""
    echo "Este script NO inicia SSSD."
    echo "El servicio posiblemente estaba configurado anteriormente."
    echo ""
else

    show_ok "SSSD no esta activo."
    show_info "Sera configurado posteriormente por config_domain_rl_fw.sh."
fi


# ==========================================================
# 18. VERIFICAR HERRAMIENTAS ACTIVE DIRECTORY
# ==========================================================

log "9. Verificando herramientas de Active Directory"


for CMD in "${AD_COMMANDS[@]}"
do

    if command -v "${CMD}" >/dev/null 2>&1; then

        show_ok "${CMD} disponible."

    else

        show_error "No se encontro ${CMD}."

        ERROR_SERVICIO=1
    fi

done


# ==========================================================
# 19. VERIFICAR PAQUETES PRINCIPALES
# ==========================================================

log "10. Verificando paquetes instalados"


PACKAGES_TO_VERIFY=(
    NetworkManager
    openssh-server
    firewalld
    policycoreutils
    policycoreutils-python-utils
    realmd
    sssd
    sssd-tools
    oddjob
    oddjob-mkhomedir
    adcli
    krb5-workstation
    samba-common-tools
    openldap-clients
)


for PACKAGE in "${PACKAGES_TO_VERIFY[@]}"
do

    if rpm -q "${PACKAGE}" >/dev/null 2>&1; then

        show_ok "${PACKAGE}"
    else

        show_error "${PACKAGE} no esta instalado."

        ERROR_SERVICIO=1
    fi

done


# ==========================================================
# 20. VERSIONES
# ==========================================================

log "11. Versiones instaladas"


echo ""
echo "Sistema:"
echo "----------------------------------------------------------"

cat /etc/rocky-release


echo ""
echo "NetworkManager:"
echo "----------------------------------------------------------"

nmcli --version


echo ""
echo "Firewalld:"
echo "----------------------------------------------------------"

firewall-cmd --version


echo ""
echo "SSSD:"
echo "----------------------------------------------------------"

sssd --version


echo ""
echo "Realmd:"
echo "----------------------------------------------------------"

if realm --version >/dev/null 2>&1; then

    realm --version

else

    rpm -q realmd
fi


echo ""
echo "Kerberos:"
echo "----------------------------------------------------------"

rpm -q krb5-workstation


echo ""
echo "ADCLI:"
echo "----------------------------------------------------------"

if adcli --version >/dev/null 2>&1; then

    adcli --version
else

    rpm -q adcli
fi


echo ""
echo "OpenLDAP:"
echo "----------------------------------------------------------"

rpm -q openldap-clients


# ==========================================================
# 21. VERIFICAR SELINUX
# ==========================================================

log "12. Verificando SELinux"


if command -v getenforce >/dev/null 2>&1; then

    SELINUX_STATUS="$(getenforce)"

    echo "Estado SELinux: ${SELINUX_STATUS}"
    echo ""


    case "${SELINUX_STATUS}" in

        Enforcing)

            show_ok "SELinux esta en modo Enforcing."
            ;;

        Permissive)

            show_warning "SELinux esta en modo Permissive."
            ;;

        Disabled)

            show_warning "SELinux esta deshabilitado."
            ;;

        *)

            show_warning "Estado SELinux desconocido."
            ;;

    esac

else

    show_warning "El comando getenforce no esta disponible."
fi


# ==========================================================
# 22. INTERFACES DETECTADAS
# ==========================================================

log "13. Interfaces detectadas"


ip -brief address


# ==========================================================
# 23. TABLA DE RUTAS
# ==========================================================

log "14. Tabla de rutas"


ip route


# ==========================================================
# 24. ESTADO DE FIREWALLD
# ==========================================================

log "15. Estado de Firewalld"


if firewall-cmd --state >/dev/null 2>&1; then

    show_ok "Firewalld esta operativo."

    echo ""
    echo "Zonas activas:"
    echo ""

    firewall-cmd --get-active-zones

else

    show_error "Firewalld no responde correctamente."

    ERROR_SERVICIO=1
fi


# ==========================================================
# 25. VERIFICAR IPv4 FORWARDING
# ==========================================================

log "16. Verificando parametros IPv4"


echo "net.ipv4.ip_forward:"
echo ""

sysctl net.ipv4.ip_forward


echo ""
echo "ICMP redirects:"
echo ""

sysctl net.ipv4.conf.all.accept_redirects
sysctl net.ipv4.conf.all.send_redirects


echo ""
echo "Source routing:"
echo ""

sysctl net.ipv4.conf.all.accept_source_route


# ==========================================================
# 26. VERIFICAR NECESIDAD DE REINICIO
# ==========================================================

log "17. Verificando kernel"


REBOOT_REQUIRED=0

CURRENT_KERNEL="$(uname -r)"


LATEST_KERNEL="$(
    rpm -q kernel \
        --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' \
        2>/dev/null |
        sort -V |
        tail -n 1
)"


echo "Kernel actual    : ${CURRENT_KERNEL}"


if [[ -n "${LATEST_KERNEL}" ]]; then

    echo "Kernel instalado : ${LATEST_KERNEL}"


    if [[ "${CURRENT_KERNEL}" != "${LATEST_KERNEL}" ]]; then

        REBOOT_REQUIRED=1

        echo ""
        show_warning "Existe un kernel mas reciente instalado."
        show_warning "Se recomienda reiniciar RL-FW."
    else

        show_ok "El servidor utiliza el kernel mas reciente."
    fi

else

    show_warning "No fue posible determinar el ultimo kernel instalado."
fi


# ==========================================================
# 27. RESULTADO FINAL
# ==========================================================

log "RESULTADO FINAL"


if [[ "${ERROR_SERVICIO}" -ne 0 ]]; then

    echo "PREPARACION DE RL-FW FINALIZADA CON ERRORES"
    echo ""
    echo "Uno o mas componentes no superaron la verificacion."
    echo ""
    echo "Revise los mensajes anteriores."

    exit 1
fi


echo "PREPARACION DE RL-FW FINALIZADA CORRECTAMENTE"
echo ""

echo "RL-FW esta preparado para:"
echo ""
echo "  - NetworkManager"
echo "  - Routing IPv4"
echo "  - Firewalld"
echo "  - SSH"
echo "  - SELinux"
echo "  - Active Directory mediante realmd/SSSD"
echo ""

echo "Servicios activos:"
echo ""
echo "  - NetworkManager"
echo "  - sshd"
echo "  - firewalld"
echo "  - oddjobd"
echo ""

echo "SSSD:"
echo ""
echo "  - Instalado"
echo "  - No iniciado por este script"
echo "  - Pendiente de configuracion de dominio"
echo ""

echo "IPv4 forwarding:"
echo ""
echo "  - Habilitado"
echo ""

echo "AUN NO se configuro:"
echo ""
echo "  - ens33 WAN"
echo "  - ens36 SERVICIOS"
echo "  - ens37 MONITOREO"
echo "  - ens38 APLICACIONES"
echo "  - ens39 DMZ"
echo ""
echo "  - Direcciones IP"
echo "  - Gateways"
echo "  - Zonas definitivas de Firewalld"
echo "  - NAT"
echo "  - Politicas inter-red"
echo "  - Union a neltek.uy"
echo ""

echo "Siguiente orden:"
echo ""
echo "  1. ./config_rl_fw.sh"
echo "  2. ./config_domain_rl_fw.sh"
echo ""


if [[ "${REBOOT_REQUIRED}" -eq 1 ]]; then

    echo "----------------------------------------------------------"
    echo "REINICIO RECOMENDADO"
    echo "----------------------------------------------------------"
    echo ""
    echo "Se instalo un kernel diferente al que esta en ejecucion."
    echo ""
    echo "Cuando corresponda:"
    echo ""
    echo "  reboot"
    echo ""
fi


echo "=========================================================="
echo " FIN DE PREPARACION RL-FW"
echo "=========================================================="
echo ""