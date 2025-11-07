# 75 - Manual Scripts

## Scripts de Ejecución Manual para Operaciones Ad-Hoc

Esta sección documenta todos los scripts de automatización diseñados para ejecución MANUAL (no programados en cron). Estos scripts permiten realizar operaciones bajo demanda como backups adicionales, sincronización forzada, configuración de SSH, y verificación de la automatización.

## Scripts Incluidos

1. **setup_ssh_keys.sh** - Configuración de autenticación SSH sin password
2. **manual_backup.sh** - Backup interactivo bajo demanda
3. **manual_sync.sh** - Forzar sincronización de logs inmediata
4. **verify_backup_automation.sh** - Verificar configuración completa de automatización

---

## 1. Setup SSH Keys

### Ubicación
`2-Standby/automation/setup_ssh_keys.sh`

### Propósito

Configurar autenticación basada en claves SSH entre primary y standby para permitir:
- Transferencia automática de backups (rsync sin password)
- Ejecución de comandos remotos sin intervención
- Copia de archives logs en caso de gaps

### Cuándo Ejecutar

- **Primera vez:** Durante deployment inicial (ejecutado por `setup_ssh.sh`)
- **Re-ejecución:** Si claves SSH se corrompen o pierden
- **Nuevas claves:** Si se requiere regenerar por seguridad

### Qué Hace el Script

#### Paso 1: Verificar Clave Existente

```bash
if [ -f /home/oracle/.ssh/id_rsa ]; then
  echo "SSH key already exists"
  read -p "Regenerate SSH key? (yes/no): " regenerate
  if [ "$regenerate" != "yes" ]; then
    echo "Using existing SSH key"
  else
    rm -f /home/oracle/.ssh/id_rsa /home/oracle/.ssh/id_rsa.pub
    ssh-keygen -t rsa -b 4096 -f /home/oracle/.ssh/id_rsa -N ""
  fi
else
  # Generate SSH key
  echo "Generating SSH key..."
  mkdir -p /home/oracle/.ssh
  chmod 700 /home/oracle/.ssh
  ssh-keygen -t rsa -b 4096 -f /home/oracle/.ssh/id_rsa -N ""
fi
```

**Explicación:**
- Verifica si `/home/oracle/.ssh/id_rsa` ya existe
- Si existe, pregunta si regenerar (interactivo)
- Si no existe, genera nueva clave automáticamente
- Usa RSA 4096 bits (muy seguro)
- `-N ""` = sin passphrase (necesario para automatización)

#### Paso 2: Copiar Clave al Standby

```bash
ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub oracle@${NODE2_FQ_HOSTNAME}
```

**Explicación:**
- `ssh-copy-id` copia la clave pública al standby
- Se agregará a `/home/oracle/.ssh/authorized_keys` en standby
- **Requiere password:** Pedirá password de oracle una vez
- Después de esto, conexiones son sin password

#### Paso 3: Probar Conexión

```bash
ssh oracle@${NODE2_FQ_HOSTNAME} "echo 'SSH connection successful from primary to standby'"

if [ $? -eq 0 ]; then
  echo "SSH Key Setup Complete!"
  echo "You can now use passwordless rsync for backup transfers"
else
  echo "ERROR: SSH connection test failed!"
  exit 1
fi
```

**Explicación:**
- Ejecuta comando remoto simple para verificar
- Si funciona sin pedir password = éxito
- Si falla, sale con error

### Ejecución

```bash
# En primary, como usuario oracle
/home/oracle/automation/setup_ssh_keys.sh
```

**Output esperado:**
```
====================================================================
Setup SSH Key-Based Authentication
====================================================================
Generating SSH key...
Generating public/private rsa key pair.
Your identification has been saved in /home/oracle/.ssh/id_rsa
Your public key has been saved in /home/oracle/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx oracle@ol8-21-dg1.localdomain

====================================================================
Copy SSH key to standby server
====================================================================
You will be prompted for the oracle user password on standby

/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/oracle/.ssh/id_rsa.pub"
oracle@ol8-21-dg2.localdomain's password: [ingrese: oracle]

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'oracle@ol8-21-dg2.localdomain'"
and check to make sure that only the key(s) you wanted were added.

====================================================================
Test SSH connection to standby
====================================================================
SSH connection successful from primary to standby

====================================================================
SSH Key Setup Complete!
====================================================================
You can now use passwordless rsync for backup transfers
```

### Verificación

