#!/bin/bash
# Script de configuración raíz del nodo Standby

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configuración raíz de STANDBY iniciada." `date`
echo "******************************************************************************"

# Preparar discos
sh /vagrant_scripts/prepare_u01_u02_disks.sh

# Instalar paquetes del SO
sh /vagrant_scripts/install_os_packages.sh

# Establecer contraseñas
echo "******************************************************************************"
echo "Estableciendo contraseñas de root y oracle y cambiando propietario." `date`
echo "******************************************************************************"
echo -e "${ROOT_PASSWORD}\n${ROOT_PASSWORD}" | passwd
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | passwd oracle
chown -R oracle:oinstall /u01 /u02
chmod -R 775 /u01 /u02

# Configurar archivo de hosts
sh /vagrant_scripts/configure_hosts_base.sh

# Configurar nombre de host
sh /vagrant_scripts/configure_hostname.sh

# Configurar sincronización de tiempo
sh /vagrant_scripts/configure_chrony.sh

# Configurar entorno del usuario oracle
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/oracle_user_environment_setup.sh'
. /home/oracle/scripts/setEnv.sh

# Instalar software de Oracle
su - oracle -c 'sh /vagrant_scripts/oracle_db_software_installation.sh'

# Ejecutar scripts raíz de Oracle
echo "******************************************************************************"
echo "Ejecutando scripts raíz de BD." `date`
echo "******************************************************************************"
sh ${ORA_INVENTORY}/orainstRoot.sh
sh ${ORACLE_HOME}/root.sh

# Crear base de datos Standby
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/oracle_create_database.sh'

# Configurar scripts de automatización
su - oracle -c 'sh /vagrant/2-Standby/scripts/standby/setup_automation.sh'

# Configurar claves SSH para recibir transferencias de copia de seguridad (ejecutar como root para acceso a /vagrant)
echo "******************************************************************************"
echo "Configurando claves SSH para recibir copias de seguridad del primario." `date`
echo "******************************************************************************"
sh /vagrant/2-Standby/scripts/standby/setup_ssh_keys_auto.sh

# Instalar trabajos cron para automatización
echo "******************************************************************************"
echo "Instalando trabajos cron para automatización." `date`
echo "******************************************************************************"
su - oracle -c 'sh /home/oracle/automation/install_cron_jobs.sh'

echo "******************************************************************************"
echo "Configuración raíz de STANDBY completada." `date`
echo "******************************************************************************"
