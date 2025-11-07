# 38 - Deploy Schema - Despliegue de Healthcare Management Schema

## Despliegue del Schema HEALTHCENTER en PDB

Este script despliega el schema de la aplicación healthcare management system en el PDB `pdb1`. Ejecuta dos scripts SQL: primero `Script_SchemeTableSpace.sql` para crear el usuario y tablespace, luego `ScriptProyectoBD.SQL` para crear todas las tablas, sequences, triggers y packages PL/SQL del sistema.

## Ubicación

`2-Standby/scripts/primary/deploy_custom_schema.sh`

## Propósito

- **Función principal:** Desplegar schema healthcare en PDB
- **Responsabilidad:** Crear usuario, tablespace, tablas, sequences, packages
- **Resultado:** Sistema healthcare completamente funcional en primary (se replicará a standby)

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 13 de 12 (después de crear DB)
- **Usuario:** `oracle`
- **Duración:** 2-5 minutos

## Variables de Entorno Utilizadas

```bash
PDB_NAME=pdb1                           # Nombre del PDB
APP_SCHEMA=HC                           # Usuario del schema
APP_SCHEMA_SQL=Script_SchemeTableSpace.sql  # Script de creación de user/tablespace
```

## Flujo de Ejecución

### Paso 1: Verificar que Existe ScriptProyectoBD.SQL

```bash
if [ ! -f "/vagrant/1-BD/ScriptProyectoBD.SQL" ]; then
  echo "ERROR: ScriptProyectoBD.SQL not found!"
  exit 1
fi
```

### Paso 2: Abrir el PDB

```bash
sqlplus / as sysdba <<EOF
ALTER PLUGGABLE DATABASE ${PDB_NAME} OPEN;
EXIT;
EOF
```

**Explicación:** El PDB debe estar abierto para ejecutar comandos DDL

### Paso 3: Crear Usuario y Tablespace

```bash
sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};
@/vagrant/1-BD/${APP_SCHEMA_SQL}
EXIT;
EOF
```

**Script_SchemeTableSpace.sql crea:**
- Tablespace `HC_TBS` (para datos de la aplicación)
- Usuario `HC` con password
- Grants necesarios (CONNECT, RESOURCE, CREATE VIEW, etc.)

### Paso 4: Ejecutar ScriptProyectoBD.SQL

```bash
sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};
@/vagrant/1-BD/ScriptProyectoBD.SQL

-- Verify tables were created
SELECT table_name, num_rows FROM user_tables ORDER BY table_name;
EXIT;
EOF
```

**ScriptProyectoBD.SQL crea:**

**Sequences (15+):**
- `SEQ_HC_USR_id` - Para usuarios
- `SEQ_HC_PRL_id` - Para payrolls
- `SEQ_HC_MSC_id` - Para month scales
- `SEQ_HC_PCD_id` - Para procedures
- etc.

**Tablas Core (20+):**
- `HC_User` - Usuarios (medics, administrative staff)
- `HC_HealthCenter` - Centros de salud
- `HC_MonthScale` - Escalas mensuales (work schedules)
- `HC_TurnXMonthScale` - Turnos individuales en escala
- `HC_Payroll` - Planillas de pago
- `HC_PayrollXUser` - Planilla por usuario
- `HC_PayrollMovement` - Movimientos de planilla (ingresos/deducciones)
- `HC_Procedure` - Procedimientos médicos realizados
- `HC_Position` - Puestos de trabajo
- `HC_Turn` - Definiciones de turnos base

**Triggers:** Auditoría automática, secuencias auto-increment

**Packages PL/SQL:**
- `PKG_UTILITIES` - Utilidades core (approve_month_scale, etc.)
- `PKG_LOGBOOK` - Logging de auditoría
- `PKG_EMAILS` - Sistema de notificaciones
- `PKG_FUNCTIONS_JOBS` - Funciones para scheduled jobs

### Paso 5: Verificar Sequences

```bash
sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${APP_SCHEMA};

SELECT sequence_name, min_value, max_value, increment_by, last_number
FROM user_sequences
ORDER BY sequence_name;
EXIT;
EOF
```

### Paso 6: Forzar Archive Log

```bash
sqlplus / as sysdba <<EOF
ALTER SYSTEM ARCHIVE LOG CURRENT;
EXIT;
EOF
```

**Explicación:**
- Fuerza switch de redo log para archivar cambios
- Asegura que schema se replicará a standby cuando se configure
- Archive log contiene todos los DDL statements ejecutados

## Tablas del Schema Healthcare

