# 📚 Conceptos Avanzados: Networking y TNS en Oracle

**Archivo:** `conceptos-avanzados/86-networking-tns.md`
**Propósito:** Documentación profunda sobre configuración de red TNS en Oracle y Data Guard
**Parte de:** Sistema de Alta Disponibilidad Oracle 21c Data Guard
**Requisitos:** Haber leído 81-data-guard-conceptos.md, 85-data-guard-broker.md

---

## 📋 Tabla de Contenidos

1. [Introducción a TNS](#introducción-a-tns)
2. [Arquitectura de Red Oracle](#arquitectura-de-red-oracle)
3. [El Listener de Oracle](#el-listener-de-oracle)
4. [tnsnames.ora - Cliente](#tnsnamesora---cliente)
5. [listener.ora - Servidor](#listenerora---servidor)
6. [sqlnet.ora - Configuración Global](#sqlnetora---configuración-global)
7. [Networking en Data Guard](#networking-en-data-guard)
8. [Troubleshooting de Red](#troubleshooting-de-red)
9. [Seguridad de Red](#seguridad-de-red)
10. [Conclusiones](#conclusiones)

---

## 🎯 Introducción a TNS

### ¿Qué es TNS?

**TNS (Transparent Network Substrate)** es la capa de networking de Oracle que permite la comunicación entre clientes y servidores de base de datos, y entre bases de datos en configuraciones como Data Guard.

**Analogía:**
- TNS es como el "sistema telefónico" de Oracle
- tnsnames.ora es como una "agenda de contactos" (mapeo de nombres a números)
- listener.ora es como la "centralita" que recibe llamadas
- sqlnet.ora es como las "reglas de la compañía telefónica"

### Componentes Clave

```
┌────────────────────────────────────────────────────────────┐
│                    CLIENTE                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Aplicación / SQL*Plus / RMAN                        │  │
│  │  "quiero conectarme a cdb1"                          │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│               ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  tnsnames.ora                                        │  │
│  │  Busca "cdb1" → Obtiene HOST, PORT, SERVICE_NAME    │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│               ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  sqlnet.ora                                          │  │
│  │  Aplica reglas: cifrado, timeout, tracing, etc.     │  │
│  └────────────┬─────────────────────────────────────────┘  │
└───────────────┼────────────────────────────────────────────┘
                │
                │ Red TCP/IP (puerto 1521)
                │
┌───────────────▼────────────────────────────────────────────┐
│                   SERVIDOR                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  LISTENER (proceso de escucha)                       │  │
│  │  Escucha en puerto 1521                              │  │
│  │  Recibe solicitud de conexión                        │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│               ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  listener.ora                                        │  │
│  │  Verifica: ¿Puedo servir "cdb1"?                    │  │
│  │  Sí → Crea proceso dedicado para el cliente         │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                            │
│               ▼                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  PROCESO SERVIDOR (dedicado al cliente)             │  │
│  │  Ejecuta queries, retorna resultados                │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Arquitectura de Red Oracle

### Topología de Red en Nuestro Proyecto

```
┌─────────────────────────────────────────────────────────────┐
│                    HOST WINDOWS                             │
│  IP: 192.168.56.1 (Host-Only Adapter)                      │
│                                                              │
│  Cliente SQL:                                               │
│  sqlplus sys/password@192.168.56.101:1521/cdb1             │
│  sqlplus sys/password@192.168.56.102:1521/cdb1_stby        │
└───────────────┬───────────────────┬─────────────────────────┘
                │                   │
                │ VirtualBox        │ VirtualBox
                │ Host-Only         │ Host-Only
                │ Network           │ Network
                │                   │
┌───────────────▼─────────┐  ┌──────▼──────────────────────┐
│  PRIMARY VM             │  │  STANDBY VM                 │
│  ol8-21-dg1.localdomain │  │  ol8-21-dg2.localdomain     │
│                         │  │                             │
│  IPs:                   │  │  IPs:                       │
│  - NAT: 10.0.2.15       │  │  - NAT: 10.0.2.15           │
│  - Host-Only:           │  │  - Host-Only:               │
│    192.168.56.101       │  │    192.168.56.102           │
│                         │  │                             │
│  Listener:              │  │  Listener:                  │
│  - Puerto 1521          │  │  - Puerto 1521              │
│  - Sirve: cdb1, pdb1    │  │  - Sirve: cdb1_stby         │
│                         │  │                             │
│  Data Guard Role:       │  │  Data Guard Role:           │
│  PRIMARY                │  │  STANDBY                    │
└─────────────────────────┘  └─────────────────────────────┘
          │                            │
          │                            │
          └────────────────────────────┘
                    │
             Replicación de Redo
          (archive logs via TNS)
          - Cifrado AES256
          - Puerto 1521
          - Protocolo TCP
```

### Tipos de Conexión

#### 1. **Easy Connect (Sin tnsnames.ora)**

```bash
# Formato: usuario/password@host:puerto/service_name
sqlplus sys/S1sPassword1!@192.168.56.101:1521/cdb1 as sysdba
sqlplus sys/S1sPassword1!@ol8-21-dg1.localdomain:1521/pdb1 as sysdba
```

**Ventajas:**
- No requiere configuración de tnsnames.ora
- Rápido para conexiones ad-hoc

**Desventajas:**
- No soporta opciones avanzadas (failover, load balancing)
- No funciona con Data Guard Broker (requiere alias)

#### 2. **Net Service Name (Con tnsnames.ora)**

```bash
# Formato: usuario/password@alias
sqlplus sys/S1sPassword1!@cdb1 as sysdba
sqlplus sys/S1sPassword1!@cdb1_stby as sysdba
```

**Ventajas:**
- Alias descriptivos (cdb1 en lugar de IP:puerto/servicio)
- Soporta opciones avanzadas
- Requerido por Data Guard Broker

**Desventajas:**
- Requiere configurar tnsnames.ora

---

## 📡 El Listener de Oracle

### ¿Qué es el Listener?

El **Listener** es un proceso en el servidor que:
- Escucha conexiones entrantes en un puerto específico (típicamente 1521)
- Autentica solicitudes de conexión
- Crea procesos servidor dedicados para atender clientes
- Registra servicios de base de datos disponibles

### Arquitectura del Listener

```
┌────────────────────────────────────────────────────────────┐
│                      LISTENER                              │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  PUERTO 1521 (escuchando)                            │  │
│  └────────┬─────────────────────────────────────────────┘  │
│           │                                                │
│           │ Cliente conecta: "quiero cdb1"                 │
│           ▼                                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  DISPATCHER (distribuidor de conexiones)            │  │
│  │  - Verifica: ¿Existe servicio "cdb1"?               │  │
│  │  - Verifica: ¿DB está disponible?                   │  │
│  └────────┬─────────────────────────────────────────────┘  │
│           │                                                │
│           ▼                                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  HANDOFF (crear proceso dedicado)                   │  │
│  │  - Fork nuevo proceso servidor                       │  │
│  │  - Conectar proceso servidor a cliente              │  │
│  │  - Transferir control al proceso servidor           │  │
│  └────────┬─────────────────────────────────────────────┘  │
└───────────┼────────────────────────────────────────────────┘
            │
            ▼
  ┌────────────────────────────────────┐
  │  PROCESO SERVIDOR DEDICADO         │
  │  (uno por cada conexión cliente)   │
  │  - Ejecuta SQL del cliente         │
  │  - Retorna resultados              │
  └────────────────────────────────────┘
```

### Comandos del Listener

```bash
# Iniciar listener
lsnrctl start

# Detener listener
lsnrctl stop

# Ver estado (servicios registrados, conexiones activas)
lsnrctl status

# Recargar configuración (sin reiniciar)
lsnrctl reload

# Verificar conectividad a un servicio
tnsping cdb1
tnsping cdb1_stby
```

### lsnrctl status - Salida Típica

```bash
$ lsnrctl status

LSNRCTL for Linux: Version 21.0.0.0.0 - Production on 04-NOV-2025 10:30:15

Copyright (c) 1991, 2021, Oracle.  All rights reserved.

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=ol8-21-dg1.localdomain)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 21.0.0.0.0 - Production
Start Date                03-NOV-2025 08:15:32
Uptime                    1 days 2 hr. 14 min. 43 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/oracle/product/21c/dbhome_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/ol8-21-dg1/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=ol8-21-dg1.localdomain)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "cdb1" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
Service "cdb1XDB" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
Service "pdb1" has 1 instance(s).
  Instance "cdb1", status READY, has 1 handler(s) for this service...
The command completed successfully
```

**Interpretación:**
- **Listening Endpoints**: Listener escucha en puerto 1521 (TCP) y socket IPC
- **Services Summary**: Tres servicios disponibles: cdb1 (CDB root), cdb1XDB (XML DB), pdb1 (Pluggable DB)
- **Status READY**: Database está abierta y aceptando conexiones

---

## 📄 tnsnames.ora - Cliente

### Ubicación

```bash
# En el servidor Oracle
/u01/app/oracle/product/21c/dbhome_1/network/admin/tnsnames.ora

# Variable de entorno (puede sobrescribir ubicación)
export TNS_ADMIN=/u01/app/oracle/product/21c/dbhome_1/network/admin
```

### Formato General

```
<alias> =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <hostname>)(PORT = <puerto>))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = <service_name>)
    )
  )
```

### tnsnames.ora en Nuestro Proyecto (Primary)

**Archivo:** `/u01/app/oracle/product/21c/dbhome_1/network/admin/tnsnames.ora`

```
# ===================================================================
# tnsnames.ora - Primary Node (ol8-21-dg1)
# ===================================================================

# ─────────────────────────────────────────────────────────────────
# Conexión al PRIMARY (CDB)
# ─────────────────────────────────────────────────────────────────
cdb1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = cdb1)
    )
  )

