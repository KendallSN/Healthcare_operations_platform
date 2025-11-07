# 32 - Prepare Disks - Preparación de Discos Oracle

## Preparación de Almacenamiento u01 y u02

Este script configura el almacenamiento persistente necesario para Oracle Database. Particiona, formatea y monta dos discos virtuales dedicados: `/u01` para software y datos Oracle, y `/u02` para backups y Fast Recovery Area.

## Ubicación

`2-Standby/infrastructure/prepare_u01_u02_disks.sh`

**Nota:** Este es un **shared script** usado tanto por primary como standby (con discos independientes por nodo).

## Propósito

- **Función principal:** Preparar almacenamiento dedicado para Oracle Database
- **Responsabilidad:** Particionar, formatear, montar y crear estructura de directorios
- **Separación de datos:** Aislar datos Oracle del disco del sistema operativo

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh` (primer paso después de cargar variables)
- **Orden:** Paso 3 de 12 en el despliegue primario
- **Usuario:** `root` (necesario para fdisk, mkfs, mount, fstab)
- **Duración:** 30-60 segundos

## Variables de Entorno Utilizadas

Cargadas desde `install.env`:

```bash
# Ninguna variable directamente, pero usa rutas hardcoded
# /u01 - Oracle base
# /u02 - Backups y FRA
```

## Flujo de Ejecución Paso a Paso

### Paso 1: Cargar Variables de Entorno

```bash
. /vagrant_config/install.env
```

**Explicación:**
- Carga variables de configuración (aunque este script no usa muchas)
- Mantiene consistencia con otros scripts

### Paso 2: Definir Función Genérica de Preparación

```bash
function prepare_disk {
  MOUNT_POINT=$1    # e.g., /u01
  DISK_DEVICE=$2    # e.g., /dev/sdb

  echo "******************************************************************************"
  echo "Prepare ${MOUNT_POINT} disk." `date`
  echo "******************************************************************************"

  # ... (resto de la función)
}
```

**Explicación:**
- Función reutilizable para preparar cualquier disco
- Recibe punto de montaje y dispositivo como parámetros
- DRY principle: evita duplicar código para u01 y u02

### Paso 3: Particionar Disco

```bash
echo -e "n\np\n1\n\n\nw" | fdisk ${DISK_DEVICE}
```

**Explicación:**
- `echo -e`: Imprime comandos separados por `\n` (newlines)
- `n`: Crear nueva partición
- `p`: Tipo primaria
- `1`: Número de partición 1
- `\n\n`: Aceptar defaults para primer y último sector (usar todo el disco)
- `w`: Escribir tabla de particiones y salir

**Resultado:**
- `/dev/sdb` → `/dev/sdb1` (100 GB completos)
- `/dev/sdc` → `/dev/sdc1` (100 GB completos)

**Comandos interactivos automatizados:**
```
Command (m for help): n
Partition type: p
Partition number (1-4): 1
First sector: <default>
Last sector: <default>
Command (m for help): w
```

### Paso 4: Crear Filesystem XFS

```bash
mkfs.xfs -f ${DISK_DEVICE}1
```

**Explicación:**
- `mkfs.xfs`: Crea filesystem XFS (recomendado para Oracle en Linux)
- `-f`: Force (sobreescribe cualquier filesystem existente)
- `${DISK_DEVICE}1`: Primera partición del disco (e.g., /dev/sdb1)

**¿Por qué XFS y no ext4?**
- **Performance:** Mejor rendimiento con archivos grandes (datafiles de Oracle)
- **Escalabilidad:** Soporta filesystems de hasta 500 TB
- **Delayed allocation:** Mejora escrituras secuenciales
- **Oracle recomienda:** XFS es el filesystem recomendado por Oracle para Linux

**Salida esperada:**
```
meta-data=/dev/sdb1              isize=512    agcount=4, agsize=6553600 blks
data     =                       bsize=4096   blocks=26214400, imaxpct=25
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=12800, version=2
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

### Paso 5: Obtener UUID del Disco

```bash
UUID=`blkid -o export ${DISK_DEVICE}1 | grep ^UUID= | head -1`
```

**Explicación:**
- `blkid -o export`: Muestra información del dispositivo en formato clave=valor
- `grep ^UUID=`: Filtra línea que empieza con "UUID="
- `head -1`: Toma solo la primera línea (por si hay múltiples UUIDs)
- Resultado ejemplo: `UUID=a1b2c3d4-e5f6-7890-abcd-ef1234567890`

