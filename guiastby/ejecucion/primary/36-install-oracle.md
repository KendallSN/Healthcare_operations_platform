# 36 - Install Oracle - Instalación de Software Oracle 21c

## Instalación Silenciosa de Oracle Database 21c Enterprise Edition

Este script instala el software de Oracle Database 21c en modo "Software Only" (sin crear base de datos todavía). Descomprime el archivo ZIP de Oracle directamente en ORACLE_HOME y ejecuta el instalador en modo silencioso usando un response file.

## Ubicación

`2-Standby/infrastructure/oracle_db_software_installation.sh`

**Nota:** Este es un **shared script** usado tanto por primary como standby.

## Propósito

- **Función principal:** Instalar binarios de Oracle Database 21c
- **Responsabilidad:** Descompresión, instalación silenciosa, generación de response file
- **Modo:** Software Only (no incluye creación de base de datos)

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 10 de 12 en el despliegue primario
- **Usuario:** `oracle` (NUNCA como root)
- **Duración:** 15-20 minutos (depende de velocidad de disco)

## Variables de Entorno Utilizadas

Cargadas desde `setEnv.sh`:

```bash
SOFTWARE_DIR=/u01/software                          # Donde está el ZIP
DB_SOFTWARE=LINUX.X64_213000_db_home.zip           # Archivo ZIP Oracle
ORACLE_HOME=/u01/app/oracle/product/21.0.0/dbhome_1  # Destino instalación
ORACLE_BASE=/u01/app/oracle                        # Base Oracle
ORA_INVENTORY=/u01/app/oraInventory                # Inventario
```

## Flujo de Ejecución Paso a Paso

### Paso 1: Cargar Variables de Entorno

```bash
. /home/oracle/scripts/setEnv.sh
```

**Explicación:**
- Carga ORACLE_HOME, SOFTWARE_DIR, etc.
- Esencial para que el script sepa dónde instalar

### Paso 2: Copiar Software Oracle a Directorio Local

```bash
echo "Copying Oracle software from shared directory..."
cp /vagrant_software/${DB_SOFTWARE} ${SOFTWARE_DIR}/
cd ${SOFTWARE_DIR}
```

**Explicación:**
- `/vagrant_software/`: Synced folder con software Oracle (desde Windows)
- Copia a `/u01/software/` (local en la VM)
- **¿Por qué copiar?** Descomprimir desde synced folder es LENTO (problema de VirtualBox)
- Copiar primero, luego descomprimir localmente es ~10x más rápido

**Duración del copy:** 2-3 minutos (2.9 GB)

### Paso 3: Descomprimir Oracle Software en ORACLE_HOME

```bash
echo "Unzipping Oracle software into ORACLE_HOME..."
cd ${ORACLE_HOME}
unzip -oq ${SOFTWARE_DIR}/${DB_SOFTWARE}
```

**Explicación:**
- **Cambio importante en Oracle 21c:** Se descomprime DIRECTAMENTE en ORACLE_HOME
- En versiones antiguas: descomprimir y luego instalar
- En 21c: descomprimir = instalar (casi)
- `-o`: Overwrite files (sin preguntar)
- `-q`: Quiet mode (menos output)

**Contenido descomprimido:**
```
$ORACLE_HOME/
├── bin/          # Binarios ejecutables (sqlplus, lsnrctl, rman)
├── lib/          # Librerías compartidas
├── network/      # Configuración de red
│   └── admin/    # tnsnames.ora, listener.ora (vacíos inicialmente)
├── rdbms/        # Archivos del RDBMS
├── jlib/         # Java libraries
├── oracore/      # Core libraries
├── install/      # Scripts de instalación
├── runInstaller  # Instalador
└── ...
```

**Duración:** 10-12 minutos

### Paso 4: Crear Response File para Instalación Silenciosa

```bash
cat > /tmp/db_install.rsp << EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v21.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ORA_INVENTORY}
ORACLE_HOME=${ORACLE_HOME}
ORACLE_BASE=${ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=dba
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
EOF
```

