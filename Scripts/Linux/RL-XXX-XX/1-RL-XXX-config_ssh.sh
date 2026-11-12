#!/bin/bash

# ============================================================
# Recolección UY
# Configuración segura de SSH - Rocky Linux 9
#
# Funciones:
#   - Crea/reutiliza usuario local adminssh
#   - Crea grupo local ssh_emergency
#   - Configura sudo para:
#       * ssh_emergency
#       * gg_rec_server_admins_linux
#   - Solicita y valida clave pública de adminssh
#   - Configura contexto SELinux de authorized_keys
#   - Configura puerto SSH personalizado
#   - Configura SELinux para el puerto SSH
#   - Configura firewalld
#   - Deshabilita root por SSH
#   - Exige:
#       clave pública + contraseña
#   - Permite SSH a:
#       * ssh_emergency
#       * gg_rec_server_admins_linux
#   - Mantiene temporalmente TCP/22 durante prueba
#   - Cierra TCP/22 solamente después de confirmación
#
# Este script NO:
#   - Instala paquetes
#   - Genera claves privadas
#   - Configura usuarios AD individuales
#   - Configura SSSD
#   - Une el servidor al dominio
# ============================================================


# ============================================================
# CONFIGURACIÓN
# ============================================================

INTERFACE="ens33"

DEFAULT_SSH_PORT="2222"

AD_DOMAIN="neltek.uy"
AD_GROUP="gg_rec_server_admins_linux"

EMERGENCY_USER="adminssh"
EMERGENCY_GROUP="ssh_emergency"


# ============================================================
# ARCHIVOS
# ============================================================

SSHD_CONFIG="/etc/ssh/sshd_config"

SSHD_DROPIN="/etc/ssh/sshd_config.d/00-recoleccion-uy.conf"

AUTHORIZED_KEYS_DIR="/etc/ssh/authorized_keys"

ADMINSSH_KEY_FILE="$AUTHORIZED_KEYS_DIR/$EMERGENCY_USER"

SUDOERS_FILE="/etc/sudoers.d/recoleccion-linux-admins"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

SSHD_CONFIG_BACKUP="${SSHD_CONFIG}.bak.${TIMESTAMP}"

SSHD_DROPIN_BACKUP="${SSHD_DROPIN}.bak.${TIMESTAMP}"

SUDOERS_BACKUP="${SUDOERS_FILE}.bak.${TIMESTAMP}"

FIREWALL_ZONE=""

SSH_PORT=""

ADMINSSH_PUBLIC_KEY=""


# ============================================================
# FUNCIONES
# ============================================================

header() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}

ok() {
    echo "[OK] $1"
}

warning() {
    echo "[ADVERTENCIA] $1"
}

error() {
    echo "[ERROR] $1"
}


# ============================================================
# VERIFICAR SI SSHD ESCUCHA EN UN PUERTO
# ============================================================

sshd_is_listening() {

    local PORT="$1"

    ss -lntpH "sport = :$PORT" 2>/dev/null \
        | grep -q 'sshd'
}


# ============================================================
# OBTENER LISTENER DE UN PUERTO
# ============================================================

get_port_listener() {

    local PORT="$1"

    ss -lntpH "sport = :$PORT" 2>/dev/null || true
}


# ============================================================
# VALIDAR CLAVE PÚBLICA
# ============================================================

validate_public_key() {

    local KEY="$1"
    local TMP_KEY

    TMP_KEY="$(mktemp)"

    printf '%s\n' "$KEY" > "$TMP_KEY"

    chmod 600 "$TMP_KEY"

    if ! ssh-keygen -l -f "$TMP_KEY" >/dev/null 2>&1; then

        rm -f "$TMP_KEY"

        return 1
    fi

    rm -f "$TMP_KEY"

    return 0
}


# ============================================================
# ROLLBACK SSH
# ============================================================

rollback_ssh() {

    header "ROLLBACK SSH"

    warning "Restaurando configuración SSH anterior."


    if [ -f "$SSHD_CONFIG_BACKUP" ]; then

        cp -a \
            "$SSHD_CONFIG_BACKUP" \
            "$SSHD_CONFIG"
    fi


    if [ -f "$SSHD_DROPIN_BACKUP" ]; then

        cp -a \
            "$SSHD_DROPIN_BACKUP" \
            "$SSHD_DROPIN"

    else

        rm -f "$SSHD_DROPIN"
    fi


    if sshd -t; then

        systemctl reload sshd

        ok "Configuración SSH anterior restaurada."

    else

        error "La configuración restaurada no supera sshd -t."

        echo
        echo "NO cierre la sesión actual."
    fi
}


