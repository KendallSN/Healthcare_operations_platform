# 33 - Install Packages - Instalación de Paquetes del Sistema

## Instalación de Prerequisitos para Oracle 21c

Este script instala todos los paquetes del sistema operativo necesarios para Oracle Database 21c, configura parámetros del kernel optimizados para Data Guard, y prepara el sistema operativo para la instalación de Oracle.

## Ubicación

`2-Standby/infrastructure/install_os_packages.sh`

**Nota:** Este es un **shared script** usado tanto por primary como standby.

## Propósito

- **Función principal:** Instalar prerequisitos del sistema para Oracle Database 21c
- **Responsabilidad:** Configurar usuarios, grupos, kernel parameters y paquetes necesarios
- **Optimización:** Aplicar tuning específico para Data Guard

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 4 de 12 en el despliegue primario
- **Usuario:** `root` (necesario para dnf install y sysctl)
- **Duración:** 5-10 minutos (depende de velocidad de internet)

## Variables de Entorno Utilizadas

Cargadas desde `install.env`:

```bash
# Ninguna variable específica usada directamente
# El script es autocontenido
```

## Flujo de Ejecución Paso a Paso

### Paso 1: Cargar Variables de Entorno

```bash
. /vagrant_config/install.env
```

### Paso 2: Banner de Inicio

```bash
echo "******************************************************************************"
echo "Install OS packages." `date`
echo "******************************************************************************"
```

### Paso 3: Instalar Oracle Preinstall Package

```bash
dnf install -y oracle-database-preinstall-21c
```

**Explicación:**
- **Paquete mágico** que configura automáticamente el 80% de prerequisitos Oracle
- **Crea usuario y grupos:**
  - Usuario: `oracle` (uid generalmente 54321)
  - Grupos: `oinstall`, `dba`, `oper`, `backupdba`, `dgdba`, `kmdba`, `racdba`
- **Configura kernel parameters:**
  - Shared memory limits
  - Semaphores
  - File descriptors
  - Network buffers
- **Crea directorios base** para Oracle
- **Configura PAM limits** para usuario oracle

**Grupos Oracle explicados:**
- `oinstall`: Grupo de instalación (owner de Oracle inventory)
- `dba`: Grupo SYSDBA (administración completa)
- `oper`: Grupo SYSOPER (operaciones sin acceso a datos)
- `backupdba`: SYSBACKUP (gestión de backups)
- `dgdba`: SYSDG (gestión de Data Guard)
- `kmdba`: SYSKM (gestión de encryption keys)

### Paso 4: Instalar Paquetes Adicionales Requeridos

```bash
dnf install -y \
  bc \
  binutils \
  elfutils-libelf \
  elfutils-libelf-devel \
  fontconfig-devel \
  glibc \
  glibc-devel \
  ksh \
  libaio \
  libaio-devel \
  libgcc \
  libnsl \
  librdmacm-devel \
  libstdc++ \
  libstdc++-devel \
  libX11 \
  libXau \
  libxcb \
  libXi \
  libXrender \
  libXrender-devel \
  libXtst \
  make \
  net-tools \
  nfs-utils \
  policycoreutils \
  policycoreutils-python-utils \
  smartmontools \
  sysstat \
  targetcli \
  unzip \
  zip \
  chrony \
  rsync
```

**Categorías de paquetes:**

**Compilación y desarrollo:**
- `bc`: Calculadora para scripts
- `binutils`: Herramientas de binarios
- `make`: Compilación
- `elfutils-libelf*`: Manejo de archivos ELF

**Librerías C:**
- `glibc*`: GNU C Library (esencial)
- `libgcc`: GCC runtime library
- `libstdc++*`: C++ standard library

**Librerías de I/O:**
- `libaio*`: Async I/O (crítico para Oracle)
- `libnsl`: Network Services Library

**X11 (para GUI de instalación):**
- `libX11`, `libXau`, `libxcb`, `libXi`, `libXrender`, `libXtst`: Librerías X Window

**Red y monitoreo:**
- `net-tools`: Herramientas de red (netstat, ifconfig)
- `nfs-utils`: NFS client (para storage compartido si se usa)
- `chrony`: Time synchronization (CRÍTICO para Data Guard)
- `rsync`: Transferencia de backups

**Utilidades:**
- `unzip`, `zip`: Descompresión de Oracle software
- `sysstat`: Monitoreo de sistema (iostat, vmstat)
- `smartmontools`: Monitoreo de discos

**Duración:** 3-7 minutos (descarga + instalación)

### Paso 5: Actualizar Sistema

```bash
dnf update -y
```

**Explicación:**
- Actualiza todos los paquetes a sus últimas versiones
- Aplica security patches
- Asegura compatibilidad

**Duración:** 1-3 minutos

### Paso 6: Configurar Parámetros del Kernel para Data Guard

```bash
echo "******************************************************************************"
echo "Configure kernel parameters." `date`
echo "******************************************************************************"

cat >> /etc/sysctl.d/98-oracle.conf << EOF
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.ip_local_port_range = 9000 65500
fs.aio-max-nr = 1048576
# TCP tuning for Data Guard
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
EOF
```

