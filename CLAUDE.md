# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Healthcare Management System with Oracle 21c Data Guard high availability setup. This is a database-centric application managing healthcare centers, users (medics and administrative staff), payrolls, work shifts/schedules (month scales), medical procedures, and document management.

The project consists of two main components:
1. **Database Schema & Business Logic** (`1-BD/`) - Oracle PL/SQL database with healthcare management system
2. **Infrastructure** (`2-Standby/`) - Oracle Data Guard setup for high availability with primary/standby replication

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
├── 2-Standby/                     # Oracle Data Guard infrastructure
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

The database schema is deployed automatically during `vagrant up primary` via:
- Script location on VM: `/vagrant/1-BD/ScriptProyectoBD.SQL`
- Deployment script: `2-Standby/scripts/primary/deploy_custom_schema.sh`
- Target: PDB named `pdb1` with schema user `HEALTHCENTER`

### Manual Database Operations

Connect to the database from Windows host:
```bash
# Primary CDB (Container Database)
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

# Primary PDB (Pluggable Database - where app schema lives)
sqlplus sys/S1sPassword1!@localhost:1521/pdb1 as sysdba

# Application schema (healthcare system)
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1

# Standby CDB
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba
```

### Key Procedures & Workflow

The healthcare system follows this operational workflow:

**1. Create Monthly Work Schedule (Month Scale)**
```sql
-- Generate month scale for health center
-- Parameters: month ('01'-'12'), year (YYYY), health_center_id
EXEC generate_month_scale('10', 2025, 1);
```

**2. Approve Month Scale & Mark Shifts Complete**
```sql
-- Marks all shifts in the month scale as finished ('F')
-- Changes month scale state to 'P' (Payment pending)
EXEC pkg_utilities.approve_month_scale(1);  -- param: MSC_id
```

**3. Generate Payroll**
```sql
-- Generate payroll for specific month, year, and payroll type
-- Payroll Type: 1=Medics, 2=Administrative
EXEC generate_payroll('10', 2025, 1);
```

**4. Process Payment**
```sql
-- Generate payment calculations for payroll
EXEC PCD_GeneratePayment(1);  -- param: PRL_id
```

### Application Schema Key Components

**Schema User**: `HEALTHCENTER` (password: `HCApp2025!`)

**Core Tables**:
- `HC_User` - Users (medics and administrative staff)
- `HC_HealthCenter` - Healthcare facilities
- `HC_MonthScale` - Monthly work schedules per health center
- `HC_TurnXMonthScale` - Individual work shifts/turns in a month
- `HC_Payroll` - Payroll records (monthly)
- `HC_PayrollXUser` - Payroll per user
- `HC_PayrollMovement` - Individual payroll line items (incomes/deductions)
- `HC_Procedure` - Medical procedures performed (generates revenue for medics)
- `HC_Position` - Job positions at health centers
- `HC_Turn` - Base turn/shift definitions

**Key Packages**:
- `PKG_UTILITIES` - Core utilities (approve_month_scale, etc.)
- `PKG_LOGBOOK` - Audit logging
- `PKG_EMAILS` - Email notifications
- `PKG_FUNCTIONS_JOBS` - Scheduled job functions

**Month Scale States**: B=Building, A=Active, R=Review, P=Payment, C=Complete
**Payroll Movement Types**: I=Income, D=Deduction
**Amount Types**: A=Absolute, P=Percentage

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
- Network configuration (NODE1_PUBLIC_IP, NODE2_PUBLIC_IP)
- Data Guard settings (PROTECTION_MODE, ARCHIVE_LAG_TARGET)
- Backup settings (BACKUP_RETENTION_DAYS, ARCHIVE_RETENTION_DAYS)

**`config/vagrant.yml`** - VM specifications:
- Memory: 4096 MB per node
- CPUs: 2 per node
- Disk: 100GB each for u01 (software/data) and u02 (backups)

## Critical Path References

When modifying infrastructure:

1. **Database schema path**: Scripts reference `/vagrant/1-BD/ScriptProyectoBD.SQL` inside VMs
2. **Vagrantfile syncs**:
   - Root directory → `/vagrant`
   - `config/` → `/vagrant_config`
   - `software/` → `/vagrant_software`
   - `2-Standby/scripts/` → accessed via `/vagrant/2-Standby/scripts/`
   - `2-Standby/automation/` → `/vagrant_automation`
   - `2-Standby/infrastructure/` → `/vagrant_scripts`
   - `1-BD/SQL-VM scripts/` → `/vagrant_sql_scripts`
   - `1-BD/directories/` → `/vagrant_directories`

3. **PowerShell scripts**: Located in `powershell/` at root, use `..` to reference parent directories

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

Database tests located in `1-BD/Tests/Script-Tests.sql`. Connect to PDB as HEALTHCENTER user to run tests.
