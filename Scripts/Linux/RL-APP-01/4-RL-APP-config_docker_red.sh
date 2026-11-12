#!/bin/bash

set -euo pipefail

# ============================================================
# Recolección UY
# Configuración de red Docker para RL-APP-01
#
# Nueva arquitectura:
#
# RL-APP-01:
#   - recoleccion_api
#   - recoleccion_admin
#   - recoleccion_db
#
# RL-PROXY-01:
#   - recoleccion_proxy
#   - recoleccion_dns
#
# IMPORTANTE:
# La red recoleccion-proxy-net ya NO es necesaria porque
# Nginx ahora se encuentra en otra VM.
#
# API y Admin se comunican con MySQL mediante:
#   recoleccion-db-net
# ============================================================


DB_NETWORK="recoleccion-db-net"


echo "=================================================="
echo " Recolección UY - Configuración de red Docker"
echo " RL-APP-01"
echo "=================================================="
echo


# ============================================================
# Verificar root
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecutar con sudo."
    exit 1
fi


# ============================================================
# Verificar Docker
# ============================================================

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker no está instalado."
    exit 1
fi


if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker no está funcionando."
    exit 1
fi


# ============================================================
# Crear red si no existe
# ============================================================

crear_red() {

    local NETWORK_NAME="$1"

    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then

        echo "[OK] La red ya existe:"
        echo "     $NETWORK_NAME"

    else

        echo "[CREANDO] $NETWORK_NAME"

        docker network create "$NETWORK_NAME" >/dev/null

        echo "[OK] Red creada:"
        echo "     $NETWORK_NAME"

    fi
}


# ============================================================
# Configurar red
# ============================================================

echo "Verificando red Docker..."
echo

crear_red "$DB_NETWORK"


# ============================================================
# Mostrar red disponible
# ============================================================

echo
echo "Red Docker disponible:"
echo

docker network ls \
    --filter "name=${DB_NETWORK}"


# ============================================================
# Mostrar información de la red
# ============================================================

echo
echo "Información:"
echo

docker network inspect "$DB_NETWORK" \
    --format '
Nombre: {{.Name}}
Driver: {{.Driver}}
Scope:  {{.Scope}}
Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}
'


# ============================================================
# Resultado
# ============================================================

echo
echo "=================================================="
echo " Configuración finalizada"
echo "=================================================="
echo

echo "Red Base de Datos:"
echo
echo "  $DB_NETWORK"
echo

echo "Deben conectarse:"
echo
echo "  - recoleccion_api"
echo "  - recoleccion_admin"
echo "  - recoleccion_db"
echo

echo "IMPORTANTE:"
echo
echo "La red recoleccion-proxy-net ya no se utiliza."
echo
echo "RL-PROXY-01 se comunica con RL-APP-01 mediante:"
echo
echo "  API:"
echo "    192.168.30.20:8080"
echo
echo "  Admin:"
echo "    192.168.30.20:8081"
echo

echo "MySQL permanece aislado dentro de:"
echo
echo "  $DB_NETWORK"
echo

echo "MySQL NO debe publicar el puerto 3306 hacia el host."
echo