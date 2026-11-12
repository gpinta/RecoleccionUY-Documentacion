#!/bin/bash

# ============================================================
# Recolección UY
# Administración de claves SSH para usuarios Active Directory
#
# Funciones:
#   - Solicita usuario AD
#   - Verifica resolución mediante SSSD
#   - Verifica pertenencia a:
#       gg_rec_server_admins_linux
#   - Verifica autorización PAM/SSSD
#   - Solicita clave pública Ed25519
#   - Valida clave
#   - Registra clave en:
#       /etc/ssh/authorized_keys/<usuario>
#   - Configura permisos
#   - Configura contexto SELinux
#   - Permite múltiples claves
#   - Evita duplicados
#
# Este script NO:
#   - Crea usuarios Linux
#   - Modifica AD
#   - Modifica sshd
#   - Modifica firewall
#   - Modifica sudo
# ============================================================


# ============================================================
# CONFIGURACIÓN
# ============================================================

AD_DOMAIN="neltek.uy"

AD_GROUP="gg_rec_server_admins_linux"

AUTHORIZED_KEYS_DIR="/etc/ssh/authorized_keys"


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
# VALIDAR CLAVE
# ============================================================

validate_public_key() {

    local KEY="$1"
    local TMP_KEY

    TMP_KEY="$(mktemp)"

    printf '%s\n' "$KEY" > "$TMP_KEY"

    chmod 600 "$TMP_KEY"


    if ! ssh-keygen \
        -l \
        -f "$TMP_KEY" \
        >/dev/null 2>&1; then

        rm -f "$TMP_KEY"

        return 1
    fi


    rm -f "$TMP_KEY"

    return 0
}


# ============================================================
# ROOT
# ============================================================

if [ "$EUID" -ne 0 ]; then

    error "Este script debe ejecutarse con privilegios root."

    echo
    echo "Utilice:"
    echo
    echo "  sudo ./config_ssh_users.sh"
    echo

    exit 1
fi


# ============================================================
# DEPENDENCIAS
# ============================================================

REQUIRED_COMMANDS=(
    ssh-keygen
    semanage
    restorecon
    realm
    ss
)

for COMMAND in "${REQUIRED_COMMANDS[@]}"; do

    if ! command -v "$COMMAND" >/dev/null 2>&1; then

        error "Falta la dependencia: $COMMAND"

        exit 1
    fi
done


# ============================================================
# VERIFICAR SSSD
# ============================================================

header "Verificando Active Directory"

if ! systemctl is-active --quiet sssd; then

    error "SSSD no está activo."

    exit 1
fi


if ! realm list 2>/dev/null \
    | grep -qiE \
    "^[[:space:]]*domain-name:[[:space:]]*$AD_DOMAIN[[:space:]]*$"; then

    error "El servidor no está unido a $AD_DOMAIN."

    exit 1
fi

ok "SSSD y dominio disponibles."


# ============================================================
# SOLICITAR USUARIO
# ============================================================

header "Usuario Active Directory"

read -r -p \
    "Usuario AD: " \
    AD_USER


if [ -z "$AD_USER" ]; then

    error "Debe indicar un usuario."

    exit 1
fi


AD_USER="${AD_USER%@${AD_DOMAIN}}"


# ============================================================
# VERIFICAR USUARIO
# ============================================================

if ! id "$AD_USER" >/dev/null 2>&1; then

    error "SSSD no puede resolver a $AD_USER."

    exit 1
fi

ok "Usuario resuelto: $AD_USER"


echo
echo "Información:"
echo

id "$AD_USER"


# ============================================================
# EVITAR USUARIOS LOCALES
# ============================================================

if grep -q "^${AD_USER}:" /etc/passwd; then

    error "$AD_USER es un usuario local."

    echo
    echo "Este script administra únicamente usuarios AD."
    echo

    exit 1
fi


# ============================================================
# VERIFICAR GRUPO
# ============================================================

header "Verificando grupo autorizado"

USER_GROUPS="$(
    id -Gn "$AD_USER" 2>/dev/null
)"


