# 31 - Primary Root Setup - Orquestador Principal

## Script Orquestador del Nodo Primario

Este es el **script más importante** del despliegue primario. Coordina la ejecución secuencial de todos los pasos necesarios para construir un nodo primario de Oracle Data Guard completamente funcional, desde la preparación de discos hasta la instalación de cron jobs.

## Ubicación

`2-Standby/scripts/primary/root_setup.sh`

## Propósito

- **Función principal:** Orquestador maestro que coordina los 12 pasos del despliegue primario
- **Responsabilidad:** Ejecutar scripts en el orden correcto, con el usuario apropiado
- **Garantía:** Si este script completa exitosamente, el nodo primario está listo para Data Guard

## Cuándo se Ejecuta

- **Llamado por:** `setup.sh` con privilegios sudo
- **Orden:** Paso 2 de 12 (es el orquestador que llama a los pasos 3-12)
- **Usuario:** `root` (invocado via sudo)
- **Duración:** 35-45 minutos (todo el proceso de provisionamiento primario)

## Variables de Entorno Utilizadas

Carga todas las variables desde `install.env`:

### Variables de Configuración de Nodos

```bash
NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain    # Hostname del nodo primario
NODE1_PUBLIC_IP=192.168.56.101              # IP del nodo primario
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain    # Hostname del nodo standby
NODE2_PUBLIC_IP=192.168.56.102              # IP del nodo standby
```

### Variables de Oracle

```bash
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=${ORACLE_BASE}/product/21.0.0/dbhome_1
ORA_INVENTORY=/u01/app/oraInventory
ORACLE_SID=cdb1
PDB_NAME=pdb1
NODE1_DB_UNIQUE_NAME=cdb1
NODE2_DB_UNIQUE_NAME=cdb1_stby
```

### Variables de Contraseñas

```bash
ROOT_PASSWORD=rootpasswd
ORACLE_PASSWORD=oracle
SYS_PASSWORD="S1sPassword1!"
PDB_PASSWORD="PdbPassword1!"
```

### Variables de Data Guard

```bash
ARCHIVE_LAG_TARGET=300          # 5 minutos
REDO_LOG_SIZE=50                # 50MB
PROTECTION_MODE=MAXAVAILABILITY
TRANSPORT_MODE=FASTSYNC
FRA_SIZE=100G
```

## Flujo de Ejecución Paso a Paso

### Paso 1: Cargar Variables de Entorno

```bash
. /vagrant_config/install.env
```

**Explicación:**
- Carga todas las variables de configuración desde el archivo compartido
- El punto (`.`) ejecuta el script en el contexto shell actual (no en subshell)
- `/vagrant_config/` es un synced folder definido en Vagrantfile

**Verificación:**
```bash
echo "ORACLE_BASE: ${ORACLE_BASE}"
echo "ORACLE_SID: ${ORACLE_SID}"
```

### Paso 2: Banner de Inicio

```bash
echo "******************************************************************************"
echo "PRIMARY Root Setup Started." `date`
echo "******************************************************************************"
```

**Explicación:**
- Marca el inicio del proceso de provisionamiento
- Timestamp para calcular duración total

### Paso 3: Preparar Discos u01 y u02

```bash
sh /vagrant_scripts/prepare_u01_u02_disks.sh
```

**Explicación:**
- **Usuario:** root (necesario para fdisk, mkfs, mount)
- **Qué hace:**
  - Particiona `/dev/sdb` → `/u01` (Oracle software + datos)
  - Particiona `/dev/sdc` → `/u02` (backups + FRA)
  - Crea filesystem XFS
  - Monta permanentemente en `/etc/fstab`
  - Crea estructura de directorios

**Duración:** 30-60 segundos

**Ver detalles:** [32 - Prepare Disks](32-prepare-disks.md)

### Paso 4: Instalar Paquetes del Sistema Operativo

```bash
sh /vagrant_scripts/install_os_packages.sh
```

