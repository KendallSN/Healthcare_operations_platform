# 59 - Setup de SSH Keys (Standby)

## Descripción General

**Archivo:** `2-Standby/scripts/standby/setup_ssh_keys_auto.sh`

**Propósito:** Configurar claves SSH para que primary pueda transferir backups al standby vía rsync sin contraseña.

**Diferencia con Primary:** PRIMARY exporta su clave pública, STANDBY importa la clave pública de primary.

**Tiempo de ejecución:** ~10 segundos (+ tiempo de espera por primary)

---

## Flujo de SSH Keys

```
PRIMARY                             STANDBY

1. Genera par de claves RSA
   ├─ id_rsa (privada)
   └─ id_rsa.pub (pública)

2. Exporta pública a shared folder
   └─> /vagrant/ssh_keys/primary_id_rsa.pub

                                    3. Espera que primary exporte
                                       (timeout 5 minutos)

                                    4. Importa pública de primary
                                       └─> ~/.ssh/authorized_keys

                                    5. Genera propias claves
                                       (para futuro uso)

                                    6. Exporta host keys
                                       └─> /vagrant/ssh_keys/standby_host_keys.txt

7. Importa host keys de standby
   └─> ~/.ssh/known_hosts

8. ✅ SSH sin contraseña:
   primary → standby
```

**Resultado:** Primary puede hacer `rsync` a standby sin pedir password.

---

## Código del Script (Standby)

```bash
#!/bin/bash
# setup_ssh_keys_auto.sh - Automated SSH key import for standby node
# Purpose: Import primary's public key for passwordless rsync backup transfers
# Called by: root_setup.sh during standby VM provisioning

set -e

echo "========================================="
echo "Automated SSH Key Setup - Standby Node"
echo "========================================="

# Source environment variables
if [ -f /vagrant_config/install.env ]; then
    source /vagrant_config/install.env
else
    echo "ERROR: install.env not found!"
    exit 1
fi

# Ensure SSH directory exists with correct permissions
SSH_DIR="/home/oracle/.ssh"
if [ ! -d "${SSH_DIR}" ]; then
    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    chown oracle:oinstall "${SSH_DIR}"
    echo "Created SSH directory: ${SSH_DIR}"
fi

# Wait for primary's public key to be available (with timeout)
SHARED_SSH_DIR="/vagrant/ssh_keys"
PRIMARY_PUBKEY="${SHARED_SSH_DIR}/primary_id_rsa.pub"
TIMEOUT=300  # 5 minutes
ELAPSED=0

echo "Waiting for primary's public key..."
while [ ! -f "${PRIMARY_PUBKEY}" ] && [ ${ELAPSED} -lt ${TIMEOUT} ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "  Waiting... (${ELAPSED}s/${TIMEOUT}s)"
done

if [ ! -f "${PRIMARY_PUBKEY}" ]; then
    echo "ERROR: Primary's public key not found after ${TIMEOUT} seconds!"
    echo "Expected: ${PRIMARY_PUBKEY}"
    exit 1
fi

echo "Primary's public key found!"

# Import primary's public key into authorized_keys
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
if [ ! -f "${AUTHORIZED_KEYS}" ]; then
    touch "${AUTHORIZED_KEYS}"
    chmod 600 "${AUTHORIZED_KEYS}"
    chown oracle:oinstall "${AUTHORIZED_KEYS}"
fi

# Add primary's key if not already present
PRIMARY_KEY_CONTENT=$(cat "${PRIMARY_PUBKEY}")
if grep -q "${PRIMARY_KEY_CONTENT}" "${AUTHORIZED_KEYS}" 2>/dev/null; then
    echo "Primary's public key already in authorized_keys"
else
    cat "${PRIMARY_PUBKEY}" >> "${AUTHORIZED_KEYS}"
    echo "Primary's public key added to authorized_keys"
fi

# Display key fingerprint for verification
echo "Imported key fingerprint:"
ssh-keygen -lf "${PRIMARY_PUBKEY}"

# Create backup storage directory for incoming backups from primary
BACKUP_FROM_PRIMARY="/u02/backup_from_primary"
if [ ! -d "${BACKUP_FROM_PRIMARY}" ]; then
    mkdir -p "${BACKUP_FROM_PRIMARY}"
    chown oracle:oinstall "${BACKUP_FROM_PRIMARY}"
    chmod 755 "${BACKUP_FROM_PRIMARY}"
    echo "Created backup storage directory: ${BACKUP_FROM_PRIMARY}"
fi

# Generate standby's own SSH keys for future use (optional but recommended)
SSH_KEY="${SSH_DIR}/id_rsa"
if [ ! -f "${SSH_KEY}" ]; then
    echo "Generating standby's own SSH key pair..."
    sudo -u oracle ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "oracle@${NODE2_FQ_HOSTNAME}"
    echo "Standby SSH key pair generated successfully"
fi

# Export standby's host keys to shared folder for primary to add to known_hosts (running as root)
STANDBY_HOST_KEYS="${SHARED_SSH_DIR}/standby_host_keys.txt"
ssh-keyscan -H "${NODE2_PUBLIC_IP}" 2>/dev/null > "${STANDBY_HOST_KEYS}"
ssh-keyscan -H "${NODE2_FQ_HOSTNAME}" 2>/dev/null >> "${STANDBY_HOST_KEYS}"
chmod 644 "${STANDBY_HOST_KEYS}"
echo "Standby host keys exported to: ${STANDBY_HOST_KEYS}"

echo "========================================="
echo "Standby SSH Key Setup Complete"
echo "========================================="
echo "Configuration summary:"
echo "  - Primary's public key imported"
echo "  - Backup directory created: ${BACKUP_FROM_PRIMARY}"
echo "  - Standby's SSH keys generated"
echo "  - Host keys exported for primary"
echo ""
echo "Next steps:"
echo "1. Primary will import standby's host keys"
echo "2. PowerShell deploy.ps1 will test SSH connectivity"
echo "3. After SSH test passes, cron jobs will be installed"
echo "========================================="
```

