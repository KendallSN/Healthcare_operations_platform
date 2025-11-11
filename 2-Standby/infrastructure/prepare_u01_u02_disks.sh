#!/bin/bash
# Preparar discos u01 y u02 para instalación de Oracle
# u01: Software de Oracle y archivos de base de datos
# u02: Copias de seguridad y Área de Recuperación Rápida

. /vagrant_config/install.env

function prepare_disk {
  MOUNT_POINT=$1
  DISK_DEVICE=$2

  echo "******************************************************************************"
  echo "Prepare ${MOUNT_POINT} disk." `date`
  echo "******************************************************************************"

  # Nueva partición para todo el disco
  echo -e "n\np\n1\n\n\nw" | fdisk ${DISK_DEVICE}

  # Añadir sistema de archivos XFS
  mkfs.xfs -f ${DISK_DEVICE}1

  # Montarlo
  UUID=`blkid -o export ${DISK_DEVICE}1 | grep ^UUID= | head -1`
  mkdir -p ${MOUNT_POINT}
  echo "${UUID}  ${MOUNT_POINT}    xfs    defaults 1 2" >> /etc/fstab
  mount ${MOUNT_POINT}
}

# Preparar u01: software Oracle y archivos de BD
prepare_disk /u01 /dev/sdb

# Preparar u02: backups y FRA
prepare_disk /u02 /dev/sdc

# Crear estructura de directorios
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/oradata
mkdir -p /u01/software
mkdir -p /u02/backup
mkdir -p /u02/fast_recovery_area

echo "******************************************************************************"
echo "Disk preparation complete." `date`
echo "******************************************************************************"
