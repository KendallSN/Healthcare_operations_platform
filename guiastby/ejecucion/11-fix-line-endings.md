# 11 - Script de Corrección de Line Endings

## Conversión Automática CRLF → LF para Compatibilidad Linux

El script `fix-line-endings.ps1` convierte automáticamente todos los archivos shell (`.sh`) y de configuración (`.env`) del proyecto de formato Windows (CRLF) a formato Unix/Linux (LF). Esta conversión es **crítica** para evitar errores de sintaxis cuando los scripts se ejecutan dentro de las máquinas virtuales Linux.

---

## 📋 Tabla de Contenidos

1. [Ubicación](#ubicación)
2. [Propósito](#propósito)
3. [Cuándo se Ejecuta](#cuándo-se-ejecuta)
4. [El Problema: CRLF vs LF](#el-problema-crlf-vs-lf)
5. [Variables y Configuración Utilizadas](#variables-y-configuración-utilizadas)
6. [Flujo de Ejecución Paso a Paso](#flujo-de-ejecución-paso-a-paso)
7. [Archivos Modificados](#archivos-modificados)
8. [Dependencias](#dependencias)
9. [Logs Generados](#logs-generados)
10. [Puntos de Fallo Comunes](#puntos-de-fallo-comunes)
11. [Relación con Data Guard](#relación-con-data-guard)
12. [Referencias Cruzadas](#referencias-cruzadas)
13. [Siguiente Paso](#siguiente-paso)

---

## Ubicación

```
powershell/fix-line-endings.ps1
```

**Ruta completa:** `C:\Users\StarAlchemist\DataGripProjects\AdminBDProyecto\powershell\fix-line-endings.ps1`

---

## Propósito

Este script tiene una responsabilidad única pero crítica: **convertir line endings de Windows a Unix** en todos los archivos shell y de configuración.

**Archivos objetivo:**
- **Scripts shell:** Todos los `.sh` en el proyecto (provisioners, automation, shared scripts)
- **Archivos de configuración:** Todos los `.env` (variables de entorno)

**Por qué es necesario:**

Windows y Linux usan diferentes caracteres para representar el final de línea:
- **Windows (CRLF):** `\r\n` (Carriage Return + Line Feed) - 2 bytes
- **Linux/Unix (LF):** `\n` (Line Feed solamente) - 1 byte

Si un script shell tiene CRLF, Bash lo interpreta como:
```bash
#!/bin/bash␍
echo "Hello"␍
```

El carácter `␍` (CR) causa el error:
```
$'\r': command not found
```

Este script elimina todos los `\r` para que los scripts funcionen correctamente en Linux.

---

## Cuándo se Ejecuta

### Contexto en la Secuencia de Despliegue

**Fase:** Fase 2 del despliegue automatizado
**Llamado por:** `deploy.ps1`
**Orden en secuencia:** 2 de 6 fases

### Comando de Ejecución

**Automático (dentro de deploy.ps1):**
```powershell
& powershell -ExecutionPolicy Bypass -File .\powershell\fix-line-endings.ps1
```

**Manual (si necesitas ejecutarlo independientemente):**
```powershell
# Desde la raíz del proyecto
.\powershell\fix-line-endings.ps1
```

### Cuándo Ejecutarlo Manualmente

**Ejecutar manualmente en estos casos:**

1. **Acabas de editar scripts `.sh` en Windows:**
   - Editaste con Notepad (siempre usa CRLF)
   - Editaste con un editor que no preserva LF
   - Acabas de crear nuevos scripts shell

2. **El despliegue falla con error `$'\r': command not found`:**
   - Este error indica line endings incorrectos
   - Ejecuta el script y vuelve a deployar

3. **Clonaste el repositorio en Windows:**
   - Git puede convertir LF a CRLF automáticamente (depende de configuración)
   - Ejecuta el script antes del primer despliegue

**NO necesitas ejecutarlo si:**
- Acabas de ejecutar `deploy.ps1` (ya lo ejecutó automáticamente)
- Solo editaste archivos `.md`, `.ps1`, o código PL/SQL
- Solo modificaste configuración en `vagrant.yml` (YAML tolera CRLF)

---

## El Problema: CRLF vs LF

### Historia y Razón de la Diferencia

**Teletypes antiguos (1960s-1970s):**
- **Carriage Return (CR):** Mover el cabezal al inicio de la línea
- **Line Feed (LF):** Mover el papel una línea hacia arriba

**Dos caracteres necesarios:**
1. CR - regresar al inicio
2. LF - avanzar a la siguiente línea

**Evolución moderna:**
- **Windows:** Mantuvo ambos caracteres (CRLF) por compatibilidad con sistemas antiguos
- **Unix/Linux:** Simplificó a solo LF (el cursor se mueve automáticamente)
- **Mac clásico (pre-OSX):** Usaba solo CR
- **Mac moderno (OSX):** Adoptó LF (Unix-like)

### Demostración del Problema

**Archivo con CRLF en Windows:**
```powershell
# Crear archivo de prueba con CRLF
"#!/bin/bash`r`necho 'Hello World'`r`n" | Out-File -FilePath test.sh -Encoding ASCII

# Ver en hexadecimal
Format-Hex test.sh
```

**Salida:**
```
00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F

00000000   23 21 2F 62 69 6E 2F 62 61 73 68 0D 0A 65 63 68  #!/bin/bash..ech
00000010   6F 20 27 48 65 6C 6C 6F 20 57 6F 72 6C 64 27 0D  o 'Hello World'.
00000020   0A                                               .
```

Observa:
- `0D` = CR (Carriage Return)
- `0A` = LF (Line Feed)
- `.` en la visualización representa caracteres no imprimibles

**Ejecutar en Linux:**
```bash
bash test.sh
```

**Error:**
```
test.sh: line 1: $'\r': command not found
Hello World
test.sh: line 2: $'\r': command not found
```

El script ejecuta pero Bash intenta interpretar `\r` como comando.

**Archivo con LF en Linux:**
```
00000000   23 21 2F 62 69 6E 2F 62 61 73 68 0A 65 63 68 6F  #!/bin/bash.echo
00000010   20 27 48 65 6C 6C 6F 20 57 6F 72 6C 64 27 0A     'Hello World'.
```

Solo `0A` (LF), sin `0D` (CR). Bash lo interpreta correctamente.

### Impacto en el Proyecto

**Sin este script, TODOS los provisioners fallarían:**

```
==> primary: Running provisioner: shell...
    primary: Running: /vagrant/2-Standby/scripts/primary/setup.sh
    primary: /vagrant/2-Standby/scripts/primary/setup.sh: line 2: $'\r': command not found
    primary: /vagrant/2-Standby/scripts/primary/setup.sh: line 3: $'\r': command not found
    ...
    [Cientos de errores]
    primary: The SSH command responded with a non-zero exit status.
```

**Resultado:** Despliegue completo fallido.

**Con este script:**
- Todos los scripts se ejecutan sin errores
- Provisioners completan exitosamente
- Despliegue exitoso

---

## Variables y Configuración Utilizadas

### Variables Internas del Script

```powershell
# Directorio del proyecto (padre del directorio powershell/)
$projectRoot = Split-Path -Parent $PSScriptRoot

# Archivos a convertir
$shFiles = Get-ChildItem -Path $projectRoot -Filter *.sh -Recurse
$envFiles = Get-ChildItem -Path $projectRoot -Filter *.env -Recurse
$files = $shFiles + $envFiles
```

**Explicación de variables:**

- **`$PSScriptRoot`:** Directorio donde está el script (powershell/)
- **`$projectRoot`:** Directorio raíz del proyecto (padre de powershell/)
- **`$shFiles`:** Array de objetos FileInfo para archivos `.sh`
- **`$envFiles`:** Array de objetos FileInfo para archivos `.env`
- **`$files`:** Unión de ambos arrays

### Parámetros de Get-ChildItem

```powershell
Get-ChildItem -Path $projectRoot -Filter *.sh -Recurse
```

**Parámetros:**
- **`-Path`:** Directorio raíz donde buscar
- **`-Filter`:** Patrón de nombres de archivo (`*.sh` o `*.env`)
- **`-Recurse`:** Buscar recursivamente en subdirectorios

### Encoding de Salida

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
```

**Por qué UTF-8 sin BOM:**
- **BOM (Byte Order Mark):** 3 bytes especiales al inicio del archivo (EF BB BF)
- **Linux no espera BOM:** Puede causar errores en shebang `#!/bin/bash`
- **UTF-8 sin BOM:** Compatible con ASCII puro y caracteres Unicode

**Ejemplo de problema con BOM:**
```
#!/bin/bash  (con BOM invisible al inicio)
```

Bash lo interpreta como:
```
#!/bin/bash  (con caracteres extraños)
```

Resultado: `bad interpreter: No such file or directory`

---

## Flujo de Ejecución Paso a Paso

### Paso 1: Mensaje de Inicio

```powershell
Write-Host "Converting shell scripts and config files to Unix (LF) line endings..." -ForegroundColor Green
```

**Explicación:**
Muestra mensaje verde indicando que el script está iniciando.

**Salida en consola:**
```
Converting shell scripts and config files to Unix (LF) line endings...
```

---

### Paso 2: Obtener Directorio Raíz del Proyecto

```powershell
# Get project root (parent of script directory)
$projectRoot = Split-Path -Parent $PSScriptRoot
```

**Explicación:**
Calcula el directorio raíz del proyecto para buscar archivos desde ahí.

**Ejemplo:**
- `$PSScriptRoot` = `C:\...\AdminBDProyecto\powershell`
- `$projectRoot` = `C:\...\AdminBDProyecto`

**Por qué es necesario:**
El script está en `powershell/` pero los archivos `.sh` están en:
- `2-Standby/scripts/primary/`
- `2-Standby/scripts/standby/`
- `2-Standby/automation/`
- `2-Standby/infrastructure/`

---

### Paso 3: Buscar Todos los Archivos .sh y .env

```powershell
# Get all .sh and .env files recursively from project root
$shFiles = Get-ChildItem -Path $projectRoot -Filter *.sh -Recurse
$envFiles = Get-ChildItem -Path $projectRoot -Filter *.env -Recurse
$files = $shFiles + $envFiles
```

**Explicación:**
Busca recursivamente en todo el proyecto:
1. Todos los archivos que terminan en `.sh`
2. Todos los archivos que terminan en `.env`
3. Los combina en un solo array

**Archivos encontrados típicamente (47 archivos):**

**Scripts Primary (12 archivos):**
```
2-Standby/scripts/primary/setup.sh
2-Standby/scripts/primary/root_setup.sh
2-Standby/scripts/primary/oracle_user_environment_setup.sh
2-Standby/scripts/primary/oracle_create_database.sh
2-Standby/scripts/primary/deploy_custom_schema.sh
2-Standby/scripts/primary/setup_automation.sh
2-Standby/scripts/primary/setup_ssh_keys_auto.sh
2-Standby/scripts/primary/install_cron_jobs_auto.sh
... (más)
```

**Scripts Standby (11 archivos):**
```
2-Standby/scripts/standby/setup.sh
2-Standby/scripts/standby/root_setup.sh
2-Standby/scripts/standby/oracle_user_environment_setup.sh
2-Standby/scripts/standby/oracle_create_database.sh
... (más)
```

**Scripts Shared (12 archivos):**
```
2-Standby/infrastructure/prepare_u01_u02_disks.sh
2-Standby/infrastructure/install_os_packages.sh
2-Standby/infrastructure/configure_hosts_base.sh
2-Standby/infrastructure/configure_hostname.sh
2-Standby/infrastructure/configure_chrony.sh
2-Standby/infrastructure/oracle_db_software_installation.sh
... (más)
```

**Scripts Automation (8 archivos):**
```
2-Standby/automation/check_log_transport.sh
2-Standby/automation/rman_daily_backup.sh
2-Standby/automation/delete_archives_primary.sh
2-Standby/automation/delete_archives_standby.sh
2-Standby/automation/verify_dataguard.sh
2-Standby/automation/install_cron_jobs.sh
2-Standby/automation/manual_backup.sh
2-Standby/automation/manual_sync.sh
```

**Archivos .env (4 archivos):**
```
config/install.env
(posiblemente otros .env si existen)
```

---

### Paso 4: Iterar y Convertir Cada Archivo

```powershell
foreach ($file in $files) {
    Write-Host "Processing: $($file.FullName)" -ForegroundColor Yellow

    # Read content and convert CRLF to LF
    $content = Get-Content $file.FullName -Raw
    $content = $content -replace "`r`n", "`n"

    # Write back without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
}
```

**Explicación paso a paso:**

**4.1. Mostrar archivo siendo procesado:**
```powershell
Write-Host "Processing: $($file.FullName)" -ForegroundColor Yellow
```

**Salida:**
```
Processing: C:\...\2-Standby\scripts\primary\setup.sh
Processing: C:\...\2-Standby\scripts\primary\root_setup.sh
...
```

**4.2. Leer contenido completo del archivo:**
```powershell
$content = Get-Content $file.FullName -Raw
```

**Parámetro `-Raw`:**
- Lee el archivo como un solo string
- Preserva exactamente todos los caracteres (incluyendo CRLF)
- Sin `-Raw`, PowerShell divide en líneas y normaliza line endings

**Ejemplo de `$content` antes de conversión:**
```
"#!/bin/bash\r\n\r\necho 'Hello'\r\n"
```

**4.3. Reemplazar CRLF con LF:**
```powershell
$content = $content -replace "`r`n", "`n"
```

**Operador `-replace`:**
- Búsqueda y reemplazo con regex
- `` `r`n`` es la secuencia de escape PowerShell para CRLF
- `` `n`` es la secuencia de escape PowerShell para LF

**Resultado:**
```
"#!/bin/bash\n\necho 'Hello'\n"
```

**4.4. Escribir de vuelta sin BOM:**
```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
```

**Por qué usar `System.IO.File` en lugar de `Out-File`:**
- `Out-File` en PowerShell 5.1 agrega BOM por defecto
- `System.IO.File.WriteAllText()` permite controlar encoding exacto
- `$false` en el constructor = sin BOM

**Alternativa en PowerShell 7+:**
```powershell
$content | Out-File -FilePath $file.FullName -Encoding utf8NoBOM
```

---

### Paso 5: Resumen de Resultados

```powershell
Write-Host "`nConversion complete! Total files processed: $($files.Count)" -ForegroundColor Green
Write-Host "  - Shell scripts (.sh): $($shFiles.Count)" -ForegroundColor Cyan
Write-Host "  - Config files (.env): $($envFiles.Count)" -ForegroundColor Cyan
Write-Host "`nYou can now run deployment again." -ForegroundColor Green
```

**Explicación:**
Muestra resumen de cuántos archivos se procesaron.

**Salida típica:**
```

Conversion complete! Total files processed: 47
  - Shell scripts (.sh): 43
  - Config files (.env): 4

You can now run deployment again.
```

---

## Archivos Modificados

### Categorías de Archivos Afectados

**1. Scripts de Provisioning Primary (12 archivos)**
```
2-Standby/scripts/primary/
├── setup.sh                              (entry point)
├── root_setup.sh                         (orquestador)
├── oracle_user_environment_setup.sh      (configuración usuario oracle)
├── oracle_create_database.sh             (creación de base de datos)
├── deploy_custom_schema.sh               (deployment del schema healthcare)
├── setup_automation.sh                   (copia scripts de automatización)
├── setup_ssh_keys_auto.sh                (configuración SSH)
├── install_cron_jobs_auto.sh             (instalación cron jobs)
└── ... (más scripts)
```

**2. Scripts de Provisioning Standby (11 archivos)**
```
2-Standby/scripts/standby/
├── setup.sh                              (entry point)
├── root_setup.sh                         (orquestador)
├── oracle_user_environment_setup.sh
├── oracle_create_database.sh             (RMAN DUPLICATE + Data Guard)
├── setup_automation.sh
├── setup_ssh_keys_auto.sh
├── install_cron_jobs_auto.sh
└── ... (más scripts)
```

**3. Scripts Compartidos (12 archivos)**
```
2-Standby/infrastructure/
├── prepare_u01_u02_disks.sh              (preparación discos)
├── install_os_packages.sh                (instalación paquetes Oracle)
├── configure_hosts_base.sh               (/etc/hosts)
├── configure_hostname.sh                 (hostname)
├── configure_chrony.sh                   (sincronización tiempo)
├── oracle_db_software_installation.sh    (instalación Oracle)
├── setup_oracle_autostart.sh             (auto-start Oracle)
└── ... (más scripts)
```

**4. Scripts de Automatización (8 archivos)**
```
2-Standby/automation/
├── check_log_transport.sh                (monitoreo cada 10 min)
├── rman_daily_backup.sh                  (backup diario 1 AM)
├── delete_archives_primary.sh            (cleanup archives primary)
├── delete_archives_standby.sh            (cleanup archives standby)
├── verify_dataguard.sh                   (verificación completa DG)
├── install_cron_jobs.sh                  (instalador de cron jobs)
├── manual_backup.sh                      (backup manual)
├── manual_sync.sh                        (sincronización manual)
└── setup_ssh_keys.sh                     (configuración SSH manual)
```

**5. Archivos de Configuración (4 archivos)**
```
config/
└── install.env                           (variables de entorno)
```

### Total de Archivos Afectados

**Típico:** 47 archivos
- 43 scripts shell (`.sh`)
- 4 archivos de configuración (`.env`)

**Tamaño total procesado:** ~200 KB de código shell

---

## Dependencias

### Prerequisitos

**Software requerido:**
- PowerShell 5.1+ (incluido en Windows 10/11)

**Permisos requeridos:**
- Lectura/escritura en el directorio del proyecto
- NO requiere permisos de administrador

### Archivos de Entrada

**Archivos que el script busca y modifica:**
- Todos los `*.sh` en el proyecto
- Todos los `*.env` en el proyecto

**Nota importante:** El script modifica archivos IN-PLACE (sobrescribe los originales).

### Archivos de Salida

**El script NO crea nuevos archivos**, solo modifica los existentes.

**Cambios realizados:**
- Line endings: CRLF → LF
- Encoding: UTF-8 sin BOM
- Contenido: Sin cambios (solo line endings)

---

## Logs Generados

### Logs en deploy.ps1

Cuando se ejecuta desde `deploy.ps1`, la salida se guarda en:

```
powershell/logs/deploy-TIMESTAMP/01-line-endings.log
```

**Contenido del log:**
```
Converting shell scripts and config files to Unix (LF) line endings...
Processing: C:\...\2-Standby\scripts\primary\setup.sh
Processing: C:\...\2-Standby\scripts\primary\root_setup.sh
Processing: C:\...\2-Standby\scripts\primary\oracle_user_environment_setup.sh
...
(47 líneas de "Processing: ...")
...

Conversion complete! Total files processed: 47
  - Shell scripts (.sh): 43
  - Config files (.env): 4

You can now run deployment again.
```

### Logs en Ejecución Manual

Cuando se ejecuta manualmente, la salida solo aparece en consola (no se guarda automáticamente).

**Para guardar log manualmente:**
```powershell
.\powershell\fix-line-endings.ps1 | Tee-Object -FilePath fix-line-endings-manual.log
```

---

## Puntos de Fallo Comunes

### 1. Execution Policy bloquea el script

**Error:**
```
.\fix-line-endings.ps1 : File C:\...\fix-line-endings.ps1 cannot be loaded
because running scripts is disabled on this system.
```

**Causa:** Execution policy de PowerShell está en `Restricted` o `AllSigned`

**Solución:**

**Opción 1: Bypass solo para esta sesión (recomendado)**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\powershell\fix-line-endings.ps1
```

**Opción 2: Ejecutar con bypass inline**
```powershell
powershell -ExecutionPolicy Bypass -File .\powershell\fix-line-endings.ps1
```

**Opción 3: Cambiar policy permanentemente (NO recomendado)**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

### 2. Access denied al escribir archivos

**Error:**
```
Exception calling "WriteAllText" with "3" argument(s): "Access to the path 'C:\...\setup.sh' is denied."
```

**Causa:** Archivo está siendo usado por otro programa o es de solo lectura

**Diagnóstico:**
```powershell
# Verificar si el archivo es de solo lectura
Get-ChildItem -Path "2-Standby\scripts\" -Filter *.sh -Recurse | Where-Object { $_.IsReadOnly }
```

**Solución:**

**Cerrar programas que usan los archivos:**
- Editores de texto (VSCode, Notepad++, etc.)
- Git GUI clients
- Antivirus en escaneo

**Remover atributo de solo lectura:**
```powershell
Get-ChildItem -Path "2-Standby\scripts\" -Filter *.sh -Recurse | ForEach-Object { $_.IsReadOnly = $false }
```

---

### 3. No se encuentran archivos .sh

**Salida:**
```
Converting shell scripts and config files to Unix (LF) line endings...

Conversion complete! Total files processed: 0
  - Shell scripts (.sh): 0
  - Config files (.env): 0
```

**Causa:** El script se ejecutó desde un directorio incorrecto

**Verificación:**
```powershell
# Ver desde dónde se está ejecutando
Get-Location

# Debe retornar la raíz del proyecto, NO powershell/
```

**Solución:**
```powershell
# Cambiar a la raíz del proyecto
cd C:\Users\StarAlchemist\DataGripProjects\AdminBDProyecto

# Ejecutar desde raíz
.\powershell\fix-line-endings.ps1
```

---

### 4. Archivos ya tienen LF pero el script los procesa igual

**Observación:**
El script procesa archivos incluso si ya tienen LF.

**Comportamiento:**
```powershell
$content = $content -replace "`r`n", "`n"
```

Si `$content` solo tiene `\n` (sin `\r`), el reemplazo no hace nada (es una operación no-op).

**Resultado:**
- No hay problema
- Es seguro ejecutar el script múltiples veces
- Es idempotente (ejecutarlo varias veces da el mismo resultado)

**Verificación de line endings:**

**Windows (PowerShell):**
```powershell
# Ver line endings de un archivo
$content = Get-Content -Path "2-Standby\scripts\primary\setup.sh" -Raw
if ($content -match "`r`n") {
    Write-Host "Archivo tiene CRLF (Windows)"
} elseif ($content -match "`n") {
    Write-Host "Archivo tiene LF (Unix)"
}
```

**Linux (dentro de VM):**
```bash
# Ver line endings
file 2-Standby/scripts/primary/setup.sh

# Salida esperada después de conversión:
# setup.sh: ASCII text

# Si tiene CRLF:
# setup.sh: ASCII text, with CRLF line terminators
```

---

### 5. Git revierte los cambios

**Problema:**
Después de ejecutar el script, Git muestra cambios en todos los `.sh`:

```bash
git status
# Muestra: modified: 2-Standby/scripts/primary/setup.sh (y 46 más)
```

**Causa:** Configuración de Git para auto-conversión de line endings

**Verificar configuración de Git:**
```bash
git config core.autocrlf
```

**Valores posibles:**
- **`true`:** Git convierte LF→CRLF al checkout (Windows), CRLF→LF al commit
- **`input`:** Git convierte CRLF→LF al commit, no modifica al checkout
- **`false`:** Git no modifica line endings

**Solución recomendada para este proyecto:**

**Opción 1: Configurar Git para preservar LF (recomendado)**
```bash
# Para este repositorio específico
git config core.autocrlf input

# Esto hace que Git:
# - Convierte CRLF→LF al hacer commit (si alguien commitea desde Windows)
# - No modifica LF al hacer checkout (preserva LF en archivos .sh)
```

**Opción 2: Usar .gitattributes (más robusto)**

Crear archivo `.gitattributes` en la raíz:
```
# Auto detect text files and normalize line endings to LF on commit
* text=auto

# Force LF for shell scripts
*.sh text eol=lf
*.env text eol=lf

# Force CRLF for Windows scripts
*.ps1 text eol=crlf
*.bat text eol=crlf

# Binary files
*.zip binary
*.vdi binary
```

Esto garantiza que:
- Scripts shell SIEMPRE tienen LF (incluso si se editan en Windows)
- Scripts PowerShell tienen CRLF (correcto para Windows)
- No importa la configuración individual de cada desarrollador

**Aplicar cambios:**
```bash
# Después de crear .gitattributes
git add .gitattributes
git add --renormalize .
git commit -m "Configure line endings for cross-platform compatibility"
```

---

## Relación con Data Guard

### Impacto Indirecto pero Crítico

El script `fix-line-endings.ps1` **no configura Data Guard directamente**, pero es **absolutamente crítico** para que Data Guard se despliegue exitosamente.

**Cadena de dependencia:**

```
fix-line-endings.ps1 (convierte CRLF→LF)
          ↓
    Scripts .sh funcionan correctamente en Linux
          ↓
    Provisioners se ejecutan sin errores
          ↓
    Oracle Database se instala
          ↓
    Primary database se crea
          ↓
    Standby database se crea (RMAN DUPLICATE)
          ↓
    Data Guard Broker se configura
          ↓
    Data Guard está activo y replicando
```

**Sin este script:**
```
Scripts .sh tienen CRLF
          ↓
    Bash interpreta $'\r': command not found
          ↓
    TODOS los provisioners fallan
          ↓
    Oracle NO se instala
          ↓
    Data Guard NO se despliega
          ↓
    FALLO COMPLETO
```

### Scripts Críticos Convertidos

El script convierte line endings de scripts que:

**1. Configuran el entorno para Data Guard:**
```
2-Standby/scripts/primary/oracle_create_database.sh
  └─> Habilita force logging
  └─> Habilita archive log mode
  └─> Crea standby redo logs
  └─> Configura LOG_ARCHIVE_DEST_2
```

**2. Crean el standby database:**
```
2-Standby/scripts/standby/oracle_create_database.sh
  └─> RMAN DUPLICATE FOR STANDBY
  └─> Configura Data Guard Broker
  └─> Establece MAXAVAILABILITY
  └─> Establece FASTSYNC
```

**3. Automatizan Data Guard:**
```
2-Standby/automation/check_log_transport.sh    (monitoreo)
2-Standby/automation/rman_daily_backup.sh      (backups)
2-Standby/automation/verify_dataguard.sh       (verificación)
```

**Si estos scripts tienen CRLF, ninguno funciona.**

---

## Referencias Cruzadas

### Documentación Relacionada

**Scripts que lo llaman:**
- [10 - deploy-powershell.md](10-deploy-powershell.md) - Script principal de despliegue

**Provisioners que dependen de este script:**
- [30 - primary-setup.md](primary/30-primary-setup.md) - Entry point primary
- [50 - standby-setup.md](standby/50-standby-setup.md) - Entry point standby
- Todos los scripts en `2-Standby/scripts/` (12+11+12 archivos)
- Todos los scripts en `2-Standby/automation/` (8 archivos)

**Conceptos relacionados:**
- [02 - Conceptos Fundamentales](../02-conceptos-fundamentales.md) - Line endings mencionados
- [94 - Troubleshooting](../operaciones/94-troubleshooting.md) - Error `$'\r': command not found`

**Guías de uso:**
- [04 - Cómo Usar](../04-como-usar.md) - Explica cuándo ejecutar este script

---

## Siguiente Paso

Después de ejecutar `fix-line-endings.ps1`:

### En el Contexto de deploy.ps1 (Automático)

**El script continúa automáticamente con:**
- Fase 3: Limpieza de VMs antiguas
- Fase 4: Despliegue de primary
- Fase 5: Despliegue de standby

**Ver:** [10 - deploy-powershell.md](10-deploy-powershell.md) para el flujo completo.

### En Ejecución Manual

**Siguiente acción:**
1. Verificar que se procesaron archivos:
   ```
   Conversion complete! Total files processed: 47
   ```

2. Ejecutar el despliegue:
   ```powershell
   .\powershell\deploy.ps1
   ```

   O si prefieres despliegue granular:
   ```bash
   vagrant up primary
   vagrant up standby
   ```

### Verificación de Conversión Exitosa

**Dentro de las VMs (después de deployment):**
```bash
vagrant ssh primary

# Verificar que los scripts tienen LF
file /vagrant/2-Standby/scripts/primary/setup.sh

# Salida esperada:
# setup.sh: ASCII text

# Si tuviera CRLF, diría:
# setup.sh: ASCII text, with CRLF line terminators
```

**Ejecutar script de prueba:**
```bash
cd /vagrant/2-Standby/scripts/primary
bash -n setup.sh  # Verificar sintaxis sin ejecutar

# Si no hay errores, no retorna nada (éxito)
# Si hay CRLF, retorna: $'\r': command not found
```

---

**Has completado la documentación del script de corrección de line endings!**

Este es un script **pequeño pero crítico**:
- Solo 30 líneas de código
- Procesamiento rápido (1-2 segundos)
- Pero **imprescindible** para el éxito del despliegue

**Recordatorio clave:**
- Windows usa `\r\n` (CRLF)
- Linux usa `\n` (LF)
- Bash no tolera `\r` en scripts
- Este script garantiza compatibilidad

Para entender los siguientes pasos del despliegue, continúa con:
- [20 - Vagrantfile.md](20-vagrantfile.md) - Configuración de las VMs
- [21 - vagrant-configuracion.md](21-vagrant-configuracion.md) - Variables de configuración