---

## Desglose del Script

### 1. Espera por Clave Pública de Primary

```bash
SHARED_SSH_DIR="/vagrant/ssh_keys"
PRIMARY_PUBKEY="${SHARED_SSH_DIR}/primary_id_rsa.pub"
TIMEOUT=300  # 5 minutes

echo "Waiting for primary's public key..."
while [ ! -f "${PRIMARY_PUBKEY}" ] && [ ${ELAPSED} -lt ${TIMEOUT} ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "  Waiting... (${ELAPSED}s/${TIMEOUT}s)"
done
```

**Por qué esperar:**
- Primary y standby se despliegan en paralelo (casi)
- Primary necesita tiempo para generar y exportar su clave
- Sin espera, standby fallaría inmediatamente

**Timeout de 5 minutos:**
- Primary normalmente exporta en 20-30 minutos
- Standby llega a este punto en ~26 minutos
- Primary ya habrá exportado para entonces

**Si timeout:**
```bash
if [ ! -f "${PRIMARY_PUBKEY}" ]; then
    echo "ERROR: Primary's public key not found after ${TIMEOUT} seconds!"
    exit 1
fi
```
- Significa que primary falló o no terminó
- Standby no puede continuar sin la clave

---

### 2. Importar Clave Pública de Primary

```bash
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
if [ ! -f "${AUTHORIZED_KEYS}" ]; then
    touch "${AUTHORIZED_KEYS}"
    chmod 600 "${AUTHORIZED_KEYS}"
    chown oracle:oinstall "${AUTHORIZED_KEYS}"
fi

# Add primary's key if not already present
PRIMARY_KEY_CONTENT=$(cat "${PRIMARY_PUBKEY}")
if grep -q "${PRIMARY_KEY_CONTENT}" "${AUTHORIZED_KEYS}" 2>/dev/null; then
    echo "Primary's public key already in authorized_keys"
else
    cat "${PRIMARY_PUBKEY}" >> "${AUTHORIZED_KEYS}"
    echo "Primary's public key added to authorized_keys"
fi
```

**Archivo authorized_keys:**
```
# /home/oracle/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... oracle@ol8-21-dg1.localdomain
```

**Permisos críticos:**
- authorized_keys: `600` (rw-------)
- Si tiene permisos incorrectos, SSH rechaza el archivo

**Efecto:**
- Cuando primary se conecta con su clave privada
- Standby verifica contra esta clave pública
- Si coincide, permite acceso sin password

---

### 3. Verificar Fingerprint

```bash
echo "Imported key fingerprint:"
ssh-keygen -lf "${PRIMARY_PUBKEY}"
```

**Salida:**
```
4096 SHA256:abc123def456ghi789jkl012mno345pqr678stu901vwx234yz5 oracle@ol8-21-dg1.localdomain (RSA)
```

