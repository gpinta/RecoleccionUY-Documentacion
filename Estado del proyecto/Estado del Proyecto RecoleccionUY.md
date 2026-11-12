# Recolección UY — Estado del proyecto y documentación técnica

**Actualización:** 12/11/2026 — Actualización de la documentación de monitoreo con Zabbix Server y agentes Windows para los controladores de dominio.

**Alcance:** Aplicación Ciudadana (`recoleccion-api`), Backend Administrativo (`recoleccion-admin`), Aplicación Camiones (`recoleccion-camiones`) e infraestructura.  

**Base documental:** Código fuente de las tres aplicaciones, documentación técnica de aplicaciones, servidores y scripts.


## Índice

- [1. Contexto y finalidad del proyecto](#1-contexto-y-finalidad-del-proyecto)
  - [1.1. Modernizando la gestión urbana](#11-modernizando-la-gestión-urbana)
- [2. Resumen ejecutivo y estado](#2-resumen-ejecutivo-y-estado)
- [3. Aplicación Ciudadana (`recoleccion-api`)](#3-aplicación-ciudadana-recoleccion-api)
  - [3.1. Objetivo y funcionalidades](#31-objetivo-y-funcionalidades)
  - [3.2. Validación y seguridad](#32-validación-y-seguridad)
  - [3.3. Rutas y componentes principales](#33-rutas-y-componentes-principales)
- [4. Backend Administrativo (`recoleccion-admin`)](#4-backend-administrativo-recoleccion-admin)
  - [4.1. Objetivo y funcionalidades](#41-objetivo-y-funcionalidades)
  - [4.2. Permisos y tareas programadas](#42-permisos-y-tareas-programadas)
  - [4.3. Archivos principales](#43-archivos-principales)
- [5. Aplicación Camiones (`recoleccion-camiones`)](#5-aplicación-camiones-recoleccion-camiones)
  - [5.1. Objetivo y funcionalidades](#51-objetivo-y-funcionalidades)
  - [5.2. Rutas y componentes](#52-rutas-y-componentes)
- [6. Reglas de negocio compartidas](#6-reglas-de-negocio-compartidas)
  - [6.1. Estados de denuncia](#61-estados-de-denuncia)
  - [6.2. Reclamos](#62-reclamos)
  - [6.3. Asignación y resolución](#63-asignación-y-resolución)
- [7. Base de datos compartida](#7-base-de-datos-compartida)
  - [7.1. Conexión entre contenedores](#71-conexión-entre-contenedores)
  - [7.2. Persistencia y almacenamiento](#72-persistencia-y-almacenamiento)
- [8. Arquitectura e infraestructura](#8-arquitectura-e-infraestructura)
  - [8.1. Segmentos y servidores](#81-segmentos-y-servidores)
  - [8.2. Publicación de servicios](#82-publicación-de-servicios)
  - [8.3. Active Directory, DNS y DHCP](#83-active-directory-dns-y-dhcp)
  - [8.4. Monitoreo y registros](#84-monitoreo-y-registros)
- [9. Stack tecnológico](#9-stack-tecnológico)
- [10. Orden de despliegue documentado](#10-orden-de-despliegue-documentado)


## 1. Contexto y finalidad del proyecto

### 1.1. Modernizando la gestión urbana

Los servicios de recolección de residuos requieren canales claros para reportar incidencias, un seguimiento consistente y coordinación entre ciudadanía, administración y personal operativo. Recolección UY aborda estas necesidades mediante un ecosistema modular que separa responsabilidades y conecta los procesos a través de información compartida.

**Ciudadanía** registra denuncias, selecciona ubicaciones y adjunta fotografías. **Administración municipal** supervisa la cartera de denuncias, asigna camiones y decide sobre reclamos. **Camiones** ejecuta las asignaciones y registra el resultado con evidencias. La trazabilidad depende de mantener diferenciados el estado de cada denuncia, el estado de su asignación y los registros de reclamaciones y fotografías.

La solución conserva aplicaciones autónomas desde el punto de vista del código y despliegue, aunque exige coordinación de cambios porque comparten esquema MySQL y recursos persistentes.

## 2. Resumen ejecutivo y estado

Recolección UY digitaliza la presentación ciudadana de denuncias vinculadas a la recolección de residuos, su administración municipal y la ejecución de asignaciones por personal de camiones. Consta de **tres aplicaciones Laravel independientes** que comparten **una base de datos MySQL 8.0** y determinados volúmenes de fotografías.

| Aplicación | Código | Función | Publicación declarada en Docker Compose |

|---|---|---|---|

| Ciudadana | `recoleccion-api` | Registro, denuncias, seguimiento, reclamos y API REST | `192.168.30.20:8080` |

| Backend Administrativo | `recoleccion-admin` | Gestión municipal, LDAP, flota, geografía y asignaciones | `192.168.30.20:8081` |

| Camiones | `recoleccion-camiones` | Ejecución de trabajos, estados y evidencias de resolución | `192.168.30.20:8082` |

**Estado comunicado por el proyecto:** aplicaciones e infraestructura desplegadas, funcionando y testeadas; scripts ejecutados satisfactoriamente. **Alcance de la presente revisión:** se verificó la presencia de código y configuraciones suministradas.

**Backup y restore:** El 09/11/2026 se documenta la implementación del sistema de respaldo automático y restauración de la base de datos MySQL `recoleccion` y del almacenamiento persistente de fotografías de denuncias y resoluciones.

El respaldo se ejecuta mediante un script Bash administrado por un servicio y un temporizador systemd, sin utilizar crontab.

La restauración se realiza mediante un script Bash independiente que verifica la integridad de los respaldos, conserva copias de emergencia y requiere confirmación administrativa antes de reemplazar datos.

Los archivos del módulo se organizan en `Scripts/Linux/RL-APP-DB_Backup_and_Restore/`.

La implementación pertenece a la infraestructura de RL-APP-01 y no modifica el código de las tres aplicaciones Laravel.

**Regla de mantenimiento:** los repositorios permanecen separados. Cualquier cambio en una tabla compartida, almacenamiento o reglas de estado requiere análisis de impacto sobre las tres aplicaciones antes de su aplicación.

## 3. Aplicación Ciudadana (`recoleccion-api`)

### 3.1. Objetivo y funcionalidades

Es la plataforma web y API REST dirigida a la ciudadanía:

- Registro con documento de identidad y datos personales; autenticación web por sesión y API mediante **Laravel Sanctum**.

- Gestión de sesiones y tokens API, con cierre de sesión actual, cierre de todas las sesiones y revocación de tokens individuales.

- Dashboard con indicadores de denuncias del ciudadano.

- Creación de denuncias con dirección, barrio, coordenadas, descripción opcional y **1 a 5 fotografías**.

- Ubicación mediante **Leaflet, OpenStreetMap y Nominatim**. El municipio se determina desde el barrio seleccionado, no por confianza en un campo enviado por el cliente.

- Listado paginado, consulta de detalle y fotografías privadas de las denuncias propias.

- Presentación de reclamos autorizados, cambios de estado y conservación de evidencias de trabajos resueltos.

- Consulta pública de denuncias; edición y eliminación de cuenta conforme a las reglas implementadas.

- Consulta pública de catálogos de municipios y barrios.

### 3.2. Validación y seguridad

`StoreDenunciaRequest.php` exige `barrio_id`, dirección, latitud entre `-35` y `-30`, longitud entre `-58` y `-53`, y de una a cinco imágenes JPEG/PNG, de hasta 5 MiB por archivo y dimensiones máximas de 8000 × 8000. La descripción es opcional y admite hasta 5000 caracteres.

`DenunciaPolicy.php` limita el acceso a denuncias propias; las ajenas se responden como no encontradas. `ReclamarDenunciaRequest.php` exige un comentario de 10 a 1000 caracteres y delega la autorización de dominio a la política.

| Operación | Límite configurado |

|---|---|

| Registro web y API | `throttle:3,10` (3 solicitudes cada 10 minutos) |

| Inicio de sesión web y API | `throttle:5,1` (5 solicitudes por minuto) |

| Consulta pública web y API | `throttle:30,1` (30 solicitudes por minuto) |

Las fotografías ciudadanas se almacenan con acceso controlado, servido por controladores específicos y no deben considerarse archivos públicos por su mera existencia en un volumen Docker.

### 3.3. Rutas y componentes principales

**Web:** `/register`, `/login`, `/dashboard`, `/denuncias`, `/denuncias/create`, `/denuncias/{id}`, `/denuncias/{id}/reclamar`, `/profile` y `/consulta`.

**API:** `/api/register`, `/api/login`, `/api/municipios`, `/api/barrios`, `/api/consulta/{denuncia}`. Bajo `auth:sanctum` se encuentran `/api/me`, `/api/dashboard`, `/api/denuncias`, `/api/logout`, `/api/logout-all`, `/api/sessions` y las operaciones relacionadas con sesiones, fotografías y reclamos.

Archivos representativos:

- `routes/web.php` y `routes/api.php`

- `app/Http/Controllers/Web/DenunciaController.php`

- `app/Http/Controllers/Api/DenunciaController.php`

- `app/Http/Requests/StoreDenunciaRequest.php`

- `app/Http/Requests/ReclamarDenunciaRequest.php`

- `app/Policies/DenunciaPolicy.php`

- `app/Services/DenunciaPhotoService.php`

- `app/Enums/DenunciaEstado.php`

## 4. Backend Administrativo (`recoleccion-admin`)

### 4.1. Objetivo y funcionalidades

Panel municipal para seguimiento y control operativo:

- Autenticación de personal contra **Active Directory / LDAP** mediante **LdapRecord**.

- Autorización separada en tres perfiles: **Reader**, **Operator** y **Admin**.

- Dashboard con métricas de denuncias y flota.

- Listado, filtros, detalle, fotografías, mapa, reclamaciones y edición de denuncias conforme a permisos.

- Asignación manual de denuncias a camiones compatibles y asignación automática considerando municipio, camión activo y carga de trabajo.

- Gestión de camiones, municipios y barrios.

- Consulta de asignaciones, comentarios y evidencias fotográficas de resolución.

- Finalización automatizada de denuncias resueltas conforme al plazo de dominio.

Los grupos de autorización se parametrizan mediante:

```dotenv

ADMIN_LDAP_READERS_GROUP_DN=...

ADMIN_LDAP_OPERATORS_GROUP_DN=...

ADMIN_LDAP_ADMINS_GROUP_DN=...

```

Este esquema de tres grupos **sustituye** la referencia anterior a un único grupo `ADMIN_LDAP_GROUP_DN`. Los nombres indicados son variables, no credenciales.

### 4.2. Permisos y tareas programadas

`AdminRole.php` define los valores `reader`, `operator` y `admin`. La política de denuncias permite la lectura a perfiles habilitados y operaciones de estado/asignación a Operator o Admin con restricciones por estado; ciertas modificaciones y eliminación se reservan a Admin. La creación de denuncias desde Admin está denegada por la política: su origen es Ciudadana.

El comando `denuncias:finalizar-vencidas`, implementado en `app/Console/Commands/FinalizarDenunciasVencidas.php`, está registrado en `routes/console.php` con periodicidad **cada minuto** y `withoutOverlapping(5)`. Su ejecución periódica efectiva depende de que el planificador Laravel esté activado en el entorno de ejecución.

### 4.3. Archivos principales

- `routes/web.php`

- `app/Http/Controllers/Admin/DenunciaController.php`

- `app/Http/Controllers/Admin/CamionController.php`

- `app/Http/Controllers/Admin/MunicipioController.php`

- `app/Http/Controllers/Admin/BarrioController.php`

- `app/Http/Controllers/Admin/FotoResolucionController.php`

- `app/Http/Controllers/Admin/AuthController.php`

- `app/Http/Middleware/EnsureBackendRole.php`

- `app/Enums/AdminRole.php` y `app/Enums/DenunciaEstado.php`

- `app/Policies/DenunciaPolicy.php`

- `app/Console/Commands/FinalizarDenunciasVencidas.php`

- `routes/console.php`

## 5. Aplicación Camiones (`recoleccion-camiones`)

### 5.1. Objetivo y funcionalidades

Aplicación web operativa para los usuarios vinculados a camiones municipales:

- Inicio y cierre de sesión.

- Dashboard de trabajos y asignaciones.

- Listado paginado y detalle de tareas.

- Inicio y finalización de asignaciones.

- Incorporación de comentarios y fotografías de resolución.

- Consulta de fotografías mediante controladores autorizados.

- Conservación del historial de trabajos resueltos y sus evidencias.

- Restricción de operaciones sobre denuncias reclamadas y exclusión operativa de asignaciones rechazadas.

La zona autenticada usa los middleware `auth` y `camion.activo`; este último comprueba que el usuario del camión continúa habilitado y, si no lo está, cierra la sesión.

### 5.2. Rutas y componentes

Rutas web: `/login`, `/dashboard`, `/asignaciones`, `/asignaciones/{asignacion}`, `/asignaciones/{asignacion}/iniciar`, `/asignaciones/{asignacion}/finalizar` y `/asignaciones/{asignacion}/fotos/{foto}`.

Archivos principales:

- `routes/web.php`

- `app/Http/Controllers/AuthController.php`

- `app/Http/Controllers/DashboardController.php`

- `app/Http/Controllers/AsignacionController.php`

- `app/Http/Controllers/FotoResolucionController.php`

- `app/Http/Middleware/EnsureCamionActivo.php`

- `app/Http/Requests/FinalizarAsignacionRequest.php`

- `app/Models/CamionUser.php`, `DenunciaCamion.php` y `FotoResolucion.php`

## 6. Reglas de negocio compartidas

### 6.1. Estados de denuncia

Los códigos persistidos identificados en los enums de Ciudadana y Admin son:

| Estado | Significado |

|---|---|

| `pendiente` | Denuncia ingresada, pendiente de atención |

| `en_proceso` | Denuncia en tratamiento |

| `resuelto` | Trabajo informado como resuelto |

| `reclamado` | Reclamo ciudadano a revisar administrativamente |

| `rechazado` | Denuncia rechazada mediante decisión administrativa |

| `finalizado` | Cierre de una denuncia resuelta tras el plazo establecido |

**Importante:** el estado general de `denuncias` no es equivalente al estado operativo de cada registro de `denuncia_camion`. Son procesos diferentes y sus actualizaciones deben conservar la coherencia entre aplicaciones.

### 6.2. Reclamos

La denuncia es reclamable solo por su titular y bajo condiciones temporales y de estado. Conforme a la política documentada:

- En `pendiente` o `en_proceso`, el reclamo se habilita después de **48 horas** desde el cambio de estado relevante.

- En `resuelto`, el reclamo puede efectuarse **durante la primera hora** posterior al cambio de estado.

- En `reclamado`, `rechazado` o `finalizado`, no procede un nuevo reclamo.

Un reclamo válido crea una reclamación, actualiza la denuncia a `reclamado` y su marca `estado_cambiado_at`. Las asignaciones activas `pendiente` o `en_proceso` se cierran como `rechazado`; las ya resueltas y sus evidencias se conservan. La continuidad o el rechazo queda bajo decisión administrativa.

### 6.3. Asignación y resolución

La asignación manual y automática corresponde a Admin; la ejecución y carga de evidencia corresponde a Camiones. Las tres aplicaciones deben respetar la misma base de datos, referencias territoriales y estados persistidos.

La finalización automática de denuncias `resuelto` se procesa desde Admin según la constante de plazo implementada en el modelo y el comando programado. No se debe asumir que una denuncia `reclamado` se finaliza automáticamente.

## 7. Base de datos compartida

Las tres aplicaciones usan **MySQL 8.0** y la base configurada con nombre `recoleccion`. Las migraciones presentes en la Aplicación Ciudadana comprenden:

- `users`, `personal_access_tokens` y tablas de soporte Laravel.

- `municipios`, `barrios`.

- `denuncias`, `fotos_denuncia`, `reclamaciones`.

- `camiones`, `denuncia_camion`, `fotos_resolucion`, `camion_user`.

Los modelos en Admin y Camiones corresponden a entidades de esta base. No se debe ejecutar una migración nueva que altere tablas compartidas sin comprobar las dependencias de los tres proyectos y el estado real del esquema en MySQL.

### 7.1. Conexión entre contenedores

Los tres Compose declaran la red externa `recoleccion-db-net` y la base `recoleccion`:

| Aplicación | `DB_HOST` en Compose | Observación |

|---|---|---|

| Ciudadana | `db` | Define el servicio MySQL `db` y el contenedor `recoleccion_db` |

| Admin | `recoleccion_db` | Referencia al nombre del contenedor MySQL en la red común |

| Camiones | `db` | Utiliza el nombre del servicio MySQL de Ciudadana |

Esta diferencia en el hostname **no demuestra que existan bases diferentes**. El alias `db` y el nombre `recoleccion_db` deben resolver al mismo servidor en la red Docker efectiva. El funcionamiento fue informado como probado; la resolución DNS en ejecución no se revalidó aquí.

La base se comunica por la red privada Docker en el puerto interno `3306`; no es necesario publicar este puerto en el host.

### 7.2. Persistencia y almacenamiento

- **Fotografías ciudadanas:** el Compose de Ciudadana y Admin monta `/srv/recoleccion-data/fotos` como `/var/www/shared-denuncias`.

- **Evidencias de Camiones:** el Compose de Camiones monta el mismo directorio del host como `/var/www/shared-fotos`.

- **MySQL:** Ciudadana define el volumen `db_data` para `/var/lib/mysql`.

- **Aplicación Ciudadana:** se define además `storage_data` para almacenamiento de aplicación.

Las rutas internas son diferentes porque cada aplicación tiene una responsabilidad distinta; no deben confundirse con proyectos intercambiables. Mantener controles de acceso a archivos y copias de seguridad del volumen de base y de las fotografías. **No ejecutar `docker compose down -v`** sin autorización expresa y una evaluación de pérdida de datos.

**Respaldo y recuperación de datos compartidos:**

Se implementó en RL-APP-01 un sistema de respaldo automático de los dos componentes de información compartida:

| Componente | Origen | Respaldo |
|---|---|---|
| Base de datos | MySQL `recoleccion`, contenedor `recoleccion_db` | `database.sql.gz` |
| Fotografías | `/srv/recoleccion-data/fotos/` | `fotos.tar.gz` |
| Integridad | Archivos generados en cada ejecución | `SHA256SUMS` |

Los respaldos se almacenan en `/var/backups/recoleccion-uy/`, dentro de directorios identificados por fecha y hora.

El servicio `recoleccion-uy-backup.service` y el temporizador `recoleccion-uy-backup.timer` administran la ejecución automática.

El script `recoleccion-uy-restore.sh` permite recuperar la base de datos y las fotografías desde un respaldo seleccionado, durante una ventana de mantenimiento.

La versión implementada no contempla eliminación automática de respaldos antiguos ni copia automática hacia almacenamiento externo.

## 8. Arquitectura e infraestructura

### 8.1. Segmentos y servidores

| Segmento | Red | Gateway | Componentes |

|---|---|---|---|

| SERVICIOS | `192.168.10.0/24` | `192.168.10.1` | `WS-DC-01` (`192.168.10.20`), `WS-DC-02` (`192.168.10.21`) |

| MONITOREO | `192.168.20.0/24` | `192.168.20.1` | `RL-MON-01` (`192.168.20.20`) |

| APLICACIONES | `192.168.30.0/24` | `192.168.30.1` | `RL-APP-01` (`192.168.30.20`) |

| DMZ | `192.168.50.0/24` | `192.168.50.1` | `RL-PROXY-01` (`192.168.50.20`) |

**Dominio interno documentado:** `neltek.uy`.

`RL-FW-01` enruta y filtra los segmentos. Sus interfaces documentadas son `ens33` (WAN), `ens36` (SERVICIOS), `ens37` (MONITOREO), `ens38` (APLICACIONES) y `ens39` (DMZ). La IP WAN efectiva no se fija en la documentación consultada.

### 8.2. Publicación de servicios

```text

Cliente externo (HTTPS / TCP 443)

   |

   v

RL-FW-01 (NAT/DNAT y filtrado)

   |

   v

RL-PROXY-01 (DMZ)

   |

   v

WAF ModSecurity / OWASP CRS

   |  Termina TLS (HTTPS público :443)

   |  Reenvía por HTTP interno

   v

Nginx (proxy inverso, HTTP interno :80)

   |

   +--> HTTP --> RL-APP-01:8080 (Ciudadana)

   +--> HTTP --> RL-APP-01:8081 (Backend Administrativo)

   +--> HTTP --> RL-APP-01:8082 (Camiones)

                      |

                      v

               recoleccion-db-net

                      |

                      v

                  MySQL 8.0

```

**HTTPS externo y HTTP interno:** esta separación es **deliberada y está implementada en los scripts**, no constituye una contradicción con que los contenedores Laravel utilicen `APP_URL` con esquema `http\://`. El cliente se conecta mediante HTTPS al WAF, que termina TLS; desde allí la comunicación hacia el Nginx interno y luego hacia las aplicaciones utiliza HTTP dentro de la infraestructura.

La implementación se documenta específicamente en los scripts de `Scripts/Linux/RL-PROXY-01/`:

- `3-RL-PROXY-config_proxy_http.sh`: configura Nginx como proxy HTTP hacia `192.168.30.20:8080`, `:8081` y `:8082`.

- `4-RL-PROXY-install_WAF.sh`: despliega el WAF delante de Nginx con el destino interno `http\://nginx:80`.

- `5-RL-PROXY-generar_certificados_tls.sh`: genera/prepara los certificados, pero no activa HTTPS por sí mismo.

- `6-RL-PROXY-migrar_waf_https.sh`: migra la publicación del WAF a `443` externo → `8443` del contenedor, conserva Nginx interno sin puertos publicados y comprueba el acceso HTTPS a los tres dominios. También comprueba que el puerto HTTP público `80` quede cerrado.

- `7-RL-PROXY-FIX_nginx.sh`: modifica `X-Forwarded-Proto` para propagar el encabezado recibido desde el WAF (`$http_x_forwarded_proto`) en lugar del protocolo HTTP de la conexión interna (`$scheme`).

Por tanto, **la publicación pública es HTTPS y el transporte entre el WAF, el proxy interno y las aplicaciones es HTTP**. La cabecera `X-Forwarded-Proto` permite trasladar información del protocolo original a la aplicación. La configuración de confianza en los proxies sigue siendo relevante para que Laravel interprete correctamente dicha cabecera, pero la existencia de `APP_URL=http\://...` en los Compose no prueba, por sí sola, un problema con el HTTPS público.

**WAF:** ModSecurity y OWASP CRS están documentados en modo `DetectionOnly`: **registran detecciones, pero no bloquean solicitudes por esas reglas**. No presentarlo como prevención activa de ataques. `dnsmasq` conserva DNS TCP/UDP 53 de forma independiente del flujo HTTP.

### 8.3. Active Directory, DNS y DHCP

- `WS-DC-01` y `WS-DC-02` prestan servicios de AD DS y DNS, con procedimientos documentados para configuración, grupos y replicación.

- Se incluyen scripts PowerShell para políticas de dominio, controles de acceso y registros DNS de los servicios.

- La configuración efectiva de ámbitos DHCP, failover y relay depende de los procedimientos y parámetros de la instalación; el proyecto declara ejecución y pruebas, pero en esta revisión no se consultó el estado vivo de dichos servicios.

- El acceso a Admin desde WAN debe respetar la política de publicación aprobada.

### 8.4. Monitoreo y registros

El entorno documenta:

- **Prometheus y Grafana:** métricas y visualización.

- **Node Exporter:** métricas del sistema operativo de MON, APP y PROXY; no implica métricas detalladas individuales de cada contenedor.

- **OpenSearch y Fluent Bit:** centralización y consulta de registros.

- **Zabbix Server y Zabbix Agent:** supervisión de disponibilidad y eventos de los controladores de dominio `WS-DC-01` y `WS-DC-02`, incluyendo seguridad, Active Directory, DNS y replicación DFS.

Los scripts de infraestructura están incluidos en el directorio `Scripts/`, organizados por sistema operativo y servidor. Sus procedimientos se describen en la documentación técnica correspondiente a `RL-MON-01`, `RL-APP-01`, `RL-PROXY-01`, `WS-DC-01` y `WS-DC-02`.

## 9. Stack tecnológico

| Capa | Tecnología |

|---|---|

| Lenguaje | PHP 8.2+ |

| Framework de las aplicaciones | Laravel 12, según definición vigente del proyecto |

| Base de datos | **MySQL 8.0** |

| Autenticación ciudadana/API | Sesiones Laravel y Sanctum |

| Autenticación administrativa | LdapRecord, LDAP y Active Directory |

| Autenticación Camiones | Sesiones Laravel y comprobación de camión activo |

| Presentación | Blade y Tailwind CSS |

| Mapas y geocodificación | Leaflet, OpenStreetMap y Nominatim |

| Infraestructura de aplicaciones | Docker y Docker Compose; contenedores web con Apache según documentación |

| Proxy y WAF | Nginx, ModSecurity y OWASP CRS |

| Sistemas operativos de infraestructura | Rocky Linux 9; controladores Windows Server conforme a documentación de servidores |

| Observabilidad | Prometheus, Grafana, Node Exporter, OpenSearch, Fluent Bit, Zabbix Server y Zabbix Agent |

| Versionado | Git |

## 10. Orden de despliegue documentado

1. **WS-DC-01:** red, AD DS, DNS, DHCP, OU, grupos y políticas, de acuerdo con los scripts de Windows Server.

2. **WS-DC-02:** incorporación como controlador adicional, DNS y comprobación de replicación.

3. **RL-FW-01:** interfaces, rutas, reglas `firewalld`, NAT/DNAT e integración al dominio.

4. **RL-APP-01:** actualización, integración AD/DNS, almacenamiento de fotografías, red Docker, Node Exporter y Fluent Bit.

5. **Aplicaciones:** despliegue independiente de Ciudadana (`8080`), Admin (`8081`) y Camiones (`8082`), asegurando la red externa y el acceso a MySQL.

6. **RL-PROXY-01:** configuración de Nginx como proxy HTTP interno, instalación del WAF, generación de certificados TLS, publicación HTTPS externa en el WAF y ajuste de `X-Forwarded-Proto`, además de agentes de observabilidad.

7. **Publicación y control:** comprobar acceso HTTPS externo al WAF por `443`, cierre del HTTP público por `80`, comunicación HTTP interna entre WAF/Nginx/aplicaciones, certificados, cabeceras de proxy, política WAN y registros WAF.

8. **SSH:** aplicar configuraciones seguras y comprobar un segundo acceso antes de cerrar la sesión activa.

9. **RL-MON-01:** Prometheus, Grafana, OpenSearch y Zabbix Server. Completar las políticas Zabbix en `RL-FW-01`, instalar los agentes en `WS-DC-01` y `WS-DC-02`, importar los archivos YAML y verificar la recepción de datos y eventos.

El orden refleja los procedimientos existentes, no una orden de reinstalación. Ante cambios, ejecutar únicamente los pasos necesarios y preservar datos y servicios productivos.
