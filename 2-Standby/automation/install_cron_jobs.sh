#!/bin/bash
# Install Cron Jobs for Automation
# Run as oracle user

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

# Determine if this is primary or standby based on hostname
CURRENT_HOST=$(hostname -f)

echo "===================================================================="
echo "Installing Cron Jobs for Automation"
echo "Current host: $CURRENT_HOST"
echo "===================================================================="

# Create temporary cron file
CRON_FILE="/tmp/oracle_cron_$$"

# Get existing cron jobs (if any)
crontab -l > $CRON_FILE 2>/dev/null || touch $CRON_FILE

# Remove old automation entries
sed -i '/# Oracle Data Guard Automation/d' $CRON_FILE
sed -i '/check_log_transport.sh/d' $CRON_FILE
sed -i '/rman_daily_backup.sh/d' $CRON_FILE
sed -i '/delete_archives/d' $CRON_FILE

echo ""
echo "Adding automation cron jobs..."

# Add header
echo "" >> $CRON_FILE
echo "# Oracle Data Guard Automation" >> $CRON_FILE

if [ "$CURRENT_HOST" == "$NODE1_FQ_HOSTNAME" ]; then
  echo "Configuring PRIMARY cron jobs..."

  # Log transport check every 10 minutes
  echo "${LOG_TRANSPORT_CHECK_INTERVAL} /home/oracle/automation/check_log_transport.sh" >> $CRON_FILE

  # Daily backup at configured time (default 1 AM)
  echo "${BACKUP_TIME} /home/oracle/automation/rman_daily_backup.sh" >> $CRON_FILE

  # Archive cleanup on primary at 2 AM (after backup)
  echo "0 2 * * * /home/oracle/automation/delete_archives_primary.sh" >> $CRON_FILE

elif [ "$CURRENT_HOST" == "$NODE2_FQ_HOSTNAME" ]; then
  echo "Configuring STANDBY cron jobs..."

  # Archive cleanup on standby at configured time (default 11 PM)
  echo "${ARCHIVE_CLEANUP_TIME} /home/oracle/automation/delete_archives_standby.sh" >> $CRON_FILE

else
  echo "ERROR: Cannot determine if this is primary or standby!"
  echo "Current hostname: $CURRENT_HOST"
  echo "Expected: $NODE1_FQ_HOSTNAME or $NODE2_FQ_HOSTNAME"
  rm -f $CRON_FILE
  exit 1
fi

# Install crontab
crontab $CRON_FILE

# Cleanup
rm -f $CRON_FILE

echo ""
echo "===================================================================="
echo "Installed Cron Jobs:"
echo "===================================================================="
crontab -l | grep -A 10 "Oracle Data Guard Automation"

echo ""
echo "===================================================================="
echo "Cron Jobs Installation Complete!"
echo "===================================================================="
