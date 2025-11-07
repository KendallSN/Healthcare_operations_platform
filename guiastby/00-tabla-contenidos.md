# 📑 Tabla de Contenidos - Guía Completa de Oracle Data Guard

## Manual de Instalación y Administración del Sistema de Alta Disponibilidad Healthcare Management

**Versión:** 1.0
**Fecha:** Noviembre 2025
**Autores:** Equipo de Base de Datos - Proyecto AdminBD
**Tecnologías:** Oracle Database 21c Enterprise Edition, Data Guard, VirtualBox, Vagrant

---

## 📖 Guía de Lectura

### Para Usuarios Nuevos (Instalación desde Cero)
Recomendamos seguir este orden:
1. Introducción (01)
2. Conceptos Fundamentales (02)
3. Prerequisitos (03)
4. **Cómo Usar** (04) ⭐ **EMPIEZA AQUÍ**
5. Arquitectura del Sistema (05)

### Para Administradores (Operaciones y Mantenimiento)
1. Cómo Usar (04) - para comandos rápidos
2. Operaciones/Monitoreo Diario (90)
3. Troubleshooting (94)
4. Scripts de Automatización (70-75)

### Para Desarrolladores (Entendimiento Profundo)
1. Arquitectura del Sistema (05)
2. Conceptos Avanzados (80-87)
3. Scripts de Ejecución (10-60)

---

## 📚 Índice Completo

### 🏠 Documentación Principal

#### [PROGRESS.md](PROGRESS.md)
**Control de Progreso del Proyecto de Documentación**
- Estado actual de creación de documentos
- Checklist completo
- Instrucciones para continuidad

