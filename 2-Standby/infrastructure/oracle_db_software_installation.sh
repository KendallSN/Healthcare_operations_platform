#!/bin/bash
# Oracle 21c Database Software Installation

. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Install Oracle Database 21c software." `date`
echo "******************************************************************************"

# Copy software to local directory
echo "Copying Oracle software from shared directory..."
cp /vagrant_software/${DB_SOFTWARE} ${SOFTWARE_DIR}/
cd ${SOFTWARE_DIR}

# Unzip directly into ORACLE_HOME
echo "Unzipping Oracle software into ORACLE_HOME..."
cd ${ORACLE_HOME}
unzip -oq ${SOFTWARE_DIR}/${DB_SOFTWARE}

# Create response file for silent installation
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

# Run installer
echo "Running Oracle installer..."
${ORACLE_HOME}/runInstaller -ignorePrereq -waitforcompletion -silent \
  -responseFile /tmp/db_install.rsp

echo "******************************************************************************"
echo "Oracle software installation complete." `date`
echo "******************************************************************************"
echo "Run these commands as root:"
echo "  ${ORA_INVENTORY}/orainstRoot.sh"
echo "  ${ORACLE_HOME}/root.sh"
