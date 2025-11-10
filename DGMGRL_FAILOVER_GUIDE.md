# Oracle Data Guard Failover & Reinstate Guide - DGMGRL Method

**Purpose**: Step-by-step guide for emergency failover and FLASHBACK DATABASE reinstatement using Data Guard Broker (DGMGRL)

**Environment**:
- Primary: ol8-21-dg1 (192.168.56.101) - Database: `cdb1`
- Standby: ol8-21-dg2 (192.168.56.102) - Database: `cdb1_stby`
- Protection Mode: MAXAVAILABILITY
- Transport Mode: FASTSYNC
- Flashback: ENABLED

**Failover Duration**: ~4-5 seconds
**Reinstate Duration**: ~16 seconds (with FLASHBACK)
**Total Recovery Time**: ~80 seconds (including sync)
**Data Loss**: Zero (with synchronous transport)

---

## What is Failover?

Failover is an **emergency operation** when the primary database is unavailable due to:
- Hardware failure
- Network outage
- Software crash
- Data corruption
- Site disaster

**Key Differences from Switchover**:

| Aspect | Switchover (Planned) | Failover (Emergency) |
|--------|---------------------|----------------------|
| **Primary Status** | Online and healthy | DOWN or unreachable |
| **Coordination** | Both databases participate | Standby-only operation |
| **Speed** | ~30 seconds | ~4-5 seconds |
| **Data Loss** | Zero (guaranteed) | Zero (with FASTSYNC) |
| **Reversibility** | Fully automatic | Requires reinstatement |
| **Use Case** | Maintenance | Disaster recovery |

---

## Prerequisites

1. **Standby VM accessible**:
   ```bash
   vagrant ssh standby
   sudo su - oracle
   ```

2. **Primary VM down** (or unreachable)

3. **Password**: `S1sPassword1!` (from `config/install.env`)

4. **FLASHBACK enabled** on primary (configured during setup)

---

## Part 1: Emergency Failover

### Step 1: Verify Primary is Down

Try connecting to primary:

```bash
vagrant ssh primary -c 'sudo su - oracle -c "sqlplus / as sysdba <<< SELECT 1 FROM dual;"'
```

**If unavailable**, proceed with failover.

**If available**, use **SWITCHOVER** instead (see `DGMGRL_SWITCHOVER_GUIDE.md`)

---

### Step 2: Check Standby Status

```bash
vagrant ssh standby
sudo su - oracle

dgmgrl sys/"S1sPassword1!" << EOF
SHOW CONFIGURATION;
EXIT;
EOF
```

**Expected Output** (with primary down):
```
Configuration - dg_config
  Members:
  cdb1      - Primary database
    Error: ORA-1034: ORACLE not available    ← PRIMARY IS DOWN

    cdb1_stby - Physical standby database

Configuration Status: ERROR
```

**Requirements**:
- Standby database must be reachable
- Error on primary is expected

---

### Step 3: Perform Failover

From **standby VM**:

```bash
dgmgrl sys/"S1sPassword1!" << EOF
FAILOVER TO cdb1_stby;
SHOW CONFIGURATION;
EXIT;
EOF
```

**Expected Output**:
```
Performing failover NOW, please wait...
Failover succeeded, new primary is "cdb1_stby".
Failover processing complete, broker ready.

Configuration - dg_config
  Members:
  cdb1_stby - Primary database              ← NOW PRIMARY
    cdb1      - Physical standby database (disabled)
      ORA-16661: the standby database needs to be reinstated  ← IMPORTANT

Configuration Status: SUCCESS
```

**Failover Duration**: ~4-5 seconds

---

### Step 4: Verify New Primary

Check database role:

```bash
sqlplus / as sysdba << EOF
SELECT name, database_role, open_mode FROM v\$database;
SELECT name, open_mode FROM v\$pdbs;
EXIT;
EOF
```

