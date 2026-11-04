# Documentación Técnica del Servidor RL-PROXY-01

**Fecha de creación:** 03/11/2026  
**Proyecto:** Recolección UY  
**Servidor:** `RL-PROXY-01`  
**Estado documentado:** infraestructura implementada y operativa, incluida la publicación HTTPS con WAF.

## Índice

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-información-general)
  - [1.2. Rol del servidor](#12-rol-del-servidor)
  - [1.3. Justificación del sistema operativo](#13-justificación-del-sistema-operativo)
- [2. Ejecución de Scripts](#2-ejecución-de-scripts)
  - [2.1. Orden de ejecución](#21-orden-de-ejecución)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos del servidor](#23-scripts-específicos-del-servidor)
    - [2.3.1. `1-RL-PROXY-update.sh`](#231-1-rl-proxy-updatesh)
    - [2.3.2. `2-RL-PROXY-config_domain_2dns_v1.3.sh`](#232-2-rl-proxy-config_domain_2dns_v13sh)
    - [2.3.3. `3-RL-PROXY-config_proxy_http.sh`](#233-3-rl-proxy-config_proxy_httpsh)
    - [2.3.4. `4-RL-PROXY-install_WAF.sh`](#234-4-rl-proxy-install_wafsh)
    - [2.3.5. `5-RL-PROXY-generar_certificados_tls.sh`](#235-5-rl-proxy-generar_certificados_tlssh)
    - [2.3.6. `6-RL-PROXY-migrar_waf_https.sh`](#236-6-rl-proxy-migrar_waf_httpssh)
    - [2.3.7. `7-RL-PROXY-FIX_nginx.sh`](#237-7-rl-proxy-fix_nginxsh)
    - [2.3.8. `8-RL-PROXY-install_node_exporter.sh`](#238-8-rl-proxy-install_node_exportersh)
    - [2.3.9. `9-RL-PROXY-install_fluent_bit.sh`](#239-9-rl-proxy-install_fluent_bitsh)
  - [2.4. Scripts comunes a los servidores Linux](#24-scripts-comunes-a-los-servidores-linux)
    - [2.4.1. `1-RL-XXX-config_ssh.sh`](#241-1-rl-xxx-config_sshsh)
    - [2.4.2. `2-RL-XXX-config_ssh_users.sh`](#242-2-rl-xxx-config_ssh_userssh)
- [3. Arquitectura y componentes del servidor](#3-arquitectura-y-componentes-del-servidor)
  - [3.1. Flujo de publicación](#31-flujo-de-publicación)
  - [3.2. Componentes y dependencias](#32-componentes-y-dependencias)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
  - [4.1. Direccionamiento](#41-direccionamiento)
  - [4.2. Puertos y protocolos](#42-puertos-y-protocolos)
  - [4.3. Comprobaciones](#43-comprobaciones)
    - [4.3.1. Pruebas de acceso HTTPS](#431-pruebas-de-acceso-https)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
  - [5.1. Inventario de componentes](#51-inventario-de-componentes)
  - [5.2. Proyecto, redes y persistencia](#52-proyecto-redes-y-persistencia)
  - [5.3. Operación de contenedores](#53-operación-de-contenedores)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
  - [6.1. Directorios operativos](#61-directorios-operativos)
  - [6.2. Permisos TLS aplicados](#62-permisos-tls-aplicados)
- [7. Base de datos MySQL](#7-base-de-datos-mysql)
- [8. Seguridad y control de acceso](#8-seguridad-y-control-de-acceso)
  - [8.1. Autenticación de dominio y SSH](#81-autenticación-de-dominio-y-ssh)
  - [8.2. WAF, TLS y proxy](#82-waf-tls-y-proxy)
  - [8.3. Firewalld y SELinux](#83-firewalld-y-selinux)
- [9. Monitoreo y registros](#9-monitoreo-y-registros)
  - [9.1. Métricas](#91-métricas)
  - [9.2. Registros](#92-registros)
- [10. Copias de seguridad y recuperación](#10-copias-de-seguridad-y-recuperación)
  - [10.1. Elementos que requieren protección](#101-elementos-que-requieren-protección)
  - [10.2. Procedimiento de recuperación](#102-procedimiento-de-recuperación)
- [11. Administración y mantenimiento](#11-administración-y-mantenimiento)
  - [11.1. Estado del sistema](#111-estado-del-sistema)
  - [11.2. Mantenimiento del stack](#112-mantenimiento-del-stack)
- [12. Diagnóstico y resolución de problemas](#12-diagnóstico-y-resolución-de-problemas)
  - [12.1. Conectividad y DNS](#121-conectividad-y-dns)
  - [12.2. Dominio y SSH](#122-dominio-y-ssh)
  - [12.3. WAF, HTTPS y Nginx](#123-waf-https-y-nginx)
  - [12.4. Backend de las aplicaciones](#124-backend-de-las-aplicaciones)
  - [12.5. Almacenamiento](#125-almacenamiento)
  - [12.6. Monitoreo y registros](#126-monitoreo-y-registros)
- [13. Anexos](#13-anexos)

---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor |
|---|---|
| Nombre del servidor | `RL-PROXY-01` |
| Sistema operativo | Rocky Linux 9 |
| Interfaz de red | Una interfaz en DMZ; el nombre de dispositivo se debe consultar con `ip -br addr` antes de utilizarlo en comandos |
| Segmento | DMZ — `192.168.50.0/24` |
| Dirección IP | `192.168.50.20` |
| Máscara de subred | `255.255.255.0` (`/24`) |
| Gateway | `192.168.50.1` (`RL-FW-01`) |
| DNS primario | `192.168.10.20` (`WS-DC-01`) |
| DNS secundario | `192.168.10.21` (`WS-DC-02`) |
| Dominio | `neltek.uy` |

La configuración presenta **una única interfaz de red DMZ**; las interfaces de otras subredes corresponden al firewall, no al proxy.

## 1.2. Rol del servidor

`RL-PROXY-01` es el punto de entrada de las tres aplicaciones web de Recolección UY. Aloja un WAF con ModSecurity y OWASP Core Rule Set (CRS), un Nginx de proxy inverso y un servicio dnsmasq. El WAF termina TLS, recibe las solicitudes HTTPS de los clientes y entrega el tráfico HTTP internamente al Nginx del proxy. Nginx reenvía las solicitudes al servidor de aplicaciones `RL-APP-01` en los puertos `8080`, `8081` y `8082`.

También integra servicios para exportar métricas del sistema operativo y enviar registros centralizados a `RL-MON-01`. `RL-FW-01` controla el paso entre redes y la exposición WAN; los controladores de dominio aportan DNS y autenticación de administración.

## 1.3. Justificación del sistema operativo

Rocky Linux 9 proporciona una base de servidor con mantenimiento empresarial y soporte para Docker Engine, Docker Compose, SELinux, Firewalld, OpenSSH, SSSD y herramientas de autenticación con Active Directory. La gestión por consola permite administrar los contenedores, limitar la superficie de exposición y mantener una plataforma homogénea con los otros servidores Linux del laboratorio.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución

Los scripts específicos se ejecutan primero y los comunes de `Scripts/Linux/RL-XXX-XX/` **siempre al final**. El orden representa las dependencias de instalación y configuración, no una indicación de volver a ejecutar los instaladores sobre un entorno operativo sin necesidad.

| Orden | Script | Función |
|---:|---|---|
| 1 | `1-RL-PROXY-update.sh` | Actualiza/prepara Rocky Linux, Docker y dependencias base. |
| 2 | `2-RL-PROXY-config_domain_2dns_v1.3.sh` | Configura DMZ, DNS y unión al dominio. |
| 3 | `3-RL-PROXY-config_proxy_http.sh` | Despliega la base Nginx y dnsmasq y las rutas a las tres aplicaciones. |
| 4 | `4-RL-PROXY-install_WAF.sh` | Incorpora ModSecurity y OWASP CRS delante de Nginx. |
| 5 | `5-RL-PROXY-generar_certificados_tls.sh` | Prepara la CA interna y los certificados SAN de los tres dominios. |
| 6 | `6-RL-PROXY-migrar_waf_https.sh` | Publica HTTPS en 443 y deja de publicar HTTP/80 en el WAF. |
| 7 | `7-RL-PROXY-FIX_nginx.sh` | Ajusta Nginx y el tratamiento del protocolo reenviado. |
| 8 | `8-RL-PROXY-install_node_exporter.sh` | Incorpora métricas del host para Prometheus. |
| 9 | `9-RL-PROXY-install_fluent_bit.sh` | Centraliza registros hacia OpenSearch. |
| 10 | `1-RL-XXX-config_ssh.sh` | Configura acceso SSH administrativo seguro. |
| 11 | `2-RL-XXX-config_ssh_users.sh` | Configura claves SSH de usuarios autorizados. |

## 2.2. Procedimiento general

Desde el directorio donde se encuentre el archivo, ejecutar:

```bash
sed -i 's/\r$//' script.sh
chmod +x script.sh
sudo ./script.sh
```

El primer comando normaliza los saltos de línea, el segundo añade permiso de ejecución y el tercero ejecuta el script con privilegios. En las fichas siguientes se sustituye `script.sh` por cada nombre exacto. Los procedimientos que modifican acceso SSH, red, certificados o publicación requieren una sesión alternativa de administración disponible para contingencias.

## 2.3. Scripts específicos del servidor

### 2.3.1. `1-RL-PROXY-update.sh`

**Nombre del script:** `1-RL-PROXY-update.sh`

**Descripción:** preparación y actualización de Rocky Linux.
**Componentes que instala o utiliza:** componentes de sistema, Docker Engine, Docker Compose y dependencias de red, seguridad e integración con Active Directory.
**Componentes que configura:** servicios base del sistema, repositorios y dependencias para los siguientes despliegues.
**Archivos y directorios creados, modificados o utilizados:** la instalación de Docker utiliza los directorios y archivos del gestor de paquetes; no se atribuyen otros directorios propios sin el contenido literal del script.

```bash
sed -i 's/\r$//' 1-RL-PROXY-update.sh
chmod +x 1-RL-PROXY-update.sh
sudo ./1-RL-PROXY-update.sh
```

### 2.3.2. `2-RL-PROXY-config_domain_2dns_v1.3.sh`

**Nombre del script:** `2-RL-PROXY-config_domain_2dns_v1.3.sh`

**Descripción:** configuración IPv4 de la DMZ y unión de `RL-PROXY-01` al dominio `neltek.uy`.
**Componentes que instala o utiliza:** NetworkManager, herramientas DNS, Kerberos, realmd y SSSD conforme a las dependencias instaladas.
**Componentes que configura:** `192.168.50.20/24`, gateway `192.168.50.1`, DNS `192.168.10.20`/`192.168.10.21`, identidad del servidor y autenticación de dominio.
**Archivos y directorios creados, modificados o utilizados:** utiliza la configuración de NetworkManager y SSSD; comprobar el perfil de conexión y `/etc/sssd/sssd.conf` para identificar el estado exacto.

```bash
sed -i 's/\r$//' 2-RL-PROXY-config_domain_2dns_v1.3.sh
chmod +x 2-RL-PROXY-config_domain_2dns_v1.3.sh
sudo ./2-RL-PROXY-config_domain_2dns_v1.3.sh
```

### 2.3.3. `3-RL-PROXY-config_proxy_http.sh`

**Nombre del script:** `3-RL-PROXY-config_proxy_http.sh`

**Descripción:** configura la base del proxy inverso, previa a la capa WAF/TLS.
**Componentes que instala o utiliza:** Nginx y dnsmasq ejecutados como contenedores Docker.
**Componentes que configura:** `recoleccion_proxy`, `recoleccion_dns`, virtual hosts para Ciudadana, Admin y Camiones, rutas a `192.168.30.20:8080/8081/8082`, y DNS de los tres dominios apuntando a `192.168.50.20`.
**Archivos y directorios creados, modificados o utilizados:** crea/gestiona `/opt/recoleccion-proxy/` y `/opt/recoleccion-proxy/docker-compose.yml` más la configuración generada de Nginx/dnsmasq dentro del directorio del proyecto.
**Requisitos previos:** red DMZ y Docker operativos. **Su configuración HTTP inicial es una etapa de preparación; no representa el acceso público final HTTPS.** No volver a aplicar este instalador como sustituto de la configuración migrada a HTTPS.

```bash
sed -i 's/\r$//' 3-RL-PROXY-config_proxy_http.sh
chmod +x 3-RL-PROXY-config_proxy_http.sh
sudo ./3-RL-PROXY-config_proxy_http.sh
```

### 2.3.4. `4-RL-PROXY-install_WAF.sh`

**Nombre del script:** `4-RL-PROXY-install_WAF.sh`

**Descripción:** interpone un WAF delante del proxy Nginx.
**Componentes que instala o utiliza:** ModSecurity y OWASP CRS mediante imagen `owasp/modsecurity-crs:4.25.1-nginx-lts`.
**Componentes que configura:** contenedor `recoleccion_waf`, inspección de solicitudes y encaminamiento hacia Nginx interno, manteniendo los tres sitios.
**Archivos y directorios creados, modificados o utilizados:** utiliza/modifica el proyecto `/opt/recoleccion-proxy/` y su Compose; comprobar los archivos efectivos de reglas y configuración dentro del proyecto antes de cualquier edición.
**Requisitos previos:** proxy básico ya operativo. La publicación HTTP original del WAF es reemplazada posteriormente por la migración HTTPS.

```bash
sed -i 's/\r$//' 4-RL-PROXY-install_WAF.sh
chmod +x 4-RL-PROXY-install_WAF.sh
sudo ./4-RL-PROXY-install_WAF.sh
```

### 2.3.5. `5-RL-PROXY-generar_certificados_tls.sh`

**Nombre del script:** `5-RL-PROXY-generar_certificados_tls.sh`

**Descripción:** prepara la autoridad certificadora interna y el certificado de servidor con nombres alternativos SAN.
**Componentes que configura:** material TLS para `recoleccion.neltek.uy`, `admin-recoleccion.neltek.uy` y `camiones-recoleccion.neltek.uy`.
**Archivos y directorios creados, modificados o utilizados:** almacena el material TLS en el árbol `/opt/recoleccion-proxy/tls/`, con certificados y clave del servicio en `/opt/recoleccion-proxy/tls/certs/`.
**Seguridad:** proteger la clave privada; distribuir a clientes únicamente el certificado público de la CA. Generar el certificado no habilita HTTPS por sí solo.

```bash
sed -i 's/\r$//' 5-RL-PROXY-generar_certificados_tls.sh
chmod +x 5-RL-PROXY-generar_certificados_tls.sh
sudo ./5-RL-PROXY-generar_certificados_tls.sh
```

### 2.3.6. `6-RL-PROXY-migrar_waf_https.sh`

**Nombre del script:** `6-RL-PROXY-migrar_waf_https.sh`

**Descripción:** establece la publicación final mediante TLS en el WAF.
**Componentes que configura:** HTTPS en `192.168.50.20:443` hacia el puerto `8443` del contenedor WAF, TLS 1.2/1.3, tres nombres virtuales y comunicación HTTP interna WAF → Nginx.
**Archivos y directorios creados, modificados o utilizados:** actualiza la definición Compose y configuración TLS/WAF bajo `/opt/recoleccion-proxy/`.
**Seguridad:** deja de publicar HTTP/80 en el WAF y conserva Nginx y dnsmasq internos. La política DNAT de WAN se administra en `RL-FW-01`, no en este servidor.

```bash
sed -i 's/\r$//' 6-RL-PROXY-migrar_waf_https.sh
chmod +x 6-RL-PROXY-migrar_waf_https.sh
sudo ./6-RL-PROXY-migrar_waf_https.sh
```

### 2.3.7. `7-RL-PROXY-FIX_nginx.sh`

**Nombre del script:** `7-RL-PROXY-FIX_nginx.sh`

**Descripción:** aplica ajustes a Nginx después de configurar el WAF y HTTPS.
**Componentes que configura:** tratamiento del protocolo original reenviado y ajustes propios del proxy para conservar el comportamiento esperado de las aplicaciones Laravel.
**Archivos y directorios creados, modificados o utilizados:** modifica archivos de configuración de Nginx del proyecto `/opt/recoleccion-proxy/`; identificar sus rutas concretas mediante el script antes de edición manual.
**Requisitos previos:** despliegue WAF y migración TLS completados.

```bash
sed -i 's/\r$//' 7-RL-PROXY-FIX_nginx.sh
chmod +x 7-RL-PROXY-FIX_nginx.sh
sudo ./7-RL-PROXY-FIX_nginx.sh
```

### 2.3.8. `8-RL-PROXY-install_node_exporter.sh`

**Nombre del script:** `8-RL-PROXY-install_node_exporter.sh`

**Descripción:** despliega Node Exporter para obtener métricas del **host RL-PROXY-01**, no métricas individuales de cada contenedor.
**Componentes que configura:** consulta por Prometheus desde `RL-MON-01` mediante TCP/9100, con acceso restringido al origen de monitoreo autorizado.
**Rutas e imagen:** consultar el Compose creado por el propio script para identificar de forma inequívoca la ruta, etiqueta de imagen y nombre configurado del contenedor, sin sustituirlos por los de RL-APP-01.

```bash
sed -i 's/\r$//' 8-RL-PROXY-install_node_exporter.sh
chmod +x 8-RL-PROXY-install_node_exporter.sh
sudo ./8-RL-PROXY-install_node_exporter.sh
```

### 2.3.9. `9-RL-PROXY-install_fluent_bit.sh`

**Nombre del script:** `9-RL-PROXY-install_fluent_bit.sh`

**Descripción:** instala Fluent Bit para centralizar registros del servidor proxy.
**Componentes que configura:** captura de logs y envío hacia OpenSearch en `RL-MON-01`, `192.168.20.20:9200`; el índice específico de RL-PROXY-01 debe conservar la nomenclatura de servidor definida en la configuración efectiva.
**Rutas e imagen:** comprobar el Compose y los archivos generados por el script para conocer su nombre exacto de contenedor, imagen, versión, fuentes de logs y ubicación del búfer; no extrapolar los nombres de RL-APP-01.

```bash
sed -i 's/\r$//' 9-RL-PROXY-install_fluent_bit.sh
chmod +x 9-RL-PROXY-install_fluent_bit.sh
sudo ./9-RL-PROXY-install_fluent_bit.sh
```

## 2.4. Scripts comunes a los servidores Linux

Los dos scripts de `Scripts/Linux/RL-XXX-XX/` pertenecen a todos los servidores Linux y se ejecutan **después de los nueve scripts específicos**.

### 2.4.1. `1-RL-XXX-config_ssh.sh`

**Nombre del script:** `1-RL-XXX-config_ssh.sh`

**Descripción:** configura acceso SSH administrativo endurecido.
**Componentes que configura:** parámetros y restricciones de OpenSSH, integración de usuarios de dominio con PAM/SSSD, autorización de administración y reglas pertinentes de acceso.
**Archivos y directorios creados, modificados o utilizados:** utiliza la configuración de `sshd`, `/etc/ssh/sshd_config.d/00-recoleccion-uy.conf` y las políticas de elevación administrativa, incluida `/etc/sudoers.d/recoleccion-linux-admins` cuando está definida.
**Precaución:** comprobar el puerto efectivo con `sshd -T` y preservar una sesión alternativa hasta validar el nuevo acceso.

```bash
sed -i 's/\r$//' 1-RL-XXX-config_ssh.sh
chmod +x 1-RL-XXX-config_ssh.sh
sudo ./1-RL-XXX-config_ssh.sh
```

### 2.4.2. `2-RL-XXX-config_ssh_users.sh`

**Nombre del script:** `2-RL-XXX-config_ssh_users.sh`

**Descripción:** administra claves públicas SSH de los usuarios autorizados de Active Directory.
**Componentes que configura:** validación de cuentas mediante SSSD, pertenencia al grupo autorizado `gg_rec_server_admins_linux`, claves públicas y permisos seguros; no incorpora contraseñas privadas al servidor.
**Archivos y directorios creados, modificados o utilizados:** utiliza `/etc/ssh/authorized_keys/` y archivos por usuario autorizado.

```bash
sed -i 's/\r$//' 2-RL-XXX-config_ssh_users.sh
chmod +x 2-RL-XXX-config_ssh_users.sh
sudo ./2-RL-XXX-config_ssh_users.sh
```

---

# 3. Arquitectura y componentes del servidor

## 3.1. Flujo de publicación

```text
Clientes HTTPS
  |
  | TCP/443, recoleccion.neltek.uy / admin-recoleccion.neltek.uy /
  | camiones-recoleccion.neltek.uy
  v
RL-FW-01 (enrutamiento / filtrado / DNAT)
  |
  v
RL-PROXY-01 [DMZ 192.168.50.20]
  |-- recoleccion_waf (HTTPS/443 publicado -> TLS/8443 interno)
  |      | ModSecurity + OWASP CRS
  |      v
  |   recoleccion_proxy (Nginx, HTTP interno)
  |      |-- 192.168.30.20:8080 -> Ciudadana
  |      |-- 192.168.30.20:8081 -> Administración
  |      `-- 192.168.30.20:8082 -> Camiones
  |
  |-- recoleccion_dns (dnsmasq, 192.168.50.20:53 TCP/UDP)
  |-- Node Exporter -> consulta por RL-MON-01:9100
  `-- Fluent Bit -> OpenSearch RL-MON-01:9200
```

## 3.2. Componentes y dependencias

| Componente | Función |
|---|---|
| `recoleccion_waf` | Recepción HTTPS, terminación TLS e inspección WAF. |
| `recoleccion_proxy` | Enrutamiento de los tres virtual hosts hacia RL-APP-01. |
| `recoleccion_dns` | Resolución local de dominios y reenvío a DNS de AD. |
| `RL-FW-01` | Políticas de tráfico, segmentación y publicación WAN. |
| `RL-APP-01` | Ejecución de aplicaciones Laravel y MySQL compartido. |
| `WS-DC-01` / `WS-DC-02` | DNS y Active Directory. |
| `RL-MON-01` | Prometheus, OpenSearch y visualización de monitoreo. |

El uso de HTTP en los tramos **internos** no significa que los clientes se conecten por HTTP. El acceso publicado de las aplicaciones es **HTTPS**.

---

# 4. Configuración de red y conectividad

## 4.1. Direccionamiento

| Dato | Valor |
|---|---|
| Interfaz | NIC DMZ única; consultar nombre exacto en el host |
| IP/máscara | `192.168.50.20/24` |
| Red | `192.168.50.0/24` |
| Gateway | `192.168.50.1` |
| DNS1 / DNS2 | `192.168.10.20` / `192.168.10.21` |

## 4.2. Puertos y protocolos

| Flujo | Puerto | Descripción |
|---|---|---|
| Clientes autorizados → RL-PROXY-01 | TCP/443 | HTTPS público; WAF TLS. |
| Clientes DNS autorizados → RL-PROXY-01 | TCP/53 y UDP/53 | dnsmasq en DMZ. |
| WAF → Nginx | HTTP interno | Tráfico entre contenedores, sin publicación de Nginx al host tras la migración. |
| RL-PROXY-01 → RL-APP-01 | TCP/8080, 8081, 8082 | Tráfico HTTP del proxy hacia las aplicaciones. |
| RL-MON-01 → RL-PROXY-01 | TCP/9100 | Métricas Node Exporter. |
| RL-PROXY-01 → RL-MON-01 | TCP/9200 | Envío de registros a OpenSearch. |
| Administración autorizada → RL-PROXY-01 | Puerto SSH configurado | Consultar `sshd -T`; el script común define su política. |
| RL-PROXY-01 → DNS de AD | TCP/UDP 53 | Consultas de resolución de nombres. |

El puerto `8443` corresponde al **interior del contenedor WAF**; el cliente utiliza **443**. La publicación HTTP/80 del WAF está cerrada después de la migración. El permiso de acceso desde WAN depende de las reglas efectivas de `RL-FW-01`.

## 4.3. Comprobaciones

```bash
ip -br addr
ip route
nmcli connection show --active
resolvectl status
getent hosts recoleccion.neltek.uy
dig @192.168.50.20 recoleccion.neltek.uy
dig @192.168.50.20 admin-recoleccion.neltek.uy
dig @192.168.50.20 camiones-recoleccion.neltek.uy
sudo ss -lntup
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
```

### 4.3.1. Pruebas de acceso HTTPS

Desde un cliente con la CA interna de confianza instalada:

```bash
curl -sSI https://recoleccion.neltek.uy
curl -sSI https://admin-recoleccion.neltek.uy
curl -sSI https://camiones-recoleccion.neltek.uy
```

Para probar directamente el destino `192.168.50.20` preservando el nombre TLS/SNI:

```bash
curl -sSI --resolve recoleccion.neltek.uy:443:192.168.50.20 https://recoleccion.neltek.uy
curl -sSI --resolve admin-recoleccion.neltek.uy:443:192.168.50.20 https://admin-recoleccion.neltek.uy
curl -sSI --resolve camiones-recoleccion.neltek.uy:443:192.168.50.20 https://camiones-recoleccion.neltek.uy
```

No utilizar `-k` como prueba de confianza: requiere una CA válida y confiable para el cliente. El código HTTP de respuesta debe interpretarse junto con la ruta y la aplicación, no como criterio único de funcionamiento.

---

# 5. Servicios y contenedores Docker

## 5.1. Inventario de componentes

| Contenedor / servicio | Componente | Imagen / versión | Exposición |
|---|---|---|---|
| `recoleccion_waf` | ModSecurity + OWASP CRS | `owasp/modsecurity-crs:4.25.1-nginx-lts` | Host `192.168.50.20:443` a puerto de contenedor `8443` |
| `recoleccion_proxy` | Nginx inverso | Etiqueta exacta: consultar Compose | Interna, sin puerto HTTP publicado al host en la configuración HTTPS final |
| `recoleccion_dns` | dnsmasq | Imagen construida por el script; inspeccionar Compose | `192.168.50.20:53` TCP/UDP |
| Servicio Node Exporter | Métricas del host | Etiqueta y `container_name`: consultar Compose generado por `8-RL-PROXY-install_node_exporter.sh` | TCP/9100 restringido |
| Servicio Fluent Bit | Agente de logs | Etiqueta y `container_name`: consultar Compose generado por `9-RL-PROXY-install_fluent_bit.sh` | Salida a `192.168.20.20:9200` |

Los nombres `recoleccion_waf`, `recoleccion_proxy` y `recoleccion_dns` se encuentran identificados en la configuración del proyecto. Para los agentes se mantiene explícita la comprobación del Compose correspondiente, sin atribuirles por analogía los nombres o etiquetas de RL-APP-01.

## 5.2. Proyecto, redes y persistencia

El proyecto principal se administra en `/opt/recoleccion-proxy/` y dispone de `docker-compose.yml`. La definición de redes y montajes concretos se consulta en su Compose vigente, ya modificado por el despliegue WAF y TLS. El stack básico establece reinicio `unless-stopped`; revisar la política del WAF y los agentes en sus definiciones efectivas antes de modificarlas.

```bash
cd /opt/recoleccion-proxy
sudo docker compose config
sudo docker compose ps
sudo docker network ls
sudo docker inspect recoleccion_waf --format '{{json .Mounts}}'
sudo docker inspect recoleccion_proxy --format '{{json .Mounts}}'
sudo docker inspect recoleccion_dns --format '{{json .Mounts}}'
```

## 5.3. Operación de contenedores

```bash
sudo docker ps -a
sudo docker logs --tail 100 recoleccion_waf
sudo docker logs --tail 100 recoleccion_proxy
sudo docker logs --tail 100 recoleccion_dns
sudo docker exec recoleccion_proxy nginx -t
sudo docker exec recoleccion_waf nginx -t
sudo docker compose -f /opt/recoleccion-proxy/docker-compose.yml ps
```

No utilizar `docker compose down -v` sobre el proyecto. Tampoco regenerar el stack HTTP inicial sobre una configuración HTTPS ya aplicada: podría sustituir parámetros vigentes del WAF/TLS.

---

# 6. Estructura de directorios y almacenamiento

## 6.1. Directorios operativos

| Ruta | Uso |
|---|---|
| `/opt/recoleccion-proxy/` | Proyecto principal Docker Compose del proxy. |
| `/opt/recoleccion-proxy/docker-compose.yml` | Definición de servicios del proyecto. |
| `/opt/recoleccion-proxy/tls/` | Configuración y recursos TLS. |
| `/opt/recoleccion-proxy/tls/certs/` | Certificados y clave privada del servicio. |
| `/opt/recoleccion-proxy/tls/certs/recoleccion.key` | Clave privada TLS: acceso restringido. |
| `/etc/sssd/sssd.conf` | Configuración de Active Directory / SSSD. |
| `/etc/ssh/sshd_config.d/00-recoleccion-uy.conf` | Política SSH del proyecto. |
| `/etc/ssh/authorized_keys/` | Claves públicas SSH de usuarios autorizados. |
| `/etc/sudoers.d/recoleccion-linux-admins` | Política de administración delegada. |

Los demás nombres exactos de archivos de Nginx, dnsmasq, WAF y agentes deben leerse en el Compose o en los scripts correspondientes antes de realizar modificaciones.

## 6.2. Permisos TLS aplicados

Los siguientes permisos y grupos forman parte del procedimiento de protección de claves:

```bash
sudo chgrp 101 /opt/recoleccion-proxy/tls/certs
sudo chgrp 101 /opt/recoleccion-proxy/tls/certs/recoleccion.key
sudo chmod 750 /opt/recoleccion-proxy/tls/certs
sudo chmod 640 /opt/recoleccion-proxy/tls/certs/recoleccion.key
sudo chgrp 101 /opt/recoleccion-proxy/tls
sudo chmod 710 /opt/recoleccion-proxy/tls
```

El objetivo es permitir al proceso autorizado acceder a la clave y negar lectura a usuarios no autorizados. Verificar permisos y propietario antes de cambios manuales:

```bash
sudo stat -c '%a %u:%g %n' /opt/recoleccion-proxy/tls /opt/recoleccion-proxy/tls/certs /opt/recoleccion-proxy/tls/certs/recoleccion.key
sudo du -sh /opt/recoleccion-proxy
sudo df -h /opt/recoleccion-proxy
```

---

# 7. Base de datos MySQL

**No aplica como servicio local.** `RL-PROXY-01` no aloja MySQL ni debe publicar TCP/3306. MySQL compartido se ejecuta en `RL-APP-01` detrás de las aplicaciones. Los contenedores del proxy encaminan solicitudes web y no requieren acceso directo a MySQL.

---

# 8. Seguridad y control de acceso

## 8.1. Autenticación de dominio y SSH

El servidor está integrado en `neltek.uy` mediante realmd/SSSD. Los scripts comunes configuran acceso SSH administrativo y claves públicas de cuentas autorizadas, con el grupo `gg_rec_server_admins_linux`. La elevación se gestiona con `sudo` bajo la política local.

```bash
realm list
systemctl status sssd --no-pager
sudo sshd -T | grep -Ei '^(port|passwordauthentication|pubkeyauthentication|permitrootlogin|authorizedkeysfile)'
sudo visudo -cf /etc/sudoers
sudo systemctl status sshd --no-pager
```

No suponer que el puerto SSH es 22: utilizar el puerto que devuelve la configuración activa.

## 8.2. WAF, TLS y proxy

- El WAF incorpora ModSecurity y OWASP CRS delante de Nginx.
- La terminación HTTPS utiliza TLS 1.2/1.3 en el WAF con certificado SAN para los tres dominios.
- La CA pública interna debe estar instalada como autoridad de confianza en los clientes.
- El puerto HTTP/80 no se publica en el WAF después de la migración.
- El backend recibe comunicaciones internas HTTP, sin deshacer el HTTPS de cara a los usuarios.
- El modo exacto vigente de ModSecurity (`On` o `DetectionOnly`) se consulta en la configuración efectiva. La presencia del motor no demuestra por sí sola que todas las reglas estén bloqueando solicitudes.
- Las cabeceras `X-Forwarded-Proto` deben ser establecidas o saneadas por el proxy de confianza; no confiar indiscriminadamente en cabeceras suministradas por el cliente.

## 8.3. Firewalld y SELinux

Verificar la zona de DMZ y los permisos de red definidos por los scripts, sin trasladar a este servidor reglas de `RL-FW-01`:

```bash
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
getenforce
sudo sestatus
```

La publicación administrativa desde WAN requiere una política de autorización explícita; disponer de un virtual host no implica que cualquier origen deba acceder a él.

---

# 9. Monitoreo y registros

## 9.1. Métricas

Node Exporter entrega datos del sistema operativo de `RL-PROXY-01` a Prometheus en `RL-MON-01` (`192.168.20.20`). La consulta se efectúa por TCP/9100 y debe limitarse al origen autorizado; las métricas son del host, no por contenedor individual.

```bash
sudo ss -lntp | grep ':9100'
curl -fsS http://192.168.50.20:9100/metrics | head
```

El endpoint HTTP de métricas es interno; no se debe reemplazar por HTTPS solo porque las aplicaciones públicas lo utilicen.

## 9.2. Registros

Fluent Bit recibe logs del proxy/servicios según su configuración y los remite al OpenSearch de `RL-MON-01` por `192.168.20.20:9200`. Los registros deben permitir identificar `RL-PROXY-01` con la nomenclatura específica de servidor.

```bash
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
sudo docker logs --tail 100 recoleccion_waf
sudo docker logs --tail 100 recoleccion_proxy
sudo docker logs --tail 100 recoleccion_dns
sudo journalctl -u docker -n 100 --no-pager
```

La ruta exacta del Compose, el índice OpenSearch y los filtros de Fluent Bit se determinan por el archivo de configuración instalado en el proxy, evitando confundirlos con los del servidor de aplicaciones.

---

# 10. Copias de seguridad y recuperación

## 10.1. Elementos que requieren protección

- Compose y configuración de Nginx, dnsmasq, ModSecurity y OWASP CRS bajo `/opt/recoleccion-proxy/`.
- Certificados, CA y claves TLS, con almacenamiento protegido y control de acceso restringido.
- Configuración de red, SSH, Firewalld, SSSD, sudo y demás parámetros específicos del servidor.
- Configuración y estado persistente de los agentes de métricas/registros, cuando corresponda.

## 10.2. Procedimiento de recuperación

1. Recuperar el sistema operativo y las configuraciones de red/identidad autorizadas.
2. Restaurar el proyecto Compose con la **configuración HTTPS vigente**, no la versión HTTP inicial.
3. Restaurar certificados y permisos de claves; verificar la correspondencia del certificado SAN con los tres dominios.
4. Validar Compose y levantar los servicios necesarios sin eliminar volúmenes.
5. Validar Nginx, WAF, resolución dnsmasq y conexiones a RL-APP-01.
6. Verificar HTTPS de los tres dominios con clientes que confíen en la CA.
7. Comprobar métricas, registros y acceso administrativo.

No se atribuye una periodicidad, retención o destino de respaldos que no haya sido establecido expresamente para este servidor.

---

# 11. Administración y mantenimiento

## 11.1. Estado del sistema

```bash
hostnamectl
ip -br addr
ip route
systemctl --failed
sudo systemctl status docker firewalld sssd sshd --no-pager
sudo docker ps -a
sudo df -h
sudo journalctl -p warning -n 100 --no-pager
```

## 11.2. Mantenimiento del stack

```bash
cd /opt/recoleccion-proxy
sudo docker compose config
sudo docker compose ps
sudo docker exec recoleccion_proxy nginx -t
sudo docker exec recoleccion_waf nginx -t
sudo docker compose logs --tail 100
```

La actualización de imágenes, certificados o archivos Compose debe contemplar los tres virtual hosts, el WAF, la cadena de confianza TLS y la disponibilidad de `RL-APP-01`. No ejecutar instaladores que regeneran la configuración HTTP inicial sobre el stack HTTPS, ni recrear certificados sin una decisión operativa explícita. Resguardar configuraciones antes de cualquier modificación.

---

# 12. Diagnóstico y resolución de problemas

## 12.1. Conectividad y DNS

```bash
ip -br addr
ip route
ping -c 3 192.168.50.1
dig @192.168.50.20 recoleccion.neltek.uy
dig @192.168.10.20 recoleccion.neltek.uy
dig @192.168.10.21 camiones-recoleccion.neltek.uy
sudo docker logs --tail 100 recoleccion_dns
```

Confirmar que los tres nombres resuelven al destino publicado `192.168.50.20` dentro de la topología DMZ y que el firewall permite el tráfico autorizado.

## 12.2. Dominio y SSH

```bash
realm list
getent passwd 'USUARIO_AD@neltek.uy'
systemctl status sssd --no-pager
sudo sshd -t
sudo sshd -T | grep '^port '
sudo journalctl -u sshd -n 80 --no-pager
```

Sustituir `USUARIO_AD` por una cuenta real autorizada; no incluir secretos en registros ni documentos.

## 12.3. WAF, HTTPS y Nginx

```bash
sudo docker compose -f /opt/recoleccion-proxy/docker-compose.yml ps
sudo docker exec recoleccion_waf nginx -t
sudo docker exec recoleccion_proxy nginx -t
sudo docker logs --tail 100 recoleccion_waf
sudo docker logs --tail 100 recoleccion_proxy
openssl s_client -connect 192.168.50.20:443 -servername recoleccion.neltek.uy </dev/null
curl -sSI --resolve recoleccion.neltek.uy:443:192.168.50.20 https://recoleccion.neltek.uy
curl -sSI --resolve admin-recoleccion.neltek.uy:443:192.168.50.20 https://admin-recoleccion.neltek.uy
curl -sSI --resolve camiones-recoleccion.neltek.uy:443:192.168.50.20 https://camiones-recoleccion.neltek.uy
```

Verificar que el certificado incluya el dominio consultado, que la CA esté confiada y que el backend correspondiente responda. Un error de certificado no debe ocultarse con `curl -k` en comprobaciones de seguridad.

## 12.4. Backend de las aplicaciones

```bash
curl -sSI http://192.168.30.20:8080
curl -sSI http://192.168.30.20:8081
curl -sSI http://192.168.30.20:8082
```

**Estas tres pruebas HTTP son exclusivamente de conectividad interna proxy → aplicaciones**. La prueba de publicación para usuarios se hace mediante HTTPS y dominio. Si el backend responde pero el acceso público falla, diagnosticar DNS, WAF, TLS, Nginx y `RL-FW-01` por separado.

## 12.5. Almacenamiento

```bash
sudo df -h
sudo du -sh /opt/recoleccion-proxy
sudo ls -ld /opt/recoleccion-proxy/tls /opt/recoleccion-proxy/tls/certs
sudo docker system df
```

No eliminar volúmenes, certificados ni archivos de configuración para liberar espacio sin identificar previamente su función.

## 12.6. Monitoreo y registros

```bash
sudo ss -lntp | grep ':9100'
curl -fsS http://192.168.50.20:9100/metrics | head
sudo docker ps -a
sudo journalctl -u docker -n 100 --no-pager
```

Verificar además conectividad saliente a OpenSearch `192.168.20.20:9200`, los registros del contenedor Fluent Bit identificado en su Compose y la presencia del índice propio de `RL-PROXY-01` en la plataforma de monitoreo.

---

# 13. Anexos

Sección reservada para anexos técnicos futuros. Se incorporarán únicamente cuando se soliciten, con numeración y título propios. **Anexos permanecerá siempre como la última sección del documento.**
