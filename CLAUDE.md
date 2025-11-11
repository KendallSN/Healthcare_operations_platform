# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Oracle 21c Data Guard high availability infrastructure with a simple test schema for verifying replication capabilities.

The project consists of two independent components:
1. **Database Schema & Business Logic** (`1-BD/`) - Oracle PL/SQL database with healthcare management system (managed by separate team)
2. **Infrastructure** (`2-Standby/`) - **STANDALONE** Oracle Data Guard setup with simple test schema for replication testing

**IMPORTANT**: The `2-Standby/` infrastructure is completely independent and does NOT depend on `1-BD/` files. It includes its own simple schema for testing Data Guard replication.

## Repository Structure

**IMPORTANT**: The `1-BD/` folder is managed by a separate team member. Do NOT modify files in `1-BD/` unless explicitly requested and coordinating with the database team.

```
ROOT/
├── 1-BD/                          # Database schema & scripts (DO NOT MODIFY without coordination)
│   ├── ScriptProyectoBD.SQL       # Main schema creation (tables, sequences, triggers)
│   ├── data.sql                   # Sample/test data
│   ├── ExecutionScript.sql        # Usage examples for procedures
│   ├── PKG_UTILITIES.PKG          # Core utility package
│   ├── Payrolls/                  # Payroll generation procedures
│   ├── MonthScales/               # Monthly schedule management
│   ├── Emails/                    # Email notification system
│   ├── LogBooks/                  # Audit logging system
│   ├── NationalRegister/          # National ID verification
│   └── Tests/                     # Database tests
│
├── 2-Standby/                     # Oracle Data Guard infrastructure (STANDALONE)
│   ├── schema/                    # Simple test schema for Data Guard testing
│   │   └── simple_schema.sql      # Tables, sequences, procedures for replication testing
│   ├── scripts/primary/           # Primary DB setup scripts
│   ├── scripts/standby/           # Standby DB setup scripts
│   ├── scripts/optional/          # Optional on-demand provisioners
│   ├── automation/                # Cron jobs, backups, monitoring
│   └── infrastructure/            # Common infrastructure scripts
│
├── powershell/                    # Deployment automation
│   ├── deploy.ps1                 # Full deployment orchestrator
│   ├── destroy.ps1                # Environment cleanup
│   └── fix-line-endings.ps1       # Convert CRLF to LF for shell scripts
│
├── config/                        # Configuration
│   ├── vagrant.yml                # VM specifications
│   └── install.env                # Environment variables (passwords, paths)
│
├── software/                      # Oracle installation files
│   └── LINUX.X64_213000_db_home.zip
│
└── Vagrantfile                    # VM orchestration
```

## Deployment Commands

### Full Environment Deployment
```powershell
# From project root - deploys primary and standby databases with Data Guard
.\powershell\deploy.ps1
```

This runs a 6-phase deployment:
1. Prerequisites check (Oracle software, VirtualBox, Vagrant)
2. Fix line endings for shell scripts
3. Cleanup stale VMs
4. Deploy primary database (30-45 minutes)
5. Deploy standby database (20-30 minutes)
6. Collect logs and verification

### Individual VM Operations
```bash
# From project root
vagrant up primary          # Deploy only primary database
vagrant up standby          # Deploy only standby database
vagrant ssh primary         # SSH into primary VM
vagrant ssh standby         # SSH into standby VM
vagrant destroy -f          # Destroy all VMs
```

### Environment Cleanup
```powershell
.\powershell\destroy.ps1    # Full cleanup including VirtualBox artifacts
```

## Database Development Workflow

### Schema Deployment Process

The simple test schema is deployed automatically during `vagrant up primary` via:
- Schema scripts on VM: `/vagrant/2-Standby/schema/` (simple_schema.sql)
- Deployment script: `2-Standby/scripts/primary/deploy_custom_schema.sh`
- Target: PDB named `pdb1` with schema user `dgtest`
- User creation: Performed inline within deploy_custom_schema.sh (no separate SQL file)
- Tablespace: Uses default `USERS` tablespace (no custom tablespace needed)

