# 56 - Instalación de Oracle Database Software (Standby)

## Descripción General

**Archivo:** `2-Standby/infrastructure/oracle_db_software_installation.sh`

**Propósito:** Instalar el software de Oracle Database 21c Enterprise Edition en modo "software only" (sin crear database).

**Compartido:** Este script es IDÉNTICO entre primary y standby.

**Tiempo de ejecución:** 10-15 minutos

---

## Diferencia con Primary

**NINGUNA** - Script completamente idéntico.

Ambos nodos instalan exactamente el mismo software Oracle Database 21c.

La diferencia viene DESPUÉS:
- **Primary:** Usa `dbca` para crear una database nueva
- **Standby:** Usa `rman duplicate` para copiar la database desde primary ⭐

---

## Proceso de Instalación

### 1. Copiar Software
```bash
cp /vagrant_software/${DB_SOFTWARE} ${SOFTWARE_DIR}/
# Copia: LINUX.X64_213000_db_home.zip (2.9 GB)
# Desde: /vagrant_software/ (synced folder)
# Hacia: /u01/software/
```

### 2. Descomprimir en ORACLE_HOME
```bash
cd ${ORACLE_HOME}
unzip -q ${SOFTWARE_DIR}/${DB_SOFTWARE}
```
**Tiempo:** 3-5 minutos
**Resultado:** ~9000 archivos descomprimidos en `$ORACLE_HOME`

### 3. Ejecutar Instalador en Modo Silent
```bash
${ORACLE_HOME}/runInstaller -silent -responseFile ${ORACLE_HOME}/install/response/db_install.rsp \
    oracle.install.option=INSTALL_DB_SWONLY \
    UNIX_GROUP_NAME=oinstall \
    INVENTORY_LOCATION=${ORA_INVENTORY} \
    ORACLE_HOME=${ORACLE_HOME} \
    ORACLE_BASE=${ORACLE_BASE} \
    oracle.install.db.InstallEdition=EE \
    oracle.install.db.OSDBA_GROUP=dba \
    oracle.install.db.OSBACKUPDBA_GROUP=dba \
    oracle.install.db.OSDGDBA_GROUP=dba \
    oracle.install.db.OSKMDBA_GROUP=dba \
    oracle.install.db.OSRACDBA_GROUP=dba \
    -waitForCompletion -ignorePrereq
```

**Parámetros clave:**
- `INSTALL_DB_SWONLY` - ⭐ Software only, no crear database
- `-silent` - No UI (headless)
- `-waitForCompletion` - Esperar a que termine
- `EE` - Enterprise Edition

**Tiempo:** 7-10 minutos

---

## Post-Instalación: Root Scripts

Ejecutados por `root_setup.sh` después de la instalación:

### 1. orainstRoot.sh
```bash
sh /u01/app/oraInventory/orainstRoot.sh
```

**Qué hace:**
- Configura Oracle Inventory central
- Establece permisos correctos
- Solo necesita ejecutarse una vez por servidor

### 2. root.sh
```bash
sh /u01/app/oracle/product/21.0.0/dbhome_1/root.sh
```

**Qué hace:**
- Configura Oracle Home
- Crea `/etc/oratab`:
  ```
  # Esta database no se agrega aún (se hace después de crear DB)
  ```
- Configura scripts de inicio (dbstart/dbshut)

---

## Verificación

```bash
# Software instalado correctamente
ls -l ${ORACLE_HOME}/bin/oracle
# Debe existir y ser ejecutable

# Version de Oracle
${ORACLE_HOME}/bin/sqlplus -version
# SQL*Plus: Release 21.0.0.0.0 - Production

# Inventory actualizado
cat ${ORA_INVENTORY}/ContentsXML/inventory.xml
# Debe listar el ORACLE_HOME
```

---

## Lo Que NO Se Ha Creado Aún

Después de esta etapa, tenemos:
- ✅ Software Oracle instalado
- ❌ **NO** hay database creada
- ❌ **NO** hay listener configurado
- ❌ **NO** hay network files (tnsnames.ora, etc.)
- ❌ **NO** hay datafiles, control files, redo logs

**Todo esto se crea en la siguiente etapa (57).**

---

## Referencia

Para análisis completo de este script:
Ver `guiastby/ejecucion/primary/36-install-oracle.md`

**El script es IDÉNTICO.**

---

**Siguiente:** [57 - 🔥 RMAN DUPLICATE - Creación de Standby Database 🔥](57-rman-duplicate.md)

**ESTA ES LA ETAPA MÁS CRÍTICA E IMPORTANTE DE TODO EL DESPLIEGUE STANDBY.**
