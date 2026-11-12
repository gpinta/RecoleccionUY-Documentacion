# Diccionario técnico de archivos — Recolección UY

**Actualización complementaria:** 12 de noviembre de 2026 — Incorporación de Zabbix Server, políticas de comunicación y agentes Windows para WS-DC-01 y WS-DC-02.

**Alcance:** este documento identifica la ubicación y responsabilidad de los archivos del proyecto. Las descripciones de **todos los archivos de las tres aplicaciones** se amplían para indicar qué hacen, cómo intervienen en el sistema y con qué componentes se relacionan. Los scripts se agrupan **por servidor** y se describen con el mismo nivel de detalle breve.


## Índice

- [1. Aplicación Ciudadana — recoleccion-api](#1-aplicación-ciudadana--recoleccion-api)
   - [1.1. Configuración principal](#11-configuración-principal)
   - [1.2. Controladores API](#12-controladores-api)
   - [1.3. Controladores Web](#13-controladores-web)
   - [1.4. Requests](#14-requests)
   - [1.5. Modelos](#15-modelos)
   - [1.6. Servicios](#16-servicios)
   - [1.7. Policies](#17-policies)
   - [1.8. Reglas de validación](#18-reglas-de-validación)
   - [1.9. Enums](#19-enums)
   - [1.10. Resources](#110-resources)
   - [1.11. Rutas](#111-rutas)
   - [1.12. Vistas de autenticación](#112-vistas-de-autenticación)
   - [1.13. Vistas generales](#113-vistas-generales)
   - [1.14. Vistas de denuncias](#114-vistas-de-denuncias)
   - [1.15. Migraciones](#115-migraciones)
      - [1.15.1. Seeders y factorías](#1151-seeders-y-factorías)
   - [1.16. Docker](#116-docker)
- [2. Backend Administrativo — recoleccion-admin](#2-backend-administrativo--recoleccion-admin)
   - [2.1. Configuración principal](#21-configuración-principal)
   - [2.2. Controladores](#22-controladores)
   - [2.3. Requests de denuncias](#23-requests-de-denuncias)
   - [2.4. Requests de autenticación y catálogos](#24-requests-de-autenticación-y-catálogos)
   - [2.5. Middleware](#25-middleware)
   - [2.6. Modelos](#26-modelos)
   - [2.7. Integración LDAP](#27-integración-ldap)
   - [2.8. Policies](#28-policies)
   - [2.9. Enums](#29-enums)
   - [2.10. Comandos](#210-comandos)
   - [2.11. Rutas](#211-rutas)
   - [2.12. Vistas generales](#212-vistas-generales)
   - [2.13. Vistas de denuncias](#213-vistas-de-denuncias)
   - [2.14. Vistas de camiones](#214-vistas-de-camiones)
   - [2.15. Vistas de barrios](#215-vistas-de-barrios)
   - [2.16. Vistas de municipios](#216-vistas-de-municipios)
   - [2.17. Docker](#217-docker)
- [3. Aplicación Camiones — recoleccion-camiones](#3-aplicación-camiones--recoleccion-camiones)
   - [3.1. Configuración y arranque](#31-configuración-y-arranque)
   - [3.2. Controladores](#32-controladores)
   - [3.3. Middleware y validación](#33-middleware-y-validación)
   - [3.4. Modelos](#34-modelos)
   - [3.5. Rutas](#35-rutas)
   - [3.6. Vistas y recursos](#36-vistas-y-recursos)
   - [3.7. Docker y entorno](#37-docker-y-entorno)
- [4. Scripts de infraestructura — agrupados por servidor](#4-scripts-de-infraestructura--agrupados-por-servidor)
   - [4.1. RL-APP-01 — aplicaciones y base de datos](#41-rl-app-01--aplicaciones-y-base-de-datos)
      - [4.1.1. RL-APP-DB_Backup_and_Restore](#411-rl-app-db_backup_and_restore)
   - [4.2. RL-FW-01 — firewall y enrutamiento](#42-rl-fw-01--firewall-y-enrutamiento)
   - [4.3. RL-PROXY-01 — publicación web y seguridad](#43-rl-proxy-01--publicación-web-y-seguridad)
   - [4.4. RL-MON-01 — monitoreo y registros](#44-rl-mon-01--monitoreo-y-registros)
   - [4.5. Administración SSH — scripts comunes de Rocky Linux](#45-administración-ssh--scripts-comunes-de-rocky-linux)
   - [4.6. WS-DC-01 y WS-DC-02 — Active Directory, DNS y DHCP](#46-ws-dc-01-y-ws-dc-02--active-directory-dns-y-dhcp)
   - [4.7. Host de administración Windows — herramientas auxiliares](#47-host-de-administración-windows--herramientas-auxiliares)
- [5. Correspondencia con el orden de despliegue](#5-correspondencia-con-el-orden-de-despliegue)
   - [5.1. Parámetros compartidos de la topología](#51-parámetros-compartidos-de-la-topología)


---

# 1. Aplicación Ciudadana — `recoleccion-api`

Aplicación Laravel utilizada por los ciudadanos para registrarse, autenticarse, crear denuncias, consultar su estado, realizar reclamaciones y administrar su perfil.

## 1.1. Configuración principal

### `bootstrap/app.php`

Define el arranque de Laravel y registra las rutas, middleware y comportamiento general de la aplicación.

Aquí se conectan las rutas con el ciclo de solicitudes HTTP y se registran los alias de middleware que utiliza el proyecto.

### `bootstrap/providers.php`

Indica los proveedores adicionales que Laravel debe cargar durante el inicio.

Permite identificar qué proveedores propios se incorporan al arranque, sin confundirlos con los paquetes instalados por Composer.

### `config/app.php`

Contiene la configuración general de Laravel utilizada por la Aplicación Ciudadana.

Agrupa parámetros de entorno, como nombre, zona horaria y comportamiento general, obtenidos de la configuración de Laravel.

### `config/filesystems.php`

Define los espacios de almacenamiento utilizados por Laravel, incluyendo el almacenamiento privado de fotografías de denuncias.

Establece los discos y sus rutas; es clave al revisar dónde persisten las fotografías y cómo acceden los controladores.

### `.env`

Contiene la configuración propia del entorno donde se ejecuta la aplicación.

No debe almacenarse en el repositorio con contraseñas o secretos reales.

Sus variables se consumen desde la configuración de Laravel y Docker; los valores secretos deben administrarse fuera de la documentación compartida.

### `app/Providers/AppServiceProvider.php`

Registra la configuración y las inicializaciones de servicios propias de la Aplicación Ciudadana.

Es el punto de registro de servicios y ajustes comunes que se aplican al iniciar esta aplicación, sin afectar a las otras dos.

## 1.2. Controladores API

### `app/Http/Controllers/Api/AuthController.php`

Gestiona el registro de ciudadanos y la autenticación mediante API.

También crea y elimina las sesiones o tokens utilizados por los clientes autenticados.

Coordina las comprobaciones de credenciales y la respuesta a cada operación de autenticación; en la API intervienen los tokens de acceso.

### `app/Http/Controllers/Api/CatalogoController.php`

Entrega los municipios y barrios disponibles para que los clientes puedan utilizarlos al registrar o consultar información.

Proporciona datos de referencia para formularios y filtros, evitando que cada cliente mantenga su propia lista de barrios y municipios.

### `app/Http/Controllers/Api/ConsultaController.php`

Permite consultar información de una denuncia mediante los mecanismos públicos definidos por la API.

Delimita los datos disponibles sin iniciar sesión, separados de la consulta privada del propietario.

### `app/Http/Controllers/Api/DashboardController.php`

Genera el resumen de denuncias y actividad utilizado por el dashboard del ciudadano.

Resume la actividad de la cuenta para que el cliente no tenga que calcular los indicadores a partir de todas sus denuncias.

### `app/Http/Controllers/Api/DenunciaController.php`

Gestiona el listado, creación y consulta de denuncias pertenecientes al ciudadano autenticado.

También registra reclamaciones y utiliza el servicio de fotografías durante la creación de una denuncia. La reclamación modifica el estado de la denuncia a `reclamado` y cierra asignaciones operativas activas, de acuerdo con la implementación disponible.

Aplica las reglas de acceso del usuario, conecta validaciones y modelos y coordina el almacenamiento de la evidencia adjunta.

### `app/Http/Controllers/Api/FotoDenunciaController.php`

Entrega fotografías privadas de una denuncia después de verificar que el ciudadano tenga permiso para acceder a ellas.

Lee el archivo desde el disco privado solamente después de autorizar el acceso a la denuncia asociada.

### `app/Http/Controllers/Api/ProfileController.php`

Gestiona la consulta y actualización de los datos personales del ciudadano autenticado.

Procesa los datos validados del perfil y mantiene separadas las operaciones de cuenta de las de denuncias.

## 1.3. Controladores Web

### `app/Http/Controllers/Web/AuthController.php`

Gestiona el registro, inicio de sesión y cierre de sesión desde las páginas web de la Aplicación Ciudadana.

Se encarga además de las redirecciones y mensajes de sesión propios del navegador.

### `app/Http/Controllers/Web/DashboardController.php`

Obtiene la información que se presenta al ciudadano después de iniciar sesión, incluyendo el resumen de sus denuncias.

Prepara los totales y listados que consume la vista principal del ciudadano.

### `app/Http/Controllers/Web/DenunciaController.php`

Gestiona el flujo web de las denuncias: listado, formulario de creación, registro, consulta de detalle y reclamaciones.

También coordina el almacenamiento de las fotografías adjuntas.

Reúne los datos de formularios y detalles; deriva la validación a Requests y el trabajo de fotografías al servicio correspondiente.

### `app/Http/Controllers/Web/FotoDenunciaController.php`

Entrega fotografías privadas al navegador únicamente cuando el ciudadano tiene autorización para visualizar la denuncia asociada.

La comprobación de propietario evita que conocer la URL de una imagen habilite su descarga.

### `app/Http/Controllers/Web/ProfileController.php`

Gestiona la edición de los datos personales del ciudadano y la eliminación de su cuenta cuando corresponde.

Conecta las operaciones permitidas de la cuenta con la validación y las respuestas visuales.

### `app/Http/Controllers/Web/ConsultaController.php`

Gestiona la consulta pública de una denuncia sin utilizar el panel privado del ciudadano.

Presenta el resultado de búsqueda pública sin exigir el flujo de autenticación del panel.

## 1.4. Requests

### `app/Http/Requests/LoginRequest.php`

Comprueba que los datos enviados para iniciar sesión tengan el formato requerido antes de intentar autenticar al ciudadano.

Mantiene la validación de entrada independiente de la consulta de credenciales.

### `app/Http/Requests/RegisterRequest.php`

Valida los datos personales y credenciales necesarios para crear una cuenta ciudadana.

Agrupa reglas del alta de ciudadanos antes de crear la cuenta en MySQL.

### `app/Http/Requests/StoreDenunciaRequest.php`

Valida la ubicación, descripción y fotografías recibidas antes de registrar una nueva denuncia.

Impide guardar ubicaciones o adjuntos fuera de los límites admitidos por el formulario.

### `app/Http/Requests/ReclamarDenunciaRequest.php`

Valida la información presentada por el ciudadano al registrar una reclamación sobre una denuncia.

Separa las condiciones de entrada de la lógica que actualiza la reclamación y sus asignaciones.

### `app/Http/Requests/UpdateProfileRequest.php`

Controla qué datos del perfil pueden modificarse y valida sus valores antes de guardarlos.

Delimita los campos actualizables para evitar cambios no autorizados mediante parámetros adicionales.

## 1.5. Modelos

### `app/Models/User.php`

Representa a los ciudadanos registrados.

Define sus relaciones con las denuncias y demás información asociada a su cuenta.

Las relaciones Eloquent permiten recuperar los registros vinculados sin repetir manualmente las claves de unión.

### `app/Models/Denuncia.php`

Representa una denuncia ciudadana.

Relaciona la denuncia con su ciudadano, ubicación, fotografías, reclamaciones y asignaciones, y concentra comportamiento asociado a su estado.

Su relación con asignaciones y reclamaciones es esencial para interpretar el estado visible en las distintas aplicaciones.

### `app/Models/FotoDenuncia.php`

Representa una fotografía adjuntada por un ciudadano a una denuncia y mantiene su relación con la denuncia correspondiente.

Conserva la referencia del archivo para recuperarlo a través de un controlador autorizado.

### `app/Models/Reclamacion.php`

Representa una reclamación realizada por un ciudadano sobre una denuncia existente.

Permite mantener el historial de reclamos diferenciado de los datos generales de la denuncia.

### `app/Models/Municipio.php`

Representa un municipio utilizado para clasificar territorialmente barrios, denuncias y otros recursos del sistema.

Es una entidad territorial compartida; su identificador se utiliza en otras tablas del ecosistema.

### `app/Models/Barrio.php`

Representa un barrio y mantiene su relación con el municipio al que pertenece.

Su relación con municipio permite validar selecciones territoriales y agrupar incidencias.

## 1.6. Servicios

### `app/Services/DenunciaPhotoService.php`

Centraliza el tratamiento de las fotografías cargadas por los ciudadanos.

Se encarga de guardarlas y eliminarlas del almacenamiento privado sin duplicar esa lógica en los controladores.

Evita que la lógica de rutas, guardado y eliminación se duplique entre el controlador web y el controlador API.

## 1.7. Policies

### `app/Policies/DenunciaPolicy.php`

Comprueba si un ciudadano puede visualizar o realizar acciones sobre una denuncia.

Evita que un usuario acceda a denuncias pertenecientes a otro ciudadano.

Centraliza la decisión de acceso en lugar de repetir comprobaciones de pertenencia o rol en cada pantalla.

## 1.8. Reglas de validación

### `app/Rules/StrongPassword.php`

Define los requisitos adicionales que debe cumplir una contraseña para ser aceptada durante el registro o modificación de credenciales.

La regla se reutiliza en las validaciones pertinentes para evitar diferencias en los criterios de contraseña.

## 1.9. Enums

### `app/Enums/DenunciaEstado.php`

Define en un único lugar los estados válidos de una denuncia.

También concentra reglas relacionadas con los cambios permitidos entre estados.

Es la referencia para identificar nombres de estado y evitar introducir transiciones inconsistentes en controladores o procesos automáticos.

## 1.10. Resources

### `app/Http/Resources/UserResource.php`

Define qué datos del ciudadano se incluyen cuando su información es enviada en una respuesta de la API.

Permite controlar el formato de salida sin exponer necesariamente todas las columnas del modelo.

## 1.11. Rutas

### `routes/web.php`

Relaciona las URLs de la interfaz web con los controladores de autenticación, perfil, dashboard, denuncias y consulta pública.

Permite localizar el recorrido entre una URL, sus middleware y la acción del controlador que genera la respuesta web.

### `routes/api.php`

Define los endpoints consumidos por clientes externos y los protege según requieran o no autenticación.

Separa las rutas públicas de las protegidas y permite reconocer los puntos de integración con clientes que consumen JSON.

### `routes/console.php`

Contiene la definición de tareas o comandos programados ejecutados por Laravel desde consola.

Centraliza los comandos y la planificación que corresponde exclusivamente a esta instalación Laravel.

## 1.12. Vistas de autenticación

### `resources/views/auth/login.blade.php`

Presenta el formulario donde el ciudadano ingresa sus credenciales para acceder a la aplicación.

También muestra los errores de autenticación correspondientes.

Envía los datos al flujo de autenticación definido por las rutas y presenta los mensajes de validación o acceso.

### `resources/views/auth/register.blade.php`

Presenta el formulario de creación de cuenta y recopila los datos requeridos para registrar un ciudadano.

La presentación de campos debe mantenerse coordinada con las reglas del Request de registro.

### `resources/views/auth/register-success.blade.php`

Confirma al ciudadano que su registro fue completado correctamente y permite continuar hacia el acceso a la aplicación.

Separa la confirmación del alta del formulario y del acceso posterior.

## 1.13. Vistas generales

### `resources/views/layouts/app.blade.php`

Define la estructura visual compartida por las páginas ciudadanas, incluyendo navegación, encabezado y contenido principal.

Concentra elementos visuales reutilizados, por lo que cualquier ajuste aquí alcanza a varias pantallas de esta aplicación.

### `resources/views/dashboard.blade.php`

Presenta un resumen de la actividad del ciudadano después de iniciar sesión.

Representa indicadores preparados por el controlador y no debe convertirse en el lugar de las reglas de negocio.

### `resources/views/consulta.blade.php`

Permite ingresar los datos necesarios para consultar públicamente una denuncia y mostrar el resultado correspondiente.

Presenta los campos de búsqueda y el resultado que devuelve el controlador de consulta pública.

### `resources/views/profile/edit.blade.php`

Permite revisar y modificar los datos personales de la cuenta ciudadana.

También contiene las acciones disponibles relacionadas con la administración del perfil.

Los cambios presentados se envían al controlador de perfil y quedan sujetos a su autorización y validación.

## 1.14. Vistas de denuncias

### `resources/views/denuncias/index.blade.php`

Presenta las denuncias pertenecientes al ciudadano autenticado y permite acceder al detalle de cada una.

La pantalla integra los datos de la incidencia y respeta las acciones habilitadas por su estado.

### `resources/views/denuncias/create.blade.php`

Recopila la ubicación, descripción y fotografías necesarias para crear una nueva denuncia.

Incluye los elementos de interfaz utilizados para seleccionar la ubicación de la incidencia.

La pantalla integra los datos de la incidencia y respeta las acciones habilitadas por su estado.

### `resources/views/denuncias/show.blade.php`

Presenta la información completa de una denuncia, incluyendo su ubicación, estado y fotografías.

También muestra las acciones disponibles para el ciudadano según el estado actual.

La pantalla integra los datos de la incidencia y respeta las acciones habilitadas por su estado.

### `resources/views/welcome.blade.php`

Vista pública de bienvenida de la Aplicación Ciudadana.

Ofrece una entrada pública a la aplicación, separada de las páginas autenticadas.

### `public/images/bandera-uy.png`

Recurso gráfico de la bandera uruguaya utilizado por la interfaz.

Es un recurso estático referenciado desde las vistas y no contiene lógica de aplicación.

## 1.15. Migraciones

### `0001_01_01_000000_create_users_table.php`

Crea la estructura inicial utilizada para almacenar los ciudadanos registrados.

Contiene columnas y restricciones de la cuenta, que deben mantenerse compatibles con los modelos de acceso.

### `0001_01_01_000001_create_cache_table.php`

Crea las tablas utilizadas por Laravel para almacenar información de caché.

Sustenta el controlador de caché basado en base de datos cuando esa opción se encuentra activa.

### `0001_01_01_000002_create_jobs_table.php`

Crea las tablas necesarias para gestionar trabajos y colas de Laravel.

Permite el almacenamiento de trabajos en cola y su control operativo.

### `2026_06_30_185107_create_personal_access_tokens_table.php`

Crea la tabla utilizada por Laravel Sanctum para almacenar tokens de autenticación.

Da soporte a Sanctum y al ciclo de vida de los tokens emitidos.

### `2026_06_30_185338_create_municipios_table.php`

Crea la tabla de municipios.

Es una tabla territorial de referencia utilizada por más de un módulo.

### `2026_06_30_185340_create_barrios_table.php`

Crea la tabla de barrios y su relación con municipios.

Establece el vínculo territorial que utilizan los formularios y búsquedas.

### `2026_06_30_185342_create_denuncias_table.php`

Crea la estructura principal utilizada para almacenar denuncias ciudadanas.

Define los campos centrales que comparten las tres aplicaciones al interpretar una incidencia.

### `2026_06_30_185346_create_fotos_denuncia_table.php`

Crea la tabla que almacena las referencias a fotografías asociadas a denuncias.

Registra metadatos de los archivos; los binarios permanecen en almacenamiento privado.

### `2026_08_10_192024_create_reclamaciones_table.php`

Crea la tabla utilizada para registrar reclamaciones realizadas por los ciudadanos.

Permite conservar reclamaciones vinculadas a denuncias registradas.

### `2026_08_23_213359_create_camiones_table.php`

Crea la tabla compartida utilizada para almacenar los camiones.

Crea la entidad compartida de flota utilizada por Administrativo y Camiones.

### `2026_08_23_224948_create_denuncia_camion_table.php`

Crea la relación entre denuncias y camiones.

También mantiene el estado particular de cada asignación o tarea.

Relaciona denuncias y vehículos sin confundir el estado operativo de la asignación con el de la incidencia.

### `2026_08_23_224955_create_fotos_resolucion_table.php`

Crea la tabla utilizada para registrar fotografías aportadas como evidencia de la resolución de una tarea.

Permite conservar referencias a evidencia generada durante el cierre de tareas.

### `2026_10_17_215021_create_camion_user_table.php`

Crea la tabla de asociación entre camiones y usuarios, utilizada para vincular una cuenta con un vehículo en la base de datos compartida.

Mantiene la asociación de cuentas y vehículos utilizada por la autenticación operativa.

## 1.15.1. Seeders y factorías

### `database/factories/UserFactory.php`

Define datos ficticios de usuarios para desarrollo y pruebas.

### `database/seeders/DatabaseSeeder.php`

Orquesta la ejecución automática de los cinco seeders de la Aplicación Ciudadana, en el siguiente orden:

1. `MunicipiosSeeder`
2. `BarriosSeeder`
3. `CamionesSeeder`
4. `UsuariosDemoSeeder`
5. `DenunciasDemoSeeder`

### `database/seeders/MunicipiosSeeder.php`

Crea o actualiza los registros del catálogo municipal mediante `updateOrInsert`.

### `database/seeders/BarriosSeeder.php`

Crea o actualiza los barrios y sus asociaciones municipales mediante `updateOrInsert`.

### `database/seeders/CamionesSeeder.php`

Genera 300 camiones sintéticos con matrículas `SIM` y distribución reproducible mediante una semilla pseudoaleatoria fija.

Contempla la conversión de 50 matrículas anteriores `STC`, conservando sus identificadores y relaciones existentes.

Evita sobrescribir los datos operativos de los camiones que ya poseen una matrícula `SIM`.

Las operaciones se realizan dentro de una transacción.

### `database/seeders/UsuariosDemoSeeder.php`

Genera hasta 1.000 cuentas ciudadanas sintéticas para pruebas.

Utiliza documentos ficticios, correos del dominio `example.invalid` y contraseñas aleatorias almacenadas mediante hash.

Emplea `insertOrIgnore` para evitar sobrescribir registros existentes ante conflictos de unicidad.

### `database/seeders/DenunciasDemoSeeder.php`

Genera hasta 10.000 denuncias sintéticas distribuidas entre los diferentes estados del sistema.

Utiliza usuarios de demostración, barrios y camiones existentes.

También genera asignaciones y reclamaciones relacionadas cuando corresponde.

Comprueba la existencia de registros antes de insertarlos y procesa las operaciones por lotes mediante transacciones.

## 1.16. Docker

### `Dockerfile`

Define el entorno PHP y Apache utilizado para ejecutar la Aplicación Ciudadana dentro de Docker.

Establece las extensiones y herramientas disponibles dentro del contenedor, así como el proceso de construcción de la imagen.

### `docker-compose.yml`

Define los servicios necesarios para ejecutar la aplicación y MySQL, junto con sus redes y almacenamiento persistente.

Determina puertos, redes, volúmenes y variables por aplicación; los cambios en recursos compartidos deben evaluarse respecto de los otros proyectos.

### `entrypoint.sh`

Prepara Laravel al iniciar el contenedor antes de dejar disponible el servicio web.

Define las tareas de inicialización del contenedor y el orden en que se preparan Laravel y los procesos del servicio.

### `laravel.conf`

Configura Apache para que publique Laravel desde su directorio `public`.

Dirige las solicitudes a la carpeta pública y permite que Apache procese las rutas de Laravel mediante su configuración web.

### `.dockerignore`

Evita copiar archivos innecesarios o sensibles durante la construcción de la imagen Docker.

Reduce el contexto enviado al construir la imagen y evita incorporar archivos locales que no forman parte del despliegue.

# 2. Backend Administrativo — `recoleccion-admin`

Aplicación Laravel utilizada por el personal autorizado para supervisar denuncias, administrar camiones, municipios y barrios, realizar asignaciones y controlar el proceso operativo.

La autenticación administrativa se realiza contra Active Directory.

## 2.1. Configuración principal

### `bootstrap/app.php`

Configura el arranque del Backend y registra sus rutas, middleware y comportamiento general.

Aquí se conectan las rutas con el ciclo de solicitudes HTTP y se registran los alias de middleware que utiliza el proyecto.

### `config/app.php`

Contiene la configuración general de Laravel utilizada por el Backend Administrativo.

Agrupa parámetros de entorno, como nombre, zona horaria y comportamiento general, obtenidos de la configuración de Laravel.

### `config/admin.php`

Centraliza parámetros propios del Backend relacionados con los roles administrativos y su integración con Active Directory.

Permite centralizar correspondencias entre grupos de Active Directory y permisos del panel, sin dispersar esas reglas en los controladores.

### `config/auth.php`

Define cómo Laravel autentica a los usuarios administrativos.

Define guardias, proveedores y mecanismos de sesión que emplea esta aplicación, sin alterar la autenticación de los otros proyectos.

### `config/ldap.php`

Configura LdapRecord y la conexión utilizada para consultar usuarios y grupos de Active Directory.

Concentra parámetros de consulta al directorio y facilita mantener la conexión LDAP separada de la lógica de negocio.

### `config/filesystems.php`

Define el acceso del Backend al almacenamiento privado donde se encuentran las fotografías de denuncias.

Establece los discos y sus rutas; es clave al revisar dónde persisten las fotografías y cómo acceden los controladores.

### `.env`

Contiene la configuración propia del entorno donde se ejecuta el Backend.

No debe almacenarse con contraseñas o secretos reales.

Sus variables se consumen desde la configuración de Laravel y Docker; los valores secretos deben administrarse fuera de la documentación compartida.

## 2.2. Controladores

### `app/Http/Controllers/Admin/AuthController.php`

Autentica usuarios administrativos contra Active Directory y crea la sesión utilizada por el Backend.

También gestiona el cierre de sesión.

Traduce la identidad y pertenencia a grupos de AD a una sesión con permisos administrativos de Laravel.

### `app/Http/Controllers/Admin/DashboardController.php`

Calcula los indicadores mostrados en el panel administrativo.

Incluye cantidades de denuncias por estado, camiones activos o inactivos, camiones asignados y denuncias pendientes de asignación.

Centraliza consultas de resumen para evitar cálculos dispersos en las plantillas Blade.

### `app/Http/Controllers/Admin/DenunciaController.php`

Concentra las principales operaciones administrativas sobre denuncias.

Permite buscar y filtrar denuncias, visualizar su detalle, modificar datos, cambiar estados, realizar asignaciones manuales o automáticas, verificar resoluciones y eliminar denuncias cuando el rol lo permite.

Es un punto sensible de integración: sus cambios de estado y asignaciones repercuten en lo que ve Ciudadana y ejecuta Camiones.

### `app/Http/Controllers/Admin/FotoDenunciaController.php`

Entrega al Backend las fotografías privadas de una denuncia después de comprobar la autorización del usuario administrativo.

Utiliza la autorización administrativa para servir imágenes desde el almacenamiento compartido sin publicarlas directamente.

### `app/Http/Controllers/Admin/CamionController.php`

Gestiona el catálogo de camiones.

Permite listarlos, filtrarlos, crearlos, modificarlos, consultar su historial de asignaciones y relacionarlos con municipios.

Sus cambios afectan el catálogo operativo y la disponibilidad de vehículos para futuras asignaciones.

### `app/Http/Controllers/Admin/BarrioController.php`

Gestiona el catálogo de barrios.

Permite crear, renombrar, asignar un municipio y eliminar barrios cuando sus relaciones existentes lo permiten.

Debe preservar la relación barrio–municipio utilizada por los filtros y las denuncias existentes.

### `app/Http/Controllers/Admin/MunicipioController.php`

Gestiona el catálogo de municipios.

Permite crearlos, renombrarlos y eliminarlos cuando no existen barrios, denuncias o camiones asociados.

Comprueba las dependencias territoriales antes de modificar o borrar registros usados en otras tablas.

### `app/Http/Controllers/Admin/FotoResolucionController.php`

Sirve las evidencias fotográficas privadas de resolución a usuarios administrativos autorizados, verificando su relación con la asignación.

Relaciona el archivo solicitado con la tarea resuelta, evitando servir evidencias por una ruta arbitraria.

## 2.3. Requests de denuncias

### `app/Http/Requests/Admin/DenunciaIndexRequest.php`

Valida los criterios utilizados para filtrar y buscar denuncias en el listado administrativo.

Normaliza los filtros y evita que parámetros inesperados lleguen a las consultas.

### `app/Http/Requests/Admin/UpdateDenunciaEstadoRequest.php`

Valida el nuevo estado solicitado para una denuncia antes de ejecutar el cambio.

Valida la intención de cambio antes de aplicar la transición sobre la denuncia.

### `app/Http/Requests/Admin/UpdateDenunciaAdminRequest.php`

Valida las modificaciones directas que un administrador puede realizar sobre los datos de una denuncia.

Define el subconjunto de atributos modificables desde la interfaz administrativa.

### `app/Http/Requests/Admin/AsignarDenunciaManualRequest.php`

Comprueba los datos utilizados para asignar manualmente una denuncia a un camión.

Comprueba los identificadores y datos de asignación antes de relacionar denuncia y vehículo.

## 2.4. Requests de autenticación y catálogos

### `app/Http/Requests/Admin/LoginRequest.php`

Valida los datos necesarios antes de intentar autenticar un usuario contra Active Directory.

Mantiene la validación de entrada independiente de la consulta de credenciales.

### `app/Http/Requests/Admin/StoreCamionRequest.php`

Valida los datos necesarios para registrar un nuevo camión.

Evita altas con datos incompletos o con formato inválido.

### `app/Http/Requests/Admin/UpdateCamionRequest.php`

Valida los cambios permitidos sobre un camión existente.

Distingue las reglas de modificación de las utilizadas en el alta.

### `app/Http/Requests/Admin/StoreBarrioRequest.php`

Valida el nombre y los datos necesarios para registrar un barrio.

Comprueba el nombre y la información territorial antes de crear el registro.

### `app/Http/Requests/Admin/UpdateBarrioRequest.php`

Valida las modificaciones permitidas sobre un barrio existente.

Valida los campos aceptados al editar el barrio existente.

### `app/Http/Requests/Admin/StoreMunicipioRequest.php`

Valida los datos necesarios para registrar un municipio.

Aplica las reglas de creación del catálogo de municipios.

### `app/Http/Requests/Admin/UpdateMunicipioRequest.php`

Valida las modificaciones permitidas sobre un municipio existente.

Valida únicamente los cambios permitidos para un municipio registrado.

## 2.5. Middleware

### `app/Http/Middleware/EnsureBackendRole.php`

Comprueba que el usuario autenticado posea uno de los roles autorizados antes de permitir el acceso a determinadas rutas del Backend.

Actúa antes de la operación solicitada para impedir que una sesión válida acceda a acciones reservadas a otro rol.

## 2.6. Modelos

### `app/Models/User.php`

Representa al ciudadano propietario de una denuncia cuando su información necesita ser consultada desde el Backend.

No representa al usuario administrativo autenticado mediante LDAP.

Las relaciones Eloquent permiten recuperar los registros vinculados sin repetir manualmente las claves de unión.

### `app/Models/Denuncia.php`

Representa una denuncia desde el Backend Administrativo.

Centraliza sus relaciones, estados y comportamiento necesario para controlar el proceso operativo.

Su relación con asignaciones y reclamaciones es esencial para interpretar el estado visible en las distintas aplicaciones.

### `app/Models/FotoDenuncia.php`

Representa las fotografías originales cargadas por el ciudadano y asociadas a una denuncia.

Conserva la referencia del archivo para recuperarlo a través de un controlador autorizado.

### `app/Models/Reclamacion.php`

Representa las reclamaciones que un ciudadano ha realizado sobre una denuncia.

Permite mantener el historial de reclamos diferenciado de los datos generales de la denuncia.

### `app/Models/Camion.php`

Representa un camión disponible para realizar tareas de recolección.

Mantiene información sobre su municipio, estado operativo y asignaciones.

Se relaciona con las asignaciones operativas y los datos que utiliza el Backend para administrar la flota.

### `app/Models/DenunciaCamion.php`

Representa una asignación entre una denuncia y un camión.

Mantiene el estado particular de la tarea, independientemente del estado general de la denuncia.

Es la entidad intermedia donde se representa el progreso de una tarea asignada a un vehículo.

### `app/Models/FotoResolucion.php`

Representa las fotografías aportadas como evidencia de que una tarea asignada fue realizada.

Vincula la evidencia guardada con la asignación correspondiente para su consulta autorizada.

### `app/Models/Barrio.php`

Representa un barrio administrado por el Backend.

Mantiene su asociación con un municipio y con las denuncias registradas en esa zona.

Su relación con municipio permite validar selecciones territoriales y agrupar incidencias.

### `app/Models/Municipio.php`

Representa un municipio y sus relaciones con barrios, denuncias y camiones.

Es una entidad territorial compartida; su identificador se utiliza en otras tablas del ecosistema.

### `app/Models/CamionUser.php`

Representa la asociación entre un camión y su cuenta de usuario, utilizada por el ecosistema para gestionar el acceso operativo de Camiones.

Mantiene la vinculación de acceso entre cuenta y vehículo sin duplicar los datos propios del camión.

## 2.7. Integración LDAP

### `app/Ldap/User.php`

Representa al usuario administrativo obtenido desde Active Directory.

Además de los datos LDAP, determina el rol de Backend correspondiente según los grupos a los que pertenece el usuario.

Separa la identidad administrativa del dominio de las cuentas ciudadanas almacenadas en MySQL.

## 2.8. Policies

### `app/Policies/DenunciaPolicy.php`

Define qué acciones sobre denuncias puede ejecutar cada rol administrativo.

Se utiliza para diferenciar operaciones de consulta, operación y administración.

Centraliza la decisión de acceso en lugar de repetir comprobaciones de pertenencia o rol en cada pantalla.

### `app/Policies/CamionPolicy.php`

Define qué usuarios pueden consultar o modificar la información relacionada con camiones.

Se utiliza en operaciones sensibles del catálogo para aplicar la autorización antes de permitir cambios.

### `app/Policies/BarrioPolicy.php`

Controla los permisos necesarios para crear, modificar, asignar municipios o eliminar barrios.

Ayuda a mantener las mismas restricciones entre el listado, la edición y la eliminación.

### `app/Policies/MunicipioPolicy.php`

Controla qué roles pueden crear, modificar o eliminar municipios.

Evita que las operaciones administrativas se habiliten únicamente por mostrar u ocultar botones en la vista.

## 2.9. Enums

### `app/Enums/DenunciaEstado.php`

Define los estados válidos de las denuncias y las transiciones utilizadas por el flujo administrativo.

Es la referencia para identificar nombres de estado y evitar introducir transiciones inconsistentes en controladores o procesos automáticos.

### `app/Enums/AdminRole.php`

Define los roles administrativos reconocidos por el Backend y centraliza las diferencias generales de permisos entre ellos.

Sus valores se utilizan como referencia para aplicar autorizaciones de manera uniforme en el panel.

### `app/Rules/StrongPassword.php`

Define validaciones de fortaleza de contraseñas cuando las operaciones del Backend las requieran.

La regla se reutiliza en las validaciones pertinentes para evitar diferencias en los criterios de contraseña.

## 2.10. Comandos

### `app/Console/Commands/FinalizarDenunciasVencidas.php`

Busca denuncias resueltas que ya cumplieron el plazo previsto y las cambia automáticamente a finalizadas.

Evita que esa actualización dependa de una intervención manual.

Se ejecuta mediante Laravel Scheduler y aplica la regla temporal de cierre sobre denuncias que reúnen las condiciones definidas.

## 2.11. Rutas

### `routes/web.php`

Define las rutas del Backend para autenticación, dashboard, denuncias, camiones, barrios y municipios.

También aplica los middleware y permisos correspondientes a cada grupo de funciones.

Permite localizar el recorrido entre una URL, sus middleware y la acción del controlador que genera la respuesta web.

### `routes/console.php`

Registra las tareas programadas que Laravel Scheduler debe ejecutar automáticamente.

Centraliza los comandos y la planificación que corresponde exclusivamente a esta instalación Laravel.

## 2.12. Vistas generales

### `resources/views/layouts/admin.blade.php`

Define la estructura compartida del Backend.

Contiene la navegación y adapta las opciones disponibles al rol del usuario autenticado.

La visibilidad de opciones complementa las autorizaciones del servidor, pero no las reemplaza.

### `resources/views/admin/auth/login.blade.php`

Presenta el formulario utilizado por los usuarios administrativos para autenticarse contra Active Directory.

Envía los datos al flujo de autenticación definido por las rutas y presenta los mensajes de validación o acceso.

### `resources/views/admin/dashboard.blade.php`

Presenta indicadores de operación del sistema.

Muestra denuncias agrupadas por estado, situación de los camiones y cantidad de denuncias todavía no asignadas.

Representa indicadores preparados por el controlador y no debe convertirse en el lugar de las reglas de negocio.

## 2.13. Vistas de denuncias

### `resources/views/admin/denuncias/index.blade.php`

Presenta el listado operativo de denuncias.

Permite aplicar filtros, consultar su estado y acceder a las acciones disponibles según el rol del usuario.

La pantalla integra los datos de la incidencia y respeta las acciones habilitadas por su estado.

### `resources/views/admin/denuncias/show.blade.php`

Presenta el detalle operativo completo de una denuncia.

Incluye datos del ciudadano, dirección, barrio, municipio, mapa, fotografías y estado, además de las acciones de cambio de estado, asignación y verificación disponibles según permisos.

La pantalla integra los datos de la incidencia y respeta las acciones habilitadas por su estado.

### `resources/views/admin/denuncias/edit.blade.php`

Permite al administrador corregir la dirección, barrio y descripción de una denuncia.

Al seleccionar un nuevo barrio, el municipio correspondiente se actualiza de acuerdo con esa relación.

La pantalla integra los datos de la incidencia y respeta las acciones habilitadas por su estado.

## 2.14. Vistas de camiones

### `resources/views/admin/camiones/index.blade.php`

Presenta el catálogo de camiones y permite consultar su situación operativa.

Desde esta pantalla se accede a las operaciones habilitadas de creación, edición y consulta.

La información se obtiene del catálogo de flota y los cambios se procesan desde los controladores administrativos.

### `resources/views/admin/camiones/create.blade.php`

Recopila los datos necesarios para registrar un nuevo camión y asociarlo a la estructura territorial correspondiente.

La información se obtiene del catálogo de flota y los cambios se procesan desde los controladores administrativos.

### `resources/views/admin/camiones/edit.blade.php`

Permite modificar los datos de identificación, estado operativo y demás información editable de un camión existente.

La información se obtiene del catálogo de flota y los cambios se procesan desde los controladores administrativos.

### `resources/views/admin/camiones/show.blade.php`

Presenta el detalle del camión, incluyendo matrícula, marca, modelo, estado operativo, municipio y situación de asignación.

También muestra el historial de denuncias que fueron asignadas al vehículo.

La información se obtiene del catálogo de flota y los cambios se procesan desde los controladores administrativos.

## 2.15. Vistas de barrios

### `resources/views/admin/barrios/index.blade.php`

Centraliza la administración de barrios.

Permite crear nuevos barrios, consultar su municipio y cantidad de denuncias, reasignarlos a otro municipio y acceder a su edición o eliminación según permisos.

La vista representa relaciones territoriales; la validación y las restricciones de borrado se aplican en el servidor.

### `resources/views/admin/barrios/edit.blade.php`

Permite modificar el nombre de un barrio existente.

La relación territorial con el municipio se administra desde el listado principal de barrios.

La vista representa relaciones territoriales; la validación y las restricciones de borrado se aplican en el servidor.

## 2.16. Vistas de municipios

### `resources/views/admin/municipios/index.blade.php`

Centraliza la administración de municipios.

Permite crear municipios y muestra cuántos barrios, denuncias y camiones están asociados a cada uno, información que también determina cuándo puede eliminarse un municipio.

La vista representa relaciones territoriales; la validación y las restricciones de borrado se aplican en el servidor.

### `resources/views/admin/municipios/edit.blade.php`

Permite modificar el nombre de un municipio existente sin alterar directamente sus relaciones con barrios, denuncias o camiones.

La vista representa relaciones territoriales; la validación y las restricciones de borrado se aplican en el servidor.

### `app/Providers/AppServiceProvider.php`

Registra el arranque y los servicios propios del Backend Administrativo.

Es el punto de registro de servicios y ajustes comunes que se aplican al iniciar esta aplicación, sin afectar a las otras dos.

### `bootstrap/providers.php`

Indica los proveedores cargados durante el arranque del Backend.

Permite identificar qué proveedores propios se incorporan al arranque, sin confundirlos con los paquetes instalados por Composer.

### `public/images/bandera-uy.png`

Recurso gráfico de la interfaz administrativa.

Es un recurso estático referenciado desde las vistas y no contiene lógica de aplicación.

## 2.17. Docker

### `Dockerfile`

Define el entorno PHP y Apache utilizado para ejecutar el Backend Administrativo dentro de Docker.

Establece las extensiones y herramientas disponibles dentro del contenedor, así como el proceso de construcción de la imagen.

### `docker-compose.yml`

Define el servicio del Backend y su integración con la base de datos y el almacenamiento privado compartido.

Determina puertos, redes, volúmenes y variables por aplicación; los cambios en recursos compartidos deben evaluarse respecto de los otros proyectos.

### `entrypoint.sh`

Prepara Laravel cuando inicia el contenedor y pone en funcionamiento los procesos necesarios para el Backend.

Define las tareas de inicialización del contenedor y el orden en que se preparan Laravel y los procesos del servicio.

### `laravel.conf`

Configura Apache para publicar el Backend desde el directorio `public` de Laravel.

Dirige las solicitudes a la carpeta pública y permite que Apache procese las rutas de Laravel mediante su configuración web.

### `.dockerignore`

Excluye archivos innecesarios o sensibles durante la construcción de la imagen Docker.

Reduce el contexto enviado al construir la imagen y evita incorporar archivos locales que no forman parte del despliegue.

# 3. Aplicación Camiones — `recoleccion-camiones`

Aplicación Laravel independiente para operación de trabajos asignados a camiones. Utiliza la misma base MySQL que Ciudadana y Administración, pero dispone de controladores, modelos, rutas, vistas y configuración Docker propios. El acceso se realiza por matrícula de camión y contraseña de su cuenta vinculada.

## 3.1. Configuración y arranque

### `app/Providers/AppServiceProvider.php`

Registra los servicios e inicializaciones de Laravel para la aplicación.

Es el punto de registro de servicios y ajustes comunes que se aplican al iniciar esta aplicación, sin afectar a las otras dos.

### `bootstrap/app.php`

Registra el arranque y el middleware `camion.activo` para proteger las rutas operativas.

Aquí se conectan las rutas con el ciclo de solicitudes HTTP y se registran los alias de middleware que utiliza el proyecto.

### `bootstrap/providers.php`

Declara los proveedores cargados por Laravel.

Permite identificar qué proveedores propios se incorporan al arranque, sin confundirlos con los paquetes instalados por Composer.

### `config/app.php`

Configuración general del entorno Laravel de Camiones.

Agrupa parámetros de entorno, como nombre, zona horaria y comportamiento general, obtenidos de la configuración de Laravel.

### `config/auth.php`

Configura autenticación y proveedor de usuarios de la aplicación.

Define guardias, proveedores y mecanismos de sesión que emplea esta aplicación, sin alterar la autenticación de los otros proyectos.

### `config/filesystems.php`

Define el disco privado `resoluciones_private` que contiene las fotografías de resolución.

Establece los discos y sus rutas; es clave al revisar dónde persisten las fotografías y cómo acceden los controladores.

## 3.2. Controladores

### `app/Http/Controllers/AsignacionController.php`

Lista y consulta las asignaciones del camión autenticado y gestiona su inicio y finalización. Excluye del trabajo activo las denuncias reclamadas, mantiene las tareas resueltas visibles y registra evidencias y comentario de cierre al finalizar.

Aplica los cambios sobre la asignación del vehículo y conserva separada la situación de la tarea del estado general de la denuncia.

### `app/Http/Controllers/AuthController.php`

Presenta el formulario de acceso; autentica por matrícula y contraseña vinculadas a un camión activo; aplica un límite de cinco intentos y administra la sesión.

Vincula el acceso a la cuenta asociada a la matrícula y aplica controles de intentos para reducir accesos indebidos.

### `app/Http/Controllers/Controller.php`

Clase base de controladores de la Aplicación Camiones.

Ofrece una clase común desde la que pueden extender los controladores específicos.

### `app/Http/Controllers/DashboardController.php`

Calcula el número de asignaciones pendientes, en proceso y resueltas correspondientes al camión autenticado.

Cuenta únicamente tareas del vehículo identificado en la sesión, no las asignaciones globales.

### `app/Http/Controllers/FotoResolucionController.php`

Entrega fotografías de resolución desde almacenamiento privado, únicamente si la asignación corresponde al camión autenticado y la ruta del archivo es válida.

Verifica la relación de la fotografía con el vehículo antes de leerla desde el volumen privado.

## 3.3. Middleware y validación

### `app/Http/Middleware/EnsureCamionActivo.php`

Comprueba en cada solicitud protegida que el usuario y el camión continúan habilitados; invalida la sesión cuando no cumplen las condiciones.

Este control complementa la autenticación inicial, porque verifica que la habilitación continúe vigente durante el uso.

### `app/Http/Requests/FinalizarAsignacionRequest.php`

Valida comentario obligatorio de 10 a 2000 caracteres y de una a cinco fotografías JPG, PNG o WEBP de hasta 5 MB por archivo.

Se ejecuta antes del guardado, de modo que el controlador reciba únicamente datos que cumplen las reglas de cierre y evidencia.

## 3.4. Modelos

### `app/Models/Camion.php`

Representa el camión y sus condiciones operativas, su cuenta de acceso y las asignaciones que le corresponden.

Se relaciona con las asignaciones operativas y los datos que utiliza el Backend para administrar la flota.

### `app/Models/CamionUser.php`

Representa la relación persistente entre usuario y camión en la base de datos compartida.

Mantiene la vinculación de acceso entre cuenta y vehículo sin duplicar los datos propios del camión.

### `app/Models/Denuncia.php`

Permite consultar los datos y estado global de una denuncia vinculada a una tarea operativa.

Su relación con asignaciones y reclamaciones es esencial para interpretar el estado visible en las distintas aplicaciones.

### `app/Models/DenunciaCamion.php`

Representa la asignación operativa y su estado propio, distinto del estado global de la denuncia.

Es la entidad intermedia donde se representa el progreso de una tarea asignada a un vehículo.

### `app/Models/FotoResolucion.php`

Representa la evidencia fotográfica de cierre de una asignación.

Vincula la evidencia guardada con la asignación correspondiente para su consulta autorizada.

### `app/Models/User.php`

Representa la cuenta que inicia sesión para operar el camión.

Las relaciones Eloquent permiten recuperar los registros vinculados sin repetir manualmente las claves de unión.

## 3.5. Rutas

### `routes/console.php`

Define los puntos de extensión de tareas de consola.

Centraliza los comandos y la planificación que corresponde exclusivamente a esta instalación Laravel.

### `routes/web.php`

Define acceso, salida, dashboard, listado y detalle de asignaciones, inicio, finalización y entrega privada de fotos bajo autenticación y `camion.activo`.

Permite localizar el recorrido entre una URL, sus middleware y la acción del controlador que genera la respuesta web.

## 3.6. Vistas y recursos

### `public/images/bandera-uy.png`

Recurso gráfico de la interfaz.

Es un recurso estático referenciado desde las vistas y no contiene lógica de aplicación.

### `resources/views/asignaciones/index.blade.php`

Listado paginado y filtrado por pendientes, en curso y completadas.

La interfaz presenta solo tareas del camión autenticado y utiliza los datos enviados por su controlador.

### `resources/views/asignaciones/show.blade.php`

Detalle de la tarea, sus acciones operativas, comentario y fotografías de resolución.

La interfaz presenta solo tareas del camión autenticado y utiliza los datos enviados por su controlador.

### `resources/views/auth/login.blade.php`

Formulario de ingreso con matrícula y contraseña.

Envía los datos al flujo de autenticación definido por las rutas y presenta los mensajes de validación o acceso.

### `resources/views/dashboard.blade.php`

Tablero de asignaciones por estado.

Representa indicadores preparados por el controlador y no debe convertirse en el lugar de las reglas de negocio.

### `resources/views/layouts/app.blade.php`

Plantilla visual compartida de Camiones.

Concentra elementos visuales reutilizados, por lo que cualquier ajuste aquí alcanza a varias pantallas de esta aplicación.

### `resources/views/welcome.blade.php`

Vista de bienvenida de Camiones.

Ofrece una entrada pública a la aplicación, separada de las páginas autenticadas.

## 3.7. Docker y entorno

### `.dockerignore`

Excluye archivos que no deben copiarse a la imagen.

Reduce el contexto enviado al construir la imagen y evita incorporar archivos locales que no forman parte del despliegue.

### `.env`

Contiene configuración local sensible, que no debe incluirse con credenciales reales en documentación ni repositorios.

Sus variables se consumen desde la configuración de Laravel y Docker; los valores secretos deben administrarse fuera de la documentación compartida.

### `docker-compose.yml`

Despliega únicamente `recoleccion_camiones`, publica `192.168.30.20:8082`, conecta `recoleccion-db-net` y monta `/srv/recoleccion-data/fotos` para las evidencias.

Determina puertos, redes, volúmenes y variables por aplicación; los cambios en recursos compartidos deben evaluarse respecto de los otros proyectos.

### `Dockerfile`

Define la imagen PHP y Apache de Camiones.

Establece las extensiones y herramientas disponibles dentro del contenedor, así como el proceso de construcción de la imagen.

### `entrypoint.sh`

Prepara el entorno Laravel al iniciar el contenedor.

Define las tareas de inicialización del contenedor y el orden en que se preparan Laravel y los procesos del servicio.

### `laravel.conf`

Configura Apache para atender la aplicación.

Dirige las solicitudes a la carpeta pública y permite que Apache procese las rutas de Laravel mediante su configuración web.

# 4. Scripts de infraestructura — agrupados por servidor

Los scripts se organizan por servidor para facilitar su localización y mantenimiento. Cada descripción resume qué prepara o modifica y su relación con el sistema. Las rutas son relativas a `RecoleccionUY/`.

## 4.1. RL-APP-01 — aplicaciones y base de datos

**Directorio:** `Scripts/Linux/RL-APP-01/`

Servidor `192.168.30.20`. Aloja los tres proyectos Laravel y la base MySQL compartida mediante Docker.

### `1-RL-APP-update.sh`

Prepara RL-APP-01 para ejecutar las aplicaciones en contenedores. Actualiza Rocky Linux 9 e instala Docker Engine, Docker Compose y herramientas de administración, además de componentes utilizados para la integración con Active Directory. Deja los servicios básicos disponibles, pero no despliega las aplicaciones.

### `2-RL-APP-config_domain_2dns_v1.3.sh`

Configura la interfaz `ens33` con la dirección `192.168.30.20/24`, la puerta de enlace de APLICACIONES y los dos DNS de Active Directory. Ajusta la identidad del servidor, realiza su integración con `neltek.uy` y configura SSSD para resolver y autenticar usuarios del dominio.

### `3-RL-APP-config_denuncias_storage_v1.1.sh`

Prepara la ubicación persistente `/srv/recoleccion-data/fotos`, compartida por las aplicaciones mediante sus respectivos montajes Docker. Crea las carpetas necesarias y ajusta propietario y permisos para que los contenedores lean o escriban fotografías de denuncias y evidencias de resolución sin depender de su almacenamiento efímero.

### `4-RL-APP-config_docker_red.sh`

Crea o reutiliza la red Docker `recoleccion-db-net` para conectar Ciudadana, Administrativo, Camiones y MySQL. Su cometido es habilitar la comunicación privada entre contenedores; no inicia las aplicaciones ni publica el puerto MySQL `3306` en el servidor.

### `5-RL-APP-install_node_exporter.sh`

Instala Node Exporter como servicio de métricas del sistema operativo. Permite que Prometheus consulte datos del host, como carga, memoria y utilización de recursos, para supervisar RL-APP-01 desde la plataforma de monitoreo.

### `6-RL-APP-install_fluent_bit.sh`

Instala y configura Fluent Bit para recopilar registros del servidor de aplicaciones. Define el procesamiento y envío de esos eventos hacia la infraestructura central de OpenSearch, facilitando la consulta de logs en un único lugar.

---

### 4.1.1. RL-APP-DB_Backup_and_Restore

**Directorio:** `Scripts/Linux/RL-APP-DB_Backup_and_Restore/`

Este módulo contiene los archivos de infraestructura utilizados para respaldar y restaurar la base de datos MySQL `recoleccion` y el almacenamiento persistente de fotografías de denuncias y resoluciones.

Se ejecuta directamente en el servidor Rocky Linux 9 `RL-APP-01`, sin modificar las aplicaciones Laravel.

#### `recoleccion-uy-backup.sh`

Genera un respaldo comprimido de la base de datos MySQL `recoleccion`, alojada en el contenedor Docker `recoleccion_db`, y del directorio `/srv/recoleccion-data/fotos/`.

Cada ejecución almacena los archivos `database.sql.gz`, `fotos.tar.gz` y `SHA256SUMS` en una carpeta identificada por fecha y hora dentro de `/var/backups/recoleccion-uy/`.

Incluye comprobaciones de integridad y mecanismos de bloqueo para evitar ejecuciones simultáneas.

#### `recoleccion-uy-backup.service`

Define el servicio systemd encargado de ejecutar el script `recoleccion-uy-backup.sh`.

Permite iniciar respaldos manualmente o mediante el temporizador correspondiente y consultar los resultados a través del journal de systemd.

#### `recoleccion-uy-backup.timer`

Define la programación automática de los respaldos mediante systemd, sin utilizar crontab.

Activa el servicio `recoleccion-uy-backup.service` según la programación configurada y permite recuperar ejecuciones omitidas mediante la opción `Persistent=true`.

#### `recoleccion-uy-restore.sh`

Permite restaurar la base de datos MySQL `recoleccion` y las fotografías desde un conjunto de respaldo previamente generado.

Verifica la integridad del respaldo, genera una copia SQL de emergencia, conserva las fotografías anteriores y requiere confirmación administrativa antes de reemplazar los datos existentes.

La restauración debe ejecutarse durante una ventana de mantenimiento, con las escrituras de las tres aplicaciones detenidas.

El script no reinicia automáticamente las aplicaciones ni realiza un rollback automático de MySQL si falla la importación.

---

## 4.2. RL-FW-01 — firewall y enrutamiento

**Directorio:** `Scripts/Linux/RL-FW-01/`

Servidor encargado de comunicar WAN, SERVICIOS, MONITOREO, APLICACIONES y DMZ mediante rutas y políticas de firewall.

### `1-RL-FW_update.sh`

Realiza la preparación inicial de `RL-FW-01`: actualiza Rocky Linux e instala NetworkManager, firewalld, SSH y utilidades de diagnóstico e integración AD. También habilita el encaminamiento IPv4 y aplica parámetros básicos de protección de red. No define todavía las interfaces ni las reglas NAT específicas del proyecto.

### `2-RL-FW-config_v1.1.sh`

Establece la topología del firewall: una interfaz WAN y cuatro interfaces internas para SERVICIOS, MONITOREO, APLICACIONES y DMZ. Configura direcciones IP, zonas y políticas de firewalld, NAT para salida a Internet y DNAT hacia el proxy, incluyendo la comunicación autorizada desde éste a los puertos `8080`, `8081` y `8082`.

### `3-RL-FW-add_MON_AD.sh`

Complementa las políticas de firewall con las comunicaciones necesarias entre monitoreo y los servicios de Active Directory. Facilita que las herramientas de supervisión y los servidores involucrados se comuniquen por los destinos y puertos previstos, sin sustituir la configuración principal de red.

### `4-RL-FW-add_Zabbix.sh`

Configura las políticas específicas de firewalld para la comunicación entre Zabbix Server en `RL-MON-01` y los agentes instalados en `WS-DC-01` y `WS-DC-02`.
Habilita los flujos autorizados TCP/10050 desde MONITOREO hacia los controladores y TCP/10051 desde los controladores hacia Zabbix Server, conservando las políticas generales del firewall.

### `RL-FW-config_domain.sh`

Integra RL-FW-01 al dominio `neltek.uy` una vez que su red y DNS están disponibles. Configura resolución del dominio, realmd, SSSD y componentes relacionados para permitir la identificación y autenticación de cuentas de Active Directory en el servidor Linux.

---

## 4.3. RL-PROXY-01 — publicación web y seguridad

**Directorio:** `Scripts/Linux/RL-PROXY-01/`

Servidor `192.168.50.20`, ubicado en DMZ. Publica los tres sitios mediante Nginx, dnsmasq, WAF y TLS.

### `1-RL-PROXY-update.sh`

Prepara RL-PROXY-01 con las herramientas de base de Rocky Linux, Docker y Docker Compose. Instala también servicios de administración, firewall y dependencias para la integración con Active Directory, dejando el host listo para desplegar los componentes de publicación web.

### `2-RL-PROXY-config_domain_2dns_v1.3.sh`

Configura la red del proxy en DMZ mediante `ens33`, la IP `192.168.50.20/24`, su gateway y los DNS de los controladores de dominio. Configura asimismo hostname, pertenencia a `neltek.uy` y autenticación mediante SSSD.

### `3-RL-PROXY-config_proxy_http.sh`

Despliega los servicios iniciales de Nginx y dnsmasq en Docker. Define la publicación HTTP de `recoleccion.neltek.uy`, `admin-recoleccion.neltek.uy` y `camiones-recoleccion.neltek.uy`, encaminando cada nombre al puerto interno correspondiente del servidor de aplicaciones.

### `4-RL-PROXY-install_WAF.sh`

Incorpora ModSecurity y las reglas OWASP Core Rule Set como capa de inspección del tráfico web. Sitúa la protección delante de los servicios publicados y conserva la separación de los tres destinos de aplicación; su objetivo es filtrar solicitudes potencialmente maliciosas.

### `5-RL-PROXY-generar_certificados_tls.sh`

Prepara el material TLS usado en la publicación segura: una autoridad certificadora interna y un certificado con nombres alternativos (SAN) para los tres sitios. Generar los certificados no cambia por sí solo el punto de escucha del proxy; esa habilitación corresponde al script de migración HTTPS.

### `6-RL-PROXY-migrar_waf_https.sh`

Adapta la publicación protegida por WAF para atender conexiones HTTPS en el puerto `443`. Incorpora los certificados, ajusta la configuración TLS y conserva el enrutamiento según el nombre de cada sitio, sustituyendo la exposición HTTP inicial del WAF.

### `7-RL-PROXY-FIX_nginx.sh`

Aplica ajustes correctivos específicos a la configuración de Nginx utilizada por el proxy. Está pensado para complementar el despliegue de publicación existente, no para reemplazar desde cero la instalación de Nginx, dnsmasq o WAF.

### `8-RL-PROXY-install_node_exporter.sh`

Instala Node Exporter en RL-PROXY-01 para exponer métricas de funcionamiento del host. Permite que el servidor de monitoreo supervise recursos del proxy y detecte cambios en su carga o disponibilidad.

### `9-RL-PROXY-install_fluent_bit.sh`

Configura Fluent Bit para capturar registros generados en el servidor de publicación y transmitirlos al sistema central de logs. Facilita correlacionar eventos del proxy con los de las aplicaciones en OpenSearch.

---

## 4.4. RL-MON-01 — monitoreo y registros

**Directorio:** `Scripts/Linux/RL-MON-01/`

Servidor `192.168.20.20`. Centraliza las métricas de infraestructura y los registros enviados por otros hosts.

### `1-RL-MON-update.sh`

Actualiza Rocky Linux en RL-MON-01 e instala herramientas y dependencias previas a los servicios de supervisión. Establece una base administrable para el despliegue posterior de Prometheus, Grafana y OpenSearch.

### `2-RL-MON-config_domain_2dns_v1.3.sh`

Configura la dirección `192.168.20.20/24` en la red MONITOREO, su ruta de salida y los servidores DNS de Active Directory. Incorpora el equipo al dominio `neltek.uy` y prepara SSSD para la autenticación de identidades del dominio.

### `3-RL-MON-monitoreo.sh`

Despliega y configura los componentes de monitoreo de métricas basados en Prometheus y Grafana. Permite recopilar información de los exporters autorizados y visualizarla en paneles de seguimiento de la infraestructura.

### `4-RL-MON-OpenSearch.sh`

Prepara OpenSearch y los componentes de consulta de registros centralizados. Proporciona el destino donde pueden almacenarse y analizarse los eventos enviados por Fluent Bit desde otros servidores del proyecto.

### `5-RL-MON-Zabbix.sh`

Despliega Zabbix Server y Zabbix Web mediante Docker Compose en `RL-MON-01` (`192.168.20.20`).
Utiliza una base MySQL independiente de la base compartida por las tres aplicaciones Laravel. Publica Zabbix Server en TCP/10051 y Zabbix Web en TCP/8088, dentro de la red de MONITOREO.

### `RL-MON-add_dashboard_general.sh`

Incorpora un dashboard general de Recolección UY a la plataforma de monitoreo. Su función es reunir indicadores de varios componentes en una vista común para facilitar el seguimiento operativo.

---

## 4.5. Administración SSH — scripts comunes de Rocky Linux

**Directorio:** `Scripts/Linux/RL-XXX-XX/`

Scripts reutilizables para administración de servidores Rocky Linux; no pertenecen exclusivamente a un host.

### `1-RL-XXX-config_ssh.sh`

Aplica una configuración común de seguridad SSH en servidores Rocky Linux. Establece parámetros de acceso remoto y restricciones administrativas para que la gestión por SSH siga criterios uniformes en los hosts donde se utiliza.

### `2-RL-XXX-config_ssh_users.sh`

Gestiona los usuarios habilitados para acceder por SSH y sus claves públicas autorizadas. Complementa las reglas generales del servicio SSH con la definición de las identidades que pueden administrar el servidor.

---

## 4.6. WS-DC-01 y WS-DC-02 — Active Directory, DNS y DHCP

**Directorio:** `Scripts/Windows/Windows Server 2012 r2/`

WS-DC-01 (`192.168.10.20`) y WS-DC-02 (`192.168.10.21`) proporcionan servicios de dominio y resolución de nombres. Los scripts de dominio se ejecutan desde WS-DC-01; los de configuración local de RDP se aplican en ambos controladores.

### `1-AD_Config_RecoleccionUY.ps1`

Crea o verifica la organización de Active Directory utilizada por el proyecto, incluyendo unidades organizativas, grupos y cuentas administrativas o de servicio. Su enfoque es preparar los objetos que consumen las políticas y aplicaciones, evitando duplicar los ya existentes.

### `2-WS-DC_Config_Local.ps1`

Configura ajustes locales de cada controlador de dominio, especialmente DNS del adaptador y administración remota por RDP. Habilita los componentes necesarios para conexiones con NLA y aplica las reglas de firewall correspondientes; requiere los parámetros adecuados para WS-DC-01 o WS-DC-02.

### `3-WS-DC_RDP_Gestionar_Origenes.ps1`

Administra las direcciones IP y redes desde las cuales se permite una conexión RDP a los controladores. Incluye operaciones para consultar, agregar o retirar orígenes y permite mantener restringido el acceso administrativo sin rehacer manualmente toda la regla.

### `4-AD_Politica_Contrasenas_Dominio.ps1`

Establece controles de seguridad para las contraseñas del dominio, como longitud mínima, complejidad, historial, expiración y bloqueo ante intentos fallidos. Centraliza estas reglas de Active Directory para aplicarlas coherentemente a las cuentas comprendidas.

### `5-GPO_Equipos_Inactividad.ps1`

Crea y vincula una directiva de grupo destinada a equipos del dominio. Configura medidas de inactividad, como bloqueo de sesión y apagado de pantalla, para reducir la exposición de sesiones que quedan desatendidas.

### `5-GPO_Equipos_Inactividad_Excepciones.ps1`

Gestiona las excepciones de aplicación de la GPO de inactividad ya creada. Permite excluir o volver a incluir determinados equipos según las necesidades operativas sin modificar la regla general para el resto del dominio.

### `6-DNS_RegistroA_RecoleccionUY_v1.3.ps1`

Crea o actualiza en DNS los registros A de Ciudadana, Administrativo y Camiones. Los tres nombres se orientan hacia el proxy de DMZ y el script utiliza la variable `$ProxyServerIP` para señalar su dirección (`192.168.50.20`).

### `7-WS-DC-Zabbix_Agent.ps1`

Instala y configura Zabbix Agent clásico en los controladores Windows Server 2012 R2.
Se ejecuta localmente en `WS-DC-01` y `WS-DC-02`, configura la comunicación con Zabbix Server (`192.168.20.20`), la regla de firewall TCP/10050 y la auditoría de eventos Windows.
Su ejecución requiere que Zabbix Server esté preparado y que las comunicaciones correspondientes estén autorizadas en `RL-FW-01`.

### `WS-DC-01-zabbix-import.yaml`

Archivo de importación específico de `WS-DC-01` para Zabbix Web. Define la configuración de monitoreo del controlador principal, incluyendo elementos y disparadores relacionados con eventos Windows.
Su importación se realiza manualmente desde la interfaz web de Zabbix.

### `WS-DC-02-zabbix-import.yaml`

Archivo de importación específico de `WS-DC-02` para Zabbix Web. Define la configuración de monitoreo del controlador adicional, incluyendo elementos y disparadores relacionados con eventos Windows.
Su importación se realiza manualmente desde la interfaz web de Zabbix.

**Aplicación por servidor:** `1`, `4`, `5`, `5-...Excepciones` y `6` corresponden a la administración de dominio desde WS-DC-01; `2`, `3` y `7-WS-DC-Zabbix_Agent.ps1` se ejecutan localmente en ambos controladores, con los parámetros correspondientes a cada servidor. Los archivos YAML de Zabbix se importan manualmente desde Zabbix Web.

---

## 4.7. Host de administración Windows — herramientas auxiliares

**Directorio:** `Scripts/Windows/Windows/`

Herramientas de apoyo usadas desde el equipo de administración Windows. Se complementan con `Scripts/Windows/README.md`.

### `HOST_CredSSP_Habilitar_Temporal.ps1`

Habilita de forma temporal CredSSP en el equipo Windows desde el que se realizan determinadas tareas de administración remota. Se utiliza cuando una operación necesita delegación de credenciales y debe ir acompañado de la restauración posterior.

### `HOST_CredSSP_Restaurar.ps1`

Revierte la configuración temporal de CredSSP aplicada al host de administración. Permite volver al estado habitual una vez terminadas las operaciones remotas que necesitaron delegación.

---

# 5. Correspondencia con el orden de despliegue

1. **VMware y segmentación:** preparar SERVICIOS `192.168.10.0/24`, MONITOREO `192.168.20.0/24`, APLICACIONES `192.168.30.0/24` y DMZ `192.168.50.0/24`.
2. **WS-DC-01 y WS-DC-02:** instalar y configurar AD DS, DNS y DHCP, incorporar el controlador adicional y ejecutar los scripts de dominio y de configuración local según su servidor.
3. **RL-FW-01:** preparar el firewall, configurar interfaces, routing, NAT/DNAT, integración al dominio y políticas de acceso entre segmentos.
4. **RL-APP-01:** configurar red, AD, almacenamiento en `/srv/recoleccion-data/fotos` y red Docker `recoleccion-db-net`; desplegar de manera independiente Ciudadana, Administrativo y Camiones, compartiendo MySQL. Incorporar el módulo `RL-APP-DB_Backup_and_Restore` para respaldar automáticamente la base de datos y las fotografías mediante systemd, y disponer del procedimiento de restauración administrativa.
5. **RL-PROXY-01:** configurar red y AD; publicar los sitios con Nginx y dnsmasq, incorporar WAF, certificados TLS y HTTPS.
6. **DNS y publicación:** mantener los tres registros A orientados a `192.168.50.20` y las reglas de publicación correspondientes.
7. **RL-MON-01:** configurar Prometheus, Grafana, OpenSearch y Zabbix Server; integrar Node Exporter y Fluent Bit de APP y PROXY. Para completar el monitoreo Windows, aplicar `4-RL-FW-add_Zabbix.sh` en RL-FW-01, ejecutar `7-WS-DC-Zabbix_Agent.ps1` en ambos controladores e importar sus archivos YAML desde Zabbix Web.
8. **Administración:** aplicar controles SSH/RDP y permisos del dominio según el servidor, respetando los mecanismos de recuperación.

## 5.1. Parámetros compartidos de la topología

| Componente | Dirección o configuración |
|---|---|
| Dominio AD | `neltek.uy` |
| WS-DC-01 | `192.168.10.20` |
| WS-DC-02 | `192.168.10.21` |
| RL-FW-01 | WAN `ens33`; SERVICIOS `192.168.10.1`; MONITOREO `192.168.20.1`; APLICACIONES `192.168.30.1`; DMZ `192.168.50.1` |
| RL-APP-01 | `192.168.30.20` |
| RL-PROXY-01 | `192.168.50.20` |
| RL-MON-01 | `192.168.20.20` |
| Ciudadana | `recoleccion.neltek.uy` → `192.168.30.20:8080` (vía proxy) |
| Administrativo | `admin-recoleccion.neltek.uy` → `192.168.30.20:8081` (vía proxy) |
| Camiones | `camiones-recoleccion.neltek.uy` → `192.168.30.20:8082` (vía proxy) |
| Base de datos | MySQL en red Docker `recoleccion-db-net`, sin publicación del puerto 3306 |
| Proxy | Nginx, dnsmasq, WAF ModSecurity/OWASP CRS y TLS |
| Monitoreo | Prometheus, Grafana, OpenSearch, Node Exporter, Fluent Bit y Zabbix Server; agentes Zabbix en `WS-DC-01` y `WS-DC-02` |

**Criterio documental:** los componentes del proyecto están operativos y probados conforme al estado confirmado por su responsable. Este diccionario es una referencia de ubicación y responsabilidad de archivos, no un instructivo de ejecución.
