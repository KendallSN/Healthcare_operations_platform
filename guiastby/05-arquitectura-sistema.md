# 05 - Arquitectura del Sistema

## Arquitectura Completa del Sistema Oracle Data Guard Healthcare Management

Este documento explica la arquitectura completa del sistema: cómo están organizados los componentes, cómo se comunican, y cómo fluyen los datos.

---

## 📋 Tabla de Contenidos

1. [Visión General](#1-visión-general)
2. [Componentes del Sistema](#2-componentes-del-sistema)
3. [Arquitectura de Red](#3-arquitectura-de-red)
4. [Arquitectura de Almacenamiento](#4-arquitectura-de-almacenamiento)
5. [Flujo de Datos](#5-flujo-de-datos)
6. [Arquitectura del Schema Healthcare](#6-arquitectura-del-schema-healthcare)
7. [Estructura del Repositorio](#7-estructura-del-repositorio)
8. [Stack Tecnológico](#8-stack-tecnológico)

---

## 1. Visión General

### 🏗️ Arquitectura de 3 Capas

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPA DE PRESENTACIÓN                      │
│                                                              │
│  SQL*Plus │ SQL Developer │ DataGrip │ Scripts PL/SQL      │
│            (desde Windows Host)                             │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   │ TNS / SQL*Net
                   │
┌──────────────────▼───────────────────────────────────────────┐
│                  CAPA DE APLICACIÓN                          │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          Oracle Database 21c (Primary)              │   │
│  │                                                      │   │
│  │  CDB: cdb1                                          │   │
│  │  └─ PDB: pdb1                                       │   │
│  │     └─ HEALTHCENTER Schema                          │   │
│  │        ├─ Tables (HC_User, HC_Payroll, ...)        │   │
│  │        ├─ Sequences                                 │   │
│  │        ├─ Triggers                                  │   │
│  │        └─ Packages (PKG_UTILITIES, PKG_LOGBOOK)    │   │
│  │                                                      │   │
│  │  PL/SQL Procedures:                                │   │
│  │  • generate_month_scale()                          │   │
│  │  • approve_month_scale()                           │   │
│  │  • generate_payroll()                              │   │
│  │  • PCD_GeneratePayment()                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│         ║                                                    │
│         ║ Oracle Data Guard                                 │
│         ║ (MAXAVAILABILITY + FASTSYNC)                     │
│         ║                                                    │
│  ┌──────▼──────────────────────────────────────────────┐   │
│  │       Oracle Database 21c (Standby)                 │   │
│  │                                                      │   │
│  │  CDB: cdb1_stby                                     │   │
│  │  └─ PDB: pdb1 (replicated)                         │   │
│  │     └─ HEALTHCENTER Schema (replicated)            │   │
│  │                                                      │   │
│  │  Read-Only for queries                              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                   │
                   │
┌──────────────────▼───────────────────────────────────────────┐
│                    CAPA DE DATOS                             │
│                                                              │
│  /u01/oradata/      │ /u02/backup/     │ /u02/fast_recovery_area/ │
│  (Datafiles)        │ (RMAN backups)   │ (Flashback logs)  │
│                                                              │
│  Archive Logs → Transferred to standby every 5 minutes      │
│  Backups → rsync to standby daily at 1 AM                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Componentes del Sistema

### 2.1. Host Windows (Tu PC)

**Rol:** Ejecutar y gestionar las máquinas virtuales

**Software:**
- **VirtualBox 7.0+**: Motor de virtualización
- **Vagrant 2.4+**: Orquestación de VMs
- **PowerShell**: Scripts de despliegue

**Recursos asignados:**
- RAM: 12+ GB (8 GB para VMs + 4 GB para host)
- Disco: 250+ GB
- CPU: 4+ cores

---

### 2.2. Primary Virtual Machine

**Nombre:** `ol8_21_dg1_primary`
**Sistema Operativo:** Oracle Linux 8
**Hostname:** `ol8-21-dg1.localdomain`
**IP:** `192.168.56.101`

**Recursos:**
- RAM: 4 GB
- CPU: 2 cores
- Disco u01: 100 GB (Oracle software + databases)
- Disco u02: 100 GB (backups + FRA)

**Software instalado:**
- Oracle Database 21c Enterprise Edition
- Oracle Data Guard Broker
- RMAN (Recovery Manager)
- Cron jobs para automatización
- Scripts de monitoreo y backup

**Bases de datos:**
- **CDB:** cdb1
- **PDB:** pdb1
- **Schema:** HEALTHCENTER

**Servicios:**
- Listener en puerto 1521
- Enterprise Manager en puerto 5500 (opcional)

---

### 2.3. Standby Virtual Machine

**Nombre:** `ol8_21_dg2_standby`
**Sistema Operativo:** Oracle Linux 8
**Hostname:** `ol8-21-dg2.localdomain`
**IP:** `192.168.56.102`

**Recursos:**
- RAM: 4 GB
- CPU: 2 cores
- Disco u01: 100 GB (Oracle software + databases)
- Disco u02: 100 GB (backups recibidos + FRA)

**Software instalado:**
- Oracle Database 21c Enterprise Edition (idéntico al primary)
- Oracle Data Guard Broker
- Scripts de aplicación de logs
- Cron jobs para limpieza

**Bases de datos:**
- **CDB:** cdb1_stby
- **PDB:** pdb1 (réplica)
- **Schema:** HEALTHCENTER (replicado)

**Modo:** Physical Standby (Read-Only)

---

### 2.4. Oracle Data Guard Configuration

**Nombre de Configuración:** `dg_config`

**Primary Database:**
- DB_NAME: cdb1
- DB_UNIQUE_NAME: cdb1
- Rol: PRIMARY
- Open Mode: READ WRITE

**Standby Database:**
- DB_NAME: cdb1 (mismo que primary)
- DB_UNIQUE_NAME: cdb1_stby (diferente para identificación)
- Rol: PHYSICAL STANDBY
- Open Mode: READ ONLY WITH APPLY (o MOUNTED)

**Configuración:**
- Protection Mode: **MAXAVAILABILITY**
- Transport Mode: **FASTSYNC**
- Archive Lag Target: **300 segundos** (5 minutos)
- Flashback: **Habilitado** en ambos

---

## 3. Arquitectura de Red

### 3.1. Topología de Red

```
┌──────────────────────────────────────────────────────────────┐
│                      Windows Host                             │
│                    10.0.2.15 (NAT)                           │
│                                                              │
│  ┌────────────────────┐         ┌────────────────────┐      │
│  │   Primary VM       │         │   Standby VM       │      │
│  │                    │         │                    │      │
│  │  NAT: 10.0.2.15   │         │  NAT: 10.0.2.15   │      │
│  │  Host-Only:        │         │  Host-Only:        │      │
│  │  192.168.56.101    │◄────────┤  192.168.56.102    │      │
│  │                    │         │                    │      │
│  │  Ports forwarded:  │         │  Ports forwarded:  │      │
│  │  1521 → 1521      │         │  1521 → 1522      │      │
│  │  5500 → 5500      │         │  5500 → 5501      │      │
│  └────────────────────┘         └────────────────────┘      │
│           │                              │                   │
│           └──────────┬───────────────────┘                   │
│                      │                                       │
│              VirtualBox NAT Network                          │
│              VirtualBox Host-Only Network                    │
└──────────────────────────────────────────────────────────────┘
                       │
                       │ Internet
                       ▼
```

---

### 3.2. Interfaces de Red

Cada VM tiene **2 interfaces de red**:

#### Interface 1: NAT (Network Address Translation)

**Propósito:** Acceso a Internet desde las VMs

**Configuración:**
- IP: 10.0.2.15 (asignada automáticamente por VirtualBox)
- Gateway: 10.0.2.2
- DNS: 10.0.2.3

**Uso:**
- Descargar paquetes con `yum`
- Actualizaciones del sistema
- NTP (time synchronization)

---

#### Interface 2: Host-Only Network

**Propósito:** Comunicación entre VMs y con el host

**Configuración Primary:**
- IP: 192.168.56.101
- Netmask: 255.255.255.0
- Network: 192.168.56.0/24

**Configuración Standby:**
- IP: 192.168.56.102
- Netmask: 255.255.255.0
- Network: 192.168.56.0/24

**Uso:**
- Data Guard log transport (primary → standby)
- SSH entre VMs (para backups)
- Conexiones desde host Windows (SQL*Plus, etc.)

---

### 3.3. Port Forwarding

Para acceder a las VMs desde Windows:

**Primary:**
| Service | VM Port | Host Port |
|---------|---------|-----------|
| Oracle Listener | 1521 | 1521 |
| Enterprise Manager | 5500 | 5500 |
| SSH | 22 | 2201 |

**Conexión desde Windows:**
```bash
sqlplus sys/password@localhost:1521/cdb1 as sysdba
```

---

**Standby:**
| Service | VM Port | Host Port |
|---------|---------|-----------|
| Oracle Listener | 1521 | **1522** |
| Enterprise Manager | 5500 | **5501** |
| SSH | 22 | 2202 |

**Conexión desde Windows:**
```bash
sqlplus sys/password@localhost:1522/cdb1_stby as sysdba
```

**Nota:** Los puertos del host son diferentes para evitar conflictos.

---

### 3.4. Configuración de Hostnames

**Archivo `/etc/hosts` en ambas VMs:**

```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
192.168.56.102  ol8-21-dg2.localdomain ol8-21-dg2
```

**Por qué es importante:**
- Oracle usa hostnames para identificar servidores
- Data Guard requiere resolución de nombres
- TNS (Transparent Network Substrate) usa hostnames en tnsnames.ora

---

## 4. Arquitectura de Almacenamiento

### 4.1. Discos de las VMs

Cada VM tiene **3 discos virtuales**:

```
┌────────────────────────────────────────────────────────────┐
│                     Primary VM                              │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  /dev/sda (20 GB)  - Sistema operativo Oracle Linux 8     │
│  ├─ /boot                                                  │
│  ├─ /                                                      │
│  └─ swap                                                   │
│                                                            │
│  /dev/sdb (100 GB) - Montado en /u01                      │
│  └─ /u01                                                   │
│     ├─ /u01/app/oracle/                                   │
│     │  ├─ product/21.0.0/dbhome_1/  (Oracle software)     │
│     │  └─ admin/                     (Admin files)        │
│     ├─ /u01/app/oraInventory/        (Inventory)          │
│     ├─ /u01/oradata/                 (Database files)     │
│     │  └─ cdb1/                                           │
│     │     ├─ system01.dbf                                 │
│     │     ├─ sysaux01.dbf                                 │
│     │     ├─ undotbs01.dbf                                │
│     │     ├─ users01.dbf                                  │
│     │     ├─ temp01.dbf                                   │
│     │     ├─ redo01.log, redo02.log, redo03.log          │
│     │     ├─ arch/  (Archive logs)                        │
│     │     └─ pdbseed/, pdb1/  (PDBs)                      │
│     └─ /u01/software/                (Installation files) │
│                                                            │
│  /dev/sdc (100 GB) - Montado en /u02                      │
│  └─ /u02                                                   │
│     ├─ /u02/backup/                  (RMAN backups)       │
│     │  ├─ autobackup_c-...ctl                             │
│     │  ├─ backup_CDB1_...bkp                              │
│     │  └─ archive_CDB1_...arc                             │
│     └─ /u02/fast_recovery_area/      (FRA)                │
│        └─ cdb1/                                           │
│           ├─ archivelog/                                  │
│           ├─ backupset/                                   │
│           ├─ flashback/          (Flashback logs)         │
│           └─ onlinelog/          (Standby redo logs)      │
│                                                            │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                     Standby VM                              │
├────────────────────────────────────────────────────────────┤
│  /dev/sda (20 GB)  - Sistema operativo                    │
│  /dev/sdb (100 GB) - /u01 (idéntico a primary)            │
│  /dev/sdc (100 GB) - /u02                                  │
│     ├─ /u02/backup_from_primary/  (Backups rsync)         │
│     └─ /u02/fast_recovery_area/   (FRA)                   │
└────────────────────────────────────────────────────────────┘
```

---

### 4.2. Sistema de Archivos

**Formato:** XFS (recomendado por Oracle para Linux)

**Puntos de montaje en `/etc/fstab`:**

```bash
/dev/sdb1  /u01  xfs  defaults  0 0
/dev/sdc1  /u02  xfs  defaults  0 0
```

**Por qué XFS:**
- Alto rendimiento con archivos grandes (datafiles de GB)
- Excelente para I/O secuencial (archive logs)
- Soporte nativo de Oracle
- Journaling para recuperación ante crashes

---

### 4.3. Organización de Datafiles

**CDB (Container Database):**
- `/u01/oradata/cdb1/system01.dbf` - 800 MB (system tablespace)
- `/u01/oradata/cdb1/sysaux01.dbf` - 600 MB (system auxiliary)
- `/u01/oradata/cdb1/undotbs01.dbf` - 200 MB (undo tablespace)
- `/u01/oradata/cdb1/users01.dbf` - 5 MB (default user tablespace)
- `/u01/oradata/cdb1/temp01.dbf` - 100 MB (temporary)

**PDB (Pluggable Database):**
- `/u01/oradata/cdb1/pdb1/system01.dbf` - 300 MB
- `/u01/oradata/cdb1/pdb1/sysaux01.dbf` - 400 MB
- `/u01/oradata/cdb1/pdb1/undotbs01.dbf` - 100 MB
- `/u01/oradata/cdb1/pdb1/users01.dbf` - 5 MB (healthcare schema aquí)

**Control Files (3 copias para redundancia):**
- `/u01/oradata/cdb1/control01.ctl`
- `/u01/app/oracle/fast_recovery_area/cdb1/control02.ctl`
- `/u02/fast_recovery_area/cdb1/control03.ctl`

---

### 4.4. Archive Logs

**Ubicación:** `/u01/oradata/cdb1/arch/`

**Formato:** `1_<sequence>_<resetlogs_id>.arc`

**Ejemplo:**
```
1_145_1234567890.arc
1_146_1234567890.arc
1_147_1234567890.arc
```

**Tamaño típico:** 50-200 MB cada uno (depende de actividad)

**Ciclo de vida:**
1. Generado en primary cada 5 minutos (archive_lag_target)
2. Enviado a standby vía network (LNS process)
3. Recibido en standby (RFS process)
4. Aplicado a standby database (MRP process)
5. Mantenido 3 días
6. Eliminado por script de cleanup

---

### 4.5. Fast Recovery Area (FRA)

**Ubicación:** `/u02/fast_recovery_area/`
**Tamaño configurado:** 100 GB

**Contenido:**
```
/u02/fast_recovery_area/cdb1/
├── archivelog/         # Copias de archive logs
├── backupset/          # Backups RMAN
├── flashback/          # Flashback Database logs
├── onlinelog/          # Standby redo logs
└── controlfile/        # Control file autobackups
```

**Gestión:** Oracle automáticamente elimina archivos antiguos cuando se llena.

---

## 5. Flujo de Datos

### 5.1. Flujo Normal de Transacción (sin Data Guard)

```
1. Usuario ejecuta INSERT/UPDATE/DELETE
       ↓
2. Oracle escribe cambio en:
   - Redo Log Buffer (memoria)
   - Database Buffer Cache (memoria)
       ↓
3. Commit
       ↓
4. LGWR (Log Writer) escribe a Online Redo Log (disco)
       ↓
5. DBWn (Database Writer) eventualmente escribe a Datafiles
```

---

### 5.2. Flujo con Oracle Data Guard

```
PRIMARY                              STANDBY

1. Transacción
   INSERT INTO HC_User ...
   COMMIT;
       ↓
2. Redo Log Buffer
       ↓
3. LGWR escribe a Online Redo Log
       ↓
4. Log Switch (cuando se llena)
       ↓
5. ARCn (Archiver) crea Archive Log
   /u01/oradata/cdb1/arch/1_145.arc
       ║
       ║ (Network - FASTSYNC)
       ║
       ╠═══════════════════════════════►  6. RFS (Remote File Server)
       ║                                      recibe archive log
       ║                                          ↓
       ║                                   7. Escribe en standby:
       ║                                      /u01/oradata/cdb1/arch/1_145.arc
       ║                                          ↓
       ║                                   8. MRP (Managed Recovery Process)
       ║                                      lee archive log
       ║                                          ↓
       ║                                   9. Aplica cambios a datafiles
       ║                                      standby
       ║                                          ↓
       ║                                   10. Standby ahora tiene:
       ║                                       INSERT INTO HC_User ... ✓
       ║
       ▼
11. Primary confirma commit al usuario
    (espera confirmación de standby con FASTSYNC)
```

---

### 5.3. Flujo Detallado de Archive Log Transport

```
PRIMARY NODE                           STANDBY NODE

Online Redo Log lleno
       ↓
┌──────────────────┐
│  Log Switch      │
│  ALTER SYSTEM    │
│  SWITCH LOGFILE; │
└─────────┬────────┘
          │
          ▼
┌───────────────────────┐
│  ARCn Process         │
│  Copia redo → archive │
└─────────┬─────────────┘
          │
          ▼
┌────────────────────────┐
│  Archive Log           │
│  1_145_1234567890.arc  │
│  /u01/oradata/cdb1/arch│
└─────────┬──────────────┘
          │
          ├──> (Local copy)
          │
          ╚═══════════════════════════════════════════════╗
                                                          ║
            Network Transport (FASTSYNC)                  ║
            Protocol: TCP/IP                              ║
            Port: 1521                                    ║
            Encryption: AES256                            ║
                                                          ║
                                                          ▼
                                              ┌───────────────────┐
                                              │  RFS Process      │
                                              │  (Remote File Srv)│
                                              └─────────┬─────────┘
                                                        │
                                                        ▼
                                              ┌────────────────────┐
                                              │  Write to disk     │
                                              │  1_145_...arc      │
                                              │  /u01/.../arch/    │
                                              └─────────┬──────────┘
                                                        │
                                                        ▼
                                              ┌────────────────────┐
                                              │  MRP0 Process      │
                                              │  (Media Recovery)  │
                                              └─────────┬──────────┘
                                                        │
                                                        ▼
                                              ┌────────────────────┐
                                              │  Apply to Datafiles│
                                              │  (redo changes)    │
                                              └─────────┬──────────┘
                                                        │
                                                        ▼
                                              ┌────────────────────┐
                                              │  Standby Database  │
                                              │  now synchronized  │
                                              └────────────────────┘
```

---

### 5.4. Flujo de Backup

```
PRIMARY                                    STANDBY

Daily 1 AM Cron Job
      ↓
┌─────────────────┐
│  RMAN Backup    │
│  Started        │
└────────┬────────┘
         │
         ▼
┌──────────────────────────┐
│  RMAN Commands:          │
│  BACKUP DATABASE         │
│  PLUS ARCHIVELOG         │
│  AS COMPRESSED BACKUPSET │
└────────┬─────────────────┘
         │
         ▼
┌────────────────────────┐
│  Backup Files Created  │
│  /u02/backup/          │
│  - backup_*.bkp        │
│  - archive_*.arc       │
│  - controlfile_*.ctl   │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────┐
│  rsync Transfer        │
│  over SSH              │
└────────╥───────────────┘
         ║
         ║ Network (192.168.56.101 → 192.168.56.102)
         ║
         ╚══════════════════════════════════════════════╗
                                                        ║
                                                        ▼
                                            ┌───────────────────┐
                                            │  Receive Backups  │
                                            │  /u02/backup_from_│
                                            │  primary/         │
                                            └───────────────────┘

                                            Now standby has:
                                            - Database backups from primary
                                            - Can restore independently
                                            - Offsite protection
```

---

## 6. Arquitectura del Schema Healthcare

### 6.1. Modelo de Datos Simplificado

```
┌──────────────────┐
│  HC_HealthCenter │  (Centros de salud)
└─────────┬────────┘
          │
          │ 1:N
          ▼
┌──────────────────┐       ┌──────────────────┐
│  HC_Position     │       │  HC_MonthScale   │  (Escalas mensuales)
│  (Posiciones)    │       │                  │
└─────────┬────────┘       └─────────┬────────┘
          │                          │
          │ N:1                      │ 1:N
          ▼                          ▼
┌──────────────────┐       ┌──────────────────┐
│  HC_User         │◄──────┤ HC_TurnXMonthSc  │  (Turnos individuales)
│  (Usuarios)      │  N:N  │                  │
└─────────┬────────┘       └──────────────────┘
          │
          │ 1:N
          ▼
┌──────────────────┐       ┌──────────────────┐
│  HC_Procedure    │       │  HC_Payroll      │  (Planillas)
│  (Procedimientos)│       │                  │
└──────────────────┘       └─────────┬────────┘
                                     │
                                     │ 1:N
                                     ▼
                           ┌──────────────────┐
                           │ HC_PayrollXUser  │  (Planilla por usuario)
                           │                  │
                           └─────────┬────────┘
                                     │
                                     │ 1:N
                                     ▼
                           ┌──────────────────┐
                           │ HC_PayrollMovmt  │  (Movimientos: ingresos/deducciones)
                           │                  │
                           └──────────────────┘
```

---

### 6.2. Flujo de Negocio

```
1. SETUP: Crear Centros de Salud y Usuarios
   ↓
2. MONTH SCALE: Generar escala mensual de turnos
   EXEC generate_month_scale('11', 2025, 1);
   ↓
   Sistema asigna turnos automáticamente a médicos/administrativos
   ↓
3. WORK: Usuarios trabajan sus turnos asignados
   ↓
4. PROCEDURES: Médicos registran procedimientos realizados
   INSERT INTO HC_Procedure ...
   ↓
5. APPROVAL: Aprobar escala completada
   EXEC pkg_utilities.approve_month_scale(1);
   ↓
   Marca todos los turnos del mes como 'F' (Finished)
   Cambia estado del month scale a 'P' (Payment pending)
   ↓
6. PAYROLL: Generar planilla de pago
   EXEC generate_payroll('11', 2025, 1);
   ↓
   Calcula salarios base por posición
   Agrega ingresos por procedimientos
   Aplica deducciones
   ↓
7. PAYMENT: Generar cálculo de pagos
   EXEC PCD_GeneratePayment(1);
   ↓
   Crea movimientos de planilla
   Genera totales por usuario
   ↓
8. RESULT: Planilla lista para procesar pagos
```

---

### 6.3. Packages Principales

**PKG_UTILITIES:**
- `approve_month_scale(p_msc_id)` - Aprobar escala mensual
- Utilidades generales del sistema

**PKG_LOGBOOK:**
- Registro de auditoría de todas las acciones
- Tracking de cambios en tablas críticas

**PKG_EMAILS:**
- Envío de notificaciones automáticas
- Alertas de eventos importantes

**PKG_FUNCTIONS_JOBS:**
- Funciones para jobs programados
- Tareas recurrentes

---

## 7. Estructura del Repositorio

```
AdminBDProyecto/
│
├── 1-BD/                              # Database Schema (gestionado por otro equipo)
│   ├── ScriptProyectoBD.SQL          # ⭐ Script principal del schema
│   ├── Script_SchemeTableSpace.sql   # Creación de tablespace
│   ├── data.sql                      # Datos de prueba
│   ├── ExecutionScript.sql           # Ejemplos de uso
│   │
│   ├── PKG_UTILITIES.PKG             # Package principal
│   ├── Payrolls/                     # Lógica de planillas
│   ├── MonthScales/                  # Lógica de escalas
│   ├── Emails/                       # Sistema de emails
│   ├── LogBooks/                     # Auditoría
│   ├── NationalRegister/             # Verificación de cédulas
│   └── Tests/                        # Tests del schema
│
├── 2-Standby/                         # Infrastructure (Data Guard)
│   ├── scripts/
│   │   ├── primary/                  # Scripts de despliegue primary
│   │   │   ├── setup.sh             # Entry point
│   │   │   ├── root_setup.sh        # Orquestador principal
│   │   │   ├── oracle_user_environment_setup.sh
│   │   │   ├── oracle_create_database.sh
│   │   │   ├── deploy_custom_schema.sh
│   │   │   ├── setup_automation.sh
│   │   │   └── setup_ssh_keys_auto.sh
│   │   │
│   │   └── standby/                  # Scripts de despliegue standby
│   │       ├── setup.sh
│   │       ├── root_setup.sh
│   │       ├── oracle_user_environment_setup.sh
│   │       ├── oracle_create_database.sh  # ⭐ RMAN DUPLICATE aquí
│   │       ├── setup_automation.sh
│   │       └── setup_ssh_keys_auto.sh
│   │
│   ├── automation/                    # Scripts de automatización
│   │   ├── check_log_transport.sh    # Monitoreo (cada 10 min)
│   │   ├── rman_daily_backup.sh      # Backup diario (1 AM)
│   │   ├── delete_archives_primary.sh
│   │   ├── delete_archives_standby.sh
│   │   ├── verify_dataguard.sh       # Verificación completa
│   │   ├── install_cron_jobs.sh
│   │   └── manual_*.sh               # Scripts on-demand
│   │
│   └── infrastructure/                # Scripts compartidos
│       ├── prepare_u01_u02_disks.sh
│       ├── install_os_packages.sh
│       ├── configure_hosts_base.sh
│       ├── configure_hostname.sh
│       ├── configure_chrony.sh
│       ├── oracle_db_software_installation.sh
│       └── setup_oracle_autostart.sh
│
├── config/                            # Configuración
│   ├── vagrant.yml                   # Specs de VMs (RAM, CPU, discos)
│   └── install.env                   # Variables de entorno (passwords, IPs)
│
├── powershell/                        # Orchestration scripts
│   ├── deploy.ps1                    # ⭐ SCRIPT PRINCIPAL DESPLIEGUE
│   ├── destroy.ps1                   # Limpieza completa
│   └── fix-line-endings.ps1          # Conversión CRLF→LF
│
├── software/                          # Oracle installation files
│   └── LINUX.X64_213000_db_home.zip  # (Usuario debe descargar)
│
├── guiastby/                          # ⭐ ESTA DOCUMENTACIÓN
│   ├── PROGRESS.md                   # Control de progreso
│   ├── 00-tabla-contenidos.md
│   ├── 01-introduccion.md
│   ├── 02-conceptos-fundamentales.md
│   ├── 03-prerequisitos.md
│   ├── 04-como-usar.md
│   ├── 05-arquitectura-sistema.md    # Este documento
│   ├── ejecucion/                    # Scripts explicados (10-60)
│   ├── scripts-automatizacion/       # Automatización (70-75)
│   ├── conceptos-avanzados/          # Teoría (80-87)
│   ├── operaciones/                  # Ops (90-94)
│   └── 99-conclusiones-recomendaciones.md
│
├── Vagrantfile                        # ⭐ Orquestación de VMs
├── .gitignore
├── CLAUDE.md                          # Project guidance
└── README.md                          # (si existe)
```

---

## 8. Stack Tecnológico

### 8.1. Capa de Sistema Operativo

| Componente | Versión | Propósito |
|------------|---------|-----------|
| **Oracle Linux** | 8.x | SO de las VMs (optimizado para Oracle DB) |
| **Kernel** | 4.18+ | Linux kernel con soporte Oracle |
| **XFS** | - | Sistema de archivos para /u01 y /u02 |
| **systemd** | - | Gestión de servicios |
| **chronyd** | - | Sincronización de tiempo (NTP) |
| **firewalld** | - | Firewall (deshabilitado en dev) |
| **SELinux** | - | Security (deshabilitado en dev) |

---

### 8.2. Capa de Virtualización

| Componente | Versión | Propósito |
|------------|---------|-----------|
| **VirtualBox** | 7.0+ | Hypervisor tipo 2 |
| **Vagrant** | 2.4+ | Orquestación de VMs |
| **vagrant-vbguest** | 0.31+ | Plugin para Guest Additions |
| **vboxsf** | - | Synced folders driver |

---

### 8.3. Capa de Base de Datos

| Componente | Versión | Propósito |
|------------|---------|-----------|
| **Oracle Database** | 21c (21.3.0.0.0) | RDBMS |
| **Oracle Data Guard** | 21c | High availability |
| **Oracle Data Guard Broker** | 21c | DG management |
| **RMAN** | 21c | Backup & Recovery |
| **SQL*Plus** | 21c | Command-line interface |
| **Oracle Listener** | 21c | Network listener |
| **TNS** | 21c | Network naming |

---

### 8.4. Capa de Automatización

| Componente | Propósito |
|------------|-----------|
| **PowerShell** | Windows host orchestration |
| **Bash** | Linux shell scripts |
| **Cron** | Scheduled jobs |
| **rsync** | Backup file transfer |
| **SSH** | Secure shell for automation |

---

### 8.5. Lenguajes y Scripts

| Lenguaje | Uso |
|----------|-----|
| **PL/SQL** | Stored procedures, packages, triggers del schema healthcare |
| **SQL** | Database queries, DDL, DML |
| **Bash** | Shell scripts para Linux (provisioning, automation) |
| **PowerShell** | Orchestration scripts para Windows |

---

## 📊 Métricas del Sistema

### Uso de Recursos (Típico)

**Primary VM:**
- RAM: 3-3.5 GB usado de 4 GB
- CPU: 10-30% en idle, 80-100% durante despliegue
- Disco /u01: 15-25 GB usado de 100 GB
- Disco /u02: 5-10 GB usado de 100 GB

**Standby VM:**
- RAM: 2.5-3 GB usado de 4 GB
- CPU: 5-20% en idle (aplicando logs)
- Disco /u01: 15-25 GB usado (similar a primary)
- Disco /u02: 10-20 GB usado (backups recibidos)

---

### Tiempos de Operación

| Operación | Tiempo |
|-----------|--------|
| Despliegue completo (deploy.ps1) | 60-70 min |
| Despliegue primary only | 35-45 min |
| Despliegue standby only | 20-30 min |
| RMAN duplicate | 10-20 min |
| Backup diario RMAN | 5-15 min |
| Log switch + apply | <30 segundos |
| Switchover | 2-5 min |
| Failover | 1-3 min |
| Reinstatement (con Flashback) | 5-10 min |

---

### Volumen de Datos

**Archive Logs:**
- Generación: 1 cada 5 minutos (archive_lag_target)
- Tamaño promedio: 50-200 MB
- Por día: ~288 logs (si hay actividad)
- Retención: 3 días = ~864 logs

**Backups:**
- Frecuencia: Diario
- Tamaño comprimido: 5-15 GB (depende de datos)
- Retención: 7 días
- Total storage: ~70-105 GB

---

## 🔗 Interconexión de Componentes

### Diagrama de Dependencias

```
Windows Host
    │
    ├─> VirtualBox (hypervisor)
    │       │
    │       ├─> Primary VM
    │       │      │
    │       │      ├─> Oracle Linux 8
    │       │      ├─> Oracle Database 21c
    │       │      │      │
    │       │      │      ├─> CDB cdb1
    │       │      │      │    └─> PDB pdb1
    │       │      │      │         └─> HEALTHCENTER schema
    │       │      │      │
    │       │      │      └─> Data Guard (transport logs)
    │       │      │                    ║
    │       │      └─> Cron Jobs        ║
    │       │           ├─> check_log_transport  ║
    │       │           ├─> rman_daily_backup    ║
    │       │           └─> delete_archives      ║
    │       │                                     ║
    │       └─> Standby VM                       ║
    │              │                              ║
    │              ├─> Oracle Linux 8 ◄══════════╝
    │              ├─> Oracle Database 21c
    │              │      │
    │              │      ├─> CDB cdb1_stby
    │              │      │    └─> PDB pdb1 (replica)
    │              │      │         └─> HEALTHCENTER (replica)
    │              │      │
    │              │      └─> Data Guard (receive & apply)
    │              │
    │              └─> Cron Jobs
    │                   └─> delete_archives
    │
    └─> Vagrant (orchestrator)
            │
            ├─> Reads: Vagrantfile
            ├─> Reads: config/vagrant.yml
            ├─> Triggers: 2-Standby/scripts/
            └─> Mounts: Synced folders
```

---

## 🎯 Resumen

Esta arquitectura implementa:

✅ **Alta Disponibilidad:** Dos servidores con Data Guard en MAXAVAILABILITY

✅ **Cero Pérdida de Datos:** FASTSYNC transport mode sincrónico

✅ **Recuperación Rápida:** Flashback Database para reinstatement en minutos

✅ **Automatización Completa:** Despliegue con un solo comando PowerShell

✅ **Backups Redundantes:** RMAN diario + transferencia a standby

✅ **Monitoreo Continuo:** Cron jobs cada 10 minutos

✅ **Schema Completo:** Sistema healthcare con 15+ tablas, procedures, packages

✅ **Documentación Exhaustiva:** 50+ archivos markdown (esta guía)

---

## ⏭️ Siguientes Pasos

**Después de entender la arquitectura:**

1. ✅ Si aún no desplegaste el sistema: [04 - Cómo Usar](04-como-usar.md)

2. ✅ Para entender los scripts en detalle: [Ejecución](ejecucion/) (archivos 10-60)

3. ✅ Para entender conceptos profundos: [Conceptos Avanzados](conceptos-avanzados/) (archivos 80-87)

4. ✅ Para operaciones diarias: [Operaciones](operaciones/) (archivos 90-94)

5. ✅ Para ver la tabla de contenidos completa: [00 - Tabla de Contenidos](00-tabla-contenidos.md)

---

**Has completado la visión general de la arquitectura del sistema!** 🎉

Ahora entiendes cómo están organizados todos los componentes y cómo fluyen los datos entre ellos.
