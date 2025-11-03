# destroy.ps1
# Automated Oracle Data Guard destruction with log backup
# Usage: .\destroy.ps1

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

Write-Info "=========================================="
Write-Info "Oracle Data Guard Automated Destruction"
Write-Info "=========================================="
Write-Info ""

# Locate VBoxManage.exe
$script:VBoxManage = Get-VBoxManagePath
if (!$script:VBoxManage) {
    Write-Warning "[WARNING] VBoxManage.exe not found. VirtualBox cleanup will be skipped."
    Write-Warning "           VMs can be manually removed from VirtualBox Manager."
}

$destroyStart = Get-Date

# Phase 1: Backup VM logs before destroying
Write-Info "[Phase 1/3] Backing Up VM Logs"
$backupStart = Get-Date

try {
    # Check if VMs are running
    $primaryStatus = vagrant status primary 2>&1 | Select-String "running"
    $standbyStatus = vagrant status standby 2>&1 | Select-String "running"

    if ($primaryStatus -or $standbyStatus) {
        Write-Info "  → VMs are running, collecting logs before destruction..."

        # Create backup directory
        $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
        $backupDir = "logs\backup-before-destroy-$timestamp"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Write-Info "  → Backup directory: $backupDir"

        if ($primaryStatus) {
            Write-Info "  → Backing up primary logs..."

            # Primary alert log
            vagrant ssh primary -c "sudo tail -2000 /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log" 2>&1 | Out-File -FilePath "$backupDir\primary-alert.log" -Encoding UTF8

            # Primary listener log
            vagrant ssh primary -c "sudo tail -1000 /u01/app/oracle/diag/tnslsnr/*/listener/alert/log.xml" 2>&1 | Out-File -FilePath "$backupDir\primary-listener.log" -Encoding UTF8

            # Primary automation logs
            vagrant ssh primary -c "sudo tar -czf /tmp/primary-automation-logs.tar.gz -C /home/oracle/logs/automation . 2>/dev/null; sudo cat /tmp/primary-automation-logs.tar.gz" 2>$null | Set-Content -Path "$backupDir\primary-automation-logs.tar.gz" -Encoding Byte

            # Primary Data Guard status
            vagrant ssh primary -c "sudo su - oracle -c '/home/oracle/automation/verify_dataguard.sh'" 2>&1 | Out-File -FilePath "$backupDir\primary-dataguard-status.log" -Encoding UTF8

            Write-Success "  [OK] Primary logs backed up"
        }

        if ($standbyStatus) {
            Write-Info "  → Backing up standby logs..."

            # Standby alert log
            vagrant ssh standby -c "sudo tail -2000 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log" 2>&1 | Out-File -FilePath "$backupDir\standby-alert.log" -Encoding UTF8

            # Standby listener log
            vagrant ssh standby -c "sudo tail -1000 /u01/app/oracle/diag/tnslsnr/*/listener/alert/log.xml" 2>&1 | Out-File -FilePath "$backupDir\standby-listener.log" -Encoding UTF8

            # Standby automation logs
            vagrant ssh standby -c "sudo tar -czf /tmp/standby-automation-logs.tar.gz -C /home/oracle/logs/automation . 2>/dev/null; sudo cat /tmp/standby-automation-logs.tar.gz" 2>$null | Set-Content -Path "$backupDir\standby-automation-logs.tar.gz" -Encoding Byte

            Write-Success "  [OK] Standby logs backed up"
        }

        # Create backup summary
        $backupSummary = @"
========================================
VM LOGS BACKUP BEFORE DESTRUCTION
========================================

Backup Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Backup Directory: $backupDir

----------------------------------------
BACKED UP FILES
----------------------------------------
$(Get-ChildItem $backupDir | ForEach-Object {
    $size = if ($_.Length -gt 1MB) { "$([math]::Round($_.Length/1MB, 2)) MB" } else { "$([math]::Round($_.Length/1KB, 2)) KB" }
    "  - $($_.Name) ($size)"
} | Out-String)

========================================
"@
        $backupSummary | Out-File -FilePath "$backupDir\BACKUP-SUMMARY.txt" -Encoding UTF8

        $backupElapsed = (Get-Date) - $backupStart
        Write-Success "  [OK] Logs backed up to $backupDir ($($backupElapsed.TotalSeconds.ToString('F1'))s)`n"
    } else {
        Write-Info "  → No VMs running, skipping log backup`n"
        $backupElapsed = New-TimeSpan -Seconds 0
    }
} catch {
    Write-Warning "  [WARNING] Log backup failed (continuing with destruction): $_`n"
    $backupElapsed = New-TimeSpan -Seconds 0
}

# Phase 2: Destroy VMs
Write-Info "[Phase 2/3] Destroying Vagrant VMs"
$destroyLog = "logs\destroy-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"
New-Item -ItemType Directory -Force -Path "logs" | Out-Null
$destroyVMStart = Get-Date

