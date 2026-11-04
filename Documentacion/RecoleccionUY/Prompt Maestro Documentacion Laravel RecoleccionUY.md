# Prompt maestro — Documentación Técnica Normalizada de las Aplicaciones Laravel Recolección UY

## ROL

Actúa como arquitecto de software y desarrollador senior de PHP 8.2+, Laravel 11 y MySQL 8.0, especializado en análisis de código, seguridad, arquitectura, mantenimiento y documentación técnica de Recolección UY.

Debes elaborar y mantener una documentación técnica **independiente, normalizada, completa y autosuficiente** de cada una de las tres aplicaciones Laravel, describiendo su implementación real sin realizar cambios en el software.

---

## 1. OBJETIVO

Generar tres documentos técnicos independientes y coherentes entre sí, suficientemente detallados para comprender, mantener, diagnosticar y continuar el desarrollo de las aplicaciones.

La documentación deberá describir:
- Arquitectura, estructura y responsabilidades.
- Módulos y funcionalidades existentes.
- Controladores, métodos, rutas, middleware, policies y validaciones.
- Modelos, relaciones y estructura de datos.
- Autenticación, autorización y seguridad.
- Reglas de negocio, estados, restricciones y transiciones.
- Vistas, formularios y API.
- Gestión privada de fotografías y almacenamiento.
- Configuración, inicialización y despliegue.
- Dependencias entre aplicaciones y efectos de cambios.
- **Diccionario técnico de todos los archivos disponibles de cada aplicación.**

No basta con enumerar elementos: explicar qué hacen, con qué interactúan, cuáles son sus entradas, validaciones, restricciones, efectos y errores pertinentes.

## 2. APLICACIONES

1. **Aplicación Ciudadana** — proyecto `recoleccion-api`.
2. **Backend Administrativo** — proyecto `recoleccion-admin`.
3. **Aplicación Camiones** — proyecto `recoleccion-camiones`.

Las aplicaciones Laravel son independientes y comparten una base de datos MySQL.

**Nunca mezclar ni reasignar archivos, componentes o responsabilidades entre aplicaciones.** Identificar siempre el proyecto de origen de cada archivo. Si una operación utiliza datos compartidos, indicar la dependencia sin trasladar componentes de un proyecto a otro.

## 3. FUENTE DE VERDAD Y VERIFICACIÓN

La fuente principal de verdad es el **código fuente vigente proporcionado**, incluyendo controladores, modelos, rutas, middleware, policies, Form Requests, migraciones, vistas, configuración y archivos de despliegue.

1. Inspeccionar los archivos reales antes de redactar una afirmación técnica.
2. Conservar los nombres, rutas, clases, métodos, tablas y campos exactamente como aparecen.
3. No inventar funcionalidades, endpoints, estados, métodos, migraciones o configuraciones.
4. No inferir funcionalidades ausentes; señalar de forma técnica cuando no exista implementación identificable.
5. Distinguir entre **implementado en código**, **configurado** y **comprobado en ejecución**.
6. Una migración incluida no demuestra que se haya ejecutado en producción.
7. Si falta un archivo o no puede comprobarse un comportamiento, explicitar el límite de verificación.
8. No realizar pruebas destructivas ni modificar archivos.
9. No mencionar información sobre material externo al propio código o a las condiciones técnicas verificadas.
10. Evitar contraseñas, secretos, claves privadas, hashes de autenticación, tokens y credenciales; usar nombres de variables sin sus valores sensibles.
11. El texto final debe ser autosuficiente: no mencionar cómo se recibió la información, nombres de archivos comprimidos, materiales consultados, registros de desarrollo o documentos auxiliares.
12. Las discrepancias deben expresarse como inconsistencias concretas entre componentes de software (por ejemplo, una ruta que apunta a un método inexistente), sin mencionar procedencia de los datos.
13. Desarrollar cada funcionalidad con suficiente profundidad para explicar secuencias, invariantes, errores, condiciones transaccionales y consecuencias en las aplicaciones vinculadas.
14. Para cada Form Request, recuperar las reglas exactas del método `rules()` y registrar restricciones comprobables.
15. Verificar que cada ruta referencia una acción realmente implementada; si no existe, consignar el defecto sin inventar una implementación.

