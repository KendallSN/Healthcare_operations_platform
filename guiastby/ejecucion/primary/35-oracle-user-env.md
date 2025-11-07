# 35 - Oracle User Environment - Configuración de Entorno Oracle

## Configuración de Variables de Entorno para Usuario Oracle

Este script crea el archivo `setEnv.sh` que define todas las variables de entorno necesarias para que el usuario `oracle` pueda ejecutar comandos de Oracle Database. También configura `.bash_profile` para cargar estas variables automáticamente en cada login.

## Ubicación

`2-Standby/scripts/primary/oracle_user_environment_setup.sh`

**Nota:** Este es un script **específico de primary** (standby tiene su propia versión con db_unique_name diferente).

## Propósito

- **Función principal:** Crear script setEnv.sh con variables de entorno Oracle
- **Responsabilidad:** Configurar PATH, ORACLE_HOME, ORACLE_SID y otras variables críticas
- **Automatización:** Cargar variables automáticamente en cada sesión shell

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 9 de 12 en el despliegue primario
- **Usuario:** `oracle` (ejecutado via `su - oracle -c`)
- **Duración:** 5-10 segundos

## Variables de Entorno Utilizadas

Cargadas desde `install.env`:

```bash
NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain    # Hostname del primary
NODE1_DB_UNIQUE_NAME=cdb1                   # Unique name del primary
ORACLE_BASE=/u01/app/oracle                 # Base de instalación Oracle
ORACLE_HOME_EXT=product/21.0.0/dbhome_1     # Extensión de ORACLE_HOME
ORA_INVENTORY=/u01/app/oraInventory         # Oracle inventory
ORACLE_SID=cdb1                             # SID de la instancia
DATA_DIR=/u01/oradata                       # Directorio de datafiles
PDB_NAME=pdb1                               # Nombre del PDB
SOFTWARE_DIR=/u01/software                  # Directorio de software Oracle
DB_SOFTWARE=LINUX.X64_213000_db_home.zip    # Archivo zip de Oracle
```

## Flujo de Ejecución Paso a Paso

### Paso 1: Cargar Variables de Configuración

```bash
. /vagrant_config/install.env
```

### Paso 2: Crear Directorios de Usuario Oracle

```bash
mkdir -p /home/oracle/scripts
mkdir -p /home/oracle/logs
```

**Explicación:**
- `/home/oracle/scripts/`: Para scripts personalizados (setEnv.sh, otros)
- `/home/oracle/logs/`: Para logs de operaciones manuales

### Paso 3: Crear Script setEnv.sh

```bash
cat > /home/oracle/scripts/setEnv.sh << EOF
# Oracle Environment
export ORACLE_HOSTNAME=${NODE1_FQ_HOSTNAME}
export ORACLE_UNQNAME=${NODE1_DB_UNIQUE_NAME}
export ORACLE_BASE=${ORACLE_BASE}
export ORACLE_HOME=${ORACLE_BASE}/${ORACLE_HOME_EXT}
export ORA_INVENTORY=${ORA_INVENTORY}
export ORACLE_SID=${ORACLE_SID}
export DATA_DIR=${DATA_DIR}
export PDB_NAME=${PDB_NAME}

# Software installation variables
export SOFTWARE_DIR=${SOFTWARE_DIR}
export DB_SOFTWARE=${DB_SOFTWARE}

export PATH=\${ORACLE_HOME}/bin:\${PATH}
export LD_LIBRARY_PATH=\${ORACLE_HOME}/lib:/lib:/usr/lib
export CLASSPATH=\${ORACLE_HOME}/jlib:\${ORACLE_HOME}/rdbms/jlib

export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

export TNS_ADMIN=\${ORACLE_HOME}/network/admin
EOF
```

**Variables exportadas explicadas:**

**Variables de identificación:**
- `ORACLE_HOSTNAME`: Hostname completo (para listener/TNS)
- `ORACLE_UNQNAME`: Unique name de la DB (cdb1 para primary)
- `ORACLE_SID`: SID de la instancia (cdb1)

**Rutas de Oracle:**
- `ORACLE_BASE`: Directorio base Oracle (/u01/app/oracle)
- `ORACLE_HOME`: Home completo (/u01/app/oracle/product/21.0.0/dbhome_1)
- `ORA_INVENTORY`: Inventario de productos Oracle
- `DATA_DIR`: Donde se crean datafiles
- `TNS_ADMIN`: Configuración de red (tnsnames.ora, listener.ora)

**Variables del sistema:**
- `PATH`: Agrega $ORACLE_HOME/bin para ejecutar sqlplus, lsnrctl, rman, etc.
- `LD_LIBRARY_PATH`: Librerías compartidas de Oracle
- `CLASSPATH`: JARs de Oracle (para Java stored procedures)