# ─────────────────────────────────────────────────────────────────
# Conexión al PRIMARY PDB (pdb1)
# ─────────────────────────────────────────────────────────────────
pdb1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = pdb1)
    )
  )

# ─────────────────────────────────────────────────────────────────
# Conexión al STANDBY (para Data Guard replication)
# ─────────────────────────────────────────────────────────────────
cdb1_stby =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = cdb1_stby)
      (UR = A)
    )
  )
```

### tnsnames.ora en Nuestro Proyecto (Standby)

**Archivo:** `/u01/app/oracle/product/21c/dbhome_1/network/admin/tnsnames.ora`

```
# ===================================================================
# tnsnames.ora - Standby Node (ol8-21-dg2)
# ===================================================================

# ─────────────────────────────────────────────────────────────────
# Conexión al STANDBY (CDB)
# ─────────────────────────────────────────────────────────────────
cdb1_stby =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = cdb1_stby)
      (UR = A)
    )
  )

# ─────────────────────────────────────────────────────────────────
# Conexión al PRIMARY (para Data Guard replication)
# ─────────────────────────────────────────────────────────────────
cdb1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = cdb1)
    )
  )

# ─────────────────────────────────────────────────────────────────
# Conexión al PRIMARY PDB
# ─────────────────────────────────────────────────────────────────
pdb1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = pdb1)
    )
  )
