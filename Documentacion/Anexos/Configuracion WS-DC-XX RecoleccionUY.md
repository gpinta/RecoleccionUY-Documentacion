# CONFIGURACIÓN DE WINDOWS SERVER 2012 R2 Y CONTROLADORES DE DOMINIO

**Actualización:** 12/11/2026 — Incorporación del monitoreo Zabbix de WS-DC-01 y WS-DC-02.

**Alcance:** configuración e integración de los controladores de dominio WS-DC-01 y WS-DC-02 con Windows Server 2012 R2, servicios Active Directory, DNS, DHCP Failover, autenticación LDAP/Kerberos, administración de usuarios y grupos de seguridad, integración con las tres aplicaciones de Recolección UY y procedimientos de implementación y verificación.

---

## Índice

1. [Alcance y parámetros generales](#1-alcance-y-parámetros-generales)
2. [Topología de red y arquitectura del sistema](#2-topología-de-red-y-arquitectura-del-sistema)
3. [Funciones y direccionamiento de los servidores](#3-funciones-y-direccionamiento-de-los-servidores)
4. [Instalación y configuración de los controladores de dominio](#4-instalación-y-configuración-de-los-controladores-de-dominio)
   - [4.1. Configuración de WS-DC-01 (Primer Controlador de Dominio)](#41-configuración-de-ws-dc-01-primer-controlador-de-dominio)
     - [Verificación Inicial de WS-DC-01](#verificación-inicial-de-ws-dc-01)
   - [4.2. Configuración e Integración de WS-DC-02](#42-configuración-e-integración-de-ws-dc-02)
   - [4.3. Redundancia y verificación DNS inter-servidor](#43-redundancia-y-verificación-dns-inter-servidor)
     - [WS-DC-01](#ws-dc-01)
     - [WS-DC-02](#ws-dc-02)
     - [Verificación de Resolución y Replicación DNS](#verificación-de-resolución-y-replicación-dns)
5. [Configuración del servicio DHCP y conmutación por error (Failover)](#5-configuración-del-servicio-dhcp-y-conmutación-por-error-failover)
   - [5.1. Autorización de servidores](#51-autorización-de-servidores)
   - [5.2. Ámbitos, rangos, exclusiones y opciones DHCP (desde WS-DC-01)](#52-ámbitos-rangos-exclusiones-y-opciones-dhcp-desde-ws-dc-01)
   - [5.3. Configuración de Failover](#53-configuración-de-failover)
6. [Resolución DNS de servicios web internos de Recolección UY](#6-resolución-dns-de-servicios-web-internos-de-recolección-uy)
7. [Integración LDAP con Backend Administrativo](#7-integración-ldap-con-backend-administrativo)
   - [7.1. Parámetros de Conexión LDAP](#71-parámetros-de-conexión-ldap)
   - [7.2. Cuenta de Servicio](#72-cuenta-de-servicio)
   - [7.3. Estructura de Grupos de Seguridad y Mapeo de Roles](#73-estructura-de-grupos-de-seguridad-y-mapeo-de-roles)
   - [7.4. Cuentas de usuario para los roles administrativos](#74-cuentas-de-usuario-para-los-roles-administrativos)
8. [Reglas de arquitectura y control de acceso](#8-reglas-de-arquitectura-y-control-de-acceso)
9. [Matriz de topología y servicios](#9-matriz-de-topología-y-servicios)
10. [Scripts PowerShell y orden de ejecución](#10-scripts-powershell-y-orden-de-ejecución)
11. [Parámetros operativos y secuencia de implementación](#11-parámetros-operativos-y-secuencia-de-implementación)
    - [11.1. Verificaciones y controles de mantenimiento por servicio](#111-verificaciones-y-controles-de-mantenimiento-por-servicio)
    - [11.2. Secuencia de implementación de la infraestructura](#112-secuencia-de-implementación-de-la-infraestructura)

---

## 1. Alcance y parámetros generales

La instalación de **Windows Server 2012 R2** comprende `WS-DC-01` y `WS-DC-02` en la topología de Recolección UY. Los roles se instalan conjuntamente: **AD DS, DNS y DHCP**; después se configuran en ese orden. WS-DC-02 **se une al dominio como miembro antes de promocionarse** como controlador adicional.

Servicios: AD DS, DNS integrado con Active Directory, DHCP con conmutación por error (Failover), LDAP/Kerberos y DNS de publicación de las tres aplicaciones de Recolección UY.

**Datos del entorno:** dominio `neltek.uy`, NetBIOS `NELTEK`, red SERVICIOS `192.168.10.0/24`, gateway `192.168.10.1`, DNS `192.168.10.20` y `192.168.10.21`.

**Alcance y estado:** Los controladores WS-DC-01 y WS-DC-02 forman parte de la infraestructura operativa de Recolección UY. Los servicios AD DS, DNS, DHCP y LDAP/Kerberos se encuentran implementados, funcionando y probados. La arquitectura contempla DHCP Failover entre ambos controladores, con distribución 50/50 según el diseño documentado. Las redes se encuentran segmentadas y los servidores utilizan direcciones IP estáticas. La versión implementada es Windows Server 2012 R2, cuyo soporte extendido regular ha finalizado; se recomienda contemplar una estrategia futura de actualización o migración.

## 2. Topología de red y arquitectura del sistema

```bash
                        CLIENTES / WAN (192.168.1.0/24 en laboratorio)
                                         |
                              RL-FW-01 ens33 (WAN)
                                         |
                +------------------------+-------------------------+
                |                        |                         |
         SERVICIOS                    APLICACIONES                 DMZ
       192.168.10.0/24               192.168.30.0/24          192.168.50.0/24
         GW .10.1                      GW .30.1                 GW .50.1
                |                        |                         |
       +--------+---------+           RL-APP-01                RL-PROXY-01
       |                  |           192.168.30.20           192.168.50.20
    WS-DC-01           WS-DC-02            |                       |
 192.168.10.20       192.168.10.21     API :8080              Nginx interno
 AD/DNS/DHCP         AD/DNS/DHCP       Admin :8081            dnsmasq :53
 LDAP/Kerberos       LDAP/Kerberos     Camiones :8082         WAF / TLS :443
                                       MySQL privado               |
                                            ^______________________|
                                                  vía RL-FW-01

       MONITOREO: 192.168.20.0/24, GW 192.168.20.1
       RL-MON-01: 192.168.20.20
```

Interfaces de `RL-FW-01`: `ens33` WAN, `ens36` SERVICIOS `192.168.10.1/24`, `ens37` MONITOREO `192.168.20.1/24`, `ens38` APLICACIONES `192.168.30.1/24` y `ens39` DMZ `192.168.50.1/24`.

`RL-PROXY-01` dispone de **una sola NIC en DMZ** (`ens33`) y no utiliza una segunda interfaz Bridged. Los clientes WAN llegan al proxy a través de DNAT en `RL-FW-01`. La capa de publicación contempla los tres hosts `recoleccion.neltek.uy`, `admin-recoleccion.neltek.uy` y `camiones-recoleccion.neltek.uy`. En el conjunto de scripts se incluyen el proxy Nginx y dnsmasq, el WAF ModSecurity con OWASP CRS y los procedimientos de certificados y publicación HTTPS/443. La publicación efectiva se determina por la configuración aplicada de WAF, puertos y firewall, sin asumir que la presencia de scripts equivalga a una configuración activa.

## 3. Funciones y direccionamiento de los servidores

| Parámetro | WS-DC-01 | WS-DC-02 |
|---|---|---|
| Función | Primer controlador del bosque | Controlador adicional del mismo dominio |
| IP / máscara | `192.168.10.20/24` | `192.168.10.21/24` |
| Gateway | `192.168.10.1` | `192.168.10.1` |
| DNS inicial | `192.168.10.20` | `192.168.10.20` (para unirse al dominio) |
| DNS preferido final | `192.168.10.20` | `192.168.10.21` |
| DNS alternativo final | `192.168.10.21` | `192.168.10.20` |
| Roles | AD DS, DNS, DHCP, Global Catalog | AD DS, DNS, DHCP, Global Catalog |
| LDAP / Kerberos | Servicios del dominio | Servicios del dominio |
| Monitoreo | Zabbix Agent clásico, Hostname `WS-DC-01` | Zabbix Agent clásico, Hostname `WS-DC-02` |

La configuración DNS final se aplica una vez que ambos servidores estén promocionados y su replicación esté saludable.

## 4. Instalación y configuración de los controladores de dominio

### 4.1. Configuración de WS-DC-01 (Primer Controlador de Dominio)

1. **Red:** Asignar la IP estática `192.168.10.20` con Gateway `192.168.10.1` y DNS inicial `192.168.10.20`. No usar DHCP.

2. **Roles:** Desde **Server Manager → Manage → Add Roles and Features**, instalar:

   * Active Directory Domain Services (AD DS)
   * Servidor DNS
   * Servidor DHCP

3. **Promoción de Dominio:**

   * Seleccionar **Promote this server to a domain controller**.
   * Elegir **Add a new forest**.
   * **Root domain name:** `neltek.uy`
   * Mantener habilitadas las opciones de **DNS Server** y **Global Catalog (GC)**.
   * Definir una contraseña segura para el **Modo de restauración de servicios de directorio (DSRM)**.
   * Completar la instalación y reiniciar.



**Identificación de interfaz de WS-DC-01:**

```bash
Hostname: WS-DC-01
IP:       192.168.10.20
Máscara:  255.255.255.0 (/24)
Gateway:  192.168.10.1
DNS:      192.168.10.20 (inicial)
```

Antes de la promoción, verificar fecha y hora. Seleccionar niveles funcionales de bosque y dominio compatibles con Windows Server 2012 R2. Revisar las rutas de base de datos de Active Directory, registros y SYSVOL, ejecutar la comprobación de requisitos previos y continuar solo si no existen errores bloqueantes. Tras reiniciar, verificar los servicios AD DS, Kerberos y LDAP. Mantener inicialmente los roles FSMO en `WS-DC-01` y configurar una fuente horaria apropiada para el dominio.

**Configuración DNS inicial de WS-DC-01:**

1. Abrir **Administrador del servidor → Herramientas → DNS**.
2. Confirmar que la zona directa `neltek.uy` está integrada con Active Directory.
3. Verificar actualizaciones dinámicas seguras, registros del controlador y registros SRV de LDAP y Kerberos.
4. Verificar resolución local de `WS-DC-01.neltek.uy` y del dominio.
5. Mantener `192.168.10.20` como DNS cliente inicialmente; incorporar `192.168.10.21` cuando el segundo controlador esté operativo.

**Configuración DHCP inicial de WS-DC-01:** completar el asistente posterior a la instalación, autorizar el servidor en Active Directory y crear únicamente los ámbitos aprobados con sus rangos, exclusiones o reservas y tiempos de concesión. Configurar opciones 003, 006 y 015; utilizar inicialmente `192.168.10.20` en la opción 006 e incorporar el segundo DNS cuando esté operativo. Activar solo los ámbitos definidos y comprobar una concesión con un cliente del segmento correspondiente.

**Punto de control:** `WS-DC-01` debe contar con AD DS, DNS y DHCP operativos antes de incorporar `WS-DC-02`.

#### Verificación Inicial de WS-DC-01

```cmd
nltest /dsgetdc:neltek.uy
```

```powershell
Get-ADDomain
Get-ADForest
```

---

### 4.2. Configuración e Integración de WS-DC-02

1. **Red:** Asignar la IP estática `192.168.10.21` con Gateway `192.168.10.1` y DNS principal `192.168.10.20` (apuntando a `WS-DC-01` para resolver la ubicación del dominio).

2. **Unión al dominio existente:**

   * Unir `WS-DC-02` al dominio: `neltek.uy`
   * Utilizar una cuenta del dominio con permisos suficientes para unir equipos al dominio, por ejemplo: `NELTEK\infra01`
   * Reiniciar `WS-DC-02` después de completar correctamente la unión al dominio.

3. **Roles:** Instalar desde el Administrador del Servidor:

   * Active Directory Domain Services
   * Servidor DNS
   * Servidor DHCP

4. **Promoción e Inclusión al Dominio:**

   * Seleccionar **Promote this server to a domain controller**.
   * Elegir **Add a domain controller to an existing domain**.
   * **Dominio:** `neltek.uy`
   * Proporcionar credenciales de un usuario con permisos suficientes (ej. `NELTEK\infra01` o Administrador del Dominio).
   * En **Opciones de Controlador**, marcar **DNS** y **Global Catalog (GC)**.
   * Establecer la contraseña DSRM.
   * En **Opciones adicionales → Replicar desde**, seleccionar explícitamente: `WS-DC-01`.
   * Finalizar la comprobación de requisitos e instalar. El servidor se reiniciará automáticamente.

---



**Identificación de interfaz de WS-DC-02:**

```bash
Hostname: WS-DC-02
IP:       192.168.10.21
Máscara:  255.255.255.0 (/24)
Gateway:  192.168.10.1
DNS:      192.168.10.20 (inicial)
```

Antes de unir el equipo al dominio, verificar conectividad y sincronización horaria. Después de la unión y del reinicio, confirmar pertenencia al dominio y autenticación con Active Directory. Los permisos habituales para unir equipos al dominio no garantizan permisos para promocionar controladores adicionales: la promoción requiere una cuenta autorizada específicamente. **No crear un bosque ni un dominio nuevo.** Durante la promoción, revisar las ubicaciones de base de datos, registros y SYSVOL, validar los requisitos previos e instalar solo si no existen errores bloqueantes. Confirmar luego la replicación de AD DS y SYSVOL desde `WS-DC-01`.

### 4.3. Redundancia y verificación DNS inter-servidor

Una vez operativos ambos controladores, actualizar la configuración DNS IPv4 en los adaptadores de red de ambos nodos:

#### WS-DC-01

```bash
DNS preferido:   192.168.10.20
DNS alternativo: 192.168.10.21
```

#### WS-DC-02

```bash
DNS preferido:   192.168.10.21
DNS alternativo: 192.168.10.20
```

#### Verificación de Resolución y Replicación DNS

```powershell
Resolve-DnsName ws-dc-01.neltek.uy
Resolve-DnsName ws-dc-02.neltek.uy
```

Verificar el estado de replicación de Active Directory:

```bash
repadmin /replsummary
repadmin /showrepl
```

---

**Comprobación de servicios y registros SRV en ambos DNS:**

```powershell
Resolve-DnsName WS-DC-01.neltek.uy -Server 192.168.10.20
Resolve-DnsName WS-DC-02.neltek.uy -Server 192.168.10.21
Resolve-DnsName -Type SRV _ldap._tcp.neltek.uy -Server 192.168.10.20
Resolve-DnsName -Type SRV _ldap._tcp.neltek.uy -Server 192.168.10.21
```

Comprobar replicación de la zona integrada `neltek.uy` y disponibilidad de los registros SRV que anuncian LDAP y Kerberos.

## 5. Configuración del servicio DHCP y conmutación por error (Failover)

### 5.1. Autorización de servidores

1. Abrir **Server Manager → Tools → DHCP** en ambos servidores.
2. Verificar que `WS-DC-01` y `WS-DC-02` estén autorizados en Active Directory. Si falta autorización: clic derecho en el servidor → **Autorizar**.
3. Verificar que los servicios DHCP estén iniciados y que no exista un servidor DHCP de VMware entregando concesiones en las mismas redes.

### 5.2. Ámbitos, rangos, exclusiones y opciones DHCP (desde WS-DC-01)

La topología del proyecto comprende SERVICIOS `192.168.10.0/24`, MONITOREO `192.168.20.0/24`, APLICACIONES `192.168.30.0/24` y DMZ `192.168.50.0/24`. **Esto no implica crear DHCP en todas las redes.** Los servidores tienen IP estática.

1. Definir cuáles redes requieren asignación dinámica y sus rangos autorizados.
2. En **WS-DC-01 → IPv4 → Nuevo ámbito**, crear cada ámbito aprobado.
3. Configurar máscara `/24` para los ámbitos de estas redes, exclusiones de direcciones fijas y duración de concesión.
4. Establecer las opciones **003 Router**, **006 Servidores DNS** y **015 Dominio DNS** según la tabla:

| Red                            |        gateway       |               DNS                |   dominio   |
|--------------------------------|----------------------|----------------------------------|-------------|
| SERVICIOS `192.168.10.0/24`    |     `192.168.10.1`   | `192.168.10.20`, `192.168.10.21` | `neltek.uy` |
| MONITOREO `192.168.20.0/24`    |     `192.168.20.1`   | `192.168.10.20`, `192.168.10.21` | `neltek.uy` |
| APLICACIONES `192.168.30.0/24` |     `192.168.30.1`   | `192.168.10.20`, `192.168.10.21` | `neltek.uy` |
| DMZ `192.168.50.0/24`          |     `192.168.50.1`   | `192.168.10.20`, `192.168.10.21` | `neltek.uy` |

**Rangos de inicio y fin:** los ámbitos DHCP deben respetar los rangos de direcciones aprobados para cada segmento, sus exclusiones, reservas y direcciones IP estáticas. La configuración de DHCP Relay en `RL-FW-01` corresponde únicamente a las redes que requieren obtener concesiones DHCP desde otro segmento. Las reglas del firewall deben permitir las comunicaciones necesarias entre los clientes, el relay cuando corresponda y ambos servidores DHCP.

5. Activar únicamente los ámbitos aprobados. Dejar WINS sin configurar si no existe dependencia.

**Preparación y controles de ámbitos:** en **DHCP → IPv4 → Nuevo ámbito...**, indicar la subred, máscara `255.255.255.0`, rango aprobado y duración de concesión. Los parámetros que deben registrarse para cada ámbito son nombre, primera y última IP asignable, exclusiones y reservas, tiempo de concesión y necesidad de DHCP Relay. Si todos los dispositivos de una red usan IP estática, no se requiere ámbito DHCP para esa red.

**Direcciones conocidas que no se deben asignar dinámicamente:**

```bash
WS-DC-01:    192.168.10.20
WS-DC-02:    192.168.10.21
RL-FW-01:
  SERVICIOS: 192.168.10.1
  MONITOREO: 192.168.20.1
  APPS:      192.168.30.1
  DMZ:       192.168.50.1
RL-APP-01:   192.168.30.20
RL-PROXY-01: 192.168.50.20
RL-MON-01:   192.168.20.20
```

En el asistente **Agregar exclusiones y retraso**, excluir todas las direcciones estáticas que queden dentro del rango dinámico, o elegir un rango que las deje fuera. Se pueden configurar reservas DHCP para clientes específicos. Para la opción **006**, utilizar `192.168.10.20` en la etapa inicial e incorporar `192.168.10.21` una vez disponible. Dejar **WINS** sin direcciones si no hay una dependencia concreta. Verificar el acceso de los clientes a los DNS a través de `RL-FW-01` desde otras redes.

### 5.3. Configuración de Failover

1. Desde `WS-DC-01`: **IPv4 → Configurar conmutación por error...**
2. Seleccionar los ámbitos creados y autorizados para Failover.
3. Elegir `WS-DC-02.neltek.uy` como servidor asociado y autorizado.
4. Configurar la relación `WS-DC-01_WS-DC-02`, modo **Equilibrio de carga**, proporción **50 % / 50 %**, conforme al diseño documentado.
5. Configurar autenticación con un secreto compartido seguro, sin incluirlo en la documentación.
6. Definir el intervalo de cambio automático de estado solo conforme a la política adoptada.
7. Finalizar; confirmar relación saludable, ámbitos disponibles y concesiones sincronizadas. No crear un segundo ámbito independiente con direcciones superpuestas.

**Verificación:** comprobar autorizaciones, estado de los ámbitos, relación Failover, distribución de concesiones, DNS y gateway entregados y comportamiento ante caída de un miembro en una ventana controlada.



En la ventana **Crear una nueva relación de conmutación por error**, los parámetros son:

```bash
Nombre:         WS-DC-01_WS-DC-02
Modo:           Equilibrio de carga
Distribución:   50 % / 50 %
Servidor par:   WS-DC-02.neltek.uy
```

Seleccionar **Siguiente → Finalizar**, comprobar el resultado de las tareas y cerrar. Ambos servidores pueden atender clientes DHCP y compartir el estado de las concesiones de los ámbitos participantes. Tras modificar ámbitos que participen en Failover, comprobar si se requiere **replicar la configuración del ámbito al servidor asociado**: no todos los cambios administrativos se transfieren automáticamente.

## 6. Resolución DNS de servicios web internos de Recolección UY

La arquitectura de publicación ubica Nginx y dnsmasq en **RL-PROXY-01** (`192.168.50.20`), con la capa WAF delante de Nginx cuando está habilitada. Los registros A internos de `neltek.uy` apuntan a esta IP para clientes con ruta hacia DMZ.

| Nombre                           | Tipo | Destino DNS interno |          Aplicación publicada         |
|----------------------------------|------|---------------------|---------------------------------------|
| `recoleccion.neltek.uy`          |   A  |    `192.168.50.20`  | Ciudadana → `192.168.30.20:8080`      |
| `admin-recoleccion.neltek.uy`    |   A  |    `192.168.50.20`  | Administrativo → `192.168.30.20:8081` |
| `camiones-recoleccion.neltek.uy` |   A  |    `192.168.50.20`  | Camiones → `192.168.30.20:8082`       |

El script disponible `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` administra los tres registros A desde WS-DC-01. Su parámetro `$ProxyServerIP` está definido como `192.168.50.20`, y la lista `$Records` incluye Ciudadana, Administrativo y Camiones. Se ejecuta cuando la zona `neltek.uy` y el proxy estén disponibles. En una zona integrada con AD, los registros se replican entre controladores mediante Active Directory.

```powershell
Resolve-DnsName recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName recoleccion.neltek.uy -Server 192.168.10.21
Resolve-DnsName admin-recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName admin-recoleccion.neltek.uy -Server 192.168.10.21
Resolve-DnsName camiones-recoleccion.neltek.uy -Server 192.168.10.20
Resolve-DnsName camiones-recoleccion.neltek.uy -Server 192.168.10.21
```

**Resultado esperado en la resolución interna:** `192.168.50.20`. Para clientes WAN externos debe definirse resolución alcanzable hacia la dirección WAN del firewall y su DNAT; no se asume que puedan acceder directamente a una dirección privada de DMZ.

## 7. Integración LDAP con Backend Administrativo

El Backend Administrativo alojado en `RL-APP-01` integra LdapRecord con Active Directory para autenticar a los usuarios mediante LDAP; el puerto documentado es `389`. La autorización distingue `reader`, `operator` y `admin` mediante grupos AD independientes. Las variables de grupo utilizadas por el Backend son `ADMIN_LDAP_READERS_GROUP_DN`, `ADMIN_LDAP_OPERATORS_GROUP_DN` y `ADMIN_LDAP_ADMINS_GROUP_DN`. El uso de TLS para LDAP requiere la correspondiente configuración y política de certificados; no debe inferirse cifrado de la sola indicación del puerto 389.

### 7.1. Parámetros de Conexión LDAP

```env
# Valores de ejemplo; definir secretos únicamente en el entorno seguro
LDAP_HOSTS="ws-dc-01.neltek.uy,ws-dc-02.neltek.uy"

LDAP_PORT=389

LDAP_USERNAME="CN=svc_recoleccion_ldap,OU=CuentasServicio,OU=RecoleccionUY,DC=neltek,DC=uy"

LDAP_PASSWORD="<SECRETO>"

LDAP_BASE_DN="DC=neltek,DC=uy"

LDAP_TIMEOUT=5
```

### 7.2. Cuenta de Servicio

* **DN:** `CN=svc_recoleccion_ldap,OU=CuentasServicio,OU=RecoleccionUY,DC=neltek,DC=uy`
* **Permisos:** Exclusivamente permisos de lectura. No debe pertenecer a `Domain Admins` ni poseer inicio de sesión interactivo.

### 7.3. Estructura de Grupos de Seguridad y Mapeo de Roles

Ubicación de Grupos: `OU=Aplicaciones,OU=Grupos,OU=RecoleccionUY,DC=neltek,DC=uy`

Ámbito: **Global** | Tipo: **Seguridad**

| Grupo AD DS                | DN Completo                                                                              | Rol en Backend |
| :------------------------- | :--------------------------------------------------------------------------------------- | :------------- |
| `GG_REC_Backend_Admins`    | `CN=GG_REC_Backend_Admins,OU=Aplicaciones,OU=Grupos,OU=RecoleccionUY,DC=neltek,DC=uy`    | `admin`        |
| `GG_REC_Backend_Operators` | `CN=GG_REC_Backend_Operators,OU=Aplicaciones,OU=Grupos,OU=RecoleccionUY,DC=neltek,DC=uy` | `operator`     |
| `GG_REC_Backend_Readers`   | `CN=GG_REC_Backend_Readers,OU=Aplicaciones,OU=Grupos,OU=RecoleccionUY,DC=neltek,DC=uy`   | `reader`       |

### 7.4. Cuentas de usuario para los roles administrativos

| Usuario           | `sAMAccountName`       | Grupo Perteneciente        |
| :---------------- | :--------------------- | :------------------------- |
| Administrador     | `admin.recoleccion`    | `GG_REC_Backend_Admins`    |
| Operador          | `operadores.recolecc`  | `GG_REC_Backend_Operators` |
| Lector / Consulta | `consulta.recoleccion` | `GG_REC_Backend_Readers`   |

```powershell
# Comandos de verificación de usuarios en AD DS:

Get-ADUser "admin.recoleccion" -Properties MemberOf,UserPrincipalName
Get-ADUser "operadores.recolecc" -Properties MemberOf,UserPrincipalName
Get-ADUser "consulta.recoleccion" -Properties MemberOf,UserPrincipalName
```

---

## 8. Reglas de arquitectura y control de acceso

1. **Proxy único:** las tres aplicaciones se publican mediante `RL-PROXY-01` (`192.168.50.20`), con el tráfico encaminado desde `RL-FW-01`.
2. **Controladores de dominio:** `WS-DC-01` y `WS-DC-02` prestan AD DS, DNS, DHCP y autenticación LDAP/Kerberos; no desempeñan la función de proxy HTTP.
3. **Nginx:** `recoleccion.neltek.uy` → `192.168.30.20:8080`, `admin-recoleccion.neltek.uy` → `192.168.30.20:8081` y `camiones-recoleccion.neltek.uy` → `192.168.30.20:8082`.
4. **Backend Administrativo:** la autorización funcional se realiza mediante grupos de seguridad de Active Directory y se complementa con los controles de acceso de la infraestructura. La publicación y las restricciones de acceso se administran mediante las políticas correspondientes de `RL-FW-01`, Nginx y WAF en `RL-PROXY-01`, manteniendo separados los controles de autenticación, autorización y seguridad perimetral.
5. **DNS:** `recoleccion_dns` publica las tres resoluciones locales en `192.168.50.20:53` (TCP/UDP), y reenvía las demás consultas a `192.168.10.20` / `192.168.10.21`. Los clientes de cada segmento deben tener una ruta y una política DNS apropiadas.
6. **MySQL:** las aplicaciones comparten `recoleccion_db` por la red privada Docker `recoleccion-db-net` de `RL-APP-01`; TCP/3306 no se publica al host.
7. **WAF y HTTPS:** la infraestructura incluye `recoleccion_waf` con ModSecurity y OWASP CRS. El procedimiento `6-RL-PROXY-migrar_waf_https.sh` prepara la publicación HTTPS en `192.168.50.20:443`, con destino al WAF en `8443`, para los tres nombres; el procedimiento exige certificados y configura el WAF para publicación exclusiva por HTTPS. La activación efectiva de estas opciones depende de su aplicación en el host.
8. **Monitoreo:** `RL-MON-01` (192.168.20.20) centraliza Prometheus, Grafana, OpenSearch y Zabbix Server. Los servidores Linux utilizan Node Exporter y Fluent Bit según sus procedimientos. `WS-DC-01` y `WS-DC-02` utilizan Zabbix Agent clásico para supervisar disponibilidad, servicios y eventos Windows. Las comunicaciones TCP/10050 y TCP/10051 se habilitan mediante políticas específicas en RL-FW-01 y no deben publicarse hacia WAN.
9. **Red:** `RL-PROXY-01` utiliza su NIC DMZ y `RL-APP-01` utiliza la red APLICACIONES, con las rutas entre segmentos controladas por `RL-FW-01`.
10. **Separación de aplicaciones:** Ciudadana, Administrativo y Camiones son proyectos Laravel independientes. Los cambios de base de datos compartida deben coordinarse entre los tres, sin mezclar los archivos de los proyectos.
11. **Seguridad de credenciales:** las cuentas de servicio LDAP necesitan permisos mínimos de lectura; no se publican secretos, contraseñas ni claves privadas en este documento. La seguridad del acceso LDAP debe ajustarse a la política de cifrado del entorno.

## 9. Matriz de topología y servicios

| Componente             |                                     Configuración vigente / planificada                                                       |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| Dominio / NetBIOS      | `neltek.uy` / `NELTEK`                                                                                                        |
| SERVICIOS / gateway    | `192.168.10.0/24` / `192.168.10.1`                                                                                            |
| MONITOREO / gateway    | `192.168.20.0/24` / `192.168.20.1`                                                                                            |
| APLICACIONES / gateway | `192.168.30.0/24` / `192.168.30.1`                                                                                            |
| DMZ / gateway          | `192.168.50.0/24` / `192.168.50.1`                                                                                            |
| WS-DC-01               | `192.168.10.20`, AD DS / DNS / DHCP                                                                                           |
| WS-DC-02               | `192.168.10.21`, AD DS / DNS / DHCP                                                                                           |
| DNS internos           | `192.168.10.20` y `192.168.10.21`                                                                                             |
| DHCP dinámico          | Servicio DHCP operativo; ámbitos y exclusiones según configuración de los servidores                                          |
| DHCP Failover          | Relación WS-DC-01 ↔ WS-DC-02; diseño de equilibrio de carga 50/50                                                             |
| RL-FW-01               | WAN `ens33`; gateway de cuatro redes internas                                                                                 |
| RL-PROXY-01            | `192.168.50.20`, Nginx interno, dnsmasq `:53`, WAF y publicación HTTPS `:443` según despliegue                                |
| RL-APP-01              | `192.168.30.20`, API `:8080`, Admin `:8081`, Camiones `:8082`                                                                 |
| RL-MON-01              | `192.168.20.20`, Prometheus / Grafana / OpenSearch / Zabbix Server / Zabbix Web                                               |
| DNS Ciudadana          | `recoleccion.neltek.uy` → `192.168.50.20` (interno)                                                                           |
| DNS Administrativo     | `admin-recoleccion.neltek.uy` → `192.168.50.20` (interno)                                                                     |
| DNS Camiones           | `camiones-recoleccion.neltek.uy` → `192.168.50.20` (interno)                                                                  |
| LDAP                   | DC1/DC2 puerto `389` según configuración del backend                                                                          |
| DN base                | `DC=neltek,DC=uy`                                                                                                             |
| Grupos backend         | `GG_REC_Backend_Admins`, `GG_REC_Backend_Operators`, `GG_REC_Backend_Readers`                                                 |
| MySQL                  | `recoleccion_db`, red privada `recoleccion-db-net`, 3306 no publicado                                                         |
| HTTPS / WAF            | Infraestructura de publicación con Nginx, WAF, certificados TLS y servicios HTTPS/443                                         |
| Control WAN de Admin   | Acceso administrativo sujeto a las políticas de firewall, Nginx, WAF y autorización por grupos AD                             |
| Zabbix WS-DC-01        | Zabbix Agent clásico, `192.168.10.20`, WS-DC-01-zabbix-import.yaml                                                            |
| Zabbix WS-DC-02        | Zabbix Agent clásico, `192.168.10.21`, WS-DC-02-zabbix-import.yaml                                                            |


## 10. Scripts PowerShell y orden de ejecución

Después de instalar los tres roles y promocionar ambos controladores, verificar AD DS, DNS y replicación. Los scripts PowerShell se ordenan por su **prefijo numérico**. No sustituyen los pasos manuales de instalación y promoción descritos arriba.

| Orden | Script | Servidor | Qué realiza |
|---|---|---|---|
| 1 | `1-AD_Config_RecoleccionUY.ps1` | WS-DC-01 | Crea/verifica OU, grupos, cuentas de prueba, cuenta privilegiada y cuenta LDAP, y membresías definidas |
| 2 | `2-WS-DC_Config_Local.ps1` | **Ambos**, ajustando parámetros | Configura DNS cliente, RDP/NLA, TermService y regla `REC-RDP-Administracion`; requiere que los grupos AD estén disponibles |
| 3 | `3-WS-DC_RDP_Gestionar_Origenes.ps1` | **Ambos** | Consulta, agrega, elimina, bloquea y restaura orígenes permitidos para RDP |
| 4 | `4-AD_Politica_Contrasenas_Dominio.ps1` | WS-DC-01 | Configura política de contraseñas, bloqueo y excepciones de expiración |
| 5 | `5-GPO_Equipos_Inactividad.ps1` | WS-DC-01 | Crea/verifica GPO de inactividad y enlaces a OU Clientes / Servidores |
| 5 | `5-GPO_Equipos_Inactividad_Excepciones.ps1` | WS-DC-01 | Gestiona excepciones de equipos a la GPO creada |
| 6 | `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` | WS-DC-01, una vez disponible RL-PROXY-01 | Crea/actualiza registros A de Ciudadana, Administrativo y Camiones; `$ProxyServerIP = "192.168.50.20"` |
| 7 | `7-WS-DC-Zabbix_Agent.ps1` | **Ambos**, ejecución local en cada controlador | Instala/configura Zabbix Agent clásico, establece el nombre de host y el servidor `192.168.20.20`, configura auditoría y genera el YAML de importación correspondiente a cada controlador |

**No ejecutar los scripts de objetos y GPO por duplicado en WS-DC-02**: son cambios de dominio que se replican. Los scripts locales `2` y `3` sí se aplican a ambos controladores.

**Dependencia de infraestructura:** ejecutar `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` después de levantar y verificar RL-PROXY-01, aunque conserve su lugar en la secuencia numerada.

**Dependencia del script 7:** ejecutar después de desplegar Zabbix Server en `RL-MON-01` y configurar las políticas de comunicación mediante `4-RL-FW-add_Zabbix.sh` en `RL-FW-01`. Ejecutar el script localmente en ambos controladores. Importar los archivos YAML resultantes manualmente desde Zabbix Web.

## 11. Parámetros operativos y secuencia de implementación

```powershell
# Ejecutar con herramientas RSAT/AD DS disponibles y permisos adecuados
dcdiag
repadmin /replsummary
repadmin /showrepl
Resolve-DnsName ws-dc-01.neltek.uy -Server 192.168.10.20
Resolve-DnsName ws-dc-02.neltek.uy -Server 192.168.10.21
```

**Servicios implementados y controles operativos:**

- AD DS, SYSVOL, Global Catalog, LDAP/Kerberos y DNS forman parte de la configuración operativa de ambos controladores de dominio.
- Los servidores DHCP proporcionan los servicios de asignación dinámica de direcciones IP de acuerdo con los ámbitos configurados.
- La relación DHCP Failover entre WS-DC-01 y WS-DC-02 corresponde al diseño de alta disponibilidad de la infraestructura.
- DHCP Relay se utiliza únicamente en los segmentos donde resulte necesario según la topología.
- Los registros DNS de Ciudadana, Administrativo y Camiones apuntan a la infraestructura de publicación `RL-PROXY-01`.
- La publicación de las aplicaciones se administra mediante las configuraciones de Nginx, WAF y HTTPS.
- El acceso al Backend Administrativo se encuentra sujeto a autenticación y autorización mediante Active Directory y a los controles perimetrales correspondientes.

**Estado general:** infraestructura configurada, operativa y probada. Los parámetros específicos de cada servicio se administran mediante sus configuraciones y scripts correspondientes.

### 11.1. Verificaciones y controles de mantenimiento por servicio

- Confirmar que los dos controladores anuncian LDAP y Kerberos y que AD DS, SYSVOL y Global Catalog funcionan.
- Confirmar que los registros SRV y la zona integrada `neltek.uy` se resuelven desde ambos DNS.
- Confirmar que ambos servidores DHCP están autorizados y solo existen ámbitos aprobados, sin ámbitos independientes solapados.
- Confirmar que la relación `WS-DC-01_WS-DC-02` funciona para los ámbitos seleccionados.
- Confirmar que la opción 003 distribuye el gateway correcto, la 006 los DNS `192.168.10.20` y `192.168.10.21`, y la 015 `neltek.uy`.
- Confirmar que las concesiones respetan los rangos y las IP estáticas, y obtener una concesión desde cada red que realmente emplee DHCP.
- Verificar DHCP Relay en `RL-FW-01` únicamente si existen ámbitos para subredes fuera de SERVICIOS.
- Mantener resolución y rutas de acceso a Ciudadana, Administrativo y Camiones desde los segmentos autorizados.
- Verificar el servicio Zabbix Agent en `WS-DC-01` y `WS-DC-02`.
- Comprobar comunicación con `RL-MON-01` mediante los puertos autorizados.
- Confirmar que ambos hosts estén registrados individualmente en Zabbix Web.
- Verificar recepción de métricas, eventos Windows y estado de los elementos de monitoreo.
- Confirmar que el acceso a Zabbix no esté publicado hacia WAN.

### 11.2. Secuencia de implementación de la infraestructura

1. Configurar `WS-DC-01` con AD DS, DNS y DHCP.
2. Unir `WS-DC-02` a `neltek.uy`, instalar roles y promocionarlo.
3. Confirmar replicación AD/DNS y configurar DHCP Failover para los ámbitos autorizados.
4. Ejecutar los scripts PowerShell numerados en los controladores correspondientes, respetando la dependencia de `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1`.
5. Desplegar `RL-FW-01` con preparación, configuración de red/firewall y unión al dominio.
6. Desplegar `RL-APP-01`, MySQL y las aplicaciones Ciudadana/API y Administrativo.
7. Desplegar `RL-PROXY-01`, Nginx y dnsmasq.
8. Completar los registros DNS de publicación de Ciudadana, Administrativo y Camiones; configurar la capa WAF y HTTPS según los scripts correspondientes y la política de acceso.
9. Integrar `RL-MON-01` y los agentes Node Exporter / Fluent Bit de los servidores correspondientes, según la configuración documentada.
10. Desplegar Zabbix Server y Zabbix Web en `RL-MON-01` mediante `5-RL-MON-Zabbix.sh`, configurar las políticas correspondientes en `RL-FW-01` mediante `4-RL-FW-add_Zabbix.sh`, ejecutar `7-WS-DC-Zabbix_Agent.ps1` localmente en ambos controladores e importar los archivos YAML desde Zabbix Web. Verificar conectividad y recepción efectiva de datos y eventos.