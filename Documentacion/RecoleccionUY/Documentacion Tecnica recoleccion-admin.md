# Documentación técnica normalizada — Backend Administrativo

**Proyecto:** `recoleccion-admin`  
**Fecha de creación:** 03/11/2026  
**Naturaleza:** documentación técnica descriptiva; no certifica despliegue operativo.


## Índice

- [1. Datos generales](#1-datos-generales)
  - [1.1. Responsabilidad y límites](#11-responsabilidad-y-límites)
- [2. Arquitectura y estructura](#2-arquitectura-y-estructura)
  - [2.1. Organización general](#21-organización-general)
  - [2.2. Inventario estructural](#22-inventario-estructural)
  - [2.3. Árbol completo de directorios y archivos](#23-árbol-completo-de-directorios-y-archivos)
  - [2.4. Archivos y responsabilidades principales](#24-archivos-y-responsabilidades-principales)
- [3. Funcionalidades implementadas](#3-funcionalidades-implementadas)
  - [3.1. Inicio de sesión y pertenencia a grupos de Active Directory](#31-inicio-de-sesión-y-pertenencia-a-grupos-de-active-directory)
  - [3.2. Autorización administrativa](#32-autorización-administrativa)
  - [3.3. Dashboard y métricas](#33-dashboard-y-métricas)
  - [3.4. Gestión y filtro de denuncias](#34-gestión-y-filtro-de-denuncias)
  - [3.5. Estados de denuncia y correcciones administrativas](#35-estados-de-denuncia-y-correcciones-administrativas)
  - [3.6. Asignación manual](#36-asignación-manual)
  - [3.7. Asignación automática y balanceo](#37-asignación-automática-y-balanceo)
  - [3.8. Resolución, verificación y cierre automático](#38-resolución-verificación-y-cierre-automático)
  - [3.9. Administración de municipios y barrios](#39-administración-de-municipios-y-barrios)
  - [3.10. Gestión de flota](#310-gestión-de-flota)
  - [3.11. Fotografías y evidencias](#311-fotografías-y-evidencias)
- [4. Rutas y controladores](#4-rutas-y-controladores)
  - [4.1. `routes/web.php`](#41-routeswebphp)
  - [4.2. Rutas API](#42-rutas-api)
  - [4.3. Controladores y métodos implementados](#43-controladores-y-métodos-implementados)
  - [4.4. Reglas de validación por Form Request](#44-reglas-de-validación-por-form-request)
  - [4.5. Reglas de validación por formulario](#45-reglas-de-validación-por-formulario)
    - [app/Http/Requests/Admin/AsignarDenunciaManualRequest.php](#apphttprequestsadminasignardenunciamanualrequestphp)
    - [app/Http/Requests/Admin/DenunciaIndexRequest.php](#apphttprequestsadmindenunciaindexrequestphp)
    - [app/Http/Requests/Admin/LoginRequest.php](#apphttprequestsadminloginrequestphp)
    - [app/Http/Requests/Admin/StoreBarrioRequest.php](#apphttprequestsadminstorebarriorequestphp)
    - [app/Http/Requests/Admin/StoreCamionRequest.php](#apphttprequestsadminstorecamionrequestphp)
    - [app/Http/Requests/Admin/StoreMunicipioRequest.php](#apphttprequestsadminstoremunicipiorequestphp)
    - [app/Http/Requests/Admin/UpdateBarrioRequest.php](#apphttprequestsadminupdatebarriorequestphp)
    - [app/Http/Requests/Admin/UpdateCamionRequest.php](#apphttprequestsadminupdatecamionrequestphp)
    - [app/Http/Requests/Admin/UpdateDenunciaAdminRequest.php](#apphttprequestsadminupdatedenunciaadminrequestphp)
    - [app/Http/Requests/Admin/UpdateDenunciaEstadoRequest.php](#apphttprequestsadminupdatedenunciaestadorequestphp)
    - [app/Http/Requests/Admin/UpdateMunicipioRequest.php](#apphttprequestsadminupdatemunicipiorequestphp)
- [5. Modelos y base de datos](#5-modelos-y-base-de-datos)
  - [5.1. Base de datos compartida](#51-base-de-datos-compartida)
    - [5.1.1. Administración de migraciones](#511-administración-de-migraciones)
    - [5.1.2. Procedimiento para modificar la estructura de la base de datos](#512-procedimiento-para-modificar-la-estructura-de-la-base-de-datos)
    - [5.1.3. Impacto entre aplicaciones](#513-impacto-entre-aplicaciones)
    - [5.1.4. Responsabilidad y control de cambios](#514-responsabilidad-y-control-de-cambios)
  - [5.2. Modelos Eloquent](#52-modelos-eloquent)
    - [`app/Models/Barrio.php`](#appmodelsbarriophp)
    - [`app/Models/Camion.php`](#appmodelscamionphp)
    - [`app/Models/CamionUser.php`](#appmodelscamionuserphp)
    - [`app/Models/Denuncia.php`](#appmodelsdenunciaphp)
    - [`app/Models/DenunciaCamion.php`](#appmodelsdenunciacamionphp)
    - [`app/Models/FotoDenuncia.php`](#appmodelsfotodenunciaphp)
    - [`app/Models/FotoResolucion.php`](#appmodelsfotoresolucionphp)
    - [`app/Models/Municipio.php`](#appmodelsmunicipiophp)
    - [`app/Models/Reclamacion.php`](#appmodelsreclamacionphp)
    - [`app/Models/User.php`](#appmodelsuserphp)
  - [5.3. Migraciones presentes en el proyecto](#53-migraciones-presentes-en-el-proyecto)
- [6. Autenticación y seguridad](#6-autenticación-y-seguridad)
- [7. Reglas de negocio y estados](#7-reglas-de-negocio-y-estados)
  - [7.1. Transiciones del estado global](#71-transiciones-del-estado-global)
  - [7.2. Estado operativo de la asignación](#72-estado-operativo-de-la-asignación)
  - [7.3. Selección y sustitución de camión](#73-selección-y-sustitución-de-camión)
  - [7.4. Resolución y finalización](#74-resolución-y-finalización)
    - [7.4.1. Plazo de finalización](#741-plazo-de-finalización)
    - [7.4.2. Comando de finalización automática](#742-comando-de-finalización-automática)
    - [7.4.3. Programación de la tarea](#743-programación-de-la-tarea)
    - [7.4.4. Dependencia del Scheduler](#744-dependencia-del-scheduler)
    - [7.4.5. Verificación operativa](#745-verificación-operativa)
  - [7.5. Protección concurrente](#75-protección-concurrente)
- [8. Interfaz, formularios y API](#8-interfaz-formularios-y-api)
  - [8.1. Pantallas Blade](#81-pantallas-blade)
  - [8.2. API](#82-api)
- [9. Fotografías y almacenamiento](#9-fotografías-y-almacenamiento)
- [10. Configuración y despliegue](#10-configuración-y-despliegue)
  - [10.1. Configuración Docker Compose](#101-configuración-docker-compose)
  - [10.2. Inicialización del contenedor y EntryPoint](#102-inicialización-del-contenedor-y-entrypoint)
    - [10.2.1. Preparación de directorios y permisos](#1021-preparación-de-directorios-y-permisos)
    - [10.2.2. Inicialización de APP_KEY](#1022-inicialización-de-app_key)
    - [10.2.3. Inicialización de Laravel Scheduler](#1023-inicialización-de-laravel-scheduler)
    - [10.2.4. Tareas programadas](#1024-tareas-programadas)
    - [10.2.5. Inicio de Apache](#1025-inicio-de-apache)
    - [10.2.6. Supervisión y finalización de procesos](#1026-supervisión-y-finalización-de-procesos)
    - [10.2.7. Migraciones y seeders](#1027-migraciones-y-seeders)
    - [10.2.8. Consideraciones operativas](#1028-consideraciones-operativas)
  - [10.3. Límites de comprobación](#103-límites-de-comprobación)
- [11. Diccionario técnico de archivos](#11-diccionario-técnico-de-archivos)
  - [11.1. Despliegue y raíz](#111-despliegue-y-raíz)
  - [11.2. Comandos](#112-comandos)
  - [11.3. Enumeraciones](#113-enumeraciones)
  - [11.4. Controladores](#114-controladores)
  - [11.5. Middleware](#115-middleware)
  - [11.6. Solicitudes y validaciones](#116-solicitudes-y-validaciones)
  - [11.7. Integración LDAP](#117-integración-ldap)
  - [11.8. Modelos](#118-modelos)
  - [11.9. Políticas de autorización](#119-políticas-de-autorización)
  - [11.10. Proveedores](#1110-proveedores)
  - [11.11. Reglas](#1111-reglas)
  - [11.12. Configuración Laravel](#1112-configuración-laravel)
  - [11.13. Recursos públicos](#1113-recursos-públicos)
  - [11.14. Vistas](#1114-vistas)
  - [11.15. Rutas](#1115-rutas)
- [12. Mantenimiento y diagnóstico](#12-mantenimiento-y-diagnóstico)
  - [12.1. Áreas críticas](#121-áreas-críticas)
  - [12.2. Inspecciones seguras](#122-inspecciones-seguras)
  - [12.3. Impacto de modificaciones](#123-impacto-de-modificaciones)
  - [12.4. Inconsistencia en la desasignación](#124-inconsistencia-en-la-desasignación)
  - [12.5. Diagnóstico y mantenimiento del Scheduler](#125-diagnóstico-y-mantenimiento-del-scheduler)
    - [12.5.1. Identificación del contenedor](#1251-identificación-del-contenedor)
    - [12.5.2. Verificación del proceso Scheduler](#1252-verificación-del-proceso-scheduler)
    - [12.5.3. Verificación de las tareas programadas](#1253-verificación-de-las-tareas-programadas)
    - [12.5.4. Revisión de registros](#1254-revisión-de-registros)
    - [12.5.5. Verificación del cierre automático](#1255-verificación-del-cierre-automático)
    - [12.5.6. Ejecución manual para diagnóstico](#1256-ejecución-manual-para-diagnóstico)
    - [12.5.7. Diagnóstico de tareas superpuestas](#1257-diagnóstico-de-tareas-superpuestas)
    - [12.5.8. Recuperación del servicio](#1258-recuperación-del-servicio)
    - [12.5.9. Validación posterior a la recuperación](#1259-validación-posterior-a-la-recuperación)
    - [12.5.10. Consideraciones operativas](#12510-consideraciones-operativas)
- [13. Anexos](#13-anexos)


---

## 1. Datos generales

**Finalidad:** Gestión administrativa de denuncias, estados, municipios, barrios, camiones, asignaciones, verificación de resoluciones, autenticación LDAP y tareas programadas.

**Proyecto independiente:** `recoleccion-admin`. Comparte la base de datos con las otras dos aplicaciones, pero mantiene controladores, modelos y configuración propios.

**Archivos identificados en el proyecto:** 71. Su descripción individual figura en la sección 11.

**Tecnologías observadas:** PHP 8.2, Laravel, Blade, MySQL, Apache y Docker Compose. Las versiones exactas de todos los componentes PHP deben confirmarse mediante el inventario de dependencias instalado; la estructura contiene la configuración necesaria para Laravel y PHP.

### 1.1. Responsabilidad y límites

Las operaciones se realizan exclusivamente mediante los componentes de este proyecto. Las tablas compartidas no convierten a los repositorios en una única aplicación. Las descripciones de integración se limitan a datos y servicios comunes.


---


## 2. Arquitectura y estructura

### 2.1. Organización general

La aplicación sigue el procesamiento Laravel: rutas → middleware → controladores → validaciones y autorización → modelos/servicios → vistas o respuestas HTTP.

### 2.2. Inventario estructural

| Área | Archivos |

|---|---:|

| Despliegue y raíz | 6 |

| Comandos | 1 |

| Enumeraciones | 2 |

| Controladores | 9 |

| Middleware | 1 |

| Solicitudes y validaciones | 11 |

| Integración LDAP | 1 |

| Modelos | 10 |

| Políticas de autorización | 4 |

| Proveedores | 1 |

| Reglas | 1 |

| Configuración Laravel | 7 |

| Recursos públicos | 1 |

| Vistas | 14 |

| Rutas | 2 |

### 2.3. Árbol completo de directorios y archivos

La estructura del proyecto se presenta a continuación, con sus directorios, subdirectorios y archivos. Las responsabilidades individuales se describen en el diccionario técnico de la sección 11.

```text
recoleccion-admin/
├── app/
│   ├── Console/
│   │   └── Commands/
│   │       └── FinalizarDenunciasVencidas.php
│   ├── Enums/
│   │   ├── AdminRole.php
│   │   └── DenunciaEstado.php
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Admin/
│   │   │   │   ├── AuthController.php
│   │   │   │   ├── BarrioController.php
│   │   │   │   ├── CamionController.php
│   │   │   │   ├── DashboardController.php
│   │   │   │   ├── DenunciaController.php
│   │   │   │   ├── FotoDenunciaController.php
│   │   │   │   ├── FotoResolucionController.php
│   │   │   │   └── MunicipioController.php
│   │   │   └── Controller.php
│   │   ├── Middleware/
│   │   │   └── EnsureBackendRole.php
│   │   └── Requests/
│   │       └── Admin/
│   │           ├── AsignarDenunciaManualRequest.php
│   │           ├── DenunciaIndexRequest.php
│   │           ├── LoginRequest.php
│   │           ├── StoreBarrioRequest.php
│   │           ├── StoreCamionRequest.php
│   │           ├── StoreMunicipioRequest.php
│   │           ├── UpdateBarrioRequest.php
│   │           ├── UpdateCamionRequest.php
│   │           ├── UpdateDenunciaAdminRequest.php
│   │           ├── UpdateDenunciaEstadoRequest.php
│   │           └── UpdateMunicipioRequest.php
│   ├── Ldap/
│   │   └── User.php
│   ├── Models/
│   │   ├── Barrio.php
│   │   ├── Camion.php
│   │   ├── CamionUser.php
│   │   ├── Denuncia.php
│   │   ├── DenunciaCamion.php
│   │   ├── FotoDenuncia.php
│   │   ├── FotoResolucion.php
│   │   ├── Municipio.php
│   │   ├── Reclamacion.php
│   │   └── User.php
│   ├── Policies/
│   │   ├── BarrioPolicy.php
│   │   ├── CamionPolicy.php
│   │   ├── DenunciaPolicy.php
│   │   └── MunicipioPolicy.php
│   ├── Providers/
│   │   └── AppServiceProvider.php
│   └── Rules/
│       └── StrongPassword.php
├── bootstrap/
│   ├── app.php
│   └── providers.php
├── config/
│   ├── admin.php
│   ├── app.php
│   ├── auth.php
│   ├── filesystems.php
│   └── ldap.php
├── public/
│   └── images/
│       └── bandera-uy.png
├── resources/
│   └── views/
│       ├── admin/
│       │   ├── auth/
│       │   │   └── login.blade.php
│       │   ├── barrios/
│       │   │   ├── edit.blade.php
│       │   │   └── index.blade.php
│       │   ├── camiones/
│       │   │   ├── create.blade.php
│       │   │   ├── edit.blade.php
│       │   │   ├── index.blade.php
│       │   │   └── show.blade.php
│       │   ├── denuncias/
│       │   │   ├── edit.blade.php
│       │   │   ├── index.blade.php
│       │   │   └── show.blade.php
│       │   ├── municipios/
│       │   │   ├── edit.blade.php
│       │   │   └── index.blade.php
│       │   └── dashboard.blade.php
│       └── layouts/
│           └── admin.blade.php
├── routes/
│   ├── console.php
│   └── web.php
├── .dockerignore
├── .env
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
└── laravel.conf
```

### 2.4. Archivos y responsabilidades principales

Los controladores implementan solicitudes HTTP; los Form Requests separan reglas de validación; los modelos encapsulan relaciones y comportamiento de dominio. La sección 11 aporta el diccionario exhaustivo por archivo.


---


## 3. Funcionalidades implementadas

### 3.1. Inicio de sesión y pertenencia a grupos de Active Directory

`Admin/AuthController` presenta el formulario `admin/auth/login.blade.php`, recibe credenciales `sAMAccountName` y autentica mediante LdapRecord. El usuario LDAP representado por `app/Ldap/User.php` no es el ciudadano representado por `app/Models/User.php`. `config/ldap.php`, `config/auth.php` y `config/admin.php` separan conexión, provider y grupos administrativos configurables.

Los grupos lógicos son lectores (`reader`), operadores (`operator`) y administradores (`admin`), modelados mediante `AdminRole`. El controlador evita dar pistas externas sobre si el usuario existe, si su clave es incorrecta o si no pertenece a un grupo admitido. El login está limitado a cinco intentos por minuto. Tras la autenticación se regenera la sesión; el cierre invalida la sesión y regenera el token CSRF.

### 3.2. Autorización administrativa

`EnsureBackendRole` comprueba que el usuario LDAP autenticado disponga de rol reconocido. Las `BarrioPolicy`, `CamionPolicy`, `DenunciaPolicy` y `MunicipioPolicy` establecen permisos concretos por entidad/operación; la visibilidad de controles en Blade no reemplaza las verificaciones del servidor. El rol lector consulta; el operador ejecuta las operaciones autorizadas; el administrador dispone de acciones de edición/corrección y eliminación conforme a las policies. La matriz definitiva depende del método de autorización correspondiente, no únicamente del nombre del rol.

### 3.3. Dashboard y métricas

`Admin/DashboardController::index()` construye el panel `admin/dashboard.blade.php`, con información sobre denuncias por estado, vehículos activos/inactivos, asignaciones y demanda operativa. El cálculo de carga debe considerar asignaciones realmente activas y no un campo histórico como criterio único de asignación.

### 3.4. Gestión y filtro de denuncias

`Admin/DenunciaController::index()` procesa filtros validados por `DenunciaIndexRequest`, y `show()` carga detalle, fotografías, reclamaciones y asignaciones. `edit()` y `update()` gestionan modificaciones de dirección, descripción y datos territoriales bajo `UpdateDenunciaAdminRequest`; al modificar barrio se debe derivar el municipio y considerar incompatibilidades con asignaciones existentes. `destroy()` realiza la supresión administrativa de la denuncia sujeta a permisos, relaciones y limpieza de fotografías. Las reclamaciones se muestran en el detalle, pero no se tratan como expedientes con estados propios si la estructura de datos no los contempla.

### 3.5. Estados de denuncia y correcciones administrativas

`Admin/DenunciaController::updateEstado()` aplica `UpdateDenunciaEstadoRequest` y las reglas de `DenunciaEstado`. Las transiciones ordinarias representadas en el enum son: `pendiente` → `en_proceso` o `rechazado`; `en_proceso` → `resuelto` o `rechazado`; `resuelto` → `finalizado` o `rechazado`; `reclamado` → `pendiente`, `en_proceso` o `rechazado`; `finalizado` → `rechazado`; `rechazado` sin transiciones normales. Los métodos `Denuncia::cambiarEstado()` y `cambiarEstadoAdministrativamente()` separan reglas ordinarias de correcciones excepcionales. La ruta de cambio genérico no debe interpretarse como permiso irrestricto para finalizar una resolución.

### 3.6. Asignación manual

`asignarManual()` valida la solicitud mediante `AsignarDenunciaManualRequest`. El camión elegido debe estar activo y pertenecer al municipio de la denuncia. Estas condiciones se imponen en el servidor, de modo que no pueden eludirse mediante cambios en HTML. La lógica `validarDenunciaAsignable()`, `validarCamionParaDenuncia()` y `reemplazarAsignacionActiva()` controla precondiciones, compatibilidad territorial y cierre de asignaciones anteriores. Las operaciones se realizan transaccionalmente y emplean bloqueos `lockForUpdate()` donde corresponda para evitar que dos operadores creen asignaciones incompatibles.

### 3.7. Asignación automática y balanceo

`asignarAutomatico()` busca camiones `activo` del mismo municipio, comprueba estados de la denuncia y contabiliza asignaciones activas (`pendiente`, `en_proceso`). El mecanismo prioriza el camión con menor carga de trabajo en lugar de asignar aleatoriamente. Una vez elegido, crea la nueva relación en `denuncia_camion` mediante la misma protección transaccional y comprobaciones de concurrencia. Las asignaciones anteriores activas se cierran de acuerdo con la regla de reemplazo.

### 3.8. Resolución, verificación y cierre automático

`verificarResolucion()` verifica las precondiciones para finalizar una denuncia resuelta, incluyendo estado global, evidencias/estado de asignación cuando corresponda y marca temporal `estado_cambiado_at`. El proyecto implementa también `FinalizarDenunciasVencidas`, firma `denuncias:finalizar-vencidas`, que procesa denuncias `resuelto` elegibles tras `Denuncia::HORAS_PARA_FINALIZAR = 1`. `routes/console.php` programa la ejecución cada minuto con `withoutOverlapping(5)`. Una ejecución del scheduler cada minuto **no** reduce el período de espera de una hora. El proceso de inicialización incorpora `schedule:work`; la ejecución en un entorno concreto se debe comprobar operativamente.

### 3.9. Administración de municipios y barrios

`MunicipioController` implementa listado, alta, edición, actualización y eliminación. El municipio no debe eliminarse cuando lo utilizan barrios, denuncias o camiones, de acuerdo con las restricciones de su controlador. `BarrioController` implementa las mismas operaciones, incluida asignación de municipio, y evita eliminar barrios utilizados por denuncias. Los `Store*Request` y `Update*Request` distinguen reglas de creación y edición, incluida unicidad donde corresponde.

### 3.10. Gestión de flota

`CamionController` administra matrícula, marca, modelo, municipio y estado operativo del camión; incluye listado filtrable, alta, detalle, edición, cambio de municipio y eliminación. Los estados `activo`/`inactivo` definen elegibilidad operativa. La propiedad `asignado` debe interpretarse atendiendo al cálculo actual basado en asignaciones activas de `denuncia_camion` y no suponer que la columna homónima representa por sí sola la carga vigente.

### 3.11. Fotografías y evidencias

`FotoDenunciaController::show()` distribuye las fotografías ciudadanas autorizadas; `FotoResolucionController::show()` presenta evidencias operativas de las asignaciones. El Backend utiliza discos privados configurados y debe conservar la relación correcta entre denuncia, asignación y foto. Las operaciones de supresión requieren coherencia entre registros y archivos persistentes.

---

## 4. Rutas y controladores

### 4.1. `routes/web.php`

| Método | URI declarada | Controlador | Acción |
|---|---|---|---|
| `GET` | `/admin/login` | `AuthController` | `showLogin()` |
| `POST` | `/admin/login` | `AuthController` | `login()` |
| `POST` | `/logout` | `AuthController` | `logout()` |
| `GET` | `/dashboard` | `DashboardController` | `index()` |
| `GET` | `/denuncias` | `DenunciaController` | `index()` |
| `GET` | `/denuncias/{denuncia}/fotos/{foto}` | `FotoDenunciaController` | `show()` |
| `GET` | `/denuncias/{denuncia}/asignaciones/{asignacion}/fotos/{foto}` | `FotoResolucionController` | `show()` |
| `GET` | `/denuncias/{denuncia}/edit` | `DenunciaController` | `edit()` |
| `PATCH` | `/denuncias/{denuncia}` | `DenunciaController` | `update()` |
| `DELETE` | `/denuncias/{denuncia}` | `DenunciaController` | `destroy()` |
| `GET` | `/denuncias/{denuncia}` | `DenunciaController` | `show()` |
| `PATCH` | `/denuncias/{denuncia}/estado` | `DenunciaController` | `updateEstado()` |
| `POST` | `/denuncias/{denuncia}/asignar-manual` | `DenunciaController` | `asignarManual()` |
| `POST` | `/denuncias/{denuncia}/asignar-automatico` | `DenunciaController` | `asignarAutomatico()` |
| `POST` | `/denuncias/{denuncia}/desasignar` | `DenunciaController` | `desasignar()` |
| `POST` | `/denuncias/{denuncia}/verificar-resolucion` | `DenunciaController` | `verificarResolucion()` |
| `PATCH` | `/barrios/{barrio}/municipio` | `BarrioController` | `asignarMunicipio()` |
| `PATCH` | `/camiones/{camion}/municipio` | `CamionController` | `asignarMunicipio()` |

Las rutas agrupadas bajo `prefix("admin")` tienen el prefijo `/admin`; los recursos `barrios`, `municipios` y `camiones` se declaran mediante `Route::resource()` y generan rutas adicionales.

### 4.2. Rutas API

Esta aplicación no define rutas API REST propias; su interacción HTTP se organiza en `routes/web.php`.

### 4.3. Controladores y métodos implementados

- **`app/Http/Controllers/Admin/AuthController.php`**: `showLogin()`, `login()`, `logout()`, `logoutFailedAuthorization()`, `throwAuthenticationError()`.

- **`app/Http/Controllers/Admin/BarrioController.php`**: `index()`, `store()`, `edit()`, `update()`, `asignarMunicipio()`, `destroy()`.

- **`app/Http/Controllers/Admin/CamionController.php`**: `index()`, `create()`, `store()`, `show()`, `edit()`, `update()`, `asignarMunicipio()`, `destroy()`.

- **`app/Http/Controllers/Admin/DashboardController.php`**: `index()`.

- **`app/Http/Controllers/Admin/DenunciaController.php`**: `index()`, `show()`, `edit()`, `update()`, `destroy()`, `asignarManual()`, `asignarAutomatico()`, `verificarResolucion()`, `updateEstado()`, `validarDenunciaAsignable()`, `validarCamionParaDenuncia()`, `reemplazarAsignacionActiva()`.

- **`app/Http/Controllers/Admin/FotoDenunciaController.php`**: `show()`.

- **`app/Http/Controllers/Admin/FotoResolucionController.php`**: `show()`.

- **`app/Http/Controllers/Admin/MunicipioController.php`**: `index()`, `store()`, `edit()`, `update()`, `destroy()`.

### 4.4. Reglas de validación por Form Request

- **`app/Http/Requests/Admin/AsignarDenunciaManualRequest.php`**: `camion_id`: `required`, `integer`, `exists:camiones,id`

- **`app/Http/Requests/Admin/DenunciaIndexRequest.php`**: `estado`: `nullable`; `buscar`: `nullable`, `integer`, `min:1`

- **`app/Http/Requests/Admin/LoginRequest.php`**: `username`: `required`, `string`, `max:100`; `password`: `required`, `string`, `max:255`

- **`app/Http/Requests/Admin/StoreBarrioRequest.php`**: `nombre`: `required`, `string`, `max:255`; `municipio_id`: `required`, `integer`, `exists:municipios,id`

- **`app/Http/Requests/Admin/StoreCamionRequest.php`**: `matricula`: `required`, `string`, `max:20`, `camiones`, `matricula`; `marca`: `required`, `string`, `max:100`; `modelo`: `required`, `string`, `max:100`; `estado_operativo`: `required`, `activo`, `inactivo`; `municipio_id`: `nullable`, `integer`, `exists:municipios,id`; `password`: `required`, `string`, `confirmed`, `max:255`

- **`app/Http/Requests/Admin/StoreMunicipioRequest.php`**: `nombre`: `required`, `string`, `max:255`, `municipios`, `nombre`

- **`app/Http/Requests/Admin/UpdateBarrioRequest.php`**: `nombre`: `required`, `string`, `max:255`, `barrios`, `nombre`, `municipio_id`

- **`app/Http/Requests/Admin/UpdateCamionRequest.php`**: `matricula`: `required`, `string`, `max:20`, `camiones`, `matricula`; `marca`: `required`, `string`, `max:100`; `modelo`: `required`, `string`, `max:100`; `estado_operativo`: `required`, `activo`, `inactivo`; `municipio_id`: `nullable`, `integer`, `exists:municipios,id`; `password`: `nullable`, `string`, `confirmed`, `max:255`

- **`app/Http/Requests/Admin/UpdateDenunciaAdminRequest.php`**: `direccion`: `required`, `string`, `max:255`; `barrio_id`: `required`, `integer`, `exists:barrios,id`; `descripcion`: `nullable`, `string`, `max:5000`

- **`app/Http/Requests/Admin/UpdateDenunciaEstadoRequest.php`**: `estado`: `required`

- **`app/Http/Requests/Admin/UpdateMunicipioRequest.php`**: `nombre`: `required`, `string`, `max:255`, `municipios`, `nombre`


---


### 4.5. Reglas de validación por formulario

Las siguientes reglas se transcriben de los métodos `rules()` vigentes y permiten identificar con precisión qué restricciones aplica el servidor. Los permisos adicionales pueden residir en `authorize()`, middleware o policies.

#### app/Http/Requests/Admin/AsignarDenunciaManualRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'camion_id' => [
                'required',
                'integer',
                'exists:camiones,id',
            ],
        ];
```

#### app/Http/Requests/Admin/DenunciaIndexRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'estado' => [
                'nullable',

                Rule::in(
                    DenunciaEstado::values()
                ),
            ],

            'buscar' => [
                'nullable',
                'integer',
                'min:1',
            ],
        ];
```

#### app/Http/Requests/Admin/LoginRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'username' => [
                'required',
                'string',
                'max:100',
            ],

            'password' => [
                'required',
                'string',
                'max:255',
            ],
        ];
```

#### app/Http/Requests/Admin/StoreBarrioRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'nombre' => [
                'required',
                'string',
                'max:255',
            ],

            'municipio_id' => [
                'required',
                'integer',
                'exists:municipios,id',
            ],
        ];
```

#### app/Http/Requests/Admin/StoreCamionRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'matricula' => [
                'required',
                'string',
                'max:20',

                Rule::unique(
                    'camiones',
                    'matricula'
                ),
            ],

            'marca' => [
                'required',
                'string',
                'max:100',
            ],

            'modelo' => [
                'required',
                'string',
                'max:100',
            ],

            'estado_operativo' => [
                'required',

                Rule::in([
                    'activo',
                    'inactivo',
                ]),
            ],

            'municipio_id' => [
                'nullable',
                'integer',
                'exists:municipios,id',
            ],

            /*
             * Credenciales iniciales del camión.
             *
             * La confirmación se envía mediante
             * password_confirmation y Laravel
             * comprueba que ambas coincidan.
             */
            'password' => [
                'required',
                'string',
                'confirmed',
                'max:255',
                new StrongPassword(),
            ],
        ];
```

#### app/Http/Requests/Admin/StoreMunicipioRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'nombre' => [
                'required',
                'string',
                'max:255',

                Rule::unique(
                    'municipios',
                    'nombre'
                ),
            ],
        ];
```

#### app/Http/Requests/Admin/UpdateBarrioRequest.php

Validación de entrada ejecutada por este Form Request:

```php
$barrio = $this->route('barrio');

        return [
            'nombre' => [
                'required',
                'string',
                'max:255',

                Rule::unique(
                    'barrios',
                    'nombre'
                )
                    ->where(
                        fn ($query) =>
                            $query->where(
                                'municipio_id',
                                $barrio->municipio_id
                            )
                    )
                    ->ignore($barrio->id),
            ],
        ];
```

#### app/Http/Requests/Admin/UpdateCamionRequest.php

Validación de entrada ejecutada por este Form Request:

```php
$camion =
            $this->route('camion');

        return [
            'matricula' => [
                'required',
                'string',
                'max:20',

                Rule::unique(
                    'camiones',
                    'matricula'
                )->ignore(
                    $camion->id
                ),
            ],

            'marca' => [
                'required',
                'string',
                'max:100',
            ],

            'modelo' => [
                'required',
                'string',
                'max:100',
            ],

            'estado_operativo' => [
                'required',

                Rule::in([
                    'activo',
                    'inactivo',
                ]),
            ],

            'municipio_id' => [
                'nullable',
                'integer',
                'exists:municipios,id',
            ],

            /*
             * La contraseña es opcional durante
             * la edición del camión.
             *
             * Si se completa, debe cumplir la misma
             * política que en el alta y confirmarse.
             */
            'password' => [
                'nullable',
                'string',
                'confirmed',
                'max:255',
                new StrongPassword(),
            ],
        ];
```

#### app/Http/Requests/Admin/UpdateDenunciaAdminRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'direccion' => [
                'required',
                'string',
                'max:255',
            ],

            'barrio_id' => [
                'required',
                'integer',
                'exists:barrios,id',
            ],

            'descripcion' => [
                'nullable',
                'string',
                'max:5000',
            ],
        ];
```

#### app/Http/Requests/Admin/UpdateDenunciaEstadoRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'estado' => [
                'required',

                Rule::in(
                    DenunciaEstado::values()
                ),
            ],
        ];
```

#### app/Http/Requests/Admin/UpdateMunicipioRequest.php

Validación de entrada ejecutada por este Form Request:

```php
$municipio = $this->route('municipio');

        return [
            'nombre' => [
                'required',
                'string',
                'max:255',

                Rule::unique(
                    'municipios',
                    'nombre'
                )->ignore(
                    $municipio->id
                ),
            ],
        ];
```

---

## 5. Modelos y base de datos

### 5.1. Base de datos compartida

El ecosistema Recolección UY está compuesto por tres aplicaciones Laravel independientes:

- **Aplicación Ciudadana (`recoleccion-api`):** permite registrar, consultar y gestionar las operaciones ciudadanas relacionadas con denuncias y reclamaciones.
- **Backend Administrativo (`recoleccion-admin`):** administra denuncias, reclamaciones, camiones, asignaciones y operaciones administrativas.
- **Aplicación Camiones (`recoleccion-camiones`):** permite a los camiones autenticados consultar y gestionar las tareas que tienen asignadas.

Las tres aplicaciones utilizan una única base de datos MySQL compartida.

Aunque cada aplicación dispone de sus propios modelos Eloquent, controladores, rutas y lógica de negocio, las operaciones realizadas sobre las tablas compartidas pueden afectar a las demás aplicaciones.

#### 5.1.1. Administración de migraciones

En la estructura actual del proyecto, las migraciones que definen el esquema de la base de datos compartida se encuentran en:

`recoleccion-api/database/migrations/`

Por lo tanto, la Aplicación Ciudadana constituye el origen actual de las migraciones utilizadas para definir las tablas compartidas.

Los proyectos `recoleccion-admin` y `recoleccion-camiones` no incluyen archivos de migraciones en los paquetes analizados. Ambos utilizan sus propios modelos Eloquent para acceder a las tablas existentes.

Esta organización debe conservarse mientras no se apruebe formalmente un cambio de arquitectura.

#### 5.1.2. Procedimiento para modificar la estructura de la base de datos

Antes de incorporar una migración que agregue, modifique o elimine tablas, columnas, índices, claves foráneas o restricciones, deberá realizarse el siguiente procedimiento:

1. Identificar las tablas y columnas afectadas.
2. Revisar los modelos Eloquent de las tres aplicaciones que utilizan dichas estructuras.
3. Identificar controladores, validaciones, consultas y relaciones dependientes.
4. Evaluar la compatibilidad de los cambios con las funcionalidades existentes.
5. Determinar si es necesario actualizar código en una o más aplicaciones.
6. Crear la migración correspondiente dentro de `recoleccion-api/database/migrations/`.
7. Verificar la migración y las aplicaciones afectadas en un entorno de pruebas.
8. Documentar los cambios realizados y sus dependencias antes de aplicarlos en producción.

No deberán crearse migraciones independientes en el Backend Administrativo o en la Aplicación Camiones para modificar el esquema compartido sin una decisión técnica documentada.

#### 5.1.3. Impacto entre aplicaciones

Cualquier modificación de las tablas compartidas deberá analizarse considerando las tres aplicaciones.

Un cambio implementado desde una aplicación puede requerir modificaciones en otras, aunque estas no participen directamente en el proceso que originó el cambio.

Especialmente, deberán verificarse:

- Relaciones y claves foráneas.
- Nombres y tipos de columnas.
- Estados de denuncias y asignaciones.
- Validaciones de datos.
- Consultas y operaciones de actualización.
- Compatibilidad de los modelos Eloquent.
- Integridad de los registros existentes.

La incorporación de nuevas columnas o tablas no implica necesariamente cambios en las tres aplicaciones, pero su impacto deberá evaluarse y documentarse.

#### 5.1.4. Responsabilidad y control de cambios

La ubicación actual de las migraciones en la Aplicación Ciudadana no implica que esta sea la única aplicación responsable de las operaciones sobre los datos.

Cada aplicación mantiene la responsabilidad sobre su propia lógica de negocio y las operaciones que ejecuta.

La administración del esquema compartido debe realizarse de manera coordinada para evitar incompatibilidades entre aplicaciones.

No deberán ejecutarse modificaciones estructurales directamente sobre la base de datos de producción sin verificar previamente su impacto y disponer de los mecanismos de respaldo y recuperación correspondientes.

### 5.2. Modelos Eloquent

#### `app/Models/Barrio.php`

Representa un barrio administrado por el Backend. Mantiene su asociación con un municipio y con las denuncias registradas en esa zona.

**Métodos/relaciones declarados:** `municipio()`, `denuncias()`.

**fillable:** `municipio_id`, `nombre`.

#### `app/Models/Camion.php`

Representa un camión disponible para realizar tareas de recolección. Mantiene información sobre su municipio, estado operativo y asignaciones.

**Métodos/relaciones declarados:** `municipio()`, `asignaciones()`, `usuario()`, `asignacionesActivas()`, `getAsignadoAttribute()`.

**table:** 'camiones'.

**fillable:** `matricula`, `marca`, `modelo`, `estado_operativo`, `municipio_id`.

#### `app/Models/CamionUser.php`

Representa las credenciales y la habilitación de acceso asociadas a un camión; proporciona la relación `camion()`.

**Métodos/relaciones declarados:** `camion()`.

**table:** 'camion_user'.

**hidden:** `password`, `remember_token`.

**guarded:** lista vacía (`[]`); revisar asignación de atributos junto con las validaciones y el controlador.

#### `app/Models/Denuncia.php`

Representa una denuncia desde el Backend Administrativo. Centraliza sus relaciones, estados y comportamiento necesario para controlar el proceso operativo.

**Métodos/relaciones declarados:** `estadoEnum()`, `estadoLabel()`, `puedeCambiarEstadoA()`, `cambiarEstado()`, `cambiarEstadoAdministrativamente()`, `puedeFinalizar()`, `minutosParaFinalizar()`, `horasParaFinalizar()`, `user()`, `barrio()`, `municipio()`, `fotos()`, `reclamaciones()`, `asignaciones()`.

**fillable:** `barrio_id`, `municipio_id`, `direccion`, `latitud`, `longitud`, `descripcion`.

**casts:** [         'estado_cambiado_at' => 'datetime',         'latitud' => 'decimal:8',         'longitud' => 'decimal:8',     ].

#### `app/Models/DenunciaCamion.php`

Representa una asignación entre una denuncia y un camión. Mantiene el estado particular de la tarea, independientemente del estado general de la denuncia.

**Métodos/relaciones declarados:** `denuncia()`, `camion()`, `fotos()`.

**table:** 'denuncia_camion'.

**fillable:** `comentario_cierre`.

#### `app/Models/FotoDenuncia.php`

Representa las fotografías originales cargadas por el ciudadano y asociadas a una denuncia.

**Métodos/relaciones declarados:** `denuncia()`.

**table:** 'fotos_denuncia'.

**guarded:** lista vacía (`[]`); revisar asignación de atributos junto con las validaciones y el controlador.

#### `app/Models/FotoResolucion.php`

Representa las fotografías aportadas como evidencia de que una tarea asignada fue realizada.

**Métodos/relaciones declarados:** `denunciaCamion()`.

**table:** 'fotos_resolucion'.

**guarded:** lista vacía (`[]`); revisar asignación de atributos junto con las validaciones y el controlador.

#### `app/Models/Municipio.php`

Representa un municipio y sus relaciones con barrios, denuncias y camiones.

**Métodos/relaciones declarados:** `barrios()`, `denuncias()`, `camiones()`.

**fillable:** `nombre`.

#### `app/Models/Reclamacion.php`

Representa las reclamaciones que un ciudadano ha realizado sobre una denuncia.

**Métodos/relaciones declarados:** `denuncia()`, `user()`.

**table:** 'reclamaciones'.

**guarded:** lista vacía (`[]`); revisar asignación de atributos junto con las validaciones y el controlador.

#### `app/Models/User.php`

Representa al ciudadano propietario de una denuncia cuando su información necesita ser consultada desde el Backend. No representa al usuario administrativo autenticado mediante LDAP.

**Métodos/relaciones declarados:** `denuncias()`, `reclamaciones()`.

**fillable:** `documento`, `name`, `email`, `telefono`.

### 5.3. Migraciones presentes en el proyecto

No se incluyen archivos `database/migrations` en el proyecto. La ausencia en el proyecto no prueba que la base de datos carezca de estas tablas.


---


## 6. Autenticación y seguridad

Autenticación LDAP/Active Directory mediante LdapRecord, con grupos administrativos configurados y roles `reader`, `operator` y `admin`. La entrada a rutas internas exige `auth` más `EnsureBackendRole`.

Las `Policies` implementan autorización por recurso; la ruta POST de login tiene `throttle:5,1`. La autorización concreta de cada acción depende de policy y controlador.


---


## 7. Reglas de negocio y estados

### 7.1. Transiciones del estado global

| Estado de origen | Destinos ordinarios definidos por el enum |
|---|---|
| `pendiente` | `en_proceso`, `rechazado` |
| `en_proceso` | `resuelto`, `rechazado` |
| `resuelto` | `finalizado`, `rechazado` |
| `reclamado` | `pendiente`, `en_proceso`, `rechazado` |
| `finalizado` | `rechazado` |
| `rechazado` | Ninguno |

La tabla representa la estructura de `DenunciaEstado::transicionesPermitidas()`. Los permisos efectivos pueden restringir aún más una transición según rol, acción y controlador. `Denuncia::cambiarEstado()` y `cambiarEstadoAdministrativamente()` no son equivalentes.

### 7.2. Estado operativo de la asignación

`denuncia_camion.estado_asignacion` usa `pendiente`, `en_proceso`, `resuelto` y `rechazado`. Este estado es independiente de `denuncias.estado`: una resolución operativa exige verificación o finalización global posterior. La carga de trabajo para elegir un camión considera las asignaciones `pendiente` y `en_proceso`.

### 7.3. Selección y sustitución de camión

Asignar requiere una denuncia admisible y un camión activo del mismo municipio. La selección automática prioriza menor cantidad de asignaciones activas. Se emplean transacciones y bloqueos, y se sustituye cualquier asignación activa previa conforme a `reemplazarAsignacionActiva()`. No usar `camiones.asignado` como sustituto de consultar las asignaciones existentes.

La desasignación administrativa se realiza mediante `DenunciaController::desasignar()`. Esta operación cambia las asignaciones activas a `rechazado`, conservando su historial y sin modificar el estado general de la denuncia. Posteriormente, la denuncia podrá asignarse nuevamente.

### 7.4. Resolución y finalización

El Backend Administrativo implementa un mecanismo de finalización automática de denuncias que permanecen en estado `resuelto` durante el plazo definido por la lógica de negocio.

El estado `resuelto` indica que el trabajo fue completado, mientras que `finalizado` representa el cierre global de la denuncia.

#### 7.4.1. Plazo de finalización

El plazo se encuentra definido en:

`app/Models/Denuncia.php`

Mediante la constante:

```php
public const HORAS_PARA_FINALIZAR = 1;
```

Esto establece un período de espera de una hora desde la marca temporal correspondiente al cambio de estado.

El método `puedeFinalizar()` verifica que:

1. La denuncia permanezca en estado `resuelto`.
2. Exista un valor válido en `estado_cambiado_at`.
3. Se haya cumplido el período establecido por `HORAS_PARA_FINALIZAR`.

#### 7.4.2. Comando de finalización automática

El comando está implementado en:

`app/Console/Commands/FinalizarDenunciasVencidas.php`

Su firma es:

```bash
php artisan denuncias:finalizar-vencidas
```

El comando selecciona las denuncias que cumplen las condiciones iniciales de finalización.

El procesamiento se realiza mediante `chunkById(100)`, permitiendo recorrer los registros en grupos de hasta 100 denuncias.

Para cada denuncia seleccionada, el procedimiento:

1. Inicia una transacción de base de datos.
2. Vuelve a consultar el registro utilizando `lockForUpdate()`.
3. Comprueba que la denuncia continúe en estado `resuelto`.
4. Revalida las condiciones mediante `puedeFinalizar()`.
5. Cambia su estado a `finalizado` cuando corresponde.
6. Confirma la transacción.

Este mecanismo reduce el riesgo de conflictos con operaciones administrativas concurrentes.

Al finalizar, el comando informa la cantidad de denuncias que cambiaron automáticamente de estado.

#### 7.4.3. Programación de la tarea

El archivo:

`routes/console.php`

contiene la siguiente configuración:

```php
Schedule::command(
    'denuncias:finalizar-vencidas'
)
    ->everyMinute()
    ->withoutOverlapping(5);
```

La programación permite evaluar cada minuto las denuncias pendientes de finalización.

El método `withoutOverlapping(5)` utiliza un bloqueo para evitar ejecuciones simultáneas de la misma tarea, con un vencimiento de cinco minutos.

Este valor no representa el plazo para finalizar denuncias, sino la duración máxima configurada para el bloqueo del Scheduler.

El período de espera efectivo para finalizar una denuncia sigue siendo una hora.

#### 7.4.4. Dependencia del Scheduler

La ejecución periódica depende del proceso:

```bash
php artisan schedule:work
```

Este proceso es iniciado desde `entrypoint.sh` durante el arranque del contenedor del Backend Administrativo.

El Scheduler se ejecuta bajo el usuario `www-data`.

No se requiere un cron externo para esta tarea en la configuración actual.

Si el Scheduler no se encuentra en funcionamiento, las denuncias elegibles pueden permanecer en estado `resuelto` hasta que vuelva a ejecutarse correctamente el comando.

Cuando el servicio se restablezca, una ejecución posterior podrá procesar las denuncias que continúen cumpliendo las condiciones.

#### 7.4.5. Verificación operativa

El procedimiento de inspección, diagnóstico y recuperación del Scheduler se describe en:

**12.5. Diagnóstico y mantenimiento del Scheduler.**

La verificación deberá comprobar tanto la disponibilidad del proceso como la programación de la tarea y el resultado de su ejecución.

La presencia del proceso `schedule:work` no demuestra por sí sola que el comando haya modificado correctamente los registros de la base de datos.

### 7.5. Protección concurrente

Las operaciones de asignación, cambio de estado y finalización que alteran varias relaciones usan transacciones y, cuando corresponda, `lockForUpdate()` para serializar lecturas y escrituras críticas. Las políticas de permisos y validaciones se comprueban en servidor.

---

## 8. Interfaz, formularios y API

### 8.1. Pantallas Blade

La aplicación contiene 14 vistas, detalladas una por una en el diccionario.

### 8.2. API

La aplicación expone sus operaciones funcionales mediante `routes/web.php`; no se define aquí un contrato REST público independiente.


---


## 9. Fotografías y almacenamiento

El backend consulta fotografías de denuncias y resoluciones mediante controladores separados. Monta `/srv/recoleccion-data/fotos` en `/var/www/shared-denuncias`. El acceso está sujeto a controles administrativos y relaciones entre denuncia, asignación y fotografía.


---


## 10. Configuración y despliegue

### 10.1. Configuración Docker Compose

- `container_name`: `recoleccion_admin`.
- `APP_URL`: `http://admin-recoleccion.neltek.uy`.
- `DB_HOST`: `recoleccion_db`.
- `DB_PORT`: `3306`.
- `DB_DATABASE`: `recoleccion`.
- `DENUNCIAS_PRIVATE_ROOT`: `/var/www/shared-denuncias`.
- Publicación/montaje: `192.168.30.20:8081:8081`.
- Publicación/montaje: `/srv/recoleccion-data/fotos:/var/www/shared-denuncias:rw,z`.

### 10.2. Inicialización del contenedor y EntryPoint

El Backend Administrativo utiliza un contenedor Docker basado en PHP 8.2 y Apache, cuya inicialización está definida en los archivos:

- `Dockerfile`
- `docker-compose.yml`
- `entrypoint.sh`
- `laravel.conf`

El Dockerfile instala las extensiones PHP utilizadas por Laravel, incluyendo soporte LDAP, incorpora Composer y configura Apache para escuchar en el puerto 8081.

La instrucción `ENTRYPOINT ["entrypoint.sh"]` establece el script responsable de inicializar el contenedor.

La instrucción `CMD ["apache2-foreground"]` define el comando que inicia Apache.

A diferencia de la Aplicación Ciudadana, el Backend Administrativo también inicia un proceso permanente de Laravel Scheduler.

#### 10.2.1. Preparación de directorios y permisos

El EntryPoint utiliza `set -e` y comienza creando los directorios necesarios para el funcionamiento de Laravel:

```bash
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/bootstrap/cache
```

Posteriormente establece al usuario `www-data` como propietario de los directorios `storage` y `bootstrap/cache`.

A continuación asigna:

- Permisos `775` a los directorios.
- Permisos `664` a los archivos.

Estas operaciones permiten que los procesos PHP ejecutados por Apache puedan utilizar los directorios de almacenamiento, sesiones, vistas compiladas, registros y caché.

#### 10.2.2. Inicialización de APP_KEY

El script comprueba si la variable de entorno `APP_KEY` está vacía.

Cuando no contiene un valor, ejecuta:

```bash
export APP_KEY=$(php artisan key:generate --show)
```

La clave generada se incorpora al entorno del proceso.

El EntryPoint informa que se generó una clave, pero no imprime su contenido.

Esta generación se realiza únicamente cuando la variable está vacía y no garantiza, por sí sola, la persistencia de la clave entre recreaciones.

En el entorno de producción deberá mantenerse una `APP_KEY` persistente y gestionada de manera segura.

#### 10.2.3. Inicialización de Laravel Scheduler

Una vez preparados los permisos y la clave, el EntryPoint inicia el programador de tareas de Laravel mediante:

```bash
su -s /bin/sh www-data -c \
    "cd /var/www/html && php artisan schedule:work" &
```

El Scheduler se ejecuta como el usuario `www-data` y permanece funcionando en segundo plano.

Esta configuración permite ejecutar las tareas programadas sin depender de un cron externo al contenedor.

La ejecución como `www-data` evita que las tareas del Scheduler generen archivos pertenecientes al usuario root en los directorios utilizados por Laravel.

Después de iniciarlo, el script almacena su identificador de proceso:

```bash
SCHEDULER_PID=$!
```

#### 10.2.4. Tareas programadas

El archivo:

`routes/console.php`

registra el comando:

```php
Schedule::command(
    'denuncias:finalizar-vencidas'
)
    ->everyMinute()
    ->withoutOverlapping(5);
```

La configuración indica que Laravel debe evaluar la ejecución del comando cada minuto.

El método `withoutOverlapping(5)` establece un mecanismo para evitar ejecuciones simultáneas de la tarea mediante un bloqueo con vencimiento de cinco minutos.

El comando está implementado en:

`app/Console/Commands/FinalizarDenunciasVencidas.php`

Su responsabilidad es gestionar la finalización automática de denuncias que cumplen las condiciones definidas por las reglas de negocio.

La programación cada minuto no significa necesariamente que existan denuncias para modificar en cada ejecución.

El resultado depende de las condiciones evaluadas por el propio comando y del estado de la base de datos.

#### 10.2.5. Inicio de Apache

Una vez iniciado el Scheduler, el EntryPoint ejecuta el comando recibido:

```bash
"$@" &
```

El comando corresponde a:

```bash
apache2-foreground
```

Apache se inicia en segundo plano desde el punto de vista del script de inicialización.

Su identificador de proceso se conserva mediante:

```bash
APP_PID=$!
```

A partir de este momento, el contenedor mantiene dos procesos principales administrados por el EntryPoint:

1. Laravel Scheduler.
2. Apache.

Apache atiende las solicitudes web del Backend Administrativo en el puerto 8081 del contenedor.

#### 10.2.6. Supervisión y finalización de procesos

El EntryPoint define una función denominada `terminate`, encargada de enviar la señal `TERM` a los identificadores de proceso almacenados para el Scheduler y Apache.

También registra:

```bash
trap terminate TERM INT
```

Esto permite iniciar la finalización de los procesos cuando el script recibe señales de terminación o interrupción.

Posteriormente utiliza:

```bash
wait -n \
    "$SCHEDULER_PID" \
    "$APP_PID"
```

El script espera a que termine cualquiera de los dos procesos.

Cuando uno finaliza, el EntryPoint obtiene su código de salida, solicita la terminación de ambos procesos, espera su finalización y termina con el estado capturado.

Este mecanismo hace que el ciclo de vida del contenedor dependa de los dos procesos.

La implementación envía señales a los PID registrados. No debe interpretarse como una garantía de terminación completa de todos los procesos descendientes sin una comprobación adicional.

#### 10.2.7. Migraciones y seeders

El EntryPoint del Backend Administrativo no ejecuta:

```bash
php artisan migrate --force
```

ni:

```bash
php artisan db:seed --force
```

El Backend Administrativo utiliza la estructura MySQL compartida con las otras aplicaciones.

Las migraciones del esquema compartido se encuentran actualmente en la Aplicación Ciudadana.

Por lo tanto, el Backend depende de que la base de datos presente una estructura compatible con sus modelos, consultas y reglas de negocio.

#### 10.2.8. Consideraciones operativas

El orden de inicialización actual es:

1. Crear los directorios necesarios para Laravel.
2. Establecer propietarios y permisos.
3. Generar `APP_KEY` cuando no existe.
4. Iniciar Laravel Scheduler como `www-data`.
5. Iniciar Apache.
6. Supervisar la finalización de los dos procesos.
7. Ejecutar el procedimiento de terminación cuando corresponda.

El funcionamiento del cierre automático de denuncias depende de que el Scheduler permanezca activo.

Si el Scheduler deja de funcionar, la tarea programada no continuará ejecutándose normalmente dentro de ese contenedor.

El comportamiento descrito corresponde a la implementación incluida en `entrypoint.sh`, `Dockerfile` y `routes/console.php`.

### 10.3. Límites de comprobación

Los datos anteriores son configuración declarada en archivos; no constituyen comprobación de contenedores activos, acceso HTTPS público ni conectividad efectiva. Los archivos `.env` no se reproducen por contener parámetros sensibles.


---


## 11. Diccionario técnico de archivos

El siguiente diccionario enumera **todos los archivos de esta aplicación**, sin mezclar archivos de los otros proyectos. Las descripciones representan la responsabilidad identificable por el código y la estructura del proyecto.

### 11.1. Despliegue y raíz

| Archivo | Responsabilidad |

|---|---|

| `.dockerignore` | Excluye archivos innecesarios o sensibles durante la construcción de la imagen Docker. |

| `.env` | Contiene la configuración propia del entorno donde se ejecuta el Backend. No debe almacenarse con contraseñas o secretos reales. |

| `docker-compose.yml` | Define el servicio del Backend y su integración con la base de datos y el almacenamiento privado compartido. |

| `Dockerfile` | Define el entorno PHP y Apache utilizado para ejecutar el Backend Administrativo dentro de Docker. |

| `entrypoint.sh` | Prepara Laravel cuando inicia el contenedor y pone en funcionamiento los procesos necesarios para el Backend. |

| `laravel.conf` | Configura Apache para publicar el Backend desde el directorio `public` de Laravel. |

### 11.2. Comandos

| Archivo | Responsabilidad |

|---|---|

| `app/Console/Commands/FinalizarDenunciasVencidas.php` | Busca denuncias resueltas que ya cumplieron el plazo previsto y las cambia automáticamente a finalizadas. Evita que esa actualización dependa de una intervención manual. |

### 11.3. Enumeraciones

| Archivo | Responsabilidad |

|---|---|

| `app/Enums/AdminRole.php` | Define los roles administrativos reconocidos por el Backend y centraliza las diferencias generales de permisos entre ellos. |

| `app/Enums/DenunciaEstado.php` | Define los estados válidos de las denuncias y las transiciones utilizadas por el flujo administrativo. |

### 11.4. Controladores

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Controllers/Admin/AuthController.php` | Autentica usuarios administrativos contra Active Directory y crea la sesión utilizada por el Backend. También gestiona el cierre de sesión. |

| `app/Http/Controllers/Admin/BarrioController.php` | Gestiona el catálogo de barrios. Permite crear, renombrar, asignar un municipio y eliminar barrios cuando sus relaciones existentes lo permiten. |

| `app/Http/Controllers/Admin/CamionController.php` | Gestiona el catálogo de camiones. Permite listarlos, filtrarlos, crearlos, modificarlos, consultar su historial de asignaciones y relacionarlos con municipios. |

| `app/Http/Controllers/Admin/DashboardController.php` | Calcula los indicadores mostrados en el panel administrativo. Incluye cantidades de denuncias por estado, camiones activos o inactivos, camiones asignados y denuncias pendientes de asignación. |

| `app/Http/Controllers/Admin/DenunciaController.php` | Concentra las principales operaciones administrativas sobre denuncias. Permite buscar y filtrar denuncias, visualizar su detalle, modificar datos, cambiar estados, realizar asignaciones manuales o automáticas, verificar resoluciones y eliminar denuncias cuando el rol lo permite. |

| `app/Http/Controllers/Admin/FotoDenunciaController.php` | Entrega al Backend las fotografías privadas de una denuncia después de comprobar la autorización del usuario administrativo. |

| `app/Http/Controllers/Admin/FotoResolucionController.php` | Controlador que implementa las acciones del módulo FotoResolucion; recibe solicitudes, aplica comprobaciones y coordina modelos y respuestas. |

| `app/Http/Controllers/Admin/MunicipioController.php` | Gestiona el catálogo de municipios. Permite crearlos, renombrarlos y eliminarlos cuando no existen barrios, denuncias o camiones asociados. |

| `app/Http/Controllers/Controller.php` | Controlador que implementa las acciones del módulo ; recibe solicitudes, aplica comprobaciones y coordina modelos y respuestas. |

### 11.5. Middleware

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Middleware/EnsureBackendRole.php` | Comprueba que el usuario autenticado posea uno de los roles autorizados antes de permitir el acceso a determinadas rutas del Backend. |

### 11.6. Solicitudes y validaciones

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Requests/Admin/AsignarDenunciaManualRequest.php` | Comprueba los datos utilizados para asignar manualmente una denuncia a un camión. |

| `app/Http/Requests/Admin/DenunciaIndexRequest.php` | Valida los criterios utilizados para filtrar y buscar denuncias en el listado administrativo. |

| `app/Http/Requests/Admin/LoginRequest.php` | Valida los datos necesarios antes de intentar autenticar un usuario contra Active Directory. |

| `app/Http/Requests/Admin/StoreBarrioRequest.php` | Valida el nombre y los datos necesarios para registrar un barrio. |

| `app/Http/Requests/Admin/StoreCamionRequest.php` | Valida los datos necesarios para registrar un nuevo camión. |

| `app/Http/Requests/Admin/StoreMunicipioRequest.php` | Valida los datos necesarios para registrar un municipio. |

| `app/Http/Requests/Admin/UpdateBarrioRequest.php` | Valida las modificaciones permitidas sobre un barrio existente. |

| `app/Http/Requests/Admin/UpdateCamionRequest.php` | Valida los cambios permitidos sobre un camión existente. |

| `app/Http/Requests/Admin/UpdateDenunciaAdminRequest.php` | Valida las modificaciones directas que un administrador puede realizar sobre los datos de una denuncia. |

| `app/Http/Requests/Admin/UpdateDenunciaEstadoRequest.php` | Valida el nuevo estado solicitado para una denuncia antes de ejecutar el cambio. |

| `app/Http/Requests/Admin/UpdateMunicipioRequest.php` | Valida las modificaciones permitidas sobre un municipio existente. |

### 11.7. Integración LDAP

| Archivo | Responsabilidad |

|---|---|

| `app/Ldap/User.php` | Representa al usuario administrativo obtenido desde Active Directory. Además de los datos LDAP, determina el rol de Backend correspondiente según los grupos a los que pertenece el usuario. |

### 11.8. Modelos

| Archivo | Responsabilidad |

|---|---|

| `app/Models/Barrio.php` | Representa un barrio administrado por el Backend. Mantiene su asociación con un municipio y con las denuncias registradas en esa zona. |

| `app/Models/Camion.php` | Representa un camión disponible para realizar tareas de recolección. Mantiene información sobre su municipio, estado operativo y asignaciones. |

| `app/Models/CamionUser.php` | Representa las credenciales y la habilitación de acceso asociadas a un camión; proporciona la relación `camion()`. |

| `app/Models/Denuncia.php` | Representa una denuncia desde el Backend Administrativo. Centraliza sus relaciones, estados y comportamiento necesario para controlar el proceso operativo. |

| `app/Models/DenunciaCamion.php` | Representa una asignación entre una denuncia y un camión. Mantiene el estado particular de la tarea, independientemente del estado general de la denuncia. |

| `app/Models/FotoDenuncia.php` | Representa las fotografías originales cargadas por el ciudadano y asociadas a una denuncia. |

| `app/Models/FotoResolucion.php` | Representa las fotografías aportadas como evidencia de que una tarea asignada fue realizada. |

| `app/Models/Municipio.php` | Representa un municipio y sus relaciones con barrios, denuncias y camiones. |

| `app/Models/Reclamacion.php` | Representa las reclamaciones que un ciudadano ha realizado sobre una denuncia. |

| `app/Models/User.php` | Representa al ciudadano propietario de una denuncia cuando su información necesita ser consultada desde el Backend. No representa al usuario administrativo autenticado mediante LDAP. |

### 11.9. Políticas de autorización

| Archivo | Responsabilidad |

|---|---|

| `app/Policies/BarrioPolicy.php` | Controla los permisos necesarios para crear, modificar, asignar municipios o eliminar barrios. |

| `app/Policies/CamionPolicy.php` | Define qué usuarios pueden consultar o modificar la información relacionada con camiones. |

| `app/Policies/DenunciaPolicy.php` | Define qué acciones sobre denuncias puede ejecutar cada rol administrativo. Se utiliza para diferenciar operaciones de consulta, operación y administración. |

| `app/Policies/MunicipioPolicy.php` | Controla qué roles pueden crear, modificar o eliminar municipios. |

### 11.10. Proveedores

| Archivo | Responsabilidad |

|---|---|

| `app/Providers/AppServiceProvider.php` | Proveedor para registrar configuraciones y vínculos de servicios de Laravel. |

### 11.11. Reglas

| Archivo | Responsabilidad |

|---|---|

| `app/Rules/StrongPassword.php` | Archivo propio de la aplicación; revisar contenido para comportamiento preciso. |

### 11.12. Configuración Laravel

| Archivo | Responsabilidad |

|---|---|

| `bootstrap/app.php` | Configura el arranque del Backend y registra sus rutas, middleware y comportamiento general. |

| `bootstrap/providers.php` | Lista de proveedores de la aplicación. |

| `config/admin.php` | Centraliza parámetros propios del Backend relacionados con los roles administrativos y su integración con Active Directory. |

| `config/app.php` | Contiene la configuración general de Laravel utilizada por el Backend Administrativo. |

| `config/auth.php` | Define cómo Laravel autentica a los usuarios administrativos. |

| `config/filesystems.php` | Define el acceso del Backend al almacenamiento privado donde se encuentran las fotografías de denuncias. |

| `config/ldap.php` | Configura LdapRecord y la conexión utilizada para consultar usuarios y grupos de Active Directory. |

### 11.13. Recursos públicos

| Archivo | Responsabilidad |

|---|---|

| `public/images/bandera-uy.png` | Recurso gráfico de la interfaz. |

### 11.14. Vistas

| Archivo | Responsabilidad |

|---|---|

| `resources/views/admin/auth/login.blade.php` | Presenta el formulario utilizado por los usuarios administrativos para autenticarse contra Active Directory. |

| `resources/views/admin/barrios/edit.blade.php` | Permite modificar el nombre de un barrio existente. La relación territorial con el municipio se administra desde el listado principal de barrios. |

| `resources/views/admin/barrios/index.blade.php` | Centraliza la administración de barrios. Permite crear nuevos barrios, consultar su municipio y cantidad de denuncias, reasignarlos a otro municipio y acceder a su edición o eliminación según permisos. |

| `resources/views/admin/camiones/create.blade.php` | Recopila los datos necesarios para registrar un nuevo camión y asociarlo a la estructura territorial correspondiente. |

| `resources/views/admin/camiones/edit.blade.php` | Permite modificar los datos de identificación, estado operativo y demás información editable de un camión existente. |

| `resources/views/admin/camiones/index.blade.php` | Presenta el catálogo de camiones y permite consultar su situación operativa. Desde esta pantalla se accede a las operaciones habilitadas de creación, edición y consulta. |

| `resources/views/admin/camiones/show.blade.php` | Presenta el detalle del camión, incluyendo matrícula, marca, modelo, estado operativo, municipio y situación de asignación. También muestra el historial de denuncias que fueron asignadas al vehículo. |

| `resources/views/admin/dashboard.blade.php` | Presenta indicadores de operación del sistema. Muestra denuncias agrupadas por estado, situación de los camiones y cantidad de denuncias todavía no asignadas. |

| `resources/views/admin/denuncias/edit.blade.php` | Permite al administrador corregir la dirección, barrio y descripción de una denuncia. Al seleccionar un nuevo barrio, el municipio correspondiente se actualiza de acuerdo con esa relación. |

| `resources/views/admin/denuncias/index.blade.php` | Presenta el listado operativo de denuncias. Permite aplicar filtros, consultar su estado y acceder a las acciones disponibles según el rol del usuario. |

| `resources/views/admin/denuncias/show.blade.php` | Presenta el detalle operativo completo de una denuncia. Incluye datos del ciudadano, dirección, barrio, municipio, mapa, fotografías y estado, además de las acciones de cambio de estado, asignación y verificación disponibles según permisos. |

| `resources/views/admin/municipios/edit.blade.php` | Permite modificar el nombre de un municipio existente sin alterar directamente sus relaciones con barrios, denuncias o camiones. |

| `resources/views/admin/municipios/index.blade.php` | Centraliza la administración de municipios. Permite crear municipios y muestra cuántos barrios, denuncias y camiones están asociados a cada uno, información que también determina cuándo puede eliminarse un municipio. |

| `resources/views/layouts/admin.blade.php` | Define la estructura compartida del Backend. Contiene la navegación y adapta las opciones disponibles al rol del usuario autenticado. |

### 11.15. Rutas

| Archivo | Responsabilidad |

|---|---|

| `routes/console.php` | Registra las tareas programadas que Laravel Scheduler debe ejecutar automáticamente. |

| `routes/web.php` | Define las rutas del Backend para autenticación, dashboard, denuncias, camiones, barrios y municipios. También aplica los middleware y permisos correspondientes a cada grupo de funciones. |


---


## 12. Mantenimiento y diagnóstico

### 12.1. Áreas críticas

Ante fallas de autenticación, comprobar guard y middleware; ante errores de validación, revisar Form Request; ante problemas de estados, comprobar enums, modelos, controlador y registros de fechas; ante fallas de imágenes, comprobar volumen, disk y reglas de autorización.

### 12.2. Inspecciones seguras

```bash
php artisan route:list
php artisan about
php artisan schedule:list
```


La disponibilidad de los comandos depende del entorno y del arranque de la aplicación. No se han ejecutado contra producción.

### 12.3. Impacto de modificaciones

Cualquier cambio en tablas comunes, reglas de estados, asignaciones o almacenamiento debe revisarse en las otras dos aplicaciones antes de desplegar.


---


### 12.4. Inconsistencia en la desasignación

La ruta `POST /admin/denuncias/{denuncia}/desasignar` está declarada y apunta a `DenunciaController::desasignar`. El método permite a los usuarios con rol **Admin** desasignar camiones de cualquier denuncia y a los usuarios con rol **Operator** hacerlo únicamente en denuncias que no se encuentren en estado terminal. Los usuarios con rol **Reader** no tienen permiso para desasignar.

La operación cambia las asignaciones activas (`pendiente` o `en_proceso`) al estado `rechazado` (no confundir con denuncia rechazada), sin eliminar registros, fotografías ni modificar el estado general de la denuncia. Se conserva el historial y se permite una nueva asignación, respetando las reglas de negocio existentes.

### 12.5. Diagnóstico y mantenimiento del Scheduler

El Backend Administrativo utiliza Laravel Scheduler para ejecutar periódicamente el comando encargado de finalizar denuncias resueltas cuyo plazo de espera ha vencido.

El proceso Scheduler se inicia automáticamente durante el arranque del contenedor Docker mediante `entrypoint.sh`.

La configuración y el funcionamiento interno del EntryPoint se encuentran documentados en la sección 10.2.

Esta sección describe los procedimientos de diagnóstico y recuperación operativa.

#### 12.5.1. Identificación del contenedor

El contenedor del Backend Administrativo se encuentra definido en:

`docker-compose.yml`

Con el nombre:

`recoleccion_admin`

Para comprobar su estado:

```bash
docker ps --filter "name=recoleccion_admin"
```

El contenedor debe aparecer en ejecución para que los servicios internos estén disponibles.

Esta comprobación no confirma por sí sola el funcionamiento del Scheduler.

Para consultar información detallada del contenedor:

```bash
docker inspect recoleccion_admin
```

#### 12.5.2. Verificación del proceso Scheduler

El EntryPoint ejecuta el siguiente comando bajo el usuario `www-data`:

```bash
php artisan schedule:work
```

Para inspeccionar los procesos del contenedor desde el anfitrión Docker:

```bash
docker top recoleccion_admin
```

En la salida deberá identificarse el proceso asociado a `php artisan schedule:work`.

También deberá comprobarse la existencia del proceso Apache.

La implementación actual supervisa ambos procesos desde el EntryPoint.

Cuando uno de ellos termina, el script solicita la finalización de los procesos registrados y termina con el código de salida correspondiente.

La política Docker `restart: unless-stopped` permite reiniciar el contenedor cuando termina inesperadamente, sujeto al comportamiento de Docker y al modo en que se detenga el servicio.

#### 12.5.3. Verificación de las tareas programadas

Para consultar las tareas registradas en Laravel:

```bash
docker exec recoleccion_admin php artisan schedule:list
```

La salida deberá incluir el comando:

`denuncias:finalizar-vencidas`

Su frecuencia configurada es cada minuto.

El listado permite comprobar que Laravel reconoce la programación, pero no confirma que la tarea haya ejecutado correctamente sus operaciones.

Si el comando no aparece, deberán revisarse:

- `routes/console.php`
- `app/Console/Commands/FinalizarDenunciasVencidas.php`
- La configuración y disponibilidad del entorno Laravel.

#### 12.5.4. Revisión de registros

Para consultar los registros recientes del contenedor:

```bash
docker logs --tail 100 recoleccion_admin
```

Para observar los registros en tiempo real:

```bash
docker logs -f recoleccion_admin
```

También puede consultarse el archivo de registros de Laravel, cuando exista:

```bash
docker exec recoleccion_admin \
    tail -n 100 storage/logs/laravel.log
```

Los registros permiten identificar errores relacionados con:

- Fallas de conexión a MySQL.
- Excepciones de Laravel.
- Errores durante la ejecución de comandos.
- Problemas de permisos en `storage`.
- Fallas durante la inicialización del contenedor.

La disponibilidad de información específica del Scheduler depende de los mensajes registrados por Laravel y el comando.

La ausencia de errores en los registros no demuestra necesariamente que se hayan procesado denuncias.

#### 12.5.5. Verificación del cierre automático

El mecanismo de finalización utiliza las siguientes condiciones principales:

1. La denuncia se encuentra en estado `resuelto`.
2. La columna `estado_cambiado_at` contiene una fecha válida.
3. Ha transcurrido al menos una hora desde el cambio de estado.
4. El registro continúa cumpliendo las condiciones al momento de procesarlo.

El plazo se encuentra definido mediante:

```php
Denuncia::HORAS_PARA_FINALIZAR
```

La implementación utiliza transacciones y bloqueo de filas para evitar conflictos con cambios administrativos concurrentes.

Para verificar el comportamiento sin modificar producción, se recomienda realizar una prueba controlada en un entorno de pruebas con datos preparados específicamente para este propósito.

La prueba deberá comprobar que:

- Una denuncia que todavía no alcanzó el plazo permanece en estado `resuelto`.
- Una denuncia elegible cambia a `finalizado` después de ejecutarse correctamente la tarea.
- Una denuncia que dejó de estar en estado `resuelto` no es finalizada por el comando.
- La ejecución del comando informa correctamente la cantidad de registros procesados.

#### 12.5.6. Ejecución manual para diagnóstico

El comando puede ejecutarse manualmente mediante:

```bash
docker exec -u www-data recoleccion_admin \
    php artisan denuncias:finalizar-vencidas
```

**Advertencia:** este comando modifica registros reales de la base de datos cuando encuentra denuncias que cumplen las condiciones de finalización.

No es una operación de solo lectura.

Por lo tanto, deberá ejecutarse preferentemente en un entorno de pruebas o como una intervención autorizada sobre producción.

El comando informa la cantidad de denuncias finalizadas automáticamente.

Su ejecución manual no sustituye el funcionamiento permanente del Scheduler.

#### 12.5.7. Diagnóstico de tareas superpuestas

La programación utiliza:

```php
->withoutOverlapping(5)
```

Este mecanismo evita que se inicie una nueva ejecución mientras exista un bloqueo activo de la misma tarea.

El bloqueo tiene un vencimiento configurado de cinco minutos.

Si una ejecución termina anormalmente y permanece un bloqueo vigente, la siguiente ejecución puede ser omitida hasta que expire.

Laravel proporciona mecanismos para administrar bloqueos del Scheduler, pero cualquier eliminación manual deberá realizarse únicamente después de confirmar que no existe una ejecución legítima todavía en funcionamiento.

No deberán eliminarse bloqueos de forma rutinaria sin determinar la causa del problema.

#### 12.5.8. Recuperación del servicio

Si el Scheduler deja de funcionar, se deberá comprobar:

1. El estado del contenedor.
2. La existencia del proceso `schedule:work`.
3. Los registros de Docker y Laravel.
4. La disponibilidad de MySQL.
5. Los permisos del directorio `storage`.
6. La presencia de la tarea en `schedule:list`.

Si corresponde reiniciar el contenedor, podrá utilizarse:

```bash
docker restart recoleccion_admin
```

Este comando reinicia el contenedor completo.

Durante el reinicio también se interrumpe temporalmente el servicio web del Backend Administrativo.

El reinicio vuelve a ejecutar `entrypoint.sh`, incluyendo la preparación de permisos, la comprobación de `APP_KEY` y el inicio de Scheduler y Apache.

La operación deberá coordinarse cuando existan usuarios administrativos activos.

No es necesario reiniciar los contenedores de Ciudadana o Camiones para recuperar exclusivamente el Scheduler del Backend Administrativo.

#### 12.5.9. Validación posterior a la recuperación

Después de recuperar el servicio, se deberán realizar las siguientes comprobaciones:

1. Confirmar que el contenedor se encuentra en ejecución.
2. Confirmar que Apache está disponible.
3. Verificar la presencia de `schedule:work` mediante `docker top`.
4. Confirmar que `schedule:list` incluye `denuncias:finalizar-vencidas`.
5. Revisar los registros recientes.
6. Comprobar, mediante una prueba controlada, que las denuncias elegibles pueden finalizarse correctamente.

La recuperación del proceso no implica necesariamente que todos los registros pendientes hayan sido procesados inmediatamente.

El procesamiento dependerá de las ejecuciones posteriores y de las condiciones de las denuncias.

#### 12.5.10. Consideraciones operativas

El Backend Administrativo utiliza un Scheduler interno al contenedor, sin necesidad de configurar un cron externo para el cierre automático de denuncias.

La frecuencia de ejecución del Scheduler es independiente del plazo establecido para la finalización.

El proceso debe permanecer disponible para garantizar la evaluación periódica de denuncias elegibles.

Los cambios en la programación deberán evaluarse conjuntamente con:

- `entrypoint.sh`
- `routes/console.php`
- `FinalizarDenunciasVencidas.php`
- `Denuncia.php`
- La configuración del almacenamiento de caché utilizado por Laravel para los bloqueos.

No deberán modificarse estos componentes sin comprobar su impacto sobre los procesos administrativos y la base de datos compartida.

---

## 13. Anexos

Reservado para matrices de permisos, contratos de respuestas, diagramas y pruebas verificadas que se incorporen posteriormente.
