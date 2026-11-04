# Documentación Técnica del Servidor RL-MON-01

**Fecha de creación:** 03/11/2026  
**Proyecto:** Recolección UY  
**Servidor:** `RL-MON-01`  
**Estado documentado:** infraestructura implementada y operativa.

---

## Índice

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-información-general)
  - [1.2. Rol del servidor](#12-rol-del-servidor)
  - [1.3. Justificación del sistema operativo](#13-justificación-del-sistema-operativo)
- [2. Ejecución de Scripts](#2-ejecución-de-scripts)
  - [2.1. Orden de ejecución](#21-orden-de-ejecución)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos del servidor](#23-scripts-específicos-del-servidor)
    - [2.3.1. `1-RL-MON-update.sh`](#231-1-rl-mon-updatesh)
    - [2.3.2. `2-RL-MON-config_domain_2dns_v1.3.sh`](#232-2-rl-mon-config_domain_2dns_v13sh)
    - [2.3.3. `3-RL-MON-monitoreo.sh`](#233-3-rl-mon-monitoreosh)
    - [2.3.4. `4-RL-MON-OpenSearch.sh`](#234-4-rl-mon-opensearchsh)
    - [2.3.5. `RL-MON-add_dashboard_general.sh`](#235-rl-mon-add_dashboard_generalsh)
  - [2.4. Scripts comunes a los servidores Linux](#24-scripts-comunes-a-los-servidores-linux)
    - [2.4.1. `1-RL-XXX-config_ssh.sh`](#241-1-rl-xxx-config_sshsh)
    - [2.4.2. `2-RL-XXX-config_ssh_users.sh`](#242-2-rl-xxx-config_ssh_userssh)
- [3. Arquitectura y componentes del servidor](#3-arquitectura-y-componentes-del-servidor)
  - [3.1. Arquitectura general](#31-arquitectura-general)
  - [3.2. Dependencias](#32-dependencias)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
  - [4.1. Interfaz y direccionamiento](#41-interfaz-y-direccionamiento)
  - [4.2. Puertos y protocolos](#42-puertos-y-protocolos)
  - [4.3. Comprobación de conectividad](#43-comprobación-de-conectividad)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
  - [5.1. Servicios](#51-servicios)
  - [5.2. Inspección precisa de los contenedores](#52-inspección-precisa-de-los-contenedores)
  - [5.3. Administración segura](#53-administración-segura)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
  - [6.1. Directorios de sistema conocidos](#61-directorios-de-sistema-conocidos)
  - [6.2. Persistencia y permisos](#62-persistencia-y-permisos)
- [7. Base de datos MySQL](#7-base-de-datos-mysql)
  - [7.1. Aplicación al servidor](#71-aplicación-al-servidor)
- [8. Seguridad y control de acceso](#8-seguridad-y-control-de-acceso)
  - [8.1. Active Directory y SSSD](#81-active-directory-y-sssd)
  - [8.2. SSH y administración](#82-ssh-y-administración)
  - [8.3. Firewalld y SELinux](#83-firewalld-y-selinux)
- [9. Monitoreo y registros](#9-monitoreo-y-registros)
  - [9.1. Métricas: Prometheus, Grafana y Node Exporter](#91-métricas-prometheus-grafana-y-node-exporter)
  - [9.2. Registros: Fluent Bit, OpenSearch y Dashboards](#92-registros-fluent-bit-opensearch-y-dashboards)
  - [9.3. Distinción entre métricas y logs](#93-distinción-entre-métricas-y-logs)
- [10. Copias de seguridad y recuperación](#10-copias-de-seguridad-y-recuperación)
  - [10.1. Información que debe protegerse](#101-información-que-debe-protegerse)
  - [10.2. Procedimiento operativo](#102-procedimiento-operativo)
  - [10.3. Recuperación](#103-recuperación)
- [11. Administración y mantenimiento](#11-administración-y-mantenimiento)
  - [11.1. Sistema operativo](#111-sistema-operativo)
  - [11.2. Contenedores](#112-contenedores)
  - [11.3. Grafana y OpenSearch](#113-grafana-y-opensearch)
- [12. Diagnóstico y resolución de problemas](#12-diagnóstico-y-resolución-de-problemas)
  - [12.1. Red, rutas y DNS](#121-red-rutas-y-dns)
  - [12.2. Dominio y SSH](#122-dominio-y-ssh)
  - [12.3. Prometheus y Grafana](#123-prometheus-y-grafana)
  - [12.4. OpenSearch y Fluent Bit](#124-opensearch-y-fluent-bit)
  - [12.5. Almacenamiento y servicios](#125-almacenamiento-y-servicios)
- [13. Anexos](#13-anexos)

---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor |
|---|---|
| Nombre del servidor | `RL-MON-01` |
| Sistema operativo | Rocky Linux 9 |
| Interfaz de red | `ens33` |
| Segmento | MONITOREO — `192.168.20.0/24` |
| Dirección IP | `192.168.20.20` |
| Máscara de subred | `255.255.255.0` (`/24`) |
| Gateway | `192.168.20.1` (RL-FW-01) |
| DNS primario | `192.168.10.20` (WS-DC-01) |
| DNS secundario | `192.168.10.21` (WS-DC-02) |
| Dominio | `neltek.uy` |

El servidor cuenta con una interfaz de red de la VM destinada al segmento MONITOREO. La comunicación con otros segmentos atraviesa RL-FW-01.

## 1.2. Rol del servidor

RL-MON-01 centraliza las **métricas, paneles y registros** de la infraestructura Recolección UY. Opera Prometheus, Grafana, Node Exporter local, OpenSearch, OpenSearch Dashboards y Fluent Bit local, y recibe información procedente de agentes instalados en RL-APP-01 y RL-PROXY-01.

Prometheus consulta las métricas exportadas por los hosts; Grafana las representa. Fluent Bit remite registros a OpenSearch, donde pueden consultarse mediante OpenSearch Dashboards. El dashboard general de Grafana reúne la observación de múltiples servidores en una misma vista.

## 1.3. Justificación del sistema operativo

Rocky Linux 9 proporciona estabilidad, administración remota, controles SELinux/Firewalld, soporte de Docker y compatibilidad con realmd, SSSD y los servicios de Active Directory. La ejecución en contenedores facilita separar los componentes de observabilidad del sistema operativo anfitrión.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución

Los scripts exclusivos de RL-MON-01 se ejecutan primero. Los scripts compartidos de `Scripts/Linux/RL-XXX-XX/` son **siempre los últimos**.

| Orden | Script exacto | Función |
|---|---|---|
| 1 | `1-RL-MON-update.sh` | Prepara Rocky Linux 9, actualiza paquetes e incorpora dependencias de sistema, administración y Docker Engine/Compose. |
| 2 | `2-RL-MON-config_domain_2dns_v1.3.sh` | Configura la interfaz ens33 con direccionamiento fijo e integra RL-MON-01 con Active Directory. |
| 3 | `3-RL-MON-monitoreo.sh` | Despliega el sistema de métricas: Prometheus, Grafana y Node Exporter local. |
| 4 | `4-RL-MON-OpenSearch.sh` | Despliega centralización y consulta de registros con OpenSearch, OpenSearch Dashboards y Fluent Bit local. |
| 5 | `RL-MON-add_dashboard_general.sh` | Incorpora un dashboard general que reúne métricas de los servidores del laboratorio. |
| 6 | `1-RL-XXX-config_ssh.sh` | Establece las políticas de administración SSH comunes de los servidores Linux. |
| 7 | `2-RL-XXX-config_ssh_users.sh` | Gestiona claves públicas SSH para usuarios autorizados de Active Directory. |

## 2.2. Procedimiento general

Ejecutar desde el directorio donde se encuentra cada script, respetando el orden del apartado 2.1. Para cada archivo realizar normalización de terminaciones de línea, habilitar su ejecución y ejecutarlo con privilegios:

```bash
sed -i 's/\r$//' script.sh
chmod +x script.sh
sudo ./script.sh
```

En cada apartado siguiente se proporciona el comando con el nombre exacto. En cambios de dominio o SSH mantener una consola de administración alternativa operativa.

## 2.3. Scripts específicos del servidor

### 2.3.1. `1-RL-MON-update.sh`

**Nombre del script:** `1-RL-MON-update.sh`.

**Descripción:** Prepara Rocky Linux 9, actualiza paquetes e incorpora dependencias de sistema, administración y Docker Engine/Compose.

**Componentes que instala o utiliza:** Rocky Linux, herramientas base y componentes Docker.

**Componentes que configura:** Servicios básicos y habilitación de Docker y componentes de soporte.

**Archivos y directorios creados, modificados o utilizados:** Las rutas de instalación de paquetes son administradas por DNF; no se atribuyen directorios exclusivos sin el script.

**Requisitos previos:** Acceso administrativo y repositorios de paquetes disponibles.

**Ejecución:**

```bash
sed -i 's/\r$//' 1-RL-MON-update.sh
chmod +x 1-RL-MON-update.sh
sudo ./1-RL-MON-update.sh
```

### 2.3.2. `2-RL-MON-config_domain_2dns_v1.3.sh`

**Nombre del script:** `2-RL-MON-config_domain_2dns_v1.3.sh`.

**Descripción:** Configura la interfaz ens33 con direccionamiento fijo e integra RL-MON-01 con Active Directory.

**Componentes que instala o utiliza:** Utiliza realmd, Kerberos, SSSD, oddjob y utilidades del dominio.

**Componentes que configura:** IP 192.168.20.20/24, gateway 192.168.20.1, DNS 192.168.10.20 y 192.168.10.21, hostname y dominio neltek.uy.

**Archivos y directorios creados, modificados o utilizados:** Gestiona la configuración de NetworkManager y SSSD; los nombres de perfiles generados deben consultarse en el host.

**Requisitos previos:** Dependencias de los scripts anteriores; acceso al recurso o red correspondiente.

**Ejecución:**

```bash
sed -i 's/\r$//' 2-RL-MON-config_domain_2dns_v1.3.sh
chmod +x 2-RL-MON-config_domain_2dns_v1.3.sh
sudo ./2-RL-MON-config_domain_2dns_v1.3.sh
```

### 2.3.3. `3-RL-MON-monitoreo.sh`

**Nombre del script:** `3-RL-MON-monitoreo.sh`.

**Descripción:** Despliega el sistema de métricas: Prometheus, Grafana y Node Exporter local.

**Componentes que instala o utiliza:** Contenedores de Prometheus, Grafana y Node Exporter.

**Componentes que configura:** Targets de los servidores, Grafana 192.168.20.20:3000 y Prometheus 127.0.0.1:9090.

**Archivos y directorios creados, modificados o utilizados:** Los archivos Compose, configuración y datos persistentes corresponden al despliegue de monitoreo; sus rutas exactas no están identificadas en la evidencia consultada.

**Requisitos previos:** Dependencias de los scripts anteriores; acceso al recurso o red correspondiente.

**Ejecución:**

```bash
sed -i 's/\r$//' 3-RL-MON-monitoreo.sh
chmod +x 3-RL-MON-monitoreo.sh
sudo ./3-RL-MON-monitoreo.sh
```

### 2.3.4. `4-RL-MON-OpenSearch.sh`

**Nombre del script:** `4-RL-MON-OpenSearch.sh`.

**Descripción:** Despliega centralización y consulta de registros con OpenSearch, OpenSearch Dashboards y Fluent Bit local.

**Componentes que instala o utiliza:** Contenedores de OpenSearch, Dashboards y Fluent Bit.

**Componentes que configura:** OpenSearch 192.168.20.20:9200, Dashboards 192.168.20.20:5601 e ingesta local de registros del host/contendores.

**Archivos y directorios creados, modificados o utilizados:** Prepara configuración y almacenamiento persistente; las rutas exactas requieren consulta del Compose efectivo.

**Requisitos previos:** Dependencias de los scripts anteriores; acceso al recurso o red correspondiente.

**Ejecución:**

```bash
sed -i 's/\r$//' 4-RL-MON-OpenSearch.sh
chmod +x 4-RL-MON-OpenSearch.sh
sudo ./4-RL-MON-OpenSearch.sh
```

### 2.3.5. `RL-MON-add_dashboard_general.sh`

**Nombre del script:** `RL-MON-add_dashboard_general.sh`.

**Descripción:** Incorpora un dashboard general que reúne métricas de los servidores del laboratorio.

**Componentes que instala o utiliza:** No requiere atribuir nuevas instalaciones de servicios.

**Componentes que configura:** Panel general de Grafana, alimentado mediante Prometheus y los exporters existentes.

**Archivos y directorios creados, modificados o utilizados:** Utiliza recursos de Grafana; ubicación de archivos JSON y provisión debe consultarse en el script.

**Requisitos previos:** Servicios Prometheus/Grafana operativos y fuentes Node Exporter disponibles.

**Ejecución:**

```bash
sed -i 's/\r$//' RL-MON-add_dashboard_general.sh
chmod +x RL-MON-add_dashboard_general.sh
sudo ./RL-MON-add_dashboard_general.sh
```

## 2.4. Scripts comunes a los servidores Linux

Estos scripts se ejecutan después de **todos** los scripts exclusivos de RL-MON-01, sin asignarlos en exclusiva a este host.

### 2.4.1. `1-RL-XXX-config_ssh.sh`

**Nombre del script:** `1-RL-XXX-config_ssh.sh`.

**Descripción:** Establece las políticas de administración SSH comunes de los servidores Linux.

**Componentes que instala o utiliza:** Configuración del servicio OpenSSH y controles de acceso existentes.

**Componentes que configura:** Políticas de sshd, autenticación y restricciones para administradores autorizados.

**Archivos y directorios creados, modificados o utilizados:** Puede utilizar /etc/ssh/sshd_config.d/00-recoleccion-uy.conf y /etc/sudoers.d/recoleccion-linux-admins según configuración común documentada.

**Requisitos previos:** Integración de dominio funcional y acceso administrativo alternativo durante el cambio SSH.

**Ejecución:**

```bash
sed -i 's/\r$//' 1-RL-XXX-config_ssh.sh
chmod +x 1-RL-XXX-config_ssh.sh
sudo ./1-RL-XXX-config_ssh.sh
```

### 2.4.2. `2-RL-XXX-config_ssh_users.sh`

**Nombre del script:** `2-RL-XXX-config_ssh_users.sh`.

**Descripción:** Gestiona claves públicas SSH para usuarios autorizados de Active Directory.

**Componentes que instala o utiliza:** No requiere otro servicio nuevo.

**Componentes que configura:** Autorización por usuarios y grupo AD, claves públicas, permisos y contextos SELinux.

**Archivos y directorios creados, modificados o utilizados:** Utiliza /etc/ssh/authorized_keys/ y archivos por usuario autorizado.

**Requisitos previos:** Integración de dominio funcional y acceso administrativo alternativo durante el cambio SSH.

**Ejecución:**

```bash
sed -i 's/\r$//' 2-RL-XXX-config_ssh_users.sh
chmod +x 2-RL-XXX-config_ssh_users.sh
sudo ./2-RL-XXX-config_ssh_users.sh
```

---

# 3. Arquitectura y componentes del servidor

## 3.1. Arquitectura general

```text
RL-APP-01 (192.168.30.20) -- Node Exporter :9100 --> Prometheus
RL-PROXY-01 (192.168.50.20) -- Node Exporter :9100 --> Prometheus
RL-MON-01 (192.168.20.20) -- Node Exporter local --> Prometheus
                                                      |
                                                      v
                                              Grafana :3000
                                              dashboard general

Fluent Bit (RL-APP-01) ----\
Fluent Bit (RL-PROXY-01) ---+---> OpenSearch :9200 ---> Dashboards :5601
Fluent Bit (RL-MON-01) ----/

Prometheus: 127.0.0.1:9090 (exposición local)
```

El esquema muestra dependencias lógicas: el tráfico efectivo depende de las políticas de Firewalld y de RL-FW-01. Node Exporter supervisa la **VM anfitriona**, no las métricas individuales de cada contenedor.

## 3.2. Dependencias

| Equipo | Función para RL-MON-01 |
|---|---|
| RL-FW-01 | Enrutamiento y filtrado entre MONITOREO, APLICACIONES, DMZ y SERVICIOS |
| WS-DC-01 / WS-DC-02 | DNS y autenticación Active Directory |
| RL-APP-01 | Exporta métricas del host y remite registros |
| RL-PROXY-01 | Exporta métricas del host y remite registros |

---

# 4. Configuración de red y conectividad

## 4.1. Interfaz y direccionamiento

`ens33` pertenece al segmento MONITOREO, IP `192.168.20.20/24`, gateway `192.168.20.1`. Usa DNS `192.168.10.20` y `192.168.10.21`.

```bash
ip -br addr show ens33
ip route
nmcli device show ens33
resolvectl status
```

## 4.2. Puertos y protocolos

| Flujo | Puerto / protocolo | Función |
|---|---|---|
| Clientes administrativos autorizados → RL-MON-01 | TCP/3000 | Grafana |
| RL-MON-01 local → Prometheus | TCP/9090 en `127.0.0.1` | Consulta Prometheus |
| RL-APP-01 y RL-PROXY-01 → RL-MON-01 | TCP/9200 | Envío de registros a OpenSearch |
| Clientes autorizados → RL-MON-01 | TCP/5601 | OpenSearch Dashboards |
| RL-MON-01 → RL-APP-01 | TCP/9100 | Métricas del host |
| RL-MON-01 → RL-PROXY-01 | TCP/9100 | Métricas del host |
| RL-MON-01 → servidores DNS AD | DNS TCP/UDP 53 | Resolución institucional |
| Administración autorizada → RL-MON-01 | SSH, puerto definido en configuración vigente | Administración remota |

Los servicios `3000`, `5601` y `9200` no deben quedar accesibles desde WAN. El endpoint `9200` es un servicio interno de OpenSearch y no se convierte a HTTPS automáticamente.

## 4.3. Comprobación de conectividad

```bash
getent hosts neltek.uy
ping -c 3 192.168.20.1
curl -fsS http://127.0.0.1:9090/-/healthy
curl -sSI http://192.168.20.20:3000/login
curl -sSI http://192.168.20.20:5601
curl -sS http://192.168.20.20:9200/
curl -fsS http://192.168.30.20:9100/metrics | head
curl -fsS http://192.168.50.20:9100/metrics | head
```

Estos comandos diagnostican servicios internos; su éxito depende de rutas, permisos y mecanismos de autenticación vigentes. Una respuesta HTTP de error de autenticación no debe confundirse con ausencia de conectividad.

---

# 5. Servicios y contenedores Docker

## 5.1. Servicios

| Servicio | Función | Exposición |
|---|---|---|
| Prometheus | Almacenamiento y consulta de series métricas | `127.0.0.1:9090` |
| Grafana | Paneles y dashboard general | `192.168.20.20:3000` |
| Node Exporter local | Métricas de la VM RL-MON-01 | Puerto exacto según Compose vigente |
| OpenSearch | Almacenamiento y consulta de logs | `192.168.20.20:9200` |
| OpenSearch Dashboards | Interfaz de exploración de logs | `192.168.20.20:5601` |
| Fluent Bit local | Captura y transmisión de logs | Salida a OpenSearch |

Los nombres exactos `container_name`, las imágenes y sus etiquetas, los montajes, políticas de reinicio y nombres de proyectos Compose **deben extraerse de los Compose efectivos**; no se sustituyen por nombres inventados ni se afirma que el nombre del servicio Docker sea necesariamente el nombre del contenedor.

## 5.2. Inspección precisa de los contenedores

```bash
sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
sudo docker compose ls
sudo docker network ls
sudo docker volume ls
sudo docker ps -aq | xargs -r sudo docker inspect --format '{{.Name}} | {{.Config.Image}} | restart={{.HostConfig.RestartPolicy.Name}}'
sudo docker ps -aq | xargs -r sudo docker inspect --format '{{.Name}} | mounts={{json .Mounts}}'
```

Para identificar los proyectos y servicios a partir de sus etiquetas:

```bash
sudo docker ps -a --format '{{.Names}}' | while read -r c; do
  sudo docker inspect "$c" --format '{{.Name}} | proyecto={{index .Config.Labels "com.docker.compose.project"}} | servicio={{index .Config.Labels "com.docker.compose.service"}}'
done
```

## 5.3. Administración segura

```bash
sudo docker ps
sudo docker stats --no-stream
sudo docker compose ls
sudo docker logs --tail 100 NOMBRE_CONTENEDOR
```

Sustituir `NOMBRE_CONTENEDOR` por el nombre real devuelto por `docker ps`. No detener todos los proyectos para atender una única incidencia.

---

# 6. Estructura de directorios y almacenamiento

## 6.1. Directorios de sistema conocidos

| Ruta | Uso |
|---|---|
| `/etc/sssd/sssd.conf` | Integración SSSD / dominio |
| `/etc/ssh/authorized_keys/` | Claves SSH de usuarios autorizados |
| `/etc/ssh/sshd_config.d/00-recoleccion-uy.conf` | Configuración SSH común, según despliegue |
| `/etc/sudoers.d/recoleccion-linux-admins` | Política administrativa de sudo, según despliegue |
| `/var/lib/docker/` | Almacenamiento administrado por Docker |

Las rutas precisas de archivos Compose de Prometheus, Grafana, OpenSearch, Dashboards y Fluent Bit, y los volúmenes con datos persistentes, no se determinan inequívocamente con la información recuperada. Para identificarlas sin inventarlas:

```bash
sudo docker compose ls
sudo docker inspect NOMBRE_CONTENEDOR --format '{{json .Mounts}}'
sudo docker volume ls
sudo du -sh /var/lib/docker
df -h
```

## 6.2. Persistencia y permisos

Proteger especialmente la configuración de Grafana, el almacenamiento de Prometheus, los índices de OpenSearch, datos de Fluent Bit y archivos con secretos o credenciales. Las propiedades y permisos exactos deben respetar el usuario de ejecución establecido en cada Compose.

---

# 7. Base de datos MySQL

## 7.1. Aplicación al servidor

**No aplica.** RL-MON-01 no aloja la base de datos MySQL de Recolección UY. El servicio de base de datos compartida reside en RL-APP-01; OpenSearch es un sistema de indexación y búsqueda de registros, no la base MySQL de las aplicaciones.

---

# 8. Seguridad y control de acceso

## 8.1. Active Directory y SSSD

La integración de RL-MON-01 con `neltek.uy` se configura mediante `2-RL-MON-config_domain_2dns_v1.3.sh`. Incluye realmd, SSSD y los servicios de provisión de directorios HOME de los usuarios autorizados.

```bash
realm list
systemctl status sssd
id USUARIO_AD
```

`USUARIO_AD` es un marcador que debe reemplazarse por una cuenta válida.

## 8.2. SSH y administración

Los scripts comunes `1-RL-XXX-config_ssh.sh` y `2-RL-XXX-config_ssh_users.sh` establecen las políticas y claves públicas de los administradores autorizados. El grupo administrativo documentado es `gg_rec_server_admins_linux`; la pertenencia efectiva se comprueba mediante SSSD.

```bash
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|allowgroups)'
sudo systemctl status sshd
sudo visudo -c
```

No asumir el puerto SSH por defecto cuando existe una política personalizada.

## 8.3. Firewalld y SELinux

```bash
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
getenforce
sudo ausearch -m AVC -ts recent
```

Las reglas de RL-FW-01 regulan el tránsito entre segmentos; la política local de RL-MON-01 controla las exposiciones propias. Se deben proteger especialmente Grafana, Dashboards y OpenSearch, así como credenciales y secretos de sus configuraciones.

---

# 9. Monitoreo y registros

## 9.1. Métricas: Prometheus, Grafana y Node Exporter

`3-RL-MON-monitoreo.sh` proporciona la plataforma de métricas. Prometheus escucha localmente en `127.0.0.1:9090`; Grafana publica la interfaz en `192.168.20.20:3000`. Node Exporter local recopila datos de RL-MON-01 y los exporters de RL-APP-01 y RL-PROXY-01 entregan métricas del sistema operativo de sus VM.

**Verificación:**

```bash
curl -fsS http://127.0.0.1:9090/api/v1/targets
curl -sSI http://192.168.20.20:3000/login
curl -fsS http://192.168.30.20:9100/metrics | head
curl -fsS http://192.168.50.20:9100/metrics | head
```

El dashboard general se incorpora mediante `RL-MON-add_dashboard_general.sh` y concentra la observación de los targets disponibles en una vista.

## 9.2. Registros: Fluent Bit, OpenSearch y Dashboards

`4-RL-MON-OpenSearch.sh` establece OpenSearch, OpenSearch Dashboards y Fluent Bit local. RL-APP-01 y RL-PROXY-01 usan agentes Fluent Bit propios para enviar sus registros a `192.168.20.20:9200`.

Los índices individuales por servidor permiten diferenciar el origen. Se ha documentado la nomenclatura `rl-app-01` para los registros de RL-APP-01; no se presupone que todos los índices o prefijos tengan esa misma configuración.

**Verificación:**

```bash
curl -sS http://192.168.20.20:9200/_cluster/health?pretty
curl -sS http://192.168.20.20:9200/_cat/indices?v
curl -sSI http://192.168.20.20:5601
```

Una respuesta de seguridad o autenticación puede ser esperable; no implica por sí sola un servicio caído. Para localizar archivos de Fluent Bit, revisar su Compose y sus montajes.

## 9.3. Distinción entre métricas y logs

Prometheus/Node Exporter gestionan métricas cuantitativas del host; Fluent Bit/OpenSearch gestionan eventos y registros. Ambos aportan información complementaria y no reemplazan por sí solos el monitoreo de cada aplicación Laravel o contenedor.

---

# 10. Copias de seguridad y recuperación

## 10.1. Información que debe protegerse

- Configuración, targets y retención de Prometheus.
- Dashboards, fuentes de datos y configuración de Grafana.
- Índices y estado persistente de OpenSearch.
- Configuración de OpenSearch Dashboards.
- Configuración de Fluent Bit y datos de estado/búfer que sean relevantes.
- Archivos Compose, certificados utilizados y configuración de acceso/SSSD/SSH.

## 10.2. Procedimiento operativo

Primero identificar el proyecto Compose, rutas bind mount, volúmenes Docker y nombres de servicios mediante las inspecciones de las secciones 5 y 6. Después aplicar los procedimientos de respaldo compatibles con cada aplicación y su consistencia, preservando los metadatos de los volúmenes. OpenSearch debe respaldarse mediante un mecanismo coherente con sus snapshots, no suponiendo que una copia en caliente de archivos sea restaurable.

Las frecuencias, retención, destinos y herramientas definitivas de respaldo de RL-MON-01 no están respaldadas por la información disponible; no se atribuye una política implementada.

## 10.3. Recuperación

Restablecer primero el sistema operativo y red, luego Docker y las configuraciones persistentes; recuperar los datos de los servicios con su método correspondiente, iniciar los proyectos y validar los endpoints, dashboards, índices y llegada de nuevos eventos. Evitar `docker compose down -v`: puede eliminar volúmenes persistentes.

---

# 11. Administración y mantenimiento

## 11.1. Sistema operativo

```bash
hostnamectl
uptime
free -h
df -h
sudo dnf check-update
sudo systemctl status docker
sudo systemctl status firewalld
sudo journalctl -u docker -n 100 --no-pager
```

## 11.2. Contenedores

```bash
sudo docker ps -a
sudo docker compose ls
sudo docker stats --no-stream
sudo docker system df
sudo docker logs --tail 100 NOMBRE_CONTENEDOR
```

Verificar el impacto de actualizaciones de imágenes y cambios de configuración antes de recrear contenedores. Preservar volúmenes persistentes y coordinar la recuperación de OpenSearch cuando intervengan índices o snapshots.

## 11.3. Grafana y OpenSearch

Revisar regularmente targets y resultados de consultas, estado de índices, utilización de disco, tiempos de retención y logs de errores. El dashboard general debe reflejar la disponibilidad real de cada exporter y las fuentes de datos registradas.

---

# 12. Diagnóstico y resolución de problemas

## 12.1. Red, rutas y DNS

```bash
ip -br addr
ip route
nmcli device status
getent hosts neltek.uy
ping -c 3 192.168.20.1
ss -lntup
```

Si no hay conectividad entre segmentos, comprobar NIC/VMware, puerta de enlace, Firewalld local y políticas de RL-FW-01.

## 12.2. Dominio y SSH

```bash
realm list
systemctl status sssd
sssctl domain-status neltek.uy
sudo sshd -t
sudo journalctl -u sshd -n 100 --no-pager
```

Validar resolución DNS y pertenencia al grupo autorizado antes de cambiar políticas de acceso.

## 12.3. Prometheus y Grafana

```bash
curl -fsS http://127.0.0.1:9090/-/healthy
curl -fsS http://127.0.0.1:9090/api/v1/targets
curl -sSI http://192.168.20.20:3000/login
```

Para targets caídos, comprobar Node Exporter en el host origen, puerto TCP/9100 y rutas de red. Si Grafana no muestra métricas, comprobar primero el estado de Prometheus y su fuente de datos.

## 12.4. OpenSearch y Fluent Bit

```bash
curl -sS http://192.168.20.20:9200/_cluster/health?pretty
curl -sS http://192.168.20.20:9200/_cat/indices?v
curl -sSI http://192.168.20.20:5601
sudo docker ps -a
```

Si no ingresan registros, comprobar origen, configuración de salida de Fluent Bit, conectividad al puerto 9200, logs del agente, estado de disco y nombres de índices configurados.

## 12.5. Almacenamiento y servicios

```bash
df -h
df -i
sudo docker system df
sudo journalctl -u docker -n 100 --no-pager
sudo docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
```

No eliminar volúmenes ni aplicar limpiezas agresivas sin identificar su relación con Prometheus, Grafana y OpenSearch.

---

# 13. Anexos

Sección reservada para anexos técnicos futuros. Se incorporarán únicamente cuando se soliciten, con numeración y título propios. **Anexos permanecerá siempre como la última sección del documento.**

