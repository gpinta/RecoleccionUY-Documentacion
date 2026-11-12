#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# RECOLECCION UY - RL-PROXY-01
# Generacion de CA interna y certificado TLS SAN
#
# DOMINIOS:
#   recoleccion.neltek.uy
#   admin-recoleccion.neltek.uy
#   camiones-recoleccion.neltek.uy
#
# FUNCIONES:
#   1. Validar servidor y dependencias.
#   2. Proteger materiales existentes.
#   3. Generar CA interna RSA 4096.
#   4. Generar clave TLS RSA 3072.
#   5. Crear CSR con SAN.
#   6. Firmar certificado TLS.
#   7. Verificar cadena, vigencia y dominios.
#   8. Publicar materiales de forma controlada.
#
# SEGURIDAD:
#   - La clave CA utiliza AES-256.
#   - La clave TLS se genera sin contrasena para
#     permitir su uso posterior por un servidor web.
#   - No se sobrescriben certificados existentes.
#   - No se muestran ni registran claves privadas.
#   - Se eliminan materiales temporales ante errores.
#
# NO MODIFICA:
#   - Docker o Docker Compose.
#   - Nginx o WAF.
#   - firewalld.
#   - SSH.
#   - Aplicaciones Laravel.
#   - Otros servidores.
#
# IMPORTANTE:
#   Este script solo genera materiales TLS.
#   NO habilita HTTPS.
# ============================================================

export LC_ALL=C

# ------------------------------------------------------------
# 1. Configuracion
# ------------------------------------------------------------

readonly SERVER="RL-PROXY-01"

readonly PROXY_DIR="/opt/recoleccion-proxy"
readonly BASE_DIR="${PROXY_DIR}/tls"

readonly CA_DIR="${BASE_DIR}/ca"
readonly CERT_DIR="${BASE_DIR}/certs"

readonly -a DOMAINS=(
    "recoleccion.neltek.uy"
    "admin-recoleccion.neltek.uy"
    "camiones-recoleccion.neltek.uy"
)

WORK_DIR=""

CA_PUBLISHED=false
CERT_PUBLISHED=false
COMPLETED=false

# ------------------------------------------------------------
# 2. Funciones generales
# ------------------------------------------------------------

show_header() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

show_info() {
    echo "[INFO] $*"
}

show_ok() {
    echo "[OK] $*"
}

