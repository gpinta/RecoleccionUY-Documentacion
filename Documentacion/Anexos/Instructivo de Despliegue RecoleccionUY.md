# Despliegue de Recolección UY — instructivo actualizado

**Actualización:** 4 de noviembre de 2026

**Alcance:** procedimientos técnicos de preparación, configuración, instalación, despliegue, integración y verificación de la infraestructura completa de Recolección UY. Comprende la configuración de los controladores de dominio WS-DC-01 y WS-DC-02 con Windows Server 2012 R2, Active Directory, DNS, DHCP Failover y autenticación LDAP/Kerberos; implementación de Rocky Linux 9, redes, routing, NAT y firewall en RL-FW-01; instalación de Docker, despliegue de las aplicaciones Ciudadana, Backend Administrativo y Camiones desarrolladas en Laravel 12, y configuración de la base de datos MySQL compartida en RL-APP-01; publicación mediante Nginx, dnsmasq, WAF ModSecurity con OWASP CRS y HTTPS/TLS en RL-PROXY-01; implementación de Prometheus, Grafana, OpenSearch y agentes de monitoreo en RL-MON-01; integración entre los servicios y ejecución de procedimientos de validación, mantenimiento y recuperación de la infraestructura.



## Índice

- [Datos del entorno y arquitectura](#datos-del-entorno-y-arquitectura)
1. [WS-DC-01 — primer controlador de dominio](#1-ws-dc-01--primer-controlador-de-dominio)
   - [1.1 Configuración inicial de Windows Server](#11-configuración-inicial-de-windows-server)
   - [1.2 Instalación y configuración de AD DS, DNS y DHCP](#12-instalación-y-configuración-de-ad-ds-dns-y-dhcp)
   - [1.3 Verificación inicial](#13-verificación-inicial)
2. [WS-DC-02 — controlador adicional](#2-ws-dc-02--controlador-adicional)
   - [2.1 Configuración inicial y unión al dominio](#21-configuración-inicial-y-unión-al-dominio)
   - [2.2 Instalación y configuración de AD DS, DNS y DHCP](#22-instalación-y-configuración-de-ad-ds-dns-y-dhcp)
   - [2.3 Verificar replicación](#23-verificar-replicación)
   - [2.4 Scripts PowerShell: orden y ubicación](#24-scripts-powershell-orden-y-ubicación)
3. [RL-FW-01 — preparación, red y dominio](#3-rl-fw-01--preparación-red-y-dominio)
   - [3.1 `1-RL-FW_update.sh`](#31-1-rl-fw_updatesh)
   - [3.2 `2-RL-FW-config_v1.1.sh`](#32-2-rl-fw-config_v11sh)
   - [3.3 `RL-FW-config_domain.sh` y `3-RL-FW-add_MON_AD.sh`](#33-rl-fw-config_domainsh-y-3-rl-fw-add_mon_adsh)
4. [RL-APP-01 — preparación y aplicaciones](#4-rl-app-01--preparación-y-aplicaciones)
   - [4.1 `1-RL-APP-update.sh`](#41-1-rl-app-updatesh)
   - [4.2 `2-RL-APP-config_domain_2dns_v1.3.sh`](#42-2-rl-app-config_domain_2dns_v13sh)
   - [4.3 Verificaciones de red](#43-verificaciones-de-red)
   - [4.4 `3-RL-APP-config_denuncias_storage_v1.1.sh`](#44-3-rl-app-config_denuncias_storage_v11sh)
   - [4.5 `4-RL-APP-config_docker_red.sh`](#45-4-rl-app-config_docker_redsh)
   - [4.6 Aplicación Ciudadana y base de datos](#46-aplicación-ciudadana-y-base-de-datos)
   - [4.7 Backend Administrativo](#47-backend-administrativo)
   - [4.8 Aplicación Camiones](#48-aplicación-camiones)
   - [4.9 LDAP, permisos y red Docker](#49-ldap-permisos-y-red-docker)
5. [RL-PROXY-01 — DMZ, Nginx y dnsmasq](#5-rl-proxy-01--dmz-nginx-y-dnsmasq)
   - [5.1 `1-RL-PROXY-update.sh`](#51-1-rl-proxy-updatesh)
   - [5.2 `2-RL-PROXY-config_domain_2dns_v1.3.sh`](#52-2-rl-proxy-config_domain_2dns_v13sh)
   - [5.3 Comprobar acceso a los backends antes del proxy](#53-comprobar-acceso-a-los-backends-antes-del-proxy)
   - [5.4 `3-RL-PROXY-config_proxy_http.sh`](#54-3-rl-proxy-config_proxy_httpsh)
   - [5.5 Verificación local del proxy](#55-verificación-local-del-proxy)
   - [5.6 WAF, certificados y publicación HTTPS](#56-waf-certificados-y-publicación-https)
   - [5.7 Operación del stack del proxy](#57-operación-del-stack-del-proxy)
6. [DNS web, publicación y pruebas de clientes](#6-dns-web-publicación-y-pruebas-de-clientes)
   - [6.1 DNS interno de Active Directory](#61-dns-interno-de-active-directory)
   - [6.2 Publicación WAN mediante RL-FW-01](#62-publicación-wan-mediante-rl-fw-01)
   - [6.3 Resolver nombres desde clientes](#63-resolver-nombres-desde-clientes)
   - [6.4 Verificaciones funcionales](#64-verificaciones-funcionales)
7. [SSH y administración](#7-ssh-y-administración)
8. [Verificación final por servidor](#8-verificación-final-por-servidor)
   - [RL-APP-01](#rl-app-01)
   - [RL-PROXY-01](#rl-proxy-01)
   - [Windows](#windows)
   - [8.1 RL-MON-01 — métricas y registros](#81-rl-mon-01--métricas-y-registros)
9. [Orden maestro resumido](#9-orden-maestro-resumido)
10. [Seguridad, precauciones y pendientes](#10-seguridad-precauciones-y-pendientes)
    - [10.1 Precauciones de despliegue](#101-precauciones-de-despliegue)
    - [10.2 Parámetros por confirmar en el entorno](#102-parámetros-por-confirmar-en-el-entorno)
    - [10.3 Diagnóstico por capas](#103-diagnóstico-por-capas)


## Datos del entorno y arquitectura

| Equipo      | Interfaz/red               | Dirección                          | Función                              |
|-------------|----------------------------|------------------------------------|--------------------------------------|
| WS-DC-01    | SERVICIOS                  | `192.168.10.20/24`                 | Primer DC, AD DS, DNS, DHCP          |
| WS-DC-02    | SERVICIOS                  | `192.168.10.21/24`                 | DC adicional, AD DS, DNS, DHCP       |
| RL-FW-01    | `ens33` WAN Bridged / DHCP | Dinámica, determinada por DHCP WAN | Entrada WAN, routing, NAT, firewalld |
| RL-FW-01    | `ens36` SERVICIOS          | `192.168.10.1/24`                  | Gateway SERVICIOS                    |
| RL-FW-01    | `ens37` MONITOREO          | `192.168.20.1/24`                  | Gateway MONITOREO                    |
| RL-FW-01    | `ens38` APLICACIONES       | `192.168.30.1/24`                  |  Gateway APLICACIONES                |
| RL-FW-01    | `ens39` DMZ                | `192.168.50.1/24`                  | Gateway DMZ                          |
| RL-APP-01   | `ens33` APLICACIONES       | `192.168.30.20/24`                 | Ciudadana, Admin, Camiones, MySQL    |
| RL-PROXY-01 | `ens33` DMZ                | `192.168.50.20/24`                 | Nginx, dnsmasq y WAF                 |
| RL-MON-01   | `ens33` MONITOREO          | `192.168.20.20/24`                 | Prometheus, Grafana y OpenSearch     |

- **Dominio:** `neltek.uy` (NetBIOS `NELTEK`).
- **DNS de Active Directory:** `192.168.10.20` y `192.168.10.21`.
- **Web Ciudadana:** `http://recoleccion.neltek.uy`.
- **Web Administrativa:** `admin-recoleccion.neltek.uy`.
- **Web Camiones:** `camiones-recoleccion.neltek.uy`.
- **API/Ciudadana:** `192.168.30.20:8080`.
- **Administrativo:** `192.168.30.20:8081`.
- **Camiones:** `192.168.30.20:8082`.
- **Proxy de publicación:** `192.168.50.20`, con configuración de HTTP inicial y scripts independientes de WAF y HTTPS en TCP/443.
- **dnsmasq en DMZ:** `192.168.50.20:53` TCP/UDP.
- **MySQL:** contenedor `recoleccion_db`, red Docker privada `recoleccion-db-net`, sin publicar `3306`.

```bash
Clientes / WAN
    |
    v
RL-FW-01 (WAN ens33; DNAT TCP/80 hacia DMZ)
    |
    v
RL-PROXY-01 (ens33 192.168.50.20)
    | Nginx :80 / dnsmasq :53
    |
    +--> RL-FW-01 (gateway DMZ 192.168.50.1)
              |
              +--> RL-APP-01 (192.168.30.20)
                    +--> recoleccion_api   :8080
                    +--> recoleccion_admin :8081
                    +--> recoleccion_camiones :8082
                    +--> recoleccion_db (privado)
```

**Redes virtuales:** cada servidor de aplicaciones y proxy utiliza una sola NIC `ens33` en su segmento. Solo **RL-FW-01** tiene una NIC WAN Bridged.

**Condiciones previas:** las redes VMnet y NIC deben estar correctamente asociadas; la salida a Internet de los servidores internos depende de las reglas y NAT de RL-FW-01. Un resultado satisfactorio de un script no sustituye la validación real de conectividad.

---

# 1. WS-DC-01 — primer controlador de dominio

## 1.1 Configuración inicial de Windows Server

- Hostname: `WS-DC-01`.
- IP: `192.168.10.20/24`.
- Gateway: `192.168.10.1`.
- DNS inicial: `192.168.10.20`.
- Verificar fecha, hora, NIC y conectividad.

## 1.2 Instalación y configuración de AD DS, DNS y DHCP

**Instalación de roles:** desde el Administrador del servidor instalar **Active Directory Domain Services**, **DNS Server** y **DHCP Server**.

**Active Directory:** seleccionar *Agregar un nuevo bosque* con dominio raíz `neltek.uy`; definir niveles funcionales compatibles con Windows Server 2012 R2, habilitar DNS y catálogo global, establecer DSRM en el asistente, comprobar requisitos previos y completar la promoción/reinicio. Verificar LDAP, Kerberos, FSMO y sincronización horaria.

**DNS:** confirmar zona `neltek.uy` integrada en AD, actualizaciones dinámicas seguras, registros del DC y registros SRV LDAP/Kerberos. Una vez disponible WS-DC-02, incorporar `192.168.10.21` como DNS alternativo.

**DHCP:** completar la posinstalación, autorizar el servidor en AD y crear **solo los ámbitos que realmente requieran direcciones dinámicas**. Para cada ámbito definir rango, exclusiones, concesiones y opciones: `003` (gateway de la red), `006` (DNS `192.168.10.20` y luego `192.168.10.21`) y `015` (`neltek.uy`). Activar y comprobar una concesión real.

**Importante:** los rangos de los ámbitos DHCP permanecen pendientes de definición. No asignar direcciones que coincidan con las IP estáticas de infraestructura; determinar los segmentos que tendrán DHCP y si requieren DHCP Relay en RL-FW-01.

## 1.3 Verificación inicial

```powershell
Get-ADDomain
Get-ADForest
Resolve-DnsName -Type SRV _ldap._tcp.neltek.uy -Server 192.168.10.20
Resolve-DnsName -Type SRV _kerberos._tcp.neltek.uy -Server 192.168.10.20
```

```cmd
nltest /dsgetdc:neltek.uy
dcdiag
```

---

# 2. WS-DC-02 — controlador adicional

## 2.1 Configuración inicial y unión al dominio

- Hostname: `WS-DC-02`.
- IP: `192.168.10.21/24`.
- Gateway: `192.168.10.1`.
- **DNS inicial:** `192.168.10.20` (WS-DC-01).
- Verificar resolución de `neltek.uy`, conectividad, fecha y hora.
- **Unir el equipo al dominio `neltek.uy` antes de instalar/promocionar los roles**, reiniciar y comprobar pertenencia y autenticación.

## 2.2 Instalación y configuración de AD DS, DNS y DHCP

**Instalación de roles:** AD DS, DNS Server y DHCP Server.

**Active Directory:** seleccionar *Agregar un controlador de dominio a un dominio existente* (`neltek.uy`), usar WS-DC-01 como origen inicial de replicación, habilitar DNS y catálogo global, definir DSRM, validar requisitos e instalar. Tras el reinicio comprobar AD DS, SYSVOL, objetos y GPO replicados. Mantener inicialmente FSMO en WS-DC-01.

**DNS:** confirmar que la zona integrada `neltek.uy` y los registros SRV se replican. Configuración final prevista en WS-DC-02: DNS preferido `192.168.10.21` y alternativo `192.168.10.20`, después de completar y comprobar replicación.

**DHCP:** completar posinstalación, autorizar en AD, comprobar ámbitos de WS-DC-01 y crear la relación de **DHCP Failover**, sin duplicar ámbitos independientes. La relación prevista es **equilibrio de carga 50/50**; aplicar únicamente a los ámbitos efectivamente definidos.

## 2.3 Verificar replicación

```cmd
dcdiag
repadmin /replsummary
repadmin /showrepl
```

```powershell
Resolve-DnsName ws-dc-01.neltek.uy -Server 192.168.10.21
Resolve-DnsName ws-dc-02.neltek.uy -Server 192.168.10.20
Resolve-DnsName -Type SRV _ldap._tcp.neltek.uy -Server 192.168.10.21
```

## 2.4 Scripts PowerShell: orden y ubicación

Una vez instalados y validados los roles, **mantener el orden del prefijo numérico** y ejecutar los scripts de dominio desde WS-DC-01; ejecutar los scripts locales `2` y `3` en ambos controladores con la configuración correspondiente.

| Orden Script                                    | WS-DC-01 | WS-DC-02 | Función                                                                      |
|-------------------------------------------------|----------|----------|------------------------------------------------------------------------------|
| 1 | `1-AD_Config_RecoleccionUY.ps1`             | Sí       | No       | Crea/verifica OU, grupos y cuentas de AD                                     |
| 2 | `2-WS-DC_Config_Local.ps1`                  | Sí       | Sí       | Configura DNS cliente, RDP, NLA, TermService y regla RDP                     |
| 3 | `3-WS-DC_RDP_Gestionar_Origenes.ps1`        | Sí       | Sí       | Administra orígenes IP permitidos para RDP                                   |
| 4 | `4-AD_Politica_Contrasenas_Dominio.ps1`     | Sí       | No       | Configura política de contraseñas y reglas previstas para cuentas            |
| 5 | `5-GPO_Equipos_Inactividad.ps1`             | Sí       | No       | Crea y vincula GPO de inactividad                                            |
| 5 | `5-GPO_Equipos_Inactividad_Excepciones.ps1` | Sí       | No       | Administra excepciones de aplicación de esa GPO                              |
| 6 | `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1`    | Sí       | No       | Crea/actualiza registros A de Ciudadana, Administrativo y Camiones en AD DNS |

**Requisito para el script 6:** comprobar el parámetro de IP del proxy `192.168.50.20` en el script vigente, y los tres registros `recoleccion.neltek.uy`, `admin-recoleccion.neltek.uy` y `camiones-recoleccion.neltek.uy`. Ejecutarlo cuando el proxy esté preparado; comprobar la replicación DNS hacia WS-DC-02. No incluir credenciales reales.

---

# 3. RL-FW-01 — preparación, red y dominio

## 3.1 `1-RL-FW_update.sh`

- Preparar Rocky Linux 9; instalar herramientas, NetworkManager, SSH, firewalld, componentes SELinux y dependencias AD/LDAP.
- Habilitar forwarding IPv4 y medidas básicas de red.
- Comprobar servicios. **Este script no instala Docker.**

## 3.2 `2-RL-FW-config_v1.1.sh`

Configurar las cinco interfaces:

```bash
ens33 = WAN (Bridged / DHCP; única ruta predeterminada)
ens36 = SERVICIOS     192.168.10.1/24
ens37 = MONITOREO     192.168.20.1/24
ens38 = APLICACIONES  192.168.30.1/24
ens39 = DMZ           192.168.50.1/24
```

El script administra zonas firewalld, masquerade/NAT de salida, políticas de tránsito entre segmentos, conexiones hacia controladores de dominio, proxy→backends (TCP/8080, 8081 y 8082) y DNAT WAN TCP/80 y TCP/443 hacia `192.168.50.20`. **Que exista una regla DNAT/443 no significa que HTTPS esté configurado en Nginx.**

Verificar con:

```bash
ip -br addr
ip -4 route
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all-policies
sudo firewall-cmd --list-all --zone=rec-wan
```

Confirmar que la política habilite las comunicaciones precisas y no exponga MySQL hacia WAN.

## 3.3 `RL-FW-config_domain.sh` y `3-RL-FW-add_MON_AD.sh`

El script `RL-FW-config_domain.sh` configura la integración con `neltek.uy`, DNS/SRV, SSSD, caché y creación automática de HOME. `3-RL-FW-add_MON_AD.sh` contempla reglas específicas de monitoreo y comunicación con servicios AD. Aplicar según sus dependencias y parámetros. La autorización de SSH y sudo corresponde a scripts separados. Verificar:

```bash
realm list
sudo sssctl config-check
systemctl status sssd
systemctl status oddjobd
```

**Cuidado:** al modificar rutas, zonas o NAT, no interrumpir la única sesión de administración antes de validar el acceso alternativo.

---

# 4. RL-APP-01 — preparación y aplicaciones

## 4.1 `1-RL-APP-update.sh`

En `RL-APP-01` (`192.168.30.20`), ejecutar desde la ubicación real del script:

```bash
sudo ./1-RL-APP-update.sh
docker --version
docker compose version
sudo systemctl status docker
sudo systemctl status sshd
sudo systemctl status firewalld
```

Actualiza Rocky Linux, instala Docker CE, Compose v2, OpenSSH, firewalld, herramientas SELinux y dependencias AD/LDAP. No configura las redes Docker ni une al dominio. Garantizar acceso a repositorios **a través de RL-FW-01**, no mediante una segunda NIC Bridged.

## 4.2 `2-RL-APP-config_domain_2dns_v1.3.sh`

Variables verificadas en el script suministrado:

```bash
INTERFACE="ens33"
IPADDR="192.168.30.20"
PREFIX="24"
GATEWAY="192.168.30.1"
DNS1="192.168.10.20"
DNS2="192.168.10.21"
HOSTNAME="RL-APP-01"
DOMAIN="neltek.uy"
```

Ejecutar:

```bash
sudo ./2-RL-APP-config_domain_2dns_v1.3.sh
realm list
sudo sssctl config-check
systemctl status sssd
systemctl status oddjobd
ip -br addr
ip route
ip route get 192.168.10.20
```

Configura red estática vía NetworkManager, `/etc/hosts`, unión a dominio (si falta), SSSD y `oddjobd`, con respaldos y validaciones. Puede alterar la conectividad SSH al cambiar la IP.

## 4.3 Verificaciones de red

```bash
ip -br addr
ip route
getent hosts ws-dc-01.neltek.uy
getent hosts ws-dc-02.neltek.uy
```

Resultados esperados: IP `192.168.30.20/24` sobre `ens33`, gateway `192.168.30.1`, resolución de los DC hacia `192.168.10.20` y `192.168.10.21`. Sin `ens36` Bridged ni `config_route_metrics.sh`.

## 4.4 `3-RL-APP-config_denuncias_storage_v1.1.sh`

```bash
sudo ./3-RL-APP-config_denuncias_storage_v1.1.sh
ls -ld /srv/recoleccion-data/fotos
```

Prepara las rutas persistentes; propietario recursivo `33:33`; permisos `755` en directorios y `644` en archivos. **No elimina fotografías**, no inicia contenedores y no modifica Docker Compose. Montaje esperado:

```bash
/srv/recoleccion-data/fotos:/var/www/shared-denuncias:rw,z
```

No utilizar `chmod 777`.

## 4.5 `4-RL-APP-config_docker_red.sh`

```bash
sudo ./4-RL-APP-config_docker_red.sh
docker network inspect recoleccion-db-net
```

Crea o reutiliza `recoleccion-db-net`. No crea `recoleccion-proxy-net`, no inicia contenedores y no publica MySQL.

## 4.6 Aplicación Ciudadana y base de datos

En el directorio real del proyecto `recoleccion-api`:

```bash
docker compose config
docker compose up -d --build
docker ps
curl -I http://192.168.30.20:8080
```

Comprobar `recoleccion_api` y `recoleccion_db`, puerto de la aplicación enlazado a **`192.168.30.20:8080`**, y MySQL sin publicación `3306`. La red compartida es `recoleccion-db-net`. **Verificar las asignaciones de puertos en el Compose existente**; un ejemplo orientativo de mapeo no debe sobrescribir la configuración interna real sin inspeccionar el Dockerfile y los servicios.

**Inicialización de Laravel:** el archivo `entrypoint.sh` de la Aplicación Ciudadana ejecuta las migraciones y los seeders configurados durante el inicio del contenedor. Este comportamiento debe tenerse en cuenta al reconstruir o reiniciar la aplicación, debido a que la base de datos MySQL es compartida con el Backend Administrativo y la Aplicación Camiones.

La clave `APP_KEY` debe mantenerse estable y gestionarse mediante la configuración propia del entorno. No incluir claves ni credenciales reales en la documentación.

## 4.7 Backend Administrativo

En el directorio real del proyecto `recoleccion-admin`:

```bash

docker compose config
docker compose up -d --build
docker ps
curl -I http://192.168.30.20:8081
```

Comprobar `recoleccion_admin`, bind `192.168.30.20:8081`, conexión a `recoleccion-db-net` y reutilización de `recoleccion_db`. No crear otra instancia MySQL.

## 4.8 Aplicación Camiones

En el directorio **independiente** del proyecto `recoleccion-camiones`:

```bash
docker compose config
docker compose up -d --build
docker ps
curl -I http://192.168.30.20:8082
```

Su `docker-compose.yml` define el contenedor `recoleccion_camiones`, publicación en `192.168.30.20:8082`, conexión a `recoleccion-db-net` y almacenamiento privado de fotografías de resolución mediante el montaje `/srv/recoleccion-data/fotos:/var/www/shared-fotos:rw,z`. La aplicación contiene controladores de autenticación, dashboard, asignaciones y fotografías de resolución; el middleware controla que el camión esté activo. Su identificación y gestión de tareas están implementadas en su propio código. Verificar que el alias DNS de base de datos utilizado en el Compose resuelva efectivamente a `recoleccion_db`; no iniciar otra base MySQL.

**Tareas programadas:** el Backend Administrativo utiliza el scheduler de Laravel para ejecutar el comando `denuncias:finalizar-vencidas`, definido en `routes/console.php`.

El proceso `php artisan schedule:work` se inicia desde `entrypoint.sh`. Este servicio forma parte del funcionamiento automático de las denuncias y debe mantenerse durante el despliegue y la operación del Backend.

**Atención a la configuración compartida:** comprobar el directorio físico de fotos y los montajes de los tres Compose antes del primer arranque; el archivo de la Aplicación Ciudadana utiliza `/var/www/shared-denuncias`, mientras Camiones utiliza `/var/www/shared-fotos`. La configuración de almacenamiento del host y los Compose deben referir al mismo contenido cuando corresponda.

## 4.9 LDAP, permisos y red Docker

```bash
getent hosts ws-dc-01.neltek.uy
getent hosts ws-dc-02.neltek.uy
docker network inspect recoleccion-db-net
docker logs recoleccion_admin
docker ps
```

Comprobar el acceso LDAP desde la aplicación sin exponer credenciales. La unión del host a AD mediante SSSD no sustituye la conexión LDAP que emplea el Backend Laravel. En `docker network inspect` deben figurar `recoleccion_api`, `recoleccion_admin`, `recoleccion_camiones` y `recoleccion_db`.

**No continuar** si alguna de las tres aplicaciones no responde localmente o si el puerto `3306` queda publicado en el host.

---

# 5. RL-PROXY-01 — DMZ, Nginx y dnsmasq

## 5.1 `1-RL-PROXY-update.sh`

```bash
sudo ./1-RL-PROXY-update.sh
docker --version
docker compose version
```

Prepara Rocky Linux 9, Docker, Compose, SSH/firewalld y dependencias AD/LDAP.

## 5.2 `2-RL-PROXY-config_domain_2dns_v1.3.sh`

Configuración real prevista en el script:

```bash
ens33 = 192.168.50.20/24
gateway = 192.168.50.1
DNS1 = 192.168.10.20
DNS2 = 192.168.10.21
hostname = RL-PROXY-01
dominio = neltek.uy
```

```bash
sudo ./2-RL-PROXY-config_domain_2dns_v1.3.sh
realm list
sudo sssctl config-check
ip -br addr
ip -4 route
ip route get 192.168.30.20
```

Debe existir **una sola NIC de datos `ens33`**, una única ruta predeterminada mediante `192.168.50.1` y tránsito hasta RL-APP-01 a través de RL-FW-01.

## 5.3 Comprobar acceso a los backends antes del proxy

```bash
curl -I http://192.168.30.20:8080
curl -I http://192.168.30.20:8081
curl -I http://192.168.30.20:8082
```

Las tres aplicaciones deben producir una respuesta HTTP desde RL-PROXY-01:

- Aplicación Ciudadana: `192.168.30.20:8080`.
- Backend Administrativo: `192.168.30.20:8081`.
- Aplicación Camiones: `192.168.30.20:8082`.

Ante un fallo de comunicación, verificar la dirección IP, el gateway, las políticas de RL-FW-01 y el puerto correspondiente antes de modificar la configuración de Nginx.

## 5.4 `3-RL-PROXY-config_proxy_http.sh`

```bash
sudo ./3-RL-PROXY-config_proxy_http.sh
```

**El script actual sí está adaptado a la nueva topología y ejecuta el arranque inicial**, además de configurar:

- Verificación de privilegios, Docker y Compose.
- Comprobación de `192.168.50.20/24`, única ruta por `192.168.50.1`, DNS AD, ruta a `192.168.30.20` y TCP/8080, TCP/8081 y TCP/8082.
- Creación de `/opt/recoleccion-proxy` y respaldos de configuraciones previas.
- Nginx con `recoleccion.neltek.uy` → `192.168.30.20:8080`, `admin-recoleccion.neltek.uy` → `192.168.30.20:8081` y `camiones-recoleccion.neltek.uy` → `192.168.30.20:8082`; `client_max_body_size 25M`; encabezados de proxy.
- dnsmasq con resoluciones locales de los tres nombres a `192.168.50.20` y upstream `192.168.10.20/21`.
- Docker Compose para `recoleccion_proxy` (`192.168.50.20:80`) y `recoleccion_dns` (`192.168.50.20:53` TCP/UDP).
- Servicios HTTP y DNS en la zona firewalld detectada (si firewalld está activo y la interfaz tiene zona).
- Descarga/construcción de imágenes, recreación e inicio de ambos contenedores, pruebas de Nginx, DNS y reverse proxy.

**Alcance del script:** configura la interfaz DMZ y el proxy, pero no define por sí mismo una ACL restrictiva del Backend Administrativo. El acceso WAN del Backend debe tratarse como pendiente de política de seguridad. La publicación WAN se controla en RL-FW-01.

## 5.5 Verificación local del proxy

```bash
docker ps
docker exec recoleccion_proxy nginx -t
docker compose -f /opt/recoleccion-proxy/docker-compose.yml ps
dig @192.168.50.20 recoleccion.neltek.uy
dig @192.168.50.20 admin-recoleccion.neltek.uy
dig @192.168.50.20 camiones-recoleccion.neltek.uy
curl -I -H "Host: recoleccion.neltek.uy" http://192.168.50.20
curl -I -H "Host: admin-recoleccion.neltek.uy" http://192.168.50.20
curl -I -H "Host: camiones-recoleccion.neltek.uy" http://192.168.50.20
```

Los tres nombres consultados a dnsmasq deben resolver a `192.168.50.20`. La respuesta HTTP puede ser un código 2xx o 3xx, o uno de error aplicable al endpoint; verificar que proviene del backend esperado y no asumir éxito solo por un código de estado.

## 5.6 WAF, certificados y publicación HTTPS

Los scripts del proxy están organizados por dependencias:

1. `3-RL-PROXY-config_proxy_http.sh` — prepara Nginx y dnsmasq con los tres virtual hosts HTTP.
2. `4-RL-PROXY-install_WAF.sh` — instala el WAF mediante imagen `owasp/modsecurity-crs:4.25.1-nginx-lts`, con ModSecurity y OWASP CRS; contempla los tres destinos 8080, 8081 y 8082.
3. `5-RL-PROXY-generar_certificados_tls.sh` — genera certificados TLS para los tres nombres de aplicación, incluyendo sus nombres alternativos.
4. `6-RL-PROXY-migrar_waf_https.sh` — migra la publicación al WAF con HTTPS por el puerto `192.168.50.20:443`. Su configuración utiliza `8443` dentro del contenedor y cierra la publicación HTTP del WAF. Validar la confianza de la CA en los clientes antes de considerar utilizable el acceso.
5. `7-RL-PROXY-FIX_nginx.sh` — ajusta la configuración Nginx relacionada con el tratamiento del protocolo reenviado.
6. `8-RL-PROXY-install_node_exporter.sh` y `9-RL-PROXY-install_fluent_bit.sh` — incorporan métricas y centralización de registros, sujetas a la disponibilidad de RL-MON-01.

Los scripts de instalación y configuración de WAF y HTTPS forman parte del despliegue implementado y probado de Recolección UY.

Los certificados TLS utilizados por la infraestructura requieren que los clientes confíen en la autoridad certificadora correspondiente.

Para tareas de mantenimiento o reconstrucción del entorno, respetar el orden de ejecución de los scripts y verificar la publicación HTTPS, el funcionamiento del WAF y el acceso a las tres aplicaciones.

Después de aplicar HTTPS, verificar Nginx y las respuestas de las tres aplicaciones por su hostname, comprobar las reglas DNAT/443 y limitar TCP/80 conforme a la política definida. El acceso Administrativo desde WAN requiere una decisión de autorización expresa, independiente de la instalación del WAF.

## 5.7 Operación del stack del proxy

La administración se efectúa desde el Compose ubicado en `/opt/recoleccion-proxy`, considerando que los scripts de WAF y HTTPS pueden modificar sus servicios:

```bash
cd /opt/recoleccion-proxy
sudo docker compose config
sudo docker compose ps
sudo docker compose up -d
```

Detener servicios únicamente mediante una decisión operativa que contemple el impacto sobre las tres aplicaciones. No utilizar `docker compose down -v` sin aprobación explícita. El comando `docker exec recoleccion_proxy nginx -t` corresponde al contenedor Nginx básico; identificar el nombre efectivo del contenedor tras la instalación del WAF antes de ejecutarlo.

---

# 6. DNS web, publicación y pruebas de clientes

## 6.1 DNS interno de Active Directory

En `WS-DC-01`, una vez preparada la DMZ, el script **`6-DNS_RegistroA_RecoleccionUY_v1.3.ps1`** debe configurar:

```bash
recoleccion.neltek.uy       -> 192.168.50.20
admin-recoleccion.neltek.uy -> 192.168.50.20
camiones-recoleccion.neltek.uy -> 192.168.50.20
```

Verificar que la variable `$ProxyServerIP` del script `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` contenga la dirección `192.168.50.20`, correspondiente a RL-PROXY-01.

El script crea o actualiza los registros A `recoleccion.neltek.uy`, `admin-recoleccion.neltek.uy` y `camiones-recoleccion.neltek.uy`, apuntando al servidor proxy.

La ejecución se realiza desde WS-DC-01. No es necesario repetir manualmente la creación de los registros en WS-DC-02, ya que la zona DNS integrada en Active Directory se replica entre ambos controladores.

```powershell
Resolve-DnsName recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName admin-recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName recoleccion.neltek.uy -Server 192.168.10.21
Resolve-DnsName admin-recoleccion.neltek.uy -Server 192.168.10.21
Resolve-DnsName camiones-recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName camiones-recoleccion.neltek.uy -Server 192.168.10.21
Test-NetConnection 192.168.50.20 -Port 80
```

Las dos primeras y dos últimas consultas deben devolver `192.168.50.20` **si el DNS interno ya se actualizó**.

## 6.2 Publicación WAN mediante RL-FW-01

Para el laboratorio, RL-FW-01 puede recibir una dirección WAN de `192.168.1.0/24` mediante DHCP (la IP efectiva debe consultarse en la interfaz WAN; **no es estática ni garantizada**). El firewall configura DNAT TCP/80 hacia `192.168.50.20:80`.

Desde una PC con ruta a la WAN de RL-FW-01:

```powershell
curl.exe -I -H "Host: recoleccion.neltek.uy" http://<IP_WAN_RL_FW_01>
curl.exe -I -H "Host: admin-recoleccion.neltek.uy" http://<IP_WAN_RL_FW_01>
```

Los ejemplos con `<IP_WAN_RL_FW_01>` son marcadores: sustituir únicamente por la IP comprobada en ese momento. **No asumir que la segunda aplicación está restringida**: el script Nginx revisado contiene ambos virtual hosts sin ACL de origen.

## 6.3 Resolver nombres desde clientes

La publicación HTTP con encabezado `Host` no demuestra que la resolución DNS de los clientes esté funcionando. Se requiere decidir la solución DNS externa/interna, el acceso al puerto 53 y, cuando corresponda, la separación de vistas o registros según el origen del cliente.

En un entorno de laboratorio, es posible crear entradas en el `hosts` de Windows:

```bash
<IP_WAN_RL_FW_01> recoleccion.neltek.uy
<IP_WAN_RL_FW_01> admin-recoleccion.neltek.uy
<IP_WAN_RL_FW_01> camiones-recoleccion.neltek.uy
```

Archivo: `C:\Windows\System32\drivers\etc\hosts`. Posteriormente:

```powershell
ipconfig /flushdns
curl.exe -I http://recoleccion.neltek.uy
curl.exe -I http://admin-recoleccion.neltek.uy
curl.exe -I http://camiones-recoleccion.neltek.uy
```

Retirar las entradas temporales al definir la solución DNS. Para equipos internos que pueden alcanzar la DMZ, la respuesta interna prevista es `192.168.50.20`; para externos detrás de la WAN del firewall podría ser su IP WAN u otra dirección publicada, según la arquitectura DNS definitiva.

**Protocolo de acceso:** comprobar si se completaron `5-RL-PROXY-generar_certificados_tls.sh` y `6-RL-PROXY-migrar_waf_https.sh`. Utilizar `https://` solo después de confirmar el servicio, el certificado, la confianza de su CA y la publicación TCP/443. La regla DNAT por sí sola no acredita HTTPS.

## 6.4 Verificaciones funcionales

- Comprobar login LDAP del Backend con usuario autorizado.
- Probar creación, consulta y reclamación de denuncias en Ciudadana.
- Comprobar fotografías privadas y permisos del almacenamiento.
- Comprobar listado, asignaciones y operaciones autorizadas en Admin.
- Verificar que MySQL no está publicado al host.
- Probar autenticación, listado de asignaciones, actualización de tareas y evidencias privadas en Camiones.
- Probar desde clientes autorizados y no autorizados una vez definida la política de acceso del Backend.
- Comprobar el WAF y HTTPS cuando se hayan aplicado sus scripts, sin confundir la existencia del instalador con su ejecución.

---

# 7. SSH y administración

Aplicar la configuración SSH **después de preparar la red y la integración con Active Directory**. Los scripts disponibles en `Scripts/Linux/RL-XXX-XX` son:

```bash
sudo bash 1-RL-XXX-config_ssh.sh
sudo bash 2-RL-XXX-config_ssh_users.sh
```

El primero controla la configuración y acceso SSH; el segundo gestiona usuarios y claves públicas de administración conforme al diseño de dominio. Adaptar y revisar las variables de cada servidor antes de ejecutarlos, manteniendo una sesión administrativa abierta hasta comprobar un acceso nuevo y los privilegios correspondientes. No compartir claves privadas ni contraseñas en la documentación.

---

# 8. Verificación final por servidor

| Servidor | Verificación |
|---|---|
| WS-DC-01 | AD DS, DNS SRV, DHCP y scripts de dominio |
| WS-DC-02 | Pertenencia, replicación AD/SYSVOL, DNS, DHCP Failover |
| RL-FW-01 | NIC correctas, rutas, masquerade, políticas interzona y DNAT/80/443, acceso a los tres backends |
| RL-APP-01 | `docker ps`, API `:8080`, Admin `:8081`, Camiones `:8082`, `recoleccion-db-net`, MySQL privado |
| RL-PROXY-01 | Nginx/WAF, HTTPS `:443` cuando esté configurado, dnsmasq `:53`, tres hostnames y acceso a backends |
| RL-MON-01 | Prometheus `:9090` local, Grafana `:3000`, OpenSearch y su almacenamiento; estado efectivo por confirmar |

Comandos esenciales:


### RL-APP-01

```bash
docker ps
docker network inspect recoleccion-db-net
curl -I http://192.168.30.20:8080
curl -I http://192.168.30.20:8081
curl -I http://192.168.30.20:8082
```


### RL-PROXY-01

```bash
docker ps
docker exec recoleccion_proxy nginx -t
dig @192.168.50.20 recoleccion.neltek.uy
dig @192.168.50.20 admin-recoleccion.neltek.uy
dig @192.168.50.20 camiones-recoleccion.neltek.uy
curl -I -H "Host: recoleccion.neltek.uy" http://192.168.50.20
curl -I -H "Host: admin-recoleccion.neltek.uy" http://192.168.50.20
curl -I -H "Host: camiones-recoleccion.neltek.uy" http://192.168.50.20
```


### Windows

```powershell
Resolve-DnsName recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName admin-recoleccion.neltek.uy -Server 192.168.10.21
Resolve-DnsName camiones-recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName camiones-recoleccion.neltek.uy -Server 192.168.10.21
```

## 8.1 RL-MON-01 — métricas y registros

Preparar el servidor `192.168.20.20/24` con gateway `192.168.20.1`, DNS AD y pertenencia al dominio, utilizando los scripts específicos:

1. `1-RL-MON-update.sh` — sistema Rocky Linux, paquetes y dependencias de contenedores.
2. `2-RL-MON-config_domain_2dns_v1.3.sh` — red, dominio y SSSD.
3. `3-RL-MON-monitoreo.sh` — instala Prometheus y Grafana, configura dashboards y targets; Prometheus se limita a acceso local en `9090` y Grafana utiliza `3000` conforme al script.
4. `4-RL-MON-OpenSearch.sh` — prepara OpenSearch y los servicios relacionados para centralización de registros.
5. `RL-MON-add_dashboard_general.sh` — incorpora el dashboard general del entorno.

Los agentes están definidos en `5-RL-APP-install_node_exporter.sh`, `6-RL-APP-install_fluent_bit.sh`, `8-RL-PROXY-install_node_exporter.sh` y `9-RL-PROXY-install_fluent_bit.sh`. Node Exporter proporciona métricas de host y Fluent Bit envía registros al servicio de logs. 

Aplicar únicamente los accesos necesarios desde las redes MONITOREO, APLICACIONES y DMZ mediante RL-FW-01; no publicar dashboards, exporters ni OpenSearch directamente a WAN.

Los servicios de monitoreo y centralización de registros forman parte de la infraestructura implementada y probada de Recolección UY. Las verificaciones incluidas en esta sección se mantienen como procedimientos de mantenimiento, diagnóstico y reconstrucción del entorno.

---

# 9. Orden maestro resumido

```bash
WS-DC-01 / WS-DC-02
  Configurar AD DS, DNS, DHCP, replicación y ámbitos aprobados.
  1-AD_Config_RecoleccionUY.ps1                     (WS-DC-01)
  2-WS-DC_Config_Local.ps1                          (ambos)
  3-WS-DC_RDP_Gestionar_Origenes.ps1                (ambos)
  4-AD_Politica_Contrasenas_Dominio.ps1             (WS-DC-01)
  5-GPO_Equipos_Inactividad.ps1                     (WS-DC-01)
  5-GPO_Equipos_Inactividad_Excepciones.ps1         (WS-DC-01)
RL-FW-01
  1-RL-FW_update.sh
  2-RL-FW-config_v1.1.sh
  RL-FW-config_domain.sh
  3-RL-FW-add_MON_AD.sh
  Verificar routing, NAT, puertos 8080/8081/8082 y AD.
RL-APP-01
  1-RL-APP-update.sh
  2-RL-APP-config_domain_2dns_v1.3.sh
  3-RL-APP-config_denuncias_storage_v1.1.sh
  4-RL-APP-config_docker_red.sh
  Docker Compose de recoleccion-api y MySQL.
  Docker Compose de recoleccion-admin.
  Docker Compose de recoleccion-camiones.
  Verificar almacenamiento, base compartida y puertos.
RL-PROXY-01
  1-RL-PROXY-update.sh
  2-RL-PROXY-config_domain_2dns_v1.3.sh
  3-RL-PROXY-config_proxy_http.sh
  4-RL-PROXY-install_WAF.sh
  5-RL-PROXY-generar_certificados_tls.sh
  6-RL-PROXY-migrar_waf_https.sh
  7-RL-PROXY-FIX_nginx.sh
  Verificar Nginx, WAF, certificados y tres hostnames.
DNS / PUBLICACIÓN
  6-DNS_RegistroA_RecoleccionUY_v1.3.ps1           (WS-DC-01)
  Confirmar registros A, DNS de clientes y reglas WAN.
RL-MON-01
  1-RL-MON-update.sh
  2-RL-MON-config_domain_2dns_v1.3.sh
  3-RL-MON-monitoreo.sh
  4-RL-MON-OpenSearch.sh
  RL-MON-add_dashboard_general.sh
AGENTES
  5-RL-APP-install_node_exporter.sh
  6-RL-APP-install_fluent_bit.sh
  8-RL-PROXY-install_node_exporter.sh
  9-RL-PROXY-install_fluent_bit.sh
SSH
  1-RL-XXX-config_ssh.sh y 2-RL-XXX-config_ssh_users.sh
  Aplicar por host con accesos y parámetros aprobados.
```

La configuración DNS y los agentes de monitoreo dependen de que sus servicios de destino estén preparados. No ejecutar una etapa dependiente antes de completar las condiciones de la sección correspondiente.

---

# 10. Seguridad, precauciones y pendientes

## 10.1 Precauciones de despliegue

- No ejecutar `docker compose down -v` sin decisión explícita sobre eliminación de volúmenes persistentes.
- No eliminar `recoleccion-db-net` mientras API/Admin/MySQL dependan de ella.
- No eliminar el volumen de MySQL ni el directorio persistente de denuncias.
- No publicar `3306` al host.
- No exponer contraseñas, secretos LDAP, claves privadas ni variables `.env` con valores reales.
- No mezclar archivos de las tres aplicaciones Laravel: cada proyecto posee su propio Compose, controladores, rutas y configuración.
- Evitar cambios de firewall y SSH que impidan la administración antes de validar una alternativa.
- No continuar con un componente si el anterior no supera sus verificaciones.

## 10.2 Parámetros por confirmar en el entorno

1. Ámbitos DHCP autorizados, rangos, exclusiones, reservas y necesidad de DHCP Relay.
2. DNS alcanzable y resolución definitiva para clientes internos y externos.
3. Restricciones de acceso desde WAN al Backend Administrativo y a la Aplicación Camiones, según la política de uso.
4. Estado efectivo de ejecución de WAF, certificados TLS y migración HTTPS, incluida confianza de la autoridad emisora en los clientes.
5. Disponibilidad de RL-MON-01, agentes, dashboards y centralización de registros.
6. Políticas de copias de seguridad, restauración, permisos y retención de datos.
7. Coherencia de montajes privados del directorio de fotografías entre scripts del host y los tres archivos Compose, además de resolución del host MySQL desde Camiones.

Los scripts incluidos en el proyecto corresponden a los procedimientos de configuración utilizados para desplegar la infraestructura de Recolección UY.

De acuerdo con las verificaciones realizadas por el responsable del proyecto, los componentes y servicios se encuentran implementados, operativos y probados.

Los procedimientos documentados permiten realizar tareas de mantenimiento, diagnóstico y reconstrucción de los servidores, manteniendo las configuraciones y dependencias establecidas.

## 10.3 Diagnóstico por capas

```bash
VMware → VMnet → MAC → NIC → ARP → IP → gateway → routing →
firewalld/NAT → DNS → TCP → AD/LDAP → Docker → Nginx → Laravel
```

Primero reunir evidencia de la capa afectada y corregir solo esa capa. No usar cambios de Laravel como primera respuesta a un fallo de conectividad.