```bash
# Probar conexión SSH sin password
ssh oracle@ol8-21-dg2.localdomain "hostname"
# Debe retornar: ol8-21-dg2.localdomain
# SIN pedir password

# Ver clave pública
cat /home/oracle/.ssh/id_rsa.pub

# Ver claves autorizadas en standby
ssh oracle@ol8-21-dg2 "cat /home/oracle/.ssh/authorized_keys"
```

### Problemas Comunes

**Error: "Permission denied (publickey,password)"**

Causa: Permisos incorrectos en archivos SSH

Solución:
```bash
# En primary
chmod 700 /home/oracle/.ssh
chmod 600 /home/oracle/.ssh/id_rsa
chmod 644 /home/oracle/.ssh/id_rsa.pub

# En standby
ssh oracle@ol8-21-dg2 "chmod 700 /home/oracle/.ssh"
ssh oracle@ol8-21-dg2 "chmod 600 /home/oracle/.ssh/authorized_keys"
```

---

## 2. Manual Backup

### Ubicación
`2-Standby/automation/manual_backup.sh`

### Propósito

Ejecutar backup RMAN completo bajo demanda con confirmaciones interactivas y opción de transferir al standby.

### Cuándo Ejecutar

- **Antes de cambios importantes:** Upgrade de Oracle, cambios de schema
- **Backup adicional:** Más allá del backup diario automático
- **Testing:** Probar proceso de backup
- **Pre-switchover:** Backup final antes de switchover

### Qué Hace el Script

#### Paso 1: Confirmación de Usuario

```bash
BACKUP_TAG="MANUAL_BACKUP_$(date +%Y%m%d_%H%M%S)"

echo "Backup tag: $BACKUP_TAG"
echo "Backup directory: $BACKUP_DIR"
echo ""

read -p "Proceed with backup? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Backup cancelled"
  exit 0
fi
```

**Explicación:**
- Tag único con fecha Y hora: `MANUAL_BACKUP_20251104_143022`
- Pide confirmación antes de proceder
- Solo "yes" exacto procede (seguridad)

#### Paso 2: Ejecución de Backup RMAN

```bash
rman target / <<REOF
RUN {
  ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_TAG}_%U';

  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  BACKUP AS COMPRESSED BACKUPSET
    DATABASE
    PLUS ARCHIVELOG
    TAG ${BACKUP_TAG};

  BACKUP CURRENT CONTROLFILE;

  RELEASE CHANNEL ch1;
}
LIST BACKUP SUMMARY;
EXIT;
REOF
```

**Explicación:**
- Similar a `rman_daily_backup.sh` pero:
  - Un solo canal (más simple, menos rápido)
  - Sin SPFILE backup (opcional)
  - Muestra LIST BACKUP SUMMARY al final

#### Paso 3: Opción de Transferencia

```bash
read -p "Transfer to standby? (yes/no): " transfer

if [ "$transfer" = "yes" ]; then
  echo "Transferring backups..."
  rsync -avz --progress ${BACKUP_DIR}/${BACKUP_TAG}* oracle@${NODE2_FQ_HOSTNAME}:/u02/backup_from_primary/
  echo "Transfer complete"
fi
```

**Explicación:**
- Pregunta si desea transferir
- Solo transfiere archivos de ESTE backup (${BACKUP_TAG}*)
- Muestra progreso durante transferencia

### Ejecución

```bash
# En primary, como usuario oracle
/home/oracle/automation/manual_backup.sh
```

**Output esperado:**
```
====================================================================
Manual RMAN Backup
====================================================================
Backup tag: MANUAL_BACKUP_20251104_143022
Backup directory: /u02/backup

Proceed with backup? (yes/no): yes

Starting backup...

Recovery Manager: Release 21.0.0.0.0 - Production
...
[RMAN output de backup]
...
channel ch1: backup set complete, elapsed time: 00:02:15

List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
45      B  F  A DISK        04-NOV-25              1       1       YES    MANUAL_BACKUP_20251104_143022

====================================================================
Manual Backup Complete
====================================================================

Transfer to standby? (yes/no): yes
Transferring backups...
sending incremental file list
MANUAL_BACKUP_20251104_143022_01v3pq9t_1_1.bkp
         1,234,567 100%   12.34MB/s    0:00:00 (xfr#1, to-chk=0/1)

sent 1,234,567 bytes  received 35 bytes  2,469,204.00 bytes/sec
total size is 1,234,567  speedup is 1.00
Transfer complete
```

### Casos de Uso