**Explicación:**
- **Usuario:** root (necesario para dnf install)
- **Qué hace:**
  - Instala `oracle-database-preinstall-21c` (crea usuario oracle, grupos, kernel params)
  - Instala 48 paquetes adicionales requeridos
  - Configura kernel parameters para Data Guard
  - Deshabilita SELinux y firewalld

**Duración:** 5-10 minutos (depende de velocidad de internet)

**Ver detalles:** [33 - Install Packages](33-install-packages.md)

### Paso 5: Configurar Contraseñas de Usuarios

```bash
echo "******************************************************************************"
echo "Set root and oracle password and change ownership." `date`
echo "******************************************************************************"
echo -e "${ROOT_PASSWORD}\n${ROOT_PASSWORD}" | passwd
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | passwd oracle
chown -R oracle:oinstall /u01 /u02
chmod -R 775 /u01 /u02
```

**Explicación:**
- Establece contraseña para usuario `root` (rootpasswd)
- Establece contraseña para usuario `oracle` (oracle) - creado por oracle-database-preinstall-21c
- Cambia ownership de discos Oracle a `oracle:oinstall`
- Permisos `775` permiten lectura/escritura/ejecución para owner y group

**Duración:** < 5 segundos

### Paso 6: Configurar Archivo Hosts

```bash
sh /vagrant_scripts/configure_hosts_base.sh
```

**Explicación:**
- **Usuario:** root (necesario para modificar /etc/hosts)
- **Qué hace:**
  - Agrega entradas DNS locales para ambos nodos
  - Permite resolución de nombres sin DNS externo
  - Crítico para conectividad Data Guard

**Contenido agregado a /etc/hosts:**
```
192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
192.168.56.102  ol8-21-dg2.localdomain ol8-21-dg2
```

**Duración:** < 5 segundos

**Ver detalles:** [34 - Configure Network](34-configure-network.md)

### Paso 7: Configurar Hostname

```bash
sh /vagrant_scripts/configure_hostname.sh
```

**Explicación:**
- **Usuario:** root (necesario para hostnamectl)
- **Qué hace:**
  - Detecta la IP del nodo
  - Configura hostname según corresponda (ol8-21-dg1.localdomain para primario)
  - Usa `hostnamectl set-hostname --static`

**Duración:** < 5 segundos

**Ver detalles:** [34 - Configure Network](34-configure-network.md)

### Paso 8: Configurar Sincronización de Tiempo

```bash
sh /vagrant_scripts/configure_chrony.sh
```

**Explicación:**
- **Usuario:** root (necesario para systemctl)
- **Qué hace:**
  - Habilita y arranca servicio `chronyd`
  - Sincroniza reloj del sistema
  - **CRÍTICO PARA DATA GUARD:** Relojes desincronizados causan fallos de replicación

**Importancia:**
- Oracle Data Guard requiere que primary y standby tengan relojes sincronizados
- Diferencias de tiempo > 5 minutos pueden causar errores de archive log transport

**Duración:** 5-10 segundos

**Ver detalles:** [34 - Configure Network](34-configure-network.md)

### Paso 9: Configurar Entorno de Usuario Oracle

```bash
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/oracle_user_environment_setup.sh'
. /home/oracle/scripts/setEnv.sh
```

**Explicación:**
- **Usuario:** `oracle` (usando `su - oracle -c`)
- **Qué hace:**
  - Crea `/home/oracle/scripts/setEnv.sh` con variables de entorno Oracle
  - Agrega source de setEnv.sh a `.bash_profile`
  - Crea directorios `ORACLE_HOME`, `DATA_DIR`
- **Segunda línea:** Carga las variables en el contexto shell actual (root) para uso posterior

**Variables exportadas en setEnv.sh:**
```bash
ORACLE_HOSTNAME=ol8-21-dg1.localdomain
ORACLE_UNQNAME=cdb1
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
ORACLE_SID=cdb1
PATH=${ORACLE_HOME}/bin:${PATH}
TNS_ADMIN=${ORACLE_HOME}/network/admin
```