# ============================================================
# COMPROBAR ROOT
# ============================================================

if [ "$EUID" -ne 0 ]; then

    error "Este script debe ejecutarse como root."

    exit 1
fi


# ============================================================
# PRESENTACIÓN
# ============================================================

header "CONFIGURACIÓN SSH - RECOLECCIÓN UY"

echo
echo "Usuario local:"
echo "  $EMERGENCY_USER"

echo
echo "Grupo local:"
echo "  $EMERGENCY_GROUP"

echo
echo "Grupo AD autorizado:"
echo "  $AD_GROUP"

echo
echo "Autenticación:"
echo "  clave pública + contraseña"

echo
echo "Root por SSH:"
echo "  deshabilitado"

echo
echo "Sudo:"
echo "  con contraseña"


# ============================================================
# VERIFICAR DEPENDENCIAS
# ============================================================

header "Verificando dependencias"

REQUIRED_COMMANDS=(
    sshd
    ssh-keygen
    semanage
    restorecon
    firewall-cmd
    visudo
    ss
    realm
)

for COMMAND in "${REQUIRED_COMMANDS[@]}"; do

    if ! command -v "$COMMAND" >/dev/null 2>&1; then

        error "Falta la dependencia: $COMMAND"

        echo
        echo "Ejecute previamente update_ssh.sh."
        echo

        exit 1
    fi
done

ok "Dependencias verificadas."


# ============================================================
# VERIFICAR SSSD / AD
# ============================================================

header "Verificando Active Directory"

if ! systemctl is-active --quiet sssd; then

    error "SSSD no está activo."

    exit 1
fi

ok "SSSD está activo."


if ! realm list 2>/dev/null \
    | grep -qiE \
    "^[[:space:]]*domain-name:[[:space:]]*$AD_DOMAIN[[:space:]]*$"; then

    error "El servidor no está unido a $AD_DOMAIN."

    exit 1
fi

ok "Servidor unido a $AD_DOMAIN."


# ============================================================
# SOLICITAR PUERTO
# ============================================================

header "Puerto SSH"

read -r -p \
    "Puerto SSH a utilizar [$DEFAULT_SSH_PORT]: " \
    SSH_PORT

SSH_PORT="${SSH_PORT:-$DEFAULT_SSH_PORT}"


if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]]; then

    error "El puerto debe ser numérico."

    exit 1
fi


if [ "$SSH_PORT" -lt 1024 ] || \
   [ "$SSH_PORT" -gt 65535 ]; then

    error "El puerto debe estar entre 1024 y 65535."

    exit 1
fi


if [ "$SSH_PORT" -eq 22 ]; then

    error "Debe utilizar un puerto distinto de TCP/22."

    exit 1
fi

ok "Puerto seleccionado: $SSH_PORT"


# ============================================================
# SOLICITAR CLAVE PÚBLICA
# ============================================================

header "Clave pública de $EMERGENCY_USER"

echo
echo "Desde PuTTYgen copie:"
echo
echo "  Public key for pasting into OpenSSH authorized_keys file"
echo
echo "Ejemplo:"
echo
echo "  ssh-ed25519 AAAAC3... comentario"
echo
echo "NO copie:"
echo "  - archivo .ppk"
echo "  - clave privada"
echo "  - passphrase"
echo

read -r -p \
    "Clave pública de $EMERGENCY_USER: " \
    ADMINSSH_PUBLIC_KEY


if [ -z "$ADMINSSH_PUBLIC_KEY" ]; then

    error "No se proporcionó ninguna clave pública."

    exit 1
fi


if [[ "$ADMINSSH_PUBLIC_KEY" != ssh-ed25519\ * ]]; then

    error "La clave debe comenzar con ssh-ed25519."

    exit 1
fi


if ! validate_public_key "$ADMINSSH_PUBLIC_KEY"; then

    error "La clave pública proporcionada no es válida."

    exit 1
fi

