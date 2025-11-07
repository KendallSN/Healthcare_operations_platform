# 10 - Script de Despliegue PowerShell

## Orquestador Principal del Despliegue Automatizado

El script `deploy.ps1` es el **punto de entrada principal** para desplegar todo el sistema Oracle Data Guard. Orquesta automáticamente las 6 fases del despliegue: verificación de prerequisitos, corrección de line endings, limpieza de VMs antiguas, despliegue del primary, despliegue del standby, verificación post-despliegue y recolección de logs.

---

## 📋 Tabla de Contenidos

1. [Ubicación](#ubicación)
2. [Propósito](#propósito)
3. [Cuándo se Ejecuta](#cuándo-se-ejecuta)
4. [Permisos de Ejecución](#permisos-de-ejecución)
5. [Variables y Configuración Utilizadas](#variables-y-configuración-utilizadas)
6. [Flujo de Ejecución Paso a Paso](#flujo-de-ejecución-paso-a-paso)
7. [Archivos Creados/Modificados](#archivos-creadosmodificados)
8. [Dependencias](#dependencias)
9. [Logs Generados](#logs-generados)
10. [Puntos de Fallo Comunes](#puntos-de-fallo-comunes)
11. [Relación con Data Guard](#relación-con-data-guard)
12. [Referencias Cruzadas](#referencias-cruzadas)
13. [Siguiente Paso](#siguiente-paso)

---

## Ubicación

```
powershell/deploy.ps1
```

**Ruta completa:** `C:\Users\StarAlchemist\DataGripProjects\AdminBDProyecto\powershell\deploy.ps1`

---

## Propósito

El script `deploy.ps1` automatiza completamente el despliegue del sistema Oracle Data Guard con las siguientes responsabilidades:

1. **Validar prerequisitos** antes de iniciar el despliegue
2. **Corregir line endings** de scripts shell para compatibilidad Linux
3. **Limpiar artefactos** de despliegues anteriores
4. **Orquestar Vagrant** para crear y provisionar ambas VMs
5. **Verificar configuración** post-despliegue (SSH, cron jobs)
6. **Recolectar logs** de Oracle y Data Guard para diagnóstico
7. **Generar resumen** ejecutivo con tiempos, configuración y siguientes pasos

Este script permite desplegar todo el sistema con **un solo comando**, eliminando la necesidad de ejecutar múltiples comandos manuales.

---

## Cuándo se Ejecuta

### Contexto en la Secuencia de Despliegue

**Fase:** Fase inicial (Fase 0 de preparación)
**Llamado por:** Usuario final desde PowerShell
**Orden en secuencia:** 1 de 1 (es el único comando necesario)

### Comando de Ejecución

Desde la raíz del proyecto en PowerShell:

```powershell
.\powershell\deploy.ps1
```

### Cuándo Usar Este Script

**Usar `deploy.ps1` cuando:**
- Es tu primera instalación del sistema
- Quieres desplegar primary y standby automáticamente
- Necesitas un despliegue limpio desde cero
- Acabas de clonar el repositorio y quieres deployar

**NO usar `deploy.ps1` si:**
- Solo quieres desplegar el primary: usa `vagrant up primary`
- Solo quieres desplegar el standby: usa `vagrant up standby`
- Las VMs ya están corriendo y solo quieres hacer cambios menores
- Quieres tener control granular de cada paso del despliegue

---

## Permisos de Ejecución

### Usuario Requerido

**Usuario:** Usuario regular de Windows (NO requiere Administrator)

### Nivel de Privilegios

- **PowerShell Execution Policy:** Debe permitir ejecución de scripts
  ```powershell
  # Verificar policy actual
  Get-ExecutionPolicy

  # Si es Restricted, cambiar temporalmente
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

- **VirtualBox:** Debe estar instalado y accesible
- **Vagrant:** Debe estar en PATH

### Por Qué Estos Permisos

**Usuario regular es suficiente porque:**
- VirtualBox y Vagrant se instalan en user space
- El script solo lee/escribe en el directorio del proyecto
- Las operaciones de administración (dentro de las VMs) se delegan a Vagrant
- Los provisioners shell ejecutan como root dentro de las VMs

**Execution Policy necesaria porque:**
- PowerShell por defecto bloquea ejecución de scripts no firmados
- `Bypass` permite ejecución temporal sin cambiar configuración global

---

## Variables y Configuración Utilizadas

### Variables Internas del Script

```powershell
# Error handling
$ErrorActionPreference = "Stop"           # Detener en cualquier error
$ProgressPreference = "SilentlyContinue"  # Suprimir barra de progreso

# Paths
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"  # Ej: 2025-11-04-143522
$scriptDir = $PSScriptRoot                         # powershell/
$projectRoot = Split-Path -Parent $scriptDir       # raíz del proyecto
$logDir = "$scriptDir\logs\deploy-$timestamp"      # logs/deploy-TIMESTAMP/

# Herramientas
$script:VBoxManage = Get-VBoxManagePath()  # Ruta a VBoxManage.exe

# Timing
$deploymentStart = Get-Date                # Inicio del despliegue
$prereqStart = Get-Date                    # Inicio de cada fase
# ... (variables de timing para cada fase)
```

### Variables de Configuración Externa

El script **lee** pero **no modifica** estos archivos de configuración:

**1. `config/vagrant.yml`** (cargado por Vagrant, no por este script directamente):
- `node1.mem_size`: RAM de primary (4096 MB)
- `node1.cpus`: CPUs de primary (2)
- `node2.mem_size`: RAM de standby (4096 MB)
- `node2.cpus`: CPUs de standby (2)

**2. `config/install.env`** (usado por scripts shell, no por PowerShell):
- Passwords de Oracle
- IPs de nodos
- Configuración de Data Guard

**3. Software requerido:**
- `software/LINUX.X64_213000_db_home.zip`: Oracle Database 21c

### Paths Importantes

```powershell
# Oracle software (verificado en Fase 1)
$oracleSoftware = "..\software\LINUX.X64_213000_db_home.zip"

# Script de corrección de line endings (ejecutado en Fase 2)
$lineEndingScript = ".\powershell\fix-line-endings.ps1"

# VMs en VirtualBox (limpiados en Fase 3)
$vboxVmsPath = "$env:USERPROFILE\VirtualBox VMs"

# Directorio de logs (creado en Fase 1)
$logDir = "powershell\logs\deploy-TIMESTAMP\"
```

---

## Flujo de Ejecución Paso a Paso

### Fase 0: Inicialización

```powershell
# Enable strict mode
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Crear directorio de logs con timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$logDir = Join-Path $scriptDir "logs\deploy-$timestamp"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Info "=========================================="
Write-Info "Oracle Data Guard Automated Deployment"
Write-Info "=========================================="
Write-Info "Log directory: $logDir"
```

**Explicación:**
- Configura modo estricto para detener el script ante cualquier error
- Crea un directorio de logs único usando timestamp (evita sobrescribir logs anteriores)
- Muestra mensaje de inicio con ubicación de logs

**Salida en consola:**
```
==========================================
Oracle Data Guard Automated Deployment
==========================================
Log directory: powershell/logs/deploy-2025-11-04-143522
```

---

### Fase 1: Verificación de Prerequisitos (10-15 segundos)

```powershell
Write-Info "[Phase 1/6] Prerequisites Check"
$prereqLog = "$logDir\00-prerequisites.log"
$prereqStart = Get-Date

# Check Oracle software exists
$oracleSoftware = "..\software\LINUX.X64_213000_db_home.zip"
if (!(Test-Path $oracleSoftware)) {
    Write-Error "FATAL: Oracle software not found at $oracleSoftware"
    exit 1
}
$oracleSize = (Get-Item $oracleSoftware).Length / 1GB
Write-Success "  [OK] Oracle software found ($([math]::Round($oracleSize, 2)) GB)"
```

**Explicación:**
Verifica que el archivo ZIP de Oracle Database 21c existe en `software/`. Este archivo es **crítico** porque los provisioners de Vagrant lo copiarán a las VMs para instalar Oracle. Sin este archivo, el despliegue fallará en Fase 4.

**Salida esperada:**
```
[Phase 1/6] Prerequisites Check
  → Checking Oracle software...
  [OK] Oracle software found (2.87 GB)
```

**Si falla:**
```
  [ERROR] FATAL: Oracle software not found at ..\software\LINUX.X64_213000_db_home.zip
  [ERROR] Please download Oracle Database 21c Enterprise Edition from oracle.com
```

---

```powershell
# Check VirtualBox service
$vboxService = Get-Service -Name "VBoxSDS" -ErrorAction SilentlyContinue
if (!$vboxService) {
    Write-Warning "  [WARNING] VirtualBox service not found (may be OK if running as application)"
} else {
    if ($vboxService.Status -ne "Running") {
        Write-Warning "  [WARNING] VirtualBox service is not running, attempting to start..."
        Start-Service -Name "VBoxSDS"
    }
    Write-Success "  [OK] VirtualBox service is running"
}
```

**Explicación:**
Verifica que el servicio de VirtualBox está corriendo. `VBoxSDS` (VirtualBox System Service) es necesario para que VirtualBox funcione correctamente. Si no está corriendo, intenta iniciarlo.

**Nota:** En algunas instalaciones de VirtualBox, este servicio puede no existir si VirtualBox se ejecuta como aplicación. El script muestra warning pero continúa.

---

```powershell
# Check VBoxManage is accessible
$script:VBoxManage = Get-VBoxManagePath
if (!$script:VBoxManage) {
    Write-Error "FATAL: VBoxManage.exe not found."
    exit 1
}
$vboxVersion = & $script:VBoxManage --version 2>&1
Write-Success "  [OK] VBoxManage found: $vboxVersion"
```

**Explicación:**
Busca el ejecutable `VBoxManage.exe` que es la herramienta de línea de comandos de VirtualBox. El script busca en:
1. PATH del sistema
2. `C:\Program Files\Oracle\VirtualBox\`
3. `C:\Program Files (x86)\Oracle\VirtualBox\`
4. Otros directorios comunes

Una vez encontrado, ejecuta `VBoxManage --version` para confirmar que funciona.

**Salida esperada:**
```
  → Verifying VBoxManage executable...
  [OK] VBoxManage found: 7.0.12r159484
```

---

```powershell
# Check Vagrant is installed
try {
    $vagrantVersion = vagrant --version 2>&1
    Write-Success "  [OK] Vagrant found: $vagrantVersion"
    "Vagrant version: $vagrantVersion" | Out-File -FilePath $prereqLog -Append
} catch {
    Write-Error "FATAL: vagrant command not found. Please install Vagrant."
    exit 1
}
```

**Explicación:**
Verifica que el comando `vagrant` está disponible en PATH ejecutando `vagrant --version`. Vagrant es **esencial** para orquestar las VMs.

**Salida esperada:**
```
  → Checking Vagrant installation...
  [OK] Vagrant found: Vagrant 2.4.1
```

---

```powershell
$prereqElapsed = (Get-Date) - $prereqStart
Write-Success "  [OK] Prerequisites check completed ($($prereqElapsed.TotalSeconds.ToString('F1'))s)`n"
```

**Explicación:**
Calcula el tiempo transcurrido en la fase de prerequisitos y lo muestra. Típicamente toma 10-15 segundos.

**Cambiar al directorio raíz:**

```powershell
$projectRoot = Split-Path -Parent $scriptDir
Set-Location $projectRoot
Write-Success "  [OK] Working directory: $(Get-Location)`n"
```

**Explicación:**
Cambia el working directory de `powershell/` a la raíz del proyecto. Esto es necesario porque:
- `Vagrantfile` está en la raíz
- Los comandos `vagrant` deben ejecutarse desde donde está `Vagrantfile`

---

### Fase 2: Corrección de Line Endings (1-2 segundos)

```powershell
Write-Info "[Phase 2/6] Fixing Line Endings"
$lineEndingLog = "$logDir\01-line-endings.log"
$lineEndingStart = Get-Date

Write-Info "  → Running fix-line-endings.ps1..."
& powershell -ExecutionPolicy Bypass -File .\powershell\fix-line-endings.ps1 | Tee-Object -FilePath $lineEndingLog
```

**Explicación:**
Ejecuta el script `fix-line-endings.ps1` que convierte todos los archivos `.sh` y `.env` de CRLF (Windows) a LF (Linux/Unix).

**Por qué es crítico:**
- Windows usa `\r\n` (CR+LF) para nuevas líneas
- Linux usa solo `\n` (LF)
- Si los scripts shell tienen CRLF, Bash los interpreta como `$'\r': command not found`
- Esto causa que **todos los provisioners fallen**

**Comando usado:**
- `-ExecutionPolicy Bypass`: Permite ejecutar el script sin restricciones
- `Tee-Object`: Muestra salida en consola Y guarda en log

**Salida esperada:**
```
[Phase 2/6] Fixing Line Endings
  → Running fix-line-endings.ps1...
Converting shell scripts and config files to Unix (LF) line endings...
Processing: C:\...\2-Standby\scripts\primary\setup.sh
Processing: C:\...\2-Standby\scripts\primary\root_setup.sh
... (47 archivos más)

Conversion complete! Total files processed: 47
  - Shell scripts (.sh): 43
  - Config files (.env): 4

You can now run deployment again.
  [OK] Line endings fixed (1.2s)
```

**Ver:** [11 - fix-line-endings.md](11-fix-line-endings.md) para detalles del script.

---

### Fase 3: Limpieza de VMs Antiguas (10-30 segundos)

```powershell
Write-Info "[Phase 3/6] Cleaning Up Stale VMs"
$cleanupLog = "$logDir\02-cleanup.log"
$cleanupStart = Get-Date

# Destroy any existing Vagrant VMs
Write-Info "  → Running vagrant destroy -f..."
vagrant destroy -f primary standby 2>&1 | Tee-Object -FilePath $cleanupLog -Append
```

**Explicación:**
Destruye cualquier VM de Vagrant que pueda existir de despliegues anteriores. El flag `-f` (force) no pide confirmación.

**Salida si NO hay VMs previas:**
```
==> primary: VM not created. Moving on...
==> standby: VM not created. Moving on...
```

**Salida si SÍ hay VMs previas:**
```
==> primary: Forcing shutdown of VM...
==> primary: Destroying VM and associated drives...
==> standby: Forcing shutdown of VM...
==> standby: Destroying VM and associated drives...
```

---

```powershell
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
}
```

**Explicación:**
Limpia VMs huérfanas en VirtualBox que Vagrant no pudo eliminar (puede ocurrir si se usó `VBoxManage` directamente o hubo errores).

**Comando usado:**
- `VBoxManage list vms`: Lista todas las VMs registradas
- `Select-String "ol8_21"`: Filtra solo nuestras VMs (nombres contienen `ol8_21`)
- `unregistervm --delete`: Elimina la VM de VirtualBox Y borra sus archivos

**Salida esperada:**
```
  → Checking for stale VirtualBox VMs...
  [OK] No stale VMs found
```

---

```powershell
# Delete orphaned VM directories
Write-Info "  → Cleaning up VM directories..."
$vboxVmsPath = "$env:USERPROFILE\VirtualBox VMs"
if (Test-Path $vboxVmsPath) {
    Get-ChildItem $vboxVmsPath | Where-Object {
        $_.Name -like "*ol8_21*" -or $_.Name -like "*vagrant-virtualbox*"
    } | ForEach-Object {
        Write-Info "    - Removing: $($_.Name)"
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}
```

**Explicación:**
Elimina directorios huérfanos de VMs en `C:\Users\Usuario\VirtualBox VMs\` que puedan quedar de despliegues anteriores incompletos.

**Directorio típico:**
```
C:\Users\StarAlchemist\VirtualBox VMs\
├── ol8_21_dg1_primary\      <-- Eliminado
└── ol8_21_dg2_standby\      <-- Eliminado
```

---

### Fase 4: Despliegue del Primary (30-45 minutos) ⏰

```powershell
Write-Info "[Phase 4/6] Deploying Primary Database"
$primaryLog = "$logDir\03-primary-vagrant.log"
$primaryStart = Get-Date

Write-Info "  → Running vagrant up primary (this may take 30-45 minutes)..."
"=== PRIMARY DEPLOYMENT STARTED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $primaryLog
vagrant up primary 2>&1 | Tee-Object -FilePath $primaryLog -Append
```

**Explicación:**
Este es el corazón del despliegue. Ejecuta `vagrant up primary` que:

1. **Crea la VM primary** en VirtualBox
2. **Ejecuta todos los provisioners** definidos en `Vagrantfile` para primary
3. **Instala Oracle Database 21c**
4. **Crea la base de datos CDB + PDB**
5. **Despliega el schema HEALTHCENTER**
6. **Configura Data Guard en modo primary**
7. **Instala scripts de automatización**
8. **Configura cron jobs**

**Comando usado:**
- `vagrant up primary`: Inicia y provisiona solo la VM primary
- `2>&1`: Redirige stderr a stdout (captura todos los mensajes)
- `Tee-Object`: Muestra en consola Y guarda en log

**Salida (primeros minutos):**
```
Bringing machine 'primary' up with 'virtualbox' provider...
==> primary: Importing base box 'oraclelinux/8'...
==> primary: Matching MAC address for NAT networking...
==> primary: Setting the name of the VM: ol8_21_dg1_primary
==> primary: Clearing any previously set network interfaces...
==> primary: Preparing network interfaces based on configuration...
==> primary: Forwarding ports...
    primary: 1521 (guest) => 1521 (host) (adapter 1)
    primary: 5500 (guest) => 5500 (host) (adapter 1)
==> primary: Running 'pre-boot' VM customizations...
==> primary: Booting VM...
==> primary: Waiting for machine to boot...
==> primary: Machine booted and ready!
==> primary: Checking for guest additions in VM...
==> primary: Setting hostname...
==> primary: Configuring and enabling network interfaces...
==> primary: Mounting shared folders...
    primary: /vagrant => C:/Users/StarAlchemist/DataGripProjects/AdminBDProyecto
    primary: /vagrant_config => .../config
    primary: /vagrant_scripts => .../2-Standby/infrastructure
    primary: /vagrant_software => .../software
    primary: /vagrant_automation => .../2-Standby/automation
==> primary: Running provisioner: shell...
    primary: Running: C:/.../2-Standby/scripts/primary/setup.sh
```

**Progreso del provisioning (minutos 5-40):**
```
primary: ===================================================
primary: PRIMARY NODE SETUP - Starting...
primary: ===================================================
primary:
primary: [Step 1/12] Preparing disks u01 and u02...
primary: Creating partition on /dev/sdb...
primary: ✓ Disks prepared successfully
primary:
primary: [Step 2/12] Installing OS packages...
primary: Installing oracle-database-preinstall-21c...
primary: [This takes 5-10 minutes]
primary: ✓ Packages installed
primary:
primary: [Step 3/12] Configuring network...
primary: ✓ Network configured
primary:
primary: [Step 4/12] Setting up Oracle user environment...
primary: ✓ Oracle environment configured
primary:
primary: [Step 5/12] Installing Oracle Database 21c...
primary: Copying Oracle software to /u01/software/...
primary: Unzipping Oracle software (3-5 minutes)...
primary: Running Oracle installer (10-15 minutes)...
primary: ✓ Oracle software installed
primary:
primary: [Step 6/12] Creating primary database...
primary: Running dbca (database creation assistant)...
primary: [This takes 15-20 minutes]
primary: Database creation progress: 25%...
primary: Database creation progress: 50%...
primary: Database creation progress: 75%...
primary: Database creation progress: 100%
primary: ✓ Database cdb1 created successfully
primary:
primary: [Step 7/12] Deploying custom schema...
primary: Executing ScriptProyectoBD.SQL...
primary: Creating tables, sequences, triggers, packages...
primary: ✓ Schema HEALTHCENTER deployed
primary:
primary: [Step 8/12] Setting up automation scripts...
primary: ✓ Automation configured
primary:
primary: [Step 9/12] Setting up SSH keys...
primary: ✓ SSH keys configured
primary:
primary: [Step 10/12] Installing cron jobs...
primary: ✓ Cron jobs installed
primary:
primary: ===================================================
primary: PRIMARY NODE SETUP - COMPLETE
primary: Time elapsed: 43 minutes
primary: ===================================================
```

**Verificación de éxito:**

```powershell
if ($LASTEXITCODE -ne 0) {
    Write-Error "Primary deployment failed with exit code $LASTEXITCODE"
    "FATAL: Deployment failed with exit code $LASTEXITCODE" | Out-File -FilePath $primaryLog -Append
    exit 1
}

$primaryElapsed = (Get-Date) - $primaryStart
Write-Success "  [OK] Primary deployed successfully ($($primaryElapsed.TotalMinutes.ToString('F1')) minutes)`n"
```

**Explicación:**
Verifica el código de salida de Vagrant (`$LASTEXITCODE`). Si es distinto de 0, significa que hubo un error y el script se detiene.

**Si tiene éxito:**
```
  [OK] Primary deployed successfully (43.2 minutes)
```

**Si falla:**
```
  [ERROR] Primary deployment failed with exit code 1
```

**Ver:** [30-primary-setup.md](primary/30-primary-setup.md) y subsiguientes para detalles de los provisioners.

---

### Fase 5: Despliegue del Standby (20-30 minutos) ⏰

```powershell
Write-Info "[Phase 5/6] Deploying Standby Database"
$standbyLog = "$logDir\04-standby-vagrant.log"
$standbyStart = Get-Date

Write-Info "  → Running vagrant up standby (this may take 20-30 minutes)..."
"=== STANDBY DEPLOYMENT STARTED: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File -FilePath $standbyLog
vagrant up standby 2>&1 | Tee-Object -FilePath $standbyLog -Append
```

**Explicación:**
Similar a Fase 4, pero para el standby. Ejecuta `vagrant up standby` que:

1. **Crea la VM standby** en VirtualBox
2. **Instala Oracle Database 21c** (idéntico al primary)
3. **Crea standby database usando RMAN DUPLICATE**
4. **Configura Data Guard Broker**
5. **Habilita replicación sincrónica**
6. **Instala scripts de automatización**

**El paso más importante:** RMAN DUPLICATE copia toda la base de datos primary al standby a través de la red.

**Salida (minutos 10-25):**
```
standby: [Step 6/10] Creating standby database...
standby: Starting auxiliary instance in NOMOUNT mode...
standby: Testing connectivity to primary...
standby: ✓ Primary is reachable at cdb1.world
standby:
standby: Running RMAN DUPLICATE FOR STANDBY...
standby: ╔═══════════════════════════════════════════════════╗
standby: ║   RMAN DUPLICATE - Copying entire database       ║
standby: ║   This takes 10-20 minutes                        ║
standby: ╚═══════════════════════════════════════════════════╝
standby:
standby: RMAN> duplicate target database
standby:         for standby
standby:         from active database
standby:         dorecover;
standby:
standby: Starting Duplicate Db at 04-NOV-25
standby: [Copying datafiles - progress updates every few minutes]
standby: channel ORA_AUX_DISK_1: datafile copy complete, elapsed time: 00:02:15
standby: ...
standby: Finished Duplicate Db at 04-NOV-25
standby: ✓ RMAN DUPLICATE complete
standby:
standby: Configuring Data Guard Broker...
standby: DGMGRL> create configuration dg_config as
standby:           primary database is cdb1 connect identifier is cdb1.world;
standby: Configuration "dg_config" created with primary database "cdb1"
standby: DGMGRL> add database cdb1_stby as
standby:           connect identifier is cdb1_stby.world
standby:           maintained as physical;
standby: Database "cdb1_stby" added
standby: DGMGRL> enable configuration;
standby: Enabled.
standby:
standby: Setting protection mode to MAXAVAILABILITY...
standby: ✓ Protection mode: MAXIMUM AVAILABILITY
standby: ✓ LogXptMode: FASTSYNC
```

**Verificación:**

```powershell
if ($LASTEXITCODE -ne 0) {
    Write-Error "Standby deployment failed with exit code $LASTEXITCODE"
    exit 1
}

$standbyElapsed = (Get-Date) - $standbyStart
Write-Success "  [OK] Standby deployed successfully ($($standbyElapsed.TotalMinutes.ToString('F1')) minutes)`n"
```

**Si tiene éxito:**
```
  [OK] Standby deployed successfully (28.5 minutes)
```

**Ver:** [50-standby-setup.md](standby/50-standby-setup.md) y subsiguientes para detalles.

---

### Fase 5.5: Verificación Post-Despliegue (30-60 segundos)

```powershell
Write-Info "[Phase 5.5/7] Post-Deployment Verification"
$verificationLog = "$logDir\04a-verification.log"
$verificationStart = Get-Date

# Step 1: Import standby's host keys to primary's known_hosts
Write-Info "  → Importing standby host keys to primary..."
vagrant ssh primary -c "sudo su - oracle -c 'if [ -f /vagrant/ssh_keys/standby_host_keys.txt ]; then cat /vagrant/ssh_keys/standby_host_keys.txt >> ~/.ssh/known_hosts; echo Host keys imported; fi'" 2>&1 | Tee-Object -FilePath $verificationLog -Append
```

**Explicación:**
Durante el provisioning, el standby exportó sus host keys SSH a `/vagrant/ssh_keys/standby_host_keys.txt`. Este paso los importa al `known_hosts` del primary para permitir SSH sin contraseña.

**Por qué es necesario:**
- El script de backup diario (`rman_daily_backup.sh`) transfiere backups vía `rsync` sobre SSH
- Sin host keys importadas, rsync pediría confirmación manual la primera vez
- Esto rompería la automatización del cron job

**Salida esperada:**
```
  → Importing standby host keys to primary...
Host keys imported
```

---

```powershell
# Step 2: Test SSH connectivity from primary to standby
Write-Info "  → Testing SSH connectivity (primary → standby)..."
$sshTestResult = vagrant ssh primary -c "sudo su - oracle -c 'ssh -o BatchMode=yes -o ConnectTimeout=10 oracle@ol8-21-dg2.localdomain hostname'" 2>&1
$sshTestResult | Out-File -FilePath $verificationLog -Append

if ($sshTestResult -match "ol8-21-dg2") {
    Write-Success "  [OK] SSH connectivity verified"
} else {
    Write-Warning "  [WARNING] SSH test did not return expected hostname"
}
```

**Explicación:**
Prueba que el primary puede hacer SSH al standby sin contraseña. Ejecuta el comando `hostname` en el standby vía SSH y verifica que retorna `ol8-21-dg2.localdomain`.

**Comando usado:**
- `ssh -o BatchMode=yes`: No pedir contraseña (falla si requiere autenticación)
- `-o ConnectTimeout=10`: Timeout de 10 segundos
- `oracle@ol8-21-dg2.localdomain`: Usuario y hostname del standby

**Salida esperada:**
```
  → Testing SSH connectivity (primary → standby)...
ol8-21-dg2.localdomain
  [OK] SSH connectivity verified
```

**Si falla:**
```
  [WARNING] SSH test did not return expected hostname
  [WARNING] SSH may require manual setup. See: logs/.../04a-verification.log
```

---

```powershell
# Step 3: Verify cron jobs installed
Write-Info "  → Verifying cron job installation..."

Write-Info "    - Primary cron jobs:"
$primaryCron = vagrant ssh primary -c "sudo su - oracle -c 'crontab -l 2>/dev/null | grep -v \"^#\" | grep -v \"^$\" | wc -l'" 2>&1
vagrant ssh primary -c "sudo su - oracle -c 'crontab -l 2>/dev/null || echo No cron jobs found'" 2>&1 | Tee-Object -FilePath $verificationLog -Append

if ($primaryCron -ge 3) {
    Write-Success "    [OK] Primary has $primaryCron cron jobs (expected: 3)"
} else {
    Write-Warning "    [WARNING] Primary has $primaryCron cron jobs (expected: 3)"
}
```

**Explicación:**
Verifica que los cron jobs se instalaron correctamente en el primary. Se esperan **3 cron jobs**:
1. `check_log_transport.sh` (cada 10 minutos)
2. `rman_daily_backup.sh` (diario 1 AM)
3. `delete_archives_primary.sh` (diario 2 AM)

**Comando usado:**
- `crontab -l`: Lista cron jobs del usuario oracle
- `grep -v "^#"`: Excluir comentarios
- `grep -v "^$"`: Excluir líneas vacías
- `wc -l`: Contar líneas

**Salida esperada:**
```
    - Primary cron jobs:
*/10 * * * * /home/oracle/automation/check_log_transport.sh
0 1 * * * /home/oracle/automation/rman_daily_backup.sh
0 2 * * * /home/oracle/automation/delete_archives_primary.sh
    [OK] Primary has 3 cron jobs (expected: 3)
```

---

```powershell
Write-Info "    - Standby cron jobs:"
$standbyCron = vagrant ssh standby -c "sudo su - oracle -c 'crontab -l 2>/dev/null | grep -v \"^#\" | grep -v \"^$\" | wc -l'" 2>&1
vagrant ssh standby -c "sudo su - oracle -c 'crontab -l 2>/dev/null || echo No cron jobs found'" 2>&1 | Tee-Object -FilePath $verificationLog -Append

if ($standbyCron -ge 1) {
    Write-Success "    [OK] Standby has $standbyCron cron job(s) (expected: 1)"
} else {
    Write-Warning "    [WARNING] Standby has $standbyCron cron jobs (expected: 1)"
}
```

**Explicación:**
Verifica que el standby tiene **1 cron job**:
1. `delete_archives_standby.sh` (diario 11 PM)

**Salida esperada:**
```
    - Standby cron jobs:
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
    [OK] Standby has 1 cron job(s) (expected: 1)
```

---

### Fase 6: Recolección de Logs (10-20 segundos)

```powershell
Write-Info "[Phase 6/7] Collecting VM Logs"
$vmLogsStart = Get-Date

# Primary alert log
Write-Info "  → Fetching primary alert log..."
$primaryAlertLog = "$logDir\05-primary-alert.log"
vagrant ssh primary -c "sudo tail -1000 /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log" 2>&1 | Out-File -FilePath $primaryAlertLog -Encoding UTF8
```

**Explicación:**
Copia las últimas 1000 líneas del alert log de Oracle desde el primary. El alert log contiene:
- Mensajes de inicio/apagado de la base de datos
- Log switches
- Errores ORA-XXXXX
- Mensajes de Data Guard (LNS, ARCn)

**Ubicación del alert log:**
```
/u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log
```

**Contenido típico del alert log:**
```
2025-11-04T15:30:00.123456+00:00
Thread 1 advanced to log sequence 145 (LGWR switch)
  Current log# 2 seq# 145 mem# 0: /u01/oradata/cdb1/redo02.log
2025-11-04T15:30:01.456789+00:00
LNS: Standby redo logfile selected for thread 1 sequence 145 for destination LOG_ARCHIVE_DEST_2
2025-11-04T15:30:05.789012+00:00
Archived Log entry 145 added for T-1.S-145
```

---

```powershell
# Standby alert log
Write-Info "  → Fetching standby alert log..."
$standbyAlertLog = "$logDir\06-standby-alert.log"
vagrant ssh standby -c "sudo tail -1000 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log" 2>&1 | Out-File -FilePath $standbyAlertLog -Encoding UTF8
```

**Explicación:**
Copia las últimas 1000 líneas del alert log del standby.

**Ubicación:**
```
/u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log
```

**Contenido típico:**
```
2025-11-04T15:30:02.123456+00:00
RFS[4]: Assigned to RFS process (PID:5678)
RFS[4]: Selected log 4 for T-1.S-145 dbid 1234567890 branch 1
2025-11-04T15:30:03.456789+00:00
Media Recovery Log /u01/oradata/cdb1/arch/1_145_1234567890.arc
Media Recovery Waiting for T1.S146
```

---

```powershell
# Data Guard status
Write-Info "  → Fetching Data Guard configuration status..."
$dgStatusLog = "$logDir\07-dataguard-status.log"
vagrant ssh primary -c "sudo su - oracle -c '/home/oracle/automation/verify_dataguard.sh'" 2>&1 | Out-File -FilePath $dgStatusLog -Encoding UTF8
```

**Explicación:**
Ejecuta el script de verificación completa de Data Guard (`verify_dataguard.sh`) que genera un reporte detallado del estado del sistema:
- Roles de bases de datos (primary/standby)
- Protection mode
- Archive log destinations
- Apply lag
- Log shipping status
- Gaps en archive logs
- Estado del Data Guard Broker

**Salida típica:** (ver [04-como-usar.md](../04-como-usar.md#verificación-completa-de-data-guard) para ejemplo completo)

---

```powershell
$vmLogsElapsed = (Get-Date) - $vmLogsStart
Write-Success "  [OK] VM logs collected ($($vmLogsElapsed.TotalSeconds.ToString('F1'))s)`n"
```

**Salida esperada:**
```
[Phase 6/7] Collecting Logs
  → Fetching primary alert log...
  → Fetching primary listener log...
  → Fetching standby alert log...
  → Fetching standby listener log...
  → Fetching Data Guard configuration status...
  [OK] VM logs collected (12.3s)
```

---

### Fase Final: Generación de Resumen

```powershell
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
Transport Mode:  FASTSYNC
Archive Lag:     300 seconds
Flashback:       ENABLED

----------------------------------------
NEXT STEPS
----------------------------------------
1. Verify Data Guard status:
   vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"

2. Access databases from Windows:
   Primary CDB:  sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba
   Primary PDB:  sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1

----------------------------------------
LOG FILES
----------------------------------------
  - 00-prerequisites.log
  - 01-line-endings.log
  - 02-cleanup.log
  - 03-primary-vagrant.log
  - 04-standby-vagrant.log
  - 04a-verification.log
  - 05-primary-alert.log
  - 06-standby-alert.log
  - 07-dataguard-status.log
  - DEPLOYMENT-SUMMARY.txt

========================================
DEPLOYMENT COMPLETED SUCCESSFULLY
========================================
"@

$summary | Out-File -FilePath $summaryFile -Encoding UTF8
```

**Explicación:**
Genera un archivo de resumen ejecutivo con:
- Tiempos de cada fase
- Configuración del sistema desplegado
- Siguientes pasos recomendados
- Lista de logs generados

Este archivo es útil para:
- Documentar el despliegue
- Reportar tiempos a stakeholders
- Troubleshooting (revisar si alguna fase tomó demasiado tiempo)

---

```powershell
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
```

**Salida final en consola:**
```
==========================================
DEPLOYMENT COMPLETED SUCCESSFULLY
==========================================
Total time: 67.3 minutes
Logs saved to: powershell/logs/deploy-2025-11-04-143522

Review the deployment summary:
  type powershell/logs/deploy-2025-11-04-143522/DEPLOYMENT-SUMMARY.txt

To verify Data Guard:
  vagrant ssh primary
  sudo su - oracle
  /home/oracle/automation/verify_dataguard.sh
```

---

## Archivos Creados/Modificados

### Directorio de Logs

**Ubicación:** `powershell/logs/deploy-YYYY-MM-DD-HHmmss/`

**Archivos generados:**

1. **`00-prerequisites.log`** - Verificación de prerequisitos
   - Tamaño: ~1 KB
   - Contiene: Versiones de software, paths encontrados

2. **`01-line-endings.log`** - Salida de fix-line-endings.ps1
   - Tamaño: ~5 KB
   - Contiene: Lista de archivos convertidos

3. **`02-cleanup.log`** - Limpieza de VMs
   - Tamaño: ~2 KB
   - Contiene: Salida de vagrant destroy y VBoxManage

4. **`03-primary-vagrant.log`** - Despliegue completo del primary
   - Tamaño: ~500 KB - 2 MB
   - Contiene: Toda la salida de `vagrant up primary`
   - **Archivo más importante para debugging**

5. **`04-standby-vagrant.log`** - Despliegue completo del standby
   - Tamaño: ~400 KB - 1.5 MB
   - Contiene: Toda la salida de `vagrant up standby`
   - Incluye salida completa de RMAN DUPLICATE

6. **`04a-verification.log`** - Verificación post-despliegue
   - Tamaño: ~3 KB
   - Contiene: Pruebas de SSH, verificación de cron jobs

7. **`05-primary-alert.log`** - Alert log de Oracle (primary)
   - Tamaño: ~100 KB
   - Contiene: Últimas 1000 líneas del alert log

8. **`05-primary-listener.log`** - Listener log (primary)
   - Tamaño: ~50 KB
   - Contiene: Últimas 500 líneas del listener log

9. **`06-standby-alert.log`** - Alert log de Oracle (standby)
   - Tamaño: ~100 KB

10. **`06-standby-listener.log`** - Listener log (standby)
    - Tamaño: ~50 KB

11. **`07-dataguard-status.log`** - Estado completo de Data Guard
    - Tamaño: ~20 KB
    - Contiene: Reporte de verify_dataguard.sh

12. **`DEPLOYMENT-SUMMARY.txt`** - Resumen ejecutivo
    - Tamaño: ~3 KB
    - Contiene: Tiempos, configuración, siguientes pasos

**Total:** ~1.5 MB - 4 MB de logs por despliegue

---

### VMs Creadas

**Primary VM:**
- Nombre: `ol8_21_dg1_primary`
- Ubicación: `C:\Users\Usuario\VirtualBox VMs\ol8_21_dg1_primary\`
- Discos:
  - `ol8_21_dg1_primary.vdi` (20 GB) - OS
  - `ol8_21_dg1_u01.vdi` (100 GB) - Oracle software + data
  - `ol8_21_dg1_u02.vdi` (100 GB) - Backups + FRA

**Standby VM:**
- Nombre: `ol8_21_dg2_standby`
- Ubicación: `C:\Users\Usuario\VirtualBox VMs\ol8_21_dg2_standby\`
- Discos:
  - `ol8_21_dg2_standby.vdi` (20 GB) - OS
  - `ol8_21_dg2_u01.vdi` (100 GB) - Oracle software + data
  - `ol8_21_dg2_u02.vdi` (100 GB) - Backups + FRA

**Total espacio en disco:** ~440 GB

---

### Archivos Modificados

**`2-Standby/scripts/**/*.sh`** - Line endings convertidos (CRLF → LF)

**`config/install.env`** - Line endings convertidos

**`.vagrant/`** - Directorio de estado de Vagrant (creado si no existe)

**`ssh_keys/`** - Claves SSH generadas (si no existe):
- `primary_id_rsa`
- `primary_id_rsa.pub`
- `standby_id_rsa`
- `standby_id_rsa.pub`
- `primary_host_keys.txt`
- `standby_host_keys.txt`

---

## Dependencias

### Prerequisitos (deben existir ANTES de ejecutar)

1. **VirtualBox 7.0+** instalado
   - Servicio VBoxSDS corriendo (o aplicación ejecutándose)
   - `VBoxManage.exe` accesible

2. **Vagrant 2.4+** instalado
   - En PATH del sistema

3. **Oracle Database 21c**
   - Archivo `software/LINUX.X64_213000_db_home.zip` (2.9 GB)
   - Descargado de oracle.com

4. **Recursos de hardware**
   - Mínimo 12 GB RAM libre
   - Mínimo 250 GB espacio en disco
   - CPU con virtualización habilitada (VT-x/AMD-V)

5. **Archivos de configuración**
   - `Vagrantfile` en raíz
   - `config/vagrant.yml`
   - `config/install.env`
   - Scripts en `2-Standby/scripts/`

### Scripts Llamados por deploy.ps1

1. **`powershell/fix-line-endings.ps1`** (Fase 2)
   - Convierte CRLF → LF

2. **`vagrant up primary`** (Fase 4)
   - Llama a: `2-Standby/scripts/primary/setup.sh`
   - Que llama a: todos los provisioners de primary

3. **`vagrant up standby`** (Fase 5)
   - Llama a: `2-Standby/scripts/standby/setup.sh`
   - Que llama a: todos los provisioners de standby

### Recursos Creados (usados por fases posteriores)

- **Logs de Fase 1-2**: Usados para troubleshooting si falla Fase 4-5
- **Primary VM (Fase 4)**: Requerida por Fase 5 (standby se conecta a primary)
- **SSH keys (Fase 4)**: Usadas en Fase 5.5 para verificación
- **Cron jobs (Fase 4-5)**: Verificados en Fase 5.5

---

## Logs Generados

### Ubicación

```
powershell/logs/deploy-YYYY-MM-DD-HHmmss/
```

Ejemplo:
```
powershell/logs/deploy-2025-11-04-143522/
```

### Formato de Logs

**Encoding:** UTF-8 (con BOM para archivos generados por PowerShell)

**Timestamp:** Nombre del directorio incluye fecha y hora exacta de inicio

### Cómo Revisar Logs Durante el Despliegue

**Opción 1: Desde otra ventana de PowerShell**

```powershell
# Buscar el directorio de logs más reciente
$latestLog = Get-ChildItem .\powershell\logs\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Ver log de primary en tiempo real
Get-Content "$($latestLog.FullName)\03-primary-vagrant.log" -Wait

# Ver log de standby en tiempo real
Get-Content "$($latestLog.FullName)\04-standby-vagrant.log" -Wait
```

**Opción 2: Desde dentro de las VMs**

```bash
# SSH a la VM
vagrant ssh primary

# Ver alert log en tiempo real
tail -f /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log
```

### Retención de Logs

**El script NO elimina logs anteriores**. Cada despliegue crea un nuevo directorio con timestamp.

**Para limpiar logs antiguos manualmente:**

```powershell
# Ver tamaño de logs
Get-ChildItem .\powershell\logs\ -Recurse | Measure-Object -Property Length -Sum

# Eliminar logs de hace más de 30 días
Get-ChildItem .\powershell\logs\ | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Recurse -Force
```

---

## Puntos de Fallo Comunes

### 1. FATAL: Oracle software not found

**Error:**
```
[ERROR] FATAL: Oracle software not found at ..\software\LINUX.X64_213000_db_home.zip
```

**Causa:** El archivo ZIP de Oracle Database no está en `software/`

**Solución:**
1. Descargar `LINUX.X64_213000_db_home.zip` de oracle.com
2. Mover el archivo a `software/`
3. Re-ejecutar: `.\powershell\deploy.ps1`

**Prevención:** Leer [03-prerequisitos.md](../03-prerequisitos.md) antes de deployar

---

### 2. FATAL: VBoxManage.exe not found

**Error:**
```
[ERROR] FATAL: VBoxManage.exe not found. Please install VirtualBox.
```

**Causa:** VirtualBox no está instalado o no está en PATH

**Solución:**
1. Instalar VirtualBox 7.0+ desde virtualbox.org
2. Reiniciar PowerShell (para actualizar PATH)
3. Re-ejecutar: `.\powershell\deploy.ps1`

**Verificación:**
```powershell
# Debe retornar la versión de VirtualBox
VBoxManage --version
```

---

### 3. FATAL: vagrant command not found

**Error:**
```
[ERROR] FATAL: vagrant command not found. Please install Vagrant.
```

**Causa:** Vagrant no está instalado o no está en PATH

**Solución:**
1. Instalar Vagrant 2.4+ desde vagrantup.com
2. Reiniciar PowerShell
3. Re-ejecutar: `.\powershell\deploy.ps1`

---

### 4. Primary deployment failed with exit code 1

**Error:**
```
[ERROR] Primary deployment failed with exit code 1
```

**Causa:** Error durante el provisioning del primary (múltiples causas posibles)

**Diagnóstico:**

1. **Revisar el log de primary:**
   ```powershell
   type powershell\logs\deploy-TIMESTAMP\03-primary-vagrant.log
   ```

2. **Buscar errores:**
   - Líneas que contienen `ERROR`, `FATAL`, `ORA-`
   - Última línea antes de que se detuvo el provisioning

3. **Errores comunes:**
   - `$'\r': command not found` → Line endings incorrectos (Fase 2 falló)
   - `No space left on device` → Disco lleno en host Windows
   - `ORA-01034` → Oracle no pudo iniciar (memoria insuficiente)
   - `Timeout waiting for machine to boot` → Virtualización deshabilitada en BIOS

**Solución general:**
1. Resolver el problema específico identificado en logs
2. Destruir VMs parcialmente creadas:
   ```powershell
   vagrant destroy -f
   ```
3. Re-ejecutar: `.\powershell\deploy.ps1`

---

### 5. Standby deployment failed (RMAN DUPLICATE error)

**Error en log:**
```
RMAN-03002: failure of Duplicate Db command
RMAN-05501: aborting duplication of target database
ORA-17629: Cannot connect to the remote database server
```

**Causa:** Standby no puede conectarse al primary

**Diagnóstico:**

1. **Verificar que primary está corriendo:**
   ```bash
   vagrant status primary
   # Debe mostrar: running
   ```

2. **Verificar listener en primary:**
   ```bash
   vagrant ssh primary -c "sudo su - oracle -c 'lsnrctl status'"
   ```

3. **Verificar conectividad de red:**
   ```bash
   vagrant ssh standby -c "ping -c 3 192.168.56.101"
   ```

**Solución:**
1. Si primary no está corriendo:
   ```bash
   vagrant up primary
   ```

2. Si listener no está corriendo:
   ```bash
   vagrant ssh primary
   sudo su - oracle
   lsnrctl start
   ```

3. Re-intentar standby:
   ```bash
   vagrant destroy -f standby
   vagrant up standby
   ```

---

### 6. SSH connectivity test failed

**Warning:**
```
[WARNING] SSH test did not return expected hostname
[WARNING] SSH may require manual setup
```

**Causa:** Claves SSH no se configuraron correctamente

**Impacto:** Los backups automáticos pueden fallar

**Solución:**

```bash
# Re-ejecutar setup de SSH en primary
vagrant ssh primary
sudo su - oracle
/home/oracle/automation/setup_ssh_keys.sh
exit
exit

# Re-ejecutar setup de SSH en standby
vagrant ssh standby
sudo su - oracle
/home/oracle/automation/setup_ssh_keys.sh
exit
exit

# Re-probar conectividad
vagrant ssh primary -c "sudo su - oracle -c 'ssh oracle@ol8-21-dg2.localdomain hostname'"
# Debe retornar: ol8-21-dg2.localdomain
```

---

### 7. Cron jobs not installed

**Warning:**
```
[WARNING] Primary has 0 cron jobs (expected: 3)
```

**Causa:** Script de instalación de cron jobs falló

**Impacto:** No habrá backups automáticos ni monitoreo

**Solución:**

```bash
vagrant ssh primary
sudo su - oracle
/home/oracle/automation/install_cron_jobs.sh
crontab -l  # Verificar que se instalaron
```

---

### 8. Disk space issues

**Error durante despliegue:**
```
No space left on device
```

**Causa:** Disco del host Windows está lleno

**Diagnóstico:**

```powershell
# Ver espacio en disco C:
Get-PSDrive C | Select-Object Used,Free
```

**Solución:**
1. Liberar al menos 250 GB en el disco donde están las VMs
2. Destruir VMs parciales:
   ```powershell
   .\powershell\destroy.ps1
   ```
3. Re-ejecutar despliegue

---

## Relación con Data Guard

### Cómo deploy.ps1 Habilita Data Guard

El script `deploy.ps1` orquesta el despliegue de **todo el sistema Data Guard** pero no configura Data Guard directamente. En su lugar:

**1. Fase 4 (Primary):**
- Provisioners instalan Oracle Database
- Provisioners crean CDB + PDB
- Provisioners configuran primary database **listo para Data Guard**:
  - Force logging habilitado
  - Archive log mode habilitado
  - Standby redo logs creados
  - Archive log destinations configurados
  - Flashback habilitado

**2. Fase 5 (Standby):**
- Provisioners instalan Oracle Database (idéntico a primary)
- Provisioners crean standby usando **RMAN DUPLICATE FOR STANDBY**
- Provisioners configuran **Data Guard Broker**:
  - Crea configuración `dg_config`
  - Agrega primary: `cdb1`
  - Agrega standby: `cdb1_stby`
  - Habilita configuración
  - Establece protection mode: **MAXAVAILABILITY**
  - Establece transport mode: **FASTSYNC**

**3. Fase 5.5 (Verificación):**
- Verifica que Data Guard está funcionando
- Ejecuta `verify_dataguard.sh` que valida:
  - Roles (primary/standby)
  - Apply lag (debe ser 0)
  - Archive log destinations
  - No gaps en archive logs

### Flujo de Datos Data Guard Habilitado por deploy.ps1

```
┌────────────────────────────────────────────────────┐
│  deploy.ps1 (este script)                          │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │ Fase 4: vagrant up primary                   │ │
│  │  └─> Provisioners crean primary DB           │ │
│  │      ├─ Force logging ON                     │ │
│  │      ├─ Archive log mode ON                  │ │
│  │      ├─ Standby redo logs creados            │ │
│  │      └─ LOG_ARCHIVE_DEST_2 configurado       │ │
│  └──────────────────────────────────────────────┘ │
│                     │                              │
│                     ▼                              │
│  ┌──────────────────────────────────────────────┐ │
│  │ Fase 5: vagrant up standby                   │ │
│  │  └─> Provisioners crean standby DB           │ │
│  │      ├─ RMAN DUPLICATE (copia primary)       │ │
│  │      ├─ Data Guard Broker configurado        │ │
│  │      ├─ Protection: MAXAVAILABILITY          │ │
│  │      └─ Transport: FASTSYNC                  │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
└────────────────────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │  Data Guard ACTIVO     │
        │  Replicación continua  │
        │  Lag: 0 segundos       │
        │  Protection: MÁXIMA    │
        └────────────────────────┘
```

### Configuración de Data Guard Resultante

Después de ejecutar `deploy.ps1`, el sistema queda configurado con:

**Protection Mode:** MAXAVAILABILITY
- **Significado:** Cero pérdida de datos garantizada
- **Comportamiento:** Primary espera confirmación de standby antes de commitear transacciones
- **Si standby falla:** Primary continúa operando pero registra alerta

**Transport Mode:** FASTSYNC
- **Significado:** Replicación sincrónica a través de la red
- **Comportamiento:** Redo data se envía al standby inmediatamente
- **Latencia:** Milisegundos (en red local)

**Archive Lag Target:** 300 segundos (5 minutos)
- **Significado:** Forzar log switch cada 5 minutos mínimo
- **Beneficio:** Standby nunca está más de 5 minutos desactualizado

**Flashback:** Habilitado en ambas bases de datos
- **Beneficio:** Permite reinstatement rápido después de failover

---

## Referencias Cruzadas

### Documentación Relacionada

**Scripts Llamados:**
- [11 - fix-line-endings.md](11-fix-line-endings.md) - Script de corrección de line endings
- [20 - Vagrantfile.md](20-vagrantfile.md) - Configuración de VMs
- [21 - vagrant-configuracion.md](21-vagrant-configuracion.md) - Variables de configuración

**Provisioners Ejecutados:**
- [30 - primary-setup.md](primary/30-primary-setup.md) - Entry point de primary
- [31-41 - Primary provisioners](primary/) - Detalles de cada paso del primary
- [50 - standby-setup.md](standby/50-standby-setup.md) - Entry point de standby
- [51-60 - Standby provisioners](standby/) - Detalles de cada paso del standby

**Conceptos:**
- [02 - Conceptos Fundamentales](../02-conceptos-fundamentales.md) - Base teórica
- [81 - Data Guard Conceptos](../conceptos-avanzados/81-data-guard-conceptos.md) - Data Guard profundo
- [82 - Modos de Protección](../conceptos-avanzados/82-modos-proteccion.md) - MAXAVAILABILITY, FASTSYNC

**Guías de Uso:**
- [04 - Cómo Usar](../04-como-usar.md) - Guía principal de uso
- [05 - Arquitectura del Sistema](../05-arquitectura-sistema.md) - Arquitectura completa

**Troubleshooting:**
- [94 - Troubleshooting](../operaciones/94-troubleshooting.md) - Resolución de problemas completa

---

## Siguiente Paso

Después de ejecutar `deploy.ps1`, el siguiente paso es:

**Fase inmediata:** El script ya ejecutó todo automáticamente. No hay siguiente paso manual.

**Siguiente acción del usuario:**

1. **Revisar el resumen de despliegue:**
   ```powershell
   type powershell\logs\deploy-TIMESTAMP\DEPLOYMENT-SUMMARY.txt
   ```

2. **Verificar que Data Guard está funcionando:**
   ```bash
   vagrant ssh primary -c "/home/oracle/automation/verify_dataguard.sh"
   ```

3. **Conectarse a las bases de datos:**
   ```bash
   # Primary CDB
   sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

   # Schema de aplicación
   sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1
   ```

4. **Explorar el sistema healthcare:**
   ```sql
   SELECT table_name FROM user_tables ORDER BY table_name;
   SELECT * FROM HC_HealthCenter;
   EXEC generate_month_scale('11', 2025, 1);
   ```

5. **Leer documentación de arquitectura:**
   - [05 - Arquitectura del Sistema](../05-arquitectura-sistema.md)

---

**Has completado la documentación del script de despliegue principal!**

Este script es el **corazón de la automatización** del proyecto. Con un solo comando, despliega todo el sistema Oracle Data Guard en ~60-70 minutos.

**Flujo completo:**
```
deploy.ps1
  ├─> fix-line-endings.ps1
  ├─> vagrant up primary
  │     └─> 12 pasos de provisioning (30-45 min)
  └─> vagrant up standby
        └─> 10 pasos de provisioning (20-30 min)
```

Para entender los detalles de cada paso, continúa con los siguientes documentos en la serie de [Ejecución](.).
