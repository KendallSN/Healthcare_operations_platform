# 40 - Setup SSH - Configuración de Claves SSH para Backups

## Configuración Automatizada de SSH Keys para Transferencia de Backups

Este script genera un par de claves SSH RSA 4096-bit para el usuario `oracle` en el nodo primario, exporta la clave pública a un directorio compartido para que el standby pueda importarla, y configura el cliente SSH para conexiones batch automatizadas. Esto permite rsync de backups de primary a standby sin interacción manual.

## Ubicación

`2-Standby/scripts/primary/setup_ssh_keys_auto.sh`

## Propósito

- **Función principal:** Generar y configurar SSH keys para usuario oracle
- **Responsabilidad:** Crear claves, exportar pública, configurar cliente SSH
- **Objetivo:** Permitir `rsync` automatizado de backups a standby

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 15 de 12 (penúltimo paso)
- **Usuario:** `root` (para acceso a /vagrant, pero configura para oracle)
- **Duración:** 5-10 segundos

## Variables de Entorno Utilizadas

```bash
NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain  # Hostname del primary
```

## Flujo de Ejecución Paso a Paso

### Paso 1: Verificar install.env

```bash
if [ -f /vagrant_config/install.env ]; then
    source /vagrant_config/install.env
else
    echo "ERROR: install.env not found!"
    exit 1
fi
```

### Paso 2: Crear Directorio .ssh para Usuario Oracle

```bash
SSH_DIR="/home/oracle/.ssh"
if [ ! -d "${SSH_DIR}" ]; then
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    chown oracle:oinstall "${SSH_DIR}"
    echo "Created SSH directory: ${SSH_DIR}"
fi
```

**Explicación:**
- `chmod 700`: Solo owner (oracle) puede leer/escribir/ejecutar
- SSH rechaza keys si permisos son más permisivos (security requirement)

### Paso 3: Generar Par de Claves SSH (Si No Existe)

```bash
SSH_KEY="${SSH_DIR}/id_rsa"
if [ ! -f "${SSH_KEY}" ]; then
    echo "Generating SSH key pair for oracle user..."
    sudo -u oracle ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "oracle@${NODE1_FQ_HOSTNAME}"
    echo "SSH key pair generated successfully"
else
    echo "SSH key pair already exists, skipping generation"
fi
```

**Parámetros de ssh-keygen:**
- `-t rsa`: Tipo RSA (alternativas: ed25519, ecdsa)
- `-b 4096`: 4096 bits (muy seguro, más que los 2048 por defecto)
- `-f "${SSH_KEY}"`: Archivo de salida
- `-N ""`: Sin passphrase (permite automatización, pero menos seguro)
- `-C "oracle@ol8-21-dg1.localdomain"`: Comentario para identificar key

**Archivos generados:**
- `/home/oracle/.ssh/id_rsa` - Clave privada (NUNCA compartir)
- `/home/oracle/.ssh/id_rsa.pub` - Clave pública (se puede compartir)

**Ejemplo de clave pública generada:**
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7x... oracle@ol8-21-dg1.localdomain
```

### Paso 4: Crear Directorio Compartido para Intercambio de Keys

```bash
SHARED_SSH_DIR="/vagrant/ssh_keys"
mkdir -p "${SHARED_SSH_DIR}"
chmod 777 "${SHARED_SSH_DIR}"  # Permisivo temporalmente para intercambio
```

**Explicación:**
- `/vagrant/ssh_keys/`: Synced folder accesible desde primary y standby
- `chmod 777`: Necesario para que root pueda escribir y standby pueda leer
- Este es un directorio temporal solo para provisioning

### Paso 5: Exportar Clave Pública al Directorio Compartido

```bash
PUBLIC_KEY="${SSH_KEY}.pub"
if [ -f "${PUBLIC_KEY}" ]; then
    cp "${PUBLIC_KEY}" "${SHARED_SSH_DIR}/primary_id_rsa.pub"
    chmod 644 "${SHARED_SSH_DIR}/primary_id_rsa.pub"
    echo "Public key exported to: ${SHARED_SSH_DIR}/primary_id_rsa.pub"

    # Display public key fingerprint for verification
    ssh-keygen -lf "${PUBLIC_KEY}"
else
    echo "ERROR: Public key not found at ${PUBLIC_KEY}"
    exit 1
fi
```

**Fingerprint ejemplo:**
```
4096 SHA256:abcd1234efgh5678ijkl9012mnop3456qrst7890uvwx (RSA)
```

**Uso del fingerprint:**
- Verificar que la key es la correcta
- Detectar si key fue modificada (man-in-the-middle attack)

### Paso 6: Crear Configuración de Cliente SSH

```bash
SSH_CONFIG="${SSH_DIR}/config"
if [ ! -f "${SSH_CONFIG}" ]; then
    cat > "${SSH_CONFIG}" << 'EOF'