ok "Clave pública válida."


# ============================================================
# FIREWALL
# ============================================================

header "Verificando firewalld"

if ! systemctl is-active --quiet firewalld; then

    error "firewalld no está activo."

    exit 1
fi


FIREWALL_ZONE="$(
    firewall-cmd \
        --get-zone-of-interface="$INTERFACE" \
        2>/dev/null
)"


if [ -z "$FIREWALL_ZONE" ] || \
   [ "$FIREWALL_ZONE" = "no zone" ]; then

    FIREWALL_ZONE="$(
        firewall-cmd --get-default-zone
    )"
fi


if [ -z "$FIREWALL_ZONE" ]; then

    error "No se pudo determinar la zona de firewalld."

    exit 1
fi

ok "Zona firewalld: $FIREWALL_ZONE"


# ============================================================
# VERIFICAR PUERTO
# ============================================================

header "Verificando TCP/$SSH_PORT"

PORT_PROCESS="$(
    get_port_listener "$SSH_PORT"
)"


if [ -n "$PORT_PROCESS" ]; then

    if echo "$PORT_PROCESS" | grep -q sshd; then

        warning "TCP/$SSH_PORT ya está siendo utilizado por sshd."

    else

        error "TCP/$SSH_PORT está siendo utilizado por otro servicio."

        echo
        echo "$PORT_PROCESS"

        exit 1
    fi
fi


# ============================================================
# CREAR / REUTILIZAR ADMINSSH
# ============================================================

header "Configurando usuario $EMERGENCY_USER"

if id "$EMERGENCY_USER" >/dev/null 2>&1; then

    ok "$EMERGENCY_USER ya existe."

else

    useradd \
        -m \
        -s /bin/bash \
        "$EMERGENCY_USER"

    if [ $? -ne 0 ]; then

        error "No se pudo crear $EMERGENCY_USER."

        exit 1
    fi

    ok "$EMERGENCY_USER creado."
fi


# ============================================================
# ASEGURAR SHELL
# ============================================================

CURRENT_SHELL="$(
    getent passwd "$EMERGENCY_USER" \
        | cut -d: -f7
)"


if [ "$CURRENT_SHELL" != "/bin/bash" ]; then

    usermod \
        -s /bin/bash \
        "$EMERGENCY_USER"

    if [ $? -ne 0 ]; then

        error "No se pudo configurar /bin/bash."

        exit 1
    fi
fi


# ============================================================
# CREAR GRUPO EMERGENCIA
# ============================================================

if ! getent group "$EMERGENCY_GROUP" >/dev/null 2>&1; then

    groupadd "$EMERGENCY_GROUP"

    if [ $? -ne 0 ]; then

        error "No se pudo crear $EMERGENCY_GROUP."

        exit 1
    fi
fi


# ============================================================
# ADMINSSH → WHEEL + SSH_EMERGENCY
# ============================================================

usermod \
    -aG "$EMERGENCY_GROUP,wheel" \
    "$EMERGENCY_USER"


if [ $? -ne 0 ]; then

    error "No se pudieron configurar los grupos."

    exit 1
fi


if ! id -nG "$EMERGENCY_USER" \
    | tr ' ' '\n' \
    | grep -Fxq "$EMERGENCY_GROUP"; then

    error "$EMERGENCY_USER no pertenece a $EMERGENCY_GROUP."

    exit 1
fi


if ! id -nG "$EMERGENCY_USER" \
    | tr ' ' '\n' \
    | grep -Fxq "wheel"; then

    error "$EMERGENCY_USER no pertenece a wheel."

    exit 1
fi

ok "$EMERGENCY_USER pertenece a wheel y $EMERGENCY_GROUP."


# ============================================================
# CONTRASEÑA LOCAL
# ============================================================

header "Contraseña local de $EMERGENCY_USER"

PASSWORD_STATUS="$(
    passwd -S "$EMERGENCY_USER" 2>/dev/null \
        | awk '{print $2}'
)"


if [ "$PASSWORD_STATUS" != "PS" ]; then

    echo
    echo "Debe configurar una contraseña LOCAL."
    echo
    echo "Se utilizará para:"
    echo "  - segundo factor SSH"
    echo "  - sudo"
    echo

    passwd "$EMERGENCY_USER"

    if [ $? -ne 0 ]; then

        error "No se pudo configurar la contraseña."

        exit 1
    fi