**Expected Output**:
```
NAME   DATABASE_ROLE   OPEN_MODE
------ --------------- ----------
CDB1   PRIMARY         READ WRITE

NAME      OPEN_MODE
--------- ----------
PDB$SEED  READ ONLY
PDB1      READ WRITE    ← PDB is accessible
```

---

### Step 5: Verify Data Integrity

Test data access on new primary:

```bash
sqlplus 'dgtest/"DGTest2025!"@localhost:1521/pdb1.world' << 'EOF'
-- Count rows
SELECT COUNT(*) as total_rows FROM replication_test;

-- Show recent records
SELECT id, test_name, created_at
FROM replication_test
ORDER BY id DESC
FETCH FIRST 5 ROWS ONLY;
EXIT;
EOF
```

**Expected**: All committed transactions before failure should be present (zero data loss with FASTSYNC)

---

### Step 6: Resume Operations

At this point:
- ✅ cdb1_stby is PRIMARY and accepting connections
- ✅ Applications can reconnect to standby VM (192.168.56.102:1521)
- ✅ Old primary (cdb1) is DISABLED and needs reinstatement

**Critical**: The old primary is **NOT** automatically available as standby. It must be **reinstated** to restore high availability.

---

## Part 2: Reinstate Old Primary Using FLASHBACK

### What is FLASHBACK DATABASE Reinstatement?

After failover, the old primary database:
- Has diverged from the new primary
- Cannot simply restart as standby
- Would traditionally require full rebuild (~20-30 minutes)

**FLASHBACK DATABASE** allows:
- ✅ Rewind database to consistent point before failover
- ✅ Automatic conversion to standby role
- ✅ Completion in ~16 seconds vs ~30 minutes rebuild
- ✅ **72x faster recovery!**

---

### Step 7: Start Old Primary in MOUNT Mode

Connect to **primary VM** (old primary):

```bash
vagrant ssh primary
sudo su - oracle

sqlplus / as sysdba << EOF
STARTUP MOUNT;
EXIT;
EOF
```

**Expected Output**:
```
ORACLE instance started.
Total System Global Area 1610612080 bytes
...
Database mounted.
```

**Important**: Start in **MOUNT** mode, not OPEN mode. FLASHBACK requires MOUNT mode.

---

### Step 8: Reinstate Using FLASHBACK DATABASE

From **standby VM** (new primary):

```bash
vagrant ssh standby
sudo su - oracle

dgmgrl sys/"S1sPassword1!" << EOF
REINSTATE DATABASE cdb1;
SHOW DATABASE cdb1;
EXIT;
EOF
```

**Expected Output**:
```
Reinstating database "cdb1", please wait...
Reinstatement of database "cdb1" succeeded     ← SUCCESS in ~16 seconds

Database - cdb1
  Role:                PHYSICAL STANDBY       ← NOW STANDBY
  Intended State:      APPLY-ON
  Transport Lag:       0 seconds
  Apply Lag:           (unknown)              ← Will clear shortly

Database Status: WARNING                      ← Normal initially
```

**Reinstate Duration**: ~16 seconds

**What Happened Behind the Scenes**:
1. DGMGRL connected to old primary
2. Executed `FLASHBACK DATABASE` to SCN before divergence
3. Converted database from PRIMARY to PHYSICAL STANDBY role
4. Started managed recovery (MRP0 process)
5. Old primary now catching up with redo from new primary

---

### Step 9: Wait for Synchronization

Wait 60 seconds for apply lag to clear:

```bash
sleep 60

dgmgrl sys/"S1sPassword1!" << EOF
SHOW CONFIGURATION;
SHOW DATABASE cdb1_stby;
SHOW DATABASE cdb1;
EXIT;
EOF
```

**Expected Output**:
```
Configuration Status: SUCCESS  ← Configuration healthy!

Database - cdb1_stby
  Role:                PRIMARY
  Database Status:     SUCCESS

Database - cdb1
  Role:                PHYSICAL STANDBY
  Transport Lag:       0 seconds           ← FULLY SYNCED
  Apply Lag:           0 seconds           ← FULLY SYNCED
  Average Apply Rate:  33.00 KByte/s
  Database Status:     SUCCESS             ← Sync complete!
```

