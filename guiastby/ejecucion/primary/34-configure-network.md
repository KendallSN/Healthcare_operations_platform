# 34 - Configure Network - Configuración de Red

## Configuración de Red para Data Guard

Este documento cubre **tres scripts** que configuran la red del nodo primario: resolución de nombres DNS local (`/etc/hosts`), hostname del sistema, y sincronización de tiempo con chrony. Estos tres componentes son críticos para el correcto funcionamiento de Oracle Data Guard.

## Ubicación de los Scripts

Todos son **shared scripts** usados por primary y standby:

1. `2-Standby/infrastructure/configure_hosts_base.sh`
2. `2-Standby/infrastructure/configure_hostname.sh`
3. `2-Standby/infrastructure/configure_chrony.sh`

## Propósito

- **configure_hosts_base.sh:** Agregar entradas DNS para primary y standby a `/etc/hosts`
- **configure_hostname.sh:** Configurar hostname basado en IP del nodo
- **configure_chrony.sh:** Habilitar y arrancar sincronización de tiempo

## Cuándo se Ejecutan

- **Llamados por:** `root_setup.sh` (pasos 6, 7 y 8)
- **Orden:** Pasos 6-8 de 12 en el despliegue primario
- **Usuario:** `root` (necesario para modificar /etc/hosts y systemctl)
- **Duración total:** 15-20 segundos (los tres scripts)

---

## Script 1: configure_hosts_base.sh

### Propósito

Agregar entradas DNS locales para ambos nodos de Data Guard en `/etc/hosts`, permitiendo resolución de nombres sin depender de DNS externo.

### Flujo de Ejecución

#### Paso 1: Cargar Variables

```bash
. /vagrant_config/install.env
```

#### Paso 2: Banner

```bash
echo "******************************************************************************"
echo "Configure /etc/hosts." `date`
echo "******************************************************************************"
```

#### Paso 3: Agregar Entradas DNS

```bash
cat >> /etc/hosts << EOF

# Oracle Data Guard Hosts
${NODE1_PUBLIC_IP}  ${NODE1_FQ_HOSTNAME} ${NODE1_HOSTNAME}
${NODE2_PUBLIC_IP}  ${NODE2_FQ_HOSTNAME} ${NODE2_HOSTNAME}
EOF
```

**Variables expandidas:**
```
192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
192.168.56.102  ol8-21-dg2.localdomain ol8-21-dg2
```

**Explicación:**
- **FQDN primero:** `ol8-21-dg1.localdomain` (Fully Qualified Domain Name)
- **Short name después:** `ol8-21-dg1` (alias)
- Ambas formas resuelven a la misma IP
- Oracle Data Guard usa FQDNs en configuración TNS

### Variables de Entorno Utilizadas

```bash
NODE1_PUBLIC_IP=192.168.56.101
NODE1_FQ_HOSTNAME=ol8-21-dg1.localdomain
NODE1_HOSTNAME=ol8-21-dg1
NODE2_PUBLIC_IP=192.168.56.102
NODE2_FQ_HOSTNAME=ol8-21-dg2.localdomain
NODE2_HOSTNAME=ol8-21-dg2
```

### Verificación

```bash
# Verificar entradas agregadas
cat /etc/hosts | tail -3

# Probar resolución
ping -c 2 ol8-21-dg1.localdomain
ping -c 2 ol8-21-dg2.localdomain

# Verificar con host command
host ol8-21-dg1.localdomain  # Puede no funcionar (usa /etc/nsswitch.conf)

# Mejor usar getent
getent hosts ol8-21-dg1.localdomain
# Output: 192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
```

### Importancia para Data Guard

**Crítico porque:**
1. **tnsnames.ora** usa hostnames para conectar a bases de datos
2. **listener.ora** registra servicios con hostnames
3. **Data Guard Broker** usa nombres de host para comunicación
4. **Archive log transport** resuelve nombres al transferir logs

**Sin /etc/hosts:**
- Conexiones fallarían con `ORA-12541: TNS:no listener`
- Broker fallaría en configuración inicial
- Archive log transport fallaría o sería lento

---

## Script 2: configure_hostname.sh

### Propósito

Detectar automáticamente si el nodo es primary o standby (basado en IP) y configurar el hostname correspondiente.

### Flujo de Ejecución

#### Paso 1: Cargar Variables

