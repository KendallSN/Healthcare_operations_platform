# 51 - Standby Root Setup - Orquestador Principal del Despliegue

## Descripción General

**Archivo:** `2-Standby/scripts/standby/root_setup.sh`

**Propósito:** Orquestador principal que ejecuta todos los pasos del despliegue standby en secuencia. Este script coordina 10 etapas para crear completamente el nodo standby de Oracle Data Guard.

**Rol en el flujo:** Controlador central que invoca scripts especializados para cada fase del despliegue.

**Tiempo de ejecución:** 20-30 minutos (total de todas las etapas)

---

## Tabla de Contenidos

1. [Ubicación en el Flujo](#1-ubicación-en-el-flujo)
2. [Las 10 Etapas del Despliegue](#2-las-10-etapas-del-despliegue)
3. [Código Fuente Completo](#3-código-fuente-completo)
4. [Análisis Detallado por Etapa](#4-análisis-detallado-por-etapa)
5. [Diferencias con Primary](#5-diferencias-con-primary)
6. [Variables de Entorno](#6-variables-de-entorno)
7. [Orden de Ejecución](#7-orden-de-ejecución)
8. [Manejo de Errores](#8-manejo-de-errores)
9. [Logs y Verificación](#9-logs-y-verificación)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Ubicación en el Flujo

### Diagrama de Flujo Completo

```
setup.sh (50)
    │
    │ sudo bash -c
    ▼
┌─────────────────────────────────────────┐
│  root_setup.sh (51) ◄─── ESTÁS AQUÍ    │
│  Orquestador Principal                  │
└───┬─────────────────────────────────────┘
    │
    ├─> [1/10] prepare_disks.sh (52)
    │   └─ Preparar /u01 y /u02
    │
    ├─> [2/10] install_packages.sh (53)
    │   └─ Instalar Oracle preinstall y paquetes
    │
    ├─> [3/10] Configurar Contraseñas
    │   └─ root, oracle, permisos /u01 /u02
    │
    ├─> [4/10] configure_hosts_base.sh (54a)
    │   └─ Configurar /etc/hosts
    │
    ├─> [5/10] configure_hostname.sh (54b)
    │   └─ Hostname: ol8-21-dg2.localdomain
    │
    ├─> [6/10] configure_chrony.sh (54c)
    │   └─ Sincronización de tiempo
    │
    ├─> [7/10] oracle_user_environment_setup.sh (55)
    │   └─ setEnv.sh con ORACLE_UNQNAME=cdb1_stby
    │
    ├─> [8/10] oracle_db_software_installation.sh (56)
    │   └─ Instalar Oracle 21c + root scripts
    │
    ├─> [9/10] oracle_create_database.sh (57) ⭐⭐⭐
    │   └─ RMAN DUPLICATE + Data Guard Broker
    │
    ├─> [10/10] setup_automation.sh (58)
    │   └─ Copiar scripts de automatización
    │
    ├─> [11/10] setup_ssh_keys_auto.sh (59)
    │   └─ Importar clave pública del primary
    │
    └─> [12/10] install_cron_jobs.sh (60)
        └─ Instalar cron job de limpieza
```

---

## 2. Las 10 Etapas del Despliegue

### Resumen de Etapas

| # | Etapa | Script | Tiempo | Crítico |
|---|-------|--------|--------|---------|
| 1 | Preparar Discos | prepare_u01_u02_disks.sh | 30s | ✅ |
| 2 | Instalar Paquetes | install_os_packages.sh | 5-8min | ✅ |
| 3 | Configurar Contraseñas | (inline) | 5s | ✅ |
| 4 | Configurar Hosts | configure_hosts_base.sh | 5s | ✅ |
| 5 | Configurar Hostname | configure_hostname.sh | 5s | ✅ |
| 6 | Configurar Tiempo | configure_chrony.sh | 10s | ⚠️ |
| 7 | Entorno Oracle | oracle_user_environment_setup.sh | 5s | ✅ |
| 8 | Instalar Oracle | oracle_db_software_installation.sh | 10-15min | ✅ |
| 9 | **RMAN DUPLICATE** | oracle_create_database.sh | 10-20min | 🔥 |
| 10 | Automatización | setup_automation.sh | 5s | ⚠️ |
| 11 | SSH Keys | setup_ssh_keys_auto.sh | 10s | ⚠️ |
| 12 | Cron Jobs | install_cron_jobs.sh | 5s | ⚠️ |

**Leyenda:**
- ✅ Crítico - Si falla, el despliegue no puede continuar
- ⚠️ Importante - Si falla, funcionalidad reducida pero DB funciona
- 🔥 MUY CRÍTICO - Corazón del standby, falla = rehacer todo

---

## 3. Código Fuente Completo

```bash
#!/bin/bash
# Standby node root setup script

. /vagrant_config/install.env

echo "******************************************************************************"
echo "STANDBY Root Setup Started." `date`
echo "******************************************************************************"

# Prepare disks
sh /vagrant_scripts/prepare_u01_u02_disks.sh

# Install OS packages
sh /vagrant_scripts/install_os_packages.sh

# Set passwords
echo "******************************************************************************"
echo "Set root and oracle password and change ownership." `date`
echo "******************************************************************************"
echo -e "${ROOT_PASSWORD}\n${ROOT_PASSWORD}" | passwd
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | passwd oracle
chown -R oracle:oinstall /u01 /u02
chmod -R 775 /u01 /u02

# Configure hosts file
sh /vagrant_scripts/configure_hosts_base.sh

# Configure hostname
sh /vagrant_scripts/configure_hostname.sh

# Configure time sync
sh /vagrant_scripts/configure_chrony.sh

# Setup oracle user environment
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/oracle_user_environment_setup.sh'
. /home/oracle/scripts/setEnv.sh

# Install Oracle software
su - oracle -c 'sh /vagrant_scripts/oracle_db_software_installation.sh'

# Run Oracle root scripts
echo "******************************************************************************"
echo "Run DB root scripts." `date`
echo "******************************************************************************"
sh ${ORA_INVENTORY}/orainstRoot.sh
sh ${ORACLE_HOME}/root.sh

# Create standby database
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/oracle_create_database.sh'

# Setup automation scripts
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/setup_automation.sh'

# Setup SSH keys for receiving backup transfers (run as root for /vagrant access)
echo "******************************************************************************"
echo "Setting up SSH keys for receiving backups from primary." `date`
echo "******************************************************************************"
sh /vagrant/2-Standby/scripts/standby/setup_ssh_keys_auto.sh

# Install cron jobs for automation
echo "******************************************************************************"
echo "Installing cron jobs for automation." `date`
echo "******************************************************************************"
su - oracle -c 'sh /home/oracle/automation/install_cron_jobs.sh'

echo "******************************************************************************"
echo "STANDBY Root Setup Complete." `date`
echo "******************************************************************************"
```

**Total:** 69 líneas

---

## 4. Análisis Detallado por Etapa

### Líneas 1-3: Shebang y Source de Variables
```bash
#!/bin/bash
# Standby node root setup script

. /vagrant_config/install.env
```

**¿Qué hace el source?**
```bash
. /vagrant_config/install.env
# Es equivalente a:
source /vagrant_config/install.env
```

**Variables cargadas (las más importantes):**
```bash
NODE2_HOSTNAME=ol8-21-dg2
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain
NODE2_PUBLIC_IP=192.168.56.102
NODE2_DB_UNIQUE_NAME=cdb1_stby        # ⭐ DIFERENTE del primary

ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
ORACLE_SID=cdb1                        # Mismo que primary
PDB_NAME=pdb1

SYS_PASSWORD="S1sPassword1!"
ROOT_PASSWORD=rootpasswd
ORACLE_PASSWORD=oracle

ARCHIVE_LAG_TARGET=300                 # 5 minutos
PROTECTION_MODE=MAXAVAILABILITY
TRANSPORT_MODE=FASTSYNC
```

**Alcance de las variables:**
- Disponibles en este script y todos los que invoque con `sh`
- Pero NO en scripts invocados con `su - oracle -c` (nuevo shell limpio)
- Por eso cada script hijo hace su propio `. /vagrant_config/install.env`

---

### Líneas 6-8: Banner de Inicio
```bash
echo "******************************************************************************"
echo "STANDBY Root Setup Started." `date`
echo "******************************************************************************"
```

**Ejemplo de salida:**
```
******************************************************************************
STANDBY Root Setup Started. Mon Nov  4 16:32:18 UTC 2025
******************************************************************************
```

---

### [ETAPA 1/10] Líneas 10-11: Preparar Discos

```bash
# Prepare disks
sh /vagrant_scripts/prepare_u01_u02_disks.sh
```

**Qué hace:**
- Crea particiones en `/dev/sdb` (100GB) y `/dev/sdc` (100GB)
- Formatea con XFS
- Monta en `/u01` y `/u02`
- Agrega a `/etc/fstab` para auto-mount
- Crea estructura de directorios

**Directorios creados:**
```
/u01/app/oracle
/u01/app/oraInventory
/u01/oradata
/u01/software
/u02/backup
/u02/fast_recovery_area
```

**Tiempo:** ~30 segundos

**Detalle:** Ver [52-prepare-disks.md](52-prepare-disks.md)

---

### [ETAPA 2/10] Líneas 13-14: Instalar Paquetes

```bash
# Install OS packages
sh /vagrant_scripts/install_os_packages.sh
```

**Qué instala:**
1. `oracle-database-preinstall-21c` - Metapaquete que:
   - Crea usuario `oracle` y grupo `oinstall`
   - Configura kernel parameters
   - Instala dependencias de Oracle
2. Paquetes adicionales (~48 paquetes):
   - `bc`, `bind-utils`, `nfs-utils`, `chrony`, `net-tools`, etc.

**Tiempo:** 5-8 minutos (descarga de Internet)

**Detalle:** Ver [53-install-packages.md](53-install-packages.md)

---

### [ETAPA 3/10] Líneas 16-23: Configurar Contraseñas

```bash
# Set passwords
echo "******************************************************************************"
echo "Set root and oracle password and change ownership." `date`
echo "******************************************************************************"
echo -e "${ROOT_PASSWORD}\n${ROOT_PASSWORD}" | passwd
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | passwd oracle
chown -R oracle:oinstall /u01 /u02
chmod -R 775 /u01 /u02
```

**Desglose:**

**1. Cambiar contraseña de root:**
```bash
echo -e "${ROOT_PASSWORD}\n${ROOT_PASSWORD}" | passwd
```
- `${ROOT_PASSWORD}` = `rootpasswd` (de install.env)
- `echo -e` - Habilita interpretación de `\n` (newline)
- Se envía dos veces (confirmación)
- `passwd` sin usuario = cambiar contraseña del usuario actual (root)

**2. Cambiar contraseña de oracle:**
```bash
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | passwd oracle
```
- `${ORACLE_PASSWORD}` = `oracle`
- Similar al anterior pero para usuario `oracle`

**3. Cambiar propietario de discos:**
```bash
chown -R oracle:oinstall /u01 /u02
```
- `-R` - Recursivo (todos los subdirectorios)
- `oracle:oinstall` - Usuario oracle, grupo oinstall
- Necesario para que oracle pueda escribir datafiles, software, etc.

**4. Cambiar permisos:**
```bash
chmod -R 775 /u01 /u02
```
- `775` = `rwxrwxr-x`:
  - Owner (oracle): lectura, escritura, ejecución
  - Group (oinstall): lectura, escritura, ejecución
  - Others: lectura, ejecución (no escritura)

**Tiempo:** ~5 segundos

---

### [ETAPA 4/10] Líneas 25-26: Configurar /etc/hosts

```bash
# Configure hosts file
sh /vagrant_scripts/configure_hosts_base.sh
```

**Qué hace:**
Agrega entradas a `/etc/hosts`:
```
192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
192.168.56.102  ol8-21-dg2.localdomain ol8-21-dg2
```

**Por qué es crítico:**
- Oracle Data Guard usa hostnames para identificar nodos
- `tnsnames.ora` usa estos hostnames
- Sin esto, no hay conectividad primary ↔ standby

**Tiempo:** ~5 segundos

**Detalle:** Ver [54-configure-network.md](54-configure-network.md)

---

### [ETAPA 5/10] Líneas 28-29: Configurar Hostname

```bash
# Configure hostname
sh /vagrant_scripts/configure_hostname.sh
```

**Qué hace:**
```bash
hostnamectl set-hostname ol8-21-dg2.localdomain
```

**Antes:**
```bash
[vagrant@localhost ~]$ hostname
localhost.localdomain
```

**Después:**
```bash
[oracle@ol8-21-dg2 ~]$ hostname
ol8-21-dg2.localdomain
```

**Por qué importa:**
- Oracle escribe el hostname en configuraciones
- Data Guard Broker lo usa para identificar el nodo
- Debe coincidir con `/etc/hosts`

**Tiempo:** ~5 segundos

**Detalle:** Ver [54-configure-network.md](54-configure-network.md)

---

### [ETAPA 6/10] Líneas 31-32: Configurar Sincronización de Tiempo

```bash
# Configure time sync
sh /vagrant_scripts/configure_chrony.sh
```

**Qué hace:**
- Configura `chronyd` (NTP client)
- Se sincroniza con servidores NTP públicos
- Habilita y arranca el servicio

**Por qué es importante:**
- Data Guard es sensible a diferencias de tiempo entre nodos
- Archive logs tienen timestamps
- Si los relojes difieren mucho, pueden haber problemas de aplicación

**Tiempo recomendado de diferencia:** < 5 segundos

**Tiempo:** ~10 segundos

**Detalle:** Ver [54-configure-network.md](54-configure-network.md)

---

### [ETAPA 7/10] Líneas 34-36: Configurar Entorno Oracle

```bash
# Setup oracle user environment
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/oracle_user_environment_setup.sh'
. /home/oracle/scripts/setEnv.sh
```

**Desglose:**

**1. Ejecutar como usuario oracle:**
```bash
su - oracle -c 'comando'
```
- `su - oracle` - Cambiar a usuario oracle con login completo (carga .bash_profile)
- `-c 'comando'` - Ejecutar comando y volver al usuario original

**2. Script ejecutado:**
```bash
sh /vagrant/2-Standby/scripts/standby/oracle_user_environment_setup.sh
```
Crea `/home/oracle/scripts/setEnv.sh` con:
```bash
export ORACLE_HOSTNAME=ol8-21-dg2.localdomain
export ORACLE_UNQNAME=cdb1_stby           # ⭐ STANDBY SPECIFIC
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
export ORACLE_SID=cdb1
export PATH=$ORACLE_HOME/bin:$PATH
# ... más variables
```

**3. Source del setEnv.sh:**
```bash
. /home/oracle/scripts/setEnv.sh
```
- Carga las variables en el shell actual (root)
- Ahora `${ORACLE_HOME}` está disponible en root_setup.sh

**Diferencia clave con Primary:**
```bash
# Primary:
export ORACLE_UNQNAME=cdb1

# Standby:
export ORACLE_UNQNAME=cdb1_stby  # ⭐ Diferente
```

**Tiempo:** ~5 segundos

**Detalle:** Ver [55-oracle-user-env.md](55-oracle-user-env.md)

---

### [ETAPA 8/10] Líneas 38-39: Instalar Oracle Software

```bash
# Install Oracle software
su - oracle -c 'sh /vagrant_scripts/oracle_db_software_installation.sh'
```

**Qué hace:**
1. Copia `/vagrant_software/LINUX.X64_213000_db_home.zip` a `/u01/software/`
2. Descomprime en `$ORACLE_HOME` (10-15 minutos)
3. Ejecuta instalador silent:
   ```bash
   ${ORACLE_HOME}/runInstaller -silent -responseFile ${ORACLE_HOME}/install/response/db_install.rsp \
       oracle.install.option=INSTALL_DB_SWONLY \
       UNIX_GROUP_NAME=oinstall \
       INVENTORY_LOCATION=${ORA_INVENTORY} \
       ORACLE_HOME=${ORACLE_HOME} \
       ORACLE_BASE=${ORACLE_BASE} \
       oracle.install.db.InstallEdition=EE \
       oracle.install.db.OSDBA_GROUP=dba \
       oracle.install.db.OSBACKUPDBA_GROUP=dba \
       oracle.install.db.OSDGDBA_GROUP=dba \
       oracle.install.db.OSKMDBA_GROUP=dba \
       oracle.install.db.OSRACDBA_GROUP=dba \
       -waitForCompletion -ignorePrereq
   ```

**Software Only:**
- `INSTALL_DB_SWONLY` - Solo instalar software, no crear database
- Database se crea después con RMAN DUPLICATE

**Tiempo:** 10-15 minutos

**Detalle:** Ver [56-install-oracle.md](56-install-oracle.md)

---

### [ETAPA 8.5/10] Líneas 41-46: Ejecutar Root Scripts

```bash
# Run Oracle root scripts
echo "******************************************************************************"
echo "Run DB root scripts." `date`
echo "******************************************************************************"
sh ${ORA_INVENTORY}/orainstRoot.sh
sh ${ORACLE_HOME}/root.sh
```

**¿Por qué como root?**
- Estos scripts deben ejecutarse con privilegios root
- Configuran permisos del sistema
- Crean grupos y configuraciones globales

**1. orainstRoot.sh:**
```bash
sh /u01/app/oraInventory/orainstRoot.sh
```
- Configura Oracle Inventory central
- Se ejecuta solo una vez por servidor

**2. root.sh:**
```bash
sh /u01/app/oracle/product/21.0.0/dbhome_1/root.sh
```
- Configura Oracle Home
- Crea `/etc/oratab`
- Configura restart automático (opcional)

**Tiempo:** ~30 segundos

---

### [ETAPA 9/10] Líneas 48-49: 🔥 CREAR STANDBY DATABASE 🔥

```bash
# Create standby database
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/oracle_create_database.sh'
```

**ESTA ES LA ETAPA MÁS CRÍTICA E IMPORTANTE**

**Qué hace (resumen):**
1. Configura network (tnsnames.ora, listener.ora, sqlnet.ora)
2. Arranca listener
3. Crea directorios para datafiles
4. Crea password file (debe coincidir con primary)
5. Arranca instancia auxiliar en NOMOUNT
6. Prueba conectividad a primary con `tnsping`
7. **EJECUTA RMAN DUPLICATE FOR STANDBY** ⭐⭐⭐
   - Copia TODA la base de datos primary a standby vía red
   - Copia todos los datafiles (system, sysaux, users, PDBs, custom schema)
   - Aplica archive logs hasta el momento
   - Tiempo: 10-20 minutos
8. Habilita Flashback Database en standby
9. Configura Data Guard Broker
10. Crea configuración Data Guard
11. Agrega standby a la configuración
12. Habilita configuración
13. Configura MAXAVAILABILITY protection mode
14. Configura FASTSYNC transport mode
15. Valida configuración

**Tiempo:** 10-20 minutos (la mayoría en RMAN DUPLICATE)

**Detalle completo:** Ver [57-rman-duplicate.md](57-rman-duplicate.md) (900 líneas)

---

### [ETAPA 10/10] Líneas 51-52: Setup Automatización

```bash
# Setup automation scripts
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/setup_automation.sh'
```

**Qué hace:**
```bash
mkdir -p /home/oracle/automation
mkdir -p /home/oracle/logs/automation

cp /vagrant_automation/*.sh /home/oracle/automation/
chmod +x /home/oracle/automation/*.sh
chown -R oracle:oinstall /home/oracle/automation
```

**Scripts copiados:**
- `delete_archives_standby.sh` - Limpieza de archives aplicados
- `verify_dataguard.sh` - Verificación completa
- `install_cron_jobs.sh` - Instalador de cron jobs
- `manual_*.sh` - Scripts on-demand

**Tiempo:** ~5 segundos

**Detalle:** Ver [58-setup-automation.md](58-setup-automation.md)

---

### [ETAPA 11/10] Líneas 54-58: Setup SSH Keys

```bash
# Setup SSH keys for receiving backup transfers (run as root for /vagrant access)
echo "******************************************************************************"
echo "Setting up SSH keys for receiving backups from primary." `date`
echo "******************************************************************************"
sh /vagrant/2-Standby/scripts/standby/setup_ssh_keys_auto.sh
```

**Qué hace:**
1. Espera a que primary exporte su clave pública a `/vagrant/ssh_keys/primary_id_rsa.pub`
2. Importa la clave pública de primary a `/home/oracle/.ssh/authorized_keys`
3. Crea directorio `/u02/backup_from_primary/` para recibir backups
4. Genera claves SSH propias de standby
5. Exporta host keys de standby para que primary las importe

**Propósito:**
- Permitir que primary haga `rsync` a standby sin contraseña
- Los backups RMAN del primary se transfieren al standby diariamente

**Tiempo:** ~10 segundos (más tiempo de espera por primary)

**Detalle:** Ver [59-setup-ssh.md](59-setup-ssh.md)

---

### [ETAPA 12/10] Líneas 60-64: Instalar Cron Jobs

```bash
# Install cron jobs for automation
echo "******************************************************************************"
echo "Installing cron jobs for automation." `date`
echo "******************************************************************************"
su - oracle -c 'sh /home/oracle/automation/install_cron_jobs.sh'
```

**Cron jobs instalados en STANDBY:**

```cron
# Oracle Data Guard Automation
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

**Solo 1 cron job:**
- `delete_archives_standby.sh` - Limpieza diaria de archives aplicados (11 PM)

**Diferencia con Primary:**
- Primary tiene 3 cron jobs:
  1. `check_log_transport.sh` - Cada 10 minutos
  2. `rman_daily_backup.sh` - Diario 1 AM
  3. `delete_archives_primary.sh` - Diario 2 AM
- Standby solo limpia archives (no hace backups, no monitorea transporte)

**Por qué standby no hace backups:**
- Los backups se hacen en primary
- Se transfieren vía rsync a standby
- Standby solo recibe y almacena

**Tiempo:** ~5 segundos

**Detalle:** Ver [60-install-cron.md](60-install-cron.md)

---

### Líneas 66-68: Banner de Finalización

```bash
echo "******************************************************************************"
echo "STANDBY Root Setup Complete." `date`
echo "******************************************************************************"
```

**Ejemplo:**
```
******************************************************************************
STANDBY Root Setup Complete. Mon Nov  4 16:58:35 UTC 2025
******************************************************************************
```

**Cálculo de tiempo:**
```
Inicio:  16:32:18
Fin:     16:58:35
Duración: 26 minutos 17 segundos
```

---

## 5. Diferencias con Primary

### Comparación Lado a Lado

| Aspecto | Primary | Standby |
|---------|---------|---------|
| **Hostname** | ol8-21-dg1 | ol8-21-dg2 |
| **IP** | 192.168.56.101 | 192.168.56.102 |
| **ORACLE_UNQNAME** | cdb1 | cdb1_stby ⭐ |
| **Creación de DB** | DBCA (crea nueva) | RMAN DUPLICATE (copia) ⭐⭐⭐ |
| **Deploy Schema** | Sí (ejecuta SQLs) | No (replicado vía DG) ⭐ |
| **Data Guard Broker** | Se configura desde standby | Ejecuta configuración |
| **SSH Keys** | Exporta pública | Importa pública de primary ⭐ |
| **Cron Jobs** | 3 jobs (monitoreo + backup) | 1 job (limpieza) ⭐ |
| **Backup Directory** | /u02/backup/ | /u02/backup_from_primary/ ⭐ |

### Etapas Únicas de Standby

**1. RMAN DUPLICATE:**
- Primary usa `dbca` para crear base de datos nueva
- Standby usa `rman duplicate for standby from active database`
- Resultado: copia exacta de primary (incluyendo custom schema)

**2. No Deploy Schema:**
- Primary ejecuta `deploy_custom_schema.sh` que corre:
  - `Script_SchemeTableSpace.sql`
  - `ScriptProyectoBD.SQL`
  - Crea tablas, sequences, triggers, packages
- Standby NO ejecuta esto porque:
  - RMAN DUPLICATE ya copió todo el schema
  - Data Guard replica los cambios ongoing

**3. SSH Keys (dirección opuesta):**
- Primary: **exporta** su clave pública para que standby la importe
- Standby: **importa** clave pública de primary para permitir rsync

---

## 6. Variables de Entorno

### Variables Cargadas de install.env

**Nombres de Nodos:**
```bash
NODE1_HOSTNAME=ol8-21-dg1
NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain
NODE1_PUBLIC_IP=192.168.56.101
NODE1_DB_UNIQUE_NAME=cdb1

NODE2_HOSTNAME=ol8-21-dg2             # ⭐ Standby
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain
NODE2_PUBLIC_IP=192.168.56.102
NODE2_DB_UNIQUE_NAME=cdb1_stby        # ⭐ Unique name
```

**Oracle Paths:**
```bash
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=${ORACLE_BASE}/product/21.0.0/dbhome_1
ORA_INVENTORY=/u01/app/oraInventory
ORACLE_SID=cdb1                       # Mismo en ambos nodos
```

**Passwords:**
```bash
ROOT_PASSWORD=rootpasswd
ORACLE_PASSWORD=oracle
SYS_PASSWORD="S1sPassword1!"
PDB_PASSWORD="PdbPassword1!"
```

**Data Guard Config:**
```bash
ARCHIVE_LAG_TARGET=300                # 5 minutos
REDO_LOG_SIZE=50                      # 50MB
PROTECTION_MODE=MAXAVAILABILITY
TRANSPORT_MODE=FASTSYNC
FRA_SIZE=100G
```

---

## 7. Orden de Ejecución

### Por Qué Este Orden Específico

**1. Discos primero:**
- Necesitamos `/u01` y `/u02` para todo lo demás
- Sin esto, no podemos instalar Oracle

**2. Paquetes antes de contraseñas:**
- `oracle-database-preinstall-21c` crea el usuario `oracle`
- Necesitamos que el usuario exista antes de cambiar su contraseña

**3. Network antes de Oracle:**
- Oracle necesita resolver hostnames
- `/etc/hosts` debe estar listo

**4. Entorno Oracle antes de instalación:**
- El instalador necesita `$ORACLE_HOME`, `$ORACLE_BASE`, etc.
- `setEnv.sh` debe existir antes

**5. Software antes de database:**
- No se puede crear database sin software instalado

**6. Database antes de automatización:**
- Los scripts de automatización asumen que la DB existe

**7. SSH antes de cron jobs:**
- Los cron jobs de backup usan SSH
- Las claves deben estar configuradas primero

---

## 8. Manejo de Errores

### Estrategia de Errores

**Este script NO tiene manejo explícito de errores:**

```bash
# No hay:
set -e                    # Salir en error
set -o pipefail          # Pipefail
trap 'handler' ERR       # Error handler
```

**Comportamiento ante errores:**
- Si un script hijo falla, root_setup.sh **continúa**
- Solo para si el comando no existe

**Ejemplo:**
```bash
sh /vagrant_scripts/prepare_u01_u02_disks.sh
# Si falla, la siguiente línea se ejecuta igual
sh /vagrant_scripts/install_os_packages.sh
```

**Implicaciones:**
- Si preparación de discos falla, instalación de paquetes puede fallar más tarde
- Errores se detectan en logs, no en exit code

**Por qué no se usa set -e:**
- Algunos comandos pueden fallar intencionalmente (cleanup previo)
- Más flexibilidad para debugging
- Errores críticos causan fallo de scripts hijos (que sí usan `set -e`)

---

## 9. Logs y Verificación

### Ubicación de Logs

**Durante ejecución:**
```
Terminal/PowerShell → vagrant up standby
                      ↓
                      Logs en consola
                      ↓
                      También en: powershell/logs/deploy-TIMESTAMP/04-standby-vagrant.log
```

**Dentro de la VM:**
```bash
vagrant ssh standby

# Logs de instalación Oracle
/u01/app/oraInventory/logs/

# Logs de RMAN DUPLICATE
/u01/app/oracle/cfgtoollogs/rman/

# Logs de Data Guard
/u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log
```

---

### Verificar Cada Etapa

**1. Discos preparados:**
```bash
df -h | grep -E "/u01|/u02"
```
Debe mostrar:
```
/dev/sdb1        99G   15G   84G  16% /u01
/dev/sdc1        99G  5.0G   94G   5% /u02
```

**2. Paquetes instalados:**
```bash
rpm -q oracle-database-preinstall-21c
id oracle
```

**3. Oracle software instalado:**
```bash
ls -l /u01/app/oracle/product/21.0.0/dbhome_1/bin/oracle
```

**4. Database creada:**
```bash
ps aux | grep pmon
# Debe mostrar: ora_pmon_cdb1
```

**5. Data Guard configurado:**
```bash
sudo su - oracle
dgmgrl / "show configuration"
```
Debe mostrar:
```
Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
  cdb1        - Primary database
  cdb1_stby   - Physical standby database
```

---

## 10. Troubleshooting

### Problema: Script para en Etapa X

**Diagnóstico:**
```bash
vagrant ssh standby

# Ver último log con timestamp
grep -n "date" /vagrant/2-Standby/scripts/standby/root_setup.sh
# Ejecutar script manualmente desde esa línea
```

**Solución:**
- Identificar el script hijo que falló
- Ver su log específico
- Ejecutar manualmente para ver error detallado

---

### Problema: RMAN DUPLICATE falla (Etapa 9)

**Síntomas:**
```
ORA-01017: invalid username/password; logon denied
ORA-12170: TNS:Connect timeout occurred
RMAN-03002: failure of Duplicate Db command
```

**Causas comunes:**
1. Primary no está corriendo
2. Listener no responde
3. Password file no coincide
4. Network no configurado
5. tnsnames.ora incorrecto

**Solución:**
Ver [57-rman-duplicate.md](57-rman-duplicate.md) sección troubleshooting

---

### Problema: SSH keys no se importan

**Síntoma:**
```
ERROR: Primary's public key not found after 300 seconds!
```

**Causa:**
- Primary aún no terminó de deployar
- Archivo `/vagrant/ssh_keys/primary_id_rsa.pub` no existe

**Solución:**
```bash
# Verificar que primary terminó
vagrant status
# Debe mostrar: primary   running

# Verificar que archivo existe
ls -l /vagrant/ssh_keys/primary_id_rsa.pub

# Si no existe, primary falló en setup_ssh_keys
vagrant provision primary --provision-with root_setup
```

---

### Problema: Cron jobs no se instalan

**Síntoma:**
```bash
crontab -l
no crontab for oracle
```

**Causa:**
- `install_cron_jobs.sh` falló
- Hostname no coincide con expected

**Solución:**
```bash
sudo su - oracle
sh /home/oracle/automation/install_cron_jobs.sh

# Verificar hostname
hostname -f
# Debe ser: ol8-21-dg2.localdomain
```

---

### Problema: Todo el script tarda < 5 minutos

**Síntoma:**
- Script termina demasiado rápido
- Banner de fin se imprime casi inmediatamente

**Causa:**
- Algún script hijo falló silenciosamente
- VM ya tenía Oracle instalado (re-provisioning)

**Diagnóstico:**
```bash
vagrant ssh standby

# Ver procesos Oracle
ps aux | grep ora_

# Si no hay procesos, DB no se creó
sqlplus / as sysdba
SQL> SELECT instance_name FROM v$instance;
# Si da error, DB no existe
```

---

## Resumen

### Puntos Clave

1. **Orquestador Central:** root_setup.sh coordina 10+ scripts especializados
2. **Etapa Crítica:** RMAN DUPLICATE (Etapa 9) es la más importante y larga
3. **Diferencia con Primary:** No crea DB nueva, la copia; no deploya schema
4. **Variables Importantes:** NODE2_DB_UNIQUE_NAME=cdb1_stby (diferente de primary)
5. **Sin Manejo de Errores:** Continúa ante fallos, requiere análisis de logs
6. **1 Cron Job:** Solo limpieza de archives, no backups

### Archivos Relacionados

- **Anterior:** [50-standby-setup.md](50-standby-setup.md) - Wrapper de entrada
- **Siguiente:** [52-prepare-disks.md](52-prepare-disks.md) - Preparación de discos
- **Crítico:** [57-rman-duplicate.md](57-rman-duplicate.md) - RMAN DUPLICATE completo
- **Equivalente Primary:** `2-Standby/scripts/primary/root_setup.sh`

### Tiempo Total Típico

```
Preparar discos:       0.5 min
Instalar paquetes:     6 min
Configurar sistema:    0.5 min
Instalar Oracle:      12 min
RMAN DUPLICATE:       15 min  ⭐ (la más larga)
Automatización:        1 min
SSH + Cron:            1 min
──────────────────────────────
TOTAL:            ~26-30 min
```

---

**Siguiente:** [52 - Preparar Discos (Standby)](52-prepare-disks.md)

Este orquestador coordina todo el despliegue standby, siendo RMAN DUPLICATE el corazón del proceso.
