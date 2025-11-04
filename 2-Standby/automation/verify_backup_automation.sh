#!/bin/bash
# Verify Backup Automation Setup
# Run after deployment to confirm all components are working
# Usage: /home/oracle/automation/verify_backup_automation.sh

. /home/oracle/scripts/setEnv.sh
. /vagrant_config/install.env

echo "========================================================================"
echo "BACKUP AUTOMATION VERIFICATION"
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "========================================================================"

ERRORS=0

# 1. Check SSH keys
echo ""
echo "=== SSH Key Configuration ==="
if [ -f ~/.ssh/id_rsa ]; then
    echo "  [OK] Private key exists"
    KEY_PERMS=$(stat -c "%a" ~/.ssh/id_rsa)
    if [ "$KEY_PERMS" = "600" ]; then
        echo "  [OK] Private key permissions correct (600)"
    else
        echo "  [ERROR] Private key permissions incorrect: $KEY_PERMS (should be 600)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  [ERROR] Private key missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -f ~/.ssh/id_rsa.pub ]; then
    echo "  [OK] Public key exists"
    PUB_KEY_PERMS=$(stat -c "%a" ~/.ssh/id_rsa.pub)
    if [ "$PUB_KEY_PERMS" = "644" ]; then
        echo "  [OK] Public key permissions correct (644)"
    else
        echo "  [ERROR] Public key permissions incorrect: $PUB_KEY_PERMS (should be 644)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  [ERROR] Public key missing"
    ERRORS=$((ERRORS + 1))
fi

# 2. Test SSH connectivity (if on primary)
if [ "$ORACLE_SID" = "cdb1" ]; then
    echo ""
    echo "=== SSH Connectivity Test ==="
    if ssh -o BatchMode=yes -o ConnectTimeout=10 oracle@${NODE2_FQ_HOSTNAME} "echo 'SSH OK'" 2>/dev/null | grep -q "SSH OK"; then
        echo "  [OK] Passwordless SSH to standby working"
    else
        echo "  [ERROR] Passwordless SSH to standby failed"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 3. Check authorized_keys (if on standby)
if [ "$ORACLE_SID" != "cdb1" ]; then
    echo ""
    echo "=== Authorized Keys ==="
    if [ -f ~/.ssh/authorized_keys ]; then
        echo "  [OK] authorized_keys file exists"
        AUTH_KEY_PERMS=$(stat -c "%a" ~/.ssh/authorized_keys)
        if [ "$AUTH_KEY_PERMS" = "600" ]; then
            echo "  [OK] authorized_keys permissions correct (600)"
        else
            echo "  [ERROR] authorized_keys permissions incorrect: $AUTH_KEY_PERMS (should be 600)"
            ERRORS=$((ERRORS + 1))
        fi

        KEY_COUNT=$(grep -c "^ssh-rsa" ~/.ssh/authorized_keys)
        echo "  [OK] Number of authorized keys: $KEY_COUNT"
    else
        echo "  [ERROR] authorized_keys file missing"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 4. Check backup directories
