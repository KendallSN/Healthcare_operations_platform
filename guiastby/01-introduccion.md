# 01 - Introducción

## Sistema Healthcare Management con Oracle Data Guard

### 🏥 Bienvenido

Este manual documenta la implementación completa de un **sistema de gestión de centros de salud (Healthcare Management System)** con alta disponibilidad utilizando Oracle Database 21c y Oracle Data Guard.

El sistema permite gestionar:
- **Centros de salud** y sus empleados
- **Usuarios** (médicos y personal administrativo)
- **Escalas de turnos mensuales** (month scales)
- **Planillas de pago** (payrolls)
- **Procedimientos médicos**
- **Documentos** y auditoría

Todo esto replicado en tiempo real a una base de datos standby para garantizar **cero pérdida de datos** y **continuidad del servicio**.

---

## 📋 ¿Qué es Este Proyecto?

Este proyecto es la implementación del **Entregable #2** del curso de Administración de Bases de Datos: **"Respaldos y Base de Datos Standby"**.

### Componentes Principales

1. **Base de Datos Principal (Primary)**
   - Oracle Database 21c Enterprise Edition
   - Container Database (CDB): `cdb1`
   - Pluggable Database (PDB): `pdb1`
   - Esquema de aplicación: `HEALTHCENTER`
   - Servidor: ol8-21-dg1.localdomain (192.168.56.101)

2. **Base de Datos Standby**
   - Réplica física exacta del primary
   - Database unique name: `cdb1_stby`
   - Sincronización en tiempo real vía Oracle Data Guard
   - Servidor: ol8-21-dg2.localdomain (192.168.56.102)

3. **Oracle Data Guard**
   - Protección MAXAVAILABILITY (cero pérdida de datos)
   - Transporte FASTSYNC (sincrónico)
   - Data Guard Broker (gestión centralizada)
   - Switchover y Failover automáticos

4. **Infraestructura Automatizada**
   - 2 VMs Oracle Linux 8 (VirtualBox)
   - Despliegue automatizado con Vagrant
   - Scripts PowerShell de orquestación
   - Backups automáticos diarios con RMAN
   - Monitoreo continuo cada 10 minutos
   - Limpieza automática de archive logs

---

## 🎯 Propósito del Sistema

### Objetivos de Negocio

El sistema healthcare permite:

1. **Gestión de Recursos Humanos**
   - Registro de médicos y personal administrativo
   - Asignación a centros de salud
   - Gestión de posiciones y roles

2. **Planificación de Turnos**
   - Generación automática de escalas mensuales de trabajo
   - Asignación de turnos (diurno, nocturno, feriados)
   - Aprobación de escalas completadas

3. **Gestión de Planillas**
   - Cálculo automático de salarios
   - Movimientos de planilla (ingresos y deducciones)
   - Generación de pagos

4. **Procedimientos Médicos**
   - Registro de procedimientos realizados
   - Cálculo de ingresos por procedimientos
   - Auditoría de actividades médicas

5. **Notificaciones y Auditoría**
   - Sistema de emails automáticos
   - Libro de bitácora (logbook) de todas las acciones
   - Verificación con registro nacional de identificación

### Objetivos Técnicos (Entregable #2)

Cumplir con los requisitos de alta disponibilidad:

✅ **Dos servidores distintos:** Primary y standby en VMs separadas

✅ **Actualización automática cada 5 minutos:** Archive lag target configurado a 300 segundos

✅ **Transferencia de información cada 10 minutos:** Verificación automática vía cron job

✅ **Generación a petición del profesor:** Scripts manuales disponibles

✅ **Oracle 21c y Linux:** Oracle Database 21c Enterprise Edition sobre Oracle Linux 8

✅ **Eliminar archivos transferidos:** Limpieza automática de archives con retención de 3 días

✅ **Respaldo diario automático:** RMAN backup diario a la 1 AM con transferencia a standby

✅ **Manual de instalación completo:** Esta documentación de 50+ archivos markdown

---

## 👥 Audiencia Objetivo

Esta documentación está diseñada para:

### 1. **Administradores de Bases de Datos (DBAs)**
- Necesitan desplegar y mantener el sistema
- Deben entender Data Guard y RMAN
- Responsables de monitoreo y troubleshooting

**Documentos recomendados:**
- [04 - Cómo Usar](04-como-usar.md) - Comandos y operaciones
- [90 - Monitoreo Diario](operaciones/90-monitoreo-diario.md)
- [92 - Switchover](operaciones/92-switchover.md) y [93 - Failover](operaciones/93-failover.md)
- [94 - Troubleshooting](operaciones/94-troubleshooting.md)

### 2. **Desarrolladores de Bases de Datos**
- Necesitan entender el schema healthcare
- Deben comprender el modelo de datos
- Desarrollan procedimientos y funciones PL/SQL

**Documentos recomendados:**
- [05 - Arquitectura del Sistema](05-arquitectura-sistema.md)
- [38 - Deploy Schema](ejecucion/primary/38-deploy-schema.md)
- Archivos en `1-BD/` del repositorio (fuera de guiastby/)

### 3. **Estudiantes y Evaluadores**
- Necesitan entender cómo funciona el sistema completo
- Deben poder replicar el despliegue
- Evalúan el cumplimiento de requisitos

**Documentos recomendados:**
- [01 - Introducción](01-introduccion.md) - Este documento
- [02 - Conceptos Fundamentales](02-conceptos-fundamentales.md)
- [03 - Prerequisitos](03-prerequisitos.md)
- [04 - Cómo Usar](04-como-usar.md)
- Todo en `conceptos-avanzados/` para entendimiento profundo

### 4. **Ingenieros de Infraestructura**
- Necesitan entender la arquitectura de red y VMs
- Deben conocer Vagrant, VirtualBox, y Linux
- Responsables de optimización de recursos

**Documentos recomendados:**
- [20 - Vagrantfile](ejecucion/20-vagrantfile.md)
- [21 - Vagrant Configuración](ejecucion/21-vagrant-configuracion.md)
- Scripts de ejecución en `ejecucion/primary/` y `ejecucion/standby/`

---

## 📖 Alcance de Esta Guía

### Lo que Cubre

✅ **Instalación Completa desde Cero**
- Descarga de Oracle Database 21c
- Instalación de VirtualBox y Vagrant
- Configuración del ambiente
- Despliegue automatizado completo

✅ **Uso del Sistema**
- Comandos PowerShell de despliegue y destrucción
- Comandos Vagrant para gestión de VMs
- Conexiones a bases de datos
- Scripts de mantenimiento

✅ **Entendimiento Profundo**
- Qué hace cada script en orden de ejecución
- Conceptos de Oracle CDB/PDB
- Conceptos de Data Guard (protection modes, transport modes)
- Arquitectura de archive logs y replicación
- Flashback Database
- Data Guard Broker
- RMAN backups

✅ **Operaciones y Mantenimiento**
- Monitoreo diario
- Backups manuales
- Switchover (cambio planificado)
- Failover (emergencia)
- Troubleshooting completo

✅ **Cada Script Explicado**
- 23 scripts de despliegue (PowerShell, Vagrant, shell)
- 6 scripts de automatización (cron jobs, backups, monitoreo)
- Propósito, flujo, dependencias, y troubleshooting de cada uno

### Lo que NO Cubre

❌ **Desarrollo de Aplicación Frontend**
- No hay UI web o aplicación móvil
- Sistema es backend: base de datos + lógica PL/SQL
- Conexión vía SQL*Plus, SQL Developer, o similar

❌ **Personalización Avanzada de Oracle**
- No cubre tuning profundo de Oracle
- No cubre configuraciones enterprise para producción a gran escala
- No cubre integración con Enterprise Manager Cloud Control

❌ **Instalación en Producción Real**
- Este es un ambiente de desarrollo/pruebas
- Producción requiere hardware bare-metal, red dedicada, storage enterprise
- Ver [99 - Conclusiones](99-conclusiones-recomendaciones.md) para recomendaciones de producción

