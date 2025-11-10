# Oracle Data Guard Switchover Guide - DGMGRL Method

**Purpose**: Step-by-step guide for planned role reversal using Data Guard Broker (DGMGRL)

**Environment**:
- Primary: ol8-21-dg1 (192.168.56.101) - Database: `cdb1`
- Standby: ol8-21-dg2 (192.168.56.102) - Database: `cdb1_stby`
- Protection Mode: MAXAVAILABILITY
- Transport Mode: FASTSYNC

**Duration**: ~30 seconds per switchover
**Downtime**: Minimal (~5-10 seconds while primary restarts)
**Data Loss**: Zero

---

## What is Switchover?

Switchover is a **planned role reversal** between primary and standby databases with zero data loss:
- **Primary becomes Standby** (starts applying redo logs)
- **Standby becomes Primary** (starts accepting transactions)

Use switchover for:
- Planned maintenance on primary server
- Testing disaster recovery procedures
- Balancing workload across sites
- Rolling upgrades

---

## Prerequisites

1. **Both VMs running**:
   ```bash
   vagrant status
   # Both should show: running (virtualbox)
   ```

2. **Access to primary VM**:
   ```bash
   vagrant ssh primary
   sudo su - oracle
   ```

3. **Password**: `S1sPassword1!` (from `config/install.env`)

---

## Step 1: Verify Configuration Ready

```bash
dgmgrl sys/"S1sPassword1!" << EOF
SHOW CONFIGURATION;
EXIT;
EOF
```

**Expected Output**:
```
Configuration - dg_config
  Protection Mode: MaxAvailability
  Members:
  cdb1      - Primary database
    cdb1_stby - Physical standby database

Configuration Status: SUCCESS
```

**Requirements**:
- Configuration Status must be **SUCCESS**
- Both databases listed as members

---

## Step 2: Validate Both Databases Ready

```bash
dgmgrl sys/"S1sPassword1!" << EOF
VALIDATE DATABASE cdb1;
VALIDATE DATABASE cdb1_stby;
EXIT;
EOF
```

**Expected Output**:
```
Database Role: Primary database
Ready for Switchover: Yes

Database Role: Physical standby database
Ready for Switchover: Yes
Ready for Failover: Yes (Primary Running)
```

**Requirements**:
- Both databases show **Ready for Switchover: Yes**
- No errors or warnings

If not ready, check:
```bash
dgmgrl sys/"S1sPassword1!" << EOF
SHOW DATABASE cdb1_stby;
EXIT;
EOF
```

Look for:
- **Transport Lag: 0 seconds** (or < 5 seconds)
- **Apply Lag: 0 seconds** (or < 5 seconds)
- **Database Status: SUCCESS**

---

## Step 3: Perform Switchover

To make `cdb1_stby` the new primary:

```bash
dgmgrl sys/"S1sPassword1!" << EOF
SWITCHOVER TO cdb1_stby;
SHOW CONFIGURATION;
EXIT;
EOF
```

**Expected Output**:
```
Performing switchover NOW, please wait...
Operation requires a connection to database "cdb1_stby"
Connecting...
New primary database "cdb1_stby" is opening...
Operation requires start up of instance "cdb1" on database "cdb1"
Starting instance "cdb1"...
Switchover succeeded, new primary is "cdb1_stby"

Configuration - dg_config
  Members:
  cdb1_stby - Primary database       ← NEW PRIMARY
    cdb1    - Physical standby database  ← NEW STANDBY

Configuration Status: SUCCESS
```

**Duration**: ~27-30 seconds

---

## Step 4: Verify Switchover Complete

### Check Configuration Status

```bash
dgmgrl sys/"S1sPassword1!" << EOF
SHOW CONFIGURATION;
SHOW DATABASE cdb1_stby;
SHOW DATABASE cdb1;
EXIT;
EOF
```

**Expected**:
- Configuration Status: **SUCCESS**
- cdb1_stby Role: **PRIMARY**
- cdb1 Role: **PHYSICAL STANDBY**
- Transport Lag: **0 seconds**
- Apply Lag: **0 seconds** (or quickly decreasing)

### Test Data Access on New Primary

Connect to **standby VM** (now running PRIMARY):

```bash
vagrant ssh standby
sudo su - oracle

sqlplus 'dgtest/"DGTest2025!"@localhost:1521/pdb1.world' << 'EOF'
-- Test query on new primary
SELECT COUNT(*) FROM replication_test;
EXIT;
EOF
```

Should succeed and return row count.

### Verify Old Primary is Standby

Connect to **primary VM** (now running STANDBY):

```bash
vagrant ssh primary
sudo su - oracle

sqlplus / as sysdba << EOF
SELECT name, database_role, open_mode FROM v\$database;
EXIT;
EOF
```

**Expected**:
```
NAME   DATABASE_ROLE      OPEN_MODE
------ ------------------ ----------
CDB1   PHYSICAL STANDBY   MOUNTED
```

---

## Step 5: Switchover Back (Optional)

To return to original configuration:

```bash
# From standby VM (current primary)
vagrant ssh standby
sudo su - oracle

dgmgrl sys/"S1sPassword1!" << EOF
SWITCHOVER TO cdb1;
SHOW CONFIGURATION;
EXIT;
EOF
```

**Expected**:
```
Switchover succeeded, new primary is "cdb1"

Configuration - dg_config
  Members:
  cdb1      - Primary database       ← BACK TO ORIGINAL
    cdb1_stby - Physical standby database

Configuration Status: SUCCESS
```