```bash
. /vagrant_config/install.env
```

#### Paso 2: Detectar IP del Nodo

```bash
IP_ADDR=$(hostname -I | awk '{print $2}')
```

**Explicación:**
- `hostname -I`: Lista todas las IPs del host
- `awk '{print $2}'`: Toma la segunda IP (primera es 10.0.2.15 de NAT, segunda es 192.168.56.x de private network)

**Ejemplo de salida de `hostname -I`:**
```
10.0.2.15 192.168.56.101
```

#### Paso 3: Determinar Hostname Basado en IP

```bash
if [ "${IP_ADDR}" == "${NODE1_PUBLIC_IP}" ]; then
  HOSTNAME_TO_SET=${NODE1_FQ_HOSTNAME}
elif [ "${IP_ADDR}" == "${NODE2_PUBLIC_IP}" ]; then
  HOSTNAME_TO_SET=${NODE2_FQ_HOSTNAME}
else
  echo "ERROR: Unable to determine node from IP: ${IP_ADDR}"
  exit 1
fi
```

**Lógica:**
- Si IP = 192.168.56.101 → hostname = ol8-21-dg1.localdomain (PRIMARY)
- Si IP = 192.168.56.102 → hostname = ol8-21-dg2.localdomain (STANDBY)
- Si no coincide → ERROR (algo está mal configurado)

#### Paso 4: Configurar Hostname

```bash
echo "******************************************************************************"
echo "Set hostname to ${HOSTNAME_TO_SET}." `date`
echo "******************************************************************************"

hostnamectl set-hostname ${HOSTNAME_TO_SET} --static
```

**Explicación:**
- `hostnamectl`: Comando moderno para gestionar hostname (reemplaza `hostname` antiguo)
- `--static`: Configura hostname permanente (persiste en reboot)
- También actualiza `/etc/hostname`

### Verificación

```bash
# Verificar hostname configurado
hostname
# Output: ol8-21-dg1.localdomain

# Verificar con hostnamectl
hostnamectl status
# Output:
#    Static hostname: ol8-21-dg1.localdomain
#          Icon name: computer-vm
#            Chassis: vm
#         Machine ID: ...
#            Boot ID: ...
#     Virtualization: oracle
#   Operating System: Oracle Linux Server 8.8
#        CPE OS Name: cpe:/o:oracle:linux:8:8:server
#             Kernel: Linux 5.4.17-2136.318.7.el8uek.x86_64
#       Architecture: x86-64

# Verificar que resuelve a IP correcta
ping -c 1 $(hostname)
```

### Importancia para Data Guard

**Oracle Database usa hostname para:**
1. **LOCAL_LISTENER parameter:**
   ```sql
   ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=ol8-21-dg1.localdomain)(PORT=1521))';
   ```

2. **DG_CONFIG parameter:**
   ```sql
   ALTER SYSTEM SET log_archive_config='DG_CONFIG=(cdb1,cdb1_stby)';
   ```

3. **Alert Log entries:** Hostname aparece en todos los mensajes de log

4. **Data Guard Broker:** Identifica nodos por hostname

**Hostname incorrecto causa:**
- Listener no arranca correctamente
- Broker no puede conectar a standby
- Errores en alert log: `ORA-12541` o `ORA-12514`

---

## Script 3: configure_chrony.sh

### Propósito

Habilitar y arrancar el servicio `chronyd` para sincronización de tiempo precisa entre primary y standby.

### Flujo de Ejecución

#### Paso 1: Cargar Variables

```bash
. /vagrant_config/install.env
```

#### Paso 2: Banner

```bash
echo "******************************************************************************"
echo "Configure chrony for time synchronization." `date`
echo "******************************************************************************"
```

#### Paso 3: Habilitar y Arrancar Chrony

```bash
systemctl enable chronyd
systemctl start chronyd
```

**Explicación:**
- `enable`: Configura chrony para arrancar automáticamente en boot
- `start`: Arranca servicio inmediatamente

**Chrony vs ntpd:**
- **Chrony:** Más rápido para sincronizar, mejor en VMs
- **ntpd:** Más antiguo, más lento para sincronizar
- Oracle recomienda chrony en Oracle Linux 8

#### Paso 4: Verificar Sincronización

```bash
chronyc tracking
```

