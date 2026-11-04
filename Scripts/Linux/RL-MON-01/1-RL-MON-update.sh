#!/usr/bin/env bash

# ==========================================================
# Recoleccion UY - Preparacion de paquetes RL-MON-01
#
# Funciones:
# - Verifica que el sistema sea Rocky Linux 9
# - Actualiza el sistema operativo
# - Instala herramientas basicas
# - Instala complementos de DNF
# - Instala Docker CE y Docker Compose
# - Instala OpenSSH, Firewalld y herramientas SELinux
# - Instala dependencias para Active Directory / LDAP
# - Instala herramientas de red y sincronizacion horaria
# - Habilita Docker, SSH, Firewalld y NetworkManager
# - Habilita Chrony
# - Verifica paquetes, servicios y componentes principales
#
# IMPORTANTE:
#
# Este script NO configura:
# - Docker
# - Redes Docker
# - Sistemas de monitoreo
# - Red estatica ens33
# - DNS
# - Hostname
# - SSH
# - Reglas de Firewall
# - Active Directory / LDAP
# - SSSD
# - Oddjob
# - Directorios de monitoreo
#
# Esas tareas corresponden a scripts especificos.
#
# Servidor:
# - RL-MON-01
#
# Red prevista:
# - Interfaz : ens33
# - IP       : 192.168.20.20/24
# - Gateway  : 192.168.20.1
# - DNS 1    : 192.168.10.20
# - DNS 2    : 192.168.10.21
# - Dominio  : neltek.uy
#
# Compatible con:
# - Rocky Linux 9
#
# Ejecutar como:
#
#   sudo ./1-RL-MON-update.sh
#
# ADVERTENCIA:
# - Se inicia firewalld siguiendo el script base.
# - Comprobar acceso SSH antes de ejecutar remotamente.
# - No se modifican reglas ni zonas de firewall.
#
# ==========================================================


set -Eeuo pipefail


# ==========================================================
# 1. CONFIGURACION GENERAL
# ==========================================================

DOCKER_REPO_URL="https://download.docker.com/linux/centos/docker-ce.repo"

DOCKER_REPO_FILE="/etc/yum.repos.d/docker-ce.repo"


BASIC_PACKAGES=(
    nano
    sudo
    dnf-plugins-core
)


SYSTEM_PACKAGES=(
    NetworkManager
    openssh-server
    openssh-clients
    firewalld
    policycoreutils-python-utils
)


AD_PACKAGES=(
    realmd
    sssd
    sssd-tools
    oddjob
    oddjob-mkhomedir
    adcli
    samba-common-tools
    krb5-workstation
    openldap-clients
    bind-utils
)


NETWORK_PACKAGES=(
    hostname
    iproute
    curl
    chrony
    authselect
)


DOCKER_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)


REQUIRED_SERVICES=(
    docker
    containerd
    sshd
    firewalld
    NetworkManager
    chronyd
)


# ==========================================================
# 2. FUNCIONES GENERALES
# ==========================================================

show_header() {

    echo ""
    echo "=========================================================="
    echo "$1"
    echo "=========================================================="
}


show_ok() {

    echo "[OK] $1"
}


show_info() {

    echo "[INFO] $1"
}


show_warning() {

    echo "[ADVERTENCIA] $1"
}


show_error() {

    echo "[ERROR] $1"
}


# ==========================================================
# 3. MANEJO GENERAL DE ERRORES
# ==========================================================

error_handler() {

    local exit_code=$?
    local line_number=$1

    echo ""
    echo "=========================================================="
    echo "ERROR DURANTE LA EJECUCION"
    echo "=========================================================="
    echo ""
    echo "Linea    : $line_number"
    echo "Comando  : $BASH_COMMAND"
    echo "Codigo   : $exit_code"
    echo ""
    echo "La preparacion de RL-MON-01 no pudo completarse."
    echo ""

    exit "$exit_code"
}


trap 'error_handler $LINENO' ERR


# ==========================================================
# 4. VERIFICAR PRIVILEGIOS
# ==========================================================

show_header "Recoleccion UY - Preparacion RL-MON-01"


if [ "$EUID" -ne 0 ]; then

    show_error "Debe ejecutar este script como root."

    echo ""
    echo "Ejemplo:"
    echo ""
    echo "  sudo ./1-RL-MON-update.sh"
    echo ""

    exit 1
fi


show_ok "Privilegios administrativos verificados."


# ==========================================================
# 5. VERIFICAR SISTEMA OPERATIVO
# ==========================================================