### Entidades Principales

**Gestión de Usuarios:**
```
HC_User (USR_id, USR_Name, USR_LastName1, USR_LastName2, USR_Email, USR_PhoneNumber, etc.)
```
- Medics (doctores, enfermeras)
- Administrative staff (admins, contadores)

**Centros de Salud:**
```
HC_HealthCenter (HCN_id, HCN_Name, HCN_Address, HCN_PhoneNumber, HCN_Active)
```

**Escalas Mensuales (Work Schedules):**
```
HC_MonthScale (MSC_id, MSC_Month, MSC_Year, MSC_State, MSC_HealthCenterID)
HC_TurnXMonthScale (PMS_id, PMS_MonthScaleID, PMS_TurnID, PMS_UserID, PMS_Date, PMS_State)
```
- Estado de Month Scale: B=Building, A=Active, R=Review, P=Payment, C=Complete
- Estado de Turn: A=Assigned, F=Finished, C=Canceled

**Planillas (Payrolls):**
```
HC_Payroll (PRL_id, PRL_Month, PRL_Year, PRL_PayrollType, PRL_State)
HC_PayrollXUser (PCT_id, PCT_PayrollID, PCT_UserID, PCT_GrossSalary, PCT_NetSalary)
HC_PayrollMovement (PRM_id, PRM_PayrollXUserID, PRM_MovementType, PRM_Description, PRM_Amount, PRM_AmountType)
```
- PayrollType: 1=Medics, 2=Administrative
- MovementType: I=Income, D=Deduction
- AmountType: A=Absolute, P=Percentage

**Procedimientos Médicos:**
```
HC_Procedure (PCD_id, PCD_Date, PCD_ProcedureType, PCD_MedicID, PCD_PatientID, PCD_Price)
```
- Genera ingresos para médicos en planilla

### Flujo de Uso del Sistema

1. **Crear Month Scale:** `EXEC generate_month_scale('10', 2025, 1);`
2. **Aprobar Month Scale:** `EXEC pkg_utilities.approve_month_scale(1);`
3. **Generar Payroll:** `EXEC generate_payroll('10', 2025, 1);`
4. **Procesar Payment:** `EXEC PCD_GeneratePayment(1);`

## Archivos Creados/Modificados

### En PDB pdb1

| Objeto | Cantidad | Descripción |
|--------|----------|-------------|
| Tables | 20+ | Tablas del schema healthcare |
| Sequences | 15+ | Auto-increment para PKs |
| Triggers | 20+ | Auditoría y validación |
| Packages | 4 | PKG_UTILITIES, PKG_LOGBOOK, etc. |
| Procedures | 10+ | generate_month_scale, generate_payroll, etc. |

### Espacio Utilizado

```sql
SELECT tablespace_name, SUM(bytes)/1024/1024 as size_mb
FROM dba_segments
WHERE owner = 'HC'
GROUP BY tablespace_name;

-- Típicamente: ~50-100 MB (schema vacío, sin datos)
```

## Dependencias

### Prerequisitos

- PDB `pdb1` debe existir y estar abierto
- CDB debe estar en ARCHIVELOG mode
- Usuario SYS debe poder conectar
- Scripts SQL deben existir en `/vagrant/1-BD/`

### Scripts SQL Requeridos

1. `/vagrant/1-BD/Script_SchemeTableSpace.sql`
2. `/vagrant/1-BD/ScriptProyectoBD.SQL`

## Verificación

### Verificar Tablas Creadas

```sql
sqlplus HC/password@localhost:1521/pdb1

SET LINESIZE 150
SET PAGESIZE 100
COL table_name FORMAT A30

SELECT table_name, num_rows, blocks
FROM user_tables
ORDER BY table_name;

-- Debe listar: HC_User, HC_Payroll, HC_MonthScale, etc.
```

### Verificar Sequences

```sql
SELECT sequence_name, last_number
FROM user_sequences
ORDER BY sequence_name;

-- Todos deben estar en last_number=1 (sin datos aún)
```

### Verificar Packages

```sql
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
ORDER BY object_name;

-- Expected status: VALID
-- Si INVALID, recompilar: ALTER PACKAGE pkg_utilities COMPILE;
```

### Verificar Triggers

```sql
SELECT trigger_name, table_name, status
FROM user_triggers
ORDER BY table_name, trigger_name;

-- Expected status: ENABLED
```

### Insertar Datos de Prueba (Opcional)

