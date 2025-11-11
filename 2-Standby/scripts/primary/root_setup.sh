#!/bin/bash
# Script de configuración root del nodo primario

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configuración root de PRIMARY iniciada." `date`
echo "******************************************************************************"

# Preparar discos
sh /vagrant_scripts/prepare_u01_u02_disks.sh

# Instalar paquetes del SO
sh /vagrant_scripts/install_os_packages.sh

# Establecer contraseñas
echo "******************************************************************************"
echo "Establecer contraseña de root y oracle y cambiar propietario." `date`
echo "******************************************************************************"
echo -e "${ROOT_PASSWORD}\n${ROOT_PASSWORD}" | passwd
echo -e "${ORACLE_PASSWORD}\n${ORACLE_PASSWORD}" | passwd oracle
chown -R oracle:oinstall /u01 /u02
chmod -R 775 /u01 /u02

# Configurar archivo hosts
sh /vagrant_scripts/configure_hosts_base.sh

# Configurar hostname
sh /vagrant_scripts/configure_hostname.sh

# Configurar sincronización de hora
sh /vagrant_scripts/configure_chrony.sh

# Configurar entorno del usuario oracle
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/oracle_user_environment_setup.sh'
. /home/oracle/scripts/setEnv.sh

# Instalar software Oracle
su - oracle -c 'sh /vagrant_scripts/oracle_db_software_installation.sh'

# Ejecutar scripts root de Oracle
echo "******************************************************************************"
echo "Ejecutar scripts root de BD." `date`
echo "******************************************************************************"
sh ${ORA_INVENTORY}/orainstRoot.sh
sh ${ORACLE_HOME}/root.sh

# Crear base de datos primaria
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/oracle_create_database.sh'

# Desplegar esquema de prueba simple para pruebas de replicación de Data Guard
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/deploy_custom_schema.sh'

# Configurar scripts de automatización
su - oracle -c 'sh /vagrant/2-Standby/scripts/primary/setup_automation.sh'

# Configurar claves SSH para transferencias de respaldo automatizadas (ejecutar como root para acceso /vagrant)
echo "******************************************************************************"
echo "Configurando claves SSH para transferencias de respaldo." `date`
echo "******************************************************************************"
sh /vagrant/2-Standby/scripts/primary/setup_ssh_keys_auto.sh

# Instalar trabajos cron para automatización
echo "******************************************************************************"
echo "Instalando trabajos cron para automatización." `date`
echo "******************************************************************************"
su - oracle -c 'sh /home/oracle/automation/install_cron_jobs.sh'

echo "******************************************************************************"
echo "Configuración root de PRIMARY completada." `date`
echo "******************************************************************************"