fi


PASSWORD_STATUS="$(
    passwd -S "$EMERGENCY_USER" 2>/dev/null \
        | awk '{print $2}'
)"


if [ "$PASSWORD_STATUS" != "PS" ]; then

    error "$EMERGENCY_USER no tiene contraseña habilitada."

    exit 1
fi

ok "Contraseña local configurada."


# ============================================================
# CONFIGURAR SUDO
# ============================================================

header "Configurando sudo"

if [ -f "$SUDOERS_FILE" ]; then

    cp -a \
        "$SUDOERS_FILE" \
        "$SUDOERS_BACKUP"
fi


SUDOERS_TMP="$(mktemp)"


cat > "$SUDOERS_TMP" <<EOF
# ============================================================
# Recolección UY
# Administradores Linux
#
# Los usuarios inician sesión normalmente.
# Para elevar privilegios utilizan sudo.
#
# NO se utiliza NOPASSWD.
# ============================================================

%$EMERGENCY_GROUP ALL=(ALL) ALL
%$AD_GROUP ALL=(ALL) ALL
EOF


chown root:root "$SUDOERS_TMP"
chmod 440 "$SUDOERS_TMP"


if ! visudo -cf "$SUDOERS_TMP"; then

    rm -f "$SUDOERS_TMP"

    error "La configuración sudo generada no es válida."

    exit 1
fi


cp "$SUDOERS_TMP" "$SUDOERS_FILE"

rm -f "$SUDOERS_TMP"


chown root:root "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"


if ! visudo -cf "$SUDOERS_FILE"; then

    error "La configuración sudo instalada no es válida."

    if [ -f "$SUDOERS_BACKUP" ]; then

        cp -a \
            "$SUDOERS_BACKUP" \
            "$SUDOERS_FILE"

    else

        rm -f "$SUDOERS_FILE"
    fi

    exit 1
fi

ok "Sudo configurado."


# ============================================================
# CREAR DIRECTORIO DE CLAVES
# ============================================================

header "Configurando repositorio de claves SSH"

mkdir -p "$AUTHORIZED_KEYS_DIR"

if [ $? -ne 0 ]; then

    error "No se pudo crear $AUTHORIZED_KEYS_DIR."

    exit 1
fi


chown root:root "$AUTHORIZED_KEYS_DIR"
chmod 755 "$AUTHORIZED_KEYS_DIR"


# ============================================================
# SELINUX - AUTHORIZED_KEYS
# ============================================================

SELINUX_STATUS="$(
    getenforce 2>/dev/null || echo Disabled
)"


if [ "$SELINUX_STATUS" != "Disabled" ]; then

    SELINUX_KEY_PATTERN="${AUTHORIZED_KEYS_DIR}(/.*)?"


    if semanage fcontext \
        -a \
        -t ssh_home_t \
        "$SELINUX_KEY_PATTERN" \
        >/dev/null 2>&1; then

        ok "Regla SELinux creada para authorized_keys."

    else

        if semanage fcontext \
            -m \
            -t ssh_home_t \
            "$SELINUX_KEY_PATTERN" \
            >/dev/null 2>&1; then

            ok "Regla SELinux actualizada."

        else

            error "No se pudo configurar SELinux para authorized_keys."

            exit 1
        fi
    fi


    restorecon \
        -Rv \
        "$AUTHORIZED_KEYS_DIR"

    if [ $? -ne 0 ]; then

        error "No se pudo aplicar contexto SELinux."

        exit 1
    fi
fi


# ============================================================
# INSTALAR CLAVE PÚBLICA
# ============================================================

printf '%s\n' \
    "$ADMINSSH_PUBLIC_KEY" \
    > "$ADMINSSH_KEY_FILE"


if [ $? -ne 0 ]; then

    error "No se pudo crear $ADMINSSH_KEY_FILE."

    exit 1
fi


chown root:root "$ADMINSSH_KEY_FILE"
chmod 644 "$ADMINSSH_KEY_FILE"


if [ "$SELINUX_STATUS" != "Disabled" ]; then

    restorecon \
        -v \
        "$ADMINSSH_KEY_FILE"

    if [ $? -ne 0 ]; then

        error "No se pudo aplicar contexto SELinux a la clave."

        exit 1
    fi
