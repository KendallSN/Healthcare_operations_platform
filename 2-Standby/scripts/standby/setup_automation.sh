#!/bin/bash
# Configurar scripts de automatización en standby

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Configurando scripts de automatización en STANDBY." `date`
echo "******************************************************************************"

# Copiar scripts de automatización a la carpeta de inicio del usuario oracle
mkdir -p /home/oracle/automation

cp /vagrant_automation/*.sh /home/oracle/automation/
chmod +x /home/oracle/automation/*.sh
chown -R oracle:oinstall /home/oracle/automation

# Crear directorio de registros para automatización
mkdir -p /home/oracle/logs/automation
chown -R oracle:oinstall /home/oracle/logs

echo "******************************************************************************"
echo "Configuración de scripts de automatización completada." `date`
echo "******************************************************************************"
echo "Scripts disponibles en /home/oracle/automation/:"
ls -l /home/oracle/automation/