#### [01 - Introducción](01-introduccion.md)
**Overview del Sistema Healthcare Management con Data Guard**
- Propósito del proyecto
- Qué es Oracle Data Guard
- Audiencia objetivo
- Alcance de la guía
- Requisitos cumplidos (Entregable #2)

**Tiempo de lectura:** ~5 minutos

#### [02 - Conceptos Fundamentales](02-conceptos-fundamentales.md)
**Conceptos Básicos Necesarios para Entender el Sistema**
- ¿Qué es Oracle Database 21c?
- Container Database (CDB) vs Pluggable Database (PDB)
- ¿Qué es Oracle Data Guard?
- Primary vs Standby
- Alta disponibilidad y recuperación ante desastres
- Replicación sincrónica vs asincrónica
- Archive logs (concepto básico)
- Virtualización (VirtualBox y Vagrant)

**Tiempo de lectura:** ~10 minutos

#### [03 - Prerequisitos](03-prerequisitos.md)
**Requisitos de Hardware, Software y Configuración Inicial**
- Requisitos de hardware (RAM, CPU, disco)
- Software necesario:
  - VirtualBox (instalación paso a paso)
  - Vagrant (instalación paso a paso)
  - Oracle Database 21c para Linux
- Descarga de Oracle 21c desde Oracle.com
- Aceptación de términos y licencias
- Organización de archivos del proyecto
- Verificación de la estructura de carpetas
- Comandos de prueba iniciales

**Tiempo de lectura:** ~15 minutos

#### [04 - Cómo Usar](04-como-usar.md) ⭐ **GUÍA PRINCIPAL**
**Guía Completa de Uso de Scripts PowerShell y Vagrant**

**Contenido:**
1. Despliegue Completo (deploy.ps1)
   - Qué hace el script
   - Las 6 fases de despliegue
   - Tiempo esperado y qué observar
   - Logs y verificación
2. Operaciones Individuales con Vagrant
3. Destrucción del Ambiente (destroy.ps1)
4. Provisioners On-Demand
5. Verificación del Sistema
6. Conexiones a las Bases de Datos
7. Scripts de Mantenimiento
8. Monitoreo de Logs en Tiempo Real
9. Troubleshooting Rápido

**Tiempo de lectura:** ~20 minutos | **Tiempo de ejecución:** 50-75 minutos

#### [05 - Arquitectura del Sistema](05-arquitectura-sistema.md)
**Arquitectura Completa del Sistema Data Guard**
- Visión general del proyecto
- Componentes principales
- Flujo de datos entre primary y standby
- Estructura de carpetas del repositorio
- Diagrama de arquitectura
- Tecnologías utilizadas

**Tiempo de lectura:** ~10 minutos

---

### ⚙️ Scripts de Ejecución (Orden de Despliegue)

#### 🔷 PowerShell y Vagrant

##### [10 - Deploy PowerShell](ejecucion/10-deploy-powershell.md)
**Script deploy.ps1 - Orquestación Principal del Despliegue**
- Ubicación: `powershell/deploy.ps1`
- Las 6 fases detalladas
- Verificaciones de prerequisitos
- Manejo de logs
- Control de errores

##### [11 - Fix Line Endings](ejecucion/11-fix-line-endings.md)
**Script fix-line-endings.ps1 - Conversión CRLF a LF**
- Por qué es necesario
- Qué archivos convierte
- Cómo funciona el proceso

##### [20 - Vagrantfile](ejecucion/20-vagrantfile.md)
**Configuración de Vagrantfile - Orquestación de VMs**
- Estructura del Vagrantfile
- Configuración de VMs (primary/standby)
- Synced folders (mapeo de directorios)
- Provisioners y su orden
- Port forwarding

##### [21 - Vagrant Configuración](ejecucion/21-vagrant-configuracion.md)
**Archivos vagrant.yml e install.env**
- Especificaciones de VMs (vagrant.yml)
- Variables de entorno (install.env)
- Configuración de Data Guard
- Configuración de respaldos
- Contraseñas y credenciales

---

#### 🔵 Primary Node - Flujo de Despliegue

##### [30 - Primary Setup](ejecucion/primary/30-primary-setup.md)
**setup.sh - Entry Point del Primary**
- Wrapper de ejecución
- Llamada a root_setup.sh

##### [31 - Primary Root Setup](ejecucion/primary/31-primary-root-setup.md)
**root_setup.sh - Orquestador Principal**
- Secuencia completa de ejecución
- Llamadas a scripts compartidos
- Llamadas a scripts específicos de primary

##### [32 - Prepare Disks](ejecucion/primary/32-prepare-disks.md)
**prepare_u01_u02_disks.sh - Preparación de Almacenamiento**
- Particionamiento de /dev/sdb y /dev/sdc
- Creación de sistemas de archivos XFS
- Montaje de /u01 y /u02
- Configuración de fstab
- Creación de estructura de directorios

##### [33 - Install Packages](ejecucion/primary/33-install-packages.md)
**install_os_packages.sh - Instalación de Prerequisitos de Oracle**
- oracle-database-preinstall-21c
- Paquetes adicionales (48 paquetes)
- Configuración de kernel parameters
- Configuración de límites (ulimits)
- Deshabilitación de SELinux y firewalld

##### [34 - Configure Network](ejecucion/primary/34-configure-network.md)
**Scripts de Configuración de Red**
- configure_hosts_base.sh - /etc/hosts
- configure_hostname.sh - hostname del sistema
- configure_chrony.sh - sincronización de tiempo NTP

##### [35 - Oracle User Environment](ejecucion/primary/35-oracle-user-env.md)
**oracle_user_environment_setup.sh - Configuración del Usuario Oracle**
- Creación de setEnv.sh
- Variables de entorno Oracle
- Configuración de .bash_profile

##### [36 - Install Oracle](ejecucion/primary/36-install-oracle.md)
**oracle_db_software_installation.sh - Instalación de Oracle 21c**
- Copia y descompresión del software
- Response file para instalación silenciosa
- Ejecución de runInstaller
- Scripts root (orainstRoot.sh, root.sh)

##### [37 - Create Database](ejecucion/primary/37-create-database.md)
**oracle_create_database.sh - Creación de Primary Database**
- Configuración de red (tnsnames.ora, listener.ora, sqlnet.ora)
- Inicio del listener
- Creación de CDB+PDB con dbca
- Configuración para Data Guard:
  - PREPARE DATABASE FOR DATA GUARD (comando moderno)
  - Parámetros de archive log
  - Standby redo logs
  - Flashback Database
- Creación de password file

##### [38 - Deploy Schema](ejecucion/primary/38-deploy-schema.md)
**deploy_custom_schema.sh - Despliegue del Esquema Healthcare**
- Apertura de PDB pdb1
- Ejecución de Script_SchemeTableSpace.sql
- Ejecución de ScriptProyectoBD.SQL
- Verificación del esquema HEALTHCENTER

##### [39 - Setup Automation](ejecucion/primary/39-setup-automation.md)
**setup_automation.sh - Configuración de Scripts de Automatización**
- Copia de scripts desde /vagrant_automation
- Asignación de permisos de ejecución
- Creación de directorios de logs

##### [40 - Setup SSH](ejecucion/primary/40-setup-ssh.md)
**setup_ssh_keys_auto.sh - Configuración de Claves SSH**
- Generación de claves RSA 4096-bit
- Exportación de clave pública
- Configuración de SSH config
- Propósito: rsync de backups sin contraseña

##### [41 - Install Cron](ejecucion/primary/41-install-cron.md)
**install_cron_jobs.sh - Instalación de Cron Jobs (Primary)**
- Cron 1: check_log_transport.sh (cada 10 minutos)
- Cron 2: rman_daily_backup.sh (diario 1 AM)
- Cron 3: delete_archives_primary.sh (diario 2 AM)

---

#### 🟢 Standby Node - Flujo de Despliegue

##### [50 - Standby Setup](ejecucion/standby/50-standby-setup.md)
**setup.sh - Entry Point del Standby**
- Wrapper de ejecución
- Llamada a root_setup.sh

##### [51 - Standby Root Setup](ejecucion/standby/51-standby-root-setup.md)
**root_setup.sh - Orquestador Standby**
- Secuencia completa de ejecución (standby)
- Diferencias con primary

##### [52 - Prepare Disks (Standby)](ejecucion/standby/52-prepare-disks.md)
**Preparación de Almacenamiento en Standby**
- Similar a primary
- Directorio adicional: /u02/backup_from_primary

##### [53 - Install Packages (Standby)](ejecucion/standby/53-install-packages.md)
**Instalación de Prerequisitos (Standby)**
- Idéntico a primary

##### [54 - Configure Network (Standby)](ejecucion/standby/54-configure-network.md)
**Configuración de Red (Standby)**
- Hostname: ol8-21-dg2.localdomain
- IP: 192.168.56.102

##### [55 - Oracle User Environment (Standby)](ejecucion/standby/55-oracle-user-env.md)
**Configuración del Usuario Oracle (Standby)**
- setEnv.sh con ORACLE_UNQNAME=cdb1_stby

##### [56 - Install Oracle (Standby)](ejecucion/standby/56-install-oracle.md)
**Instalación de Oracle 21c (Standby)**
- Idéntico a primary

##### [57 - RMAN Duplicate](ejecucion/standby/57-rman-duplicate.md) ⭐ **CRÍTICO**
**oracle_create_database.sh - RMAN DUPLICATE + Data Guard Configuration**
- Configuración de red (tnsnames, listener)
- Creación de estructura de directorios
- Creación de password file (debe coincidir con primary)
- Inicio de instancia auxiliar (nomount)
- **RMAN DUPLICATE FOR STANDBY FROM ACTIVE DATABASE**
  - Copia completa sobre la red
  - Aplicación de archive logs
  - Configuración de parámetros standby
- Habilitación de Flashback en standby
- Configuración de Data Guard Broker:
  - CREATE CONFIGURATION
  - ADD DATABASE
  - ENABLE CONFIGURATION
- Configuración de MAXAVAILABILITY Protection Mode
- Configuración de LogXptMode=FASTSYNC
- Validación completa
- Verificación de replicación del esquema

##### [58 - Setup Automation (Standby)](ejecucion/standby/58-setup-automation.md)
**Scripts de Automatización (Standby)**
- Copia de scripts
- Configuración idéntica a primary

##### [59 - Setup SSH (Standby)](ejecucion/standby/59-setup-ssh.md)
**Configuración de SSH (Standby)**
- Importación de clave pública del primary
- Exportación de host keys del standby
- Autorización para recibir rsync

##### [60 - Install Cron (Standby)](ejecucion/standby/60-install-cron.md)
**Instalación de Cron Jobs (Standby)**
- Cron 1: delete_archives_standby.sh (diario 11 PM)

---

### 🤖 Scripts de Automatización

##### [70 - Check Log Transport](scripts-automatizacion/70-check-log-transport.md)
**check_log_transport.sh - Monitoreo de Replicación**
- Frecuencia: Cada 10 minutos (primary)
- Verificación de gap de archive logs
- Cálculo de lag de aplicación
- Alertas si gap > 10 secuencias
- Consultas a v$archived_log y v$dataguard_stats

##### [71 - RMAN Daily Backup](scripts-automatizacion/71-rman-daily-backup.md)
**rman_daily_backup.sh - Respaldo Diario Automatizado**
- Frecuencia: Diario 1 AM (primary)
- RMAN compressed backupset
- Backup DATABASE + ARCHIVELOG
- Backup CONTROLFILE y SPFILE
- DELETE OBSOLETE (retención 7 días)
- Transferencia a standby vía rsync
- Logs detallados

##### [72 - Delete Archives Primary](scripts-automatizacion/72-delete-archives-primary.md)
**delete_archives_primary.sh - Limpieza de Archives (Primary)**
- Frecuencia: Diario 2 AM (después de backup)
- Retención: 3 días
- Solo elimina archives:
  - Respaldados a disco
  - Aplicados en standby
- Comando RMAN: DELETE ARCHIVELOG ... BACKED UP 1 TIMES TO DISK

##### [73 - Delete Archives Standby](scripts-automatizacion/73-delete-archives-standby.md)
**delete_archives_standby.sh - Limpieza de Archives (Standby)**
- Frecuencia: Diario 11 PM
- Retención: 3 días
- Solo elimina archives aplicados

##### [74 - Verify Data Guard](scripts-automatizacion/74-verify-dataguard.md)
**verify_dataguard.sh - Verificación Completa de Data Guard**
- Ejecución: Manual (on-demand)
- Verifica:
  - Estado de databases (primary/standby)
  - Archive destinations
  - Standby redo logs
  - Log switch history
  - Apply lag
  - Archive gaps
  - Data Guard Broker configuration
  - Replicación del esquema HEALTHCENTER
- Genera reporte completo

##### [75 - Manual Scripts](scripts-automatizacion/75-manual-scripts.md)
**Scripts Manuales Adicionales**
- setup_ssh_keys.sh - Setup manual de SSH
- manual_backup.sh - Backup on-demand
- manual_sync.sh - Forzar log switch
- verify_backup_automation.sh - Verificar proceso de backup

---

### 🎓 Conceptos Avanzados

##### [80 - Oracle CDB/PDB](conceptos-avanzados/80-oracle-cdb-pdb.md)
**Arquitectura Container Database y Pluggable Database**
- ¿Qué es un CDB?
- ¿Qué es un PDB?
- Analogía: edificio de apartamentos
- Ventajas de la arquitectura multitenant
- Conexiones CDB vs PDB
- Uso en este proyecto (cdb1 / pdb1)

##### [81 - Data Guard Conceptos](conceptos-avanzados/81-data-guard-conceptos.md)
**Oracle Data Guard en Profundidad**
- Qué es Data Guard
- Arquitectura de Data Guard
- Procesos: LNS, RFS, MRP
- Physical Standby vs Logical Standby
- Ventajas de Data Guard
- Casos de uso

##### [82 - Modos de Protección](conceptos-avanzados/82-modos-proteccion.md)
**Protection Modes y Transport Modes**
- **Protection Modes:**
  - MAXPROTECTION
  - MAXAVAILABILITY (usado en este proyecto)
  - MAXPERFORMANCE
- **Transport Modes:**
  - SYNC
  - FASTSYNC (usado en este proyecto)
  - ASYNC
- Comparación y trade-offs
- Por qué elegimos MAXAVAILABILITY + FASTSYNC

##### [83 - Archive Logs](conceptos-avanzados/83-archive-logs.md)
**Archive Logs y Replicación**
- ¿Qué son los archive logs?
- Flujo de replicación paso a paso
- Archive lag target (5 minutos)
- Log transport services
- Apply services (MRP)
- Monitoreo de gaps
- Políticas de retención

##### [84 - Flashback Database](conceptos-avanzados/84-flashback-database.md)
**Flashback Database para Data Guard**
- ¿Qué es Flashback Database?
- Diferencia con Flashback Query
- Por qué es crítico para Data Guard
- Escenario: failover y reinstatement
- Con Flashback: minutos
- Sin Flashback: horas (RMAN duplicate)
- Fast Recovery Area (FRA)
- Configuración en este proyecto

##### [85 - Data Guard Broker](conceptos-avanzados/85-data-guard-broker.md)
**Data Guard Broker - Gestión Centralizada**
- ¿Qué es Data Guard Broker?
- Comando moderno: PREPARE DATABASE FOR DATA GUARD
- Configuración automática:
  - ARCHIVELOG mode
  - FORCE LOGGING
  - Standby redo logs
  - Flashback Database
- Comandos dgmgrl
- CREATE CONFIGURATION
- SHOW CONFIGURATION
- VALIDATE DATABASE
- SWITCHOVER y FAILOVER

##### [86 - Networking TNS](conceptos-avanzados/86-networking-tns.md)
**Configuración de Red TNS**
- TNS (Transparent Network Substrate)
- tnsnames.ora - definiciones de conexión
- listener.ora - configuración del listener
- sqlnet.ora - comportamiento de red
- Encriptación AES256
- Checksums SHA256
- Port forwarding (host Windows)
- Conexiones desde Windows host

##### [87 - RMAN Backups](conceptos-avanzados/87-rman-backups.md)
**RMAN (Recovery Manager) y Respaldos**
- ¿Qué es RMAN?
- Configuración de RMAN en este proyecto
- Retention policy (7 días)
- Backup types: full, incremental, archivelog
- Compressed backupsets
- Autobackup de control file
- Delete obsolete
- Transferencia de backups a standby
- Restauración desde standby

---

### 🔨 Operaciones y Mantenimiento

##### [90 - Monitoreo Diario](operaciones/90-monitoreo-diario.md)
**Guía de Monitoreo y Mantenimiento Diario**
- Checklist diario
- Comandos de verificación
- verify_dataguard.sh (uso detallado)
- Interpretación de métricas:
  - Apply lag
  - Transport lag
  - Archive gap
- Queries útiles de DBA
- Umbrales de alerta

##### [91 - Respaldos Manuales](operaciones/91-respaldos-manuales.md)
**Ejecución Manual de Respaldos**
- Cuándo ejecutar respaldos manuales
- Uso de manual_backup.sh
- Comandos RMAN directos
- Verificación de respaldos
- Restauración de prueba
- Backup antes de mantenimiento

##### [92 - Switchover](operaciones/92-switchover.md)
**Procedimiento de Switchover (Cambio Planificado)**
- ¿Qué es switchover?
- Cuándo usarlo (mantenimiento planificado)
- Procedimiento paso a paso:
  1. Verificar sincronización
  2. SWITCHOVER TO cdb1_stby
  3. Verificar nuevo primary
  4. Reconectar aplicaciones
  5. Switchover de regreso (opcional)
- Comandos dgmgrl
- Verificaciones post-switchover

##### [93 - Failover](operaciones/93-failover.md)
**Procedimiento de Failover (Emergencia)**
- ¿Qué es failover?
- Cuándo usarlo (primary caído)
- Diferencia con switchover
- Procedimiento de emergencia:
  1. Confirmar primary no recuperable
  2. FAILOVER TO cdb1_stby
  3. Activar standby como primary
  4. Actualizar conexiones de aplicación
- Reinstatement del antiguo primary:
  - Con Flashback Database (rápido)
  - Sin Flashback (reconstrucción)
- Comandos críticos
- Timeframe esperado

##### [94 - Troubleshooting](operaciones/94-troubleshooting.md)
**Guía de Resolución de Problemas**
- **Problemas Comunes:**
  1. Apply lag aumentando
     - Causas
     - Diagnóstico
     - Soluciones
  2. Archive gap detectado
     - Qué es
     - Cómo identificar
     - Recuperación manual
  3. "ORA-16627: RESYNCHRONIZATION mode"
     - Causa
     - Solución
  4. SSH connection refused
     - Diagnóstico
     - Re-configuración de claves
  5. VirtualBox Guest Additions mismatch
     - Síntomas
     - Instalación de vagrant-vbguest
  6. Oracle no inicia después de vagrant reload
     - Causa (no auto-start)
     - Solución: setup_oracle_autostart provisioner
  7. Synced folders no montan
     - Guest Additions
     - Verificación
  8. Backup falla
     - Logs de RMAN
     - Espacio en disco
     - Permisos
- **Logs Importantes:**
  - Alert log primary: /u01/app/oracle/diag/.../alert_cdb1.log
  - Alert log standby: /u01/app/oracle/diag/.../alert_cdb1.log
  - Listener log
  - Automation logs: /home/oracle/logs/automation/
- **Comandos de Diagnóstico:**
  - SQL*Plus queries
  - dgmgrl commands
  - RMAN list backup
  - Unix commands (df, du, ps, netstat)

---

### 🎯 Conclusión

##### [99 - Conclusiones y Recomendaciones](99-conclusiones-recomendaciones.md)
**Conclusiones Finales y Mejores Prácticas**
- Resumen de lo implementado
- Cumplimiento de requisitos (Entregable #2)
- Ventajas del sistema implementado
- Mejores prácticas:
  - Monitoreo constante
  - Backups regulares
  - Pruebas de switchover periódicas
  - Documentación de cambios
- Recomendaciones para producción:
  - Hardware sizing
  - Red dedicada
  - Almacenamiento enterprise
  - Monitoreo con Enterprise Manager
- Posibles mejoras futuras:
  - Multiple standbys
  - Active Data Guard (read-only queries on standby)
  - Far Sync instance
  - Integración con Cloud
- Referencias adicionales
- Contacto y soporte

---

## 📊 Métricas de la Documentación

| Categoría | Archivos | Páginas Est. | Tiempo Lectura |
|-----------|----------|--------------|----------------|
| Documentación Principal | 5 | ~30 | 60 minutos |
| PowerShell/Vagrant | 4 | ~20 | 40 minutos |
| Scripts Primary | 12 | ~60 | 2 horas |
| Scripts Standby | 11 | ~55 | 1.5 horas |
| Automatización | 6 | ~30 | 1 hora |
| Conceptos Avanzados | 8 | ~40 | 1.5 horas |
| Operaciones | 5 | ~25 | 1 hora |
| **TOTAL** | **51** | **~260** | **~8 horas** |

---

## 🔍 Índice Alfabético de Conceptos

- **Active Data Guard** → 99-conclusiones-recomendaciones.md
- **Apply Lag** → 70-check-log-transport.md, 90-monitoreo-diario.md
- **Archive Gap** → 74-verify-dataguard.md, 94-troubleshooting.md
- **Archive Logs** → 83-archive-logs.md
- **Archive Lag Target** → 37-create-database.md, 83-archive-logs.md
- **Backup** → 71-rman-daily-backup.md, 87-rman-backups.md, 91-respaldos-manuales.md
- **CDB (Container Database)** → 02-conceptos-fundamentales.md, 80-oracle-cdb-pdb.md
- **Chrony** → 34-configure-network.md
- **Cron Jobs** → 41-install-cron.md, 60-install-cron.md
- **Data Guard** → 02-conceptos-fundamentales.md, 81-data-guard-conceptos.md
- **Data Guard Broker** → 57-rman-duplicate.md, 85-data-guard-broker.md
- **dbca** → 37-create-database.md
- **dgmgrl** → 57-rman-duplicate.md, 85-data-guard-broker.md
- **Failover** → 84-flashback-database.md, 93-failover.md
- **FASTSYNC** → 57-rman-duplicate.md, 82-modos-proteccion.md
- **Flashback Database** → 37-create-database.md, 57-rman-duplicate.md, 84-flashback-database.md
- **FRA (Fast Recovery Area)** → 84-flashback-database.md, 87-rman-backups.md
- **Guest Additions** → 94-troubleshooting.md
- **Listener** → 37-create-database.md, 86-networking-tns.md
- **Log Transport** → 70-check-log-transport.md, 83-archive-logs.md
- **MAXAVAILABILITY** → 57-rman-duplicate.md, 82-modos-proteccion.md
- **MRP (Managed Recovery Process)** → 81-data-guard-conceptos.md
- **Oracle 21c** → 02-conceptos-fundamentales.md, 03-prerequisitos.md
- **oracle-database-preinstall-21c** → 33-install-packages.md
- **Password File** → 37-create-database.md, 57-rman-duplicate.md
- **PDB (Pluggable Database)** → 02-conceptos-fundamentales.md, 80-oracle-cdb-pdb.md
- **Port Forwarding** → 20-vagrantfile.md, 86-networking-tns.md
- **PREPARE DATABASE FOR DATA GUARD** → 37-create-database.md, 85-data-guard-broker.md
- **Primary Database** → 37-create-database.md
- **RMAN** → 57-rman-duplicate.md, 71-rman-daily-backup.md, 87-rman-backups.md
- **RMAN DUPLICATE** → 57-rman-duplicate.md
- **rsync** → 71-rman-daily-backup.md, 87-rman-backups.md
- **Standby Database** → 57-rman-duplicate.md
- **Standby Redo Logs** → 37-create-database.md, 85-data-guard-broker.md
- **SSH Keys** → 40-setup-ssh.md, 59-setup-ssh.md
- **Switchover** → 92-switchover.md
- **Synced Folders** → 20-vagrantfile.md
- **TNS** → 86-networking-tns.md
- **tnsnames.ora** → 37-create-database.md, 86-networking-tns.md
- **Troubleshooting** → 94-troubleshooting.md
- **u01, u02** → 32-prepare-disks.md
- **Vagrant** → 02-conceptos-fundamentales.md, 20-vagrantfile.md
- **vagrant.yml** → 21-vagrant-configuracion.md
- **VirtualBox** → 02-conceptos-fundamentales.md, 03-prerequisitos.md
- **XFS** → 32-prepare-disks.md

---

## 📞 Soporte y Contribuciones

Para preguntas, reportes de errores o sugerencias:
- **Repositorio:** [Proyecto AdminBD]
- **Equipo:** Base de Datos - Proyecto Healthcare Management
- **Documentación actualizada:** Noviembre 2025

---

**Nota:** Esta guía documenta un sistema **funcional y probado**. Todos los procedimientos han sido validados en el ambiente de desarrollo/pruebas. Para producción, consultar las recomendaciones en [99 - Conclusiones y Recomendaciones](99-conclusiones-recomendaciones.md).