```

### Parámetros Importantes en CONNECT_DATA

| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| **SERVICE_NAME** | Nombre del servicio de BD | `cdb1`, `pdb1`, `cdb1_stby` |
| **SID** | System ID (deprecated, usar SERVICE_NAME) | `cdb1` |
| **SERVER** | Tipo de conexión: DEDICATED o SHARED | `DEDICATED` |
| **INSTANCE_NAME** | Nombre de instancia específica (RAC) | `cdb1` |
| **UR** | Unregistered (A=permitir conexión a BD no registrada en listener) | `A` |

**UR=A en Data Guard:**
- Permite conectarse al standby incluso si no está registrado en el listener
- Útil durante RMAN DUPLICATE cuando standby está en NOMOUNT
- Esencial para operaciones de Data Guard

---

## 📄 listener.ora - Servidor

### Ubicación

```bash
/u01/app/oracle/product/21c/dbhome_1/network/admin/listener.ora
```

### listener.ora en Nuestro Proyecto (Primary)

**Archivo:** `/u01/app/oracle/product/21c/dbhome_1/network/admin/listener.ora`

```
# ===================================================================
# listener.ora - Primary Node (ol8-21-dg1)
# ===================================================================

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

# ─────────────────────────────────────────────────────────────────
# SID_LIST - Servicios estáticos (usado para RMAN, Data Guard)
# ─────────────────────────────────────────────────────────────────
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = cdb1_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/21c/dbhome_1)
      (SID_NAME = cdb1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = cdb1)
      (ORACLE_HOME = /u01/app/oracle/product/21c/dbhome_1)
      (SID_NAME = cdb1)
    )
  )

# ─────────────────────────────────────────────────────────────────
# Configuración adicional
# ─────────────────────────────────────────────────────────────────
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER = ON
INBOUND_CONNECT_TIMEOUT_LISTENER = 120
```

### listener.ora en Nuestro Proyecto (Standby)

**Archivo:** `/u01/app/oracle/product/21c/dbhome_1/network/admin/listener.ora`

```
# ===================================================================
# listener.ora - Standby Node (ol8-21-dg2)
# ===================================================================

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