**¿Por qué UUID en lugar de /dev/sdb1?**
- **Persistencia:** `/dev/sdb1` puede cambiar si se agregan/quitan discos
- **Confiabilidad:** UUID es único y permanente para ese filesystem
- **Mejores prácticas:** Recomendado por Oracle y Linux best practices

### Paso 6: Crear Punto de Montaje

```bash
mkdir -p ${MOUNT_POINT}
```

**Explicación:**
- Crea directorio donde se montará el disco
- `-p`: No falla si el directorio ya existe

### Paso 7: Agregar Entrada a /etc/fstab

```bash
echo "${UUID}  ${MOUNT_POINT}    xfs    defaults 1 2" >> /etc/fstab
```

**Explicación:**
- `>>`: Append a /etc/fstab (no sobrescribe contenido existente)
- Formato: `<filesystem> <mount point> <type> <options> <dump> <pass>`
- `defaults`: Opciones por defecto (rw, suid, dev, exec, auto, nouser, async)
- `1`: dump (habilita backups con dump command)
- `2`: fsck pass (orden de verificación en boot, 1 es para /, 2 para otros)

**Entrada resultante:**
```
UUID=a1b2c3d4-e5f6-7890-abcd-ef1234567890  /u01    xfs    defaults 1 2
```

### Paso 8: Montar el Filesystem

```bash
mount ${MOUNT_POINT}
```

**Explicación:**
- `mount` sin opciones lee configuración de /etc/fstab
- Monta el filesystem en el punto especificado
- A partir de ahora `/u01` está disponible con 100 GB

**Verificación:**
```bash
df -h /u01
# Output: Filesystem      Size  Used Avail Use% Mounted on
#         /dev/sdb1        100G  746M   99G   1% /u01
```

### Paso 9: Ejecutar Función para Ambos Discos

```bash
# Prepare u01 (Oracle base)
prepare_disk /u01 /dev/sdb

# Prepare u02 (Backups and FRA)
prepare_disk /u02 /dev/sdc
```

**Explicación:**
- Llama a la función dos veces con diferentes parámetros
- Primera llamada: u01 en /dev/sdb
- Segunda llamada: u02 en /dev/sdc

### Paso 10: Crear Estructura de Directorios Oracle

```bash
# Create directory structure
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/oradata
mkdir -p /u01/software
mkdir -p /u02/backup
mkdir -p /u02/fast_recovery_area
```

**Explicación:**
- Crea directorios necesarios para instalación Oracle
- `/u01/app/oracle`: ORACLE_BASE (base de instalación)
- `/u01/app/oraInventory`: Inventario de productos Oracle instalados
- `/u01/oradata`: Datafiles de la base de datos
- `/u01/software`: Software Oracle antes de instalar
- `/u02/backup`: Destino de backups RMAN
- `/u02/fast_recovery_area`: FRA para flashback logs, archive logs, backups

**Propiedad:** root:root (se cambiará a oracle:oinstall en paso posterior de root_setup.sh)

### Paso 11: Banner de Finalización

```bash
echo "******************************************************************************"
echo "Disk preparation complete." `date`
echo "******************************************************************************"
```

## Archivos Creados/Modificados

### Sistema de Archivos

| Archivo/Directorio | Descripción |
|-------------------|-------------|
| `/dev/sdb1` | Partición primaria de 100 GB (u01) |
| `/dev/sdc1` | Partición primaria de 100 GB (u02) |
| `/etc/fstab` | Entradas de montaje automático agregadas |
| `/u01/` | Punto de montaje para Oracle base y datos |
| `/u02/` | Punto de montaje para backups y FRA |

### Estructura de Directorios Creada

```
/u01/
├── app/
│   ├── oracle/          # ORACLE_BASE (será ORACLE_HOME parent)
│   └── oraInventory/    # Oracle inventory
├── oradata/             # Database datafiles
└── software/            # Oracle installation files (zip)

/u02/
├── backup/              # RMAN backups
└── fast_recovery_area/  # FRA (flashback, archives, backups)
```

## Dependencias

### Hardware (VirtualBox)

Requiere que Vagrantfile haya creado y attached dos discos virtuales:

```ruby
# En Vagrantfile
unless File.exist?("u01-primary.vdi")
  vb.customize ["createhd", "--filename", "u01-primary.vdi", "--size", 102400]
end
unless File.exist?("u02-primary.vdi")
  vb.customize ["createhd", "--filename", "u02-primary.vdi", "--size", 102400]
end

vb.customize ["storageattach", :id, "--storagectl", "SATA Controller",
              "--port", 1, "--device", 0, "--type", "hdd", "--medium", "u01-primary.vdi"]
vb.customize ["storageattach", :id, "--storagectl", "SATA Controller",
              "--port", 2, "--device", 0, "--type", "hdd", "--medium", "u02-primary.vdi"]
```

### Software

- `fdisk` - Particionado de discos (incluido en Oracle Linux 8)
- `mkfs.xfs` - Crear filesystem XFS (incluido en OL8)
- `blkid` - Identificar UUIDs de bloques (incluido en OL8)

## Logs y Verificación

### Verificación Durante Ejecución

```bash
# Ver discos disponibles
lsblk

# Output esperado:
# NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# sda      8:0    0   60G  0 disk
# ├─sda1   8:1    0  600M  0 part /boot/efi
# ├─sda2   8:2    0    1G  0 part /boot
# └─sda3   8:3    0 58.4G  0 part /
# sdb      8:16   0  100G  0 disk
# └─sdb1   8:17   0  100G  0 part /u01
# sdc      8:32   0  100G  0 disk
# └─sdc1   8:33   0  100G  0 part /u02
```

### Verificación Post-Ejecución

```bash
# Verificar montajes
df -h | grep "/u0"
# /dev/sdb1       100G  746M   99G   1% /u01
# /dev/sdc1       100G  746M   99G   1% /u02

# Verificar /etc/fstab
grep "/u0" /etc/fstab
# UUID=xxx  /u01  xfs  defaults 1 2
# UUID=yyy  /u02  xfs  defaults 1 2

# Verificar estructura de directorios
ls -la /u01/
ls -la /u02/

# Verificar tipo de filesystem
mount | grep "/u0"
# /dev/sdb1 on /u01 type xfs (rw,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota)
```

### Desde Windows Host

```powershell
# Verificar desde host Windows
vagrant ssh primary -c "df -h | grep '/u0'"
vagrant ssh primary -c "ls -la /u01/"
vagrant ssh primary -c "cat /etc/fstab | grep u0"
```

## Puntos de Fallo Comunes

### 1. Disco Virtual No Existe

**Error:**
```
fdisk: cannot open /dev/sdb: No such file or directory
```

**Causa:** VirtualBox no creó o attached el disco virtual

**Solución:**
```bash
# Verificar discos en VirtualBox
VBoxManage showvminfo <vm-name> | grep "SATA"

# Recrear Vagrantfile con discos correctos
vagrant destroy -f
# Editar Vagrantfile para agregar discos
vagrant up
```

### 2. Disco Ya Tiene Particiones

**Error:**
```
Device contains neither a valid DOS partition table, nor Sun, SGI or OSF disklabel
```

**Causa:** Ejecución previa dejó particiones

**Solución:**
- Usar `-f` en `mkfs.xfs` (ya incluido en el script)
- O limpiar disco completamente:
```bash
dd if=/dev/zero of=/dev/sdb bs=1M count=100
```

### 3. Punto de Montaje Ya Ocupado

**Error:**
```
mount: /u01: /dev/sdb1 already mounted
```

**Causa:** Script ejecutado múltiples veces

**Solución:**
```bash
# Desmontar
umount /u01

# Limpiar /etc/fstab (remover entrada duplicada)
vi /etc/fstab

# Re-ejecutar script
```

### 4. Permisos Insuficientes

**Error:**
```
mkfs.xfs: Operation not permitted
```

**Causa:** Script no ejecutado como root

**Solución:**
- Este script DEBE ejecutarse como root
- root_setup.sh ya lo ejecuta con privilegios correctos

### 5. Espacio Insuficiente en Disco

**Error:**
```
mkfs.xfs: insufficient space
```

**Causa:** Disco virtual muy pequeño

**Solución:**
```ruby
# En Vagrantfile, aumentar tamaño (en MB)
vb.customize ["createhd", "--filename", "u01-primary.vdi", "--size", 204800]  # 200 GB
```

