# 03 - Prerequisitos

## Requisitos de Hardware, Software y Configuración Inicial

Antes de desplegar el sistema Oracle Data Guard, debes asegurarte de que tu sistema cumple con todos los prerequisitos necesarios.

---

## 📋 Tabla de Contenidos

1. [Requisitos de Hardware](#1-requisitos-de-hardware)
2. [Requisitos de Software](#2-requisitos-de-software)
3. [Descarga de Oracle Database 21c](#3-descarga-de-oracle-database-21c)
4. [Instalación de VirtualBox](#4-instalación-de-virtualbox)
5. [Instalación de Vagrant](#5-instalación-de-vagrant)
6. [Verificación del Proyecto](#6-verificación-del-proyecto)
7. [Configuración del Archivo install.env](#7-configuración-del-archivo-installenv)
8. [Verificación de Prerequisitos](#8-verificación-de-prerequisitos)

---

## 1. Requisitos de Hardware

### 💻 Sistema Host (Tu PC)

| Componente | Mínimo | Recomendado | Óptimo |
|------------|--------|-------------|---------|
| **CPU** | 4 cores | 6 cores | 8+ cores |
| **RAM** | 12 GB | 16 GB | 32 GB |
| **Disco Duro Libre** | 250 GB | 300 GB | 500 GB |
| **Tipo de Disco** | HDD | SSD | NVMe SSD |
| **Sistema Operativo** | Windows 10 | Windows 10/11 Pro | Windows 11 Pro |
| **Virtualización** | Habilitada en BIOS | Habilitada en BIOS | Habilitada en BIOS |

### ⚙️ Desglose de Recursos

**RAM (12 GB mínimo):**
- Primary VM: 4 GB
- Standby VM: 4 GB
- Host OS: 4 GB
- **Total requerido:** 12 GB

**Disco (250 GB mínimo):**
- Oracle software ZIP: 3 GB
- Primary VM discos (u01 + u02): 200 GB
- Standby VM discos (u01 + u02): 200 GB
- Base box Oracle Linux 8: 2 GB
- Overhead (snapshots, logs): 45 GB
- **Total requerido:** 450 GB

**Pero las VMs usan "thin provisioning":**
- Los discos de 100GB empiezan pequeños y crecen según uso
- Uso real inicial: ~50-70 GB por VM
- **Total real inicial:** ~250 GB

**CPU (4 cores mínimo):**
- Primary VM: 2 cores
- Standby VM: 2 cores
- Host OS: necesita al menos 2 cores adicionales
- **Total requerido:** 6 cores (4 mínimo si aceptas lentitud)

### ✅ Cómo Verificar Tu Hardware

#### Verificar RAM

```powershell
# En PowerShell
systeminfo | findstr /C:"Total Physical Memory"
```

**Salida esperada (ejemplo):**
```
Total Physical Memory:     16,384 MB
```

**Necesitas ver:** 12,288 MB o más (12 GB)

---

#### Verificar Espacio en Disco

```powershell
Get-PSDrive C | Select-Object Used,Free
```

**Salida esperada:**
```
      Used          Free
      ----          ----
 214748364800  268435456000
```

Los números están en bytes. Necesitas al menos **250 GB libres** (268,435,456,000 bytes).

**Herramienta alternativa:** Explorador de Windows → clic derecho en disco C: → Propiedades

---

#### Verificar CPU

```powershell
Get-WmiObject Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors
```

**Salida esperada:**
```
Name                           NumberOfCores NumberOfLogicalProcessors
----                           ------------- -------------------------
Intel(R) Core(TM) i7-9750H         6                    12
```

**Necesitas ver:** `NumberOfCores` ≥ 4 (6+ recomendado)

---

#### Verificar Virtualización Habilitada

```powershell
Get-ComputerInfo | Select-Object HyperVisorPresent,HyperVRequirementVirtualizationFirmwareEnabled
```

**Salida esperada:**
```
HyperVisorPresent HyperVRequirementVirtualizationFirmwareEnabled
----------------- -----------------------------------------------
True              True
```

**Si vez "False":**
1. Reinicia tu PC
2. Entra al BIOS/UEFI (usualmente presionando F2, F10, o Del durante el boot)
3. Busca opciones de virtualización:
   - Intel: "Intel VT-x" o "Intel Virtualization Technology"
   - AMD: "AMD-V" o "SVM Mode"
4. Habilita la opción
5. Guarda y reinicia

---

## 2. Requisitos de Software

### 📦 Software Necesario

| Software | Versión Mínima | Versión Recomendada | Propósito |
|----------|----------------|---------------------|-----------|
| **Windows** | 10 Home | 11 Pro | Sistema operativo host |
| **VirtualBox** | 6.1 | 7.0+ | Motor de virtualización |
| **Vagrant** | 2.3 | 2.4+ | Orquestación de VMs |
| **Oracle DB 21c Linux** | 21.3.0.0.0 | 21.3.0.0.0 | Software de base de datos |
| **PowerShell** | 5.1 | 7.0+ | Scripts de despliegue |

**Nota:** PowerShell viene preinstalado en Windows 10/11.

---

## 3. Descarga de Oracle Database 21c

### 🔗 Proceso de Descarga

#### Paso 1: Crear Cuenta Oracle (si no tienes una)

1. Ve a [oracle.com](https://www.oracle.com)
2. Clic en "View Accounts" (esquina superior derecha)
3. Clic en "Create an Account"
4. Completa el formulario de registro
5. Verifica tu email

---

#### Paso 2: Acceder a la Página de Descargas

1. Ve a: [https://www.oracle.com/database/technologies/oracle21c-linux-downloads.html](https://www.oracle.com/database/technologies/oracle21c-linux-downloads.html)
2. O busca en Google: "Oracle Database 21c Linux download"

---

#### Paso 3: Aceptar Licencia

**Encontrarás dos opciones:**

- **Oracle Database 21c for Linux x86-64** (ZIP)
  - Archivo: `LINUX.X64_213000_db_home.zip`
  - Tamaño: **2.9 GB** (3,106,661,680 bytes)
  - ✅ **Esta es la que necesitas**

- **Oracle Database 21c for Linux ARM64** (ZIP)
  - ❌ No uses esta versión

**Importante:**
1. Lee los términos de licencia
2. Marca la casilla "I accept the Oracle..."
3. Clic en "Download LINUX.X64_213000_db_home.zip"

**Nota sobre licencia:** Oracle Database 21c está disponible gratuitamente para desarrollo, pruebas, prototipado, y demostración. Para uso en producción, necesitas licencia comercial.

---

#### Paso 4: Descargar el Archivo

- La descarga tardará dependiendo de tu conexión (2.9 GB)
- **No descomprimas el archivo**
- El ZIP debe quedar como está

---

#### Paso 5: Colocar en Carpeta Correcta

1. Una vez descargado, mueve el archivo a la carpeta `software/` del proyecto:

```
C:\Users\TuUsuario\DataGripProjects\AdminBDProyecto\software\LINUX.X64_213000_db_home.zip
```

2. **Verifica la ubicación:**

```powershell
Test-Path ".\software\LINUX.X64_213000_db_home.zip"
```

**Salida esperada:** `True`

3. **Verifica el tamaño del archivo:**

```powershell
(Get-Item ".\software\LINUX.X64_213000_db_home.zip").Length
```

**Salida esperada:** `3106661680` (aproximadamente 2.9 GB)

**Si el número es mucho menor:** La descarga se corrompió. Descarga nuevamente.

---

### ⚠️ Problemas Comunes de Descarga

**Problema: "Descarga muy lenta"**

Solución:
- Usa un gestor de descargas (Free Download Manager, Internet Download Manager)
- Descarga durante horas de menor tráfico
- Verifica tu conexión a Internet

---

**Problema: "Descarga se interrumpe"**

Solución:
- Usa un gestor de descargas que soporte reanudar
- O usa wget desde WSL/Git Bash:

```bash
wget --continue https://download.oracle.com/otn/linux/oracle21c/213000/LINUX.X64_213000_db_home.zip
```

(Reemplaza la URL con la URL real que obtendrás del sitio de Oracle)

---

**Problema: "No tengo cuenta Oracle y no quiero crear una"**

Solución:
- Desafortunadamente, Oracle requiere cuenta para descargas
- Es gratuito y solo toma 5 minutos
- Alternativamente, pregunta a un compañero que ya lo tenga

---

## 4. Instalación de VirtualBox

### 📥 Descarga VirtualBox

1. Ve a: [https://www.virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)
2. Descarga "VirtualBox X.X.X platform packages" → **Windows hosts**
3. Versión recomendada: **7.0.14** o más reciente

**Archivo descargado:** `VirtualBox-7.0.14-XXXXX-Win.exe` (~100 MB)

---

### 🛠️ Instalación Paso a Paso

1. **Ejecuta el instalador** (doble clic en el .exe)

2. **Pantalla de bienvenida:**
   - Clic en "Next"

3. **Custom Setup:**
   - Deja todas las opciones por defecto
   - Ubicación de instalación: `C:\Program Files\Oracle\VirtualBox\`
   - Clic en "Next"

4. **Warning: Network Interfaces:**
   - Mensaje: "This will reset your network connection temporarily"
   - Clic en "Yes" (es normal, la red se reconectará automáticamente)

5. **Ready to Install:**
   - Clic en "Install"

6. **Permitir instalación de drivers:**
   - Windows preguntará si confías en Oracle
   - Clic en "Install" para cada driver (USB, Network)

7. **Instalación completada:**
   - Clic en "Finish"

---

### ✅ Verificar Instalación de VirtualBox

```powershell
# Verificar que VBoxManage está disponible
VBoxManage --version
```

**Salida esperada:**
```
7.0.14r161095
```

---

```powershell
# Verificar servicio de VirtualBox
Get-Service -Name "VBoxSVC"
```

**Salida esperada:**
```
Status   Name               DisplayName
------   ----               -----------
Running  VBoxSVC            VirtualBox Host Service
```

**Si el servicio no está running:**

```powershell
Start-Service -Name "VBoxSVC"
```

---

### 🎨 Opcional: Verificar GUI de VirtualBox

1. Abre el menú de Windows
2. Busca "Oracle VM VirtualBox"
3. Ejecuta la aplicación
4. Debes ver la ventana principal de VirtualBox (vacía, sin VMs)

**Nota:** No necesitas usar la GUI. Todo se maneja vía Vagrant.

---

## 5. Instalación de Vagrant

### 📥 Descarga Vagrant

1. Ve a: [https://www.vagrantup.com/downloads](https://www.vagrantup.com/downloads)
2. Selecciona **Windows** → **AMD64**
3. Versión recomendada: **2.4.1** o más reciente

**Archivo descargado:** `vagrant_2.4.1_windows_amd64.msi` (~300 MB)

---

### 🛠️ Instalación Paso a Paso

1. **Ejecuta el instalador** (doble clic en el .msi)

2. **Pantalla de bienvenida:**
   - Clic en "Next"

3. **End-User License Agreement:**
   - Lee y acepta los términos
   - Clic en "I accept" y "Next"

4. **Destination Folder:**
   - Ubicación: `C:\HashiCorp\Vagrant\`
   - Clic en "Next"

5. **Ready to install:**
   - Clic en "Install"

6. **Instalación completada:**
   - Clic en "Finish"
   - **Reinicia tu computadora** (importante!)

---

### ✅ Verificar Instalación de Vagrant

**Después de reiniciar:**

```powershell
vagrant --version
```

**Salida esperada:**
```
Vagrant 2.4.1
```

---

```powershell
vagrant plugin list
```

**Salida esperada:**
```
vagrant-vbguest (0.31.0, global)
```

**Si no ves vagrant-vbguest:**

```powershell
vagrant plugin install vagrant-vbguest
```

**Qué hace este plugin:**
- Mantiene VirtualBox Guest Additions actualizadas en las VMs
- Soluciona problemas de synced folders automáticamente
- Muy recomendado para este proyecto

---

## 6. Verificación del Proyecto

### 📁 Estructura de Carpetas

Asegúrate de que tu proyecto tiene esta estructura:

```
C:\Users\TuUsuario\DataGripProjects\AdminBDProyecto\
├── 1-BD/
│   ├── ScriptProyectoBD.SQL          ← Script principal del schema
│   ├── data.sql
│   ├── PKG_UTILITIES.PKG
│   └── ... (otros archivos)
│
├── 2-Standby/
│   ├── scripts/
│   │   ├── primary/
│   │   └── standby/
│   ├── automation/
│   └── infrastructure/
│
├── config/
│   ├── vagrant.yml                   ← Configuración de VMs
│   └── install.env                   ← Variables de entorno
│
├── powershell/
│   ├── deploy.ps1                    ← Script principal de despliegue
│   ├── destroy.ps1
│   └── fix-line-endings.ps1
│
├── software/
│   └── LINUX.X64_213000_db_home.zip  ← Oracle 21c (descargado)
│
├── guiastby/                          ← Esta documentación
│   ├── 00-tabla-contenidos.md
│   ├── 01-introduccion.md
│   ├── ...
│   └── PROGRESS.md
│
├── Vagrantfile                        ← Configuración de Vagrant
├── .gitignore
└── CLAUDE.md
```

---

### ✅ Verificar Archivos Críticos

```powershell
# Desde la raíz del proyecto

# Verificar Vagrantfile
Test-Path ".\Vagrantfile"

# Verificar configuración
Test-Path ".\config\vagrant.yml"
Test-Path ".\config\install.env"

# Verificar scripts PowerShell
Test-Path ".\powershell\deploy.ps1"
Test-Path ".\powershell\destroy.ps1"

# Verificar Oracle software
Test-Path ".\software\LINUX.X64_213000_db_home.zip"

# Verificar scripts de primary
Test-Path ".\2-Standby\scripts\primary\setup.sh"

# Verificar scripts de standby
Test-Path ".\2-Standby\scripts\standby\setup.sh"
```

**Todos deben devolver:** `True`

**Si alguno devuelve `False`:**
- El archivo no existe o la ruta es incorrecta
- Verifica que estás en el directorio correcto del proyecto
- Verifica que clonaste/descargaste el repositorio completo

---

## 7. Configuración del Archivo install.env

El archivo `config/install.env` contiene todas las variables de entorno usadas por los scripts.

### 📝 Revisión de Configuración

Abre el archivo en un editor de texto:

```powershell
notepad .\config\install.env
```

### Valores Críticos a Verificar

#### Contraseñas

```bash
SYS_PASSWORD=S1sPassword1!
PDB_PASSWORD=PdbPassword1!
APP_SCHEMA_PASSWORD=HCApp2025!
```

**Puedes cambiarlas si deseas**, pero ten en cuenta:
- Se usan en toda la documentación
- Se usan en comandos de conexión
- Deben cumplir política de Oracle: mínimo 8 caracteres, mayúscula, minúscula, número, símbolo

**Recomendación:** Déjalas por defecto para tu primer despliegue.

---

#### IPs de Red

```bash
NODE1_PUBLIC_IP=192.168.56.101
NODE2_PUBLIC_IP=192.168.56.102
```

**No cambies estas IPs** a menos que tengas conflictos con otras VMs de VirtualBox.

**Cómo verificar conflictos:**

```powershell
VBoxManage list vms
VBoxManage list runningvms
```

Si hay VMs usando 192.168.56.x, considera cambiar a otra subred (ej: 192.168.57.x).

---

#### Configuración de Data Guard

```bash
ARCHIVE_LAG_TARGET=300        # 5 minutos (requisito del entregable)
PROTECTION_MODE=MAXAVAILABILITY
TRANSPORT_MODE=FASTSYNC
```

**No cambies estos valores.** Están configurados para cumplir los requisitos del entregable.

---

#### Configuración de Backups

```bash
BACKUP_RETENTION_DAYS=7       # Retener backups 7 días
ARCHIVE_RETENTION_DAYS=3      # Retener archives 3 días (requisito)
```

**Puedes ajustar si necesitas:**
- `BACKUP_RETENTION_DAYS`: Aumenta si quieres backups más antiguos (consumirá más disco)
- `ARCHIVE_RETENTION_DAYS`: **No bajes de 3 días** (requisito del entregable)

---

### 🔐 Seguridad del Archivo install.env

**Advertencia:** Este archivo contiene contraseñas en texto plano.

**Para ambiente de desarrollo/pruebas:** Está bien.

**Para producción:**
- No uses contraseñas por defecto
- Usa contraseñas fuertes generadas aleatoriamente
- Considera usar Oracle Wallet para encriptar credenciales
- No versiones install.env en Git (ya está en .gitignore)

---

## 8. Verificación de Prerequisitos

### ✅ Script de Verificación Automática

El script `deploy.ps1` verifica prerequisitos automáticamente, pero puedes probarlo sin ejecutar todo el despliegue:

```powershell
# Verificar solo prerequisitos (sin despliegue)
.\powershell\deploy.ps1 -VerifyOnly
```

**Si el parámetro no existe**, puedes hacer verificación manual:

---

### 🔍 Verificación Manual Completa

Ejecuta todos estos comandos en PowerShell desde la raíz del proyecto:

```powershell
Write-Host "=== Verificación de Prerequisitos ===" -ForegroundColor Cyan

# 1. RAM
$ram = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1GB
Write-Host "RAM Total: $ram GB" -ForegroundColor $(if ($ram -ge 12) {"Green"} else {"Red"})

# 2. Espacio en disco
$disk = Get-PSDrive C
$freeGB = [math]::Round($disk.Free / 1GB, 2)
Write-Host "Espacio libre en C: $freeGB GB" -ForegroundColor $(if ($freeGB -ge 250) {"Green"} else {"Red"})

# 3. CPU cores
$cores = (Get-WmiObject Win32_Processor).NumberOfCores
Write-Host "CPU Cores: $cores" -ForegroundColor $(if ($cores -ge 4) {"Green"} else {"Yellow"})

# 4. VirtualBox
try {
    $vboxVersion = VBoxManage --version
    Write-Host "VirtualBox: $vboxVersion" -ForegroundColor Green
} catch {
    Write-Host "VirtualBox: NO INSTALADO" -ForegroundColor Red
}

# 5. Vagrant
try {
    $vagrantVersion = vagrant --version
    Write-Host "Vagrant: $vagrantVersion" -ForegroundColor Green
} catch {
    Write-Host "Vagrant: NO INSTALADO" -ForegroundColor Red
}

# 6. Oracle software
if (Test-Path ".\software\LINUX.X64_213000_db_home.zip") {
    $oraSize = [math]::Round((Get-Item ".\software\LINUX.X64_213000_db_home.zip").Length / 1GB, 2)
    Write-Host "Oracle 21c: Presente ($oraSize GB)" -ForegroundColor Green
} else {
    Write-Host "Oracle 21c: NO ENCONTRADO" -ForegroundColor Red
}

# 7. Archivos del proyecto
$files = @(
    "Vagrantfile",
    "config\vagrant.yml",
    "config\install.env",
    "powershell\deploy.ps1"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "$file: OK" -ForegroundColor Green
    } else {
        Write-Host "$file: FALTA" -ForegroundColor Red
    }
}

Write-Host "`n=== Verificación Completa ===" -ForegroundColor Cyan
```

---

### ✅ Resultados Esperados

```
=== Verificación de Prerequisitos ===
RAM Total: 16 GB
Espacio libre en C: 320.5 GB
CPU Cores: 6
VirtualBox: 7.0.14r161095
Vagrant: Vagrant 2.4.1
Oracle 21c: Presente (2.9 GB)
Vagrantfile: OK
config\vagrant.yml: OK
config\install.env: OK
powershell\deploy.ps1: OK

=== Verificación Completa ===
```

**Todo en verde:** Estás listo para desplegar! ✅

**Alguno en rojo:** Revisa la sección correspondiente arriba.

---

## 🚀 ¿Qué Sigue?

Una vez que todos los prerequisitos están cumplidos:

### ✅ Checklist Final

- [ ] Hardware cumple requisitos (RAM ≥12GB, Disco ≥250GB, CPU ≥4 cores)
- [ ] Virtualización habilitada en BIOS
- [ ] VirtualBox instalado y funcionando
- [ ] Vagrant instalado y funcionando
- [ ] Plugin vagrant-vbguest instalado
- [ ] Oracle Database 21c descargado en `software/`
- [ ] Estructura de carpetas del proyecto verificada
- [ ] Archivo `install.env` revisado

### ⏭️ Próximo Paso

**Estás listo para desplegar el sistema!**

Continúa con **[04 - Cómo Usar](04-como-usar.md)** y ejecuta:

```powershell
.\powershell\deploy.ps1
```

---

## ⚠️ Troubleshooting de Prerequisitos

### Problema: "No tengo suficiente RAM"

**Opción 1: Reducir RAM de VMs** (no recomendado)

Editar `config/vagrant.yml`:

```yaml
node1:
  mem_size: 3072  # Reducir de 4096 a 3GB

node2:
  mem_size: 3072
```

**Advertencia:** Puede causar lentitud o errores. Mínimo absoluto: 2048 (2GB) por VM.

**Opción 2: Cerrar aplicaciones** durante el despliegue

- Cierra navegadores, IDEs, juegos
- Libera la mayor cantidad de RAM posible

**Opción 3: Desplegar solo primary** (para pruebas)

```bash
vagrant up primary
# No ejecutes standby si no tienes RAM suficiente
```

---

### Problema: "No tengo suficiente disco"

**Opción 1: Limpiar espacio**

```powershell
# Limpiador de disco de Windows
cleanmgr /d C:

# Eliminar archivos temporales
Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue

# Vaciar papelera de reciclaje
Clear-RecycleBin -Force
```

**Opción 2: Usar otro disco**

Si tienes otro disco con más espacio (D:, E:, etc.):

1. Mueve el proyecto completo a ese disco
2. Ejecuta desde allí

**Opción 3: Reducir tamaño de discos VMs** (no recomendado)

Editar `config/vagrant.yml`:

```yaml
node1:
  disk_size: 51200  # Reducir de 102400 (100GB) a 50GB

node2:
  disk_size: 51200
```

**Advertencia:** 50GB puede ser insuficiente si cargas muchos datos.

---

### Problema: "Virtualización no disponible en BIOS"

**Síntoma:**

```
VBoxManage: error: AMD-V is disabled in the BIOS
```

**Solución:**

1. Reinicia tu PC
2. Presiona la tecla de BIOS durante el boot:
   - Dell: F2
   - HP: F10 o Esc
   - Lenovo/ThinkPad: F1
   - ASUS: F2 o Del
   - Acer: F2 o Del
   - MSI: Del

3. Busca sección de CPU o Advanced
4. Busca opción:
   - **Intel:** "Intel VT-x", "Intel Virtualization Technology", "VMX"
   - **AMD:** "AMD-V", "SVM Mode", "Secure Virtual Machine"
5. Cambia a **Enabled**
6. Guarda (F10) y reinicia

**Si no encuentras la opción:**
- Consulta el manual de tu PC/motherboard
- Busca en Google: "[Modelo de tu PC] habilitar virtualización"

---

### Problema: "Windows Home no soporta Hyper-V"

**Síntoma:** Tienes Windows 10/11 Home y has visto mensajes sobre Hyper-V.

**Solución:** No necesitas Hyper-V. VirtualBox funciona perfectamente en Windows Home.

**Asegúrate de:**
- Hyper-V NO está habilitado (Windows Home no lo tiene)
- VirtualBox está usando su propio hypervisor
- Virtualización está habilitada en BIOS (ver arriba)

**Verificar que Hyper-V no interfiere:**

```powershell
Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
```

Si muestra "Enabled", deshabilita:

```powershell
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
# Reinicia después
```

---

### Problema: "Descarga de Oracle falla/corrompe"

**Solución 1: Verificar SHA256**

Oracle proporciona checksums. Verifica:

```powershell
Get-FileHash -Algorithm SHA256 .\software\LINUX.X64_213000_db_home.zip
```

Compara con el checksum en la página de descarga de Oracle.

**Solución 2: Usar gestor de descargas**

- Free Download Manager
- Internet Download Manager
- wget (desde WSL o Git Bash)

**Solución 3: Descargar desde otra ubicación**

Pide a un compañero que ya lo tenga o descarga desde un mirror de Oracle (si están disponibles).

---

## 📚 Referencias

- [VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant Downloads](https://www.vagrantup.com/downloads)
- [Oracle Database 21c Downloads](https://www.oracle.com/database/technologies/oracle21c-linux-downloads.html)
- [Vagrant VBGuest Plugin](https://github.com/dotless-de/vagrant-vbguest)

---

## ⏭️ Siguiente Paso

**Prerequisitos completados!**

Continúa con **[04 - Cómo Usar](04-como-usar.md)** para desplegar el sistema.

Si quieres entender mejor los conceptos básicos primero, lee **[02 - Conceptos Fundamentales](02-conceptos-fundamentales.md)**.

---

**¡Estás listo para comenzar!** 🚀