**Parámetros explicados:**

**Versión y modo:**
- `responseFileVersion`: Versión del formato de response file (21.0.0)
- `oracle.install.option=INSTALL_DB_SWONLY`: Instalar solo software, sin crear DB

**Grupos y ownership:**
- `UNIX_GROUP_NAME=oinstall`: Grupo de instalación
- `INVENTORY_LOCATION`: Donde se registra inventario de productos Oracle
- `ORACLE_HOME`: Ruta de instalación
- `ORACLE_BASE`: Base de Oracle

**Edición:**
- `InstallEdition=EE`: Enterprise Edition (incluye Data Guard, Partitioning, etc.)
- Alternativas: SE2 (Standard Edition 2), PE (Personal Edition)

**Grupos por privilegio:**
- `OSDBA_GROUP=dba`: SYSDBA privilege (admin completo)
- `OSOPER_GROUP=oper`: SYSOPER privilege (operaciones sin ver datos)
- `OSBACKUPDBA_GROUP=backupdba`: SYSBACKUP privilege
- `OSDGDBA_GROUP=dgdba`: SYSDG privilege (Data Guard)
- `OSKMDBA_GROUP=kmdba`: SYSKM privilege (Key Management)
- `OSRACDBA_GROUP=dba`: SYSRAC privilege (RAC admin)

**Security updates:**
- `SECURITY_UPDATES_VIA_MYORACLESUPPORT=false`: No configurar My Oracle Support
- `DECLINE_SECURITY_UPDATES=true`: No recibir notificaciones de seguridad

### Paso 5: Ejecutar Instalador en Modo Silencioso

```bash
echo "Running Oracle installer..."
${ORACLE_HOME}/runInstaller -ignorePrereq -waitforcompletion -silent \
  -responseFile /tmp/db_install.rsp
```

**Opciones del instalador:**
- `-ignorePrereq`: Ignora prerequisite checks (ya cumplidos con oracle-database-preinstall-21c)
- `-waitforcompletion`: Espera a que instalación complete (no background)
- `-silent`: Modo no interactivo (usa response file)
- `-responseFile`: Especifica archivo de respuestas

**Salida esperada:**
```
Launching Oracle Database Setup Wizard...

[WARNING] [INS-13014] Target environment does not meet some optional requirements.
   CAUSE: Some of the optional prerequisites are not met...
   ACTION: ...

The response file for this session can be found at:
 /u01/app/oracle/product/21.0.0/dbhome_1/install/response/db_2025-11-04_02-35-22PM.rsp

You can find the log of this install session at:
 /u01/app/oraInventory/logs/InstallActions2025-11-04_02-35-22PM.log

As a root user, execute the following script(s):
        1. /u01/app/oraInventory/orainstRoot.sh
        2. /u01/app/oracle/product/21.0.0/dbhome_1/root.sh

Successfully Setup Software with warning(s).
```

**Duración:** 3-5 minutos

### Paso 6: Mensaje para Ejecutar Root Scripts

```bash
echo "******************************************************************************"
echo "Oracle software installation complete." `date`
echo "******************************************************************************"
echo "Run these commands as root:"
echo "  ${ORA_INVENTORY}/orainstRoot.sh"
echo "  ${ORACLE_HOME}/root.sh"
```

**Explicación:**
- Scripts root DEBEN ejecutarse como root (no como oracle)
- root_setup.sh los ejecuta en el paso siguiente
- Si se olvidan, Oracle no funcionará correctamente

## Archivos Creados/Modificados

### Oracle Software

| Directorio/Archivo | Descripción | Tamaño Aproximado |
|-------------------|-------------|-------------------|
| `$ORACLE_HOME/` | Todos los binarios y librerías Oracle | ~8 GB |
| `$ORACLE_HOME/bin/` | Ejecutables (sqlplus, rman, lsnrctl, etc.) | ~500 MB |
| `$ORACLE_HOME/lib/` | Librerías compartidas (.so) | ~2 GB |
| `$ORACLE_HOME/rdbms/` | Core RDBMS files | ~3 GB |
| `$ORA_INVENTORY/` | Inventario de productos Oracle | ~50 MB |