**Parámetros explicados:**

**File system:**
- `fs.file-max = 6815744`: Máximo de file descriptors (Oracle abre muchos archivos)
- `fs.aio-max-nr = 1048576`: Máximo de async I/O requests (Oracle usa AIO intensivamente)

**Semaphores (IPC):**
- `kernel.sem = 250 32000 100 128`:
  - `250`: SEMMSL (max semaphores per array)
  - `32000`: SEMMNS (max semaphores system-wide)
  - `100`: SEMOPM (max operations per semctl call)
  - `128`: SEMMNI (max semaphore arrays)

**Shared memory:**
- `kernel.shmmni = 4096`: Max shared memory segments
- `kernel.shmall = 1073741824`: Max shared memory pages (1 TB con páginas de 4KB)
- `kernel.shmmax = 4398046511104`: Max size single shared memory segment (4 TB)
- Oracle SGA y PGA usan shared memory

**Network buffers:**
- `net.core.rmem_default = 262144`: Default receive buffer (256 KB)
- `net.core.rmem_max = 16777216`: Max receive buffer (16 MB)
- `net.core.wmem_default = 262144`: Default send buffer (256 KB)
- `net.core.wmem_max = 16777216`: Max send buffer (16 MB)

**Port range:**
- `net.ipv4.ip_local_port_range = 9000 65500`: Puertos efímeros (evita conflicto con well-known ports)

**TCP tuning para Data Guard:**
- `net.ipv4.tcp_rmem = 4096 87380 16777216`: TCP receive buffer (min, default, max)
- `net.ipv4.tcp_wmem = 4096 16384 16777216`: TCP send buffer (min, default, max)
- **Crítico para rendimiento de replicación:** Buffers grandes mejoran throughput de archive log transport

### Paso 7: Aplicar Configuración de Kernel

```bash
sysctl -p /etc/sysctl.d/98-oracle.conf
```

**Explicación:**
- Carga configuración inmediatamente (sin reboot)
- `-p`: Read values from file
- Cambios persisten después de reboot (porque están en /etc/sysctl.d/)

**Salida esperada:**
```
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
...
```

### Paso 8: Deshabilitar SELinux

```bash
echo "******************************************************************************"
echo "Disable SELinux and Firewall." `date`
echo "******************************************************************************"

sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
setenforce Permissive 2>/dev/null || true
```

**Explicación:**
- **SELinux (Security-Enhanced Linux):** Framework de seguridad de kernel
- **¿Por qué deshabilitar?**
  - Oracle no está completamente compatible con SELinux enforcing
  - Causa problemas con acceso a archivos y puertos
  - En producción real, configurar SELinux policies específicas en lugar de deshabilitar
- `sed -i`: Modifica /etc/selinux/config permanentemente
- `setenforce Permissive`: Aplica inmediatamente (sin reboot)
- `2>/dev/null || true`: Ignora error si ya está en permissive

**Estados de SELinux:**
- `enforcing`: Bloquea accesos no permitidos
- `permissive`: Registra violations pero no bloquea (para testing)
- `disabled`: Completamente deshabilitado

### Paso 9: Deshabilitar Firewall

```bash
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true
```

**Explicación:**
- **firewalld:** Firewall dinámico de Linux
- **¿Por qué deshabilitar?**
  - En ambiente de lab/desarrollo no es necesario
  - En producción, configurar reglas específicas:
    - Puerto 1521: Oracle listener
    - Puerto 22: SSH
    - Puertos efímeros 9000-65500
- `stop`: Detiene servicio inmediatamente
- `disable`: Previene inicio automático en boot
- `|| true`: Ignora error si ya está stopped/disabled

### Paso 10: Banner de Finalización

```bash
echo "******************************************************************************"
echo "OS package installation complete." `date`
echo "******************************************************************************"
```

## Archivos Creados/Modificados

### Sistema

| Archivo | Descripción |
|---------|-------------|
| `/etc/sysctl.d/98-oracle.conf` | Kernel parameters para Oracle |
| `/etc/selinux/config` | SELinux configurado a permissive |
| `/etc/security/limits.d/oracle-database-preinstall-21c.conf` | Resource limits para usuario oracle |

### Usuarios y Grupos Creados

```bash
# Usuario oracle
id oracle
# uid=54321(oracle) gid=54321(oinstall) groups=54321(oinstall),
# 54322(dba),54323(oper),54324(backupdba),54325(dgdba),
# 54326(kmdba),54330(racdba)
```

### Paquetes Instalados

Total: **~50 paquetes** incluyendo dependencias

## Dependencias

### Internet Connectivity

**Crítico:** Este script requiere internet para descargar paquetes desde Oracle Linux repos.

**Repositorios usados:**
- `ol8_baseos_latest`: Base OS packages
- `ol8_appstream`: Application stream packages
- `ol8_addons`: Add-on packages

### Prerequisitos

- Oracle Linux 8 (o compatible: Rocky Linux, AlmaLinux)
- Privilegios de root
- Al menos 2 GB de espacio en `/var/cache/dnf`

