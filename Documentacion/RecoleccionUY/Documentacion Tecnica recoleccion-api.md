# Documentación técnica normalizada — Aplicación Ciudadana

**Proyecto:** `recoleccion-api`  
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
  - [3.1. Registro de ciudadanos y credenciales](#31-registro-de-ciudadanos-y-credenciales)
  - [3.2. Inicio y cierre de sesión web](#32-inicio-y-cierre-de-sesión-web)
  - [3.3. Autenticación API y administración de tokens](#33-autenticación-api-y-administración-de-tokens)
  - [3.4. Dashboard personal](#34-dashboard-personal)
  - [3.5. Creación de denuncias y ubicación territorial](#35-creación-de-denuncias-y-ubicación-territorial)
  - [3.6. Listado, detalle y control de propiedad](#36-listado-detalle-y-control-de-propiedad)
  - [3.7. Reclamos y reapertura de denuncias](#37-reclamos-y-reapertura-de-denuncias)
  - [3.8. Consulta pública](#38-consulta-pública)
  - [3.9. Perfil y supresión de cuenta](#39-perfil-y-supresión-de-cuenta)
  - [3.10. Catálogos y fotografías](#310-catálogos-y-fotografías)
- [4. Rutas y controladores](#4-rutas-y-controladores)
  - [4.1. `routes/web.php`](#41-routeswebphp)
  - [4.2. `routes/api.php`](#42-routesapiphp)
  - [4.3. Controladores y métodos implementados](#43-controladores-y-métodos-implementados)
  - [4.4. Reglas de validación por Form Request](#44-reglas-de-validación-por-form-request)
  - [4.5. Reglas de validación por formulario](#45-reglas-de-validación-por-formulario)
    - [app/Http/Requests/LoginRequest.php](#apphttprequestsloginrequestphp)
    - [app/Http/Requests/ReclamarDenunciaRequest.php](#apphttprequestsreclamardenunciarequestphp)
    - [app/Http/Requests/RegisterRequest.php](#apphttprequestsregisterrequestphp)
    - [app/Http/Requests/StoreDenunciaRequest.php](#apphttprequestsstoredenunciarequestphp)
    - [app/Http/Requests/UpdateProfileRequest.php](#apphttprequestsupdateprofilerequestphp)
- [5. Modelos y base de datos](#5-modelos-y-base-de-datos)
  - [5.1. Base de datos compartida](#51-base-de-datos-compartida)
    - [5.1.1. Administración de migraciones](#511-administración-de-migraciones)
    - [5.1.2. Procedimiento para modificar la estructura de la base de datos](#512-procedimiento-para-modificar-la-estructura-de-la-base-de-datos)
    - [5.1.3. Impacto entre aplicaciones](#513-impacto-entre-aplicaciones)
    - [5.1.4. Responsabilidad y control de cambios](#514-responsabilidad-y-control-de-cambios)
  - [5.2. Modelos Eloquent](#52-modelos-eloquent)
    - [`app/Models/Barrio.php`](#appmodelsbarriophp)
    - [`app/Models/Denuncia.php`](#appmodelsdenunciaphp)
    - [`app/Models/FotoDenuncia.php`](#appmodelsfotodenunciaphp)
    - [`app/Models/Municipio.php`](#appmodelsmunicipiophp)
    - [`app/Models/Reclamacion.php`](#appmodelsreclamacionphp)
    - [`app/Models/User.php`](#appmodelsuserphp)
  - [5.3. Migraciones presentes en el proyecto](#53-migraciones-presentes-en-el-proyecto)
- [6. Autenticación y seguridad](#6-autenticación-y-seguridad)
- [7. Reglas de negocio y estados](#7-reglas-de-negocio-y-estados)
  - [7.1. Estados globales](#71-estados-globales)
  - [7.2. Reglas de oportunidad del reclamo](#72-reglas-de-oportunidad-del-reclamo)
  - [7.3. Atomicidad y efecto del reclamo](#73-atomicidad-y-efecto-del-reclamo)
  - [7.4. Integridad de denuncia y archivos](#74-integridad-de-denuncia-y-archivos)
  - [7.5. Identificadores y preservación histórica](#75-identificadores-y-preservación-histórica)
- [8. Interfaz, formularios y API](#8-interfaz-formularios-y-api)
  - [8.1. Pantallas Blade](#81-pantallas-blade)
  - [8.2. API](#82-api)
- [9. Fotografías y almacenamiento](#9-fotografías-y-almacenamiento)
- [10. Configuración y despliegue](#10-configuración-y-despliegue)
  - [10.1. Configuración Docker Compose](#101-configuración-docker-compose)
  - [10.2. Inicialización del contenedor y EntryPoint](#102-inicialización-del-contenedor-y-entrypoint)
    - [10.2.1. Preparación de permisos](#1021-preparación-de-permisos)
    - [10.2.2. Inicialización de APP_KEY](#1022-inicialización-de-app_key)
    - [10.2.3. Preparación del almacenamiento público](#1023-preparación-del-almacenamiento-público)
    - [10.2.4. Ejecución automática de migraciones](#1024-ejecución-automática-de-migraciones)
    - [10.2.5. Ejecución automática de seeders](#1025-ejecución-automática-de-seeders)
    - [10.2.6. Inicio de Apache](#1026-inicio-de-apache)
    - [10.2.7. Consideraciones operativas](#1027-consideraciones-operativas)
  - [10.3. Límites de comprobación](#103-límites-de-comprobación)
- [11. Diccionario técnico de archivos](#11-diccionario-técnico-de-archivos)
  - [11.1. Despliegue y raíz](#111-despliegue-y-raíz)
  - [11.2. Enumeraciones](#112-enumeraciones)
  - [11.3. Controladores](#113-controladores)
  - [11.4. Solicitudes y validaciones](#114-solicitudes-y-validaciones)
  - [11.5. Recursos API](#115-recursos-api)
  - [11.6. Modelos](#116-modelos)
  - [11.7. Políticas de autorización](#117-políticas-de-autorización)
  - [11.8. Proveedores](#118-proveedores)
  - [11.9. Reglas](#119-reglas)
  - [11.10. Servicios](#1110-servicios)
  - [11.11. Configuración Laravel](#1111-configuración-laravel)
  - [11.12. Factories](#1112-factories)
  - [11.13. Migraciones](#1113-migraciones)
  - [11.14. Seeders](#1114-seeders)
  - [11.15. Recursos públicos](#1115-recursos-públicos)
  - [11.16. Vistas](#1116-vistas)
  - [11.17. Rutas](#1117-rutas)
- [12. Mantenimiento y diagnóstico](#12-mantenimiento-y-diagnóstico)
  - [12.1. Áreas críticas](#121-áreas-críticas)
  - [12.2. Inspecciones seguras](#122-inspecciones-seguras)
  - [12.3. Impacto de modificaciones](#123-impacto-de-modificaciones)
- [13. Anexos](#13-anexos)


---

## 1. Datos generales

**Finalidad:** Registro, autenticación, consulta y creación de denuncias ciudadanas, reclamos, fotografías, perfil, API REST y catálogo territorial.

**Proyecto independiente:** `recoleccion-api`. Comparte la base de datos con las otras dos aplicaciones, pero mantiene controladores, modelos y configuración propios.

**Archivos identificados en el proyecto:** 77. Su descripción individual figura en la sección 11.

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

| Enumeraciones | 1 |

| Controladores | 14 |

| Solicitudes y validaciones | 5 |

| Recursos API | 1 |

| Modelos | 6 |

| Políticas de autorización | 1 |

| Proveedores | 1 |

| Reglas | 1 |

| Servicios | 1 |

| Configuración Laravel | 4 |

| Factories | 1 |

| Migraciones | 13 |

| Seeders | 7 |

| Recursos públicos | 1 |

| Vistas | 11 |

| Rutas | 3 |

### 2.3. Árbol completo de directorios y archivos

La estructura del proyecto se presenta a continuación, con sus directorios, subdirectorios y archivos. Las responsabilidades individuales se describen en el diccionario técnico de la sección 11.

```text
recoleccion-api/
├── app/
│   ├── Enums/
│   │   └── DenunciaEstado.php
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Api/
│   │   │   │   ├── AuthController.php
│   │   │   │   ├── CatalogoController.php
│   │   │   │   ├── ConsultaController.php
│   │   │   │   ├── DashboardController.php
│   │   │   │   ├── DenunciaController.php
│   │   │   │   ├── FotoDenunciaController.php
│   │   │   │   └── ProfileController.php
│   │   │   ├── Web/
│   │   │   │   ├── AuthController.php
│   │   │   │   ├── ConsultaController.php
│   │   │   │   ├── DashboardController.php
│   │   │   │   ├── DenunciaController.php
│   │   │   │   ├── FotoDenunciaController.php
│   │   │   │   └── ProfileController.php
│   │   │   └── Controller.php
│   │   ├── Requests/
│   │   │   ├── LoginRequest.php
│   │   │   ├── ReclamarDenunciaRequest.php
│   │   │   ├── RegisterRequest.php
│   │   │   ├── StoreDenunciaRequest.php
│   │   │   └── UpdateProfileRequest.php
│   │   └── Resources/
│   │       └── UserResource.php
│   ├── Models/
│   │   ├── Barrio.php
│   │   ├── Denuncia.php
│   │   ├── FotoDenuncia.php
│   │   ├── Municipio.php
│   │   ├── Reclamacion.php
│   │   └── User.php
│   ├── Policies/
│   │   └── DenunciaPolicy.php
│   ├── Providers/
│   │   └── AppServiceProvider.php
│   ├── Rules/
│   │   └── StrongPassword.php
│   └── Services/
│       └── DenunciaPhotoService.php
├── bootstrap/
│   ├── app.php
│   └── providers.php
├── config/
│   ├── app.php
│   └── filesystems.php
├── database/
│   ├── factories/
│   │   └── UserFactory.php
│   ├── migrations/
│   │   ├── 0001_01_01_000000_create_users_table.php
│   │   ├── 0001_01_01_000001_create_cache_table.php
│   │   ├── 0001_01_01_000002_create_jobs_table.php
│   │   ├── 2026_06_30_185107_create_personal_access_tokens_table.php
│   │   ├── 2026_06_30_185338_create_municipios_table.php
│   │   ├── 2026_06_30_185340_create_barrios_table.php
│   │   ├── 2026_06_30_185342_create_denuncias_table.php
│   │   ├── 2026_06_30_185346_create_fotos_denuncia_table.php
│   │   ├── 2026_08_10_192024_create_reclamaciones_table.php
│   │   ├── 2026_08_23_213359_create_camiones_table.php
│   │   ├── 2026_08_23_224948_create_denuncia_camion_table.php
│   │   ├── 2026_08_23_224955_create_fotos_resolucion_table.php
│   │   └── 2026_10_17_215021_create_camion_user_table.php
│   └── seeders/
│       ├── BarriosSeeder.php
│       ├── CamionesSeeder.php
│       ├── DatabaseSeeder.php
│       ├── DenunciasDemoSeeder.php
│       ├── MunicipiosSeeder.php
│       └── UsuariosDemoSeeder.php
├── public/
│   └── images/
│       └── bandera-uy.png
├── resources/
│   └── views/
│       ├── auth/
│       │   ├── login.blade.php
│       │   ├── register-success.blade.php
│       │   └── register.blade.php
│       ├── denuncias/
│       │   ├── create.blade.php
│       │   ├── index.blade.php
│       │   └── show.blade.php
│       ├── layouts/
│       │   └── app.blade.php
│       ├── profile/
│       │   └── edit.blade.php
│       ├── consulta.blade.php
│       ├── dashboard.blade.php
│       └── welcome.blade.php
├── routes/
│   ├── api.php
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

### 3.1. Registro de ciudadanos y credenciales

La cuenta ciudadana se registra con documento, nombre, correo electrónico, contraseña y teléfono opcional. `users.id` es la identidad interna empleada por las relaciones; `documento` es un identificador de acceso distinto de la clave primaria, obligatorio y único. La pantalla de registro (`auth/register.blade.php`) envía los datos a `Web/AuthController::register()` mediante `RegisterRequest`; el alta web conduce a `auth/register-success.blade.php`, sin conceder automáticamente una sesión autenticada. La API ofrece un flujo de registro separado en `Api/AuthController::register()`.

`app/Rules/StrongPassword.php` centraliza la regla de contraseñas: longitud mínima de ocho caracteres y combinación de mayúscula, minúscula, dígito y símbolo permitido (`@`, `.`, `-`, `_`, `$`, `!`). El correo es único y editable; el documento no forma parte de los campos modificables del perfil. La contraseña se almacena mediante los mecanismos de hash de Laravel, no en texto plano.

### 3.2. Inicio y cierre de sesión web

`Web/AuthController::showLogin()` presenta `auth/login.blade.php`. `Web/AuthController::login()` valida documento y contraseña usando `LoginRequest` y la autenticación de sesiones de Laravel; el controlador regenera la sesión al autenticar. `logout()` cierra la autenticación y aplica invalidación de sesión y regeneración del token CSRF. Las rutas sensibles imponen un límite de intentos: inicio de sesión, cinco por minuto; registro, tres por hora por dirección IP.

### 3.3. Autenticación API y administración de tokens

`Api/AuthController` implementa `register()`, `login()`, `logout()`, `logoutAll()`, `sessions()` y `revokeSession()`. Se utiliza Sanctum para validar el token de acceso en operaciones privadas (`auth:sanctum`). El servicio crea tokens y elimina tokens vencidos mediante los métodos internos `createApiToken()` y `deleteExpiredTokens()`. La política funcional establece vencimiento de 30 días y un máximo de cinco sesiones/tokens activos. La revocación individual comprueba el token del usuario antes de eliminarlo. `UserResource` restringe qué atributos personales aparecen en las respuestas de usuario.

### 3.4. Dashboard personal

`Web/DashboardController::index()` y `Api/DashboardController::index()` producen información circunscrita al usuario autenticado. Se muestran recuentos y denuncias asociadas al ciudadano; una sesión no concede acceso a estadísticas de otros usuarios. La interfaz web está en `resources/views/dashboard.blade.php`.

### 3.5. Creación de denuncias y ubicación territorial

`Web/DenunciaController::create()` prepara catálogos para `denuncias/create.blade.php`; `store()` recibe `StoreDenunciaRequest`. El formulario permite dirección, descripción, coordenadas y selección territorial, con soporte de mapa Leaflet, cartografía OpenStreetMap y consultas Nominatim en la interfaz. El barrio es obligatorio en el alta; el municipio debe determinarse en servidor a partir del barrio asociado, no confiarse a un dato territorial arbitrario enviado por el cliente. La API implementa el mismo dominio en `Api/DenunciaController::store()` y su método auxiliar `prepareDenuncia()`.

El flujo de persistencia registra la denuncia y las relaciones de fotografías dentro de una transacción. `DenunciaPhotoService` guarda archivos en el disco privado; ante una excepción se revierte la transacción y se intenta retirar cualquier archivo que ya hubiera sido escrito. La descripción de archivos de imagen se conserva como ruta relativa y no como ruta física o URL pública.

### 3.6. Listado, detalle y control de propiedad

`Web/DenunciaController::index()` presenta las denuncias propias y `show()` ofrece su detalle con estado, ubicación, descripción, fotografías y reclamos. `Api/DenunciaController::index()` y `show()` exponen las operaciones correspondientes en JSON. `app/Policies/DenunciaPolicy.php` impide que un ciudadano consulte o reclame denuncias de otro titular. `FotoDenunciaController` (Web y API) comprueba la vinculación de la fotografía con la denuncia solicitada y la autorización del usuario.

### 3.7. Reclamos y reapertura de denuncias

`ReclamarDenunciaRequest` exige un comentario de 10 a 1000 caracteres. El modelo `Denuncia::puedeReclamar()` determina el plazo según el estado:
- `pendiente` y `en_proceso`: habilitación al cumplirse 48 horas en el estado.
- `resuelto`: reclamo disponible desde la resolución y **hasta antes de cumplirse 60 minutos**.
- `reclamado`, `rechazado` y `finalizado`: no admiten reclamo adicional bajo la lógica actual.

El controlador web realiza la operación en `DB::transaction()`, obtiene la denuncia mediante `lockForUpdate()`, ejecuta `Gate::authorize('reclamar', ...)` y registra la reclamación. Después convierte a `rechazado` las asignaciones `pendiente` o `en_proceso` vinculadas a esa denuncia, preservando las ya resueltas y sus fotografías. Finalmente coloca la denuncia en **`reclamado`** y actualiza `estado_cambiado_at`. Esta reapertura es fundamental: reclamar **no** conserva el estado anterior ni cambia simplemente a `pendiente`. La API aplica el proceso correspondiente desde `Api/DenunciaController::reclamar()`.

### 3.8. Consulta pública

`Web/ConsultaController::show()` presenta el formulario, `search()` procesa la búsqueda y `Api/ConsultaController::show()` proporciona la variante API. El acceso público se limita a los datos habilitados de la denuncia: no debe utilizarse como vía para consultar documento, correo o fotografías privadas del ciudadano. La consulta pública tiene límite de 30 solicitudes por minuto por dirección IP.

### 3.9. Perfil y supresión de cuenta

`Web/ProfileController` y `Api/ProfileController` gestionan lectura, actualización y eliminación de la cuenta. `UpdateProfileRequest` centraliza las reglas de edición; el documento permanece inmutable. La eliminación revoca sesiones/tokens, finaliza la sesión y elimina el usuario; las denuncias históricas quedan preservadas bajo la estrategia de clave foránea nullable para `denuncias.user_id`. La eliminación de una identidad no equivale a eliminación de denuncias.

### 3.10. Catálogos y fotografías

`Api/CatalogoController::municipios()` y `barrios()` proporcionan datos territoriales para los consumidores autorizados según sus rutas. El disco `denuncias_private` en `config/filesystems.php` mantiene las imágenes fuera de publicación directa; el servicio `DenunciaPhotoService` centraliza escrituras y eliminaciones. Los adjuntos de nueva denuncia requieren entre 1 y 5 imágenes JPG/JPEG o PNG, de hasta 5120 KiB cada una. Las fotografías deben solicitarse a los controladores autorizados.

---

## 4. Rutas y controladores

### 4.1. `routes/web.php`

| Método | URI declarada | Controlador | Acción |
|---|---|---|---|
| `GET` | `/consulta` | `ConsultaController` | `show()` |
| `POST` | `/consulta` | `ConsultaController` | `search()` |
| `GET` | `/register` | `AuthController` | `showRegister()` |
| `POST` | `/register` | `AuthController` | `register()` |
| `GET` | `/login` | `AuthController` | `showLogin()` |
| `POST` | `/login` | `AuthController` | `login()` |
| `POST` | `/logout` | `AuthController` | `logout()` |
| `GET` | `/dashboard` | `DashboardController` | `index()` |
| `GET` | `/denuncias` | `DenunciaController` | `index()` |
| `GET` | `/denuncias/create` | `DenunciaController` | `create()` |
| `POST` | `/denuncias` | `DenunciaController` | `store()` |
| `GET` | `/denuncias/{denuncia}/fotos/{foto}` | `FotoDenunciaController` | `show()` |
| `GET` | `/denuncias/{id}` | `DenunciaController` | `show()` |
| `POST` | `/denuncias/{id}/reclamar` | `DenunciaController` | `reclamar()` |
| `GET` | `/profile` | `ProfileController` | `edit()` |
| `PUT` | `/profile` | `ProfileController` | `update()` |
| `DELETE` | `/profile` | `ProfileController` | `destroy()` |

### 4.2. `routes/api.php`

| Método | URI declarada | Controlador | Acción |
|---|---|---|---|
| `POST` | `/register` | `AuthController` | `register()` |
| `POST` | `/login` | `AuthController` | `login()` |
| `GET` | `/municipios` | `CatalogoController` | `municipios()` |
| `GET` | `/barrios` | `CatalogoController` | `barrios()` |
| `GET` | `/consulta/{denuncia}` | `ConsultaController` | `show()` |
| `POST` | `/logout` | `AuthController` | `logout()` |
| `POST` | `/logout-all` | `AuthController` | `logoutAll()` |
| `GET` | `/sessions` | `AuthController` | `sessions()` |
| `DELETE` | `/sessions/{tokenId}` | `AuthController` | `revokeSession()` |
| `GET` | `/me` | `ProfileController` | `show()` |
| `PUT` | `/me` | `ProfileController` | `update()` |
| `DELETE` | `/me` | `ProfileController` | `destroy()` |
| `GET` | `/dashboard` | `DashboardController` | `index()` |
| `GET` | `/denuncias` | `DenunciaController` | `index()` |
| `POST` | `/denuncias` | `DenunciaController` | `store()` |
| `GET` | `/denuncias/{denuncia}/fotos/{foto}` | `FotoDenunciaController` | `show()` |
| `GET` | `/denuncias/{denuncia}` | `DenunciaController` | `show()` |
| `POST` | `/denuncias/{denuncia}/reclamar` | `DenunciaController` | `reclamar()` |

Los endpoints API se publican normalmente bajo el prefijo `/api`, según el arranque de Laravel.

### 4.3. Controladores y métodos implementados

- **`app/Http/Controllers/Api/AuthController.php`**: `register()`, `login()`, `logout()`, `logoutAll()`, `sessions()`, `revokeSession()`, `createApiToken()`, `deleteExpiredTokens()`.

- **`app/Http/Controllers/Api/CatalogoController.php`**: `municipios()`, `barrios()`.

- **`app/Http/Controllers/Api/ConsultaController.php`**: `show()`.

- **`app/Http/Controllers/Api/DashboardController.php`**: `index()`.

- **`app/Http/Controllers/Api/DenunciaController.php`**: `__construct()`, `index()`, `store()`, `show()`, `reclamar()`, `prepareDenuncia()`.

- **`app/Http/Controllers/Api/FotoDenunciaController.php`**: `show()`.

- **`app/Http/Controllers/Api/ProfileController.php`**: `show()`, `update()`, `destroy()`.

- **`app/Http/Controllers/Web/AuthController.php`**: `showRegister()`, `register()`, `showLogin()`, `login()`, `logout()`.

- **`app/Http/Controllers/Web/ConsultaController.php`**: `show()`, `search()`.

- **`app/Http/Controllers/Web/DashboardController.php`**: `index()`.

- **`app/Http/Controllers/Web/DenunciaController.php`**: `__construct()`, `index()`, `create()`, `store()`, `show()`, `reclamar()`.

- **`app/Http/Controllers/Web/FotoDenunciaController.php`**: `show()`.

- **`app/Http/Controllers/Web/ProfileController.php`**: `edit()`, `update()`, `destroy()`.

### 4.4. Reglas de validación por Form Request

- **`app/Http/Requests/LoginRequest.php`**: `documento`: `required`, `string`, `max:20`; `password`: `required`, `string`; `device_name`: `nullable`, `string`, `max:100`

- **`app/Http/Requests/ReclamarDenunciaRequest.php`**: `comentario`: `required`, `string`, `min:10`, `max:1000`

- **`app/Http/Requests/RegisterRequest.php`**: `documento`: `required`, `string`, `max:20`; `name`: `required`, `string`, `max:255`; `email`: `required`, `string`, `email`, `max:255`; `password`: `required`, `string`, `confirmed`; `telefono`: `nullable`, `string`, `max:20`; `device_name`: `nullable`, `string`, `max:100`

- **`app/Http/Requests/StoreDenunciaRequest.php`**: `barrio_id`: `required`, `integer`, `exists:barrios,id`; `municipio_id`: `nullable`, `integer`, `exists:municipios,id`; `direccion`: `required`, `string`, `max:255`; `latitud`: `required`, `numeric`, `between:-35,-30`; `longitud`: `required`, `numeric`, `between:-58,-53`; `descripcion`: `nullable`, `string`, `max:5000`; `fotos`: `required`, `array`, `min:1`, `max:5`; `fotos.*`: `required`, `file`, `image`, `mimes:jpg,jpeg,png`, `mimetypes:image/jpeg,image/png`, `max:5120`, `dimensions:max_width=8000,max_height=8000`

- **`app/Http/Requests/UpdateProfileRequest.php`**: `name`: `required`, `string`, `max:255`; `email`: `required`, `string`, `email`, `max:255`, `users`, `email`; `telefono`: `nullable`, `string`, `max:20`; `password`: `nullable`, `string`, `confirmed`


---


### 4.5. Reglas de validación por formulario

Las siguientes reglas se transcriben de los métodos `rules()` vigentes y permiten identificar con precisión qué restricciones aplica el servidor. Los permisos adicionales pueden residir en `authorize()`, middleware o policies.

#### app/Http/Requests/LoginRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'documento' => [
                'required',
                'string',
                'max:20',
            ],

            'password' => [
                'required',
                'string',
            ],

            'device_name' => [
                'nullable',
                'string',
                'max:100',
            ],
        ];
```

#### app/Http/Requests/ReclamarDenunciaRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'comentario' => [
                'required',
                'string',
                'min:10',
                'max:1000',
            ],
        ];
```

#### app/Http/Requests/RegisterRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'documento' => [
                'required',
                'string',
                'max:20',
            ],

            'name' => [
                'required',
                'string',
                'max:255',
            ],

            'email' => [
                'required',
                'string',
                'email',
                'max:255',
            ],

            'password' => [
                'required',
                'string',
                new StrongPassword(),
                'confirmed',
            ],

            'telefono' => [
                'nullable',
                'string',
                'max:20',
            ],

            /*
             * Solo es utilizado por API.
             *
             * En Web simplemente no será enviado.
             */
            'device_name' => [
                'nullable',
                'string',
                'max:100',
            ],
        ];
```

#### app/Http/Requests/StoreDenunciaRequest.php

Validación de entrada ejecutada por este Form Request:

```php
return [
            'barrio_id' => [
                'required',
                'integer',
                'exists:barrios,id',
            ],

            /*
             * El municipio no se confía al cliente.
             *
             * DenunciaController lo obtiene siempre a partir
             * del barrio seleccionado.
             */
            'municipio_id' => [
                'nullable',
                'integer',
                'exists:municipios,id',
            ],

            'direccion' => [
                'required',
                'string',
                'max:255',
            ],

            'latitud' => [
                'required',
                'numeric',
                'between:-35,-30',
            ],

            'longitud' => [
                'required',
                'numeric',
                'between:-58,-53',
            ],

            'descripcion' => [
                'nullable',
                'string',
                'max:5000',
            ],

            'fotos' => [
                'required',
                'array',
                'min:1',
                'max:5',
            ],

            'fotos.*' => [
                'required',
                'file',
                'image',
                'mimes:jpg,jpeg,png',
                'mimetypes:image/jpeg,image/png',
                'max:5120',
                'dimensions:max_width=8000,max_height=8000',
            ],
        ];
```

#### app/Http/Requests/UpdateProfileRequest.php

Validación de entrada ejecutada por este Form Request:

```php
$user = $this->user();

        return [
            'name' => [
                'required',
                'string',
                'max:255',
            ],

            'email' => [
                'required',
                'string',
                'email',
                'max:255',

                Rule::unique(
                    'users',
                    'email'
                )->ignore(
                    $user->id
                ),
            ],

            'telefono' => [
                'nullable',
                'string',
                'max:20',
            ],

            /*
             * Documento deliberadamente NO aparece aquí.
             *
             * No puede modificarse después del registro.
             */
            'password' => [
                'nullable',
                'string',
                new StrongPassword(),
                'confirmed',
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

Representa un barrio y mantiene su relación con el municipio al que pertenece.

**Métodos/relaciones declarados:** `municipio()`, `denuncias()`.

**fillable:** `municipio_id`, `nombre`.

#### `app/Models/Denuncia.php`

Representa una denuncia ciudadana. Relaciona la denuncia con su ciudadano, ubicación, fotografías, reclamaciones y asignaciones, y concentra comportamiento asociado a su estado.

**Métodos/relaciones declarados:** `estadoEnum()`, `estadoLabel()`, `puedeReclamar()`, `horasEnEstadoActual()`, `horasParaPoderReclamar()`, `minutosRestantesParaReclamar()`, `user()`, `barrio()`, `municipio()`, `fotos()`, `reclamaciones()`.

**fillable:** `barrio_id`, `municipio_id`, `direccion`, `latitud`, `longitud`, `descripcion`.

**casts:** [         'estado_cambiado_at' => 'datetime',         'latitud' => 'decimal:8',         'longitud' => 'decimal:8',     ].

**hidden:** `user_id`.

#### `app/Models/FotoDenuncia.php`

Representa una fotografía adjuntada por un ciudadano a una denuncia y mantiene su relación con la denuncia correspondiente.

**Métodos/relaciones declarados:** `denuncia()`.

**table:** 'fotos_denuncia'.

**fillable:** `ruta`.

**hidden:** `denuncia_id`, `ruta`.

#### `app/Models/Municipio.php`

Representa un municipio utilizado para clasificar territorialmente barrios, denuncias y otros recursos del sistema.

**Métodos/relaciones declarados:** `barrios()`.

**fillable:** `nombre`.

#### `app/Models/Reclamacion.php`

Representa una reclamación realizada por un ciudadano sobre una denuncia existente.

**Métodos/relaciones declarados:** `denuncia()`, `user()`.

**table:** 'reclamaciones'.

**fillable:** `comentario`.

**hidden:** `denuncia_id`, `user_id`.

#### `app/Models/User.php`

Representa a los ciudadanos registrados. Define sus relaciones con las denuncias y demás información asociada a su cuenta.

**Métodos/relaciones declarados:** `casts()`, `denuncias()`.

**fillable:** `documento`, `name`, `email`, `password`, `telefono`.

**hidden:** `password`, `remember_token`.

### 5.3. Migraciones presentes en el proyecto

- `database/migrations/0001_01_01_000000_create_users_table.php` — Crea la estructura inicial utilizada para almacenar los ciudadanos registrados.

- `database/migrations/0001_01_01_000001_create_cache_table.php` — Crea las tablas utilizadas por Laravel para almacenar información de caché.

- `database/migrations/0001_01_01_000002_create_jobs_table.php` — Crea las tablas necesarias para gestionar trabajos y colas de Laravel.

- `database/migrations/2026_06_30_185107_create_personal_access_tokens_table.php` — Crea la tabla utilizada por Laravel Sanctum para almacenar tokens de autenticación.

- `database/migrations/2026_06_30_185338_create_municipios_table.php` — Crea la tabla de municipios.

- `database/migrations/2026_06_30_185340_create_barrios_table.php` — Crea la tabla de barrios y su relación con municipios.

- `database/migrations/2026_06_30_185342_create_denuncias_table.php` — Crea la estructura principal utilizada para almacenar denuncias ciudadanas.

- `database/migrations/2026_06_30_185346_create_fotos_denuncia_table.php` — Crea la tabla que almacena las referencias a fotografías asociadas a denuncias.

- `database/migrations/2026_08_10_192024_create_reclamaciones_table.php` — Crea la tabla utilizada para registrar reclamaciones realizadas por los ciudadanos.

- `database/migrations/2026_08_23_213359_create_camiones_table.php` — Crea la tabla compartida utilizada para almacenar los camiones.

- `database/migrations/2026_08_23_224948_create_denuncia_camion_table.php` — Crea la relación entre denuncias y camiones. También mantiene el estado particular de cada asignación o tarea.

- `database/migrations/2026_08_23_224955_create_fotos_resolucion_table.php` — Crea la tabla utilizada para registrar fotografías aportadas como evidencia de la resolución de una tarea.

- `database/migrations/2026_10_17_215021_create_camion_user_table.php` — Migración que define o modifica la estructura de create camion user table.


---


## 6. Autenticación y seguridad

Autenticación web basada en sesiones; rutas API protegidas por `auth:sanctum`; registro e inicio de sesión API limitados por `throttle:3,10` y `throttle:5,1` respectivamente. La consulta pública API tiene `throttle:30,1`.

La `DenunciaPolicy` restringe operaciones sobre recursos de denuncias y los controladores de fotografía realizan comprobaciones de acceso.


---


## 7. Reglas de negocio y estados

### 7.1. Estados globales

El enum `DenunciaEstado` declara `pendiente`, `en_proceso`, `resuelto`, `reclamado`, `rechazado` y `finalizado`. El campo `denuncias.estado_cambiado_at` registra la última transición real y es obligatorio para interpretar correctamente ventanas de reclamo y finalización.

### 7.2. Reglas de oportunidad del reclamo

| Estado actual | Condición temporal | Acción permitida |
|---|---|---|
| `pendiente` | Desde las 48 horas en el estado | Reclamar |
| `en_proceso` | Desde las 48 horas en el estado | Reclamar |
| `resuelto` | Antes de cumplirse 60 minutos desde la resolución | Reclamar |
| `reclamado` | No corresponde un nuevo reclamo | No |
| `rechazado` | Estado terminal | No |
| `finalizado` | Estado terminal | No |

El cálculo utiliza `Denuncia::puedeReclamar()`, `horasEnEstadoActual()`, `horasParaPoderReclamar()` y `minutosRestantesParaReclamar()`. Una fecha futura se trata de forma conservadora y no habilita un reclamo prematuro.

### 7.3. Atomicidad y efecto del reclamo

El reclamo requiere propiedad/permiso mediante `DenunciaPolicy`, bloquea la fila con `lockForUpdate()` y se completa en una transacción. Se registra la reclamación, se rechazan las asignaciones aún activas y se actualiza la denuncia a `reclamado`; se preserva el historial de trabajos concluidos. El bloqueo coordina la operación con el proceso de finalización administrativa.

### 7.4. Integridad de denuncia y archivos

El alta combina inserciones en `denuncias` y `fotos_denuncia` con escritura de imágenes. La transacción revierte los registros cuando alguna etapa falla y la limpieza compensatoria elimina archivos recién creados. Las rutas se guardan relativas al disco `denuncias_private`; no se publican directamente.

### 7.5. Identificadores y preservación histórica

`users.id` es la clave de relaciones internas. `documento` se utiliza para autenticación e identidad ciudadana, pero no sustituye `users.id`. La eliminación de usuario no borra necesariamente las denuncias históricas; la relación permite conservarlas sin titular actual.

---

## 8. Interfaz, formularios y API

### 8.1. Pantallas Blade

La aplicación contiene 11 vistas, detalladas una por una en el diccionario.

### 8.2. API

El contrato de endpoints se enumera en la sección 4. Para integración debe revisarse también el formato efectivo de respuestas en los controladores y recursos API.


---


## 9. Fotografías y almacenamiento

Los adjuntos de denuncias se almacenan mediante `DenunciaPhotoService`; el volumen del host `/srv/recoleccion-data/fotos` se monta en `/var/www/shared-denuncias` y se sirve de modo privado por controladores web/API.


---


## 10. Configuración y despliegue

### 10.1. Configuración Docker Compose

- `container_name`: `recoleccion_api`.
- `container_name`: `recoleccion_db`.
- `image`: `mysql:8.0`.
- `APP_URL`: `http://recoleccion.neltek.uy`.
- `DB_HOST`: `db`.
- `DB_PORT`: `3306`.
- `DB_DATABASE`: `recoleccion`.
- `DENUNCIAS_PRIVATE_ROOT`: `/var/www/shared-denuncias`.
- Publicación/montaje: `192.168.30.20:8080:8080`.
- Publicación/montaje: `/srv/recoleccion-data/fotos:/var/www/shared-denuncias:rw,z`.

### 10.2. Inicialización del contenedor y EntryPoint

La Aplicación Ciudadana utiliza un contenedor Docker basado en PHP 8.2 y Apache, cuya inicialización está controlada por los archivos:

- `Dockerfile`
- `docker-compose.yml`
- `entrypoint.sh`
- `laravel.conf`

El archivo `Dockerfile` configura el entorno de ejecución, instala las extensiones PHP necesarias, incorpora Composer, copia el proyecto Laravel y prepara Apache para escuchar en el puerto 8080.

La instrucción `ENTRYPOINT ["entrypoint.sh"]` establece que el script de inicialización se ejecute cada vez que arranca el contenedor.

La instrucción `CMD ["apache2-foreground"]` define el proceso principal que se ejecutará al finalizar correctamente la inicialización.

#### 10.2.1. Preparación de permisos

El script `entrypoint.sh` comienza utilizando `set -e`, por lo que un comando que finalice con error puede detener el procedimiento de inicialización.

Posteriormente ejecuta:

```bash
chown -R www-data:www-data /var/www/html
```

Esta operación establece al usuario `www-data` como propietario de los archivos del proyecto dentro del contenedor.

El procedimiento se ejecuta en cada arranque para mantener los permisos establecidos en el script.

#### 10.2.2. Inicialización de APP_KEY

El EntryPoint verifica si la variable de entorno `APP_KEY` contiene un valor.

Cuando está vacía, ejecuta:

```bash
export APP_KEY=$(php artisan key:generate --show)
```

La clave generada se exporta al entorno del proceso para permitir que Laravel la utilice durante esa ejecución.

La implementación actual también imprime el valor generado en los registros del contenedor.

Esta última operación representa una exposición de información sensible y deberá corregirse en el código.

Adicionalmente, la generación durante el arranque no garantiza que la misma clave se conserve entre recreaciones del contenedor. En producción se debe disponer de una clave persistente y administrada de forma segura.

#### 10.2.3. Preparación del almacenamiento público

El script comprueba la existencia de la ruta:

`/var/www/html/public/storage`

Si existe un enlace simbólico o cualquier otro elemento en esa ruta, lo elimina mediante:

```bash
rm -rf /var/www/html/public/storage
```

Posteriormente ejecuta:

```bash
php artisan storage:link
```

Este comando crea el enlace simbólico utilizado por Laravel para acceder al almacenamiento público configurado.

El procedimiento no debe confundirse con el almacenamiento privado de fotografías de denuncias, cuyo directorio compartido dentro del contenedor se encuentra definido mediante `DENUNCIAS_PRIVATE_ROOT`.

#### 10.2.4. Ejecución automática de migraciones

Después de preparar el almacenamiento, el EntryPoint ejecuta:

```bash
php artisan migrate --force
```

Este comando aplica las migraciones pendientes sobre la base de datos MySQL compartida.

La opción `--force` permite ejecutar migraciones sin solicitar confirmación interactiva, incluso cuando Laravel detecta el entorno de producción.

Las migraciones están definidas en:

`recoleccion-api/database/migrations/`

Es importante destacar que el comando se ejecuta cada vez que arranca el contenedor.

Laravel registra las migraciones aplicadas en la tabla `migrations`, por lo que normalmente no vuelve a ejecutar las migraciones ya registradas.

Sin embargo, cuando existen migraciones pendientes, estas pueden modificar la estructura de tablas utilizadas también por el Backend Administrativo y la Aplicación Camiones.

Por lo tanto, cualquier modificación de migraciones deberá analizar su impacto en las tres aplicaciones antes del despliegue.

#### 10.2.5. Ejecución automática de seeders

Una vez finalizadas las migraciones, el EntryPoint ejecuta:

```bash
php artisan db:seed --force
```

Este comando invoca el seeder principal:

`database/seeders/DatabaseSeeder.php`

El seeder principal ejecuta los siguientes seeders, en este orden:

1. `MunicipiosSeeder`
2. `BarriosSeeder`
3. `CamionesSeeder`
4. `UsuariosDemoSeeder`
5. `DenunciasDemoSeeder`

**MunicipiosSeeder**

Utiliza `updateOrInsert` para crear o actualizar los registros de municipios a partir de los identificadores definidos en el código.

**BarriosSeeder**

Utiliza `updateOrInsert` para crear o actualizar barrios, identificándolos por su nombre y municipio correspondiente.

**CamionesSeeder**

Genera un conjunto reproducible de 300 matrículas sintéticas con el formato `SIM` seguido de cuatro cifras, utilizando una semilla pseudoaleatoria fija.

Contempla la conversión de 50 matrículas anteriores con el formato `STC `, conservando los identificadores y las relaciones existentes de esos vehículos.

Antes de realizar modificaciones, comprueba si existen registros con las matrículas anteriores o nuevas y detecta posibles colisiones.

Cuando encuentra una matrícula anterior que debe convertirse, actualiza la matrícula y la fecha de modificación del registro.

Cuando una matrícula nueva ya existe, conserva sus datos operativos y continúa sin sobrescribirlos.

Para los vehículos inexistentes, inserta nuevos registros con marca, modelo, municipio, estado operativo y demás atributos definidos en el seeder.

Las operaciones se ejecutan dentro de una transacción de base de datos.

**UsuariosDemoSeeder**

Genera hasta 1.000 cuentas ciudadanas sintéticas destinadas a pruebas y demostraciones.

Utiliza identificadores documentales ficticios, direcciones de correo de demostración y contraseñas generadas aleatoriamente y almacenadas mediante hash.

Los registros se insertan mediante `insertOrIgnore`, evitando sobrescribir cuentas existentes cuando se producen conflictos de unicidad.

**DenunciasDemoSeeder**

Genera hasta 10.000 denuncias sintéticas distribuidas entre diferentes estados del ciclo de vida de una denuncia.

Utiliza los usuarios de demostración, barrios y camiones sintéticos disponibles en la base de datos.

También genera, cuando corresponde, registros relacionados de asignaciones a camiones y reclamaciones.

Antes de insertar denuncias, comprueba la existencia de registros de demostración identificados por su dirección. Asimismo, evita duplicar determinadas asignaciones y reclamaciones existentes.

Las inserciones se realizan por lotes y mediante transacciones.

**Consideraciones operativas**

Los cinco seeders se ejecutan automáticamente en cada arranque del contenedor de la Aplicación Ciudadana, debido a la instrucción `php artisan db:seed --force` definida en `entrypoint.sh`.

Aunque los seeders implementan mecanismos para evitar determinadas duplicaciones y preservar registros existentes, su ejecución automática no debe considerarse completamente inocua.

En particular, los seeders de municipios y barrios utilizan operaciones de actualización, mientras que los seeders de demostración pueden incorporar registros adicionales si faltan datos sintéticos.

El seeder de camiones conserva los datos operativos de vehículos que ya tienen una matrícula `SIM`, pero contempla la conversión de las matrículas anteriores previstas en su implementación.

Por lo tanto, cualquier modificación de los seeders deberá evaluarse considerando la integridad de la base MySQL compartida y las dependencias de la Aplicación Ciudadana, el Backend Administrativo y la Aplicación Camiones.

Los seeders `UsuariosDemoSeeder` y `DenunciasDemoSeeder` forman parte de la secuencia activa definida por `DatabaseSeeder.php` y no requieren ejecución manual independiente durante el arranque normal del contenedor.

#### 10.2.6. Inicio de Apache

Después de ejecutar correctamente las tareas anteriores, el EntryPoint ejecuta:

```bash
exec "$@"
```

El comando sustituye el proceso del EntryPoint por el proceso principal definido en el Dockerfile:

```bash
apache2-foreground
```

Apache queda funcionando en primer plano, atendiendo las solicitudes de la Aplicación Ciudadana en el puerto 8080 del contenedor.

Si alguna de las operaciones anteriores falla y provoca la terminación del script, Apache no llega a iniciarse mediante este procedimiento.

#### 10.2.7. Consideraciones operativas

El orden de inicialización actual es:

1. Ajustar los propietarios de los archivos.
2. Generar `APP_KEY` si no existe.
3. Eliminar el elemento existente en `public/storage`.
4. Crear el enlace simbólico de almacenamiento.
5. Ejecutar las migraciones pendientes.
6. Ejecutar automáticamente los seeders de municipios, barrios, camiones, usuarios de demostración y denuncias de demostración.
7. Iniciar Apache.

Este procedimiento corresponde al código incluido en el proyecto analizado.

La ejecución automática de migraciones y seeders forma parte de la implementación actual y no deberá eliminarse ni modificarse sin evaluar previamente las dependencias del sistema.

Antes de actualizar migraciones o seeders en producción, deberá comprobarse el impacto sobre la base de datos compartida, las tres aplicaciones y los registros existentes.

Esta descripción documenta el comportamiento definido en los archivos del proyecto; no constituye una comprobación de su ejecución en un servidor activo.

### 10.3. Límites de comprobación

Los datos anteriores son configuración declarada en archivos; no constituyen comprobación de contenedores activos, acceso HTTPS público ni conectividad efectiva. Los archivos `.env` no se reproducen por contener parámetros sensibles.

---

## 11. Diccionario técnico de archivos

El siguiente diccionario enumera **todos los archivos de esta aplicación**, sin mezclar archivos de los otros proyectos. Las descripciones representan la responsabilidad identificable por el código y la estructura del proyecto.

### 11.1. Despliegue y raíz

| Archivo | Responsabilidad |

|---|---|

| `.dockerignore` | Evita copiar archivos innecesarios o sensibles durante la construcción de la imagen Docker. |

| `.env` | Contiene la configuración propia del entorno donde se ejecuta la aplicación. No debe almacenarse en el repositorio con contraseñas o secretos reales. |

| `docker-compose.yml` | Define los servicios necesarios para ejecutar la aplicación y MySQL, junto con sus redes y almacenamiento persistente. |

| `Dockerfile` | Define el entorno PHP y Apache utilizado para ejecutar la Aplicación Ciudadana dentro de Docker. |

| `entrypoint.sh` | Prepara Laravel al iniciar el contenedor antes de dejar disponible el servicio web. |

| `laravel.conf` | Configura Apache para que publique Laravel desde su directorio `public`. |

### 11.2. Enumeraciones

| Archivo | Responsabilidad |

|---|---|

| `app/Enums/DenunciaEstado.php` | Define en un único lugar los estados válidos de una denuncia. También concentra reglas relacionadas con los cambios permitidos entre estados. |

### 11.3. Controladores

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Controllers/Api/AuthController.php` | Gestiona el registro de ciudadanos y la autenticación mediante API. También crea y elimina las sesiones o tokens utilizados por los clientes autenticados. |

| `app/Http/Controllers/Api/CatalogoController.php` | Entrega los municipios y barrios disponibles para que los clientes puedan utilizarlos al registrar o consultar información. |

| `app/Http/Controllers/Api/ConsultaController.php` | Permite consultar información de una denuncia mediante los mecanismos públicos definidos por la API. |

| `app/Http/Controllers/Api/DashboardController.php` | Genera el resumen de denuncias y actividad utilizado por el dashboard del ciudadano. |

| `app/Http/Controllers/Api/DenunciaController.php` | Gestiona el listado, creación y consulta de denuncias pertenecientes al ciudadano autenticado. También permite registrar reclamaciones y utiliza el servicio de fotografías durante la creación de una denuncia. |

| `app/Http/Controllers/Api/FotoDenunciaController.php` | Entrega fotografías privadas de una denuncia después de verificar que el ciudadano tenga permiso para acceder a ellas. |

| `app/Http/Controllers/Api/ProfileController.php` | Gestiona la consulta y actualización de los datos personales del ciudadano autenticado. |

| `app/Http/Controllers/Controller.php` | Controlador que implementa las acciones del módulo ; recibe solicitudes, aplica comprobaciones y coordina modelos y respuestas. |

| `app/Http/Controllers/Web/AuthController.php` | Gestiona el registro, inicio de sesión y cierre de sesión desde las páginas web de la Aplicación Ciudadana. |

| `app/Http/Controllers/Web/ConsultaController.php` | Gestiona la consulta pública de una denuncia sin utilizar el panel privado del ciudadano. |

| `app/Http/Controllers/Web/DashboardController.php` | Obtiene la información que se presenta al ciudadano después de iniciar sesión, incluyendo el resumen de sus denuncias. |

| `app/Http/Controllers/Web/DenunciaController.php` | Gestiona el flujo web de las denuncias: listado, formulario de creación, registro, consulta de detalle y reclamaciones. También coordina el almacenamiento de las fotografías adjuntas. |

| `app/Http/Controllers/Web/FotoDenunciaController.php` | Entrega fotografías privadas al navegador únicamente cuando el ciudadano tiene autorización para visualizar la denuncia asociada. |

| `app/Http/Controllers/Web/ProfileController.php` | Gestiona la edición de los datos personales del ciudadano y la eliminación de su cuenta cuando corresponde. |

### 11.4. Solicitudes y validaciones

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Requests/LoginRequest.php` | Comprueba que los datos enviados para iniciar sesión tengan el formato requerido antes de intentar autenticar al ciudadano. |

| `app/Http/Requests/ReclamarDenunciaRequest.php` | Valida la información presentada por el ciudadano al registrar una reclamación sobre una denuncia. |

| `app/Http/Requests/RegisterRequest.php` | Valida los datos personales y credenciales necesarios para crear una cuenta ciudadana. |

| `app/Http/Requests/StoreDenunciaRequest.php` | Valida la ubicación, descripción y fotografías recibidas antes de registrar una nueva denuncia. |

| `app/Http/Requests/UpdateProfileRequest.php` | Controla qué datos del perfil pueden modificarse y valida sus valores antes de guardarlos. |

### 11.5. Recursos API

| Archivo | Responsabilidad |

|---|---|

| `app/Http/Resources/UserResource.php` | Archivo propio de la aplicación; revisar contenido para comportamiento preciso. |

### 11.6. Modelos

| Archivo | Responsabilidad |

|---|---|

| `app/Models/Barrio.php` | Representa un barrio y mantiene su relación con el municipio al que pertenece. |

| `app/Models/Denuncia.php` | Representa una denuncia ciudadana. Relaciona la denuncia con su ciudadano, ubicación, fotografías, reclamaciones y asignaciones, y concentra comportamiento asociado a su estado. |

| `app/Models/FotoDenuncia.php` | Representa una fotografía adjuntada por un ciudadano a una denuncia y mantiene su relación con la denuncia correspondiente. |

| `app/Models/Municipio.php` | Representa un municipio utilizado para clasificar territorialmente barrios, denuncias y otros recursos del sistema. |

| `app/Models/Reclamacion.php` | Representa una reclamación realizada por un ciudadano sobre una denuncia existente. |

| `app/Models/User.php` | Representa a los ciudadanos registrados. Define sus relaciones con las denuncias y demás información asociada a su cuenta. |

### 11.7. Políticas de autorización

| Archivo | Responsabilidad |

|---|---|

| `app/Policies/DenunciaPolicy.php` | Comprueba si un ciudadano puede visualizar o realizar acciones sobre una denuncia. Evita que un usuario acceda a denuncias pertenecientes a otro ciudadano. |

### 11.8. Proveedores

| Archivo | Responsabilidad |

|---|---|

| `app/Providers/AppServiceProvider.php` | Proveedor para registrar configuraciones y vínculos de servicios de Laravel. |

### 11.9. Reglas

| Archivo | Responsabilidad |

|---|---|

| `app/Rules/StrongPassword.php` | Define los requisitos adicionales que debe cumplir una contraseña para ser aceptada durante el registro o modificación de credenciales. |

### 11.10. Servicios

| Archivo | Responsabilidad |

|---|---|

| `app/Services/DenunciaPhotoService.php` | Centraliza el tratamiento de las fotografías cargadas por los ciudadanos. Se encarga de guardarlas y eliminarlas del almacenamiento privado sin duplicar esa lógica en los controladores. |

### 11.11. Configuración Laravel

| Archivo | Responsabilidad |

|---|---|

| `bootstrap/app.php` | Define el arranque de Laravel y registra las rutas, middleware y comportamiento general de la aplicación. |

| `bootstrap/providers.php` | Indica los proveedores adicionales que Laravel debe cargar durante el inicio. |

| `config/app.php` | Contiene la configuración general de Laravel utilizada por la Aplicación Ciudadana. |

| `config/filesystems.php` | Define los espacios de almacenamiento utilizados por Laravel, incluyendo el almacenamiento privado de fotografías de denuncias. |

### 11.12. Factories

| Archivo | Responsabilidad |

|---|---|

| `database/factories/UserFactory.php` | Archivo propio de la aplicación; revisar contenido para comportamiento preciso. |

### 11.13. Migraciones

| Archivo | Responsabilidad |

|---|---|

| `database/migrations/0001_01_01_000000_create_users_table.php` | Crea la estructura inicial utilizada para almacenar los ciudadanos registrados. |

| `database/migrations/0001_01_01_000001_create_cache_table.php` | Crea las tablas utilizadas por Laravel para almacenar información de caché. |

| `database/migrations/0001_01_01_000002_create_jobs_table.php` | Crea las tablas necesarias para gestionar trabajos y colas de Laravel. |

| `database/migrations/2026_06_30_185107_create_personal_access_tokens_table.php` | Crea la tabla utilizada por Laravel Sanctum para almacenar tokens de autenticación. |

| `database/migrations/2026_06_30_185338_create_municipios_table.php` | Crea la tabla de municipios. |

| `database/migrations/2026_06_30_185340_create_barrios_table.php` | Crea la tabla de barrios y su relación con municipios. |

| `database/migrations/2026_06_30_185342_create_denuncias_table.php` | Crea la estructura principal utilizada para almacenar denuncias ciudadanas. |

| `database/migrations/2026_06_30_185346_create_fotos_denuncia_table.php` | Crea la tabla que almacena las referencias a fotografías asociadas a denuncias. |

| `database/migrations/2026_08_10_192024_create_reclamaciones_table.php` | Crea la tabla utilizada para registrar reclamaciones realizadas por los ciudadanos. |

| `database/migrations/2026_08_23_213359_create_camiones_table.php` | Crea la tabla compartida utilizada para almacenar los camiones. |

| `database/migrations/2026_08_23_224948_create_denuncia_camion_table.php` | Crea la relación entre denuncias y camiones. También mantiene el estado particular de cada asignación o tarea. |

| `database/migrations/2026_08_23_224955_create_fotos_resolucion_table.php` | Crea la tabla utilizada para registrar fotografías aportadas como evidencia de la resolución de una tarea. |

| `database/migrations/2026_10_17_215021_create_camion_user_table.php` | Migración que define o modifica la estructura de create camion user table. |

### 11.14. Seeders

| Archivo | Responsabilidad |
|---|---|
| `database/seeders/BarriosSeeder.php` | Crea o actualiza el catálogo de barrios y sus asociaciones con municipios. |
| `database/seeders/CamionesSeeder.php` | Genera hasta 300 camiones sintéticos y contempla la conversión controlada de matrículas anteriores, conservando identificadores y relaciones existentes. |
| `database/seeders/DatabaseSeeder.php` | Define y ejecuta la secuencia de los cinco seeders activos de la Aplicación Ciudadana. |
| `database/seeders/DenunciasDemoSeeder.php` | Genera hasta 10.000 denuncias sintéticas, incluyendo asignaciones y reclamaciones relacionadas cuando corresponde. |
| `database/seeders/MunicipiosSeeder.php` | Crea o actualiza los registros del catálogo municipal. |
| `database/seeders/UsuariosDemoSeeder.php` | Genera hasta 1.000 cuentas ciudadanas sintéticas para pruebas y demostraciones. |

### 11.15. Recursos públicos

| Archivo | Responsabilidad |

|---|---|

| `public/images/bandera-uy.png` | Recurso gráfico de la interfaz. |

### 11.16. Vistas

| Archivo | Responsabilidad |

|---|---|

| `resources/views/auth/login.blade.php` | Presenta el formulario donde el ciudadano ingresa sus credenciales para acceder a la aplicación. También muestra los errores de autenticación correspondientes. |

| `resources/views/auth/register-success.blade.php` | Confirma al ciudadano que su registro fue completado correctamente y permite continuar hacia el acceso a la aplicación. |

| `resources/views/auth/register.blade.php` | Presenta el formulario de creación de cuenta y recopila los datos requeridos para registrar un ciudadano. |

| `resources/views/consulta.blade.php` | Permite ingresar los datos necesarios para consultar públicamente una denuncia y mostrar el resultado correspondiente. |

| `resources/views/dashboard.blade.php` | Presenta un resumen de la actividad del ciudadano después de iniciar sesión. |

| `resources/views/denuncias/create.blade.php` | Recopila la ubicación, descripción y fotografías necesarias para crear una nueva denuncia. Incluye los elementos de interfaz utilizados para seleccionar la ubicación de la incidencia. |

| `resources/views/denuncias/index.blade.php` | Presenta las denuncias pertenecientes al ciudadano autenticado y permite acceder al detalle de cada una. |

| `resources/views/denuncias/show.blade.php` | Presenta la información completa de una denuncia, incluyendo su ubicación, estado y fotografías. También muestra las acciones disponibles para el ciudadano según el estado actual. |

| `resources/views/layouts/app.blade.php` | Define la estructura visual compartida por las páginas ciudadanas, incluyendo navegación, encabezado y contenido principal. |

| `resources/views/profile/edit.blade.php` | Permite revisar y modificar los datos personales de la cuenta ciudadana. También contiene las acciones disponibles relacionadas con la administración del perfil. |

| `resources/views/welcome.blade.php` | Vista Blade que representa la pantalla welcome. |

### 11.17. Rutas

| Archivo | Responsabilidad |

|---|---|

| `routes/api.php` | Define los endpoints consumidos por clientes externos y los protege según requieran o no autenticación. |

| `routes/console.php` | Contiene la definición de tareas o comandos programados ejecutados por Laravel desde consola. |

| `routes/web.php` | Relaciona las URLs de la interfaz web con los controladores de autenticación, perfil, dashboard, denuncias y consulta pública. |

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