**Salida esperada:**
```
Reference ID    : A29FC87B (centos.pool.ntp.org)
Stratum         : 3
Ref time (UTC)  : Mon Nov 04 14:35:28 2025
System time     : 0.000000523 seconds fast of NTP time
Last offset     : +0.000001234 seconds
RMS offset      : 0.000002345 seconds
Frequency       : 5.123 ppm slow
Residual freq   : +0.001 ppm
Skew            : 0.123 ppm
Root delay      : 0.012345678 seconds
Root dispersion : 0.001234567 seconds
Update interval : 64.5 seconds
Leap status     : Normal
```

**Valores clave:**
- **Stratum:** Número de saltos al reloj de referencia (3-4 es normal)
- **System time offset:** Debe ser < 1 segundo
- **Leap status: Normal** (no está desincronizado)

### Configuración por Defecto de Chrony

Archivo: `/etc/chrony.conf` (creado por `dnf install chrony`)

```conf
# Use public NTP servers from pool.ntp.org
pool 2.rhel.pool.ntp.org iburst

# Record drift to allow quick sync on boot
driftfile /var/lib/chrony/drift

# Allow system clock to be stepped in first three updates
makestep 1.0 3

# Enable hardware timestamps if available
hwtimestamp *

# Enable kernel sync
rtcsync
```

**Configuración adecuada para Data Guard** (no requiere cambios)

### Verificación

```bash
# Verificar que chronyd está corriendo
systemctl status chronyd
# Output: active (running)

# Verificar sources de tiempo
chronyc sources
# Output:
# MS Name/IP address         Stratum Poll Reach LastRx Last sample
# ===============================================================================
# ^* time.cloudflare.com           3   6   377    34   +123us[+456us] +/-   15ms
# ^- ntp1.wiktel.com               2   6   377    35   +234us[+567us] +/-   23ms

# Verificar que tiempo está sincronizado
timedatectl status
# Output:
#                Local time: Mon 2025-11-04 14:35:30 UTC
#            Universal time: Mon 2025-11-04 14:35:30 UTC
#                  RTC time: Mon 2025-11-04 14:35:30
#                 Time zone: UTC (UTC, +0000)
# System clock synchronized: yes
#               NTP service: active
#           RTC in local TZ: no
```

### Importancia para Data Guard

**CRÍTICO - Sincronización de tiempo es absolutamente necesaria:**

1. **Archive Log Apply:**
   - Standby aplica logs en orden cronológico
   - Timestamps incorrectos → logs aplicados en orden incorrecto
   - Puede causar corrupción de datos

2. **SCN (System Change Number) vs Timestamps:**
   - Oracle usa SCN para ordering de transacciones
   - Pero también verifica consistency con timestamps
   - Diferencia > 5 minutos → alertas ORA-19815

3. **Flashback Database:**
   - Flashback usa timestamps para "rewind" database
   - Timestamps incorrectos → flashback falla

4. **Data Guard Broker:**
   - Broker verifica que relojes estén sincronizados
   - Diferencia > 5 min → configuración falla

5. **Archive Log Sequence:**
   - Logs tienen timestamp en header
   - Standby verifica que timestamp sea consistente con sequence number

**Errores comunes por relojes desincronizados:**
```
ORA-19815: WARNING: db_recovery_file_dest_size of XXX bytes is 100% used
ORA-16191: Primary log shipping client not logged on standby
ORA-16198: Timeout incurred on internal channel during remote archival
```

### Troubleshooting Time Sync Issues

```bash
# Forzar sincronización inmediata
chronyc makestep

# Ver diferencia de tiempo con NTP server
chronyc tracking

# Ver log de chrony
tail -f /var/log/chrony/*.log

# Verificar que no hay conflicto con ntpd
systemctl status ntpd
# Debe estar disabled/stopped

# Configurar timezone a UTC (recomendado para Oracle)
timedatectl set-timezone UTC
```

---

## Archivos Creados/Modificados

### configure_hosts_base.sh

| Archivo | Descripción |
|---------|-------------|
| `/etc/hosts` | Agregadas 2 líneas (primary + standby DNS entries) |

### configure_hostname.sh

| Archivo | Descripción |
|---------|-------------|
| `/etc/hostname` | Contiene FQDN del nodo |

### configure_chrony.sh

| Archivo | Descripción |
|---------|-------------|
| (ninguno) | Solo habilita servicio existente |

---

## Dependencias

### Prerequisitos de configure_hosts_base.sh

