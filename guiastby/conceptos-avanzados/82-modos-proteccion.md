# 82 - Modos de Protección y Transporte en Oracle Data Guard

## Modos de Protección (Protection Modes) y Modos de Transporte (Transport Modes)

Este documento explica en profundidad los diferentes modos de protección y transporte disponibles en Oracle Data Guard, por qué existen diferentes opciones, cuáles usamos en este proyecto, y las implicaciones de cada elección.

---

## 📋 Tabla de Contenidos

1. [Introduction](#introducción)
2. [Modos de Protección (Protection Modes)](#modos-de-protección-protection-modes)
3. [Modos de Transporte (Transport Modes)](#modos-de-transporte-transport-modes)
4. [Configuración en Este Proyecto](#configuración-en-este-proyecto)
5. [Comparaciones y Trade-offs](#comparaciones-y-trade-offs)
6. [RPO y RTO](#rpo-y-rto)
7. [Cambio de Modos](#cambio-de-modos)
8. [Mejores Prácticas](#mejores-prácticas)

---

## Introducción

Oracle Data Guard ofrece diferentes **niveles de protección de datos** y **métodos de transporte de redo** para adaptarse a diferentes necesidades de negocio, tolerancia a pérdida de datos, y restricciones de red.

La elección correcta depende de:
- **RPO (Recovery Point Objective):** Cuántos datos puedes permitirte perder
- **RTO (Recovery Time Objective):** Cuánto downtime es aceptable
- **Rendimiento:** Impacto en el primary
- **Red:** Ancho de banda y latencia disponibles
- **Costo:** Recursos necesarios

---

## Modos de Protección (Protection Modes)

Los **Protection Modes** definen el **nivel de protección de datos** entre primary y standby.

### MAXPROTECTION

**Definición:** Cero pérdida de datos **garantizada**.

**Funcionamiento:**
- Primary **debe** recibir confirmación del standby antes de hacer commit
- Si standby no está disponible, **primary se apaga** (shutdown)
- Transporte: SYNC o FASTSYNC (síncrono)

**Garantías:**
- ✅ **Zero Data Loss:** 100% garantizado
- ✅ **RPO = 0:** Nunca pierdes datos

**Desventajas:**
- ❌ **Disponibilidad comprometida:** Primary se cae si standby falla
- ❌ **Requiere red perfecta:** Cualquier problema de red tumba el primary
- ❌ **Impacto en rendimiento:** Esperas síncronas

**Cuándo usar:**
- Datos absolutamente críticos (finanzas, salud crítica)
- Red dedicada y redundante
- Aceptas downtime del primary si falla red
- Cumplimiento regulatorio estricto

**Ejemplo de configuración:**
```dgmgrl
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPROTECTION;
```

---

### MAXAVAILABILITY ⭐ (Usado en este proyecto)

**Definición:** Balance entre protección de datos y disponibilidad.

**Funcionamiento:**
- Primary intenta operar **síncronamente** con standby
- Si standby no disponible, **cambia a asíncrono** temporalmente
- Primary **nunca se apaga** por problemas de standby
- Al restaurar conectividad, vuelve a síncrono

**Garantías:**
- ✅ **Zero Data Loss (cuando standby disponible):** RPO = 0
- ✅ **Disponibilidad del primary:** No se cae por problemas de standby
- ⚠️ **Posible pérdida de datos:** Solo si primary falla **mientras** está en modo asíncrono

**Ventajas:**
- ✅ Balance óptimo: protección + disponibilidad
- ✅ Primary siempre operativo
- ✅ Síncrono cuando todo funciona bien
- ✅ Tolera fallos de red/standby

**Desventajas:**
- ⚠️ Riesgo muy bajo de pérdida de datos (requiere dos fallos simultáneos)

**Cuándo usar:**
- **La mayoría de entornos de producción**
- Necesitas alta disponibilidad
- Quieres zero data loss pero no a costa de disponibilidad
- **Este es el modo más común y recomendado**

**Configuración en este proyecto:**
```dgmgrl
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
Configuration "dg_config" updated
```

**Por qué lo elegimos:**
- Zero data loss en operación normal
- Primary nunca se cae por standby
- Tolerante a fallos de red
- Mejor práctica de Oracle

---

### MAXPERFORMANCE

**Definición:** Rendimiento máximo del primary, protección de datos secundaria.

**Funcionamiento:**
- Primary **no espera** confirmación del standby
- Redo se envía **asíncronamente**
- Primary opera a máxima velocidad
- Standby recibe cambios "cuando puede"

**Garantías:**
- ❌ **No garantiza zero data loss**
- ⚠️ **RPO > 0:** Depende de cuánto se atrase el standby

**Ventajas:**
- ✅ Máximo rendimiento del primary
- ✅ Funciona con redes lentas/WAN
- ✅ No impacta transacciones

**Desventajas:**
- ❌ Posible pérdida de datos si primary falla
- ❌ Standby puede quedar muy atrasado

**Cuándo usar:**
- Rendimiento es más crítico que protección
- Red lenta o geográficamente distribuida
- RPO de minutos/horas es aceptable
- Standby lejano (otro continente)

**Ejemplo:**
```dgmgrl
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
```

---

### Tabla Comparativa: Protection Modes

| Aspecto | MAXPROTECTION | MAXAVAILABILITY ⭐ | MAXPERFORMANCE |
|---------|---------------|---------------------|----------------|
| **Zero Data Loss** | Siempre | Cuando standby disponible | No garantizado |
| **RPO** | 0 | 0 (normal), >0 (fallback) | >0 |
| **Primary se apaga si standby falla** | ✅ Sí | ❌ No | ❌ No |
| **Impacto en rendimiento** | Alto | Medio | Mínimo |
| **Requiere red rápida** | ✅ Sí | ✅ Sí | ❌ No |
| **Recomendado para** | Datos ultra-críticos | **Producción general** | WAN, rendimiento crítico |
| **Transport Mode** | SYNC/FASTSYNC | SYNC/FASTSYNC | ASYNC |

---

## Modos de Transporte (Transport Modes)

Los **Transport Modes** definen **cómo** se envían los redo logs al standby.

### SYNC

**Definición:** Transporte completamente síncrono.

**Funcionamiento:**
1. Primary genera redo
2. LNS envía a standby
3. Standby **escribe redo a disco**
4. Standby envía ACK al primary
5. Primary hace commit

**Características:**
- ✅ Máxima seguridad: redo en disco del standby antes de commit
- ❌ Más lento: espera escritura a disco
- ✅ Garantiza zero data loss incluso si standby pierde memoria

**Latencia:**
- Depende de:
  - Latencia de red (A → B)
  - Tiempo de escritura a disco en standby
  - Latencia de red (B → A) para ACK

**Configuración:**
```dgmgrl
DGMGRL> EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='SYNC';
```

---

### FASTSYNC ⭐ (Usado en este proyecto)

**Definición:** Transporte síncrono **optimizado**.

**Funcionamiento:**
1. Primary genera redo
2. LNS envía a standby
3. Standby **recibe redo en memoria (redo buffer)**
4. Standby envía ACK inmediatamente
5. Primary hace commit
6. Standby escribe a disco **asíncronamente después**

**Características:**
- ✅ Más rápido que SYNC: no espera escritura a disco
- ✅ Zero data loss: standby tiene redo en memoria
- ✅ Balance perfecto entre velocidad y seguridad

**¿Por qué es seguro?**
- Standby tiene redo en memoria buffer
- Standby escribe a disco después (pero no se espera)
- Para que haya pérdida de datos:
  - Primary debe fallar **Y**
  - Standby debe perder memoria **Y**
  - Standby debe perder disco
  - **Muy improbable**

**Latencia:**
- Solo latencia de red (ida + vuelta)
- No incluye tiempo de escritura a disco
- Típicamente 50-80% más rápido que SYNC

**Configuración en este proyecto:**
```dgmgrl
DGMGRL> EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
DGMGRL> EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='FASTSYNC';
```

**Por qué lo elegimos:**
- Balance óptimo velocidad/seguridad
- Zero data loss práctico
- Mejor rendimiento que SYNC
- Recomendado por Oracle para MAXAVAILABILITY

---

### ASYNC

**Definición:** Transporte completamente asíncrono.

**Funcionamiento:**
1. Primary genera redo
2. Primary hace commit inmediatamente
3. LNS envía a standby cuando puede (en background)
4. Standby recibe y aplica cuando le llega

**Características:**
- ✅ Cero impacto en primary
- ✅ Funciona con red lenta
- ❌ No garantiza zero data loss
- ❌ Standby puede quedar muy atrasado

**Cuándo usar:**
- MAXPERFORMANCE protection mode
- Red WAN lenta
- Standby remoto (otro continente)
- RPO de minutos es aceptable

**Configuración:**
```dgmgrl
DGMGRL> EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='ASYNC';
```

---

### Tabla Comparativa: Transport Modes

| Aspecto | SYNC | FASTSYNC ⭐ | ASYNC |
|---------|------|-------------|-------|
| **Zero Data Loss** | ✅ Garantizado | ✅ Práctico | ❌ No |
| **Primary espera** | Escritura a disco | Recepción en memoria | Nada |
| **Latencia agregada** | Alta | Media | Ninguna |
| **Red necesaria** | Rápida, <5ms | Rápida, <10ms | Cualquiera |
| **Compatible con** | MAXPROTECTION, MAXAVAILABILITY | MAXAVAILABILITY | MAXPERFORMANCE |
| **Velocidad relativa** | 1x (base) | 1.5-2x | ∞ (no espera) |
| **Uso típico** | Ultra crítico | **Producción general** | WAN, remoto |

---

## Configuración en Este Proyecto

### Protection Mode

**Elegido:** `MAXAVAILABILITY`

**Razón:**
- Zero data loss en operación normal
- Primary nunca se apaga por problemas de standby
- Best practice para entornos de producción
- Cumple requisito de entregable: alta disponibilidad

**Verificación:**
```sql
SQL> SELECT protection_mode, protection_level
     FROM v$database;

PROTECTION_MODE      PROTECTION_LEVEL
-------------------- --------------------
MAXIMUM AVAILABILITY MAXIMUM AVAILABILITY
```

---

### Transport Mode

**Elegido:** `FASTSYNC`

**Razón:**
- Balance óptimo rendimiento/protección
- Zero data loss práctico
- 50-80% más rápido que SYNC
- Recommended by Oracle para MAXAVAILABILITY

**Verificación:**
```dgmgrl
DGMGRL> SHOW DATABASE cdb1 LogXptMode;
  LogXptMode = 'FASTSYNC'

DGMGRL> SHOW DATABASE cdb1_stby LogXptMode;
  LogXptMode = 'FASTSYNC'
```

**Implementación en scripts:**

Archivo: `2-Standby/scripts/standby/oracle_create_database.sh` (líneas 233-295)

```bash
# Set LogXptMode to FASTSYNC on primary
dgmgrl / <<EOF
EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
exit
EOF

# Set LogXptMode to FASTSYNC on standby
dgmgrl / <<EOF
EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='FASTSYNC';
exit
EOF

# Verify LogXptMode is applied (with retry logic)
# ...

# Set protection mode to MAXAVAILABILITY
dgmgrl / <<EOF
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
exit
EOF
```

---

## Comparaciones y Trade-offs

### Zero Data Loss vs Disponibilidad

**Escenario 1: MAXPROTECTION**
```
Network failure → Primary SHUTS DOWN
✅ Zero data loss guaranteed
❌ Application outage
```

**Escenario 2: MAXAVAILABILITY** ⭐
```
Network failure → Primary switches to ASYNC
✅ Application continues
⚠️ Potential data loss only if primary also fails now
   (two simultaneous failures required)
```

**Escenario 3: MAXPERFORMANCE**
```
Network failure → Primary unaffected
✅ Application continues
❌ Data loss if primary fails (standby behind)
```

---

### Rendimiento vs Protección

**Latencia de commit por modo:**

```
Transaction commit time:

MAXPERFORMANCE + ASYNC:
├─ Primary processing: 10ms
└─ Total: 10ms

MAXAVAILABILITY + FASTSYNC:
├─ Primary processing: 10ms
├─ Network to standby: 1ms
├─ Standby receive to memory: 0.5ms
├─ Network ACK back: 1ms
└─ Total: 12.5ms (+25%)

MAXPROTECTION + SYNC:
├─ Primary processing: 10ms
├─ Network to standby: 1ms
├─ Standby receive to memory: 0.5ms
├─ Standby write to disk: 3ms
├─ Network ACK back: 1ms
└─ Total: 15.5ms (+55%)
```

**En este proyecto:**
- Ambiente de prueba en VMs locales
- Red host-only (192.168.56.x) muy rápida (<1ms)
- FASTSYNC añade overhead mínimo (~2-3ms)
- Aceptable para propósitos del entregable

---

## RPO y RTO

### RPO (Recovery Point Objective)

**Definición:** Cuántos datos puedes permitirte perder.

| Configuration | RPO |
|---------------|-----|
| MAXPROTECTION + SYNC | 0 (siempre) |
| MAXAVAILABILITY + FASTSYNC | 0 (normal)<br>Segundos-minutos (si fallback a async) |
| MAXPERFORMANCE + ASYNC | Minutos-horas |

**En este proyecto:**
- **RPO = 0** en operación normal (MAXAVAILABILITY + FASTSYNC)
- **RPO ≈ archive_lag_target** (5 min) en peor caso con fallback

---

### RTO (Recovery Time Objective)

**Definición:** Cuánto downtime es aceptable.

| Operation | RTO |
|-----------|-----|
| Switchover (planificado) | 2-5 minutos |
| Failover sin Flashback | 10-20 minutos (reconstrucción) |
| Failover con Flashback | 5-10 minutos (reinstatement rápido) |

**En este proyecto:**
- **RTO ≈ 2-3 minutos** (failover con Flashback)
- Flashback habilitado para reinstatement rápido
- Ver: [93-failover.md](../operaciones/93-failover.md)

---

## Cambio de Modos

### Cambiar Protection Mode

**Requisitos:**
- Database debe estar en configuración válida
- Standby debe estar sincronizado
- LogXptMode debe ser compatible

**Procedimiento:**

1. **Verificar estado actual:**
```dgmgrl
DGMGRL> SHOW CONFIGURATION;
```

2. **Cambiar a MAXAVAILABILITY:**
```dgmgrl
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
```

3. **Cambiar a MAXPERFORMANCE:**
```dgmgrl
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
```

4. **Cambiar a MAXPROTECTION:**
```dgmgrl
-- Requiere SYNC o FASTSYNC en todos los standbys
DGMGRL> EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='SYNC';
DGMGRL> EDIT CONFIGURATION SET PROTECTION MODE AS MAXPROTECTION;
```

---

### Cambiar Transport Mode

**En primary:**
```dgmgrl
DGMGRL> EDIT DATABASE cdb1 SET PROPERTY LogXptMode='FASTSYNC';
```

**En standby:**
```dgmgrl
DGMGRL> EDIT DATABASE cdb1_stby SET PROPERTY LogXptMode='FASTSYNC';
```

**Verificar:**
```dgmgrl
DGMGRL> SHOW DATABASE cdb1 LogXptMode;
DGMGRL> SHOW DATABASE cdb1_stby LogXptMode;
```

**Nota:** Cambio es inmediato, no requiere reinicio.

---

## Mejores Prácticas

### 1. Usar MAXAVAILABILITY para Producción

**Razón:**
- Balance óptimo entre protección y disponibilidad
- Zero data loss en operación normal
- Primary nunca se cae por standby
- Recomendado por Oracle

---

### 2. Usar FASTSYNC con MAXAVAILABILITY

**Razón:**
- Mejor rendimiento que SYNC
- Zero data loss práctico
- Recomendación oficial de Oracle
- Overhead aceptable

---

### 3. Reservar MAXPROTECTION para Casos Especiales

**Usar solo si:**
- Regulación EXIGE zero data loss absoluto
- Tienes red redundante y super confiable
- Aceptas que primary se caiga si falla standby

**No usar si:**
- Disponibilidad es crítica
- Red no es 100% confiable

---

### 4. MAXPERFORMANCE para Standby Remotos

**Usar si:**
- Standby está en otro continente
- Red es WAN con alta latencia
- RPO de minutos es aceptable
- Tienes standby local (MAXAVAILABILITY) + standby remoto (MAXPERFORMANCE)

---

### 5. Monitorear Constantemente

**Queries importantes:**

```sql
-- Verificar protection mode
SELECT protection_mode, protection_level FROM v$database;

-- Verificar transport lag
SELECT name, value, unit, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');

-- Verificar si está en fallback (resynchronization)
SELECT protection_level FROM v$database;
-- Si muestra "RESYNCHRONIZATION" en lugar de "MAXIMUM AVAILABILITY"
-- está en modo fallback asíncrono
```

---

### 6. Probar Failover Regularmente

**Frecuencia recomendada:** Mensual o trimestral

**Procedimiento:**
1. Switchover a standby (simulación de fallo)
2. Verificar aplicación funciona
3. Medir RTO real
4. Switchover de vuelta
5. Documentar resultados

---

## Referencias

- [81 - Data Guard Conceptos](81-data-guard-conceptos.md) - Arquitectura general
- [85 - Data Guard Broker](85-data-guard-broker.md) - Gestión de configuración
- [92 - Switchover](../operaciones/92-switchover.md) - Cambio planificado
- [93 - Failover](../operaciones/93-failover.md) - Cambio de emergencia
- [Oracle Data Guard Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/21/sbydb/)

---

## Resumen

**Configuración de este proyecto:**
- **Protection Mode:** MAXAVAILABILITY ⭐
- **Transport Mode:** FASTSYNC ⭐
- **RPO:** 0 segundos (operación normal)
- **RTO:** 2-3 minutos (con Flashback)

**Justificación:**
- Balance óptimo entre protección y disponibilidad
- Zero data loss en operación normal
- Rendimiento aceptable
- Best practice de Oracle
- Cumple requisitos del entregable

Esta configuración es apropiada para **la mayoría de entornos de producción** y representa las **mejores prácticas** de Oracle Data Guard.
