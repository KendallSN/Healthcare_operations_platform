# 02 - Conceptos Fundamentales

## Conceptos Básicos Necesarios para Entender el Sistema

Antes de comenzar con el despliegue, es importante entender algunos conceptos fundamentales de Oracle Database y Data Guard. Este documento explica la terminología básica que usarás a lo largo de la documentación.

---

## 📋 Tabla de Contenidos

1. [¿Qué es Oracle Database?](#1-qué-es-oracle-database)
2. [Container Database (CDB) vs Pluggable Database (PDB)](#2-container-database-cdb-vs-pluggable-database-pdb)
3. [¿Qué es Oracle Data Guard?](#3-qué-es-oracle-data-guard)
4. [Primary Database vs Standby Database](#4-primary-database-vs-standby-database)
5. [Alta Disponibilidad y Recuperación ante Desastres](#5-alta-disponibilidad-y-recuperación-ante-desastres)
6. [Replicación Sincrónica vs Asincrónica](#6-replicación-sincrónica-vs-asincrónica)
7. [Archive Logs](#7-archive-logs)
8. [Virtualización: VirtualBox y Vagrant](#8-virtualización-virtualbox-y-vagrant)

---

## 1. ¿Qué es Oracle Database?

**Oracle Database** es un **sistema de gestión de bases de datos relacionales (RDBMS)** de nivel empresarial desarrollado por Oracle Corporation.

### Definición Simple

Una base de datos Oracle es como un **almacén super organizado** donde guardas datos en **tablas** (como hojas de Excel), pero con capacidades mucho más avanzadas:

- **Transacciones ACID:** Garantiza que los datos siempre estén consistentes
- **SQL:** Lenguaje estándar para consultar y manipular datos
- **PL/SQL:** Lenguaje de programación para lógica de negocio
- **Concurrencia:** Miles de usuarios pueden acceder simultáneamente
- **Seguridad:** Control de acceso granular
- **Rendimiento:** Optimizado para grandes volúmenes de datos

### Versiones

**Oracle Database 21c** (la usada en este proyecto):
- **c** = "c" de Cloud (diseñado para la nube)
- Versión: 21.3.0.0.0
- Enterprise Edition (todas las características disponibles)
- Lanzado: 2021

**Otras versiones comunes:**
- 11g (2007-2019) - g = Grid
- 12c (2013-2021) - c = Cloud
- 18c, 19c - Long Term Support
- 21c, 23c - Innovation releases

---

## 2. Container Database (CDB) vs Pluggable Database (PDB)

A partir de Oracle 12c, Oracle introdujo la **arquitectura multitenant**: CDB y PDB.

### ¿Qué es un CDB (Container Database)?

El **Container Database** es la base de datos de nivel superior que actúa como un **contenedor** para una o más Pluggable Databases.

**Analogía:** El CDB es un **edificio de apartamentos**.

**Contiene:**
- Sistema de Oracle
- Metadata común
- Usuarios administrativos (SYS, SYSTEM)
- Root container (CDB$ROOT)
- Seed PDB (PDB$SEED) - plantilla para crear nuevas PDBs
- Una o más Pluggable Databases

**En este proyecto:**
- Nombre del CDB: `cdb1` (primary) y `cdb1_stby` (standby)

---

### ¿Qué es un PDB (Pluggable Database)?

Una **Pluggable Database** es una base de datos **autónoma y portable** dentro de un CDB.

**Analogía:** Un PDB es un **apartamento individual** dentro del edificio.

**Características:**
- Tiene sus propios usuarios y schemas
- Tiene sus propios datafiles
- Se puede abrir/cerrar independientemente
- Se puede "desenchufar" (unplug) y "enchufar" (plug) en otro CDB
- Aislamiento: un PDB no ve los datos de otro PDB

**En este proyecto:**
- Nombre del PDB: `pdb1`
- Schema de aplicación: `HEALTHCENTER` (vive dentro de pdb1)

---

### ¿Por Qué Usar CDB/PDB?

**Ventajas:**

✅ **Consolidación:** Múltiples aplicaciones en una sola instancia Oracle (ahorra recursos)

✅ **Portabilidad:** Mueve PDBs entre CDBs fácilmente

✅ **Aislamiento:** Cada PDB es independiente

✅ **Patching:** Actualiza el CDB y todos los PDBs se benefician

✅ **Clonación Rápida:** Crea copias de PDBs en minutos

**En este proyecto:**
- Solo tenemos 1 PDB (pdb1) con el schema healthcare
- Podríamos agregar más PDBs sin crear más CDBs

---

### Diagrama CDB/PDB

```
┌────────────────────────────────────────────────────────┐
│              Container Database (CDB: cdb1)             │
│                                                        │
│  ┌──────────────────────────────────────────────┐     │
│  │         Root Container (CDB$ROOT)             │     │
│  │  - System tablespaces                         │     │
│  │  - Common users (SYS, SYSTEM)                │     │
│  │  - Shared Oracle processes                    │     │
│  └──────────────────────────────────────────────┘     │
│                                                        │
│  ┌──────────────────────────────────────────────┐     │
│  │         Seed PDB (PDB$SEED)                   │     │
│  │  - Template for creating new PDBs            │     │
│  └──────────────────────────────────────────────┘     │
│                                                        │
│  ┌──────────────────────────────────────────────┐     │
│  │    Pluggable Database (PDB: pdb1)            │     │
│  │                                               │     │
│  │  - Application schema: HEALTHCENTER          │     │
│  │  - Tables: HC_User, HC_Payroll, etc.         │     │
│  │  - Procedures, Packages, Triggers            │     │
│  │  - Application users                         │     │
│  └──────────────────────────────────────────────┘     │
│                                                        │
│  (Podrías tener más PDBs: pdb2, pdb3, ...)           │
└────────────────────────────────────────────────────────┘
```

---

### Conexiones: CDB vs PDB

**Conectar al CDB (administración):**
```bash
sqlplus sys/password@localhost:1521/cdb1 as sysdba
```

**Conectar al PDB (aplicación):**
```bash
sqlplus HEALTHCENTER/password@localhost:1521/pdb1
```

**Desde dentro del CDB, cambiar a PDB:**
```sql
SQL> ALTER SESSION SET CONTAINER=pdb1;
SQL> SHOW CON_NAME;

CON_NAME
------------------------------
PDB1
```

---

## 3. ¿Qué es Oracle Data Guard?

**Oracle Data Guard** es una solución de **alta disponibilidad**, **recuperación ante desastres**, y **protección de datos** de Oracle.

### Definición Simple

Data Guard mantiene una o más **copias idénticas** (standby databases) de tu base de datos principal (primary database), sincronizadas **automáticamente en tiempo real**.

**Analogía:** Es como tener un **escriba** que copia todo lo que escribes en un cuaderno (primary) en otro cuaderno (standby) **al mismo tiempo**.

---

### ¿Qué Hace Data Guard?

1. **Replica automáticamente** todos los cambios del primary al standby
2. **Detecta fallos** del primary
3. **Cambia automáticamente** al standby si el primary falla (failover)
4. **Permite cambios planificados** (switchover) para mantenimiento
5. **Protege contra corrupción** de datos

---

### Tipos de Standby

**Physical Standby (usado en este proyecto):**
- Copia **exacta a nivel de bloques** del primary
- Cambios aplicados **físicamente** a los datafiles
- Puede abrirse en **read-only** para queries
- **Más común y recomendado**

**Logical Standby:**
- Copia **lógica** (SQL statements aplicados)
- Puede tener estructura diferente
- Más flexible pero más complejo

**Snapshot Standby:**
- Standby temporal en modo read-write para pruebas
- Se descarta y resincroniza después

---

### Componentes de Data Guard

**En el Primary:**
- **ARCn (Archiver):** Crea archive logs de los redo logs llenos
- **LNS (Log Network Server):** Envía redo data al standby
- **LGWR (Log Writer):** Escribe cambios a redo logs

**En el Standby:**
- **RFS (Remote File Server):** Recibe redo data del primary
- **MRP (Managed Recovery Process):** Aplica los cambios recibidos
- **ARCn:** Archiva logs recibidos

**Data Guard Broker (Management):**
- Framework de gestión centralizada
- Simplifica configuración, monitoreo, switchover, failover
- Usado en este proyecto

---

## 4. Primary Database vs Standby Database

### Primary Database

**Rol:** Producción, recibe todas las transacciones.

**Características:**
- **Read-Write:** Usuarios pueden leer y escribir datos
- **Activa:** Procesa transacciones normalmente
- **Origen de verdad:** Es la fuente de datos

**En este proyecto:**
- DB_NAME: cdb1
- DB_UNIQUE_NAME: cdb1
- Hostname: ol8-21-dg1.localdomain
- IP: 192.168.56.101
- Puerto: 1521

---

### Standby Database

**Rol:** Backup activo, recibe replicación continua.

**Características:**
- **Read-Only** (o mounted): No acepta escrituras
- **Pasiva:** Solo aplica cambios del primary
- **Backup en vivo:** Siempre sincronizada con primary
- **Lista para activarse:** Puede convertirse en primary con failover

**En este proyecto:**
- DB_NAME: cdb1 (mismo!)
- DB_UNIQUE_NAME: cdb1_stby (diferente para identificación)
- Hostname: ol8-21-dg2.localdomain
- IP: 192.168.56.102
- Puerto: 1521 (1522 desde Windows host)

---

### ¿Por Qué Tienen el Mismo DB_NAME?

El **DB_NAME** es el **nombre lógico** de la base de datos.

El standby es una **copia física del primary**, por lo tanto debe tener el mismo `DB_NAME`.

**Pero:** Necesitan diferentes `DB_UNIQUE_NAME` para que Data Guard los distinga:
- Primary: `DB_UNIQUE_NAME=cdb1`
- Standby: `DB_UNIQUE_NAME=cdb1_stby`

**Analogía:** Dos copias del mismo libro (mismo título = DB_NAME), pero en diferentes bibliotecas (DB_UNIQUE_NAME diferente).

---

## 5. Alta Disponibilidad y Recuperación ante Desastres

### Alta Disponibilidad (High Availability - HA)

**Objetivo:** Minimizar **downtime** (tiempo de inactividad).

**Pregunta clave:** ¿Cuánto tiempo puede estar tu aplicación sin funcionar?

**Métricas:**
- **RTO (Recovery Time Objective):** Tiempo máximo aceptable de downtime
  - Con Data Guard: 1-5 minutos (failover automático)
- **RPO (Recovery Point Objective):** Cantidad máxima de datos que puedes perder
  - Con Data Guard MAXAVAILABILITY: **cero pérdida** (sincrónico)

**En este proyecto:**
- RTO: ~2 minutos (tiempo de failover)
- RPO: **0 segundos** (MAXAVAILABILITY + FASTSYNC)

---

### Recuperación ante Desastres (Disaster Recovery - DR)

**Objetivo:** Proteger contra **desastres catastróficos**.

**Escenarios:**
- Incendio en datacenter
- Inundación
- Fallo eléctrico total
- Corrupción de datos
- Ransomware

**Sin Data Guard:**
- Restaurar desde backup (horas/días)
- Pérdida de datos (hasta el último backup)

**Con Data Guard:**
- Failover al standby (minutos)
- Cero pérdida de datos (con MAXAVAILABILITY)

---

### Analogías

**Sin Data Guard:**
```
Tu casa (primary) se incendia
    ↓
Buscar backup en almacenamiento
    ↓
Restaurar (8 horas)
    ↓
Datos perdidos desde último backup (ayer)
```

**Con Data Guard:**
```
Tu casa (primary) se incendia
    ↓
Mudarse inmediatamente a casa idéntica (standby) - 2 minutos
    ↓
Sin pérdida de datos (copia en tiempo real)
```

---

## 6. Replicación Sincrónica vs Asincrónica

### Replicación Asincrónica (ASYNC)

**Cómo funciona:**
1. Primary **no espera** confirmación del standby
2. Primary envía cambios **cuando puede**
3. Standby aplica cambios **cuando los recibe**

**Ventajas:**
- ✅ **Rápido** para el primary (no espera)
- ✅ Funciona con **conexiones lentas** o **WAN**

**Desventajas:**
- ❌ **Posible pérdida de datos** si primary falla antes de enviar logs
- ❌ Standby puede quedar **atrasado**

**Cuándo usar:** Standby geográficamente lejos, RPO de minutos/horas aceptable

---

### Replicación Sincrónica (SYNC / FASTSYNC)

**Cómo funciona:**
1. Primary **espera** confirmación del standby
2. Standby confirma cuando **recibe** (FASTSYNC) o **escribe a disco** (SYNC)
3. Primary **no continúa** hasta recibir confirmación

**Ventajas:**
- ✅ **Cero pérdida de datos**
- ✅ Standby siempre **sincronizado**

**Desventajas:**
- ❌ **Más lento** (latencia de red afecta primary)
- ❌ Requiere **red rápida y confiable**

**En este proyecto:** Usamos **FASTSYNC** (espera recepción en memoria, no disco).

---

### FASTSYNC vs SYNC

| Aspecto | SYNC | FASTSYNC |
|---------|------|----------|
| **Espera** | Standby escribe a **disco** | Standby recibe en **memoria** |
| **Velocidad** | Más lento | Más rápido |
| **Pérdida de datos** | Cero | Cero (standby escribe a disco después) |
| **Uso** | Máxima protección | Balance velocidad/protección |

**Por qué FASTSYNC es seguro:**
- Standby recibe redo en memoria buffer
- Standby escribe a disco asíncronamente
- Si standby cae, tiene redo en memoria para escribir al reiniciar
- Muy raro que standby pierda memoria Y disco simultáneamente

---

## 7. Archive Logs

### ¿Qué son los Archive Logs?

Los **Archive Logs** son copias de los **Online Redo Logs** que Oracle crea cuando un redo log se llena.

### Flujo de Redo Logs

```
1. Transacción (INSERT, UPDATE, DELETE)
       ↓
2. Cambios escritos en REDO LOG BUFFER (memoria)
       ↓
3. Commit
       ↓
4. LGWR escribe a ONLINE REDO LOG (disco)
       ↓
5. Online Redo Log se llena
       ↓
6. LOG SWITCH (cambio a siguiente redo log)
       ↓
7. ARCn copia redo log lleno → ARCHIVE LOG
       ↓
8. Archive log disponible para:
   - Recuperación
   - Replicación a standby
   - Backup
```

---

### Online Redo Logs vs Archive Logs

**Online Redo Logs:**
- **Ubicación:** `/u01/oradata/cdb1/redo01.log`, `redo02.log`, `redo03.log`
- **Cantidad:** 3 grupos (circular)
- **Tamaño:** 50 MB cada uno (configurable)
- **Uso:** Activo, Oracle escribe cambios aquí
- **Reutilización:** Sí (circular)

**Archive Logs:**
- **Ubicación:** `/u01/oradata/cdb1/arch/`
- **Cantidad:** Ilimitada (hasta limpiar)
- **Tamaño:** 50 MB (depende del online redo log source)
- **Uso:** Histórico, para recuperación y replicación
- **Reutilización:** No (archivos inmutables)

---

### Formato de Archive Logs

**Ejemplo:** `1_145_1234567890.arc`

Donde:
- `1` = Thread number (instancia)
- `145` = Sequence number (consecutivo)
- `1234567890` = Resetlogs ID (identificador único)
- `.arc` = Extensión

---

### Archive Lag Target

**Configuración en este proyecto:**
```sql
ALTER SYSTEM SET archive_lag_target=300;
```

**Qué hace:**
- Fuerza un **log switch cada 5 minutos** (300 segundos)
- Incluso si el redo log **no está lleno**

**Por qué es importante:**
- Sin esto: Si no hay transacciones, no hay log switch, standby no recibe cambios
- Con esto: Standby nunca está más de **5 minutos** atrasado

**Cumple requisito del entregable:** "Actualización cada 5 minutos"

---

### Limpieza de Archive Logs

**Problema:** Archive logs se acumulan y llenan el disco.

**Solución en este proyecto:**
- **Primary:** Elimina archives >3 días (después de backup)
- **Standby:** Elimina archives >3 días (después de aplicar)
- **Scripts:** `delete_archives_primary.sh`, `delete_archives_standby.sh`
- **Frecuencia:** Diario (cron jobs)

**Requisito del entregable cumplido:** "Eliminar archivos con rango de 3 días"

---

## 8. Virtualización: VirtualBox y Vagrant

### ¿Qué es Virtualización?

**Virtualización** permite ejecutar múltiples **máquinas virtuales** (VMs) en una sola computadora física.

**Analogía:** Tu computadora es un edificio. Cada VM es un apartamento independiente con su propio sistema operativo.

---

### VirtualBox

**Oracle VM VirtualBox** es un **hypervisor** (software de virtualización).

**Qué hace:**
- Crea máquinas virtuales
- Emula hardware (CPU, RAM, disco, red)
- Ejecuta sistemas operativos guest (Oracle Linux 8)
- Aísla VMs entre sí

**Tipo:** Hypervisor Tipo 2 (corre sobre Windows, no directamente en hardware)

**En este proyecto:**
- Crea 2 VMs (primary y standby)
- Cada VM tiene Oracle Linux 8
- Cada VM tiene 4GB RAM, 2 CPUs, 200GB disco

---

### Vagrant

**Vagrant** es una herramienta de **orquestación** de máquinas virtuales.

**Qué hace:**
- **Automatiza** creación de VMs (no clicks manuales)
- **Configura** red, discos, recursos
- **Provisiona** software (ejecuta scripts)
- **Gestiona** ciclo de vida (up, halt, destroy, reload)

**Analogía:** Vagrant es como un **arquitecto** que toma tus planos (Vagrantfile) y construye el edificio (VMs) automáticamente.

---

### Vagrantfile

**El Vagrantfile** es un archivo de configuración en Ruby que define las VMs.

**Ubicación:** Raíz del proyecto (`Vagrantfile`)

**Ejemplo simplificado:**
```ruby
Vagrant.configure("2") do |config|
  config.vm.define "primary" do |primary|
    primary.vm.box = "oraclelinux/8"
    primary.vm.hostname = "ol8-21-dg1.localdomain"
    primary.vm.network "private_network", ip: "192.168.56.101"

    primary.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = 2
    end

    primary.vm.provision "shell", path: "2-Standby/scripts/primary/setup.sh"
  end

  config.vm.define "standby" do |standby|
    # Similar configuración...
  end
end
```

**Qué declara:**
- Nombres de VMs (primary, standby)
- Sistema operativo base (Oracle Linux 8)
- Red (IPs, port forwarding)
- Recursos (RAM, CPU)
- Discos adicionales
- Scripts de provisioning

---

### Comandos Vagrant Comunes

```bash
# Crear y arrancar VMs
vagrant up

# Ver estado
vagrant status

# Conectar por SSH
vagrant ssh primary

# Reiniciar
vagrant reload primary

# Apagar
vagrant halt

# Destruir
vagrant destroy -f

# Re-ejecutar provisioning
vagrant provision primary
```

---

### Synced Folders

**Vagrant sincroniza** carpetas entre host (Windows) y VMs (Linux).

**En este proyecto:**
- Host: `C:\Users\...\AdminBDProyecto\` → VM: `/vagrant/`
- Host: `config/` → VM: `/vagrant_config/`
- Host: `software/` → VM: `/vagrant_software/`
- Host: `2-Standby/automation/` → VM: `/vagrant_automation/`

**Por qué es útil:**
- Editas código en Windows
- Scripts se ejecutan en Linux
- No necesitas copiar archivos manualmente

**Tecnología:** VirtualBox Guest Additions (vboxsf filesystem)

---

## 🎯 Resumen de Conceptos

| Concepto | Definición Simple |
|----------|-------------------|
| **Oracle Database** | Sistema de gestión de bases de datos empresarial |
| **CDB** | Contenedor de databases (edificio) |
| **PDB** | Base de datos individual (apartamento) |
| **Data Guard** | Sistema de replicación y alta disponibilidad |
| **Primary** | Base de datos principal (activa, read-write) |
| **Standby** | Copia sincronizada (pasiva, read-only) |
| **Archive Logs** | Archivos de cambios para replicación |
| **MAXAVAILABILITY** | Modo de protección (cero pérdida datos) |
| **FASTSYNC** | Modo de transporte (sincrónico rápido) |
| **VirtualBox** | Software de virtualización |
| **Vagrant** | Orquestador de VMs |

---

## 🔗 Relaciones Entre Conceptos

```
Oracle Database 21c
    │
    ├─> CDB (cdb1)
    │      │
    │      └─> PDB (pdb1)
    │             │
    │             └─> HEALTHCENTER Schema
    │
    ├─> Data Guard (replicación)
    │      │
    │      ├─> Primary (cdb1)
    │      └─> Standby (cdb1_stby)
    │
    └─> Archive Logs (mecanismo de replicación)
           │
           ├─> MAXAVAILABILITY (sin pérdida datos)
           └─> FASTSYNC (sincrónico)

VirtualBox (host)
    │
    ├─> Primary VM (Oracle Linux 8)
    │      └─> Oracle DB + Primary
    │
    └─> Standby VM (Oracle Linux 8)
           └─> Oracle DB + Standby

Vagrant (orquestador)
    └─> Automatiza todo lo anterior
```

---

## ⏭️ Siguientes Pasos

**Después de entender estos conceptos:**

1. ✅ Verifica que cumples los [Prerequisitos](03-prerequisitos.md)
2. ✅ Despliega el sistema con [Cómo Usar](04-como-usar.md)
3. ✅ Explora la [Arquitectura del Sistema](05-arquitectura-sistema.md)
4. ✅ Profundiza en [Conceptos Avanzados](conceptos-avanzados/) cuando estés listo

---

## 📚 Glosario Rápido

| Término | Significado |
|---------|-------------|
| **ACID** | Atomicity, Consistency, Isolation, Durability (propiedades de transacciones) |
| **ARCn** | Archiver process (crea archive logs) |
| **Commit** | Confirmar una transacción |
| **Datafile** | Archivo físico que contiene datos de tablas |
| **DBA** | Database Administrator |
| **DDL** | Data Definition Language (CREATE, ALTER, DROP) |
| **DML** | Data Manipulation Language (INSERT, UPDATE, DELETE) |
| **Instance** | Procesos + memoria de Oracle en ejecución |
| **LGWR** | Log Writer (escribe redo logs) |
| **LNS** | Log Network Server (envía logs a standby) |
| **MRP** | Managed Recovery Process (aplica logs en standby) |
| **PL/SQL** | Procedural Language/SQL (programación en Oracle) |
| **RDBMS** | Relational Database Management System |
| **Redo Log** | Registro de cambios (para recuperación) |
| **RFS** | Remote File Server (recibe logs en standby) |
| **RMAN** | Recovery Manager (herramienta de backup) |
| **RPO** | Recovery Point Objective (pérdida de datos aceptable) |
| **RTO** | Recovery Time Objective (downtime aceptable) |
| **Schema** | Colección de objetos (tablas, procedures) de un usuario |
| **SQL** | Structured Query Language |
| **Tablespace** | Espacio lógico que agrupa datafiles |
| **TNS** | Transparent Network Substrate (networking de Oracle) |
| **VM** | Virtual Machine |

---

**¡Has completado los conceptos fundamentales!** 🎉

Ahora tienes el conocimiento base para entender el resto de la documentación.

Continúa con [03 - Prerequisitos](03-prerequisitos.md) →
