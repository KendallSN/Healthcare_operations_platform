# 55 - Configuración del Entorno del Usuario Oracle (Standby)

## Descripción General

**Archivo:** `2-Standby/scripts/standby/oracle_user_environment_setup.sh`

**Propósito:** Crear el archivo `setEnv.sh` que define todas las variables de entorno necesarias para el usuario `oracle`.

**Diferencia Clave con Primary:** La variable `ORACLE_UNQNAME` es diferente.

**Tiempo de ejecución:** ~5 segundos

---

## Diferencia Crítica con Primary

### Primary setEnv.sh
```bash
export ORACLE_UNQNAME=cdb1
```

### Standby setEnv.sh ⭐
```bash
export ORACLE_UNQNAME=cdb1_stby  # ⭐ DIFERENTE
```

**Por qué es crítico:**
- `ORACLE_UNQNAME` (DB_UNIQUE_NAME) identifica únicamente cada database en configuración Data Guard
- Debe ser DIFERENTE entre primary y standby
- `DB_NAME` es el mismo (`cdb1`), pero `DB_UNIQUE_NAME` es único
- Data Guard Broker usa `DB_UNIQUE_NAME` para distinguir los nodos

---

## Archivo setEnv.sh Completo (Standby)

```bash
# Oracle Environment
export ORACLE_HOSTNAME=ol8-21-dg2.localdomain            # ⭐ Standby hostname
export ORACLE_UNQNAME=cdb1_stby                          # ⭐ DIFERENCIA CRÍTICA
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_SID=cdb1                                   # Mismo que primary
export DATA_DIR=/u01/oradata
export PDB_NAME=pdb1

# Software installation variables
export SOFTWARE_DIR=/u01/software
export DB_SOFTWARE=LINUX.X64_213000_db_home.zip

export PATH=${ORACLE_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:/lib:/usr/lib
export CLASSPATH=${ORACLE_HOME}/jlib:${ORACLE_HOME}/rdbms/jlib

export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

export TNS_ADMIN=${ORACLE_HOME}/network/admin
```

---

## Comparación Primary vs Standby

| Variable | Primary | Standby | ¿Diferente? |
|----------|---------|---------|-------------|
| ORACLE_HOSTNAME | ol8-21-dg1.localdomain | ol8-21-dg2.localdomain | ✅ |
| **ORACLE_UNQNAME** | **cdb1** | **cdb1_stby** | ✅ ⭐ |
| ORACLE_BASE | /u01/app/oracle | /u01/app/oracle | ❌ |
| ORACLE_HOME | /u01/.../dbhome_1 | /u01/.../dbhome_1 | ❌ |
| ORACLE_SID | cdb1 | cdb1 | ❌ |
| PDB_NAME | pdb1 | pdb1 | ❌ |
| PATH | $ORACLE_HOME/bin:... | $ORACLE_HOME/bin:... | ❌ |
| TNS_ADMIN | $ORACLE_HOME/network/admin | $ORACLE_HOME/network/admin | ❌ |

**Solo 2 variables son diferentes:**
1. `ORACLE_HOSTNAME` - Refleja el hostname del nodo
2. `ORACLE_UNQNAME` - ⭐ **CRÍTICO PARA DATA GUARD** ⭐

---

## Cómo se Usa ORACLE_UNQNAME

### En Configuración Data Guard Broker

```sql
-- Primary
ALTER SYSTEM SET db_unique_name='cdb1' SCOPE=SPFILE;

-- Standby
ALTER SYSTEM SET db_unique_name='cdb1_stby' SCOPE=SPFILE;  -- ⭐
```

### En RMAN DUPLICATE

```rman
duplicate target database
  for standby
  from active database
  dorecover
  spfile
    set db_unique_name='cdb1_stby' comment 'Is standby';  -- ⭐
```

### En Data Guard Broker Configuration

```dgmgrl
create configuration dg_config as
  primary database is cdb1                    -- Primary DB_UNIQUE_NAME
  connect identifier is cdb1.world;

add database cdb1_stby as                    -- ⭐ Standby DB_UNIQUE_NAME
  connect identifier is cdb1_stby.world
  maintained as physical;
```

### En Queries

```sql
-- Ver DB_UNIQUE_NAME de la database actual
SELECT name, db_unique_name FROM v$database;

-- Primary muestra:
NAME      DB_UNIQUE_NAME
--------- --------------
CDB1      cdb1

-- Standby muestra:
NAME      DB_UNIQUE_NAME
--------- --------------
CDB1      cdb1_stby      -- ⭐ DB_NAME igual, DB_UNIQUE_NAME diferente
```

---

## Directorios Creados

```bash
mkdir -p /home/oracle/scripts
mkdir -p /home/oracle/logs
```

**Propósito:**
- `/home/oracle/scripts/` - Almacena `setEnv.sh`
- `/home/oracle/logs/` - Logs de procedimientos, jobs, etc.

---

## Integración con .bash_profile

```bash
# Agregado a /home/oracle/.bash_profile
. /home/oracle/scripts/setEnv.sh
```

