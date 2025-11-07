# 20 - Vagrantfile: Orquestación de Máquinas Virtuales

## Configuración Central de la Infraestructura del Proyecto

El `Vagrantfile` es el **archivo de configuración central** que define cómo se crean, configuran y provisionan las dos máquinas virtuales (primary y standby) del sistema Oracle Data Guard. Vagrant lee este archivo para orquestar todo el proceso de creación de infraestructura.

---

## 📋 Tabla de Contenidos

1. [Ubicación](#ubicación)
2. [Propósito](#propósito)
3. [Cuándo se Ejecuta](#cuándo-se-ejecuta)
4. [Estructura del Archivo](#estructura-del-archivo)
5. [Configuración Compartida](#configuración-compartida)
6. [Configuración de Primary VM](#configuración-de-primary-vm)
7. [Configuración de Standby VM](#configuración-de-standby-vm)
8. [Synced Folders (Carpetas Compartidas)](#synced-folders-carpetas-compartidas)
9. [Provisioners (Scripts de Instalación)](#provisioners-scripts-de-instalación)
10. [Network Configuration](#network-configuration)
11. [Storage Configuration](#storage-configuration)
12. [Dependencias](#dependencias)
13. [Relación con Data Guard](#relación-con-data-guard)
14. [Referencias Cruzadas](#referencias-cruzadas)
15. [Siguiente Paso](#siguiente-paso)

---

## Ubicación

```
Vagrantfile
```

**Ruta completa:** `C:\Users\StarAlchemist\DataGripProjects\AdminBDProyecto\Vagrantfile`

**Ubicación en el proyecto:** Raíz del proyecto

---

## Propósito

El `Vagrantfile` define la **infraestructura como código** (Infrastructure as Code) para el proyecto. Sus responsabilidades son:

### 1. Definición de Máquinas Virtuales

- **Primary VM:** `ol8_21_dg1_primary`
  - Hostname: `ol8-21-dg1.localdomain`
  - IP: `192.168.56.101`
  - Rol: Base de datos primary

- **Standby VM:** `ol8_21_dg2_standby`
  - Hostname: `ol8-21-dg2.localdomain`
  - IP: `192.168.56.102`
  - Rol: Base de datos standby (réplica)

### 2. Configuración de Recursos

- **Memoria RAM:** 4 GB por VM (8 GB total)
- **CPU:** 2 cores por VM (4 cores total)
- **Discos adicionales:**
  - `/u01` - 100 GB (Oracle software + databases)
  - `/u02` - 100 GB (Backups + Fast Recovery Area)

### 3. Configuración de Red

- **Red privada host-only:** Para comunicación entre VMs y con host
- **Port forwarding:** Para acceder a servicios desde Windows
- **Hostnames resolvibles:** Configuración de `/etc/hosts`

### 4. Orquestación de Provisioning

- **Synced folders:** Montar directorios de Windows en Linux
- **Provisioners:** Ejecutar scripts shell para instalación y configuración
- **Orden de ejecución:** Definir secuencia de provisioning

### 5. Idempotencia

- Permite ejecutar `vagrant up` múltiples veces
- Permite destruir y recrear VMs fácilmente
- Configuración reproducible en cualquier máquina Windows

---

## Cuándo se Ejecuta

### Contexto en el Flujo de Despliegue

**Fase:** Leído en Fase 4 y Fase 5 de `deploy.ps1`
**Llamado por:** Comando `vagrant up`
**Orden en secuencia:** Configuración leída antes de crear/iniciar VMs

### Comandos que Usan el Vagrantfile

```bash
# Crear y provisionar primary
vagrant up primary

# Crear y provisionar standby
vagrant up standby

# Crear y provisionar ambas VMs
vagrant up

# Destruir VMs
vagrant destroy -f

# Reiniciar VMs
vagrant reload

# Ver estado
vagrant status

# SSH a las VMs
vagrant ssh primary
vagrant ssh standby
```

### Modificación del Vagrantfile

**Cuándo editar:**
- Cambiar recursos (RAM, CPU, disco)
- Agregar nuevos synced folders
- Agregar nuevos provisioners
- Cambiar configuración de red
- Agregar nueva VM al proyecto

**Después de editar:**
```bash
# Si las VMs ya existen, destruir y recrear
vagrant destroy -f
vagrant up

# O si solo cambiaste provisioners
vagrant reload --provision
```

---

## Estructura del Archivo

### Anatomía del Vagrantfile

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'

# Comentarios del proyecto
# Oracle 21c Data Guard Environment
# Primary: ol8-21-dg1 (192.168.56.101)
# Standby: ol8-21-dg2 (192.168.56.102)

# Cargar configuración externa
params = YAML.load_file 'config/vagrant.yml'

Vagrant.configure("2") do |config|
  # Configuración compartida
  config.vm.box = params['shared']['box']
  # ...

  # Synced folders
  config.vm.synced_folder ".", "/vagrant"
  # ...

  # Definición de Primary VM
  config.vm.define "primary", primary: true do |primary|
    # Configuración de primary
  end

  # Definición de Standby VM
  config.vm.define "standby", autostart: false do |standby|
    # Configuración de standby
  end
end
```

### Lenguaje: Ruby DSL

**DSL:** Domain-Specific Language

El Vagrantfile está escrito en **Ruby**, pero no necesitas saber Ruby para entenderlo. Vagrant proporciona un DSL simple:

**Sintaxis básica:**
```ruby
config.vm.setting = value          # Asignar valor
config.vm.network "tipo", opciones # Configurar red
config.vm.provision "tipo", path   # Agregar provisioner
```

**Bloques:**
```ruby
config.vm.define "nombre" do |variable|
  variable.vm.hostname = "..."
  variable.vm.network "...", ...
end
```

---

## Configuración Compartida

### Carga de Configuración Externa

```ruby
require 'yaml'
params = YAML.load_file 'config/vagrant.yml'
```

**Explicación:**
- `require 'yaml'`: Importa la biblioteca YAML de Ruby
- `YAML.load_file`: Lee y parsea `config/vagrant.yml`
- `params`: Variable que contiene toda la configuración

**Contenido de `vagrant.yml`:** Ver [21 - vagrant-configuracion.md](21-vagrant-configuracion.md)

**Ventajas de separar configuración:**
- Configuración en formato legible (YAML)
- Fácil modificar valores sin tocar lógica de Vagrant
- Reutilizable en múltiples Vagrantfiles

### Box Base

```ruby
config.vm.box = params['shared']['box']
config.vm.box_url = params['shared']['box_url']
config.vm.box_check_update = false
```

**Explicación:**

**`config.vm.box`:** Imagen base de la VM
- Valor: `"oraclelinux/8"` (desde `vagrant.yml`)
- Es una plantilla de Oracle Linux 8 pre-configurada

**`config.vm.box_url`:** URL del catálogo de boxes
- Valor: `"https://oracle.github.io/vagrant-projects/boxes/oraclelinux/8.json"`
- Vagrant descarga el box desde aquí si no existe localmente

**`config.vm.box_check_update`:** Deshabilitar búsqueda de actualizaciones
- Valor: `false`
- Evita que Vagrant busque versiones nuevas del box (ahorra tiempo)

**Box es como una plantilla VMware/VirtualBox:**
- Contiene disco virtual con OS pre-instalado
- Oracle Linux 8 minimal
- ~500 MB comprimido
- Se descarga una sola vez y se reutiliza

**Ubicación del box descargado:**
```
C:\Users\Usuario\.vagrant.d\boxes\oraclelinux-VAGRANTSLASH-8\
```

---

## Synced Folders (Carpetas Compartidas)

### ¿Qué son Synced Folders?

Los synced folders permiten **compartir directorios** entre el host Windows y las VMs Linux. Los archivos en Windows se ven automáticamente en Linux y viceversa.

**Tecnología:** VirtualBox Guest Additions (vboxsf driver)

### Configuración de Synced Folders

```ruby
config.vm.synced_folder ".", "/vagrant"
config.vm.synced_folder "config", "/vagrant_config"
config.vm.synced_folder "2-Standby/infrastructure", "/vagrant_scripts"
config.vm.synced_folder "software", "/vagrant_software"
config.vm.synced_folder "2-Standby/automation", "/vagrant_automation"
config.vm.synced_folder "1-BD/SQL-VM scripts", "/vagrant_sql_scripts"
config.vm.synced_folder "1-BD/directories", "/vagrant_directories"
```

**Sintaxis:**
```ruby
config.vm.synced_folder "ruta_en_windows", "ruta_en_linux"
```

**Tabla de Synced Folders:**

| Windows (Host)                  | Linux (VM)            | Propósito                                    |
|---------------------------------|-----------------------|----------------------------------------------|
| `.` (raíz proyecto)             | `/vagrant`            | Acceso a todo el proyecto                    |
| `config/`                       | `/vagrant_config`     | Archivos de configuración (install.env, etc.)|
| `2-Standby/infrastructure/`     | `/vagrant_scripts`    | Scripts shell compartidos                    |
| `software/`                     | `/vagrant_software`   | Oracle Database ZIP                          |
| `2-Standby/automation/`         | `/vagrant_automation` | Scripts de automatización                    |
| `1-BD/SQL-VM scripts/`          | `/vagrant_sql_scripts`| Scripts SQL adicionales                      |
| `1-BD/directories/`             | `/vagrant_directories`| Directorios Oracle (UTL_FILE, etc.)         |

### Importancia de Synced Folders

**Sin synced folders:**
```bash
# Tendrías que copiar archivos manualmente
scp LINUX.X64_213000_db_home.zip vagrant@192.168.56.101:/tmp/
```

**Con synced folders:**
```bash
# Los archivos están automáticamente disponibles
vagrant ssh primary
ls /vagrant_software/LINUX.X64_213000_db_home.zip  # ✓ Existe
```

**Beneficios:**
1. **Instalación de Oracle:** El script copia desde `/vagrant_software/`
2. **Provisioners:** Ejecutan scripts desde `/vagrant/2-Standby/scripts/`
3. **Logs compartidos:** Logs en `/vagrant/ssh_keys/` se ven en Windows
4. **Desarrollo iterativo:** Edita en Windows, ejecuta en Linux inmediatamente

### Ejemplo de Uso

**Desde Windows:**
```powershell
# Editar script
notepad 2-Standby\scripts\primary\setup.sh
```

**Desde la VM (instantáneamente disponible):**
```bash
vagrant ssh primary
cat /vagrant/2-Standby/scripts/primary/setup.sh  # ✓ Contiene cambios
```

### Problemas Comunes con Synced Folders

**1. "mount: unknown filesystem type 'vboxsf'"**

**Causa:** VirtualBox Guest Additions no instaladas o desactualizadas

**Solución:**
```bash
vagrant plugin install vagrant-vbguest
vagrant reload
```

**2. Synced folder no se ve en la VM**

**Diagnóstico:**
```bash
vagrant ssh primary
ls -la /vagrant_config  # ¿Existe el directorio?
mount | grep vboxsf     # ¿Está montado?
```

**Solución:**
```bash
vagrant reload  # Reinicia y remonta folders
```

---

## Configuración de Primary VM

### Definición de Primary

```ruby
config.vm.define "primary", primary: true do |primary|
  # Configuración específica de primary
end
```

**Parámetros:**
- **`"primary"`:** Nombre de la VM
- **`primary: true`:** Esta es la VM por defecto (se inicia primero con `vagrant up`)
- **`|primary|`:** Variable de bloque para configurar esta VM

### Hostname

```ruby
primary.vm.hostname = "ol8-21-dg1.localdomain"
```

**Efecto:** Ejecuta `hostnamectl set-hostname ol8-21-dg1.localdomain` en la VM

**Importancia para Data Guard:**
- Oracle usa hostnames para identificar servidores
- TNS (Transparent Network Substrate) usa hostnames en `tnsnames.ora`
- Data Guard Broker usa hostnames en configuración

### Red Privada

```ruby
primary.vm.network "private_network", ip: params['node1']['public_ip']
```

**Parámetros:**
- **`"private_network"`:** Red host-only (solo host y VMs se ven entre sí)
- **`ip:`** `192.168.56.101` (desde `vagrant.yml`)

**Resultado:** Interface de red con IP estática `192.168.56.101`

**En la VM:**
```bash
ip addr show

2: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP>
    inet 192.168.56.101/24 brd 192.168.56.255 scope global enp0s8
```

### Port Forwarding

```ruby
primary.vm.network "forwarded_port", guest: 1521, host: 1521
primary.vm.network "forwarded_port", guest: 5500, host: 5500
```

**Sintaxis:**
```ruby
vm.network "forwarded_port", guest: PUERTO_EN_VM, host: PUERTO_EN_WINDOWS
```

**Configuración primary:**

| Servicio            | Puerto en VM (guest) | Puerto en Windows (host) |
|---------------------|----------------------|--------------------------|
| Oracle Listener     | 1521                 | 1521                     |
| Enterprise Manager  | 5500                 | 5500                     |

**Uso desde Windows:**
```bash
# Conectar a Oracle Listener en primary
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

# Acceder a Enterprise Manager
http://localhost:5500/em
```

**Nota:** SSH ya está forwardeado por defecto por Vagrant (puerto 2222).

### Configuración de VirtualBox Provider

```ruby
primary.vm.provider "virtualbox" do |vb|
  vb.name = params['node1']['vm_name']
  vb.memory = params['node1']['mem_size']
  vb.cpus = params['node1']['cpus']

  # Set non-rotational flag for better performance
  vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                '--port', '0', '--nonrotational', params['shared']['non_rotational']]

  # Create and attach u01 disk
  u01_disk = params['node1']['u01_disk']
  unless File.exist?(u01_disk)
    vb.customize ['createhd', '--filename', u01_disk,
                  '--size', params['node1']['disk_size']]
  end
  vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                '--port', 1, '--device', 0, '--type', 'hdd', '--medium', u01_disk,
                '--nonrotational', params['shared']['non_rotational']]

  # Create and attach u02 disk
  u02_disk = params['node1']['u02_disk']
  unless File.exist?(u02_disk)
    vb.customize ['createhd', '--filename', u02_disk,
                  '--size', params['node1']['disk_size']]
  end
  vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                '--port', 2, '--device', 0, '--type', 'hdd', '--medium', u02_disk,
                '--nonrotational', params['shared']['non_rotational']]
end
```

**Desglose:**

#### Configuración Básica

```ruby
vb.name = params['node1']['vm_name']     # "ol8_21_dg1_primary"
vb.memory = params['node1']['mem_size']  # 4096 (4 GB)
vb.cpus = params['node1']['cpus']        # 2
```

#### Configuración de Disco Principal (SSD flag)

```ruby
vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
              '--port', '0', '--nonrotational', 'on']
```

**Explicación:**
- **`storageattach`:** Modificar disco existente
- **`:id`:** ID de la VM (proporcionado por Vagrant)
- **`--storagectl 'SATA Controller'`:** Controlador SATA
- **`--port 0`:** Puerto 0 = disco principal (OS)
- **`--nonrotational on`:** Marcar como SSD (mejora rendimiento I/O)

**Beneficio:**
Oracle optimiza I/O diferente para SSD vs HDD. Marcar como SSD mejora rendimiento de database incluso si el disco host es HDD.

#### Creación de Disco u01 (100 GB)

```ruby
u01_disk = params['node1']['u01_disk']  # "./ol8_21_dg1_u01.vdi"

unless File.exist?(u01_disk)
  vb.customize ['createhd', '--filename', u01_disk, '--size', 102400]
end
```

**Explicación:**
- **`unless File.exist?`:** Solo crear si no existe (idempotencia)
- **`createhd`:** Comando VBoxManage para crear disco virtual
- **`--size 102400`:** Tamaño en MB (102400 MB = 100 GB)
- **Formato:** VDI (VirtualBox Disk Image) - formato nativo de VirtualBox

**Archivo creado:**
```
C:\Users\StarAlchemist\DataGripProjects\AdminBDProyecto\ol8_21_dg1_u01.vdi
```

**Tamaño inicial:** ~1 MB (thin provisioned - crece dinámicamente)

#### Adjuntar Disco u01

```ruby
vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
              '--port', 1, '--device', 0, '--type', 'hdd',
              '--medium', u01_disk, '--nonrotational', 'on']
```

**Explicación:**
- **`--port 1`:** Puerto 1 = segundo disco (después del OS en puerto 0)
- **`--device 0`:** Dispositivo 0 en ese puerto
- **`--type hdd`:** Tipo hard disk
- **`--medium u01_disk`:** Ruta al archivo VDI
- **`--nonrotational on`:** Marcar como SSD

**En la VM se ve como:**
```bash
lsblk

NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   20G  0 disk          # OS disk (base box)
├─sda1   8:1    0    1G  0 part /boot
└─sda2   8:2    0   19G  0 part /
sdb      8:16   0  100G  0 disk          # u01 disk (Oracle software/data)
sdc      8:32   0  100G  0 disk          # u02 disk (backups/FRA)
```

#### Creación y Adjunción de Disco u02 (100 GB)

```ruby
u02_disk = params['node1']['u02_disk']  # "./ol8_21_dg1_u02.vdi"

unless File.exist?(u02_disk)
  vb.customize ['createhd', '--filename', u02_disk, '--size', 102400]
end

vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
              '--port', 2, '--device', 0, '--type', 'hdd',
              '--medium', u02_disk, '--nonrotational', 'on']
```

**Idéntico a u01 pero:**
- Puerto 2 (tercer disco)
- Nombre archivo: `ol8_21_dg1_u02.vdi`

### Provisioners de Primary

```ruby
primary.vm.provision "shell", path: "2-Standby/scripts/primary/setup.sh"

primary.vm.provision "shell",
  path: "2-Standby/scripts/optional/deploy_sql_and_directories.sh",
  name: "deploy_sql_and_directories",
  run: "never"

primary.vm.provision "shell",
  path: "2-Standby/scripts/optional/setup_oracle_autostart.sh",
  name: "setup_oracle_autostart",
  run: "never"
```

**Explicación:**

#### Provisioner Principal (siempre ejecuta)

```ruby
primary.vm.provision "shell", path: "2-Standby/scripts/primary/setup.sh"
```

**Tipo:** `"shell"` (ejecuta script shell)
**Path:** Ruta relativa desde el directorio del Vagrantfile
**Ejecución:** Siempre que se ejecuta `vagrant up` o `vagrant provision`

**Este es el entry point del provisioning de primary.**

Ver: [30-primary-setup.md](primary/30-primary-setup.md)

#### Provisioners On-Demand (solo si se solicitan)

```ruby
primary.vm.provision "shell",
  path: "2-Standby/scripts/optional/deploy_sql_and_directories.sh",
  name: "deploy_sql_and_directories",
  run: "never"
```

**Parámetros:**
- **`name:`** Nombre identificador
- **`run: "never"`:** No ejecutar automáticamente

**Ejecución manual:**
```bash
vagrant provision primary --provision-with deploy_sql_and_directories
```

**Propósito:** Desplegar SQLs y directorios adicionales después del despliegue inicial.

---

```ruby
primary.vm.provision "shell",
  path: "2-Standby/scripts/optional/setup_oracle_autostart.sh",
  name: "setup_oracle_autostart",
  run: "never"
```

**Propósito:** Configurar Oracle para auto-inicio con systemd.

**Ejecución manual:**
```bash
vagrant provision primary --provision-with setup_oracle_autostart
```

**Resultado:** Oracle se inicia automáticamente cuando arranca la VM.

---

## Configuración de Standby VM

### Definición de Standby

```ruby
config.vm.define "standby", autostart: false do |standby|
  # Configuración específica de standby
end
```

**Diferencias con primary:**
- **`autostart: false`:** No inicia automáticamente con `vagrant up` (solo inicia si se especifica `vagrant up standby`)
- **NO tiene `primary: true`:** No es la VM por defecto

**Razón de `autostart: false`:**
- Primary debe estar completamente desplegado antes de desplegar standby
- `deploy.ps1` controla el orden: primero primary, luego standby
- Evita errores si se ejecuta `vagrant up` sin especificar VM

### Configuración Similar a Primary

```ruby
standby.vm.hostname = "ol8-21-dg2.localdomain"
standby.vm.network "private_network", ip: params['node2']['public_ip']  # 192.168.56.102
```

**Diferencias clave:**
- Hostname: `ol8-21-dg2.localdomain` (vs `ol8-21-dg1`)
- IP: `192.168.56.102` (vs `192.168.56.101`)

### Port Forwarding de Standby

```ruby
standby.vm.network "forwarded_port", guest: 1521, host: 1522
standby.vm.network "forwarded_port", guest: 5500, host: 5501
```

**Nota importante:** Puertos en Windows host son **diferentes** de primary

**Configuración standby:**

| Servicio            | Puerto en VM (guest) | Puerto en Windows (host) |
|---------------------|----------------------|--------------------------|
| Oracle Listener     | 1521                 | **1522** (diferente)     |
| Enterprise Manager  | 5500                 | **5501** (diferente)     |

**Razón:** No puede haber dos servicios en el mismo puerto del host.

**Uso desde Windows:**
```bash
# Conectar a primary
sqlplus sys/S1sPassword1!@localhost:1521/cdb1 as sysdba

# Conectar a standby (puerto 1522, no 1521)
sqlplus sys/S1sPassword1!@localhost:1522/cdb1_stby as sysdba
```

### VirtualBox Provider de Standby

```ruby
standby.vm.provider "virtualbox" do |vb|
  vb.name = params['node2']['vm_name']      # "ol8_21_dg2_standby"
  vb.memory = params['node2']['mem_size']   # 4096
  vb.cpus = params['node2']['cpus']         # 2

  # Discos u01 y u02 (idénticos a primary)
  u01_disk = params['node2']['u01_disk']    # "./ol8_21_dg2_u01.vdi"
  u02_disk = params['node2']['u02_disk']    # "./ol8_21_dg2_u02.vdi"
  # ... (creación y adjunción idéntica a primary)
end
```

**Idéntico a primary excepto:**
- Nombres de archivo VDI diferentes (`dg2` en lugar de `dg1`)
- Lee configuración de `params['node2']` en lugar de `params['node1']`

### Provisioners de Standby

```ruby
standby.vm.provision "shell", path: "2-Standby/scripts/standby/setup.sh"

standby.vm.provision "shell",
  path: "2-Standby/scripts/optional/deploy_sql_and_directories.sh",
  name: "deploy_sql_and_directories",
  run: "never"

standby.vm.provision "shell",
  path: "2-Standby/scripts/optional/setup_oracle_autostart.sh",
  name: "setup_oracle_autostart",
  run: "never"
```

**Diferencia con primary:**
- Provisioner principal: `2-Standby/scripts/standby/setup.sh` (en lugar de `primary/setup.sh`)
- Scripts compartidos: Idénticos (deploy_sql_and_directories, setup_oracle_autostart)

**Ver:** [50-standby-setup.md](standby/50-standby-setup.md)

---

## Network Configuration

### Tipos de Red en VirtualBox

**Cada VM tiene 2 interfaces de red:**

#### 1. NAT (Network Address Translation) - Interface enp0s3

**Configuración automática por Vagrant (no aparece explícita en Vagrantfile)**

```
enp0s3: inet 10.0.2.15
```

**Propósito:**
- Acceso a Internet desde las VMs
- Descargar paquetes con `yum`
- Actualización del sistema

**Características:**
- IP: 10.0.2.15 (igual en todas las VMs, pero NAT separa el tráfico)
- Gateway: 10.0.2.2 (proporcionado por VirtualBox)
- DNS: 10.0.2.3 (proporcionado por VirtualBox)

**Limitación:**
- Las VMs NO pueden comunicarse entre sí por esta red
- El host NO puede conectarse a las VMs por esta red

#### 2. Host-Only Network - Interface enp0s8

**Configuración explícita en Vagrantfile:**

```ruby
primary.vm.network "private_network", ip: "192.168.56.101"
standby.vm.network "private_network", ip: "192.168.56.102"
```

**En las VMs:**
```
enp0s8: inet 192.168.56.101  (primary)
enp0s8: inet 192.168.56.102  (standby)
```

**Propósito:**
- Comunicación entre primary y standby (Data Guard)
- Comunicación entre VMs y host Windows (SQL*Plus, SSH)

**Características:**
- Red privada: 192.168.56.0/24
- Netmask: 255.255.255.0
- VMs pueden comunicarse entre sí
- Host puede conectarse a VMs
- VMs NO pueden acceder a Internet por esta red

**Diagrama de Red:**

```
┌─────────────────────────────────────────────────────┐
│              Windows Host                           │
│          (192.168.56.1 on vboxnet0)                │
│                                                     │
│  ┌───────────────┐           ┌───────────────┐    │
│  │  Primary VM   │           │  Standby VM   │    │
│  │               │           │               │    │
│  │ enp0s3 (NAT) ├───────┐   │ enp0s3 (NAT) ├────┐│
│  │ 10.0.2.15    │  NAT  │   │ 10.0.2.15    │NAT ││
│  │              │       │   │              │    ││
│  │ enp0s8       │       ▼   │ enp0s8       │    ││
│  │ 192.168.56.101├──────────┤192.168.56.102│    ││
│  │              │ Host-Only │              │    ││
│  └───────────────┘  Network └───────────────┘    ││
│                                                   ││
└───────────────────────────────────────────────────┘│
                        │                            │
                        ▼                            │
                   Internet ◄────────────────────────┘
```

### Port Forwarding Detallado

**Primary:**
```ruby
primary.vm.network "forwarded_port", guest: 1521, host: 1521
primary.vm.network "forwarded_port", guest: 5500, host: 5500
```

**Standby:**
```ruby
standby.vm.network "forwarded_port", guest: 1521, host: 1522
standby.vm.network "forwarded_port", guest: 5500, host: 5501
```

**Tabla completa:**

| VM      | Servicio            | Puerto VM | Puerto Windows | Uso desde Windows                               |
|---------|---------------------|-----------|----------------|-------------------------------------------------|
| Primary | Oracle Listener     | 1521      | 1521           | `sqlplus sys/pass@localhost:1521/cdb1 as sysdba`|
| Primary | Enterprise Manager  | 5500      | 5500           | `http://localhost:5500/em`                      |
| Primary | SSH (Vagrant auto)  | 22        | 2201           | `ssh -p 2201 vagrant@localhost`                 |
| Standby | Oracle Listener     | 1521      | 1522           | `sqlplus sys/pass@localhost:1522/cdb1_stby as sysdba`|
| Standby | Enterprise Manager  | 5500      | 5501           | `http://localhost:5501/em`                      |
| Standby | SSH (Vagrant auto)  | 22        | 2202           | `ssh -p 2202 vagrant@localhost`                 |

**Nota:** SSH port forwarding es automático por Vagrant (no aparece explícito en Vagrantfile).

---

## Storage Configuration

### Arquitectura de Discos

**Cada VM tiene 3 discos:**

```
┌────────────────────────────────────────────┐
│              Primary VM                    │
├────────────────────────────────────────────┤
│                                            │
│  /dev/sda (20 GB) - OS Disk               │
│  ├─ sda1: /boot (1 GB)                    │
│  └─ sda2: / (19 GB) - root filesystem     │
│                                            │
│  /dev/sdb (100 GB) - u01 Disk             │
│  └─ sdb1: /u01 (100 GB)                   │
│     └─ Oracle software + databases        │
│                                            │
│  /dev/sdc (100 GB) - u02 Disk             │
│  └─ sdc1: /u02 (100 GB)                   │
│     └─ Backups + Fast Recovery Area       │
│                                            │
└────────────────────────────────────────────┘
```

### Mapeo de Puertos SATA

**Controlador SATA (SATA Controller):**
- **Puerto 0:** Disco OS (20 GB) - del base box
- **Puerto 1:** Disco u01 (100 GB) - creado por Vagrantfile
- **Puerto 2:** Disco u02 (100 GB) - creado por Vagrantfile

**Comando VBoxManage equivalente:**

```bash
# Crear disco u01
VBoxManage createhd --filename ol8_21_dg1_u01.vdi --size 102400

# Adjuntar disco u01
VBoxManage storageattach ol8_21_dg1_primary \
  --storagectl "SATA Controller" \
  --port 1 \
  --device 0 \
  --type hdd \
  --medium ol8_21_dg1_u01.vdi \
  --nonrotational on
```

### Thin Provisioning

**Los discos VDI crecen dinámicamente:**

**Al crear:**
```
ol8_21_dg1_u01.vdi: ~1 MB (vacío)
ol8_21_dg1_u02.vdi: ~1 MB (vacío)
```

**Después de instalar Oracle:**
```
ol8_21_dg1_u01.vdi: ~25 GB (Oracle + CDB + PDB)
ol8_21_dg1_u02.vdi: ~5 GB (algunos backups)
```

**Máximo posible:**
```
ol8_21_dg1_u01.vdi: 100 GB
ol8_21_dg1_u02.vdi: 100 GB
```

**Beneficio:** No ocupa 200 GB inmediatamente, solo crece según se usa.

### Formato de Filesystem

**Los provisioners formatean los discos como XFS:**

```bash
# En el provisioner prepare_u01_u02_disks.sh
mkfs.xfs -f /dev/sdb1  # u01
mkfs.xfs -f /dev/sdc1  # u02
```

**Por qué XFS:**
- Recomendado por Oracle para Linux
- Alto rendimiento con archivos grandes (datafiles de varios GB)
- Journaling para recuperación ante crashes
- Soporte de archivos >2 TB

---

## Dependencias

### Prerequisitos (en el Host Windows)

**1. VirtualBox 7.0+**
- Hypervisor para ejecutar VMs
- Vagrant lo controla vía VBoxManage

**2. Vagrant 2.4+**
- Lee y ejecuta Vagrantfile
- Orquesta VirtualBox

**3. Base Box `oraclelinux/8`**
- Descargado automáticamente la primera vez
- Tamaño: ~500 MB
- Ubicación: `C:\Users\Usuario\.vagrant.d\boxes\`

**4. Espacio en disco**
- Mínimo: 250 GB libres
- VMs finales: ~220 GB total (2 VMs × ~110 GB c/u)

### Archivos de Configuración Referenciados

**1. `config/vagrant.yml`** (requerido)
```ruby
params = YAML.load_file 'config/vagrant.yml'
```

**Ver:** [21-vagrant-configuracion.md](21-vagrant-configuracion.md)

**2. Scripts de provisioning (requeridos):**
- `2-Standby/scripts/primary/setup.sh`
- `2-Standby/scripts/standby/setup.sh`
- `2-Standby/scripts/optional/deploy_sql_and_directories.sh`
- `2-Standby/scripts/optional/setup_oracle_autostart.sh`

**3. Synced folders (deben existir):**
- `config/`
- `2-Standby/infrastructure/`
- `software/`
- `2-Standby/automation/`
- `1-BD/SQL-VM scripts/`
- `1-BD/directories/`

**Si falta algún directorio:**
```
The following SSH command responded with a non-zero exit status.
Vagrant assumes that this means the command failed!

mount -t vboxsf -o uid=1000,gid=1000 vagrant_config /vagrant_config
```

**Solución:** Crear el directorio faltante.

---

## Relación con Data Guard

### Cómo el Vagrantfile Habilita Data Guard

El Vagrantfile **no configura Data Guard directamente**, pero crea la **infraestructura necesaria** para que Data Guard funcione:

### 1. Dos Máquinas Virtuales Independientes

```ruby
config.vm.define "primary" do |primary|
  # ...
end

config.vm.define "standby" do |standby|
  # ...
end
```

**Necesario para Data Guard:**
- Primary y standby deben estar en servidores separados
- Si estuvieran en la misma VM, no habría redundancia
- Simula entorno de producción (2 servidores físicos)

### 2. Red Privada entre VMs

```ruby
primary.vm.network "private_network", ip: "192.168.56.101"
standby.vm.network "private_network", ip: "192.168.56.102"
```

**Necesario para Data Guard:**
- Data Guard replica logs a través de la red
- Primary envía redo logs a standby continuamente
- Requiere conectividad TCP/IP de baja latencia

**Tráfico de red típico:**
```
Primary (192.168.56.101) ──[Archive Logs]──> Standby (192.168.56.102)
                         <──[Acknowledgments]──
```

### 3. Hostnames Resolvibles

```ruby
primary.vm.hostname = "ol8-21-dg1.localdomain"
standby.vm.hostname = "ol8-21-dg2.localdomain"
```

**Necesario para Data Guard:**
- Data Guard Broker usa hostnames (no IPs)
- TNS (tnsnames.ora) usa hostnames
- Más portable que hardcodear IPs

**Configuración de Data Guard Broker:**
```
DGMGRL> create configuration dg_config as
          primary database is cdb1 connect identifier is cdb1.localdomain;

DGMGRL> add database cdb1_stby as
          connect identifier is cdb1_stby.localdomain;
```

### 4. Almacenamiento Separado

**Primary:**
```ruby
u01_disk = "./ol8_21_dg1_u01.vdi"
u02_disk = "./ol8_21_dg1_u02.vdi"
```

**Standby:**
```ruby
u01_disk = "./ol8_21_dg2_u01.vdi"
u02_disk = "./ol8_21_dg2_u02.vdi"
```

**Necesario para Data Guard:**
- Primary y standby tienen bases de datos independientes
- Si compartieran almacenamiento, corrupción afectaría ambos
- Backups de primary se copian a u02 de standby (protección adicional)

### 5. Provisioners que Configuran Data Guard

```ruby
primary.vm.provision "shell", path: "2-Standby/scripts/primary/setup.sh"
standby.vm.provision "shell", path: "2-Standby/scripts/standby/setup.sh"
```

**Estos provisioners:**
- Instalan Oracle Database
- Configuran primary para Data Guard
- Crean standby con RMAN DUPLICATE
- Configuran Data Guard Broker

**Sin Vagrantfile:** Tendrías que crear VMs manualmente, configurar red, instalar Oracle, etc. (horas de trabajo manual).

**Con Vagrantfile:** `vagrant up` automatiza todo.

---

## Referencias Cruzadas

### Documentación Relacionada

**Configuración:**
- [21 - vagrant-configuracion.md](21-vagrant-configuracion.md) - Variables en vagrant.yml e install.env

**Scripts llamados:**
- [10 - deploy-powershell.md](10-deploy-powershell.md) - Script que ejecuta vagrant up
- [30 - primary-setup.md](primary/30-primary-setup.md) - Provisioner de primary
- [50 - standby-setup.md](standby/50-standby-setup.md) - Provisioner de standby

**Conceptos:**
- [02 - Conceptos Fundamentales](../02-conceptos-fundamentales.md) - Virtualización, Vagrant
- [05 - Arquitectura del Sistema](../05-arquitectura-sistema.md) - Arquitectura completa

**Guías de uso:**
- [04 - Cómo Usar](../04-como-usar.md) - Comandos vagrant up, reload, etc.

---

## Siguiente Paso

Después de entender el Vagrantfile, el siguiente paso es:

### Leer Configuración Externa

**Siguiente documento:** [21 - vagrant-configuracion.md](21-vagrant-configuracion.md)

**Aprenderás:**
- Contenido de `config/vagrant.yml` (specs de VMs)
- Contenido de `config/install.env` (variables de entorno)
- Cómo modificar recursos (RAM, CPU, disco)
- Cómo cambiar passwords y configuración de Data Guard

### Comandos Vagrant Útiles

**Verificar configuración:**
```bash
# Validar sintaxis de Vagrantfile
vagrant validate

# Ver configuración de VMs
vagrant status

# Ver configuración SSH
vagrant ssh-config primary
```

**Modificar configuración:**
1. Editar `Vagrantfile` o `config/vagrant.yml`
2. Destruir VMs existentes: `vagrant destroy -f`
3. Recrear con nueva configuración: `vagrant up`

---

**Has completado la documentación del Vagrantfile!**

Este archivo es el **corazón de la infraestructura** del proyecto:
- Define 2 VMs (primary y standby)
- Configura red, almacenamiento y recursos
- Orquesta provisioning completo
- Permite reproducir el ambiente en cualquier máquina

**Flujo de despliegue:**
```
deploy.ps1
  └─> vagrant up primary
        └─> Lee Vagrantfile
              └─> Crea VM primary según especificaciones
                    └─> Ejecuta provisioners de primary

  └─> vagrant up standby
        └─> Lee Vagrantfile
              └─> Crea VM standby según especificaciones
                    └─> Ejecuta provisioners de standby
```

Para entender la configuración detallada de las VMs, continúa con [21 - vagrant-configuracion.md](21-vagrant-configuracion.md).
