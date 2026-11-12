# Documentación Técnica del Servidor RL-FW-01

**Fecha de creación:** 03/11/2026  
**Proyecto:** Recolección UY  
**Servidor:** `RL-FW-01`  
**Estado documentado:** infraestructura implementada y operativa, incluidas todas las interfaces necesarias.

---


## Índice

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-información-general)
    - [1.1.1. Interfaces y segmentos](#111-interfaces-y-segmentos)
  - [1.2. Rol del servidor](#12-rol-del-servidor)
  - [1.3. Justificación del sistema operativo](#13-justificación-del-sistema-operativo)
- [2. Ejecución de Scripts](#2-ejecución-de-scripts)
  - [2.1. Orden de ejecución](#21-orden-de-ejecución)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos del servidor](#23-scripts-específicos-del-servidor)
    - [2.3.1. `1-RL-FW_update.sh`](#231-1-rl-fw_updatesh)
    - [2.3.2. `2-RL-FW-config_v1.1.sh`](#232-2-rl-fw-config_v11sh)
    - [2.3.3. `RL-FW-config_domain.sh`](#233-rl-fw-config_domainsh)
    - [2.3.4. `3-RL-FW-add_MON_AD.sh`](#234-3-rl-fw-add_mon_adsh)
    - [2.3.5. `4-RL-FW-add_Zabbix.sh`](#235-4-rl-fw-add_zabbixsh)
  - [2.4. Scripts comunes a los servidores Linux](#24-scripts-comunes-a-los-servidores-linux)
    - [2.4.1. `1-RL-XXX-config_ssh.sh`](#241-1-rl-xxx-config_sshsh)
    - [2.4.2. `2-RL-XXX-config_ssh_users.sh`](#242-2-rl-xxx-config_ssh_userssh)
- [3. Arquitectura y componentes del servidor](#3-arquitectura-y-componentes-del-servidor)
  - [3.1. Topología lógica](#31-topología-lógica)
  - [3.2. Tráfico de aplicaciones](#32-tráfico-de-aplicaciones)
  - [3.3. Dependencias](#33-dependencias)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
  - [4.1. NetworkManager y rutas](#41-networkmanager-y-rutas)
  - [4.2. Zonas, políticas y filtrado](#42-zonas-políticas-y-filtrado)
  - [4.3. Flujos principales](#43-flujos-principales)
  - [4.4. NAT, DNAT y comunicaciones interiores](#44-nat-dnat-y-comunicaciones-interiores)
  - [4.5. Redes OFICINAS e INFORMÁTICA](#45-redes-oficinas-e-informática)
  - [4.6. Pruebas de red](#46-pruebas-de-red)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
  - [5.1. Aplicación a RL-FW-01](#51-aplicación-a-rl-fw-01)
  - [5.2. Gestión de servicios](#52-gestión-de-servicios)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
  - [6.1. Rutas funcionales](#61-rutas-funcionales)
  - [6.2. Permisos y persistencia](#62-permisos-y-persistencia)
- [7. Base de datos MySQL](#7-base-de-datos-mysql)
- [8. Seguridad y control de acceso](#8-seguridad-y-control-de-acceso)
  - [8.1. Active Directory y SSSD](#81-active-directory-y-sssd)
  - [8.2. SSH y usuarios autorizados](#82-ssh-y-usuarios-autorizados)
  - [8.3. SELinux y Firewalld](#83-selinux-y-firewalld)
  - [8.4. Control de acceso WAN](#84-control-de-acceso-wan)
- [9. Monitoreo y registros](#9-monitoreo-y-registros)
  - [9.1. Observabilidad del firewall](#91-observabilidad-del-firewall)
  - [9.2. Eventos y diagnóstico](#92-eventos-y-diagnóstico)
- [10. Copias de seguridad y recuperación](#10-copias-de-seguridad-y-recuperación)
  - [10.1. Elementos a proteger](#101-elementos-a-proteger)
  - [10.2. Respaldo operativo de configuraciones](#102-respaldo-operativo-de-configuraciones)
  - [10.3. Recuperación](#103-recuperación)
- [11. Administración y mantenimiento](#11-administración-y-mantenimiento)
  - [11.1. Inspección](#111-inspección)
  - [11.2. Actualizaciones](#112-actualizaciones)
  - [11.3. Cambios en políticas](#113-cambios-en-políticas)
- [12. Diagnóstico y resolución de problemas](#12-diagnóstico-y-resolución-de-problemas)
  - [12.1. WAN y conectividad](#121-wan-y-conectividad)
  - [12.2. Enrutamiento](#122-enrutamiento)
  - [12.3. HTTPS / DNAT](#123-https--dnat)
  - [12.4. Dominio y SSH](#124-dominio-y-ssh)
  - [12.5. Firewalld y NAT](#125-firewalld-y-nat)
  - [12.6. Interfaces OFICINAS / INFORMÁTICA](#126-interfaces-oficinas--informática)
  - [12.7. Almacenamiento y registros](#127-almacenamiento-y-registros)
- [13. Anexos](#13-anexos)


---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor |
|---|---|
| Nombre del servidor | `RL-FW-01` |
| Sistema operativo | Rocky Linux 9 |
| Rol | Firewall, router interredes y NAT/DNAT |
| Dominio | `neltek.uy` |
| DNS primario | `192.168.10.20` — WS-DC-01 |
| DNS secundario | `192.168.10.21` — WS-DC-02 |
| Gateway predeterminado | Obtenido por DHCP en WAN `ens33`; dirección no fija |

### 1.1.1. Interfaces y segmentos

| Interfaz | Segmento | Dirección IPv4 | Máscara | Gateway del segmento |
|---|---|---|---|---|
| `ens33` | WAN — VMware Bridged | DHCP; variable | Asignada por DHCP | Ruta predeterminada recibida por DHCP |
| `ens36` | SERVICIOS | `192.168.10.1` | `/24` (`255.255.255.0`) | El propio `192.168.10.1` para clientes |
| `ens37` | MONITOREO | `192.168.20.1` | `/24` (`255.255.255.0`) | El propio `192.168.20.1` para clientes |
| `ens38` | APLICACIONES | `192.168.30.1` | `/24` (`255.255.255.0`) | El propio `192.168.30.1` para clientes |
| `ens39` | DMZ | `192.168.50.1` | `/24` (`255.255.255.0`) | El propio `192.168.50.1` para clientes |
| `ens40` | INFORMÁTICA | IPv4 no confirmada en evidencia recuperada | Sin dato confirmado | Sin dato confirmado |
| `ens41` | OFICINAS | IPv4 no confirmada en evidencia recuperada | Sin dato confirmado | Sin dato confirmado |

La operación inicial se basó en cinco interfaces con `ens33` a `ens39`. Posteriormente se añadieron `ens40` y `ens41` para ampliar los segmentos del laboratorio (OFICINAS e INFORMÁTICA). Las últimas observaciones conocidas de `ip -br addr` mostraban ambas interfaces `UP` con dirección IPv6 de enlace local y sin IPv4 visible. Esto **no determina** que la ampliación funcional finalmente aplicada carezca de IPv4: su direccionamiento debe extraerse de la configuración y scripts efectivos antes de consignarlo. No se inventan rangos, DHCP, NAT ni políticas para estas redes.

## 1.2. Rol del servidor

RL-FW-01 es el punto central de encaminamiento y filtrado entre SERVICIOS, MONITOREO, APLICACIONES, DMZ y la red WAN. Proporciona salida mediante NAT masquerade, reglas de comunicación entre subredes y traducción de puertos de publicación hacia el proxy de Recolección UY.

Los usuarios acceden por **HTTPS/443** a RL-PROXY-01; el firewall permite la comunicación correspondiente con la DMZ. El proxy retransmite internamente hacia RL-APP-01 por HTTP en los puertos `8080`, `8081` y `8082`. RL-FW-01 no termina TLS, no aloja las aplicaciones ni administra los contenedores del proxy.

## 1.3. Justificación del sistema operativo

Rocky Linux 9 ofrece NetworkManager, Firewalld/nftables, herramientas de enrutamiento, registros de sistema, controles SELinux y servicios de integración con Active Directory. Permite implementar un firewall de laboratorio administrable por consola sin necesidad de Docker y con separación explícita de interfaces.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución

Ejecutar primero los scripts específicos de RL-FW-01 y **siempre al final los scripts comunes** de `Scripts/Linux/RL-XXX-XX/`.

| Orden | Script | Función |
|---|---|---|
| 1 | `1-RL-FW_update.sh` | Prepara Rocky Linux 9, NetworkManager, OpenSSH, Firewalld, SELinux, herramientas de red y dependencias AD/LDAP. Habilita IPv4 forwarding. |
| 2 | `2-RL-FW-config_v1.1.sh` | Configura las interfaces WAN, SERVICIOS, MONITOREO, APLICACIONES y DMZ, zonas y políticas Firewalld, masquerade y DNAT. |
| 3 | `RL-FW-config_domain.sh` | Integra `RL-FW-01` en el dominio neltek.uy por realmd, Kerberos y SSSD. |
| 4 | `3-RL-FW-add_MON_AD.sh` | Amplía las políticas de conectividad para los servicios de monitoreo y Active Directory. |
| 5 | `4-RL-FW-add_Zabbix.sh` | Configura políticas específicas de Firewalld para comunicar Zabbix Server en `RL-MON-01` con los agentes de `WS-DC-01` y `WS-DC-02`. |
| 6 | `1-RL-XXX-config_ssh.sh` | Aplica las restricciones de SSH y administración Linux comunes del laboratorio. |
| 7 | `2-RL-XXX-config_ssh_users.sh` | Gestiona las claves públicas SSH de los usuarios de Active Directory autorizados. |

## 2.2. Procedimiento general

Desde la carpeta que contiene el script correspondiente:

```bash
sed -i 's/\r$//' script.sh
chmod +x script.sh
sudo ./script.sh
```

El primer comando normaliza terminaciones CRLF; el segundo habilita la ejecución y el tercero ejecuta el archivo con privilegios. Los nombres exactos se encuentran en los apartados individuales.

**Precaución operativa:** los cambios de interfaces, routing, Firewalld y SSH pueden interrumpir la conectividad. Mantener acceso por consola de la VM antes de ejecutar o repetir estas configuraciones.

## 2.3. Scripts específicos del servidor

### 2.3.1. `1-RL-FW_update.sh`

**Nombre del script:** `1-RL-FW_update.sh`.

**Descripción:** Prepara Rocky Linux 9, NetworkManager, OpenSSH, Firewalld, SELinux, herramientas de red y dependencias AD/LDAP. Habilita IPv4 forwarding.

**Componentes que instala o utiliza:** Servicios del sistema, módulos y paquetes de red. No instala Docker.

**Componentes que configura:** Integración y comprobaciones asociadas a su función de infraestructura.

**Archivos y directorios creados, modificados o utilizados:** Configuración y parámetros de encaminamiento; repositorios y servicios gestionados por el sistema. Los nombres exactos de perfiles y archivos que genere se determinan por el propio script.

**Requisitos previos:** Componentes de las etapas anteriores disponibles, y conectividad a DNS y servicios correspondientes.

**Ejecución:**

```bash
sed -i 's/\r$//' 1-RL-FW_update.sh
chmod +x 1-RL-FW_update.sh
sudo ./1-RL-FW_update.sh
```

### 2.3.2. `2-RL-FW-config_v1.1.sh`

**Nombre del script:** `2-RL-FW-config_v1.1.sh`.

**Descripción:** Configura las interfaces WAN, SERVICIOS, MONITOREO, APLICACIONES y DMZ, zonas y políticas Firewalld, masquerade y DNAT.

**Componentes que instala o utiliza:** NetworkManager y Firewalld previamente preparados.

**Componentes que configura:** Red WAN/segmentos, zonas, políticas, NAT masquerade, DNAT hacia el proxy, encaminamiento y accesos internos.

**Archivos y directorios creados, modificados o utilizados:** Perfiles de NetworkManager, zonas/políticas de Firewalld y reglas NAT/DNAT. Los nombres exactos de perfiles y archivos que genere se determinan por el propio script.

**Requisitos previos:** Consola de VMware accesible, identificación correcta de interfaces y conectividad física/virtual.

**Ejecución:**

```bash
sed -i 's/\r$//' 2-RL-FW-config_v1.1.sh
chmod +x 2-RL-FW-config_v1.1.sh
sudo ./2-RL-FW-config_v1.1.sh
```

### 2.3.3. `RL-FW-config_domain.sh`

**Nombre del script:** `RL-FW-config_domain.sh`.

**Descripción:** Integra RL-FW-01 en el dominio neltek.uy por realmd, Kerberos y SSSD.

**Componentes que instala o utiliza:** Herramientas de dominio instaladas por el script de preparación.

**Componentes que configura:** Integración y comprobaciones asociadas a su función de infraestructura.

**Archivos y directorios creados, modificados o utilizados:** /etc/sssd/sssd.conf y archivos de configuración de dominio administrados por realmd. Los nombres exactos de perfiles y archivos que genere se determinan por el propio script.

**Requisitos previos:** Componentes de las etapas anteriores disponibles, y conectividad a DNS y servicios correspondientes.

**Ejecución:**

```bash
sed -i 's/\r$//' RL-FW-config_domain.sh
chmod +x RL-FW-config_domain.sh
sudo ./RL-FW-config_domain.sh
```

### 2.3.4. `3-RL-FW-add_MON_AD.sh`

**Nombre del script:** `3-RL-FW-add_MON_AD.sh`.

**Descripción:** Amplía las políticas de conectividad para los servicios de monitoreo y Active Directory.

**Componentes que instala o utiliza:** Firewalld y redes internas configuradas.

**Componentes que configura:** Integración y comprobaciones asociadas a su función de infraestructura.

**Archivos y directorios creados, modificados o utilizados:** Reglas y políticas en Firewalld; no se atribuyen archivos ajenos al propio firewall. Los nombres exactos de perfiles y archivos que genere se determinan por el propio script.

**Requisitos previos:** Componentes de las etapas anteriores disponibles, y conectividad a DNS y servicios correspondientes.

**Ejecución:**

```bash
sed -i 's/\r$//' 3-RL-FW-add_MON_AD.sh
chmod +x 3-RL-FW-add_MON_AD.sh
sudo ./3-RL-FW-add_MON_AD.sh
```

### 2.3.5. `4-RL-FW-add_Zabbix.sh`

**Nombre del script:** `4-RL-FW-add_Zabbix.sh`.

**Descripción:** Configura las políticas de comunicación necesarias entre Zabbix Server, alojado en RL-MON-01 (`192.168.20.20`), y los agentes Zabbix de los controladores WS-DC-01 (`192.168.10.20`) y WS-DC-02 (`192.168.10.21`).

**Componentes que utiliza:** Firewalld y la configuración existente de las zonas SERVICIOS y MONITOREO.

**Componentes que configura:**

- Política `rec-zbx-mon-dc`: permite TCP/10050 desde RL-MON-01 hacia los dos controladores para consultas pasivas a los agentes.
- Política `rec-zbx-dc-mon`: permite TCP/10051 desde los dos controladores hacia RL-MON-01 para comunicaciones activas con Zabbix Server.

**Requisitos previos:** interfaces y zonas de red configuradas, Firewalld activo, encaminamiento disponible y direcciones IP correspondientes a la topología documentada.

**Comportamiento operativo:** crea o valida las políticas específicas sin reemplazar NAT, DNAT, zonas ni reglas ajenas. Puede requerir confirmación interactiva antes de recargar Firewalld. Si la recarga no se autoriza, debe comprobarse si las políticas están efectivamente activas en runtime.

**Ejecución — exclusivamente en RL-FW-01:**

```bash
sed -i 's/\r$//' 4-RL-FW-add_Zabbix.sh
chmod +x 4-RL-FW-add_Zabbix.sh
sudo ./4-RL-FW-add_Zabbix.sh
```

**Verificación:** comprobar las políticas permanentes y runtime y probar la conectividad real desde los equipos de origen autorizados. La existencia de las reglas no garantiza, por sí sola, que el tráfico llegue al servicio de destino.

## 2.4. Scripts comunes a los servidores Linux

Los siguientes scripts no son exclusivos de RL-FW-01. Se aplican después de los cinco específicos y mantienen su orden interno.

### 2.4.1. `1-RL-XXX-config_ssh.sh`

**Nombre del script:** `1-RL-XXX-config_ssh.sh`.

**Descripción:** Aplica las restricciones de SSH y administración Linux comunes del laboratorio.

**Componentes que instala o utiliza:** OpenSSH, sudo y servicios de dominio disponibles.

**Componentes que configura y archivos utilizados:** Configuración del servicio sshd y política de elevación administrativa. Incluye las restricciones de usuarios y grupos administrativos definidas en el entorno, sin exponer material secreto.

**Requisitos previos:** Dominio y usuarios autorizados disponibles; sesión alternativa abierta.

```bash
sed -i 's/\r$//' 1-RL-XXX-config_ssh.sh
chmod +x 1-RL-XXX-config_ssh.sh
sudo ./1-RL-XXX-config_ssh.sh
```

### 2.4.2. `2-RL-XXX-config_ssh_users.sh`

**Nombre del script:** `2-RL-XXX-config_ssh_users.sh`.

**Descripción:** Gestiona las claves públicas SSH de los usuarios de Active Directory autorizados.

**Componentes que instala o utiliza:** No instala servicios de aplicación.

**Componentes que configura y archivos utilizados:** /etc/ssh/authorized_keys/ y permisos de las claves por usuario. Incluye las restricciones de usuarios y grupos administrativos definidas en el entorno, sin exponer material secreto.

**Requisitos previos:** Dominio y usuarios autorizados disponibles; sesión alternativa abierta.

```bash
sed -i 's/\r$//' 2-RL-XXX-config_ssh_users.sh
chmod +x 2-RL-XXX-config_ssh_users.sh
sudo ./2-RL-XXX-config_ssh_users.sh
```

---

# 3. Arquitectura y componentes del servidor

## 3.1. Topología lógica

```text
               WAN (Bridged / DHCP)
                        |
                        | ens33
                    RL-FW-01
              routing / firewalld / NAT
                        |
     +------------------+-----------------------+
     |                  |                       |
 ens36 SERVICIOS    ens37 MONITOREO      ens38 APLICACIONES
 192.168.10.1       192.168.20.1         192.168.30.1
     |                  |                       |
 WS-DC-01/02         RL-MON-01              RL-APP-01
 AD / DNS            Prometheus             Laravel / MySQL
                     Grafana                8080 / 8081 / 8082
                     OpenSearch
                     Zabbix Server
                        |
                  ens39 DMZ
                 192.168.50.1
                        |
                 RL-PROXY-01
                 192.168.50.20
                   HTTPS/443
                   WAF / Nginx

 ens40 / ens41: ampliación OFICINAS / INFORMÁTICA
 (configuración IPv4 definitiva no acreditada aquí)
```

## 3.2. Tráfico de aplicaciones

1. El cliente utiliza `https://recoleccion.neltek.uy`, `https://admin-recoleccion.neltek.uy` o `https://camiones-recoleccion.neltek.uy`.
2. La publicación pasa por la política de red y DNAT correspondiente a RL-PROXY-01 (`192.168.50.20:443`) cuando el acceso procede desde WAN.
3. El contenedor WAF de RL-PROXY-01 termina HTTPS, aplica ModSecurity/OWASP CRS y reenvía internamente a Nginx.
4. Nginx conecta con RL-APP-01 (`192.168.30.20`) en TCP `8080`/`8081`/`8082`, según el nombre solicitado.
5. RL-APP-01 ejecuta las aplicaciones y la base MySQL privada. **No** se publica MySQL TCP/3306 en WAN.

## 3.3. Dependencias

| Equipo | Función |
|---|---|
| WS-DC-01 (`192.168.10.20`) | DNS / AD |
| WS-DC-02 (`192.168.10.21`) | DNS / AD adicional |
| RL-MON-01 (`192.168.20.20`) | Plataforma de métricas y logs |
| RL-APP-01 (`192.168.30.20`) | Servicios web internos y MySQL |
| RL-PROXY-01 (`192.168.50.20`) | Terminación TLS, WAF y proxy |

---

# 4. Configuración de red y conectividad

## 4.1. NetworkManager y rutas

La interfaz WAN `ens33` utiliza dirección por DHCP y aporta la **única ruta predeterminada**. Las redes internas tienen rutas conectadas en el propio RL-FW-01, con las interfaces del apartado 1.1.

```bash
ip -br addr
ip -4 route
nmcli device status
nmcli -f GENERAL,IP4 device show ens33
nmcli connection show
sysctl net.ipv4.ip_forward
```

El valor esperado de `net.ipv4.ip_forward` para funcionamiento como router es `1`. La IP WAN puede cambiar si VMware modifica la conexión Bridged o si cambia la concesión DHCP. No utilizar una IP WAN histórica como dirección fija de la arquitectura.

## 4.2. Zonas, políticas y filtrado

Firewalld administra las zonas y políticas de tránsito. La zona WAN documentada incluye `rec-wan`. El flujo entre segmentos debe respetar el origen, destino, puerto y protocolo autorizados, sin transformar el laboratorio en una red completamente abierta.

```bash
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --get-zones
sudo firewall-cmd --get-policies
sudo firewall-cmd --list-all-policies
sudo firewall-cmd --zone=rec-wan --list-all
sudo firewall-cmd --list-forward-ports --zone=rec-wan
sudo firewall-cmd --list-rich-rules --zone=rec-wan
```

Los nombres de las políticas adicionales deben consultarse en `firewall-cmd --get-policies`; no se presuponen etiquetas no verificadas.

## 4.3. Flujos principales

| Origen → destino | Puerto/protocolo | Finalidad |
|---|---|---|
| WAN → RL-PROXY-01 (`192.168.50.20`) | TCP/443 | Publicación HTTPS del WAF |
| RL-PROXY-01 → RL-APP-01 (`192.168.30.20`) | TCP/8080 | Ciudadana, HTTP interno |
| RL-PROXY-01 → RL-APP-01 (`192.168.30.20`) | TCP/8081 | Administración, HTTP interno |
| RL-PROXY-01 → RL-APP-01 (`192.168.30.20`) | TCP/8082 | Camiones, HTTP interno |
| RL-MON-01 → RL-APP-01 / RL-PROXY-01 | TCP/9100 | Métricas Node Exporter |
| RL-MON-01 → WS-DC-01 / WS-DC-02 | TCP/10050 | Consultas pasivas a los agentes Zabbix Windows |
| RL-APP-01 / RL-PROXY-01 → RL-MON-01 | TCP/9200 | Ingesta OpenSearch |
| WS-DC-01 / WS-DC-02 → RL-MON-01 (192.168.20.20) | TCP/10051 | Comunicaciones activas de los agentes hacia Zabbix Server |
| Servidores Linux → WS-DC-01 / WS-DC-02 | DNS, Kerberos y LDAP según configuración | Integración con dominio |
| Administración autorizada → RL-FW-01 | SSH, puerto vigente | Gestión |

## 4.4. NAT, DNAT y comunicaciones interiores

Masquerade traduce tráfico saliente de las redes internas hacia la WAN. DNAT dirige conexiones destinadas a un servicio publicado hacia RL-PROXY-01. El tráfico entre segmentos internos se regula mediante las políticas de Firewalld, evitando rutas directas no autorizadas.

```bash
sudo firewall-cmd --zone=rec-wan --query-masquerade
sudo firewall-cmd --zone=rec-wan --list-forward-ports
sudo nft list ruleset
sudo ss -lntup
```

No modificar ni vaciar globalmente `nftables` ni Firewalld mientras el sistema esté en servicio.

## 4.5. Redes OFICINAS e INFORMÁTICA

La expansión incorpora interfaces adicionales `ens40` y `ens41`. Antes de atribuirles IPv4, máscaras, gateways de clientes, DHCP, NAT o reglas de tráfico definitivas, validar los parámetros aplicados:

```bash
ip -br addr show ens40
ip -br addr show ens41
nmcli device show ens40
nmcli device show ens41
nmcli -f NAME,UUID,TYPE,DEVICE connection show
sudo firewall-cmd --get-active-zones
ip -4 route
```

La información recuperada no permite consignar con certeza el direccionamiento final ni la matriz completa de permisos de ambas redes. En particular, una interfaz `UP` con solo IPv6 link-local no demuestra que tenga IPv4 asignada.

## 4.6. Pruebas de red

```bash
ping -c 3 192.168.10.20
ping -c 3 192.168.10.21
ping -c 3 192.168.20.20
ping -c 3 192.168.30.20
ping -c 3 192.168.50.20
getent hosts recoleccion.neltek.uy
curl -I https://recoleccion.neltek.uy
curl -I https://admin-recoleccion.neltek.uy
curl -I https://camiones-recoleccion.neltek.uy
```

Para HTTPS con autoridad certificadora interna, el sistema desde el que se ejecuta `curl` debe confiar en la CA correspondiente; no desactivar comprobación TLS por defecto. El fallo de ICMP no equivale necesariamente al fallo de TCP de la aplicación.

---

# 5. Servicios y contenedores Docker

## 5.1. Aplicación a RL-FW-01

**No aplica.** RL-FW-01 actúa como enrutador/firewall del host Rocky Linux. `1-RL-FW_update.sh` no instala Docker y no se documentan contenedores Docker locales para este servidor.

Sus servicios centrales son NetworkManager, Firewalld, OpenSSH y los componentes de integración AD/SSSD.

## 5.2. Gestión de servicios

```bash
sudo systemctl status NetworkManager
sudo systemctl status firewalld
sudo systemctl status sshd
sudo systemctl status sssd
sudo systemctl status oddjobd
```

---

# 6. Estructura de directorios y almacenamiento

## 6.1. Rutas funcionales

| Ruta | Función |
|---|---|
| `/etc/NetworkManager/system-connections/` | Perfiles persistentes de conexiones y NIC |
| `/etc/firewalld/` | Zonas, políticas y configuración persistente de filtrado |
| `/etc/sssd/sssd.conf` | Parámetros SSSD y dominio |
| `/etc/ssh/sshd_config` | Configuración básica SSH |
| `/etc/ssh/sshd_config.d/` | Fragmentos de configuración SSH |
| `/etc/ssh/authorized_keys/` | Claves públicas de administradores configuradas por scripts comunes |
| `/etc/sudoers.d/` | Política de sudo por grupos |
| `/etc/sysctl.d/` | Parámetros persistentes del kernel, cuando se emplean |
| `/var/log/` | Registros del sistema, según servicios y rotación |
| `/var/lib/sss/` | Cachés y estado de SSSD |

Los nombres particulares de archivos dentro de estas rutas se establecen por el script/configuración efectiva.

## 6.2. Permisos y persistencia

El firewall depende principalmente de configuraciones persistentes, no de volúmenes de aplicación. Proteger archivos de claves, credenciales de dominio y perfiles NetworkManager.

```bash
sudo ls -la /etc/firewalld
sudo ls -la /etc/NetworkManager/system-connections
sudo stat /etc/sssd/sssd.conf
df -h
```

---

# 7. Base de datos MySQL

**No aplica.** MySQL reside en RL-APP-01 dentro de su red privada Docker y no debe publicarse desde RL-FW-01 hacia WAN. RL-FW-01 solo es responsable de hacer cumplir el aislamiento entre segmentos.

---

# 8. Seguridad y control de acceso

## 8.1. Active Directory y SSSD

`RL-FW-config_domain.sh` integra el host con `neltek.uy`, utilizando realmd, DNS y SSSD. La administración se autoriza con controles del sistema y grupos de dominio.

```bash
realm list
sudo sssctl config-check
sudo systemctl status sssd
sudo systemctl status oddjobd
```

## 8.2. SSH y usuarios autorizados

`1-RL-XXX-config_ssh.sh` configura acceso administrativo seguro y `2-RL-XXX-config_ssh_users.sh` administra claves públicas. Se documenta el grupo `gg_rec_server_admins_linux` como referencia de autorización Linux.

```bash
sudo sshd -t
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|allowgroups)'
sudo visudo -c
sudo ls -l /etc/ssh/authorized_keys/
```

El puerto SSH debe consultarse en la configuración efectiva y no suponerse como TCP/22 si se aplicaron scripts de endurecimiento.

## 8.3. SELinux y Firewalld

```bash
getenforce
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all-policies
sudo ausearch -m AVC -ts recent
```

Controlar acceso administrativo y limitar la publicación a los flujos requeridos. No almacenar secretos o claves privadas en la documentación.

## 8.4. Control de acceso WAN

La publicación HTTPS de Ciudadana, Administración y Camiones no equivale a autorización universal desde WAN. Las restricciones diferenciadas de aplicaciones administrativas dependen de la política efectiva. Mantener la restricción de MySQL y evitar puertos de administración abiertos a Internet.

---

# 9. Monitoreo y registros

## 9.1. Observabilidad del firewall

RL-MON-01 (`192.168.20.20`) es la plataforma central de métricas y registros. La información examinada no acredita un script específico de Node Exporter o Fluent Bit para RL-FW-01 que deba añadirse automáticamente a su orden de ejecución.

Para diagnóstico del propio RL-FW-01 utilizar herramientas nativas:

```bash
sudo journalctl -u firewalld -n 100 --no-pager
sudo journalctl -u NetworkManager -n 100 --no-pager
sudo journalctl -u sshd -n 100 --no-pager
sudo journalctl -u sssd -n 100 --no-pager
sudo firewall-cmd --list-all-policies
ip -s link
```

No describir agentes, contenedores, dashboards, índices o puertos de escucha locales del firewall como si existieran sin evidencias de instalación.

## 9.2. Eventos y diagnóstico

Para investigar rechazos de conexiones comprobar zona, política, flujo real, direcciones origen/destino, encaminamiento, NAT y contadores/logs configurados. Los registros disponibles dependen del nivel de logging de Firewalld y del kernel. No habilitar logging indiscriminado en operación normal sin prever impacto.

---

# 10. Copias de seguridad y recuperación

## 10.1. Elementos a proteger

- Perfiles NetworkManager de interfaces y rutas.
- Zonas, políticas y reglas persistentes Firewalld.
- Configuración DNS, SSSD y pertenencia al dominio.
- Configuración SSH, claves públicas, sudo y parámetros de forwarding.
- Scripts que permiten reproducir el despliegue.
- Información necesaria para recuperar conexiones y acceso por consola de la VM.

## 10.2. Respaldo operativo de configuraciones

Este procedimiento es una **guía administrativa** y no representa una política de respaldo periódico ya confirmada:

```bash
sudo tar --xattrs --acls -czf /root/rl-fw-01-config-backup.tar.gz   /etc/NetworkManager /etc/firewalld /etc/sssd   /etc/ssh /etc/sudoers.d /etc/sysctl.d
sudo chmod 600 /root/rl-fw-01-config-backup.tar.gz
```

El archivo puede contener información sensible; custodiarlo de forma segura y no compartirlo sin protección. Respetar las condiciones de seguridad de la ubicación de destino.

No están confirmadas frecuencias, retención ni destinos definitivos para RL-FW-01; no se atribuye automáticamente una estrategia 3-2-1-0 ejecutándose.

## 10.3. Recuperación

Recuperar la VM y sus tarjetas virtuales, confirmar identificadores de interfaces y topología VMware, restaurar rutas y zonas, revisar forwarding y DNAT, comprobar DNS/AD, validar acceso de administración y las tres aplicaciones por HTTPS antes de dar la recuperación por finalizada.

No aplicar una restauración ciega si cambian nombres o MAC de interfaces.

---

# 11. Administración y mantenimiento

## 11.1. Inspección

```bash
hostnamectl
uptime
ip -br addr
ip route
nmcli connection show
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all-policies
sudo nft list ruleset
sudo systemctl --failed
df -h
```

## 11.2. Actualizaciones

```bash
sudo dnf check-update
sudo dnf update
```

Planificar actualizaciones considerando posibles reinicios de NetworkManager, Firewalld, SSSD o del propio kernel. Mantener acceso de consola y copia de la configuración antes de cambios de red.

## 11.3. Cambios en políticas

Antes de editar, identificar la zona de cada interfaz y comprobar el origen/destino exacto. Para reglas persistentes, revisar diferencias entre configuración `runtime` y `permanent`:

```bash
sudo firewall-cmd --runtime-to-permanent
sudo firewall-cmd --check-config
sudo firewall-cmd --list-all-policies
sudo firewall-cmd --permanent --list-all-policies
```

**Advertencia:** `--runtime-to-permanent` escribe todas las reglas runtime actuales a configuración permanente. No ejecutarlo de forma indiscriminada; usarlo solo si se ha validado que la configuración activa completa es la que se desea preservar.

---

# 12. Diagnóstico y resolución de problemas

## 12.1. WAN y conectividad

```bash
ip -br addr show ens33
ip route get 1.1.1.1
nmcli device show ens33
ping -c 3 192.168.10.20
```

Si se cambia el adaptador de VMware de Bridged a NAT, la IP DHCP y el gateway WAN pueden cambiar; las IP internas no deben cambiar por ese motivo salvo modificación independiente de sus perfiles.

## 12.2. Enrutamiento

```bash
sysctl net.ipv4.ip_forward
ip -4 route
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all-policies
```

Un ping al gateway no demuestra que el tráfico atraviese todas las políticas. Comprobar también conexión TCP desde el equipo origen efectivo.

## 12.3. HTTPS / DNAT

```bash
sudo firewall-cmd --zone=rec-wan --list-forward-ports
sudo nft list ruleset
curl -I https://recoleccion.neltek.uy
curl -I https://admin-recoleccion.neltek.uy
curl -I https://camiones-recoleccion.neltek.uy
```

Distinguir error de DNS, rechazo de firewall, certificado no confiable, servicio WAF y backend Laravel. La comprobación HTTPS requiere confianza en la CA interna instalada en el cliente.

## 12.4. Dominio y SSH

```bash
realm list
sudo sssctl config-check
sudo sshd -t
sudo systemctl status sshd sssd oddjobd
sudo journalctl -u sshd -n 80 --no-pager
```

## 12.5. Firewalld y NAT

```bash
sudo firewall-cmd --state
sudo firewall-cmd --zone=rec-wan --query-masquerade
sudo firewall-cmd --get-policies
sudo firewall-cmd --list-all-policies
sudo nft list ruleset
```

## 12.6. Interfaces OFICINAS / INFORMÁTICA

```bash
ip -br addr show ens40 ens41
nmcli device status
nmcli -f GENERAL,IP4 device show ens40
nmcli -f GENERAL,IP4 device show ens41
sudo firewall-cmd --get-active-zones
```

Para pruebas definitivas de esas redes, utilizar el direccionamiento y las reglas efectivamente aplicados. No asumir comunicación total entre nuevos segmentos y SERVICIOS, MONITOREO, APLICACIONES o DMZ.

## 12.7. Almacenamiento y registros

```bash
df -h
df -i
sudo journalctl -p warning -n 100 --no-pager
sudo systemctl --failed
```

---

# 13. Anexos

Sección reservada para anexos técnicos futuros. Se incorporarán únicamente cuando se soliciten, con numeración y título propios. **Anexos permanecerá siempre como la última sección del documento.**

