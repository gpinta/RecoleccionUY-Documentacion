#!/usr/bin/env bash

set -Eeuo pipefail
umask 022

# ============================================================
# RECOLECCION UY - RL-MON-01
# Dashboard general de servidores RL
#
# OBJETIVO:
#   Crear o actualizar un dashboard de Grafana para:
#
#   - RL-MON-01   192.168.20.20
#   - RL-APP-01   192.168.30.20
#   - RL-PROXY-01 192.168.50.20
#
# METRICAS:
#   - Estado UP / DOWN
#   - Uso de CPU
#   - Uso de RAM
#   - Uso del disco raiz
#
# TOTAL:
#   12 paneles distribuidos en 3 columnas.
#
# REQUISITOS:
#   - Monitoreo ya instalado en RL-MON-01.
#   - Grafana con provisioning de dashboards.
#   - Datasource Prometheus con UID prometheus.
#   - Targets node definidos en Prometheus.
#
# SEGURIDAD:
#   - No instala paquetes.
#   - No modifica Docker Compose.
#   - No reinicia servicios.
#   - No modifica firewalld.
#   - No modifica SSH.
#   - No modifica RL-FW-01.
#   - No modifica otros servidores.
#   - No altera dashboards diferentes al indicado.
#   - No elimina contenedores ni volumenes.
#
# FUNCIONAMIENTO:
#   El dashboard se guarda mediante escritura atomica.
#   Grafana lo detecta automaticamente mediante
#   provisioning, sin necesidad de reiniciar.
#
# REEJECUCION:
#   Actualiza solamente el dashboard propio.
# ============================================================

export LC_ALL=C

# ============================================================
# 1. CONFIGURACION GENERAL
# ============================================================

readonly SERVER="RL-MON-01"
readonly MON_IP="192.168.20.20"

readonly BASE="/opt/recoleccion-uy/monitoring"

readonly DASH_DIR="$BASE/grafana/dashboards"

readonly PROVIDER="$BASE/grafana/provisioning/dashboards/dashboard.yml"

readonly DATASOURCE="$BASE/grafana/provisioning/datasources/prometheus.yml"

readonly COMPOSE_FILE="$BASE/compose.yaml"

readonly DEST="$DASH_DIR/recoleccion-uy-servidores-rl.json"

readonly DASHBOARD_UID="recoleccion-uy-rl-general"

# ============================================================
# 2. FUNCIONES GENERALES
# ============================================================

show_header() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

show_ok() {
    echo "[OK] $1"
}

show_info() {
    echo "[INFO] $1"
}

show_warning() {
    echo "[ADVERTENCIA] $1" >&2
}

show_error() {
    echo "[ERROR] $1" >&2
}

die() {
    show_error "$1"
    exit 1
}

# ============================================================
# 3. MANEJO DE ERRORES
# ============================================================

error_handler() {

    local status=$?
    local line="$1"

    trap - ERR

    show_header "ERROR DURANTE LA EJECUCION"

    show_error "Linea: $line"
    show_error "Codigo: $status"
    show_error "No se pudo completar la configuracion."

    exit "$status"
}

trap 'error_handler "$LINENO"' ERR

# ============================================================
# 4. VERIFICAR PERMISOS Y SERVIDOR
# ============================================================

show_header "Recoleccion UY - Dashboard general RL"

[[ "$EUID" -eq 0 ]] ||
    die "Ejecutar como root en RL-MON-01."

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

[[ "$HOST_ACTUAL" == "rl-mon-01" ]] ||
    die "Servidor incorrecto: $HOST_ACTUAL"

show_ok "Servidor RL-MON-01 verificado."
show_ok "Rocky Linux 9 verificado."

# ============================================================
# 5. VERIFICAR HERRAMIENTAS
# ============================================================

show_header "Verificando herramientas"

for CMD in python3 grep hostname; do

    command -v "$CMD" >/dev/null 2>&1 ||
        die "Falta herramienta: $CMD"

    show_ok "$CMD disponible."

done

# ============================================================
# 6. VERIFICAR INSTALACION DE MONITOREO
# ============================================================

show_header "Verificando instalacion de monitoreo"

[[ -f "$COMPOSE_FILE" ]] ||
    die "No se encontro $COMPOSE_FILE"

[[ -f "$PROVIDER" ]] ||
    die "No se encontro $PROVIDER"

[[ -f "$DATASOURCE" ]] ||
    die "No se encontro $DATASOURCE"