❌ **Código del Schema Healthcare en Detalle**
- El schema se despliega automáticamente desde `1-BD/ScriptProyectoBD.SQL`
- Para entender el código PL/SQL, revisar archivos en `1-BD/` del repositorio
- Esta guía documenta el despliegue y replicación, no la lógica de negocio interna

---

## 🔍 ¿Qué es Oracle Data Guard?

Oracle Data Guard es la **solución de alta disponibilidad y recuperación ante desastres** de Oracle.

### Concepto Simple

Imagina que tienes un cuaderno importante donde escribes todo (la base de datos primary).

**Sin Data Guard:**
- Si pierdes el cuaderno, pierdes todo
- Si el cuaderno se daña, no puedes continuar trabajando

**Con Data Guard:**
- Alguien está copiando cada palabra que escribes en otro cuaderno idéntico (standby)
- Si pierdes el primer cuaderno, usas la copia (failover)
- La copia está sincronizada en tiempo real (cero pérdida de datos)

### Cómo Funciona

1. **Primary Database** recibe todas las transacciones (INSERT, UPDATE, DELETE)
2. Oracle escribe cambios en **redo logs**
3. Cuando un redo log se llena, se convierte en **archive log**
4. Archive logs se **envían automáticamente al standby** vía red
5. **Standby database** recibe los archive logs y los **aplica**
6. Standby queda idéntico al primary

**Resultado:** Dos bases de datos idénticas en servidores diferentes.

### Beneficios

✅ **Alta Disponibilidad:** Si primary falla, standby toma su lugar (downtime de minutos)

✅ **Cero Pérdida de Datos:** Con MAXAVAILABILITY, no se pierde ninguna transacción

✅ **Recuperación Rápida:** Flashback Database permite reinstatement rápido después de failover

✅ **Backups Remotos:** Backups se transfieren a standby (protección geográfica)

✅ **Testing sin Riesgo:** Puedes hacer switchover a standby para mantenimiento del primary

✅ **Reportes sin Impacto:** Queries de lectura pueden ejecutarse en standby (Active Data Guard)

---

## 🏗️ Arquitectura de Alto Nivel

### Infraestructura

```
┌─────────────────────────────────────────────────────────────┐
│                     Windows Host PC                         │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  VirtualBox VM   │         │  VirtualBox VM   │         │
│  │                  │         │                  │         │
│  │  Primary Node    │ ═══════>│  Standby Node    │         │
│  │  ol8-21-dg1      │ Archive │  ol8-21-dg2      │         │
│  │  192.168.56.101  │  Logs   │  192.168.56.102  │         │
│  │                  │ ═══════>│                  │         │
│  │  Oracle 21c      │         │  Oracle 21c      │         │
│  │  CDB: cdb1       │         │  CDB: cdb1_stby  │         │
│  │  PDB: pdb1       │         │  (read-only)     │         │
│  │                  │         │                  │         │
│  │  HEALTHCENTER    │ ═══════>│  HEALTHCENTER    │         │
│  │  schema          │ Replica │  schema          │         │
│  └──────────────────┘         └──────────────────┘         │
│                                                              │
│  PowerShell + Vagrant + VirtualBox                          │
└─────────────────────────────────────────────────────────────┘

Synced Folders:
  - Project root → /vagrant
  - config/ → /vagrant_config
  - software/ → /vagrant_software
  - 2-Standby/automation/ → /vagrant_automation
  - 1-BD/ → /vagrant/1-BD
```

### Flujo de Replicación

```
PRIMARY                           STANDBY

User Transaction
    ↓
Redo Log Buffer
    ↓
Online Redo Log
    ↓
Archive Log ────────────────────→ Receive (RFS)
    ↓                                  ↓
Local Archive                     Remote Archive
                                       ↓
                                  Apply (MRP)
                                       ↓
                                  Datafiles
                                       ↓
                                  Identical Copy
```

### Automatización