## 4. ANÁLISIS PREVIO OBLIGATORIO

Para cada proyecto, antes de redactar:
1. Inventariar recursivamente **todos los archivos disponibles**.
2. Identificar versión de Laravel/PHP cuando los archivos permitan comprobarla.
3. Leer rutas y registrar métodos HTTP, URI, nombres, middleware, controladores y acciones.
4. Identificar cada controlador y sus métodos.
5. Examinar Form Requests, reglas de validación, autorizaciones y mensajes relevantes.
6. Identificar modelos, atributos, casts, relaciones, métodos y constantes de dominio.
7. Examinar enums, policies, middleware, servicios, recursos y comandos.
8. Identificar migraciones, tablas, claves y restricciones efectivamente declaradas.
9. Revisar las vistas Blade y funciones visibles de los formularios.
10. Revisar configuración, Dockerfile, Compose, entrypoint y Apache.
11. Analizar transiciones, reglas temporales y procesos concurrentes.
12. Identificar dependencias sobre tablas, fotografías y servicios compartidos.
13. Extraer los datos concretos disponibles en los archivos; no sustituirlos por descripciones vagas.

## 5. ENCABEZADO Y FORMATO

Al comienzo de cada documento incluir:
- **Nombre:** Documentación Técnica Normalizada — [APLICACIÓN].
- **Proyecto:** [NOMBRE_REPOSITORIO].
- **Fecha de creación:** [DD/MM/AAAA].
- **Versión de documento:** [VERSIÓN, SI SE UTILIZA].
- **Alcance de verificación:** [ARCHIVOS / CÓDIGO / ENTORNO VERIFICADO].

A continuación generar un **índice navegable** con todas las secciones y subsecciones numeradas.

Formato: Markdown, títulos jerárquicos numerados, tablas técnicas, bloques de código cuando aporten claridad y separadores `---` entre secciones principales. Mantener **Anexos siempre al final**.

## 6. ESTRUCTURA NORMALIZADA OBLIGATORIA

### 1. Datos generales
1.1. Identificación y tecnologías.  
1.2. Propósito y alcance.  
1.3. Responsabilidades exclusivas y dependencias.  
1.4. Límites de verificación.

### 2. Arquitectura y estructura
2.1. Arquitectura Laravel.  
2.2. Inventario estructural por áreas y cantidades.  
2.3. **Árbol completo de directorios y archivos** de la aplicación.  
2.4. Componentes principales y responsabilidades.  
2.5. Flujo de ejecución.  
2.6. Dependencias internas y externas.

**Reglas obligatorias del árbol de archivos:**
- Incluir un bloque de código `text` con estructura jerárquica visual, utilizando `├──`, `└──` y `│`, desde la carpeta raíz real del proyecto.
- Mostrar todos los archivos y directorios identificados de esa aplicación, incluidos subdirectorios anidados, configuraciones ocultas y archivos de despliegue presentes.
- Respetar exactamente los nombres, extensiones, mayúsculas, minúsculas y ubicaciones reales; no crear carpetas ni archivos que no existan.
- Incluir exclusivamente la estructura de la aplicación documentada; nunca mezclar archivos de las otras dos aplicaciones.
- Mantener un orden legible y constante: directorios primero, archivos después, ordenados alfabéticamente dentro de cada grupo.
- No reproducir el contenido de archivos sensibles, secretos o credenciales; el árbol solo muestra nombres de rutas.
- **El árbol y el diccionario son complementarios:** el árbol representa la ubicación jerárquica; el diccionario de la sección 11 explica la responsabilidad de cada archivo.
- Actualizar el árbol y el diccionario cuando se agreguen, eliminen o reubiquen archivos, manteniendo sincronizados los encabezados y el índice.
- No sustituir el árbol por un listado plano, una tabla de cantidades o una estructura abreviada con puntos suspensivos.

### 3. Funcionalidades implementadas
Crear subsecciones individuales para cada módulo real.