**Formato y locale:**
- `NLS_DATE_FORMAT`: Formato de fechas (YYYY-MM-DD HH24:MI:SS)
- `NLS_LANG`: Locale y character set (AL32UTF8 = UTF-8)

**Escape de variables:**
- `\${ORACLE_HOME}`: Escapa $ para que se expanda en runtime, no durante creación del archivo
- `${ORACLE_BASE}`: Sin escape, se expande con valor de install.env

### Paso 4: Agregar setEnv.sh a .bash_profile

```bash
echo ". /home/oracle/scripts/setEnv.sh" >> /home/oracle/.bash_profile
```

**Explicación:**
- Agrega source de setEnv.sh al profile de usuario oracle
- Se ejecuta automáticamente en cada login
- Usuario oracle siempre tiene variables correctas

### Paso 5: Cargar Variables en Contexto Actual

```bash
. /home/oracle/scripts/setEnv.sh
```

**Explicación:**
- Carga variables en la sesión actual del script
- Permite usar variables en pasos siguientes del script

### Paso 6: Crear Directorios Oracle

```bash
mkdir -p ${ORACLE_HOME}
mkdir -p ${DATA_DIR}
```

**Explicación:**
- Crea ORACLE_HOME (donde se instalará software)
- Crea DATA_DIR (donde se crearán datafiles)

### Paso 7: Establecer Ownership

```bash
chown -R oracle:oinstall /home/oracle/scripts
chown -R oracle:oinstall /home/oracle/logs
chown oracle:oinstall /home/oracle/.bash_profile
```

**Explicación:**
- Asegura que usuario oracle es owner de sus archivos
- Grupo oinstall (grupo de instalación Oracle)

## Archivos Creados/Modificados

| Archivo/Directorio | Descripción |
|-------------------|-------------|
| `/home/oracle/scripts/` | Directorio para scripts |
| `/home/oracle/scripts/setEnv.sh` | Variables de entorno Oracle (principal) |
| `/home/oracle/logs/` | Directorio para logs |
| `/home/oracle/.bash_profile` | Modificado para source setEnv.sh |
| `${ORACLE_HOME}` | Creado vacío (se llenará en instalación) |
| `${DATA_DIR}` | Creado vacío (se llenará en creación de DB) |

## Contenido Completo de setEnv.sh

Después de expansión de variables, el archivo contiene:

```bash
# Oracle Environment
export ORACLE_HOSTNAME=ol8-21-dg1.localdomain
export ORACLE_UNQNAME=cdb1
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_SID=cdb1
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

## Verificación

### Verificar que setEnv.sh fue Creado

```bash
vagrant ssh primary -c "cat /home/oracle/scripts/setEnv.sh"
```

### Verificar Variables en Sesión Oracle

```bash
vagrant ssh primary
sudo su - oracle

# Variables deberían estar cargadas automáticamente
echo $ORACLE_HOME
echo $ORACLE_SID
echo $PATH | grep oracle

# Verificar todas las variables Oracle
env | grep ORACLE
env | grep TNS
```

### Probar Comando Oracle (después de instalación)

```bash
sudo su - oracle
which sqlplus
# Output: /u01/app/oracle/product/21.0.0/dbhome_1/bin/sqlplus

sqlplus / as sysdba
# Debe conectar sin error (después de que DB esté creada)
```

## Dependencias

### Prerequisitos

- Usuario `oracle` debe existir (creado por oracle-database-preinstall-21c)
- Grupo `oinstall` debe existir
- Directorios `/u01/app/oracle` deben existir (creados por root_setup.sh)

### Scripts que Usan setEnv.sh

Después de este script, TODOS los scripts que se ejecutan como usuario oracle cargan setEnv.sh:

```bash
# Patrón usado en scripts posteriores
. /home/oracle/scripts/setEnv.sh

# Ejemplo en oracle_db_software_installation.sh
. /home/oracle/scripts/setEnv.sh
cd ${SOFTWARE_DIR}
unzip -oq ${SOFTWARE_DIR}/${DB_SOFTWARE}
```

## Puntos de Fallo Comunes

### 1. Variables No Se Cargan en Nueva Sesión

**Síntoma:**
```bash
sudo su - oracle
echo $ORACLE_HOME
# (vacío)
```

**Causa:** .bash_profile no se ejecutó

**Solución:**
```bash
# Verificar que .bash_profile tiene la línea correcta
cat /home/oracle/.bash_profile | grep setEnv

# Si falta, agregar manualmente
echo ". /home/oracle/scripts/setEnv.sh" >> /home/oracle/.bash_profile