## Logs y Verificación

### Verificación de Paquetes Instalados

```bash
# Verificar oracle-database-preinstall-21c
rpm -qi oracle-database-preinstall-21c

# Verificar usuario oracle creado
id oracle

# Verificar grupos
getent group | grep -E "oinstall|dba|oper|backupdba|dgdba"

# Verificar paquetes críticos
rpm -q libaio libaio-devel glibc glibc-devel chrony rsync

# Verificar kernel parameters
sysctl -a | grep -E "fs.file-max|kernel.sem|net.ipv4.tcp"

# Verificar SELinux
getenforce
# Output esperado: Permissive

# Verificar firewall
systemctl status firewalld
# Output esperado: inactive (dead)
```

### Verificación desde Windows Host

```powershell
# Verificar usuario oracle
vagrant ssh primary -c "id oracle"

# Verificar kernel parameters
vagrant ssh primary -c "sysctl fs.file-max"

# Verificar paquetes instalados
vagrant ssh primary -c "rpm -qa | wc -l"
```

## Puntos de Fallo Comunes

### 1. Sin Conectividad a Internet

**Error:**
```
Failed to download metadata for repo 'ol8_baseos_latest'
Cannot download repomd.xml
```

**Solución:**
```bash
# Verificar conectividad
ping google.com

# Configurar proxy si es necesario
export http_proxy="http://proxy:8080"
export https_proxy="http://proxy:8080"

# O configurar en /etc/dnf/dnf.conf
echo "proxy=http://proxy:8080" >> /etc/dnf/dnf.conf
```

### 2. Espacio Insuficiente en /var

**Error:**
```
Error: Disk Requirements: At least XXX MB more space needed on the /var filesystem
```

**Solución:**
```bash
# Limpiar cache de dnf
dnf clean all

# Verificar espacio
df -h /var

# Aumentar tamaño de disco raíz en Vagrantfile si es necesario
```

### 3. oracle-database-preinstall-21c No Disponible

**Error:**
```
No match for argument: oracle-database-preinstall-21c
```

**Causa:** Repos de Oracle no habilitados

**Solución:**
```bash
# Habilitar repos de Oracle Linux
dnf install -y oracle-epel-release-el8
dnf config-manager --enable ol8_oracle_software
```

### 4. Kernel Parameters No Se Aplican

**Error:**
```
sysctl: cannot stat /proc/sys/...: No such file or directory
```

**Causa:** Typo en nombre de parámetro

**Solución:**
- Verificar nombres de parámetros con `sysctl -a`
- Corregir /etc/sysctl.d/98-oracle.conf

## Importancia para Data Guard

### TCP Tuning para Replicación

Los parámetros de red son **críticos** para performance de Data Guard:

```bash
# Buffers grandes = mejor throughput de archive logs
net.ipv4.tcp_rmem = 4096 87380 16777216  # 16 MB max
net.ipv4.tcp_wmem = 4096 16384 16777216  # 16 MB max
```

**Impacto:**
- Archive logs típicamente 50-500 MB
- Sin tuning: Transferencia puede tomar minutos
- Con tuning: Transferencia en segundos
- **MAXAVAILABILITY mode** requiere transferencia rápida para no bloquear transacciones

### Time Synchronization con Chrony

```bash
dnf install -y chrony
```

**Crítico porque:**
- Data Guard compara timestamps de redo records
- Relojes desincronizados (>5 min) causan fallos de apply
- Chrony es más preciso que ntpd (especialmente en VMs)

### Shared Memory para SGA/PGA

```bash
kernel.shmall = 1073741824  # 1 TB en páginas
kernel.shmmax = 4398046511104  # 4 TB
```

**Necesario para:**
- System Global Area (SGA): Caché de datos, redo buffers
- Program Global Area (PGA): Sort areas, hash joins
- Típicamente asignar 70% de RAM a Oracle (2.8 GB en VM de 4 GB)

### Async I/O para Archive Log Transport

```bash
fs.aio-max-nr = 1048576
```

**Beneficios:**
- Oracle escribe archive logs de forma asíncrona
- No bloquea redo log generation durante archive
- Mejora throughput de log transport a standby

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador que llama a este script
- **[32 - Prepare Disks](32-prepare-disks.md)** - Ejecutado antes (discos necesarios para dnf cache)
- **[34 - Configure Network](34-configure-network.md)** - Ejecutado después (usa chrony instalado aquí)

### Documentación de Contexto

- **[03 - Prerequisitos](../../03-prerequisitos.md)** - Requisitos de hardware/software
- **[81 - Data Guard Conceptos](../../conceptos-avanzados/81-data-guard-conceptos.md)** - Por qué estos packages son necesarios
- **[86 - Networking TNS](../../conceptos-avanzados/86-networking-tns.md)** - Configuración de red

## Código Fuente Completo

Ver archivo: `2-Standby/infrastructure/install_os_packages.sh` (89 líneas)

---

**Siguiente:** [34 - Configure Network](34-configure-network.md) - Configuración de hosts, hostname y sincronización de tiempo.