**1. Backup Pre-Mantenimiento:**
```bash
# Antes de actualizar esquema
/home/oracle/automation/manual_backup.sh
# yes → yes (backup y transferir)

# Ejecutar cambios
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 @/vagrant/1-BD/cambios.sql

# Si algo sale mal, restore desde MANUAL_BACKUP tag
```

**2. Backup Solo Local (Sin Transferir):**
```bash
/home/oracle/automation/manual_backup.sh
# yes → no (backup sin transferir)
```

**3. Testing de Proceso:**
```bash
# Ejecutar y verificar que funciona
/home/oracle/automation/manual_backup.sh
# yes → yes

# Verificar en RMAN
rman target /
LIST BACKUP TAG 'MANUAL_BACKUP%';
```

---

## 3. Manual Sync

### Ubicación
`2-Standby/automation/manual_sync.sh`

### Propósito

Forzar creación inmediata de archive log y verificar sincronización con standby.

### Cuándo Ejecutar

- **Pre-verificación:** Antes de ejecutar verify_dataguard.sh
- **Testing de replicación:** Probar que Data Guard funciona
- **Después de transacciones:** Forzar replicación de cambios recientes
- **Pre-switchover:** Garantizar que standby tiene todo

### Qué Hace el Script

#### Paso 1: Forzar Log Switch

```bash
sqlplus / as sysdba <<EOF
-- Synchronous command - waits for archiving to complete
ALTER SYSTEM ARCHIVE LOG CURRENT;

-- Verify latest sequence
SELECT MAX(sequence#) AS latest_seq FROM v\$archived_log WHERE dest_id=2;
EXIT;
EOF
```

**Explicación:**

##### ALTER SYSTEM ARCHIVE LOG CURRENT
- Fuerza switch del redo log actual a archive log
- **Síncrono:** Comando espera a que archivado complete
- Garantiza que todos los cambios hasta AHORA están en archive log

##### dest_id=2
- Destino 2 = standby (LOG_ARCHIVE_DEST_2)
- Muestra última secuencia enviada al standby

**Ejemplo de output:**
```
System altered.

LATEST_SEQ
----------
       261
```

#### Paso 2: Verificar Sincronización en Standby

```bash
sqlplus sys/${SYS_PASSWORD}@${NODE2_DB_UNIQUE_NAME}${DB_DOMAIN_STR} as sysdba <<EOF
SET LINESIZE 150
COL name FORMAT A30
COL value FORMAT A30
SELECT name, value, unit FROM v\$dataguard_stats WHERE name IN ('transport lag','apply lag');
EXIT;
EOF
```

**Explicación:**
- Conecta a standby
- Consulta métricas de lag
- Muestra qué tan atrasado está standby

**Ejemplo de output:**
```
NAME                           VALUE              UNIT
------------------------------ ------------------ ---------------
transport lag                  +0 00:00:00        seconds
apply lag                      +0 00:00:05        seconds
```

### Ejecución

```bash
# En primary, como usuario oracle
/home/oracle/automation/manual_sync.sh
```

**Output completo esperado:**
```
====================================================================
Manual Log Archive and Sync
====================================================================

System altered.

LATEST_SEQ
----------
       261

====================================================================
Check standby for sync status
====================================================================

NAME                           VALUE              UNIT
------------------------------ ------------------ ---------------
transport lag                  +0 00:00:00        seconds
apply lag                      +0 00:00:05        seconds

====================================================================
Sync Complete
====================================================================
```

### Casos de Uso

**1. Verificar Replicación Funciona:**
```bash
# Hacer cambio en primary
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 <<EOF
INSERT INTO HC_LOGBOOK (LGB_id, LGB_date, LGB_type, LGB_description)
VALUES (999, SYSDATE, 'TEST', 'Testing replication');
COMMIT;
EXIT;
EOF

# Forzar replicación
/home/oracle/automation/manual_sync.sh

# Verificar en standby (si está en READ ONLY mode)
ssh oracle@ol8-21-dg2 "sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1" <<EOF
SELECT * FROM HC_LOGBOOK WHERE LGB_id = 999;
EXIT;
EOF
```

**2. Pre-Switchover:**
```bash
# Forzar que standby tenga TODO
/home/oracle/automation/manual_sync.sh

# Verificar lag es mínimo (< 10 segundos)
# Proceder con switchover
```

**3. Después de Carga de Datos:**
```bash
# Después de cargar muchos datos
sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1 @/vagrant/1-BD/big_data_load.sql

# Forzar replicación
/home/oracle/automation/manual_sync.sh

# Ver que secuencia subió
```

---

## 4. Verify Backup Automation