### Manual Database Operations

Connect to the database from Windows host:
```bash
# Primary CDB (Container Database)
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

# Primary PDB (Pluggable Database - where test schema lives)
sqlplus sys/S1sPassword1!@localhost:1521/pdb1 as sysdba

# Test schema (Data Guard replication testing)
sqlplus dgtest/DGTest2025!@localhost:1521/pdb1

# Standby CDB
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba

# Standby PDB (read-only - for verifying replication)
sqlplus sys/S1sPassword1!@localhost:1522/pdb1 as sysdba
```

### Testing Data Guard Replication

The simple test schema provides easy ways to verify Data Guard replication:

**1. Insert Test Data on Primary**
```sql
-- Connect to primary database
sqlplus dgtest/DGTest2025!@localhost:1521/pdb1

-- Insert test data using the procedure
DECLARE
  v_test_id NUMBER;
BEGIN
  insert_test_data('My Test Record', 'Testing Data Guard replication', v_test_id);
  DBMS_OUTPUT.PUT_LINE('Created test record with ID: ' || v_test_id);
END;
/

-- Or insert directly
INSERT INTO replication_test (id, test_name, test_data)
VALUES (seq_replication_test.NEXTVAL, 'Manual Test', 'Inserted at ' || SYSTIMESTAMP);
COMMIT;
```

**2. Verify Replication on Standby**
```sql
-- Connect to standby database (read-only)
sqlplus dgtest/DGTest2025!@localhost:1522/pdb1

-- Query replicated data
SELECT id, test_name, created_at, created_on_db
FROM replication_test
ORDER BY created_at DESC;

-- Check replication status
SET SERVEROUTPUT ON
EXEC check_replication_status;
```

**3. Monitor Data Guard Lag**
```bash
# SSH into primary VM
vagrant ssh primary

# Run Data Guard verification script
/home/oracle/automation/verify_dataguard.sh

# Check log transport status
/home/oracle/automation/check_log_transport.sh
```

### Test Schema Components

**Schema User**: `dgtest` (password: `DGTest2025!`)

**Test Tables**:
- `replication_test` - Main test table with timestamps and DB name tracking
- `replication_details` - Secondary table for testing foreign key replication
- `audit_log` - Simple audit trail for tracking operations

**Sequences**:
- `seq_replication_test` - ID generator for replication_test
- `seq_replication_details` - ID generator for replication_details
- `seq_audit_log` - ID generator for audit_log

**Procedures**:
- `insert_test_data(test_name, test_data, OUT test_id)` - Insert test records with automatic auditing
- `check_replication_status()` - Display replication status and record counts

**Key Columns for Testing**:
- `created_at` - Timestamp when record was created (compare primary vs standby)
- `updated_at` - Timestamp when record was last updated
- `created_on_db` - Database unique name where record originated

## Infrastructure Details

### Data Guard Configuration

- **Protection Mode**: MAXAVAILABILITY (synchronous with zero data loss)
- **Transport Mode**: FASTSYNC
- **Archive Lag Target**: 300 seconds (5 minutes)
- **Flashback**: Enabled on both databases

**Primary Database**:
- Hostname: ol8-21-dg1.localdomain (192.168.56.101)
- Database: cdb1 / pdb1
- Port: 1521

**Standby Database**:
- Hostname: ol8-21-dg2.localdomain (192.168.56.102)
- Database: cdb1_stby
- Port: 1522 (forwarded)

### Monitoring & Maintenance

Inside VMs:
```bash
# Verify Data Guard status
/home/oracle/automation/verify_dataguard.sh

# Manual backup
/home/oracle/automation/manual_backup.sh

# Check log transport
/home/oracle/automation/check_log_transport.sh

# Setup SSH keys for backups
/home/oracle/automation/setup_ssh_keys.sh

# Install cron jobs (backups, archive cleanup, monitoring)
/home/oracle/automation/install_cron_jobs.sh
```

### Configuration Files