[[ -d "$DASH_DIR" ]] ||
    die "No se encontro $DASH_DIR"

show_ok "Docker Compose de monitoreo encontrado."
show_ok "Provisioning de dashboards encontrado."
show_ok "Datasource de Prometheus encontrado."
show_ok "Directorio de dashboards disponible."

# ============================================================
# 7. VERIFICAR PROVISIONING
# ============================================================

show_header "Verificando provisioning de Grafana"

if ! grep -Eq \
    '^[[:space:]]*path:[[:space:]]*/var/lib/grafana/dashboards[[:space:]]*$' \
    "$PROVIDER"; then

    die "El provider no utiliza el directorio esperado."

fi

if ! grep -Eq \
    '^[[:space:]]*uid:[[:space:]]*prometheus[[:space:]]*$' \
    "$DATASOURCE"; then

    die "No se encontro datasource UID prometheus."

fi

show_ok "Directorio de provisioning verificado."
show_ok "Datasource UID prometheus verificado."

# ============================================================
# 8. VERIFICAR ARCHIVO DE DESTINO
# ============================================================

show_header "Verificando dashboard de destino"

[[ ! -L "$DEST" ]] ||
    die "No se permite un enlace simbolico como destino."

[[ ! -d "$DEST" ]] ||
    die "El destino es un directorio."

if [[ -e "$DEST" ]]; then

    [[ -f "$DEST" ]] ||
        die "El destino no es un archivo regular."

    # Evitar sobrescribir un dashboard ajeno
    # aunque tenga el mismo nombre de archivo.

    python3 - "$DEST" "$DASHBOARD_UID" <<'PY'
import json
import sys

path = sys.argv[1]
expected_uid = sys.argv[2]

with open(path, encoding="utf-8") as f:
    dashboard = json.load(f)

if not isinstance(dashboard, dict):
    raise SystemExit("El dashboard existente no es valido.")

if dashboard.get("uid") != expected_uid:
    raise SystemExit(
        "El dashboard existente tiene otro UID. "
        "No se sobrescribe."
    )
PY

    show_info "El dashboard ya existe y sera actualizado."

else

    show_info "Se creara un dashboard nuevo."

fi

# ============================================================
# 9. MOSTRAR CONFIGURACION
# ============================================================

show_header "Configuracion del dashboard"

show_info "Servidor Grafana: RL-MON-01"
show_info "Datasource: prometheus"
show_info "UID dashboard: $DASHBOARD_UID"

echo
show_info "Servidores incluidos:"
show_info "  RL-MON-01   192.168.20.20:9100"
show_info "  RL-APP-01   192.168.30.20:9100"
show_info "  RL-PROXY-01 192.168.50.20:9100"

echo
show_info "Metricas:"
show_info "  Estado"
show_info "  CPU"
show_info "  RAM"
show_info "  Disco raiz"

# ============================================================
# 10. GENERAR DASHBOARD
# ============================================================

show_header "Generando dashboard Grafana"

export DEST
export DASHBOARD_UID

python3 - <<'PY'
import json
import os
import tempfile
from pathlib import Path

# ------------------------------------------------------------
# Configuracion
# ------------------------------------------------------------

destination = Path(os.environ["DEST"])
dashboard_uid = os.environ["DASHBOARD_UID"]

nodes = [
    ("RL-MON-01", "192.168.20.20:9100"),
    ("RL-APP-01", "192.168.30.20:9100"),
    ("RL-PROXY-01", "192.168.50.20:9100"),
]

datasource = {
    "type": "prometheus",
    "uid": "prometheus",
}

panels = []
panel_id = 1

# ------------------------------------------------------------
# Funcion generadora de paneles
# ------------------------------------------------------------

def panel(
    title,
    expression,
    x,
    y,
    unit="percent",
    minimum=None,
    maximum=None,
    mappings=None,
):
    global panel_id

    defaults = {
        "unit": unit,
        "color": {
            "mode": "thresholds",
        },
        "thresholds": {
            "mode": "absolute",
            "steps": [
                {
                    "color": "green",
                    "value": None,
                },
                {
                    "color": "orange",
                    "value": 75,
                },
                {
                    "color": "red",
                    "value": 90,
                },
            ],
        },
    }

    if minimum is not None:
        defaults["min"] = minimum

    if maximum is not None:
        defaults["max"] = maximum

    if mappings is not None:
        defaults["mappings"] = mappings
        defaults["thresholds"] = {
            "mode": "absolute",
            "steps": [
                {
                    "color": "red",
                    "value": None,
                },
                {
                    "color": "green",
                    "value": 1,
                },
            ],
        }

    result = {
        "id": panel_id,
        "title": title,
        "type": "stat",
        "datasource": datasource,
        "gridPos": {
            "h": 5,
            "w": 8,
            "x": x,
            "y": y,
        },
        "fieldConfig": {
            "defaults": defaults,
            "overrides": [],
        },
        "options": {
            "reduceOptions": {
                "calcs": ["lastNotNull"],
                "fields": "",
                "values": False,
            },
            "orientation": "auto",
            "textMode": "auto",
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
        },
        "targets": [
            {
                "refId": "A",
                "expr": expression,
                "instant": True,
            },
        ],
    }

    panel_id += 1
    panels.append(result)