# ─────────────────────────────────────────────────────────────────
# SID_LIST - Servicios estáticos
# ─────────────────────────────────────────────────────────────────
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = cdb1_stby_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/21c/dbhome_1)
      (SID_NAME = cdb1_stby)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = cdb1_stby)
      (ORACLE_HOME = /u01/app/oracle/product/21c/dbhome_1)
      (SID_NAME = cdb1_stby)
    )
  )

# ─────────────────────────────────────────────────────────────────
# Configuración adicional
# ─────────────────────────────────────────────────────────────────
ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER = ON
INBOUND_CONNECT_TIMEOUT_LISTENER = 120
```

### Registro de Servicios: Estático vs Dinámico

#### Registro Dinámico (Automático)

- Cuando la database se inicia, **automáticamente** registra sus servicios en el listener
- Proceso PMON contacta al listener cada 60 segundos
- **No requiere** entrada en SID_LIST_LISTENER

**Ventaja:** Sin configuración manual
**Desventaja:** No funciona cuando DB está en NOMOUNT o MOUNT (Data Guard, RMAN)

#### Registro Estático (Manual en listener.ora)

- Servicios definidos explícitamente en SID_LIST_LISTENER
- Disponibles incluso cuando DB está en NOMOUNT
- **Requerido** para:
  - RMAN DUPLICATE
  - Data Guard Broker (DGMGRL)
  - Conexiones a DB en MOUNT

**En nuestro proyecto:**
```
SID_DESC =
  (GLOBAL_DBNAME = cdb1_DGMGRL)  ← Para Data Guard Broker
  (ORACLE_HOME = /u01/app/oracle/product/21c/dbhome_1)
  (SID_NAME = cdb1)
```

---

## 📄 sqlnet.ora - Configuración Global

### Ubicación

```bash
/u01/app/oracle/product/21c/dbhome_1/network/admin/sqlnet.ora
```

### sqlnet.ora en Nuestro Proyecto

**Archivo:** `/u01/app/oracle/product/21c/dbhome_1/network/admin/sqlnet.ora`

```
# ===================================================================
# sqlnet.ora - Configuración de red global (Primary y Standby)
# ===================================================================

# ─────────────────────────────────────────────────────────────────
# Orden de resolución de nombres
# ─────────────────────────────────────────────────────────────────
NAMES.DIRECTORY_PATH = (TNSNAMES, EZCONNECT, HOSTNAME)

# TNSNAMES   = Buscar en tnsnames.ora primero
# EZCONNECT  = Permitir Easy Connect (host:port/service)
# HOSTNAME   = Resolver hostname via DNS/hosts file

# ─────────────────────────────────────────────────────────────────
# Cifrado de Red (AES256 para Data Guard)
# ─────────────────────────────────────────────────────────────────
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256)
SQLNET.ENCRYPTION_CLIENT = REQUIRED
SQLNET.ENCRYPTION_TYPES_CLIENT = (AES256)

# Algoritmo: AES256 (Advanced Encryption Standard 256-bit)
# REQUIRED = Conexión rechazada si no hay cifrado

# ─────────────────────────────────────────────────────────────────
# Checksums de Integridad de Datos
# ─────────────────────────────────────────────────────────────────
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)
SQLNET.CRYPTO_CHECKSUM_CLIENT = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_CLIENT = (SHA256)

# SHA256 = Secure Hash Algorithm 256-bit
# Detecta manipulación de datos en tránsito

# ─────────────────────────────────────────────────────────────────
# Timeouts
# ─────────────────────────────────────────────────────────────────
SQLNET.INBOUND_CONNECT_TIMEOUT = 120
SQLNET.OUTBOUND_CONNECT_TIMEOUT = 120
SQLNET.RECV_TIMEOUT = 30
SQLNET.SEND_TIMEOUT = 30

# ─────────────────────────────────────────────────────────────────
# Seguridad - Autenticación Local OS
# ─────────────────────────────────────────────────────────────────
SQLNET.AUTHENTICATION_SERVICES = (NTS, BEQ)

# NTS = Network Authentication Service (Kerberos en Linux)
# BEQ = Bequeath (autenticación local OS - permite "/ as sysdba")

