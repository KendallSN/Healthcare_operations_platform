#!/bin/bash
# Instalación de Software de Base de Datos Oracle 21c

. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Install Oracle Database 21c software." `date`
echo "******************************************************************************"

# Copiar software a directorio local
echo "Copying Oracle software from shared directory..."
cp /vagrant_software/${DB_SOFTWARE} ${SOFTWARE_DIR}/
cd ${SOFTWARE_DIR}

# Descomprimir directamente en ORACLE_HOME
echo "Unzipping Oracle software into ORACLE_HOME..."
cd ${ORACLE_HOME}
unzip -oq ${SOFTWARE_DIR}/${DB_SOFTWARE}

# Crear archivo de respuesta para instalación silenciosa
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

# Ejecutar instalador
echo "Running Oracle installer..."
${ORACLE_HOME}/runInstaller -ignorePrereq -waitforcompletion -silent \
  -responseFile /tmp/db_install.rsp

echo "******************************************************************************"
echo "Instalación de software de Oracle completada." `date`
echo "******************************************************************************"
echo "Ejecutar estos comandos como root:"
echo "  ${ORA_INVENTORY}/orainstRoot.sh"
echo "  ${ORACLE_HOME}/root.sh"