show_header "Verificando sistema operativo"


if [ ! -f /etc/os-release ]; then

    show_error "No fue posible identificar el sistema operativo."

    exit 1
fi


source /etc/os-release


if [ "${ID:-}" != "rocky" ]; then

    show_error "Este script esta preparado para Rocky Linux."
    echo ""
    echo "Sistema detectado:"
    echo ""
    echo "  ID=${ID:-desconocido}"
    echo "  VERSION_ID=${VERSION_ID:-desconocido}"
    echo ""

    exit 1
fi


if [ "${VERSION_ID%%.*}" != "9" ]; then

    show_error "Este script requiere Rocky Linux 9."
    echo ""
    echo "Version detectada: ${VERSION_ID:-desconocida}"
    echo ""

    exit 1
fi


show_ok "Rocky Linux 9 detectado."

echo ""
echo "Sistema : ${PRETTY_NAME:-Rocky Linux 9}"


# ==========================================================
# 6. VERIFICAR DNF
# ==========================================================

if ! command -v dnf >/dev/null 2>&1; then

    show_error "DNF no esta disponible."

    exit 1
fi


show_ok "DNF disponible."


# ==========================================================
# 7. ACTUALIZAR SISTEMA OPERATIVO
# ==========================================================

show_header "1. Actualizando Rocky Linux"


dnf upgrade -y


show_ok "Actualizacion del sistema completada."


# ==========================================================
# 8. INSTALAR HERRAMIENTAS BASICAS
# ==========================================================

show_header "2. Instalando herramientas basicas"


dnf install -y "${BASIC_PACKAGES[@]}"


show_ok "Herramientas basicas instaladas."


# ==========================================================
# 9. INSTALAR COMPONENTES DEL SISTEMA
# ==========================================================

show_header "3. Instalando componentes del sistema"


dnf install -y "${SYSTEM_PACKAGES[@]}"


show_ok "Componentes del sistema instalados."


# ==========================================================
# 10. INSTALAR DEPENDENCIAS AD / LDAP
# ==========================================================

show_header "4. Instalando dependencias AD / LDAP"


dnf install -y "${AD_PACKAGES[@]}"


show_ok "Dependencias AD / LDAP instaladas."


# ==========================================================
# 11. INSTALAR HERRAMIENTAS DE RED Y TIEMPO
# ==========================================================

show_header "5. Instalando herramientas de red y tiempo"


dnf install -y "${NETWORK_PACKAGES[@]}"


show_ok "Herramientas de red y tiempo instaladas."


# ==========================================================
# 12. CONFIGURAR REPOSITORIO DOCKER
# ==========================================================

show_header "6. Configurando repositorio Docker"


if [ ! -f "$DOCKER_REPO_FILE" ]; then

    show_info "Repositorio Docker no encontrado."
    show_info "Agregando repositorio oficial Docker CE."


    dnf config-manager --add-repo "$DOCKER_REPO_URL"


    if [ ! -f "$DOCKER_REPO_FILE" ]; then

        show_error "El archivo del repositorio Docker no fue creado."

        exit 1
    fi


    show_ok "Repositorio Docker agregado."

else

    show_ok "Repositorio Docker ya configurado."

fi


# ==========================================================
# 13. VERIFICAR REPOSITORIO DOCKER
# ==========================================================

show_info "Verificando disponibilidad del repositorio Docker."


if ! dnf repolist --enabled | grep -q "docker-ce-stable"; then

    show_error "El repositorio docker-ce-stable no esta habilitado."
    echo ""
    echo "Archivo detectado:"
    echo ""
    echo "  $DOCKER_REPO_FILE"
    echo ""

    exit 1
fi


show_ok "Repositorio docker-ce-stable disponible."


# ==========================================================
# 14. INSTALAR DOCKER
# ==========================================================

show_header "7. Instalando Docker"


dnf install -y "${DOCKER_PACKAGES[@]}"


show_ok "Docker instalado."


# ==========================================================
# 15. ADVERTENCIA FIREWALL
# ==========================================================

show_header "8. Preparando servicios"


echo "Se habilitaran los siguientes servicios:"
echo ""
echo "  - Docker"
echo "  - Containerd"
echo "  - SSH"
echo "  - Firewalld"
echo "  - NetworkManager"
echo "  - Chronyd"
echo ""


show_warning "Este script NO modifica reglas de firewall."
show_warning "La configuracion especifica se realizara mediante otro script."
show_warning "Antes de iniciar firewalld se debe verificar el acceso SSH."
echo ""


