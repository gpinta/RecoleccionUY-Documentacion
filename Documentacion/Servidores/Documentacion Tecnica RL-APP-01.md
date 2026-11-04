# Documentación Técnica del Servidor RL-APP-01

**Fecha de creación:** 03/11/2026  
**Proyecto:** Recolección UY  
**Servidor:** `RL-APP-01`  
**Estado documentado:** infraestructura implementada y operativa, incluido los contenedores.

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
    - [2.3.1. `1-RL-APP-update.sh`](#231-1-rl-app-updatesh)
    - [2.3.2. `2-RL-APP-config_domain_2dns_v1.3.sh`](#232-2-rl-app-config_domain_2dns_v13sh)
    - [2.3.3. `3-RL-APP-config_denuncias_storage_v1.1.sh`](#233-3-rl-app-config_denuncias_storage_v11sh)
    - [2.3.4. `4-RL-APP-config_docker_red.sh`](#234-4-rl-app-config_docker_redsh)
    - [2.3.5. `5-RL-APP-install_node_exporter.sh`](#235-5-rl-app-install_node_exportersh)
    - [2.3.6. `6-RL-APP-install_fluent_bit.sh`](#236-6-rl-app-install_fluent_bitsh)
  - [2.4. Scripts comunes a los servidores Linux](#24-scripts-comunes-a-los-servidores-linux)
    - [2.4.1. `1-RL-XXX-config_ssh.sh`](#241-1-rl-xxx-config_sshsh)
    - [2.4.2. `2-RL-XXX-config_ssh_users.sh`](#242-2-rl-xxx-config_ssh_userssh)
- [3. Arquitectura y componentes del servidor](#3-arquitectura-y-componentes-del-servidor)
  - [3.1. Arquitectura general](#31-arquitectura-general)
  - [3.2. Relación entre Laravel, Docker y MySQL](#32-relación-entre-laravel-docker-y-mysql)
  - [3.3. Dependencias de otros equipos](#33-dependencias-de-otros-equipos)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
  - [4.1. Direccionamiento](#41-direccionamiento)
  - [4.2. Puertos y protocolos](#42-puertos-y-protocolos)
  - [4.3. Comprobaciones de conectividad](#43-comprobaciones-de-conectividad)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
  - [5.1. Componentes](#51-componentes)
  - [5.2. Redes, almacenamiento y reinicio](#52-redes-almacenamiento-y-reinicio)
  - [5.3. Comandos de administración](#53-comandos-de-administración)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
  - [6.1. Rutas operativas](#61-rutas-operativas)
  - [6.2. Permisos del almacenamiento fotográfico](#62-permisos-del-almacenamiento-fotográfico)
  - [6.3. Persistencia](#63-persistencia)
- [7. Base de datos MySQL](#7-base-de-datos-mysql)
  - [7.1. Función y arquitectura](#71-función-y-arquitectura)
  - [7.2. Conexiones y aislamiento](#72-conexiones-y-aislamiento)
  - [7.3. Administración y comprobaciones](#73-administración-y-comprobaciones)
- [8. Seguridad y control de acceso](#8-seguridad-y-control-de-acceso)
  - [8.1. Identidad y autorización](#81-identidad-y-autorización)
  - [8.2. SSH](#82-ssh)
  - [8.3. SELinux y Firewalld](#83-selinux-y-firewalld)
- [9. Monitoreo y registros](#9-monitoreo-y-registros)
  - [9.1. Node Exporter](#91-node-exporter)
  - [9.2. Fluent Bit y OpenSearch](#92-fluent-bit-y-opensearch)
  - [9.3. Diagnóstico de registros](#93-diagnóstico-de-registros)
- [10. Copias de seguridad y recuperación](#10-copias-de-seguridad-y-recuperación)
  - [10.1. Elementos a proteger](#101-elementos-a-proteger)
  - [10.2. Procedimiento de respaldo](#102-procedimiento-de-respaldo)
  - [10.3. Recuperación](#103-recuperación)
  - [10.4. Comprobaciones posteriores](#104-comprobaciones-posteriores)
- [11. Administración y mantenimiento](#11-administración-y-mantenimiento)
  - [11.1. Estado del anfitrión](#111-estado-del-anfitrión)
  - [11.2. Estado Docker](#112-estado-docker)
  - [11.3. Actualizaciones y reinicios](#113-actualizaciones-y-reinicios)
- [12. Diagnóstico y resolución de problemas](#12-diagnóstico-y-resolución-de-problemas)
  - [12.1. Comprobaciones de servicios](#121-comprobaciones-de-servicios)
  - [12.2. Comprobaciones de dominio y SSH](#122-comprobaciones-de-dominio-y-ssh)
- [13. Anexos](#13-anexos)

---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor |
|---|---|
| Nombre del servidor | RL-APP-01 |
| Sistema operativo | Rocky Linux 9 |
| Interfaz de red | `ens33` |
| Segmento | APLICACIONES — `192.168.30.0/24` |
| Dirección IP | `192.168.30.20` |
| Máscara de subred | `255.255.255.0` (`/24`) |
| Gateway | `192.168.30.1` |
| DNS primario | `192.168.10.20` — WS-DC-01 |
| DNS secundario | `192.168.10.21` — WS-DC-02 |
| Dominio | `neltek.uy` |

## 1.2. Rol del servidor

RL-APP-01 es el servidor central de aplicaciones y base de datos de Recolección UY. Aloja la Aplicación Ciudadana, el Backend Administrativo y la Aplicación Camiones, además de un servicio MySQL compartido y almacenamiento persistente de fotografías. Utiliza Docker y Docker Compose para ejecutar los componentes de aplicación.

Los servicios web escuchan internamente en `192.168.30.20:8080` (Ciudadana), `192.168.30.20:8081` (Administración) y `192.168.30.20:8082` (Camiones). RL-PROXY-01 proporciona la publicación HTTPS; RL-APP-01 mantiene comunicación HTTP interna con el proxy. RL-MON-01 recibe métricas y registros del servidor.

## 1.3. Justificación del sistema operativo

Rocky Linux 9 ofrece una base empresarial estable, actualizaciones de seguridad, administración remota por SSH y compatibilidad con Docker, Firewalld, SELinux y los componentes de integración con Active Directory (SSSD, realmd, Kerberos y LDAP). El uso de un sistema sin interfaz gráfica permite orientar los recursos a los servicios desplegados, facilita la operación por consola y mantiene consistencia con los demás servidores Linux del proyecto.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución

Se ejecutan primero los scripts específicos de RL-APP-01. **Los scripts comunes de `Scripts/Linux/RL-XXX-XX/` se ejecutan siempre al final.**

| Orden | Script | Breve descripción |
|---|---|---|
| 1 | `1-RL-APP-update.sh` | Actualiza Rocky Linux e instala dependencias y Docker. |
| 2 | `2-RL-APP-config_domain_2dns_v1.3.sh` | Configura red, DNS, nombre de equipo y Active Directory. |
| 3 | `3-RL-APP-config_denuncias_storage_v1.1.sh` | Prepara almacenamiento persistente de fotografías. |
| 4 | `4-RL-APP-config_docker_red.sh` | Crea la red de comunicación Docker interna. |
| 5 | `5-RL-APP-install_node_exporter.sh` | Despliega Node Exporter para métricas del servidor. |
| 6 | `6-RL-APP-install_fluent_bit.sh` | Despliega Fluent Bit para envío de registros. |
| 7 | `1-RL-XXX-config_ssh.sh` | Configura el acceso SSH protegido y administrativo. |
| 8 | `2-RL-XXX-config_ssh_users.sh` | Registra claves SSH de usuarios autorizados de AD. |

## 2.2. Procedimiento general

Ejecutar en RL-APP-01, desde el directorio que contiene cada archivo, con una cuenta con permisos administrativos. Sustituir `script.sh` por el nombre real:

```bash
sed -i 's/\r$//' script.sh
chmod +x script.sh
sudo ./script.sh
```

El primer comando corrige terminaciones CRLF; el segundo asigna permiso de ejecución; el tercero ejecuta el script con privilegios de administrador. Finalizar cada script antes de continuar con el siguiente. La modificación de conectividad y SSH requiere disponer de acceso de administración alternativo durante la transición.

## 2.3. Scripts específicos del servidor

### 2.3.1. `1-RL-APP-update.sh`

**Nombre del script:** `1-RL-APP-update.sh`

**Descripción:** Actualiza los paquetes de Rocky Linux 9 e instala las herramientas base, Docker Engine, Docker Compose y dependencias de autenticación de dominio.

**Componentes que instala o utiliza:** Herramientas básicas (`nano`, `sudo`, complementos DNF); OpenSSH, Firewalld y utilidades SELinux; `realmd`, `sssd`, `sssd-tools`, `oddjob`, `oddjob-mkhomedir`, `adcli`, `samba-common-tools`, `krb5-workstation`, clientes LDAP y utilidades DNS; `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` y `docker-compose-plugin`.

**Componentes que configura:** Actualización mediante DNF; repositorio Docker CE; habilitación de `containerd`, `docker`, `sshd` y `firewalld`; comprobaciones del sistema y de SELinux.

**Archivos y directorios creados, modificados o utilizados:** Archivo `/etc/yum.repos.d/docker-ce.repo` (repositorio Docker); los directorios internos de los paquetes son administrados por sus instaladores.

**Ejecución:**

```bash
sed -i 's/\r$//' 1-RL-APP-update.sh
chmod +x 1-RL-APP-update.sh
sudo ./1-RL-APP-update.sh
```

### 2.3.2. `2-RL-APP-config_domain_2dns_v1.3.sh`

**Nombre del script:** `2-RL-APP-config_domain_2dns_v1.3.sh`

**Descripción:** Establece la configuración IPv4, resuelve el dominio institucional e integra el host con Active Directory.

**Componentes que instala o utiliza:** Utiliza las dependencias de red, Kerberos, LDAP y SSSD previamente instaladas.

**Componentes que configura:** Interfaz `ens33`; `192.168.30.20/24`; gateway `192.168.30.1`; DNS `192.168.10.20` y `192.168.10.21`; hostname `RL-APP-01`; dominio `neltek.uy`; SSSD y `oddjobd`; entradas de hosts.

**Archivos y directorios creados, modificados o utilizados:** Modifica `/etc/hosts` y `/etc/sssd/sssd.conf`; realiza copias de seguridad con sufijo temporal cuando corresponde.

**Ejecución:**

```bash
sed -i 's/\r$//' 2-RL-APP-config_domain_2dns_v1.3.sh
chmod +x 2-RL-APP-config_domain_2dns_v1.3.sh
sudo ./2-RL-APP-config_domain_2dns_v1.3.sh
```

### 2.3.3. `3-RL-APP-config_denuncias_storage_v1.1.sh`

**Nombre del script:** `3-RL-APP-config_denuncias_storage_v1.1.sh`

**Descripción:** Prepara el directorio persistente donde las aplicaciones almacenan y consultan fotografías asociadas a denuncias.

**Componentes que instala o utiliza:** No incorpora paquetes adicionales.

**Componentes que configura:** Propietario UID/GID `33:33`; permisos `755` en directorios y `644` en archivos existentes; estructura compartida para las aplicaciones.

**Archivos y directorios creados, modificados o utilizados:** Crea `/srv/recoleccion-data/fotos/`. Las subcarpetas `{denuncia_id}/foto_denuncia/` y `{denuncia_id}/foto_resolucion/` las crean posteriormente las aplicaciones, no este script.

**Ejecución:**

```bash
sed -i 's/\r$//' 3-RL-APP-config_denuncias_storage_v1.1.sh
chmod +x 3-RL-APP-config_denuncias_storage_v1.1.sh
sudo ./3-RL-APP-config_denuncias_storage_v1.1.sh
```

### 2.3.4. `4-RL-APP-config_docker_red.sh`

**Nombre del script:** `4-RL-APP-config_docker_red.sh`

**Descripción:** Prepara una red Docker interna para la comunicación entre las aplicaciones y MySQL.

**Componentes que instala o utiliza:** Utiliza Docker Engine instalado previamente.

**Componentes que configura:** Red Docker `recoleccion-db-net`; consulta del estado y detalles de la red.

**Archivos y directorios creados, modificados o utilizados:** No crea carpetas ni archivos de configuración propios; crea la red administrada internamente por Docker.

**Ejecución:**

```bash
sed -i 's/\r$//' 4-RL-APP-config_docker_red.sh
chmod +x 4-RL-APP-config_docker_red.sh
sudo ./4-RL-APP-config_docker_red.sh
```

### 2.3.5. `5-RL-APP-install_node_exporter.sh`

**Nombre del script:** `5-RL-APP-install_node_exporter.sh`

**Descripción:** Despliega Node Exporter en un contenedor, exponiendo métricas del host para el monitoreo.

**Componentes que instala o utiliza:** Imagen `prom/node-exporter:v1.9.1`; contenedor `node-exporter` mediante el proyecto Docker Compose `recoleccion-node-exporter-app`.

**Componentes que configura:** Docker Compose; `192.168.30.20:9100`; acceso de consulta desde RL-MON-01 (`192.168.20.20`); regla limitada de Firewalld; reinicio del contenedor.

**Archivos y directorios creados, modificados o utilizados:** Crea `/opt/recoleccion-uy/node-exporter/` y `/opt/recoleccion-uy/node-exporter/compose.yaml`.

**Ejecución:**

```bash
sed -i 's/\r$//' 5-RL-APP-install_node_exporter.sh
chmod +x 5-RL-APP-install_node_exporter.sh
sudo ./5-RL-APP-install_node_exporter.sh
```

### 2.3.6. `6-RL-APP-install_fluent_bit.sh`

**Nombre del script:** `6-RL-APP-install_fluent_bit.sh`

**Descripción:** Despliega Fluent Bit para leer registros de los contenedores Docker y remitirlos a OpenSearch.

**Componentes que instala o utiliza:** Imagen `fluent/fluent-bit:3.0.0`; contenedor `recoleccion-fluent-bit-app`; procesamiento Lua.

**Componentes que configura:** Lectura de logs `json-file`; destino OpenSearch `192.168.20.20:9200`; enriquecimiento con metadatos Docker; índice/prefijo `rl-app-01`; almacenamiento de búfer y estado.

**Archivos y directorios creados, modificados o utilizados:** Crea `/opt/recoleccion-uy/fluent-bit/` con `fluent-bit.conf`, `parsers.conf`, `docker_metadata.lua`, `compose.yaml` y `storage/`. Lee `/var/lib/docker/containers` sin crear ese directorio.

**Ejecución:**

```bash
sed -i 's/\r$//' 6-RL-APP-install_fluent_bit.sh
chmod +x 6-RL-APP-install_fluent_bit.sh
sudo ./6-RL-APP-install_fluent_bit.sh
```

## 2.4. Scripts comunes a los servidores Linux

Estos scripts pertenecen a `Scripts/Linux/RL-XXX-XX/`; no son exclusivos de RL-APP-01 y **se ejecutan después de los scripts específicos**.

### 2.4.1. `1-RL-XXX-config_ssh.sh`

**Nombre del script:** `1-RL-XXX-config_ssh.sh`

**Descripción:** Establece SSH seguro mediante autenticación de clave pública más contraseña, acceso restringido a grupos autorizados, cuenta de emergencia y cambio controlado de puerto.

**Componentes que instala o utiliza:** No requiere instalar paquetes adicionales: utiliza OpenSSH, SSSD, Firewalld y herramientas SELinux.

**Componentes que configura:** Puerto SSH configurable (predeterminado TCP `2222`); usuario local `adminssh`; grupo `ssh_emergency`; grupo AD `gg_rec_server_admins_linux`; permisos sudo; prohibición de login directo de root; transición desde el puerto estándar tras comprobar la nueva conexión.

**Archivos y directorios creados, modificados o utilizados:** Crea `/etc/ssh/authorized_keys/` y `/etc/ssh/authorized_keys/adminssh`; genera `/etc/ssh/sshd_config.d/00-recoleccion-uy.conf` y `/etc/sudoers.d/recoleccion-linux-admins`; modifica `/etc/ssh/sshd_config`; genera respaldos temporales de configuración cuando corresponde.

**Ejecución:**

```bash
sed -i 's/\r$//' 1-RL-XXX-config_ssh.sh
chmod +x 1-RL-XXX-config_ssh.sh
sudo ./1-RL-XXX-config_ssh.sh
```

### 2.4.2. `2-RL-XXX-config_ssh_users.sh`

**Nombre del script:** `2-RL-XXX-config_ssh_users.sh`

**Descripción:** Administra claves públicas Ed25519 para usuarios del dominio autorizados a acceder por SSH.

**Componentes que instala o utiliza:** No requiere instalar componentes adicionales.

**Componentes que configura:** Verificación del usuario mediante SSSD, membresía en `gg_rec_server_admins_linux`, autorización PAM, claves públicas sin duplicados, permisos de archivos y contextos SELinux.

**Archivos y directorios creados, modificados o utilizados:** Utiliza `/etc/ssh/authorized_keys/` y crea/actualiza `/etc/ssh/authorized_keys/USUARIO_AD` para cada cuenta autorizada.

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
Usuarios / clientes
        |
        v
RL-PROXY-01 (HTTPS / proxy inverso / WAF)
        |
        | HTTP interno: 8080, 8081 y 8082
        v
RL-APP-01 (192.168.30.20, ens33)
        |-- Aplicación Ciudadana (8080)
        |-- Backend Administrativo (8081)
        |-- Aplicación Camiones (8082)
        |-- MySQL compartido (red Docker privada)
        |-- Fotografías persistentes (/srv/recoleccion-data/fotos)
        |-- Node Exporter (9100) ---> RL-MON-01
        `-- Fluent Bit -----------> RL-MON-01 / OpenSearch (9200)
```

La publicación HTTPS y las funciones de WAF se realizan en RL-PROXY-01, no en RL-APP-01. Las tres aplicaciones comparten el almacenamiento de datos MySQL, pero mantienen sus propias bases de código, despliegues y responsabilidades.

## 3.2. Relación entre Laravel, Docker y MySQL

Laravel ejecuta la lógica de las aplicaciones en contenedores independientes. El servicio MySQL `recoleccion_db` se comparte entre las aplicaciones; `recoleccion-db-net` proporciona la comunicación interna Docker. MySQL no publica el puerto 3306 hacia el host.

## 3.3. Dependencias de otros equipos

| Equipo | Dependencia |
|---|---|
| RL-FW-01 | Enrutamiento entre segmentos y control de tráfico. |
| RL-PROXY-01 | Recepción de clientes mediante HTTPS y proxy hacia los puertos 8080/8081/8082. |
| WS-DC-01 / WS-DC-02 | Resolución DNS, Active Directory y autenticación de dominio. |
| RL-MON-01 | Consulta de métricas y recepción/consulta de registros. |

---

# 4. Configuración de red y conectividad

## 4.1. Direccionamiento

| Parámetro | Valor |
|---|---|
| NIC | `ens33` |
| IP/máscara | `192.168.30.20/24` |
| Subred | `192.168.30.0/24` |
| Gateway | `192.168.30.1` |
| DNS1 / DNS2 | `192.168.10.20` / `192.168.10.21` |
| Dominio | `neltek.uy` |

## 4.2. Puertos y protocolos

| Origen o destino | Puerto | Uso |
|---|---|---|
| RL-PROXY-01 → RL-APP-01 | TCP 8080 | Aplicación Ciudadana |
| RL-PROXY-01 → RL-APP-01 | TCP 8081 | Backend Administrativo |
| RL-PROXY-01 → RL-APP-01 | TCP 8082 | Aplicación Camiones |
| RL-MON-01 → RL-APP-01 | TCP 9100 | Consulta de métricas Node Exporter |
| RL-APP-01 → RL-MON-01 | TCP 9200 | Envío de registros a OpenSearch |
| Administración autorizada → RL-APP-01 | TCP 2222 (predeterminado configurable) | SSH seguro |
| Contenedores → MySQL | TCP 3306 (interno) | Base de datos, sin publicación al host |

Los servicios de DNS y autenticación Active Directory utilizan los protocolos correspondientes a la infraestructura institucional.

## 4.3. Comprobaciones de conectividad

```bash
ip -br addr show ens33
ip route
nmcli device show ens33
getent hosts neltek.uy
curl -I https://recoleccion.neltek.uy
curl -I https://admin-recoleccion.neltek.uy
curl -I https://camiones-recoleccion.neltek.uy
curl -fsS http://192.168.30.20:9100/metrics | head
```

Las tres pruebas HTTPS verifican el acceso publicado a través de RL-PROXY-01, utilizando la CA interna instalada como autoridad de confianza en el equipo desde el que se ejecutan. La terminación TLS se realiza en RL-PROXY-01; las conexiones autorizadas del proxy hacia los contenedores de RL-APP-01 utilizan HTTP interno en los puertos 8080, 8081 y 8082. El tráfico entre segmentos está sujeto a las reglas de RL-FW-01. Las políticas de ese firewall se administran en su propio servidor.

---

# 5. Servicios y contenedores Docker

## 5.1. Componentes

| Servicio / contenedor | Función | Exposición |
|---|---|---|
| `recoleccion_api` | Aplicación Ciudadana | `192.168.30.20:8080` |
| `recoleccion_admin` | Backend Administrativo | `192.168.30.20:8081` |
| `recoleccion_camiones` | Aplicación Camiones | `192.168.30.20:8082` |
| `recoleccion_db` | MySQL compartido | Solo red Docker interna |
| `node-exporter` | Métricas del host, proyecto Compose `recoleccion-node-exporter-app` | `192.168.30.20:9100` |
| `recoleccion-fluent-bit-app` | Recolección de registros | Salida a RL-MON-01 |

Los nombres de los contenedores de las tres aplicaciones están definidos expresamente en sus respectivos archivos `docker-compose.yml`. Node Exporter utiliza el contenedor `node-exporter`, creado por el proyecto Compose `recoleccion-node-exporter-app`.

## 5.2. Redes, almacenamiento y reinicio

La red privada compartida conocida es `recoleccion-db-net`. Las fotografías se conservan en el host bajo `/srv/recoleccion-data/fotos/` y se montan en las aplicaciones: `/var/www/shared-denuncias` en Ciudadana y Administración, y `/var/www/shared-fotos` en Camiones.

Los contenedores `recoleccion_api`, `recoleccion_admin`, `recoleccion_camiones` y `recoleccion_db` utilizan `restart: unless-stopped` en sus Compose. La Aplicación Ciudadana define los volúmenes Docker `db_data` (MySQL, montado en `/var/lib/mysql`) y `storage_data` (archivos públicos de Laravel, montado en `/var/www/html/storage/app/public`). Node Exporter utiliza `restart: unless-stopped`, `network_mode: host` y `pid: host`; Fluent Bit utiliza Docker Compose para su despliegue.

## 5.3. Comandos de administración

```bash
sudo docker ps -a
sudo docker network ls
sudo docker network inspect recoleccion-db-net
sudo docker logs --tail 100 recoleccion_api
sudo docker logs --tail 100 recoleccion_admin
sudo docker logs --tail 100 recoleccion_db
sudo docker compose -f /opt/recoleccion-uy/node-exporter/compose.yaml ps
sudo docker compose -f /opt/recoleccion-uy/fluent-bit/compose.yaml ps
```

Antes de reiniciar o modificar contenedores, comprobar el servicio concreto y su configuración Compose. No aplicar acciones globales que afecten innecesariamente a otras aplicaciones.

---

# 6. Estructura de directorios y almacenamiento

## 6.1. Rutas operativas

| Ruta | Finalidad |
|---|---|
| `/srv/recoleccion-data/fotos/` | Almacenamiento compartido persistente de fotografías |
| `/srv/recoleccion-data/fotos/{denuncia_id}/foto_denuncia/` | Fotografías asociadas a la denuncia, creadas por Laravel |
| `/srv/recoleccion-data/fotos/{denuncia_id}/foto_resolucion/` | Fotografías de resolución, creadas por Laravel |
| `/opt/recoleccion-uy/node-exporter/` | Configuración Compose de Node Exporter |
| `/opt/recoleccion-uy/fluent-bit/` | Configuración de Fluent Bit, Lua, parser y búfer |
| `/etc/ssh/authorized_keys/` | Claves públicas de acceso SSH |
| `/etc/sssd/sssd.conf` | Configuración de integración AD/SSSD |
| `/etc/ssh/sshd_config.d/00-recoleccion-uy.conf` | Parámetros SSH específicos del proyecto |
| `/etc/sudoers.d/recoleccion-linux-admins` | Control de elevación administrativa |

## 6.2. Permisos del almacenamiento fotográfico

El directorio base y los elementos existentes quedan con propietario UID/GID `33:33`, permisos `755` para directorios y `644` para archivos, según el procedimiento de preparación.

```bash
sudo ls -ld /srv/recoleccion-data/fotos
sudo find /srv/recoleccion-data/fotos -maxdepth 2 -type d | head -40
sudo df -h /srv/recoleccion-data/fotos
```

## 6.3. Persistencia

El almacenamiento de fotografías depende de una ruta persistente del anfitrión. MySQL utiliza almacenamiento persistente Docker; la identificación exacta de su volumen o montaje deberá hacerse mediante inspección del contenedor, evitando atribuirle una ruta no documentada.

```bash
sudo docker inspect recoleccion_db --format '{{json .Mounts}}'
```

---

# 7. Base de datos MySQL

## 7.1. Función y arquitectura

MySQL proporciona persistencia compartida a la Aplicación Ciudadana, el Backend Administrativo y la Aplicación Camiones. La instancia se identifica como `recoleccion_db`; se comunica con las aplicaciones por la red Docker `recoleccion-db-net` sin publicar TCP/3306 en la interfaz del host.

## 7.2. Conexiones y aislamiento

Las aplicaciones son proyectos Laravel independientes y comparten el servicio de datos. Cualquier modificación de estructura, permisos, relaciones o procesos de actualización de base de datos puede impactar a las tres aplicaciones.

No se documentan nombres de usuario, contraseñas ni cadenas de conexión que contengan secretos.

## 7.3. Administración y comprobaciones

```bash
sudo docker ps --filter name=recoleccion_db
sudo docker logs --tail 100 recoleccion_db
sudo docker inspect recoleccion_db --format '{{json .NetworkSettings.Networks}}'
sudo docker port recoleccion_db
```

La consulta de puertos del último comando debe confirmar la ausencia de publicación del servicio MySQL hacia el host. Para operaciones sobre esquemas o datos, usar las herramientas y procedimientos específicos de MySQL y realizar un respaldo adecuado previamente.

---

# 8. Seguridad y control de acceso

## 8.1. Identidad y autorización

RL-APP-01 pertenece al dominio `neltek.uy`. La integración del sistema operativo se realiza con SSSD y componentes de Active Directory; esta integración es independiente de las consultas LDAP que puedan realizar las aplicaciones.

El grupo AD `gg_rec_server_admins_linux` autoriza la administración por SSH y sudo. La cuenta `adminssh` y el grupo `ssh_emergency` permiten el acceso local administrativo de emergencia según la configuración establecida.

## 8.2. SSH

El acceso SSH utiliza un puerto configurable, con `2222` como valor predeterminado del script, autenticación mediante clave pública y contraseña y acceso root directo deshabilitado. Las claves públicas se almacenan en `/etc/ssh/authorized_keys/`.

```bash
sudo sshd -t
sudo systemctl status sshd --no-pager
sudo ss -lntp | grep ssh
sudo ls -l /etc/ssh/authorized_keys/
```

No se incluyen claves privadas, contraseñas ni tokens en este documento.

## 8.3. SELinux y Firewalld

SELinux aplica controles de contexto a claves SSH y puertos configurados. Firewalld administra las reglas locales, incluida la autorización delimitada para Node Exporter desde RL-MON-01.

```bash
getenforce
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
sudo semanage port -l | grep ssh
```

---

# 9. Monitoreo y registros

## 9.1. Node Exporter

El contenedor `node-exporter` (imagen `prom/node-exporter:v1.9.1`) pertenece al proyecto Docker Compose `recoleccion-node-exporter-app`, se ejecuta con `network_mode: host` y `pid: host`, y expone métricas del host en `192.168.30.20:9100/metrics`. El acceso a ese puerto está destinado al servidor de monitoreo `192.168.20.20`.

```bash
curl -fsS http://192.168.30.20:9100/metrics | head
sudo docker compose -f /opt/recoleccion-uy/node-exporter/compose.yaml ps
```

## 9.2. Fluent Bit y OpenSearch

Fluent Bit recopila logs Docker con el controlador `json-file`, agrega metadatos del contenedor mediante Lua y los remite a `http://192.168.20.20:9200`. El prefijo vigente de índices es `rl-app-01`, que origina índices diarios consultables mediante `rl-app-01-*`.

Rutas de configuración:

- `/opt/recoleccion-uy/fluent-bit/fluent-bit.conf`
- `/opt/recoleccion-uy/fluent-bit/parsers.conf`
- `/opt/recoleccion-uy/fluent-bit/docker_metadata.lua`
- `/opt/recoleccion-uy/fluent-bit/compose.yaml`
- `/opt/recoleccion-uy/fluent-bit/storage/`

```bash
sudo docker compose -f /opt/recoleccion-uy/fluent-bit/compose.yaml ps
sudo docker logs --tail 100 recoleccion-fluent-bit-app
curl -fsS 'http://192.168.20.20:9200/_cluster/health?pretty'
curl -fsS 'http://192.168.20.20:9200/_cat/indices/rl-app-01-*?v'
```

## 9.3. Diagnóstico de registros

Ante ausencia de datos, comprobar el estado del contenedor Fluent Bit, la presencia de archivos Docker `json-file`, la salida hacia OpenSearch y la existencia del patrón de índices `rl-app-01-*`. La administración del clúster OpenSearch corresponde a RL-MON-01.

---

# 10. Copias de seguridad y recuperación

## 10.1. Elementos a proteger

| Elemento | Alcance |
|---|---|
| MySQL | Datos y esquema de la instancia compartida |
| Fotografías | `/srv/recoleccion-data/fotos/` |
| Configuración Docker | Compose, redes y montajes de las aplicaciones |
| Configuración de seguridad | SSH, sudo, SSSD y parámetros de firewall relevantes |
| Telemetría | Configuraciones de Node Exporter y Fluent Bit |

## 10.2. Procedimiento de respaldo

La documentación disponible no establece un único calendario, destino externo, retención ni procedimiento automático completo de respaldo para RL-APP-01. Estos parámetros no se fijan arbitrariamente.

Para un respaldo consistente se debe preservar la coordinación entre el estado de MySQL y los archivos de fotografías. La extracción de datos debe realizarse mediante mecanismos de copia consistentes de MySQL y el almacenamiento fotográfico mediante una herramienta que preserve permisos y propietarios.

## 10.3. Recuperación

La restauración requiere recuperar los datos de MySQL, los archivos persistentes y las configuraciones necesarias, evitando iniciar servicios dependientes de una base todavía incompleta. La ejecución concreta dependerá del formato y ubicación de los respaldos existentes.

## 10.4. Comprobaciones posteriores

Verificar que los contenedores estén operativos, que MySQL responda internamente, que los archivos compartidos tengan permisos correctos y que las tres aplicaciones funcionen. Comprobar además métricas, logs y conectividad con RL-PROXY-01. No realizar restauraciones de prueba directamente sobre datos productivos sin un procedimiento controlado.

---

# 11. Administración y mantenimiento

## 11.1. Estado del anfitrión

```bash
hostnamectl
cat /etc/os-release
uptime
df -h
free -h
sudo systemctl status docker --no-pager
sudo systemctl status firewalld --no-pager
sudo systemctl status sssd --no-pager
```

## 11.2. Estado Docker

```bash
sudo docker ps -a
sudo docker stats --no-stream
sudo docker network ls
sudo docker system df
```

## 11.3. Actualizaciones y reinicios

Planificar actualizaciones y reinicios del anfitrión considerando que tres aplicaciones comparten MySQL y almacenamiento. Antes de modificar contenedores, comprobar sus Compose, dependencias y persistencia. Los comandos de mantenimiento deben ejecutarse sobre el servicio concreto, no indiscriminadamente sobre toda la infraestructura.

---

# 12. Diagnóstico y resolución de problemas

| Síntoma | Comprobaciones iniciales |
|---|---|
| Aplicaciones no accesibles | `docker ps -a`, estado de 8080/8081/8082, conectividad con RL-PROXY-01 |
| Problemas DNS | `nmcli device show ens33`, resolución de los controladores de dominio |
| Fallas de autenticación | `systemctl status sssd`, pertenencia a grupos AD, configuración SSH |
| Errores de base de datos | Estado/logs de `recoleccion_db`, red `recoleccion-db-net`, conexiones internas |
| Fotografías no disponibles | Existencia de archivos, propietarios UID/GID `33:33`, montajes de contenedores |
| Ausencia de métricas | Node Exporter, escucha TCP/9100 y permisos de red desde RL-MON-01 |
| Ausencia de logs | Fluent Bit, `json-file`, salida TCP/9200, índices `rl-app-01-*` |
| Falta de espacio | `df -h`, `docker system df`, crecimiento de fotografías y logs |

## 12.1. Comprobaciones de servicios

```bash
sudo docker ps -a
sudo docker logs --tail 100 recoleccion_api
sudo docker logs --tail 100 recoleccion_admin
sudo docker logs --tail 100 recoleccion_db
sudo ss -lntp
```

## 12.2. Comprobaciones de dominio y SSH

```bash
realm list
getent group gg_rec_server_admins_linux
sudo systemctl status sssd --no-pager
sudo sshd -t
sudo firewall-cmd --list-all
```

No realizar correcciones que modifiquen otras aplicaciones o servidores sin identificar primero el componente afectado.

---

# 13. Anexos

Sección reservada para anexos técnicos futuros. Se incorporarán únicamente cuando se soliciten, con numeración y título propios. **Anexos permanecerá siempre como la última sección del documento.**