# ─────────────────────────────────────────────────────────────────
# Configuración de Tracing (deshabilitado en producción)
# ─────────────────────────────────────────────────────────────────
# TRACE_LEVEL_CLIENT = OFF
# TRACE_LEVEL_SERVER = OFF
# Para debug, cambiar a: ADMIN, SUPPORT, USER

# ─────────────────────────────────────────────────────────────────
# Configuración de Logging
# ─────────────────────────────────────────────────────────────────
# LOG_DIRECTORY_CLIENT = /u01/app/oracle/diag/clients/user_oracle/host_*/trace
# LOG_DIRECTORY_SERVER = /u01/app/oracle/diag/tnslsnr/...
```

### Parámetros Importantes en sqlnet.ora

| Parámetro | Descripción | Nuestro Valor |
|-----------|-------------|---------------|
| **NAMES.DIRECTORY_PATH** | Orden de resolución de nombres | `(TNSNAMES, EZCONNECT, HOSTNAME)` |
| **SQLNET.ENCRYPTION_SERVER** | Cifrado en servidor | `REQUIRED` (AES256) |
| **SQLNET.ENCRYPTION_CLIENT** | Cifrado en cliente | `REQUIRED` (AES256) |
| **SQLNET.CRYPTO_CHECKSUM_SERVER** | Checksum en servidor | `REQUIRED` (SHA256) |
| **SQLNET.INBOUND_CONNECT_TIMEOUT** | Timeout de conexión entrante (seg) | `120` |
| **SQLNET.AUTHENTICATION_SERVICES** | Servicios de autenticación | `(NTS, BEQ)` |

---

## 🔗 Networking en Data Guard

### Flujo de Red en Replicación de Data Guard

```
PRIMARY (ol8-21-dg1)                    STANDBY (ol8-21-dg2)
┌─────────────────────────────┐         ┌─────────────────────────────┐
│  1. Transacción COMMIT      │         │                             │
│     ↓                       │         │                             │
│  2. LGWR escribe            │         │                             │
│     Online Redo Log         │         │                             │
│     ↓                       │         │                             │
│  3. LNSn (Log Network       │         │                             │
│     Server) lee redo        │         │                             │
│     ↓                       │         │                             │
│  4. Consulta tnsnames.ora:  │         │                             │
│     "¿Dónde está cdb1_stby?"│         │                             │
│     ↓                       │         │                             │
│  5. Obtiene:                │         │                             │
│     HOST=ol8-21-dg2         │         │                             │
│     PORT=1521               │         │                             │
│     ↓                       │         │                             │
│  6. Aplica sqlnet.ora:      │         │                             │
│     - Cifrado AES256        │         │                             │
│     - Checksum SHA256       │         │                             │
│     ↓                       │         │                             │
│  7. Envía redo data ────────┼────────►│  8. LISTENER recibe en     │
│     por red TCP 1521        │ AES256  │     puerto 1521             │
│     (cifrado)               │         │     ↓                       │
│                             │         │  9. RFS (Remote File        │
│                             │         │     Server) acepta conexión │
│                             │         │     ↓                       │
│                             │         │ 10. Verifica cifrado/       │
│                             │         │     checksum (sqlnet.ora)   │
│                             │         │     ↓                       │
│                             │         │ 11. Escribe a Standby       │
│                             │         │     Redo Logs               │
│                             │         │     ↓                       │
│  12. Recibe confirmación ◄──┼─────────│ 12. Envía ACK al primary   │
│      (FASTSYNC)             │         │                             │
└─────────────────────────────┘         └─────────────────────────────┘
```

### Configuración de Red para Data Guard

**Requisitos:**
1. Ambas databases deben poder resolver nombres mutuamente (hosts file o DNS)
2. Listeners activos en ambos lados
3. tnsnames.ora con alias de la database remota
4. Servicios estáticos para DGMGRL
5. Cifrado configurado (opcional pero recomendado)

**Validación:**

```bash
# En PRIMARY, verificar conexión al standby
tnsping cdb1_stby

# Salida esperada:
# OK (10 msec)

# Conectarse al standby desde primary
sqlplus sys/S1sPassword1!@cdb1_stby as sysdba <<EOF
SELECT database_role, open_mode FROM v\$database;
EXIT;
EOF