# Recargar
source ~/.bash_profile
```

### 2. ORACLE_HOME Incorrecto

**Síntoma:**
```bash
sqlplus: command not found
```

**Causa:** ORACLE_HOME no apunta a directorio correcto o no está en PATH

**Solución:**
```bash
# Verificar ORACLE_HOME
ls $ORACLE_HOME/bin
# Debe listar: sqlplus, lsnrctl, rman, etc.

# Si está vacío, verificar setEnv.sh
cat /home/oracle/scripts/setEnv.sh | grep ORACLE_HOME

# Re-source
. /home/oracle/scripts/setEnv.sh
```

### 3. Permisos Incorrectos

**Síntoma:**
```bash
-bash: /home/oracle/scripts/setEnv.sh: Permission denied
```

**Causa:** Ownership o permisos incorrectos

**Solución:**
```bash
# Como root
chown oracle:oinstall /home/oracle/scripts/setEnv.sh
chmod 755 /home/oracle/scripts/setEnv.sh
```

### 4. Variables Se Pierden al Usar sudo

**Síntoma:**
```bash
# Como vagrant
sudo sqlplus / as sysdba
# ORA-12162: TNS:net service name is incorrectly specified
```

**Causa:** `sudo` no preserva variables de entorno por defecto

**Solución:**
```bash
# Opción 1: usar su - oracle (recomendado)
sudo su - oracle -c "sqlplus / as sysdba"

# Opción 2: usar sudo -E (preserva environment)
sudo -E -u oracle sqlplus / as sysdba

# Opción 3: source setEnv.sh en cada comando
sudo su - oracle -c ". /home/oracle/scripts/setEnv.sh && sqlplus / as sysdba"
```

## Importancia para Data Guard

### Variables Críticas para Data Guard

**ORACLE_HOSTNAME:**
```bash
export ORACLE_HOSTNAME=ol8-21-dg1.localdomain
```
- Usado en listener.ora
- Usado en tnsnames.ora
- Data Guard Broker lo usa para identificar el nodo

**ORACLE_UNQNAME:**
```bash
export ORACLE_UNQNAME=cdb1  # Primary
# vs
export ORACLE_UNQNAME=cdb1_stby  # Standby
```
- Identifica la base de datos en configuración Data Guard
- Usado en DG_CONFIG parameter
- Diferente entre primary y standby

**TNS_ADMIN:**
```bash
export TNS_ADMIN=${ORACLE_HOME}/network/admin
```
- Especifica dónde buscar tnsnames.ora y listener.ora
- Crítico para conectividad entre primary y standby

### NLS_LANG para Replicación

```bash
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
```

**Importancia:**
- **AL32UTF8** es el character set Unicode completo
- Debe ser idéntico en primary y standby
- Character set mismatch causa errores de apply en standby

**Errores comunes si NLS_LANG es diferente:**
```
ORA-12704: character set mismatch
ORA-26040: Data block was loaded using the NOLOGGING option
```

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador que llama a este script
- **[36 - Install Oracle](36-install-oracle.md)** - Usa variables definidas aquí
- **[37 - Create Database](37-create-database.md)** - Usa ORACLE_SID, ORACLE_HOME, etc.
- **[55 - Standby Oracle User Env](../standby/55-oracle-user-env.md)** - Versión standby (ORACLE_UNQNAME diferente)

### Documentación de Contexto

- **[02 - Conceptos Fundamentales](../../02-conceptos-fundamentales.md)** - Variables Oracle explicadas
- **[80 - Oracle CDB/PDB](../../conceptos-avanzados/80-oracle-cdb-pdb.md)** - Arquitectura Oracle

## Mejoras Futuras Posibles

1. **Aliases útiles:**
```bash
alias alert='tail -f $ORACLE_BASE/diag/rdbms/$ORACLE_UNQNAME/$ORACLE_SID/trace/alert_$ORACLE_SID.log'
alias sqlplus='rlwrap sqlplus'  # Con history
alias dgmgrl='rlwrap dgmgrl'
```

2. **Prompt personalizado:**
```bash
export PS1='[\u@\h:$ORACLE_SID]\$ '
# Muestra SID en prompt: [oracle@ol8-21-dg1:cdb1]$
```

3. **Validación de variables:**
```bash
# Al final de setEnv.sh
if [ ! -d "$ORACLE_HOME" ]; then
  echo "WARNING: ORACLE_HOME does not exist: $ORACLE_HOME"
fi
```

## Código Fuente Completo

Ver archivo: `2-Standby/scripts/primary/oracle_user_environment_setup.sh` (56 líneas)

---

**Siguiente:** [36 - Install Oracle](36-install-oracle.md) - Instalación del software Oracle Database 21c.
