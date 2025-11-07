# 54 - Configuración de Red en Standby

## Descripción General

**Scripts:**
- `2-Standby/infrastructure/configure_hosts_base.sh`
- `2-Standby/infrastructure/configure_hostname.sh`
- `2-Standby/infrastructure/configure_chrony.sh`

**Propósito:** Configurar resolución de nombres, hostname del nodo, y sincronización de tiempo.

**Compartido:** Scripts son idénticos, pero valores de hostname son específicos del nodo.

**Tiempo de ejecución:** ~20 segundos

---

## 1. Configurar /etc/hosts

### Script: configure_hosts_base.sh

```bash
cat >> /etc/hosts <<EOF
192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
192.168.56.102  ol8-21-dg2.localdomain ol8-21-dg2
EOF
```

**Resultado en /etc/hosts:**
```
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain

192.168.56.101  ol8-21-dg1.localdomain ol8-21-dg1
192.168.56.102  ol8-21-dg2.localdomain ol8-21-dg2
```

**Por qué es crítico:**
- Oracle Data Guard usa hostnames para comunicación
- `tnsnames.ora` referencia estos hostnames
- Broker usa FQDN (Fully Qualified Domain Names)
- Debe ser IDÉNTICO en primary y standby

---

## 2. Configurar Hostname

### Script: configure_hostname.sh

```bash
hostnamectl set-hostname ${NODE2_FQ_HOSTNAME}
# Valor: ol8-21-dg2.localdomain
```

**Antes:**
```bash
[vagrant@localhost ~]$ hostname
localhost.localdomain
```

**Después:**
```bash
[oracle@ol8-21-dg2 ~]$ hostname
ol8-21-dg2.localdomain

[oracle@ol8-21-dg2 ~]$ hostname -s
ol8-21-dg2

[oracle@ol8-21-dg2 ~]$ hostname -f
ol8-21-dg2.localdomain
```

**Diferencia con Primary:**
- Primary: `ol8-21-dg1.localdomain`
- Standby: `ol8-21-dg2.localdomain` ⭐

**Persistente:**
- `hostnamectl` modifica `/etc/hostname`
- Persiste después de reinicios

---

## 3. Configurar Sincronización de Tiempo

### Script: configure_chrony.sh

```bash
# Instalar chronyd
yum install -y chrony

# Configurar /etc/chrony.conf
cat > /etc/chrony.conf <<EOF
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

# Habilitar y arrancar
systemctl enable chronyd
systemctl start chronyd
```

**Por qué es importante para Data Guard:**
- Archive logs tienen timestamps
- Si clocks difieren mucho, puede haber problemas de ordenamiento
- Apply process es sensible a diferencias de tiempo
- Recomendado: < 5 segundos de diferencia

**Verificar sincronización:**
```bash
chronyc tracking

# Debe mostrar:
Reference ID    : 1.2.3.4 (ntp.server.com)
Stratum         : 3
Ref time (UTC)  : Mon Nov 04 17:00:00 2025
System time     : 0.000123456 seconds slow of NTP time
Last offset     : +0.000098765 seconds
RMS offset      : 0.000234567 seconds
...
```

**Diferencia con Primary:**
- Configuración IDÉNTICA
- Ambos se sincronizan con mismos servidores NTP públicos
- Resultado: clocks sincronizados entre nodos

---

## 4. Verificar Conectividad entre Nodos

### Desde Standby → Primary

```bash
# Ping por IP
ping -c 3 192.168.56.101

# Ping por hostname corto
ping -c 3 ol8-21-dg1

# Ping por FQDN
ping -c 3 ol8-21-dg1.localdomain

# Todos deben responder
```

### Resolución Inversa

```bash
# Resolver IP a hostname
host 192.168.56.101
# Debe mostrar: ol8-21-dg1.localdomain

host 192.168.56.102
# Debe mostrar: ol8-21-dg2.localdomain
```

---

## 5. Configuración de Red VirtualBox

### Interfaces de Red (ambos nodos)

**eth0 (NAT):**
- IP: 10.0.2.15 (DHCP)
- Gateway: 10.0.2.2
- Propósito: Acceso a Internet (yum, ntp)

**eth1 (Host-Only Network):**
- IP Primary: 192.168.56.101 (estático)
- IP Standby: 192.168.56.102 (estático) ⭐
- Network: 192.168.56.0/24
- Propósito: Comunicación Data Guard y acceso desde host

### Port Forwarding (Host Windows → Standby VM)

| Servicio | VM Port | Host Port |
|----------|---------|-----------|
| Oracle Listener | 1521 | **1522** ⭐ |
| Enterprise Manager | 5500 | **5501** ⭐ |
| SSH | 22 | 2202 |

**Nota:** Puertos del host son diferentes a primary para evitar conflictos.

---

## Archivos TNS (creados más adelante)

Estos se crean en etapa 9 (oracle_create_database.sh):

### tnsnames.ora (IDÉNTICO en primary y standby)

```
cdb1.world =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = cdb1)
    )
  )

cdb1_stby.world =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ol8-21-dg2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = cdb1)
    )
  )
```

**Usan los hostnames configurados aquí.**

---

## Resumen de Configuración de Red

### Primary
- Hostname: `ol8-21-dg1.localdomain`
- IP: `192.168.56.101`
- Listener: 1521
- Host port: 1521

### Standby
- Hostname: `ol8-21-dg2.localdomain` ⭐
- IP: `192.168.56.102` ⭐
- Listener: 1521 (interno)
- Host port: **1522** ⭐ (diferente)

---

## Troubleshooting

### Problema: No resuelve hostname

```bash
ping ol8-21-dg1
ping: ol8-21-dg1: Name or service not known
```

**Solución:**
```bash
# Verificar /etc/hosts
cat /etc/hosts | grep ol8-21-dg

# Re-ejecutar script
sh /vagrant_scripts/configure_hosts_base.sh
```

### Problema: Clocks desincronizados

```bash
# Ver offset de tiempo
chronyc tracking | grep "System time"

# Si offset > 5 segundos:
systemctl restart chronyd
chronyc makestep
```

---

**Siguiente:** [55 - Configuración Entorno Usuario Oracle](55-oracle-user-env.md)
