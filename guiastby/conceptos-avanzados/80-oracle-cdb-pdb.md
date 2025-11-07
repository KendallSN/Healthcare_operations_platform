# 80 - Arquitectura Multitenant: CDB y PDB

## Container Database y Pluggable Database - Fundamentos Profundos

La arquitectura multitenant introducida en Oracle Database 12c representa uno de los cambios más significativos en la historia de Oracle Database. Este documento explora en profundidad los conceptos de Container Database (CDB) y Pluggable Database (PDB), su funcionamiento interno, ventajas, casos de uso y su implementación en este proyecto.

Antes de Oracle 12c, cada base de datos era completamente independiente, con su propia instancia, procesos, memoria y archivos. Con la arquitectura multitenant, Oracle permite consolidar múltiples bases de datos (PDBs) en una sola instancia de Oracle (CDB), compartiendo recursos de manera eficiente pero manteniendo el aislamiento lógico.

En este proyecto, utilizamos un CDB llamado `cdb1` (primary) y `cdb1_stby` (standby), cada uno conteniendo un PDB llamado `pdb1` donde reside el schema de aplicación `HEALTHCENTER`. Aunque solo tenemos un PDB, la arquitectura está diseñada para escalar fácilmente agregando más PDBs sin necesidad de crear nuevas instancias de Oracle.

Esta arquitectura es particularmente poderosa cuando se combina con Oracle Data Guard, ya que la replicación ocurre a nivel CDB, automáticamente protegiendo todos los PDBs contenidos dentro. Esto simplifica significativamente la administración de alta disponibilidad para múltiples aplicaciones.

---

## 📋 Tabla de Contenidos

