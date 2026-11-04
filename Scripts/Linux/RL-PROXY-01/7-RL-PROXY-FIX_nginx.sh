#!/usr/bin/env bash
# Recolección UY - Proxy Nginx
# Ejecutar en el servidor proxy con: sudo bash actualizar_forwarded_proto.sh
set -Eeuo pipefail

DIR="/opt/recoleccion-proxy/nginx/conf.d"
BACKUP="/opt/recoleccion-proxy/nginx/conf.d.backup-$(date +%Y%m%d-%H%M%S)"

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Este script requiere permisos de root (sudo)." >&2
    exit 1
fi

if [[ ! -d "$DIR" ]]; then
    echo "[ERROR] No existe el directorio: $DIR" >&2
    exit 1
fi

# Identificar archivos antes de crear el respaldo.
mapfile -d '' FILES < <(
    grep -rlZ -F 'proxy_set_header X-Forwarded-Proto $scheme;' "$DIR" \
      --include='*.conf' || true
)

if (( ${#FILES[@]} == 0 )); then
    echo "[ERROR] No se encontraron líneas para modificar."
    exit 1
fi

# Respaldo de la configuración.
cp -a "$DIR" "$BACKUP"
echo "[OK] Respaldo: $BACKUP"

# Sustituir únicamente la cabecera del protocolo.
for FILE in "${FILES[@]}"; do
    sed -i \
      's/proxy_set_header X-Forwarded-Proto \$scheme;/proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;/g' \
      "$FILE"
    echo "[OK] Actualizado: $FILE"
done

# Validar Nginx; restaurar si la sintaxis falla.
if ! docker exec recoleccion_proxy nginx -t; then
    echo "[ERROR] Configuración inválida. Restaurando respaldo." >&2
    cp -a "$BACKUP/." "$DIR/"
    exit 1
fi

# Recargar sin recrear el contenedor.
docker exec recoleccion_proxy nginx -s reload

echo "[OK] Nginx interno actualizado."