# ------------------------------------------------------------
# Paneles por servidor
# ------------------------------------------------------------

for index, (name, instance) in enumerate(nodes):

    x = index * 8

    selector = (
        f'job="node",'
        f'servidor="{name}",'
        f'instance="{instance}"'
    )

    # --------------------------------------------------------
    # Estado del servidor
    # --------------------------------------------------------

    panel(
        name + " · Estado",
        f'up{{{selector}}}',
        x,
        0,
        unit="none",
        minimum=0,
        maximum=1,
        mappings=[
            {
                "type": "value",
                "options": {
                    "0": {
                        "text": "DOWN",
                        "color": "red",
                    },
                    "1": {
                        "text": "UP",
                        "color": "green",
                    },
                },
            },
            {
                "type": "special",
                "options": {
                    "match": "null+nan",
                    "result": {
                        "text": "SIN DATOS",
                        "color": "red",
                    },
                },
            },
        ],
    )

    # --------------------------------------------------------
    # Uso de CPU
    # --------------------------------------------------------

    cpu_expr = (
        "100 * (1 - avg("
        "rate(node_cpu_seconds_total"
        f'{{{selector},mode="idle"}}[5m])'
        "))"
    )

    panel(
        name + " · CPU",
        cpu_expr,
        x,
        5,
        unit="percent",
        minimum=0,
        maximum=100,
    )

    # --------------------------------------------------------
    # Uso de RAM
    # --------------------------------------------------------

    ram_expr = (
        "100 * (1 - "
        f"node_memory_MemAvailable_bytes{{{selector}}}"
        " / "
        f"node_memory_MemTotal_bytes{{{selector}}}"
        ")"
    )

    panel(
        name + " · RAM",
        ram_expr,
        x,
        10,
        unit="percent",
        minimum=0,
        maximum=100,
    )

    # --------------------------------------------------------
    # Uso del disco raiz
    # --------------------------------------------------------

    filesystem_selector = (
        selector +
        ',mountpoint="/",'
        'fstype!~"tmpfs|overlay"'
    )

    disk_expr = (
        "100 * (1 - "
        "node_filesystem_avail_bytes"
        f"{{{filesystem_selector}}}"
        " / "
        "node_filesystem_size_bytes"
        f"{{{filesystem_selector}}}"
        ")"
    )

    panel(
        name + " · Disco raiz /",
        disk_expr,
        x,
        15,
        unit="percent",
        minimum=0,
        maximum=100,
    )

# ------------------------------------------------------------
# Documento del dashboard
# ------------------------------------------------------------

dashboard = {
    "uid": dashboard_uid,
    "title": "Recoleccion UY - Estado general de servidores RL",
    "description": (
        "Metricas del sistema operativo de RL-MON-01, "
        "RL-APP-01 y RL-PROXY-01 mediante Node Exporter. "
        "No desglosa contenedores Docker."
    ),
    "tags": [
        "recoleccion-uy",
        "infraestructura",
        "rl",
        "node-exporter",
    ],
    "timezone": "browser",
    "schemaVersion": 39,
    "version": 1,
    "refresh": "30s",
    "time": {
        "from": "now-1h",
        "to": "now",
    },
    "panels": panels,
    "templating": {
        "list": [],
    },
    "editable": True,
}

# ------------------------------------------------------------
# Verificar estructura antes de escribir
# ------------------------------------------------------------

if len(panels) != 12:
    raise SystemExit(
        f"Cantidad inesperada de paneles: {len(panels)}"
    )

panel_ids = [item["id"] for item in panels]

if len(panel_ids) != len(set(panel_ids)):
    raise SystemExit(
        "Se detectaron identificadores de panel duplicados."
    )