# Resultado esperado:
# DATABASE_ROLE    | OPEN_MODE
# PHYSICAL STANDBY | MOUNTED
```

---

## 🔧 Troubleshooting de Red

### Problema 1: ORA-12541 (No listener)

**Error:**
```
ORA-12541: TNS:no listener
```

**Causa:** Listener no está corriendo en el servidor de destino

**Diagnóstico:**
```bash
# En el servidor de destino
lsnrctl status

# Si dice "The command completed successfully" → Listener OK
# Si dice "TNS-12541: TNS:no listener" → Listener caído
```

**Solución:**
```bash
# Iniciar listener
lsnrctl start

# Verificar
lsnrctl status
```

### Problema 2: ORA-12514 (Service not registered)

**Error:**
```
ORA-12514: TNS:listener does not currently know of service requested in connect descriptor
```

**Causa:** Listener no conoce el servicio solicitado

**Diagnóstico:**
```bash
# Ver servicios registrados en listener
lsnrctl services

# Buscar el servicio que necesitas (ej. cdb1_stby)
```

**Soluciones:**

1. **Si database está OPEN (registro dinámico):**
```sql
-- Forzar registro inmediato
ALTER SYSTEM REGISTER;

-- Esperar 10 segundos y verificar
```

2. **Si database está en MOUNT (Data Guard):**
```
-- Añadir entrada estática en listener.ora:
SID_DESC =
  (GLOBAL_DBNAME = cdb1_stby)
  (ORACLE_HOME = /u01/app/oracle/product/21c/dbhome_1)
  (SID_NAME = cdb1_stby)

-- Recargar listener
lsnrctl reload
```

### Problema 3: ORA-12170 (Connection timeout)

**Error:**
```
ORA-12170: TNS:Connect timeout occurred
```

**Causa:** Firewall bloqueando, red lenta, o host inalcanzable

**Diagnóstico:**
```bash
# 1. Verificar conectividad IP
ping ol8-21-dg2.localdomain

# 2. Verificar puerto abierto
telnet ol8-21-dg2.localdomain 1521
# O con nmap:
nmap -p 1521 ol8-21-dg2.localdomain

# 3. Verificar firewall
sudo firewall-cmd --list-all
# Puerto 1521 debe estar permitido
```

**Solución:**
```bash
# Abrir puerto 1521 en firewall (si está cerrado)
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --reload
```

### Problema 4: ORA-12154 (Could not resolve connect identifier)

**Error:**
```
ORA-12154: TNS:could not resolve the connect identifier specified
```

**Causa:** Alias no existe en tnsnames.ora

**Diagnóstico:**
```bash
# Verificar que tnsnames.ora tiene el alias
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep -A 10 "cdb1_stby"

# Verificar TNS_ADMIN apunta al directorio correcto
echo $TNS_ADMIN
# Debería estar vacío (usa default) o apuntar a $ORACLE_HOME/network/admin
```

**Solución:**
```bash
# Añadir alias faltante a tnsnames.ora
vi $ORACLE_HOME/network/admin/tnsnames.ora

# Añadir:
cdb1_stby =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = cdb1_stby)
    )
  )

# Verificar con tnsping
tnsping cdb1_stby
```

### Problema 5: Data Guard Transport Failing

**Síntomas:**
```sql
-- En primary
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id = 2;

-- Resultado:
-- DEST_ID | STATUS | ERROR
-- 2       | ERROR  | ORA-16191: Primary log shipping client not logged on standby
```

**Diagnóstico completo:**

```bash
# 1. Verificar tnsping desde primary a standby
tnsping cdb1_stby

# 2. Verificar listener en standby
ssh oracle@ol8-21-dg2 "lsnrctl status"

# 3. Intentar conexión SQL desde primary a standby
sqlplus sys/password@cdb1_stby as sysdba <<EOF
SELECT open_mode FROM v\$database;
EXIT;
EOF

# 4. Verificar que standby está en MOUNT (no OPEN)
```

**Solución:**
```bash
# Si standby está OPEN (incorrecto para physical standby):
sqlplus / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
EXIT;
EOF

# Re-habilitar archive destination en primary
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET log_archive_dest_state_2='DEFER';
ALTER SYSTEM SET log_archive_dest_state_2='ENABLE';
EXIT;
EOF
```

---

## 🔐 Seguridad de Red

### Cifrado de Red Oracle

Nuestro proyecto usa **AES256** para cifrado de datos en tránsito:

```
# sqlnet.ora
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256)
```

**Ventajas:**
- Protege archive logs durante transporte (Data Guard)
- Protege credenciales en conexiones remotas
- Cumplimiento de normativas (GDPR, HIPAA para healthcare data)

**Verificación:**

```sql
-- Ver cifrado activo en sesiones
SELECT username, network_service_banner
FROM v$session_connect_info
WHERE sid = (SELECT DISTINCT sid FROM v$mystat);