# SSH Client Configuration for Data Guard Backup Transfer
Host ol8-21-dg2 ol8-21-dg2.localdomain 192.168.56.102
    StrictHostKeyChecking accept-new
    BatchMode yes
    ConnectTimeout 10
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    chown oracle:oinstall "${SSH_CONFIG}"
    chmod 600 "${SSH_CONFIG}"
    echo "SSH client configuration created"
fi
```

**Opciones explicadas:**

**Host matching:**
```
Host ol8-21-dg2 ol8-21-dg2.localdomain 192.168.56.102
```
- Configuración se aplica cuando conectamos a standby (cualquier forma de nombre)

**StrictHostKeyChecking accept-new:**
- Acepta nuevas host keys automáticamente (primera conexión)
- No pregunta "Are you sure you want to continue connecting? (yes/no)"
- Pero rechaza keys cambiadas (protege contra MITM)

**BatchMode yes:**
- No solicita passwords o confirmaciones interactivas
- Falla inmediatamente si autenticación no funciona
- Necesario para scripts automatizados (cron jobs)

**ConnectTimeout 10:**
- Timeout de conexión de 10 segundos
- Falla rápido si standby no está disponible

**ServerAliveInterval 60:**
- Envía keepalive cada 60 segundos
- Previene que firewall cierre conexión durante rsync largo

**ServerAliveCountMax 3:**
- Si 3 keepalives fallan, cierra conexión
- Total timeout: 3 * 60 = 180 segundos sin respuesta

### Paso 7: Crear Archivo known_hosts

```bash
KNOWN_HOSTS="${SSH_DIR}/known_hosts"
touch "${KNOWN_HOSTS}"
chown oracle:oinstall "${KNOWN_HOSTS}"
chmod 644 "${KNOWN_HOSTS}"
```

**Explicación:**
- Archivo donde SSH guarda host keys de servers conocidos
- Inicialmente vacío (se poblará en primera conexión)
- PowerShell deploy.ps1 agregará host key de standby después

## Archivos Creados/Modificados

### En Primary

| Archivo | Descripción | Permisos |
|---------|-------------|----------|
| `/home/oracle/.ssh/` | Directorio SSH | 700 (drwx------) |
| `/home/oracle/.ssh/id_rsa` | Clave privada | 600 (-rw-------) |
| `/home/oracle/.ssh/id_rsa.pub` | Clave pública | 644 (-rw-r--r--) |
| `/home/oracle/.ssh/config` | Configuración cliente SSH | 600 (-rw-------) |
| `/home/oracle/.ssh/known_hosts` | Host keys conocidas | 644 (-rw-r--r--) |

### En Directorio Compartido

| Archivo | Descripción |
|---------|-------------|
| `/vagrant/ssh_keys/primary_id_rsa.pub` | Clave pública exportada para standby |
| `/vagrant/ssh_keys/standby_id_rsa.pub` | (Creado por standby después) |

## Permisos Críticos

**SSH es MUY estricto con permisos. Si están mal, rechaza las keys:**

```
# Correcto
/home/oracle/.ssh/           - 700 (drwx------)
/home/oracle/.ssh/id_rsa     - 600 (-rw-------)
/home/oracle/.ssh/id_rsa.pub - 644 (-rw-r--r--)
/home/oracle/.ssh/config     - 600 (-rw-------)
/home/oracle/.ssh/authorized_keys - 600 (-rw-------)

# Incorrecto (SSH rechazará)
/home/oracle/.ssh/           - 755 (drwxr-xr-x) ❌
/home/oracle/.ssh/id_rsa     - 644 (-rw-r--r--) ❌
```

## Dependencias

### Prerequisitos

- Usuario `oracle` debe existir
- Paquete `openssh-clients` debe estar instalado (incluido en install_os_packages.sh)
- Synced folder `/vagrant` debe estar disponible

### Workflow de SSH Key Exchange

**Orden de ejecución:**

1. **Primary:** `setup_ssh_keys_auto.sh` (ESTE SCRIPT)
   - Genera keys en primary
   - Exporta `primary_id_rsa.pub` a `/vagrant/ssh_keys/`

2. **Standby:** `setup_ssh_keys_auto.sh` (versión standby)
   - Genera keys en standby
   - Exporta `standby_id_rsa.pub` a `/vagrant/ssh_keys/`
   - Importa `primary_id_rsa.pub` a `/home/oracle/.ssh/authorized_keys`

3. **Primary:** PowerShell deploy.ps1
   - Importa `standby_id_rsa.pub` a `/home/oracle/.ssh/authorized_keys` (en primary)
   - Agrega host key de standby a `/home/oracle/.ssh/known_hosts`
   - Prueba conectividad SSH: `ssh oracle@ol8-21-dg2 'echo test'`

## Verificación

### Verificar Keys Generadas

```bash
vagrant ssh primary
sudo su - oracle

# Verificar que existe clave privada
ls -la ~/.ssh/id_rsa
# -rw------- 1 oracle oinstall 3243 Nov  4 14:35 /home/oracle/.ssh/id_rsa

