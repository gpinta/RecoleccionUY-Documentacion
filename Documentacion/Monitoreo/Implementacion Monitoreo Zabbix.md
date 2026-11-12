# Implementación Monitoreo Zabbix — Recolección UY

**Fecha de revisión:** 11/11/2026  
**Componente:** Zabbix 7.0 (imágenes Docker fijadas por digest), Zabbix Agent 7.0.32 en Windows  
**Tipo de documento:** Instructivo de instalación, configuración, acceso, verificación y mantenimiento  
**Servidor de instalación central:** **RL-MON-01 (`192.168.20.20`)**  
**Servidor de políticas de tránsito:** **RL-FW-01**  
**Servidores monitoreados:** **WS-DC-01 (`192.168.10.20`)** y **WS-DC-02 (`192.168.10.21`)**

> **Alcance:** implementación específica de Zabbix para los dos controladores de dominio Windows Server 2012 R2, conforme a los scripts Bash, PowerShell y archivos YAML incluidos en el repositorio. Este documento replica los doce capítulos de «Implementación Monitoreo Grafana» y «Implementación Monitoreo OpenSearch», sin volver a describir la configuración general de los servidores.


## Índice

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-información-general)
  - [1.2. Rol de Zabbix](#12-rol-de-zabbix)
- [2. Ejecución de Scripts](#2-ejecución-de-scripts)
  - [2.1. Orden de ejecución y servidor correspondiente](#21-orden-de-ejecución-y-servidor-correspondiente)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos](#23-scripts-específicos)
    - [2.3.1. `5-RL-MON-Zabbix.sh` — RL-MON-01](#231-5-rl-mon-zabbixsh--rl-mon-01)
    - [2.3.2. `4-RL-FW-add_Zabbix.sh` — RL-FW-01](#232-4-rl-fw-add_zabbixsh--rl-fw-01)
    - [2.3.3. `7-WS-DC-Zabbix_Agent.ps1` — WS-DC-01 y WS-DC-02](#233-7-ws-dc-zabbix_agentps1--ws-dc-01-y-ws-dc-02)
  - [2.4. Importación manual de YAML](#24-importación-manual-de-yaml)
- [3. Arquitectura y componentes](#3-arquitectura-y-componentes)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
  - [5.1. Servicios de Zabbix](#51-servicios-de-zabbix)
  - [5.2. Acceso a Zabbix Web](#52-acceso-a-zabbix-web)
  - [5.3. Agentes Windows y modo de monitoreo](#53-agentes-windows-y-modo-de-monitoreo)
  - [5.4. Plantilla y archivos de importación](#54-plantilla-y-archivos-de-importación)
  - [5.5. Eventos y alertas configuradas](#55-eventos-y-alertas-configuradas)
  - [5.6. Cómo verificar los controladores](#56-cómo-verificar-los-controladores)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
- [7. Seguridad y control de acceso](#7-seguridad-y-control-de-acceso)
- [8. Monitoreo y registros](#8-monitoreo-y-registros)
  - [8.1. Verificación de disponibilidad de Zabbix](#81-verificación-de-disponibilidad-de-zabbix)
  - [8.2. Verificación de agentes y conectividad](#82-verificación-de-agentes-y-conectividad)
  - [8.3. Verificación de eventos y alertas](#83-verificación-de-eventos-y-alertas)
  - [8.4. Comprobación de hosts importados](#84-comprobación-de-hosts-importados)
- [9. Copias de seguridad y recuperación](#9-copias-de-seguridad-y-recuperación)
- [10. Administración y mantenimiento](#10-administración-y-mantenimiento)
- [11. Diagnóstico y resolución de problemas](#11-diagnóstico-y-resolución-de-problemas)
- [12. Anexos](#12-anexos)


---

# 1. Datos del Servidor

## 1.1. Información general

| Elemento | Valor documentado |
|---|---|
| Plataforma central | RL-MON-01, `192.168.20.20`, Linux x86_64, Docker Compose v2 |
| Servidor de firewall interredes | RL-FW-01, firewalld |
| Controlador de dominio 1 | WS-DC-01, `192.168.10.20`, Windows Server 2012 R2 x64 |
| Controlador de dominio 2 | WS-DC-02, `192.168.10.21`, Windows Server 2012 R2 x64 |
| Zabbix Server | Contenedor Docker, TCP `10051` publicado en `192.168.20.20` |
| Interfaz web | Contenedor Docker, HTTP `192.168.20.20:8088` |
| Zabbix Agent | Agente clásico (no Agent 2), versión MSI prevista `7.0.32`; escucha TCP `10050` |
| Base de datos | MySQL **exclusiva** para Zabbix, en volumen Docker propio |
| Hora de aplicación web | `America/Montevideo` |
| Alcance de vigilancia | WS-DC-01 y WS-DC-02; no se configuran aquí agentes Zabbix para las aplicaciones Laravel |

## 1.2. Rol de Zabbix

Zabbix incorpora seguimiento de disponibilidad e incidentes de Windows, seguridad de cuentas, almacenamiento, Active Directory, DNS y DFS Replication de los dos controladores. Es complementario, no sustitutivo, de los componentes ya documentados: **Grafana/Prometheus** visualiza métricas de infraestructura; **OpenSearch/Fluent Bit** centraliza logs Docker; **Zabbix** recoge elementos y eventos de los controladores Windows mediante agentes. El despliegue de Zabbix usa un proyecto Compose y una base MySQL **separados** de la base compartida por las tres aplicaciones Laravel.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución y servidor correspondiente

| Paso | Servidor | Archivo del repositorio | Propósito |
|---|---|---|---|
| 1 | RL-MON-01 | `Scripts/Linux/RL-MON-01/5-RL-MON-Zabbix.sh` | Prepara/inicia MySQL, Zabbix Server y Zabbix Web |
| 2 | RL-FW-01 | `Scripts/Linux/RL-FW-01/4-RL-FW-add_Zabbix.sh` | Define políticas de firewalld entre monitoreo y controladores |
| 3 | WS-DC-01 | `Scripts/Windows/Windows Server 2012 r2/7-WS-DC-Zabbix_Agent.ps1` | Instala/configura agente, firewall local, auditoría y exportación YAML |
| 4 | WS-DC-02 | **El mismo archivo PowerShell**, ejecutado localmente | Configuración independiente del segundo controlador |
| 5 | Navegador autorizado / Zabbix Web | `WS-DC-01-zabbix-import.yaml` y `WS-DC-02-zabbix-import.yaml` | Importar los hosts manualmente y comprobar elementos/eventos |
| 6 | RL-MON-01, controladores y red | Comandos de verificación de este documento | Confirmar comunicación real y alcance de acceso |

El orden se presenta como **secuencia operativa recomendada** a partir de las dependencias; no representa un orquestador automático entre equipos. Deben existir previamente Docker/Compose, firewalld, direccionamiento y rutas. El script del firewall puede solicitar una confirmación interactiva para `firewall-cmd --reload`.

## 2.2. Procedimiento general

1. Revisar el nombre de host, las IP y las zonas/interfaces configuradas en cada script. Ejecutar **cada archivo exclusivamente en su servidor** y con privilegios de administrador/root.
2. En RL-MON-01, ejecutar el script desde una ubicación controlada, después de validar que los digests de imágenes apuntan a las versiones aprobadas y que `192.168.20.20:10051` y `:8088` están disponibles. Ejemplo: `sudo ./5-RL-MON-Zabbix.sh`.
3. En RL-FW-01, ejecutar `sudo ./4-RL-FW-add_Zabbix.sh`. Si el script requiere recarga de firewalld, evaluar su impacto y escribir `SI` solo con autorización; sin ella deja la configuración permanente y termina con código `2`.
4. En **cada** Windows Server 2012 R2, colocar previamente el MSI oficial en la ruta configurada si aún no existe el servicio, verificar el paquete según el script y ejecutar el PowerShell elevado. Ejemplo: `powershell.exe -ExecutionPolicy Bypass -File .\7-WS-DC-Zabbix_Agent.ps1` (el uso de `Bypass` debe estar permitido por las políticas operativas; preferir la política corporativa vigente).
5. Recoger el YAML generado localmente en `%ProgramData%\RecoleccionUY-Zabbix\` o utilizar el YAML correspondiente del repositorio, revisar posibles hosts preexistentes e **importar manualmente** ambos YAML desde Zabbix Web.
6. Validar alcance del puerto web, tráfico TCP/10050 y TCP/10051, recepción de datos y funcionamiento de disparadores. No considerar finalizada la habilitación solo por mensajes `[OK]` de los scripts.

## 2.3. Scripts específicos

### 2.3.1. `5-RL-MON-Zabbix.sh` — RL-MON-01

- Comprueba usuario root, hostname `rl-mon-01`, arquitectura `x86_64`, Docker y Compose v2, comandos requeridos, IP local, firewalld y zona de la interfaz `ens33` (o `MON_ZONE` ajustada).
- Usa `/opt/recoleccionuy-zabbix/independiente-v1`, proyecto Docker `recoleccion-zbx`. En una instalación nueva genera `compose.yaml` y secretos aleatorios en archivos; **no** crea `.env`.
- Configura `mysql-server`, `zabbix-server` y `zabbix-web`, volumen `zbx_mysql`, red puente `zbx_private`; sus imágenes están fijadas por digests explícitos.
- Concede al UID `1997` acceso ACL de lectura **solo** al secreto de MySQL de la aplicación, tras verificar el UID efectivo de las imágenes. Con SELinux en modo Enforcing aplica `container_file_t` al archivo compartido.
- Inicia únicamente esa pila con `docker compose up -d --no-build`; no borra volúmenes, secretos ni otros proyectos.
- Crea reglas locales de firewalld para TCP/10051 desde ambos DC en configuración permanente y runtime, **sin recargar firewalld**.
- Verifica contenedores en ejecución, salud de MySQL y presencia de reglas. **No** importa los hosts, no habilita por sí solo TCP/8088 en firewalld y no demuestra aislamiento de los puertos publicados por Docker.

En instalaciones preexistentes conserva Compose, secretos y volúmenes; rechaza configuraciones antiguas con `.env`, secretos faltantes, IP/puerto discordantes u otros conflictos que requieran migración manual.

### 2.3.2. `4-RL-FW-add_Zabbix.sh` — RL-FW-01

- Valida hostname `rl-fw-01`, root, firewalld activo, IP y zonas distintas de monitoreo y servicios; detecta las zonas según la ruta o admite `ZONE_MON`/`ZONE_SERV`.
- Crea o valida las políticas `rec-zbx-mon-dc` y `rec-zbx-dc-mon`, con destino `CONTINUE`, prioridad `-2` y reglas restringidas a origen/destino.
- Autoriza `192.168.20.20` → `192.168.10.20/.21` **TCP/10050** y `192.168.10.20/.21` → `192.168.20.20` **TCP/10051**.
- Mantiene configuración permanente y runtime. Si las políticas nuevas aún no están cargadas, solo realiza `firewall-cmd --reload` después de confirmación interactiva explícita.
- Rechaza políticas homónimas incompatibles; no altera NAT, FORWARD global, zonas ni reglas ajenas. Requiere verificar la conectividad real de extremo a extremo.

### 2.3.3. `7-WS-DC-Zabbix_Agent.ps1` — WS-DC-01 y WS-DC-02

- Requiere PowerShell 4.0+, sesión elevada, Windows Server 2012 R2 x64 e IP esperada según el hostname. Detecta Zabbix Agent 2 y detiene la operación si está instalado.
- Si falta el servicio `Zabbix Agent`, instala desde `C:\Temp\zabbix_agent-7.0.32-windows-amd64-openssl.msi`, después de comprobar nombre, SHA-256 configurado y firma Authenticode. **No actualiza** un agente ya instalado.
- Ajusta las directivas `Server=192.168.20.20`, `ServerActive=192.168.20.20` y `Hostname` igual al nombre de máquina. Antes de reescribir `zabbix_agentd.conf` genera una copia `.bak`.
- Inicia/reinicia el servicio según corresponda. Crea o valida la regla local `RecoleccionUY Zabbix Agent 10050 - Monitor Only` con acceso TCP/10050 **solo** desde `192.168.20.20`.
- Configura mediante `auditpol.exe` las subcategorías Logon (fallos), Account Lockout (éxitos), User Account Management (éxitos) y Kerberos Authentication Service (fallos). Una GPO puede reemplazar esa auditoría local.
- Genera un YAML Zabbix 7.0 por controlador en `%ProgramData%\RecoleccionUY-Zabbix\<HOST>-zabbix-import.yaml`; **no lo importa**.
- Comprueba que el servicio esté corriendo, comprueba el puerto de escucha TCP/10050 y prueba el acceso al Server TCP/10051. Los dos últimos fallos producen **advertencias**, no un fallo final obligatorio del script.

## 2.4. Importación manual de YAML

Los dos archivos versionados se ubican en `Scripts/Windows/Windows Server 2012 r2/` y definen un host cada uno: `WS-DC-01` (`192.168.10.20`) y `WS-DC-02` (`192.168.10.21`). El procedimiento exige:

1. Acceder a Zabbix Web desde una estación autorizada.
2. Localizar la opción de **importación** de configuración correspondiente a la versión instalada, seleccionar un YAML por vez y revisar la vista previa/opciones para evitar modificar accidentalmente hosts existentes.
3. Comprobar la existencia del grupo `Recolección UY / Windows` y de la plantilla `Windows by Zabbix agent` referenciada por nombre; si no existe, la importación necesita resolver esa dependencia.
4. Confirmar host, interfaz, cinco elementos personalizados, disparadores y activación; verificar recepción de datos tras importar ambos archivos.

Los YAML no contienen una configuración de medios, usuarios o canales de notificación. Los eventos disparados en la interfaz no equivalen automáticamente a avisos por correo u otros medios.

---

# 3. Arquitectura y componentes

```text
WS-DC-01 (192.168.10.20) -- Agente clásico -->|
    TCP/10051 (activo)                        |
WS-DC-02 (192.168.10.21) -------------------->|  RL-FW-01  --> RL-MON-01 (192.168.20.20)
                                              |                ├─ zabbix-server :10051
RL-MON-01 -- TCP/10050 (consultas pasivas) ---|--> DCs         ├─ zabbix-web :8088 (HTTP)
                                                               └─ mysql-server + zbx_mysql
```

El script central concentra **Zabbix Server y Zabbix Web** en RL-MON-01. Los agentes Windows admiten configuración activa (`ServerActive`) y pasiva (`Server`), aunque los **cinco elementos de eventos importados** son de tipo `ZABBIX_ACTIVE`. El firewall interredes se implementa en RL-FW-01, y existe además un firewall local en los controladores y otro en RL-MON-01.

**Convivencia:** Grafana/Prometheus y OpenSearch/Fluent Bit mantienen sus propias pilas y objetivos. Zabbix no usa la base MySQL de Laravel ni reemplaza esos sistemas; el script rechaza modificar pilas Docker ajenas.

---

# 4. Configuración de red y conectividad

| Origen | Destino | Protocolo | Propósito | Control indicado |
|---|---|---|---|---|
| RL-MON-01 `192.168.20.20` | WS-DC-01 `192.168.10.20` | TCP/10050 | Consulta pasiva del agente | Política `rec-zbx-mon-dc` y firewall Windows |
| RL-MON-01 `192.168.20.20` | WS-DC-02 `192.168.10.21` | TCP/10050 | Consulta pasiva del agente | Misma política y firewall Windows |
| WS-DC-01 `192.168.10.20` | RL-MON-01 `192.168.20.20` | TCP/10051 | Datos/consultas activas | Política `rec-zbx-dc-mon`, reglas locales y Docker |
| WS-DC-02 `192.168.10.21` | RL-MON-01 `192.168.20.20` | TCP/10051 | Datos/consultas activas | Misma política, reglas locales y Docker |
| Estación administrativa autorizada | RL-MON-01 `192.168.20.20` | TCP/8088 | Zabbix Web HTTP | **Control de acceso externo por implementar/verificar; no abierto por el script** |
| Contenedores del proyecto | MySQL de la misma pila | Red interna `zbx_private` | Persistencia Zabbix | No se publica puerto MySQL en el host |

La publicación Docker de TCP/10051 y TCP/8088 puede atravesar reglas diferentes de las reglas INPUT de firewalld. **No basta** con comprobar que exista una rich rule: probar explícitamente el acceso desde los DC y el rechazo desde orígenes no autorizados. TCP/8088 está publicado ligado a la IP MON, pero no tiene restricción de orígenes ni TLS configurado dentro del script.

---

# 5. Servicios y contenedores Docker

## 5.1. Servicios de Zabbix

| Servicio Compose | Imagen | Función | Persistencia/puerto |
|---|---|---|---|
| `mysql-server` | `mysql@sha256:7dcddc01...` | Base de datos independiente Zabbix | Volumen `zbx_mysql`; sin puerto publicado |
| `zabbix-server` | `zabbix/zabbix-server-mysql@sha256:3f25a179...` | Servidor central | `192.168.20.20:10051:10051` |
| `zabbix-web` | `zabbix/zabbix-web-nginx-mysql@sha256:197e4607...` | Consola HTTP | `192.168.20.20:8088:8080` |

Los tres servicios reinician con `unless-stopped`. MySQL usa `utf8mb4`, colación `utf8mb4_bin`, chequeo `mysqladmin ping` cada 15 segundos y `--log-bin-trust-function-creators=1`. Los otros dos dependen de MySQL saludable. El script fija `ZBX_STARTPOLLERS=5` y `PHP_TZ=America/Montevideo`.

**Control de versiones:** la intención documentada es Zabbix 7.0. Los digests están fijados, pero el repositorio no acredita por sí solo que las imágenes descargadas correspondan a esa versión; validarlo con la imagen efectiva antes del primer despliegue.

## 5.2. Acceso a Zabbix Web

URL prevista: **`http://192.168.20.20:8088/`**. Se accede desde un navegador en una red autorizada, **no** por un túnel SSH exigido por el script. El servicio está configurado en HTTP; no se documenta TLS, proxy de autenticación ni un procedimiento de aprovisionamiento de usuarios. El puerto web no se abre en firewalld por el instalador: su habilitación restringida corresponde a una decisión de red separada.

## 5.3. Agentes Windows y modo de monitoreo

El agente clásico usa `C:\Program Files\Zabbix Agent\zabbix_agentd.conf`, `Server` y `ServerActive` apuntando a RL-MON-01. Los elementos `eventlog[...]` definidos en los YAML son de tipo **activo**: el agente inicia la comunicación hacia TCP/10051. La escucha pasiva TCP/10050 también queda configurada y restringida para las consultas del servidor y la plantilla referenciada. La mera existencia de la escucha no confirma que los ítems activos se reciban.

## 5.4. Plantilla y archivos de importación

- Grupo: `Recolección UY / Windows`.
- Plantilla referenciada: `Windows by Zabbix agent`.
- Interfaz de host: `192.168.10.20` o `192.168.10.21` según archivo.
- Cinco elementos de log por host, intervalo `30s`, histórico `14d`, tendencias `0`.
- Cada YAML incluye **21 disparadores de eventos** por host; son de tipo `MULTIPLE`, recuperación `NONE` y cierre manual habilitado.
- `inventory_mode: DISABLED`.

Los dos YAML tienen el mismo UUID de grupo, para referirse a un único grupo común. Sus nombres de host, IP y expresiones son específicos de cada DC.

## 5.5. Eventos y alertas configuradas

| Registro Windows | ID de evento filtrados | Disparadores definidos |
|---|---|---|
| `Security` | 4625, 4740, 4771, 4720, 4726 | 4740, 4720, 4726 (3) |
| `System` | 7, 11, 51, 153, 41, 6008 | Los seis ID (6) |
| `Directory Service` | 1863, 1083, 1311, 1865, 1925, 1988, 2042 | Los siete ID (7) |
| `DNS Server` | 4013, 4000, 4004, 4015 | Los cuatro ID (4) |
| `DFS Replication` | 2213 | 2213 (1) |

El filtro del log `Security` **recoge** 4625 y 4771, pero **no define disparadores específicos** para esos dos ID en los YAML. No confundir recolección del evento con generación de un problema. Las prioridades `HIGH` y `WARNING` están declaradas por disparador en los YAML; no se añade ninguna acción de envío de alertas.

## 5.6. Cómo verificar los controladores

En la interfaz Zabbix comprobar la existencia y habilitación de ambos hosts, que la plantilla se vinculó correctamente, que los cinco ítems activos no muestran errores y que aparecen entradas recientes en **Latest data** / últimos datos y, cuando corresponda, problemas en **Problems**. Comprobar también el estado del agente y la hora de los últimos datos recibidos. No generar eventos de seguridad reales en los controladores únicamente para probar alertas sin autorización y procedimiento de pruebas.

---

# 6. Estructura de directorios y almacenamiento

**RL-MON-01:**

```text
/opt/recoleccionuy-zabbix/independiente-v1/
├── compose.yaml
└── secrets/
    ├── MYSQL_PASSWORD
    └── MYSQL_ROOT_PASSWORD
```

El volumen Docker `zbx_mysql` conserva la base MySQL. La ubicación física administrada por Docker depende de la instalación y no debe asumirse a partir del script. Los secretos se crean en la primera instalación con `openssl rand -hex 32` y permisos restrictivos; en ejecuciones posteriores se conservan.

**WS-DC-01 y WS-DC-02:**

```text
C:\Program Files\Zabbix Agent\zabbix_agentd.conf
C:\ProgramData\RecoleccionUY-Zabbix\
    <HOST>-zabbix-import.yaml
    zabbix_agentd.conf.<fecha>.bak          (si hubo cambios)
    zabbix-agent-msi.log                     (si hubo instalación MSI)
```

Ruta MSI esperada para alta nueva: `C:\Temp\zabbix_agent-7.0.32-windows-amd64-openssl.msi`.

**Repositorio:** `Scripts/Linux/RL-MON-01/5-RL-MON-Zabbix.sh`, `Scripts/Linux/RL-FW-01/4-RL-FW-add_Zabbix.sh`, y los tres archivos Windows indicados en el capítulo 2.

---

# 7. Seguridad y control de acceso

- **Separación:** el Compose `recoleccion-zbx` y el volumen MySQL son independientes de Grafana, OpenSearch y las aplicaciones Laravel.
- **Secretos:** sin `.env`; archivos `MYSQL_PASSWORD` y `MYSQL_ROOT_PASSWORD` creados únicamente en instalación nueva. El secreto de aplicación se habilita mediante ACL para UID `1997`; la clave root de MySQL permanece separada. No copiar esos archivos a documentación ni a Git.
- **Docker y firewall:** reglas locales de TCP/10051 limitadas a los dos DC y políticas interredes específicas; verificar con pruebas reales que Docker no exponga los puertos a terceros. No se realiza apertura automática del web `8088`.
- **Interfaz:** Zabbix Web se publica mediante **HTTP sin TLS configurado**. Restringir origen de acceso y considerar terminación HTTPS en un componente de red autorizado; la implementación de esa protección no figura en estos scripts.
- **Windows:** la regla del agente admite TCP/10050 desde RL-MON-01 solamente. La instalación nueva exige verificación de firma y SHA-256 del MSI. No se modifica AD/LDAP/DNS/DHCP/GPO en el script, aunque se habilita auditoría local.
- **Auditoría:** una GPO puede sobrescribir las subcategorías configuradas con `auditpol`. Confirmar el resultado efectivo de políticas.
- **Cuentas y notificaciones:** los scripts no establecen política de usuarios, autenticación externa, destinatarios ni canales de notificación Zabbix. No presumir que están configurados.

---

# 8. Monitoreo y registros

## 8.1. Verificación de disponibilidad de Zabbix

En **RL-MON-01**, desde el directorio del proyecto:

```bash
cd /opt/recoleccionuy-zabbix/independiente-v1
sudo docker compose config -q
sudo docker compose ps
sudo docker compose logs --tail=100 zabbix-server zabbix-web mysql-server
curl -I http://192.168.20.20:8088/
```

Verificar contenedores en ejecución, salud de MySQL, ausencia de errores relevantes y respuesta web. `curl` solo verifica respuesta HTTP desde donde se ejecuta; no comprueba permisos de acceso remotos ni la disponibilidad de los hosts Windows.

## 8.2. Verificación de agentes y conectividad

En **cada controlador** (PowerShell elevado):

```powershell
Get-Service -Name 'Zabbix Agent'
Get-NetTCPConnection -State Listen -LocalPort 10050
Test-NetConnection -ComputerName 192.168.20.20 -Port 10051
auditpol.exe /get /category:*
```

En **RL-MON-01**, probar TCP/10050 hacia ambas IP, por ejemplo con una herramienta TCP instalada y autorizada. En **RL-FW-01**, revisar las políticas:

```bash
sudo firewall-cmd --permanent --policy=rec-zbx-mon-dc --list-all
sudo firewall-cmd --permanent --policy=rec-zbx-dc-mon --list-all
sudo firewall-cmd --policy=rec-zbx-mon-dc --list-all
sudo firewall-cmd --policy=rec-zbx-dc-mon --list-all
```

No ejecutar un `firewall-cmd --reload` de manera automática para diagnosticar sin revisar los efectos sobre otras reglas runtime.

## 8.3. Verificación de eventos y alertas

En Zabbix Web revisar la recepción de `eventlog[Security,...]`, `eventlog[System,...]`, `eventlog[Directory Service,...]`, `eventlog[DNS Server,...]` y `eventlog[DFS Replication,...]` para cada host. Comprobar la aparición de los disparadores correspondientes **solo cuando se produzcan eventos legítimos** y evaluar los problemas de cierre manual. Los ítems emplean la opción `skip`, por lo que no debe presumirse importación retrospectiva de todos los eventos anteriores a la activación.

## 8.4. Comprobación de hosts importados

Comprobar **dos hosts**, sus direcciones, plantilla vinculada, **cinco ítems personalizados por host y 21 disparadores por host**. La importación es una tarea manual posterior a la ejecución PowerShell. El repositorio contiene YAML válidos estructuralmente, pero ello no prueba que ya estén cargados en el Zabbix desplegado.

---

# 9. Copias de seguridad y recuperación

El script de RL-MON-01 **no implementa una tarea programada de respaldo** ni exportación de la base Zabbix. Conserva `zbx_mysql`, Compose y secretos existentes, pero dicha conservación no equivale a una copia recuperable.

Para un plan de recuperación hacen falta al menos respaldo consistente de la **base MySQL exclusiva de Zabbix**, resguardo seguro del `compose.yaml`, secretos asociados y exportaciones de configuración (hosts/plantillas). Los secretos deben mantenerse fuera del repositorio y con acceso restringido. Antes de restaurar, identificar la versión efectiva de las imágenes y confirmar compatibilidad de la base respaldada. Probar la recuperación en un entorno controlado; no restaurar por encima de una pila activa sin una ventana autorizada.

El procedimiento «Implementación Backup y Restore DB» del ecosistema Laravel **no debe suponerse aplicable** al volumen MySQL de Zabbix, pues es una base diferente.

---

# 10. Administración y mantenimiento

En **RL-MON-01**:

```bash
cd /opt/recoleccionuy-zabbix/independiente-v1
sudo docker compose ps
sudo docker compose logs --tail=100
sudo docker compose config -q
```

Cualquier `docker compose restart`, `up` o actualización de imágenes puede interrumpir el monitoreo y debe coordinarse. El instalador permite reutilizar una pila existente preservando secretos, volúmenes y Compose, pero **no migra** automáticamente configuraciones heredadas con `.env`, puertos cambiados o secretos faltantes.

En los **Windows DC**, controlar estado del servicio, retención de eventos, configuración efectiva de auditoría y continuidad de políticas de firewall. Las versiones de agentes no se actualizan automáticamente; cambiar el MSI o el hash requiere revisión previa del procedimiento de instalación.

**Mantenimiento de reglas:** revisar en RL-FW-01 las políticas permanentes y runtime, y en RL-MON-01 las rich rules locales. Evitar cambios en NAT, filtros de otras pilas, o apertura global de 10050/10051/8088.

---

# 11. Diagnóstico y resolución de problemas

| Síntoma | Verificación respaldada | Dónde |
|---|---|---|
| No responde Zabbix Web | `docker compose ps/logs`, `curl -I http://192.168.20.20:8088/`, acceso desde estación autorizada y reglas efectivas | RL-MON-01, red y navegador |
| MySQL Zabbix no saludable | Estado de contenedor `mysql-server`, logs y secretos del proyecto | RL-MON-01 |
| Zabbix Server se reinicia | `docker compose logs zabbix-server`, disponibilidad de MySQL, digest/UID/ACL del secreto | RL-MON-01 |
| Puerto TCP/10051 inaccesible | Contenedor, publicación Docker, reglas locales, políticas `rec-zbx-dc-mon` y ruta | RL-MON-01, RL-FW-01 y DC |
| Puerto TCP/10050 inaccesible | Servicio Windows, escucha, regla local y política `rec-zbx-mon-dc` | DC, RL-FW-01 y RL-MON-01 |
| Instalación MSI rechazada | Ruta, nombre, SHA-256, firma digital, permisos y plataforma Windows | DC afectado |
| Servicio de agente inicia, pero sin datos | `ServerActive`, hostname coincidente con el host importado, acceso a 10051 e ítems activos | DC y Zabbix Web |
| Host no aparece | YAML creado/exportado pero pendiente de importación manual; revisar plantilla requerida | Zabbix Web |
| Fallan elementos `eventlog` | Existencia del canal Windows, permisos del servicio y auditoría efectiva/GPO | DC y Zabbix Web |
| Se ve el evento 4625 o 4771, pero no hay problema específico | Ambos se filtran/recogen; los YAML no definen disparadores dedicados | YAML y Zabbix Web |
| Firewall informa configuración permanente, pero no runtime | Recarga pendiente de autorización interactiva; no asumir política activa | RL-FW-01 |
| Acceso indebido a puertos publicados | Probar desde redes no autorizadas; Docker puede evitar la semántica esperada de reglas INPUT | RL-MON-01 y perímetro |
| No se envían avisos de problemas | No existen acciones/canales de notificación documentados en los YAML | Configuración Zabbix Web |

**Observaciones puntuales del código y documentación:**

1. **Coherencia documental:** La incorporación de Zabbix se encuentra reflejada en la documentación general actualizada de Recolección UY, incluyendo el README, el estado del proyecto, el instructivo y el orden de despliegue. La documentación técnica particular de cada servidor debe mantenerse alineada con los scripts Bash, PowerShell y archivos YAML vigentes.
2. **Resultado no totalmente automático:** el PowerShell siempre deja la **importación de hosts** en manos del operador. La advertencia ante fallos de escucha/10051 tampoco impide que informe fin del proceso.
3. **Seguridad pendiente de verificación externa:** el script central advierte que los puertos Docker pueden pasar controles distintos de firewalld, y que la autorización web debe implementarse por separado.
4. **Dependencia de versión:** los digest Docker deben verificarse contra la versión efectiva Zabbix 7.0, y la plantilla `Windows by Zabbix agent` debe estar disponible.
5. **Sin integración configurada con Grafana u OpenSearch:** compartir RL-MON-01 no implica que Zabbix envíe datos a esos componentes. No se ha identificado en estos scripts un datasource de Grafana para Zabbix ni envío de eventos Zabbix a OpenSearch.

---

# 12. Anexos

Sección reservada para incorporar información complementaria de Zabbix que se documente y verifique posteriormente.