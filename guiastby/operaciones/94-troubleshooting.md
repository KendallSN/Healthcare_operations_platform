# 94 - Troubleshooting Comprehensive

## Guía Completa de Resolución de Problemas

Este documento proporciona soluciones detalladas para todos los problemas comunes que pueden ocurrir en el sistema Oracle Data Guard.

---

## Tabla de Contenidos

1. [Problemas de Deployment](#problemas-de-deployment)
2. [Problemas de Data Guard](#problemas-de-data-guard)
3. [Problemas de Red](#problemas-de-red)
4. [Problemas de Almacenamiento](#problemas-de-almacenamiento)
5. [Problemas de Backup](#problemas-de-backup)
6. [Problemas de Rendimiento](#problemas-de-rendimiento)
7. [Logs para Diagnóstico](#logs-para-diagnóstico)
8. [Queries de Diagnóstico](#queries-de-diagnóstico)

---

## Problemas de Deployment

### Problema 1: "Oracle software not found: software/LINUX.X64_213000_db_home.zip"

**Síntomas:**
```
Error: Could not find Oracle software at: software/LINUX.X64_213000_db_home.zip
Deployment cannot continue.
```

**Causa:** El archivo ZIP de Oracle Database 21c no está en la carpeta `software/`.

**Solución:**

1. Ve a [Oracle Database Downloads](https://www.oracle.com/database/technologies/oracle21c-linux-downloads.html)
2. Acepta los términos de licencia
3. Descarga "Oracle Database 21c (21.3) for Linux x86-64"
   - Archivo: `LINUX.X64_213000_db_home.zip`
   - Tamaño: ~2.9 GB
4. Mueve el archivo descargado a: `C:\Users\[TuUsuario]\DataGripProjects\AdminBDProyecto\software\`
5. Verifica que el archivo esté en la ubicación correcta:
   ```powershell
   ls software\LINUX.X64_213000_db_home.zip
   ```
6. Re-ejecuta el deployment:
   ```powershell
   .\powershell\deploy.ps1
   ```

---

### Problema 2: "VirtualBox service is not running"

**Síntomas:**
```
Error: VirtualBox service is not running.
Please start VirtualBox service and try again.
```

**Causa:** El servicio VBoxSVC no está activo en Windows.

**Solución:**

**Opción 1: Via PowerShell (requiere Admin)**

```powershell
Start-Service -Name "VBoxSVC"
Get-Service -Name "VBoxSVC"  # Verificar
```

**Opción 2: Via Servicios de Windows**

1. Presiona `Win+R`
2. Escribe `services.msc` y presiona Enter
3. Busca "VirtualBox"
4. Click derecho → Iniciar
5. Configura "Tipo de inicio" → Automático

**Opción 3: Reiniciar VirtualBox**

1. Cierra todas las ventanas de VirtualBox
2. Abre VirtualBox nuevamente como Administrador
3. Re-intenta deployment

**Si nada funciona:** Reinicia Windows.

---

### Problema 3: Deploy falla con "line 2: $'\r': command not found"

**Síntomas:**
```
/vagrant/2-Standby/scripts/primary/setup.sh: line 2: $'\r': command not found
/vagrant/2-Standby/scripts/primary/setup.sh: line 5: syntax error near unexpected token `$'{\r''
```

**Causa:** Scripts shell tienen line endings de Windows (CRLF) en lugar de Unix (LF).

**Solución:**

```powershell
# Ejecutar fix-line-endings.ps1
.\powershell\fix-line-endings.ps1

# Verificar
Select-String -Path "2-Standby\scripts\primary\*.sh" -Pattern "`r`n"

# Si no muestra nada, está corregido

# Re-ejecutar deployment
.\powershell\deploy.ps1
```

**Prevención:** Edita scripts shell solo con:
- Visual Studio Code (configura "End of Line" → LF)
- Notepad++ (Edit → EOL Conversion → Unix LF)
- Vim/Nano dentro de las VMs

**NO uses:** Notepad de Windows.

---

### Problema 4: "Failed to mount folders in Linux guest"

**Síntomas:**
```
Vagrant was unable to mount VirtualBox shared folders. This is usually
because the filesystem "vboxsf" is not available. This filesystem is
made available via the VirtualBox Guest Additions.
```

**Causa:** VirtualBox Guest Additions desactualizado o no instalado.

**Solución:**

**Paso 1: Instalar plugin vagrant-vbguest (una vez)**

```bash
vagrant plugin install vagrant-vbguest
```

**Paso 2: Recargar VM (actualizará Guest Additions automáticamente)**

```bash
vagrant reload primary
vagrant reload standby
```

**Si persiste:**

```bash
# Destruir y recrear VMs
vagrant destroy -f
.\powershell\deploy.ps1
```

---

### Problema 5: "SSH connection refused during provisioning"

**Síntomas:**
```
SSH connection refused.
Unable to connect to 192.168.56.101:22
```

**Causa:** VM no ha arrancado completamente o red virtual no configurada.

**Solución:**

**Paso 1: Verificar que VM está corriendo**

```bash
vagrant status
```

**Paso 2: Si muestra "running", espera 30 segundos y reintenta**

**Paso 3: Si persiste, verifica red de VirtualBox**

```powershell
VBoxManage list hostonlyifs
```

Debe mostrar un adaptador en `192.168.56.1`.

**Si no existe:**

```bash
vagrant reload primary
```

**Paso 4: Si aún falla, destruye y recrea**

```bash
vagrant destroy -f primary
vagrant up primary
```

---

### Problema 6: "No space left on device" durante deployment

**Síntomas:**
```
No space left on device
Cannot write to /u01/oradata/
```

**Causa:** Disco virtual /u01 o /u02 quedó sin espacio.

**Diagnóstico:**

```bash
vagrant ssh primary -c "df -h"
```

**Solución:**

**Si /u01 está lleno (>95%):**

Probablemente muchos archive logs acumulados.

```bash
vagrant ssh primary

sudo su - oracle
cd /u01/oradata/cdb1/arch
ls -lh | wc -l  # Contar archivos
# Si hay cientos de archivos

# Eliminar archives viejos
rman target / <<EOF
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'SYSDATE-1';
EXIT;
EOF
```

**Si /u02 está lleno (backups):**

```bash
vagrant ssh primary

sudo su - oracle
rman target / <<EOF
DELETE NOPROMPT OBSOLETE;
EXIT;
EOF
```

**Si root (/) está lleno:**

```bash
# Limpiar logs del sistema
sudo journalctl --vacuum-time=3d
```

---

### Problema 7: "ORA-12541: TNS:no listener" durante deployment

**Síntomas:**
```
ORA-12541: TNS:no listener
Cannot connect to database during schema deployment
```

**Causa:** Listener no está corriendo o no configurado correctamente.

**Solución:**

```bash
vagrant ssh primary

sudo su - oracle

# Verificar estado del listener
lsnrctl status

# Si no está corriendo, iniciar
lsnrctl start

# Verificar que cdb1 y pdb1 están registrados
lsnrctl services

# Debe mostrar:
# Service "cdb1" has X instance(s)
# Service "pdb1" has X instance(s)
```

**Si servicios no aparecen:**

```bash
sqlplus / as sysdba <<EOF
ALTER SYSTEM REGISTER;
EXIT;
EOF

# Esperar 10 segundos
sleep 10

lsnrctl services
```

---

### Problema 8: "ORA-01034: ORACLE not available" durante deployment

**Síntomas:**
```
ORA-01034: ORACLE not available
ORA-27101: shared memory realm does not exist
```

**Causa:** Instancia Oracle no está iniciada.

**Solución:**

```bash
vagrant ssh primary

sudo su - oracle

# Verificar si instancia está corriendo
ps aux | grep pmon

# Si no hay proceso ora_pmon_cdb1, iniciar instancia
sqlplus / as sysdba <<EOF
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
EXIT;
EOF
```

---

## Problemas de Data Guard

### Problema 9: Apply lag aumentando constantemente

**Síntomas:**
```
Apply lag: +00 00:05:32 (5 minutos)
Apply lag: +00 00:08:15 (8 minutos)
Apply lag: +00 00:12:45 (12 minutos)  # Incrementando
```

**Causa Posible 1:** MRP0 (Managed Recovery Process) no está corriendo.

**Diagnóstico:**

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT process, status FROM v\$managed_standby WHERE process='MRP0';
EXIT;
EOF
```

**Si no devuelve rows o status != 'APPLYING_LOG':**

**Solución:**

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

**Verificar:**

```sql
SELECT process, status FROM v$managed_standby WHERE process='MRP0';
```

Debe mostrar: `MRP0 | APPLYING_LOG`

---

**Causa Posible 2:** Standby está abrumado (CPU o disco lento).

**Diagnóstico:**

```bash
vagrant ssh standby

# Verificar CPU
top -bn1 | head -20

# Verificar procesos Oracle
ps aux | grep ora_ | grep cdb1
```

**Si CPU >90% constantemente:**

**Solución:**

Aumentar recursos de VM en `config/vagrant.yml`:

```yaml
node2:
  mem_size: 6144  # Aumentar de 4096 a 6144 (6GB)
  cpus: 3         # Aumentar de 2 a 3 CPUs
```

```bash
vagrant reload standby
```

---

**Causa Posible 3:** Problemas de red causando lag en recepción.

**Diagnóstico:**

```bash
# Verificar conectividad
vagrant ssh primary -c "ping -c 5 192.168.56.102"
```

**Si hay packet loss o latencia >10ms:**

**Solución:**

1. Reiniciar interfaz de red virtual
2. Verificar que no hay otros procesos usando ancho de banda
3. Reiniciar VMs

---

### Problema 10: Archive gap detected

**Síntomas:**
```
SELECT * FROM v$archive_gap;

THREAD# LOW_SEQUENCE# HIGH_SEQUENCE#
------- ------------- --------------
      1           145            147
```

Esto significa que las secuencias 145, 146, 147 faltan en el standby.

**Causa:** Transporte de logs interrumpido (red, listener caído, etc.)

**Solución Manual (Archive Gap Recovery):**

**Paso 1: Identificar archives faltantes en primary**

```bash
vagrant ssh primary

sudo su - oracle
cd /u01/oradata/cdb1/arch
ls -lh *_145_*.arc *_146_*.arc *_147_*.arc
```

**Paso 2: Copiar manualmente a standby**

```bash
scp /u01/oradata/cdb1/arch/*_145_*.arc oracle@ol8-21-dg2.localdomain:/u01/oradata/cdb1/arch/
scp /u01/oradata/cdb1/arch/*_146_*.arc oracle@ol8-21-dg2.localdomain:/u01/oradata/cdb1/arch/
scp /u01/oradata/cdb1/arch/*_147_*.arc oracle@ol8-21-dg2.localdomain:/u01/oradata/cdb1/arch/
```

**Paso 3: Registrar archives en standby**

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
ALTER DATABASE REGISTER PHYSICAL LOGFILE '/u01/oradata/cdb1/arch/<nombre_archivo_145>.arc';
ALTER DATABASE REGISTER PHYSICAL LOGFILE '/u01/oradata/cdb1/arch/<nombre_archivo_146>.arc';
ALTER DATABASE REGISTER PHYSICAL LOGFILE '/u01/oradata/cdb1/arch/<nombre_archivo_147>.arc';
EXIT;
EOF
```

**Paso 4: Verificar que gap se resolvió**

```bash
sqlplus / as sysdba <<EOF
SELECT * FROM v\$archive_gap;
EXIT;
EOF
```

Debe devolver: `no rows selected`

---

### Problema 11: "ORA-16627: No standby databases support the overall protection mode"

**Síntomas:**
```
ORA-16627: No standby databases support the overall protection mode
Configuration Status: ERROR
```

**Causa:** Standby no puede garantizar el modo de protección MAXAVAILABILITY (posiblemente caído o desincronizado).

**Solución:**

**Paso 1: Verificar estado del standby**

```bash
vagrant ssh standby -c "sudo su - oracle -c 'sqlplus / as sysdba <<< \"SELECT database_role, open_mode FROM v\\\$database;\"'"
```

**Si standby está caído:** Iniciarlo.

```bash
vagrant ssh standby

sudo su - oracle
lsnrctl start
sqlplus / as sysdba <<EOF
STARTUP MOUNT;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF
```

**Paso 2: Verificar conectividad primary → standby**

```bash
vagrant ssh primary

sudo su - oracle
tnsping cdb1_stby.world
```

Debe devolver: `OK (Xmsec)`

**Paso 3: Verificar configuración de Data Guard Broker**

```bash
dgmgrl / <<EOF
SHOW DATABASE cdb1_stby;
EXIT;
EOF
```

Si muestra ERROR, reiniciar broker:

```dgmgrl
DISABLE DATABASE cdb1_stby;
ENABLE DATABASE cdb1_stby;
```

---

### Problema 12: "Transport lag" alto pero "apply lag" bajo

**Síntomas:**
```
transport lag: +00 00:05:00  (5 minutos)
apply lag:     +00 00:00:02  (2 segundos)
```

**Causa:** Los logs se están aplicando rápido en standby, pero están llegando lento desde primary (problema de red o LNS process).

**Diagnóstico:**

**Paso 1: Verificar proceso LNS en primary**

```bash
vagrant ssh primary

sudo su - oracle
ps aux | grep lns | grep cdb1
```

Debe mostrar: `ora_lns_cdb1`

**Paso 2: Verificar estado de archive destination**

```bash
sqlplus / as sysdba <<EOF
SELECT dest_name, status, error FROM v\$archive_dest WHERE dest_id=2;
EXIT;
EOF
```

**Si STATUS = 'ERROR':**

Ver columna ERROR para mensaje específico.

**Soluciones comunes:**

- **ERROR = "ORA-12514"**: TNS service no encontrado → Verificar tnsnames.ora
- **ERROR = "ORA-12541"**: Listener caído en standby → Iniciar listener
- **ERROR = "ORA-16047"**: DGID mismatch → Rebuild standby

---

### Problema 13: MRP0 se detiene constantemente

**Síntomas:**
```
MRP0: Background Media Recovery terminated with error 1110
```

**Causa:** Error en aplicación de redo (corrupción, espacio insuficiente, etc.)

**Diagnóstico:**

```bash
vagrant ssh standby

tail -100 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log
```

**Buscar:** `ORA-XXXXX` en las últimas líneas.

**Soluciones según error:**

- **ORA-00312/ORA-00313**: Archivo de log corrupto
  - Solución: Copiar archive log desde primary (ver Problema 10)

- **ORA-01547**: Tablespace sin espacio
  - Solución: Agregar espacio o eliminar datos

- **ORA-00600**: Error interno
  - Solución: Consultar Oracle Support, posiblemente rebuild standby

---

## Problemas de Red

### Problema 14: "ORA-12154: TNS:could not resolve the connect identifier"

**Síntomas:**
```
ORA-12154: TNS:could not resolve the connect identifier specified
```

**Causa:** Entrada no existe en tnsnames.ora o nombre mal escrito.

**Solución:**

**Paso 1: Verificar tnsnames.ora**

```bash
vagrant ssh primary

sudo su - oracle
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep -A 5 cdb1_stby
```

**Debe contener:**

```
CDB1_STBY.WORLD =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = cdb1_stby.world)
    )
  )
```

**Si no existe o está mal:** Re-ejecutar configuración de network.

```bash
cd /vagrant/2-Standby/scripts/primary
./configure_network.sh
```

---

### Problema 15: "ORA-12514: TNS:listener does not currently know of service"

**Síntomas:**
```
ORA-12514: TNS:listener does not currently know of service requested in connect descriptor
```

**Causa:** Servicio no está registrado en listener.

**Solución:**

```bash
vagrant ssh [primary o standby según sea el caso]

sudo su - oracle

# Forzar registro de servicios
sqlplus / as sysdba <<EOF
ALTER SYSTEM REGISTER;
EXIT;
EOF

# Esperar 10 segundos
sleep 10

# Verificar servicios
lsnrctl services
```

**Debe mostrar:**

```
Service "cdb1" has 1 instance(s).
Service "cdb1.world" has 1 instance(s).
Service "pdb1" has 1 instance(s).
```

---

### Problema 16: "ORA-12541: TNS:no listener"

**Síntomas:**
```
ORA-12541: TNS:no listener
```

**Causa:** Listener no está corriendo en el host destino.

**Solución:**

```bash
vagrant ssh [host con problema]

sudo su - oracle
lsnrctl start

# Verificar
lsnrctl status
```

---

### Problema 17: "Connection timeout" al conectar a VMs

**Síntomas:**
```
ssh: connect to host 192.168.56.101 port 22: Connection timed out
```

**Causa:** Firewall bloqueando conexión o VM realmente caída.

**Solución:**

**Paso 1: Verificar que VM está corriendo**

```bash
vagrant status
```

**Si muestra "running":**

**Paso 2: Verificar desde VirtualBox GUI**

1. Abre VirtualBox
2. Busca VM `ol8_21_dg1_primary` o `ol8_21_dg2_standby`
3. Verifica estado

**Si VM está "Running" pero no responde SSH:**

```bash
# Forzar reinicio
vagrant reload [primary o standby]
```

**Si persiste:** Problema de red virtual.

```bash
vagrant destroy -f [primary o standby]
vagrant up [primary o standby]
```

---

## Problemas de Almacenamiento

### Problema 18: "FRA full" (Flash Recovery Area)

**Síntomas:**
```
ORA-19809: limit exceeded for recovery files
ORA-19804: cannot reclaim 52428800 bytes disk space from 107374182400 limit
```

**Causa:** Flash Recovery Area (FRA) llena de archive logs o backups.

**Diagnóstico:**

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
SELECT * FROM v\$recovery_file_dest;
EXIT;
EOF
```

**Si SPACE_USED cerca de SPACE_LIMIT:**

**Solución:**

```bash
rman target / <<EOF
# Eliminar backups obsoletos
DELETE NOPROMPT OBSOLETE;

# Eliminar archives aplicados en standby
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';

EXIT;
EOF
```

**Si no es suficiente, aumentar FRA:**

```sql
ALTER SYSTEM SET db_recovery_file_dest_size=20G SCOPE=BOTH;
```

---

### Problema 19: Disco /u01 o /u02 lleno

**Síntomas:**
```
df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1        99G   95G    0G  98% /u01
```

**Diagnóstico:**

```bash
vagrant ssh primary

# Ver qué está consumiendo espacio
du -sh /u01/*
```

**Típicamente:**

- `/u01/oradata/` → Datafiles (no se pueden eliminar)
- `/u01/oradata/cdb1/arch/` → Archive logs ← **Aquí limpiar**

**Solución:**

```bash
sudo su - oracle

# Ver cuántos archives hay
ls /u01/oradata/cdb1/arch/*.arc | wc -l

# Si hay cientos, eliminar viejos con RMAN
rman target / <<EOF
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-3';
EXIT;
EOF
```

**Para /u02 (backups):**

```bash
sudo su - oracle
rman target / <<EOF
DELETE NOPROMPT OBSOLETE;
EXIT;
EOF
```

---

### Problema 20: "Cannot extend tablespace"

**Síntomas:**
```
ORA-01653: unable to extend table HC_USER by 128 in tablespace HEALTHCENTER_DATA
```

**Causa:** Tablespace sin espacio libre.

**Solución:**

**Opción 1: Agregar espacio al datafile**

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER=pdb1;
ALTER DATABASE DATAFILE '/u01/oradata/CDB1/pdb1/healthcenter_data01.dbf' RESIZE 1G;
EXIT;
EOF
```

**Opción 2: Agregar nuevo datafile**

```sql
ALTER SESSION SET CONTAINER=pdb1;
ALTER TABLESPACE healthcenter_data ADD DATAFILE '/u01/oradata/CDB1/pdb1/healthcenter_data02.dbf' SIZE 500M AUTOEXTEND ON;
```

---

## Problemas de Backup

### Problema 21: RMAN backup falla con "ORA-19502"

**Síntomas:**
```
RMAN-00569: ERROR MESSAGE STACK FOLLOWS
RMAN-00571: ===========================================================
RMAN-03002: failure of backup command at 11/04/2025 15:30:00
ORA-19502: write error on file "", block number  (block size=)
```

**Causa:** Error escribiendo a disco (espacio insuficiente, permisos, disco corrupto).

**Diagnóstico:**

```bash
vagrant ssh primary

# Verificar espacio en /u02 (backups)
df -h /u02

# Verificar permisos
ls -ld /u02/backup
# Debe ser: drwxr-xr-x oracle oinstall
```

**Solución:**

**Si falta espacio:**

```bash
# Limpiar backups viejos
sudo su - oracle
rman target / <<EOF
DELETE NOPROMPT OBSOLETE;
EXIT;
EOF
```

**Si problema de permisos:**

```bash
sudo chown -R oracle:oinstall /u02/backup
sudo chmod 755 /u02/backup
```

---

### Problema 22: Backup transfer a standby falla

**Síntomas:**
```
rsync: connection unexpectedly closed
rsync error: error in rsync protocol data stream (code 12)
```

**Causa:** SSH entre primary y standby no funciona.

**Diagnóstico:**

```bash
vagrant ssh primary

sudo su - oracle
ssh oracle@ol8-21-dg2.localdomain hostname
```

**Si pide contraseña o falla:**

**Solución:**

```bash
# Re-configurar SSH keys
/home/oracle/automation/setup_ssh_keys.sh

# En standby también
vagrant ssh standby -c "/home/oracle/automation/setup_ssh_keys.sh"

# Importar keys al otro nodo
vagrant ssh primary
sudo su - oracle
ssh-keyscan ol8-21-dg2.localdomain >> ~/.ssh/known_hosts
```

---

### Problema 23: "RMAN-06004: ORACLE error from recovery catalog"

**Síntomas:**
```
RMAN-06004: ORACLE error from recovery catalog database
```

**Causa:** Intentando usar recovery catalog pero no está configurado.

**Solución:**

Este proyecto usa RMAN sin catalog (controlfile-based). No necesitas catalog.

**Si el error persiste:**

```bash
rman target / nocatalog <<EOF
LIST BACKUP;
EXIT;
EOF
```

Siempre usa `nocatalog` explícitamente o simplemente `rman target /`.

---

## Problemas de Rendimiento

### Problema 24: Queries muy lentas en primary

**Diagnóstico:**

```bash
vagrant ssh primary

sudo su - oracle

# Verificar CPU y memoria
top

# Verificar procesos Oracle
ps aux | grep ora_ | grep cdb1
```

**Soluciones:**

**Si CPU >90%:**

1. Aumentar CPUs en vagrant.yml
2. Optimizar queries (agregar índices)
3. Reducir carga (menos usuarios concurrentes)

**Si memoria baja:**

```bash
free -h
```

Si "available" < 500MB:

1. Aumentar memoria en vagrant.yml
2. Ajustar SGA/PGA:

```sql
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET sga_target=1500M SCOPE=BOTH;
ALTER SYSTEM SET pga_aggregate_target=500M SCOPE=BOTH;
EXIT;
EOF
```

---

### Problema 25: Redo log switch muy frecuente

**Síntomas:**
```
Thread 1 advanced to log sequence 250
Thread 1 advanced to log sequence 251
Thread 1 advanced to log sequence 252
# Switches cada 1-2 minutos
```

**Causa:** Redo logs muy pequeños para la carga de trabajo.

**Solución:**

Agregar redo log groups más grandes:

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
-- Agregar nuevos grupos de 100MB
ALTER DATABASE ADD LOGFILE GROUP 4 '/u01/oradata/CDB1/redo04.log' SIZE 100M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/u01/oradata/CDB1/redo05.log' SIZE 100M;

-- Después de varios switches, eliminar grupos viejos
-- (espera a que STATUS = INACTIVE)
SELECT group#, status FROM v\$log;

-- Cuando grupos 1-3 estén INACTIVE:
ALTER DATABASE DROP LOGFILE GROUP 1;
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;

EXIT;
EOF
```

**Importante:** Hacer lo mismo en standby.

---

## Logs para Diagnóstico

### Primary Alert Log

```bash
vagrant ssh primary -c "tail -100 /u01/app/oracle/diag/rdbms/cdb1/cdb1/trace/alert_cdb1.log"
```

**Buscar:**
- `ORA-XXXXX` (errores)
- `Errors in file` (archivos de trace con detalles)
- `checkpoint not complete` (redo logs muy pequeños)
- `unable to extend` (espacio insuficiente)

---

### Standby Alert Log

```bash
vagrant ssh standby -c "tail -100 /u01/app/oracle/diag/rdbms/cdb1_stby/cdb1/trace/alert_cdb1.log"
```

**Buscar:**
- `Media Recovery Log` (normal)
- `ORA-XXXXX` (errores)
- `FAL[server]` (fetch archive log - gaps)
- `MRP0: Background Media Recovery terminated` (problemas de apply)

---

### Listener Logs

```bash
# Primary
vagrant ssh primary -c "tail -50 /u01/app/oracle/diag/tnslsnr/ol8-21-dg1/listener/trace/listener.log"

# Standby
vagrant ssh standby -c "tail -50 /u01/app/oracle/diag/tnslsnr/ol8-21-dg2/listener/trace/listener.log"
```

**Buscar:**
- `TNS-XXXXX` (errores de red)
- Connection attempts
- Service registrations

---

### Automation Logs

```bash
# Log transport check
vagrant ssh primary -c "tail -50 /home/oracle/logs/automation/log_transport.log"

# RMAN backups
vagrant ssh primary -c "ls -lt /home/oracle/logs/automation/rman_backup_*.log | head -1 | xargs tail -100"

# Archive cleanup
vagrant ssh primary -c "tail -50 /home/oracle/logs/automation/delete_archives_primary.log"
```

---

### Deployment Logs (desde Windows)

```powershell
# Ver último deployment
ls .\powershell\logs\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Ver logs del deployment
$latest = (ls .\powershell\logs\ | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
Get-Content ".\powershell\logs\$latest\03-primary-vagrant.log" -Tail 100
Get-Content ".\powershell\logs\$latest\04-standby-vagrant.log" -Tail 100
```

---

## Queries de Diagnóstico

### Query 1: Estado General

```sql
-- Ejecutar en primary o standby
SELECT name, db_unique_name, database_role, open_mode, log_mode,
       protection_mode, protection_level, switchover_status,
       flashback_on, force_logging
FROM v$database;
```

---

### Query 2: Archive Destinations (Primary)

```sql
SELECT dest_id, dest_name, status, destination, error,
       log_sequence, fail_sequence
FROM v$archive_dest
WHERE status != 'INACTIVE'
ORDER BY dest_id;
```

---

### Query 3: Apply/Transport Lag (Standby)

```sql
SELECT name, value, unit, time_computed, datum_time
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag', 'apply finish time')
ORDER BY name;
```

---

### Query 4: MRP Status (Standby)

```sql
SELECT process, status, thread#, sequence#, block#, blocks,
       delay_mins, known_agents, active_agents
FROM v$managed_standby
WHERE process IN ('MRP0', 'RFS', 'LNS')
ORDER BY process;
```

---

### Query 5: Archive Gap (Standby)

```sql
SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;

-- Si devuelve rows, hay gap
-- Si no devuelve rows, no hay gap (bueno)
```

---

### Query 6: Log Switch Frequency

```sql
-- Ejecutar en primary
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hour,
       COUNT(*) AS switches,
       ROUND(AVG(blocks * block_size)/1024/1024, 2) AS avg_mb
FROM v$log_history
WHERE first_time > SYSDATE - 1
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY hour DESC;
```

---

### Query 7: Espacio de Tablespaces

```sql
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024, 2) AS used_mb,
       ROUND(MAX(maxbytes)/1024/1024, 2) AS max_mb,
       ROUND(SUM(bytes)/MAX(maxbytes) * 100, 2) AS pct_used
FROM dba_data_files
GROUP BY tablespace_name
ORDER BY pct_used DESC;
```

---

### Query 8: Sesiones Bloqueadas

```sql
SELECT s.sid, s.serial#, s.username, s.program,
       s.blocking_session, s.event, s.wait_time, s.seconds_in_wait
FROM v$session s
WHERE blocking_session IS NOT NULL
ORDER BY seconds_in_wait DESC;
```

---

### Query 9: Top SQL por CPU

```sql
SELECT sql_id, child_number,
       ROUND(elapsed_time/1000000, 2) AS elapsed_sec,
       ROUND(cpu_time/1000000, 2) AS cpu_sec,
       executions,
       ROUND(cpu_time/executions/1000000, 4) AS cpu_per_exec
FROM v$sql
WHERE executions > 0
ORDER BY cpu_time DESC
FETCH FIRST 10 ROWS ONLY;
```

---

### Query 10: Redo Generation Rate

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI') AS time,
       sequence#,
       ROUND(blocks * block_size / 1024 / 1024, 2) AS redo_mb,
       ROUND((next_time - first_time) * 24 * 60, 2) AS minutes
FROM v$log_history
WHERE first_time > SYSDATE - 1/24  -- última hora
ORDER BY first_time DESC;
```

---

## Comandos de Emergencia

### Reiniciar Primary Database

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
EXIT;
EOF

lsnrctl stop
lsnrctl start
```

---

### Reiniciar Standby Database

```bash
vagrant ssh standby

sudo su - oracle
sqlplus / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF

lsnrctl stop
lsnrctl start
```

---

### Rebuild Standby desde Cero (Último Recurso)

```bash
# Desde Windows
vagrant destroy -f standby
vagrant up standby
```

Esto ejecuta todo el proceso de creación de standby (RMAN DUPLICATE), tomando 20-30 minutos.

---

### Restart Data Guard Broker

```bash
vagrant ssh primary

sudo su - oracle
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH;
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH;
EXIT;
EOF

dgmgrl / <<EOF
SHOW CONFIGURATION;
EXIT;
EOF
```

---

## Matriz de Troubleshooting Rápido

| Síntoma | Causa Probable | Acción Inmediata | Referencia |
|---------|----------------|------------------|-----------|
| No conecta a DB | Listener caído | `lsnrctl start` | Problema 7, 16 |
| Apply lag alto | MRP0 no corriendo | `ALTER DATABASE RECOVER...` | Problema 9 |
| Archive gap | Logs no llegaron | Copiar archives manualmente | Problema 10 |
| Disk full | Archives acumulados | `DELETE ARCHIVELOG...` | Problema 18, 19 |
| Backup falla | Espacio insuficiente | `DELETE OBSOLETE` | Problema 21 |
| SSH falla | Keys no configuradas | `setup_ssh_keys.sh` | Problema 22 |
| Configuration WARNING | Standby desincronizado | `SHOW DATABASE VERBOSE` | Problema 11 |
| ORA-12154 | tnsnames.ora incorrecto | Verificar tnsnames.ora | Problema 14 |
| ORA-12514 | Servicio no registrado | `ALTER SYSTEM REGISTER` | Problema 15 |
| ORA-12541 | Listener caído | `lsnrctl start` | Problema 7, 16 |
| ORA-01034 | Instance caída | `STARTUP` | Problema 8 |
| ORA-01653 | Tablespace lleno | `ALTER DATABASE...RESIZE` | Problema 20 |
| ORA-16627 | Standby no soporta protection | Verificar standby operativo | Problema 11 |
| ORA-19809 | FRA llena | `DELETE OBSOLETE` | Problema 18 |
| Line ending error | CRLF en scripts | `fix-line-endings.ps1` | Problema 3 |
| Synced folders fail | Guest Additions viejo | `vagrant-vbguest` plugin | Problema 4 |

---

## Referencias

- [90 - Monitoreo Diario](90-monitoreo-diario.md) - Detección temprana de problemas
- [92 - Switchover](92-switchover.md) - Troubleshooting de switchover
- [93 - Failover](93-failover.md) - Recovery de disaster
- [Oracle Error Messages](https://docs.oracle.com/en/database/oracle/oracle-database/21/errmg/)
- [Data Guard Troubleshooting Guide](https://docs.oracle.com/en/database/oracle/oracle-database/21/sbydb/troubleshooting-oracle-data-guard.html)

---

**Nota Final:** Este documento cubre los problemas más comunes. Para errores específicos no listados, busca el código de error (ORA-XXXXX) en Oracle documentation o My Oracle Support. Documenta problemas nuevos y sus soluciones para futura referencia.