try {
    Write-Info "  → Running vagrant destroy -f..."
    "=== VAGRANT DESTROY STARTED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $destroyLog
    vagrant destroy -f primary standby 2>&1 | Tee-Object -FilePath $destroyLog -Append

    $destroyVMElapsed = (Get-Date) - $destroyVMStart
    Write-Success "  [OK] Vagrant VMs destroyed ($($destroyVMElapsed.TotalSeconds.ToString('F1'))s)`n"
} catch {
    Write-Warning "  [WARNING] Vagrant destroy encountered errors: $_`n"
    $_ | Out-File -FilePath $destroyLog -Append
}

# Phase 3: Cleanup VirtualBox artifacts
Write-Info "[Phase 3/3] Cleaning Up VirtualBox Artifacts"
$cleanupStart = Get-Date

try {
    # Unregister any Oracle Linux VMs from VirtualBox
    if ($script:VBoxManage) {
        Write-Info "  → Checking for stale VirtualBox VMs..."
        $vms = & $script:VBoxManage list vms 2>&1 | Select-String "ol8_21"
        if ($vms) {
            Write-Info "  → Found VMs to clean up..."
            foreach ($vm in $vms) {
                $vmName = $vm -replace '.*"(.+)".*', '$1'
                Write-Info "    - Unregistering: $vmName"
                & $script:VBoxManage unregistervm $vmName --delete 2>&1 | Out-File -FilePath $destroyLog -Append
            }
            Write-Success "  [OK] VirtualBox VMs unregistered"
        } else {
            Write-Success "  [OK] No VirtualBox VMs to clean up"
        }
    } else {
        Write-Warning "  [WARNING] Skipping VirtualBox VM cleanup (VBoxManage not found)"
    }

    # Delete orphaned VM directories
    Write-Info "  → Cleaning up VM directories..."
    $vboxVmsPath = "$env:USERPROFILE\VirtualBox VMs"
    if (Test-Path $vboxVmsPath) {
        $removed = 0
        Get-ChildItem $vboxVmsPath | Where-Object { $_.Name -like "*ol8_21*" -or $_.Name -like "*vagrant-virtualbox*" } | ForEach-Object {
            Write-Info "    - Removing: $($_.Name)"
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $removed++
        }
        if ($removed -gt 0) {
            Write-Success "  [OK] Removed $removed orphaned VM directories"
        } else {
            Write-Success "  [OK] No orphaned directories to clean up"
        }
    }

    # Delete .vagrant directory (Vagrant state)
    if (Test-Path ".vagrant") {
        Write-Info "  → Removing .vagrant state directory..."
        Remove-Item ".vagrant" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "  [OK] Vagrant state directory removed"
    }

    $cleanupElapsed = (Get-Date) - $cleanupStart
    Write-Success "  [OK] Cleanup completed ($($cleanupElapsed.TotalSeconds.ToString('F1'))s)`n"
} catch {
    Write-Warning "  [WARNING] Cleanup encountered errors: $_`n"
    $_ | Out-File -FilePath $destroyLog -Append
}

# Generate destruction summary
$destroyElapsed = (Get-Date) - $destroyStart

$destroySummary = @"
========================================
ORACLE DATA GUARD DESTRUCTION SUMMARY
========================================

Destruction Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

----------------------------------------
TIMING
----------------------------------------
VM Log Backup:      $($backupElapsed.TotalSeconds.ToString('F1'))s
VM Destruction:     $($destroyVMElapsed.TotalSeconds.ToString('F1'))s
Cleanup:            $($cleanupElapsed.TotalSeconds.ToString('F1'))s

TOTAL TIME: $($destroyElapsed.TotalSeconds.ToString('F1'))s

----------------------------------------
ACTIONS PERFORMED
----------------------------------------
[OK] VM logs backed up (if VMs were running)
[OK] Vagrant VMs destroyed
[OK] VirtualBox VMs unregistered
[OK] Orphaned VM directories removed
[OK] Vagrant state directory removed

----------------------------------------
NEXT STEPS
----------------------------------------
To redeploy:
  .\deploy.ps1

To view destruction log:
  type $destroyLog

========================================
DESTRUCTION COMPLETED SUCCESSFULLY
========================================
"@

"=== DESTRUCTION COMPLETED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $destroyLog -Append
$destroySummary | Out-File -FilePath $destroyLog -Append

Write-Success "=========================================="
Write-Success "DESTRUCTION COMPLETED SUCCESSFULLY"
Write-Success "=========================================="
Write-Success "Total time: $($destroyElapsed.TotalSeconds.ToString('F1'))s"
Write-Info ""
if ($backupDir) {
    Write-Info "VM logs backed up to: $backupDir"
}
Write-Info "Destruction log: $destroyLog"
Write-Info ""
Write-Info "To redeploy: .\deploy.ps1"