```
┌─────────────────────────────────────────────────────────────┐
│                    Automation Layer                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Primary Cron Jobs:                                         │
│  • Every 10 min: Check log transport (monitor replication)  │
│  • Daily 1 AM:   RMAN backup + rsync to standby             │
│  • Daily 2 AM:   Delete old archives (>3 days)              │
│                                                              │
│  Standby Cron Jobs:                                         │
│  • Daily 11 PM:  Delete old archives (>3 days)              │
│                                                              │
│  Manual Scripts:                                            │
│  • verify_dataguard.sh     (health check)                   │
│  • manual_backup.sh        (on-demand backup)               │
│  • manual_sync.sh          (force log switch)               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📚 Estructura de Esta Documentación

Esta guía está organizada en categorías:

### 📘 Documentación Principal (archivos 01-05)
Introducción, conceptos, prerequisitos, guía de uso, y arquitectura.

### ⚙️ Scripts de Ejecución (archivos 10-60)
Cada script del despliegue explicado en el orden que se ejecuta:
- PowerShell/Vagrant (10-21)
- Primary deployment (30-41)
- Standby deployment (50-60)

### 🤖 Scripts de Automatización (archivos 70-75)
Cron jobs, backups, monitoreo, scripts manuales.

### 🎓 Conceptos Avanzados (archivos 80-87)
Explicación profunda de:
- CDB/PDB
- Data Guard
- Protection modes
- Archive logs
- Flashback
- Data Guard Broker
- Networking
- RMAN

### 🔨 Operaciones (archivos 90-94)
Guías operacionales:
- Monitoreo diario
- Backups manuales
- Switchover
- Failover
- Troubleshooting

### 🎯 Conclusión (archivo 99)
Conclusiones, recomendaciones, mejores prácticas.

---

## 🚀 Cómo Usar Esta Documentación

### Para Usuarios Nuevos (Primera Vez)

**Ruta recomendada:**

1. **Lee este documento** (01 - Introducción) para entender el panorama general ✅
2. **Lee [02 - Conceptos Fundamentales](02-conceptos-fundamentales.md)** para entender terminología básica
3. **Lee [03 - Prerequisitos](03-prerequisitos.md)** y asegúrate de cumplirlos
4. **Sigue [04 - Cómo Usar](04-como-usar.md)** para desplegar el sistema ⭐ **EMPIEZA AQUÍ**
5. **Explora el sistema** con comandos de la sección 6 de "Cómo Usar"
6. **Lee [05 - Arquitectura del Sistema](05-arquitectura-sistema.md)** para entender cómo encajan las piezas

**Tiempo estimado:** 2-3 horas de lectura + 60-70 minutos de despliegue automatizado = **~4 horas totales**

### Para Administradores (Ya Conocen Oracle)

**Ruta recomendada:**

1. **Vistazo rápido a [03 - Prerequisitos](03-prerequisitos.md)** (5 min)
2. **Lee [04 - Cómo Usar](04-como-usar.md) completamente** (20 min)
3. **Despliega el sistema** con `.\powershell\deploy.ps1` (60-70 min)
4. **Lee [90 - Monitoreo Diario](operaciones/90-monitoreo-diario.md)** (15 min)
5. **Practica [92 - Switchover](operaciones/92-switchover.md)** (30 min)

**Tiempo estimado:** ~2.5 horas

### Para Desarrolladores (Necesitan Entender el Schema)

**Ruta recomendada:**

1. **Lee [04 - Cómo Usar](04-como-usar.md) secciones 1, 5, 6** (15 min)
2. **Despliega el sistema** (60-70 min)
3. **Conéctate al schema:** `sqlplus HEALTHCENTER/HCApp2025!@localhost:1521/pdb1`
4. **Revisa archivos en `1-BD/` del repositorio** (fuera de guiastby/)
5. **Lee [38 - Deploy Schema](ejecucion/primary/38-deploy-schema.md)** para entender qué se despliega

**Tiempo estimado:** ~2 horas

### Para Estudiantes (Entendimiento Profundo)

**Ruta recomendada:**

1. Lee **toda la documentación principal** (01-05)
2. Despliega el sistema siguiendo [04 - Cómo Usar](04-como-usar.md)
3. Lee **todos los scripts de ejecución** (10-60) en orden
4. Lee **conceptos avanzados** (80-87)
5. Practica **operaciones** (90-94)

**Tiempo estimado:** 8-10 horas de lectura + práctica

---

## ⚠️ Requisitos del Entregable Cumplidos

Esta implementación cumple todos los requisitos especificados en el Entregable #2:

| Requisito | Estado | Referencia |
|-----------|--------|------------|
| Dos servidores (primary/standby) | ✅ | [05 - Arquitectura](05-arquitectura-sistema.md) |
| Actualización cada 5 minutos | ✅ | [37 - Create Database](ejecucion/primary/37-create-database.md) - archive_lag_target=300 |
| Transferencia cada 10 minutos | ✅ | [70 - Check Log Transport](scripts-automatizacion/70-check-log-transport.md) |
| Generación a petición | ✅ | [75 - Manual Scripts](scripts-automatizacion/75-manual-scripts.md) |
| Oracle 21c y Linux | ✅ | Oracle 21c EE sobre Oracle Linux 8 |
| Eliminar archivos transferidos (3 días) | ✅ | [72](scripts-automatizacion/72-delete-archives-primary.md), [73](scripts-automatizacion/73-delete-archives-standby.md) |
| Respaldo diario automático | ✅ | [71 - RMAN Daily Backup](scripts-automatizacion/71-rman-daily-backup.md) |
| Manual de instalación completo | ✅ | Esta documentación (50+ archivos) |
| Conceptos explicados | ✅ | [Conceptos Avanzados](conceptos-avanzados/) |
| Recomendaciones y conclusiones | ✅ | [99 - Conclusiones](99-conclusiones-recomendaciones.md) |

---

## 🎯 Próximos Pasos

**Después de leer esta introducción:**

1. ✅ **Continúa con [02 - Conceptos Fundamentales](02-conceptos-fundamentales.md)**
   - Aprenderás terminología básica de Oracle
   - Entenderás qué es un CDB, PDB, Data Guard, archive logs
   - Es corto (10 minutos) pero esencial

2. ✅ **Lee [03 - Prerequisitos](03-prerequisitos.md)**
   - Verifica que tu PC cumple los requisitos
   - Descarga Oracle Database 21c
   - Instala VirtualBox y Vagrant

3. ✅ **Ejecuta el despliegue con [04 - Cómo Usar](04-como-usar.md)** ⭐
   - Comando: `.\powershell\deploy.ps1`
   - Tiempo: 60-70 minutos (automatizado)
   - Al finalizar: sistema completamente funcional

4. ✅ **Verifica que todo funciona**
   - Conéctate a las bases de datos
   - Ejecuta `verify_dataguard.sh`
   - Prueba el schema healthcare

5. ✅ **Profundiza según tu rol**
   - **DBA:** Lee operaciones (90-94)
   - **Desarrollador:** Revisa scripts de despliegue (30-60)
   - **Estudiante:** Lee conceptos avanzados (80-87)

---

## 📞 Soporte

Si encuentras problemas:

1. **Consulta [94 - Troubleshooting](operaciones/94-troubleshooting.md)**
2. **Revisa logs en `powershell/logs/deploy-TIMESTAMP/`**
3. **Ejecuta `verify_dataguard.sh` para diagnóstico**
4. **Revisa los alert logs de Oracle dentro de las VMs**
5. **Consulta la documentación oficial de Oracle**

---

## 📖 Referencias

- [Documentación Oracle Database 21c](https://docs.oracle.com/en/database/oracle/oracle-database/21/)
- [Oracle Data Guard Concepts and Administration](https://docs.oracle.com/en/database/oracle/oracle-database/21/sbydb/)
- [Oracle RMAN Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/bradv/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [VirtualBox Documentation](https://www.virtualbox.org/wiki/Documentation)

---

**¡Bienvenido al sistema Oracle Data Guard Healthcare Management!**

Este es el inicio de tu viaje para entender y operar un sistema de base de datos de alta disponibilidad de nivel empresarial.

Continúa con [02 - Conceptos Fundamentales](02-conceptos-fundamentales.md) →