show_warning() {
    echo "[ADVERTENCIA] $*" >&2
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

# ------------------------------------------------------------
# 3. Limpieza y recuperacion
# ------------------------------------------------------------

cleanup() {

    local status=$?

    trap - EXIT

    if [[ "$COMPLETED" != true ]]; then

        # Solo retirar directorios nuevos publicados
        # por esta ejecucion. Nunca tocar materiales
        # que existieran previamente.

        if [[ "$CERT_PUBLISHED" == true ]]; then
            rm -rf -- "$CERT_DIR" || true
        fi

        if [[ "$CA_PUBLISHED" == true ]]; then
            rm -rf -- "$CA_DIR" || true
        fi

        if (( status != 0 )); then
            show_warning "Generacion TLS no completada."
            show_warning "No se modificaron servicios."
        fi

    fi

    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR" || true
    fi

    exit "$status"
}

trap cleanup EXIT

# ------------------------------------------------------------
# 4. Verificar servidor
# ------------------------------------------------------------

show_header "Recoleccion UY - TLS RL-PROXY-01"

(( EUID == 0 )) ||
    die "Ejecutar como root."

[[ -r /etc/os-release ]] ||
    die "No se encuentra /etc/os-release."

# shellcheck source=/etc/os-release
source /etc/os-release

[[ "${ID:-}" == "rocky" ]] ||
    die "Se requiere Rocky Linux."

[[ "${VERSION_ID%%.*}" == "9" ]] ||
    die "Se requiere Rocky Linux 9."

HOST_ACTUAL="$(hostname -s)"
HOST_ACTUAL="${HOST_ACTUAL,,}"

[[ "$HOST_ACTUAL" == "rl-proxy-01" ]] ||
    die "Servidor incorrecto: $HOST_ACTUAL"

[[ -d "$PROXY_DIR" && ! -L "$PROXY_DIR" ]] ||
    die "Directorio del proxy inexistente o invalido."

show_ok "Servidor RL-PROXY-01 verificado."
show_ok "Rocky Linux 9 verificado."

# ------------------------------------------------------------
# 5. Verificar herramientas
# ------------------------------------------------------------

show_header "Verificando herramientas"

for CMD in \
    hostname \
    dnf \
    install \
    mktemp \
    mv \
    rm
do

    command -v "$CMD" >/dev/null 2>&1 ||
        die "Falta herramienta: $CMD"

done

if ! command -v openssl >/dev/null 2>&1; then

    show_info "Instalando OpenSSL..."

    dnf install -y openssl

fi

command -v openssl >/dev/null 2>&1 ||
    die "OpenSSL no esta disponible."

show_ok "OpenSSL disponible."

openssl version

# ------------------------------------------------------------
# 6. Proteger materiales existentes
# ------------------------------------------------------------

show_header "Verificando certificados existentes"

[[ ! -L "$BASE_DIR" ]] ||
    die "El directorio TLS es un enlace simbolico."

# Se requiere una instalacion nueva.
# No se modifica una CA existente ni un certificado
# posiblemente utilizado por otros componentes.

[[ ! -e "$CA_DIR" && ! -L "$CA_DIR" ]] ||
    die "Ya existe $CA_DIR. No se sobrescribe."

[[ ! -e "$CERT_DIR" && ! -L "$CERT_DIR" ]] ||
    die "Ya existe $CERT_DIR. No se sobrescribe."

show_ok "No existen materiales TLS anteriores."

# ------------------------------------------------------------
# 7. Preparar directorio temporal
# ------------------------------------------------------------

show_header "Preparando generacion"

install -d -m 0700 "$BASE_DIR"

WORK_DIR="$(
    mktemp -d "${BASE_DIR}/.certificados.XXXXXXXX"
)" || die "No se pudo crear directorio temporal."

chmod 700 "$WORK_DIR"

install -d -m 0700 \
    "$WORK_DIR/ca" \
    "$WORK_DIR/certs"

# ------------------------------------------------------------
# 8. Configuracion de la CA
# ------------------------------------------------------------

show_header "Configurando CA interna"

cat > "$WORK_DIR/ca/ca.cnf" <<'EOF'
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca

[dn]
C = UY
O = Recoleccion UY
CN = Recoleccion UY CA

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF

chmod 600 "$WORK_DIR/ca/ca.cnf"

show_ok "Configuracion de CA preparada."

# ------------------------------------------------------------
# 9. Configuracion SAN
# ------------------------------------------------------------

show_header "Configurando certificado TLS SAN"

cat > "$WORK_DIR/certs/san.cnf" <<'EOF'
[req]
distinguished_name = dn
prompt = no
req_extensions = req_ext

[dn]
C = UY
O = Recoleccion UY
CN = recoleccion.neltek.uy

[req_ext]
subjectAltName = @alt_names