# Verificar que existe clave pública
ls -la ~/.ssh/id_rsa.pub
# -rw-r--r-- 1 oracle oinstall 742 Nov  4 14:35 /home/oracle/.ssh/id_rsa.pub

# Ver contenido de clave pública
cat ~/.ssh/id_rsa.pub
# ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... oracle@ol8-21-dg1.localdomain
```

### Verificar Configuración Cliente SSH

```bash
cat ~/.ssh/config

# Expected output:
# Host ol8-21-dg2 ol8-21-dg2.localdomain 192.168.56.102
#     StrictHostKeyChecking accept-new
#     BatchMode yes
#     ...
```

### Verificar Clave Exportada

```bash
# Desde host Windows
vagrant ssh primary -c "cat /vagrant/ssh_keys/primary_id_rsa.pub"

# Debe mostrar la misma key que ~/.ssh/id_rsa.pub
```

### Probar Conectividad SSH (Después de Standby Setup)

```bash
# Como usuario oracle
ssh oracle@ol8-21-dg2 'hostname'
# Debe retornar: ol8-21-dg2.localdomain (sin pedir password)

# Test rsync
rsync -avz --dry-run /u02/backup/ oracle@ol8-21-dg2:/u02/backup_from_primary/
```

## Puntos de Fallo Comunes

### 1. Permisos Incorrectos

**Error:**
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for '/home/oracle/.ssh/id_rsa' are too open.
It is required that your private key files are NOT accessible by others.
```

**Solución:**
```bash
chmod 600 /home/oracle/.ssh/id_rsa
chmod 700 /home/oracle/.ssh
```

### 2. SSH Pide Password (No Usa Key)

**Causa:** Clave pública no está en authorized_keys del standby

**Solución:**
```bash
# En standby
cat /vagrant/ssh_keys/primary_id_rsa.pub >> /home/oracle/.ssh/authorized_keys
chmod 600 /home/oracle/.ssh/authorized_keys
```

### 3. Connection Refused

**Error:**
```
ssh: connect to host ol8-21-dg2 port 22: Connection refused
```

**Causa:** sshd no corriendo en standby

**Solución:**
```bash
# En standby
sudo systemctl start sshd
sudo systemctl enable sshd
```

### 4. Host Key Verification Failed

**Error:**
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

**Causa:** Host key de standby cambió (VM recreada)

**Solución:**
```bash
ssh-keygen -R ol8-21-dg2.localdomain
ssh-keygen -R 192.168.56.102
# Reconectar para aceptar nueva key
```

## Importancia para Data Guard

### Backups Redundantes

**Workflow de backup con rsync:**

1. Primary ejecuta RMAN backup → `/u02/backup/`
2. Cron job ejecuta rsync a standby:
   ```bash
   rsync -avz --delete /u02/backup/ oracle@ol8-21-dg2:/u02/backup_from_primary/
   ```
3. Standby tiene copia de backups de primary

**Beneficios:**
- Si primary falla completamente (hardware), backups en standby siguen disponibles
- Permite restore de primary desde standby
- Protección adicional contra ransomware (backups off-site)

### Disaster Recovery Scenarios

**Scenario 1: Primary falla, standby toma over (switchover/failover)**
- Standby se convierte en primary
- Backups del antiguo primary están en el nuevo primary
- Recovery continúa sin interrupción

**Scenario 2: Primary corrupción lógica (usuario elimina tabla)**
- Restore del backup en primary
- Point-in-time recovery
- Backups están disponibles localmente y en standby

**Scenario 3: Ambos nodos fallan (datacenter disaster)**
- Backups en standby pueden copiarse a nuevo hardware
- Restore desde backups del standby

### Automatización sin Intervención Humana

SSH keys permiten que cron jobs ejecuten rsync **sin password:**

```bash
# Cron job (ejecuta automáticamente cada noche)
0 3 * * * /usr/bin/rsync -avz --delete /u02/backup/ oracle@ol8-21-dg2:/u02/backup_from_primary/ >> /home/oracle/logs/rsync.log 2>&1
```

## Próximos Pasos

Después de este script:
1. **Standby setup** ejecuta su versión de setup_ssh_keys_auto.sh
2. **PowerShell deploy.ps1** completa el intercambio de keys
3. **[41 - Install Cron](41-install-cron.md)** instala cron jobs que usan SSH

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador
- **[41 - Install Cron](41-install-cron.md)** - Cron jobs que usan estas keys
- **[59 - Standby Setup SSH](../standby/59-setup-ssh.md)** - Equivalente en standby
- **[71 - RMAN Daily Backup](../../scripts-automatizacion/71-rman-daily-backup.md)** - Usa rsync con SSH

## Código Fuente Completo

Ver archivo: `2-Standby/scripts/primary/setup_ssh_keys_auto.sh` (89 líneas)

---

**Siguiente:** [41 - Install Cron](41-install-cron.md) - **ÚLTIMO PASO** - Instalación de cron jobs para automatización completa.
