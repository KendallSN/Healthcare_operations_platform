# 39 - Setup Automation - Configuración de Scripts de Automatización

## Despliegue de Scripts de Monitoreo y Mantenimiento

Este script copia los scripts de automatización desde el directorio compartido de Vagrant a `/home/oracle/automation/`, establece permisos de ejecución y crea directorios para logs. Estos scripts permiten monitorear Data Guard, ejecutar backups y limpiar archive logs automáticamente.

## Ubicación

`2-Standby/scripts/primary/setup_automation.sh`

## Propósito

- **Función principal:** Desplegar scripts de automatización en el nodo primario
- **Responsabilidad:** Copiar, establecer permisos, crear estructura de directorios
- **Scripts desplegados:** 6 scripts de monitoreo, backup y mantenimiento

## Cuándo se Ejecuta

- **Llamado por:** `root_setup.sh`
- **Orden:** Paso 14 de 12 (después de deploy schema)
- **Usuario:** `oracle`
- **Duración:** < 5 segundos

## Flujo de Ejecución

### Paso 1: Cargar Variables

```bash
. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh
```

### Paso 2: Crear Directorio de Automatización

```bash
mkdir -p /home/oracle/automation
```

### Paso 3: Copiar Scripts desde Synced Folder

```bash
cp /vagrant_automation/*.sh /home/oracle/automation/
```

**Scripts copiados (6 scripts):**

1. **check_log_transport.sh** - Monitorea replicación de archive logs
2. **rman_daily_backup.sh** - Respaldo diario RMAN
3. **delete_archives_primary.sh** - Limpieza de archive logs antiguos (primary)
4. **delete_archives_standby.sh** - Limpieza de archive logs antiguos (standby)
5. **verify_dataguard.sh** - Verificación manual de estado Data Guard
6. **manual_backup.sh** - Respaldo manual on-demand
7. **setup_ssh_keys.sh** - Configuración manual de SSH (para troubleshooting)
8. **install_cron_jobs.sh** - Instalador de cron jobs

### Paso 4: Establecer Permisos de Ejecución

```bash
chmod +x /home/oracle/automation/*.sh
```

### Paso 5: Cambiar Ownership

```bash
chown -R oracle:oinstall /home/oracle/automation
```

### Paso 6: Crear Directorio de Logs

```bash
mkdir -p /home/oracle/logs/automation
chown -R oracle:oinstall /home/oracle/logs
```

### Paso 7: Listar Scripts Desplegados

```bash
echo "Available scripts in /home/oracle/automation/:"
ls -l /home/oracle/automation/
```

## Scripts de Automatización Desplegados

### 1. check_log_transport.sh

**Propósito:** Monitorear replicación de archive logs a standby

**Qué hace:**
- Consulta `v$archived_log` para verificar archive logs aplicados
- Detecta gaps en secuencias de archive logs
- Alerta si gap > 10 sequences (configurable)
- Escribe resultados a log file

**Uso manual:**
```bash
/home/oracle/automation/check_log_transport.sh
```

**Salida:**
```
==== Log Transport Check - Mon Nov  4 14:35:22 UTC 2025 ====
Archive Log Status:
- Last archived sequence on primary: 45
- Last applied sequence on standby: 45
- Gap: 0 sequences
- Status: OK

Log Transport: HEALTHY
```

**Configurado en cron:** Cada 10 minutos

### 2. rman_daily_backup.sh

**Propósito:** Respaldo incremental diario con RMAN

**Qué hace:**
- Ejecuta RMAN backup incremental level 1
- Backup de archive logs
- Backup de control file
- Limpia obsolete backups (retention > 7 días)
- Opcional: rsync a standby

**Uso manual:**
```bash
/home/oracle/automation/rman_daily_backup.sh
```

**Comandos RMAN ejecutados:**
```
BACKUP INCREMENTAL LEVEL 1 DATABASE PLUS ARCHIVELOG;
BACKUP CURRENT CONTROLFILE;
DELETE NOPROMPT OBSOLETE;
```

**Configurado en cron:** Diariamente a la 1 AM

### 3. delete_archives_primary.sh

**Propósito:** Limpieza de archive logs antiguos en primary

**Qué hace:**
- Verifica que archive logs fueron aplicados en standby
- Elimina archive logs > 3 días (ARCHIVE_RETENTION_DAYS)
- Usa RMAN para borrado seguro
- Libera espacio en `/u01/oradata/cdb1/arch/`

**Uso manual:**
```bash
/home/oracle/automation/delete_archives_primary.sh
```

**Comandos RMAN:**
```
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-3';
CROSSCHECK ARCHIVELOG ALL;
```

**Configurado en cron:** Diariamente a las 2 AM (después del backup)

### 4. delete_archives_standby.sh

**Propósito:** Limpieza de archive logs en standby

**Similar a delete_archives_primary.sh pero ejecuta en standby**

### 5. verify_dataguard.sh

**Propósito:** Verificación manual completa de Data Guard

**Qué hace:**
- Verifica que ambos nodos están online
- Consulta `v$database`, `v$dataguard_stats`
- Verifica apply lag, transport lag
- Verifica protection mode
- Genera reporte completo

**Uso manual:**
```bash
/home/oracle/automation/verify_dataguard.sh
```