[server_ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[alt_names]
DNS.1 = recoleccion.neltek.uy
DNS.2 = admin-recoleccion.neltek.uy
DNS.3 = camiones-recoleccion.neltek.uy
EOF

chmod 600 "$WORK_DIR/certs/san.cnf"

show_ok "Tres dominios SAN configurados."

# ------------------------------------------------------------
# 10. Generar clave privada de CA
# ------------------------------------------------------------

show_header "Generando clave privada de CA"

show_info "RSA 4096 bits."
show_info "Proteccion AES-256."
show_info "OpenSSL solicitara una contrasena para la CA."

openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:4096 \
    -aes-256-cbc \
    -out "$WORK_DIR/ca/recoleccion-ca.key" ||
    die "No se pudo generar clave privada de CA."

chmod 600 "$WORK_DIR/ca/recoleccion-ca.key"

show_ok "Clave privada CA generada."

# ------------------------------------------------------------
# 11. Generar certificado de CA
# ------------------------------------------------------------

show_header "Generando certificado CA"

show_info "Vigencia: 3650 dias."
show_info "OpenSSL solicitara la contrasena de la CA."

openssl req \
    -new \
    -x509 \
    -sha256 \
    -days 3650 \
    -key "$WORK_DIR/ca/recoleccion-ca.key" \
    -out "$WORK_DIR/ca/recoleccion-ca.crt" \
    -config "$WORK_DIR/ca/ca.cnf" \
    -extensions v3_ca ||
    die "No se pudo generar certificado CA."

chmod 644 "$WORK_DIR/ca/recoleccion-ca.crt"

show_ok "Certificado CA generado."

# ------------------------------------------------------------
# 12. Generar clave privada TLS
# ------------------------------------------------------------

show_header "Generando clave TLS del servidor"

show_info "RSA 3072 bits."

openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:3072 \
    -out "$WORK_DIR/certs/recoleccion.key" ||
    die "No se pudo generar clave TLS."

chmod 600 "$WORK_DIR/certs/recoleccion.key"

show_ok "Clave TLS generada."

# ------------------------------------------------------------
# 13. Generar CSR
# ------------------------------------------------------------

show_header "Generando solicitud de certificado"

openssl req \
    -new \
    -sha256 \
    -key "$WORK_DIR/certs/recoleccion.key" \
    -out "$WORK_DIR/certs/recoleccion.csr" \
    -config "$WORK_DIR/certs/san.cnf" ||
    die "No se pudo generar CSR."

chmod 600 "$WORK_DIR/certs/recoleccion.csr"

show_ok "CSR generado."

# ------------------------------------------------------------
# 14. Firmar certificado TLS
# ------------------------------------------------------------

show_header "Firmando certificado TLS"

show_info "Vigencia: 365 dias."
show_info "OpenSSL solicitara la contrasena de la CA."

openssl x509 \
    -req \
    -sha256 \
    -days 365 \
    -in "$WORK_DIR/certs/recoleccion.csr" \
    -CA "$WORK_DIR/ca/recoleccion-ca.crt" \
    -CAkey "$WORK_DIR/ca/recoleccion-ca.key" \
    -CAcreateserial \
    -out "$WORK_DIR/certs/recoleccion.crt" \
    -extfile "$WORK_DIR/certs/san.cnf" \
    -extensions server_ext ||
    die "No se pudo firmar certificado TLS."

chmod 644 "$WORK_DIR/certs/recoleccion.crt"

show_ok "Certificado TLS firmado."

# ------------------------------------------------------------
# 15. Verificar certificado CA
# ------------------------------------------------------------

show_header "Verificando CA interna"

openssl x509 \
    -in "$WORK_DIR/ca/recoleccion-ca.crt" \
    -noout \
    -checkend 0 >/dev/null ||
    die "Certificado CA vencido o invalido."

openssl x509 \
    -in "$WORK_DIR/ca/recoleccion-ca.crt" \
    -noout \
    -text |
    grep -Eq 'CA:TRUE' ||
    die "El certificado CA no tiene CA:TRUE."

show_ok "CA interna valida."

# ------------------------------------------------------------
# 16. Verificar vigencia TLS
# ------------------------------------------------------------

show_header "Verificando vigencia TLS"

openssl x509 \
    -in "$WORK_DIR/certs/recoleccion.crt" \
    -noout \
    -checkend 0 >/dev/null ||
    die "Certificado TLS vencido o invalido."

show_ok "Certificado TLS vigente."

# ------------------------------------------------------------
# 17. Verificar firma y uso TLS
# ------------------------------------------------------------

show_header "Verificando cadena de confianza"

openssl verify \
    -purpose sslserver \
    -CAfile "$WORK_DIR/ca/recoleccion-ca.crt" \
    "$WORK_DIR/certs/recoleccion.crt" ||
    die "No se pudo verificar certificado TLS."

show_ok "Firma y uso TLS verificados."

# ------------------------------------------------------------
# 18. Verificar los tres dominios
# ------------------------------------------------------------

show_header "Verificando dominios SAN"

for DOMAIN in "${DOMAINS[@]}"; do

    if openssl verify \
        -purpose sslserver \
        -verify_hostname "$DOMAIN" \
        -CAfile "$WORK_DIR/ca/recoleccion-ca.crt" \
        "$WORK_DIR/certs/recoleccion.crt" \
        >/dev/null; then

        show_ok "Dominio incluido y verificado: $DOMAIN"

    else

        die "El certificado no valida para $DOMAIN."

    fi

done

# ------------------------------------------------------------
# 19. Verificar correspondencia de claves
# ------------------------------------------------------------

show_header "Verificando clave y certificado"

# Comparar la clave publica derivada de la clave privada
# con la del certificado, sin mostrar material sensible.

PRIVATE_PUBLIC="$(
    openssl pkey \
        -in "$WORK_DIR/certs/recoleccion.key" \
        -pubout \
        -outform DER |
    openssl dgst -sha256
)" || die "No se pudo verificar clave privada TLS."

