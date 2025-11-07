# 81 - Oracle Data Guard - Conceptos Profundos

## Arquitectura Completa de Oracle Data Guard

Oracle Data Guard es la solución empresarial de Oracle para alta disponibilidad, recuperación ante desastres y protección de datos. Este documento explora en profundidad la arquitectura interna de Data Guard, sus procesos, tipos de standby, mecanismos de replicación y cómo todo funciona bajo el capó.

Data Guard no es simplemente una herramienta de backup o replicación; es un framework completo que mantiene una o más copias exactas (standby databases) de tu base de datos de producción (primary database), sincronizadas en tiempo real. A diferencia de soluciones de replicación a nivel de aplicación o lógica, Data Guard trabaja a nivel de bloques físicos de datos, garantizando una réplica idéntica byte por byte.

En este proyecto, implementamos un Data Guard configuración con un primary database (cdb1) y un physical standby (cdb1_stby) usando el modo de protección MAXAVAILABILITY con transporte FASTSYNC, proporcionando cero pérdida de datos (RPO=0) con un tiempo de recuperación mínimo (RTO de 1-3 minutos). La replicación ocurre cada 5 minutos máximo gracias al parámetro archive_lag_target=300 segundos.

Este documento es fundamental para entender cómo Oracle garantiza que tus datos críticos nunca se pierdan, incluso ante fallos catastróficos de hardware, corrupción de datos, o desastres naturales. Exploraremos cada proceso background, cada tipo de standby, y cada modo de operación en detalle.

---

## 📋 Tabla de Contenidos