# ==========================================================
# 16. HABILITAR SERVICIOS
# ==========================================================

systemctl enable --now containerd

show_ok "Containerd habilitado."


systemctl enable --now docker

show_ok "Docker habilitado."


systemctl enable --now sshd

show_ok "SSHD habilitado."


systemctl enable --now firewalld

show_ok "Firewalld habilitado."


systemctl enable --now NetworkManager

show_ok "NetworkManager habilitado."


systemctl enable --now chronyd

show_ok "Chronyd habilitado."


# ==========================================================
# 17. VERIFICAR SERVICIOS
# ==========================================================

show_header "9. Verificando servicios"


SERVICE_ERROR=0


for SERVICE in "${REQUIRED_SERVICES[@]}"; do

    if systemctl is-active --quiet "$SERVICE"; then

        show_ok "$SERVICE esta activo."

    else

        show_error "$SERVICE no esta activo."

        SERVICE_ERROR=1

    fi

done


# ==========================================================
# 18. VERIFICAR QUE SSSD NO SE HABILITO
# ==========================================================

echo ""

show_info "Verificando SSSD."


if systemctl is-active --quiet sssd; then

    show_warning "SSSD esta activo."

    echo ""
    echo "Este script no inicia SSSD."
    echo "El servicio posiblemente ya estaba configurado anteriormente."
    echo ""

else

    show_ok "SSSD no esta activo."

fi


# ==========================================================
# 19. VERIFICAR ODDJOB
# ==========================================================

show_info "Verificando Oddjob."


if systemctl is-active --quiet oddjobd; then

    show_warning "oddjobd esta activo."

    echo ""
    echo "Este script no inicia oddjobd."
    echo "El servicio posiblemente ya estaba habilitado anteriormente."
    echo ""

else

    show_ok "oddjobd no esta activo."

fi


# ==========================================================
# 20. VERIFICAR INSTALACIONES
# ==========================================================

show_header "10. Verificando instalaciones"


echo ""
echo "Rocky Linux:"
echo "----------------------------------------------------------"

cat /etc/rocky-release


echo ""
echo "Nano:"
echo "----------------------------------------------------------"

nano --version | head -n 1


echo ""
echo "DNF Plugins Core:"
echo "----------------------------------------------------------"

rpm -q dnf-plugins-core


echo ""
echo "Docker:"
echo "----------------------------------------------------------"

docker --version


echo ""
echo "Docker Compose:"
echo "----------------------------------------------------------"

docker compose version


echo ""
echo "Containerd:"
echo "----------------------------------------------------------"

containerd --version


echo ""
echo "OpenSSH Server:"
echo "----------------------------------------------------------"

rpm -q openssh-server


echo ""
echo "Firewalld:"
echo "----------------------------------------------------------"

rpm -q firewalld


echo ""
echo "SELinux Tools:"
echo "----------------------------------------------------------"

rpm -q policycoreutils-python-utils


echo ""
echo "NetworkManager:"
echo "----------------------------------------------------------"

rpm -q NetworkManager


echo ""
echo "Chrony:"
echo "----------------------------------------------------------"

rpm -q chrony


echo ""
echo "Realmd:"
echo "----------------------------------------------------------"

rpm -q realmd


echo ""
echo "SSSD:"
echo "----------------------------------------------------------"

rpm -q sssd


echo ""
echo "SSSD Tools:"
echo "----------------------------------------------------------"

rpm -q sssd-tools


echo ""
echo "Oddjob:"
echo "----------------------------------------------------------"

rpm -q oddjob


echo ""
echo "Oddjob MKHomeDir:"
echo "----------------------------------------------------------"

rpm -q oddjob-mkhomedir


echo ""
echo "ADCLI:"
echo "----------------------------------------------------------"

rpm -q adcli


echo ""
echo "Kerberos:"
echo "----------------------------------------------------------"

rpm -q krb5-workstation


echo ""
echo "LDAP:"
echo "----------------------------------------------------------"

rpm -q openldap-clients


echo ""
echo "Samba:"
echo "----------------------------------------------------------"

rpm -q samba-common-tools


echo ""
echo "Bind Utils:"
echo "----------------------------------------------------------"

rpm -q bind-utils


echo ""
echo "Authselect:"
echo "----------------------------------------------------------"

rpm -q authselect


# ==========================================================
# 21. VERIFICAR HERRAMIENTAS DE RED
# ==========================================================

show_header "11. Verificando herramientas de red"


if command -v nmcli >/dev/null 2>&1; then

    show_ok "NetworkManager CLI disponible."