**Propósito:**
- Verificación visual de que clave es correcta
- Fingerprint único identifica la clave
- Útil para debugging si SSH falla

---

### 4. Crear Directorio de Backups

```bash
BACKUP_FROM_PRIMARY="/u02/backup_from_primary"
if [ ! -d "${BACKUP_FROM_PRIMARY}" ]; then
    mkdir -p "${BACKUP_FROM_PRIMARY}"
    chown oracle:oinstall "${BACKUP_FROM_PRIMARY}"
    chmod 755 "${BACKUP_FROM_PRIMARY}"
    echo "Created backup storage directory: ${BACKUP_FROM_PRIMARY}"
fi
```

**Directorio exclusivo de standby:**
```
/u02/backup_from_primary/
```

**Uso:**
- Primary hace backup RMAN a `/u02/backup/`
- Primary hace rsync a standby: `oracle@standby:/u02/backup_from_primary/`
- Standby almacena backups del primary aquí

**Por qué separado:**
- Standby podría teoricamente hacer sus propios backups en `/u02/backup/`
- Mejor mantener backups del primary separados
- Más claro qué es qué

---

### 5. Generar Claves Propias de Standby

```bash
SSH_KEY="${SSH_DIR}/id_rsa"
if [ ! -f "${SSH_KEY}" ]; then
    echo "Generating standby's own SSH key pair..."
    sudo -u oracle ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N "" -C "oracle@${NODE2_FQ_HOSTNAME}"
    echo "Standby SSH key pair generated successfully"
fi
```

**Genera:**
```
/home/oracle/.ssh/id_rsa          # Privada
/home/oracle/.ssh/id_rsa.pub      # Pública
```

**Por qué:**
- Standby podría necesitar conectar a otros servidores
- Buena práctica de seguridad
- No se usa actualmente, pero disponible

**Parámetros:**
- `rsa` - Algoritmo RSA
- `4096` - Tamaño de clave (más seguro que 2048)
- `-N ""` - Sin passphrase (para automatización)
- `-C` - Comentario (identifica la clave)

---

### 6. Exportar Host Keys de Standby

```bash
STANDBY_HOST_KEYS="${SHARED_SSH_DIR}/standby_host_keys.txt"
ssh-keyscan -H "${NODE2_PUBLIC_IP}" 2>/dev/null > "${STANDBY_HOST_KEYS}"
ssh-keyscan -H "${NODE2_FQ_HOSTNAME}" 2>/dev/null >> "${STANDBY_HOST_KEYS}"
chmod 644 "${STANDBY_HOST_KEYS}"
echo "Standby host keys exported to: ${STANDBY_HOST_KEYS}"
```

**¿Qué son host keys?**
- Cada servidor SSH tiene su propia clave (no relacionada con usuario)
- Cliente verifica la identidad del servidor con esta clave
- Primera conexión pide confirmar: "Are you sure you want to continue connecting?"

**ssh-keyscan:**
- Obtiene host keys del servidor sin conectar
- `-H` - Hash (ofusca el hostname en known_hosts)

**Archivo exportado:**
```
/vagrant/ssh_keys/standby_host_keys.txt

# Contenido:
|1|abc123...= ecdsa-sha2-nistp256 AAAAE2VjZHNh...
|1|def456...= ssh-rsa AAAAB3NzaC1yc2EAAAADAQA...
|1|ghi789...= ssh-ed25519 AAAAC3NzaC1lZDI1N...
```

**Por qué exportar:**
- Primary necesita agregar estos keys a su `known_hosts`
- Sin esto, primera conexión pediría confirmación manual
- Automatización requiere que primary ya conozca el host

---

## Verificación Post-Configuración

### Verificar que SSH funciona (desde Primary)

**Ejecutado por deploy.ps1 (Fase 5.5):**
```powershell
# Import standby keys to primary
vagrant ssh primary -c "sudo su - oracle -c 'cat /vagrant/ssh_keys/standby_host_keys.txt >> ~/.ssh/known_hosts'"

# Test SSH connectivity
vagrant ssh primary -c "sudo su - oracle -c 'ssh oracle@ol8-21-dg2.localdomain hostname'"

# Debe mostrar: ol8-21-dg2.localdomain
```

**Si funciona:**
```
ol8-21-dg2.localdomain
```

**Si falla:**
```
ssh: connect to host ol8-21-dg2.localdomain port 22: Connection refused
# o
Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

---

### Verificar Manualmente (dentro de VMs)

**Desde primary:**
```bash
vagrant ssh primary
sudo su - oracle