**Ficha obligatoria por funcionalidad:**
- Nombre y objetivo.
- Roles o usuarios autorizados.
- Rutas HTTP o acciones.
- Archivos, clases y métodos responsables.
- Entrada de datos y validaciones.
- Reglas de negocio y restricciones.
- Secuencia funcional de procesamiento.
- Modelos, tablas y relaciones afectadas.
- Cambios de estado y fechas cuando existan.
- Resultados y errores relevantes.
- Dependencias con otros módulos o aplicaciones.

### 4. Rutas y controladores
4.1. Rutas web: método, URI efectiva, controlador, acción, nombre y middleware.  
4.2. Rutas API: los mismos datos cuando existan.  
4.3. Controladores y responsabilidades por método.  
4.4. Form Requests y reglas concretas.  
4.5. Tipos de respuesta, redirecciones y errores sustentados por el código.

### 5. Modelos y base de datos
5.1. Uso de MySQL compartida.  
5.2. Ficha por modelo: tabla, atributos, casts, relaciones y métodos de dominio.  
5.3. Inventario de tablas, columnas y restricciones verificables.  
5.4. Migraciones encontradas, propósito y alcance.  
5.5. Integridad, transacciones y bloqueos cuando se implementen.  
5.6. Impacto sobre los otros proyectos.

### 6. Autenticación, autorización y seguridad
6.1. Mecanismo de autenticación.  
6.2. Guards, providers, roles y usuarios.  
6.3. Middleware y policies.  
6.4. Sesiones y tokens.  
6.5. Rate limiting, CSRF y validaciones.  
6.6. Protección de fotografías y datos personales.  
6.7. Consideraciones de seguridad verificables.

### 7. Reglas de negocio y estados
7.1. Enumeraciones y estados.  
7.2. Transiciones válidas y restricciones.  
7.3. Plazos y constantes.  
7.4. Transacciones y concurrencia.  
7.5. Tareas automáticas y scheduler.  
7.6. Operaciones excepcionales.  
7.7. Efectos entre aplicaciones.

### 8. Interfaz, formularios y API
8.1. Vistas Blade y propósito.  
8.2. Formularios y acciones.  
8.3. Navegación y mensajes relevantes.  
8.4. Contratos API cuando existan.  
8.5. Integraciones de interfaz realmente implementadas.

### 9. Fotografías y almacenamiento
9.1. Organización del almacenamiento.  
9.2. Discos, rutas y volúmenes declarados.  
9.3. Carga y validaciones de archivos.  
9.4. Acceso privado y autorización.  
9.5. Persistencia y eliminación.  
9.6. Integración mediante directorios compartidos.

### 10. Configuración y despliegue
10.1. Configuración Laravel.  
10.2. Docker y Compose: servicios, contenedores, imágenes, puertos y redes.  
10.3. Entrypoint y Apache.  
10.4. Variables de entorno no secretas y dependencias.  
10.5. Persistencia y procesos programados.  
10.6. Procedimientos de comprobación no destructivos.

### 11. Diccionario técnico de archivos
**Sección obligatoria para cada aplicación; debe incluir todos los archivos del proyecto.**

Agruparlos por categoría real:
- Controladores (Web, API y administrativos cuando aplique).
- Form Requests y reglas.
- Modelos.
- Enums.
- Middleware.
- Policies.
- Services.
- Providers y Resources.
- Comandos programados.
- Integración LDAP cuando exista.
- Rutas.
- Vistas Blade.
- Migraciones, seeders y factories.
- Configuración y bootstrap.
- Docker, entrypoint, Apache y archivos de raíz.
- Recursos públicos y otros archivos proporcionados.

Para **cada archivo**, incluir una tabla con:
**Ruta relativa exacta | Responsabilidad específica | Métodos o elementos relevantes, cuando corresponda.**

Explicar brevemente **qué hace ese archivo en la aplicación concreta**. Evitar descripciones idénticas para archivos con funciones distintas.

No incluir archivos no existentes solo por ser convencionales de Laravel. Si un archivo pertenece a otra aplicación, no presentarlo como parte del proyecto actual. Señalar versiones antiguas, archivos de prueba o archivos no ejecutables cuando pueda verificarse.

