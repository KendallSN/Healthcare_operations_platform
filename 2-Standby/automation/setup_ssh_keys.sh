#!/bin/bash
# Configurar autenticación basada en claves SSH para respaldos automatizados
# Ejecutar en la base de datos PRIMARIA como usuario oracle

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "===================================================================="
echo "Configurar autenticación basada en claves SSH"
echo "===================================================================="

# Verificar si la clave SSH ya existe
if [ -f /home/oracle/.ssh/id_rsa ]; then
  echo "La clave SSH ya existe"
  read -p "¿Regenerar clave SSH? (sí/no): " regenerate
  if [ "$regenerate" != "yes" ] && [ "$regenerate" != "sí" ]; then
    echo "Usando clave SSH existente"
  else
    rm -f /home/oracle/.ssh/id_rsa /home/oracle/.ssh/id_rsa.pub
    ssh-keygen -t rsa -b 4096 -f /home/oracle/.ssh/id_rsa -N ""
  fi
else
  # Generar clave SSH
  echo "Generando clave SSH..."
  mkdir -p /home/oracle/.ssh
  chmod 700 /home/oracle/.ssh
  ssh-keygen -t rsa -b 4096 -f /home/oracle/.ssh/id_rsa -N ""
fi

echo ""
echo "===================================================================="
echo "Copiar clave SSH al servidor en espera"
echo "===================================================================="
echo "Se le pedirá la contraseña del usuario oracle en el servidor en espera"
echo ""

# Copiar clave pública al servidor en espera
ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub oracle@${NODE2_FQ_HOSTNAME}

echo ""
echo "===================================================================="
echo "Probar conexión SSH al servidor en espera"
echo "===================================================================="

ssh oracle@${NODE2_FQ_HOSTNAME} "echo 'SSH connection successful from primary to standby'"

if [ $? -eq 0 ]; then
  echo ""
  echo "===================================================================="
  echo "¡Configuración de clave SSH completada!"
  echo "===================================================================="
  echo "Ahora puede usar rsync sin contraseña para transferencias de respaldo"
else
  echo ""
  echo "===================================================================="
  echo "ERROR: ¡La prueba de conexión SSH falló!"
  echo "===================================================================="
  exit 1
fi
