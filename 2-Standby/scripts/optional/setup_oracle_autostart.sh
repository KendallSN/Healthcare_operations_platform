#!/bin/bash
# Configurar Base de Datos Oracle y Listener para auto-iniciarse al arranque del sistema a través de systemd
# Este script crea un servicio systemd que gestiona el ciclo de vida de la base de datos Oracle

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configurando Auto-Inicio de Base de Datos Oracle a través de systemd" `date`
echo "******************************************************************************"

# Paso 1: Crear scripts envolventes para iniciar y detener Oracle
echo "Creando scripts envolventes de inicio/parada de Oracle..."

START_SCRIPT="/home/oracle/scripts/oracle_start.sh"
STOP_SCRIPT="/home/oracle/scripts/oracle_stop.sh"

# Crear script de inicio
cat > "$START_SCRIPT" <<'STARTEOF'
#!/bin/bash
# Iniciar Base de Datos Oracle y Listener

# Cargar entorno de Oracle
. /home/oracle/scripts/setEnv.sh

# Iniciar listener
echo "Iniciando Oracle Listener..."
lsnrctl start

# Iniciar base de datos
echo "Iniciando Base de Datos Oracle..."
sqlplus -s / as sysdba <<EOF
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
EXIT;
EOF

echo "Base de Datos Oracle y Listener iniciados exitosamente"
STARTEOF

# Crear script de detención
cat > "$STOP_SCRIPT" <<'STOPEOF'
#!/bin/bash
# Detener Base de Datos Oracle y Listener

# Cargar entorno de Oracle
. /home/oracle/scripts/setEnv.sh

# Detener base de datos
echo "Deteniendo Base de Datos Oracle..."
sqlplus -s / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
EXIT;
EOF

# Detener listener
echo "Deteniendo Oracle Listener..."
lsnrctl stop

echo "Base de Datos Oracle y Listener detenidos exitosamente"
STOPEOF

# Establecer permisos y propietario
chown oracle:oinstall "$START_SCRIPT" "$STOP_SCRIPT"
chmod 750 "$START_SCRIPT" "$STOP_SCRIPT"

echo "[OK] Scripts envolventes creados"
echo ""

# Paso 2: Crear archivo de servicio systemd
SERVICE_FILE="/etc/systemd/system/oracle-database.service"

echo "Creando archivo de servicio systemd: $SERVICE_FILE"

cat > "$SERVICE_FILE" <<SERVICEEOF
[Unit]
Description=Oracle Database and Listener
After=network.target local-fs.target

[Service]
Type=forking
User=oracle
Group=oinstall
Restart=no
RemainAfterExit=yes

# Scripts de inicio y detención
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT

# Configuración de tiempo de espera (Oracle puede tomar tiempo para iniciar/detener)
TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Establecer permisos apropiados en archivo de servicio
chmod 644 "$SERVICE_FILE"

echo "[OK] Archivo de servicio systemd creado"
echo ""

# Recargar systemd para reconocer el nuevo servicio
echo "Recargando daemon systemd..."
systemctl daemon-reload

# Habilitar el servicio para que inicie al arrancar
echo "Habilitando oracle-database.service para que inicie al arrancar..."
systemctl enable oracle-database.service

# Verificar estado del servicio
echo ""
echo "******************************************************************************"
echo "¡Configuración de servicio completada!" `date`
echo "******************************************************************************"
echo ""
echo "Estado del servicio:"
systemctl status oracle-database.service --no-pager || true

echo ""
echo "Para controlar manualmente el servicio de base de datos Oracle:"
echo "  Iniciar:   sudo systemctl start oracle-database"
echo "  Detener:    sudo systemctl stop oracle-database"
echo "  Reiniciar: sudo systemctl restart oracle-database"
echo "  Estado:  sudo systemctl status oracle-database"
echo ""
echo "El servicio ahora se iniciará automáticamente cuando se arranque la VM."
echo ""

# Verificar si Oracle se está ejecutando actualmente y preguntar si debemos iniciar el servicio ahora
echo "Verificando si Oracle se está ejecutando actualmente..."
RUNNING=$(su - oracle -c "ps aux | grep pmon | grep -v grep" || true)

if [ -z "$RUNNING" ]; then
  echo "Oracle no se está ejecutando actualmente."
  echo "Iniciando oracle-database.service ahora..."
  systemctl start oracle-database.service

  # Esperar un momento y verificar estado
  sleep 5
  if systemctl is-active --quiet oracle-database.service; then
    echo "[OK] Servicio de base de datos Oracle iniciado exitosamente"
  else
    echo "[ERROR] Falló al iniciar servicio de base de datos Oracle"
    echo "Verificar registros con: journalctl -u oracle-database -n 50"
  fi
else
  echo "Oracle ya se está ejecutando. El servicio está configurado pero no iniciado."
  echo "El servicio se iniciará automáticamente en el próximo reinicio."
  echo "Para iniciar manualmente el servicio ahora (y detener Oracle actual): sudo systemctl start oracle-database"
fi

echo ""
echo "******************************************************************************"
echo "¡Configuración de auto-inicio completada!" `date`
echo "******************************************************************************"