if ! echo "$USER_GROUPS" \
    | tr ' ' '\n' \
    | grep -Fxiq "$AD_GROUP"; then

    error "$AD_USER no pertenece a $AD_GROUP."

    echo
    echo "No se instalará ninguna clave."
    echo

    exit 1
fi

ok "$AD_USER pertenece a $AD_GROUP."


# ============================================================
# VERIFICAR PAM / SSSD
# ============================================================

if command -v sssctl >/dev/null 2>&1; then

    if ! sssctl user-checks \
        -a acct \
        -s sshd \
        "$AD_USER" \
        >/dev/null 2>&1; then

        error \
            "PAM/SSSD no autoriza a $AD_USER para sshd."

        exit 1
    fi

    ok "PAM/SSSD autoriza al usuario."
fi


# ============================================================
# SOLICITAR CLAVE
# ============================================================

header "Clave pública SSH"

echo
echo "Desde PuTTYgen copie:"
echo
echo "  Public key for pasting into OpenSSH authorized_keys file"
echo
echo "Debe comenzar con:"
echo
echo "  ssh-ed25519 AAAA..."
echo


read -r -p \
    "Clave pública: " \
    PUBLIC_KEY


if [ -z "$PUBLIC_KEY" ]; then

    error "No se proporcionó una clave."

    exit 1
fi


if [[ "$PUBLIC_KEY" != ssh-ed25519\ * ]]; then

    error "La clave debe ser Ed25519."

    exit 1
fi


if ! validate_public_key "$PUBLIC_KEY"; then

    error "La clave pública no es válida."

    exit 1
fi


# ============================================================
# CREAR DIRECTORIO
# ============================================================

mkdir -p "$AUTHORIZED_KEYS_DIR"

chown root:root "$AUTHORIZED_KEYS_DIR"

chmod 755 "$AUTHORIZED_KEYS_DIR"


# ============================================================
# CONFIGURAR SELINUX
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

        ok "Regla SELinux creada."

    else

        if ! semanage fcontext \
            -m \
            -t ssh_home_t \
            "$SELINUX_KEY_PATTERN" \
            >/dev/null 2>&1; then

            error "No se pudo configurar SELinux."

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
# ARCHIVO DEL USUARIO
# ============================================================

KEY_FILE="$AUTHORIZED_KEYS_DIR/$AD_USER"


touch "$KEY_FILE"

chown root:root "$KEY_FILE"

chmod 644 "$KEY_FILE"


if [ "$SELINUX_STATUS" != "Disabled" ]; then

    restorecon \
        -v \
        "$KEY_FILE"
fi


# ============================================================
# EVITAR DUPLICADOS
# ============================================================

if grep -Fxq "$PUBLIC_KEY" "$KEY_FILE"; then

    warning "La clave ya estaba registrada."

else

    printf '%s\n' \
        "$PUBLIC_KEY" \
        >> "$KEY_FILE"

    ok "Clave agregada."
fi


# ============================================================
# VALIDAR ARCHIVO
# ============================================================

if ! ssh-keygen \
    -l \
    -f "$KEY_FILE"; then

    error "El archivo de claves presenta problemas."

    exit 1
fi


# ============================================================
# RESULTADO
# ============================================================

header "USUARIO SSH CONFIGURADO"

echo
echo "Usuario:"
echo "  $AD_USER"

echo
echo "Grupo:"
echo "  $AD_GROUP"

echo
echo "Clave:"
echo "  $KEY_FILE"

echo
echo "Permisos:"
ls -l "$KEY_FILE"


if [ "$SELINUX_STATUS" != "Disabled" ]; then

    echo
    echo "Contexto SELinux:"
    ls -Z "$KEY_FILE"
fi


echo
echo "Ingreso SSH:"
echo
echo "  clave privada correspondiente"
echo "  +"
echo "  contraseña Active Directory"

echo
echo "Privilegios:"
echo
echo "  sudo <comando>"

echo
echo "El usuario deberá introducir"
echo "su contraseña del dominio al utilizar sudo."

echo
echo "============================================================"