### Ubicación
`2-Standby/automation/verify_backup_automation.sh`

### Propósito

Verificar que TODA la configuración de automatización de backups está correcta:
- Claves SSH configuradas
- Conectividad entre nodos
- Directorios de backup existen
- Scripts de automatización están presentes y ejecutables
- Cron jobs instalados
- Logs directory existe

### Cuándo Ejecutar

- **Post-deployment:** Después de `vagrant up` para confirmar setup
- **Troubleshooting:** Si backups automáticos no funcionan
- **Auditoría:** Verificar que todo está configurado correctamente
- **Pre-producción:** Antes de poner sistema en producción

### Qué Hace el Script

El script ejecuta 10 secciones de verificación:

#### 1. SSH Key Configuration

```bash
echo "=== SSH Key Configuration ==="
if [ -f ~/.ssh/id_rsa ]; then
    echo "  [OK] Private key exists"
    KEY_PERMS=$(stat -c "%a" ~/.ssh/id_rsa)
    if [ "$KEY_PERMS" = "600" ]; then
        echo "  [OK] Private key permissions correct (600)"
    else
        echo "  [ERROR] Private key permissions incorrect: $KEY_PERMS (should be 600)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  [ERROR] Private key missing"
    ERRORS=$((ERRORS + 1))
fi
```

**Verifica:**
- Archivo `~/.ssh/id_rsa` existe
- Permisos son 600 (solo usuario puede leer/escribir)
- Archivo `~/.ssh/id_rsa.pub` existe con permisos 644

#### 2. SSH Connectivity Test (Primary)

```bash
if [ "$ORACLE_SID" = "cdb1" ]; then
    echo "=== SSH Connectivity Test ==="
    if ssh -o BatchMode=yes -o ConnectTimeout=10 oracle@${NODE2_FQ_HOSTNAME} "echo 'SSH OK'" 2>/dev/null | grep -q "SSH OK"; then
        echo "  [OK] Passwordless SSH to standby working"
    else
        echo "  [ERROR] Passwordless SSH to standby failed"
        ERRORS=$((ERRORS + 1))
    fi
fi
```

**Verifica:**
- Conexión SSH sin password funciona
- `-o BatchMode=yes` = no pide password interactivo
- Timeout de 10 segundos

#### 3. Authorized Keys (Standby)

```bash
if [ "$ORACLE_SID" != "cdb1" ]; then
    echo "=== Authorized Keys ==="
    if [ -f ~/.ssh/authorized_keys ]; then
        echo "  [OK] authorized_keys file exists"
        # ... verifica permisos y cuenta claves
    fi
fi
```

**Verifica:**
- Archivo `authorized_keys` existe
- Permisos son 600
- Cuenta cuántas claves hay registradas

#### 4. Backup Directories

```bash
echo "=== Backup Directories ==="
if [ "$ORACLE_SID" = "cdb1" ]; then
    if [ -d /u02/backup ]; then
        echo "  [OK] Primary backup directory exists: /u02/backup"
        BACKUP_COUNT=$(ls -1 /u02/backup/*.bkp 2>/dev/null | wc -l)
        BACKUP_SIZE=$(du -sh /u02/backup 2>/dev/null | awk '{print $1}')
        echo "    Backup files: $BACKUP_COUNT"
        echo "    Total size: $BACKUP_SIZE"
    fi
else
    # Similar para standby (/u02/backup_from_primary)
fi
```

**Verifica:**
- Directorio de backup existe
- Cuenta archivos .bkp presentes
- Muestra tamaño total

#### 5. Automation Scripts

```bash
echo "=== Automation Scripts ==="
REQUIRED_SCRIPTS=(
    "check_log_transport.sh"
    "delete_archives_primary.sh"
    "delete_archives_standby.sh"
    "install_cron_jobs.sh"
    "manual_backup.sh"
    "rman_daily_backup.sh"
    "setup_ssh_keys.sh"
    "verify_dataguard.sh"
    "verify_backup_automation.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -x "/home/oracle/automation/$script" ]; then
        echo "  [OK] $script"
    else
        echo "  [ERROR] $script (missing or not executable)"
        ERRORS=$((ERRORS + 1))
    fi
done
```

**Verifica:**
- Todos los scripts existen
- Son ejecutables (chmod +x)

#### 6. Cron Jobs