```sql
-- Insertar health center de prueba
INSERT INTO HC_HealthCenter (HCN_id, HCN_Name, HCN_Address, HCN_Active)
VALUES (SEQ_HC_HCN_id.NEXTVAL, 'Hospital Central', 'San Jose', 'A');

-- Insertar usuario de prueba
INSERT INTO HC_User (USR_id, USR_Name, USR_LastName1, USR_Email, USR_UserType)
VALUES (SEQ_HC_USR_id.NEXTVAL, 'Juan', 'Perez', 'jperez@test.com', 'M');

COMMIT;

SELECT * FROM HC_HealthCenter;
SELECT * FROM HC_User;
```

## Importancia para Data Guard

### Replicación Automática

**TODO lo creado en este script se replica automáticamente a standby:**

1. Schema se crea en primary
2. DDL statements van a redo logs
3. Redo logs se archivan
4. Archive logs se transfieren a standby
5. Standby aplica archive logs
6. Schema aparece idéntico en standby

**Verificar replicación (después de configurar standby):**
```sql
-- En standby (read-only)
sqlplus / as sysdba
ALTER SESSION SET CONTAINER=pdb1;
SELECT COUNT(*) FROM HC.HC_User;
-- Debe retornar mismo count que primary
```

### Protección de Datos Healthcare

**¿Por qué Data Guard es crítico para healthcare?**

1. **Datos sensibles:** Información médica protegida (HIPAA compliance)
2. **Alta disponibilidad:** Hospital no puede parar operaciones
3. **Recovery rápido:** RPO < 5 minutos (archive_lag_target)
4. **Disaster recovery:** Switchover en < 1 minuto

### Auditoría Automática

Todos los packages incluyen logging:
```sql
-- PKG_LOGBOOK registra todas las operaciones
INSERT INTO HC_LogBook (LOG_Action, LOG_User, LOG_Date)
VALUES ('APPROVE_MONTH_SCALE', USER, SYSDATE);
```

Logs también se replican a standby (para auditorías post-failover)

## Puntos de Fallo Comunes

### 1. PDB No Abierto

**Error:**
```
ORA-65011: Pluggable database PDB1 does not exist.
```

**Solución:**
```sql
ALTER PLUGGABLE DATABASE pdb1 OPEN;
```

### 2. Usuario HC Ya Existe

**Error:**
```
ORA-01920: user name 'HC' conflicts with another user or role name
```

**Solución:**
```sql
-- Limpiar y recrear
DROP USER HC CASCADE;
-- Re-ejecutar script
```

### 3. Scripts SQL No Encontrados

**Error:**
```
SP2-0310: unable to open file "/vagrant/1-BD/ScriptProyectoBD.SQL"
```

**Causa:** Synced folder no montado

**Solución:**
```bash
# Desde host Windows
vagrant reload primary
# O reinstalar VirtualBox Guest Additions
```

### 4. Packages Inválidos

**Error:**
```
ORA-04063: package body "HC.PKG_UTILITIES" has errors
```

**Solución:**
```sql
-- Ver errores de compilación
SHOW ERRORS PACKAGE BODY PKG_UTILITIES;

-- Recompilar
ALTER PACKAGE PKG_UTILITIES COMPILE BODY;

-- Recompilar todo el schema
BEGIN
  DBMS_UTILITY.compile_schema('HC');
END;
/
```

## Referencias Cruzadas

### Scripts Relacionados

- **[37 - Create Database](37-create-database.md)** - Crea CDB/PDB donde se despliega schema
- **[57 - Standby RMAN Duplicate](../standby/57-rman-duplicate.md)** - Clona primary incluyendo schema

### Documentación del Schema

- **[CLAUDE.md](../../../CLAUDE.md)** - Overview del schema healthcare
- **[1-BD/ScriptProyectoBD.SQL](../../../1-BD/ScriptProyectoBD.SQL)** - Schema completo
- **[1-BD/ExecutionScript.sql](../../../1-BD/ExecutionScript.sql)** - Ejemplos de uso

### Workflows del Sistema

```
1. Crear Month Scale → generate_month_scale('10', 2025, 1)
2. Aprobar Month Scale → pkg_utilities.approve_month_scale(1)
3. Generar Payroll → generate_payroll('10', 2025, 1)
4. Procesar Payment → PCD_GeneratePayment(1)
```

## Código Fuente Completo

Ver archivo: `2-Standby/scripts/primary/deploy_custom_schema.sh` (106 líneas)

---

**Siguiente:** [39 - Setup Automation](39-setup-automation.md) - Configuración de scripts de automatización para monitoreo y backups.