**Duración:** 5-10 segundos

**Ver detalles:** [35 - Oracle User Environment](35-oracle-user-env.md)

### Paso 10: Instalar Software Oracle 21c

```bash
su - oracle -c 'sh /vagrant_scripts/oracle_db_software_installation.sh'
```

**Explicación:**
- **Usuario:** `oracle` (instalación de software NO debe ser como root)
- **Qué hace:**
  - Copia `LINUX.X64_213000_db_home.zip` de `/vagrant_software/` a `/u01/software/`
  - Descomprime en `ORACLE_HOME`
  - Ejecuta `runInstaller` en modo silencioso
  - Instalación "Software Only" (sin crear base de datos aún)

**Duración:** 15-20 minutos (descompresión + instalación)

**Ver detalles:** [36 - Install Oracle](36-install-oracle.md)

### Paso 11: Ejecutar Scripts Root de Oracle

```bash
echo "******************************************************************************"
echo "Run DB root scripts." `date`
echo "******************************************************************************"
sh ${ORA_INVENTORY}/orainstRoot.sh
sh ${ORACLE_HOME}/root.sh
```

**Explicación:**
- **Usuario:** root (estos scripts DEBEN ejecutarse como root)
- **orainstRoot.sh:** Configura inventario de Oracle
- **root.sh:** Configura binarios con permisos especiales (e.g., setuid para acceso a memoria)
- Requerido después de cada instalación de Oracle

**Salida esperada:**
```
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.
...
The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/oracle/product/21.0.0/dbhome_1
```

**Duración:** 10-30 segundos

### Paso 12: Crear Base de Datos Primaria con Configuración Data Guard

```bash
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/oracle_create_database.sh'
```

**Explicación:**
- **Usuario:** `oracle`
- **Qué hace:** (⭐ **PASO MÁS CRÍTICO**)
  1. Crea archivos de configuración de red (tnsnames.ora, listener.ora, sqlnet.ora)
  2. Arranca listener
  3. Crea CDB (`cdb1`) + PDB (`pdb1`) usando `dbca`
  4. **PREPARA LA BASE PARA DATA GUARD** usando comando moderno:
     ```sql
     PREPARE DATABASE FOR DATA GUARD
       WITH db_unique_name IS cdb1
       db_recovery_file_dest IS "/u01/app/oracle/fast_recovery_area"
       db_recovery_file_dest_size IS 100G;
     ```
  5. Configura archive log mode, standby redo logs, flashback database
  6. Configura parámetros de Data Guard (log_archive_dest, archive_lag_target, etc.)
  7. Crea password file
  8. Habilita Flashback Database

**Duración:** 8-12 minutos

**Ver detalles:** [37 - Create Database](37-create-database.md) ⭐ **DOCUMENTO CRÍTICO**

### Paso 13: Desplegar Schema Healthcare

```bash
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/deploy_custom_schema.sh'
```

**Explicación:**
- **Usuario:** `oracle`
- **Qué hace:**
  1. Abre PDB `pdb1`
  2. Crea usuario `HC` con tablespace usando `Script_SchemeTableSpace.sql`
  3. Ejecuta `ScriptProyectoBD.SQL` para crear schema healthcare
  4. Verifica tablas y sequences creadas
  5. Fuerza archive log para replicar schema a standby

**Schema creado:**
- 20+ tablas (HC_User, HC_Payroll, HC_MonthScale, HC_Procedure, etc.)
- 15+ sequences
- Triggers de auditoría
- Packages PL/SQL (PKG_UTILITIES, PKG_LOGBOOK, PKG_EMAILS)

**Duración:** 2-5 minutos

**Ver detalles:** [38 - Deploy Schema](38-deploy-schema.md)

### Paso 14: Configurar Scripts de Automatización

```bash
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/setup_automation.sh'
```

