# 93 - Failover Procedure

## Procedimiento de Failover de Emergencia

Este documento describe el procedimiento completo para realizar un failover de emergencia cuando el primary database falla catastróficamente.

---

## Tabla de Contenidos

1. [¿Qué es un Failover?](#qué-es-un-failover)
2. [Cuándo Realizar un Failover](#cuándo-realizar-un-failover)
3. [Diferencias con Switchover](#diferencias-con-switchover)
4. [Tipos de Failover](#tipos-de-failover)
5. [Evaluación Inicial](#evaluación-inicial)
6. [Procedimiento de Failover](#procedimiento-de-failover)
7. [Verificación Post-Failover](#verificación-post-failover)
8. [Reinstatement del Old Primary](#reinstatement-del-old-primary)
9. [Checklist](#checklist)

---

## ¿Qué es un Failover?

**Failover** es la operación **de emergencia** de activar el standby database como nuevo primary cuando el primary original falla.

### Conceptos Clave

- **Operación de emergencia:** Se hace cuando primary no está disponible
- **Posible pérdida de datos:** Depende del protection mode y sincronización
- **No reversible fácilmente:** Old primary debe ser "reinstated" (proceso complejo)
- **Primary no operativo:** Primary puede estar caído, inaccesible, o corrupto
- **Requiere Data Guard Broker:** Automatiza validaciones críticas

### Resultado del Failover

**Antes:**
- cdb1 (ol8-21-dg1) = PRIMARY (CAÍDO/INACCESIBLE)
- cdb1_stby (ol8-21-dg2) = PHYSICAL STANDBY

**Después:**
- cdb1 (ol8-21-dg1) = DESHABILITADO (necesita reinstatement)
- cdb1_stby (ol8-21-dg2) = PRIMARY (activo)

---

## Cuándo Realizar un Failover

### Situaciones de Emergencia

1. **Primary Database Inaccesible**
   - Host caído (hardware failure)
   - VM no inicia
   - Red completamente caída
   - Storage corrupto

2. **Primary Database Corrupto**
   - ORA-600/ORA-7445 (internal errors)
   - Corrupción de datafiles
   - Controlfile corrupto
   - No puede arrancar

3. **Desastre Natural/Físico**
   - Falla de datacenter
   - Pérdida de energía prolongada
   - Incendio, inundación
   - Sabotaje

4. **Pruebas de DR (Disaster Recovery)**
   - Simulación de desastre
   - Entrenamiento de personal
   - **Solo en ambientes de prueba**

---

### ⚠️ ADVERTENCIA CRÍTICA

**NO hacer failover prematuramente.**

**Antes de hacer failover, SIEMPRE:**

1. **Intentar recuperar primary** (reiniciar VM, reiniciar Oracle, restore de backup)
2. **Confirmar que primary realmente está muerto** (no solo lento o con problemas temporales)
3. **Evaluar pérdida de datos potencial**
4. **Notificar a management/equipo**
5. **Documentar razón del failover**

**Hacer failover innecesariamente causa:**
- Pérdida de datos (si hay lag)
- Downtime adicional
- Complejidad operativa (reinstatement)
- Riesgo de errores

---

## Diferencias con Switchover

| Aspecto | Failover | Switchover |
|---------|----------|------------|
| **Tipo** | Emergencia | Planificado |
| **Primary disponible** | No | Sí |
| **Pérdida de datos** | Posible | No |
| **Sincronización previa** | No garantizada | Garantizada |
| **Reversible** | No (requiere reinstatement) | Sí (fácil) |
| **Tiempo** | 5-10 minutos | 2-5 minutos |
| **Complejidad** | Alta | Baja |
| **Riesgo** | Medio-Alto | Bajo |
| **Decisión** | Bajo presión | Planificada |
| **Validación** | Manual | Automática |

---

## Tipos de Failover

### 1. Complete Failover (Usado en este proyecto)

- Standby se convierte en primary completamente
- Old primary queda deshabilitado
- Requiere reinstatement del old primary

**Comando:**

```dgmgrl
FAILOVER TO <standby_name>;
```

---

### 2. Immediate Failover

- Similar a Complete, pero sin esperar a aplicar todos los redo logs
- Puede perder datos (últimos segundos/minutos)
- Más rápido (30-60 segundos)

**Comando:**

```dgmgrl
FAILOVER TO <standby_name> IMMEDIATE;
```

**Cuándo usar:** Solo si velocidad es más crítica que datos (raro).

---

### 3. Fast-Start Failover (No configurado en este proyecto)

- Failover completamente automático
- Oracle detecta falla de primary y hace failover sin intervención humana
- Requiere Oracle Observer
- Requiere licencia Enterprise Edition con Active Data Guard

**No disponible en este proyecto.**

---

## Evaluación Inicial

Antes de proceder con failover, evalúa la situación.

### Paso 1: Confirmar que Primary está Realmente Caído

**Intentar conectar desde Windows:**

```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba <<EOF
SELECT name FROM v\$database;
EXIT;
EOF
```

**Si devuelve error:** `ORA-12541: TNS:no listener` o `ORA-01034: ORACLE not available`

**Intentar conectar via SSH:**

```bash
vagrant ssh primary
```

**Si no responde después de 30 segundos:** VM probablemente caída.

---

### Paso 2: Intentar Recuperación Rápida del Primary

**Opción 1: Reiniciar VM**

```bash
vagrant reload primary
```

**Esperar:** 2-3 minutos.

**Intentar conexión nuevamente.**

---

**Opción 2: Iniciar Oracle manualmente**

```bash
vagrant ssh primary

sudo su - oracle
lsnrctl start
sqlplus / as sysdba <<EOF
STARTUP;
EXIT;
EOF
```

---

**Si primary no recupera después de estos intentos:** Proceder con failover.

---

### Paso 3: Evaluar Pérdida de Datos Potencial

**Conectar a standby:**

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT name, value, time_computed
FROM v\$dataguard_stats
WHERE name IN ('apply lag', 'transport lag');
EXIT;
EOF
```

**Interpretar:**

- `apply lag = 0 seconds` → Sin pérdida de datos ✓
- `apply lag = 5 seconds` → Pérdida de ~5 segundos de transacciones ⚠️
- `apply lag = 5 minutes` → Pérdida de 5 minutos de datos 🔴

**También verificar sequence gap:**

```sql
-- Última secuencia aplicada en standby
SELECT MAX(sequence#) AS last_applied
FROM v$archived_log
WHERE applied = 'YES';
```

Anotar este número. Los archive logs con sequence# mayor a este (si existían en primary) se perderán.

---

### Paso 4: Decisión Go/No-Go

**Factores a considerar:**

- **Criticidad de servicio:** ¿Cuánto downtime es aceptable?
- **Pérdida de datos:** ¿Es aceptable perder X minutos/segundos?
- **Probabilidad de recuperar primary:** ¿Es factible?
- **Tiempo de recovery de primary:** ¿Cuánto tomaría?

**Ejemplo de decisión:**

```
Situación: Primary VM no responde
Intentos de recovery: Reinicio VM - FALLÓ
Apply lag: 2 segundos
Pérdida de datos: Mínima (2 segundos)
Criticidad: Alta (sistema de healthcare)
Downtime acumulado: 15 minutos

DECISIÓN: Proceder con FAILOVER
```

---

## Procedimiento de Failover

### Prerequisito: Acceso al Standby

Necesitas conectarte al standby (que se convertirá en nuevo primary).

```bash
vagrant ssh standby
```

---

### Paso 1: Conectar a Data Guard Broker

```bash
sudo su - oracle
dgmgrl /
```

**Salida:**

```
DGMGRL for Linux: Release 21.0.0.0.0 - Production on Mon Nov 4 17:00:00 2025

Copyright (c) 1982, 2021, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "cdb1"
Connected as SYSDBA.

DGMGRL>
```

---

### Paso 2: Verificar Configuración Actual

```dgmgrl
SHOW CONFIGURATION;
```

**Salida típica durante falla de primary:**

```
Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1        - Primary database
    Warning: ORA-16810: multiple errors or warnings detected for the database

    cdb1_stby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
WARNING   (status updated 30 seconds ago)
```

**Notar:**
- Primary muestra WARNING o ERROR
- Configuration Status: WARNING o ERROR

---

### Paso 3: Verificar Estado del Standby

```dgmgrl
SHOW DATABASE cdb1_stby;
```

**Salida esperada:**

```
Database - cdb1_stby

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON
  Transport Lag:      (unknown)
  Apply Lag:          2 seconds (computed 5 seconds ago)
  Average Apply Rate: 15.00 KByte/s
  Real Time Query:    ON
  Instance(s):
    cdb1

Database Status:
SUCCESS
```

**Verificar:**
- Database Status: SUCCESS (standby está sano) ✓
- Apply Lag: razonable (<5 minutos) ✓

---

### Paso 4: Ejecutar Failover

**Sintaxis:**

```dgmgrl
FAILOVER TO <standby_name>;
```

**En nuestro caso:**

```dgmgrl
FAILOVER TO cdb1_stby;
```

**Qué hace este comando:**
1. Verifica que primary realmente está inaccesible
2. Aplica todos los redo logs disponibles en standby
3. Convierte standby a primary
4. Abre nuevo primary en modo READ WRITE
5. Deshabilita old primary en configuración

**Tiempo:** 5-10 minutos

**Salida durante el proceso:**

```
Performing failover NOW, please wait...
Failover succeeded, new primary is "cdb1_stby"

DGMGRL>
```

**Si hay errores durante failover:** Ver sección Troubleshooting.

---

### Paso 5: Verificar Nuevo Primary

```dgmgrl
SHOW CONFIGURATION;
```

**Salida esperada:**

```
Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1_stby   - Primary database
    cdb1      - Physical standby database (disabled)
      ORA-16661: the standby database needs to be reinstated

Fast-Start Failover:  Disabled

Configuration Status:
WARNING   (status updated 3 seconds ago)
```

**Notar:**
- `cdb1_stby` ahora es PRIMARY ✓
- `cdb1` está DISABLED (necesita reinstatement) ✓
- Configuration Status: WARNING (normal después de failover)

---

```dgmgrl
SHOW DATABASE cdb1_stby;
```

**Debe mostrar:**

```
Database - cdb1_stby

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Instance(s):
    cdb1

Database Status:
SUCCESS
```

---

### Paso 6: Salir de DGMGRL

```dgmgrl
EXIT;
```

---

### Paso 7: Verificar que Nuevo Primary está Abierto

```bash
sqlplus / as sysdba <<EOF
SELECT name, database_role, open_mode FROM v\$database;
EXIT;
EOF
```

**Salida esperada:**

```
NAME   DATABASE_ROLE  OPEN_MODE
------ -------------- -----------
CDB1   PRIMARY        READ WRITE
```

---

### Paso 8: Abrir PDB si es Necesario

```bash
sqlplus / as sysdba <<EOF
SHOW PDBS;
EXIT;
EOF
```

**Si PDB está en MOUNTED:**

```sql
ALTER PLUGGABLE DATABASE pdb1 OPEN;
```

---

## Verificación Post-Failover

### 1. Verificar Conectividad desde Windows

**Conectar al nuevo primary (puerto 1522 - standby node):**

```bash
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<EOF
SELECT database_role, open_mode FROM v\$database;
EXIT;
EOF
```

**Debe devolver:**

```
DATABASE_ROLE  OPEN_MODE
-------------- -----------
PRIMARY        READ WRITE
```

---

### 2. Verificar Schema de Aplicación

```bash
sqlplus HEALTHCENTER/HCApp2025!@localhost:1522/pdb1 <<EOF
SELECT COUNT(*) AS table_count FROM user_tables;
SELECT COUNT(*) AS user_count FROM HC_User;
EXIT;
EOF
```

**Debe devolver:**
- table_count: 15 (o el número esperado)
- user_count: >0 (datos presentes)

---

### 3. Probar Escritura en Nuevo Primary

```bash
sqlplus HEALTHCENTER/HCApp2025!@localhost:1522/pdb1 <<EOF
INSERT INTO HC_HealthCenter (HCT_id, HCT_name, HCT_location, HCT_phone)
VALUES (9997, 'Test After Failover', 'Location', '555-0001');
COMMIT;
SELECT COUNT(*) FROM HC_HealthCenter WHERE HCT_id=9997;
EXIT;
EOF
```

**Debe devolver:** `1` (insert exitoso) ✓

---

### 4. Evaluar Pérdida de Datos (si la hubo)

**Comparar con anotaciones previas:**

- **Última secuencia aplicada en standby:** (anotado en evaluación inicial)
- **Última secuencia del primary:** (si está disponible en backups/logs)

**Gap = última_primary - última_aplicada**

**Ejemplo:**

```
Última secuencia en primary antes de falla: 150
Última secuencia aplicada en standby: 148
GAP: 2 sequences

Redo log size: 50 MB
Redo generation rate: ~10 MB/min

Pérdida estimada: 2 sequences × 50 MB / 10 MB/min ≈ 10 minutos de transacciones
```

**Documentar pérdida en reporte de incidente.**

---

### 5. Notificar a Usuarios

**Mensaje ejemplo:**

```
La base de datos primary experimentó una falla a las 17:00 horas.
Se activó el standby como nuevo primary a las 17:08 horas.
El servicio está restaurado.
Pérdida de datos: Aproximadamente 2 minutos de transacciones.
Por favor verifiquen sus últimas operaciones.
```

---

### 6. Documentar Incidente

**Template de reporte:**

```
======================================
INCIDENT REPORT: PRIMARY FAILOVER
======================================

Date/Time of failure: 2025-11-04 17:00:00
Date/Time of failover: 2025-11-04 17:08:00
Total downtime: 8 minutes

PRIMARY STATUS:
- Host: ol8-21-dg1 (192.168.56.101)
- Status before failure: PRIMARY
- Status after failure: DISABLED
- Reason for failure: [VM crashed / Network failure / Database corruption / etc.]

FAILOVER PROCESS:
- Initiated by: [DBA Name]
- Method: Data Guard Broker FAILOVER command
- Duration: 5 minutes
- Errors during failover: [None / List errors]

NEW PRIMARY:
- Host: ol8-21-dg2 (192.168.56.102)
- Database: cdb1_stby
- Status: PRIMARY - READ WRITE
- PDB status: OPEN

DATA LOSS ASSESSMENT:
- Apply lag at time of failure: 2 seconds
- Archive sequences lost: 2 (148-150)
- Estimated data loss: 2 minutes of transactions
- Affected transactions: [Unknown / Verified with users]

RECOVERY PLAN:
- Old primary will be reinstated as new standby
- ETA: [Date/Time]
- Assigned to: [DBA Name]

LESSONS LEARNED:
- [Notes on what went well]
- [Notes on what could improve]

SIGN-OFF:
DBA: ________________  Date: __________
Manager: _____________ Date: __________
```

---

## Reinstatement del Old Primary

Después de un failover, el old primary (que falló) debe ser "reinstated" como nuevo standby.

### Opción 1: Con Flashback Database (Rápido - 5-10 minutos)

**Prerequisito:** Flashback debe haber estado habilitado antes de la falla (lo está en este proyecto).

---

#### Paso 1: Recuperar Old Primary

Si el old primary está caído, primero recupéralo:

```bash
# Si VM está caída
vagrant up primary

# O si VM responde pero Oracle caído
vagrant ssh primary

sudo su - oracle
lsnrctl start
sqlplus / as sysdba <<EOF
STARTUP MOUNT;
EXIT;
EOF
```

---

#### Paso 2: Verificar Flashback

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT flashback_on FROM v\$database;
EXIT;
EOF
```

**Debe devolver:** `YES`

---

#### Paso 3: Conectar a Broker desde Nuevo Primary

```bash
vagrant ssh standby  # Nuevo primary

sudo su - oracle
dgmgrl /
```

---

#### Paso 4: Reinstater Old Primary

```dgmgrl
REINSTATE DATABASE cdb1;
```

**Qué hace:**
1. Usa Flashback Database para revertir cdb1 a punto antes del failover
2. Convierte cdb1 en physical standby
3. Sincroniza con nuevo primary
4. Inicia redo apply

**Tiempo:** 5-10 minutos

**Salida:**

```
Reinstating database "cdb1", please wait...
Reinstatement of database "cdb1" succeeded

DGMGRL>
```

---

#### Paso 5: Verificar

```dgmgrl
SHOW CONFIGURATION;
```

**Debe mostrar:**

```
Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1_stby   - Primary database
    cdb1      - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

**Notar:**
- `cdb1` ya NO está DISABLED ✓
- `cdb1` ahora es Physical standby ✓
- Configuration Status: SUCCESS ✓

---

### Opción 2: Sin Flashback (Lento - 30-60 minutos)

Si Flashback no estaba habilitado o no funciona, debes recrear standby desde cero.

**Proceso:**

1. **Hacer backup del nuevo primary:**

```bash
vagrant ssh standby  # Nuevo primary
/home/oracle/automation/manual_backup.sh
```

2. **Destroy y recrear old primary VM:**

```bash
# Desde Windows
vagrant destroy -f primary
vagrant up primary
```

Esto ejecutará todo el proceso de setup de primary, pero el script `oracle_create_database.sh` detectará que cdb1_stby ya es primary y configurará cdb1 como standby automáticamente.

**Tiempo:** 30-40 minutos (full re-deploy de primary node)

---

## Checklist

### Pre-Failover Checklist (Evaluación)

- [ ] Confirmar que primary está realmente caído (no responde después de múltiples intentos)
- [ ] Intentar recuperación rápida (reiniciar VM, reiniciar Oracle)
- [ ] Si primary no recupera después de 10-15 minutos, proceder
- [ ] Verificar que standby está operativo
- [ ] Evaluar apply lag (pérdida de datos potencial)
- [ ] Anotar última secuencia aplicada en standby
- [ ] Documentar razón del failover
- [ ] Notificar a management (si aplica)
- [ ] Obtener autorización para failover (si es política)

### Durante Failover Checklist

- [ ] Conectar a standby node via SSH
- [ ] Conectar a DGMGRL
- [ ] Ejecutar SHOW CONFIGURATION (anotar estado)
- [ ] Ejecutar SHOW DATABASE cdb1_stby (verificar SUCCESS)
- [ ] Ejecutar FAILOVER TO cdb1_stby
- [ ] Anotar tiempo de inicio y fin
- [ ] Verificar mensaje "Failover succeeded"
- [ ] Verificar nuevo primary está abierto (READ WRITE)
- [ ] Abrir PDBs si es necesario

### Post-Failover Checklist

- [ ] Verificar configuración con SHOW CONFIGURATION
- [ ] Verificar database_role = PRIMARY en SQL
- [ ] Verificar open_mode = READ WRITE
- [ ] Probar conectividad desde Windows
- [ ] Verificar schema de aplicación presente
- [ ] Probar escritura (INSERT de prueba)
- [ ] Evaluar pérdida de datos real
- [ ] Notificar a usuarios que servicio está restaurado
- [ ] Documentar incidente completo
- [ ] Planificar reinstatement de old primary
- [ ] Ejecutar reinstatement cuando old primary esté disponible
- [ ] Verificar configuración final (ambos nodos operativos)

---

## Resumen de Comandos

### Evaluación Pre-Failover

```bash
# Intentar conectar a primary
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

# Verificar estado de standby
vagrant ssh standby -c "sudo su - oracle -c 'sqlplus / as sysdba <<< \"SELECT database_role FROM v\\\$database;\"'"

# Verificar apply lag
vagrant ssh standby -c "sudo su - oracle -c 'sqlplus / as sysdba <<< \"SELECT name, value FROM v\\\$dataguard_stats WHERE name=\\\\\"apply lag\\\\\";\"'"
```

### Failover

```bash
vagrant ssh standby

sudo su - oracle
dgmgrl /

# Dentro de DGMGRL:
SHOW CONFIGURATION;
SHOW DATABASE cdb1_stby;
FAILOVER TO cdb1_stby;
SHOW CONFIGURATION;
EXIT;
```

### Post-Failover

```bash
# Verificar nuevo primary
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<< "SELECT database_role, open_mode FROM v\$database;"

# Probar escritura
sqlplus HEALTHCENTER/HCApp2025!@localhost:1522/pdb1 <<EOF
INSERT INTO HC_HealthCenter VALUES (9999, 'Test', 'Loc', '555');
COMMIT;
EXIT;
EOF
```

### Reinstatement

```bash
# Si old primary está caído, recuperarlo primero
vagrant reload primary

# Conectar a nuevo primary
vagrant ssh standby

sudo su - oracle
dgmgrl /

# Dentro de DGMGRL:
REINSTATE DATABASE cdb1;
SHOW CONFIGURATION;
EXIT;
```

---

## Referencias

- [92 - Switchover](92-switchover.md) - Operación planificada alternativa
- [94 - Troubleshooting](94-troubleshooting.md) - Solución de problemas durante failover
- [Oracle Data Guard Failover Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/sbydb/managing-oracle-data-guard-role-transitions.html)
- [Flashback Database Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/using-flasback-database-restore-points.html)

---

**Nota Final:** El failover es una operación de alto impacto que debe hacerse solo cuando es absolutamente necesario. Siempre intenta recuperar el primary antes de hacer failover. Documenta todo meticulosamente para análisis post-mortem y mejora continua.
