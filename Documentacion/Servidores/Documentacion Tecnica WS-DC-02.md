# Documentación Técnica del Servidor WS-DC-02

**Fecha de creación:** 03/11/2026  
**Proyecto:** Recolección UY  
**Servidor:** `WS-DC-02`  
**Estado documentado:** infraestructura implementada, operativa y verificada, con servicios de Active Directory, DNS y DHCP configurados y funcionando.

## Índice navegable

- [1. Datos del Servidor](#1-datos-del-servidor)
  - [1.1. Información general](#11-informacion-general)
  - [1.2. Rol del servidor](#12-rol-del-servidor)
  - [1.3. Justificación del sistema operativo](#13-justificacion-del-sistema-operativo)
- [2. Ejecución de Scripts](#2-ejecucion-de-scripts)
  - [2.1. Orden de ejecución](#21-orden-de-ejecucion)
  - [2.2. Procedimiento general](#22-procedimiento-general)
  - [2.3. Scripts específicos del servidor](#23-scripts-especificos-del-servidor)
    - [2.3.1. 2-WS-DC_Config_Local.ps1](#231-2-ws-dc_config_localps1)
    - [2.3.2. 3-WS-DC_RDP_Gestionar_Origenes.ps1](#232-3-ws-dc_rdp_gestionar_origenesps1)
  - [2.4. Scripts comunes](#24-scripts-comunes)
- [3. Arquitectura y componentes del servidor](#3-arquitectura-y-componentes-del-servidor)
- [4. Configuración de red y conectividad](#4-configuracion-de-red-y-conectividad)
- [5. Servicios y contenedores Docker](#5-servicios-y-contenedores-docker)
- [6. Estructura de directorios y almacenamiento](#6-estructura-de-directorios-y-almacenamiento)
- [7. Base de datos MySQL](#7-base-de-datos-mysql)
- [8. Seguridad y control de acceso](#8-seguridad-y-control-de-acceso)
- [9. Monitoreo y registros](#9-monitoreo-y-registros)
- [10. Copias de seguridad y recuperación](#10-copias-de-seguridad-y-recuperacion)
- [11. Administración y mantenimiento](#11-administracion-y-mantenimiento)
- [12. Diagnóstico y resolución de problemas](#12-diagnostico-y-resolucion-de-problemas)
- [13. Anexos](#13-anexos)

---

# 1. Datos del Servidor

## 1.1. Información general

| Campo | Valor |
|---|---|
| Nombre del servidor | `WS-DC-02` |
| Sistema operativo | Windows Server 2012 R2 |
| Interfaz de red | Identificador/alias no confirmado en los archivos |
| Segmento | SERVICIOS — `192.168.10.0/24` |
| Dirección IP | `192.168.10.21` |
| Máscara de subred | `255.255.255.0` (`/24`) |
| Gateway | `192.168.10.1` (`RL-FW-01`) |
| DNS primario | `192.168.10.21` (una vez promovido y operativo) |
| DNS secundario | `192.168.10.20` (`WS-DC-01`) |
| Dominio | `neltek.uy` |

Durante la unión inicial al dominio se utiliza `192.168.10.20` como DNS; después de comprobar la promoción y replicación, el DNS preferido es el propio `WS-DC-02`.

## 1.2. Rol del servidor

`WS-DC-02` es el **controlador de dominio adicional** de `neltek.uy` y proporciona redundancia para Active Directory Domain Services (AD DS), DNS y catálogo global (GC). Participa en la replicación de Active Directory y SYSVOL con `WS-DC-01` (`192.168.10.20`). El diseño incluye el servicio DHCP y una relación de conmutación por error con `WS-DC-01`; el detalle efectivo de ámbitos y estado del failover debe verificarse en el entorno.

Las aplicaciones Recolección UY y los servidores Linux miembros del dominio dependen de la disponibilidad de resolución DNS y servicios de identidad; no se alojan aplicaciones Laravel ni MySQL en `WS-DC-02`.

## 1.3. Justificación del sistema operativo

Windows Server 2012 R2 es la plataforma utilizada por los scripts PowerShell específicos y los procedimientos de AD DS, DNS y DHCP del proyecto. Permite integrarse con `neltek.uy`, administrar directivas de grupo y replicar servicios de directorio. **Advertencia de mantenimiento:** Windows Server 2012 R2 se encuentra fuera de su soporte extendido ordinario; evaluar mitigaciones y un plan de actualización sin modificar unilateralmente la tecnología instalada.

---

# 2. Ejecución de Scripts

## 2.1. Orden de ejecución

La unión al dominio, instalación de roles y promoción de `WS-DC-02` se realizan **antes** de los scripts locales. Se requiere que AD DS, DNS y replicación estén operativos.

| Orden | Script exacto | Función |
|---|---|---|
| 1 | `2-WS-DC_Config_Local.ps1` | Configura DNS cliente, permisos administrativos y RDP con NLA y la regla `REC-RDP-Administracion`, usando parámetros de WS-DC-02. |
| 2 | `3-WS-DC_RDP_Gestionar_Origenes.ps1` | Consulta y administra los orígenes autorizados en la regla RDP creada previamente. |

**Alcance de los demás scripts:** `1-AD_Config_RecoleccionUY.ps1`, `4-AD_Politica_Contrasenas_Dominio.ps1`, `5-GPO_Equipos_Inactividad.ps1`, `5-GPO_Equipos_Inactividad_Excepciones.ps1` y `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1` administran objetos o configuraciones de alcance de dominio o zona DNS. No deben repetirse en `WS-DC-02` solamente por haber incorporado un controlador adicional.

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

### 2.3.1. 2-WS-DC_Config_Local.ps1

**Nombre del script:** `2-WS-DC_Config_Local.ps1`. La numeración integrada es `2`; no se declara etiqueta de versión en el nombre.

**Descripción:** configuración local de controlador de dominio, DNS cliente, RDP y controles de acceso. Comprueba Active Directory, busca la interfaz activa por IP y configura el orden de DNS. Incluye operaciones sobre `Netlogon`, RDP y reglas del firewall de Windows.

**Componentes que instala o utiliza:** módulos PowerShell `ActiveDirectory` y componentes de red y firewall de Windows; no reemplaza la instalación de los roles AD DS, DNS o DHCP.

**Componentes que configura:** DNS cliente de la interfaz correcta; registro DNS de equipo; servicio `Netlogon`; escritorio remoto (RDP), autenticación a nivel de red (NLA), servicio `TermService`, grupo administrativo `GG_REC_Server_Admins_Windows` y regla `REC-RDP-Administracion`. La variable de orígenes RDP del archivo es `192.168.10.0/24`.

**Archivos y directorios creados, modificados o utilizados:** configura parámetros de Windows, grupos y reglas locales; no se documenta una ruta de archivo de salida obligatoria para este script. Utiliza la configuración local de la interfaz detectada; se verifica por `Get-NetIPConfiguration`.

**Requisitos previos:** el dominio `neltek.uy` y sus grupos administrativos deben existir; `WS-DC-01` y `WS-DC-02` deben estar operativos y replicando. Ejecutar en PowerShell elevado.

**Parámetros específicos de WS-DC-02:** el archivo suministrado tiene **valores activos para WS-DC-01**. Antes de ejecutarlo en `WS-DC-02` deben establecerse, como el propio script indica:

```powershell
$ServerIP = "192.168.10.21"
$DNSServers = @(
    "192.168.10.21",
    "192.168.10.20"
)
```

**Ejecución:**

```powershell
Get-Item .\2-WS-DC_Config_Local.ps1
Get-Content .\2-WS-DC_Config_Local.ps1 | Select-String 'ServerIP|DNSServers'
.\2-WS-DC_Config_Local.ps1
```

**Precaución:** no ejecutar con el valor predeterminado `$ServerIP = "192.168.10.20"` sobre `WS-DC-02`; la validación de interfaz fallaría. Conservar el archivo original y preparar una copia con parámetros apropiados si la operación requiere archivos separados por servidor.

### 2.3.2. 3-WS-DC_RDP_Gestionar_Origenes.ps1

**Nombre del script:** `3-WS-DC_RDP_Gestionar_Origenes.ps1`; numeración `3`, sin etiqueta de versión en el nombre.

**Descripción:** menú para visualizar, agregar, eliminar, bloquear temporalmente y restaurar direcciones de origen permitidas para RDP. No administra el firewall de otro servidor.

**Componentes que instala o utiliza:** módulo `NetSecurity`; comandos `Get-NetFirewallRule` y `Get-NetFirewallAddressFilter`, entre otros; no instala roles de servidor.

**Componentes que configura:** regla local de firewall `REC-RDP-Administracion`. Admite IP individuales, redes CIDR e IP/máscara; al eliminar el último origen la regla queda deshabilitada.

**Archivos y directorios creados, modificados o utilizados:** utiliza y puede crear `%ProgramData%\RecoleccionUY\` y el archivo `%ProgramData%\RecoleccionUY\RDP-BlockedOrigins.json` para guardar temporalmente los orígenes al bloquearlos. El marcador interno `127.0.0.1` no representa un origen autorizado.

**Requisitos previos:** ejecutar localmente en `WS-DC-02`, con elevación; la regla `REC-RDP-Administracion` debe existir previamente (creada por el script 2).

**Ejecución:**

```powershell
Get-Item .\3-WS-DC_RDP_Gestionar_Origenes.ps1
Get-NetFirewallRule -Name "REC-RDP-Administracion"
.\3-WS-DC_RDP_Gestionar_Origenes.ps1
```

**Precaución:** restringir RDP sin verificar previamente los orígenes administrativos puede impedir acceso remoto. Mantener un mecanismo de acceso por consola disponible.

## 2.4. Scripts comunes

No se identificaron scripts PowerShell comunes adicionales cuya ejecución sea obligatoria en `WS-DC-02`. Los scripts `1-RL-XXX-config_ssh.sh` y `2-RL-XXX-config_ssh_users.sh` pertenecen a los servidores **Linux** y no se aplican al controlador Windows. Los auxiliares `HOST_CredSSP_Habilitar_Temporal.ps1` y `HOST_CredSSP_Restaurar.ps1` corresponden a la máquina anfitriona de administración, no a la secuencia local del controlador.

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

El equipo de esta ficha es **`WS-DC-02`**. La capa de aplicaciones (`RL-APP-01`), el proxy (`RL-PROXY-01`, `192.168.50.20`) y el monitoreo (`RL-MON-01`) pertenecen a servidores separados. No se les atribuyen sus archivos, contenedores ni servicios a este controlador.
---

# 4. Configuración de red y conectividad

`WS-DC-02` pertenece al segmento SERVICIOS (`192.168.10.0/24`), con IP `192.168.10.21/24`, gateway `192.168.10.1` (`RL-FW-01`) y DNS cliente preferido `192.168.10.21` y alternativo `192.168.10.20`. En `WS-DC-02`, ese orden corresponde al estado posterior a la promoción y verificación de la replicación.

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

Verificaciones sin modificar la configuración:

```powershell
Get-NetIPConfiguration
Get-DnsClientServerAddress -AddressFamily IPv4
Get-NetRoute -AddressFamily IPv4
Resolve-DnsName WS-DC-01.neltek.uy -Server 192.168.10.21
Resolve-DnsName -Type SRV _ldap._tcp.neltek.uy -Server 192.168.10.21
Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion' -ErrorAction SilentlyContinue
Get-NetFirewallAddressFilter -AssociatedNetFirewallRule (Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion')
```

Los dominios públicos `recoleccion.neltek.uy`, `admin-recoleccion.neltek.uy` y `camiones-recoleccion.neltek.uy` se comprueban mediante **HTTPS**. Los registros A internos del proyecto dirigen hacia el proxy `192.168.50.20` (`RL-PROXY-01`); estos registros no implican que el controlador publique las aplicaciones. El eventual HTTP entre proxy y servidores de aplicaciones es tráfico interno distinto del acceso público.
---

# 5. Servicios y contenedores Docker

Docker **no aplica** a la función documentada de `WS-DC-02`. Los servicios de Active Directory, DNS y DHCP son roles nativos de Windows Server; no se atribuyen contenedores, proyectos Compose, imágenes, redes o volúmenes Docker a este controlador.

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

**No aplica una instancia MySQL local a `WS-DC-02`.** La base de datos compartida por la Aplicación Ciudadana, el Backend Administrativo y la Aplicación Camiones pertenece a la capa de aplicaciones, no a los controladores de dominio.

La relación de este servidor con las aplicaciones es indirecta, mediante los servicios de identidad y DNS. No corresponde atribuirle administración, volúmenes, credenciales ni procedimientos de respaldo de MySQL.
---

# 8. Seguridad y control de acceso

- **Identidad:** dominio `neltek.uy`, catálogo global, LDAP y Kerberos. La existencia de LDAPS habilitado no se deduce de un puerto estándar; debe verificarse aparte.
- **Delegación de permisos:** el script `1-AD_Config_RecoleccionUY.ps1` crea grupos de aplicación e infraestructura y gestiona membresías, incluida la integración de `GG_REC_Server_Admins_Windows` con grupos administrativos y de Escritorio remoto. Las cuentas sensibles no se reproducen con credenciales.
- **RDP:** `2-WS-DC_Config_Local.ps1` configura NLA, `TermService` y la regla `REC-RDP-Administracion`; valor de orígenes inicialmente autorizado `192.168.10.0/24`. `3-WS-DC_RDP_Gestionar_Origenes.ps1` permite cambios controlados; consultar el estado efectivo antes de intervenir.
- **Contraseñas:** script 4 fija longitud mínima 12, historial 12, edad máxima 90 días, mínima 1 día, complejidad activada, cifrado reversible desactivado, bloqueo tras 5 errores y intervalos de 15 minutos. Las opciones `PasswordNeverExpires` de cuentas de servicio y privilegiadas se deben revisar expresamente.
- **GPO:** el script de dominio establece bloqueo a 10 minutos y monitor a 15; el script de excepciones modifica ACL para cuentas de equipo designadas. No se presume aplicación al controlador: el script tiene deshabilitado el vínculo a `Domain Controllers`.
- **SSH / sudo / SSSD / SELinux:** no aplican como controles locales propios de este Windows Server, aunque servidores Linux integrados al dominio pueden usarlos.

```powershell
Get-ADDefaultDomainPasswordPolicy -Identity 'neltek.uy'
Get-GPO -Name 'GPO_REC_Equipos_Inactividad'
gpresult /r /scope computer
Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion'
Get-NetFirewallAddressFilter -AssociatedNetFirewallRule (Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion')
```

El estado real de actualizaciones, antivirus, certificados, auditoría avanzada y ACL particulares no está documentado con precisión.

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

Existe un servidor independiente de monitoreo denominado `RL-MON-01`. Los materiales disponibles no permiten identificar en `WS-DC-02` un agente de métricas o envío de logs instalado, ni su versión, endpoint o destino efectivo. La ausencia de esos detalles documentales no demuestra ausencia del servicio.
---

# 10. Copias de seguridad y recuperación

Se deben proteger el **estado del sistema** del controlador (AD DS, SYSVOL y componentes necesarios para una restauración consistente), DNS, DHCP y sus relaciones de failover cuando correspondan, GPO, configuraciones de seguridad y el estado de administración RDP.

**Situación documental:** no se dispone de evidencia verificable de destino, programación, frecuencia, retención o restauraciones probadas de copias correspondientes a `WS-DC-02`. No se afirma que exista o no exista una tarea programada a partir de esa limitación.

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

Antes de cualquier recuperación, comprobar la salud y replicación de `WS-DC-01`, los roles FSMO y la disponibilidad de respaldos consistentes. No realizar restauraciones improvisadas de NTDS, SYSVOL ni instantáneas de un controlador replicado.
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
Get-DhcpServerv4Scope -ComputerName WS-DC-02 -ErrorAction SilentlyContinue
Get-DhcpServerv4Failover -ComputerName WS-DC-02 -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName 'REC-RDP-Administracion' -ErrorAction SilentlyContinue
Get-Volume
```

Planificar actualizaciones y reinicios manteniendo disponible el controlador par. Verificar hora, almacenamiento, eventos y replicación antes y después de los cambios. No volver a ejecutar scripts de alcance de dominio simplemente para sincronizar un controlador adicional; evaluar primero su objetivo y sus efectos globales.
---

# 12. Diagnóstico y resolución de problemas

| Síntoma | Comprobación inicial | Consideración |
|---|---|---|
| WS-DC-02 no resuelve el dominio | `ipconfig /all`; `Resolve-DnsName neltek.uy -Server 192.168.10.20` | Revisar orden de DNS y conectividad con WS-DC-01. |
| Replicación AD fallida | `repadmin /replsummary`; `repadmin /showrepl`; `dcdiag` | Revisar DNS, conectividad, hora y eventos de directorio. |
| Falta SYSVOL / NETLOGON | `Get-SmbShare -Name SYSVOL,NETLOGON` | Verificar sincronización de SYSVOL antes de dar por sano el DC. |
| DNS responde sin registros SRV | `Resolve-DnsName -Type SRV _ldap._tcp.neltek.uy -Server 192.168.10.21` | Revisar servicio DNS, zona y Netlogon. |
| Clientes sin DHCP | `Get-Service DHCPServer`; `Get-DhcpServerv4Scope` | Confirmar ámbitos activos, autorización, opciones y relay cuando proceda. |
| Failover DHCP degradado | `Get-DhcpServerv4Failover` | Comprobar estado del par y conectividad con WS-DC-01. |
| RDP no disponible | `Get-NetFirewallRule -Name REC-RDP-Administracion`; `Get-Service TermService` | Comprobar NLA y direcciones de origen; usar consola si RDP quedó bloqueado. |
| Script local rechaza IP | `Get-NetIPConfiguration`; inspección de `$ServerIP` | El script entregado trae por defecto la IP de WS-DC-01; ajustar a `.21`. |
| Fallan autenticaciones | `Get-Service KDC,Netlogon`; `dcdiag` | Verificar hora, registros SRV y replicación. |
| Espacio o eventos anómalos | `Get-Volume`; `Get-WinEvent` | Revisar almacenamiento y registros sin eliminar datos preventivamente. |

Evitar acciones correctivas destructivas (eliminar zonas, forzar replicaciones, restablecer DHCP o cambiar reglas generales) sin diagnóstico previo y validación del impacto sobre los dos controladores.

---

# 13. Anexos

Sección reservada para anexos técnicos aprobados posteriormente. No se incorporan anexos en esta edición.