if dashboard["uid"] != dashboard_uid:
    raise SystemExit("UID de dashboard incorrecto.")

# ------------------------------------------------------------
# Escritura atomica
# ------------------------------------------------------------

fd, temporary_path = tempfile.mkstemp(
    prefix=".recoleccion-dashboard-",
    suffix=".tmp",
    dir=destination.parent,
)

try:
    with os.fdopen(fd, "w", encoding="utf-8") as file:
        json.dump(
            dashboard,
            file,
            ensure_ascii=False,
            indent=2,
        )
        file.write("\n")
        file.flush()
        os.fsync(file.fileno())

    os.chmod(temporary_path, 0o644)

    # Comprobar que el archivo generado es JSON valido.
    with open(temporary_path, encoding="utf-8") as file:
        validated = json.load(file)

    if validated.get("uid") != dashboard_uid:
        raise ValueError("UID no coincide.")

    if len(validated.get("panels", [])) != 12:
        raise ValueError("Cantidad de paneles incorrecta.")

    os.replace(temporary_path, destination)

finally:
    if os.path.exists(temporary_path):
        os.unlink(temporary_path)

print(f"[OK] Dashboard generado: {destination}")
print(f"[OK] UID: {dashboard_uid}")
print(f"[OK] Servidores: {len(nodes)}")
print(f"[OK] Paneles: {len(panels)}")
print("[OK] JSON validado y publicado.")

PY

# ============================================================
# 11. VERIFICAR ARCHIVO GENERADO
# ============================================================

show_header "Verificando dashboard instalado"

[[ -f "$DEST" ]] ||
    die "No se genero el archivo de dashboard."

[[ ! -L "$DEST" ]] ||
    die "El archivo generado no debe ser simbolico."

python3 - "$DEST" "$DASHBOARD_UID" <<'PY'
import json
import sys

path = sys.argv[1]
expected_uid = sys.argv[2]

with open(path, encoding="utf-8") as file:
    dashboard = json.load(file)

assert dashboard["uid"] == expected_uid, "UID incorrecto"
assert len(dashboard["panels"]) == 12, "Se esperan 12 paneles"

expected_titles = (
    "RL-MON-01",
    "RL-APP-01",
    "RL-PROXY-01",
)

for server in expected_titles:
    count = sum(
        server in item["title"]
        for item in dashboard["panels"]
    )
    assert count == 4, f"Paneles incompletos: {server}"

print("[OK] Dashboard JSON valido.")
print("[OK] Tres servidores configurados.")
print("[OK] Cuatro paneles por servidor.")
PY

# ============================================================
# 12. RESULTADO FINAL
# ============================================================

show_header "CONFIGURACION FINALIZADA"

echo
echo "Servidor:"
echo "  RL-MON-01"
echo "  $MON_IP"

echo
echo "Dashboard:"
echo "  Recoleccion UY - Estado general de servidores RL"

echo
echo "UID:"
echo "  $DASHBOARD_UID"

echo
echo "Archivo:"
echo "  $DEST"

echo
echo "Datasource:"
echo "  Prometheus"
echo "  UID: prometheus"

echo
echo "Servidores monitoreados:"
echo "  RL-MON-01"
echo "  RL-APP-01"
echo "  RL-PROXY-01"

echo
echo "Paneles:"
echo "  Estado"
echo "  CPU"
echo "  RAM"
echo "  Disco raiz"

echo
echo "Total:"
echo "  12 paneles"

echo
echo "Acceso:"
echo "  http://${MON_IP}:3000"

echo
echo "Ubicacion en Grafana:"
echo "  Dashboards"
echo "    Recoleccion UY - Estado general de servidores RL"

echo
echo "Provisioning:"
echo "  Grafana revisa periodicamente el directorio."
echo "  No es necesario reiniciar los contenedores."

echo
echo "Seguridad:"
echo "  No se modifico Docker Compose."
echo "  No se modificaron otros dashboards."
echo "  No se modifico firewalld."
echo "  No se modifico SSH."
echo "  No se modifico RL-FW-01."
echo "  No se reiniciaron servicios."

echo
echo "IMPORTANTE:"
echo "  El archivo JSON fue generado y validado."
echo "  La carga efectiva debe comprobarse en Grafana."
echo "  Los valores dependen de los targets Prometheus."
echo "  Un target DOWN o SIN DATOS requiere revisar"
echo "  Node Exporter y conectividad correspondiente."

echo
show_ok "Dashboard general instalado correctamente."
echo