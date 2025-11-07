# 21 - Configuración de Vagrant

## Variables de Configuración del Sistema (vagrant.yml e install.env)

Este documento explica los dos archivos de configuración centrales que controlan **todos los parámetros** del sistema Oracle Data Guard: `vagrant.yml` (especificaciones de VMs) e `install.env` (variables de entorno para scripts shell).

---

## 📋 Tabla de Contenidos

1. [Ubicación de Archivos](#ubicación-de-archivos)
2. [Propósito](#propósito)
3. [Archivo vagrant.yml](#archivo-vagrantyml)
4. [Archivo install.env](#archivo-installenv)
5. [Cómo Modificar la Configuración](#cómo-modificar-la-configuración)
6. [Variables Críticas para Data Guard](#variables-críticas-para-data-guard)
7. [Ejemplos de Personalización](#ejemplos-de-personalización)
8. [Relación con Data Guard](#relación-con-data-guard)
9. [Referencias Cruzadas](#referencias-cruzadas)
10. [Siguiente Paso](#siguiente-paso)

---

## Ubicación de Archivos

### config/vagrant.yml

```
config/vagrant.yml
```

**Ruta completa:** `C:\Users\StarAlchemist\DataGripProjects\AdminBDProyecto\config\vagrant.yml`

**Propósito:** Especificaciones de las máquinas virtuales (RAM, CPU, discos, red)

**Leído por:** Vagrantfile (Ruby)

---

### config/install.env

```
config/install.env
```

**Ruta completa:** `C:\Users\StarAlchemist\DataGripProjects\AdminBDProyecto\config\install.env`

**Propósito:** Variables de entorno para scripts shell (passwords, paths, configuración Oracle)

**Leído por:** Scripts shell mediante `source /vagrant_config/install.env`

---

## Propósito

### Separación de Configuración

**Principio:** Separar **configuración** (datos) de **lógica** (código)

**Beneficios:**
1. **Facilidad de modificación:** Cambiar RAM sin tocar Vagrantfile
2. **Claridad:** Todos los parámetros en un solo lugar
3. **Seguridad:** Passwords en archivo separado (puede excluirse de Git)
4. **Reutilización:** Misma lógica con diferentes configuraciones

### División de Responsabilidades

**vagrant.yml:**
- Usado por Vagrant (Windows/Ruby)
- Infraestructura: VMs, red, almacenamiento
- Formato: YAML (fácil de leer/editar)

**install.env:**
- Usado por scripts shell (Linux/Bash)
- Aplicación: Oracle, Data Guard, automatización
- Formato: Bash variables (`export VAR=value`)

---

## Archivo vagrant.yml

### Contenido Completo

```yaml
shared:
  box: oraclelinux/8
  box_url: https://oracle.github.io/vagrant-projects/boxes/oraclelinux/8.json
  non_rotational: 'on'

node1:
  vm_name: ol8_21_dg1_primary
  mem_size: 4096
  cpus: 2
  public_ip: 192.168.56.101
  u01_disk: ./ol8_21_dg1_u01.vdi
  u02_disk: ./ol8_21_dg1_u02.vdi
  disk_size: 102400  # 100GB

node2:
  vm_name: ol8_21_dg2_standby
  mem_size: 4096
  cpus: 2
  public_ip: 192.168.56.102
  u01_disk: ./ol8_21_dg2_u01.vdi
  u02_disk: ./ol8_21_dg2_u02.vdi
  disk_size: 102400  # 100GB
```

### Sección: shared

**Variables compartidas por ambas VMs:**

#### box

```yaml
box: oraclelinux/8
```

**Tipo:** String
**Valor:** `oraclelinux/8`
**Descripción:** Nombre del Vagrant box (imagen base de VM)

**Qué es:** Imagen de Oracle Linux 8 minimal (~500 MB) mantenida por Oracle

**Dónde se usa:** Vagrantfile línea 14
```ruby
config.vm.box = params['shared']['box']
```

**Cómo modificar:**
Podrías usar otro box, por ejemplo:
```yaml
box: generic/rhel8  # Red Hat Enterprise Linux 8
box: centos/8       # CentOS 8
```

**Advertencia:** Solo usa Oracle Linux o RHEL para Oracle Database. CentOS/Fedora/Ubuntu no están certificados.

---

#### box_url

```yaml
box_url: https://oracle.github.io/vagrant-projects/boxes/oraclelinux/8.json
```

**Tipo:** URL
**Descripción:** Catálogo de versiones del box

**Dónde se usa:** Vagrantfile línea 15
```ruby
config.vm.box_url = params['shared']['box_url']
```

**Función:** Vagrant descarga el box desde esta URL la primera vez que ejecutas `vagrant up`

**No necesitas modificar** a menos que uses un box personalizado.

---

#### non_rotational

```yaml
non_rotational: 'on'
```

**Tipo:** String (`'on'` o `'off'`)
**Valor:** `'on'`
**Descripción:** Marcar discos virtuales como SSD

**Dónde se usa:** Vagrantfile (múltiples líneas)
```ruby
vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
              '--port', '0', '--nonrotational', params['shared']['non_rotational']]
```

**Beneficio:**
- Oracle optimiza I/O diferente para SSD vs HDD
- Mejor rendimiento de database
- Funciona incluso si el disco host real es HDD

**Valores posibles:**
- `'on'` - Marcar como SSD (recomendado)
- `'off'` - Marcar como HDD rotacional

---

### Sección: node1 (Primary VM)

**Configuración específica de la VM primary:**

#### vm_name

```yaml
vm_name: ol8_21_dg1_primary
```

**Tipo:** String
**Descripción:** Nombre de la VM en VirtualBox

**Resultado:** La VM aparece como `ol8_21_dg1_primary` en VirtualBox Manager

**Convención de nombres:**
- `ol8` - Oracle Linux 8
- `21` - Oracle Database 21c
- `dg1` - Data Guard nodo 1
- `primary` - Rol

**Puedes cambiar** si prefieres otro nombre:
```yaml
vm_name: healthcare_primary_db
```

---

#### mem_size

```yaml
mem_size: 4096
```

**Tipo:** Integer
**Unidad:** MB
**Valor:** 4096 MB = 4 GB

**Descripción:** Cantidad de RAM asignada a la VM

**Requisitos mínimos de Oracle:**
- Oracle Database 21c: Mínimo 2 GB
- Con Data Guard: Recomendado 4 GB
- Producción: 8-16 GB+

**Cómo modificar:**

**Si tienes 16+ GB RAM en host:**
```yaml
mem_size: 6144  # 6 GB por VM
```

**Si tienes solo 8 GB RAM en host:**
```yaml
mem_size: 3072  # 3 GB por VM (mínimo aceptable)
```

**Advertencia:** No bajes de 2048 MB (2 GB).

---

#### cpus

```yaml
cpus: 2
```

**Tipo:** Integer
**Valor:** 2 cores virtuales

**Descripción:** Cantidad de CPUs asignadas a la VM

**Requisitos de Oracle:**
- Mínimo: 1 CPU (extremadamente lento)
- Recomendado: 2-4 CPUs
- Producción: 8-16+ CPUs

**Cómo modificar:**

**Si tienes CPU potente (8+ cores):**
```yaml
cpus: 4  # Deployment más rápido
```

**Si tienes CPU débil (4 cores):**
```yaml
cpus: 1  # Libera recursos, pero deployment más lento
```

**Nota:** No asignes más CPUs virtuales que cores físicos en tu host.

---

#### public_ip

```yaml
public_ip: 192.168.56.101
```

**Tipo:** IP Address
**Valor:** `192.168.56.101`

**Descripción:** IP de la VM en la red host-only

**Convención de IPs:**
- Red: `192.168.56.0/24`
- Gateway (host): `192.168.56.1` (automático)
- Primary: `192.168.56.101`
- Standby: `192.168.56.102`

**Puedes cambiar** si tienes conflictos de red:
```yaml
public_ip: 192.168.100.10  # Otra subred
```

**Si cambias, también modifica:**
- `node2.public_ip` (debe estar en la misma subred)
- `config/install.env` (NODE1_PUBLIC_IP, NODE2_PUBLIC_IP)

---

#### u01_disk

```yaml
u01_disk: ./ol8_21_dg1_u01.vdi
```

**Tipo:** File path
**Descripción:** Ruta del archivo de disco virtual para /u01

**Convención:**
- `./` - Directorio actual (raíz del proyecto)
- `ol8_21_dg1` - Identificador del nodo
- `u01` - Mount point
- `.vdi` - VirtualBox Disk Image

**Contenido de /u01:**
- Oracle Database software (21c)
- Bases de datos (datafiles, control files, redo logs)
- Oracle Inventory
- Admin files

**Tamaño:** Definido por `disk_size`

---

#### u02_disk

```yaml
u02_disk: ./ol8_21_dg1_u02.vdi
```

**Tipo:** File path
**Descripción:** Ruta del archivo de disco virtual para /u02

**Contenido de /u02:**
- Backups RMAN
- Fast Recovery Area (FRA)
- Archive logs (antiguos)
- Flashback logs

**Tamaño:** Definido por `disk_size`

---

#### disk_size

```yaml
disk_size: 102400  # 100GB
```

**Tipo:** Integer
**Unidad:** MB
**Valor:** 102400 MB = 100 GB

**Descripción:** Tamaño de discos u01 y u02

**Uso típico:**
- u01: ~25 GB (Oracle + base de datos)
- u02: ~10 GB (backups iniciales)

**Cómo modificar:**

**Si tienes poco espacio en disco:**
```yaml
disk_size: 51200  # 50 GB (mínimo recomendado)
```

**Si quieres más espacio para backups:**
```yaml
disk_size: 204800  # 200 GB
```

**Advertencia:** No reduzcas a menos de 40 GB por disco (Oracle + DB requieren ~30 GB).

---

### Sección: node2 (Standby VM)

**Configuración idéntica a node1, pero con valores distintos:**

```yaml
node2:
  vm_name: ol8_21_dg2_standby       # Diferente
  mem_size: 4096                    # Igual
  cpus: 2                           # Igual
  public_ip: 192.168.56.102         # Diferente (misma subred)
  u01_disk: ./ol8_21_dg2_u01.vdi    # Diferente (archivo separado)
  u02_disk: ./ol8_21_dg2_u02.vdi    # Diferente (archivo separado)
  disk_size: 102400                 # Igual
```

**Diferencias clave:**
- `vm_name`: Identificador único en VirtualBox
- `public_ip`: IP diferente en la misma red
- `u01_disk` / `u02_disk`: Archivos VDI separados

**Recursos (mem_size, cpus, disk_size):** Generalmente iguales a primary, pero puedes reducir standby si es necesario:

```yaml
node2:
  mem_size: 3072  # 3 GB (vs 4 GB en primary)
  cpus: 1         # 1 CPU (vs 2 en primary)
```

**Impacto:** Standby más lento al aplicar logs, pero funciona.

---

## Archivo install.env

### Estructura y Propósito

**Formato:** Bash shell script con variables de entorno

**Sintaxis:**
```bash
export VARIABLE=value
```

**Uso en scripts:**
```bash
# En cualquier script shell
source /vagrant_config/install.env

# Ahora puedes usar las variables
echo "Primary IP: $NODE1_PUBLIC_IP"
echo "Oracle SID: $ORACLE_SID"
```

### Contenido Completo Comentado

```bash
# Domain Configuration
export DOMAIN_NAME=localdomain

# Hostnames
export NODE1_HOSTNAME=ol8-21-dg1
export NODE2_HOSTNAME=ol8-21-dg2
export NODE1_FQ_HOSTNAME=${NODE1_HOSTNAME}.${DOMAIN_NAME}
export NODE2_FQ_HOSTNAME=${NODE2_HOSTNAME}.${DOMAIN_NAME}

# IP Addresses
export NODE1_PUBLIC_IP=192.168.56.101
export NODE2_PUBLIC_IP=192.168.56.102

# Oracle Paths
export ORACLE_BASE=/u01/app/oracle
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_HOME_EXT=product/21.0.0/dbhome_1

# Database Names
export ORACLE_SID=cdb1
export DB_NAME=${ORACLE_SID}
export PDB_NAME=pdb1
export NODE1_DB_UNIQUE_NAME=${ORACLE_SID}
export NODE2_DB_UNIQUE_NAME=${ORACLE_SID}_stby

# DB Domain (optional)
export DB_DOMAIN=world
if [ "${DB_DOMAIN}" != "" ]; then
  export DB_DOMAIN_STR=".${DB_DOMAIN}"
else
  export DB_DOMAIN_STR=
fi

# Oracle Settings
export ORACLE_TERM=xterm
export ORA_LANGUAGES=en,en_GB

# Network Encryption
export NATIVE_NETWORK_ENCRYPTION=true

# Data Directory
export DATA_DIR=/u01/oradata

# Passwords
export ROOT_PASSWORD=rootpasswd
export ORACLE_PASSWORD=oracle
export SYS_PASSWORD="S1sPassword1!"
export PDB_PASSWORD="PdbPassword1!"

# Application Schema
export APP_SCHEMA=HC
export APP_SCHEMA_PASSWORD="password"
export APP_SCHEMA_SQL="Script_SchemeTableSpace.sql"

# Oracle Software
export SOFTWARE_DIR=/u01/software
export DB_SOFTWARE=LINUX.X64_213000_db_home.zip

# Patching (optional)
export PATCH_DB="false"
export OPATCH_FILE="p6880880_210000_Linux-x86-64.zip"
export PATCH_FILE="p34160444_210000_Linux-x86-64.zip"
export PATCH_TOP=${SOFTWARE_DIR}/34160444

# Data Guard Configuration
export ARCHIVE_LAG_TARGET=300  # 5 minutes
export REDO_LOG_SIZE=50        # 50MB
export PROTECTION_MODE=MAXAVAILABILITY
export TRANSPORT_MODE=FASTSYNC

# Fast Recovery Area
export FRA_SIZE=100G
export FRA_LOCATION=${ORACLE_BASE}/fast_recovery_area

# Backup Configuration
export BACKUP_DIR=/u02/backup
export BACKUP_RETENTION_DAYS=7
export BACKUP_TIME="0 1 * * *"  # 1 AM daily

# Archive Log Management
export ARCHIVE_RETENTION_DAYS=3
export ARCHIVE_CLEANUP_TIME="0 23 * * *"  # 11 PM daily

# Log Transport Monitoring
export LOG_TRANSPORT_CHECK_INTERVAL="*/10 * * * *"  # Every 10 minutes
export LOG_GAP_ALERT_THRESHOLD=10
```

### Variables Críticas (Explicación Detallada)

#### Dominio y Hostnames

```bash
export DOMAIN_NAME=localdomain
export NODE1_HOSTNAME=ol8-21-dg1
export NODE2_HOSTNAME=ol8-21-dg2
export NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain
export NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain
```

**Uso:**
- Configuración de `/etc/hosts`
- TNS names (tnsnames.ora)
- Data Guard Broker

**Ejemplo en /etc/hosts:**
```
192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
192.168.56.102  ol8-21-dg2.localdomain ol8-21-dg2
```

---

#### IPs de Nodos

```bash
export NODE1_PUBLIC_IP=192.168.56.101
export NODE2_PUBLIC_IP=192.168.56.102
```

**Debe coincidir con vagrant.yml**

Si cambias IPs en `vagrant.yml`, también cámbialas aquí.

---

#### Paths de Oracle

```bash
export ORACLE_BASE=/u01/app/oracle
export ORA_INVENTORY=/u01/app/oraInventory
export ORACLE_HOME_EXT=product/21.0.0/dbhome_1
```

**ORACLE_HOME completo:**
```bash
$ORACLE_HOME = $ORACLE_BASE/$ORACLE_HOME_EXT
             = /u01/app/oracle/product/21.0.0/dbhome_1
```

**Convenciones Oracle:**
- `ORACLE_BASE`: Directorio raíz de Oracle
- `ORACLE_HOME`: Instalación específica de Oracle (puede haber múltiples)
- `ORA_INVENTORY`: Registro de instalaciones

---

#### Nombres de Bases de Datos

```bash
export ORACLE_SID=cdb1
export DB_NAME=cdb1
export PDB_NAME=pdb1
export NODE1_DB_UNIQUE_NAME=cdb1
export NODE2_DB_UNIQUE_NAME=cdb1_stby
```

**Explicación:**

**ORACLE_SID:** Identificador de la instancia en el OS
- Primary: `cdb1`
- Standby: `cdb1` (mismo SID)

**DB_NAME:** Nombre de la base de datos
- Primary y standby: `cdb1` (mismo DB_NAME)

**DB_UNIQUE_NAME:** Nombre único para identificar en Data Guard
- Primary: `cdb1`
- Standby: `cdb1_stby` (diferente)

**PDB_NAME:** Nombre de la Pluggable Database
- `pdb1` (dentro del CDB)

---

#### Passwords

```bash
export ROOT_PASSWORD=rootpasswd
export ORACLE_PASSWORD=oracle
export SYS_PASSWORD="S1sPassword1!"
export PDB_PASSWORD="PdbPassword1!"
```

**⚠️ IMPORTANTE:** Cambia estos passwords en producción

**Uso:**
- `ROOT_PASSWORD`: Usuario root de Linux (no usado, VMs tienen vagrant user)
- `ORACLE_PASSWORD`: Usuario oracle de Linux
- `SYS_PASSWORD`: Usuario SYS de Oracle Database
- `PDB_PASSWORD`: Usuario SYS del PDB

**Requisitos de password Oracle:**
- Mínimo 8 caracteres
- Debe contener número
- Debe contener carácter especial
- NO puede ser el username

**Ejemplo de passwords seguros:**
```bash
export SYS_PASSWORD="MySecur3P@ssw0rd"
export PDB_PASSWORD="PDB_2025!Secure"
```

---

#### Schema de Aplicación

```bash
export APP_SCHEMA=HC
export APP_SCHEMA_PASSWORD="password"
export APP_SCHEMA_SQL="Script_SchemeTableSpace.sql"
```

**⚠️ Advertencia:** Password muy débil, cámbialo

**Uso:**
- `APP_SCHEMA`: Nombre del schema (HC = HealthCare)
- `APP_SCHEMA_PASSWORD`: Password del usuario HEALTHCENTER
- `APP_SCHEMA_SQL`: Script que crea tablespace

**El schema real es HEALTHCENTER**, no HC (HC es solo prefijo de las tablas).

---

#### Software de Oracle

```bash
export SOFTWARE_DIR=/u01/software
export DB_SOFTWARE=LINUX.X64_213000_db_home.zip
```

**Path completo:** `/u01/software/LINUX.X64_213000_db_home.zip`

**Este archivo viene de:** `/vagrant_software/LINUX.X64_213000_db_home.zip` (copiado durante provisioning)

**NO modifiques** a menos que uses otra versión de Oracle:
```bash
export DB_SOFTWARE=LINUX.X64_193000_db_home.zip  # Oracle 19c
```

---

#### Configuración de Data Guard

```bash
export ARCHIVE_LAG_TARGET=300  # 5 minutes
export REDO_LOG_SIZE=50        # 50MB
export PROTECTION_MODE=MAXAVAILABILITY
export TRANSPORT_MODE=FASTSYNC
```

**ARCHIVE_LAG_TARGET:**
- Unidad: Segundos
- Valor: 300 = 5 minutos
- Significado: Forzar log switch cada 5 minutos mínimo
- Beneficio: Standby nunca está más de 5 minutos desactualizado

**REDO_LOG_SIZE:**
- Unidad: MB
- Valor: 50 MB
- Significado: Tamaño de cada redo log file
- Consideraciones:
  - Más grande: Menos switches, menos overhead
  - Más pequeño: Más switches, mejor granularidad de recovery

**PROTECTION_MODE:**
- Valor: `MAXAVAILABILITY`
- Opciones:
  - `MAXPROTECTION` - Cero pérdida de datos garantizada (primary se detiene si standby falla)
  - `MAXAVAILABILITY` - Cero pérdida de datos si standby disponible (primary continúa si standby falla)
  - `MAXPERFORMANCE` - Async, posible pérdida de datos

**TRANSPORT_MODE:**
- Valor: `FASTSYNC`
- Opciones:
  - `SYNC` - Síncrono, espera confirmación de escritura en disco en standby
  - `FASTSYNC` - Síncrono, espera confirmación de recepción en memoria en standby (más rápido)
  - `ASYNC` - Asíncrono, no espera

---

#### Fast Recovery Area

```bash
export FRA_SIZE=100G
export FRA_LOCATION=/u01/app/oracle/fast_recovery_area
```

**FRA (Fast Recovery Area):**
- Ubicación centralizada para:
  - Archive logs
  - Backups RMAN
  - Flashback logs
  - Standby redo logs

**Tamaño:** 100 GB (generoso para dev/test)

**Producción:** 200-500 GB o más

---

#### Configuración de Backups

```bash
export BACKUP_DIR=/u02/backup
export BACKUP_RETENTION_DAYS=7
export BACKUP_TIME="0 1 * * *"  # 1 AM daily
```

**BACKUP_DIR:** Dónde se guardan backups RMAN

**BACKUP_RETENTION_DAYS:** Cuántos días mantener backups (7 días = 1 semana)

**BACKUP_TIME:** Formato cron
- `0 1 * * *` = A la 1:00 AM todos los días
- Formato: `minuto hora día_mes mes día_semana`

**Ejemplos:**
```bash
export BACKUP_TIME="0 2 * * *"    # 2 AM
export BACKUP_TIME="0 0 * * 0"    # Medianoche domingos
export BACKUP_TIME="0 */6 * * *"  # Cada 6 horas
```

---

#### Configuración de Archive Logs

```bash
export ARCHIVE_RETENTION_DAYS=3
export ARCHIVE_CLEANUP_TIME="0 23 * * *"  # 11 PM daily
```

**ARCHIVE_RETENTION_DAYS:** Cuántos días mantener archive logs

**Por qué 3 días:**
- Backups diarios retienen 7 días
- Archive logs solo necesitan 3 días (suficiente para recovery)
- Ahorra espacio en disco

**ARCHIVE_CLEANUP_TIME:** Cuándo limpiar archives
- `0 23 * * *` = 11 PM diario
- Primary: 2 AM (después de backup)
- Standby: 11 PM (después de aplicar)

---

#### Monitoreo de Log Transport

```bash
export LOG_TRANSPORT_CHECK_INTERVAL="*/10 * * * *"  # Every 10 minutes
export LOG_GAP_ALERT_THRESHOLD=10
```

**LOG_TRANSPORT_CHECK_INTERVAL:** Frecuencia de verificación de replicación
- `*/10 * * * *` = Cada 10 minutos
- Script: `check_log_transport.sh`

**LOG_GAP_ALERT_THRESHOLD:** Umbral para alerta
- Valor: 10 sequences
- Si gap > 10, genera alerta en logs

---

## Cómo Modificar la Configuración

### Proceso General

1. **Editar archivos de configuración:**
   - `config/vagrant.yml` (infraestructura)
   - `config/install.env` (aplicación)

2. **Destruir VMs existentes:**
   ```powershell
   .\powershell\destroy.ps1
   ```

3. **Re-deployar con nueva configuración:**
   ```powershell
   .\powershell\deploy.ps1
   ```

### Modificaciones Comunes

#### Cambiar RAM/CPU

**Archivo:** `config/vagrant.yml`

```yaml
node1:
  mem_size: 6144  # Cambiar de 4096 a 6144 (6 GB)
  cpus: 4         # Cambiar de 2 a 4 CPUs

node2:
  mem_size: 6144
  cpus: 4
```

**Cuándo:** Tienes más recursos y quieres deployment más rápido

---

#### Cambiar Passwords

**Archivo:** `config/install.env`

```bash
export SYS_PASSWORD="MyNewSecureP@ss1"
export PDB_PASSWORD="PDB_NewP@ss2"
export APP_SCHEMA_PASSWORD="HC_Secure123!"
```

**IMPORTANTE:** Usa comillas dobles para passwords con caracteres especiales

---

#### Cambiar IPs

**Archivo 1:** `config/vagrant.yml`

```yaml
node1:
  public_ip: 192.168.100.10  # Nueva subred

node2:
  public_ip: 192.168.100.20
```

**Archivo 2:** `config/install.env`

```bash
export NODE1_PUBLIC_IP=192.168.100.10
export NODE2_PUBLIC_IP=192.168.100.20
```

**Ambos archivos deben coincidir.**

---

#### Cambiar Tamaño de Discos

**Archivo:** `config/vagrant.yml`

```yaml
node1:
  disk_size: 204800  # 200 GB (más espacio para datos/backups)

node2:
  disk_size: 204800
```

**Nota:** Solo aplica a discos nuevos. No puede redimensionar discos existentes.

---

## Variables Críticas para Data Guard

### Tabla de Variables Data Guard

| Variable               | Valor por Defecto    | Impacto en Data Guard                        |
|------------------------|----------------------|----------------------------------------------|
| `PROTECTION_MODE`      | MAXAVAILABILITY      | Nivel de protección contra pérdida de datos |
| `TRANSPORT_MODE`       | FASTSYNC             | Sincronía de replicación                     |
| `ARCHIVE_LAG_TARGET`   | 300 (5 min)          | Frecuencia mínima de log switches            |
| `REDO_LOG_SIZE`        | 50 MB                | Tamaño de redo logs                          |
| `FRA_SIZE`             | 100G                 | Espacio para flashback/archives              |
| `LOG_GAP_ALERT_THRESHOLD` | 10                | Umbral de alerta por lag                     |

### Combinaciones Recomendadas

**Producción (cero pérdida de datos):**
```bash
export PROTECTION_MODE=MAXAVAILABILITY
export TRANSPORT_MODE=FASTSYNC
export ARCHIVE_LAG_TARGET=180  # 3 minutos
export BACKUP_RETENTION_DAYS=30
```

**Desarrollo (balance):**
```bash
export PROTECTION_MODE=MAXAVAILABILITY
export TRANSPORT_MODE=FASTSYNC
export ARCHIVE_LAG_TARGET=300
export BACKUP_RETENTION_DAYS=7
```

**Testing (rendimiento prioritario):**
```bash
export PROTECTION_MODE=MAXPERFORMANCE
export TRANSPORT_MODE=ASYNC
export ARCHIVE_LAG_TARGET=600  # 10 minutos
export BACKUP_RETENTION_DAYS=3
```

---

## Ejemplos de Personalización

### Ejemplo 1: Ambiente de Desarrollo Ligero

**Objetivo:** Reducir uso de recursos para laptop con 8 GB RAM

**config/vagrant.yml:**
```yaml
node1:
  mem_size: 3072  # 3 GB
  cpus: 1
  disk_size: 51200  # 50 GB

node2:
  mem_size: 2048  # 2 GB (mínimo para standby)
  cpus: 1
  disk_size: 51200
```

**config/install.env:**
```bash
export ARCHIVE_LAG_TARGET=600  # 10 minutos (menos switches)
export BACKUP_RETENTION_DAYS=3
export ARCHIVE_RETENTION_DAYS=2
```

**Impacto:**
- Despliegue más lento (menos CPU/RAM)
- Usa ~5 GB RAM total (vs 8 GB)
- Usa ~100 GB disco (vs 200+ GB)

---

### Ejemplo 2: Ambiente de Producción

**Objetivo:** Alta disponibilidad con backups robustos

**config/vagrant.yml:**
```yaml
node1:
  mem_size: 8192  # 8 GB
  cpus: 4
  disk_size: 204800  # 200 GB

node2:
  mem_size: 8192
  cpus: 4
  disk_size: 204800
```

**config/install.env:**
```bash
export PROTECTION_MODE=MAXAVAILABILITY
export TRANSPORT_MODE=FASTSYNC
export ARCHIVE_LAG_TARGET=180  # 3 minutos
export REDO_LOG_SIZE=100       # 100 MB
export FRA_SIZE=200G
export BACKUP_RETENTION_DAYS=30
export ARCHIVE_RETENTION_DAYS=7
```

**Impacto:**
- Despliegue rápido
- Lag mínimo (<3 min)
- Backups 30 días
- Requiere host potente (16+ GB RAM, 500+ GB disco)

---

## Relación con Data Guard

### Flujo de Configuración Data Guard

```
install.env (config/install.env)
     │
     ├─> PROTECTION_MODE=MAXAVAILABILITY
     ├─> TRANSPORT_MODE=FASTSYNC
     ├─> ARCHIVE_LAG_TARGET=300
     └─> REDO_LOG_SIZE=50
           │
           ▼
Scripts de provisioning leen install.env
           │
           ▼
oracle_create_database.sh configura primary:
  - ALTER SYSTEM SET log_archive_dest_2='SERVICE=cdb1_stby SYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=cdb1_stby';
  - ALTER SYSTEM SET archive_lag_target=300;
           │
           ▼
RMAN DUPLICATE crea standby desde primary
           │
           ▼
Data Guard Broker configura protection:
  DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
  DGMGRL> EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
           │
           ▼
Data Guard activo con configuración de install.env
```

---

## Referencias Cruzadas

**Documentación relacionada:**
- [10 - deploy-powershell.md](10-deploy-powershell.md) - Script que usa estas configuraciones
- [20 - Vagrantfile.md](20-vagrantfile.md) - Cómo se usan las variables de vagrant.yml
- [30 - primary-setup.md](primary/30-primary-setup.md) - Scripts que leen install.env
- [82 - Modos de Protección](../conceptos-avanzados/82-modos-proteccion.md) - MAXAVAILABILITY vs MAXPERFORMANCE

---

## Siguiente Paso

Después de entender la configuración:

**Para entender provisioning de primary:**
- [30 - primary-setup.md](primary/30-primary-setup.md)

**Para entender provisioning de standby:**
- [50 - standby-setup.md](standby/50-standby-setup.md)

**Para modificar y re-deployar:**
1. Editar `config/vagrant.yml` y/o `config/install.env`
2. Ejecutar `.\powershell\destroy.ps1`
3. Ejecutar `.\powershell\deploy.ps1`

---

**Has completado la documentación de configuración!**

Estos dos archivos controlan **TODO** el comportamiento del sistema:
- **vagrant.yml:** Infraestructura (VMs)
- **install.env:** Aplicación (Oracle/Data Guard)

Con esta documentación puedes personalizar completamente el despliegue según tus necesidades.
