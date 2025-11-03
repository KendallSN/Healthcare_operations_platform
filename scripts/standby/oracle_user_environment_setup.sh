#!/bin/bash
# Setup Oracle user environment for STANDBY

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Setup Oracle user environment." `date`
echo "******************************************************************************"

# Create scripts directory
mkdir -p /home/oracle/scripts
mkdir -p /home/oracle/logs

# Create setEnv.sh
cat > /home/oracle/scripts/setEnv.sh << EOF
# Oracle Environment
export ORACLE_HOSTNAME=${NODE2_FQ_HOSTNAME}
export ORACLE_UNQNAME=${NODE2_DB_UNIQUE_NAME}
export ORACLE_BASE=${ORACLE_BASE}
export ORACLE_HOME=${ORACLE_BASE}/${ORACLE_HOME_EXT}
export ORA_INVENTORY=${ORA_INVENTORY}
export ORACLE_SID=${ORACLE_SID}
export DATA_DIR=${DATA_DIR}
export PDB_NAME=${PDB_NAME}

# Software installation variables
export SOFTWARE_DIR=${SOFTWARE_DIR}
export DB_SOFTWARE=${DB_SOFTWARE}

export PATH=\${ORACLE_HOME}/bin:\${PATH}
export LD_LIBRARY_PATH=\${ORACLE_HOME}/lib:/lib:/usr/lib
export CLASSPATH=\${ORACLE_HOME}/jlib:\${ORACLE_HOME}/rdbms/jlib

export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

export TNS_ADMIN=\${ORACLE_HOME}/network/admin
EOF

# Add to .bash_profile
echo ". /home/oracle/scripts/setEnv.sh" >> /home/oracle/.bash_profile

# Source the environment and create Oracle directories
. /home/oracle/scripts/setEnv.sh
mkdir -p ${ORACLE_HOME}
mkdir -p ${DATA_DIR}

# Set ownership
chown -R oracle:oinstall /home/oracle/scripts
chown -R oracle:oinstall /home/oracle/logs
chown oracle:oinstall /home/oracle/.bash_profile

echo "******************************************************************************"
echo "Oracle user environment setup complete." `date`
echo "******************************************************************************"