CERT_PUBLIC="$(
    openssl x509 \
        -in "$WORK_DIR/certs/recoleccion.crt" \
        -pubkey \
        -noout |
    openssl pkey \
        -pubin \
        -outform DER |
    openssl dgst -sha256
)" || die "No se pudo verificar certificado TLS."

[[ "$PRIVATE_PUBLIC" == "$CERT_PUBLIC" ]] ||
    die "La clave privada no corresponde al certificado."

show_ok "Clave TLS y certificado corresponden."

# ------------------------------------------------------------
# 20. Publicar materiales verificados
# ------------------------------------------------------------

show_header "Publicando certificados"

# Comprobar nuevamente para evitar sobrescribir
# instalaciones creadas durante la ejecucion.

[[ ! -e "$CA_DIR" && ! -L "$CA_DIR" ]] ||
    die "El destino CA ya existe."

[[ ! -e "$CERT_DIR" && ! -L "$CERT_DIR" ]] ||
    die "El destino TLS ya existe."

# Las carpetas temporales estan dentro del mismo
# directorio base; moverlas evita copiar parcialmente
# cada archivo al destino definitivo.

mv -T "$WORK_DIR/ca" "$CA_DIR" ||
    die "No se pudo publicar la CA."

CA_PUBLISHED=true

mv -T "$WORK_DIR/certs" "$CERT_DIR" ||
    die "No se pudo publicar certificado TLS."

CERT_PUBLISHED=true

chmod 700 "$CA_DIR" "$CERT_DIR"

chmod 600 \
    "$CA_DIR/recoleccion-ca.key" \
    "$CERT_DIR/recoleccion.key" \
    "$CERT_DIR/recoleccion.csr" \
    "$CERT_DIR/san.cnf"

chmod 644 \
    "$CA_DIR/recoleccion-ca.crt" \
    "$CERT_DIR/recoleccion.crt"

# La CA genera material auxiliar de serializacion.
# Se conserva en su propio directorio.

COMPLETED=true

# ------------------------------------------------------------
# 21. Resultado final
# ------------------------------------------------------------

show_header "CERTIFICADOS TLS GENERADOS CORRECTAMENTE"

echo
echo "Servidor:"
echo "  RL-PROXY-01"

echo
echo "Autoridad certificadora:"
echo "  $CA_DIR/recoleccion-ca.crt"

echo
echo "Clave privada CA:"
echo "  $CA_DIR/recoleccion-ca.key"

echo
echo "Certificado TLS:"
echo "  $CERT_DIR/recoleccion.crt"

echo
echo "Clave privada TLS:"
echo "  $CERT_DIR/recoleccion.key"

echo
echo "Dominios SAN:"
for DOMAIN in "${DOMAINS[@]}"; do
    echo "  $DOMAIN"
done

echo
echo "Vigencias:"
echo "  CA: 3650 dias"
echo "  TLS: 365 dias"

echo
echo "Estado:"
echo "  CA: VERIFICADA"
echo "  Firma TLS: VERIFICADA"
echo "  Clave privada TLS: VERIFICADA"
echo "  SAN: 3 DOMINIOS VERIFICADOS"

echo
echo "IMPORTANTE:"
echo "  La CA interna no es confiable automaticamente."
echo "  Debe distribuirse su certificado publico a clientes."
echo "  No distribuir la clave privada de CA."
echo "  Este script NO habilita HTTPS."
echo "  Docker, Nginx, WAF y firewalld no fueron modificados."

echo
show_ok "Generacion TLS finalizada."