# Implementación Monitoreo Grafana — Recolección UY

**Fecha de revisión:** 11/11/2026  
**Componente:** Grafana 12.0.2  
**Tipo de documento:** Instructivo de instalación, configuración, acceso, verificación y mantenimiento  
**Servidor de ejecución e instalación:** **RL-MON-01 (`192.168.20.20`)**

> **Alcance:** documentación específica de Grafana y los componentes necesarios para visualizar las métricas de Recolección UY. Se mantiene el procedimiento implementado en los scripts existentes, sin incluir la configuración general de otros servicios o aplicaciones.


## Índice

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-información-general)
  - [1.2. Rol del servidor](#12-rol-del-servidor)
- [2. Ejecución de Scripts](#2-ejecución-de-scripts)
  - [2.1. Orden de ejecución](#21-orden-de-ejecución)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos](#23-scripts-específicos)
    - [2.3.1. `3-RL-MON-monitoreo.sh`](#231-3-rl-mon-monitoreosh)
    - [2.3.2. `RL-MON-add_dashboard_general.sh`](#232-rl-mon-add_dashboard_generalsh)
- [3. Arquitectura y componentes del servidor](#3-arquitectura-y-componentes-del-servidor)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
  - [5.1. Servicio Grafana](#51-servicio-grafana)
  - [5.2. Instalación de contenedores](#52-instalación-de-contenedores)
  - [5.3. Acceso a Grafana](#53-acceso-a-grafana)
  - [5.4. Datasource Prometheus](#54-datasource-prometheus)
  - [5.5. Aprovisionamiento y dashboards](#55-aprovisionamiento-y-dashboards)
  - [5.6. Cómo visualizar los servidores](#56-cómo-visualizar-los-servidores)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
- [7. Seguridad y control de acceso](#7-seguridad-y-control-de-acceso)
- [8. Monitoreo y registros](#8-monitoreo-y-registros)
  - [8.1. Verificación de disponibilidad de Grafana](#81-verificación-de-disponibilidad-de-grafana)
  - [8.2. Verificación de targets y servidores](#82-verificación-de-targets-y-servidores)
  - [8.3. Interpretación de los paneles](#83-interpretación-de-los-paneles)
- [9. Copias de seguridad y recuperación](#9-copias-de-seguridad-y-recuperación)
- [10. Administración y mantenimiento](#10-administración-y-mantenimiento)
- [11. Diagnóstico y resolución de problemas](#11-diagnóstico-y-resolución-de-problemas)
- [12. Anexos](#12-anexos)


---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor |
|---|---|
| Nombre del servidor de Grafana | **RL-MON-01** |
| Sistema operativo | Rocky Linux 9 |
| Dirección IP utilizada por Grafana | `192.168.20.20` |
| Servicio | `grafana` |
| Versión | `12.0.2` |
| URL de acceso | `http://192.168.20.20:3000` |
| Puerto publicado | `192.168.20.20:3000:3000` (TCP, HTTP) |
| Método de instalación | Script local y Docker Compose |
| Directorio de instalación | `/opt/recoleccion-uy/monitoring` |
| Proyecto Docker Compose | `recoleccion-monitoring` |

## 1.2. Rol del servidor

Grafana se instala **en RL-MON-01**, desde donde presenta dashboards con métricas de tres servidores: **RL-MON-01**, **RL-APP-01** y **RL-PROXY-01**. Las métricas se obtienen desde el datasource Prometheus; Grafana no consulta directamente cada Node Exporter.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución

**Todos los comandos de esta sección se ejecutan en una terminal del servidor `RL-MON-01` (`192.168.20.20`), no en RL-APP-01 ni en RL-PROXY-01.**

| Orden | Servidor donde se ejecuta | Script exacto | Resultado relativo a Grafana |
|---|---|---|---|
| 1 | **RL-MON-01** | `3-RL-MON-monitoreo.sh` | Instala y configura Grafana, Prometheus, Node Exporter local y el dashboard inicial |
| 2 | **RL-MON-01** | `RL-MON-add_dashboard_general.sh` | Genera y aprovisiona el dashboard general de 12 paneles para tres servidores |

La segunda ejecución depende de la primera. **No se ejecutan estos scripts en los servidores que solo son monitoreados.**

## 2.2. Procedimiento general

**Servidor: RL-MON-01.** Desde el directorio donde se encuentre el script correspondiente, el procedimiento prescrito de ejecución es normalizar finales de línea, dar permiso de ejecución y ejecutar con `sudo`:

```bash
sed -i 's/\r$//' NOMBRE_DEL_SCRIPT.sh
chmod +x NOMBRE_DEL_SCRIPT.sh
sudo ./NOMBRE_DEL_SCRIPT.sh
```

En las fichas siguientes se sustituyen los nombres por los archivos reales. La ubicación del directorio desde el que se lanzan los scripts no está fijada en su contenido; debe utilizarse la ubicación donde el administrador haya copiado los archivos del proyecto. El directorio `/opt/recoleccion-uy/monitoring` es el **destino generado por el instalador**, no necesariamente la carpeta desde donde se ejecuta el script.

## 2.3. Scripts específicos

### 2.3.1. `3-RL-MON-monitoreo.sh`

**Servidor de ejecución: RL-MON-01 (`192.168.20.20`).**

**Nombre del script:** `3-RL-MON-monitoreo.sh`.

**Descripción:** prepara la instalación de monitoreo en RL-MON-01, genera la configuración de Grafana y Prometheus, crea el proyecto Docker Compose y pone en marcha sus servicios. Incluye la instalación del dashboard Node Exporter Full ID 1860 y un dashboard básico como alternativa si no puede obtener o adaptar el primero.

**Componentes que instala o utiliza:** Docker Engine, Docker Compose, Grafana `grafana/grafana:12.0.2`, Prometheus `prom/prometheus:v3.4.2`, Node Exporter local `prom/node-exporter:v1.9.1`, Python 3, `curl` e `iproute`.

**Componentes que configura:** usuario administrativo inicial de Grafana; datasource Prometheus con UID `prometheus`; proveedor de dashboards por archivos; volúmenes persistentes; targets Prometheus de RL-MON-01, RL-APP-01 y RL-PROXY-01.

**Archivos y directorios creados o configurados:**

- `/opt/recoleccion-uy/monitoring/compose.yaml`
- `/opt/recoleccion-uy/monitoring/.grafana.env`
- `/opt/recoleccion-uy/monitoring/prometheus.yml`
- `/opt/recoleccion-uy/monitoring/grafana/provisioning/datasources/prometheus.yml`
- `/opt/recoleccion-uy/monitoring/grafana/provisioning/dashboards/dashboard.yml`
- `/opt/recoleccion-uy/monitoring/grafana/dashboards/node-exporter-full.json` (cuando se descarga y adapta)
- `/opt/recoleccion-uy/monitoring/grafana/dashboards/dashboard_basico.json` (alternativa de respaldo)

**Requisitos previos:** ejecutar como administrador en RL-MON-01, con Rocky Linux 9, IP `192.168.20.20` configurada, puertos requeridos disponibles y una consola interactiva para establecer la contraseña inicial. El script controla condiciones previas y evita sobrescribir ciertos recursos existentes; por eso **no debe volver a ejecutarse indiscriminadamente sobre una instalación ya realizada**.

**Ejecución — únicamente en RL-MON-01**, desde la carpeta que contiene el script:

```bash
sed -i 's/\r$//' 3-RL-MON-monitoreo.sh
chmod +x 3-RL-MON-monitoreo.sh
sudo ./3-RL-MON-monitoreo.sh
```

Durante la instalación se solicita la contraseña del usuario `admin`: mínimo **12 caracteres**, utilizando letras, números o `@ _ + = . , : ! -`. El script genera `.grafana.env`, con permisos `600`, y la utiliza para configurar Grafana; no se publica esa contraseña en este documento.

El propio instalador valida `docker compose config --quiet`, ejecuta `docker compose pull`, `docker compose up -d`, consulta `docker compose ps` y realiza pruebas de los endpoints HTTP.

### 2.3.2. `RL-MON-add_dashboard_general.sh`

**Servidor de ejecución: RL-MON-01 (`192.168.20.20`).**

**Nombre del script:** `RL-MON-add_dashboard_general.sh`.

**Descripción:** genera o actualiza únicamente el dashboard `Recoleccion UY - Estado general de servidores RL`, con **12 paneles**: estado, CPU, RAM y disco raíz para cada servidor.

**Componentes que instala o utiliza:** instalación existente de Grafana, datasource Prometheus `prometheus`, proveedor de dashboards por archivos y Python 3. **No instala Grafana ni modifica Docker Compose.**

**Componentes que configura:** archivo de dashboard con UID `recoleccion-uy-rl-general`. Su escritura es atómica, valida la estructura JSON y evita sobrescribir un dashboard existente que tenga otro UID.

**Archivo creado o actualizado:** `/opt/recoleccion-uy/monitoring/grafana/dashboards/recoleccion-uy-servidores-rl.json`.

**Archivos utilizados (no modificados):** `/opt/recoleccion-uy/monitoring/compose.yaml`, `grafana/provisioning/dashboards/dashboard.yml` y `grafana/provisioning/datasources/prometheus.yml` dentro del directorio base.

**Requisitos previos:** instalación de monitoreo realizada en RL-MON-01, proveedor de dashboards y datasource con UID `prometheus` disponibles, y targets `node` configurados en Prometheus.

**Ejecución — únicamente en RL-MON-01**, desde la carpeta que contiene el script:

```bash
sed -i 's/\r$//' RL-MON-add_dashboard_general.sh
chmod +x RL-MON-add_dashboard_general.sh
sudo ./RL-MON-add_dashboard_general.sh
```

Grafana revisa periódicamente el directorio aprovisionado. El script **no reinicia los contenedores**; la comprobación visual de la carga efectiva se realiza desde la interfaz web de Grafana.

---

# 3. Arquitectura y componentes del servidor

En el sistema implementado, Prometheus recolecta las métricas de los exporters y Grafana las representa en dashboards:

```text
RL-MON-01   192.168.20.20:9100 ─┐
RL-APP-01   192.168.30.20:9100 ─┼──> Prometheus ──> Grafana
RL-PROXY-01 192.168.50.20:9100 ─┘       :9090       :3000
                                     (interno)    (web)
```

- **Grafana:** interfaz y dashboards en RL-MON-01.
- **Prometheus:** datasource de Grafana, dentro del proyecto Docker Compose.
- **Node Exporter:** expone métricas del sistema operativo; el instalador lo incorpora localmente en RL-MON-01.
- **RL-APP-01 y RL-PROXY-01:** requieren Node Exporter y conectividad para mostrar valores; este instructivo no instala componentes en esos servidores.

---

# 4. Configuración de red y conectividad

| Uso | Ubicación / dirección | Protocolo |
|---|---|---|
| Interfaz web Grafana | `http://192.168.20.20:3000` | HTTP, TCP 3000 |
| Salud de Grafana | `http://192.168.20.20:3000/api/health` | HTTP |
| Prometheus en el anfitrión | `http://127.0.0.1:9090` | HTTP, solo localhost |
| Prometheus desde Grafana | `http://prometheus:9090` | HTTP, comunicación entre servicios |
| Node Exporter local | `http://192.168.20.20:9100/metrics` | HTTP |
| Node Exporter RL-APP-01 | `192.168.30.20:9100` | Target Prometheus |
| Node Exporter RL-PROXY-01 | `192.168.50.20:9100` | Target Prometheus |

Grafana se publica por HTTP; el acceso remoto está condicionado por las políticas de red existentes. El instalador no configura HTTPS.

---

# 5. Servicios y contenedores Docker

## 5.1. Servicio Grafana

**Servidor anfitrión: RL-MON-01.** El script crea `/opt/recoleccion-uy/monitoring/compose.yaml` con el proyecto `recoleccion-monitoring`.

| Campo | Valor implementado |
|---|---|
| Nombre del servicio Compose | `grafana` |
| Imagen | `grafana/grafana:12.0.2` |
| Política de reinicio | `unless-stopped` |
| Dependencia | `prometheus` |
| Archivo de variables | `.grafana.env` |
| Puerto | `192.168.20.20:3000:3000` |
| Datos | `grafana_data:/var/lib/grafana` |
| Aprovisionamiento | `./grafana/provisioning:/etc/grafana/provisioning:ro,Z` |
| Dashboards | `./grafana/dashboards:/var/lib/grafana/dashboards:ro,Z` |

No hay `container_name` declarado en Compose para Grafana. Por lo tanto, no se asigna un nombre literal de contenedor: se administra por el **servicio `grafana`** en el proyecto Compose.

## 5.2. Instalación de contenedores

**Servidor: RL-MON-01.** Son operaciones ya contenidas en `3-RL-MON-monitoreo.sh`; **no se requieren pasos manuales adicionales de instalación**:

```bash
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
```

Se ejecutan por el script desde el directorio base `/opt/recoleccion-uy/monitoring`.

## 5.3. Acceso a Grafana

**Desde un navegador en un equipo autorizado con conectividad hacia RL-MON-01:**

1. Abrir `http://192.168.20.20:3000`.
2. Iniciar sesión con el usuario `admin`.
3. Introducir la contraseña definida interactivamente durante la ejecución del instalador **en RL-MON-01**.
4. Abrir **Dashboards** para consultar los paneles disponibles.

El instalador define el usuario y la contraseña inicial. No se presupone un sistema de autenticación LDAP/AD específico para Grafana porque los scripts no lo configuran.

## 5.4. Datasource Prometheus

**Configuración automática realizada en RL-MON-01** en `/opt/recoleccion-uy/monitoring/grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

El datasource queda predeterminado y no editable desde la interfaz. El usuario no tiene que crearlo manualmente después de la instalación.

## 5.5. Aprovisionamiento y dashboards

El proveedor de dashboards se configura mediante `grafana/provisioning/dashboards/dashboard.yml`, con:

- Nombre: `Node Exporter`.
- Tipo: `file`.
- Carpeta de lectura en el contenedor: `/var/lib/grafana/dashboards`.
- Intervalo de actualización: **10 segundos**.
- `editable: true` y `disableDeletion: false`.

La instalación principal intenta incorporar **Node Exporter Full (ID 1860)**. Si no puede descargarlo o adaptarlo, genera `dashboard_basico.json` como alternativa.

La segunda ejecución incorpora **Recoleccion UY - Estado general de servidores RL**, con UID `recoleccion-uy-rl-general`. El script verifica el JSON y el total de 12 paneles. La carga del dashboard en Grafana y la recepción de métricas deben comprobarse posteriormente en la interfaz.

## 5.6. Cómo visualizar los servidores

**Desde Grafana**, ingresar en **Dashboards → Recoleccion UY - Estado general de servidores RL**.

Cada columna corresponde a un servidor:

| Columna | Servidor | Target |
|---|---|---|
| 1 | RL-MON-01 | `192.168.20.20:9100` |
| 2 | RL-APP-01 | `192.168.30.20:9100` |
| 3 | RL-PROXY-01 | `192.168.50.20:9100` |

Cada servidor tiene paneles de **Estado, CPU, RAM y Disco raíz `/`**. El rango temporal inicial es **última hora** (`now-1h` a `now`) y la actualización está configurada cada **30 segundos**. El dashboard muestra métricas de sistema operativo, **no un desglose por contenedor Docker**.

---

# 6. Estructura de directorios y almacenamiento

**Ubicación en RL-MON-01:**

```text
/opt/recoleccion-uy/monitoring/
├── compose.yaml
├── .grafana.env
├── prometheus.yml
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── prometheus.yml
    │   └── dashboards/
    │       └── dashboard.yml
    └── dashboards/
        ├── node-exporter-full.json           (si se descargó y adaptó)
        ├── dashboard_basico.json             (alternativa)
        └── recoleccion-uy-servidores-rl.json (script complementario)
```

El volumen Docker `grafana_data` se monta en `/var/lib/grafana`, y las rutas de aprovisionamiento y dashboards se montan en modo de solo lectura (`ro,Z`). Los directorios creados usan `0755`; los archivos de configuración y dashboards generados, `0644`; `.grafana.env`, `0600`.

---

# 7. Seguridad y control de acceso

- **Usuario inicial de Grafana:** `admin`.
- **Contraseña:** la establece el operador en la consola de **RL-MON-01** durante la instalación.
- **Archivo de entorno:** `/opt/recoleccion-uy/monitoring/.grafana.env`, con permisos `600`.
- **Acceso web:** HTTP en `192.168.20.20:3000`.
- **Conectividad remota:** depende de las reglas existentes de firewall.

El propio instalador advierte que Grafana se publica por HTTP y que se debe restringir su acceso o implementar HTTPS. **No se afirma que HTTPS haya sido configurado**, ni se añade un procedimiento no existente en los scripts.

---

# 8. Monitoreo y registros

## 8.1. Verificación de disponibilidad de Grafana

**Ejecutar en RL-MON-01.** El instalador comprueba el endpoint de salud de Grafana:

```bash
curl --noproxy '*' --connect-timeout 2 --max-time 4 -fsS \
  "http://192.168.20.20:3000/api/health"
```

La lógica del script reintenta hasta **15 veces**, con **2 segundos** entre intentos. Esta verificación confirma respuesta HTTP del servicio; no confirma por sí sola que todos los servidores monitoreados estén accesibles.

## 8.2. Verificación de targets y servidores

**Ejecutar en RL-MON-01.** El instalador consulta los targets Prometheus mediante:

```bash
curl --noproxy '*' -fsS --max-time 10 \
  "http://127.0.0.1:9090/api/v1/targets"
```

El instalador interpreta `activeTargets` para mostrar el estado de los targets configurados. **La instalación puede finalizar aunque uno o más targets estén DOWN**. Los tres objetivos `node` son:

| Servidor supervisado | Target | Etiqueta `servidor` |
|---|---|---|
| RL-MON-01 | `192.168.20.20:9100` | `RL-MON-01` |
| RL-APP-01 | `192.168.30.20:9100` | `RL-APP-01` |
| RL-PROXY-01 | `192.168.50.20:9100` | `RL-PROXY-01` |

Para comprobarlos desde Grafana, abrir el dashboard general y observar el panel **Estado** de cada columna. Si RL-APP-01 o RL-PROXY-01 aparecen sin datos o DOWN, comprobar Node Exporter, la conectividad TCP 9100 y las reglas de red. La instalación de los exporters remotos corresponde a `5-RL-APP-install_node_exporter.sh` y `8-RL-PROXY-install_node_exporter.sh`, respectivamente; **no se ejecutan desde este procedimiento de Grafana**.

## 8.3. Interpretación de los paneles

Los indicadores se generan con expresiones PromQL del script y seleccionan simultáneamente `job="node"`, el nombre del servidor y el `instance` correspondiente.

| Panel | Qué presenta | Criterio implementado |
|---|---|---|
| Estado | Disponibilidad del target | `up`: `1` = **UP**, `0` = **DOWN**, nulo/NaN = **SIN DATOS** (una consulta sin series puede mostrar el estado predeterminado de Grafana) |
| CPU | Uso porcentual | Cálculo sobre `node_cpu_seconds_total` en modo `idle`, ventana de 5 minutos |
| RAM | Uso porcentual | `1 - MemAvailable / MemTotal`, expresado en % |
| Disco raíz `/` | Utilización del filesystem raíz | `1 - avail / size`, en %, excluyendo `tmpfs` y `overlay` |

Los paneles de porcentaje usan umbrales visuales **verde**, **naranja desde 75** y **rojo desde 90**. El indicador Estado utiliza mapeos de UP/DOWN/SIN DATOS para los valores correspondientes. Un target DOWN indica fallo de obtención de métricas y **no demuestra por sí solo que el servidor esté apagado**.

---

# 9. Copias de seguridad y recuperación

Los datos y configuraciones que forman parte de la instalación identificada son:

- Volumen persistente `grafana_data`.
- Archivos de aprovisionamiento en `grafana/provisioning/`.
- Archivos JSON de `grafana/dashboards/`.
- Configuración `compose.yaml` y archivo protegido `.grafana.env`.

**Los scripts revisados no implementan un procedimiento de backup, destino, frecuencia, retención ni restauración de Grafana.** En consecuencia, no se incluyen comandos inventados ni se afirma que exista una copia automatizada.

---

# 10. Administración y mantenimiento

**Ejecutar en RL-MON-01**, dentro del directorio de la instalación, `/opt/recoleccion-uy/monitoring`:

```bash
cd /opt/recoleccion-uy/monitoring
docker compose ps
docker compose logs
docker compose restart
```

Estos son los comandos de administración mostrados por el instalador. `docker compose restart` **reinicia los servicios del proyecto**, por lo que debe utilizarse únicamente cuando corresponda una intervención operativa.

El script de dashboard general no requiere reinicio: Grafana detecta los archivos aprovisionados en el directorio que revisa periódicamente.

---

# 11. Diagnóstico y resolución de problemas

| Síntoma | Verificación respaldada | Dónde |
|---|---|---|
| La interfaz Grafana no responde | Endpoint `http://192.168.20.20:3000/api/health` | **RL-MON-01** |
| Grafana no aparece en ejecución | `docker compose ps` | **RL-MON-01**, directorio base |
| Fallo de arranque o aprovisionamiento | `docker compose logs` | **RL-MON-01**, directorio base |
| Dashboard general no figura en la interfaz | Comprobar generación del JSON y su UID; revisar **Dashboards** | **RL-MON-01** y navegador autorizado |
| Panel Estado = DOWN | Consultar estado del target en API de Prometheus y revisar Node Exporter/conectividad | **RL-MON-01**; el target afectado puede ser remoto |
| Panel Estado = SIN DATOS | Comprobar que exista el target y que Prometheus esté proporcionando la serie esperada | **RL-MON-01** |
| CPU/RAM/Disco sin valores | Verificar que el target exporta las métricas necesarias y que el dashboard corresponde al servidor | Grafana / Prometheus existentes |

El segundo script **solo confirma que el JSON se generó correctamente**. No sustituye la inspección del dashboard en Grafana. El primer script advierte que RL-APP-01 y RL-PROXY-01 requieren Node Exporter accesible para obtener valores.

---

# 12. Anexos

Sección reservada para incorporar información complementaria de Grafana que se documente y verifique posteriormente.