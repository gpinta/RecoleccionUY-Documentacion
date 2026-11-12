# RECOLECCIÓN UY - ORDEN DE DESPLIEGUE POR SERVIDOR

**Actualización:** 12/11/2026 — Incorporación de Zabbix Server, políticas de comunicación y agentes Windows para el monitoreo de WS-DC-01 y WS-DC-02.

**Alcance:** planificación, secuencia de implementación y orden de ejecución de los procedimientos y scripts necesarios para el despliegue integral de la infraestructura de Recolección UY. Comprende la preparación de las redes virtuales VMware, configuración de los controladores de dominio WS-DC-01 y WS-DC-02 con Active Directory, DNS y DHCP Failover, implementación del firewall RL-FW-01, despliegue de las tres aplicaciones Laravel y la base de datos MySQL compartida en RL-APP-01, configuración de Nginx, dnsmasq, WAF y HTTPS en RL-PROXY-01, implementación de Prometheus, Grafana, OpenSearch y Zabbix Server en RL-MON-01, configuración de las políticas de monitoreo en RL-FW-01 e incorporación de agentes Zabbix en WS-DC-01 y WS-DC-02, integración con Active Directory y procedimientos de verificación de los servicios.



## Índice

- [1. Orden general de despliegue](#1-orden-general-de-despliegue)
- [2. Topología de referencia](#2-topología-de-referencia)
- [3. WS-DC-01](#3-ws-dc-01)
  - [1. Configuración inicial de Windows Server](#1-configuración-inicial-de-windows-server)
  - [2. Instalación y configuración de AD DS, DNS y DHCP (procedimiento Windows Server)](#2-instalación-y-configuración-de-ad-ds-dns-y-dhcp-procedimiento-windows-server)
  - [3. 1-AD_Config_RecoleccionUY.ps1](#3-1-ad_config_recoleccionuyps1)
  - [4. 2-WS-DC_Config_Local.ps1](#4-2-ws-dc_config_localps1)
  - [5. 3-WS-DC_RDP_Gestionar_Origenes.ps1](#5-3-ws-dc_rdp_gestionar_origenesps1)
  - [6. 4-AD_Politica_Contrasenas_Dominio.ps1](#6-4-ad_politica_contrasenas_dominiops1)
  - [7. 5-GPO_Equipos_Inactividad.ps1](#7-5-gpo_equipos_inactividadps1)
  - [8. 5-GPO_Equipos_Inactividad_Excepciones.ps1 (no crea una política, edita la ya creada)](#8-5-gpo_equipos_inactividad_excepcionesps1-no-crea-una-política-edita-la-ya-creada)
  - [9. 6-DNS_RegistroA_RecoleccionUY_v1.3.ps1](#9-6-dns_registroa_recoleccionuy_v13ps1)
  - [10. 7-WS-DC-Zabbix_Agent.ps1](#10-7-ws-dc-zabbix_agentps1)
- [4. WS-DC-02](#4-ws-dc-02)
  - [1. Configuración inicial de Windows Server](#1-configuración-inicial-de-windows-server-1)
  - [2. Incorporación al dominio neltek.uy](#2-incorporación-al-dominio-neltekuy)
  - [3. Instalación y configuración de AD DS, DNS y DHCP (procedimiento Windows Server)](#3-instalación-y-configuración-de-ad-ds-dns-y-dhcp-procedimiento-windows-server)
  - [4. 2-WS-DC_Config_Local.ps1](#4-2-ws-dc_config_localps1-1)
  - [5. 3-WS-DC_RDP_Gestionar_Origenes.ps1](#5-3-ws-dc_rdp_gestionar_origenesps1-1)
  - [6. 7-WS-DC-Zabbix_Agent.ps1](#6-7-ws-dc-zabbix_agentps1)
- [5. RL-FW-01](#5-rl-fw-01)
  - [1. 1-RL-FW_update.sh](#1-1-rl-fw_updatesh)
  - [2. 2-RL-FW-config_v1.1.sh](#2-2-rl-fw-config_v11sh)
  - [3. RL-FW-config_domain.sh](#3-rl-fw-config_domainsh)
  - [4. Verificar interfaces y routing](#4-verificar-interfaces-y-routing)
  - [5. Verificar Active Directory](#5-verificar-active-directory)
  - [6. Verificar firewalld / NAT](#6-verificar-firewalld--nat)
  - [7. Configuración de administración SSH](#7-configuración-de-administración-ssh)
  - [8. Verificación final de RL-FW-01](#8-verificación-final-de-rl-fw-01)
  - [9. 4-RL-FW-add_Zabbix.sh](#9-4-rl-fw-add_zabbixsh)
- [6. RL-APP-01](#6-rl-app-01)
  - [1. 1-RL-APP-update.sh](#1-1-rl-app-updatesh)
  - [2. 2-RL-APP-config_domain_2dns_v1.3.sh](#2-2-rl-app-config_domain_2dns_v13sh)
  - [3. Verificar interfaz de APLICACIONES](#3-verificar-interfaz-de-aplicaciones)
  - [4. Verificar gateway y routing mediante RL-FW-01](#4-verificar-gateway-y-routing-mediante-rl-fw-01)
  - [5. 3-RL-APP-config_denuncias_storage_v1.1.sh](#5-3-rl-app-config_denuncias_storage_v11sh)
  - [6. 4-RL-APP-config_docker_red.sh](#6-4-rl-app-config_docker_redsh)
  - [7. Docker Compose Ciudadana/API](#7-docker-compose-ciudadanaapi)
  - [8. Docker Compose Admin](#8-docker-compose-admin)
  - [9. Docker Compose Camiones](#9-docker-compose-camiones)
  - [10. Verificar contenedores](#10-verificar-contenedores)
  - [11. Verificar puertos locales](#11-verificar-puertos-locales)
  - [12. Verificar red Docker](#12-verificar-red-docker)
  - [13. RL-APP-DB_Backup_and_Restore](#13-rl-app-db_backup_and_restore)
  - [14. config_ssh.sh](#14-config_sshsh)
  - [15. config_ssh_users.sh](#15-config_ssh_userssh)
- [7. RL-PROXY-01](#7-rl-proxy-01)
  - [1. 1-RL-PROXY-update.sh](#1-1-rl-proxy-updatesh)
  - [2. 2-RL-PROXY-config_domain_2dns_v1.3.sh](#2-2-rl-proxy-config_domain_2dns_v13sh)
  - [3. Verificar interfaz de DMZ](#3-verificar-interfaz-de-dmz)
  - [4. Verificar gateway y routing mediante RL-FW-01](#4-verificar-gateway-y-routing-mediante-rl-fw-01-1)
  - [5. Verificar acceso a aplicaciones antes de configurar proxy](#5-verificar-acceso-a-aplicaciones-antes-de-configurar-proxy)
  - [6. 3-RL-PROXY-config_proxy_http.sh](#6-3-rl-proxy-config_proxy_httpsh)
  - [7. 4-RL-PROXY-install_WAF.sh](#7-4-rl-proxy-install_wafsh)
  - [8. 5-RL-PROXY-generar_certificados_tls.sh](#8-5-rl-proxy-generar_certificados_tlssh)
  - [9. 6-RL-PROXY-migrar_waf_https.sh](#9-6-rl-proxy-migrar_waf_httpssh)
  - [10. 7-RL-PROXY-FIX_nginx.sh](#10-7-rl-proxy-fix_nginxsh)
  - [11. Verificar contenedores](#11-verificar-contenedores)
  - [12. Verificar configuración Nginx](#12-verificar-configuración-nginx)
  - [13. Verificar DNS del proxy](#13-verificar-dns-del-proxy)
  - [14. Verificar publicación HTTPS mediante Host](#14-verificar-publicación-https-mediante-host)
  - [15. config_ssh.sh](#15-config_sshsh)
  - [16. config_ssh_users.sh](#16-config_ssh_userssh)
- [8. RL-MON-01 (MONITOREO)](#8-rl-mon-01-monitoreo)
  - [1. 1-RL-MON-update.sh](#1-1-rl-mon-updatesh)
  - [2. 2-RL-MON-config_domain_2dns_v1.3.sh](#2-2-rl-mon-config_domain_2dns_v13sh)
  - [3. Verificar conectividad del segmento MONITOREO](#3-verificar-conectividad-del-segmento-monitoreo)
  - [4. 3-RL-MON-monitoreo.sh](#4-3-rl-mon-monitoreosh)
  - [5. 4-RL-MON-OpenSearch.sh](#5-4-rl-mon-opensearchsh)
  - [6. 5-RL-MON-Zabbix.sh](#6-5-rl-mon-zabbixsh)
  - [7. RL-MON-add_dashboard_general.sh](#7-rl-mon-add_dashboard_generalsh)
  - [8. Verificar contenedores de monitoreo](#8-verificar-contenedores-de-monitoreo)
  - [9. Verificar métricas y registros](#9-verificar-métricas-y-registros)
  - [10. 1-RL-XXX-config_ssh.sh](#10-1-rl-xxx-config_sshsh)
  - [11. 2-RL-XXX-config_ssh_users.sh](#11-2-rl-xxx-config_ssh_userssh)
- [9. DNS / PUBLICACIÓN DE APLICACIONES](#9-dns--publicación-de-aplicaciones)
  - [1. 6-DNS_RegistroA_RecoleccionUY_v1.3.ps1](#1-6-dns_registroa_recoleccionuy_v13ps1)
  - [2. Verificar DNS en clientes](#2-verificar-dns-en-clientes)
  - [3. Verificar WAN / RL-FW-01 / RL-PROXY-01](#3-verificar-wan--rl-fw-01--rl-proxy-01)
  - [4. Verificar acceso real a Ciudadana, Administrativo y Camiones](#4-verificar-acceso-real-a-ciudadana-administrativo-y-camiones)
  - [5. Verificar seguridad de publicación](#5-verificar-seguridad-de-publicación)
- [10. AGENTES DE MONITOREO E INTEGRACIÓN](#10-agentes-de-monitoreo-e-integración)
  - [1. RL-APP-01: 5-RL-APP-install_node_exporter.sh](#1-rl-app-01-5-rl-app-install_node_exportersh)
  - [2. RL-APP-01: 6-RL-APP-install_fluent_bit.sh](#2-rl-app-01-6-rl-app-install_fluent_bitsh)
  - [3. RL-PROXY-01: 8-RL-PROXY-install_node_exporter.sh](#3-rl-proxy-01-8-rl-proxy-install_node_exportersh)
  - [4. RL-PROXY-01: 9-RL-PROXY-install_fluent_bit.sh](#4-rl-proxy-01-9-rl-proxy-install_fluent_bitsh)
  - [5. RL-FW-01: 3-RL-FW-add_MON_AD.sh](#5-rl-fw-01-3-rl-fw-add_mon_adsh)
  - [6. Verificar métricas](#6-verificar-métricas)
  - [7. Verificar logs](#7-verificar-logs)
  - [8. Integración Zabbix — RL-FW-01 / WS-DC-01 / WS-DC-02](#8-integración-zabbix--rl-fw-01--ws-dc-01--ws-dc-02)
  - [9. Verificar monitoreo Zabbix](#9-verificar-monitoreo-zabbix)
- [11. VERIFICACIÓN FINAL DE TODOS LOS SERVIDORES](#11-verificación-final-de-todos-los-servidores)
  - [1. Verificar VMware / redes](#1-verificar-vmware--redes)
  - [2. Verificar WS-DC-01 / WS-DC-02](#2-verificar-ws-dc-01--ws-dc-02)
  - [3. Verificar RL-FW-01](#3-verificar-rl-fw-01)
  - [4. Verificar RL-APP-01](#4-verificar-rl-app-01)
  - [5. Verificar RL-PROXY-01](#5-verificar-rl-proxy-01)
  - [6. Verificar publicación](#6-verificar-publicación)
  - [7. Verificar RL-MON-01 cuando esté desplegado](#7-verificar-rl-mon-01-cuando-esté-desplegado)
  - [8. Verificar seguridad](#8-verificar-seguridad)


---

## 1. Orden general de despliegue

1. Preparación VMware / VMnet.
2. WS-DC-01: Active Directory principal y DNS.
3. WS-DC-02: controlador adicional y DNS.
4. RL-FW-01: firewall, routing, NAT y administración por AD.
5. RL-APP-01: MySQL, Ciudadana/API, Administrativo y Camiones.
6. RL-PROXY-01: Nginx, dnsmasq, WAF y TLS.
7. DNS definitivo y publicación desde clientes.
8. RL-MON-01: Prometheus, Grafana, OpenSearch, Fluent Bit y Zabbix Server, según los scripts específicos de despliegue.
9. Integración Zabbix: políticas de red en RL-FW-01, agentes Windows en WS-DC-01 y WS-DC-02, importación de hosts y verificación del monitoreo.

## 2. Topología de referencia

|Servidor        |IP                                                            |Red / función             |
|:--------------:|:------------------------------------------------------------:|:------------------------ |
|**WS-DC-01**    |`192.168.10.20`                                               |SERVICIOS / AD / DNS      |
|**WS-DC-02**    |`192.168.10.21`                                               |SERVICIOS / AD / DNS      |
|**RL-FW-01**    |`192.168.10.1`, `192.168.20.1`, `192.168.30.1`, `192.168.50.1`|Router y firewall central |
|**RL-APP-01**   |`192.168.30.20`                                               |APLICACIONES              |
|**RL-PROXY-01** |`192.168.50.20`                                               |DMZ                       |
|**RL-MON-01**   |`192.168.20.20`                                               |MONITOREO                 |

La interfaz WAN de RL-FW-01 es `ens33` y utiliza DHCP; consultar la dirección efectiva antes de configurar publicación y DNS externo.

=================================================
## 3. WS-DC-01
=================================================

### 1. Configuración inicial de Windows Server
   -> hostname = WS-DC-01
   -> interfaz SERVICIOS = 192.168.10.20/24
   -> gateway = 192.168.10.1
   -> DNS inicial = 192.168.10.20
   -> configura hora, red y servicios básicos

### 2. Instalación y configuración de AD DS, DNS y DHCP (procedimiento Windows Server)

   -> INSTALACIÓN DE ROLES
      -> instala Active Directory Domain Services (AD DS)
      -> instala DNS Server
      -> instala DHCP Server

   -> CONFIGURACIÓN DE ACTIVE DIRECTORY
      -> promociona WS-DC-01 como primer controlador de dominio
      -> selecciona agregar un nuevo bosque
      -> dominio raíz = neltek.uy
      -> configura nivel funcional del bosque y dominio
      -> habilita DNS y Global Catalog durante la promoción
      -> configura contraseña DSRM
      -> verifica requisitos previos de instalación
      -> completa promoción y reinicia Windows Server
      -> verifica funcionamiento de Active Directory
      -> verifica servicios LDAP y Kerberos
      -> mantiene inicialmente los roles FSMO en WS-DC-01
      -> configura sincronización horaria del dominio

   -> CONFIGURACIÓN DE DNS
      -> utiliza DNS integrado con Active Directory
      -> verifica creación de zona directa neltek.uy
      -> configura actualizaciones dinámicas seguras
      -> verifica registros DNS del controlador de dominio
      -> verifica registros SRV de LDAP y Kerberos
      -> configura DNS preferido = 192.168.10.20
      -> incorpora DNS alternativo = 192.168.10.21
         cuando WS-DC-02 esté operativo
      -> verifica resolución del dominio neltek.uy

   -> CONFIGURACIÓN DE DHCP
      -> completa configuración posterior a la instalación
      -> autoriza WS-DC-01 como servidor DHCP en Active Directory
      -> crea ámbitos DHCP únicamente para redes que requieran asignación dinámica
      -> configura rangos de direcciones IP
      -> configura exclusiones para direcciones IP estáticas
      -> configura opción 003 = gateway correspondiente a cada red
      -> configura opción 006 = DNS 192.168.10.20
      -> incorpora DNS 192.168.10.21 cuando esté operativo
      -> configura opción 015 = neltek.uy
      -> configura duración de concesiones
      -> activa ámbitos DHCP definidos
      -> verifica asignación de IP, gateway, DNS y dominio
      -> deja preparado DHCP para configurar Failover con WS-DC-02

   -> VERIFICACIÓN FINAL
      -> verifica Active Directory operativo
      -> verifica DNS operativo
      -> verifica DHCP operativo
      -> verifica resolución de neltek.uy
      -> verifica autenticación LDAP y Kerberos
      -> deja preparado WS-DC-01 para incorporar WS-DC-02
      -> completar antes de ejecutar scripts de objetos AD

### 3. 1-AD_Config_RecoleccionUY.ps1
   -> crea/verifica la estructura de OU del proyecto Recolección UY
   -> crea/verifica grupos de seguridad y administración
   -> crea cuentas de prueba definidas
   -> crea cuenta privilegiada infra01
   -> crea cuenta de servicio svc_recoleccion_ldap
   -> configura membresías administrativas Windows/Linux
   -> crea/verifica grupo GG_REC_Server_Admins_Windows
   -> evita duplicar objetos existentes

### 4. 2-WS-DC_Config_Local.ps1
   -> configura DNS cliente del controlador
   -> configura RDP y autenticación NLA
   -> configura servicio TermService
   -> configura reglas de firewall para RDP
   -> crea/verifica regla REC-RDP-Administracion
   -> configura orígenes RDP iniciales = 192.168.10.0/24
   -> configura permisos de administración RDP definidos

### 5. 3-WS-DC_RDP_Gestionar_Origenes.ps1
   -> permite consultar orígenes autorizados para RDP
   -> permite agregar direcciones IP y redes CIDR
   -> permite eliminar orígenes autorizados
   -> permite bloquear temporalmente los accesos
   -> permite restaurar orígenes guardados
   -> administra regla REC-RDP-Administracion

### 6. 4-AD_Politica_Contrasenas_Dominio.ps1
   -> configura longitud mínima = 12 caracteres
   -> configura historial = 12 contraseñas
   -> configura edad máxima = 90 días
   -> configura edad mínima = 1 día
   -> habilita complejidad de contraseñas
   -> deshabilita cifrado reversible
   -> configura bloqueo tras 5 intentos fallidos
   -> configura duración de bloqueo = 15 minutos
   -> configura reinicio del contador = 15 minutos
   -> administra excepciones de expiración de cuentas

### 7. 5-GPO_Equipos_Inactividad.ps1
   -> crea/verifica GPO_REC_Equipos_Inactividad
   -> configura bloqueo por inactividad = 10 minutos
   -> configura apagado de monitor = 15 minutos
   -> vincula GPO a OU Clientes
   -> vincula GPO a OU Servidores
   -> no vincula la GPO a Domain Controllers por defecto

### 8. 5-GPO_Equipos_Inactividad_Excepciones.ps1 (no crea una política, edita la ya creada)
   -> permite consultar equipos excluidos
   -> permite agregar equipos a las excepciones
   -> permite quitar equipos de las excepciones
   -> permite verificar exclusiones
   -> aplica Deny - Apply Group Policy al equipo seleccionado

### 9. 6-DNS_RegistroA_RecoleccionUY_v1.3.ps1
   -> verifica zona DNS neltek.uy
   -> crea/verifica registro A recoleccion.neltek.uy
   -> crea/verifica registro A admin-recoleccion.neltek.uy
   -> crea/verifica registro A camiones-recoleccion.neltek.uy
   -> actualiza registros existentes cuando corresponde
   -> utiliza variable $ProxyServerIP para definir la IP de destino
   -> ProxyServerIP = 192.168.50.20 (RL-PROXY-01)
   -> los tres registros A apuntan a RL-PROXY-01
   -> no requiere modificar la IP mientras se mantenga la topología vigente

### 10. 7-WS-DC-Zabbix_Agent.ps1
   -> ejecutar durante la etapa de integración de Zabbix
   -> requiere Zabbix Server preparado en RL-MON-01
   -> requiere conectividad autorizada mediante RL-FW-01
   -> instala/configura Zabbix Agent clásico
   -> configura Hostname = WS-DC-01
   -> configura Server = 192.168.20.20
   -> configura ServerActive = 192.168.20.20
   -> configura regla local de firewall TCP/10050
   -> configura auditoría de eventos Windows
   -> genera WS-DC-01-zabbix-import.yaml
   -> importar el YAML manualmente desde Zabbix Web
   -> verificar servicio, conectividad y recepción de eventos
  

=================================================
## 4. WS-DC-02
=================================================

### 1. Configuración inicial de Windows Server
   -> hostname = WS-DC-02
   -> interfaz SERVICIOS = 192.168.10.21/24
   -> gateway = 192.168.10.1
   -> DNS preferido = 192.168.10.20
   -> verifica conectividad con WS-DC-01
   -> verifica resolución DNS de neltek.uy
   -> verifica fecha, hora y sincronización

### 2. Incorporación al dominio neltek.uy
   -> une WS-DC-02 al dominio existente neltek.uy
   -> utiliza una cuenta autorizada para unir equipos
   -> reinicia Windows Server
   -> verifica pertenencia al dominio
   -> verifica autenticación contra Active Directory
   -> verifica comunicación con WS-DC-01
   -> completar antes de instalar y configurar los roles

### 3. Instalación y configuración de AD DS, DNS y DHCP (procedimiento Windows Server)
   -> INSTALACIÓN DE ROLES
      -> instala Active Directory Domain Services (AD DS)
      -> instala DNS Server
      -> instala DHCP Server

   -> CONFIGURACIÓN DE ACTIVE DIRECTORY
      -> promociona WS-DC-02 como controlador de dominio adicional
      -> selecciona agregar un controlador de dominio a un dominio existente
      -> dominio = neltek.uy
      -> selecciona WS-DC-01 como origen de replicación inicial
      -> habilita DNS y Global Catalog durante la promoción
      -> configura contraseña DSRM
      -> verifica requisitos previos de instalación
      -> completa promoción y reinicia Windows Server
      -> verifica funcionamiento de Active Directory
      -> verifica replicación de usuarios, grupos, OU y GPO
      -> verifica replicación de SYSVOL
      -> verifica servicios LDAP y Kerberos
      -> mantiene inicialmente los roles FSMO en WS-DC-01
      -> verifica sincronización horaria del dominio

   -> CONFIGURACIÓN DE DNS
      -> utiliza DNS integrado con Active Directory
      -> replica la zona DNS neltek.uy desde WS-DC-01
      -> verifica actualizaciones dinámicas seguras
      -> verifica registros DNS de ambos controladores
      -> verifica registros SRV de LDAP y Kerberos
      -> configura DNS preferido = 192.168.10.21 tras promoción
      -> configura DNS alternativo = 192.168.10.20
      -> verifica resolución del dominio neltek.uy
      -> verifica resolución DNS utilizando ambos servidores
      -> comprueba replicación de zonas DNS integradas con AD

   -> CONFIGURACIÓN DE DHCP
      -> completa configuración posterior a la instalación
      -> autoriza WS-DC-02 como servidor DHCP en Active Directory
      -> verifica los ámbitos DHCP existentes en WS-DC-01
      -> configura DHCP Failover con WS-DC-01
      -> selecciona los ámbitos que participarán en Failover
      -> configura modo de alta disponibilidad según política definida
      -> establece parámetros de relación y tiempos de Failover
      -> configura sincronización de concesiones DHCP
      -> utiliza las opciones DHCP existentes:
         opción 003 = gateway correspondiente a cada red
         opción 006 = DNS 192.168.10.20 / 192.168.10.21
         opción 015 = neltek.uy
      -> evita crear ámbitos independientes con rangos superpuestos
      -> verifica replicación de ámbitos y concesiones
      -> verifica disponibilidad del servicio DHCP en ambos servidores
      -> comprueba funcionamiento de Failover

   -> VERIFICACIÓN FINAL
      -> verifica Active Directory operativo
      -> verifica replicación AD con WS-DC-01
      -> verifica DNS operativo en ambos controladores
      -> verifica registros LDAP y Kerberos
      -> verifica replicación SYSVOL
      -> verifica DHCP operativo
      -> verifica estado de DHCP Failover
      -> ejecuta dcdiag
      -> ejecuta repadmin /replsummary
      -> ejecuta repadmin /showrepl
      -> verifica resolución DNS de neltek.uy
      -> verifica autenticación contra ambos controladores
      -> confirma redundancia de AD DS, DNS y DHCP

### 4. 2-WS-DC_Config_Local.ps1
   -> configura DNS cliente del controlador
   -> utiliza parámetros correspondientes a WS-DC-02
   -> ServerIP = 192.168.10.21
   -> DNSServers = 192.168.10.20 / 192.168.10.21
   -> verifica grupo GG_REC_Server_Admins_Windows
   -> configura RDP y autenticación NLA
   -> configura servicio TermService
   -> configura reglas de firewall para RDP
   -> crea/verifica regla REC-RDP-Administracion
   -> configura orígenes RDP iniciales = 192.168.10.0/24
   -> configura permisos de administración RDP definidos

### 5. 3-WS-DC_RDP_Gestionar_Origenes.ps1
   -> permite consultar orígenes autorizados para RDP
   -> permite agregar direcciones IP y redes CIDR
   -> permite eliminar orígenes autorizados
   -> permite bloquear temporalmente los accesos
   -> permite restaurar orígenes guardados
   -> administra regla REC-RDP-Administracion

### 6. 7-WS-DC-Zabbix_Agent.ps1
   -> ejecutar durante la etapa de integración de Zabbix
   -> requiere Zabbix Server preparado en RL-MON-01
   -> requiere conectividad autorizada mediante RL-FW-01
   -> instala/configura Zabbix Agent clásico
   -> configura Hostname = WS-DC-02
   -> configura Server = 192.168.20.20
   -> configura ServerActive = 192.168.20.20
   -> configura regla local de firewall TCP/10050
   -> configura auditoría de eventos Windows
   -> genera WS-DC-02-zabbix-import.yaml
   -> importar el YAML manualmente desde Zabbix Web
   -> verificar servicio, conectividad y recepción de eventos

=================================================
## 5. RL-FW-01
=================================================

### 1. 1-RL-FW_update.sh
   -> verifica que el sistema operativo sea Rocky Linux
   -> actualiza Rocky Linux
   -> instala herramientas básicas del sistema
   -> instala NetworkManager
   -> instala herramientas de red y diagnóstico
   -> instala OpenSSH
   -> instala firewalld
   -> instala componentes SELinux
   -> instala dependencias Active Directory / LDAP
   -> instala realmd / SSSD / Kerberos / oddjob
   -> habilita IPv4 forwarding
   -> configura parámetros seguros de routing IPv4
   -> deshabilita ICMP redirects y source routing
   -> habilita NetworkManager
   -> habilita sshd
   -> habilita firewalld
   -> habilita oddjobd
   -> verifica paquetes y servicios instalados
   -> verifica interfaces de red detectadas
   -> verifica tabla de rutas
   -> verifica estado de SELinux
   -> verifica necesidad de reiniciar por actualización del kernel
   -> NO configura interfaces, NAT ni unión al dominio

### 2. 2-RL-FW-config_v1.1.sh
   -> configura hostname = RL-FW-01
   -> configura /etc/hosts
   -> realiza respaldo de configuración existente

   -> CONFIGURACIÓN DE INTERFACES
      -> ens33 = WAN (Bridged / DHCP)
      -> ens36 = 192.168.10.1/24 SERVICIOS
      -> ens37 = 192.168.20.1/24 MONITOREO
      -> ens38 = 192.168.30.1/24 APLICACIONES
      -> ens39 = 192.168.50.1/24 DMZ
      -> configura perfiles mediante NetworkManager
      -> establece IP estáticas en redes internas
      -> evita gateways predeterminados en interfaces internas
      -> establece ruta default únicamente por WAN

   -> CONFIGURACIÓN DNS
      -> DNS1 = 192.168.10.20 (WS-DC-01)
      -> DNS2 = 192.168.10.21 (WS-DC-02)
      -> configura resolución DNS mediante SERVICIOS
      -> ignora DNS automático de WAN

   -> CONFIGURACIÓN DE ROUTING
      -> habilita net.ipv4.ip_forward = 1
      -> deshabilita ICMP redirects
      -> deshabilita source routing
      -> verifica rutas de las redes internas

   -> CONFIGURACIÓN FIREWALLD
      -> crea zona rec-wan
      -> crea zona rec-servicios
      -> crea zona rec-monitoreo
      -> crea zona rec-apps
      -> crea zona rec-dmz
      -> asocia interfaces con sus zonas
      -> recrea políticas de comunicación entre redes

   -> CONFIGURACIÓN NAT
      -> habilita masquerade en rec-wan
      -> permite salida hacia WAN desde redes internas

   -> POLÍTICAS SERVICIOS / ACTIVE DIRECTORY
      -> permite RL-APP-01 -> WS-DC-01 / WS-DC-02
      -> permite RL-PROXY-01 -> WS-DC-01 / WS-DC-02
      -> habilita puertos necesarios de DNS / LDAP / Kerberos
      -> contempla LDAPS, SMB, NTP y Global Catalog

   -> POLÍTICAS APLICACIONES
      -> permite RL-PROXY-01 -> 192.168.30.20:8080
      -> permite RL-PROXY-01 -> 192.168.30.20:8081
      -> permite RL-PROXY-01 -> 192.168.30.20:8082
      -> NO publica directamente MySQL 3306

   -> POLÍTICAS MONITOREO
      -> permite RL-MON-01 -> RL-APP-01 TCP/9100
      -> permite RL-MON-01 -> RL-PROXY-01 TCP/9100
      -> permite RL-APP-01 -> RL-MON-01 TCP/9200
      -> permite RL-PROXY-01 -> RL-MON-01 TCP/9200

   -> PUBLICACIÓN WAN / DMZ
      -> configura DNAT WAN TCP/80 -> 192.168.50.20:80
      -> configura DNAT WAN TCP/443 -> 192.168.50.20:443
      -> configura política rec-wan-to-dmz
      -> NO publica directamente 8080, 8081, 8082 ni 3306
      -> HTTPS requiere servicio TCP/443 operativo en RL-PROXY-01

   -> VERIFICACIÓN
      -> verifica interfaces configuradas
      -> verifica ruta default por ens33
      -> verifica DNS de Active Directory
      -> verifica zonas firewalld
      -> verifica políticas activas
      -> verifica masquerade WAN
      -> verifica IPv4 forwarding
      -> mantiene sshd activo sin habilitar acceso SSH en firewalld

### 3. RL-FW-config_domain.sh
   -> verifica configuración de red realizada previamente
   -> verifica interfaz ens36 = 192.168.10.1/24
   -> verifica hostname = RL-FW-01
   -> verifica configuración de /etc/hosts
   -> verifica DNS1 = 192.168.10.20
   -> verifica DNS2 = 192.168.10.21
   -> verifica resolución de neltek.uy
   -> verifica registros SRV LDAP de Active Directory
   -> comprueba si RL-FW-01 ya pertenece al dominio
   -> descubre dominio neltek.uy mediante realmd
   -> une RL-FW-01 al dominio neltek.uy si corresponde
   -> evita repetir realm join si ya pertenece al dominio
   -> verifica archivo /etc/sssd/sssd.conf
   -> realiza respaldo de configuración SSSD
   -> configura use_fully_qualified_names = False
   -> configura fallback_homedir = /home/%u
   -> habilita cache_credentials = True
   -> valida configuración mediante sssctl config-check
   -> habilita y reinicia SSSD
   -> habilita oddjobd
   -> configura creación automática de HOME mediante authselect
   -> verifica estado de SSSD y oddjobd
   -> verifica pertenencia al dominio mediante realm list
   -> verifica resolución DNS de WS-DC-01 y WS-DC-02
   -> NO configura usuarios SSH, grupos autorizados ni sudo

### 4. Verificar interfaces y routing
   -> ip -br addr
   -> ip route
   -> ens33 = WAN
   -> ens36 = 192.168.10.1/24
   -> ens37 = 192.168.20.1/24
   -> ens38 = 192.168.30.1/24
   -> ens39 = 192.168.50.1/24
   -> ruta default únicamente mediante ens33
   -> verificar net.ipv4.ip_forward = 1

### 5. Verificar Active Directory
   -> realm list
   -> sssctl config-check
   -> systemctl status sssd
   -> systemctl status oddjobd
   -> verificar resolución de WS-DC-01
   -> verificar resolución de WS-DC-02
   -> verificar acceso a usuarios AD autorizados

### 6. Verificar firewalld / NAT
   -> firewall-cmd --get-active-zones
   -> firewall-cmd --get-active-policies
   -> firewall-cmd --zone=rec-wan --query-masquerade
   -> verificar políticas entre SERVICIOS, MONITOREO,
      APLICACIONES y DMZ
   -> verificar publicación TCP/80 y TCP/443 hacia RL-PROXY-01

### 7. Configuración de administración SSH
   -> config_ssh.sh
   -> config_ssh_users.sh
   -> configura usuarios y grupos AD autorizados
   -> verifica grupo gg_rec_server_admins_linux
   -> configura privilegios sudo autorizados
   -> habilita acceso SSH en firewalld únicamente
      desde los orígenes administrativos permitidos
   -> verifica acceso antes de cerrar sesión de recuperación

### 8. Verificación final de RL-FW-01
   -> NetworkManager operativo
   -> firewalld operativo
   -> IPv4 forwarding habilitado
   -> routing entre redes operativo
   -> NAT hacia WAN operativo
   -> políticas inter-red aplicadas
   -> DNS Active Directory operativo
   -> RL-FW-01 unido a neltek.uy
   -> SSSD operativo
   -> administración SSH autorizada
   -> publicación WAN hacia RL-PROXY-01 configurada
   -> mantener una única ruta default por ens33

### 9. 4-RL-FW-add_Zabbix.sh
   -> ejecutar durante la etapa de integración de Zabbix
   -> requiere Zabbix Server preparado en RL-MON-01
   -> configura políticas firewalld para monitoreo Zabbix
   -> crea/verifica política rec-zbx-mon-dc
   -> permite RL-MON-01 -> WS-DC-01 / WS-DC-02 TCP/10050
   -> crea/verifica política rec-zbx-dc-mon
   -> permite WS-DC-01 / WS-DC-02 -> RL-MON-01 TCP/10051
   -> conserva las políticas de red existentes
   -> verifica las políticas configuradas
   -> comprobar conectividad entre Zabbix Server y agentes Windows

=================================================
## 6. RL-APP-01
=================================================

### 1. 1-RL-APP-update.sh
   -> verifica que el sistema operativo sea Rocky Linux
   -> actualiza Rocky Linux
   -> instala herramientas básicas del sistema
   -> instala complementos de DNF
   -> instala OpenSSH
   -> instala firewalld
   -> instala herramientas SELinux
   -> instala dependencias Active Directory / LDAP
   -> instala realmd / SSSD / Kerberos / oddjob
   -> configura repositorio oficial Docker CE
   -> instala Docker CE
   -> instala Docker Compose Plugin
   -> instala Containerd
   -> habilita Docker
   -> habilita Containerd
   -> habilita sshd
   -> habilita firewalld
   -> verifica paquetes y servicios instalados
   -> verifica funcionamiento de Docker Engine
   -> verifica estado de SELinux
   -> verifica necesidad de reiniciar por actualización del kernel
   -> NO configura redes Docker, Active Directory, SSSD ni SSH

### 2. 2-RL-APP-config_domain_2dns_v1.3.sh
   -> verifica dependencias instaladas
   -> verifica interfaz de red ens33
   -> identifica perfil NetworkManager
   -> configura IP estática = 192.168.30.20/24
   -> configura gateway = 192.168.30.1
   -> configura DNS1 = 192.168.10.20 (WS-DC-01)
   -> configura DNS2 = 192.168.10.21 (WS-DC-02)
   -> deshabilita DNS automático
   -> deshabilita IPv6 en la interfaz
   -> aplica configuración de red
   -> verifica dirección IP configurada
   -> configura hostname = RL-APP-01
   -> configura /etc/hosts
   -> realiza respaldo de /etc/hosts
   -> verifica resolución DNS de neltek.uy
   -> verifica registros SRV LDAP de Active Directory
   -> comprueba si el servidor ya pertenece al dominio
   -> descubre dominio neltek.uy mediante realmd
   -> une RL-APP-01 al dominio neltek.uy si corresponde
   -> evita repetir realm join si ya pertenece al dominio
   -> verifica archivo /etc/sssd/sssd.conf
   -> realiza respaldo de configuración SSSD
   -> configura use_fully_qualified_names = False
   -> configura fallback_homedir = /home/%u
   -> habilita cache_credentials = True
   -> valida configuración mediante sssctl config-check
   -> habilita y reinicia SSSD
   -> habilita oddjobd
   -> configura creación automática de HOME mediante authselect
   -> verifica estado de SSSD y oddjobd
   -> verifica pertenencia al dominio mediante realm list
   -> verifica resolución DNS de WS-DC-01 y WS-DC-02
   -> NO configura usuarios SSH, grupos autorizados ni sudo

### 3. Verificar interfaz de APLICACIONES
   -> interfaz = ens33
   -> red = 192.168.30.0/24
   -> IP = 192.168.30.20/24
   -> ip -br addr
   -> verificar configuración aplicada por NetworkManager

### 4. Verificar gateway y routing mediante RL-FW-01
   -> gateway = 192.168.30.1
   -> ip route
   -> verificar ruta predeterminada mediante RL-FW-01
   -> comunicación con SERVICIOS a través de RL-FW-01
   -> verificar acceso DNS a 192.168.10.20 / 192.168.10.21
   -> no utilizar segunda interfaz Bridged

### 5. 3-RL-APP-config_denuncias_storage_v1.1.sh
   -> verifica ejecución con privilegios root
   -> crea/verifica directorio principal:
      /srv/recoleccion-data/fotos
   -> estructura de almacenamiento utilizada:
      /srv/recoleccion-data/fotos/{denuncia_id}/foto_denuncia
      /srv/recoleccion-data/fotos/{denuncia_id}/foto_resolucion
   -> configura propietario UID = 33
   -> configura grupo GID = 33
   -> aplica propietario 33:33 recursivamente
   -> configura permisos 755 en directorios
   -> configura permisos 644 en archivos
   -> verifica directorios y permisos configurados
   -> muestra contenido existente hasta profundidad 2
   -> prepara almacenamiento persistente para Docker
   -> montaje Aplicación Ciudadana y Backend Administrativo:
      /srv/recoleccion-data/fotos:/var/www/shared-denuncias:rw,z
   -> montaje Aplicación Camiones:
      /srv/recoleccion-data/fotos:/var/www/shared-fotos:rw,z
   -> NO inicia contenedores
   -> NO modifica Docker Compose
   -> NO elimina fotografías ni directorios existentes

### 6. 4-RL-APP-config_docker_red.sh
   -> verifica ejecución con privilegios root
   -> verifica Docker instalado
   -> verifica Docker Engine operativo
   -> crea/verifica red Docker recoleccion-db-net
   -> reutiliza la red si ya existe
   -> muestra redes Docker disponibles
   -> verifica nombre, driver, scope y subnet de la red
   -> prepara conectividad para:
      recoleccion_api
      recoleccion_admin
      recoleccion_camiones
      recoleccion_db
   -> NO crea recoleccion-proxy-net
   -> NO elimina redes Docker existentes
   -> NO inicia contenedores
   -> NO publica MySQL 3306
   -> RL-PROXY-01 se comunica mediante IP y puertos de RL-APP-01

### 7. Docker Compose Ciudadana/API
   -> levanta recoleccion_api
   -> levanta recoleccion_db
   -> API publica únicamente:
      192.168.30.20:8080
   -> MySQL permanece privado en:
      recoleccion-db-net
   -> utiliza almacenamiento persistente de MySQL
   -> utiliza almacenamiento compartido de denuncias
   -> NO publicar 3306

### 8. Docker Compose Admin
   -> levanta recoleccion_admin
   -> publica únicamente:
      192.168.30.20:8081
   -> conectado a:
      recoleccion-db-net
   -> utiliza MySQL compartido con Ciudadana/API
   -> NO crea una segunda instancia MySQL

### 9. Docker Compose Camiones
   -> levanta recoleccion_camiones
   -> publica únicamente:
      192.168.30.20:8082
   -> conectado a:
      recoleccion-db-net
   -> utiliza MySQL compartido con Ciudadana/API
   -> integrar autenticación y asignaciones propias de Camiones
   -> preservar almacenamiento compartido y evidencias de resolución

### 10. Verificar contenedores
   -> docker ps
   -> recoleccion_api
   -> recoleccion_admin
   -> recoleccion_db
   -> comprobar que los tres contenedores estén operativos

### 11. Verificar puertos locales
    -> curl -I http://192.168.30.20:8080
    -> curl -I http://192.168.30.20:8081
    -> curl -I http://192.168.30.20:8082
    -> las tres aplicaciones deben responder

### 12. Verificar red Docker
    -> docker network inspect recoleccion-db-net
    -> deben aparecer:
       recoleccion_api
       recoleccion_admin
       recoleccion_camiones
       recoleccion_db
    -> verificar conectividad entre aplicaciones y MySQL
    -> verificar que MySQL no publique TCP/3306


### 13. RL-APP-DB_Backup_and_Restore
   -> ubicación:
      Scripts/Linux/RL-APP-DB_Backup_and_Restore/
   -> requiere Docker y contenedor recoleccion_db operativo
   -> requiere almacenamiento persistente de fotografías disponible
   -> instala recoleccion-uy-backup.sh en /usr/local/sbin/
   -> instala recoleccion-uy-restore.sh en /usr/local/sbin/
   -> instala recoleccion-uy-backup.service en /etc/systemd/system/
   -> instala recoleccion-uy-backup.timer en /etc/systemd/system/
   -> recarga configuración de systemd
   -> habilita y activa el temporizador de respaldo automático
   -> realiza respaldo de base de datos MySQL recoleccion
   -> realiza respaldo de /srv/recoleccion-data/fotos/
   -> almacena respaldos en /var/backups/recoleccion-uy/
   -> genera archivos database.sql.gz, fotos.tar.gz y SHA256SUMS
   -> verifica ejecución del servicio de backup
   -> verifica programación del temporizador systemd
   -> verifica integridad de los archivos respaldados
   -> verifica disponibilidad del script de restauración
   -> permite restaurar MySQL y fotografías durante mantenimiento
   -> conserva copias de emergencia durante la restauración
   -> NO utiliza crontab
   -> NO modifica archivos de las aplicaciones Laravel
   -> NO realiza restauraciones destructivas automáticamente

### 14. config_ssh.sh
    -> configura acceso SSH seguro
    -> configura grupos y privilegios autorizados

### 15. config_ssh_users.sh
    -> configura claves públicas SSH para usuarios AD autorizados
    -> verificar acceso antes de cerrar la sesión actual

=================================================
## 7. RL-PROXY-01
=================================================

### 1. 1-RL-PROXY-update.sh
   -> verifica que el sistema operativo sea Rocky Linux
   -> actualiza Rocky Linux
   -> instala herramientas básicas del sistema
   -> instala complementos de DNF
   -> instala OpenSSH
   -> instala firewalld
   -> instala herramientas SELinux
   -> instala dependencias Active Directory / LDAP
   -> instala realmd / SSSD / Kerberos / oddjob
   -> configura repositorio oficial Docker CE
   -> instala Docker CE
   -> instala Docker Compose Plugin
   -> instala Containerd
   -> habilita Docker
   -> habilita Containerd
   -> habilita sshd
   -> habilita firewalld
   -> verifica paquetes y servicios instalados
   -> verifica funcionamiento de Docker Engine
   -> verifica estado de SELinux
   -> verifica necesidad de reiniciar por actualización del kernel
   -> NO configura redes Docker, proxy, AD, SSSD ni SSH

### 2. 2-RL-PROXY-config_domain_2dns_v1.3.sh
   -> verifica dependencias instaladas
   -> verifica interfaz de red ens33
   -> identifica perfil NetworkManager
   -> configura IP estática = 192.168.50.20/24
   -> configura gateway = 192.168.50.1
   -> configura DNS1 = 192.168.10.20 (WS-DC-01)
   -> configura DNS2 = 192.168.10.21 (WS-DC-02)
   -> deshabilita DNS automático
   -> deshabilita IPv6 en la interfaz
   -> aplica configuración de red
   -> verifica dirección IP configurada
   -> configura hostname = RL-PROXY-01
   -> configura /etc/hosts
   -> realiza respaldo de /etc/hosts
   -> verifica resolución DNS de neltek.uy
   -> verifica registros SRV LDAP de Active Directory
   -> comprueba si el servidor ya pertenece al dominio
   -> descubre dominio neltek.uy mediante realmd
   -> une RL-PROXY-01 al dominio neltek.uy si corresponde
   -> evita repetir realm join si ya pertenece al dominio
   -> verifica archivo /etc/sssd/sssd.conf
   -> realiza respaldo de configuración SSSD
   -> configura use_fully_qualified_names = False
   -> configura fallback_homedir = /home/%u
   -> habilita cache_credentials = True
   -> valida configuración mediante sssctl config-check
   -> habilita y reinicia SSSD
   -> habilita oddjobd
   -> configura creación automática de HOME mediante authselect
   -> verifica estado de SSSD y oddjobd
   -> verifica pertenencia al dominio mediante realm list
   -> verifica resolución DNS de WS-DC-01 y WS-DC-02
   -> NO configura usuarios SSH, grupos autorizados ni sudo

### 3. Verificar interfaz de DMZ
   -> interfaz = ens33
   -> red = 192.168.50.0/24
   -> IP = 192.168.50.20/24
   -> ip -br addr
   -> verificar configuración aplicada por NetworkManager
   -> una sola interfaz de red

### 4. Verificar gateway y routing mediante RL-FW-01
   -> gateway = 192.168.50.1
   -> ip route
   -> verificar ruta predeterminada mediante RL-FW-01
   -> comunicación con APLICACIONES a través de RL-FW-01
   -> verificar acceso a SERVICIOS mediante RL-FW-01
   -> no utilizar segunda interfaz Bridged
   -> no utilizar config_route_metrics.sh

### 5. Verificar acceso a aplicaciones antes de configurar proxy
   -> curl -I http://192.168.30.20:8080
   -> curl -I http://192.168.30.20:8081
   -> curl -I http://192.168.30.20:8082
   -> las tres aplicaciones deben responder a través de RL-FW-01

### 6. 3-RL-PROXY-config_proxy_http.sh
   -> verifica ejecución con privilegios root
   -> verifica dependencias necesarias
   -> verifica Docker Engine operativo
   -> verifica Docker Compose v2 disponible
   -> detecta interfaz que contiene 192.168.50.20/24
   -> verifica existencia de una única ruta default
   -> verifica gateway = 192.168.50.1
   -> verifica DNS de Active Directory
   -> verifica acceso TCP/53 a ambos DNS
   -> verifica resolución DNS de WS-DC-01 y WS-DC-02
   -> verifica routing hacia RL-APP-01 mediante RL-FW-01
   -> verifica conectividad con Ciudadana:
      192.168.30.20:8080
   -> verifica conectividad con Administrativo:
      192.168.30.20:8081

   -> PREPARACIÓN DEL PROXY
      -> crea/verifica /opt/recoleccion-proxy
      -> crea directorio nginx/conf.d
      -> crea directorio dnsmasq
      -> realiza respaldo de configuraciones existentes

   -> CONFIGURACIÓN NGINX
      -> configura Nginx Reverse Proxy en Docker
      -> crea nginx/conf.d/recoleccion.conf
      -> configura virtual host Ciudadana:
         recoleccion.neltek.uy
         -> 192.168.30.20:8080
      -> configura virtual host Administrativo:
         admin-recoleccion.neltek.uy
         -> 192.168.30.20:8081
      -> configura virtual host Camiones:
         camiones-recoleccion.neltek.uy
         -> 192.168.30.20:8082
      -> configura cabeceras HTTP de proxy
      -> configura límites y tiempos de conexión
      -> publica Nginx únicamente en 192.168.50.20:80

   -> CONFIGURACIÓN DNSMASQ
      -> crea dnsmasq/Dockerfile
      -> crea dnsmasq/dnsmasq.conf
      -> configura DNS upstream = 192.168.10.20
      -> configura DNS upstream = 192.168.10.21
      -> configura recoleccion.neltek.uy = 192.168.50.20
      -> configura admin-recoleccion.neltek.uy = 192.168.50.20
      -> configura camiones-recoleccion.neltek.uy = 192.168.50.20
      -> habilita caché DNS
      -> habilita registro de consultas DNS
      -> publica DNS en 192.168.50.20:53 TCP/UDP

   -> CONFIGURACIÓN DOCKER COMPOSE
      -> crea /opt/recoleccion-proxy/docker-compose.yml
      -> configura contenedor recoleccion_proxy
      -> configura contenedor recoleccion_dns
      -> establece restart: unless-stopped
      -> valida configuración mediante docker compose config

   -> CONFIGURACIÓN FIREWALLD
      -> identifica zona asociada a la interfaz DMZ
      -> habilita servicio HTTP en la zona detectada
      -> habilita servicio DNS en la zona detectada
      -> no cambia arbitrariamente la zona de la interfaz
      -> recarga firewalld antes de iniciar Docker

   -> PREPARACIÓN Y ARRANQUE
      -> descarga imagen Nginx
      -> construye imagen dnsmasq
      -> detiene contenedores anteriores del mismo Compose
      -> elimina contenedores huérfanos de ese proyecto
      -> inicia servicios mediante docker compose up -d
      -> recrea contenedores
      -> espera disponibilidad de recoleccion_proxy
      -> espera disponibilidad de recoleccion_dns

   -> VERIFICACIÓN
      -> verifica configuración Nginx mediante nginx -t
      -> verifica disponibilidad de 192.168.50.20:80
      -> verifica disponibilidad de 192.168.50.20:53/TCP
      -> verifica resolución DNS de los tres hostnames
      -> verifica reverse proxy Ciudadana
      -> verifica reverse proxy Administrativo
      -> verifica reverse proxy Camiones
      -> muestra estado final mediante docker compose ps
      -> NO configura NAT ni publicación directa hacia WAN

### 7. 4-RL-PROXY-install_WAF.sh
   -> instala e integra WAF ModSecurity / OWASP CRS
   -> incorpora inspección HTTP delante de Nginx interno
   -> configura los tres hosts: Ciudadana, Admin y Camiones
   -> verificar reglas y destino interno sin exponer directamente las aplicaciones

### 8. 5-RL-PROXY-generar_certificados_tls.sh
   -> genera el material TLS previsto para los tres nombres de servicio
   -> gestiona certificados y confianza local según el script
   -> proteger archivos privados y excluir secretos de la documentación

### 9. 6-RL-PROXY-migrar_waf_https.sh
   -> migra la publicación a WAF HTTPS en 192.168.50.20:443
   -> configura puerto TLS interno del WAF 8443
   -> conserva Nginx interno sin puertos publicados al host
   -> comprueba la configuración para los tres dominios
   -> cierra HTTP público en la configuración del proxy al completar la migración
   -> coordinar en RL-FW-01 la política WAN correspondiente

### 10. 7-RL-PROXY-FIX_nginx.sh
    -> aplica ajustes específicos de configuración Nginx del proxy
    -> ejecutar según la dependencia funcional documentada del WAF/TLS

### 11. Verificar contenedores
   -> docker ps
   -> recoleccion_proxy
   -> recoleccion_dns
   -> comprobar que ambos contenedores estén operativos

### 12. Verificar configuración Nginx
   -> docker exec recoleccion_proxy nginx -t
   -> comprobar virtual host Ciudadana
   -> comprobar virtual host Administrativo
   -> comprobar virtual host Camiones
   -> verificar destinos 192.168.30.20:8080, :8081 y :8082

### 13. Verificar DNS del proxy
    -> dig @192.168.50.20 recoleccion.neltek.uy
    -> dig @192.168.50.20 admin-recoleccion.neltek.uy
    -> dig @192.168.50.20 camiones-recoleccion.neltek.uy
    -> los tres nombres deben resolver a 192.168.50.20
    -> verificar reenvío DNS a WS-DC-01 / WS-DC-02

### 14. Verificar publicación HTTPS mediante Host
    -> curl -I https://recoleccion.neltek.uy
    -> curl -I https://admin-recoleccion.neltek.uy
    -> curl -I https://camiones-recoleccion.neltek.uy
    -> verificar certificado TLS y respuesta de cada aplicación

### 15. config_ssh.sh
    -> configura SSH seguro y privilegios de administración

### 16. config_ssh_users.sh
    -> configura claves SSH para administradores AD autorizados

=================================================
## 8. RL-MON-01 (MONITOREO)
=================================================

### 1. 1-RL-MON-update.sh
   -> prepara Rocky Linux 9 y los componentes de sistema necesarios
   -> instala dependencias de red, administración y servicios
   -> prepara Docker Engine y Docker Compose según el script

### 2. 2-RL-MON-config_domain_2dns_v1.3.sh
   -> configura ens33 = 192.168.20.20/24
   -> gateway = 192.168.20.1
   -> DNS = 192.168.10.20 / 192.168.10.21
   -> hostname = RL-MON-01
   -> incorpora neltek.uy mediante realmd y configura SSSD
   -> habilita oddjob y creación automática de HOME
   -> preserva una sola NIC y la ruta por RL-FW-01

### 3. Verificar conectividad del segmento MONITOREO
   -> red = 192.168.20.0/24
   -> IP = 192.168.20.20/24
   -> gateway = 192.168.20.1
   -> verificar DNS de controladores de dominio
   -> verificar reglas autorizadas con APLICACIONES y DMZ

### 4. 3-RL-MON-monitoreo.sh
   -> instala y configura Prometheus, Grafana y Node Exporter local
   -> construye el stack Docker Compose de monitoreo
   -> publica Grafana en 192.168.20.20:3000
   -> expone Prometheus en 127.0.0.1:9090
   -> configura targets de métricas para hosts del ecosistema
   -> mantiene componentes de monitoreo fuera de WAN

### 5. 4-RL-MON-OpenSearch.sh
   -> configura OpenSearch y OpenSearch Dashboards en Docker Compose
   -> incorpora Fluent Bit local para logs Docker de RL-MON-01
   -> publica OpenSearch en 192.168.20.20:9200
   -> utiliza OpenSearch Dashboards en el servidor de monitoreo
   -> configura persistencia y parámetros necesarios del host
   -> verificar controles de acceso y permisos SELinux

### 6. 5-RL-MON-Zabbix.sh
   -> comprueba las dependencias de Docker y Docker Compose
   -> prepara la base MySQL independiente de Zabbix
   -> despliega Zabbix Server y Zabbix Web
   -> publica Zabbix Server en 192.168.20.20:10051
   -> publica Zabbix Web en 192.168.20.20:8088
   -> verifica los servicios y las reglas locales correspondientes

### 7. RL-MON-add_dashboard_general.sh
   -> incorpora el dashboard general del ecosistema a Grafana
   -> utiliza métricas de los hosts y targets disponibles
   -> respetar las dependencias de Prometheus y Grafana

### 8. Verificar contenedores de monitoreo
   -> docker ps
   -> revisar servicios de Prometheus, Grafana, OpenSearch, Dashboards y Fluent Bit
   -> revisar contenedores de Zabbix Server, Zabbix Web y MySQL de Zabbix
   -> comprobar puertos dentro de MONITOREO y accesos autorizados
   -> no publicar interfaces de gestión hacia WAN

### 9. Verificar métricas y registros
   -> verificar targets de Prometheus y paneles de Grafana
   -> verificar OpenSearch, Dashboards y sus índices
   -> verificar disponibilidad de Zabbix Server y Zabbix Web
   -> verificar conectividad de agentes Windows tras su configuración
   -> comprobar recepción de datos y eventos en Zabbix
   -> distinguir servicio iniciado de recepción efectiva de datos y registros

### 10. 1-RL-XXX-config_ssh.sh
   -> configura administración SSH según origen y grupos de AD autorizados

### 11. 2-RL-XXX-config_ssh_users.sh
    -> configura claves públicas de administradores permitidos

=================================================
=================================================
## 9. DNS / PUBLICACIÓN DE APLICACIONES
=================================================

### 1. 6-DNS_RegistroA_RecoleccionUY_v1.3.ps1
   -> configura registros A recoleccion.neltek.uy
   -> configura registros A admin-recoleccion.neltek.uy
   -> configura registros A camiones-recoleccion.neltek.uy
   -> para clientes en DMZ o redes con ruta a DMZ:
      destino previsto = 192.168.50.20
   -> para clientes situados fuera de la red interna:
      definir DNS alcanzable y política de publicación

### 2. Verificar DNS en clientes
   -> nslookup recoleccion.neltek.uy
   -> nslookup admin-recoleccion.neltek.uy
   -> nslookup camiones-recoleccion.neltek.uy
   -> confirmar dirección adecuada según red de origen

### 3. Verificar WAN / RL-FW-01 / RL-PROXY-01
   -> verificar publicación HTTPS por TCP/443
   -> verificar DNAT hacia 192.168.50.20:443
   -> WAF termina TLS y reenvía al Nginx interno
   -> Nginx enruta por encabezado Host
   -> no exponer directamente 192.168.30.20:8080/8081/8082

### 4. Verificar acceso real a Ciudadana, Administrativo y Camiones
   -> https://recoleccion.neltek.uy
   -> https://admin-recoleccion.neltek.uy
   -> https://camiones-recoleccion.neltek.uy
   -> comprobar login y redirecciones de Laravel

### 5. Verificar seguridad de publicación
   -> confirmar la política de acceso WAN del Backend Administrativo
   -> verificar el certificado TLS configurado en el WAF
   -> comprobar que TCP/443 responde correctamente
   -> verificar que HTTP público no permanezca habilitado

=================================================
## 10. AGENTES DE MONITOREO E INTEGRACIÓN
=================================================

### 1. RL-APP-01: 5-RL-APP-install_node_exporter.sh
   -> instala y configura Node Exporter de APLICACIONES
   -> proporciona métricas de host para consultas desde RL-MON-01
   -> restringe acceso al origen de monitoreo autorizado

### 2. RL-APP-01: 6-RL-APP-install_fluent_bit.sh
   -> configura Fluent Bit para logs de los contenedores Docker
   -> dirige registros a OpenSearch 192.168.20.20:9200
   -> utiliza configuración de recolección específica del servidor

### 3. RL-PROXY-01: 8-RL-PROXY-install_node_exporter.sh
   -> instala y configura Node Exporter de DMZ
   -> permite métricas desde RL-MON-01 según reglas autorizadas

### 4. RL-PROXY-01: 9-RL-PROXY-install_fluent_bit.sh
   -> configura Fluent Bit en el host del proxy
   -> envía logs a OpenSearch en RL-MON-01 según configuración

### 5. RL-FW-01: 3-RL-FW-add_MON_AD.sh
   -> ajusta conectividad autorizada de monitoreo y Active Directory
   -> revisar el alcance exacto de las reglas antes de aplicar

### 6. Verificar métricas
   -> RL-MON-01 consulta los exporters habilitados
   -> Prometheus registra targets disponibles
   -> no publicar TCP/9100 hacia WAN

### 7. Verificar logs
   -> Fluent Bit comunica con OpenSearch
   -> comprobar índices diferenciados por origen
   -> revisar permisos, persistencia y retención
   
### 8. Integración Zabbix — RL-FW-01 / WS-DC-01 / WS-DC-02
   -> verificar Zabbix Server operativo en RL-MON-01
   -> ejecutar 4-RL-FW-add_Zabbix.sh en RL-FW-01
   -> verificar políticas TCP/10050 y TCP/10051
   -> ejecutar 7-WS-DC-Zabbix_Agent.ps1 en WS-DC-01
   -> ejecutar 7-WS-DC-Zabbix_Agent.ps1 en WS-DC-02
   -> importar WS-DC-01-zabbix-import.yaml en Zabbix Web
   -> importar WS-DC-02-zabbix-import.yaml en Zabbix Web
   -> verificar identificación individual de ambos controladores

### 9. Verificar monitoreo Zabbix
   -> comprobar disponibilidad de WS-DC-01 y WS-DC-02
   -> verificar conectividad TCP/10050 y TCP/10051
   -> verificar asociación con Windows by Zabbix agent
   -> comprobar recepción de métricas y eventos Windows
   -> revisar disponibilidad de datos y disparadores configurados
   -> comprobar acceso web desde estaciones autorizadas
   -> no exponer Zabbix Server ni Zabbix Web hacia WAN

=================================================
=================================================
## 11. VERIFICACIÓN FINAL DE TODOS LOS SERVIDORES
=================================================

### 1. Verificar VMware / redes
   -> NIC y MAC únicas
   -> SERVICIOS = 192.168.10.0/24
   -> MONITOREO = 192.168.20.0/24
   -> APLICACIONES = 192.168.30.0/24
   -> DMZ = 192.168.50.0/24

### 2. Verificar WS-DC-01 / WS-DC-02
   -> DNS = 192.168.10.20 / 192.168.10.21
   -> dominio neltek.uy operativo
   -> LDAP / Kerberos operativos
   -> replicación saludable
   -> servicio Zabbix Agent operativo en ambos controladores
   -> Hostname correcto para WS-DC-01 y WS-DC-02
   -> comunicación autorizada con Zabbix Server
   -> archivos YAML importados correctamente
   -> métricas y eventos Windows disponibles en Zabbix

### 3. Verificar RL-FW-01
   -> WAN y cuatro interfaces internas correctas
   -> routing / NAT / firewalld correctos
   -> acceso entre redes limitado a flujos previstos
   -> políticas Zabbix rec-zbx-mon-dc y rec-zbx-dc-mon configuradas
   -> flujos TCP/10050 y TCP/10051 autorizados según origen y destino
   -> comprobar comunicación efectiva entre RL-MON-01 y ambos controladores

### 4. Verificar RL-APP-01
   -> recoleccion_api = UP
   -> recoleccion_admin = UP
   -> recoleccion_camiones = UP
   -> recoleccion_db = UP
   -> API = 192.168.30.20:8080
   -> Admin = 192.168.30.20:8081
   -> Camiones = 192.168.30.20:8082
   -> MySQL sin publicación de TCP/3306
   -> red Docker = recoleccion-db-net
   -> módulo de backup y restore:
      RL-APP-DB_Backup_and_Restore
   -> servicio systemd de backup instalado
   -> temporizador systemd habilitado
   -> respaldo de MySQL generado correctamente
   -> respaldo de fotografías generado correctamente
   -> archivo SHA256SUMS disponible
   -> script de restore instalado y verificado
   -> respaldos almacenados en:
      /var/backups/recoleccion-uy/

### 5. Verificar RL-PROXY-01
   -> recoleccion_proxy = UP
   -> recoleccion_dns = UP
   -> recoleccion_waf = UP cuando está habilitado
   -> WAF HTTPS en 192.168.50.20:443 tras la migración TLS
   -> Nginx interno sirve los tres destinos sin publicación directa
   -> dnsmasq en 192.168.50.20:53 TCP/UDP
   -> Nginx enruta los tres hostnames

### 6. Verificar publicación
   -> recoleccion.neltek.uy
   -> admin-recoleccion.neltek.uy
   -> camiones-recoleccion.neltek.uy
   -> clientes resuelven los tres nombres según origen
   -> acceso WAN según política

### 7. Verificar RL-MON-01 cuando esté desplegado
   -> Prometheus y Grafana
   -> OpenSearch y Dashboards
   -> exporters y Fluent Bit
   -> Zabbix Server y Zabbix Web
   -> base MySQL independiente de Zabbix
   -> agentes WS-DC-01 y WS-DC-02 disponibles
   -> recepción de datos y eventos de ambos controladores
   -> puertos restringidos y datos persistentes

### 8. Verificar seguridad
   -> usuarios AD autorizados
   -> SSH administrable
   -> no publicar MySQL, exporters ni dashboards a WAN
   -> política definitiva de acceso Administrativo
   -> verificar publicación HTTPS y configuración TLS del WAF
   -> restringir Zabbix Web a estaciones administrativas autorizadas
   -> no publicar TCP/10050, TCP/10051 ni TCP/8088 hacia WAN
   -> verificar las políticas de comunicación entre MONITOREO y SERVICIOS