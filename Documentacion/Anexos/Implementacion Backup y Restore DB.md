# Implementación de Backup y Restore — Recolección UY

**Actualización:** 9 de noviembre de 2026

**Alcance:** implementación y configuración del sistema de respaldo y restauración de Recolección UY en el servidor RL-APP-01 con Rocky Linux 9, utilizando scripts Bash y servicios systemd (.service y .timer) para la ejecución automática de respaldos sin utilizar crontab. Incluye el respaldo de la base de datos MySQL compartida por las tres aplicaciones, la protección de las fotografías de denuncias y resoluciones, los procedimientos de instalación, programación, ejecución, verificación de integridad, restauración de información, recuperación ante fallos y consideraciones de seguridad y mantenimiento.

---


## Índice

- [1. Objetivo](#1-objetivo)
- [2. Alcance y arquitectura](#2-alcance-y-arquitectura)
   - [2.1. Aplicaciones involucradas](#21-aplicaciones-involucradas)
   - [2.2. Servidor y componentes](#22-servidor-y-componentes)
   - [2.3. Datos protegidos](#23-datos-protegidos)
- [3. Requisitos previos](#3-requisitos-previos)
   - [3.1. Componentes necesarios](#31-componentes-necesarios)
   - [3.2. Condiciones de almacenamiento](#32-condiciones-de-almacenamiento)
- [4. Implementación del sistema de backup](#4-implementación-del-sistema-de-backup)
   - [4.1. Archivos utilizados](#41-archivos-utilizados)
   - [4.2. Instalación del script de backup](#42-instalación-del-script-de-backup)
   - [4.3. Instalación del servicio systemd](#43-instalación-del-servicio-systemd)
   - [4.4. Instalación del temporizador systemd](#44-instalación-del-temporizador-systemd)
   - [4.5. Recargar systemd](#45-recargar-systemd)
   - [4.6. Habilitar el respaldo automático](#46-habilitar-el-respaldo-automático)
   - [4.7. Comprobar la programación](#47-comprobar-la-programación)
   - [4.8. Estructura de los archivos generados](#48-estructura-de-los-archivos-generados)
   - [4.9. Ejecución manual de un backup](#49-ejecución-manual-de-un-backup)
- [5. Verificación de los respaldos](#5-verificación-de-los-respaldos)
   - [5.1. Seleccionar el respaldo](#51-seleccionar-el-respaldo)
   - [5.2. Verificar las sumas SHA-256](#52-verificar-las-sumas-sha-256)
   - [5.3. Verificar el archivo de fotografías](#53-verificar-el-archivo-de-fotografías)
   - [5.4. Verificar el archivo SQL](#54-verificar-el-archivo-sql)
- [6. Implementación del sistema de restore](#6-implementación-del-sistema-de-restore)
   - [6.1. Objetivo](#61-objetivo)
   - [6.2. Archivo utilizado](#62-archivo-utilizado)
   - [6.3. Instalación](#63-instalación)
   - [6.4. Consultar respaldos disponibles](#64-consultar-respaldos-disponibles)
   - [6.5. Verificar el último respaldo sin alterar datos](#65-verificar-el-último-respaldo-sin-alterar-datos)
   - [6.6. Seleccionar un respaldo específico](#66-seleccionar-un-respaldo-específico)
   - [6.7. Requisitos del conjunto de restauración](#67-requisitos-del-conjunto-de-restauración)
- [7. Procedimiento de restauración](#7-procedimiento-de-restauración)
   - [7.1. Preparar la ventana de mantenimiento](#71-preparar-la-ventana-de-mantenimiento)
   - [7.2. Identificar los contenedores](#72-identificar-los-contenedores)
   - [7.3. Comprobaciones anteriores](#73-comprobaciones-anteriores)
   - [7.4. Restaurar el respaldo más reciente](#74-restaurar-el-respaldo-más-reciente)
   - [7.5. Restaurar un respaldo específico](#75-restaurar-un-respaldo-específico)
   - [7.6. Confirmación obligatoria](#76-confirmación-obligatoria)
   - [7.7. Operaciones realizadas por el script](#77-operaciones-realizadas-por-el-script)
   - [7.8. Comportamiento ante errores](#78-comportamiento-ante-errores)
- [8. Validación posterior a la restauración](#8-validación-posterior-a-la-restauración)
   - [8.1. Verificar las tablas MySQL](#81-verificar-las-tablas-mysql)
   - [8.2. Verificar las fotografías](#82-verificar-las-fotografías)
   - [8.3. Reiniciar las aplicaciones](#83-reiniciar-las-aplicaciones)
   - [8.4. Verificaciones funcionales](#84-verificaciones-funcionales)
   - [8.5. Reactivar el backup automático](#85-reactivar-el-backup-automático)
- [9. Seguridad y consideraciones operativas](#9-seguridad-y-consideraciones-operativas)
   - [9.1. Protección de la información](#91-protección-de-la-información)
   - [9.2. Consistencia entre MySQL y fotografías](#92-consistencia-entre-mysql-y-fotografías)
   - [9.3. Motor de almacenamiento MySQL](#93-motor-de-almacenamiento-mysql)
   - [9.4. Permisos y SELinux](#94-permisos-y-selinux)
   - [9.5. Recuperaciones de prueba](#95-recuperaciones-de-prueba)
- [10. Administración y mantenimiento](#10-administración-y-mantenimiento)
   - [10.1. Consultar el servicio](#101-consultar-el-servicio)
   - [10.2. Consultar el temporizador](#102-consultar-el-temporizador)
   - [10.3. Consultar los registros](#103-consultar-los-registros)
   - [10.4. Consultar los respaldos](#104-consultar-los-respaldos)
   - [10.5. Política de retención](#105-política-de-retención)
   - [10.6. Copias externas](#106-copias-externas)
   - [10.7. Alertas y supervisión](#107-alertas-y-supervisión)
   - [10.8. Cambios de infraestructura](#108-cambios-de-infraestructura)
- [11. Estado de implementación](#11-estado-de-implementación)
- [12. Anexos](#12-anexos)
   - [12.1. Archivos instalados](#121-archivos-instalados)
   - [12.2. Directorios utilizados](#122-directorios-utilizados)
   - [12.3. Comandos principales de backup](#123-comandos-principales-de-backup)
   - [12.4. Comandos principales de restore](#124-comandos-principales-de-restore)
   - [12.5. Consideración final](#125-consideración-final)


---

## 1. Objetivo

Implementar un sistema de respaldo y restauración para Recolección UY mediante scripts Bash ejecutados directamente en el servidor RL-APP-01.

La solución permite proteger y recuperar:

- La base de datos MySQL compartida por las tres aplicaciones.
- La carpeta persistente que almacena las fotografías de denuncias y resoluciones.

Los respaldos se ejecutan automáticamente mediante temporizadores de systemd, sin utilizar `crontab`.

La restauración se realiza bajo demanda mediante un script independiente, con verificaciones previas y confirmación obligatoria del operador.

## 2. Alcance y arquitectura

### 2.1. Aplicaciones involucradas

| Aplicación | Relación con el respaldo |
|---|---|
| Aplicación Ciudadana | Utiliza la base de datos y las fotografías de denuncias. |
| Backend Administrativo | Utiliza la base de datos compartida y las fotografías asociadas a las denuncias. |
| Aplicación Camiones | Utiliza la base de datos compartida y los recursos fotográficos correspondientes. |

Las tres aplicaciones son proyectos Laravel 12 independientes.

El sistema de respaldo y restauración se ejecuta en la infraestructura del servidor y no requiere modificar archivos de las aplicaciones.

### 2.2. Servidor y componentes

| Componente | Configuración |
|---|---|
| Servidor | RL-APP-01 |
| Sistema operativo | Rocky Linux 9 |
| Motor de base de datos | MySQL 8.0 |
| Contenedor MySQL | `recoleccion_db` |
| Base de datos | `recoleccion` |
| Directorio de fotografías | `/srv/recoleccion-data/fotos/` |
| Directorio de respaldos | `/var/backups/recoleccion-uy/` |
| Programación | systemd |
| Servicio de respaldo | `recoleccion-uy-backup.service` |
| Temporizador | `recoleccion-uy-backup.timer` |

### 2.3. Datos protegidos

**Base de datos MySQL.** Se genera un volcado SQL comprimido de la base `recoleccion`, compartida por las tres aplicaciones.

**Fotografías.** Se respalda el contenido completo de `/srv/recoleccion-data/fotos/`, incluyendo las subcarpetas y archivos asociados a las denuncias y resoluciones.

Los dos componentes deben conservarse como parte de un mismo conjunto de respaldo.

## 3. Requisitos previos

### 3.1. Componentes necesarios

El servidor debe disponer de:

- Acceso administrativo mediante `root` o `sudo`.
- Docker y el contenedor MySQL operativo.
- Bash y Python 3.
- `tar` y `gzip`.
- `sha256sum` y `flock`.
- systemd.

El contenedor MySQL debe disponer de la variable `MYSQL_ROOT_PASSWORD`, utilizada por los scripts para autenticarse sin imprimir su contenido.

Si se utilizan Docker Secrets u otro mecanismo de autenticación, será necesario adaptar la configuración de los scripts.

### 3.2. Condiciones de almacenamiento

Debe existir espacio suficiente para:

1. Generar y almacenar el respaldo de MySQL.
2. Comprimir las fotografías.
3. Conservar respaldos anteriores.
4. Generar una copia SQL de emergencia durante una restauración.
5. Extraer temporalmente las fotografías restauradas.

## 4. Implementación del sistema de backup

### 4.1. Archivos utilizados

| Archivo | Función |
|---|---|
| `recoleccion-uy-backup.sh` | Ejecuta el respaldo de MySQL y fotografías. |
| `recoleccion-uy-backup.service` | Define el servicio systemd encargado de ejecutar el script. |
| `recoleccion-uy-backup.timer` | Programa la ejecución automática del servicio. |

Los tres archivos se instalan directamente en el host Rocky Linux 9, no dentro de los contenedores Laravel.

### 4.2. Instalación del script de backup

Ejecutar desde el directorio donde se encuentra el archivo:

```bash
sudo install -o root -g root -m 700 \
  recoleccion-uy-backup.sh \
  /usr/local/sbin/recoleccion-uy-backup.sh
```

El script queda instalado con propietario `root` y permisos `700`.

### 4.3. Instalación del servicio systemd

```bash
sudo install -o root -g root -m 644 \
  recoleccion-uy-backup.service \
  /etc/systemd/system/recoleccion-uy-backup.service
```

### 4.4. Instalación del temporizador systemd

```bash
sudo install -o root -g root -m 644 \
  recoleccion-uy-backup.timer \
  /etc/systemd/system/recoleccion-uy-backup.timer
```

La programación efectiva se define en el archivo `.timer`.

### 4.5. Recargar systemd

```bash
sudo systemctl daemon-reload
```

### 4.6. Habilitar el respaldo automático

```bash
sudo systemctl enable --now recoleccion-uy-backup.timer
```

Este comando habilita el temporizador para iniciarse automáticamente con el sistema y lo activa.

### 4.7. Comprobar la programación

```bash
sudo systemctl list-timers --all recoleccion-uy-backup.timer
```

### 4.8. Estructura de los archivos generados

```text
/var/backups/recoleccion-uy/
├── backup_AAAA-MM-DD_HHMMSS/
│   ├── database.sql.gz
│   ├── fotos.tar.gz
│   └── SHA256SUMS
└── backup_AAAA-MM-DD_HHMMSS/
    ├── database.sql.gz
    ├── fotos.tar.gz
    └── SHA256SUMS
```

| Archivo | Descripción |
|---|---|
| `database.sql.gz` | Volcado SQL comprimido de la base de datos `recoleccion`. |
| `fotos.tar.gz` | Archivo TAR comprimido con el directorio `fotos/` y su contenido. |
| `SHA256SUMS` | Sumas SHA-256 para comprobar la integridad de los archivos. |

### 4.9. Ejecución manual de un backup

Iniciar manualmente:

```bash
sudo systemctl start recoleccion-uy-backup.service
```

Comprobar su estado:

```bash
sudo systemctl status recoleccion-uy-backup.service
```

Consultar registros:

```bash
sudo journalctl -u recoleccion-uy-backup.service -n 100 --no-pager
```

Consultar respaldos:

```bash
sudo ls -lah /var/backups/recoleccion-uy/
```

## 5. Verificación de los respaldos

La existencia de los archivos no garantiza por sí sola que puedan recuperarse correctamente.

### 5.1. Seleccionar el respaldo

Sustituir `RUTA` por la carpeta real `backup_...`:

```bash
cd RUTA
```

### 5.2. Verificar las sumas SHA-256

```bash
sudo sha256sum -c SHA256SUMS
```

### 5.3. Verificar el archivo de fotografías

```bash
sudo tar -tzf fotos.tar.gz | head
```

El TAR debe contener el directorio `fotos/`.

### 5.4. Verificar el archivo SQL

```bash
sudo gzip -t database.sql.gz
```

El volcado utilizado se generó mediante `mysqldump --databases recoleccion`, por lo que incluye instrucciones para crear y seleccionar la base.

## 6. Implementación del sistema de restore

### 6.1. Objetivo

Recuperar la base de datos y las fotografías desde un conjunto de respaldo existente. La restauración es una operación administrativa manual y potencialmente destructiva.

### 6.2. Archivo utilizado

`recoleccion-uy-restore.sh`

El script pertenece a la infraestructura de RL-APP-01, no a ninguna aplicación Laravel.

### 6.3. Instalación

```bash
sudo install -o root -g root -m 700 \
  recoleccion-uy-restore.sh \
  /usr/local/sbin/recoleccion-uy-restore.sh
```

### 6.4. Consultar respaldos disponibles

```bash
sudo /usr/local/sbin/recoleccion-uy-restore.sh --list
```

### 6.5. Verificar el último respaldo sin alterar datos

```bash
sudo /usr/local/sbin/recoleccion-uy-restore.sh --latest
```

### 6.6. Seleccionar un respaldo específico

```bash
sudo /usr/local/sbin/recoleccion-uy-restore.sh \
  --backup /var/backups/recoleccion-uy/backup_AAAA-MM-DD_HHMMSS
```

Sustituir el marcador por la identificación real de una carpeta.

### 6.7. Requisitos del conjunto de restauración

```text
backup_AAAA-MM-DD_HHMMSS/
├── database.sql.gz
├── fotos.tar.gz
└── SHA256SUMS
```

El SQL debe corresponder a la base `recoleccion`, el TAR debe contener `fotos/` y los archivos deben superar las comprobaciones de integridad. El respaldo debe ser generado por el sistema de backup documentado.

## 7. Procedimiento de restauración

### 7.1. Preparar la ventana de mantenimiento

Antes de restaurar, detener los procesos que puedan modificar la base de datos o las fotografías de:

1. Aplicación Ciudadana.
2. Backend Administrativo.
3. Aplicación Camiones.

Detener también workers de colas, schedulers y procesos externos que generen denuncias o fotos.

**No detener el contenedor `recoleccion_db`.**

### 7.2. Identificar los contenedores

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

Detener los servicios pertinentes usando los respectivos archivos Docker Compose y sus directorios de despliegue.

El script no detiene ni reinicia automáticamente aplicaciones para evitar actuar sobre servicios equivocados. El operador debe confirmar que las escrituras están detenidas.

### 7.3. Comprobaciones anteriores

Verificar:

- Que no existan procesos escribiendo datos.
- Que el respaldo seleccionado sea correcto.
- Que exista espacio para un SQL de emergencia.
- Que exista espacio para extraer las fotografías.
- Que MySQL permanezca disponible.
- Que se comprenda el impacto de reemplazar la información.

La restauración puede eliminar denuncias y fotografías posteriores a la fecha del respaldo.

### 7.4. Restaurar el respaldo más reciente

```bash
sudo /usr/local/sbin/recoleccion-uy-restore.sh \
  --latest \
  --apply \
  --maintenance-confirmed
```

`--apply` habilita la restauración. `--maintenance-confirmed` declara que la ventana de mantenimiento está preparada.

### 7.5. Restaurar un respaldo específico

```bash
sudo /usr/local/sbin/recoleccion-uy-restore.sh \
  --backup /var/backups/recoleccion-uy/backup_AAAA-MM-DD_HHMMSS \
  --apply \
  --maintenance-confirmed
```

### 7.6. Confirmación obligatoria

El operador debe escribir exactamente:

```text
RESTAURAR recoleccion
```

### 7.7. Operaciones realizadas por el script

1. Valida SHA-256, gzip, el TAR y las rutas internas.
2. Comprueba que MySQL esté activo y accesible como root.
3. Obtiene un bloqueo compatible con el del script de respaldo y detiene el timer si estaba activo.
4. Genera un SQL de emergencia en `/var/backups/recoleccion-uy/pre_restauracion_FECHA/database-antes.sql.gz`.
5. Extrae las fotografías restauradas a un directorio temporal.
6. Elimina y restaura la base `recoleccion` desde `database.sql.gz`.
7. Conserva las fotos actuales como `/srv/recoleccion-data/fotos.pre-restauracion_FECHA` y coloca las restauradas en `/srv/recoleccion-data/fotos/`.
8. Mantiene las copias de emergencia; no las elimina automáticamente.

### 7.8. Comportamiento ante errores

**No existe rollback automático de MySQL.** Si la importación falla, conservar el SQL de emergencia, evaluar el estado de la base y **no reiniciar las aplicaciones** hasta resolverlo.

No combinar un SQL de un punto temporal con fotografías de otro en una recuperación que requiera consistencia estricta.

## 8. Validación posterior a la restauración

### 8.1. Verificar las tablas MySQL

```bash
docker exec recoleccion_db sh -c '
  export MYSQL_PWD="${MYSQL_ROOT_PASSWORD:?}"
  mysql -uroot recoleccion -e "SHOW TABLES;"
'
```

### 8.2. Verificar las fotografías

```bash
find /srv/recoleccion-data/fotos -type f | wc -l
ls -ldZ /srv/recoleccion-data/fotos
```

Verificar propietarios, permisos y contexto SELinux. Al restaurar en otro host puede ser necesario adaptar los identificadores de usuario y grupo.

### 8.3. Reiniciar las aplicaciones

Reiniciar los servicios de las tres aplicaciones y sus workers mediante los respectivos archivos Docker Compose, después de validar MySQL y las fotografías.

### 8.4. Verificaciones funcionales

- Inicio de sesión en las aplicaciones.
- Consulta de denuncias anteriores.
- Visualización de fotografías de denuncias.
- Visualización de fotografías de resolución.
- Acceso a los datos desde las tres aplicaciones.
- Funcionamiento normal de los módulos que dependen de los datos recuperados.

### 8.5. Reactivar el backup automático

```bash
sudo systemctl start recoleccion-uy-backup.timer
sudo systemctl list-timers --all recoleccion-uy-backup.timer
```

## 9. Seguridad y consideraciones operativas

### 9.1. Protección de la información

Los respaldos pueden contener datos personales y fotografías. Restringir los accesos y cifrar las copias externas.

### 9.2. Consistencia entre MySQL y fotografías

El volcado SQL y el TAR de fotografías se generan secuencialmente y no constituyen necesariamente una instantánea atómica. Si se requiere coherencia estricta, coordinar una ventana sin escrituras o utilizar instantáneas.

### 9.3. Motor de almacenamiento MySQL

Revisar el método de consistencia si existen tablas que no utilizan InnoDB.

### 9.4. Permisos y SELinux

La extracción conserva los permisos y propietarios almacenados en el TAR. Verificar el acceso efectivo de los contenedores después de restaurar.

### 9.5. Recuperaciones de prueba

Realizar restauraciones periódicas en un ambiente aislado. Las pruebas de integridad no sustituyen la validación funcional.

## 10. Administración y mantenimiento

### 10.1. Consultar el servicio

```bash
sudo systemctl status recoleccion-uy-backup.service
```

### 10.2. Consultar el temporizador

```bash
sudo systemctl list-timers --all recoleccion-uy-backup.timer
```

### 10.3. Consultar los registros

```bash
sudo journalctl -u recoleccion-uy-backup.service -n 100 --no-pager
```

### 10.4. Consultar los respaldos

```bash
sudo ls -lah /var/backups/recoleccion-uy/
```

### 10.5. Política de retención

La versión documentada no elimina automáticamente respaldos anteriores. Definir una política de conservación y verificar que exista espacio suficiente.

### 10.6. Copias externas

El destino actual está en el mismo host RL-APP-01 y no protege frente a pérdida total del servidor. Mantener una copia en almacenamiento independiente.

### 10.7. Alertas y supervisión

Se recomienda supervisar ejecuciones fallidas, respaldos ausentes, errores de integridad, falta de espacio y fallos en copias externas.

### 10.8. Cambios de infraestructura

Ante cambios en el contenedor MySQL, credenciales, rutas o destino de respaldo, revisar y verificar ambos scripts.

## 11. Estado de implementación

El responsable del proyecto confirmó el funcionamiento satisfactorio del mecanismo de respaldo y restauración.

| Componente | Estado informado |
|---|---|
| Script de backup | Funcionando |
| Servicio systemd | Funcionando |
| Temporizador systemd | Funcionando |
| Generación de respaldo MySQL | Funcionando |
| Respaldo de fotografías | Funcionando |
| Script de restore | Funcionando |
| Recuperación de MySQL y fotografías | Funcionamiento confirmado |
| Retención automática | No implementada en esta versión |
| Copia externa independiente | Pendiente |
| Alertas automáticas | Pendientes |

## 12. Anexos

### 12.1. Archivos instalados

```text
/usr/local/sbin/
├── recoleccion-uy-backup.sh
└── recoleccion-uy-restore.sh

/etc/systemd/system/
├── recoleccion-uy-backup.service
└── recoleccion-uy-backup.timer
```

### 12.2. Directorios utilizados

```text
/var/backups/recoleccion-uy/
├── backup_AAAA-MM-DD_HHMMSS/
│   ├── database.sql.gz
│   ├── fotos.tar.gz
│   └── SHA256SUMS
└── pre_restauracion_FECHA/
    └── database-antes.sql.gz

/srv/recoleccion-data/
├── fotos/
└── fotos.pre-restauracion_FECHA/
```

### 12.3. Comandos principales de backup

```bash
sudo systemctl enable --now recoleccion-uy-backup.timer
sudo systemctl start recoleccion-uy-backup.service
sudo systemctl status recoleccion-uy-backup.service
sudo journalctl -u recoleccion-uy-backup.service -n 100 --no-pager
sudo systemctl list-timers --all recoleccion-uy-backup.timer
```

### 12.4. Comandos principales de restore

```bash
# Listar respaldos
sudo /usr/local/sbin/recoleccion-uy-restore.sh --list

# Verificar el respaldo más reciente
sudo /usr/local/sbin/recoleccion-uy-restore.sh --latest

# Restaurar el más reciente (tras preparar mantenimiento)
sudo /usr/local/sbin/recoleccion-uy-restore.sh \
  --latest --apply --maintenance-confirmed

# Reactivar respaldos tras validar la recuperación
sudo systemctl start recoleccion-uy-backup.timer
```

### 12.5. Consideración final

El sistema protege la información central de Recolección UY mediante mecanismos separados de respaldo y restauración. Su continuidad depende de verificar los respaldos, mantener los servicios operativos y conservar copias independientes del servidor principal.

La retención automática, las alertas y la copia externa se identifican como mejoras futuras, sin alterar la implementación actual.