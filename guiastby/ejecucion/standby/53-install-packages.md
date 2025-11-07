# 53 - Instalación de Paquetes OS en Standby

## Descripción General

**Archivo:** `2-Standby/infrastructure/install_os_packages.sh`

**Propósito:** Instalar paquetes del sistema operativo necesarios para Oracle Database 21c.

**Compartido:** Este script es IDÉNTICO entre primary y standby.

**Tiempo de ejecución:** 5-8 minutos

---

## Paquetes Instalados

### 1. Oracle Database Preinstall
```bash
yum install -y oracle-database-preinstall-21c
```

**Este metapaquete hace:**
- Crea usuario `oracle` y grupos (`oinstall`, `dba`, etc.)
- Configura kernel parameters en `/etc/sysctl.conf`:
  ```
  fs.file-max = 6815744
  kernel.sem = 250 32000 100 128
  kernel.shmmni = 4096
  kernel.shmall = ...
  kernel.shmmax = ...
  net.core.rmem_default = 262144
  net.core.rmem_max = 4194304
  net.core.wmem_default = 262144
  net.core.wmem_max = 1048576
  fs.aio-max-nr = 1048576
  ```
- Configura límites en `/etc/security/limits.conf`:
  ```
  oracle   soft   nofile    1024
  oracle   hard   nofile    65536
  oracle   soft   nproc    16384
  oracle   hard   nproc    16384
  oracle   soft   stack    10240
  oracle   hard   stack    32768
  ```
- Instala dependencias Oracle (libaio, glibc, etc.)

### 2. Paquetes Adicionales (~48 paquetes)

```bash
yum install -y \
  bc bind-utils nfs-utils smartmontools \
  unzip zip screen tree psmisc net-tools \
  rlwrap git strace lsof wget vim \
  rsync chrony
```

**Categorías:**
- **Utilidades:** bc, unzip, zip, tree, wget
- **Red:** bind-utils, net-tools, nfs-utils
- **Monitoreo:** smartmontools, psmisc, lsof, strace
- **Sincronización:** chrony (NTP)
- **Backup:** rsync ⭐ (para recibir backups de primary)
- **Desarrollo:** git, vim, screen
- **Oracle SQL:** rlwrap (mejora sqlplus interactivo)

---

## Diferencia con Primary

**NINGUNA** - Script idéntico.

Ambos nodos necesitan los mismos paquetes base.

---

## Usuario y Grupos Creados

Después de `oracle-database-preinstall-21c`:

```bash
id oracle
# uid=54321(oracle) gid=54321(oinstall) groups=54321(oinstall),54322(dba),
# 54323(oper),54324(backupdba),54325(dgdba),54326(kmdba),54330(racdba)
```

**Grupos importantes:**
- `oinstall` (54321) - Propietario del inventario Oracle
- `dba` (54322) - SYSDBA privileges
- `dgdba` (54325) - Data Guard administration ⭐
- `backupdba` (54324) - RMAN backup/recovery

---

## Verificación

```bash
# Paquetes instalados
rpm -qa | grep oracle-database-preinstall

# Usuario oracle existe
id oracle

# Kernel parameters configurados
sysctl -a | grep kernel.sem

# Chrony corriendo (time sync)
systemctl status chronyd
```

---

## Referencia

Para análisis completo:
Ver `guiastby/ejecucion/primary/33-install-packages.md`

---

**Siguiente:** [54 - Configuración de Red](54-configure-network.md)
