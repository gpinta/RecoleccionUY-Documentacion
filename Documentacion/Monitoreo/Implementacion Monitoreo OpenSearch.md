# Implementación Monitoreo OpenSearch — Recolección UY

**Fecha de revisión:** 11/11/2026  
**Componente:** OpenSearch 2.12.0 y OpenSearch Dashboards 2.12.0  
**Tipo de documento:** Instructivo de instalación, configuración, acceso, verificación y mantenimiento  
**Servidor de instalación:** **RL-MON-01 (`192.168.20.20`)**  
**Servidores remitentes de logs:** **RL-MON-01**, **RL-APP-01 (`192.168.30.20`)** y **RL-PROXY-01 (`192.168.50.20`)**

> **Alcance:** documentación específica de OpenSearch, OpenSearch Dashboards y los agentes Fluent Bit necesarios para enviar y consultar los registros Docker de Recolección UY. Los procedimientos corresponden a los scripts existentes. No se documenta nuevamente la configuración general de los servidores.


## Índice

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-información-general)
  - [1.2. Rol de OpenSearch](#12-rol-de-opensearch)
- [2. Ejecución de Scripts](#2-ejecución-de-scripts)
  - [2.1. Orden de ejecución y servidor correspondiente](#21-orden-de-ejecución-y-servidor-correspondiente)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos](#23-scripts-específicos)
    - [2.3.1. `4-RL-MON-OpenSearch.sh`](#231-4-rl-mon-opensearchsh)
    - [2.3.2. `6-RL-APP-install_fluent_bit.sh`](#232-6-rl-app-install_fluent_bitsh)
    - [2.3.3. `9-RL-PROXY-install_fluent_bit.sh`](#233-9-rl-proxy-install_fluent_bitsh)
  - [2.4. Prefijos de índices antes de ejecutar los scripts](#24-prefijos-de-índices-antes-de-ejecutar-los-scripts)
- [3. Arquitectura y componentes](#3-arquitectura-y-componentes)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
  - [5.1. Servicios de OpenSearch](#51-servicios-de-opensearch)
  - [5.2. Acceso a OpenSearch Dashboards](#52-acceso-a-opensearch-dashboards)
  - [5.3. Recolección mediante Fluent Bit](#53-recolección-mediante-fluent-bit)
  - [5.4. Identificación del nombre del contenedor mediante Lua](#54-identificación-del-nombre-del-contenedor-mediante-lua)
  - [5.5. Índices de logs y prefijos por servidor](#55-índices-de-logs-y-prefijos-por-servidor)
  - [5.6. Cómo verificar registros de los servidores](#56-cómo-verificar-registros-de-los-servidores)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
- [7. Seguridad y control de acceso](#7-seguridad-y-control-de-acceso)
- [8. Monitoreo y registros](#8-monitoreo-y-registros)
  - [8.1. Verificación de disponibilidad de OpenSearch](#81-verificación-de-disponibilidad-de-opensearch)
  - [8.2. Verificación de Dashboards](#82-verificación-de-dashboards)
  - [8.3. Verificación de agentes y recepción real](#83-verificación-de-agentes-y-recepción-real)
  - [8.4. Comprobación manual de índices y documentos](#84-comprobación-manual-de-índices-y-documentos)
- [9. Copias de seguridad y recuperación](#9-copias-de-seguridad-y-recuperación)
- [10. Administración y mantenimiento](#10-administración-y-mantenimiento)
- [11. Diagnóstico y resolución de problemas](#11-diagnóstico-y-resolución-de-problemas)
- [12. Anexos](#12-anexos)


---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor implementado |
|---|---|
| Servidor de OpenSearch y Dashboards | **RL-MON-01** |
| Sistema operativo anfitrión | Rocky Linux 9 |
| IP del servidor central | `192.168.20.20` |
| OpenSearch | `opensearchproject/opensearch:2.12.0` |
| OpenSearch Dashboards | `opensearchproject/opensearch-dashboards:2.12.0` |
| Agente local | `fluent/fluent-bit:3.0.0` |
| URL de OpenSearch | `http://192.168.20.20:9200` |
| URL de Dashboards | `http://192.168.20.20:5601` |
| Instalación | Script local y Docker Compose |
| Directorio central | `/opt/recoleccion-uy/opensearch` |
| Proyecto Compose central | `recoleccion-opensearch` |

## 1.2. Rol de OpenSearch

OpenSearch almacena e indexa registros enviados por Fluent Bit. OpenSearch Dashboards proporciona la interfaz web para consultar los documentos indexados. Los scripts implementan la captura de **logs de contenedores Docker que utilicen el controlador `json-file`**; no implementan recolección genérica de todos los archivos de log del sistema operativo, de MySQL ni de todos los eventos de aplicaciones.

El script central instala Fluent Bit **solo para los logs Docker locales de RL-MON-01**. Los logs Docker de RL-APP-01 y RL-PROXY-01 requieren instalar los agentes respectivos en esos servidores.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución y servidor correspondiente

**No se ejecutan los tres scripts en el mismo servidor.** La instalación central se realiza en RL-MON-01; luego los agentes remotos se instalan en sus propios equipos.

| Orden | Servidor donde se ejecuta | Script exacto | Resultado |
|---|---|---|---|
| 1 | **RL-MON-01** (`192.168.20.20`) | `4-RL-MON-OpenSearch.sh` | Instala OpenSearch, Dashboards y Fluent Bit **local** |
| 2 | **RL-APP-01** (`192.168.30.20`) | `6-RL-APP-install_fluent_bit.sh` | Configura y arranca Fluent Bit para enviar los logs Docker de **RL-APP-01** a OpenSearch |
| 3 | **RL-PROXY-01** (`192.168.50.20`) | `9-RL-PROXY-install_fluent_bit.sh` | Configura y arranca Fluent Bit para enviar los logs Docker de **RL-PROXY-01** a OpenSearch |

**Dependencias:** antes de iniciar OpenSearch, RL-MON-01 debe contar con Docker Engine y Docker Compose operativos. Cada script remoto requiere OpenSearch ya accesible en `192.168.20.20:9200`. La tabla expresa el orden lógico de incorporación a este sistema, **no reemplaza el orden completo de preparación de cada servidor documentado para el proyecto**.

## 2.2. Procedimiento general

**Ejecutar cada bloque en el servidor indicado** y desde la carpeta donde se copió el script correspondiente. Esa carpeta de origen no está fijada por el script; los directorios `/opt/recoleccion-uy/...` son destinos de instalación.

El procedimiento adoptado en la documentación del proyecto normaliza finales de línea, asigna permiso de ejecución y ejecuta con privilegios:

```bash
sed -i 's/\r$//' NOMBRE_DEL_SCRIPT.sh
chmod +x NOMBRE_DEL_SCRIPT.sh
sudo ./NOMBRE_DEL_SCRIPT.sh
```

Los nombres reales y el servidor de ejecución figuran en las fichas siguientes. **No volver a ejecutar un instalador sobre una instalación existente sin revisar sus comprobaciones de protección.**

## 2.3. Scripts específicos

### 2.3.1. `4-RL-MON-OpenSearch.sh`

**Servidor de ejecución: RL-MON-01 (`192.168.20.20`).**

**Nombre del script:** `4-RL-MON-OpenSearch.sh`.

**Descripción:** instala OpenSearch, OpenSearch Dashboards y un Fluent Bit local mediante Docker Compose; configura la lectura de logs JSON de contenedores Docker del propio RL-MON-01 y su envío a OpenSearch.

**Componentes que instala o utiliza:** OpenSearch 2.12.0, OpenSearch Dashboards 2.12.0, Fluent Bit 3.0.0, Docker y Docker Compose ya operativos; utiliza además `curl`, `ss`, `sysctl`, `ip`, `awk` y `df`.

**Componentes que configura:** contenedores y red `logs-net`; volumen `opensearch-data`; parser Docker; filtro Lua de identificación de contenedores; salida Fluent Bit a `opensearch:9200`; publicación TCP 9200 y 5601; posible ajuste `vm.max_map_count=262144`.

**Archivos y directorios creados o configurados:**

- `/opt/recoleccion-uy/opensearch/compose.yaml`
- `/opt/recoleccion-uy/opensearch/fluent-bit/fluent-bit.conf`
- `/opt/recoleccion-uy/opensearch/fluent-bit/parsers.conf`
- `/opt/recoleccion-uy/opensearch/fluent-bit/docker_metadata.lua`
- `/opt/recoleccion-uy/opensearch/fluent-bit/storage/`
- `/etc/sysctl.d/99-recoleccion-opensearch.conf` **solo si** el valor actual de `vm.max_map_count` es inferior a 262144.

**Requisitos previos verificados por el script:**

- Usuario root; Rocky Linux 9.
- Hostname `rl-mon-01` e IP local `192.168.20.20`.
- Docker y Docker Compose funcionales.
- Existencia de `/var/lib/docker/containers`.
- Puertos TCP **9200** y **5601** libres.
- **Al menos 4 GiB de RAM total** y **10 GiB disponibles** en el sistema de archivos de `/var/lib/docker`.
- Ausencia del archivo `/opt/recoleccion-uy/opensearch/compose.yaml` y de los tres contenedores que el script crearía.

El script advierte si el controlador por defecto de logs Docker, o el de contenedores activos, no es `json-file`.

**Ejecución — exclusivamente en RL-MON-01:**

```bash
sed -i 's/\r$//' 4-RL-MON-OpenSearch.sh
chmod +x 4-RL-MON-OpenSearch.sh
sudo ./4-RL-MON-OpenSearch.sh
```

El script no modifica el monitoreo de Grafana/Prometheus, no modifica `firewalld` y no elimina contenedores ni volúmenes existentes. **Rechaza una instalación previa con los recursos que comprueba**, por lo que no debe tratarse como un actualizador.

### 2.3.2. `6-RL-APP-install_fluent_bit.sh`

**Servidor de ejecución: RL-APP-01 (`192.168.30.20`). Nunca en RL-MON-01.**

**Nombre del script:** `6-RL-APP-install_fluent_bit.sh`.

**Descripción:** instala Fluent Bit 3.0.0 para leer logs Docker de RL-APP-01 y enviarlos a OpenSearch en RL-MON-01.

**Componentes que instala o utiliza:** imagen `fluent/fluent-bit:3.0.0`, Docker Compose, parser de archivos Docker, filtro Lua e identificación de contenedores.

**Componentes que configura:** proyecto `recoleccion-fluent-bit-app`, contenedor `recoleccion-fluent-bit-app`, directorio de almacenamiento local, destino `192.168.20.20:9200`, prefijo de índices `rl-app-01-logs` y etiqueta `host=RL-APP-01`.

**Archivos y directorios creados o configurados:** `/opt/recoleccion-uy/fluent-bit/compose.yaml`, `fluent-bit.conf`, `parsers.conf`, `docker_metadata.lua` y `storage/`.

**Requisitos previos:** Rocky Linux 9, hostname `rl-app-01`, IP `192.168.30.20`, Docker y Compose funcionales, Python 3, controlador predeterminado Docker `json-file`, directorio de logs Docker existente y OpenSearch central accesible y con estado de clúster `green` o `yellow`. El script valida condiciones de configuración y evita sobrescribir archivos existentes.

**Ejecución — exclusivamente en RL-APP-01:**

```bash
sed -i 's/\r$//' 6-RL-APP-install_fluent_bit.sh
chmod +x 6-RL-APP-install_fluent_bit.sh
sudo ./6-RL-APP-install_fluent_bit.sh
```

Este script **no modifica las aplicaciones Laravel**, ni la configuración de Docker del anfitrión ni `firewalld`. Verifica su configuración y el funcionamiento inicial de Fluent Bit; la recepción efectiva de documentos debe comprobarse después en OpenSearch.

### 2.3.3. `9-RL-PROXY-install_fluent_bit.sh`

**Servidor de ejecución: RL-PROXY-01 (`192.168.50.20`). Nunca en RL-MON-01.**

**Nombre del script:** `9-RL-PROXY-install_fluent_bit.sh`.

**Descripción:** instala Fluent Bit 3.0.0 para capturar logs Docker de RL-PROXY-01 y enviarlos a OpenSearch en RL-MON-01.

**Componentes que instala o utiliza:** imagen `fluent/fluent-bit:3.0.0`, Docker Compose, parser Docker y filtro Lua.

**Componentes que configura:** proyecto `recoleccion-fluent-bit-proxy`, contenedor `recoleccion-fluent-bit-proxy`, destino `192.168.20.20:9200`, prefijo de índices `rl-proxy-01-logs` y etiqueta `host=RL-PROXY-01`.

**Archivos y directorios creados o configurados:** `/opt/recoleccion-uy/fluent-bit/compose.yaml`, `fluent-bit.conf`, `parsers.conf`, `docker_metadata.lua` y `storage/`.

**Requisitos previos:** Rocky Linux 9, hostname `rl-proxy-01`, IP `192.168.50.20`, Docker/Compose y Python 3 operativos, conectividad hacia OpenSearch y estado de clúster `green` o `yellow`. El script exige encontrar al menos un contenedor que use `json-file` y al menos un archivo `*-json.log` en el directorio de logs Docker.

**Ejecución — exclusivamente en RL-PROXY-01:**

```bash
sed -i 's/\r$//' 9-RL-PROXY-install_fluent_bit.sh
chmod +x 9-RL-PROXY-install_fluent_bit.sh
sudo ./9-RL-PROXY-install_fluent_bit.sh
```

El script **no cambia Nginx, WAF ni `firewalld`**. Verifica que Fluent Bit permanezca activo, pero indica que la entrega real de documentos debe confirmarse en OpenSearch.

## 2.4. Prefijos de índices antes de ejecutar los scripts

**Antes de la primera instalación**, revisar en el script correspondiente el valor `Logstash_Prefix` que se escribe dentro del bloque de generación de `fluent-bit.conf`. Cada servidor debe utilizar su propio prefijo, para separar los registros en OpenSearch.

| Servidor de instalación | Script que debe revisarse | Valor definido actualmente |
|---|---|---|
| RL-MON-01 | `4-RL-MON-OpenSearch.sh` | `Logstash_Prefix       rl-mon-01-logs` |
| RL-APP-01 | `6-RL-APP-install_fluent_bit.sh` | `Logstash_Prefix       rl-app-01-logs` |
| RL-PROXY-01 | `9-RL-PROXY-install_fluent_bit.sh` | `Logstash_Prefix       rl-proxy-01-logs` |

**Los tres scripts ya contienen prefijos diferentes y adecuados para los tres servidores definidos en el proyecto.** Si se mantienen esos nombres, no es necesario editarlos. Si el despliegue exige otro identificador, modificar el prefijo **en el script del servidor correspondiente antes de ejecutarlo** y comprobar que siga siendo único; luego ejecutar la instalación normal indicada en 2.3.

El instalador genera `fluent-bit.conf` a partir de texto incorporado en el propio script. Por eso, cambiar un archivo de configuración de otro servidor, o intentar modificarlo antes de que exista, no reemplaza la revisión previa del script. No intercambiar scripts entre servidores.

Los nombres de índices resultantes adoptan la forma `<prefijo>-AAAA.MM.DD` por `Logstash_Format On`. Si se cambia un prefijo, utilizar el nuevo valor al consultar índices y al configurar la vista de datos de Dashboards. El cambio no renombra automáticamente índices existentes.

---

# 3. Arquitectura y componentes

```text
RL-MON-01    Logs Docker json-file ──> Fluent Bit local ──────┐
                                                              │
RL-APP-01    Logs Docker json-file ──> Fluent Bit APP ────────┼──> OpenSearch
                                                              │      :9200
RL-PROXY-01  Logs Docker json-file ──> Fluent Bit PROXY ──────┘       │
                                                                      v
                                                           OpenSearch Dashboards
                                                                 :5601
```

- **OpenSearch:** servicio central de indexación y consulta, instalado en RL-MON-01.
- **OpenSearch Dashboards:** aplicación web para consultar los datos indexados, instalada en RL-MON-01.
- **Fluent Bit local:** lee `/var/lib/docker/containers/*/*-json.log` de RL-MON-01.
- **Fluent Bit remoto:** cada agente lee los logs Docker del servidor en que se instala y los envía por HTTP a RL-MON-01.
- **Lua:** obtiene el identificador de contenedor desde la ruta del log e intenta recuperar su nombre leyendo `config.v2.json`, sin montar el socket Docker.

La lectura configurada es de logs Docker existentes y nuevos en formato `json-file`; el `Read_From_Head Off` de los agentes indica que **no se plantea importar automáticamente todo el histórico previo** al iniciar el seguimiento.

---

# 4. Configuración de red y conectividad

| Origen | Destino | Puerto / URL | Finalidad |
|---|---|---|---|
| Navegador autorizado | RL-MON-01 | `http://192.168.20.20:5601` | Abrir Dashboards |
| Agente RL-MON-01 | OpenSearch local en red Compose | `http://opensearch:9200` | Enviar logs locales |
| Agente RL-APP-01 | RL-MON-01 | `http://192.168.20.20:9200` | Enviar logs del servidor APP |
| Agente RL-PROXY-01 | RL-MON-01 | `http://192.168.20.20:9200` | Enviar logs del servidor PROXY |
| Cliente autorizado | RL-MON-01 | `http://192.168.20.20:9200` | API HTTP de OpenSearch |

OpenSearch y Dashboards se publican en la IP `192.168.20.20` con TCP 9200 y TCP 5601. **La comunicación documentada es HTTP sin TLS**. La conectividad real entre segmentos está sujeta a las políticas de red existentes; ninguno de estos instaladores configura reglas de firewall.

---

# 5. Servicios y contenedores Docker

## 5.1. Servicios de OpenSearch

**Proyecto Docker Compose central:** `recoleccion-opensearch` — **servidor RL-MON-01**.

| Servicio Compose | Imagen | Nombre explícito del contenedor | Puertos |
|---|---|---|---|
| `opensearch` | `opensearchproject/opensearch:2.12.0` | `recoleccion-opensearch` | `192.168.20.20:9200:9200` |
| `dashboards` | `opensearchproject/opensearch-dashboards:2.12.0` | `recoleccion-opensearch-dashboards` | `192.168.20.20:5601:5601` |
| `fluent-bit` | `fluent/fluent-bit:3.0.0` | `recoleccion-fluent-bit-mon` | Sin puerto publicado |

Los tres contenedores emplean política de reinicio `unless-stopped` y red `logs-net` tipo `bridge`.

**Configuración relevante de OpenSearch:**

```yaml
environment:
  - discovery.type=single-node
  - DISABLE_SECURITY_PLUGIN=true
  - DISABLE_INSTALL_DEMO_CONFIG=true
  - OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
volumes:
  - opensearch-data:/usr/share/opensearch/data
ports:
  - "192.168.20.20:9200:9200"
```

El script fija `ulimits` para `memlock` y `nofile`. Puede elevar `vm.max_map_count` a 262144 antes del arranque si el valor existente es inferior.

**Configuración relevante de Dashboards:**

```yaml
environment:
  - 'OPENSEARCH_HOSTS=["http://opensearch:9200"]'
  - DISABLE_SECURITY_DASHBOARDS_PLUGIN=true
ports:
  - "192.168.20.20:5601:5601"
```

**Importante:** en esta implementación los plugins de seguridad están deshabilitados. No se configura autenticación de usuario para OpenSearch Dashboards mediante estos scripts.

## 5.2. Acceso a OpenSearch Dashboards

**Desde el navegador de un equipo autorizado con conectividad hacia RL-MON-01:**

1. Abrir `http://192.168.20.20:5601`.
2. Comprobar que carga OpenSearch Dashboards.
3. Consultar los índices de logs cuando existan documentos recibidos y esté definido el patrón de datos correspondiente.

El instalador no crea usuarios ni contraseñas para Dashboards, porque configura `DISABLE_SECURITY_DASHBOARDS_PLUGIN=true` y deshabilita el plugin de seguridad de OpenSearch. **No debe describirse una pantalla de inicio de sesión como parte de esta implementación.**

**El script no crea automáticamente un patrón de índices o vista de datos en Dashboards**, ni un dashboard visual específico de logs. Para consultar registros mediante la interfaz debe existir una vista/patrón que coincida con los índices realmente creados. No se atribuye a los scripts un procedimiento gráfico automatizado que no implementan.

## 5.3. Recolección mediante Fluent Bit

Los tres scripts configuran un input de lectura de archivos Docker, parser JSON y salida OpenSearch. Para RL-MON-01, la configuración generada incluye:

```ini
[INPUT]
    Name                  tail
    Tag                   docker.mon
    Path                  /var/lib/docker/containers/*/*-json.log
    Parser                docker_custom
    Path_Key              filepath
    DB                    /fluent-bit/storage/docker.db
    Read_From_Head        Off
    Mem_Buf_Limit         50MB
    Skip_Long_Lines       On
    Refresh_Interval      5
    Rotate_Wait           30
    storage.type          filesystem
```

Los filtros añaden información de identificación y origen, entre ella:

- `host`: `RL-MON-01`, `RL-APP-01` o `RL-PROXY-01`, según el agente.
- `server_ip`: IP correspondiente al servidor.
- `environment`: `recoleccion-uy`.
- `container_id` y, cuando se logra obtener, `container_name`.

**Limitación implementada:** solo se capturan contenedores cuyo log realmente está almacenado como `*-json.log` (driver `json-file`). El instalador de RL-APP-01 exige que el controlador predeterminado de Docker sea `json-file`; los instaladores de RL-MON-01 y RL-PROXY-01 advierten sobre controladores no compatibles, pero RL-PROXY-01 también exige encontrar al menos un contenedor y un archivo de log de tipo `json-file`. El contenedor Fluent Bit de RL-MON-01 monta `/var/lib/docker/containers` como solo lectura; la lectura efectiva puede depender de los permisos y de SELinux, sin que el script deshabilite SELinux.

## 5.4. Identificación del nombre del contenedor mediante Lua

**Los tres instaladores generan automáticamente `docker_metadata.lua`; no hay que crear ni instalar manualmente este archivo.** El objetivo es que, además del identificador Docker, cada registro pueda mostrar el nombre legible del contenedor en OpenSearch Dashboards.

La configuración de Fluent Bit conecta el filtro Lua con la función creada por los scripts:

```ini
[FILTER]
    Name                  lua
    Match                 docker.*
    script                /fluent-bit/etc/docker_metadata.lua
    call                  add_container_name
```

El procesamiento previsto es el siguiente:

1. El input `tail` obtiene la ruta del archivo de log en el campo `filepath` (`Path_Key`).
2. Lua extrae `container_id` de la ruta `/var/lib/docker/containers/<id>/...`.
3. Lee el archivo Docker `/var/lib/docker/containers/<id>/config.v2.json`, identifica el valor `Name` y elimina la barra inicial.
4. Añade `container_name` al registro; conserva en caché los nombres ya resueltos para no repetir lecturas.
5. Si no puede abrir el archivo o encontrar el nombre, registra `container_name = "unknown"`.

| Servidor | Archivo generado en el anfitrión |
|---|---|
| RL-MON-01 | `/opt/recoleccion-uy/opensearch/fluent-bit/docker_metadata.lua` |
| RL-APP-01 | `/opt/recoleccion-uy/fluent-bit/docker_metadata.lua` |
| RL-PROXY-01 | `/opt/recoleccion-uy/fluent-bit/docker_metadata.lua` |

Los scripts montan el archivo Lua y los metadatos de contenedores en el contenedor Fluent Bit. **No requieren montar `/var/run/docker.sock`.** Para ver el nombre en Dashboards, primero debe existir un documento indexado que contenga el campo `container_name`; se puede buscar o añadir ese campo a la tabla de resultados de la vista de datos.

Si aparece `unknown`, comprobar la accesibilidad de `config.v2.json`, los permisos del montaje de `/var/lib/docker/containers` y los logs de Fluent Bit del servidor de origen.

## 5.5. Índices de logs y prefijos por servidor

Todos los agentes usan `Logstash_Format On`, con prefijos de índice específicos por servidor:

| Servidor que envía | `Logstash_Prefix` configurado | Índices esperados por fecha |
|---|---|---|
| RL-MON-01 | `rl-mon-01-logs` | `rl-mon-01-logs-AAAA.MM.DD` |
| RL-APP-01 | `rl-app-01-logs` | `rl-app-01-logs-AAAA.MM.DD` |
| RL-PROXY-01 | `rl-proxy-01-logs` | `rl-proxy-01-logs-AAAA.MM.DD` |

**Inconsistencia confirmada en el script central:** su mensaje final menciona `recoleccion-logs-AAAA.MM.DD`, pero la configuración efectiva de salida de Fluent Bit establece `rl-mon-01-logs`. Para identificar índices debe utilizarse la **configuración efectiva**, no ese mensaje informativo. La corrección del mensaje del script queda pendiente; este documento no modifica código.

La existencia de índices requiere que se hayan producido logs elegibles, que Fluent Bit pueda leerlos y que OpenSearch haya aceptado los documentos.

## 5.6. Cómo verificar registros de los servidores

La secuencia respaldada por la implementación es:

1. **RL-MON-01:** comprobar que OpenSearch y Dashboards respondan y que los tres contenedores centrales sigan activos.
2. **RL-APP-01:** comprobar que el agente `recoleccion-fluent-bit-app` haya iniciado correctamente.
3. **RL-PROXY-01:** comprobar que el agente `recoleccion-fluent-bit-proxy` haya iniciado correctamente.
4. **RL-MON-01 / Dashboards:** verificar la **existencia de índices y documentos** con los prefijos `rl-mon-01-logs`, `rl-app-01-logs` y `rl-proxy-01-logs`; las comprobaciones de arranque de los scripts no certifican ingestión real.
5. Para diferenciar el origen de cada documento, utilizar las etiquetas `host`, `server_ip`, `container_id` y `container_name` cuando estén presentes.

El paso 4 requiere una comprobación de datos posterior al despliegue. Los scripts no automatizan la creación de una vista de datos en Dashboards ni comprueban la cantidad de documentos recibidos. Los comandos de consulta manual se indican en el apartado 8.4 y son procedimientos de verificación, **no comandos ejecutados por los instaladores**.

---

# 6. Estructura de directorios y almacenamiento

**Servidor RL-MON-01:**

```text
/opt/recoleccion-uy/opensearch/
├── compose.yaml
└── fluent-bit/
    ├── fluent-bit.conf
    ├── parsers.conf
    ├── docker_metadata.lua
    └── storage/
```

| Ubicación | Función |
|---|---|
| `/opt/recoleccion-uy/opensearch/compose.yaml` | Despliegue de OpenSearch, Dashboards y Fluent Bit local |
| `/opt/recoleccion-uy/opensearch/fluent-bit/fluent-bit.conf` | Input, filtros y salida de logs |
| `/opt/recoleccion-uy/opensearch/fluent-bit/parsers.conf` | Parser JSON Docker |
| `/opt/recoleccion-uy/opensearch/fluent-bit/docker_metadata.lua` | Recuperación del nombre del contenedor |
| `/opt/recoleccion-uy/opensearch/fluent-bit/storage/` | Estado y almacenamiento de Fluent Bit |
| `opensearch-data:/usr/share/opensearch/data` | Volumen persistente de índices OpenSearch |
| `/etc/sysctl.d/99-recoleccion-opensearch.conf` | Ajuste condicional de `vm.max_map_count` |

El instalador central aplica permisos `750` al directorio base y a `fluent-bit`, `770` a `storage` y `640` a los archivos de configuración creados.

**Servidores RL-APP-01 y RL-PROXY-01:**

```text
/opt/recoleccion-uy/fluent-bit/
├── compose.yaml
├── fluent-bit.conf
├── parsers.conf
├── docker_metadata.lua
└── storage/
```

Estos directorios corresponden **a cada servidor remoto de forma independiente**. No deben mezclarse ni copiarse los archivos de configuración entre servidores: los valores de `host`, `server_ip`, proyectos Compose, nombres de contenedores y prefijos de índices son diferentes.

---

# 7. Seguridad y control de acceso

- **OpenSearch API:** HTTP en `192.168.20.20:9200`.
- **Dashboards:** HTTP en `192.168.20.20:5601`.
- **Plugin de seguridad OpenSearch:** deshabilitado por `DISABLE_SECURITY_PLUGIN=true`.
- **Plugin de seguridad Dashboards:** deshabilitado por `DISABLE_SECURITY_DASHBOARDS_PLUGIN=true`.
- **Transmisión de Fluent Bit:** `TLS Off` en los tres agentes.
- **Firewall:** los instaladores no crean ni modifican reglas; el acceso debe estar limitado por los controles de red existentes.

**Advertencia importante:** la configuración existente expone una API y una interfaz **sin autenticación y sin cifrado TLS** en la IP de RL-MON-01. Los scripts indican restringir el acceso mediante firewall, pero **no verifican que la restricción esté aplicada**. No se afirma que esta protección haya sido desplegada.

---

# 8. Monitoreo y registros

## 8.1. Verificación de disponibilidad de OpenSearch

**Servidor: RL-MON-01.** El instalador realiza la siguiente prueba para esperar la respuesta del servicio central:

```bash
curl --noproxy '*' -fsS --max-time 3 \
  "http://192.168.20.20:9200"
```

Reintenta hasta **60 veces**, con pausas de **2 segundos**. Esta verificación comprueba respuesta HTTP de OpenSearch, no la llegada de documentos.

En **RL-APP-01**, el script comprueba la salud del clúster con:

```bash
curl --noproxy '*' -fsS --max-time 5 \
  "http://192.168.20.20:9200/_cluster/health"
```

En **RL-PROXY-01**, el script utiliza:

```bash
curl --noproxy '*' -fsS --connect-timeout 3 --max-time 8 \
  "http://192.168.20.20:9200/_cluster/health"
```

Ambos agentes remotos validan que el estado del clúster sea `green` o `yellow` antes de continuar. La disponibilidad de OpenSearch debe comprobarse **desde el servidor que ejecuta cada agente**, porque la conectividad intersegmento puede diferir.

## 8.2. Verificación de Dashboards

**Servidor: RL-MON-01.** El script central verifica HTTP en:

```text
http://192.168.20.20:5601/
```

Acepta respuestas `2xx` o `3xx` y reintenta hasta 60 veces, con pausas de dos segundos.

La carga del sitio debe comprobarse después desde un navegador autorizado. La respuesta HTTP por sí sola no demuestra que exista una vista de logs lista para consultar.

## 8.3. Verificación de agentes y recepción real

El instalador central comprueba el estado `Running` de:

- `recoleccion-opensearch`
- `recoleccion-opensearch-dashboards`
- `recoleccion-fluent-bit-mon`

Los scripts de RL-APP-01 y RL-PROXY-01 comprueban que sus agentes sigan activos tras el despliegue y revisan condiciones y mensajes de error. **Los tres scripts distinguen entre contenedor en ejecución e ingestión efectiva.**

Para que se visualicen documentos deben cumplirse todas estas condiciones:

1. El contenedor de origen utiliza un controlador de log compatible (`json-file`).
2. Fluent Bit tiene permisos efectivos de lectura sobre los archivos Docker.
3. Existe conectividad desde el agente hasta `192.168.20.20:9200` o el servicio interno `opensearch:9200`.
4. OpenSearch acepta los documentos.
5. Hay índices/documentos disponibles para su consulta en Dashboards.

La instalación inicial no equivale a confirmar los cinco puntos.

## 8.4. Comprobación manual de índices y documentos

**Ejecutar en RL-MON-01** una vez instalados los agentes. Estos comandos son verificaciones operativas adicionales; **no forman parte de los instaladores existentes**.

Para listar los índices asociados a los tres servidores:

```bash
curl --noproxy '*' -fsS --max-time 10 \
  "http://192.168.20.20:9200/_cat/indices/rl-*-logs-*?v"
```

Para consultar la cantidad de documentos que coincide con los índices de cada servidor:

```bash
for prefijo in rl-mon-01-logs rl-app-01-logs rl-proxy-01-logs; do
  echo "Servidor / prefijo: $prefijo"
  curl --noproxy '*' -fsS --max-time 10 \
    "http://192.168.20.20:9200/${prefijo}-*/_count?ignore_unavailable=true&allow_no_indices=true"
  echo
done
```

Un resultado sin índices o con `count` igual a `0` indica que no se identificaron documentos para ese prefijo al momento de la consulta. No demuestra por sí solo que el agente esté detenido: también deben revisarse los permisos de lectura, los archivos de origen, los logs del agente y la conectividad. La API se encuentra configurada sin autenticación, por lo que estas consultas solo deben realizarse desde un equipo autorizado.

---

# 9. Copias de seguridad y recuperación

Los recursos identificados que deben contemplarse en un respaldo de esta solución son:

- El volumen persistente `opensearch-data`, que contiene los datos de OpenSearch.
- `compose.yaml` y los archivos de configuración del agente local.
- Los archivos Compose y Fluent Bit independientes de RL-APP-01 y RL-PROXY-01.
- Los directorios `storage/` de Fluent Bit, utilizados para el seguimiento y almacenamiento asociado a la lectura.

**Los scripts de instalación revisados no establecen un plan de copias, frecuencia, retención, destino, snapshots ni procedimiento de restauración.** Tampoco configuran políticas de retención de índices. Por ello no se presentan como implementados procedimientos de backup o recuperación que no figuran en los archivos.

La persistencia del volumen Docker **no sustituye una copia de seguridad**.

---

# 10. Administración y mantenimiento

Los comandos de verificación incluidos expresamente en la salida final del instalador central se ejecutan en **RL-MON-01**:

```bash
cd /opt/recoleccion-uy/opensearch
docker compose ps
docker compose logs --tail=50
```

En **RL-APP-01** y, por separado, en **RL-PROXY-01**, los instaladores muestran para revisar sus agentes:

```bash
cd /opt/recoleccion-uy/fluent-bit
docker compose ps
docker compose logs --tail=50
```

**No confundir proyectos:** en RL-MON-01 se administra `recoleccion-opensearch`; los agentes remotos se gestionan con proyectos Compose propios. Estos comandos son de inspección, no reinstalan servicios.

Los scripts no implementan rotación o eliminación programada de índices de OpenSearch. Tampoco documentan una actualización automatizada de imágenes. Evitar considerar la reejecución de los instaladores como procedimiento de actualización.

---

# 11. Diagnóstico y resolución de problemas

| Síntoma | Comprobación respaldada por scripts | Servidor de comprobación |
|---|---|---|
| OpenSearch no inicia o no responde | `docker compose ps`, `docker compose logs --tail=50` y respuesta HTTP del puerto 9200 | **RL-MON-01** |
| Dashboards no abre | Respuesta HTTP en `http://192.168.20.20:5601/` y logs del proyecto central | **RL-MON-01** |
| Fluent Bit local inactivo | Estado del contenedor `recoleccion-fluent-bit-mon` y logs del proyecto | **RL-MON-01** |
| No llegan logs de RL-APP-01 | Acceso a `192.168.20.20:9200`, estado del clúster, agente y logs | **RL-APP-01**, comprobación final en **RL-MON-01** |
| No llegan logs de RL-PROXY-01 | Acceso a `192.168.20.20:9200`, estado del clúster, agente y logs | **RL-PROXY-01**, comprobación final en **RL-MON-01** |
| Solo aparecen algunos contenedores | Comprobar que sus logs usen driver `json-file` y que Fluent Bit pueda leerlos | Servidor de origen |
| Índice del servidor ausente | Confirmar que el agente remite eventos y que OpenSearch recibe documentos | Servidor de origen y RL-MON-01 |
| Dashboards funciona, pero no hay logs visibles | Confirmar índices/documentos y disponibilidad de la vista de datos necesaria | RL-MON-01 / navegador autorizado |
| Instalador central se detiene por requisitos | Hostname/IP, RAM, disco, puertos, Docker y recursos preexistentes | RL-MON-01 |

**Observaciones puntuales del código:**

- El script central **falla si ya existe** el Compose o cualquiera de los contenedores esperados.
- Los scripts no convierten controladores de logs a `json-file`. RL-APP-01 exige ese controlador como predeterminado; RL-PROXY-01 exige al menos un contenedor y un archivo compatibles.
- El acceso HTTP sin autenticación es una decisión de la configuración implementada, no una configuración segura por defecto.
- El mensaje final de índice `recoleccion-logs-AAAA.MM.DD` no coincide con `Logstash_Prefix rl-mon-01-logs` configurado en Fluent Bit local.

---

# 12. Anexos

Sección reservada para documentación complementaria verificada que corresponda específicamente a OpenSearch y Fluent Bit.