1. [¿Qué es la Arquitectura Multitenant?](#1-qué-es-la-arquitectura-multitenant)
2. [¿Por Qué Oracle Creó CDB/PDB?](#2-por-qué-oracle-creó-cdbpdb)
3. [Container Database (CDB) - Arquitectura Interna](#3-container-database-cdb---arquitectura-interna)
4. [Pluggable Database (PDB) - Arquitectura Interna](#4-pluggable-database-pdb---arquitectura-interna)
5. [Componentes del CDB](#5-componentes-del-cdb)
6. [Recursos Compartidos vs Aislados](#6-recursos-compartidos-vs-aislados)
7. [Arquitectura de Memoria (SGA/PGA)](#7-arquitectura-de-memoria-sgapga)
8. [Arquitectura de Almacenamiento](#8-arquitectura-de-almacenamiento)
9. [Conexiones: CDB vs PDB](#9-conexiones-cdb-vs-pdb)
10. [Operaciones sobre PDBs](#10-operaciones-sobre-pdbs)
11. [CDB/PDB en Este Proyecto](#11-cdbpdb-en-este-proyecto)
12. [Casos de Uso y Ventajas](#12-casos-de-uso-y-ventajas)
13. [Limitaciones y Consideraciones](#13-limitaciones-y-consideraciones)
14. [Comandos y Queries Relevantes](#14-comandos-y-queries-relevantes)
15. [Mejores Prácticas](#15-mejores-prácticas)
16. [Comparación: Pre-12c vs Multitenant](#16-comparación-pre-12c-vs-multitenant)

---

## 1. ¿Qué es la Arquitectura Multitenant?

### Definición

La **arquitectura multitenant** de Oracle es un modelo donde múltiples bases de datos independientes (llamadas **Pluggable Databases** o PDBs) coexisten dentro de una única instancia de Oracle (llamada **Container Database** o CDB).

### Analogía del Edificio

Imagina que antes de 12c, cada aplicación necesitaba su propio edificio completo:
- Edificio A: Oracle instance para App1 (4GB RAM, 2 CPUs, procesos dedicados)
- Edificio B: Oracle instance para App2 (4GB RAM, 2 CPUs, procesos dedicados)
- Edificio C: Oracle instance para App3 (4GB RAM, 2 CPUs, procesos dedicados)

**Total:** 12GB RAM, 6 CPUs, tres conjuntos completos de procesos background.

Con la arquitectura multitenant:
- **Edificio único (CDB):** Una instancia Oracle (6GB RAM, 2 CPUs, un conjunto de procesos)
  - **Apartamento A (PDB1):** App1
  - **Apartamento B (PDB2):** App2
  - **Apartamento C (PDB3):** App3

**Total:** 6GB RAM, 2 CPUs, un conjunto de procesos background compartido.

**Ventaja:** Reducción del 50% en recursos, pero cada "apartamento" (PDB) sigue siendo independiente y aislado.

---

### Componentes Principales

```
┌─────────────────────────────────────────────────────────────────┐
│                  CONTAINER DATABASE (CDB)                        │
│                    Instance: cdb1                                │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   CDB$ROOT                                 │  │
│  │            (Root Container)                                │  │
│  │                                                            │  │
│  │  - System metadata                                        │  │
│  │  - Common users (SYS, SYSTEM)                             │  │
│  │  - Data dictionary                                         │  │
│  │  - Common objects shared across all PDBs                  │  │
│  │  - Background processes (PMON, SMON, DBWn, LGWR, etc.)    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   PDB$SEED                                 │  │
│  │            (Seed Template PDB)                             │  │
│  │                                                            │  │
│  │  - Template for creating new PDBs                         │  │
│  │  - Always READ ONLY                                        │  │
│  │  - Contains default data dictionary                       │  │
│  │  - Cannot be modified                                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   PDB1 (User PDB)                          │  │
│  │                                                            │  │
│  │  - Application schemas (HEALTHCENTER)                     │  │
│  │  - Application data (tables, indexes, etc.)               │  │
│  │  - Local users                                             │  │
│  │  - Local metadata                                          │  │
│  │  - Can be opened, closed, unplugged independently         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   PDB2 (otro PDB posible)                  │  │
│  │  - Otra aplicación completamente independiente            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. ¿Por Qué Oracle Creó CDB/PDB?

### Problema Histórico: Proliferación de Instancias

Antes de Oracle 12c (lanzado en 2013), las organizaciones enfrentaban serios problemas:

**Escenario típico en una empresa:**
- 50 aplicaciones
- 50 bases de datos Oracle separadas
- 50 instancias Oracle ejecutándose
- 50 conjuntos de procesos background
- 50 SGAs separadas
- Administración multiplicada por 50

**Problemas:**
1. **Desperdicio de recursos:** Cada instancia consume memoria y CPU, incluso si la aplicación está inactiva.
2. **Complejidad administrativa:** Parchear 50 bases de datos requiere 50 ventanas de mantenimiento.
3. **Costos de licenciamiento:** Oracle Database Enterprise Edition se licencia por core. Más instancias = más cores ocupados = más costoso.
4. **Ineficiencia operacional:** Backups, upgrades, tuning multiplicados por N.

---

### Soluciones Pre-12c y Sus Limitaciones

**Opción 1: Schemas separados en una sola DB**
```
Una DB con:
- Schema APP1
- Schema APP2
- Schema APP3
```

**Problema:**
- Sin aislamiento real: Un usuario puede ver metadata de otros schemas
- Sin portabilidad: No puedes mover APP2 a otra DB fácilmente
- Riesgo de contaminación: Un bug en APP1 puede afectar APP2
- Todos comparten la misma configuración de base de datos

**Opción 2: Virtualización a nivel SO**
```
VM1: Oracle instance para APP1
VM2: Oracle instance para APP2
VM3: Oracle instance para APP3
```

**Problema:**
- Cada VM tiene overhead del sistema operativo guest
- Duplicación de binarios de Oracle en cada VM
- No comparte ningún recurso entre instancias
- Administración sigue siendo multiplicada

---

### La Solución: Arquitectura Multitenant

Oracle 12c introdujo multitenant con estos objetivos:

1. **Consolidación real:** Múltiples bases de datos en una sola instancia
2. **Aislamiento completo:** Cada PDB es independiente (no ve a otros PDBs)
3. **Portabilidad extrema:** Desenchufar un PDB y enchufarlo en otro CDB en minutos
4. **Administración centralizada:** Parchar/actualizar el CDB actualiza todos los PDBs
5. **Reducción de costos:** Menos instancias = menos cores ocupados
6. **Eficiencia de recursos:** Compartir SGA, procesos background, cachés

**Beneficio clave para Data Guard:**
- Con arquitectura antigua: Configurar Data Guard para 50 DBs = 50 configuraciones
- Con multitenant: Configurar Data Guard para 1 CDB = automáticamente protege los 50 PDBs

---

### Cambio de Paradigma

**Pre-12c:**
```
Base de Datos = Instancia + Datafiles
Un conjunto completo de procesos y memoria por cada BD
```

**12c en adelante (Multitenant):**
```
CDB = Instancia + N PDBs
Un conjunto de procesos y memoria compartido
Cada PDB es una "base de datos" lógica
```

**Implicación filosófica:**
Una "base de datos" ya no es un objeto físico único, sino un objeto lógico (PDB) que vive dentro de un contenedor físico (CDB).

---

## 3. Container Database (CDB) - Arquitectura Interna

### Definición Técnica

Un **Container Database (CDB)** es una base de datos Oracle que puede contener cero, uno o múltiples PDBs. Es la instancia "física" que tiene:
- Un conjunto de procesos background
- Una System Global Area (SGA) compartida
- Datafiles para el root (CDB$ROOT) y para cada PDB
- Redo logs y control files únicos

---

### Componentes del CDB

#### CDB$ROOT (Root Container)

**Propósito:** Es el "corazón" del CDB. Contiene:

1. **Data Dictionary del CDB:**
   - Metadata sobre el propio CDB
   - Lista de PDBs que contiene
   - Common users (usuarios que existen en todos los PDBs)
   - Configuración global del CDB

2. **Procesos Background Compartidos:**
   - `PMON` (Process Monitor): Limpia procesos fallidos
   - `SMON` (System Monitor): Recuperación de instancia
   - `DBWn` (Database Writer): Escribe dirty buffers a datafiles
   - `LGWR` (Log Writer): Escribe redo logs
   - `CKPT` (Checkpoint): Sincroniza datafiles con control files
   - `ARCn` (Archiver): Crea archive logs
   - **NOTA:** Estos procesos trabajan para **todos los PDBs** simultáneamente

3. **Tablespaces del Sistema:**
   - `SYSTEM`: Metadata del data dictionary
   - `SYSAUX`: Auxiliary system data
   - `TEMP`: Temporary tablespace
   - `UNDO`: Undo tablespace (para rollback y read consistency)

**Estado:**
- Siempre está abierto cuando el CDB está abierto
- No puede cerrarse independientemente

**Conexión:**
```bash
sqlplus sys/password@localhost:1521/cdb1 as sysdba
```

Una vez conectado al CDB$ROOT:
```sql
SQL> SHOW CON_NAME;
CON_NAME
------------------------------
CDB$ROOT

SQL> SHOW CON_ID;
CON_ID
------------------------------
1
```

**Container ID (CON_ID):**
- CDB$ROOT siempre tiene `CON_ID = 1`

---

#### PDB$SEED (Seed PDB)

**Propósito:** Es una plantilla de solo lectura para crear nuevos PDBs.

**Características:**
1. **Siempre READ ONLY:** No se puede modificar
2. **Contiene:**
   - Data dictionary base para un PDB
   - Tablespaces por defecto (SYSTEM, SYSAUX, TEMP, USERS)
   - Metadata necesaria para que un PDB funcione

3. **Creación de PDBs:**
   - Cuando creas un nuevo PDB, Oracle **clona** PDB$SEED
   - Es extremadamente rápido (copy-on-write con ASM, o file copy)

**Estado:**
- Siempre en modo `READ ONLY`
- Abierto automáticamente cuando el CDB se abre

**Container ID:**
- `CON_ID = 2` (siempre)

**Query:**
```sql
SQL> SELECT name, open_mode FROM v$pdbs WHERE name='PDB$SEED';

NAME      OPEN_MODE
--------- ----------
PDB$SEED  READ ONLY
```

---

### Procesos Background del CDB

Aunque los procesos son compartidos, internamente Oracle mantiene **contexto** para saber a qué PDB pertenece cada operación.

**Ejemplo: LGWR (Log Writer)**

```
LGWR escribe cambios al redo log
    ↓
Cambio en PDB1: INSERT INTO table1 ...
    → LGWR sabe que este cambio pertenece a CON_ID=3 (PDB1)
    → Lo escribe al redo log con metadata de CON_ID
    ↓
Cambio en PDB2: UPDATE table2 ...
    → LGWR sabe que este cambio pertenece a CON_ID=4 (PDB2)
    → Lo escribe al redo log con metadata de CON_ID
```

**Durante recovery:**
- Oracle lee el redo log
- Ve el CON_ID en cada entrada
- Aplica el cambio al PDB correcto

---

### Identificación de Containers

Cada container (CDB$ROOT, PDB$SEED, o un PDB) tiene:

1. **CON_ID (Container ID):**
   - Identificador numérico único
   - `CON_ID=0`: Toda la instancia CDB
   - `CON_ID=1`: CDB$ROOT
   - `CON_ID=2`: PDB$SEED
   - `CON_ID>=3`: User PDBs (PDB1, PDB2, ...)

2. **CON_NAME (Container Name):**
   - Nombre alfanumérico del container
   - Ejemplos: `CDB$ROOT`, `PDB$SEED`, `PDB1`, `PDB2`

**Query:**
```sql
SQL> SELECT con_id, name, open_mode FROM v$containers ORDER BY con_id;

    CON_ID NAME          OPEN_MODE
---------- ------------- ----------
         1 CDB$ROOT      READ WRITE
         2 PDB$SEED      READ ONLY
         3 PDB1          READ WRITE
```

---

## 4. Pluggable Database (PDB) - Arquitectura Interna

### Definición Técnica

Una **Pluggable Database (PDB)** es un conjunto autónomo de schemas, objetos y datafiles que aparece a los usuarios como una base de datos independiente, pero físicamente es parte de un CDB.

---

### Características de un PDB

**1. Aislamiento Total:**
- Un usuario en PDB1 **NO PUEDE** ver objetos en PDB2
- Los schemas en PDB1 son completamente independientes de PDB2
- Data dictionary local: Cada PDB tiene su propia vista del diccionario

**Ejemplo:**
```sql
-- Conectado a PDB1
SQL> SELECT username FROM dba_users;

USERNAME
--------
HEALTHCENTER
HR
SYS
SYSTEM
(usuarios locales de PDB1)

-- Conectado a PDB2 (otro PDB)
SQL> SELECT username FROM dba_users;

USERNAME
--------
APP2_SCHEMA
SYS
SYSTEM
(usuarios locales de PDB2 - no ve HEALTHCENTER)
```

---

**2. Portabilidad Completa:**

Puedes "desenchufar" un PDB de un CDB y "enchufarlo" en otro CDB.

**Proceso:**
```sql
-- En CDB1:
ALTER PLUGGABLE DATABASE pdb1 CLOSE;
ALTER PLUGGABLE DATABASE pdb1 UNPLUG INTO '/tmp/pdb1.xml';
DROP PLUGGABLE DATABASE pdb1 KEEP DATAFILES;

-- En CDB2 (otro servidor):
CREATE PLUGGABLE DATABASE pdb1 USING '/tmp/pdb1.xml'
  SOURCE_FILE_NAME_CONVERT=('/u01/cdb1/', '/u02/cdb2/');
ALTER PLUGGABLE DATABASE pdb1 OPEN;
```

**Resultado:** PDB1 ahora vive en CDB2 con todos sus datos intactos.

**Casos de uso:**
- Migrar aplicación de un servidor a otro
- Mover PDB de desarrollo a QA a producción
- Consolidar múltiples servidores en uno

---

**3. Control Independiente de Estado:**

Cada PDB puede abrirse o cerrarse independientemente del CDB y de otros PDBs.

**Estados de un PDB:**

```
MOUNTED
    ↓ (ALTER PLUGGABLE DATABASE pdb1 OPEN)
READ WRITE
    ↓ (ALTER PLUGGABLE DATABASE pdb1 OPEN READ ONLY)
READ ONLY
    ↓ (ALTER PLUGGABLE DATABASE pdb1 CLOSE)
MOUNTED
```

**Ejemplo:**
```sql
-- PDB1 abierto en READ WRITE (usuarios pueden leer y escribir)
SQL> ALTER PLUGGABLE DATABASE pdb1 OPEN;

-- PDB2 abierto en READ ONLY (solo lectura, útil para reporting)
SQL> ALTER PLUGGABLE DATABASE pdb2 OPEN READ ONLY;

-- PDB3 cerrado (nadie puede conectarse)
SQL> ALTER PLUGGABLE DATABASE pdb3 CLOSE;
```

**Query de estado:**
```sql
SQL> SELECT name, open_mode, restricted FROM v$pdbs;

NAME  OPEN_MODE  RESTRICTED
----- ---------- ----------
PDB1  READ WRITE NO
PDB2  READ ONLY  NO
PDB3  MOUNTED    NO
```

---

**4. Resource Management:**

Puedes limitar los recursos que cada PDB puede consumir usando **Resource Manager**.

**Ejemplo:**
```sql
-- PDB1 puede usar máximo 50% de la CPU del CDB
-- PDB2 puede usar máximo 30% de la CPU del CDB
-- PDB3 puede usar máximo 20% de la CPU del CDB

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN(
    plan => 'cdb_plan',
    comment => 'CDB Resource Plan'
  );

  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN_DIRECTIVE(
    plan => 'cdb_plan',
    pluggable_database => 'pdb1',
    shares => 5,
    utilization_limit => 50
  );

  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

**Ventaja:** Evita que un PDB acapare todos los recursos y afecte a otros PDBs.

---

### Datafiles de un PDB

Cada PDB tiene sus propios datafiles, separados físicamente del CDB$ROOT.

**Estructura:**
```
/u01/oradata/cdb1/
├── system01.dbf          # CDB$ROOT SYSTEM tablespace
├── sysaux01.dbf          # CDB$ROOT SYSAUX tablespace
├── undotbs01.dbf         # CDB$ROOT UNDO tablespace (compartido)
├── users01.dbf           # CDB$ROOT USERS tablespace
├── temp01.dbf            # CDB$ROOT TEMP tablespace
│
├── pdbseed/
│   ├── system01.dbf      # PDB$SEED SYSTEM
│   ├── sysaux01.dbf      # PDB$SEED SYSAUX
│   └── temp01.dbf        # PDB$SEED TEMP
│
└── pdb1/
    ├── system01.dbf      # PDB1 SYSTEM tablespace
    ├── sysaux01.dbf      # PDB1 SYSAUX tablespace
    ├── temp01.dbf        # PDB1 TEMP tablespace
    └── users01.dbf       # PDB1 USERS tablespace (datos de aplicación)
```

**NOTA:**
- Cada PDB tiene su propio SYSTEM y SYSAUX tablespace
- El UNDO tablespace es **compartido** entre todos los PDBs
- Cada PDB puede tener su propio TEMP tablespace (o compartido)

---

### Local vs Common Objects

**Common Objects:**
- Existen en CDB$ROOT
- Visibles en todos los PDBs
- Ejemplos:
  - Common users: `C##ADMIN` (usuarios que empiezan con `C##`)
  - Common roles: `C##DBA_ROLE`

**Local Objects:**
- Existen solo dentro de un PDB específico
- No visibles en otros PDBs
- Ejemplos:
  - Local users: `HEALTHCENTER`, `HR`, `SALES`
  - Local tables, procedures, packages

**Ejemplo:**
```sql
-- Crear un common user (debe hacerse en CDB$ROOT)
CREATE USER c##global_admin IDENTIFIED BY password CONTAINER=ALL;
-- Este usuario puede conectarse a cualquier PDB

-- Crear un local user (debe hacerse dentro del PDB)
ALTER SESSION SET CONTAINER=pdb1;
CREATE USER healthcenter IDENTIFIED BY password CONTAINER=CURRENT;
-- Este usuario solo puede conectarse a PDB1
```

---

## 5. Componentes del CDB

### Vista Lógica Completa

```
┌─────────────────────────────────────────────────────────────────┐
│                      INSTANCE: cdb1                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   MEMORY (SGA)                              │ │
│  │                                                             │ │
│  │  • Shared Pool                   (Compartido por todos)    │ │
│  │  • Database Buffer Cache          (Compartido por todos)    │ │
│  │  • Redo Log Buffer                (Compartido por todos)    │ │
│  │  • Large Pool                     (Compartido por todos)    │ │
│  │  • Java Pool                      (Compartido por todos)    │ │
│  │                                                             │ │
│  │  NOTA: Internamente Oracle trackea qué bloques pertenecen │ │
│  │        a qué PDB usando CON_ID                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              BACKGROUND PROCESSES                           │ │
│  │                                                             │ │
│  │  • PMON, SMON, RECO                (Sistema)               │ │
│  │  • DBW0-DBWn                       (Escritura a disco)     │ │
│  │  • LGWR                            (Redo logs)             │ │
│  │  • CKPT                            (Checkpoints)           │ │
│  │  • ARCn                            (Archive logs)          │ │
│  │                                                             │ │
│  │  NOTA: Estos procesos trabajan para CDB$ROOT y todos PDBs │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   STORAGE                                   │ │
│  │                                                             │ │
│  │  • Control Files (3 copias)           (CDB-wide)           │ │
│  │  • Redo Logs (3 groups)                (CDB-wide)           │ │
│  │  • Datafiles:                                              │ │
│  │    ├─ CDB$ROOT datafiles                                   │ │
│  │    ├─ PDB$SEED datafiles                                   │ │
│  │    └─ PDB1, PDB2, ... datafiles                            │ │
│  │  • Archive Logs                        (CDB-wide)           │ │
│  │                                                             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   CONTAINERS                                │ │
│  │                                                             │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  CDB$ROOT (CON_ID=1)                                 │  │ │
│  │  │  - Common users                                       │  │ │
│  │  │  - CDB data dictionary                                │  │ │
│  │  │  - System metadata                                    │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                             │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  PDB$SEED (CON_ID=2) - READ ONLY                     │  │ │
│  │  │  - Template for creating PDBs                        │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                             │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │  PDB1 (CON_ID=3) - READ WRITE                        │  │ │
│  │  │  - HEALTHCENTER schema                               │  │ │
│  │  │  - Application data                                   │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                             │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Recursos Compartidos vs Aislados

### Recursos Compartidos (Shared)

**Estos recursos son únicos por CDB y compartidos entre todos los PDBs:**

1. **System Global Area (SGA):**
   - Shared Pool
   - Database Buffer Cache
   - Redo Log Buffer
   - Large Pool
   - Java Pool

2. **Background Processes:**
   - PMON, SMON, RECO
   - DBWn (Database Writers)
   - LGWR (Log Writer)
   - CKPT (Checkpoint)
   - ARCn (Archiver)

3. **Redo Logs:**
   - Online redo logs (3 groups)
   - Archive logs

4. **Control Files:**
   - 3 copias de control files

5. **UNDO Tablespace:**
   - Un solo UNDO compartido por todos los PDBs
   - (Opcional: Puede haber UNDO local por PDB desde 12.2)

**Ventaja:**
- Reducción masiva de overhead de recursos
- Ejemplo: 10 PDBs comparten un solo LGWR en lugar de tener 10 LGWR separados

---

### Recursos Aislados (Isolated)

**Cada PDB tiene sus propios:**

1. **Datafiles:**
   - SYSTEM tablespace
   - SYSAUX tablespace
   - TEMP tablespace
   - USER tablespaces (donde viven los datos de aplicación)

2. **Metadata Local:**
   - Data dictionary local (vistas DBA_*, ALL_*, USER_*)
   - Schemas locales
   - Usuarios locales
   - Objetos locales (tablas, índices, procedimientos)

3. **Configuración:**
   - Parámetros de inicialización locales (algunos pueden sobreescribirse por PDB)
   - Servicios de red (cada PDB puede tener su propio servicio TNS)

---

### Ejemplo: Buffer Cache Compartido pero Trackeable

Aunque el Database Buffer Cache es compartido, Oracle internamente sabe qué bloques pertenecen a qué PDB:

```sql
-- Ver qué PDB ocupa cuánto espacio en buffer cache
SELECT
  con_id,
  name,
  ROUND(SUM(blocks * 8192) / 1024 / 1024, 2) AS mb_in_cache
FROM v$bh
JOIN v$containers USING (con_id)
GROUP BY con_id, name
ORDER BY con_id;

    CON_ID NAME          MB_IN_CACHE
---------- ------------- -----------
         1 CDB$ROOT           450.50
         2 PDB$SEED            12.75
         3 PDB1               980.25
```

**Interpretación:**
- PDB1 está usando 980 MB del buffer cache compartido
- CDB$ROOT usa 450 MB
- El buffer cache total puede ser 2 GB, compartido entre todos

---

## 7. Arquitectura de Memoria (SGA/PGA)

### System Global Area (SGA)

La SGA es **única y compartida** para todo el CDB.

**Componentes:**

```
┌─────────────────────────────────────────────────────────────────┐
│                  System Global Area (SGA)                        │
│                         (Ejemplo: 4 GB)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │       Shared Pool (1.5 GB)                                  │ │
│  │                                                             │ │
│  │  • Library Cache:                                          │ │
│  │    - SQL statements parseados (de todos los PDBs)         │ │
│  │    - PL/SQL code (procedures, packages)                   │ │
│  │    - CON_ID asociado a cada objeto                        │ │
│  │                                                             │ │
│  │  • Data Dictionary Cache:                                  │ │
│  │    - Metadata de CDB$ROOT                                  │ │
│  │    - Metadata de cada PDB (compartimentado por CON_ID)    │ │
│  │                                                             │ │
│  │  • Result Cache:                                           │ │
│  │    - Resultados cacheados de queries                       │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │       Database Buffer Cache (2 GB)                          │ │
│  │                                                             │ │
│  │  • Data blocks de todos los datafiles                      │ │
│  │  • Bloques de CDB$ROOT datafiles                           │ │
│  │  • Bloques de PDB1 datafiles                               │ │
│  │  • Bloques de PDB2 datafiles                               │ │
│  │  • Cada bloque tiene metadata: CON_ID, file#, block#      │ │
│  │                                                             │ │
│  │  LRU (Least Recently Used) algorithm aplica globalmente    │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │       Redo Log Buffer (16 MB)                               │ │
│  │                                                             │ │
│  │  • Cambios (redo entries) de todos los PDBs                │ │
│  │  • Cada redo entry incluye CON_ID                          │ │
│  │  • LGWR escribe a online redo logs                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │       Large Pool (256 MB)                                   │ │
│  │  • RMAN operations                                          │ │
│  │  • Parallel execution messages                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │       Java Pool (128 MB)                                    │ │
│  │  • Java stored procedures                                   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Cómo Oracle mantiene aislamiento en SGA compartida:**

Cada objeto en memoria tiene asociado su `CON_ID`:
- Bloque de datos de PDB1: `CON_ID=3`
- SQL parseado en PDB2: `CON_ID=4`
- Dictionary cache de CDB$ROOT: `CON_ID=1`

Cuando un usuario se conecta a PDB1, Oracle filtra la SGA para mostrar solo objetos con `CON_ID=3` (más el CDB$ROOT `CON_ID=1` para common objects).

---

### Program Global Area (PGA)

La PGA es **privada** por cada sesión de usuario.

**Estructura:**
```
Usuario conectado a PDB1:
    ↓
Crea una sesión
    ↓
Asigna PGA privado (ej: 10 MB)
    ├─ SQL Work Area (para sorts, joins)
    ├─ Session Memory (variables, cursors)
    └─ Private SQL Area (bind variables, runtime info)
```

**NOTA:** Cada sesión tiene su propio PGA independientemente del PDB al que esté conectado.

**Configuración:**
```sql
-- Ver configuración de PGA
SQL> SHOW PARAMETER pga_aggregate_target;

NAME                      TYPE    VALUE
------------------------- ------- -------
pga_aggregate_target      big int 1G

-- Este límite aplica a TODAS las sesiones de TODOS los PDBs combinadas
```

---

### Queries de Memoria por PDB

**Ver uso de SGA por PDB:**
```sql
SELECT
  con_id,
  ROUND(SUM(bytes)/1024/1024/1024, 2) AS gb_used
FROM v$sgastat
WHERE con_id > 0
GROUP BY con_id
ORDER BY con_id;
```

**Ver sesiones y PGA por PDB:**
```sql
SELECT
  s.con_id,
  c.name AS pdb_name,
  COUNT(*) AS num_sessions,
  ROUND(SUM(p.pga_used_mem)/1024/1024, 2) AS pga_mb
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
JOIN v$containers c ON s.con_id = c.con_id
WHERE s.type = 'USER'
GROUP BY s.con_id, c.name
ORDER BY s.con_id;
```

---

## 8. Arquitectura de Almacenamiento

### Control Files

**Un solo conjunto de control files** para todo el CDB.

Contiene:
- Información de la estructura del CDB
- Lista de datafiles (de CDB$ROOT y todos los PDBs)
- Lista de redo logs
- Checkpoint information
- Backup information (RMAN)

**Ubicación (en este proyecto):**
```
/u01/oradata/cdb1/control01.ctl
/u01/app/oracle/fast_recovery_area/cdb1/control02.ctl
/u02/fast_recovery_area/cdb1/control03.ctl
```

**Query:**
```sql
SQL> SELECT name FROM v$controlfile;

NAME
----
/u01/oradata/cdb1/control01.ctl
/u01/app/oracle/fast_recovery_area/cdb1/control02.ctl
/u02/fast_recovery_area/cdb1/control03.ctl
```

---

### Online Redo Logs

**Un solo conjunto de redo logs** para todo el CDB.

Contiene:
- Todos los cambios de CDB$ROOT
- Todos los cambios de PDB1, PDB2, ...
- Cada redo entry tiene `CON_ID` identificando el PDB

**Estructura:**
```
Group 1:
  /u01/oradata/cdb1/redo01.log (50 MB)
Group 2:
  /u01/oradata/cdb1/redo02.log (50 MB)
Group 3:
  /u01/oradata/cdb1/redo03.log (50 MB)
```

**Durante log switch:**
- Oracle cambia de Group 1 a Group 2
- ARCn archiva Group 1 → `/u01/oradata/cdb1/arch/1_145.arc`
- Archive log contiene cambios de **todos los PDBs** en ese periodo

**Query:**
```sql
SQL> SELECT group#, status, bytes/1024/1024 AS mb FROM v$log;

    GROUP# STATUS      MB
---------- ------- -----
         1 CURRENT    50
         2 INACTIVE   50
         3 INACTIVE   50
```

---

### Datafiles por Container

**CDB$ROOT:**
```
/u01/oradata/cdb1/
├── system01.dbf      (800 MB) - SYSTEM tablespace
├── sysaux01.dbf      (600 MB) - SYSAUX tablespace
├── undotbs01.dbf     (200 MB) - UNDO tablespace (compartido)
├── users01.dbf       (5 MB)   - USERS tablespace
└── temp01.dbf        (100 MB) - TEMP tablespace
```

**PDB$SEED:**
```
/u01/oradata/cdb1/pdbseed/
├── system01.dbf      (300 MB)
├── sysaux01.dbf      (400 MB)
└── temp01.dbf        (50 MB)
```

**PDB1:**
```
/u01/oradata/cdb1/pdb1/
├── system01.dbf      (300 MB)
├── sysaux01.dbf      (400 MB)
├── temp01.dbf        (50 MB)
└── users01.dbf       (100 MB) - Datos de aplicación HEALTHCENTER
```

**Query:**
```sql
-- Ver datafiles por container
SELECT
  c.name AS pdb_name,
  d.name AS datafile,
  d.bytes/1024/1024 AS mb
FROM v$datafile d
JOIN v$containers c ON d.con_id = c.con_id
ORDER BY c.con_id, d.name;
```

---

## 9. Conexiones: CDB vs PDB

### Conectarse al CDB$ROOT

**Desde fuera de la VM (Windows):**
```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba
```

**Desde dentro de la VM:**
```bash
sqlplus / as sysdba
```

**Verificar que estás en CDB$ROOT:**
```sql
SQL> SHOW CON_NAME;
CON_NAME
------------------------------
CDB$ROOT

SQL> SHOW CON_ID;
CON_ID
------------------------------
1
```

---

### Conectarse a un PDB

**Método 1: Conexión directa con service name**

```bash
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1
```

**Método 2: Conectar al CDB y cambiar de container**

```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

SQL> ALTER SESSION SET CONTAINER=pdb1;
Session altered.

SQL> SHOW CON_NAME;
CON_NAME
------------------------------
PDB1
```

**Método 3: Usar CONNECT**

```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

SQL> CONNECT HEALTHCENTER/HCApp2025!@localhost:1521/pdb1
Connected.

SQL> SHOW CON_NAME;
CON_NAME
------------------------------
PDB1
```

---

### Service Names

Cada PDB puede tener su propio service name para conexiones.

**Crear un service para PDB1:**
```sql
-- Conectado a PDB1
ALTER SESSION SET CONTAINER=pdb1;

BEGIN
  DBMS_SERVICE.CREATE_SERVICE(
    service_name => 'healthcenter_service',
    network_name => 'healthcenter_service'
  );
  DBMS_SERVICE.START_SERVICE(
    service_name => 'healthcenter_service'
  );
END;
/
```

**Conectar usando el service:**
```bash
sqlplus HEALTHCENTER/password@localhost:1521/healthcenter_service
```

**Ver services:**
```sql
SQL> SELECT name, pdb FROM v$services WHERE pdb IS NOT NULL;

NAME                   PDB
---------------------- ------
pdb1                   PDB1
healthcenter_service   PDB1
```

---

## 10. Operaciones sobre PDBs

### Abrir y Cerrar PDBs

**Abrir un PDB:**
```sql
ALTER PLUGGABLE DATABASE pdb1 OPEN;
```

**Abrir en modo READ ONLY:**
```sql
ALTER PLUGGABLE DATABASE pdb1 OPEN READ ONLY;
```

**Cerrar un PDB:**
```sql
ALTER PLUGGABLE DATABASE pdb1 CLOSE;
```

**Abrir todos los PDBs:**
```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
```

---

### Crear un Nuevo PDB

**Crear desde PDB$SEED:**
```sql
CREATE PLUGGABLE DATABASE pdb2
  ADMIN USER pdb2admin IDENTIFIED BY password
  FILE_NAME_CONVERT=(
    '/u01/oradata/cdb1/pdbseed/',
    '/u01/oradata/cdb1/pdb2/'
  );

ALTER PLUGGABLE DATABASE pdb2 OPEN;
```

**Verificar:**
```sql
SQL> SELECT name, open_mode FROM v$pdbs;

NAME      OPEN_MODE
--------- ----------
PDB$SEED  READ ONLY
PDB1      READ WRITE
PDB2      READ WRITE
```

---

### Clonar un PDB Existente

**Clonar PDB1 a PDB3:**
```sql
-- PDB1 debe estar en READ ONLY
ALTER PLUGGABLE DATABASE pdb1 CLOSE;
ALTER PLUGGABLE DATABASE pdb1 OPEN READ ONLY;

-- Crear el clon
CREATE PLUGGABLE DATABASE pdb3 FROM pdb1
  FILE_NAME_CONVERT=(
    '/u01/oradata/cdb1/pdb1/',
    '/u01/oradata/cdb1/pdb3/'
  );

ALTER PLUGGABLE DATABASE pdb3 OPEN;

-- Reabrir PDB1 en READ WRITE
ALTER PLUGGABLE DATABASE pdb1 CLOSE;
ALTER PLUGGABLE DATABASE pdb1 OPEN;
```

**Resultado:** PDB3 es una copia exacta de PDB1 con todos los datos.

---

### Desenchufar (Unplug) un PDB

**Escenario:** Mover PDB1 de este CDB a otro CDB.

**Paso 1: Cerrar el PDB**
```sql
ALTER PLUGGABLE DATABASE pdb1 CLOSE;
```

**Paso 2: Desenchufar y generar archivo XML de metadatos**
```sql
ALTER PLUGGABLE DATABASE pdb1 UNPLUG INTO '/tmp/pdb1_metadata.xml';
```

**Paso 3: Eliminar el PDB del CDB (manteniendo datafiles)**
```sql
DROP PLUGGABLE DATABASE pdb1 KEEP DATAFILES;
```

**Resultado:**
- PDB1 ya no está en este CDB
- Los datafiles `/u01/oradata/cdb1/pdb1/` todavía existen
- El archivo XML describe la estructura del PDB

---

### Enchufar (Plug In) un PDB

**Escenario:** Agregar PDB1 a otro CDB usando el XML.

**Paso 1: Verificar compatibilidad**
```sql
-- En el nuevo CDB
SET SERVEROUTPUT ON
DECLARE
  compatible BOOLEAN;
BEGIN
  compatible := DBMS_PDB.CHECK_PLUG_COMPATIBILITY(
    pdb_descr_file => '/tmp/pdb1_metadata.xml'
  );

  IF compatible THEN
    DBMS_OUTPUT.PUT_LINE('PDB is compatible!');
  ELSE
    DBMS_OUTPUT.PUT_LINE('PDB is NOT compatible. Check PDB_PLUG_IN_VIOLATIONS.');
  END IF;
END;
/
```

**Paso 2: Enchufar el PDB**
```sql
CREATE PLUGGABLE DATABASE pdb1 USING '/tmp/pdb1_metadata.xml'
  SOURCE_FILE_NAME_CONVERT=(
    '/u01/oradata/old_cdb/pdb1/',
    '/u01/oradata/new_cdb/pdb1/'
  )
  COPY;  -- o NOCOPY si los datafiles ya están en la ubicación correcta
```

**Paso 3: Ejecutar script de migración**
```sql
ALTER SESSION SET CONTAINER=pdb1;
@$ORACLE_HOME/rdbms/admin/noncdb_to_pdb.sql
```

**Paso 4: Abrir el PDB**
```sql
ALTER PLUGGABLE DATABASE pdb1 OPEN;
```

**Resultado:** PDB1 ahora vive en el nuevo CDB completamente funcional.

---

### Eliminar un PDB

**Eliminar y borrar datafiles:**
```sql
ALTER PLUGGABLE DATABASE pdb2 CLOSE;
DROP PLUGGABLE DATABASE pdb2 INCLUDING DATAFILES;
```

**Eliminar pero mantener datafiles (para backup):**
```sql
DROP PLUGGABLE DATABASE pdb2 KEEP DATAFILES;
```

---

## 11. CDB/PDB en Este Proyecto

### Configuración Actual

**Primary:**
```
CDB: cdb1
├── CDB$ROOT (CON_ID=1)
│   - SYS, SYSTEM
│   - Metadata del CDB
│
├── PDB$SEED (CON_ID=2)
│   - Plantilla (READ ONLY)
│
└── PDB1 (CON_ID=3)
    - HEALTHCENTER schema
    - Tablas: HC_User, HC_Payroll, HC_MonthScale, etc.
    - Packages: PKG_UTILITIES, PKG_LOGBOOK, PKG_EMAILS
    - Procedures: generate_month_scale, generate_payroll, etc.
```

**Standby:**
```
CDB: cdb1_stby
├── CDB$ROOT (réplica del primary CDB$ROOT)
├── PDB$SEED (réplica)
└── PDB1 (réplica exacta del primary PDB1)
    - Todos los datos replicados
    - READ ONLY o MOUNTED (dependiendo del modo de Data Guard)
```

---

### Por Qué Un Solo PDB

En este proyecto educativo, usamos un solo PDB (pdb1) porque:

1. **Simplicidad:** Una aplicación = un PDB
2. **Enfoque:** El objetivo es aprender Data Guard, no multitenant avanzado
3. **Recursos:** Una VM con 4GB RAM y un PDB es suficiente

**Pero la arquitectura permite:**
- Agregar PDB2 para otra aplicación (ej: sistema de inventario)
- Agregar PDB3 para desarrollo/QA
- Todos automáticamente protegidos por Data Guard

---

### Cómo Agregar Otro PDB (Ejemplo)

**Escenario:** Agregar un segundo sistema (Inventario) al mismo CDB.

```sql
-- En el primary
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

-- Crear PDB2
CREATE PLUGGABLE DATABASE pdb2
  ADMIN USER pdb2admin IDENTIFIED BY password
  FILE_NAME_CONVERT=(
    '/u01/oradata/cdb1/pdbseed/',
    '/u01/oradata/cdb1/pdb2/'
  );

ALTER PLUGGABLE DATABASE pdb2 OPEN;

-- Crear schema de aplicación
ALTER SESSION SET CONTAINER=pdb2;

CREATE USER inventory IDENTIFIED BY password;
GRANT CONNECT, RESOURCE, DBA TO inventory;

-- Desplegar esquema de inventario
@/path/to/inventory_schema.sql
```

**Resultado:**
- PDB2 creado en primary
- Data Guard automáticamente replica PDB2 al standby
- Ambas aplicaciones (healthcare en PDB1, inventory en PDB2) protegidas

---

### Conexión desde Aplicación

**Aplicación Healthcare conecta a PDB1:**
```java
String url = "jdbc:oracle:thin:@localhost:1521/pdb1";
String user = "HEALTHCENTER";
String password = "HCApp2025!";

Connection conn = DriverManager.getConnection(url, user, password);
```

**Aplicación Inventario conecta a PDB2:**
```java
String url = "jdbc:oracle:thin:@localhost:1521/pdb2";
String user = "inventory";
String password = "password";

Connection conn = DriverManager.getConnection(url, user, password);
```

**NOTA:** Las aplicaciones no se dan cuenta de que están en el mismo CDB. Ven solo su PDB.

---

## 12. Casos de Uso y Ventajas

### Caso de Uso 1: Consolidación de Bases de Datos

**Problema:**
Una empresa tiene 20 aplicaciones, cada una con su propia base de datos Oracle en servidores separados.

**Solución con Multitenant:**
- Crear 1 CDB en un servidor potente
- Crear 20 PDBs (uno por aplicación)
- Resultado: 20 bases de datos en una sola instancia

**Beneficios:**
- Reducción de 20 servidores a 1
- Reducción de costos de hardware
- Reducción de licencias Oracle (menos cores ocupados)
- Simplificación de administración

---

### Caso de Uso 2: Desarrollo, QA y Producción

**Problema:**
Necesitas entornos separados para desarrollo, QA y producción.

**Solución:**
```
CDB1 (Producción):
├── PDB1_PROD (aplicación en producción)

CDB2 (No Producción):
├── PDB1_DEV (desarrollo)
├── PDB1_QA (QA)
└── PDB1_STAGING (staging)
```

**Flujo:**
1. Desarrollas en PDB1_DEV
2. Cuando está listo, **clonas** PDB1_DEV → PDB1_QA
   ```sql
   CREATE PLUGGABLE DATABASE pdb1_qa FROM pdb1_dev;
   ```
3. QA prueba en PDB1_QA
4. Cuando QA aprueba, **desenchufas** PDB1_QA y lo **enchufas** en CDB1 como producción
   ```sql
   -- En CDB2
   ALTER PLUGGABLE DATABASE pdb1_qa CLOSE;
   ALTER PLUGGABLE DATABASE pdb1_qa UNPLUG INTO '/tmp/pdb1_qa.xml';

   -- En CDB1
   CREATE PLUGGABLE DATABASE pdb1_prod USING '/tmp/pdb1_qa.xml' ...;
   ALTER PLUGGABLE DATABASE pdb1_prod OPEN;
   ```

**Beneficio:** Migración de entornos en minutos (no horas de exportación/importación).

---

### Caso de Uso 3: Multi-Tenancy SaaS

**Problema:**
Provees una aplicación SaaS a 100 clientes. Cada cliente necesita sus datos aislados.

**Solución:**
```
CDB1:
├── PDB_Cliente1
├── PDB_Cliente2
├── PDB_Cliente3
...
└── PDB_Cliente100
```

**Ventajas:**
- **Aislamiento total:** Cliente1 no puede ver datos de Cliente2
- **Personalización:** Cada cliente puede tener su propia versión del schema
- **Billing:** Puedes medir uso de recursos por PDB y cobrar en consecuencia
- **Movilidad:** Si un cliente crece mucho, puedes mover su PDB a un CDB dedicado

---

### Caso de Uso 4: Patching y Upgrades

**Problema:**
Necesitas actualizar Oracle de 19c a 21c para 50 bases de datos.

**Sin Multitenant:**
- 50 upgrades separados
- 50 ventanas de mantenimiento
- Alto riesgo de inconsistencias

**Con Multitenant:**
1. Crea un nuevo CDB con Oracle 21c
2. **Desenchufa** cada PDB del CDB viejo (19c)
3. **Enchufa** cada PDB en el CDB nuevo (21c)
4. Ejecuta scripts de migración

**Beneficio:**
- Un solo upgrade del CDB
- Todos los PDBs automáticamente migrados
- Rollback fácil (desenchufar y regresar al CDB viejo)

---

### Caso de Uso 5: Clonación Rápida para Testing

**Problema:**
Necesitas crear una copia de producción para debugging.

**Sin Multitenant:**
```bash
# Exportar (horas)
expdp ... FULL=Y FILE=prod_dump.dmp

# Importar en nueva DB (horas)
impdp ... FULL=Y FILE=prod_dump.dmp
```

**Con Multitenant:**
```sql
-- Clonar PDB de producción en segundos/minutos
CREATE PLUGGABLE DATABASE pdb1_debug FROM pdb1_prod;
ALTER PLUGGABLE DATABASE pdb1_debug OPEN;
```

**Resultado:** Clon completo de producción en minutos (copy-on-write con snapshot).

---

## 13. Limitaciones y Consideraciones

### Limitaciones Técnicas

1. **No todos los features funcionan igual:**
   - Algunas características legacy requieren workarounds en PDBs
   - Ejemplo: AWR (Automatic Workload Repository) genera reportes por CDB o por PDB

2. **UNDO Compartido:**
   - Por defecto, todos los PDBs comparten el mismo UNDO tablespace
   - Un PDB con muchas transacciones largas puede afectar a otros
   - Solución: Local UNDO (desde 12.2)

3. **Compatibilidad:**
   - No puedes tener PDBs de diferentes versiones en el mismo CDB
   - Ejemplo: No puedes enchufar un PDB 19c en un CDB 21c (pero sí al revés con upgrade)

---

### Consideraciones de Rendimiento

**Resource Contention:**
- Todos los PDBs compiten por los mismos recursos (CPU, SGA, I/O)
- Un PDB con carga pesada puede afectar a otros
- **Solución:** Usar Resource Manager para limitar recursos por PDB

**Ejemplo de Resource Manager:**
```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

  -- Plan para distribuir CPU
  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN(
    plan => 'balanced_plan',
    comment => 'Balanced CPU distribution'
  );

  -- PDB1 (producción) obtiene 60% CPU
  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN_DIRECTIVE(
    plan => 'balanced_plan',
    pluggable_database => 'pdb1',
    shares => 6,
    utilization_limit => 60
  );

  -- PDB2 (dev) obtiene 30% CPU
  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN_DIRECTIVE(
    plan => 'balanced_plan',
    pluggable_database => 'pdb2',
    shares => 3,
    utilization_limit => 30
  );

  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/

-- Activar el plan
ALTER SYSTEM SET RESOURCE_MANAGER_PLAN='balanced_plan';
```

---

### Consideraciones de Licenciamiento

**Oracle Database Enterprise Edition:**
- **Multitenant es gratuito** con hasta **3 PDBs** en EE
- Más de 3 PDBs requiere **Multitenant Option** (licencia adicional costosa)

**En este proyecto:**
- Usamos 1 PDB (pdb1)
- No necesitamos licencia adicional

**Recomendación:**
- En producción comercial, verifica licensing antes de crear muchos PDBs

---

### Consideraciones de Data Guard

**Replicación:**
- Data Guard replica el **CDB completo**
- No puedes replicar solo un PDB (standby replica todos o ninguno)

**Ventaja:**
- Configurar Data Guard una vez protege todos los PDBs

**Desventaja:**
- No puedes tener DR selectivo (replicar PDB1 pero no PDB2)

---

## 14. Comandos y Queries Relevantes

### Información del CDB

**Ver si la base de datos es un CDB:**
```sql
SQL> SELECT name, cdb, con_id FROM v$database;

NAME      CDB CON_ID
--------- --- ------
CDB1      YES      0
```

**Ver containers:**
```sql
SQL> SELECT con_id, name, open_mode, restricted FROM v$containers ORDER BY con_id;

    CON_ID NAME          OPEN_MODE  RESTRICTED
---------- ------------- ---------- ----------
         1 CDB$ROOT      READ WRITE NO
         2 PDB$SEED      READ ONLY  NO
         3 PDB1          READ WRITE NO
```

**Ver a qué container estás conectado:**
```sql
SQL> SHOW CON_NAME;
CON_NAME
------------------------------
CDB$ROOT

SQL> SHOW CON_ID;
CON_ID
------------------------------
1
```

---

### Gestión de PDBs

**Ver todos los PDBs:**
```sql
SQL> SELECT name, open_mode, restricted, open_time FROM v$pdbs;

NAME      OPEN_MODE  RESTRICTED OPEN_TIME
--------- ---------- ---------- -------------------
PDB$SEED  READ ONLY  NO         2025-11-04 10:00:00
PDB1      READ WRITE NO         2025-11-04 10:05:00
```

**Abrir/cerrar PDBs:**
```sql
-- Abrir todos
ALTER PLUGGABLE DATABASE ALL OPEN;

-- Abrir uno específico
ALTER PLUGGABLE DATABASE pdb1 OPEN;

-- Abrir en READ ONLY
ALTER PLUGGABLE DATABASE pdb1 OPEN READ ONLY;

-- Cerrar
ALTER PLUGGABLE DATABASE pdb1 CLOSE IMMEDIATE;

-- Cerrar todos excepto PDB$SEED
ALTER PLUGGABLE DATABASE ALL CLOSE;
```

**Ver historial de PDBs:**
```sql
SQL> SELECT con_id, name, dbid, con_uid, guid FROM v$pdbs;
```

---

### Información de Recursos

**Ver datafiles por PDB:**
```sql
SELECT
  c.name AS pdb_name,
  t.name AS tablespace,
  d.name AS datafile,
  ROUND(d.bytes/1024/1024/1024, 2) AS gb
FROM v$datafile d
JOIN v$tablespace t ON d.ts# = t.ts#
JOIN v$containers c ON d.con_id = c.con_id
ORDER BY c.name, t.name;
```

**Ver tamaño total por PDB:**
```sql
SELECT
  c.name AS pdb_name,
  ROUND(SUM(d.bytes)/1024/1024/1024, 2) AS total_gb
FROM v$datafile d
JOIN v$containers c ON d.con_id = c.con_id
GROUP BY c.name
ORDER BY c.name;
```

**Ver sesiones por PDB:**
```sql
SELECT
  c.name AS pdb_name,
  s.username,
  COUNT(*) AS num_sessions
FROM v$session s
JOIN v$containers c ON s.con_id = c.con_id
WHERE s.type = 'USER'
GROUP BY c.name, s.username
ORDER BY c.name;
```

---

### Administración de Usuarios

**Crear common user (en CDB$ROOT):**
```sql
-- Conectado a CDB$ROOT
CREATE USER c##admin IDENTIFIED BY password CONTAINER=ALL;
GRANT SYSDBA TO c##admin CONTAINER=ALL;
```

**Crear local user (en un PDB):**
```sql
-- Conectado a PDB1
ALTER SESSION SET CONTAINER=pdb1;
CREATE USER app_user IDENTIFIED BY password CONTAINER=CURRENT;
GRANT CONNECT, RESOURCE TO app_user;
```

**Ver usuarios por container:**
```sql
SELECT
  c.name AS pdb_name,
  u.username,
  u.common,
  u.account_status
FROM cdb_users u
JOIN v$containers c ON u.con_id = c.con_id
WHERE u.username NOT IN ('SYS', 'SYSTEM', 'OUTLN', 'XS$NULL')
ORDER BY c.name, u.username;
```

---

### Operaciones Avanzadas

**Crear PDB desde seed:**
```sql
CREATE PLUGGABLE DATABASE pdb2
  ADMIN USER pdb2admin IDENTIFIED BY password
  FILE_NAME_CONVERT=(
    '/u01/oradata/cdb1/pdbseed/',
    '/u01/oradata/cdb1/pdb2/'
  );
```

**Clonar PDB existente:**
```sql
CREATE PLUGGABLE DATABASE pdb3 FROM pdb1;
```

**Desenchufar PDB:**
```sql
ALTER PLUGGABLE DATABASE pdb2 CLOSE;
ALTER PLUGGABLE DATABASE pdb2 UNPLUG INTO '/tmp/pdb2.xml';
DROP PLUGGABLE DATABASE pdb2 KEEP DATAFILES;
```

**Enchufar PDB:**
```sql
CREATE PLUGGABLE DATABASE pdb2 USING '/tmp/pdb2.xml'
  SOURCE_FILE_NAME_CONVERT=('/old/path/', '/new/path/')
  NOCOPY;
```

---

## 15. Mejores Prácticas

### 1. Planificación de Capacidad

**Antes de crear múltiples PDBs:**
- Estimar recursos por PDB (CPU, memoria, disco)
- Sumar todos los PDBs y verificar que el CDB puede soportarlo
- Ejemplo: 10 PDBs × 2GB SGA cada uno = 20GB SGA mínimo

**Monitoreo continuo:**
```sql
-- Ver uso de recursos por PDB
SELECT
  c.name,
  ROUND(SUM(s.value)/1024/1024, 2) AS mb_used
FROM v$sesstat s
JOIN v$session se ON s.sid = se.sid
JOIN v$containers c ON se.con_id = c.con_id
WHERE s.statistic# IN (SELECT statistic# FROM v$statname WHERE name LIKE '%memory%')
GROUP BY c.name;
```

---

### 2. Usar Resource Manager

**Siempre configura Resource Manager** cuando tienes múltiples PDBs para evitar que uno acapare recursos.

```sql
-- Ver plan activo
SELECT name, is_top_plan FROM v$rsrc_plan WHERE is_top_plan = 'TRUE';

-- Ver asignación de recursos por PDB
SELECT plan, pluggable_database, shares, utilization_limit
FROM dba_cdb_rsrc_plan_directives
WHERE plan = 'ORA$AUTOTASK_CDB_PLAN';
```

---

### 3. Automatizar Apertura de PDBs

**Problema:**
Por defecto, los PDBs no se abren automáticamente al arrancar el CDB.

**Solución:**
```sql
-- Configurar PDB para auto-open
ALTER PLUGGABLE DATABASE pdb1 SAVE STATE;
```

**Verificar:**
```sql
SELECT con_name, state FROM dba_pdb_saved_states;

CON_NAME STATE
-------- ------
PDB1     OPEN
```

---

### 4. Nombrar PDBs Consistentemente

**Convención recomendada:**
- `pdb_<aplicacion>_<entorno>`
- Ejemplos:
  - `pdb_healthcare_prod`
  - `pdb_healthcare_dev`
  - `pdb_inventory_prod`

**Ventaja:** Fácil identificar qué PDB es qué.

---

### 5. Backups Separados por PDB

**Aunque RMAN puede hacer backup del CDB completo, considera backups por PDB:**

```bash
rman target /

# Backup solo PDB1
BACKUP PLUGGABLE DATABASE pdb1;

# Restore solo PDB1
RESTORE PLUGGABLE DATABASE pdb1;
RECOVER PLUGGABLE DATABASE pdb1;
```

**Ventaja:** Restaurar un PDB sin afectar a otros.

---

### 6. Monitoreo de Límites

**Establecer límites de storage por PDB:**
```sql
ALTER PLUGGABLE DATABASE pdb1 STORAGE (MAXSIZE 50G);
```

**Verificar límites:**
```sql
SELECT
  pdb_name,
  max_size
FROM dba_pdbs
WHERE max_size IS NOT NULL;
```

---

### 7. Seguridad y Aislamiento

**Usa usuarios locales siempre que sea posible:**
- Evita common users (C##) a menos que realmente necesites acceso global
- Cada aplicación debe tener su propio usuario local en su PDB

**Auditoría por PDB:**
```sql
-- Habilitar auditoría en PDB1
ALTER SESSION SET CONTAINER=pdb1;
AUDIT INSERT, UPDATE, DELETE ON healthcenter.hc_payroll BY ACCESS;
```

---

### 8. Testing de Plug/Unplug

**Antes de mover un PDB a producción, prueba el proceso:**
```sql
-- Test unplug
ALTER PLUGGABLE DATABASE pdb1_test CLOSE;
ALTER PLUGGABLE DATABASE pdb1_test UNPLUG INTO '/tmp/test.xml';

-- Test compatibilidad
SET SERVEROUTPUT ON
DECLARE
  compatible BOOLEAN;
BEGIN
  compatible := DBMS_PDB.CHECK_PLUG_COMPATIBILITY(
    pdb_descr_file => '/tmp/test.xml'
  );

  IF NOT compatible THEN
    -- Ver violaciones
    FOR rec IN (SELECT * FROM pdb_plug_in_violations WHERE status != 'RESOLVED') LOOP
      DBMS_OUTPUT.PUT_LINE('ERROR: ' || rec.message);
    END LOOP;
  END IF;
END;
/
```

---

## 16. Comparación: Pre-12c vs Multitenant

### Arquitectura Pre-12c (Non-CDB)

```
Server 1:
├── Oracle Instance 1 (4GB RAM, 2 CPU)
│   └── Database APP1
│       ├── SYSTEM, SYSAUX, UNDO, TEMP
│       ├── Schema: APP1_SCHEMA
│       └── Datafiles: /u01/oradata/app1/

Server 2:
├── Oracle Instance 2 (4GB RAM, 2 CPU)
│   └── Database APP2
│       ├── SYSTEM, SYSAUX, UNDO, TEMP
│       ├── Schema: APP2_SCHEMA
│       └── Datafiles: /u01/oradata/app2/

Server 3:
├── Oracle Instance 3 (4GB RAM, 2 CPU)
│   └── Database APP3
│       ├── SYSTEM, SYSAUX, UNDO, TEMP
│       ├── Schema: APP3_SCHEMA
│       └── Datafiles: /u01/oradata/app3/

Total: 12GB RAM, 6 CPUs, 3 servers
```

---

### Arquitectura Multitenant (12c+)

```
Server 1:
├── Oracle Instance CDB1 (6GB RAM, 2 CPU)
│   ├── CDB$ROOT
│   │   ├── SYSTEM, SYSAUX, UNDO (compartido)
│   │   └── Background processes (compartidos)
│   │
│   ├── PDB1 (APP1)
│   │   ├── Local SYSTEM, SYSAUX
│   │   ├── Schema: APP1_SCHEMA
│   │   └── Datafiles: /u01/oradata/cdb1/pdb1/
│   │
│   ├── PDB2 (APP2)
│   │   ├── Local SYSTEM, SYSAUX
│   │   ├── Schema: APP2_SCHEMA
│   │   └── Datafiles: /u01/oradata/cdb1/pdb2/
│   │
│   └── PDB3 (APP3)
│       ├── Local SYSTEM, SYSAUX
│       ├── Schema: APP3_SCHEMA
│       └── Datafiles: /u01/oradata/cdb1/pdb3/

Total: 6GB RAM, 2 CPUs, 1 server
```

---

### Tabla Comparativa

| Aspecto | Pre-12c (Non-CDB) | 12c+ (Multitenant) |
|---------|-------------------|-------------------|
| **Arquitectura** | 1 DB = 1 Instancia | 1 CDB = N PDBs |
| **Procesos Background** | Duplicados por cada DB | Compartidos |
| **SGA** | Separada por DB | Compartida |
| **Consolidación** | Difícil (schemas en mismo DB) | Fácil (PDBs aislados) |
| **Portabilidad** | Export/Import (lento) | Plug/Unplug (rápido) |
| **Aislamiento** | Schemas ven metadata de otros | PDBs totalmente aislados |
| **Patching** | Por cada DB | Una vez para CDB |
| **Data Guard** | Config por cada DB | Config una vez |
| **Licenciamiento** | Por core × DBs | Por core × CDB (con límite PDBs) |
| **Complejidad Admin** | Multiplicada por N DBs | Centralizada |
| **Clonación** | Horas (export/import) | Minutos (copy-on-write) |

---

### Ejemplo Numérico

**Escenario:** 10 aplicaciones, cada una requiere 1GB SGA, 0.5 CPU, 20GB disco.

**Opción 1: Pre-12c (10 DBs separadas)**
- SGA total: 10 × 1GB = **10GB**
- CPU: 10 × 0.5 = **5 CPUs**
- Disco: 10 × (20GB datos + 5GB system) = **250GB**
- Administración: **10 ventanas de patching**

**Opción 2: Multitenant (1 CDB, 10 PDBs)**
- SGA total: 3GB (compartido) = **3GB**
- CPU: 2 CPUs (compartidos) = **2 CPUs**
- Disco: 10 × 20GB + 1 × 20GB CDB$ROOT = **220GB**
- Administración: **1 ventana de patching**

**Ahorro:**
- RAM: 70% menos
- CPU: 60% menos
- Disco: 12% menos
- Tiempo de admin: 90% menos

---

## 🎯 Resumen

La arquitectura multitenant de Oracle (CDB/PDB) representa una evolución fundamental en cómo Oracle Database gestiona múltiples aplicaciones. Los puntos clave:

1. **CDB (Container Database):**
   - Instancia física única
   - Contiene CDB$ROOT, PDB$SEED, y múltiples PDBs
   - Comparte procesos background y SGA

2. **PDB (Pluggable Database):**
   - Base de datos lógica aislada
   - Tiene sus propios schemas, datafiles, metadata
   - Portable (plug/unplug)
   - Independiente (open/close por separado)

3. **Ventajas principales:**
   - Consolidación eficiente de recursos
   - Portabilidad extrema
   - Administración centralizada
   - Aislamiento total entre PDBs
   - Integración perfecta con Data Guard

4. **En este proyecto:**
   - 1 CDB (cdb1) con 1 PDB (pdb1)
   - Schema healthcare en pdb1
   - Replicación automática vía Data Guard
   - Arquitectura escalable para agregar más PDBs

La arquitectura multitenant simplifica dramáticamente la gestión de múltiples bases de datos mientras mantiene el aislamiento y la seguridad. Cuando se combina con Data Guard, obtienes alta disponibilidad para todas las aplicaciones con una sola configuración.

---

## 📚 Referencias

**Oracle Documentation:**
- [Oracle Multitenant Administrator's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/21/multi/)
- [CREATE PLUGGABLE DATABASE](https://docs.oracle.com/en/database/oracle/oracle-database/21/sqlrf/CREATE-PLUGGABLE-DATABASE.html)
- [V$PDBS View Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/refrn/V-PDBS.html)

**Documentos relacionados:**
- [02 - Conceptos Fundamentales](../02-conceptos-fundamentales.md) - Introducción básica CDB/PDB
- [05 - Arquitectura del Sistema](../05-arquitectura-sistema.md) - Arquitectura completa del proyecto
- [81 - Data Guard Conceptos](81-data-guard-conceptos.md) - Cómo Data Guard replica CDBs