**Explicación:**
- **Usuario:** `oracle`
- **Qué hace:**
  - Copia scripts de `/vagrant_automation/` a `/home/oracle/automation/`
  - Establece permisos de ejecución
  - Crea directorio `/home/oracle/logs/automation`

**Scripts copiados:**
- `check_log_transport.sh` - Monitoreo de replicación
- `rman_daily_backup.sh` - Respaldos diarios
- `delete_archives_primary.sh` - Limpieza de archive logs
- `verify_dataguard.sh` - Verificación de estado
- `manual_backup.sh` - Respaldo manual
- `setup_ssh_keys.sh` - Configuración manual de SSH

**Duración:** < 5 segundos

**Ver detalles:** [39 - Setup Automation](39-setup-automation.md)

### Paso 15: Configurar Claves SSH para Transferencia de Backups

```bash
echo "******************************************************************************"
echo "Setting up SSH keys for backup transfers." `date`
echo "******************************************************************************"
sh /vagrant/2-Standby/scripts/primary/setup_ssh_keys_auto.sh
```

**Explicación:**
- **Usuario:** root (para acceso a /vagrant)
- **Qué hace:**
  - Genera par de claves SSH RSA 4096 bits para usuario oracle
  - Exporta clave pública a `/vagrant/ssh_keys/primary_id_rsa.pub`
  - Crea configuración SSH cliente en `/home/oracle/.ssh/config`
  - Prepara known_hosts

**Propósito:** Permitir rsync de backups de primary a standby sin contraseña

**Duración:** 5-10 segundos

**Ver detalles:** [40 - Setup SSH](40-setup-ssh.md)

### Paso 16: Instalar Cron Jobs para Automatización

```bash
echo "******************************************************************************"
echo "Installing cron jobs for automation." `date`
echo "******************************************************************************"
su - oracle -c 'sh /home/oracle/automation/install_cron_jobs.sh'
```

**Explicación:**
- **Usuario:** `oracle`
- **Qué hace:**
  - Detecta que es nodo primario (basado en hostname)
  - Instala 3 cron jobs:
    1. `check_log_transport.sh` - Cada 10 minutos
    2. `rman_daily_backup.sh` - Diariamente a la 1 AM
    3. `delete_archives_primary.sh` - Diariamente a las 2 AM

**Crontab instalado:**
```cron
*/10 * * * * /home/oracle/automation/check_log_transport.sh
0 1 * * * /home/oracle/automation/rman_daily_backup.sh
0 2 * * * /home/oracle/automation/delete_archives_primary.sh
```

**Duración:** < 5 segundos

**Ver detalles:** [41 - Install Cron](41-install-cron.md)

### Paso 17: Banner de Finalización

```bash
echo "******************************************************************************"
echo "PRIMARY Root Setup Complete." `date`
echo "******************************************************************************"
```

**Explicación:**
- Indica finalización exitosa de todos los pasos
- Timestamp final permite calcular duración total

## Archivos Creados/Modificados

### Sistema de Archivos

| Ruta | Descripción |
|------|-------------|
| `/u01/` | Disco para Oracle software y datos |
| `/u02/` | Disco para backups y FRA |
| `/etc/fstab` | Entradas de montaje para u01 y u02 |
| `/etc/hosts` | Entradas DNS para ambos nodos |
| `/etc/sysctl.d/98-oracle.conf` | Kernel parameters |

### Usuario Oracle

| Ruta | Descripción |
|------|-------------|
| `/home/oracle/scripts/setEnv.sh` | Variables de entorno Oracle |
| `/home/oracle/.bash_profile` | Modificado para source setEnv.sh |
| `/home/oracle/automation/` | Scripts de automatización |
| `/home/oracle/logs/` | Directorio de logs |
| `/home/oracle/.ssh/` | Claves SSH y configuración |

### Oracle Software y Datos