**Salida ejemplo:**
```
===============================================
Data Guard Configuration Verification
===============================================
Primary Database: cdb1
  Status: OPEN
  Role: PRIMARY
  Log Mode: ARCHIVELOG
  Flashback: ON
  Protection Mode: MAXIMUM AVAILABILITY

Standby Database: cdb1_stby
  Status: MOUNTED (STANDBY)
  Role: PHYSICAL STANDBY
  Apply Lag: 0 seconds
  Transport Lag: 2 seconds

Archive Log Gap Analysis:
  Primary Last Sequence: 67
  Standby Last Sequence: 67
  Gap: 0

Overall Status: HEALTHY
===============================================
```

### 6. manual_backup.sh

**Propósito:** Respaldo manual on-demand

**Uso:**
```bash
/home/oracle/automation/manual_backup.sh
```

Ejecuta backup completo (level 0) inmediatamente

### 7. setup_ssh_keys.sh

**Propósito:** Configuración manual de SSH (para troubleshooting)

**Uso si SSH automatizado falla:**
```bash
/home/oracle/automation/setup_ssh_keys.sh
```

### 8. install_cron_jobs.sh

**Propósito:** Instalar/reinstalar cron jobs

**Uso:**
```bash
/home/oracle/automation/install_cron_jobs.sh
```

## Estructura de Directorios Creada

```
/home/oracle/
├── automation/
│   ├── check_log_transport.sh
│   ├── rman_daily_backup.sh
│   ├── delete_archives_primary.sh
│   ├── delete_archives_standby.sh
│   ├── verify_dataguard.sh
│   ├── manual_backup.sh
│   ├── setup_ssh_keys.sh
│   └── install_cron_jobs.sh
└── logs/
    └── automation/
        ├── check_log_transport_YYYYMMDD.log
        ├── rman_backup_YYYYMMDD.log
        ├── delete_archives_YYYYMMDD.log
        └── verify_dataguard_YYYYMMDD.log
```

## Archivos Creados/Modificados

| Directorio/Archivo | Descripción |
|-------------------|-------------|
| `/home/oracle/automation/` | 8 scripts de automatización |
| `/home/oracle/logs/automation/` | Logs de ejecución de scripts |

## Dependencias

### Prerequisitos

- Oracle Database debe estar creada y corriendo
- RMAN debe estar configurado (automático después de dbca)
- setEnv.sh debe estar cargado
- Synced folder `/vagrant_automation/` debe estar disponible

### Scripts Source

Los scripts originales están en:
```
2-Standby/automation/*.sh
```

Mapeado a VM como:
```
/vagrant_automation/*.sh
```

## Verificación

### Verificar Scripts Copiados

```bash
vagrant ssh primary
ls -la /home/oracle/automation/

# Debe mostrar:
# -rwxr-xr-x oracle oinstall check_log_transport.sh
# -rwxr-xr-x oracle oinstall rman_daily_backup.sh
# ...
```

### Ejecutar Verificación Manual

```bash
sudo su - oracle
/home/oracle/automation/verify_dataguard.sh

# (Antes de configurar standby, mostrará que standby no está disponible - esperado)
```

### Probar Check Log Transport

```bash
sudo su - oracle
/home/oracle/automation/check_log_transport.sh
```

## Importancia para Data Guard

### Monitoreo Continuo

**check_log_transport.sh ejecutándose cada 10 minutos garantiza:**
- Detección rápida de problemas de replicación
- Alertas tempranas si standby se atrasa
- Visibilidad de log gaps

### Backups Automáticos

**rman_daily_backup.sh:**
- Protección adicional además de Data Guard
- Permite recovery point-in-time
- Backups se pueden rsync a standby para redundancia

### Gestión de Espacio

**delete_archives_primary.sh:**
- Previene que `/u01` se llene de archive logs
- Limpia solo archive logs ya aplicados en standby
- Evita impactar replicación

### RPO y RTO

- **RPO (Recovery Point Objective):** archive_lag_target=300s = 5 min
- **RTO (Recovery Time Objective):** Flashback + failover < 2 min

Scripts de automatización mejoran ambos:
- Monitoreo detecta problemas antes de que afecten RPO
- Backups permiten recovery si Data Guard falla

## Próximos Pasos

Después de este script:
1. **[40 - Setup SSH](40-setup-ssh.md)** - Configurar SSH para rsync de backups
2. **[41 - Install Cron](41-install-cron.md)** - Instalar cron jobs que ejecutarán estos scripts

## Referencias Cruzadas

### Documentación de Scripts

- **[70 - Check Log Transport](../../scripts-automatizacion/70-check-log-transport.md)** - Detalles de monitoreo
- **[71 - RMAN Daily Backup](../../scripts-automatizacion/71-rman-daily-backup.md)** - Detalles de backups
- **[72 - Delete Archives Primary](../../scripts-automatizacion/72-delete-archives-primary.md)** - Limpieza de logs
- **[74 - Verify Data Guard](../../scripts-automatizacion/74-verify-dataguard.md)** - Script de verificación

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador
- **[41 - Install Cron](41-install-cron.md)** - Instalación de cron jobs

## Código Fuente Completo

Ver archivo: `2-Standby/scripts/primary/setup_automation.sh` (27 líneas)

---

**Siguiente:** [40 - Setup SSH](40-setup-ssh.md) - Configuración de claves SSH para transferencia automatizada de backups.
