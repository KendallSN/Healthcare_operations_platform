# 58 - Setup de Scripts de Automatización (Standby)

## Descripción General

**Archivo:** `2-Standby/scripts/standby/setup_automation.sh`

**Propósito:** Copiar scripts de automatización y monitoreo desde el directorio compartido a `/home/oracle/automation/` del nodo standby.

**Compartido:** Script similar al de primary, pero los scripts copiados se usan diferente.

**Tiempo de ejecución:** ~5 segundos

---

## Código del Script

```bash
#!/bin/bash
# Setup automation scripts on standby

. /vagrant_config/install.env
. /home/oracle/scripts/setEnv.sh

echo "******************************************************************************"
echo "Setup automation scripts on STANDBY." `date`
echo "******************************************************************************"

# Copy automation scripts to oracle user home
mkdir -p /home/oracle/automation

cp /vagrant_automation/*.sh /home/oracle/automation/
chmod +x /home/oracle/automation/*.sh
chown -R oracle:oinstall /home/oracle/automation

# Create logs directory for automation
mkdir -p /home/oracle/logs/automation
chown -R oracle:oinstall /home/oracle/logs

echo "******************************************************************************"
echo "Automation scripts setup complete." `date`
echo "******************************************************************************"
echo "Available scripts in /home/oracle/automation/:"
ls -l /home/oracle/automation/
```

---

## Scripts Copiados

**Desde:** `/vagrant_automation/` (synced folder)
**Hacia:** `/home/oracle/automation/`

**Lista de scripts:**
```bash
/home/oracle/automation/
├── check_log_transport.sh        # Monitoreo lag (NO usado en standby)
├── rman_daily_backup.sh          # Backup diario (NO usado en standby)
├── delete_archives_primary.sh    # Limpieza archives (NO usado en standby)
├── delete_archives_standby.sh    # Limpieza archives ⭐ USADO
├── verify_dataguard.sh           # Verificación completa ⭐ USADO
├── install_cron_jobs.sh          # Instalador de cron ⭐ USADO
├── manual_backup.sh              # Backup on-demand (NO usado en standby)
├── manual_sync.sh                # Forzar sync (NO usado en standby)
└── setup_ssh_keys.sh             # SSH keys (NO usado, hay version auto)
```

---

## Diferencia con Primary

### Scripts que SE USAN en Standby

**1. delete_archives_standby.sh ⭐**
- Propósito: Limpia archive logs aplicados en standby
- Cron job: Diario 11 PM
- Ver [60-install-cron.md](60-install-cron.md)

**2. verify_dataguard.sh ⭐**
- Propósito: Verificación completa de Data Guard
- Ejecutar manualmente cuando sea necesario
- Ver [operaciones/90-monitoreo-diario.md](../../operaciones/90-monitoreo-diario.md)

**3. install_cron_jobs.sh ⭐**
- Propósito: Instalar cron job de limpieza
- Se ejecuta al final de root_setup.sh

### Scripts que NO SE USAN en Standby

**1. check_log_transport.sh**
- Solo en primary (monitorea lag desde primary)
- Standby no necesita monitorear (es el receptor)

**2. rman_daily_backup.sh**
- Solo en primary (hace backups RMAN)
- Standby recibe backups vía rsync, no los genera

**3. delete_archives_primary.sh**
- Solo en primary
- Standby usa `delete_archives_standby.sh`

**4. manual_backup.sh**
- Solo en primary
- Standby no hace backups

**5. manual_sync.sh**
- Solo en primary (fuerza log switch)
- Standby no puede forzar sync (es receptor)

---

## Directorios Creados

```bash
/home/oracle/automation/         # Scripts ejecutables
/home/oracle/logs/automation/    # Logs de los scripts
```

**Estructura de logs:**
```
/home/oracle/logs/automation/
├── delete_archives_standby.log          # Log de limpieza
└── verify_dataguard_TIMESTAMP.log       # Logs de verificación
```

---

## Permisos

```bash
chmod +x /home/oracle/automation/*.sh
chown -R oracle:oinstall /home/oracle/automation
chown -R oracle:oinstall /home/oracle/logs
```

**Permisos:**
- Scripts: `rwxr-xr-x` (755) - Ejecutables
- Directorio: `rwxr-xr-x` (755)
- Owner: oracle:oinstall

---

## Verificación

```bash
# Ver scripts copiados
ls -l /home/oracle/automation/

# Debe mostrar:
total 64
-rwxr-xr-x 1 oracle oinstall 2345 Nov  4 17:30 check_log_transport.sh
-rwxr-xr-x 1 oracle oinstall 3456 Nov  4 17:30 delete_archives_primary.sh
-rwxr-xr-x 1 oracle oinstall 3123 Nov  4 17:30 delete_archives_standby.sh
-rwxr-xr-x 1 oracle oinstall 1234 Nov  4 17:30 install_cron_jobs.sh
-rwxr-xr-x 1 oracle oinstall 2345 Nov  4 17:30 manual_backup.sh
-rwxr-xr-x 1 oracle oinstall 1567 Nov  4 17:30 manual_sync.sh
-rwxr-xr-x 1 oracle oinstall 4567 Nov  4 17:30 rman_daily_backup.sh
-rwxr-xr-x 1 oracle oinstall 2345 Nov  4 17:30 setup_ssh_keys.sh
-rwxr-xr-x 1 oracle oinstall 8901 Nov  4 17:30 verify_dataguard.sh

# Ver logs directory
ls -ld /home/oracle/logs/automation/

# Debe mostrar:
drwxr-xr-x 2 oracle oinstall 4096 Nov  4 17:30 /home/oracle/logs/automation/
```

---

## Uso Posterior

### Script de Limpieza (Automático)

**Instalado vía cron (etapa 60):**
```cron
0 23 * * * /home/oracle/automation/delete_archives_standby.sh
```

**Ejecución manual:**
```bash
vagrant ssh standby
sudo su - oracle
/home/oracle/automation/delete_archives_standby.sh
```

Ver logs:
```bash
cat /home/oracle/logs/automation/delete_archives_standby.log
```

---

### Script de Verificación (Manual)

**Ejecución:**
```bash
vagrant ssh standby -c "/home/oracle/automation/verify_dataguard.sh"
```

**Salida:** Ver [operaciones/90-monitoreo-diario.md](../../operaciones/90-monitoreo-diario.md)

---

## Troubleshooting

### Problema: Scripts no copiados

**Síntoma:**
```bash
ls /home/oracle/automation/
ls: cannot access '/home/oracle/automation/': No such file or directory
```

**Solución:**
```bash
# Re-ejecutar script
sudo su - oracle
sh /vagrant/2-Standby/scripts/standby/setup_automation.sh
```

### Problema: Scripts no ejecutables

**Síntoma:**
```bash
/home/oracle/automation/verify_dataguard.sh
bash: /home/oracle/automation/verify_dataguard.sh: Permission denied
```

**Solución:**
```bash
chmod +x /home/oracle/automation/*.sh
```

---

## Referencia

Para análisis completo de cada script:
- [70-check-log-transport.md](../../scripts-automatizacion/70-check-log-transport.md)
- [73-delete-archives-standby.md](../../scripts-automatizacion/73-delete-archives-standby.md)
- [74-verify-dataguard.md](../../scripts-automatizacion/74-verify-dataguard.md)

---

**Siguiente:** [59 - Setup de SSH Keys](59-setup-ssh.md)