else

    show_error "nmcli no esta disponible."
    SERVICE_ERROR=1

fi


if command -v dig >/dev/null 2>&1; then

    show_ok "Herramientas DNS disponibles."

else

    show_error "dig no esta disponible."
    SERVICE_ERROR=1

fi


if command -v chronyc >/dev/null 2>&1; then

    show_ok "Herramientas Chrony disponibles."

else

    show_error "chronyc no esta disponible."
    SERVICE_ERROR=1

fi


# ==========================================================
# 22. VERIFICAR SELINUX
# ==========================================================

show_header "12. Verificando SELinux"


if command -v getenforce >/dev/null 2>&1; then

    SELINUX_STATUS="$(getenforce)"

    echo "Estado SELinux: $SELINUX_STATUS"


    case "$SELINUX_STATUS" in

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

            show_warning "No fue posible determinar correctamente el estado SELinux."
            ;;

    esac

else

    show_warning "El comando getenforce no esta disponible."

fi


# ==========================================================
# 23. VERIFICAR DOCKER
# ==========================================================

show_header "13. Verificando funcionamiento Docker"


if docker info >/dev/null 2>&1; then

    show_ok "Docker Engine responde correctamente."

else

    show_error "Docker esta instalado pero Docker Engine no responde."

    SERVICE_ERROR=1

fi


# ==========================================================
# 24. COMPROBAR NECESIDAD DE REINICIO
# ==========================================================

show_header "14. Verificando necesidad de reinicio"


REBOOT_REQUIRED=0


CURRENT_KERNEL="$(uname -r)"

LATEST_KERNEL="$(
    rpm -q kernel \
        --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' \
        2>/dev/null |
        sort -V |
        tail -n 1
)"


echo "Kernel actual    : $CURRENT_KERNEL"


if [ -n "$LATEST_KERNEL" ]; then

    echo "Kernel instalado : $LATEST_KERNEL"


    if [ "$CURRENT_KERNEL" != "$LATEST_KERNEL" ]; then

        REBOOT_REQUIRED=1

        show_warning "Existe un kernel mas reciente instalado."
        show_warning "Se recomienda reiniciar el servidor."

    else

        show_ok "El servidor esta utilizando el kernel mas reciente."

    fi

else

    show_warning "No fue posible determinar el ultimo kernel instalado."

fi


# ==========================================================
# 25. RESULTADO FINAL
# ==========================================================

show_header "RESULTADO FINAL"


if [ "$SERVICE_ERROR" -ne 0 ]; then

    echo "PREPARACION FINALIZADA CON ERRORES"
    echo ""
    echo "Uno o mas servicios o herramientas no respondieron"
    echo "correctamente durante la verificacion."
    echo ""

    exit 1

fi


echo "PREPARACION FINALIZADA CORRECTAMENTE"
echo ""

echo "Servicios activos:"
echo ""
echo "  - Docker"
echo "  - Containerd"
echo "  - SSH"
echo "  - Firewalld"
echo "  - NetworkManager"
echo "  - Chronyd"
echo ""

echo "Componentes AD instalados:"
echo ""
echo "  - Realmd"
echo "  - SSSD"
echo "  - SSSD Tools"
echo "  - Oddjob"
echo "  - ADCLI"
echo "  - Kerberos"
echo "  - LDAP Clients"
echo "  - Samba Common Tools"
echo ""

echo "SSSD y Oddjob NO fueron iniciados por este script."
echo "Seran configurados posteriormente mediante el script"
echo "de integracion con Active Directory."
echo ""

echo "Configuraciones pendientes:"
echo ""
echo "  - Red estatica ens33"
echo "  - DNS Active Directory"
echo "  - Hostname RL-MON-01"
echo "  - Union al dominio neltek.uy"
echo "  - Configuracion SSSD"
echo "  - Configuracion SSH"
echo "  - Reglas locales de firewall"
echo "  - Redes Docker"
echo "  - Instalacion de monitoreo"
echo ""


if [ "$REBOOT_REQUIRED" -eq 1 ]; then

    echo "----------------------------------------------------------"
    echo "REINICIO RECOMENDADO"
    echo "----------------------------------------------------------"
    echo ""
    echo "Se instalo un kernel diferente al que esta ejecutandose."
    echo ""
    echo "Cuando corresponda, reinicie mediante:"
    echo ""
    echo "  reboot"
    echo ""

fi


echo "=========================================================="
echo " FIN DE PREPARACION RL-MON-01"
echo "=========================================================="
echo ""