**Efecto:**
- Cada vez que oracle hace login (`su - oracle`), variables se cargan automáticamente
- No necesita hacer `source setEnv.sh` manualmente
- Disponibles en sesiones SSH interactivas

---

## Variables de Path

### PATH
```bash
export PATH=${ORACLE_HOME}/bin:${PATH}
```

**Agrega al PATH:**
- `sqlplus` - SQL*Plus client
- `rman` - Recovery Manager
- `lsnrctl` - Listener control
- `dgmgrl` - Data Guard Manager CLI
- `asmcmd` - ASM command (no usado en este proyecto)
- Cientos de utilidades Oracle

**Resultado:**
```bash
[oracle@ol8-21-dg2 ~]$ which sqlplus
/u01/app/oracle/product/21.0.0/dbhome_1/bin/sqlplus
```

### LD_LIBRARY_PATH
```bash
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:/lib:/usr/lib
```

**Propósito:**
- Librerías compartidas Oracle (`.so` files)
- Necesario para que binarios Oracle encuentren sus dependencias

### CLASSPATH
```bash
export CLASSPATH=${ORACLE_HOME}/jlib:${ORACLE_HOME}/rdbms/jlib
```

**Propósito:**
- Java classes para componentes Oracle (JDBC, etc.)

---

## Variables de Internacionalización

### NLS_DATE_FORMAT
```bash
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"
```

**Efecto en SQL*Plus:**
```sql
-- Sin NLS_DATE_FORMAT:
SELECT SYSDATE FROM dual;
SYSDATE
---------
04-NOV-25

-- Con NLS_DATE_FORMAT:
SELECT SYSDATE FROM dual;
SYSDATE
-------------------
2025-11-04 17:30:15
```

### NLS_LANG
```bash
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
```

**Componentes:**
- `AMERICAN` - Idioma (mensajes de error en inglés)
- `AMERICA` - Territory (formato de fecha/números)
- `AL32UTF8` - Character set (UTF-8, soporta todos los caracteres Unicode)

**Por qué AL32UTF8:**
- Compatible con caracteres españoles (ñ, á, é, etc.)
- Soporta caracteres de todos los idiomas
- Estándar moderno

---

## TNS_ADMIN

```bash
export TNS_ADMIN=${ORACLE_HOME}/network/admin
```

**Propósito:**
- Indica dónde buscar `tnsnames.ora`, `sqlnet.ora`, `listener.ora`
- Por defecto: `$ORACLE_HOME/network/admin`
- Puede cambiarse para usar configuración centralizada

**Archivos en esta ubicación (creados después):**
```
$TNS_ADMIN/
├── tnsnames.ora      # Service names (cdb1.world, cdb1_stby.world)
├── sqlnet.ora        # Network encryption, timeout, domain
└── listener.ora      # Listener configuration
```

---

## Verificación

### Como usuario oracle:
```bash
sudo su - oracle

# Variables cargadas automáticamente:
echo $ORACLE_HOME
# /u01/app/oracle/product/21.0.0/dbhome_1

echo $ORACLE_UNQNAME
# cdb1_stby  ⭐

echo $ORACLE_SID
# cdb1

# Comandos Oracle disponibles:
which sqlplus
which rman
which lsnrctl

# Ver todas las variables Oracle:
env | grep ORA
```

---

## Troubleshooting

### Problema: Variables no se cargan en login

```bash
su - oracle
echo $ORACLE_HOME
# (vacío)
```

**Solución:**
```bash
# Verificar que .bash_profile tiene el source
cat /home/oracle/.bash_profile | grep setEnv

# Si no está, agregarlo:
echo ". /home/oracle/scripts/setEnv.sh" >> /home/oracle/.bash_profile
```

### Problema: ORACLE_UNQNAME incorrecto

**Síntoma en standby:**
```sql
SQL> SELECT db_unique_name FROM v$database;
DB_UNIQUE_NAME
--------------
cdb1  -- ❌ INCORRECTO (debería ser cdb1_stby)
```

**Causa:**
- Se usó setEnv.sh de primary en standby
- O el script no se ejecutó correctamente

**Solución:**
```bash
# Re-ejecutar script de standby
sudo su - oracle
sh /vagrant/2-Standby/scripts/standby/oracle_user_environment_setup.sh

# Verificar contenido
grep ORACLE_UNQNAME /home/oracle/scripts/setEnv.sh
# Debe mostrar: export ORACLE_UNQNAME=cdb1_stby

# Re-cargar
. /home/oracle/scripts/setEnv.sh
```

---

## Resumen

### Variable Más Crítica

```bash
export ORACLE_UNQNAME=cdb1_stby  # ⭐⭐⭐
```

**Si esta variable está mal:**
- Data Guard Broker no puede distinguir los nodos
- Configuración de standby falla
- No se puede crear la configuración DG

### Diferencias con Primary

Solo **2 variables** son diferentes:
1. `ORACLE_HOSTNAME` - Hostname del nodo
2. `ORACLE_UNQNAME` - **DB_UNIQUE_NAME** (cdb1 vs cdb1_stby)

Todo lo demás es idéntico.

---

**Siguiente:** [56 - Instalación de Oracle Software](56-install-oracle.md)