echo ""
echo "=== Backup Directories ==="
if [ "$ORACLE_SID" = "cdb1" ]; then
    if [ -d /u02/backup ]; then
        echo "  [OK] Primary backup directory exists: /u02/backup"
        BACKUP_COUNT=$(ls -1 /u02/backup/*.bkp 2>/dev/null | wc -l)
        BACKUP_SIZE=$(du -sh /u02/backup 2>/dev/null | awk '{print $1}')
        echo "    Backup files: $BACKUP_COUNT"
        echo "    Total size: $BACKUP_SIZE"
    else
        echo "  [ERROR] Primary backup directory missing: /u02/backup"
        ERRORS=$((ERRORS + 1))
    fi
else
    if [ -d /u02/backup_from_primary ]; then
        echo "  [OK] Standby backup directory exists: /u02/backup_from_primary"
        BACKUP_COUNT=$(ls -1 /u02/backup_from_primary/*.bkp 2>/dev/null | wc -l)
        BACKUP_SIZE=$(du -sh /u02/backup_from_primary 2>/dev/null | awk '{print $1}')
        echo "    Backup files: $BACKUP_COUNT"
        echo "    Total size: $BACKUP_SIZE"
    else
        echo "  [ERROR] Standby backup directory missing: /u02/backup_from_primary"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 5. Check automation scripts
echo ""
echo "=== Automation Scripts ==="
REQUIRED_SCRIPTS=(
    "check_log_transport.sh"
    "delete_archives_primary.sh"
    "delete_archives_standby.sh"
    "install_cron_jobs.sh"
    "manual_backup.sh"
    "rman_daily_backup.sh"
    "setup_ssh_keys.sh"
    "verify_dataguard.sh"
    "verify_backup_automation.sh"
)

SCRIPT_ERRORS=0
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -x "/home/oracle/automation/$script" ]; then
        echo "  [OK] $script"
    else
        echo "  [ERROR] $script (missing or not executable)"
        ERRORS=$((ERRORS + 1))
        SCRIPT_ERRORS=$((SCRIPT_ERRORS + 1))
    fi
done

if [ $SCRIPT_ERRORS -eq 0 ]; then
    echo "  All automation scripts present and executable"
fi

# 6. Check cron jobs
echo ""
echo "=== Cron Jobs ==="
CRON_COUNT=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)
if [ "$ORACLE_SID" = "cdb1" ]; then
    # Primary should have 3 cron jobs
    if [ "$CRON_COUNT" -ge 3 ]; then
        echo "  [OK] Primary cron jobs installed ($CRON_COUNT jobs)"
        echo ""
        crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | sed 's/^/    /'
    else
        echo "  [ERROR] Primary cron jobs missing (found $CRON_COUNT, expected 3)"
        echo "  Run: /home/oracle/automation/install_cron_jobs.sh"
        ERRORS=$((ERRORS + 1))
    fi
else
    # Standby should have 1 cron job
    if [ "$CRON_COUNT" -ge 1 ]; then
        echo "  [OK] Standby cron jobs installed ($CRON_COUNT jobs)"
        echo ""
        crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | sed 's/^/    /'
    else
        echo "  [ERROR] Standby cron jobs missing (found $CRON_COUNT, expected 1)"
        echo "  Run: /home/oracle/automation/install_cron_jobs.sh"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 7. Check logs directory
echo ""
echo "=== Logs Directory ==="
if [ -d /home/oracle/logs/automation ]; then
    echo "  [OK] Logs directory exists: /home/oracle/logs/automation"
    LOG_COUNT=$(ls -1 /home/oracle/logs/automation/*.log 2>/dev/null | wc -l)
    echo "    Log files: $LOG_COUNT"

    if [ $LOG_COUNT -gt 0 ]; then
        echo "    Recent logs:"
        ls -lth /home/oracle/logs/automation/*.log 2>/dev/null | head -5 | awk '{print "      " $9 " (" $5 ")"}'
    fi
else
    echo "  [ERROR] Logs directory missing: /home/oracle/logs/automation"
    ERRORS=$((ERRORS + 1))
fi

# 8. Check Oracle environment
echo ""
echo "=== Oracle Environment ==="
if [ -n "$ORACLE_HOME" ]; then
    echo "  [OK] ORACLE_HOME set: $ORACLE_HOME"
else
    echo "  [ERROR] ORACLE_HOME not set"
    ERRORS=$((ERRORS + 1))
fi

if [ -n "$ORACLE_SID" ]; then
    echo "  [OK] ORACLE_SID set: $ORACLE_SID"
else
    echo "  [ERROR] ORACLE_SID not set"
    ERRORS=$((ERRORS + 1))
fi

# 9. Check database connectivity
echo ""
echo "=== Database Connectivity ==="
DB_STATUS=$(sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT status FROM v\$instance;
EXIT;
EOF
)

DB_STATUS=$(echo "$DB_STATUS" | tr -d '[:space:]')

if [ "$DB_STATUS" = "OPEN" ] || [ "$DB_STATUS" = "MOUNTED" ]; then
    echo "  [OK] Database status: $DB_STATUS"
else
    echo "  [WARNING] Database status: $DB_STATUS (unexpected)"
    ERRORS=$((ERRORS + 1))
fi

# 10. Check Data Guard configuration (if primary)
if [ "$ORACLE_SID" = "cdb1" ]; then
    echo ""
    echo "=== Data Guard Configuration ==="

    DG_STATUS=$(dgmgrl / "show configuration" 2>/dev/null | grep "Configuration Status" | awk -F: '{print $2}' | tr -d '[:space:]')

    if [ "$DG_STATUS" = "SUCCESS" ]; then
        echo "  [OK] Data Guard configuration status: SUCCESS"
    else
        echo "  [WARNING] Data Guard configuration status: $DG_STATUS"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Summary
echo ""
echo "========================================================================"
if [ $ERRORS -eq 0 ]; then
    echo "VERIFICATION RESULT: [OK] ALL CHECKS PASSED"
    echo ""
    echo "Backup automation is fully configured and ready."
    echo ""
    echo "Automated tasks:"
    if [ "$ORACLE_SID" = "cdb1" ]; then
        echo "  - Daily backups at 1:00 AM (with auto-transfer to standby)"
        echo "  - Archive cleanup at 2:00 AM (after standby confirmation)"
        echo "  - Log transport monitoring every 10 minutes"
    else
        echo "  - Archive cleanup at 11:00 PM (3-day retention)"
    fi
else
    echo "VERIFICATION RESULT: [FAIL] FOUND $ERRORS ERROR(S)"
    echo ""
    echo "Please review the errors above and fix before production use."
    echo ""
    echo "Common fixes:"
    echo "  - Missing cron jobs: /home/oracle/automation/install_cron_jobs.sh"
    echo "  - SSH keys missing: /home/oracle/automation/setup_ssh_keys.sh"
fi
echo "========================================================================"

exit $ERRORS
