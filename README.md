# Recolección UY

**Sistema integral de gestión de denuncias relacionadas con la recolección de residuos.**

Recolección UY centraliza el registro y seguimiento de denuncias ciudadanas, la supervisión municipal y la ejecución de tareas por parte de los equipos de recolección. El ecosistema está formado por **tres aplicaciones Laravel independientes** que comparten una **base de datos MySQL 8.0**.

La infraestructura documentada utiliza servidores Windows Server para Active Directory y DNS, y servidores Rocky Linux para el firewall, las aplicaciones, el proxy inverso y el monitoreo. El proyecto declara que los componentes desplegados y los scripts de configuración han sido probados; este índice sirve como punto de acceso a su documentación técnica.

## Índice

- [Estado del proyecto](#estado-del-proyecto)
- [Documentación de servidores](#documentación-de-servidores)
- [Aplicaciones Laravel](#aplicaciones-laravel)
- [Scripts de infraestructura](#scripts-de-infraestructura)
- [Estructura del repositorio](#estructura-del-repositorio)

## Estado del proyecto

Documento transversal que reúne el estado funcional del ecosistema, el grado de implementación, las reglas de negocio, la infraestructura, la seguridad y las verificaciones documentadas. Se mantiene separado de la documentación técnica particular de servidores y aplicaciones.

[Recolección UY — Estado del proyecto y documentación técnica](<Estado del proyecto/Estado del Proyecto RecoleccionUY.md>)


## Documentación de servidores

Acceso directo a la documentación técnica de cada servidor. Los nombres de host se mantienen como están definidos en el proyecto.

| Servidor | Función | Documentación |
|---|---|---|
| **`WS-DC-01`** | Controlador de dominio principal · AD DS, DNS y DHCP | [Ver documentación](Documentacion/Servidores/Documentacion-Tecnica-WS-DC-01.md) |
| **`WS-DC-02`** | Controlador de dominio adicional · AD DS y DNS | [Ver documentación](Documentacion/Servidores/Documentacion-Tecnica-WS-DC-02.md) |
| **`RL-FW-01`** | Firewall y enrutamiento entre segmentos | [Ver documentación](Documentacion/Servidores/Documentacion-Tecnica-RL-FW-01.md) |
| **`RL-APP-01`** | Alojamiento de aplicaciones y servicios Docker | [Ver documentación](Documentacion/Servidores/Documentacion-Tecnica-RL-APP-01.md) |
| **`RL-PROXY-01`** | Proxy inverso Nginx, WAF y TLS | [Ver documentación](Documentacion/Servidores/Documentacion-Tecnica-RL-PROXY-01.md) |
| **`RL-MON-01`** | Métricas, paneles y centralización de registros | [Ver documentación](Documentacion/Servidores/Documentacion-Tecnica-RL-MON-01.md) |

## Aplicaciones Laravel

Cada aplicación tiene su propio código y documentación. **No se deben mezclar archivos entre proyectos**, aunque compartan la base de datos y ciertos recursos de infraestructura.

| Aplicación | Proyecto | Alcance | Documentación |
|---|---|---|---|
| **Aplicación Ciudadana** | `recoleccion-api` | Registro y autenticación, denuncias, fotografías, reclamos y API REST. | [Ver documentación](Documentacion/RecoleccionUY/Documentacion-Tecnica-recoleccion-api.md) |
| **Backend Administrativo** | `recoleccion-admin` | Autenticación LDAP, gestión de denuncias, flota, geografía y asignaciones. | [Ver documentación](Documentacion/RecoleccionUY/Documentacion-Tecnica-recoleccion-admin.md) |
| **Aplicación Camiones** | `recoleccion-camiones` | Tareas asignadas, gestión operativa y evidencias fotográficas. | [Ver documentación](Documentacion/RecoleccionUY/Documentacion-Tecnica-recoleccion-camiones.md) |

## Scripts de infraestructura

Los enlaces siguientes abren **carpetas**, de modo que GitHub muestre todos los scripts disponibles en ellas. No se reproducen aquí los nombres de los archivos, para que el listado permanezca actualizado cuando se agreguen nuevos scripts.

### Servidores Rocky Linux

| Servidor | Carpeta de scripts |
|---|---|
| **`RL-FW-01`** | [Abrir scripts de RL-FW-01](Scripts/Linux/RL-FW-01/) |
| **`RL-APP-01`** | [Abrir scripts de RL-APP-01](Scripts/Linux/RL-APP-01/) |
| **`RL-PROXY-01`** | [Abrir scripts de RL-PROXY-01](Scripts/Linux/RL-PROXY-01/) |
| **`RL-MON-01`** | [Abrir scripts de RL-MON-01](Scripts/Linux/RL-MON-01/) |

**Scripts comunes de Linux:** [Configuración SSH reutilizable (`RL-XXX-XX`)](Scripts/Linux/RL-XXX-XX/). Esta carpeta es una plantilla general, no un servidor adicional.

### Servidores Windows

| Servidor | Carpeta de scripts |
|---|---|
| **`WS-DC-01`** | [Abrir scripts de Windows Server](Scripts/Windows/Windows-Server-2012-R2/) |
| **`WS-DC-02`** | [Abrir scripts de Windows Server](Scripts/Windows/Windows-Server-2012-R2/) |

> **Importante:** en el material recibido, `WS-DC-01` y `WS-DC-02` **no tienen carpetas de scripts individuales**. Ambos enlaces llevan a la carpeta compartida `Scripts/Windows/Windows-Server-2012-R2/`, que contiene los scripts de configuración de AD, DNS y Windows Server. Revisar los requisitos de cada script antes de ejecutarlo en un controlador concreto.

**Herramientas adicionales de Windows:** [Scripts auxiliares del host (`CredSSP`)](Scripts/Windows/Windows/).

## Estructura del repositorio

Este `README.md` está preparado para situarse en la **raíz del repositorio**. Para que los enlaces funcionen, deben utilizarse exactamente los siguientes nombres:

```text
RecoleccionUY/
├── README.md
├── Estado-del-proyecto/
│   └── Estado-del-proyecto-RecoleccionUY.md
├── Documentacion/
│   ├── Servidores/
│   │   ├── Documentacion-Tecnica-RL-APP-01.md
│   │   ├── Documentacion-Tecnica-RL-FW-01.md
│   │   ├── Documentacion-Tecnica-RL-MON-01.md
│   │   ├── Documentacion-Tecnica-RL-PROXY-01.md
│   │   ├── Documentacion-Tecnica-WS-DC-01.md
│   │   └── Documentacion-Tecnica-WS-DC-02.md
│   └── RecoleccionUY/
│       ├── Documentacion-Tecnica-recoleccion-api.md
│       ├── Documentacion-Tecnica-recoleccion-admin.md
│       └── Documentacion-Tecnica-recoleccion-camiones.md
└── Scripts/
    ├── Linux/
    │   ├── RL-APP-01/
    │   ├── RL-FW-01/
    │   ├── RL-MON-01/
    │   ├── RL-PROXY-01/
    │   └── RL-XXX-XX/                 # Plantillas comunes
    └── Windows/
        ├── Windows-Server-2012-R2/   # Scripts compartidos por los DC
        └── Windows/                  # Utilidades del host
```