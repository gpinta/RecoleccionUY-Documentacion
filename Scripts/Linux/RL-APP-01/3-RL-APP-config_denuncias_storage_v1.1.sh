#!/bin/bash

set -euo pipefail

# ============================================================
# Recolección UY
# Preparación del almacenamiento privado de fotografías
#
# Servidor:
#   RL-APP-01
#
# Directorio del host:
#   /srv/recoleccion-data/fotos
#
# Organización de fotografías:
#   /srv/recoleccion-data/fotos/{denuncia_id}/foto_denuncia
#   /srv/recoleccion-data/fotos/{denuncia_id}/foto_resolucion
#
# Montaje dentro de los contenedores:
#   API y Administración:
#     /var/www/shared-denuncias
#
#   Camiones:
#     /var/www/shared-fotos
#
# Usuario/grupo Apache dentro de los contenedores Debian:
#   UID 33
#   GID 33
#
# Este script NO:
#   - Inicia contenedores
#   - Modifica Docker Compose
#   - Elimina fotografías
#   - Elimina directorios
#   - Crea carpetas individuales de denuncias
# ============================================================


BASE_DIR="/srv/recoleccion-data/fotos"

WEB_UID="33"
WEB_GID="33"


# ============================================================
# Root
# ============================================================

if [ "$(id -u)" -ne 0 ]; then

    echo "ERROR:"
    echo "Este script debe ejecutarse con sudo."
    echo
    echo "Ejemplo:"
    echo "sudo ./3-RL-APP-config_denuncias_storage.sh"

    exit 1
fi


# ============================================================
# Inicio
# ============================================================

echo "=========================================="
echo " Recolección UY"
echo " Preparación almacenamiento de fotografías"
echo " RL-APP-01"
echo "=========================================="
echo


# ============================================================
# Crear directorios
# ============================================================

echo "=========================================="
echo "1. Creando estructura de directorios..."
echo "=========================================="

mkdir -p "$BASE_DIR"

echo
echo "[OK] Directorio disponible:"
echo "  $BASE_DIR"

# Las carpetas por ID de denuncia se crearán
# automáticamente desde Laravel.
#
# Ejemplos:
#   {denuncia_id}/foto_denuncia
#   {denuncia_id}/foto_resolucion
#
# No creamos carpetas con IDs ficticios aquí.


# ============================================================
# Propietario
# ============================================================

echo
echo "=========================================="
echo "2. Configurando propietario..."
echo "=========================================="

chown -R "${WEB_UID}:${WEB_GID}" "$BASE_DIR"

echo
echo "[OK] Propietario configurado:"
echo "  UID: $WEB_UID"
echo "  GID: $WEB_GID"


# ============================================================
# Permisos de directorios
# ============================================================

echo
echo "=========================================="
echo "3. Configurando permisos de directorios..."
echo "=========================================="

find "$BASE_DIR" \
    -type d \
    -exec chmod 755 {} \;

echo
echo "[OK] Directorios configurados con permisos 755."


# ============================================================
# Permisos de archivos
# ============================================================

echo
echo "=========================================="
echo "4. Configurando permisos de archivos..."
echo "=========================================="

find "$BASE_DIR" \
    -type f \
    -exec chmod 644 {} \;

echo
echo "[OK] Archivos configurados con permisos 644."


# ============================================================
# Verificación
# ============================================================

echo
echo "=========================================="
echo "5. Verificando configuración..."
echo "=========================================="
echo

ls -ld "$BASE_DIR"

echo
echo "Contenido actual:"
echo

find "$BASE_DIR" \
    -maxdepth 3 \
    -printf '%M %u:%g %p\n' \
    | head -n 50


# ============================================================
# Resultado
# ============================================================

echo
echo "=========================================="
echo " CONFIGURACIÓN FINALIZADA"
echo "=========================================="
echo
echo "Directorio base:"
echo "  $BASE_DIR"
echo
echo "Estructura de fotografías:"
echo "  ${BASE_DIR}/{denuncia_id}/foto_denuncia"
echo "  ${BASE_DIR}/{denuncia_id}/foto_resolucion"
echo
echo "Propietario:"
echo "  ${WEB_UID}:${WEB_GID}"
echo
echo "Permisos:"
echo "  Directorios -> 755"
echo "  Archivos     -> 644"
echo
echo "Montaje esperado en Docker:"
echo "  $BASE_DIR:/var/www/shared-denuncias:rw,z"
echo
echo "=========================================="