```bash
echo "=== Cron Jobs ==="
CRON_COUNT=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)
if [ "$ORACLE_SID" = "cdb1" ]; then
    # Primary debe tener 3 cron jobs
    if [ "$CRON_COUNT" -ge 3 ]; then
        echo "  [OK] Primary cron jobs installed ($CRON_COUNT jobs)"
        crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | sed 's/^/    /'
    else
        echo "  [ERROR] Primary cron jobs missing"
        ERRORS=$((ERRORS + 1))
    fi
else
    # Standby debe tener 1 cron job
fi
```

**Verifica:**
- Cron jobs están instalados
- Cantidad correcta (3 en primary, 1 en standby)
- Muestra los cron jobs actuales

#### 7. Logs Directory

```bash
echo "=== Logs Directory ==="
if [ -d /home/oracle/logs/automation ]; then
    echo "  [OK] Logs directory exists"
    LOG_COUNT=$(ls -1 /home/oracle/logs/automation/*.log 2>/dev/null | wc -l)
    echo "    Log files: $LOG_COUNT"
fi
```

**Verifica:**
- Directorio de logs existe
- Cuenta archivos .log
- Muestra logs recientes

#### 8. Oracle Environment

```bash
echo "=== Oracle Environment ==="
if [ -n "$ORACLE_HOME" ]; then
    echo "  [OK] ORACLE_HOME set: $ORACLE_HOME"
else
    echo "  [ERROR] ORACLE_HOME not set"
    ERRORS=$((ERRORS + 1))
fi
```

**Verifica:**
- ORACLE_HOME está definido
- ORACLE_SID está definido

#### 9. Database Connectivity

```bash
echo "=== Database Connectivity ==="
DB_STATUS=$(sqlplus -s / as sysdba << EOF
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT status FROM v\$instance;
EXIT;
EOF
)

if [ "$DB_STATUS" = "OPEN" ] || [ "$DB_STATUS" = "MOUNTED" ]; then
    echo "  [OK] Database status: $DB_STATUS"
fi
```

**Verifica:**
- Puede conectar a database
- Status es OPEN o MOUNTED

#### 10. Data Guard Configuration (Primary)

```bash
if [ "$ORACLE_SID" = "cdb1" ]; then
    echo "=== Data Guard Configuration ==="
    DG_STATUS=$(dgmgrl / "show configuration" 2>/dev/null | grep "Configuration Status" | awk -F: '{print $2}' | tr -d '[:space:]')

    if [ "$DG_STATUS" = "SUCCESS" ]; then
        echo "  [OK] Data Guard configuration status: SUCCESS"
    fi
fi
```

**Verifica:**
- Data Guard Broker configuración es SUCCESS

### Ejecución

```bash
# En primary
/home/oracle/automation/verify_backup_automation.sh

# En standby
ssh oracle@ol8-21-dg2 "/home/oracle/automation/verify_backup_automation.sh"
```

### Output Esperado (Todo OK)

```
========================================================================
BACKUP AUTOMATION VERIFICATION
Host: ol8-21-dg1.localdomain
Date: Tue Nov  4 14:30:00 UTC 2025
========================================================================

=== SSH Key Configuration ===
  [OK] Private key exists
  [OK] Private key permissions correct (600)
  [OK] Public key exists
  [OK] Public key permissions correct (644)

=== SSH Connectivity Test ===
  [OK] Passwordless SSH to standby working

=== Backup Directories ===
  [OK] Primary backup directory exists: /u02/backup
    Backup files: 5
    Total size: 4.5G

=== Automation Scripts ===
  [OK] check_log_transport.sh
  [OK] delete_archives_primary.sh
  [OK] delete_archives_standby.sh
  [OK] install_cron_jobs.sh
  [OK] manual_backup.sh
  [OK] rman_daily_backup.sh
  [OK] setup_ssh_keys.sh
  [OK] verify_dataguard.sh
  [OK] verify_backup_automation.sh
  All automation scripts present and executable

=== Cron Jobs ===
  [OK] Primary cron jobs installed (3 jobs)

    */10 * * * * /home/oracle/automation/check_log_transport.sh
    0 1 * * * /home/oracle/automation/rman_daily_backup.sh
    0 2 * * * /home/oracle/automation/delete_archives_primary.sh

=== Logs Directory ===
  [OK] Logs directory exists: /home/oracle/logs/automation
    Log files: 3
    Recent logs:
      /home/oracle/logs/automation/log_transport.log (15K)
      /home/oracle/logs/automation/rman_backup_20251104.log (125K)
      /home/oracle/logs/automation/delete_archives_primary.log (8K)

=== Oracle Environment ===
  [OK] ORACLE_HOME set: /u01/app/oracle/product/21.0.0/dbhome_1
  [OK] ORACLE_SID set: cdb1

=== Database Connectivity ===
  [OK] Database status: OPEN

=== Data Guard Configuration ===
  [OK] Data Guard configuration status: SUCCESS

========================================================================
VERIFICATION RESULT: [OK] ALL CHECKS PASSED

Backup automation is fully configured and ready.

Automated tasks:
  - Daily backups at 1:00 AM (with auto-transfer to standby)
  - Archive cleanup at 2:00 AM (after standby confirmation)
  - Log transport monitoring every 10 minutes
========================================================================
```