| Ruta | Descripción |
|------|-------------|
| `/u01/app/oracle/product/21.0.0/dbhome_1/` | ORACLE_HOME |
| `/u01/app/oraInventory/` | Oracle Inventory |
| `/u01/oradata/cdb1/` | Datafiles de la base de datos |
| `/u01/oradata/cdb1/arch/` | Archive logs locales |
| `/u01/app/oracle/fast_recovery_area/` | FRA (flashback logs, backups) |
| `/u02/backup/` | Destino de backups RMAN |

### Archivos de Configuración Oracle

| Ruta | Descripción |
|------|-------------|
| `$ORACLE_HOME/network/admin/tnsnames.ora` | Descriptores de conexión TNS |
| `$ORACLE_HOME/network/admin/listener.ora` | Configuración del listener |
| `$ORACLE_HOME/network/admin/sqlnet.ora` | Configuración de red (encryption) |
| `$ORACLE_HOME/dbs/orapwcdb1` | Password file |
| `$ORACLE_HOME/dbs/spfilecdb1.ora` | Server parameter file |

## Dependencias

### Scripts que Deben Existir

**Shared scripts** (usados por primary y standby):
- `/vagrant_scripts/prepare_u01_u02_disks.sh`
- `/vagrant_scripts/install_os_packages.sh`
- `/vagrant_scripts/configure_hosts_base.sh`
- `/vagrant_scripts/configure_hostname.sh`
- `/vagrant_scripts/configure_chrony.sh`
- `/vagrant_scripts/oracle_db_software_installation.sh`

**Primary-specific scripts:**
- `/vagrant/2-Standby/scripts/primary/oracle_user_environment_setup.sh`
- `/vagrant/2-Standby/scripts/primary/oracle_create_database.sh`
- `/vagrant/2-Standby/scripts/primary/deploy_custom_schema.sh`
- `/vagrant/2-Standby/scripts/primary/setup_automation.sh`
- `/vagrant/2-Standby/scripts/primary/setup_ssh_keys_auto.sh`

**Automation scripts:**
- `/vagrant_automation/*.sh` (6 scripts)

**Database scripts:**
- `/vagrant/1-BD/Script_SchemeTableSpace.sql`
- `/vagrant/1-BD/ScriptProyectoBD.SQL`

### Prerequisitos del Sistema

- Discos virtuales `/dev/sdb` (100GB) y `/dev/sdc` (100GB) attached a la VM
- Conexión a internet para `dnf install`
- Oracle software en `/vagrant_software/LINUX.X64_213000_db_home.zip`
- Al menos 4 GB RAM disponible
- Al menos 2 CPUs

### Synced Folders de Vagrant

```ruby
config.vm.synced_folder ".", "/vagrant"
config.vm.synced_folder "config", "/vagrant_config"
config.vm.synced_folder "software", "/vagrant_software"
config.vm.synced_folder "2-Standby/infrastructure", "/vagrant_scripts"
config.vm.synced_folder "2-Standby/automation", "/vagrant_automation"
```

## Logs y Verificación

### Logs en Windows Host

```
powershell/logs/deploy-YYYY-MM-DD-HHMMSS/primary-setup.log
```

### Logs en VM

```bash
# Logs del sistema
/var/log/messages

# Logs de Oracle
/u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log

# Logs de automatización
/home/oracle/logs/automation/
```

### Comandos de Verificación Post-Despliegue

```bash
# Verificar que la base de datos está corriendo
vagrant ssh primary -c "source ~/.bash_profile && sqlplus / as sysdba <<< 'SELECT status FROM v\$instance;'"

# Verificar modo archive log
vagrant ssh primary -c "source ~/.bash_profile && sqlplus / as sysdba <<< 'archive log list;'"

# Verificar Flashback Database
vagrant ssh primary -c "source ~/.bash_profile && sqlplus / as sysdba <<< 'SELECT flashback_on FROM v\$database;'"

# Verificar cron jobs instalados
vagrant ssh primary -c "crontab -l"

# Verificar tablas del schema healthcare
vagrant ssh primary -c "source ~/.bash_profile && sqlplus HC/password@localhost:1521/pdb1 <<< 'SELECT COUNT(*) FROM user_tables;'"

# Verificar listener corriendo
vagrant ssh primary -c "source ~/.bash_profile && lsnrctl status"
```