- Variables NODE1_PUBLIC_IP, NODE2_PUBLIC_IP en install.env

### Prerequisitos de configure_hostname.sh

- Private network configurada en Vagrantfile
- IP 192.168.56.101 o 192.168.56.102 asignada

### Prerequisitos de configure_chrony.sh

- Paquete `chrony` instalado (por install_os_packages.sh)
- Conectividad a internet (para acceder a NTP servers de pool.ntp.org)

---

## Logs y Verificación

### Verificación Completa de Red

```bash
# Verificar /etc/hosts
cat /etc/hosts | grep "Oracle Data Guard"

# Verificar hostname
hostname
hostname -f  # FQDN

# Verificar resolución DNS local
getent hosts ol8-21-dg1.localdomain
getent hosts ol8-21-dg2.localdomain

# Verificar conectividad a standby (desde primary)
ping -c 2 ol8-21-dg2.localdomain

# Verificar chrony
systemctl status chronyd
chronyc tracking
timedatectl

# Verificar que tiempo está sincronizado en ambos nodos
# (diferencia debe ser < 1 segundo)
vagrant ssh primary -c "date +%s"
vagrant ssh standby -c "date +%s"
```

---

## Puntos de Fallo Comunes

### 1. IP No Detectada Correctamente

**Error en configure_hostname.sh:**
```
ERROR: Unable to determine node from IP: 10.0.2.15
```

**Causa:** Script tomó IP de NAT en lugar de private network

**Solución:**
- Cambiar `awk '{print $2}'` a `awk '{print $3}'` si NAT es diferente
- O detectar IP que empieza con 192.168:
```bash
IP_ADDR=$(hostname -I | tr ' ' '\n' | grep '^192\.168\.')
```

### 2. Hostname No Persiste Después de Reboot

**Causa:** `hostnamectl --static` no usado

**Solución:**
```bash
# Verificar que /etc/hostname tiene el FQDN correcto
cat /etc/hostname

# Si está vacío o incorrecto:
echo "ol8-21-dg1.localdomain" > /etc/hostname
```

### 3. Chrony No Sincroniza (Sin Internet)

**Error:**
```
503 No such source
```

**Causa:** VM no puede acceder a pool.ntp.org

**Solución para ambiente offline:**
```bash
# Configurar host Windows como NTP server
# O usar NTP server local

# Editar /etc/chrony.conf
cat > /etc/chrony.conf << EOF
server 192.168.56.1 iburst  # Windows host
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF

systemctl restart chronyd
```

### 4. Relojes Derivan Con Tiempo

**Síntoma:** Inicialmente sincronizados, después divergen

**Causa:** VirtualBox puede pausar VMs, causando drift

**Solución:**
```bash
# Verificar que RTC sync está habilitado
grep rtcsync /etc/chrony.conf

# Forzar sync periódicamente con cron (workaround)
echo "*/5 * * * * root /usr/bin/chronyc makestep >/dev/null 2>&1" >> /etc/crontab
```

---

## Importancia para Data Guard - Resumen

Estos tres scripts configuran los **fundamentos de red** para Data Guard:

1. **DNS Local (`/etc/hosts`):**
   - Permite que primary y standby se encuentren por nombre
   - Requerido para TNS, Listener, Data Guard Broker

2. **Hostname:**
   - Identifica el nodo en configuraciones Oracle
   - Usado en listener.ora, tnsnames.ora, DG_CONFIG

3. **Time Sync:**
   - **ABSOLUTAMENTE CRÍTICO**
   - Previene corrupción de datos
   - Permite Flashback Database
   - Asegura orden correcto de archive logs

**Sin estos tres componentes, Data Guard NO FUNCIONARÁ.**

---

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Orquestador que llama a estos scripts
- **[33 - Install Packages](33-install-packages.md)** - Instala chrony (prerequisito)
- **[37 - Create Database](37-create-database.md)** - Usa hostnames en tnsnames.ora

### Documentación de Contexto

- **[86 - Networking TNS](../../conceptos-avanzados/86-networking-tns.md)** - Configuración de red Oracle
- **[81 - Data Guard Conceptos](../../conceptos-avanzados/81-data-guard-conceptos.md)** - Requisitos de red

---

**Siguiente:** [35 - Oracle User Environment](35-oracle-user-env.md) - Configuración del entorno de usuario Oracle.