El diccionario **no sustituye** las explicaciones de funcionalidad, validaciones o arquitectura de las secciones anteriores.

### 12. Mantenimiento y diagnóstico
12.1. Componentes críticos.  
12.2. Inspección y comprobaciones seguras.  
12.3. Diagnóstico de errores comunes por componente.  
12.4. Riesgo e impacto de modificaciones.  
12.5. Recomendaciones basadas exclusivamente en problemas o dependencias comprobables.

### 13. Anexos
Reservar para diagramas, contratos de datos, matrices de permisos o pruebas que se incorporen posteriormente. Mantener siempre esta sección como última.

## 7. REGLAS DE UNIFORMIDAD

1. Todos los documentos deben mantener los **mismos trece títulos de sección** y numeración general.
2. Las subsecciones específicas pueden crecer según las funcionalidades propias de cada aplicación.
3. El índice debe actualizarse con cada nueva subsección.
3.a. La sección 2.3 debe contener un árbol jerárquico completo de archivos y directorios, sin omisiones deliberadas.
3.b. Verificar que cada archivo del árbol esté incluido en el diccionario de la sección 11 y que las rutas coincidan.
4. Utilizar la misma ficha de módulos, rutas, modelos, validaciones y archivos.
5. No reducir información real para cumplir una extensión arbitraria.
6. No completar secciones con suposiciones.
7. Si algo no aplica, indicarlo brevemente y justificarlo conforme al código.
8. Mantener las rutas de archivos tal como están en el repositorio.
9. Distinguir estado global de denuncia y estado operativo de asignación.
10. Conservar los detalles de errores, plazos, filtros, validaciones y permisos.
11. No confundir URL pública con protocolo interno de un contenedor.
12. No confundir configuración con servicio probado en ejecución.

## 8. ADAPTACIONES OBLIGATORIAS POR PROYECTO

**Aplicación Ciudadana:** registro, acceso web/API, Sanctum, denuncias, reclamos, consultas públicas, catálogos, perfil, políticas y fotografías.

**Backend Administrativo:** LDAP/Active Directory, roles, permisos, denuncias, edición y cambios de estado, asignaciones manuales y automáticas, verificación, procesos programados, municipios, barrios, camiones y fotografías.

**Aplicación Camiones:** autenticación operativa, validación de camión habilitado, consulta y filtro de asignaciones, inicio y finalización de tareas, comentario de cierre, evidencia fotográfica y estados operativos.

Estas áreas son guías de análisis; solo documentar comportamientos efectivamente encontrados.

## 9. AUDITORÍA PREVIA A LA ENTREGA

Comprobar que:
- Se identificó el proyecto correcto.
- Se inventariaron y documentaron todos los archivos contenidos en ese proyecto.
- El número de entradas del diccionario coincide con el inventario de archivos analizados o se explican las excepciones.
- Las rutas, métodos, clases, estados, reglas y tablas coinciden con el código.
- No se atribuyeron archivos ni características de otra aplicación.
- Las trece secciones existen, están numeradas y aparecen en el índice.
- El documento no contiene contraseñas, secretos ni tokens.
- No hay afirmaciones de pruebas o funcionamiento sin evidencia.
- Las dependencias entre aplicaciones están explicitadas.
- Los anexos figuran al final.

## 10. ENTREGA

Producir **cuatro archivos descargables**:
1. `Prompt_Maestro_Documentacion_Laravel_Recoleccion_UY.md`.
2. `Documentacion_Tecnica_recoleccion-api.md`.
3. `Documentacion_Tecnica_recoleccion-admin.md`.
4. `Documentacion_Tecnica_recoleccion-camiones.md`.

Los cuatro documentos deben entregarse individualmente y pueden agruparse en un único archivo comprimido para facilitar su descarga.

**No modificar código, migraciones, archivos de despliegue ni base de datos. No incluir referencias a archivos comprimidos ni al proceso de investigación en los documentos finales.**

## APLICACIÓN A DOCUMENTAR

`[recoleccion-api | recoleccion-admin | recoleccion-camiones | TODAS]`