fi


# ============================================================
# VALIDAR ARCHIVO
# ============================================================

if [ ! -s "$ADMINSSH_KEY_FILE" ]; then

    error "$ADMINSSH_KEY_FILE está vacío."

    exit 1
fi


if ! ssh-keygen \
    -l \
    -f "$ADMINSSH_KEY_FILE" \
    >/dev/null 2>&1; then

    error "La clave instalada no es válida."

    exit 1
fi

ok "Clave pública instalada correctamente."

echo
echo "Fingerprint:"

ssh-keygen \
    -l \
    -f "$ADMINSSH_KEY_FILE"


# ============================================================
# VERIFICAR INCLUDE
# ============================================================

header "Verificando sshd_config"

if ! grep -Eq \
    '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' \
    "$SSHD_CONFIG"; then

    error "$SSHD_CONFIG no carga sshd_config.d."

    exit 1
fi


# ============================================================
# BACKUPS
# ============================================================

cp -a \
    "$SSHD_CONFIG" \
    "$SSHD_CONFIG_BACKUP"


if [ -f "$SSHD_DROPIN" ]; then

    cp -a \
        "$SSHD_DROPIN" \
        "$SSHD_DROPIN_BACKUP"
fi


# ============================================================
# LIMPIAR LEGACY
# ============================================================

sed -i \
    -E \
    "/^[[:space:]]*AllowUsers[[:space:]]+${EMERGENCY_USER}[[:space:]]*$/d" \
    "$SSHD_CONFIG"


sed -i \
    -E \
    '/^[[:space:]]*Port[[:space:]]+[0-9]+[[:space:]]*$/d' \
    "$SSHD_CONFIG"


# ============================================================
# SELINUX - PUERTO SSH
# ============================================================

header "Configurando SELinux para TCP/$SSH_PORT"


if [ "$SELINUX_STATUS" != "Disabled" ]; then

    if semanage port -l \
        | grep '^ssh_port_t' \
        | grep -Eq \
        "(^|,|[[:space:]])${SSH_PORT}($|,|[[:space:]])"; then

        ok "TCP/$SSH_PORT ya pertenece a ssh_port_t."

    else

        if semanage port \
            -a \
            -t ssh_port_t \
            -p tcp \
            "$SSH_PORT" \
            >/dev/null 2>&1; then

            ok "TCP/$SSH_PORT agregado a ssh_port_t."

        else

            if semanage port \
                -m \
                -t ssh_port_t \
                -p tcp \
                "$SSH_PORT" \
                >/dev/null 2>&1; then

                ok "TCP/$SSH_PORT actualizado."

            else

                error "No se pudo configurar SELinux para el puerto."

                exit 1
            fi
        fi
    fi
fi


# ============================================================
# FIREWALL - ABRIR PUERTO
# ============================================================

header "Abriendo TCP/$SSH_PORT"

firewall-cmd \
    --zone="$FIREWALL_ZONE" \
    --add-port="${SSH_PORT}/tcp"


if [ $? -ne 0 ]; then

    error "No se pudo abrir TCP/$SSH_PORT."

    exit 1
fi


firewall-cmd \
    --permanent \
    --zone="$FIREWALL_ZONE" \
    --add-port="${SSH_PORT}/tcp"


if [ $? -ne 0 ]; then

    error "No se pudo persistir TCP/$SSH_PORT."

    exit 1
fi


# ============================================================
# FASE 1 - TRANSICIÓN
# ============================================================

header "Configurando transición SSH"

cat > "$SSHD_DROPIN" <<EOF
# ============================================================
# Recolección UY
# Fase de transición SSH
# ============================================================

Port 22
Port $SSH_PORT

PermitRootLogin no
PermitEmptyPasswords no

UsePAM yes

PubkeyAuthentication yes
PasswordAuthentication yes
KbdInteractiveAuthentication no

AuthenticationMethods publickey,password

AuthorizedKeysFile $AUTHORIZED_KEYS_DIR/%u

AllowGroups $EMERGENCY_GROUP $AD_GROUP
EOF


chown root:root "$SSHD_DROPIN"
chmod 600 "$SSHD_DROPIN"


# ============================================================
# VALIDAR Y RECARGAR
# ============================================================