# Test SSH sin password
ssh oracle@ol8-21-dg2.localdomain hostname

# Debe conectar sin pedir password y mostrar:
ol8-21-dg2.localdomain

# Test rsync
rsync -avz /tmp/testfile oracle@ol8-21-dg2.localdomain:/u02/backup_from_primary/
```

**Desde standby:**
```bash
vagrant ssh standby
sudo su - oracle

# Ver authorized_keys
cat ~/.ssh/authorized_keys

# Debe contener la clave de primary:
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... oracle@ol8-21-dg1.localdomain

# Ver backups directory
ls -ld /u02/backup_from_primary/
drwxr-xr-x 2 oracle oinstall 4096 Nov  4 17:30 /u02/backup_from_primary/
```

---

## Archivos Creados

### En Standby

```
/home/oracle/.ssh/
├── authorized_keys          # Contiene clave pública de primary ⭐
├── id_rsa                   # Clave privada de standby
├── id_rsa.pub               # Clave pública de standby
└── known_hosts              # (creado cuando standby conecta a otros)

/u02/backup_from_primary/    # Directorio para backups ⭐
```

### En Shared Folder

```
/vagrant/ssh_keys/
├── primary_id_rsa.pub       # Exportado por primary
└── standby_host_keys.txt    # Exportado por standby ⭐
```

---

## Troubleshooting

### Problema: Timeout esperando clave de primary

**Error:**
```
Waiting for primary's public key...
  Waiting... (300s/300s)
ERROR: Primary's public key not found after 300 seconds!
```

**Causa:**
- Primary no terminó su despliegue
- Primary falló en etapa de SSH keys

**Solución:**
```bash
# Verificar que primary terminó
vagrant status
# primary debe estar "running"

# Verificar que archivo existe
ls -l /vagrant/ssh_keys/primary_id_rsa.pub

# Si no existe, re-provisionar primary
vagrant provision primary --provision-with root_setup
```

---

### Problema: SSH pide password

**Síntoma:**
```bash
ssh oracle@ol8-21-dg2.localdomain
oracle@ol8-21-dg2.localdomain's password:  # ❌ No debería pedir
```

**Causa:**
- Clave pública no en authorized_keys
- Permisos incorrectos

**Solución:**
```bash
# En standby
chmod 700 /home/oracle/.ssh
chmod 600 /home/oracle/.ssh/authorized_keys

# Ver contenido
cat /home/oracle/.ssh/authorized_keys
# Debe contener clave de primary

# Re-importar si está vacío
cat /vagrant/ssh_keys/primary_id_rsa.pub >> /home/oracle/.ssh/authorized_keys
```

---

### Problema: "Host key verification failed"

**Error:**
```bash
ssh oracle@ol8-21-dg2.localdomain
Host key verification failed.
```

**Causa:**
- Primary no tiene host keys de standby en known_hosts

**Solución:**
```bash
# En primary
cat /vagrant/ssh_keys/standby_host_keys.txt >> /home/oracle/.ssh/known_hosts

# O eliminar entrada antigua si cambió
ssh-keygen -R ol8-21-dg2.localdomain
ssh-keygen -R 192.168.56.102
```

---

## Resumen

### Propósito Final

**Permitir transferencia automática de backups:**

```
Primary (daily 1 AM):
  1. rman_daily_backup.sh hace backup RMAN
     └─> /u02/backup/*.bkp

  2. rsync a standby (sin password) ⭐
     └─> oracle@standby:/u02/backup_from_primary/

Standby:
  - Recibe backups del primary
  - Almacena en /u02/backup_from_primary/
  - Puede usar para restore si primary falla completamente
```

### Diferencia con Primary

| Aspecto | Primary | Standby |
|---------|---------|---------|
| **Genera claves** | ✅ Si (id_rsa, id_rsa.pub) | ✅ Si (propias) |
| **Exporta pública** | ✅ Si (para standby) | ❌ No (no necesario) |
| **Importa pública** | ❌ No | ✅ Si (de primary) ⭐ |
| **Exporta host keys** | ❌ No | ✅ Si (para primary) ⭐ |
| **Importa host keys** | ✅ Si (de standby) | ❌ No |
| **Directorio backup** | /u02/backup/ | /u02/backup_from_primary/ ⭐ |

**Flujo:** Primary → Standby (unidireccional)

---

**Siguiente:** [60 - Instalación de Cron Jobs](60-install-cron.md)