1. [¿Qué es Oracle Data Guard?](#1-qué-es-oracle-data-guard)
2. [Historia y Evolución](#2-historia-y-evolución)
3. [Arquitectura General](#3-arquitectura-general)
4. [Procesos de Data Guard](#4-procesos-de-data-guard)
5. [Physical Standby vs Logical Standby](#5-physical-standby-vs-logical-standby)
6. [Snapshot Standby](#6-snapshot-standby)
7. [Active Data Guard](#7-active-data-guard)
8. [Transporte de Redo (Redo Transport)](#8-transporte-de-redo-redo-transport)
9. [Aplicación de Redo (Redo Apply)](#9-aplicación-de-redo-redo-apply)
10. [System Change Number (SCN)](#10-system-change-number-scn)
11. [Recovery Window y Lag](#11-recovery-window-y-lag)
12. [Switchover vs Failover](#12-switchover-vs-failover)
13. [Fast-Start Failover (FSFO)](#13-fast-start-failover-fsfo)
14. [Data Guard en Este Proyecto](#14-data-guard-en-este-proyecto)
15. [Configuración y Queries](#15-configuración-y-queries)
16. [Monitoreo de Data Guard](#16-monitoreo-de-data-guard)
17. [Troubleshooting Común](#17-troubleshooting-común)

---

## 1. ¿Qué es Oracle Data Guard?

### Definición Completa

**Oracle Data Guard** es una solución integrada de Oracle Database que mantiene una o más copias sincronizadas (standby databases) de una base de datos de producción (primary database), proporcionando:

1. **Alta Disponibilidad (High Availability):**
   - Minimiza downtime planificado y no planificado
   - Switchover para mantenimiento sin pérdida de datos
   - Failover automático ante fallos

2. **Protección de Datos (Data Protection):**
   - Cero pérdida de datos (RPO=0) con configuración adecuada
   - Protección contra corrupción física y lógica
   - Múltiples copias en diferentes ubicaciones geográficas

3. **Recuperación ante Desastres (Disaster Recovery):**
   - Standby en otra ciudad/región
   - Recuperación en minutos (no horas/días)
   - Validación continua de integridad

4. **Offloading de Carga:**
   - Queries de reporting en standby (Active Data Guard)
   - Backups desde standby (no impacta producción)
   - Testing en snapshot standby

---

### Componentes Principales

```
┌────────────────────────────────────────────────────────────────────┐
│                     ORACLE DATA GUARD                               │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────┐         ┌──────────────────────────┐ │
│  │   PRIMARY DATABASE       │         │   STANDBY DATABASE       │ │
│  │                          │         │                          │ │
│  │  CDB: cdb1              │═══════→│  CDB: cdb1_stby         │ │
│  │  Mode: READ WRITE        │         │  Mode: READ ONLY/MOUNT   │ │
│  │                          │         │                          │ │
│  │  Processes:              │         │  Processes:              │ │
│  │  • ARCn (Archiver)       │         │  • RFS (Recv File Srv)   │ │
│  │  • LNS (Log Net Srv)     │────────→│  • MRP (Media Recovery)  │ │
│  │  • LGWR (Log Writer)     │         │  • ARCn (Archiver)       │ │
│  │                          │         │                          │ │
│  │  Archive Logs Generated  │         │  Archive Logs Applied    │ │
│  │  Every 5 min (lag=300)   │         │  Continuously            │ │
│  └──────────────────────────┘         └──────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐│
│  │              DATA GUARD BROKER (Management Layer)              ││
│  │                                                                 ││
│  │  • Centralized configuration                                   ││
│  │  • Automated switchover/failover                               ││
│  │  • Monitoring and alerting                                     ││
│  │  • Fast-Start Failover (optional)                              ││
│  └────────────────────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────────┘
```

---

### Por Qué Usar Data Guard

**Escenario sin Data Guard:**
```
Primary DB falla (hardware failure, corrupción, desastre)
    ↓
Detectar problema (10 min)
    ↓
Encontrar último backup válido (30 min)
    ↓
Restaurar backup (4 horas)
    ↓
Aplicar archive logs hasta el punto de fallo (2 horas)
    ↓
Validar integridad (1 hora)
    ↓
Reconfigurar aplicaciones (30 min)
    ↓
TOTAL: 8 horas downtime
Pérdida de datos: Desde último backup (potencialmente horas)
```

**Escenario con Data Guard:**
```
Primary DB falla
    ↓
Data Guard detecta (30 segundos)
    ↓
Failover automático al standby (1-2 min)
    ↓
Reconfigurar aplicaciones (1 min) o automático
    ↓
TOTAL: 2-3 minutos downtime
Pérdida de datos: CERO (con MAXAVAILABILITY)
```

---

## 2. Historia y Evolución

### Oracle Data Guard Timeline

**Oracle 7.3 (1996) - Standby Database:**
- Concepto inicial: "Standby Database"
- Totalmente manual
- Aplicación de logs manualmente
- No había failover automático

**Oracle 8i (1999) - Managed Standby:**
- Introducción de "Managed Recovery Process" (MRP)
- Aplicación automática de archive logs
- Seguía siendo mayormente manual

**Oracle 9i (2001) - Data Guard:**
- Nombre oficial: "Oracle Data Guard"
- **Data Guard Broker** introducido (gestión centralizada)
- Logical Standby introducido
- Switchover automatizado

**Oracle 10g (2003) - Mejoras:**
- Flashback Database (reinstatement rápido)
- Real-Time Apply (aplicación sin esperar archive)
- Fast-Start Failover (FSFO)

**Oracle 11g (2007) - Active Data Guard:**
- **Active Data Guard:** Queries en standby mientras aplica logs
- Snapshot Standby mejorado
- Compresión de redo transport

**Oracle 12c (2013) - Multitenant:**
- Soporte completo para CDB/PDB
- Far Sync (replicación de larga distancia)
- Standby redo log automation

**Oracle 19c/21c (2019/2021) - Actual:**
- Automatic Block Media Recovery
- DML Redirection (escribe en standby redirige a primary)
- Mejoras en FSFO
- Mejor integración con Cloud

**En este proyecto:** Usamos Oracle 21c con todas las características modernas.

---

## 3. Arquitectura General

### Vista de Alto Nivel

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          PRIMARY DATABASE                                │
│                      (ol8-21-dg1.localdomain)                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                       APPLICATION LAYER                             │ │
│  │                                                                     │ │
│  │  Users → SQL*Plus / App → PDB1 → HEALTHCENTER schema               │ │
│  │                                                                     │ │
│  │  INSERT INTO HC_User ...                                            │ │
│  │  UPDATE HC_Payroll ...                                              │ │
│  │  COMMIT;                                                            │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│           ↓                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     ORACLE INSTANCE (SGA/PGA)                       │ │
│  │                                                                     │ │
│  │  Shared Pool | Buffer Cache | Redo Log Buffer                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│           ↓                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    BACKGROUND PROCESSES                             │ │
│  │                                                                     │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │ │
│  │  │  LGWR   │  │  DBWn   │  │  ARCn   │  │  LNS    │  │  CKPT   │ │ │
│  │  │ (Logs)  │  │ (Data)  │  │(Archive)│  │(Network)│  │(Chkpnt) │ │ │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘ │ │
│  │       │            │            │            │            │       │ │
│  └───────┼────────────┼────────────┼────────────┼────────────┼───────┘ │
│          │            │            │            ║            │          │
│          ↓            ↓            ↓            ║            ↓          │
│  ┌──────────────────────────────────────────────║──────────────────────┐│
│  │                     STORAGE LAYER            ║                      ││
│  │                                              ║                      ││
│  │  Online Redo Logs → Archive Logs ══════════════╗                    ││
│  │  Datafiles                                     ║                    ││
│  │  Control Files                                 ║                    ││
│  └────────────────────────────────────────────────║────────────────────┘│
└───────────────────────────────────────────────────║─────────────────────┘
                                                    ║
                                    NETWORK (192.168.56.0/24)
                                   Archive Log Transport
                                   (AES256 encrypted)
                                                    ║
┌───────────────────────────────────────────────────║─────────────────────┐
│                         STANDBY DATABASE         ║                      │
│                     (ol8-21-dg2.localdomain)     ║                      │
├──────────────────────────────────────────────────║──────────────────────┤
│                                                  ║                      │
│  ┌───────────────────────────────────────────────║────────────────────┐ │
│  │                 REDO TRANSPORT RECEIVE        ║                    │ │
│  │                                               ║                    │ │
│  │  ┌─────────┐                                  ║                    │ │
│  │  │   RFS   │ ◄═══════════════════════════════╝                    │ │
│  │  │(Remote  │                                                       │ │
│  │  │File Srv)│  Receives archive logs from primary                  │ │
│  │  └────┬────┘                                                       │ │
│  │       │                                                            │ │
│  └───────┼────────────────────────────────────────────────────────────┘ │
│          │                                                               │
│          ↓                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    ARCHIVE LOG STORAGE                              │ │
│  │                                                                     │ │
│  │  /u01/oradata/cdb1_stby/arch/                                      │ │
│  │  1_145_xxxxx.arc                                                    │ │
│  │  1_146_xxxxx.arc                                                    │ │
│  │  1_147_xxxxx.arc                                                    │ │
│  └────────┬───────────────────────────────────────────────────────────┘ │
│           │                                                              │
│           ↓                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                 REDO APPLY (MRP Process)                            │ │
│  │                                                                     │ │
│  │  ┌─────────┐                                                        │ │
│  │  │   MRP0  │  Reads archive logs                                   │ │
│  │  │(Managed │  Applies redo to standby datafiles                    │ │
│  │  │Recovery)│  Maintains synchronization with primary                │ │
│  │  └────┬────┘                                                        │ │
│  │       │                                                            │ │
│  └───────┼────────────────────────────────────────────────────────────┘ │
│          │                                                               │
│          ↓                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    STANDBY DATABASE FILES                           │ │
│  │                                                                     │ │
│  │  Datafiles (replica of primary)                                    │ │
│  │  Control Files (standby control file)                              │ │
│  │  Mode: MOUNTED or READ ONLY WITH APPLY                             │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Procesos de Data Guard

### Procesos en Primary

#### LGWR (Log Writer)

**Función principal:**
- Escribe cambios (redo entries) del Redo Log Buffer a los Online Redo Logs

**Interacción con Data Guard:**
- Cuando el transporte es SYNC o FASTSYNC, LGWR también envía redo al standby
- En ASYNC, LGWR solo escribe localmente; LNS envía después

**Flujo:**
```
Transacción COMMIT
    ↓
LGWR despierta
    ↓
Escribe redo buffer → Online Redo Log (disco)
    ↓ (si SYNC/FASTSYNC)
También envía a LNS para transmitir a standby
    ↓
Espera confirmación de standby (FASTSYNC)
    ↓
COMMIT confirmado al usuario
```

---

#### ARCn (Archiver Process)

**Función principal:**
- Copia Online Redo Logs llenos a Archive Logs

**Proceso:**
```
1. LGWR llena Online Redo Log Group 1
     ↓
2. Log Switch (cambia a Group 2)
     ↓
3. ARCn despierta
     ↓
4. Copia Group 1 → Archive Log
     /u01/oradata/cdb1/arch/1_145_xxxxx.arc
     ↓
5. Archive log disponible para:
   - Backup (RMAN)
   - Recovery
   - Envío a standby (si no fue enviado en tiempo real)
```

**Múltiples ARCn:**
- Oracle puede tener ARCn (ARC0, ARC1, ARC2, ARC3, ...) en paralelo
- Configurado con `LOG_ARCHIVE_MAX_PROCESSES`

**Query:**
```sql
SQL> SHOW PARAMETER log_archive_max_processes;

NAME                         TYPE    VALUE
---------------------------- ------- -----
log_archive_max_processes    integer 4
```

---

#### LNS (Log Network Server)

**Función principal:**
- **Transmite redo data** del primary al standby vía red

**Modos de operación:**

**ASYNC Mode:**
```
LNS trabaja independientemente de LGWR
    ↓
Lee archive logs ya generados
    ↓
Envía a standby cuando hay ancho de banda disponible
    ↓
Primary no espera confirmación
```

**SYNC/FASTSYNC Mode:**
```
LNS trabaja en conjunto con LGWR
    ↓
LGWR le pasa redo entries directamente
    ↓
LNS envía a standby inmediatamente
    ↓
Espera confirmación (FASTSYNC: recepción en memoria, SYNC: escritura a disco)
    ↓
Devuelve confirmación a LGWR
    ↓
LGWR confirma COMMIT al usuario
```

**Procesos LNS por destino:**
- Cada destino de standby tiene su propio proceso LNS
- Ejemplo: LNSn donde n = número de destino

**Identificar procesos LNS:**
```bash
ps -ef | grep "ora_lns" | grep -v grep

oracle   12345  1  0 10:00 ?  00:00:05 ora_lns1_cdb1
oracle   12346  1  0 10:00 ?  00:00:03 ora_lns2_cdb1
```

---

### Procesos en Standby

#### RFS (Remote File Server)

**Función principal:**
- **Recibe redo data** del primary (enviado por LNS)

**Proceso detallado:**
```
1. RFS escucha en el puerto Oracle (1521)
     ↓
2. LNS del primary conecta
     ↓
3. RFS recibe redo stream
     ↓
4. Escribe a:
   - Standby Redo Logs (si existen)
   - O directamente a Archive Logs
     ↓
5. Confirma recepción a LNS (si SYNC/FASTSYNC)
     ↓
6. RFS termina o espera más datos
```

**Múltiples RFS:**
- Un proceso RFS por cada conexión LNS
- Si hay múltiples threads o destinos, habrá múltiples RFS

**Ver procesos RFS:**
```bash
ps -ef | grep "ora_rfs" | grep -v grep

oracle   23456  1  0 10:05 ?  00:00:02 ora_rfs0_cdb1
```

---

#### MRP (Managed Recovery Process)

**Función principal:**
- **Aplica redo** del archive logs a los datafiles del standby

**Proceso detallado:**
```
1. MRP despierta (modo managed recovery)
     ↓
2. Lee el siguiente archive log secuencial
   /u01/oradata/cdb1_stby/arch/1_145_xxxxx.arc
     ↓
3. Parsea el redo log
     ↓
4. Identifica qué bloques de datafiles cambiar
     ↓
5. Aplica los cambios:
   - Inserts, Updates, Deletes
   - DDL changes
   - Block changes
     ↓
6. Actualiza control file con SCN aplicado
     ↓
7. Elimina archive log (o marca como aplicado)
     ↓
8. Lee siguiente archive log (1_146_xxxxx.arc)
     ↓
9. Repite indefinidamente
```

**Modos de Apply:**

**Managed Recovery (Automatic):**
```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;
-- MRP aplica logs automáticamente conforme llegan
```

**Real-Time Apply:**
```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
-- MRP aplica desde Standby Redo Logs sin esperar archive
```

**Ver estado de MRP:**
```sql
SQL> SELECT process, status, thread#, sequence#, block#, blocks
     FROM v$managed_standby
     WHERE process LIKE 'MRP%';

PROCESS STATUS    THREAD# SEQUENCE#    BLOCK#     BLOCKS
------- --------- ------- --------- --------- ----------
MRP0    APPLYING        1       147      5000      10000
```

---

## 5. Physical Standby vs Logical Standby

### Physical Standby (Usado en este proyecto)

**Definición:**
- Copia **exacta a nivel de bloques** del primary
- Aplica cambios físicamente (redo apply)
- Idéntico byte por byte

**Características:**

1. **Block-for-block identical:**
   ```
   Primary datafile block 12345 = Standby datafile block 12345
   ```

2. **Redo Apply:**
   - Lee redo logs
   - Aplica cambios de bloques directamente
   - Más rápido y confiable que SQL Apply

3. **Modos:**
   - **MOUNTED:** Standby cerrado, solo aplicando logs
   - **READ ONLY:** Standby abierto para queries (requiere Active Data Guard en algunos casos)
   - **READ ONLY WITH APPLY:** Queries y aplicación simultánea (Active Data Guard)

**Ventajas:**
- ✅ **Más confiable:** Garantiza consistencia exacta
- ✅ **Más rápido:** Apply a nivel de bloque es más eficiente
- ✅ **Menos riesgo:** No hay conversión SQL, solo física
- ✅ **Soporta todo:** Todos los tipos de datos, LOBs, objetos complejos
- ✅ **Flashback:** Puede usar Flashback Database para reinstatement

**Desventajas:**
- ❌ **No read-write:** No puedes modificar datos en standby (solo primary)
- ❌ **Estructura idéntica:** No puedes tener índices adicionales en standby
- ❌ **Downtime para queries:** Si está en MOUNTED, no puedes hacer queries

---

### Logical Standby

**Definición:**
- Copia **lógica** del primary
- Aplica cambios mediante **SQL statements** (SQL Apply)
- Puede tener estructura diferente

**Cómo funciona:**
```
Primary:
  INSERT INTO emp VALUES (1, 'John', 50000);
     ↓
Redo log contiene:
  Block change: Block 1234, offset 56, new data ...
     ↓
Logical Standby:
  1. Lee redo log
  2. **Convierte** block change → SQL statement
  3. Ejecuta: INSERT INTO emp VALUES (1, 'John', 50000);
```

**Ventajas:**
- ✅ **Read-Write:** Puedes agregar índices, tablas temporales
- ✅ **Offloading:** Reporting queries sin impactar primary
- ✅ **Estructura diferente:** Puedes omitir tablas no críticas

**Desventajas:**
- ❌ **Más lento:** SQL Apply es más lento que redo apply
- ❌ **Limitaciones de tipos de datos:** No soporta algunos tipos (LONGs, algunos LOBs)
- ❌ **Complejidad:** Más configuración y troubleshooting
- ❌ **Divergencia:** Puede haber inconsistencias si la conversión falla

**Cuándo usar:**
- Necesitas reporting en standby con tablas adicionales
- Quieres omitir ciertas tablas (ej: tablas de log)
- Necesitas esquema diferente en standby

**En este proyecto:** NO usamos Logical Standby. Usamos Physical Standby por confiabilidad.

---

## 6. Snapshot Standby

### ¿Qué es?

Un **Snapshot Standby** es un physical standby **temporalmente** convertido a **read-write** para pruebas.

**Escenario:**
```
Quieres probar un patch en datos de producción sin afectar producción
    ↓
Conviertes standby a Snapshot Standby
    ↓
Standby ahora es READ WRITE
    ↓
Aplicas el patch, haces pruebas
    ↓
Si funciona: Documentas
Si falla: Sabes que no debes aplicarlo a producción
    ↓
Conviertes Snapshot Standby de vuelta a Physical Standby
    ↓
Todos los cambios hechos en snapshot SE DESCARTAN
    ↓
Resincroniza con primary y sigue como standby normal
```

---

### Cómo Funciona Internamente

Usa **Flashback Database**:

```
1. Physical Standby (aplicando logs)
     ↓
2. Convierte a Snapshot Standby:
   ALTER DATABASE CONVERT TO SNAPSHOT STANDBY;
     ↓
3. Flashback crea guaranteed restore point
     ↓
4. Standby abre en READ WRITE
     ↓
5. Usuarios pueden hacer cambios (solo en snapshot)
     ↓
6. Primary sigue enviando logs (se acumulan, no se aplican)
     ↓
7. Cuando terminas pruebas:
   ALTER DATABASE CONVERT TO PHYSICAL STANDBY;
     ↓
8. Flashback regresa al restore point (descarta cambios)
     ↓
9. Aplica logs acumulados durante snapshot
     ↓
10. Standby sincronizado nuevamente
```

---

### Comandos

**Convertir a Snapshot:**
```sql
-- En el standby
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
SQL> ALTER DATABASE CONVERT TO SNAPSHOT STANDBY;
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP;

SQL> SELECT open_mode, database_role FROM v$database;

OPEN_MODE            DATABASE_ROLE
-------------------- ----------------
READ WRITE           SNAPSHOT STANDBY
```

**Hacer pruebas:**
```sql
-- Ahora puedes hacer cambios
INSERT INTO test_table VALUES (...);
UPDATE production_table SET ...;
-- Estos cambios son temporales
```

**Revertir a Physical:**
```sql
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;
SQL> ALTER DATABASE CONVERT TO PHYSICAL STANDBY;
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

SQL> SELECT open_mode, database_role FROM v$database;

OPEN_MODE            DATABASE_ROLE
-------------------- ----------------
MOUNTED              PHYSICAL STANDBY
```

---

### Casos de Uso

1. **Testing de patches:**
   - Probar Oracle patches en datos reales
   - Si falla, revertir sin impacto

2. **Testing de upgrades:**
   - Probar upgrade de 19c → 21c en snapshot
   - Validar aplicaciones

3. **Testing de cambios de aplicación:**
   - Probar nueva versión de app en datos reales
   - Validar performance

4. **Troubleshooting:**
   - Reproducir bugs en datos de producción
   - Investigar sin riesgo

**IMPORTANTE:** Durante snapshot, el standby NO está protegido. Si el primary falla, no puedes hacer failover a snapshot standby.

---

## 7. Active Data Guard

### ¿Qué es Active Data Guard?

**Active Data Guard** es una característica licenciada de Oracle que permite:
- **Queries en standby** mientras **aplica redo** simultáneamente
- Modo: `READ ONLY WITH APPLY`

**Sin Active Data Guard:**
```
Physical Standby tiene dos opciones:
1. MOUNTED (aplicando logs, sin queries)
2. READ ONLY (queries, pero NO aplica logs)

Para queries, debes:
  - Cancelar apply
  - Abrir en READ ONLY
  - Hacer queries
  - Cerrar
  - Reiniciar apply
```

**Con Active Data Guard:**
```
Physical Standby:
  - READ ONLY WITH APPLY
  - Aplica logs continuamente
  - Acepta queries simultáneamente
  - No necesitas cancelar/reiniciar apply
```

---

### Beneficios

1. **Offloading de Reporting:**
   ```
   Primary: Transacciones OLTP (inserts, updates)
   Standby: Queries de reporting (sin impacto al primary)
   ```

2. **Backups desde Standby:**
   ```bash
   # RMAN backup en standby (no carga el primary)
   rman target sys/password@standby_db

   RMAN> BACKUP DATABASE;
   ```

3. **Testing de queries:**
   - Probar queries pesadas en standby sin afectar producción

4. **DML Redirection (21c+):**
   - Ejecutas INSERT en conexión a standby
   - Oracle automáticamente redirige al primary
   - Cambio se replica de vuelta al standby

---

### Configuración

**Abrir standby en Active Data Guard:**
```sql
-- En standby
SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP MOUNT;

-- Abrir READ ONLY
SQL> ALTER DATABASE OPEN READ ONLY;

-- Iniciar apply (esta es la magia de Active Data Guard)
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

-- Verificar
SQL> SELECT open_mode, database_role FROM v$database;

OPEN_MODE              DATABASE_ROLE
---------------------- ----------------
READ ONLY WITH APPLY   PHYSICAL STANDBY
```

**Queries en standby:**
```sql
-- Usuario se conecta a standby
sqlplus healthcenter/password@standby_db

-- Puede hacer queries
SELECT * FROM hc_payroll WHERE month = '10';

-- Datos están sincronizados (puede tener lag de segundos)
```

---

### Licenciamiento

**IMPORTANTE:**
- Active Data Guard es una **opción licenciada** de Oracle
- **NO está incluida** en Oracle Database Enterprise Edition
- Requiere licencia adicional (costosa)

**En este proyecto:**
- Configuramos el standby en modo básico (MOUNTED o READ ONLY sin apply simultáneo)
- Para habilitar Active Data Guard en producción, necesitas licencia

**Alternativa gratuita:**
- Abrir standby en READ ONLY temporalmente (cancelando apply)
- Hacer queries
- Reiniciar apply

---

## 8. Transporte de Redo (Redo Transport)

### Flujo Completo de Redo Transport

```
PRIMARY                                   STANDBY

1. Transacción
   INSERT ...
   COMMIT;
     ↓
2. Redo Log Buffer
     ↓
3. LGWR escribe a Online Redo Log
     ↓
4. Log Switch (redo log lleno)
     ↓
5. ARCn archiva redo log
   /u01/.../arch/1_145.arc
     ║
     ║ REDO TRANSPORT
     ║ (LNS process)
     ║
     ╠══════════════════════════════════►6. RFS recibe
     ║                                      /u01/.../arch/1_145.arc
     ║                                            ↓
     ║                                   7. MRP aplica
     ║                                      Lee archive log
     ║                                      Aplica a datafiles
     ║                                            ↓
     ║                                   8. Standby sincronizado
     ║
     ╚═══════ Confirmación (si SYNC/FASTSYNC)
```

---

### Modos de Transporte

**ASYNC (Asynchronous):**
```
Primary:
  - LGWR escribe local
  - LNS envía cuando puede (independiente)
  - NO espera confirmación

Ventaja: Máxima performance en primary
Desventaja: Posible pérdida de datos si primary falla antes de enviar
```

**SYNC (Synchronous):**
```
Primary:
  - LGWR escribe local
  - LNS envía a standby
  - Espera que standby ESCRIBA A DISCO
  - Solo entonces confirma COMMIT

Ventaja: Cero pérdida datos
Desventaja: Más lento (espera I/O de disco en standby)
```

**FASTSYNC (Fast Synchronous - usado en este proyecto):**
```
Primary:
  - LGWR escribe local
  - LNS envía a standby
  - Espera que standby RECIBA EN MEMORIA
  - Confirma COMMIT (standby escribe a disco después)

Ventaja: Balance perfecto (cero pérdida + buen performance)
Desventaja: Muy ligera latencia de red
```

**Comparación:**
| Modo | Espera | Pérdida datos | Performance | Uso |
|------|--------|---------------|-------------|-----|
| ASYNC | No espera | Posible | Máxima | WAN, largas distancias |
| SYNC | Espera escritura disco | Cero | Más lenta | Máxima protección |
| **FASTSYNC** | Espera recepción memoria | **Cero** | **Rápida** | **LAN, recomendado** |

---

### Destinos de Archive Log

**Configuración:**
```sql
-- Ver destinos configurados
SQL> SHOW PARAMETER log_archive_dest

NAME                      TYPE    VALUE
------------------------- ------- -----------------------------
log_archive_dest_1        string  LOCATION=/u01/oradata/cdb1/arch/
log_archive_dest_2        string  SERVICE=cdb1_stby SYNC AFFIRM
                                  DB_UNIQUE_NAME=cdb1_stby
                                  VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)
```

**Explicación:**

**log_archive_dest_1:**
- **Local archive log destination**
- `LOCATION=/u01/oradata/cdb1/arch/`
- Archive logs guardados localmente en primary

**log_archive_dest_2:**
- **Remote archive log destination (standby)**
- `SERVICE=cdb1_stby`: TNS service name del standby
- `SYNC` o `FASTSYNC`: Modo de transporte
- `AFFIRM`: Confirmar escritura (necesario para SYNC/FASTSYNC)
- `DB_UNIQUE_NAME=cdb1_stby`: Identificador del standby
- `VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)`: Solo cuando primary es primary (no cuando hace failover)

---

### Standby Redo Logs (SRL)

**¿Qué son?**
- Redo logs adicionales en el **standby**
- Reciben redo data en tiempo real del primary (vía LNS → RFS)
- MRP aplica desde SRL sin esperar archive

**Ventaja:**
- **Menor lag:** Standby aplica logs sin esperar que se archive
- **Real-Time Apply:** Redo aplicado inmediatamente

**Estructura:**
```
STANDBY:
├── Online Redo Logs (normales, para si se convierte en primary)
│   ├── Group 1: redo01.log
│   ├── Group 2: redo02.log
│   └── Group 3: redo03.log
│
└── Standby Redo Logs (reciben data del primary)
    ├── Group 4: standby_redo04.log
    ├── Group 5: standby_redo05.log
    ├── Group 6: standby_redo06.log
    └── Group 7: standby_redo07.log
```

**Regla:** N+1 standby redo log groups donde N = número de online redo log groups en primary.

**Crear Standby Redo Logs:**
```sql
-- En standby
ALTER DATABASE ADD STANDBY LOGFILE GROUP 4
  ('/u01/oradata/cdb1_stby/standby_redo04.log') SIZE 50M;

ALTER DATABASE ADD STANDBY LOGFILE GROUP 5
  ('/u01/oradata/cdb1_stby/standby_redo05.log') SIZE 50M;

ALTER DATABASE ADD STANDBY LOGFILE GROUP 6
  ('/u01/oradata/cdb1_stby/standby_redo06.log') SIZE 50M;

ALTER DATABASE ADD STANDBY LOGFILE GROUP 7
  ('/u01/oradata/cdb1_stby/standby_redo07.log') SIZE 50M;
```

**Ver Standby Redo Logs:**
```sql
SQL> SELECT group#, status, type, member FROM v$logfile WHERE type = 'STANDBY';

    GROUP# STATUS  TYPE     MEMBER
---------- ------- -------- ----------------------------------------
         4         STANDBY  /u01/oradata/cdb1_stby/standby_redo04.log
         5         STANDBY  /u01/oradata/cdb1_stby/standby_redo05.log
         6         STANDBY  /u01/oradata/cdb1_stby/standby_redo06.log
         7         STANDBY  /u01/oradata/cdb1_stby/standby_redo07.log
```

---

## 9. Aplicación de Redo (Redo Apply)

### Proceso de Apply Detallado

**Fase 1: Lectura**
```
MRP (Managed Recovery Process)
    ↓
Lee siguiente archive log secuencial
    /u01/oradata/cdb1_stby/arch/1_145_xxxxx.arc
    ↓
Carga en memoria
```

**Fase 2: Parsing**
```
MRP parsea el archive log:
    ↓
Identifica redo records:
  - SCN (System Change Number)
  - Tipo de cambio (INSERT, UPDATE, DELETE, DDL)
  - Datafile y bloque afectado
  - Datos antes y después (undo y redo)
```

**Fase 3: Aplicación**
```
Para cada redo record:
    ↓
1. Leer bloque del datafile en buffer
    ↓
2. Verificar SCN del bloque
    ↓
3. Si SCN del bloque < SCN del redo:
     - Aplicar cambio al bloque
     - Actualizar SCN del bloque
    ↓
4. Marcar bloque como dirty
    ↓
5. DBWn eventualmente escribe a disco
```

**Fase 4: Checkpoint**
```
MRP actualiza:
    - Control file: último SCN aplicado
    - Datafile headers: checkpoint SCN
    ↓
Permite recovery futuro desde este punto
```

---

### Tipos de Apply

**Managed Recovery (Auto Apply):**
```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;
```
- MRP aplica logs automáticamente
- Corre en background (DISCONNECT)
- Continúa indefinidamente

**Real-Time Apply:**
```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```
- Aplica desde Standby Redo Logs (no espera archive)
- Menor lag (segundos en lugar de minutos)

**Manual Recovery:**
```sql
RECOVER STANDBY DATABASE;
```
- Aplica logs uno por uno
- Requiere intervención manual
- Usado para testing o recovery punto específico

---

## 10. System Change Number (SCN)

### ¿Qué es el SCN?

**System Change Number (SCN)** es un contador lógico que Oracle usa para:
- Identificar el **orden de las transacciones**
- Garantizar **consistencia de lectura**
- Coordinar **checkpoint y recovery**

**Características:**
- Monotónicamente creciente
- Único por transacción COMMIT
- Almacenado en cada bloque de datos

---

### SCN en Data Guard

**Primary:**
```
Transacción 1: INSERT ... COMMIT; → SCN 1000
Transacción 2: UPDATE ... COMMIT; → SCN 1001
Transacción 3: DELETE ... COMMIT; → SCN 1002
```

**Redo Log contiene:**
```
SCN 1000: INSERT INTO table1 VALUES ...
SCN 1001: UPDATE table2 SET ...
SCN 1002: DELETE FROM table3 WHERE ...
```

**Standby:**
```
MRP lee redo log:
    ↓
Aplica SCN 1000
Aplica SCN 1001
Aplica SCN 1002
    ↓
Standby ahora está en SCN 1002
```

**Ver SCN actual:**
```sql
-- En primary
SQL> SELECT current_scn FROM v$database;

CURRENT_SCN
-----------
    2145678

-- En standby (después de apply)
SQL> SELECT current_scn FROM v$database;

CURRENT_SCN
-----------
    2145650  (ligeramente atrás del primary)
```

---

### SCN y Lag

**Lag** es la diferencia de SCN entre primary y standby:

```sql
-- Query para ver lag
SELECT
  name,
  value,
  unit,
  time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');

NAME               VALUE      UNIT         TIME_COMPUTED
------------------ ---------- ------------ -------------------
transport lag      +00:00:03  seconds      2025-11-04 14:30:00
apply lag          +00:00:05  seconds      2025-11-04 14:30:00
```

**Transport lag:** Tiempo entre generación de log en primary y recepción en standby
**Apply lag:** Tiempo entre recepción en standby y aplicación a datafiles

**Objetivo:** Lag < 10 segundos (nuestro proyecto: <5 min gracias a archive_lag_target=300)

---

## 11. Recovery Window y Lag

### Recovery Window

**Definición:**
- Tiempo necesario para que standby alcance al primary después de un gap

**Factores:**
1. **Gap size:** Cuántos archive logs faltan
2. **Apply rate:** Velocidad de MRP (MB/segundo)
3. **Network bandwidth:** Ancho de banda disponible
4. **Disk I/O:** Velocidad de disco en standby

**Ejemplo:**
```
Gap: 100 archive logs faltantes
Tamaño promedio: 50 MB cada uno
Total: 5 GB

Apply rate: 50 MB/segundo
Recovery window: 5000 MB / 50 MB/s = 100 segundos (~2 minutos)
```

---

### Monitoreo de Lag

**Query completo:**
```sql
SELECT
  thread#,
  MAX(sequence#) AS max_seq
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#;

-- vs

SELECT
  thread#,
  MAX(sequence#) AS max_seq
FROM v$archived_log
WHERE standby_dest = 'YES'
GROUP BY thread#;
```

**Gap detection:**
```sql
SELECT
  thread#,
  low_sequence#,
  high_sequence#
FROM v$archive_gap;

-- Si devuelve filas, hay gap
```

---

## 12. Switchover vs Failover

### Switchover (Planned)

**Definición:** Cambio de roles planificado (primary ↔ standby) sin pérdida de datos.

**Escenario:**
- Mantenimiento planificado en servidor primary
- Testing de DR
- Balanceo de carga (mover producción a otro datacenter)

**Proceso:**
```
1. Primary = cdb1 (READ WRITE)
   Standby = cdb1_stby (MOUNTED)
     ↓
2. Switchover iniciado
     ↓
3. Primary sincroniza completamente con standby
     ↓
4. Primary se convierte a standby:
   cdb1 ahora es MOUNTED (standby role)
     ↓
5. Standby se convierte a primary:
   cdb1_stby ahora es READ WRITE (primary role)
     ↓
6. Aplicaciones reconfiguradas a nuevo primary
     ↓
7. Completado sin pérdida de datos
```

**Comando (con Data Guard Broker):**
```bash
dgmgrl sys/password@cdb1

DGMGRL> SHOW CONFIGURATION;

Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
    cdb1      - Primary database
    cdb1_stby - Physical standby database

DGMGRL> SWITCHOVER TO cdb1_stby;
Performing switchover NOW, please wait...
Operation requires a connection to database "cdb1_stby"
Connecting ...
Connected to "cdb1_stby"
Switchover succeeded, new primary is "cdb1_stby"

DGMGRL> SHOW CONFIGURATION;

Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
    cdb1_stby - Primary database
    cdb1      - Physical standby database
```

**Tiempo:** 2-5 minutos

**Pérdida de datos:** CERO

---

### Failover (Unplanned)

**Definición:** Activación de emergencia del standby cuando primary falla (no planificado).

**Escenario:**
- Primary sufre fallo catastrófico (hardware, datacenter incendio, corrupción)
- Primary no responde
- Necesitas restaurar servicio INMEDIATAMENTE

**Proceso:**
```
1. Primary = cdb1 (INACCESIBLE/FALLIDO)
   Standby = cdb1_stby (MOUNTED, aplicando logs)
     ↓
2. DBA detecta fallo de primary
     ↓
3. DBA inicia failover manual (o Fast-Start Failover automático)
     ↓
4. Standby aplica todos los logs recibidos
     ↓
5. Standby termina recovery
     ↓
6. Standby abre como nuevo primary:
   cdb1_stby ahora es READ WRITE (primary role)
     ↓
7. Aplicaciones reconfiguradas a nuevo primary
     ↓
8. Servicio restaurado
```

**Comando:**
```bash
dgmgrl sys/password@cdb1_stby

DGMGRL> SHOW CONFIGURATION;

Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
    cdb1      - Primary database (FAILED)
    cdb1_stby - Physical standby database

DGMGRL> FAILOVER TO cdb1_stby;
Performing failover NOW, please wait...
Failover succeeded, new primary is "cdb1_stby"

DGMGRL> SHOW CONFIGURATION;

Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
    cdb1_stby - Primary database
```

**Tiempo:** 1-3 minutos

**Pérdida de datos:**
- Con MAXAVAILABILITY/FASTSYNC: **CERO**
- Con ASYNC: Posible pérdida (logs no enviados)

---

### Reinstatement (Después de Failover)

**Problema:**
Después de failover, el old primary (cdb1) no es válido como standby porque divergió.

**Solución 1: Flashback Database (RÁPIDO - usado en este proyecto)**
```
Old primary tiene Flashback habilitado
    ↓
Flashback al punto antes del failover
    ↓
Convierte a standby
    ↓
Sincroniza con nuevo primary
    ↓
Tiempo: 5-10 minutos
```

**Solución 2: Rebuild (LENTO)**
```
Eliminar old primary
    ↓
Recrear standby desde nuevo primary (RMAN DUPLICATE)
    ↓
Tiempo: 30-60 minutos
```

**Por qué Flashback es crítico:**
- Sin Flashback: Horas para rebuild
- Con Flashback: Minutos para reinstatement

---

## 13. Fast-Start Failover (FSFO)

### ¿Qué es?

**Fast-Start Failover** es failover **automático** sin intervención humana.

**Requiere:**
1. Data Guard Broker configurado
2. Observer process ejecutándose
3. FSFO habilitado
4. Condiciones de failover definidas

---

### Componentes

**Observer:**
- Proceso separado que monitorea primary y standby
- Ejecuta en servidor independiente (no primary ni standby)
- Detecta fallos del primary
- Inicia failover automático

**Arquitectura:**
```
┌─────────────┐       Heartbeat       ┌─────────────┐
│   PRIMARY   │◄─────────────────────►│  OBSERVER   │
└─────────────┘                        └──────┬──────┘
                                             │
                                        Heartbeat
                                             │
┌─────────────┐                        ┌─────▼──────┐
│   STANDBY   │◄───────────────────────┤  OBSERVER  │
└─────────────┘       Heartbeat        └────────────┘
```

**Si primary falla:**
```
Observer detecta:
  - No heartbeat de primary (>FastStartFailoverThreshold segundos)
  - Standby está sincronizado
    ↓
Observer inicia failover automático a standby
    ↓
Standby se convierte en primary
    ↓
Aplicaciones redirigidas automáticamente (con TNS failover)
```

---

### Configuración (No usado en este proyecto)

**Habilitar FSFO:**
```bash
dgmgrl sys/password

DGMGRL> ENABLE FAST_START FAILOVER;
DGMGRL> EDIT CONFIGURATION SET PROPERTY FastStartFailoverThreshold = 30;
```

**Iniciar Observer:**
```bash
# En servidor independiente
nohup dgmgrl -silent sys/password <<EOF
START OBSERVER FILE IS '/home/oracle/observer.dat';
EOF &
```

**Verificar:**
```bash
DGMGRL> SHOW FAST_START FAILOVER;

Fast-Start Failover: ENABLED

  Threshold:          30 seconds
  Target:             cdb1_stby
  Observer:           observer-server
  Lag Limit:          30 seconds
  Shutdown Primary:   TRUE
  Auto-reinstate:     TRUE
```

---

### Condiciones de Failover

**FSFO solo hace failover si:**
1. Primary no responde (heartbeat timeout)
2. Standby está sincronizado (lag < threshold)
3. No hay errores en standby
4. Network partition confirmado (observer no puede alcanzar primary, pero standby sí puede)

**Ventaja:** Downtime mínimo (30-60 segundos)

**Riesgo:** Failover innecesario si es problema de red (no fallo real de primary)

---

## 14. Data Guard en Este Proyecto

### Configuración Actual

**Primary:** cdb1 (ol8-21-dg1.localdomain)
- IP: 192.168.56.101
- Rol: PRIMARY
- Open Mode: READ WRITE
- Protection Mode: MAXAVAILABILITY
- Archive Lag Target: 300 segundos

**Standby:** cdb1_stby (ol8-21-dg2.localdomain)
- IP: 192.168.56.102
- Rol: PHYSICAL STANDBY
- Open Mode: MOUNTED (o READ ONLY)
- Redo Apply: ACTIVE

**Transport:** FASTSYNC
**Flashback:** Habilitado en ambos
**Broker:** Configurado y habilitado

---

### Monitoreo Automatizado

**Script:** `/home/oracle/automation/check_log_transport.sh`

**Ejecución:** Cada 10 minutos (cron)

**Verifica:**
- Gap en archive logs
- Lag de apply
- Estado de procesos (LNS, RFS, MRP)
- Conectividad entre primary y standby

**Alertas si:**
- Gap > 10 sequences
- Apply lag > 15 minutos
- Procesos caídos

---

## 15. Configuración y Queries

### Ver Configuración

**Role y Mode:**
```sql
SQL> SELECT database_role, open_mode, protection_mode, protection_level
     FROM v$database;

DATABASE_ROLE    OPEN_MODE  PROTECTION_MODE      PROTECTION_LEVEL
---------------- ---------- -------------------- ----------------
PRIMARY          READ WRITE MAXIMUM AVAILABILITY MAXIMUM AVAILABILITY
```

**Destinos de Archive:**
```sql
SQL> SELECT dest_id, status, destination, error
     FROM v$archive_dest
     WHERE status != 'INACTIVE';

   DEST_ID STATUS    DESTINATION                ERROR
---------- --------- -------------------------- -----
         1 VALID     /u01/oradata/cdb1/arch/
         2 VALID     cdb1_stby
```

**Archive Log Shipping:**
```sql
SQL> SELECT thread#, sequence#, first_time, next_time,
            applied, archived, deleted
     FROM v$archived_log
     WHERE dest_id = 2
     ORDER BY sequence# DESC
     FETCH FIRST 10 ROWS ONLY;
```

---

### Monitoreo de Lag

**Standby Lag:**
```sql
SELECT
  name,
  value,
  unit,
  time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
```

**Ver Gap:**
```sql
SELECT * FROM v$archive_gap;
```

**Estado de Apply:**
```sql
SELECT process, status, thread#, sequence#, block#, blocks
FROM v$managed_standby
WHERE process LIKE 'MRP%' OR process LIKE 'RFS%';
```

---

## 16. Monitoreo de Data Guard

### Verificación Completa

**Script:** `/home/oracle/automation/verify_dataguard.sh`

```bash
#!/bin/bash
. /home/oracle/scripts/setEnv.sh

echo "=== DATA GUARD VERIFICATION ==="

# Primary status
sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SELECT 'PRIMARY STATUS' AS check_name FROM dual;
SELECT database_role, open_mode, protection_mode FROM v$database;

SELECT 'ARCHIVE DESTINATIONS' AS check_name FROM dual;
SELECT dest_id, status, destination FROM v$archive_dest WHERE status != 'INACTIVE';

SELECT 'RECENT ARCHIVE LOGS' AS check_name FROM dual;
SELECT sequence#, first_time, applied FROM v$archived_log
WHERE dest_id = 2 ORDER BY sequence# DESC FETCH FIRST 5 ROWS ONLY;

SELECT 'DATA GUARD STATS' AS check_name FROM dual;
SELECT name, value, unit FROM v$dataguard_stats;
EOF
```

---

## 17. Troubleshooting Común

### Problema: Gap en Archive Logs

**Síntoma:**
```sql
SQL> SELECT * FROM v$archive_gap;

THREAD# LOW_SEQUENCE# HIGH_SEQUENCE#
------- ------------- --------------
      1           145            150
```

**Causa:** Standby perdió algunos archive logs (red caída, etc.)

**Solución:**
```bash
# En primary, copiar los archive logs faltantes manualmente
scp /u01/oradata/cdb1/arch/1_145_*.arc oracle@standby:/tmp/
scp /u01/oradata/cdb1/arch/1_146_*.arc oracle@standby:/tmp/
...

# En standby, registrar los logs
sqlplus / as sysdba

SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '/tmp/1_145_*.arc';
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '/tmp/1_146_*.arc';
...

-- MRP aplicará automáticamente
```

---

### Problema: MRP No Está Aplicando

**Síntoma:**
```sql
SQL> SELECT process, status FROM v$managed_standby WHERE process = 'MRP0';

PROCESS STATUS
------- -------
MRP0    IDLE
```

**Solución:**
```sql
-- Cancelar recovery actual
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

-- Reiniciar recovery
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;

-- Verificar
SELECT process, status FROM v$managed_standby WHERE process = 'MRP0';

PROCESS STATUS
------- --------
MRP0    APPLYING
```

---

### Problema: Transport Lag Alto

**Síntoma:**
```
apply lag: +00:30:00 (30 minutos)
```

**Causas posibles:**
1. Network lento
2. Primary generando logs muy rápido
3. Standby disk I/O lento
4. MRP no tiene suficientes recursos

**Solución:**
```sql
-- Ver si MRP está activo
SELECT process, status FROM v$managed_standby WHERE process = 'MRP0';

-- Ver velocidad de apply
SELECT SOFAR, TOTALWORK FROM v$recovery_progress WHERE ITEM = 'Active Apply Rate';

-- Si es lento, considerar:
-- 1. Aumentar recursos en standby
-- 2. Usar Real-Time Apply
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

---

## 🎯 Resumen

Oracle Data Guard es una solución integral de alta disponibilidad que:

1. **Replica automáticamente** todos los cambios del primary al standby
2. **Garantiza cero pérdida de datos** con MAXAVAILABILITY
3. **Permite recuperación rápida** con switchover/failover en minutos
4. **Usa procesos especializados:**
   - Primary: LGWR, ARCn, LNS
   - Standby: RFS, MRP, ARCn
5. **Soporta múltiples tipos:**
   - Physical Standby (usado aquí)
   - Logical Standby
   - Snapshot Standby
   - Active Data Guard
6. **Protege contra:**
   - Fallos de hardware
   - Corrupción de datos
   - Desastres naturales
   - Errores humanos

En este proyecto, implementamos un Data Guard robusto con cero pérdida de datos (RPO=0) y recuperación en minutos (RTO=2-3 min), todo automatizado y monitoreado continuamente.

---

## 📚 Referencias

- [82 - Modos de Protección](82-modos-proteccion.md) - MAXAVAILABILITY y FASTSYNC explicados
- [83 - Archive Logs](83-archive-logs.md) - Mecanismo de archive logs detallado
- [84 - Flashback Database](84-flashback-database.md) - Reinstatement rápido
- [85 - Data Guard Broker](85-data-guard-broker.md) - Gestión centralizada