**`config/install.env`** - Key environment variables:
- Database credentials (SYS_PASSWORD, PDB_PASSWORD, APP_SCHEMA_PASSWORD)
- Test schema configuration (APP_SCHEMA=dgtest, uses default USERS tablespace)
- Network configuration (NODE1_PUBLIC_IP, NODE2_PUBLIC_IP)
- Data Guard settings (PROTECTION_MODE, ARCHIVE_LAG_TARGET)
- Backup settings (BACKUP_RETENTION_DAYS, ARCHIVE_RETENTION_DAYS)

**`config/vagrant.yml`** - VM specifications:
- Memory: 4096 MB per node
- CPUs: 2 per node
- Disk: 100GB each for u01 (software/data) and u02 (backups)

## Critical Path References

When modifying infrastructure:

1. **Database schema path**: Scripts reference `/vagrant/2-Standby/schema/` inside VMs (completely standalone)
2. **Vagrantfile syncs**:
   - Root directory → `/vagrant`
   - `config/` → `/vagrant_config`
   - `software/` → `/vagrant_software`
   - `2-Standby/scripts/` → accessed via `/vagrant/2-Standby/scripts/`
   - `2-Standby/schema/` → accessed via `/vagrant/2-Standby/schema/`
   - `2-Standby/automation/` → `/vagrant_automation`
   - `2-Standby/infrastructure/` → `/vagrant_scripts`

3. **PowerShell scripts**: Located in `powershell/` at root, use `..` to reference parent directories

**NOTE**: The obsolete synced folders `1-BD/SQL-VM scripts/` and `1-BD/directories/` have been removed. The 2-Standby infrastructure no longer depends on any 1-BD files.

## Common Issues

**Line endings**: Windows CRLF causes shell script failures in Linux VMs. Always run `.\powershell\fix-line-endings.ps1` before deployment if editing shell scripts on Windows.

**Oracle software**: Must have `LINUX.X64_213000_db_home.zip` in `software/` directory before deployment.

**VM networking**: VMs use private network 192.168.56.x. Ensure no conflicts with existing VirtualBox VMs.

**Data Guard lag**: If standby falls behind, check archive log transport with `check_log_transport.sh` automation script.

**Oracle not starting after VM reload**: By default, Oracle database does not auto-start after `vagrant reload` or VM reboot. To enable auto-start:
```bash
# Enable Oracle auto-start via systemd (one-time setup)
vagrant provision --provision-with setup_oracle_autostart

# Or manually start Oracle when needed
vagrant ssh primary -c "sudo su - oracle -c 'lsnrctl start && sqlplus / as sysdba <<< STARTUP'"
```

**VirtualBox Guest Additions mismatch**: If synced folders fail to mount after `vagrant reload`, the Guest Additions version may not match your VirtualBox version. The `vagrant-vbguest` plugin auto-updates Guest Additions:
```bash
# Install the plugin (one-time)
vagrant plugin install vagrant-vbguest

# Reload VM - plugin will auto-update Guest Additions
vagrant reload
```

**Synced folder errors**: If provisioners report missing files like `/vagrant_config/install.env`, ensure:
1. VirtualBox Guest Additions are up to date (see above)
2. VM was reloaded after Vagrantfile changes: `vagrant reload`
3. Check VM logs: `vagrant ssh -c "ls -la /vagrant_config"`

## Testing

The simple test schema (`dgtest`) is designed for testing Data Guard replication:

```sql
-- Connect to primary
sqlplus dgtest/DGTest2025!@localhost:1521/pdb1

-- Insert test data
EXEC insert_test_data('Test ' || TO_CHAR(SYSDATE, 'HH24:MI:SS'), 'Auto test data');

-- View all test records
SELECT * FROM replication_test ORDER BY created_at DESC;

-- Connect to standby (after waiting for log transport)
sqlplus dgtest/DGTest2025!@localhost:1522/pdb1

-- Verify data replicated
SELECT * FROM replication_test ORDER BY created_at DESC;

-- Check replication status
SET SERVEROUTPUT ON
EXEC check_replication_status;
```

For testing the healthcare schema in `1-BD/`, see `1-BD/Tests/Script-Tests.sql` (requires HEALTHCENTER schema deployment via optional provisioner).