### Output con Problemas

```
========================================================================
VERIFICATION RESULT: [FAIL] FOUND 2 ERROR(S)

Please review the errors above and fix before production use.

Common fixes:
  - Missing cron jobs: /home/oracle/automation/install_cron_jobs.sh
  - SSH keys missing: /home/oracle/automation/setup_ssh_keys.sh
========================================================================
```

### Casos de Uso

**1. Post-Deployment:**
```bash
# Después de vagrant up primary
vagrant ssh primary -c "/home/oracle/automation/verify_backup_automation.sh"

# Si todo OK, deployment exitoso
```

**2. Troubleshooting de Backups:**
```bash
# Si backups automáticos no funcionan
/home/oracle/automation/verify_backup_automation.sh | grep ERROR

# Fix problemas encontrados
# Re-ejecutar hasta 0 errores
```

**3. Documentación:**
```bash
# Generar reporte de estado
/home/oracle/automation/verify_backup_automation.sh > /vagrant/backup_automation_status.txt

# Incluir en documentación de proyecto
```

---

## Resumen de Scripts Manuales

| Script | Propósito | Cuándo Usar | Nivel |
|--------|-----------|-------------|-------|
| setup_ssh_keys.sh | Configurar SSH | Primera vez, re-config | Básico |
| manual_backup.sh | Backup on-demand | Pre-mantenimiento, testing | Intermedio |
| manual_sync.sh | Forzar replicación | Pre-verificación, testing | Básico |
| verify_backup_automation.sh | Verificar config completa | Post-deployment, troubleshooting | Avanzado |

## Workflow Típico

### Deployment Inicial

```bash
1. vagrant up primary
2. vagrant ssh primary
3. /home/oracle/automation/setup_ssh_keys.sh         # Configurar SSH
4. /home/oracle/automation/verify_backup_automation.sh  # Verificar todo
```

### Pre-Mantenimiento

```bash
1. /home/oracle/automation/manual_backup.sh          # Backup completo
2. Realizar mantenimiento
3. /home/oracle/automation/manual_sync.sh            # Sincronizar cambios
4. /home/oracle/automation/verify_dataguard.sh       # Verificar estado
```

### Troubleshooting

```bash
1. /home/oracle/automation/verify_backup_automation.sh  # Identificar problemas
2. Fix según errores encontrados
3. /home/oracle/automation/manual_backup.sh          # Probar backup
4. /home/oracle/automation/manual_sync.sh            # Probar replicación
```

## Referencias Cruzadas

### Documentos Relacionados

- **[40-setup-ssh.md](../ejecucion/primary/40-setup-ssh.md)** - Setup SSH automático
- **[41-install-cron.md](../ejecucion/primary/41-install-cron.md)** - Instalación cron jobs
- **[71-rman-daily-backup.md](71-rman-daily-backup.md)** - Backup automático
- **[74-verify-dataguard.md](74-verify-dataguard.md)** - Verificación completa
- **[91-respaldos-manuales.md](../operaciones/91-respaldos-manuales.md)** - Procedimientos de restore

### Scripts Relacionados

**Automatizados (cron):**
```bash
/home/oracle/automation/check_log_transport.sh       # Cada 10 min
/home/oracle/automation/rman_daily_backup.sh         # Diario 1 AM
/home/oracle/automation/delete_archives_primary.sh   # Diario 2 AM
/home/oracle/automation/delete_archives_standby.sh   # Diario 11 PM
```

**Manuales (este documento):**
```bash
/home/oracle/automation/setup_ssh_keys.sh
/home/oracle/automation/manual_backup.sh
/home/oracle/automation/manual_sync.sh
/home/oracle/automation/verify_backup_automation.sh
```

**Verificación:**
```bash
/home/oracle/automation/verify_dataguard.sh
```

---

**Última Actualización:** 2025-11-04
**Autor:** Claude (Subagente 4)
**Versión:** 1.0
