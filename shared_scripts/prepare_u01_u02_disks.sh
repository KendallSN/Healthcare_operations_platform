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