**Sync Duration**: ~60 seconds after reinstatement

---

### Step 10: Verify MRP Process Running

On **primary VM** (reinstated standby):

```bash
ps -ef | grep -i 'ora_mrp0' | grep -v grep
```

**Expected Output**:
```
oracle  12345  1  0 05:16 ?  00:00:00 ora_mrp0_cdb1   ← Recovery active
```

This confirms the standby is actively applying redo logs.

---

## Part 3: Return to Original Configuration (Optional)

If you want to return to the original configuration (cdb1 as primary):

```bash
# From standby VM (current primary)
dgmgrl sys/"S1sPassword1!" << EOF
SWITCHOVER TO cdb1;
SHOW CONFIGURATION;
EXIT;
EOF
```

See `DGMGRL_SWITCHOVER_GUIDE.md` for detailed switchover procedures.

---

## Common Issues

### Issue 1: REINSTATE Fails (ORA-16653)

**Symptom**:
```
Error: ORA-16653: failed to reinstate database
Reinstatement of database "cdb1" failed
```

**Cause**: Database not in correct state (not mounted or FLASHBACK disabled)

**Solution**:

1. Verify database is MOUNTED:
   ```bash
   vagrant ssh primary
   sudo su - oracle
   sqlplus / as sysdba <<< "SELECT status FROM v\$instance;"
   # Should show: MOUNTED
   ```

2. If not mounted, start it:
   ```bash
   sqlplus / as sysdba << EOF
   STARTUP MOUNT;
   EXIT;
   EOF
   ```

3. Retry REINSTATE from new primary

---

### Issue 2: FLASHBACK Not Enabled (ORA-38706)

**Symptom**:
```
ORA-38706: Cannot turn on FLASHBACK DATABASE logging
```

**Cause**: FLASHBACK DATABASE was not enabled on primary

**Solution**: Without FLASHBACK, you must rebuild the standby using RMAN DUPLICATE (~20-30 minutes):

```bash
# This is complex - contact your DBA or see Oracle documentation
# Basic steps:
# 1. Remove old database from broker configuration
# 2. Delete old database files
# 3. Use RMAN DUPLICATE to rebuild from backup
# 4. Re-add to broker configuration
```

**Prevention**: Always enable FLASHBACK during initial setup (already configured in this project)

---

### Issue 3: High Apply Lag After Reinstatement

**Symptom**:
```
Apply Lag: 2 minutes 15 seconds
```

**Is This Normal?** **YES!** for 1-2 minutes after reinstatement

**What's Happening**: Old primary is catching up with redo generated during the failover window

**Solution**: Wait and monitor. Check progress:

```bash
watch -n 5 "dgmgrl sys/\"S1sPassword1!\" <<< 'SHOW DATABASE cdb1' | grep -E 'Lag:|Apply Rate'"
```

**Expected**:
- Apply lag decreasing steadily
- Average Apply Rate showing several KB/s or MB/s
- After 1-2 minutes: Apply Lag = 0 seconds

---

### Issue 4: Protection Mode Warning After Failover

**Symptom**:
```
ORA-16627: no member available to support the protection mode
Database Status: WARNING
```

**Cause**: After failover, there's only one database (no standby yet)

**Is This a Problem?** Not initially. This is expected until reinstatement completes.

**Solution**: Complete reinstatement (Steps 7-9). Warning will clear automatically.

---

### Issue 5: Cannot Connect to PDB on Old Primary After Reinstate

**Symptom**:
```
ORA-01219: database or pluggable database not open
```

**Is This Expected?** **YES!** This is correct behavior.

**Why**: Standby databases run in MOUNT mode. PDBs are **NOT accessible** on standby databases (requires Active Data Guard license for read-only access).

**Solution**: Connect to the **PRIMARY** database (cdb1_stby on standby VM) for PDB access.

---

### Issue 6: Old Primary Won't Start (ORA-01033)