-- Resultado esperado:
-- NETWORK_SERVICE_BANNER
-- TCP/IP NT Protocol Adapter for Linux: Version 21.0.0.0.0 - Production
-- Encryption service for Linux: Version 21.0.0.0.0 - Production
-- AES256 Encryption service adapter for Linux: Version 21.0.0.0.0 - Production ← Cifrado activo
-- Crypto-checksumming service for Linux: Version 21.0.0.0.0 - Production
-- SHA256 Crypto-checksumming service adapter for Linux: Version 21.0.0.0.0 - Production
```

### Algoritmos Disponibles

| Algoritmo | Nivel de Seguridad | Performance | Recomendado |
|-----------|-------------------|-------------|-------------|
| **AES256** | Muy Alto | Bueno (con CPU moderno) | ✅ Sí (nuestro proyecto) |
| AES192 | Alto | Bueno | ✅ Alternativa |
| AES128 | Alto | Mejor | ⚠️ Menos seguro que AES256 |
| 3DES168 | Medio | Bajo | ❌ Deprecated |
| RC4_256 | Bajo | Alto | ❌ Inseguro |

### Checksum de Integridad

Además de cifrado, usamos **SHA256** para checksums:

```
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)
```

**Propósito:**
- Detecta corrupción de datos en tránsito
- Detecta manipulación maliciosa (man-in-the-middle)
- Complementa el cifrado

---

## 📝 Conclusiones

### Puntos Clave sobre Networking TNS

1. **Tres Archivos Críticos:**
   - **tnsnames.ora**: Mapeo de alias a conexiones (cliente)
   - **listener.ora**: Configuración del listener (servidor)
   - **sqlnet.ora**: Configuración global de red (ambos)

2. **Listener Esencial:** Sin listener corriendo, no hay conexiones remotas posibles.

3. **Registro Estático para Data Guard:** DGMGRL y RMAN requieren registro estático en listener.ora.

4. **Cifrado Obligatorio:** En entornos de producción (especialmente healthcare), cifrado es crítico.

5. **tnsping es tu Amigo:** Siempre usa `tnsping <alias>` para diagnosticar problemas de red.

### Configuración en Nuestro Proyecto

| Componente | Configuración |
|------------|---------------|
| **Listener port** | 1521 (TCP) |
| **Servicios primary** | cdb1, pdb1 |
| **Servicios standby** | cdb1_stby |
| **Registro** | Dinámico + Estático (DGMGRL) |
| **Cifrado** | AES256 (REQUIRED) |
| **Checksum** | SHA256 (REQUIRED) |
| **Timeout** | 120 segundos |
| **Resolución nombres** | TNSNAMES, EZCONNECT, HOSTNAME |

### Relación con Otros Componentes

- **Data Guard Broker** (85-data-guard-broker.md): Broker requiere alias TNS configurados
- **Archive Logs** (83-archive-logs.md): Archive log transport usa TNS
- **RMAN Backups** (87-rman-backups.md): RMAN DUPLICATE usa TNS para conectarse remotamente

### Comandos Rápidos de Referencia

```bash
# Listener
lsnrctl start
lsnrctl stop
lsnrctl status
lsnrctl reload

# Verificar conectividad
tnsping cdb1
tnsping cdb1_stby

# Conexión Easy Connect
sqlplus sys/password@192.168.56.101:1521/cdb1 as sysdba

# Conexión con alias
sqlplus sys/password@cdb1 as sysdba

# Ver cifrado activo
sqlplus / as sysdba <<EOF
SELECT network_service_banner FROM v\$session_connect_info WHERE sid IN (SELECT sid FROM v\$mystat);
EXIT;
EOF

# Troubleshooting
telnet ol8-21-dg2.localdomain 1521
nmap -p 1521 ol8-21-dg2.localdomain
lsnrctl services
```

---

**Siguiente:** [87-rman-backups.md](87-rman-backups.md) - RMAN Backup Strategies y Recovery
**Anterior:** [85-data-guard-broker.md](85-data-guard-broker.md) - Data Guard Broker
**Inicio:** [00-tabla-contenidos.md](../00-tabla-contenidos.md)