## Importancia para Data Guard

### Separación de Almacenamiento

**¿Por qué dos discos separados?**

1. **Performance:**
   - `/u01`: I/O intensivo de base de datos (datafiles, redo logs)
   - `/u02`: I/O de backups (secuencial, menos crítico)
   - Separar evita contención de I/O

2. **Recuperación ante desastres:**
   - Si `/u01` falla, backups en `/u02` siguen disponibles
   - Permite restore desde backups locales

3. **Gestión de espacio:**
   - Backups pueden crecer independientemente de datos
   - Evitar que backups llenen disco de datos

### Fast Recovery Area (FRA)

Crítica para Data Guard:

```sql
-- Configuración de FRA (realizada en oracle_create_database.sh)
ALTER SYSTEM SET db_recovery_file_dest='/u02/fast_recovery_area' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest_size=100G SCOPE=BOTH;
```

**Contenido de FRA:**
- **Flashback logs:** Para Flashback Database (rewind de DB después de failover)
- **Archive logs:** Logs archivados antes de transferir a standby
- **Backups:** Backups automáticos de RMAN
- **Standby redo logs:** En standby, recibe redo data del primary

### Filesystem XFS para Oracle

**Beneficios en Data Guard:**

1. **Archivos grandes:**
   - Datafiles pueden crecer a 500 TB
   - Archive logs con I/O intensivo se benefician de delayed allocation

2. **Metadata journaling:**
   - Recuperación rápida en caso de crash
   - Importante para mantener consistencia durante switchover/failover

3. **Allocation groups:**
   - Paralelización de I/O
   - Mejor rendimiento para redo logs y archive logs

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador que llama a este script
- **[52 - Standby Prepare Disks](../standby/52-prepare-disks.md)** - Equivalente en standby (mismo script)

### Documentación de Contexto

- **[20 - Vagrantfile](../20-vagrantfile.md)** - Configuración de discos virtuales
- **[05 - Arquitectura](../../05-arquitectura-sistema.md)** - Arquitectura de almacenamiento
- **[87 - RMAN Backups](../../conceptos-avanzados/87-rman-backups.md)** - Uso de /u02 para backups

### Flujo Completo

```
root_setup.sh
  └─> prepare_u01_u02_disks.sh (ESTE SCRIPT)
      └─> install_os_packages.sh (siguiente)
```

## Mejoras Futuras Posibles

1. **Validación previa:** Verificar que discos existen antes de particionar
2. **Tamaño configurable:** Leer tamaño de discos de install.env
3. **RAID support:** Soportar RAID para alta disponibilidad
4. **LVM:** Usar Logical Volume Manager para flexibilidad futura
5. **Idempotencia:** Detectar si discos ya están preparados y skip

## Código Fuente Completo

```bash
#!/bin/bash
# Prepare u01 and u02 disks for Oracle installation
# u01: Oracle software and database files
# u02: Backups and Fast Recovery Area

. /vagrant_config/install.env

function prepare_disk {
  MOUNT_POINT=$1
  DISK_DEVICE=$2

  echo "******************************************************************************"
  echo "Prepare ${MOUNT_POINT} disk." `date`
  echo "******************************************************************************"

  # New partition for the whole disk
  echo -e "n\np\n1\n\n\nw" | fdisk ${DISK_DEVICE}

  # Add XFS file system
  mkfs.xfs -f ${DISK_DEVICE}1

  # Mount it
  UUID=`blkid -o export ${DISK_DEVICE}1 | grep ^UUID= | head -1`
  mkdir -p ${MOUNT_POINT}
  echo "${UUID}  ${MOUNT_POINT}    xfs    defaults 1 2" >> /etc/fstab
  mount ${MOUNT_POINT}
}

# Prepare u01 (Oracle base)
prepare_disk /u01 /dev/sdb

# Prepare u02 (Backups and FRA)
prepare_disk /u02 /dev/sdc

# Create directory structure
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/oradata
mkdir -p /u01/software
mkdir -p /u02/backup
mkdir -p /u02/fast_recovery_area

echo "******************************************************************************"
echo "Disk preparation complete." `date`
echo "******************************************************************************"
```

**Total:** 46 líneas

---

**Siguiente:** [33 - Install Packages](33-install-packages.md) - Instalación de paquetes del sistema operativo necesarios para Oracle Database 21c.
