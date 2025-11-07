# 52 - Preparar Discos en Standby

## Descripción General

**Archivo:** `2-Standby/infrastructure/prepare_u01_u02_disks.sh`

**Propósito:** Preparar los discos `/dev/sdb` y `/dev/sdc` para almacenar Oracle software, databases y backups.

**Compartido:** Este script es IDÉNTICO entre primary y standby.

**Tiempo de ejecución:** ~30 segundos

---

## Diferencia con Primary

**NINGUNA** - Este script es exactamente el mismo.

La única diferencia es que en standby se crea un directorio adicional:

```bash
# En root_setup.sh después de prepare_disks:
mkdir -p /u02/backup_from_primary
```

Este directorio (`/u02/backup_from_primary/`) es donde standby recibe los backups RMAN transferidos desde primary vía rsync.

---

## Estructura de Directorios Creada

### /u01 (100 GB) - Oracle Base

```
/u01/
├── app/
│   ├── oracle/                    # ORACLE_BASE
│   │   ├── product/
│   │   │   └── 21.0.0/
│   │   │       └── dbhome_1/      # ORACLE_HOME (instalación Oracle)
│   │   ├── admin/
│   │   │   └── cdb1/
│   │   │       └── adump/         # Audit files
│   │   └── fast_recovery_area/    # FRA (alternativa)
│   │
│   └── oraInventory/              # ORA_INVENTORY (inventario central)
│
├── oradata/                       # DATA_DIR
│   └── CDB1/                      # Mayúscula por convención Oracle
│       ├── system01.dbf           # System tablespace
│       ├── sysaux01.dbf
│       ├── undotbs01.dbf
│       ├── users01.dbf
│       ├── temp01.dbf
│       ├── control01.ctl          # Control file 1
│       ├── redo01.log             # Online redo logs
│       ├── redo02.log
│       ├── redo03.log
│       ├── arch/                  # Archive logs standby
│       ├── pdbseed/               # PDB$SEED
│       └── pdb1/                  # PDB1 (healthcare schema)
│
└── software/                      # Staging para instaladores
```

### /u02 (100 GB) - Backups y FRA

```
/u02/
├── backup/                        # En PRIMARY: backups RMAN locales
│                                  # En STANDBY: vacío (no hace backups)
│
├── backup_from_primary/           # ⭐ SOLO EN STANDBY
│   └── [backups rsync desde primary]
│
└── fast_recovery_area/            # Fast Recovery Area (FRA)
    └── cdb1/  (o cdb1_stby en standby)
        ├── archivelog/            # Archive logs FRA
        ├── backupset/             # Backup sets
        ├── flashback/             # Flashback logs ⭐
        ├── onlinelog/             # Standby redo logs
        └── controlfile/           # Control file autobackups
```

---

## Operaciones Realizadas

### 1. Particionar Disco /dev/sdb → /u01

```bash
echo -e "n\np\n1\n\n\nw" | fdisk /dev/sdb
```

**Comandos fdisk:**
- `n` - Nueva partición
- `p` - Primaria
- `1` - Número de partición
- (default) - Primer sector (inicio del disco)
- (default) - Último sector (fin del disco)
- `w` - Write (guardar cambios)

**Resultado:** `/dev/sdb1` (partición de 100GB)

### 2. Formatear con XFS

```bash
mkfs.xfs -f /dev/sdb1
```

**Por qué XFS:**
- Alto rendimiento para archivos grandes (datafiles de GB)
- Excelente para I/O secuencial (redo logs, archive logs)
- Recomendado por Oracle para Linux
- Journaling para recuperación ante crashes

### 3. Montar en /u01

```bash
UUID=`blkid -o export /dev/sdb1 | grep ^UUID= | head -1`
mkdir -p /u01
echo "${UUID}  /u01    xfs    defaults 1 2" >> /etc/fstab
mount /u01
```

**Agregar a /etc/fstab:**
- Permite auto-mount al reiniciar VM
- `defaults` - Opciones por defecto
- `1 2` - dump y fsck order

### 4. Repetir para /dev/sdc → /u02

Mismo proceso: particionar, formatear XFS, montar, agregar a fstab.

---

## Verificación

```bash
# Ver discos montados
df -h | grep -E "/u01|/u02"

# Debe mostrar:
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1        99G  1.2G   98G   2% /u01
/dev/sdc1        99G  1.0G   98G   2% /u02

# Ver /etc/fstab
grep -E "/u01|/u02" /etc/fstab

# Ver estructura
tree -L 2 /u01 /u02
```

---

## Referencia

Para análisis completo de este script (idéntico en primary y standby):

Ver documentación de primary: `guiastby/ejecucion/primary/32-prepare-disks.md`

---

**Siguiente:** [53 - Instalación de Paquetes OS](53-install-packages.md)
