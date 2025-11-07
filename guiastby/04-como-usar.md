# 04 - Cómo Usar el Sistema Oracle Data Guard

## 🎯 GUÍA PRINCIPAL DE USO

Esta es la guía más importante del sistema. Aquí encontrarás **todo lo necesario para desplegar, usar y mantener** el sistema Oracle Data Guard sin necesidad de entender todos los detalles técnicos internos.

**Prerequisitos antes de continuar:**
- Has leído [03 - Prerequisitos](03-prerequisitos.md)
- Tienes Oracle Database 21c descargado en `software/LINUX.X64_213000_db_home.zip`
- VirtualBox y Vagrant están instalados
- Tu máquina cumple los requisitos de hardware

---

## 📋 Tabla de Contenidos

1. [Despliegue Completo (Método Recomendado)](#1-despliegue-completo-método-recomendado)
2. [Operaciones Individuales con Vagrant](#2-operaciones-individuales-con-vagrant)
3. [Destrucción del Ambiente](#3-destrucción-del-ambiente)
4. [Provisioners On-Demand](#4-provisioners-on-demand)
5. [Verificación del Sistema](#5-verificación-del-sistema)
6. [Conexiones a las Bases de Datos](#6-conexiones-a-las-bases-de-datos)
7. [Scripts de Mantenimiento](#7-scripts-de-mantenimiento)
8. [Monitoreo de Logs en Tiempo Real](#8-monitoreo-de-logs-en-tiempo-real)
9. [Troubleshooting Rápido](#9-troubleshooting-rápido)

---

## 1. Despliegue Completo (Método Recomendado)

### 🚀 Comando Principal

Desde la raíz del proyecto en PowerShell:

```powershell
.\powershell\deploy.ps1
```

Este único comando despliega **todo el sistema Data Guard** de principio a fin de forma completamente automatizada.

### ⏱️ Tiempo Esperado

- **Mínimo:** 50 minutos (hardware rápido, SSD)
- **Típico:** 60-70 minutos (hardware estándar)
- **Máximo:** 75+ minutos (hardware lento, HDD)

### 📊 Las 6 Fases del Despliegue

El script ejecuta estas fases automáticamente:

#### **Fase 1: Verificación de Prerequisitos** (10-15 segundos)

**Qué verás en consola:**
```
=== Phase 1: Checking Prerequisites ===
Checking for Oracle software...
✓ Found: software/LINUX.X64_213000_db_home.zip (2.9 GB)
Checking VirtualBox...
✓ VirtualBox is running
✓ Found VBoxManage at: C:\Program Files\Oracle\VirtualBox\VBoxManage.exe
Checking Vagrant...
✓ Vagrant is installed: 2.4.1
Creating log directory: powershell/logs/deploy-2025-11-04-143522
```

**Qué hace:**
- Verifica que `LINUX.X64_213000_db_home.zip` existe en `software/`
- Verifica que el servicio de VirtualBox está corriendo
- Verifica que Vagrant está instalado
- Crea directorio de logs con timestamp

**Si falla:** Revisa que cumples los [prerequisitos](03-prerequisitos.md)

---

#### **Fase 2: Corrección de Line Endings** (1-2 segundos)

**Qué verás en consola:**
```
=== Phase 2: Fixing Line Endings ===
Running fix-line-endings.ps1...
Converting CRLF to LF for Linux compatibility...
✓ Converted 47 shell scripts
```

**Qué hace:**
- Convierte archivos shell (`.sh`) de CRLF (Windows) a LF (Linux)
- Crítico para evitar errores de sintaxis en Linux
- Convierte scripts en: `2-Standby/scripts/`, `2-Standby/automation/`, `2-Standby/infrastructure/`

**Por qué es necesario:** Windows usa dos caracteres para nuevas líneas (CR+LF), Linux usa uno solo (LF). Sin esta conversión, los scripts shell fallarían.

---

#### **Fase 3: Limpieza de VMs Antiguas** (10-30 segundos)

**Qué verás en consola:**
```
=== Phase 3: Cleaning Up Stale VMs ===
Destroying existing Vagrant VMs...
==> primary: VM not created. Moving on...
==> standby: VM not created. Moving on...

Unregistering VMs from VirtualBox...
Checking for: ol8_21_dg1_primary, ol8_21_dg2_standby
Cleaning VM directories...
✓ Cleanup complete
```

**Qué hace:**
- Ejecuta `vagrant destroy -f` para eliminar VMs de Vagrant
- Ejecuta `VBoxManage unregistervm --delete` para limpiar VirtualBox
- Elimina directorios huérfanos de VMs

**Si es tu primera ejecución:** Esta fase no hace nada (no hay VMs previas)

**Si reinicias el despliegue:** Esta fase elimina las VMs anteriores para empezar limpio

---

#### **Fase 4: Despliegue del Primary Database** (30-45 minutos) ⏰

**Qué verás en consola:**
```
=== Phase 4: Deploying Primary Database ===
Starting: vagrant up primary
This will take 30-45 minutes...

Bringing machine 'primary' up with 'virtualbox' provider...
==> primary: Importing base box 'oraclelinux/8'...
==> primary: Matching MAC address for NAT networking...
==> primary: Setting the name of the VM: ol8_21_dg1_primary
==> primary: Clearing any previously set network interfaces...
==> primary: Preparing network interfaces based on configuration...
==> primary: Forwarding ports...
    primary: 1521 (guest) => 1521 (host) (adapter 1)
    primary: 5500 (guest) => 5500 (host) (adapter 1)
==> primary: Running 'pre-boot' VM customizations...
==> primary: Booting VM...
==> primary: Waiting for machine to boot...
==> primary: Machine booted and ready!
==> primary: Checking for guest additions in VM...
==> primary: Setting hostname...
==> primary: Configuring and enabling network interfaces...
==> primary: Mounting shared folders...
    primary: /vagrant => C:/Users/StarAlchemist/DataGripProjects/AdminBDProyecto
    primary: /vagrant_config => C:/Users/StarAlchemist/DataGripProjects/AdminBDProyecto/config
    [... más synced folders ...]
==> primary: Running provisioner: shell...
    primary: Running: C:/Users/.../2-Standby/scripts/primary/setup.sh
```

**Después comenzarás a ver logs del provisioning:**

```
primary: ===================================================
primary: PRIMARY NODE SETUP - Starting...
primary: ===================================================
primary:
primary: [Step 1/12] Preparing disks u01 and u02...
primary: Creating partition on /dev/sdb...
primary: Creating partition on /dev/sdc...
primary: Formatting /dev/sdb1 as XFS...
primary: Formatting /dev/sdc1 as XFS...
primary: Mounting /u01...
primary: Mounting /u02...
primary: ✓ Disks prepared successfully
primary:
primary: [Step 2/12] Installing OS packages...
primary: Installing oracle-database-preinstall-21c...
primary: Installing additional packages (48 packages)...
primary: [This takes 5-10 minutes]
primary: ✓ Packages installed
primary:
primary: [Step 3/12] Configuring network...
primary: Setting hostname to ol8-21-dg1.localdomain...
primary: Configuring /etc/hosts...
primary: Configuring chrony for time sync...
primary: ✓ Network configured
primary:
primary: [Step 4/12] Setting up Oracle user environment...
primary: Creating setEnv.sh...
primary: ✓ Oracle environment configured
primary:
primary: [Step 5/12] Installing Oracle Database 21c...
primary: Copying Oracle software to /u01/software/...
primary: Unzipping Oracle software (this takes 3-5 minutes)...
primary: Running Oracle installer (silent mode)...
primary: [This takes 10-15 minutes - be patient]
primary: Running root scripts...
primary: ✓ Oracle software installed
primary:
primary: [Step 6/12] Creating primary database...
primary: Configuring network (tnsnames.ora, listener.ora, sqlnet.ora)...
primary: Starting listener...
primary: Running dbca (database creation assistant)...
primary: [This takes 15-20 minutes]
primary: Database creation progress: 10%...
primary: Database creation progress: 25%...
primary: Database creation progress: 50%...
primary: Database creation progress: 75%...
primary: Database creation progress: 100%
primary: Configuring Data Guard parameters...
primary: Running: prepare database for data guard...
primary: Creating standby redo logs...
primary: Enabling Flashback Database...
primary: ✓ Database cdb1 created successfully
primary:
primary: [Step 7/12] Deploying custom schema...
primary: Opening PDB pdb1...
primary: Connecting to pdb1...
primary: Executing Script_SchemeTableSpace.sql...
primary: Executing ScriptProyectoBD.SQL...
primary: Creating tables, sequences, triggers, packages...
primary: ✓ Schema HEALTHCENTER deployed
primary:
primary: [Step 8/12] Setting up automation scripts...
primary: Copying scripts from /vagrant_automation...
primary: Setting permissions...
primary: ✓ Automation configured
primary:
primary: [Step 9/12] Setting up SSH keys...
primary: Generating RSA 4096-bit key pair...
primary: Exporting public key to /vagrant/ssh_keys/...
primary: ✓ SSH keys configured
primary:
primary: [Step 10/12] Installing cron jobs...
primary: Installing check_log_transport.sh (every 10 minutes)...
primary: Installing rman_daily_backup.sh (daily 1 AM)...
primary: Installing delete_archives_primary.sh (daily 2 AM)...
primary: ✓ Cron jobs installed
primary:
primary: ===================================================
primary: PRIMARY NODE SETUP - COMPLETE
primary: Time elapsed: 43 minutes
primary: ===================================================
```

**Salida del script:**
- Logs guardados en: `powershell/logs/deploy-TIMESTAMP/03-primary-vagrant.log`

**Qué se crea:**
- VM: `ol8_21_dg1_primary` (192.168.56.101)
- Base de datos CDB: `cdb1`
- Pluggable Database: `pdb1`
- Esquema: `HEALTHCENTER` con tablas del sistema healthcare
- Listener en puerto 1521
- 3 cron jobs configurados

**Puedes tomar un café en esta fase.** Es la más larga.

---

#### **Fase 5: Despliegue del Standby Database** (20-30 minutos) ⏰

**Qué verás en consola:**
```
=== Phase 5: Deploying Standby Database ===
Starting: vagrant up standby
This will take 20-30 minutes...

Bringing machine 'standby' up with 'virtualbox' provider...
[... similar VM creation to primary ...]
==> standby: Running provisioner: shell...
```

**Logs del provisioning:**

```
standby: ===================================================
standby: STANDBY NODE SETUP - Starting...
standby: ===================================================
standby:
standby: [Step 1/10] Preparing disks u01 and u02...
standby: ✓ Disks prepared successfully
standby:
standby: [Step 2/10] Installing OS packages...
standby: ✓ Packages installed
standby:
standby: [Step 3/10] Configuring network...
standby: Setting hostname to ol8-21-dg2.localdomain...
standby: ✓ Network configured
standby:
standby: [Step 4/10] Setting up Oracle user environment...
standby: Creating setEnv.sh with ORACLE_UNQNAME=cdb1_stby...
standby: ✓ Oracle environment configured
standby:
standby: [Step 5/10] Installing Oracle Database 21c...
standby: [Same as primary - 10-15 minutes]
standby: ✓ Oracle software installed
standby:
standby: [Step 6/10] Creating standby database...
standby: Configuring network...
standby: Starting listener...
standby: Creating directory structure...
standby: Creating password file (matching primary)...
standby: Starting auxiliary instance in NOMOUNT mode...
standby: Testing connectivity to primary...
standby: ✓ Primary is reachable at cdb1.world
standby:
standby: Running RMAN DUPLICATE FOR STANDBY...
standby: ╔═══════════════════════════════════════════════════╗
standby: ║   RMAN DUPLICATE - Copying entire database       ║
standby: ║   This takes 10-20 minutes                        ║
standby: ╚═══════════════════════════════════════════════════╝
standby:
standby: RMAN> duplicate target database
standby:         for standby
standby:         from active database
standby:         dorecover;
standby:
standby: Starting Duplicate Db at 04-NOV-25
standby: allocated channel: ORA_AUX_DISK_1
standby: channel ORA_AUX_DISK_1: SID=245 device type=DISK
standby:
standby: contents of Memory Script:
standby: {
standby:    backup as copy reuse
standby:    targetfile '/u01/app/oracle/product/21.0.0/dbhome_1/dbs/orapwcdb1' ...
standby: }
standby: executing Memory Script
standby:
standby: [Copying datafiles - progress updates every few minutes]
standby: channel ORA_AUX_DISK_1: datafile copy complete, elapsed time: 00:02:15
standby: channel ORA_AUX_DISK_1: starting datafile copy
standby: input datafile file number=00001 name=/u01/oradata/CDB1/system01.dbf
standby: output file name=/u01/oradata/CDB1/system01.dbf tag=...
standby: channel ORA_AUX_DISK_1: datafile copy complete, elapsed time: 00:05:32
standby: [... continues for all datafiles ...]
standby:
standby: Finished Duplicate Db at 04-NOV-25
standby: ✓ RMAN DUPLICATE complete
standby:
standby: Enabling Flashback Database on standby...
standby: ✓ Flashback enabled
standby:
standby: Configuring Data Guard Broker...
standby: Enabling broker on primary...
standby: Enabling broker on standby...
standby: Creating Data Guard configuration...
standby:
standby: DGMGRL> create configuration dg_config as
standby:           primary database is cdb1 connect identifier is cdb1.world;
standby: Configuration "dg_config" created with primary database "cdb1"
standby:
standby: DGMGRL> add database cdb1_stby as
standby:           connect identifier is cdb1_stby.world
standby:           maintained as physical;
standby: Database "cdb1_stby" added
standby:
standby: DGMGRL> enable configuration;
standby: Enabled.
standby:
standby: Setting protection mode to MAXAVAILABILITY...
standby: Setting LogXptMode to FASTSYNC...
standby: Verifying configuration...
standby: ✓ Protection mode: MAXIMUM AVAILABILITY
standby: ✓ LogXptMode: FASTSYNC
standby:
standby: Validating Data Guard configuration...
standby: ✓ Primary database validated
standby: ✓ Standby database validated
standby: ✓ Custom schema replicated successfully
standby:
standby: [Step 7/10] Setting up automation scripts...
standby: ✓ Automation configured
standby:
standby: [Step 8/10] Setting up SSH keys...
standby: Importing primary's public key...
standby: Exporting standby host keys...
standby: ✓ SSH keys configured
standby:
standby: [Step 9/10] Installing cron jobs...
standby: Installing delete_archives_standby.sh (daily 11 PM)...
standby: ✓ Cron jobs installed
standby:
standby: ===================================================
standby: STANDBY NODE SETUP - COMPLETE
standby: Time elapsed: 28 minutes
standby: ===================================================
```

**Salida del script:**
- Logs guardados en: `powershell/logs/deploy-TIMESTAMP/04-standby-vagrant.log`

**Qué se crea:**
- VM: `ol8_21_dg2_standby` (192.168.56.102)
- Base de datos standby: `cdb1_stby`
- Copia completa de primary (incluyendo PDB y esquema HEALTHCENTER)
- Data Guard Broker configurado
- Replicación sincrónica activa

**El paso más importante:** RMAN DUPLICATE copia toda la base de datos primary al standby a través de la red. Esto incluye todos los datos del esquema healthcare.

---

#### **Fase 5.5: Verificación Post-Despliegue** (30-60 segundos)

**Qué verás en consola:**
```
=== Phase 5.5: Post-Deployment Verification ===
Importing standby SSH keys to primary...
✓ SSH keys imported

Testing SSH connectivity primary → standby...
Executing: vagrant ssh primary -c "ssh oracle@ol8-21-dg2.localdomain hostname"
ol8-21-dg2.localdomain
✓ SSH connectivity verified

Verifying cron jobs installation...
Primary cron jobs: 3 found
  - check_log_transport.sh (every 10 minutes)
  - rman_daily_backup.sh (daily 1 AM)
  - delete_archives_primary.sh (daily 2 AM)
Standby cron jobs: 1 found
  - delete_archives_standby.sh (daily 11 PM)
✓ Cron jobs verified
```

**Qué hace:**
- Importa host keys de standby al primary para SSH sin contraseña
- Prueba conectividad SSH primary → standby
- Verifica que los cron jobs estén instalados correctamente

**Si algo falla aquí:** No es crítico, pero el backup automático podría fallar. Revisa [Troubleshooting](#9-troubleshooting-rápido).

---

#### **Fase 6: Recolección de Logs** (10-20 segundos)

**Qué verás en consola:**
```
=== Phase 6: Collecting Logs ===
Fetching primary alert log...
✓ Saved to: logs/deploy-TIMESTAMP/05-primary-alert-log.txt

Fetching primary listener log...
✓ Saved to: logs/deploy-TIMESTAMP/05-primary-listener-log.txt

Fetching standby alert log...
✓ Saved to: logs/deploy-TIMESTAMP/05-standby-alert-log.txt

Fetching standby listener log...
✓ Saved to: logs/deploy-TIMESTAMP/05-standby-listener-log.txt

Running Data Guard verification...
vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"
✓ Saved to: logs/deploy-TIMESTAMP/06-dataguard-verification.txt

Generating deployment summary...
✓ Saved to: logs/deploy-TIMESTAMP/DEPLOYMENT-SUMMARY.txt
```

**Qué hace:**
- Copia los alert logs de Oracle desde ambas VMs
- Copia los listener logs
- Ejecuta script de verificación de Data Guard
- Genera resumen del despliegue

---

### 📄 Resultado Final

**Consola mostrará:**

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        ORACLE DATA GUARD DEPLOYMENT COMPLETE                  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

✓ Primary Database:  cdb1 (192.168.56.101:1521)
✓ Standby Database:  cdb1_stby (192.168.56.102:1521 → host:1522)
✓ Protection Mode:   MAXAVAILABILITY
✓ Transport Mode:    FASTSYNC
✓ Custom Schema:     HEALTHCENTER replicated ✓

Total deployment time: 67 minutes

Logs available at:
  powershell/logs/deploy-2025-11-04-143522/

Deployment summary:
  powershell/logs/deploy-2025-11-04-143522/DEPLOYMENT-SUMMARY.txt

Next steps:
  1. Verify Data Guard: vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"
  2. Connect to database: sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba
  3. Connect to schema: sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1
  4. Read: guiastby/05-arquitectura-sistema.md for details

╔════════════════════════════════════════════════════════════════╗
║  System is ready for use. Data Guard is actively replicating. ║
╚════════════════════════════════════════════════════════════════╝
```

**Archivos generados en `powershell/logs/deploy-TIMESTAMP/`:**

- `01-prerequisites.log` - Verificación de prerequisitos
- `02-fix-line-endings.log` - Conversión de scripts
- `03-primary-vagrant.log` - Despliegue completo de primary (salida de vagrant)
- `04-standby-vagrant.log` - Despliegue completo de standby
- `04a-verification.log` - Verificación post-despliegue
- `05-primary-alert-log.txt` - Alert log de Oracle primary
- `05-primary-listener-log.txt` - Listener log primary
- `05-standby-alert-log.txt` - Alert log de Oracle standby
- `05-standby-listener-log.txt` - Listener log standby
- `06-dataguard-verification.txt` - Estado completo de Data Guard
- `DEPLOYMENT-SUMMARY.txt` - Resumen ejecutivo con configuración y tiempos

---

## 2. Operaciones Individuales con Vagrant

Si prefieres más control o necesitas desplegar solo una VM, usa comandos Vagrant directamente.

### 📍 Comandos Básicos

#### Iniciar Primary Solamente

```bash
vagrant up primary
```

**Cuándo usar:**
- Desarrollo de schema sin necesidad de standby
- Pruebas de configuración
- Troubleshooting de issues específicos del primary

**Tiempo:** 30-45 minutos

---

#### Iniciar Standby Solamente

```bash
vagrant up standby
```

**Prerequisito:** Primary debe existir y estar corriendo. Standby se conecta a primary durante RMAN DUPLICATE.

**Cuándo usar:**
- Re-crear standby después de pruebas destructivas
- Troubleshooting de issues de replicación

**Tiempo:** 20-30 minutos

---

#### Conectar a VMs vía SSH

```bash
# Conectar a primary
vagrant ssh primary

# Conectar a standby
vagrant ssh standby
```

**Dentro de la VM puedes:**

```bash
# Cambiar a usuario oracle
sudo su - oracle

# Ver variables de entorno
cat ~/scripts/setEnv.sh

# Conectar a SQL*Plus
sqlplus / as sysdba

# Ver estado del listener
lsnrctl status

# Ver logs
tail -f /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log
```

---

#### Reiniciar una VM

```bash
# Reiniciar (apaga y vuelve a encender)
vagrant reload primary
vagrant reload standby

# Nota: Oracle NO se inicia automáticamente después de reload
# Ver sección "Provisioners On-Demand" para habilitar auto-start
```

---

#### Apagar VMs

```bash
# Apagar limpiamente
vagrant halt primary
vagrant halt standby

# O ambas
vagrant halt
```

**Nota:** Oracle se apaga limpiamente antes de la VM. Los datos están seguros.

---

#### Reanudar VMs Apagadas

```bash
vagrant up primary
vagrant up standby
```

**Importante:** Si las VMs ya existen, `vagrant up` solo las enciende, NO ejecuta provisioners.

**Para iniciar Oracle manualmente después de reload/halt:**

```bash
vagrant ssh primary

# Dentro de la VM
sudo su - oracle
lsnrctl start
sqlplus / as sysdba <<EOF
STARTUP;
EXIT;
EOF
```

**Para auto-inicio automático:** Ver sección [Provisioners On-Demand](#4-provisioners-on-demand).

---

#### Ver Estado de las VMs

```bash
vagrant status
```

**Salida:**
```
Current machine states:

primary                   running (virtualbox)
standby                   running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state.
```

**Estados posibles:**
- `not created` - VM no existe
- `running` - VM encendida
- `poweroff` - VM apagada
- `saved` - VM suspendida (no recomendado para databases)

---

#### Re-ejecutar Provisioners

```bash
# Re-ejecutar provisioning completo
vagrant provision primary
vagrant provision standby
```

**Cuándo usar:**
- Después de modificar scripts en `2-Standby/scripts/`
- Para aplicar cambios de configuración
- NO lo uses si ya tienes datos importantes (destructivo)

**Advertencia:** Esto puede re-crear la base de datos. Solo úsalo si entiendes qué hará cada provisioner.

---

## 3. Destrucción del Ambiente

### 🗑️ Eliminación Completa con PowerShell (Recomendado)

```powershell
.\powershell\destroy.ps1
```

**Qué hace:**
1. Ejecuta `vagrant destroy -f` (elimina VMs de Vagrant)
2. Ejecuta `VBoxManage unregistervm --delete` (limpia VirtualBox)
3. Elimina directorios huérfanos de VMs
4. Limpia archivos de estado de Vagrant (`.vagrant/`)
5. Opcionalmente elimina discos VDI (te pregunta)

**Advertencia:** ⚠️ **ESTO ELIMINA TODAS LAS BASES DE DATOS Y DATOS**

**Qué NO elimina:**
- El código del proyecto
- Los logs en `powershell/logs/`
- El archivo ZIP de Oracle en `software/`
- Claves SSH en `ssh_keys/`

---

### 🗑️ Eliminación con Vagrant Solamente

```bash
# Eliminar todas las VMs
vagrant destroy -f

# Eliminar solo una VM
vagrant destroy -f primary
vagrant destroy -f standby
```

**Diferencia con destroy.ps1:** Vagrant destroy solo elimina las VMs, pero puede dejar artifacts en VirtualBox.

**Para limpieza completa manual después de vagrant destroy:**

```powershell
# Ver VMs registradas en VirtualBox
VBoxManage list vms

# Si ves ol8_21_dg1 o ol8_21_dg2, elimínalas:
VBoxManage unregistervm ol8_21_dg1_primary --delete
VBoxManage unregistervm ol8_21_dg2_standby --delete
```

---

### ⚠️ Cuándo Usar Destroy

**Usa destroy cuando:**
- Terminas las pruebas y necesitas liberar espacio (VMs ocupan ~100GB c/u)
- Quieres empezar desde cero con configuración limpia
- Tienes errores irrecuperables durante el despliegue
- Vas a actualizar scripts y necesitas un despliegue limpio

**NO uses destroy si:**
- Solo quieres reiniciar Oracle (usa `vagrant reload`)
- Solo quieres probar cambios en el schema (conéctate y hazlos directamente)
- Tienes datos de prueba importantes (haz backup primero)

---

## 4. Provisioners On-Demand

Algunos provisioners están configurados como `run: "never"` y solo se ejecutan cuando los solicitas explícitamente.

### 🔄 Provisioner: deploy_sql_and_directories

**Propósito:** Desplegar SQLs y directorios adicionales desde `1-BD/SQL-VM scripts/` y `1-BD/directories/`.

**Uso:**

```bash
# En primary
vagrant provision primary --provision-with deploy_sql_and_directories

# En standby
vagrant provision standby --provision-with deploy_sql_and_directories
```

**Qué hace:**
- Copia scripts SQL desde `/vagrant_sql_scripts/` a `/home/oracle/custom_sql/`
- Copia directorios desde `/vagrant_directories/` a `/u01/app/oracle/admin/directories/`
- Ejecuta scripts de setup si existen

**Cuándo usar:**
- Después de agregar nuevos scripts SQL al proyecto
- Para desplegar procedimientos, funciones o packages adicionales
- Para actualizar directorios Oracle (UTL_FILE, external tables)

---

### 🚀 Provisioner: setup_oracle_autostart

**Propósito:** Configurar Oracle para que se inicie automáticamente cuando la VM arranca.

**Uso:**

```bash
vagrant provision primary --provision-with setup_oracle_autostart
vagrant provision standby --provision-with setup_oracle_autostart
```

**Qué hace:**
- Crea archivo systemd unit: `/etc/systemd/system/oracle.service`
- Configura Oracle Listener para inicio automático
- Configura Database para inicio automático
- Habilita el servicio: `systemctl enable oracle`

**Después de ejecutar esto:**

```bash
# Reinicia la VM y Oracle se iniciará automáticamente
vagrant reload primary

# Verifica que Oracle está corriendo
vagrant ssh primary -c "ps aux | grep pmon"
```

**Cuándo usar:**
- Si frecuentemente reinicias las VMs (`vagrant reload`)
- Si tu host Windows se reinicia frecuentemente
- Para simular comportamiento de producción

**Cuándo NO usar:**
- Si solo usas el ambiente ocasionalmente (ahorra recursos)
- Si prefieres control manual del inicio de Oracle

---

## 5. Verificación del Sistema

### ✅ Verificación Completa de Data Guard

Ejecuta el script de verificación más completo:

```bash
vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"
```

**Salida esperada:**

```
═══════════════════════════════════════════════════════════
   ORACLE DATA GUARD - VERIFICATION REPORT
═══════════════════════════════════════════════════════════
Generated: 04-NOV-2025 15:30:22

─────────────────────────────────────────
1. DATABASE ROLES AND STATUS
─────────────────────────────────────────

PRIMARY DATABASE (cdb1):
  Database Role:        PRIMARY
  Open Mode:            READ WRITE
  Protection Mode:      MAXIMUM AVAILABILITY
  Protection Level:     MAXIMUM AVAILABILITY
  Switchover Status:    TO STANDBY
  Flashback:            ON
  Force Logging:        YES

STANDBY DATABASE (cdb1_stby):
  Database Role:        PHYSICAL STANDBY
  Open Mode:            READ ONLY WITH APPLY
  Protection Mode:      MAXIMUM AVAILABILITY
  Flashback:            ON
  MRP Status:           APPLYING_LOG

─────────────────────────────────────────
2. ARCHIVE LOG DESTINATIONS
─────────────────────────────────────────

Destination 1 (Local): VALID
  Type:          LOCAL
  Destination:   /u01/oradata/cdb1/arch
  Status:        VALID
  Binding:       OPTIONAL

Destination 2 (Standby): VALID
  Type:          PHYSICAL
  Destination:   cdb1_stby
  Status:        VALID
  Binding:       MANDATORY
  Network:       YES
  Reopen Secs:   300
  Log Sequence:  145

─────────────────────────────────────────
3. STANDBY REDO LOGS
─────────────────────────────────────────

PRIMARY Standby Redo Logs:
  4 groups configured
  Size: 50 MB each
  Status: UNASSIGNED (normal for primary)

STANDBY Standby Redo Logs:
  4 groups configured
  Size: 50 MB each
  Status: ACTIVE (receiving redo)

─────────────────────────────────────────
4. LOG SHIPPING STATUS
─────────────────────────────────────────

Last 10 Log Switches:
  Seq#    Thread  First Time            Switch Time           Applied
  ─────────────────────────────────────────────────────────────────
  136     1       04-NOV-25 14:05:12    04-NOV-25 14:10:15    YES
  137     1       04-NOV-25 14:10:15    04-NOV-25 14:15:18    YES
  138     1       04-NOV-25 14:15:18    04-NOV-25 14:20:21    YES
  139     1       04-NOV-25 14:20:21    04-NOV-25 14:25:24    YES
  140     1       04-NOV-25 14:25:24    04-NOV-25 14:30:27    YES
  141     1       04-NOV-25 14:30:27    04-NOV-25 14:35:30    YES
  142     1       04-NOV-25 14:35:30    04-NOV-25 14:40:33    YES
  143     1       04-NOV-25 14:40:33    04-NOV-25 14:45:36    YES
  144     1       04-NOV-25 14:45:36    04-NOV-25 14:50:39    YES
  145     1       04-NOV-25 14:50:39    04-NOV-25 14:55:42    YES

✓ All logs applied to standby

─────────────────────────────────────────
5. APPLY LAG
─────────────────────────────────────────

Apply Lag: 0 seconds
Transport Lag: 0 seconds

✓ Standby is fully synchronized

─────────────────────────────────────────
6. ARCHIVE LOG GAPS
─────────────────────────────────────────

Checking for gaps in sequence...

✓ No archive log gaps detected

─────────────────────────────────────────
7. DATA GUARD BROKER CONFIGURATION
─────────────────────────────────────────

Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1        - Primary database
  cdb1_stby   - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 3 seconds ago)

Database - cdb1

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Transport Lag:      0 seconds (computed 2 seconds ago)
  Apply Lag:          0 seconds (computed 2 seconds ago)
  Average Apply Rate: 15.00 KByte/s
  Real Time Query:    OFF

Database Status:
SUCCESS

Database - cdb1_stby

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON
  Transport Lag:      0 seconds (computed 2 seconds ago)
  Apply Lag:          0 seconds (computed 2 seconds ago)
  Average Apply Rate: 15.00 KByte/s
  Real Time Query:    ON
  Instance(s):
    cdb1

Database Status:
SUCCESS

─────────────────────────────────────────
8. CUSTOM SCHEMA VERIFICATION
─────────────────────────────────────────

Checking HEALTHCENTER schema on PRIMARY:
  User exists: YES
  Tables: 15
  Sequences: 15
  Triggers: 8
  Packages: 5
  Sample table count (HC_User): 5 rows

Checking HEALTHCENTER schema on STANDBY:
  Tables: 15 ✓
  Sequences: 15 ✓
  Triggers: 8 ✓
  Packages: 5 ✓

✓ Schema replicated successfully

═══════════════════════════════════════════════════════════
   DATA GUARD VERIFICATION: PASSED
   All checks successful. System is healthy.
═══════════════════════════════════════════════════════════
```

**Qué verificar:**
- ✅ Protection Mode: MAXIMUM AVAILABILITY
- ✅ Apply Lag: 0 seconds (o <5 segundos)
- ✅ No archive log gaps
- ✅ Database Status: SUCCESS
- ✅ Custom schema replicated

**Si algo muestra error:** Ver sección [9. Troubleshooting Rápido](#9-troubleshooting-rápido).

---

### 🔍 Verificaciones Rápidas desde Windows

#### Verificar que VMs están corriendo

```powershell
vagrant status
```

Debes ver ambas en estado `running`.

---

#### Verificar que Oracle Listener responde (Primary)

```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba <<EOF
SELECT instance_name, status, database_role FROM v\$instance, v\$database;
EXIT;
EOF
```

**Salida esperada:**
```
INSTANCE_NAME    STATUS       DATABASE_ROLE
---------------- ------------ ----------------
cdb1             OPEN         PRIMARY
```

---

#### Verificar que Oracle Listener responde (Standby)

```bash
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<EOF
SELECT instance_name, status, database_role FROM v\$instance, v\$database;
EXIT;
EOF
```

**Salida esperada:**
```
INSTANCE_NAME    STATUS       DATABASE_ROLE
---------------- ------------ ----------------
cdb1             MOUNTED      PHYSICAL STANDBY
```

**Nota:** El puerto del standby desde Windows es **1522** (forwarded), no 1521.

---

#### Verificar replicación básica

```bash
# Generar actividad en primary
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 <<EOF
INSERT INTO HC_HealthCenter (HCT_id, HCT_name, HCT_location, HCT_phone)
VALUES (9999, 'Test Center', 'Test Location', '555-TEST');
COMMIT;
SELECT COUNT(*) FROM HC_HealthCenter WHERE HCT_id=9999;
EXIT;
EOF
```

**Salida:** `1`

```bash
# Forzar switch de log (para aplicación inmediata)
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF

# Esperar 5-10 segundos
timeout /t 10

# Verificar en standby (requiere open read only)
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<EOF
ALTER DATABASE OPEN READ ONLY;
ALTER PLUGGABLE DATABASE pdb1 OPEN READ ONLY;
EXIT;
EOF

sqlplus HEALTHCENTER/HCApp2025!@localhost:1522/pdb1 <<EOF
SELECT COUNT(*) FROM HC_HealthCenter WHERE HCT_id=9999;
EXIT;
EOF
```

**Salida esperada:** `1` (el dato se replicó)

---

## 6. Conexiones a las Bases de Datos

### 🔌 Desde Windows Host

#### Conectar a CDB (Container) del Primary

```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba
```

**Uso:**
- Administración de la base de datos
- Crear/eliminar PDBs
- Ver configuración de Data Guard
- Gestión de tablespaces del CDB

---

#### Conectar a PDB (Pluggable Database) del Primary

```bash
sqlplus sys/S1sPassword1!@localhost:1521/pdb1 as sysdba
```

**Uso:**
- Administración de la PDB
- Gestión de usuarios y tablespaces del PDB

---

#### Conectar al Esquema de Aplicación (Primary)

```bash
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1
```

**Uso:**
- Desarrollo de queries
- Insertar/actualizar datos
- Ejecutar procedimientos del healthcare system
- Generar month scales, payrolls, etc.

**Ejemplos:**

```sql
-- Ver tablas
SELECT table_name FROM user_tables ORDER BY table_name;

-- Ver usuarios
SELECT USR_id, USR_name, USR_email FROM HC_User;

-- Generar month scale
EXEC generate_month_scale('11', 2025, 1);

-- Ver payrolls
SELECT * FROM HC_Payroll;
```

---

#### Conectar a Standby (Read-Only)

```bash
# CDB standby
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba

# PDB standby (requiere abrir primero)
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<EOF
ALTER DATABASE OPEN READ ONLY;
ALTER PLUGGABLE DATABASE pdb1 OPEN READ ONLY;
EXIT;
EOF

sqlplus HEALTHCENTER/HCApp2025!@localhost:1522/pdb1
```

**Uso:**
- Queries de lectura sin impactar primary
- Reportes pesados
- Verificar replicación

**Limitación:** Standby físico es READ ONLY. No puedes hacer INSERT/UPDATE/DELETE.

---

### 🔌 Desde Dentro de las VMs

#### SSH a Primary y conectar

```bash
vagrant ssh primary

# Cambiar a usuario oracle
sudo su - oracle

# Las variables de entorno ya están cargadas (setEnv.sh)
echo $ORACLE_SID    # cdb1
echo $ORACLE_HOME   # /u01/app/oracle/product/21.0.0/dbhome_1

# Conectar directamente (sin tnsnames)
sqlplus / as sysdba

# O conectar a PDB
sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=pdb1;
SHOW CON_NAME;
EXIT;
EOF

# O conectar al esquema
sqlplus HEALTHCENTER/HCApp2025!@pdb1
```

---

#### SSH a Standby y conectar

```bash
vagrant ssh standby
sudo su - oracle

sqlplus / as sysdba

# Verificar rol
SQL> SELECT database_role FROM v$database;

DATABASE_ROLE
----------------
PHYSICAL STANDBY
```

---

### 🗂️ Archivos TNS

Si quieres conectar desde herramientas gráficas (SQL Developer, DBeaver, DataGrip), necesitas configurar TNS.

**Dentro de las VMs**, los archivos TNS están en:
- `/u01/app/oracle/product/21.0.0/dbhome_1/network/admin/tnsnames.ora`
- `/u01/app/oracle/product/21.0.0/dbhome_1/network/admin/listener.ora`

**Para conectar desde Windows con herramientas GUI:**

Crea un archivo `tnsnames.ora` en tu máquina:

```
# C:\oracle\network\admin\tnsnames.ora

CDB1_PRIMARY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVICE_NAME = cdb1)
    )
  )

PDB1_PRIMARY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVICE_NAME = pdb1)
    )
  )

CDB1_STANDBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    (CONNECT_DATA =
      (SERVICE_NAME = cdb1_stby)
    )
  )

PDB1_STANDBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    (CONNECT_DATA =
      (SERVICE_NAME = pdb1)
    )
  )
```

Luego en tu herramienta GUI:
- **Connection Type:** TNS
- **TNS Name:** CDB1_PRIMARY, PDB1_PRIMARY, etc.
- **Username:** sys (as sysdba) o HEALTHCENTER
- **Password:** S1sPassword1! o HCApp2025!

**Alternativamente (sin TNS):**
- **Host:** localhost
- **Port:** 1521 (primary) o 1522 (standby)
- **Service Name:** cdb1, pdb1, o cdb1_stby

---

## 7. Scripts de Mantenimiento

Todos los scripts de mantenimiento están en `/home/oracle/automation/` dentro de las VMs.

### 🕒 Scripts Automatizados (Cron)

Estos scripts se ejecutan automáticamente. Ver logs en `/home/oracle/logs/automation/`.

#### check_log_transport.sh (Primary)

**Frecuencia:** Cada 10 minutos
**Propósito:** Monitorear lag de replicación

**Ejecutar manualmente:**

```bash
vagrant ssh primary -c "/home/oracle/automation/check_log_transport.sh"
```

**Salida:**
```
[2025-11-04 15:30:00] Checking Data Guard log transport status...
Primary last archived sequence: 145
Standby last applied sequence: 145
Archive gap: 0 sequences
Apply lag: 0 seconds
✓ Data Guard replication is healthy
```

**Ver log histórico:**
```bash
vagrant ssh primary -c "cat /home/oracle/logs/automation/check_log_transport.log"
```

---

#### rman_daily_backup.sh (Primary)

**Frecuencia:** Diario 1 AM
**Propósito:** Backup RMAN completo + transferencia a standby

**Ejecutar manualmente:**

```bash
vagrant ssh primary -c "/home/oracle/automation/rman_daily_backup.sh"
```

**Salida:**
```
=== RMAN Backup Started: 2025-11-04 15:35:00 ===

Running RMAN backup...
Recovery Manager: Release 21.0.0.0.0 - Production
connected to target database: CDB1 (DBID=1234567890)

RMAN> BACKUP AS COMPRESSED BACKUPSET
      DATABASE
      PLUS ARCHIVELOG
      TAG DAILY_BACKUP_20251104;

Starting backup at 04-NOV-25
allocated channel: ORA_DISK_1
channel ORA_DISK_1: starting compressed full datafile backup set
[... progress ...]
Finished backup at 04-NOV-25

RMAN> BACKUP CURRENT CONTROLFILE;
RMAN> BACKUP SPFILE;
RMAN> DELETE NOPROMPT OBSOLETE;

✓ RMAN backup completed successfully

Transferring backups to standby...
rsync -avz /u02/backup/ oracle@ol8-21-dg2.localdomain:/u02/backup_from_primary/
[... rsync output ...]
✓ Backups transferred to standby

=== RMAN Backup Completed: 2025-11-04 15:42:15 ===
Duration: 7 minutes 15 seconds
```

**Ver log del último backup:**
```bash
vagrant ssh primary -c "ls -lt /home/oracle/logs/automation/rman_backup_*.log | head -1 | xargs cat"
```

---

#### delete_archives_primary.sh (Primary)

**Frecuencia:** Diario 2 AM (después de backup)
**Propósito:** Eliminar archives antiguos (>3 días)

**Ejecutar manualmente:**

```bash
vagrant ssh primary -c "/home/oracle/automation/delete_archives_primary.sh"
```

---

#### delete_archives_standby.sh (Standby)

**Frecuencia:** Diario 11 PM
**Propósito:** Eliminar archives antiguos aplicados

**Ejecutar manualmente:**

```bash
vagrant ssh standby -c "/home/oracle/automation/delete_archives_standby.sh"
```

---

### 🛠️ Scripts Manuales

#### verify_dataguard.sh

Ya cubierto en [Sección 5](#5-verificación-del-sistema).

---

#### manual_backup.sh

**Propósito:** Backup on-demand antes de mantenimiento

**Uso:**

```bash
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"
```

**Cuándo usar:**
- Antes de cambios mayores en el schema
- Antes de actualizaciones de Oracle
- Antes de pruebas destructivas

---

#### manual_sync.sh

**Propósito:** Forzar switch de log y sincronización inmediata

**Uso:**

```bash
vagrant ssh primary -c "/home/oracle/automation/manual_sync.sh"
```

**Salida:**
```
Forcing log switch on primary...
✓ Log switch complete
Waiting for standby to apply (max 30 seconds)...
✓ Standby synchronized
Archive gap: 0 sequences
```

**Cuándo usar:**
- Después de cambios importantes en primary
- Antes de verificar replicación
- Antes de switchover/failover

---

## 8. Monitoreo de Logs en Tiempo Real

### 📄 Logs de Despliegue (desde Windows)

#### Durante el despliegue (PowerShell en otra ventana)

```powershell
# Ver log de primary en tiempo real
Get-Content .\powershell\logs\deploy-TIMESTAMP\03-primary-vagrant.log -Wait

# Ver log de standby en tiempo real
Get-Content .\powershell\logs\deploy-TIMESTAMP\04-standby-vagrant.log -Wait
```

**Reemplaza `TIMESTAMP` con el timestamp de tu despliegue actual.**

---

### 📄 Logs de Oracle (desde dentro de VMs)

#### Alert Log (Primary)

```bash
vagrant ssh primary -c "tail -f /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log"
```

**Qué ver:**
- Log switches: `Thread 1 advanced to log sequence 145`
- Errores: `ORA-XXXXX`
- Data Guard messages: `LNS: Standby redo logfile selected...`

**Para salir:** Ctrl+C

---

#### Alert Log (Standby)

```bash
vagrant ssh standby -c "tail -f /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log"
```

**Qué ver:**
- Archive log apply: `Media Recovery Log /u01/oradata/cdb1/arch/1_145_...arc`
- MRP status: `MRP0: Media Recovery Waiting for T1.S145`

---

#### Listener Log

```bash
# Primary
vagrant ssh primary -c "tail -f /u01/app/oracle/diag/tnslsnr/ol8-21-dg1/listener/trace/listener.log"

# Standby
vagrant ssh standby -c "tail -f /u01/app/oracle/diag/tnslsnr/ol8-21-dg2/listener/trace/listener.log"
```

**Qué ver:**
- Conexiones: `CONNECT_DATA=(SERVICE_NAME=cdb1)...`
- Errors de conexión

---

#### Automation Logs

```bash
# Ver último log de check_log_transport
vagrant ssh primary -c "tail -20 /home/oracle/logs/automation/check_log_transport.log"

# Ver últimos backups
vagrant ssh primary -c "ls -lt /home/oracle/logs/automation/rman_backup_*.log | head -5"
```

---

### 📊 Queries de Monitoreo en Tiempo Real

#### Ver Sesiones Activas

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT sid, serial#, username, program, status, sql_id
FROM v\$session
WHERE username IS NOT NULL
ORDER BY logon_time DESC;
EOF
```

---

#### Ver Actividad de Redo Log

```bash
sqlplus / as sysdba <<EOF
SELECT sequence#, first_time, next_time,
       (blocks * block_size)/1024/1024 as size_mb
FROM v\$archived_log
WHERE first_time > SYSDATE - 1
ORDER BY first_time DESC
FETCH FIRST 10 ROWS ONLY;
EOF
```

---

#### Ver Apply Progress en Standby

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT process, status, thread#, sequence#,
       block#, blocks,
       TO_CHAR(timestamp, 'DD-MON-YY HH24:MI:SS') as timestamp
FROM v\$managed_standby
WHERE process LIKE 'MRP%' OR process LIKE 'RFS%';
EOF
```

---

## 9. Troubleshooting Rápido

### ⚠️ Problema: "No such file or directory: software/LINUX.X64_213000_db_home.zip"

**Causa:** Oracle software no descargado.

**Solución:**
1. Ve a [Oracle Database Downloads](https://www.oracle.com/database/technologies/oracle21c-linux-downloads.html)
2. Acepta términos de licencia
3. Descarga "LINUX.X64_213000_db_home.zip" (2.9 GB)
4. Mueve el archivo a `software/` en la raíz del proyecto
5. Re-ejecuta: `.\powershell\deploy.ps1`

---

### ⚠️ Problema: "VirtualBox service is not running"

**Causa:** Servicio de VirtualBox no está activo.

**Solución:**

```powershell
# Iniciar servicio
Start-Service -Name "VBoxSVC"

# Verificar
Get-Service -Name "VBoxSVC"
```

Si no funciona, reinicia VirtualBox desde el menú de Windows o reinicia tu PC.

---

### ⚠️ Problema: Deploy falla con "line 2: $'\r': command not found"

**Causa:** Scripts shell tienen line endings Windows (CRLF).

**Solución:**

```powershell
# Ejecutar fix line endings manualmente
.\powershell\fix-line-endings.ps1

# Luego re-ejecutar deploy
.\powershell\deploy.ps1
```

**Prevención:** No edites scripts `.sh` en Notepad. Usa VSCode, Notepad++, o vim.

---

### ⚠️ Problema: "ORA-12541: TNS:no listener"

**Causa:** Listener no está corriendo.

**Solución:**

```bash
vagrant ssh primary

sudo su - oracle
lsnrctl start

# Verificar
lsnrctl status
```

---

### ⚠️ Problema: "ORA-01034: ORACLE not available"

**Causa:** Database instance no está corriendo.

**Solución:**

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
STARTUP;
EXIT;
EOF
```

---

### ⚠️ Problema: Apply lag aumentando en standby

**Causa:** Standby no puede aplicar logs lo suficientemente rápido.

**Diagnóstico:**

```bash
vagrant ssh primary -c "/home/oracle/automation/check_log_transport.sh"
```

**Solución:**

1. **Si gap < 10 sequences:** Normal durante actividad alta. Espera.
2. **Si gap > 10 sequences:**
   ```bash
   vagrant ssh standby

   sudo su - oracle
   sqlplus / as sysdba <<EOF
   -- Verificar que MRP está corriendo
   SELECT process, status FROM v\$managed_standby WHERE process='MRP0';

   -- Si no está corriendo, iniciarlo
   ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
   EXIT;
   EOF
   ```

---

### ⚠️ Problema: "SSH connection refused" (primary → standby)

**Causa:** Claves SSH no configuradas correctamente.

**Solución:**

```bash
# Re-ejecutar setup de SSH en ambos nodos
vagrant provision primary --provision-with root_setup
vagrant provision standby --provision-with root_setup

# O manualmente
vagrant ssh primary
sudo su - oracle
/home/oracle/automation/setup_ssh_keys.sh
```

---

### ⚠️ Problema: VMs consumen mucha RAM

**Causa:** Cada VM usa 4GB RAM configurado en `vagrant.yml`.

**Solución temporal:**

```bash
# Apagar VMs cuando no las uses
vagrant halt
```

**Solución permanente (editar configuración):**

Editar `config/vagrant.yml`:

```yaml
node1:
  mem_size: 3072  # Reducir de 4096 a 3072 (3GB)

node2:
  mem_size: 3072
```

**Advertencia:** Oracle requiere mínimo 2GB. No bajes de 2048.

---

### ⚠️ Problema: Synced folders no montan ("mount: unknown filesystem type 'vboxsf'")

**Causa:** VirtualBox Guest Additions desactualizadas.

**Solución:**

```bash
# Instalar plugin vagrant-vbguest (una vez)
vagrant plugin install vagrant-vbguest

# Recargar VM (actualizará Guest Additions automáticamente)
vagrant reload primary
vagrant reload standby
```

---

### ⚠️ Problema: Oracle no inicia después de `vagrant reload`

**Causa:** Oracle no está configurado para auto-start.

**Solución:**

**Opción 1: Inicio manual**
```bash
vagrant ssh primary

sudo su - oracle
lsnrctl start
sqlplus / as sysdba <<EOF
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
EXIT;
EOF
```

**Opción 2: Configurar auto-start (permanente)**
```bash
vagrant provision primary --provision-with setup_oracle_autostart
vagrant reload primary
```

---

### ⚠️ Problema: Disk space full

**Diagnóstico:**

```bash
vagrant ssh primary -c "df -h"
```

**Si `/u01` está lleno:**

```bash
# Eliminar old archives (corre script de cleanup)
vagrant ssh primary -c "/home/oracle/automation/delete_archives_primary.sh"
```

**Si `/u02` está lleno (backups):**

```bash
vagrant ssh primary

sudo su - oracle
# Eliminar backups viejos manualmente
rman target / <<EOF
DELETE NOPROMPT OBSOLETE DEVICE TYPE DISK;
EXIT;
EOF
```

---

### 📞 Si Nada Funciona

1. **Revisa los logs detallados:**
   - `powershell/logs/deploy-TIMESTAMP/`
   - Alert logs dentro de VMs

2. **Destroy y re-deploy desde cero:**
   ```powershell
   .\powershell\destroy.ps1
   .\powershell\deploy.ps1
   ```

3. **Consulta la documentación avanzada:**
   - [94 - Troubleshooting Completo](operaciones/94-troubleshooting.md)
   - [Scripts de Ejecución](ejecucion/) para entender qué hace cada paso

4. **Verifica prerequisitos nuevamente:**
   - [03 - Prerequisitos](03-prerequisitos.md)

---

## 🎯 Resumen de Comandos Más Usados

### Despliegue y Destrucción

```powershell
# Despliegue completo automatizado
.\powershell\deploy.ps1

# Destrucción completa
.\powershell\destroy.ps1

# Despliegue individual
vagrant up primary
vagrant up standby

# Destrucción individual
vagrant destroy -f primary
vagrant destroy -f standby
```

---

### Gestión de VMs

```bash
# Ver estado
vagrant status

# Conectar por SSH
vagrant ssh primary
vagrant ssh standby

# Reiniciar
vagrant reload primary

# Apagar
vagrant halt primary

# Reanudar (si está apagada)
vagrant up primary
```

---

### Verificación

```bash
# Verificación completa Data Guard
vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"

# Verificar conectividad desde Windows
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

# Conectar al esquema de aplicación
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1
```

---

### Mantenimiento

```bash
# Backup manual
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"

# Forzar sincronización
vagrant ssh primary -c "/home/oracle/automation/manual_sync.sh"

# Ver logs de monitoreo
vagrant ssh primary -c "tail -20 /home/oracle/logs/automation/check_log_transport.log"
```

---

### Conexiones Rápidas

```bash
# Primary CDB
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

# Primary PDB
sqlplus sys/S1sPassword1!@localhost:1521/pdb1 as sysdba

# Esquema aplicación (primary)
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1

# Standby CDB
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba
```

---

## ⏭️ Siguientes Pasos

**Después de completar el despliegue:**

1. ✅ **Lee [05 - Arquitectura del Sistema](05-arquitectura-sistema.md)** para entender cómo funciona todo

2. ✅ **Explora el esquema healthcare:**
   ```sql
   sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1

   SELECT table_name FROM user_tables ORDER BY table_name;
   DESC HC_User;
   SELECT * FROM HC_HealthCenter;
   ```

3. ✅ **Prueba los procedimientos del sistema:**
   ```sql
   -- Generar escala del mes
   EXEC generate_month_scale('11', 2025, 1);

   -- Aprobar escala y marcar turnos como completos
   EXEC pkg_utilities.approve_month_scale(1);

   -- Generar planilla
   EXEC generate_payroll('11', 2025, 1);
   ```

4. ✅ **Familiarízate con Data Guard Broker:**
   ```bash
   vagrant ssh primary
   sudo su - oracle
   dgmgrl /

   DGMGRL> SHOW CONFIGURATION;
   DGMGRL> SHOW DATABASE cdb1;
   DGMGRL> SHOW DATABASE cdb1_stby;
   ```

5. ✅ **Lee sobre conceptos avanzados:**
   - [80 - Oracle CDB/PDB](conceptos-avanzados/80-oracle-cdb-pdb.md)
   - [81 - Data Guard Conceptos](conceptos-avanzados/81-data-guard-conceptos.md)
   - [82 - Modos de Protección](conceptos-avanzados/82-modos-proteccion.md)

6. ✅ **Aprende operaciones de mantenimiento:**
   - [90 - Monitoreo Diario](operaciones/90-monitoreo-diario.md)
   - [92 - Switchover](operaciones/92-switchover.md)
   - [93 - Failover](operaciones/93-failover.md)

---

## 📚 Referencias

- [00 - Tabla de Contenidos](00-tabla-contenidos.md) - Índice completo de la documentación
- [03 - Prerequisitos](03-prerequisitos.md) - Requisitos antes de empezar
- [Documentación Oracle Data Guard 21c](https://docs.oracle.com/en/database/oracle/oracle-database/21/sbydb/)
- [CLAUDE.md](../CLAUDE.md) - Guía rápida del proyecto
- [InstruccionesSBY.txt](../local_docs/InstruccionesSBY.txt) - Requisitos del entregable

---

**¡Felicidades!** Has completado la guía de uso del sistema Oracle Data Guard. El sistema ahora está desplegado y listo para usar.

Para entender en profundidad qué hace cada script y cómo funciona Data Guard internamente, continúa con los siguientes documentos en la [Tabla de Contenidos](00-tabla-contenidos.md).
