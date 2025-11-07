# 92 - Switchover Procedure

## Procedimiento de Switchover Planificado

Este documento describe el procedimiento completo para realizar un switchover planificado en Oracle Data Guard.

---

## Tabla de Contenidos

1. [¿Qué es un Switchover?](#qué-es-un-switchover)
2. [Cuándo Realizar un Switchover](#cuándo-realizar-un-switchover)
3. [Diferencias con Failover](#diferencias-con-failover)
4. [Prerequisitos](#prerequisitos)
5. [Procedimiento Paso a Paso](#procedimiento-paso-a-paso)
6. [Verificación Post-Switchover](#verificación-post-switchover)
7. [Switchover Reverso](#switchover-reverso)
8. [Troubleshooting](#troubleshooting)
9. [Checklist](#checklist)

---

## ¿Qué es un Switchover?

**Switchover** es la operación **planificada** de intercambiar los roles entre primary y standby database.

### Conceptos Clave

- **Operación planificada:** No es una emergencia
- **Sin pérdida de datos:** Sincronización completa antes del switch
- **Reversible:** Puedes volver al estado original
- **Ambos nodos operativos:** Primary y standby deben estar funcionando
- **Uso de Data Guard Broker:** Automatiza gran parte del proceso

### Resultado del Switchover

**Antes:**
- cdb1 (ol8-21-dg1) = PRIMARY
- cdb1_stby (ol8-21-dg2) = PHYSICAL STANDBY

**Después:**
- cdb1 (ol8-21-dg1) = PHYSICAL STANDBY
- cdb1_stby (ol8-21-dg2) = PRIMARY

Los nombres de bases de datos NO cambian, solo los roles.

---

## Cuándo Realizar un Switchover

### Casos de Uso Comunes

1. **Mantenimiento Programado del Primary**
   - Actualizaciones de OS
   - Patches de Oracle
   - Cambios de hardware
   - Reinicio del servidor host

2. **Testing de Alta Disponibilidad**
   - Verificar que el standby puede funcionar como primary
   - Probar procedimientos de failover
   - Entrenar personal en operaciones DR

3. **Balanceo de Carga Geográfico**
   - Acercar el primary a usuarios en otra ubicación
   - Reducir latencia para aplicaciones

4. **Upgrade de Hardware**
   - Mover primary a servidor más potente
   - Aprovechar mejor infraestructura

5. **Verificación antes de Ventana de Mantenimiento**
   - Asegurar que switchover funciona antes de trabajo crítico

---

## Diferencias con Failover

| Aspecto | Switchover | Failover |
|---------|-----------|----------|
| **Tipo** | Planificado | Emergencia |
| **Primary disponible** | Sí | No |
| **Pérdida de datos** | No (sincronizado) | Posible (depende de modo) |
| **Reversible** | Sí (fácilmente) | No (requiere reinstatement) |
| **Tiempo** | 2-5 minutos | 5-10 minutos |
| **Complejidad** | Baja | Media-Alta |
| **Riesgo** | Muy bajo | Medio |
| **Uso de Broker** | Recomendado | Requerido |
| **Validación previa** | Automática | Manual |

---

## Prerequisitos

Antes de realizar un switchover, verifica:

### 1. Ambos Nodos Operativos

```bash
# Verificar primary
vagrant ssh primary -c "sudo su - oracle -c 'sqlplus / as sysdba << EOF
SELECT name, database_role, open_mode FROM v\\\$database;
EXIT;
EOF'"

# Verificar standby
vagrant ssh standby -c "sudo su - oracle -c 'sqlplus / as sysdba << EOF
SELECT name, database_role, open_mode FROM v\\\$database;
EXIT;
EOF'"
```

**Salida esperada:**
- Primary: DATABASE_ROLE = PRIMARY, OPEN_MODE = READ WRITE
- Standby: DATABASE_ROLE = PHYSICAL STANDBY, OPEN_MODE = MOUNTED

---

### 2. Sin Archive Gaps

```bash
vagrant ssh primary -c "sudo su - oracle -c 'sqlplus sys/S1sPassword1!@cdb1_stby.world as sysdba << EOF
SELECT * FROM v\\\$archive_gap;
EXIT;
EOF'"
```

**Debe devolver:** `no rows selected`

**Si hay gaps:** Espera a que se resuelvan o ver [94-troubleshooting.md](94-troubleshooting.md).

---

### 3. Apply Lag Bajo (<5 segundos)

```bash
vagrant ssh primary -c "sudo su - oracle -c 'sqlplus sys/S1sPassword1!@cdb1_stby.world as sysdba << EOF
SELECT name, value FROM v\\\$dataguard_stats WHERE name IN (\\\"apply lag\\\", \\\"transport lag\\\");
EXIT;
EOF'"
```

**Salida ideal:**
```
NAME           VALUE
-------------- --------------
apply lag      +00 00:00:02
transport lag  +00 00:00:01
```

---

### 4. Data Guard Broker Configurado

```bash
vagrant ssh primary -c "sudo su - oracle -c 'dgmgrl sys/S1sPassword1!@cdb1.world << EOF
SHOW CONFIGURATION;
EXIT;
EOF'"
```

**Debe mostrar:**
```
Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
  cdb1        - Primary database
  cdb1_stby   - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

**Si Configuration Status no es SUCCESS:** Investigar antes de continuar.

---

### 5. Switchover Status = TO STANDBY (Primary)

```bash
vagrant ssh primary -c "sudo su - oracle -c 'sqlplus / as sysdba << EOF
SELECT switchover_status FROM v\\\$database;
EXIT;
EOF'"
```

**Debe devolver:** `TO STANDBY` o `SESSIONS ACTIVE`

**Valores posibles:**
- `TO STANDBY` = Listo para switchover ✓
- `SESSIONS ACTIVE` = Listo, pero hay sesiones activas (cerrarlas o usar WITH SESSION SHUTDOWN)
- `NOT ALLOWED` = No se puede hacer switchover (investigar) 🔴
- `RESYNCHRONIZATION REQUIRED` = Hay gaps o lag alto (sincronizar primero) 🔴

---

### 6. Switchover Status = NOT ALLOWED (Standby)

```bash
vagrant ssh standby -c "sudo su - oracle -c 'sqlplus / as sysdba << EOF
SELECT switchover_status FROM v\\\$database;
EXIT;
EOF'"
```

**Debe devolver:** `NOT ALLOWED` (normal para standby antes de switchover)

---

### 7. Backup Reciente

**Recomendación:** Hacer backup antes de cualquier operación mayor.

```bash
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"
```

Responder `yes` dos veces.

---

## Procedimiento Paso a Paso

### Método: Usando Data Guard Broker (Recomendado)

Data Guard Broker automatiza todo el proceso y valida prerequisitos.

---

### Paso 1: Conectar a Data Guard Broker

```bash
vagrant ssh primary

sudo su - oracle
dgmgrl /
```

**Salida:**

```
DGMGRL for Linux: Release 21.0.0.0.0 - Production on Mon Nov 4 16:00:00 2025

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

**Salida esperada:**

```
Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1        - Primary database
    cdb1_stby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 3 seconds ago)
```

**Anotar:**
- Primary actual: `cdb1`
- Standby actual: `cdb1_stby`
- Status: `SUCCESS`

---

### Paso 3: Verificar Estado de Ambas Bases de Datos

```dgmgrl
SHOW DATABASE cdb1;
```

**Salida:**

```
Database - cdb1

  Role:               PRIMARY
  Intended State:     TRANSPORT-ON
  Instance(s):
    cdb1

Database Status:
SUCCESS
```

```dgmgrl
SHOW DATABASE cdb1_stby;
```

**Salida:**

```
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
```

**Verificar:**
- Transport Lag: 0 segundos ✓
- Apply Lag: 0 segundos ✓
- Database Status: SUCCESS ✓

---

### Paso 4: Ejecutar Switchover

**Sintaxis:**

```dgmgrl
SWITCHOVER TO <nombre_standby>;
```

**En nuestro caso:**

```dgmgrl
SWITCHOVER TO cdb1_stby;
```

**Qué hace este comando:**
1. Valida prerequisitos automáticamente
2. Detiene apply en standby
3. Sincroniza completamente primary y standby
4. Convierte primary a standby
5. Convierte standby a primary
6. Abre nuevo primary en modo READ WRITE
7. Inicia redo transport hacia nuevo standby
8. Inicia redo apply en nuevo standby

**Tiempo:** 2-5 minutos

**Salida durante el proceso:**

```
Performing switchover NOW, please wait...
Operation requires a connection to database "cdb1_stby"
Connecting ...
Connected to "cdb1_stby"
Connected as SYSDBA.
New primary database "cdb1_stby" is opening...
Operation requires start up of instance "cdb1" on database "cdb1"
Starting instance "cdb1"...
Connected to an idle instance.
ORACLE instance started.
Connected to "cdb1"
Database mounted.
Database opened.
Connected to "cdb1"
Switchover succeeded, new primary is "cdb1_stby"
```

**Anotar:**
- Tiempo de inicio del switchover
- Tiempo de finalización
- Mensaje final: `Switchover succeeded, new primary is "cdb1_stby"`

---

### Paso 5: Verificar Nuevos Roles

Inmediatamente después del switchover:

```dgmgrl
SHOW CONFIGURATION;
```

**Salida esperada:**

```
Configuration - dg_config

  Protection Mode: MaxAvailability
  Members:
  cdb1_stby   - Primary database
    cdb1      - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 3 seconds ago)
```

**Notar:**
- `cdb1_stby` ahora es PRIMARY ✓
- `cdb1` ahora es PHYSICAL STANDBY ✓

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

```dgmgrl
SHOW DATABASE cdb1;
```

**Debe mostrar:**

```
Database - cdb1

  Role:               PHYSICAL STANDBY
  Intended State:     APPLY-ON
  Transport Lag:      0 seconds (computed 2 seconds ago)
  Apply Lag:          0 seconds (computed 2 seconds ago)
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

## Verificación Post-Switchover

### 1. Verificar Roles desde SQL*Plus

**En el nuevo primary (cdb1_stby - ol8-21-dg2):**

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT name, database_role, open_mode, switchover_status FROM v\$database;
EXIT;
EOF
```

**Salida esperada:**

```
NAME   DATABASE_ROLE  OPEN_MODE   SWITCHOVER_STATUS
------ -------------- ----------- -----------------
CDB1   PRIMARY        READ WRITE  TO STANDBY
```

---

**En el nuevo standby (cdb1 - ol8-21-dg1):**

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT name, database_role, open_mode, switchover_status FROM v\$database;
EXIT;
EOF
```

**Salida esperada:**

```
NAME   DATABASE_ROLE       OPEN_MODE         SWITCHOVER_STATUS
------ ------------------- ----------------- -----------------
CDB1   PHYSICAL STANDBY    READ ONLY WITH    NOT ALLOWED
                           APPLY
```

---

### 2. Verificar Conectividad desde Windows

**Al nuevo primary (ahora en puerto 1522):**

```bash
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<EOF
SELECT database_role FROM v\$database;
EXIT;
EOF
```

**Debe devolver:** `PRIMARY`

**Al nuevo standby (ahora en puerto 1521):**

```bash
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba <<EOF
SELECT database_role FROM v\$database;
EXIT;
EOF
```

**Debe devolver:** `PHYSICAL STANDBY`

---

### 3. Probar Replicación

**Insertar datos en nuevo primary:**

```bash
# Conectar al nuevo primary (puerto 1522)
sqlplus HEALTHCENTER/HCApp2025!@localhost:1522/pdb1 <<EOF
INSERT INTO HC_HealthCenter (HCT_id, HCT_name, HCT_location, HCT_phone)
VALUES (9998, 'Test After Switchover', 'Location', '555-0000');
COMMIT;
SELECT COUNT(*) FROM HC_HealthCenter WHERE HCT_id=9998;
EXIT;
EOF
```

**Salida:** `1`

---

**Forzar log switch:**

```bash
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF
```

---

**Esperar 10 segundos:**

```bash
timeout /t 10
```

---

**Verificar en nuevo standby:**

```bash
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 <<EOF
SELECT COUNT(*) FROM HC_HealthCenter WHERE HCT_id=9998;
EXIT;
EOF
```

**Salida esperada:** `1` (dato replicado) ✓

---

### 4. Ejecutar Script de Verificación

```bash
# Ahora debemos ejecutarlo desde el nuevo primary (standby VM)
vagrant ssh standby -c "/home/oracle/automation/verify_dataguard.sh"
```

**Verificar en la salida:**
- Primary Database (cdb1_stby): Database Role = PRIMARY ✓
- Standby Database (cdb1): Database Role = PHYSICAL STANDBY ✓
- Apply Lag: 0 seconds ✓
- No archive gaps ✓
- Configuration Status: SUCCESS ✓

---

## Switchover Reverso

Si necesitas volver a la configuración original (switchover de vuelta):

### Cuándo Hacer Switchover Reverso

- Después de completar mantenimiento en el nodo original
- Después de probar que switchover funciona
- Para volver a configuración preferida

---

### Procedimiento

Es exactamente el mismo procedimiento, pero en dirección opuesta.

**Paso 1:** Conectar a Data Guard Broker (desde actual primary):

```bash
vagrant ssh standby  # Actual primary

sudo su - oracle
dgmgrl /
```

---

**Paso 2:** Ejecutar switchover al otro nodo:

```dgmgrl
SWITCHOVER TO cdb1;
```

---

**Paso 3:** Verificar:

```dgmgrl
SHOW CONFIGURATION;
```

**Debe mostrar:**
- `cdb1` = Primary (de vuelta al original)
- `cdb1_stby` = Physical standby

---

**Paso 4:** Salir:

```dgmgrl
EXIT;
```

---

**Ahora estás de vuelta a la configuración original.**

---

## Troubleshooting

### Problema: "Switchover status is NOT ALLOWED"

**Causa:** Prerequisitos no cumplidos.

**Diagnóstico:**

```sql
-- En primary
SELECT switchover_status FROM v$database;
```

**Soluciones según status:**

- `RESYNCHRONIZATION REQUIRED`: Hay archive gaps o apply lag alto
  - Solución: Esperar a que se sincronice, verificar MRP0 está corriendo

- `SESSIONS ACTIVE`: Hay sesiones de usuario conectadas
  - Solución: Cerrar sesiones o usar `SWITCHOVER TO <db> WITH SESSION SHUTDOWN`

- `NOT ALLOWED`: Problema de configuración
  - Solución: Verificar logs de alerta, consultar [94-troubleshooting.md](94-troubleshooting.md)

---

### Problema: "ORA-16795: the standby database needs to be re-created"

**Causa:** Standby desincronizado más allá de recovery posible.

**Solución:** No hacer switchover. Consultar [93-failover.md](93-failover.md) para reinstatement.

---

### Problema: Switchover se queda colgado

**Síntomas:** Comando SWITCHOVER no termina después de 10+ minutos.

**Diagnóstico:**

```bash
# En otra ventana, verificar alert logs
vagrant ssh primary -c "tail -50 /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log"
vagrant ssh standby -c "tail -50 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log"
```

**Buscar errores ORA-XXXXX.**

**Solución temporal:** Ctrl+C para cancelar comando en DGMGRL, investigar error en alert logs.

**Solución definitiva:** Resolver error específico (consultar troubleshooting).

---

### Problema: Nuevo primary no abre en READ WRITE

**Diagnóstico:**

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT open_mode FROM v\$database;
EXIT;
EOF
```

**Si muestra MOUNTED:**

```sql
-- Intentar abrir manualmente
ALTER DATABASE OPEN;
```

**Si falla con error:** Revisar alert log para causa específica.

---

### Problema: Nuevo standby no inicia redo apply

**Diagnóstico:**

```bash
vagrant ssh primary  # Nuevo standby

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT process, status FROM v\$managed_standby WHERE process='MRP0';
EXIT;
EOF
```

**Si no hay rows o status != APPLYING_LOG:**

```sql
-- Iniciar apply manualmente
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

---

### Problema: Data Guard Broker muestra WARNING después de switchover

**Diagnóstico:**

```dgmgrl
SHOW CONFIGURATION;
```

**Si muestra WARNING en lugar de SUCCESS:**

```dgmgrl
SHOW DATABASE VERBOSE cdb1;
SHOW DATABASE VERBOSE cdb1_stby;
```

Buscar líneas con WARNING o ERROR.

**Soluciones comunes:**
- Esperar 30-60 segundos (broker re-evalúa cada 30 seg)
- Verificar conectividad de red
- Verificar que listeners están corriendo en ambos nodos

---

## Checklist

### Pre-Switchover Checklist

- [ ] Ambos nodos (primary y standby) están operativos
- [ ] Sin archive gaps (v$archive_gap vacío)
- [ ] Apply lag < 5 segundos
- [ ] Transport lag < 2 segundos
- [ ] Data Guard Broker status = SUCCESS
- [ ] Switchover status (primary) = TO STANDBY o SESSIONS ACTIVE
- [ ] Backup reciente realizado (<24 horas)
- [ ] Notificar a usuarios de ventana de mantenimiento (si aplica)
- [ ] Documentar configuración actual (roles, IPs, puertos)

### Durante Switchover Checklist

- [ ] Conectar a DGMGRL
- [ ] Ejecutar SHOW CONFIGURATION (anotar estado inicial)
- [ ] Ejecutar SHOW DATABASE para ambos nodos
- [ ] Ejecutar SWITCHOVER TO <standby_name>
- [ ] Monitorear salida por errores
- [ ] Anotar tiempo de inicio y fin
- [ ] Verificar mensaje "Switchover succeeded"

### Post-Switchover Checklist

- [ ] Verificar nuevos roles con SHOW CONFIGURATION
- [ ] Verificar status = SUCCESS en ambas bases
- [ ] Verificar database_role en SQL*Plus (ambos nodos)
- [ ] Verificar open_mode correcto (nuevo primary = READ WRITE)
- [ ] Probar conectividad desde Windows
- [ ] Probar replicación (insert + verificar en standby)
- [ ] Ejecutar verify_dataguard.sh
- [ ] Verificar apply lag < 5 segundos
- [ ] Verificar sin archive gaps
- [ ] Verificar alert logs (sin errores)
- [ ] Actualizar documentación (si roles permanecen cambiados)
- [ ] Notificar a usuarios que mantenimiento terminó

---

## Resumen de Comandos

### Verificación Pre-Switchover

```bash
# Verificar ambos nodos operativos
vagrant status

# Verificar roles actuales
vagrant ssh primary -c "sudo su - oracle -c 'sqlplus / as sysdba <<< \"SELECT database_role FROM v\\\$database;\"'"

# Verificar sin gaps
vagrant ssh primary -c "sudo su - oracle -c 'sqlplus sys/S1sPassword1!@cdb1_stby.world as sysdba <<< \"SELECT * FROM v\\\$archive_gap;\"'"

# Verificar apply lag
vagrant ssh primary -c "/home/oracle/automation/check_log_transport.sh"

# Backup previo
vagrant ssh primary -c "/home/oracle/automation/manual_backup.sh"
```

### Switchover

```bash
vagrant ssh primary

sudo su - oracle
dgmgrl /

# Dentro de DGMGRL:
SHOW CONFIGURATION;
SHOW DATABASE cdb1;
SHOW DATABASE cdb1_stby;
SWITCHOVER TO cdb1_stby;
SHOW CONFIGURATION;
EXIT;
```

### Verificación Post-Switchover

```bash
# Verificar desde nuevo primary
vagrant ssh standby -c "/home/oracle/automation/verify_dataguard.sh"

# Probar replicación
sqlplus HEALTHCENTER/HCApp2025!@localhost:1522/pdb1 <<EOF
INSERT INTO HC_HealthCenter VALUES (9999, 'Test', 'Loc', '555-1234');
COMMIT;
EXIT;
EOF

# Forzar sync
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba <<< "ALTER SYSTEM ARCHIVE LOG CURRENT;"

# Verificar en nuevo standby
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 <<< "SELECT COUNT(*) FROM HC_HealthCenter WHERE HCT_id=9999;"
```

---

## Referencias

- [90 - Monitoreo Diario](90-monitoreo-diario.md) - Verificaciones previas
- [93 - Failover](93-failover.md) - Procedimiento de emergencia
- [94 - Troubleshooting](94-troubleshooting.md) - Solución de problemas
- [Oracle Data Guard Broker Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/dgbkr/)
- [Role Transitions Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/sbydb/managing-oracle-data-guard-role-transitions.html)

---

**Nota Final:** El switchover es una operación de bajo riesgo cuando se ejecuta correctamente. Practica en ambientes de desarrollo antes de hacerlo en producción. El procedimiento completo toma solo 2-5 minutos de downtime planificado.