### Logs de Instalación

| Archivo | Descripción |
|---------|-------------|
| `$ORA_INVENTORY/logs/InstallActions*.log` | Log detallado de instalación |
| `$ORACLE_HOME/install/response/db_*.rsp` | Response file usado (backup) |
| `$ORACLE_HOME/cfgtoollogs/` | Logs de herramientas de configuración |

## Root Scripts que Deben Ejecutarse Después

### 1. orainstRoot.sh

```bash
sh ${ORA_INVENTORY}/orainstRoot.sh
```

**Qué hace:**
- Configura permisos del inventario Oracle
- Crea grupo `oinstall` en nivel sistema (si no existe)
- Establece `/etc/oraInst.loc` con ubicación del inventario

**Contenido de /etc/oraInst.loc:**
```
inventory_loc=/u01/app/oraInventory
inst_group=oinstall
```

### 2. root.sh

```bash
sh ${ORACLE_HOME}/root.sh
```

**Qué hace:**
- Configura permisos especiales en binarios Oracle
- Setea capabilities para acceso a memoria (extjob, oradism)
- Configura dbhome entry
- Crea archivo `/etc/oratab` (registro de databases)

**Contenido inicial de /etc/oratab:**
```
# /etc/oratab
# Database SID:ORACLE_HOME:Auto-start flag
```

## Dependencias

### Prerequisitos

**Antes de este script:**
1. Usuario `oracle` y grupo `oinstall` deben existir
2. `setEnv.sh` debe estar creado y cargado
3. Directorios `/u01/app/oracle`, `/u01/oradata` deben existir
4. Oracle software ZIP debe estar en `/vagrant_software/`
5. Kernel parameters deben estar configurados

### Software Requerido

- Oracle Database 21c (3.0 GB): `LINUX.X64_213000_db_home.zip`
- Espacio en `/u01`: ~15 GB libres (8 GB software + 5 GB temporal)

## Logs y Verificación

### Verificar Instalación Exitosa

```bash
# Como usuario oracle
. /home/oracle/scripts/setEnv.sh

# Verificar que binarios están presentes
ls -lh $ORACLE_HOME/bin/sqlplus
ls -lh $ORACLE_HOME/bin/rman
ls -lh $ORACLE_HOME/bin/lsnrctl

# Verificar versión de Oracle
$ORACLE_HOME/bin/sqlplus -version
# Output: SQL*Plus: Release 21.0.0.0.0 - Production

# Verificar inventario
cat $ORA_INVENTORY/ContentsXML/inventory.xml
```

### Verificar Root Scripts Ejecutados

```bash
# Verificar oraInst.loc
cat /etc/oraInst.loc

# Verificar oratab
cat /etc/oratab

# Verificar permisos de extjob (debe tener setuid)
ls -l $ORACLE_HOME/bin/extjob
# -rwsr-x--- (s significa setuid)
```

### Logs de Instalación

```bash
# Ver log principal de instalación
tail -100 $ORA_INVENTORY/logs/InstallActions*

# Buscar errores
grep -i error $ORA_INVENTORY/logs/InstallActions*
grep -i warning $ORA_INVENTORY/logs/InstallActions*
```

## Puntos de Fallo Comunes

### 1. Espacio Insuficiente en /u01

**Error:**
```
[FATAL] Insufficient disk space: /u01
Required: 15000 MB
Available: 5000 MB
```

**Solución:**
```bash
# Verificar espacio
df -h /u01

# Aumentar tamaño de disco en Vagrantfile
# vb.customize ["modifyhd", "u01-primary.vdi", "--resize", 204800]  # 200 GB
```

### 2. runInstaller No Ejecutable

**Error:**
```
bash: /u01/app/oracle/.../runInstaller: Permission denied
```

**Causa:** Permisos incorrectos después de unzip