**Symptom**:
```
ORA-01033: ORACLE initialization or shutdown in progress
```

**Cause**: Database is still shutting down from crash

**Solution**: Wait 30 seconds and retry, or force cleanup:

```bash
sqlplus / as sysdba << EOF
SHUTDOWN ABORT;
STARTUP MOUNT;
EXIT;
EOF
```

---

## Performance Benchmarks

Based on testing with Oracle 21c on VirtualBox VMs (4GB RAM, 2 CPUs):

| Operation | Duration | Method |
|-----------|----------|--------|
| **Primary crash detection** | Instant | - |
| **Failover to standby** | 4-5 seconds | DGMGRL FAILOVER |
| **Start old primary (MOUNT)** | 20-30 seconds | STARTUP MOUNT |
| **FLASHBACK reinstatement** | 16 seconds | REINSTATE DATABASE |
| **Apply lag synchronization** | 60 seconds | Automatic |
| **Total recovery time** | ~80 seconds | Full HA restored |
| **Traditional rebuild** | 20-30 minutes | RMAN DUPLICATE |
| **Time saved with FLASHBACK** | **72x faster** | 16s vs 30min |

---

## Decision Tree: Failover vs Switchover

```
Is the primary database available and healthy?
│
├─ YES → Use SWITCHOVER (see DGMGRL_SWITCHOVER_GUIDE.md)
│         - Zero data loss guaranteed
│         - Fully automated role reversal
│         - Both databases participate
│         - ~30 seconds duration
│
└─ NO → Use FAILOVER (this guide)
          - Emergency operation
          - Standby-only operation
          - ~4-5 seconds duration
          - Requires reinstatement after recovery
```

---

## Testing Failover (Practice Run)

To practice failover in a safe environment:

### 1. Simulate Primary Crash

```bash
vagrant ssh primary
sudo su - oracle
sqlplus / as sysdba <<< "SHUTDOWN ABORT;"
```

### 2. Perform Failover

Follow Steps 2-6 above

### 3. Verify Data Integrity

Check that all data is accessible on new primary (Step 5)

### 4. Reinstate Old Primary

Follow Steps 7-9 above

### 5. Return to Original Configuration

Use SWITCHOVER to restore original roles:

```bash
dgmgrl sys/"S1sPassword1!" <<< "SWITCHOVER TO cdb1"
```

**Recommendation**: Practice failover quarterly to ensure team readiness and verify FLASHBACK is working.

---

## Summary

This guide provides emergency failover and reinstatement procedures for Oracle Data Guard:

### Failover (~5 seconds)
✅ Emergency promotion of standby to primary
✅ Zero data loss with synchronous transport
✅ Fastest possible recovery
✅ Operations resume immediately

### FLASHBACK Reinstatement (~16 seconds)
✅ Rewind old primary to consistent state
✅ Automatic conversion to standby role
✅ 72x faster than traditional rebuild
✅ High availability restored in ~80 seconds total

### Key Advantages Over Traditional Methods
- **No backup restore required** (RMAN DUPLICATE avoided)
- **No full database copy** (network bandwidth saved)
- **Minimal manual intervention** (DGMGRL automates everything)
- **Fast return to HA** (80 seconds vs 30+ minutes)

### When FLASHBACK Reinstatement Cannot Be Used
- FLASHBACK DATABASE not enabled (must rebuild with RMAN)
- Storage failure corrupted FLASHBACK logs (must rebuild)
- Database files physically lost (must restore from backup)

**Related Guides**:
- `DGMGRL_SWITCHOVER_GUIDE.md` - Planned role reversal
- `TESTING_GUIDE_UPDATED.md` - Complete testing procedures

---

**Last Tested**: 2025-11-10
**Oracle Version**: 21c Enterprise Edition
**Data Guard Version**: 21.3.0.0.0
**FLASHBACK Enabled**: YES
**Test Result**: ✅ FAILOVER SUCCESSFUL - ZERO DATA LOSS - REINSTATE IN 16 SECONDS