if ! sshd -t; then

    error "La configuración SSH no es válida."

    rollback_ssh

    exit 1
fi


systemctl reload sshd


if [ $? -ne 0 ]; then

    error "No fue posible recargar sshd."

    rollback_ssh

    exit 1
fi


sleep 2


# ============================================================
# VERIFICAR NUEVO PUERTO
# ============================================================

if ! sshd_is_listening "$SSH_PORT"; then

    error "sshd no está escuchando en TCP/$SSH_PORT."

    rollback_ssh

    exit 1
fi

ok "SSH disponible en TCP/$SSH_PORT."


# ============================================================
# PRUEBA PUTTY
# ============================================================

header "PRUEBA OBLIGATORIA DESDE PUTTY"

echo
echo "NO cierre esta sesión."
echo
echo "Abra otra instancia de PuTTY:"
echo
echo "  Host:    IP del servidor"
echo "  Puerto:  $SSH_PORT"
echo "  Usuario: $EMERGENCY_USER"
echo
echo "Seleccione el .ppk correspondiente."
echo
echo
echo "Debe:"
echo "  1. aceptar la clave"
echo "  2. solicitar contraseña LOCAL"
echo "  3. iniciar sesión"
echo
echo "Después ejecute:"
echo
echo "  whoami"
echo "  sudo whoami"
echo
echo "Esperado:"
echo "  adminssh"
echo "  root"
echo


read -r -p \
    "¿Funcionaron SSH y sudo? Escriba SI: " \
    CONFIRMATION


if [ "$CONFIRMATION" != "SI" ]; then

    rollback_ssh

    exit 1
fi


# ============================================================
# FASE 2 - DEFINITIVA
# ============================================================

header "Configuración SSH definitiva"

cat > "$SSHD_DROPIN" <<EOF
# ============================================================
# Recolección UY
# Configuración SSH
# ============================================================

Port $SSH_PORT

PermitRootLogin no
PermitEmptyPasswords no

UsePAM yes

PubkeyAuthentication yes
PasswordAuthentication yes
KbdInteractiveAuthentication no

AuthenticationMethods publickey,password

AuthorizedKeysFile $AUTHORIZED_KEYS_DIR/%u

AllowGroups $EMERGENCY_GROUP $AD_GROUP
EOF


chown root:root "$SSHD_DROPIN"
chmod 600 "$SSHD_DROPIN"


if ! sshd -t; then

    error "La configuración definitiva no es válida."

    rollback_ssh

    exit 1
fi


systemctl restart sshd


if [ $? -ne 0 ]; then

    error "No fue posible reiniciar sshd."

    rollback_ssh

    exit 1
fi


sleep 2


if ! sshd_is_listening "$SSH_PORT"; then

    error "SSH dejó de escuchar en TCP/$SSH_PORT."

    rollback_ssh

    exit 1
fi


# ============================================================
# CERRAR TCP/22
# ============================================================

header "Cerrando TCP/22"

firewall-cmd \
    --zone="$FIREWALL_ZONE" \
    --remove-service=ssh \
    >/dev/null 2>&1 || true


firewall-cmd \
    --permanent \
    --zone="$FIREWALL_ZONE" \
    --remove-service=ssh \
    >/dev/null 2>&1 || true


firewall-cmd \
    --zone="$FIREWALL_ZONE" \
    --remove-port=22/tcp \
    >/dev/null 2>&1 || true


firewall-cmd \
    --permanent \
    --zone="$FIREWALL_ZONE" \
    --remove-port=22/tcp \
    >/dev/null 2>&1 || true


# ============================================================
# RESULTADO
# ============================================================

header "CONFIGURACIÓN FINALIZADA"

echo
echo "Puerto SSH:"
echo "  $SSH_PORT"

echo
echo "Usuario de emergencia:"
echo "  $EMERGENCY_USER"

echo
echo "Autenticación:"
echo "  clave pública + contraseña"

echo
echo "Sudo:"
echo "  habilitado con contraseña"

echo
echo "Root SSH:"
echo "  deshabilitado"

echo
echo "Clave:"
echo "  $ADMINSSH_KEY_FILE"

echo
echo "Sockets:"
echo

ss -lntpH \
    | grep sshd \
    || true


echo
echo "============================================================"