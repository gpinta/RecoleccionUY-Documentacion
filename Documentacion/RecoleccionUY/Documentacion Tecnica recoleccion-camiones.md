# Documentación técnica normalizada — Aplicación Camiones

**Proyecto:** `recoleccion-camiones`  
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
  - [3.1. Acceso del camión y vigencia del usuario](#31-acceso-del-camión-y-vigencia-del-usuario)
  - [3.2. Dashboard operativo](#32-dashboard-operativo)
  - [3.3. Listado de asignaciones y filtros](#33-listado-de-asignaciones-y-filtros)
  - [3.4. Consulta de detalle](#34-consulta-de-detalle)
  - [3.5. Inicio de trabajo](#35-inicio-de-trabajo)
  - [3.6. Finalización y carga de evidencias](#36-finalización-y-carga-de-evidencias)
  - [3.7. Evidencias privadas](#37-evidencias-privadas)
  - [3.8. Separación del estado operativo](#38-separación-del-estado-operativo)
- [4. Rutas y controladores](#4-rutas-y-controladores)
  - [4.1. `routes/web.php`](#41-routeswebphp)
  - [4.2. Rutas API](#42-rutas-api)
  - [4.3. Controladores y métodos implementados](#43-controladores-y-métodos-implementados)
  - [4.4. Reglas de validación por Form Request](#44-reglas-de-validación-por-form-request)
  - [4.5. Reglas de validación por formulario](#45-reglas-de-validación-por-formulario)
    - [app/Http/Requests/FinalizarAsignacionRequest.php](#apphttprequestsfinalizarasignacionrequestphp)
- [5. Modelos y base de datos](#5-modelos-y-base-de-datos)
  - [5.1. Base de datos compartida](#51-base-de-datos-compartida)
    - [5.1.1. Administración de migraciones](#511-administración-de-migraciones)
    - [5.1.2. Procedimiento para modificar la estructura de la base de datos](#512-procedimiento-para-modificar-la-estructura-de-la-base-de-datos)
    - [5.1.3. Impacto entre aplicaciones](#513-impacto-entre-aplicaciones)
    - [5.1.4. Responsabilidad y control de cambios](#514-responsabilidad-y-control-de-cambios)
  - [5.2. Modelos Eloquent](#52-modelos-eloquent)
    - [`app/Models/Camion.php`](#appmodelscamionphp)
    - [`app/Models/CamionUser.php`](#appmodelscamionuserphp)
    - [`app/Models/Denuncia.php`](#appmodelsdenunciaphp)
    - [`app/Models/DenunciaCamion.php`](#appmodelsdenunciacamionphp)
    - [`app/Models/FotoResolucion.php`](#appmodelsfotoresolucionphp)
    - [`app/Models/User.php`](#appmodelsuserphp)
  - [5.3. Migraciones presentes en el proyecto](#53-migraciones-presentes-en-el-proyecto)
- [6. Autenticación y seguridad](#6-autenticación-y-seguridad)
- [7. Reglas de negocio y estados](#7-reglas-de-negocio-y-estados)
  - [7.1. Matriz de estados operativos](#71-matriz-de-estados-operativos)
  - [7.2. Validación de cierre](#72-validación-de-cierre)
  - [7.3. Transacciones y recuperación](#73-transacciones-y-recuperación)
  - [7.4. Separación de responsabilidades](#74-separación-de-responsabilidades)
- [8. Interfaz, formularios y API](#8-interfaz-formularios-y-api)
  - [8.1. Pantallas Blade](#81-pantallas-blade)
  - [8.2. API](#82-api)
- [9. Fotografías y almacenamiento](#9-fotografías-y-almacenamiento)
- [10. Configuración y despliegue](#10-configuración-y-despliegue)
  - [10.1. Configuración Docker Compose](#101-configuración-docker-compose)
  - [10.2. Inicialización del contenedor y EntryPoint](#102-inicialización-del-contenedor-y-entrypoint)
    - [10.2.1. Preparación de directorios y permisos](#1021-preparación-de-directorios-y-permisos)
    - [10.2.2. Inicialización y validación de APP_KEY](#1022-inicialización-y-validación-de-app_key)
    - [10.2.3. Inicio de Apache](#1023-inicio-de-apache)
    - [10.2.4. Migraciones y seeders](#1024-migraciones-y-seeders)
    - [10.2.5. Laravel Scheduler](#1025-laravel-scheduler)
    - [10.2.6. Almacenamiento compartido](#1026-almacenamiento-compartido)
    - [10.2.7. Consideraciones operativas](#1027-consideraciones-operativas)
  - [10.3. Límites de comprobación](#103-límites-de-comprobación)
- [11. Diccionario técnico de archivos](#11-diccionario-técnico-de-archivos)
  - [11.1. Despliegue y raíz](#111-despliegue-y-raíz)
  - [11.2. Controladores](#112-controladores)
  - [11.3. Middleware](#113-middleware)
  - [11.4. Solicitudes y validaciones](#114-solicitudes-y-validaciones)
  - [11.5. Modelos](#115-modelos)
  - [11.6. Proveedores](#116-proveedores)
  - [11.7. Configuración Laravel](#117-configuración-laravel)
  - [11.8. Recursos públicos](#118-recursos-públicos)
  - [11.9. Vistas](#119-vistas)
  - [11.10. Rutas](#1110-rutas)
- [12. Mantenimiento y diagnóstico](#12-mantenimiento-y-diagnóstico)
  - [12.1. Áreas críticas](#121-áreas-críticas)
  - [12.2. Inspecciones seguras](#122-inspecciones-seguras)
  - [12.3. Impacto de modificaciones](#123-impacto-de-modificaciones)
- [13. Anexos](#13-anexos)


---

## 1. Datos generales

**Finalidad:** Operación de camiones: acceso mediante usuario vinculado a matrícula, visualización, inicio y finalización de asignaciones y evidencia fotográfica.

**Proyecto independiente:** `recoleccion-camiones`. Comparte la base de datos con las otras dos aplicaciones, pero mantiene controladores, modelos y configuración propios.

**Archivos identificados en el proyecto:** 34. Su descripción individual figura en la sección 11.

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

| Controladores | 5 |

| Middleware | 1 |

| Solicitudes y validaciones | 1 |

| Modelos | 6 |

| Proveedores | 1 |

| Configuración Laravel | 5 |

| Recursos públicos | 1 |

| Vistas | 6 |

| Rutas | 2 |

### 2.3. Árbol completo de directorios y archivos

La estructura del proyecto se presenta a continuación, con sus directorios, subdirectorios y archivos. Las responsabilidades individuales se describen en el diccionario técnico de la sección 11.

```text
recoleccion-camiones/
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── AsignacionController.php
│   │   │   ├── AuthController.php
│   │   │   ├── Controller.php
│   │   │   ├── DashboardController.php
│   │   │   └── FotoResolucionController.php
│   │   ├── Middleware/
│   │   │   └── EnsureCamionActivo.php
│   │   └── Requests/
│   │       └── FinalizarAsignacionRequest.php
│   ├── Models/
│   │   ├── Camion.php
│   │   ├── CamionUser.php
│   │   ├── Denuncia.php
│   │   ├── DenunciaCamion.php
│   │   ├── FotoResolucion.php
│   │   └── User.php
│   └── Providers/
│       └── AppServiceProvider.php
├── bootstrap/
│   ├── app.php
│   └── providers.php
├── config/
│   ├── app.php
│   ├── auth.php
│   └── filesystems.php
├── public/
│   └── images/
│       └── bandera-uy.png
├── resources/
│   └── views/
│       ├── asignaciones/
│       │   ├── index.blade.php
│       │   └── show.blade.php
│       ├── auth/
│       │   └── login.blade.php
│       ├── layouts/
│       │   └── app.blade.php
│       ├── dashboard.blade.php
│       └── welcome.blade.php
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

### 3.1. Acceso del camión y vigencia del usuario

`AuthController::showLogin()` presenta `auth/login.blade.php`; `login()` autentica al operador usando la matrícula y la credencial asociada al registro `camion_user`, vinculado con `camiones`. `logout()` cierra la sesión. `EnsureCamionActivo` controla que el usuario siga habilitado y su camión conserve el estado permitido; si deja de reunir las condiciones, impide continuar con operaciones protegidas. La autenticación de esta aplicación es propia y no equivale al login ciudadano ni al LDAP administrativo.

### 3.2. Dashboard operativo

`DashboardController::index()` presenta `dashboard.blade.php` con información del camión asociado al usuario y su carga de trabajo; los datos se extraen de la relación entre `camion_user`, `camiones` y `denuncia_camion`.

### 3.3. Listado de asignaciones y filtros

`AsignacionController::index()` obtiene el camión desde `$request->user()->camion`, no desde un identificador recibido libremente del navegador. Acepta filtros `pendiente`, `en_proceso` y `resuelto`; cualquier otro valor se normaliza a `pendiente`. Se presentan diez elementos por página ordenados por creación descendente. Las asignaciones `rechazado` siguen registradas pero no se incluyen entre las categorías del listado operativo. Para pendientes y en curso, la denuncia relacionada debe seguir en `pendiente` o `en_proceso`, de modo que una denuncia reclamada o cerrada no quede como trabajo activo.

### 3.4. Consulta de detalle

`AsignacionController::show()` busca la asignación con condición simultánea `camion_id = camión autenticado` e identificador solicitado. Carga la denuncia y sus fotos de resolución. Una asignación de otro camión no puede recuperarse simplemente cambiando su número en la URL.

### 3.5. Inicio de trabajo

`AsignacionController::iniciar()` ejecuta una transacción; localiza la denuncia relacionada y obtiene bloqueos `lockForUpdate()` primero sobre la denuncia y después sobre la asignación. Exige que la asignación esté `pendiente` y que la denuncia global esté `pendiente` o `en_proceso`. Si la denuncia está pendiente, la cambia a `en_proceso` mediante `Denuncia::cambiarEstadoOperativo()`; si Administración ya la inició, preserva su estado global. La asignación pasa a `en_proceso`. Ante condiciones incompatibles devuelve error de validación, sin actualizar parcialmente.

### 3.6. Finalización y carga de evidencias

`FinalizarAsignacionRequest` exige `comentario_cierre` de 10 a 2000 caracteres y entre 1 y 5 fotografías, con límite de 5120 KiB por imagen y formatos permitidos por la regla MIME del archivo. `AsignacionController::finalizar()` exige asignación `en_proceso` y denuncia global `en_proceso`, con bloqueo transaccional de denuncia seguido de asignación.

Las fotos se escriben en el disco `resoluciones_private` bajo la ruta relativa `{denuncia_id}/foto_resolucion/...`; el identificador usado en el directorio es el de la **denuncia**, no el de la asignación. Cada foto genera un registro en `fotos_resolucion` con `denuncia_camion_id`. Después la denuncia pasa de `en_proceso` a `resuelto` y la asignación a `resuelto`, conservando `comentario_cierre`. Si falla la transacción, se eliminan las imágenes recién escritas para evitar archivos huérfanos. El camión **no** puede marcar una denuncia directamente como `finalizado`: el cierre final pertenece al proceso administrativo.

### 3.7. Evidencias privadas

`FotoResolucionController::show()` permite la entrega controlada de la fotografía de resolución en el contexto de la asignación autorizada. `config/filesystems.php` define el disco privado; las rutas persistidas son relativas. La publicación de archivos mediante URLs públicas directas no sustituye el controlador protegido.

### 3.8. Separación del estado operativo

`DenunciaCamion` distingue `pendiente`, `en_proceso`, `resuelto` y `rechazado`; los métodos `estaPendiente()`, `estaEnProceso()`, `estaResuelta()` y `estaRechazada()` simplifican sus comprobaciones. La tabla guarda además comentario de cierre, fecha y relación con camión y denuncia. `Denuncia::cambiarEstadoOperativo()` controla que la aplicación no ejecute cambios de estado global que corresponden al Backend Administrativo.

---

## 4. Rutas y controladores

### 4.1. `routes/web.php`

| Método | URI declarada | Controlador | Acción |
|---|---|---|---|
| `GET` | `/login` | `AuthController` | `showLogin()` |
| `POST` | `/login` | `AuthController` | `login()` |
| `GET` | `/dashboard` | `DashboardController` | `index()` |
| `GET` | `/asignaciones` | `AsignacionController` | `index()` |
| `GET` | `/asignaciones/{asignacion}` | `AsignacionController` | `show()` |
| `POST` | `/asignaciones/{asignacion}/iniciar` | `AsignacionController` | `iniciar()` |
| `POST` | `/asignaciones/{asignacion}/finalizar` | `AsignacionController` | `finalizar()` |
| `GET` | `/asignaciones/{asignacion}/fotos/{foto}` | `FotoResolucionController` | `show()` |
| `POST` | `/logout` | `AuthController` | `logout()` |

### 4.2. Rutas API

Esta aplicación no define rutas API REST propias; su interacción HTTP se organiza en `routes/web.php`.

### 4.3. Controladores y métodos implementados

- **`app/Http/Controllers/AsignacionController.php`**: `index()`, `show()`, `iniciar()`, `finalizar()`.

- **`app/Http/Controllers/AuthController.php`**: `showLogin()`, `login()`, `logout()`.

- **`app/Http/Controllers/DashboardController.php`**: `index()`.

- **`app/Http/Controllers/FotoResolucionController.php`**: `show()`.

### 4.4. Reglas de validación por Form Request

- **`app/Http/Requests/FinalizarAsignacionRequest.php`**: `comentario_cierre`: `required`, `string`, `min:10`, `max:2000`; `fotos`: `required`, `array`, `min:1`, `max:5`; `fotos.*`: `required`, `image`, `mimes:jpg,jpeg,png,webp`, `max:5120`


---


### 4.5. Reglas de validación por formulario

Las siguientes reglas se transcriben de los métodos `rules()` vigentes y permiten identificar con precisión qué restricciones aplica el servidor. Los permisos adicionales pueden residir en `authorize()`, middleware o policies.

#### app/Http/Requests/FinalizarAsignacionRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'comentario_cierre' => [
                'required',
                'string',
                'min:10',
                'max:2000',
            ],

            'fotos' => [
                'required',
                'array',
                'min:1',
                'max:5',
            ],

            'fotos.*' => [
                'required',
                'image',
                'mimes:jpg,jpeg,png,webp',
                'max:5120',
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

#### `app/Models/Camion.php`

Representa la flota: matrícula, marca, modelo, municipio, estado operativo y relaciones con usuario y asignaciones.

**Métodos/relaciones declarados:** `casts()`, `usuario()`, `asignaciones()`, `asignacionesActivas()`, `estaActivo()`.

**table:** 'camiones'.

**fillable:** `matricula`, `marca`, `modelo`, `estado_operativo`, `municipio_id`.

#### `app/Models/CamionUser.php`

Representa las credenciales y la habilitación de acceso asociadas a un camión; proporciona la relación `camion()`.

**Métodos/relaciones declarados:** `casts()`, `camion()`, `estaHabilitado()`.

**table:** 'camion_user'.

**fillable:** `camion_id`, `password`.

**hidden:** `password`, `remember_token`.

#### `app/Models/Denuncia.php`

Representa una denuncia y sus relaciones operativas; permite cambios controlados del estado global cuando la tarea se inicia o resuelve.

**Métodos/relaciones declarados:** `casts()`, `asignaciones()`, `cambiarEstadoOperativo()`.

**table:** 'denuncias'.

**guarded:** lista vacía (`[]`); revisar asignación de atributos junto con las validaciones y el controlador.

#### `app/Models/DenunciaCamion.php`

Representa una tarea asignada a un camión, su estado operativo, comentario de cierre y las fotos de resolución.

**Métodos/relaciones declarados:** `casts()`, `camion()`, `denuncia()`, `fotos()`, `estaPendiente()`, `estaEnProceso()`, `estaResuelta()`, `estaRechazada()`, `estadoLabel()`.

**table:** 'denuncia_camion'.

**guarded:** lista vacía (`[]`); revisar asignación de atributos junto con las validaciones y el controlador.

#### `app/Models/FotoResolucion.php`

Representa cada evidencia fotográfica privada y su relación con la asignación de denuncia.

**Métodos/relaciones declarados:** `asignacion()`.

**table:** 'fotos_resolucion'.

**hidden:** `ruta`.

**guarded:** lista vacía (`[]`); revisar asignación de atributos junto con las validaciones y el controlador.

#### `app/Models/User.php`

Modelo de usuario Laravel; no debe confundirse con la identidad operativa específica de CamionUser.

**Métodos/relaciones declarados:** `casts()`.

**fillable:** `name`, `email`, `password`.

**hidden:** `password`, `remember_token`.

### 5.3. Migraciones presentes en el proyecto

No se incluyen archivos `database/migrations` en el proyecto. La ausencia en el proyecto no prueba que la base de datos carezca de estas tablas.


---


## 6. Autenticación y seguridad

Autenticación de sesión web asociada a `CamionUser` y `Camion`; middleware `camion.activo` en rutas protegidas. Las operaciones están restringidas a asignaciones del camión autenticado.

No se encontraron rutas API en el proyecto de Camiones.


---


## 7. Reglas de negocio y estados

### 7.1. Matriz de estados operativos

| Operación | Estado de asignación exigido | Estado global exigido | Resultado |
|---|---|---|---|
| Iniciar | `pendiente` | `pendiente` o `en_proceso` | Asignación `en_proceso`; denuncia se inicia solo si estaba `pendiente` |
| Finalizar | `en_proceso` | `en_proceso` | Ambos pasan a `resuelto`; guarda comentario y evidencias |
| Visualizar completadas | `resuelto` | No exige estado operativo activo | Conserva historial |
| Listar activas | `pendiente` o `en_proceso` | `pendiente` o `en_proceso` | Excluye denuncias ya reclamadas o cerradas |

Las asignaciones `rechazado` no aparecen como tarea activa en el listado del camión.

### 7.2. Validación de cierre

`comentario_cierre` obligatorio entre 10 y 2000 caracteres; `fotos` entre una y cinco imágenes, máximo 5120 KiB cada una. Los formatos se controlan en `FinalizarAsignacionRequest`.

### 7.3. Transacciones y recuperación

`iniciar()` y `finalizar()` bloquean primero la denuncia y después la asignación. `finalizar()` escribe archivos bajo un subdirectorio de la denuncia, crea registros en `fotos_resolucion` y actualiza estados en una sola transacción. Cuando falla la operación, el controlador ejecuta limpieza compensatoria de las imágenes guardadas. Se mantienen los comentarios y las evidencias históricas de tareas ya completadas.

### 7.4. Separación de responsabilidades

El camión solo puede operar asignaciones propias; no decide un cambio global a `finalizado` ni reasigna un trabajo a otro camión. La verificación y eventual cierre final son responsabilidades administrativas.

---

## 8. Interfaz, formularios y API

### 8.1. Pantallas Blade

La aplicación contiene 6 vistas, detalladas una por una en el diccionario.

### 8.2. API

La aplicación expone sus operaciones funcionales mediante `routes/web.php`; no se define aquí un contrato REST público independiente.


---


## 9. Fotografías y almacenamiento

Las fotos de resolución se asocian con `DenunciaCamion` mediante `FotoResolucion`. El host `/srv/recoleccion-data/fotos` se monta como `/var/www/shared-fotos`. La visualización depende de la asignación y del camión autenticado.


---


## 10. Configuración y despliegue

### 10.1. Configuración Docker Compose

- `container_name`: `recoleccion_camiones`.
- `APP_URL`: `http://camiones-recoleccion.neltek.uy`.
- `DB_HOST`: `db`.
- `DB_PORT`: `3306`.
- `DB_DATABASE`: `recoleccion`.
- `RESOLUCIONES_PRIVATE_ROOT`: `/var/www/shared-fotos`.
- Publicación/montaje: `192.168.30.20:8082:8082`.
- Publicación/montaje: `/srv/recoleccion-data/fotos:/var/www/shared-fotos:rw,z`.

### 10.2. Inicialización del contenedor y EntryPoint

La Aplicación Camiones utiliza un contenedor Docker basado en PHP 8.2 y Apache.

Los archivos involucrados en su inicialización son:

- `Dockerfile`
- `docker-compose.yml`
- `entrypoint.sh`
- `laravel.conf`

El Dockerfile instala las extensiones PHP utilizadas por la aplicación, incorpora Composer y configura Apache para escuchar en el puerto 8082.

La instrucción `ENTRYPOINT ["entrypoint.sh"]` establece el script encargado de preparar el entorno.

La instrucción `CMD ["apache2-foreground"]` define el proceso principal del contenedor.

#### 10.2.1. Preparación de directorios y permisos

El EntryPoint utiliza `set -e` y crea los directorios necesarios para el funcionamiento de Laravel:

```bash
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/bootstrap/cache
```

Posteriormente asigna al usuario `www-data` la propiedad de los directorios:

- `/var/www/html/storage`
- `/var/www/html/bootstrap/cache`

Los permisos establecidos son:

- `775` para directorios.
- `664` para archivos.

Estos permisos permiten que Apache y PHP utilicen las rutas de almacenamiento necesarias para Laravel.

#### 10.2.2. Inicialización y validación de APP_KEY

El EntryPoint comprueba si existe una clave de aplicación mediante:

```bash
if [ -z "${APP_KEY:-}" ]; then
```

Si la variable está vacía o no está definida, genera una clave mediante:

```bash
clave_generada="$(php artisan key:generate --show)"
```

Posteriormente procesa la salida de Artisan para extraer exclusivamente la línea que contiene la clave con el formato esperado `base64:`.

Esta validación es necesaria porque el script contempla la posibilidad de que la salida de Artisan incluya líneas adicionales.

Si no encuentra una clave válida, muestra un mensaje de error y finaliza la inicialización:

```bash
if [ -z "$APP_KEY" ]; then
    echo "ERROR: Laravel no generó una APP_KEY válida." >&2
    exit 1
fi
```

Cuando la clave supera la comprobación, se exporta mediante:

```bash
export APP_KEY
```

El script informa que la clave fue generada, pero no imprime su contenido.

La generación es válida únicamente para la ejecución actual, salvo que la configuración externa garantice su persistencia.

En producción debe utilizarse una `APP_KEY` persistente y gestionada de forma segura.

#### 10.2.3. Inicio de Apache

Una vez finalizada la preparación de Laravel, el EntryPoint ejecuta:

```bash
exec "$@"
```

El comando sustituye el proceso del script por:

```bash
apache2-foreground
```

Apache queda ejecutándose en primer plano y atiende las solicitudes de la Aplicación Camiones en el puerto 8082 del contenedor.

#### 10.2.4. Migraciones y seeders

El EntryPoint de la Aplicación Camiones no ejecuta migraciones ni seeders.

Por lo tanto, durante el procedimiento de inicialización no se invocan automáticamente:

```bash
php artisan migrate --force
```

```bash
php artisan db:seed --force
```

La Aplicación Camiones utiliza la base de datos MySQL compartida.

Las migraciones del esquema compartido se encuentran actualmente en la Aplicación Ciudadana.

La Aplicación Camiones depende de que las tablas y relaciones necesarias para sus operaciones se encuentren disponibles y sean compatibles con sus modelos Eloquent.

#### 10.2.5. Laravel Scheduler

El EntryPoint no inicia un proceso permanente de Laravel Scheduler.

Tampoco se encuentra configurada una tarea programada específica en el archivo `routes/console.php` incluido en el paquete analizado.

Por lo tanto, la inicialización del contenedor no depende de un proceso `schedule:work`.

Esta configuración es diferente de la utilizada por el Backend Administrativo, que ejecuta un Scheduler para gestionar tareas programadas.

#### 10.2.6. Almacenamiento compartido

La Aplicación Camiones utiliza el volumen compartido del anfitrión:

`/srv/recoleccion-data/fotos`

El volumen se monta dentro del contenedor mediante:

`/var/www/shared-fotos`

La variable `RESOLUCIONES_PRIVATE_ROOT` identifica la ruta interna utilizada para las fotografías privadas de resolución.

El EntryPoint no modifica directamente este directorio compartido ni crea un enlace simbólico específico para él.

El acceso efectivo a dicho almacenamiento depende de la configuración de Docker, de los permisos del sistema de archivos y de las operaciones implementadas en Laravel.

#### 10.2.7. Consideraciones operativas

El orden de inicialización actual es:

1. Crear los directorios necesarios para Laravel.
2. Establecer propietarios y permisos.
3. Verificar la existencia de `APP_KEY`.
4. Generar y validar una clave cuando sea necesario.
5. Exportar la clave generada.
6. Iniciar Apache.

La Aplicación Camiones no ejecuta migraciones, seeders ni tareas programadas durante su inicialización.

Su funcionamiento depende de la disponibilidad de la base de datos compartida y del almacenamiento configurado.

### 10.3. Límites de comprobación

Los datos anteriores son configuración declarada en archivos; no constituyen comprobación de contenedores activos, acceso HTTPS público ni conectividad efectiva. Los archivos `.env` no se reproducen por contener parámetros sensibles.


---


## 11. Diccionario técnico de archivos

El siguiente diccionario enumera **todos los archivos de esta aplicación**, sin mezclar archivos de los otros proyectos. Las descripciones representan la responsabilidad identificable por el código y la estructura del proyecto.

### 11.1. Despliegue y raíz

| Archivo | Responsabilidad |

|---|---|

| `.dockerignore` | Exclusiones del contexto de construcción de Docker. |

| `.env` | Variables de entorno; contiene valores potencialmente sensibles que no se reproducen. |

| `docker-compose.yml` | Define servicios, contenedores, redes, volúmenes y variables de despliegue. |

| `Dockerfile` | Construye la imagen PHP y Apache que ejecuta Laravel. |

| `entrypoint.sh` | Inicializa Laravel y servicios auxiliares al arrancar el contenedor. |

| `laravel.conf` | Configuración del VirtualHost de Apache para servir Laravel. |

### 11.2. Controladores

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Controllers/AsignacionController.php` | Lista y filtra las asignaciones del camión autenticado, carga detalles, inicia tareas mediante transacciones y registra el cierre con comentario, imágenes privadas y actualización coordinada de estados. |

| `app/Http/Controllers/AuthController.php` | Presenta el formulario de acceso, valida matrícula y contraseña, autentica al usuario operativo y termina la sesión. |

| `app/Http/Controllers/Controller.php` | Clase base de los controladores HTTP de la aplicación. |

| `app/Http/Controllers/DashboardController.php` | Consulta el camión autenticado y prepara el resumen de su actividad operativa para el dashboard. |

| `app/Http/Controllers/FotoResolucionController.php` | Recupera evidencia fotográfica de una asignación, validando su pertenencia al camión autenticado y obteniendo el archivo desde almacenamiento privado. |

### 11.3. Middleware

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Middleware/EnsureCamionActivo.php` | Comprueba que la cuenta operativa y el camión asociado cumplan las condiciones de habilitación; impide la continuidad de una sesión no autorizada. |

### 11.4. Solicitudes y validaciones

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Requests/FinalizarAsignacionRequest.php` | Valida comentario obligatorio de cierre (10 a 2000 caracteres) y entre 1 y 5 imágenes con restricciones de tipo y tamaño. |

### 11.5. Modelos

| Archivo | Responsabilidad |

|---|---|

| `app/Models/Camion.php` | Representa el vehículo y sus atributos de identificación, municipio, estado operativo y relaciones de usuarios/asignaciones. |

| `app/Models/CamionUser.php` | Representa la cuenta de autenticación asociada a un camión y su relación con el vehículo operativo. |

| `app/Models/Denuncia.php` | Representa la denuncia compartida y controla cambios permitidos de estado operativo para inicio y resolución de trabajos. |

| `app/Models/DenunciaCamion.php` | Representa la asignación, su vínculo con camión y denuncia, el comentario de cierre, fotografías y predicados de estado. |

| `app/Models/FotoResolucion.php` | Representa las fotografías de resolución, la ruta relativa persistida y la asociación con una asignación. |

| `app/Models/User.php` | Modelo de usuario disponible en la aplicación; no sustituye la autenticación específica de camiones mediante CamionUser. |

### 11.6. Proveedores

| Archivo | Responsabilidad |

|---|---|

| `app/Providers/AppServiceProvider.php` | Registra configuración general y extensiones de servicios requeridas por Laravel en el arranque. |

### 11.7. Configuración Laravel

| Archivo | Responsabilidad |

|---|---|

| `bootstrap/app.php` | Arranque de Laravel, registro de rutas web y alias del middleware que exige camión activo. |

| `bootstrap/providers.php` | Lista de proveedores cargados durante la inicialización. |

| `config/app.php` | Nombre de aplicación, entorno, zona horaria y opciones generales del framework. |

| `config/auth.php` | Guards, providers, autenticación y configuración de contraseñas de la aplicación operativa. |

| `config/filesystems.php` | Configuración de discos de almacenamiento, incluido `resoluciones_private` para evidencias. |

### 11.8. Recursos públicos

| Archivo | Responsabilidad |

|---|---|

| `public/images/bandera-uy.png` | Recurso gráfico de la interfaz. |

### 11.9. Vistas

| Archivo | Responsabilidad |

|---|---|

| `resources/views/asignaciones/index.blade.php` | Pantalla de tareas del camión, con filtros Pendientes, En curso y Completadas y paginación. |

| `resources/views/asignaciones/show.blade.php` | Detalle de una asignación, acciones de iniciar/finalizar, comentario de cierre y evidencias asociadas. |

| `resources/views/auth/login.blade.php` | Formulario de identificación del usuario operativo por matrícula y contraseña. |

| `resources/views/dashboard.blade.php` | Panel principal que resume el trabajo del camión autenticado. |

| `resources/views/layouts/app.blade.php` | Plantilla general compartida por las vistas operativas y la navegación. |

| `resources/views/welcome.blade.php` | Vista de entrada accesible desde la ruta de bienvenida configurada. |

### 11.10. Rutas

| Archivo | Responsabilidad |

|---|---|

| `routes/console.php` | Declaraciones de comandos y programación de tareas propias del proyecto, si las hubiera. |

| `routes/web.php` | Define rutas HTTP de login, logout, dashboard, listado, detalle, inicio, cierre y fotografías de asignaciones. |


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


## 13. Anexos

Reservado para matrices de permisos, contratos de respuestas, diagramas y pruebas verificadas que se incorporen posteriormente.
