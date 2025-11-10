# Data Guard Switchover Guide

## Prerequisites

- Both VMs running: `vagrant status`
- Data Guard configured and synchronized (no lag)

## 1. Verify Data Guard Status

```bash
vagrant ssh primary -c 'sudo su - oracle -c "/home/oracle/automation/verify_dataguard.sh"'
```

**Check for**:
- Transport lag: 0 seconds
- Apply lag: 0 seconds
- No archive gaps
- MRP0 applying logs

## 2. Test Replication

**On Primary**:
```bash
vagrant ssh primary -c "sudo su - oracle -c \"sqlplus 'dgtest/\\\"DGTest2025!\\\"@localhost:1521/pdb1.world' << 'EOF'
DECLARE v_id NUMBER;
BEGIN
  insert_test_data('Replication Test', 'Testing before switchover', v_id);
END;
/
SELECT id, test_name FROM replication_test ORDER BY id DESC FETCH FIRST 3 ROWS ONLY;
EXIT;
EOF
\""
```

**Wait 10 seconds for replication**, then check on standby:
```bash
vagrant ssh standby -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
ALTER SESSION SET CONTAINER=pdb1;
SELECT id, test_name FROM dgtest.replication_test ORDER BY id DESC FETCH FIRST 3 ROWS ONLY;
EXIT;
EOF
'
```

## 3. Perform Switchover (Manual Method)

### Step 1: Convert Primary to Standby

On **current primary**:
```bash
vagrant ssh primary -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
ALTER DATABASE COMMIT TO SWITCHOVER TO PHYSICAL STANDBY WITH SESSION SHUTDOWN;
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
ALTER DATABASE MOUNT STANDBY DATABASE;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF
'
```

### Step 2: Convert Standby to Primary

On **current standby**:
```bash
vagrant ssh standby -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
ALTER DATABASE COMMIT TO SWITCHOVER TO PRIMARY WITH SESSION SHUTDOWN;
SHUTDOWN IMMEDIATE;
STARTUP;
EXIT;
EOF
'
```

### Step 3: Open PDB on New Primary

```bash
vagrant ssh standby -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
ALTER PLUGGABLE DATABASE pdb1 OPEN;
EXIT;
EOF
'
```

## 4. Verify Switchover

Check roles are swapped:

**New Standby** (was primary):
```bash
vagrant ssh primary -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
SELECT name, database_role, open_mode FROM v\$database;
EXIT;
EOF
'
```
Expected: `PHYSICAL STANDBY | MOUNTED`

**New Primary** (was standby):
```bash
vagrant ssh standby -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
SELECT name, database_role, open_mode FROM v\$database;
EXIT;
EOF
'
```
Expected: `PRIMARY | READ WRITE`

## 5. Test Data on New Primary

```bash
vagrant ssh standby -c "sudo su - oracle -c \"sqlplus 'dgtest/\\\"DGTest2025!\\\"@localhost:1521/pdb1.world' << 'EOF'
SELECT id, test_name FROM replication_test ORDER BY id DESC FETCH FIRST 3 ROWS ONLY;
EXIT;
EOF
\""
```

## Quick Status Check

```bash
# Check both databases
vagrant ssh primary -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
SELECT name, database_role FROM v\$database;
EXIT;
EOF
'

vagrant ssh standby -c 'sudo su - oracle -c "sqlplus / as sysdba" << EOF
SELECT name, database_role FROM v\$database;
EXIT;
EOF
'
```

## Rollback Switchover

To switch back to original configuration, repeat steps 3-5 in reverse order.

## Troubleshooting

**Issue**: Switchover hangs
- Check for active sessions: `SELECT count(*) FROM v$session;`
- Kill active sessions if needed

**Issue**: ORA-16139 (media recovery required)
- On standby: `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;`

**Issue**: PDB won't open
- Check alert log: `/u01/app/oracle/diag/rdbms/*/alert_*.log`
- Try: `ALTER PLUGGABLE DATABASE pdb1 CLOSE; ALTER PLUGGABLE DATABASE pdb1 OPEN;`
