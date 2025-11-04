#!/bin/bash
# Setup Oracle Database and Listener to auto-start on system boot via systemd
# This script creates a systemd service that manages Oracle database lifecycle

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Setting up Oracle Database Auto-Start via systemd" `date`
echo "******************************************************************************"

# Step 1: Create wrapper scripts for starting and stopping Oracle
echo "Creating Oracle start/stop wrapper scripts..."

START_SCRIPT="/home/oracle/scripts/oracle_start.sh"
STOP_SCRIPT="/home/oracle/scripts/oracle_stop.sh"

# Create start script
cat > "$START_SCRIPT" <<'STARTEOF'
#!/bin/bash
# Start Oracle Database and Listener

# Source Oracle environment
. /home/oracle/scripts/setEnv.sh

# Start listener
echo "Starting Oracle Listener..."
lsnrctl start

# Start database
echo "Starting Oracle Database..."
sqlplus -s / as sysdba <<EOF
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
EXIT;
EOF

echo "Oracle Database and Listener started successfully"
STARTEOF

# Create stop script
cat > "$STOP_SCRIPT" <<'STOPEOF'
#!/bin/bash
# Stop Oracle Database and Listener

# Source Oracle environment
. /home/oracle/scripts/setEnv.sh

# Stop database
echo "Stopping Oracle Database..."
sqlplus -s / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
EXIT;
EOF

# Stop listener
echo "Stopping Oracle Listener..."
lsnrctl stop

echo "Oracle Database and Listener stopped successfully"
STOPEOF

# Set permissions and ownership
chown oracle:oinstall "$START_SCRIPT" "$STOP_SCRIPT"
chmod 750 "$START_SCRIPT" "$STOP_SCRIPT"

echo "[OK] Wrapper scripts created"
echo ""

# Step 2: Create the systemd service file
SERVICE_FILE="/etc/systemd/system/oracle-database.service"

echo "Creating systemd service file: $SERVICE_FILE"

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

# Start and stop scripts
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT

# Timeout settings (Oracle can take time to start/stop)
TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Set proper permissions on service file
chmod 644 "$SERVICE_FILE"

echo "[OK] Systemd service file created"
echo ""

# Reload systemd to recognize the new service
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service to start on boot
echo "Enabling oracle-database.service to start on boot..."
systemctl enable oracle-database.service

# Check service status
echo ""
echo "******************************************************************************"
echo "Service configuration complete!" `date`
echo "******************************************************************************"
echo ""
echo "Service Status:"
systemctl status oracle-database.service --no-pager || true

echo ""
echo "To manually control the Oracle database service:"
echo "  Start:   sudo systemctl start oracle-database"
echo "  Stop:    sudo systemctl stop oracle-database"
echo "  Restart: sudo systemctl restart oracle-database"
echo "  Status:  sudo systemctl status oracle-database"
echo ""
echo "The service will now automatically start when the VM boots."
echo ""

# Check if Oracle is currently running and ask if we should start the service now
echo "Checking if Oracle is currently running..."
RUNNING=$(su - oracle -c "ps aux | grep pmon | grep -v grep" || true)

if [ -z "$RUNNING" ]; then
  echo "Oracle is not currently running."
  echo "Starting oracle-database.service now..."
  systemctl start oracle-database.service

  # Wait a moment and check status
  sleep 5
  if systemctl is-active --quiet oracle-database.service; then
    echo "[OK] Oracle database service started successfully"
  else
    echo "[ERROR] Failed to start Oracle database service"
    echo "Check logs with: journalctl -u oracle-database -n 50"
  fi
else
  echo "Oracle is already running. Service is configured but not started."
  echo "The service will start automatically on next reboot."
  echo "To manually start the service now (and stop current Oracle): sudo systemctl start oracle-database"
fi

echo ""
echo "******************************************************************************"
echo "Auto-start setup complete!" `date`
echo "******************************************************************************"
