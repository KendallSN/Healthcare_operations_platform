# deploy.ps1
# Automated Oracle Data Guard deployment with comprehensive logging
# Usage: .\deploy.ps1

# Enable strict mode
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Color output functions
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success { Write-ColorOutput Green $args }
function Write-Warning { Write-ColorOutput Yellow $args }
function Write-Error { Write-ColorOutput Red $args }
function Write-Info { Write-ColorOutput Cyan $args }

# Function to locate VBoxManage.exe
function Get-VBoxManagePath {
    # Check if VBoxManage.exe is in PATH
    $vboxInPath = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
    if ($vboxInPath) {
        return "VBoxManage.exe"
    }

    # Check common installation paths
    $commonPaths = @(
        "${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles}\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\VirtualBox\VBoxManage.exe"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# Create timestamped log directory (in powershell subdirectory)
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$scriptDir = $PSScriptRoot
$logDir = Join-Path $scriptDir "logs\deploy-$timestamp"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Info "=========================================="
Write-Info "Oracle Data Guard Automated Deployment"
Write-Info "=========================================="
Write-Info "Log directory: $logDir"
Write-Info ""

$deploymentStart = Get-Date

# Phase 1: Prerequisites Check
Write-Info "[Phase 1/6] Prerequisites Check"
$prereqLog = "$logDir\00-prerequisites.log"
$prereqStart = Get-Date

try {
    # Check Oracle software exists
    Write-Info "  → Checking Oracle software..."
    $oracleSoftware = "..\software\LINUX.X64_213000_db_home.zip"
    if (!(Test-Path $oracleSoftware)) {
        Write-Error "FATAL: Oracle software not found at $oracleSoftware"
        Write-Error "Please download Oracle Database 21c Enterprise Edition from oracle.com"
        "FATAL: Oracle software not found at $oracleSoftware" | Out-File -FilePath $prereqLog
        exit 1
    }
    $oracleSize = (Get-Item $oracleSoftware).Length / 1GB
    Write-Success "  [OK] Oracle software found ($([math]::Round($oracleSize, 2)) GB)"
    "Oracle software: $oracleSoftware (Size: $oracleSize GB)" | Out-File -FilePath $prereqLog

    # Check VirtualBox is running
    Write-Info "  → Checking VirtualBox service..."
    $vboxService = Get-Service -Name "VBoxSDS" -ErrorAction SilentlyContinue
    if (!$vboxService) {
        Write-Warning "  [WARNING] VirtualBox service not found (may be OK if running as application)"
        "VirtualBox service: Not found (may be application mode)" | Out-File -FilePath $prereqLog -Append
    } else {
        if ($vboxService.Status -ne "Running") {
            Write-Warning "  [WARNING] VirtualBox service is not running, attempting to start..."
            Start-Service -Name "VBoxSDS"
            Start-Sleep -Seconds 2
        }
        Write-Success "  [OK] VirtualBox service is running"
        "VirtualBox service: Running" | Out-File -FilePath $prereqLog -Append
    }

    # Check VBoxManage is accessible
    Write-Info "  → Verifying VBoxManage executable..."
    $script:VBoxManage = Get-VBoxManagePath
    if (!$script:VBoxManage) {
        Write-Error "FATAL: VBoxManage.exe not found. Please install VirtualBox and ensure it's in PATH or installed in a standard location."
        "FATAL: VBoxManage.exe not found in PATH or common installation directories" | Out-File -FilePath $prereqLog -Append
        exit 1
    }
    try {
        $vboxVersion = & $script:VBoxManage --version 2>&1
        Write-Success "  [OK] VBoxManage found: $vboxVersion"
        "VBoxManage path: $script:VBoxManage" | Out-File -FilePath $prereqLog -Append
        "VBoxManage version: $vboxVersion" | Out-File -FilePath $prereqLog -Append
    } catch {
        Write-Error "FATAL: VBoxManage.exe found but failed to execute: $_"
        "FATAL: VBoxManage.exe execution failed: $_" | Out-File -FilePath $prereqLog -Append
        exit 1
    }

    # Check Vagrant is installed
    Write-Info "  → Checking Vagrant installation..."
    try {
        $vagrantVersion = vagrant --version 2>&1
        Write-Success "  [OK] Vagrant found: $vagrantVersion"
        "Vagrant version: $vagrantVersion" | Out-File -FilePath $prereqLog -Append
    } catch {
        Write-Error "FATAL: vagrant command not found. Please install Vagrant."
        "FATAL: vagrant not found" | Out-File -FilePath $prereqLog -Append
        exit 1
    }

    $prereqElapsed = (Get-Date) - $prereqStart
    Write-Success "  [OK] Prerequisites check completed ($($prereqElapsed.TotalSeconds.ToString('F1'))s)`n"
} catch {
    Write-Error "Prerequisites check failed: $_"
    $_ | Out-File -FilePath $prereqLog -Append
    exit 1
}

# Change to project root for Vagrant operations
Write-Info "  → Changing to project root directory..."
$projectRoot = Split-Path -Parent $scriptDir
Set-Location $projectRoot
Write-Success "  [OK] Working directory: $(Get-Location)`n"

# Phase 2: Fix line endings
Write-Info "[Phase 2/6] Fixing Line Endings"
$lineEndingLog = "$logDir\01-line-endings.log"
$lineEndingStart = Get-Date

try {
    Write-Info "  → Running fix-line-endings.ps1..."
    & powershell -ExecutionPolicy Bypass -File .\powershell\fix-line-endings.ps1 | Tee-Object -FilePath $lineEndingLog
    $lineEndingElapsed = (Get-Date) - $lineEndingStart
    Write-Success "  [OK] Line endings fixed ($($lineEndingElapsed.TotalSeconds.ToString('F1'))s)`n"
} catch {
    Write-Error "Line ending fix failed: $_"
    $_ | Out-File -FilePath $lineEndingLog -Append
    exit 1
}

# Phase 3: Cleanup stale VMs
Write-Info "[Phase 3/6] Cleaning Up Stale VMs"
$cleanupLog = "$logDir\02-cleanup.log"
$cleanupStart = Get-Date

try {
    # Destroy any existing Vagrant VMs
    Write-Info "  → Running vagrant destroy -f..."
    "=== Vagrant Destroy Output ===" | Out-File -FilePath $cleanupLog
    vagrant destroy -f primary standby 2>&1 | Tee-Object -FilePath $cleanupLog -Append

    # Unregister any Oracle Linux VMs from VirtualBox
    Write-Info "  → Checking for stale VirtualBox VMs..."
    $vms = & $script:VBoxManage list vms 2>&1 | Select-String "ol8_21"
    if ($vms) {
        Write-Info "  → Found stale VMs, unregistering..."
        foreach ($vm in $vms) {
            $vmName = $vm -replace '.*"(.+)".*', '$1'
            Write-Info "    - Unregistering: $vmName"
            & $script:VBoxManage unregistervm $vmName --delete 2>&1 | Out-File -FilePath $cleanupLog -Append
        }
        Write-Success "  [OK] Stale VMs removed"
    } else {
        Write-Success "  [OK] No stale VMs found"
    }

    # Delete orphaned VM directories
    Write-Info "  → Cleaning up VM directories..."
    $vboxVmsPath = "$env:USERPROFILE\VirtualBox VMs"
    if (Test-Path $vboxVmsPath) {
        Get-ChildItem $vboxVmsPath | Where-Object { $_.Name -like "*ol8_21*" -or $_.Name -like "*vagrant-virtualbox*" } | ForEach-Object {
            Write-Info "    - Removing: $($_.Name)"
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $cleanupElapsed = (Get-Date) - $cleanupStart
    Write-Success "  [OK] Cleanup completed ($($cleanupElapsed.TotalSeconds.ToString('F1'))s)`n"
} catch {
    Write-Warning "Cleanup encountered errors (may be OK): $_"
    $_ | Out-File -FilePath $cleanupLog -Append
}

# Phase 4: Deploy Primary
Write-Info "[Phase 4/6] Deploying Primary Database"
$primaryLog = "$logDir\03-primary-vagrant.log"
$primaryStart = Get-Date

try {
    Write-Info "  → Running vagrant up primary (this may take 30-45 minutes)..."
    "=== PRIMARY DEPLOYMENT STARTED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $primaryLog
    vagrant up primary 2>&1 | Tee-Object -FilePath $primaryLog -Append

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Primary deployment failed with exit code $LASTEXITCODE"
        "FATAL: Deployment failed with exit code $LASTEXITCODE" | Out-File -FilePath $primaryLog -Append
        exit 1
    }

    $primaryElapsed = (Get-Date) - $primaryStart
    Write-Success "  [OK] Primary deployed successfully ($($primaryElapsed.TotalMinutes.ToString('F1')) minutes)`n"
    "=== PRIMARY DEPLOYMENT COMPLETED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $primaryLog -Append
    "Total time: $($primaryElapsed.TotalMinutes.ToString('F1')) minutes" | Out-File -FilePath $primaryLog -Append
} catch {
    Write-Error "Primary deployment failed: $_"
    $_ | Out-File -FilePath $primaryLog -Append
    exit 1
}

# Phase 5: Deploy Standby
Write-Info "[Phase 5/6] Deploying Standby Database"
$standbyLog = "$logDir\04-standby-vagrant.log"
$standbyStart = Get-Date

try {
    Write-Info "  → Running vagrant up standby (this may take 20-30 minutes)..."
    "=== STANDBY DEPLOYMENT STARTED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $standbyLog
    vagrant up standby 2>&1 | Tee-Object -FilePath $standbyLog -Append

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Standby deployment failed with exit code $LASTEXITCODE"
        "FATAL: Deployment failed with exit code $LASTEXITCODE" | Out-File -FilePath $standbyLog -Append
        exit 1
    }

    $standbyElapsed = (Get-Date) - $standbyStart
    Write-Success "  [OK] Standby deployed successfully ($($standbyElapsed.TotalMinutes.ToString('F1')) minutes)`n"
    "=== STANDBY DEPLOYMENT COMPLETED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $standbyLog -Append
    "Total time: $($standbyElapsed.TotalMinutes.ToString('F1')) minutes" | Out-File -FilePath $standbyLog -Append
} catch {
    Write-Error "Standby deployment failed: $_"
    $_ | Out-File -FilePath $standbyLog -Append
    exit 1
}

# Phase 6: Collect VM Logs
Write-Info "[Phase 6/6] Collecting VM Logs"
$vmLogsStart = Get-Date

try {
    # Primary alert log
    Write-Info "  → Fetching primary alert log..."
    $primaryAlertLog = "$logDir\05-primary-alert.log"
    vagrant ssh primary -c "sudo tail -1000 /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log" 2>&1 | Out-File -FilePath $primaryAlertLog -Encoding UTF8

    # Primary listener log
    Write-Info "  → Fetching primary listener log..."
    $primaryListenerLog = "$logDir\05-primary-listener.log"
    vagrant ssh primary -c "sudo tail -500 /u01/app/oracle/diag/tnslsnr/*/listener/alert/log.xml" 2>&1 | Out-File -FilePath $primaryListenerLog -Encoding UTF8

    # Standby alert log
    Write-Info "  → Fetching standby alert log..."
    $standbyAlertLog = "$logDir\06-standby-alert.log"
    vagrant ssh standby -c "sudo tail -1000 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log" 2>&1 | Out-File -FilePath $standbyAlertLog -Encoding UTF8

    # Standby listener log
    Write-Info "  → Fetching standby listener log..."
    $standbyListenerLog = "$logDir\06-standby-listener.log"
    vagrant ssh standby -c "sudo tail -500 /u01/app/oracle/diag/tnslsnr/*/listener/alert/log.xml" 2>&1 | Out-File -FilePath $standbyListenerLog -Encoding UTF8

    # Data Guard status
    Write-Info "  → Fetching Data Guard configuration status..."
    $dgStatusLog = "$logDir\07-dataguard-status.log"
    vagrant ssh primary -c "sudo su - oracle -c '/home/oracle/automation/verify_dataguard.sh'" 2>&1 | Out-File -FilePath $dgStatusLog -Encoding UTF8

    $vmLogsElapsed = (Get-Date) - $vmLogsStart
    Write-Success "  [OK] VM logs collected ($($vmLogsElapsed.TotalSeconds.ToString('F1'))s)`n"
} catch {
    Write-Warning "VM log collection encountered errors: $_"
}

# Generate deployment summary
$deploymentElapsed = (Get-Date) - $deploymentStart
$summaryFile = "$logDir\DEPLOYMENT-SUMMARY.txt"

$summary = @"
========================================
ORACLE DATA GUARD DEPLOYMENT SUMMARY
========================================

Deployment Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Log Directory: $logDir

----------------------------------------
TIMING
----------------------------------------
Prerequisites Check:  $($prereqElapsed.TotalSeconds.ToString('F1'))s
Line Endings Fix:     $($lineEndingElapsed.TotalSeconds.ToString('F1'))s
Cleanup:              $($cleanupElapsed.TotalSeconds.ToString('F1'))s
Primary Deployment:   $($primaryElapsed.TotalMinutes.ToString('F1')) minutes
Standby Deployment:   $($standbyElapsed.TotalMinutes.ToString('F1')) minutes
VM Logs Collection:   $($vmLogsElapsed.TotalSeconds.ToString('F1'))s

TOTAL TIME: $($deploymentElapsed.TotalMinutes.ToString('F1')) minutes

----------------------------------------
CONFIGURATION
----------------------------------------
Primary:  ol8-21-dg1.localdomain (192.168.56.101)
  Database: cdb1
  PDB: pdb1
  Port: 1521

Standby:  ol8-21-dg2.localdomain (192.168.56.102)
  Database: cdb1_stby
  Port: 1522

Protection Mode: MAXAVAILABILITY
Transport Mode:  FASTSYNC (synchronous)
Archive Lag:     300 seconds (5 minutes)
Flashback:       ENABLED (both databases)

----------------------------------------
NEXT STEPS
----------------------------------------
1. Verify Data Guard status:
   vagrant ssh primary
   sudo su - oracle
   /home/oracle/automation/verify_dataguard.sh

2. Check flashback is enabled:
   dgmgrl sys/S1sPassword1!@cdb1.localdomain
   SHOW CONFIGURATION;

3. Setup SSH keys for backups (run on both nodes):
   vagrant ssh primary
   sudo su - oracle
   /home/oracle/automation/setup_ssh_keys.sh

4. Install cron jobs (run on both nodes):
   /home/oracle/automation/install_cron_jobs.sh

5. Access databases from Windows:
   Primary CDB:  sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba
   Primary PDB:  sqlplus sys/S1sPassword1!@localhost:1521/pdb1 as sysdba
   Standby CDB:  sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba

----------------------------------------
LOG FILES
----------------------------------------
$(Get-ChildItem $logDir | ForEach-Object { "  - $($_.Name)" } | Out-String)

========================================
DEPLOYMENT COMPLETED SUCCESSFULLY
========================================
"@

$summary | Out-File -FilePath $summaryFile -Encoding UTF8

Write-Success "=========================================="
Write-Success "DEPLOYMENT COMPLETED SUCCESSFULLY"
Write-Success "=========================================="
Write-Success "Total time: $($deploymentElapsed.TotalMinutes.ToString('F1')) minutes"
Write-Success "Logs saved to: $logDir"
Write-Info ""
Write-Info "Review the deployment summary:"
Write-Info "  type $summaryFile"
Write-Info ""
Write-Info "To verify Data Guard:"
Write-Info "  vagrant ssh primary"
Write-Info "  sudo su - oracle"
Write-Info "  /home/oracle/automation/verify_dataguard.sh"