### Verificación de Data Guard (Pre-Standby)

```sql
-- Conectar como SYSDBA
sqlplus / as sysdba

-- Verificar configuración Data Guard
SELECT name, db_unique_name, database_role, log_mode, flashback_on, protection_mode
FROM v$database;

-- Expected output:
-- NAME: CDB1
-- DB_UNIQUE_NAME: cdb1
-- DATABASE_ROLE: PRIMARY
-- LOG_MODE: ARCHIVELOG
-- FLASHBACK_ON: YES
-- PROTECTION_MODE: MAXIMUM PERFORMANCE (cambiará a MAXIMUM AVAILABILITY cuando standby esté configurado)

-- Verificar standby redo logs (creados por PREPARE DATABASE)
SELECT group#, thread#, bytes/1024/1024 as size_mb, status
FROM v$standby_log;

-- Verificar archive log destinations
SHOW PARAMETER log_archive_dest;
```

## Puntos de Fallo Comunes

### 1. Fallo en Preparación de Discos

**Error:**
```
fdisk: cannot open /dev/sdb: No such file or directory
```

**Causa:** Discos virtuales no attached en Vagrantfile

**Solución:**
```ruby
# En Vagrantfile
vb.customize ["createhd", "--filename", "u01-primary.vdi", "--size", 102400]
vb.customize ["storageattach", :id, "--storagectl", "SATA Controller",
              "--port", 1, "--device", 0, "--type", "hdd", "--medium", "u01-primary.vdi"]
```

### 2. Fallo en Instalación de Paquetes (No Internet)

**Error:**
```
Failed to download metadata for repo 'ol8_baseos_latest'
```

**Causa:** VM no tiene conectividad a internet

**Solución:**
- Verificar configuración de red en Vagrantfile
- Usar `public_network` en lugar de `private_network` si hay problemas
- Configurar proxy si tu red lo requiere

### 3. Fallo en Instalación de Oracle (Memoria Insuficiente)

**Error:**
```
[FATAL] [INS-30131] Initial setup required for the execution of installer validations failed
```

**Causa:** Menos de 2 GB RAM disponible para la VM

**Solución:**
```ruby
# En vagrant.yml
memory: 4096  # Mínimo 4 GB
```

### 4. Fallo en Creación de Base de Datos (Espacio Insuficiente)

**Error:**
```
ORA-01119: error in creating database file
ORA-27040: file create error, unable to create file
```

**Causa:** Disco /u01 lleno o muy pequeño

**Solución:**
- Verificar tamaño de disco virtual: `vb.customize ["createhd", ..., "--size", 102400]` (100 GB)
- Reducir `REDO_LOG_SIZE` en install.env si es necesario

### 5. Schema Healthcare No se Despliega

**Error:**
```
SP2-0310: unable to open file "/vagrant/1-BD/ScriptProyectoBD.SQL"
```

**Causa:** Synced folder `/vagrant` no montado

**Solución:**
```bash
# Instalar/actualizar VirtualBox Guest Additions
vagrant plugin install vagrant-vbguest
vagrant reload primary
```

### 6. Cron Jobs No se Instalan

**Error:**
```
ERROR: Cannot determine if this is primary or standby!
```

**Causa:** Hostname no coincide con `NODE1_FQ_HOSTNAME` o `NODE2_FQ_HOSTNAME`

**Solución:**
- Verificar que `configure_hostname.sh` se ejecutó correctamente
- Verificar que `/etc/hosts` tiene las entradas correctas
- Ejecutar: `hostnamectl set-hostname ol8-21-dg1.localdomain --static`

## Importancia para Data Guard

### Configuraciones Críticas Realizadas

Este script garantiza que el nodo primario está **100% preparado para Data Guard**:

1. **Archive Log Mode:** Habilitado con `ARCHIVE_LAG_TARGET=300` segundos
2. **Flashback Database:** Habilitado para flashback después de failover
3. **Standby Redo Logs:** Creados automáticamente por `PREPARE DATABASE FOR DATA GUARD`
4. **Fast Recovery Area:** Configurada con 100 GB
5. **Log Archive Destinations:** Configuradas para primary y standby
6. **Protection Mode:** Preparado para MAXAVAILABILITY (se activa cuando standby se conecta)
7. **Password File:** Creado en formato 12c para sincronización de usuarios
8. **Network Encryption:** AES256 + SHA256 checksums
9. **Time Sync:** Chronyd habilitado para prevenir desfase de relojes

### Comandos Modernos Utilizados

**PREPARE DATABASE FOR DATA GUARD** (Oracle 21c):
- Reemplaza configuración manual de múltiples parámetros
- Configura automáticamente: force_logging, log_mode=archivelog, standby redo logs, FRA
- Más confiable que configuración manual

### Orden de Ejecución Crítico

El orden de los pasos NO es arbitrario:

1. **Discos primero:** Oracle necesita espacio antes de instalación
2. **Paquetes antes de Oracle:** `oracle-database-preinstall-21c` crea usuario oracle
3. **Red antes de DB creation:** `dbca` necesita hostname correcto
4. **Time sync antes de DB creation:** Relojes sincronizados desde el inicio
5. **Schema después de DB:** PDB debe existir y estar abierta
6. **SSH antes de cron:** Cron jobs de backup necesitan SSH configurado

## Referencias Cruzadas

### Scripts Invocados (en orden)

1. **[32 - Prepare Disks](32-prepare-disks.md)** - Preparación de discos
2. **[33 - Install Packages](33-install-packages.md)** - Instalación de paquetes OS
3. **[34 - Configure Network](34-configure-network.md)** - Configuración de red (hosts, hostname, chrony)
4. **[35 - Oracle User Environment](35-oracle-user-env.md)** - Entorno de usuario Oracle
5. **[36 - Install Oracle](36-install-oracle.md)** - Instalación de software Oracle 21c
6. **[37 - Create Database](37-create-database.md)** ⭐ - Creación de DB con Data Guard
7. **[38 - Deploy Schema](38-deploy-schema.md)** - Despliegue de schema healthcare
8. **[39 - Setup Automation](39-setup-automation.md)** - Scripts de automatización
9. **[40 - Setup SSH](40-setup-ssh.md)** - Configuración de SSH keys
10. **[41 - Install Cron](41-install-cron.md)** - Instalación de cron jobs

### Documentación de Contexto

- **[30 - Primary Setup](30-primary-setup.md)** - Script que invoca este orquestador
- **[04 - Cómo Usar](../../04-como-usar.md)** - Guía de usuario
- **[05 - Arquitectura](../../05-arquitectura-sistema.md)** - Arquitectura completa
- **[81 - Data Guard Conceptos](../../conceptos-avanzados/81-data-guard-conceptos.md)** - Conceptos de Data Guard

## Resumen Ejecutivo

Este script es el **corazón del despliegue primario**. En 35-45 minutos, transforma una VM vacía de Oracle Linux 8 en un nodo primario de Oracle Data Guard completamente funcional con:

- ✅ Base de datos Oracle 21c Enterprise Edition
- ✅ CDB + PDB con schema healthcare desplegado
- ✅ Archive log mode habilitado
- ✅ Flashback Database habilitado
- ✅ Standby redo logs configurados
- ✅ Network encryption (AES256)
- ✅ Automatización con cron jobs
- ✅ SSH configurado para backups
- ✅ Monitoreo de log transport
- ✅ 100% listo para conectar standby

**Siguiente:** El standby ejecutará `RMAN DUPLICATE` para clonar esta base de datos y establecer Data Guard.

---

**Siguiente en la cadena:** [32 - Prepare Disks](32-prepare-disks.md)