**Solución:**
```bash
chmod +x $ORACLE_HOME/runInstaller
# O re-ejecutar unzip que debería preservar permisos
```

### 3. Instalación como Root (ERROR CRÍTICO)

**Error:**
```
[FATAL] Oracle software installation should not be performed as root user
```

**Causa:** Script ejecutado como root en lugar de oracle

**Solución:**
- SIEMPRE ejecutar como usuario oracle
- root_setup.sh usa `su - oracle -c` correctamente

### 4. ORACLE_HOME No Vacío

**Error:**
```
[FATAL] The Oracle home directory '/u01/app/oracle/product/...' already contains an Oracle installation
```

**Causa:** Instalación previa no limpiada

**Solución:**
```bash
# Como oracle
rm -rf $ORACLE_HOME/*
# Luego re-ejecutar instalación
```

### 5. Response File con Errores

**Error:**
```
[FATAL] INVENTORY_LOCATION not specified in response file
```

**Causa:** Response file mal formado o variable no expandida

**Solución:**
```bash
# Verificar que response file tiene valores correctos
cat /tmp/db_install.rsp
# Todas las variables deben estar expandidas (no ${VAR})
```

## Importancia para Data Guard

### Enterprise Edition Requerida

```bash
oracle.install.db.InstallEdition=EE
```

**Data Guard NO está disponible en Standard Edition 2.**

**Features EE usados en Data Guard:**
- Data Guard (obvio)
- Flashback Database
- Active Data Guard (opcional, para read-only queries en standby)
- Fast-Start Failover (opcional)
- Compression para archive log transport (opcional)

### Grupos OSDGDBA

```bash
oracle.install.db.OSDGDBA_GROUP=dgdba
```

**SYSDG privilege** permite:
- Gestionar configuración Data Guard
- Switchover/failover
- Cambiar protection modes
- Sin acceso a datos de aplicación (más seguro que SYSDBA)

**Uso:**
```bash
sqlplus sys/password as sysdg
dgmgrl sys/password
```

### OSBACKUPDBA para RMAN

```bash
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
```

**SYSBACKUP privilege** permite:
- Ejecutar RMAN backups
- Sin acceso a datos de aplicación
- Requerido para backups automatizados con cron jobs

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Ejecuta root scripts después de este
- **[35 - Oracle User Environment](35-oracle-user-env.md)** - Configura variables usadas aquí
- **[37 - Create Database](37-create-database.md)** - Usa binarios instalados aquí
- **[56 - Standby Install Oracle](../standby/56-install-oracle.md)** - Mismo script en standby

### Documentación de Contexto

- **[03 - Prerequisitos](../../03-prerequisitos.md)** - Descargar Oracle software
- **[02 - Conceptos Fundamentales](../../02-conceptos-fundamentales.md)** - Arquitectura Oracle

## Diferencia con Instalaciones Anteriores

### Oracle 19c y Anteriores

```bash
# Descomprimir en directorio temporal
unzip LINUX.X64_190000_db_home.zip -d /tmp/oracle_install

# Ejecutar installer desde directorio temporal
/tmp/oracle_install/runInstaller -responseFile ...

# Copiar archivos a ORACLE_HOME durante instalación
```

### Oracle 21c (Usado Aquí)

```bash
# Descomprimir DIRECTAMENTE en ORACLE_HOME
cd $ORACLE_HOME
unzip LINUX.X64_213000_db_home.zip

# Ejecutar installer desde ORACLE_HOME
$ORACLE_HOME/runInstaller -responseFile ...

# Instalación "in-place" - archivos ya están en ORACLE_HOME
```

**Ventaja:** Más rápido, menos espacio temporal requerido

## Código Fuente Completo

Ver archivo: `2-Standby/infrastructure/oracle_db_software_installation.sh` (50 líneas)

---

**Siguiente:** [37 - Create Database](37-create-database.md) ⭐ **DOCUMENTO CRÍTICO** - Creación de base de datos con configuración completa de Data Guard.