---

## Monitoring During Switchover

### Real-Time Progress

In a separate terminal, monitor apply lag:

```bash
watch -n 2 "dgmgrl sys/\"S1sPassword1!\" <<< 'SHOW DATABASE cdb1_stby' | grep 'Lag:'"
```

### Check MRP Process

After switchover, verify managed recovery running on new standby:

```bash
ps -ef | grep -i 'ora_mrp0' | grep -v grep
```

Should show: `ora_mrp0_cdb1` (standby recovery process)

---

## Common Issues

### Issue 1: Configuration Not Ready (WARNING Status)

**Symptom**:
```
Configuration Status: WARNING
```

**Check lag**:
```bash
dgmgrl sys/"S1sPassword1!" << EOF
SHOW DATABASE cdb1_stby;
EXIT;
EOF
```

**Solution**: Wait for lag to clear (Transport Lag and Apply Lag should be 0 seconds)

---

### Issue 2: Database Not Ready for Switchover

**Symptom**:
```
Ready for Switchover: No
ORA-16853: apply lag has exceeded threshold
```

**Solution**: Wait for standby to catch up. Check progress:
```bash
dgmgrl sys/"S1sPassword1!" << EOF
SHOW DATABASE VERBOSE cdb1_stby;
EXIT;
EOF
```

Look for "Average Apply Rate" - should be actively applying logs.

---

### Issue 3: Switchover Hangs or Times Out

**Symptom**: SWITCHOVER command doesn't complete after 5 minutes

**Solution**:
1. Cancel with Ctrl+C
2. Check for active sessions blocking shutdown:
   ```bash
   sqlplus / as sysdba << EOF
   SELECT COUNT(*) FROM v\$session WHERE status = 'ACTIVE';
   EXIT;
   EOF
   ```
3. Retry switchover

---

### Issue 4: ORA-16814 After Switchover

**Symptom**:
```
ORA-16814: Cannot start apply on database with standby redo log gap
```

**Solution**:
```bash
dgmgrl sys/"S1sPassword1!" << EOF
EDIT DATABASE cdb1_stby SET STATE=APPLY-OFF;
EDIT DATABASE cdb1_stby SET STATE=APPLY-ON;
EXIT;
EOF
```

---

### Issue 5: Temporary WARNING Status After Switchover

**Symptom**:
```
Database Status: WARNING
ORA-16854: apply lag could not be determined
```

**Is This Normal?** **YES!** This appears for 10-30 seconds after switchover while standby initializes.

**Solution**: Wait 30 seconds, then check again. Status should change to SUCCESS.

---

## Performance Benchmarks

Based on testing with Oracle 21c on VirtualBox VMs (4GB RAM, 2 CPUs):

| Metric | Value |
|--------|-------|
| Switchover duration | 27-30 seconds |
| Database restart time | ~20 seconds |
| Client connection downtime | ~5-10 seconds |
| Apply lag after switchover | 0 seconds (within 30 sec) |
| Data loss | **Zero** |

---

## Best Practices

1. **Schedule During Maintenance Window**: Although downtime is minimal, plan for off-peak hours

2. **Notify Applications**: Clients may need to reconnect after 5-10 second interruption

3. **Test Regularly**: Practice switchover monthly to verify DR readiness

4. **Verify Before Switchover**:
   - Configuration Status = SUCCESS
   - Transport Lag = 0 seconds
   - Apply Lag = 0 seconds
   - No archive gaps

5. **Monitor After Switchover**:
   - Check both databases show SUCCESS status
   - Verify new standby is applying logs (MRP0 process running)
   - Test data access on new primary

6. **Document Role Changes**: Update your documentation/diagrams showing current primary location

---

## Quick Reference Commands

**Show current configuration**:
```bash
dgmgrl sys/"S1sPassword1!" <<< "SHOW CONFIGURATION"
```

**Check database status**:
```bash
dgmgrl sys/"S1sPassword1!" <<< "SHOW DATABASE cdb1_stby"
```

**Validate readiness**:
```bash
dgmgrl sys/"S1sPassword1!" <<< "VALIDATE DATABASE cdb1_stby"
```

**Perform switchover**:
```bash
dgmgrl sys/"S1sPassword1!" <<< "SWITCHOVER TO cdb1_stby"
```

**Check which is primary**:
```bash
sqlplus / as sysdba <<< "SELECT database_role FROM v\$database;"
```

---

## Summary

DGMGRL switchover provides:
- ✅ **Automated role reversal** (no manual SQL commands)
- ✅ **Zero data loss** (all committed transactions preserved)
- ✅ **Minimal downtime** (~5-10 second client interruption)
- ✅ **Fast completion** (~30 seconds total)
- ✅ **Automatic recovery startup** on new standby
- ✅ **Broker configuration updates** automatically

**Use Cases**:
- Planned maintenance on primary server hardware
- Testing disaster recovery procedures
- OS/Oracle patching on primary
- Network maintenance at primary site

**Next Steps**: See `DGMGRL_FAILOVER_GUIDE.md` for unplanned failover procedures.

---

**Last Tested**: 2025-11-10
**Oracle Version**: 21c Enterprise Edition
**Data Guard Version**: 21.3.0.0.0
**Test Result**: ✅ SWITCHOVER SUCCESSFUL - ZERO DATA LOSS
