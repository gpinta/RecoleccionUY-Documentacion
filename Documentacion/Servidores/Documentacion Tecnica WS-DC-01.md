# Documentación Técnica del Servidor WS-DC-01

**Actualización:** 12/11/2026 — Incorporación de Zabbix Agent y monitoreo de eventos Windows para WS-DC-01. 
**Proyecto:** Recolección UY  
**Servidor:** `WS-DC-01`  
**Estado documentado:** infraestructura implementada, operativa y verificada, con servicios de Active Directory, DNS y DHCP configurados y funcionando.


## Índice

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-información-general)
  - [1.2. Rol del servidor](#12-rol-del-servidor)
  - [1.3. Justificación del sistema operativo](#13-justificación-del-sistema-operativo)
- [2. Ejecución de Scripts](#2-ejecución-de-scripts)
  - [2.1. Orden de ejecución](#21-orden-de-ejecución)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos del servidor](#23-scripts-específicos-del-servidor)
    - [2.3.1. 1-AD_Config_RecoleccionUY.ps1](#231-1-ad_config_recoleccionuyps1)
    - [2.3.2. 2-WS-DC_Config_Local.ps1](#232-2-ws-dc_config_localps1)
    - [2.3.3. 3-WS-DC_RDP_Gestionar_Origenes.ps1](#233-3-ws-dc_rdp_gestionar_origenesps1)
    - [2.3.4. 4-AD_Politica_Contrasenas_Dominio.ps1](#234-4-ad_politica_contrasenas_dominiops1)
    - [2.3.5. 5-GPO_Equipos_Inactividad.ps1](#235-5-gpo_equipos_inactividadps1)
    - [2.3.6. 5-GPO_Equipos_Inactividad_Excepciones.ps1](#236-5-gpo_equipos_inactividad_excepcionesps1)
    - [2.3.7. 6-DNS_RegistroA_RecoleccionUY_v1.3.ps1](#237-6-dns_registroa_recoleccionuy_v13ps1)
    - [2.3.8. 7-WS-DC-Zabbix_Agent.ps1](#238-7-ws-dc-zabbix_agentps1)
  - [2.4. Scripts comunes](#24-scripts-comunes)
- [3. Arquitectura y componentes del servidor](#3-arquitectura-y-componentes-del-servidor)
- [4. Configuración de red y conectividad](#4-configuración-de-red-y-conectividad)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
- [7. Base de datos MySQL](#7-base-de-datos-mysql)
- [8. Seguridad y control de acceso](#8-seguridad-y-control-de-acceso)
- [9. Monitoreo y registros](#9-monitoreo-y-registros)
- [10. Copias de seguridad y recuperación](#10-copias-de-seguridad-y-recuperación)
- [11. Administración y mantenimiento](#11-administración-y-mantenimiento)
- [12. Diagnóstico y resolución de problemas](#12-diagnóstico-y-resolución-de-problemas)
- [13. Anexos](#13-anexos)


---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor |
|---|---|
| Nombre del servidor | `WS-DC-01` |
| Sistema operativo | Windows Server 2012 R2 |
| Interfaz de red | Adaptador de red de SERVICIOS; nombre exacto de Windows no documentado |
| Segmento | SERVICIOS — `192.168.10.0/24` |
| Dirección IP | `192.168.10.20` (estática) |
| Máscara de subred | `255.255.255.0` |
| Gateway | `192.168.10.1` (`RL-FW-01`) |
| DNS primario | `192.168.10.20` |
| DNS secundario | `192.168.10.21` |
| Dominio | `neltek.uy` (NetBIOS `NELTEK`) |

El DNS secundario corresponde a `WS-DC-02`, una vez disponible y replicando. No se ha encontrado confirmación del nombre específico de la interfaz (`Ethernet`, etc.) ni de interfaces adicionales.

## 1.2. Rol del servidor

`WS-DC-01` es el primer controlador de dominio del bosque `neltek.uy`. Proporciona Active Directory Domain Services (AD DS), DNS integrado con AD, catálogo global y servicio DHCP. Mantiene objetos y políticas centralizados del proyecto y presta resolución DNS y autenticación a los equipos y aplicaciones del entorno. Comparte responsabilidades de AD/DNS con `WS-DC-02` (`192.168.10.21`). El diseño incluye DHCP Failover, cuya relación concreta y ámbitos se deben consultar en el entorno para documentar su estado preciso.

El Backend Administrativo utiliza servicios de identidad LDAP/AD; los servidores Linux integrados en dominio utilizan los servicios pertinentes de directorio, DNS y Kerberos.

## 1.3. Justificación del sistema operativo

Windows Server 2012 R2 corresponde a la plataforma operativa sobre la que se desarrollaron y probaron los scripts PowerShell y roles de dominio existentes. Su integración nativa con AD DS, DNS, DHCP y Group Policy permite mantener la configuración desplegada sin cambiar el ecosistema. **Advertencia de mantenimiento:** es una versión fuera de soporte regular; evaluar las medidas de soporte aplicables y una migración planificada por separado, sin introducir cambios en esta documentación.

---
---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución

**Prerrequisito:** AD DS, DNS, ambos controladores y replicación operativos; los roles y su configuración inicial no son sustituidos por estos scripts.

| Orden | Nombre exacto | Función |
|---|---|---|
| 1 | `1-AD_Config_RecoleccionUY.ps1` | Objetos AD |
| 2 | `2-WS-DC_Config_Local.ps1` | Configuración local DNS/RDP |
| 3 | `3-WS-DC_RDP_Gestionar_Origenes.ps1` | Gestión de orígenes RDP |
| 4 | `4-AD_Politica_Contrasenas_Dominio.ps1` | Política de contraseñas |
| 5 | `5-GPO_Equipos_Inactividad.ps1` | GPO de inactividad |
| 6 | `5-GPO_Equipos_Inactividad_Excepciones.ps1` | Excepciones de GPO |
| 7 | `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` | Registros A de aplicaciones |
| 8 | `7-WS-DC-Zabbix_Agent.ps1` | Instala y configura Zabbix Agent clásico |

El script `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` se ejecuta una vez que `RL-PROXY-01` esté disponible. Los scripts `1-AD_Config_RecoleccionUY.ps1`, `4-AD_Politica_Contrasenas_Dominio.ps1`, `5-GPO_Equipos_Inactividad.ps1`, `5-GPO_Equipos_Inactividad_Excepciones.ps1` y `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` administran objetos compartidos del dominio y no se repiten por rutina en WS-DC-02.

Los scripts `2-WS-DC_Config_Local.ps1`, `3-WS-DC_RDP_Gestionar_Origenes.ps1` y `7-WS-DC-Zabbix_Agent.ps1` tienen alcance local y deben ejecutarse en cada controlador con los valores correspondientes.

Antes de ejecutar `7-WS-DC-Zabbix_Agent.ps1`, Zabbix Server debe estar preparado en `RL-MON-01` y deben verificarse las políticas de comunicación de `RL-FW-01`. La importación del archivo YAML generado se realiza manualmente desde Zabbix Web.

No existen scripts comunes Linux aplicables a este servidor Windows.

## 2.2. Procedimiento general

Abrir **Windows PowerShell como administrador** en el servidor correspondiente. Los archivos se distribuyen en `Scripts\Windows\Windows Server 2012 r2\`; su ubicación definitiva en los servidores no está confirmada.

```powershell
hostname
Get-Location
Get-Item '.\2-WS-DC_Config_Local.ps1'
Get-ExecutionPolicy -List
```

Para ejecutar un script validado se usa `.\NombreExacto.ps1`, con el nombre indicado en cada ficha. No son aplicables `sed`, `chmod` ni `sudo` (comandos de Linux). Antes de intervenir en producción, validar la identidad del equipo, los parámetros locales y la política de ejecución autorizada.

## 2.3. Scripts específicos del servidor

### 2.3.1. 1-AD_Config_RecoleccionUY.ps1

**Nombre del script:** `1-AD_Config_RecoleccionUY.ps1`. **Versión:** Sin etiqueta de versión explícita en el nombre.

**Descripción:** Organiza Active Directory para Recolección UY: OUs, grupos, usuarios de prueba, cuenta infra01, cuenta svc_recoleccion_ldap y membresías.

**Componentes que instala o utiliza:** ActiveDirectory; dominio neltek.uy y objetos de directorio. No instala roles Windows; utiliza los previamente disponibles.

**Componentes que configura:** Organiza Active Directory para Recolección UY: OUs, grupos, usuarios de prueba, cuenta infra01, cuenta svc_recoleccion_ldap y membresías.

**Archivos y directorios creados, modificados o utilizados:** OU=RecoleccionUY,DC=neltek,DC=uy; OU=Disabled Users,DC=neltek,DC=uy; OUs Usuarios, CuentasPrivilegiadas, Grupos/Aplicaciones, Grupos/Infraestructura, Equipos/Servidores, Equipos/Clientes, CuentasServicio. Crea o actualiza cuentas, grupos y membresías en AD; no son carpetas de disco.

**Requisitos previos:** AD DS operativo y permisos de administración del dominio.

**Ejecución:**

```powershell
Set-Location 'C:\Ruta\Aprobada\Scripts'
Test-Path '.\1-AD_Config_RecoleccionUY.ps1'
.\1-AD_Config_RecoleccionUY.ps1
```

### 2.3.2. 2-WS-DC_Config_Local.ps1

**Nombre del script:** `2-WS-DC_Config_Local.ps1`. **Versión:** Sin etiqueta de versión explícita en el nombre.

**Descripción:** Establece el DNS cliente de WS-DC-01, acceso RDP con NLA, servicio TermService y regla REC-RDP-Administracion.

**Componentes que instala o utiliza:** Configuración de interfaz Windows, RDP/TermService, NetSecurity y DNS cliente. No instala roles Windows; utiliza los previamente disponibles.

**Componentes que configura:** Establece el DNS cliente de WS-DC-01, acceso RDP con NLA, servicio TermService y regla REC-RDP-Administracion.

**Archivos y directorios creados, modificados o utilizados:** Modifica configuración local del equipo y reglas de Windows Firewall; no declara carpetas persistentes propias. Valores del script: ServerIP 192.168.10.20, DNSServers 192.168.10.20 y 192.168.10.21, RDPRemoteAddress 192.168.10.0/24.

**Requisitos previos:** Ambos controladores operativos y replicando; verificar los valores locales antes de ejecutar.

**Ejecución:**

```powershell
Set-Location 'C:\Ruta\Aprobada\Scripts'
Test-Path '.\2-WS-DC_Config_Local.ps1'
.\2-WS-DC_Config_Local.ps1
```

### 2.3.3. 3-WS-DC_RDP_Gestionar_Origenes.ps1

**Nombre del script:** `3-WS-DC_RDP_Gestionar_Origenes.ps1`. **Versión:** Sin etiqueta de versión explícita en el nombre.

**Descripción:** Gestiona por menú los orígenes autorizados de la regla de firewall RDP; permite bloqueo temporal y restauración.

**Componentes que instala o utiliza:** NetSecurity; firewall de Windows y persistencia JSON para restauración. No instala roles Windows; utiliza los previamente disponibles.

**Componentes que configura:** Gestiona por menú los orígenes autorizados de la regla de firewall RDP; permite bloqueo temporal y restauración.

**Archivos y directorios creados, modificados o utilizados:** Utiliza/crea %ProgramData%\RecoleccionUY y %ProgramData%\RecoleccionUY\RDP-BlockedOrigins.json, y modifica REC-RDP-Administracion.

**Requisitos previos:** Ejecutar primero el script 2, que crea la regla; usar consola elevada.

**Ejecución:**

```powershell
Set-Location 'C:\Ruta\Aprobada\Scripts'
Test-Path '.\3-WS-DC_RDP_Gestionar_Origenes.ps1'
.\3-WS-DC_RDP_Gestionar_Origenes.ps1
```

### 2.3.4. 4-AD_Politica_Contrasenas_Dominio.ps1

**Nombre del script:** `4-AD_Politica_Contrasenas_Dominio.ps1`. **Versión:** Sin etiqueta de versión explícita en el nombre.

**Descripción:** Establece política predeterminada de contraseñas y bloqueo del dominio, y gestiona expiración de cuentas en OUs concretas.

**Componentes que instala o utiliza:** Módulo ActiveDirectory; política de contraseña del dominio. No instala roles Windows; utiliza los previamente disponibles.

**Componentes que configura:** Establece política predeterminada de contraseñas y bloqueo del dominio, y gestiona expiración de cuentas en OUs concretas.

**Archivos y directorios creados, modificados o utilizados:** Modifica la política predeterminada del dominio y atributos PasswordNeverExpires en cuentas de OU=CuentasServicio y OU=CuentasPrivilegiadas. No crea archivos locales, usuarios, OUs ni GPO.

**Requisitos previos:** Active Directory operativo y OUs ya creadas; revisar opciones de expiración antes de reejecutar.

**Ejecución:**

```powershell
Set-Location 'C:\Ruta\Aprobada\Scripts'
Test-Path '.\4-AD_Politica_Contrasenas_Dominio.ps1'
.\4-AD_Politica_Contrasenas_Dominio.ps1
```

### 2.3.5. 5-GPO_Equipos_Inactividad.ps1

**Nombre del script:** `5-GPO_Equipos_Inactividad.ps1`. **Versión:** Sin etiqueta de versión explícita en el nombre.

**Descripción:** Configura GPO_REC_Equipos_Inactividad para bloqueo a 10 minutos y apagado de pantalla a 15 minutos y sus vínculos.

**Componentes que instala o utiliza:** Módulos ActiveDirectory y GroupPolicy; GPO y vínculos. No instala roles Windows; utiliza los previamente disponibles.

**Componentes que configura:** Configura GPO_REC_Equipos_Inactividad para bloqueo a 10 minutos y apagado de pantalla a 15 minutos y sus vínculos.

**Archivos y directorios creados, modificados o utilizados:** Crea o actualiza la GPO en AD/SYSVOL; configura vínculos con OU Clientes, Servidores y, según interruptores, Domain Controllers. No establece archivos locales de aplicación.

**Requisitos previos:** Replicación AD/SYSVOL saludable; OUs creadas.

**Ejecución:**

```powershell
Set-Location 'C:\Ruta\Aprobada\Scripts'
Test-Path '.\5-GPO_Equipos_Inactividad.ps1'
.\5-GPO_Equipos_Inactividad.ps1
```

### 2.3.6. 5-GPO_Equipos_Inactividad_Excepciones.ps1

**Nombre del script:** `5-GPO_Equipos_Inactividad_Excepciones.ps1`. **Versión:** Sin etiqueta de versión explícita en el nombre.

**Descripción:** Administra excepciones de equipos a GPO_REC_Equipos_Inactividad mediante denegación específica de Apply Group Policy.

**Componentes que instala o utiliza:** Módulos ActiveDirectory y GroupPolicy; ACL de la GPO. No instala roles Windows; utiliza los previamente disponibles.

**Componentes que configura:** Administra excepciones de equipos a GPO_REC_Equipos_Inactividad mediante denegación específica de Apply Group Policy.

**Archivos y directorios creados, modificados o utilizados:** Modifica ACL del objeto CN={GUID},CN=Policies,CN=System,DC=neltek,DC=uy. No crea OUs, GPO, grupos ni archivos locales.

**Requisitos previos:** Debe existir la GPO del script anterior.

**Ejecución:**

```powershell
Set-Location 'C:\Ruta\Aprobada\Scripts'
Test-Path '.\5-GPO_Equipos_Inactividad_Excepciones.ps1'
.\5-GPO_Equipos_Inactividad_Excepciones.ps1
```

### 2.3.7. 6-DNS_RegistroA_RecoleccionUY_v1.3.ps1

**Nombre del script:** `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1`. **Versión:** v1.3.

**Descripción:** Crea o actualiza registros A de recoleccion, admin-recoleccion y camiones-recoleccion dentro de neltek.uy.

**Componentes que instala o utiliza:** Módulo DnsServer; zona DNS neltek.uy. No instala roles Windows; utiliza los previamente disponibles.

**Componentes que configura:** Crea o actualiza registros A de recoleccion, admin-recoleccion y camiones-recoleccion dentro de neltek.uy.

**Archivos y directorios creados, modificados o utilizados:** Actualiza registros A de la zona: los tres apuntan a 192.168.50.20 (RL-PROXY-01). No crea carpetas locales.

**Requisitos previos:** Zona DNS existente; ejecutar después de disponer del proxy y comprobar el diseño de resolución interna.

**Ejecución:**

```powershell
Set-Location 'C:\Ruta\Aprobada\Scripts'
Test-Path '.\6-DNS_RegistroA_RecoleccionUY_v1.3.ps1'
.\6-DNS_RegistroA_RecoleccionUY_v1.3.ps1
```

### 2.3.8. 7-WS-DC-Zabbix_Agent.ps1

**Nombre del script:** `7-WS-DC-Zabbix_Agent.ps1`.

**Descripción:** Instala o configura Zabbix Agent clásico en WS-DC-01 para su supervisión desde RL-MON-01. Configura la comunicación con Zabbix Server, una regla de Windows Firewall, determinadas subcategorías de auditoría y genera un archivo YAML para importar la configuración del controlador en Zabbix Web.

**Servidor de ejecución:** WS-DC-01 (`192.168.10.20`). El mismo script debe ejecutarse por separado en WS-DC-02 (`192.168.10.21`).

**Componentes que instala o utiliza:** Zabbix Agent clásico 7.0.32, PowerShell 4.0 o superior, Windows Firewall, `auditpol.exe` y el registro de eventos de Windows. No instala Zabbix Agent 2.

**Componentes que configura:**

- `Hostname=WS-DC-01`.
- `Server=192.168.20.20`.
- `ServerActive=192.168.20.20`.
- Servicio Windows `Zabbix Agent`.
- Regla `RecoleccionUY Zabbix Agent 10050 - Monitor Only`, limitada a conexiones TCP/10050 desde `192.168.20.20`.
- Auditoría de fallos de inicio de sesión, bloqueos de cuentas, administración de usuarios y fallos de autenticación Kerberos.

**Archivos y directorios creados o utilizados:**

- `C:\Program Files\Zabbix Agent\zabbix_agentd.conf`.
- `C:\ProgramData\RecoleccionUY-Zabbix\WS-DC-01-zabbix-import.yaml`.
- Copia de seguridad de la configuración del agente, si corresponde.
- Registro de instalación MSI, cuando sea necesario instalar el agente.

**Paquete de instalación previsto:** `C:\Temp\zabbix_agent-7.0.32-windows-amd64-openssl.msi`.

**Requisitos previos:** Windows Server 2012 R2 x64, sesión administrativa elevada, nombre del equipo e IP correctos, paquete MSI aprobado cuando corresponda y conectividad con RL-MON-01. La instalación nueva verifica el SHA-256 configurado y la firma digital del MSI.

**Ejecución — exclusivamente en WS-DC-01:**

```powershell
hostname
Get-ExecutionPolicy -List
Test-Path '.\7-WS-DC-Zabbix_Agent.ps1'
.\7-WS-DC-Zabbix_Agent.ps1
```

Ejecutar desde Windows PowerShell elevado y desde la carpeta que contiene el archivo, respetando la política de ejecución autorizada.

**Verificación:** comprobar que `Zabbix Agent` esté iniciado, que exista una escucha TCP/10050 y que WS-DC-01 pueda comunicarse con `192.168.20.20:10051`.

**Importante:** el script genera el archivo `WS-DC-01-zabbix-import.yaml`, pero no lo importa automáticamente. La importación debe realizarse manualmente desde Zabbix Web. Las comprobaciones de conectividad pueden producir advertencias sin detener obligatoriamente el script.

## 2.4. Scripts comunes

No aplica. `1-RL-XXX-config_ssh.sh` y `2-RL-XXX-config_ssh_users.sh` están destinados a servidores Linux y no se ejecutan en controladores de dominio Windows.

---
---

# 3. Arquitectura y componentes del servidor

Ambos controladores integran el dominio `neltek.uy` en la red SERVICIOS. `WS-DC-01` es el controlador inicial y `WS-DC-02` el adicional, con servicios AD DS, DNS, catálogo global y DHCP. Se debe comprobar el estado real de la replicación de directorio, zonas integradas y SYSVOL.

```text
                   Dominio neltek.uy
       WS-DC-01                 WS-DC-02
       192.168.10.20            192.168.10.21
       AD DS / DNS / GC  <-->   AD DS / DNS / GC
       DHCP             <-->   DHCP (failover)
                        |
          SERVICIOS 192.168.10.0/24
                        |
              RL-FW-01 192.168.10.1
                        |
           Otras redes Recolección UY
```

El equipo de esta ficha es **`WS-DC-01`**. La capa de aplicaciones (`RL-APP-01`), el proxy (`RL-PROXY-01`, `192.168.50.20`) y el monitoreo (`RL-MON-01`) pertenecen a servidores separados. No se les atribuyen sus archivos, contenedores ni servicios a este controlador.
---

# 4. Configuración de red y conectividad

`WS-DC-01` pertenece al segmento SERVICIOS (`192.168.10.0/24`), con IP `192.168.10.20/24`, gateway `192.168.10.1` (`RL-FW-01`) y DNS cliente preferido `192.168.10.20` y alternativo `192.168.10.21`. En `WS-DC-02`, ese orden corresponde al estado posterior a la promoción y verificación de la replicación.

Puertos de referencia de los servicios del dominio (**no constituyen inventario de reglas efectivamente habilitadas**):

| Función | Transporte / puerto de referencia | Observación |
|---|---|---|
| DNS | TCP/UDP 53 | Zona `neltek.uy` |
| Kerberos | TCP/UDP 88 | Autenticación AD |
| LDAP | TCP/UDP 389 | Directorio; LDAPS requiere validación separada |
| LDAPS | TCP 636 | Solo si TLS está configurado y comprobado |
| Catálogo global | TCP 3268; 3269 con TLS | Según configuración efectiva |
| SMB / SYSVOL | TCP 445 | Recursos y directivas AD |
| RPC / AD | TCP 135 y puertos dinámicos | Administración y replicación |
| DHCP | UDP 67/68 | Servicio según ámbito y relay |
| DHCP Failover | TCP 647 | Si existe relación habilitada |
| RDP | TCP 3389 | Regla `REC-RDP-Administracion` con orígenes controlados |
| Zabbix Agent — consultas pasivas | TCP 10050 | Entrada desde RL-MON-01 (`192.168.20.20`) mediante regla local restringida |
| Zabbix Agent — comunicación activa | TCP 10051 | Salida desde WS-DC-01 hacia Zabbix Server (`192.168.20.20`) |

**Verificaciones sin modificar la configuración:**

```powershell
Get-NetIPConfiguration
Get-DnsClientServerAddress -AddressFamily IPv4
Get-NetRoute -AddressFamily IPv4
Resolve-DnsName WS-DC-02.neltek.uy -Server 192.168.10.20
Resolve-DnsName -Type SRV _ldap._tcp.neltek.uy -Server 192.168.10.20
Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion' -ErrorAction SilentlyContinue
Get-NetFirewallAddressFilter -AssociatedNetFirewallRule (Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion')
```

**Comprobaciones de conectividad Zabbix — ejecutar en WS-DC-01:**

```powershell
Get-Service -Name 'Zabbix Agent'
Get-NetTCPConnection -State Listen -LocalPort 10050
Test-NetConnection -ComputerName 192.168.20.20 -Port 10051
Get-NetFirewallRule -DisplayName 'RecoleccionUY Zabbix Agent 10050 - Monitor Only'
```

La existencia del servicio y de una regla local no demuestra que Zabbix Server esté recibiendo datos. También deben verificarse las políticas interredes de RL-FW-01 y los elementos de monitoreo desde Zabbix Web.

Los dominios públicos `recoleccion.neltek.uy`, `admin-recoleccion.neltek.uy` y `camiones-recoleccion.neltek.uy` se comprueban mediante **HTTPS**. Los registros A internos del proyecto dirigen hacia el proxy `192.168.50.20` (`RL-PROXY-01`); estos registros no implican que el controlador publique las aplicaciones. El eventual HTTP entre proxy y servidores de aplicaciones es tráfico interno distinto del acceso público.
---

# 5. Servicios y contenedores Docker

Docker **no aplica** a la función documentada de `WS-DC-01`. Los servicios de Active Directory, DNS y DHCP son roles nativos de Windows Server; no se atribuyen contenedores, proyectos Compose, imágenes, redes o volúmenes Docker a este controlador.

Comprobación de los servicios Windows:

```powershell
Get-Service -Name NTDS,DNS,DHCPServer,Netlogon,KDC -ErrorAction SilentlyContinue
Get-WindowsFeature AD-Domain-Services,DNS,DHCP
```

Los contenedores de aplicaciones Laravel y MySQL corresponden a la infraestructura de aplicaciones y no a este equipo.
---

# 6. Estructura de directorios y almacenamiento

Los datos de AD DS, SYSVOL, DNS y DHCP se almacenan en ubicaciones administradas por roles de Windows. Las rutas físicas efectivas de NTDS, logs de transacción, SYSVOL y la base DHCP deben comprobarse en la instalación; no se asumen ubicaciones predeterminadas como verificadas.

| Ruta | Función |
|---|---|
| `%ProgramData%\RecoleccionUY` | Carpeta local para la persistencia de la administración de RDP |
| `%ProgramData%\RecoleccionUY\RDP-BlockedOrigins.json` | Archivo de estado de orígenes RDP bloqueados, cuando lo genera el script de gestión |
| `C:\Program Files\Zabbix Agent\zabbix_agentd.conf` | Configuración del agente Zabbix clásico |
| `C:\ProgramData\RecoleccionUY-Zabbix\` | Directorio local de archivos auxiliares y exportaciones Zabbix |
| `C:\ProgramData\RecoleccionUY-Zabbix\WS-DC-01-zabbix-import.yaml` | Archivo de configuración del host para importación manual en Zabbix Web |
| `C:\Temp\zabbix_agent-7.0.32-windows-amd64-openssl.msi` | Ruta prevista para instalación nueva del agente |

Comprobaciones de solo lectura:

```powershell
Get-SmbShare -Name SYSVOL,NETLOGON -ErrorAction SilentlyContinue
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters'
Get-Volume
Get-Item "$env:ProgramData\RecoleccionUY" -ErrorAction SilentlyContinue
Get-Acl "$env:ProgramData\RecoleccionUY" -ErrorAction SilentlyContinue
```

No se han confirmado propietarios, ACL ni ruta permanente de los scripts copiados al servidor. No se atribuyen volúmenes Laravel, MySQL ni Docker locales a este controlador.
---

# 7. Base de datos MySQL

**No aplica una instancia MySQL local a `WS-DC-01`.** La base de datos compartida por la Aplicación Ciudadana, el Backend Administrativo y la Aplicación Camiones pertenece a la capa de aplicaciones, no a los controladores de dominio.

La relación de este servidor con las aplicaciones es indirecta, mediante los servicios de identidad y DNS. No corresponde atribuirle administración, volúmenes, credenciales ni procedimientos de respaldo de MySQL.
---

# 8. Seguridad y control de acceso

- **Identidad:** dominio `neltek.uy`, catálogo global, LDAP y Kerberos. La existencia de LDAPS habilitado no se deduce de un puerto estándar; debe verificarse aparte.
- **Delegación de permisos:** el script `1-AD_Config_RecoleccionUY.ps1` crea grupos de aplicación e infraestructura y gestiona membresías, incluida la integración de `GG_REC_Server_Admins_Windows` con grupos administrativos y de Escritorio remoto. Las cuentas sensibles no se reproducen con credenciales.
- **RDP:** `2-WS-DC_Config_Local.ps1` configura NLA, `TermService` y la regla `REC-RDP-Administracion`; valor de orígenes inicialmente autorizado `192.168.10.0/24`. `3-WS-DC_RDP_Gestionar_Origenes.ps1` permite cambios controlados; consultar el estado efectivo antes de intervenir.
- **Contraseñas:** script 4 fija longitud mínima 12, historial 12, edad máxima 90 días, mínima 1 día, complejidad activada, cifrado reversible desactivado, bloqueo tras 5 errores y intervalos de 15 minutos. Las opciones `PasswordNeverExpires` de cuentas de servicio y privilegiadas se deben revisar expresamente.
- **GPO:** script 5 establece bloqueo a 10 minutos y monitor a 15; el script de excepciones modifica ACL del objeto de política para cuentas de equipo designadas.
- **Zabbix Agent:** el acceso pasivo TCP/10050 queda restringido mediante la regla `RecoleccionUY Zabbix Agent 10050 - Monitor Only`, que permite únicamente la IP `192.168.20.20`.
- **Comunicación activa:** `ServerActive` dirige la comunicación del agente a Zabbix Server en RL-MON-01, utilizando TCP/10051.
- **Auditoría Windows:** `7-WS-DC-Zabbix_Agent.ps1` configura determinadas subcategorías de auditoría con `auditpol.exe`. Las directivas de grupo pueden sobrescribir la configuración local; debe comprobarse la política efectiva.
- **Importación de configuración:** el archivo YAML generado para WS-DC-01 se importa manualmente en Zabbix Web. El script no crea automáticamente usuarios, destinatarios ni canales de notificación.
- **SSH / sudo / SSSD / SELinux:** no aplican como controles locales propios de este Windows Server, aunque servidores Linux integrados al dominio pueden usarlos.

```powershell
Get-ADDefaultDomainPasswordPolicy -Identity 'neltek.uy'
Get-GPO -Name 'GPO_REC_Equipos_Inactividad'
gpresult /r /scope computer
Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion'
Get-NetFirewallAddressFilter -AssociatedNetFirewallRule (Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion')
```

El estado real de actualizaciones, antivirus, certificados y ACL particulares requiere comprobación operativa. La configuración de determinadas subcategorías de auditoría Windows está contemplada en `7-WS-DC-Zabbix_Agent.ps1`, pero su aplicación efectiva puede depender de las directivas de grupo vigentes.

---

# 9. Monitoreo y registros

Las fuentes nativas de diagnóstico son los registros de eventos de Windows (`System`, `Application`, `Security`, `Directory Service` y los canales de DNS y DHCP cuando estén habilitados).

Consultas de solo lectura:

```powershell
Get-WinEvent -ListLog '*Directory Service*','*DNS*','*DHCP*' -ErrorAction SilentlyContinue
Get-WinEvent -LogName System -MaxEvents 20
Get-Service NTDS,DNS,DHCPServer,Netlogon -ErrorAction SilentlyContinue
dcdiag /q
repadmin /replsummary
repadmin /showrepl
```

WS-DC-01 incorpora Zabbix Agent clásico, cuya instalación y configuración se documentan en `7-WS-DC-Zabbix_Agent.ps1`. El servidor central Zabbix se encuentra en RL-MON-01 (`192.168.20.20`).

El agente permite supervisar disponibilidad del controlador y recopilar eventos de los registros `Security`, `System`, `Directory Service`, `DNS Server` y `DFS Replication`. El archivo `WS-DC-01-zabbix-import.yaml` define cinco elementos personalizados de eventos Windows y 21 disparadores, además de referenciar la plantilla `Windows by Zabbix agent`.

Los elementos personalizados de eventos son de tipo activo (`ZABBIX_ACTIVE`) y utilizan TCP/10051 hacia RL-MON-01. El agente también mantiene TCP/10050 para consultas pasivas autorizadas.

**Importación obligatoria:** el script PowerShell genera el archivo YAML, pero su incorporación a Zabbix Web es manual. La instalación del agente no certifica por sí sola la recepción de eventos ni la activación efectiva de los disparadores.

Los eventos recopilados no equivalen automáticamente a notificaciones enviadas. Los YAML documentados no configuran canales de aviso.
---

# 10. Copias de seguridad y recuperación

Se deben proteger el **estado del sistema** del controlador (AD DS, SYSVOL y componentes necesarios para una restauración consistente), DNS, DHCP y sus relaciones de failover cuando correspondan, GPO, configuraciones de seguridad y el estado de administración RDP.

También debe conservarse la configuración necesaria para recuperar Zabbix Agent, incluido el archivo `zabbix_agentd.conf`, el script de instalación aprobado y la exportación `WS-DC-01-zabbix-import.yaml`.

Estos elementos no sustituyen las copias del estado del sistema de Windows ni los respaldos independientes de la base MySQL de Zabbix alojada en RL-MON-01.

**Situación documental:** no se dispone de evidencia verificable de destino, programación, frecuencia, retención o restauraciones probadas de copias correspondientes a `WS-DC-01`. No se afirma que exista o no exista una tarea programada a partir de esa limitación.

Comprobaciones no destructivas:

```powershell
wbadmin get versions
Get-WindowsFeature Windows-Server-Backup
Get-DhcpServerv4Scope -ErrorAction SilentlyContinue
Get-DhcpServerv4Failover -ErrorAction SilentlyContinue
repadmin /replsummary
Get-ADDomain | Select-Object PDCEmulator,RIDMaster,InfrastructureMaster
Get-ADForest | Select-Object SchemaMaster,DomainNamingMaster
```

Antes de cualquier recuperación, comprobar la salud y replicación de `WS-DC-02`, los roles FSMO y la disponibilidad de respaldos consistentes. No realizar restauraciones improvisadas de NTDS, SYSVOL ni instantáneas de un controlador replicado.
---

# 11. Administración y mantenimiento

Antes de intervenir, comprobar salud de AD DS, DNS, DHCP, SYSVOL y replicación. Las operaciones de dominio pueden afectar autenticación y resolución de nombres de las tres aplicaciones, sin modificar sus repositorios.

```powershell
hostname
Get-Service NTDS,DNS,DHCPServer,Netlogon,KDC -ErrorAction SilentlyContinue
dcdiag /q
repadmin /replsummary
repadmin /showrepl
Get-ADDomainController -Filter *
Get-DnsServerZone
Get-DhcpServerv4Scope -ComputerName WS-DC-01 -ErrorAction SilentlyContinue
Get-DhcpServerv4Failover -ComputerName WS-DC-01 -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion' -ErrorAction SilentlyContinue
Get-Volume
```

Planificar actualizaciones y reinicios manteniendo disponible el controlador par. Verificar hora, almacenamiento, eventos y replicación antes y después de los cambios. No volver a ejecutar scripts de alcance de dominio simplemente para sincronizar un controlador adicional; evaluar primero su objetivo y sus efectos globales.

**Mantenimiento Zabbix:** comprobar periódicamente el estado del servicio `Zabbix Agent`, la configuración `Server` y `ServerActive`, la regla local TCP/10050, la auditoría efectiva de Windows y la recepción de datos en Zabbix Web.

El script `7-WS-DC-Zabbix_Agent.ps1` no actualiza automáticamente un agente previamente instalado. Cualquier actualización del MSI o modificación de su hash de validación requiere revisión y aprobación del procedimiento correspondiente.
---

# 12. Diagnóstico y resolución de problemas

| Síntoma | Comprobación inicial | Consideración |
|---|---|---|
| Falla resolución DNS | `Resolve-DnsName WS-DC-02.neltek.uy -Server 192.168.10.20`; `Get-Service DNS` | Revisar zona integrada y replicación |
| Inicio de sesión de dominio falla | `dcdiag /q`; `Get-Service NTDS,Netlogon,KDC`; hora del equipo | Revisar Kerberos y sincronización horaria |
| Divergencia entre DCs | `repadmin /replsummary`; `repadmin /showrepl` | Validar AD y SYSVOL antes de reejecutar scripts |
| No se aplica GPO de inactividad | `gpresult /r /scope computer`; `Get-GPO -Name 'GPO_REC_Equipos_Inactividad'` | Revisar vínculos y ACL/excepciones |
| RDP inaccesible | `Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion'`; `Get-Service TermService` | Comprobar origen permitido y NLA; no abrir acceso indiscriminado |
| Cliente no obtiene DHCP | `Get-DhcpServerv4Scope`; `Get-DhcpServerv4Failover`; `Get-Service DHCPServer` | Validar ámbito real, autorización y DHCP Relay cuando aplique |
| No resuelve dominio de aplicación | `Resolve-DnsName recoleccion.neltek.uy -Server 192.168.10.20` | Revisar registro A a `192.168.50.20`; HTTPS se termina fuera del DC |
| Disco o SYSVOL | `Get-Volume`; `Get-SmbShare -Name SYSVOL,NETLOGON` | Inspeccionar capacidad, accesibilidad y eventos |
| Zabbix Agent detenido | `Get-Service -Name 'Zabbix Agent'` | Revisar servicio, configuración y registros del agente |
| Sin comunicación activa con Zabbix Server | `Test-NetConnection -ComputerName 192.168.20.20 -Port 10051` | Comprobar servidor, firewall local y políticas de RL-FW-01 |
| Consultas pasivas Zabbix inaccesibles | `Get-NetTCPConnection -State Listen -LocalPort 10050` | Comprobar escucha y regla local; verificar desde RL-MON-01 |
| WS-DC-01 sin datos en Zabbix Web | Revisar host `WS-DC-01`, plantilla, elementos y últimos datos | Confirmar importación manual del YAML y coincidencia de `Hostname` |

Si falla el proxy o las aplicaciones Laravel, diagnosticar sus respectivos servidores; no modificar archivos de Ciudadana, Administrativo o Camiones desde WS-DC-01.

---
---

# 13. Anexos

Sección reservada para anexos técnicos aprobados posteriormente. No se incorporan anexos en esta edición.
