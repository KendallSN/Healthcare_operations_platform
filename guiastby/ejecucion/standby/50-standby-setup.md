# 50 - Standby Setup - Punto de Entrada del Despliegue

## Descripción General

**Archivo:** `2-Standby/scripts/standby/setup.sh`

**Propósito:** Punto de entrada principal para el despliegue del nodo standby de Oracle Data Guard. Este es el primer script que Vagrant ejecuta cuando se provisiona la VM standby.

**Rol en el flujo:** Wrapper simple que invoca el orquestador principal (`root_setup.sh`) con privilegios de root.

**Tiempo de ejecución:** < 1 segundo (solo invoca otro script)

---

## Tabla de Contenidos

1. [Ubicación en el Flujo de Despliegue](#1-ubicación-en-el-flujo-de-despliegue)
2. [Código Fuente Completo](#2-código-fuente-completo)
3. [Análisis Línea por Línea](#3-análisis-línea-por-línea)
4. [Invocación desde Vagrant](#4-invocación-desde-vagrant)
5. [Comparación con Primary](#5-comparación-con-primary)
6. [Logs y Verificación](#6-logs-y-verificación)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Ubicación en el Flujo de Despliegue

### Flujo Completo del Despliegue Standby

```
Windows Host
    │
    ├─> PowerShell: deploy.ps1
    │
    └─> Vagrant: vagrant up standby
            │
            ├─> Crea VM ol8_21_dg2_standby
            ├─> Configura red (192.168.56.102)
            ├─> Monta synced folders
            │
            └─> Provisioner: shell
                    │
                    ▼
            ┌──────────────────────────────┐
            │  50-standby-setup.sh         │  ◄─── ESTÁS AQUÍ
            │  (Este documento)            │
            └──────────┬───────────────────┘
                       │
                       │ Invoca con sudo
                       ▼
            ┌──────────────────────────────┐
            │  51-root_setup.sh            │
            │  (Orquestador principal)     │
            └──────────┬───────────────────┘
                       │
                       ├─> 52: prepare_disks
                       ├─> 53: install_packages
                       ├─> 54: configure_network
                       ├─> 55: oracle_user_env
                       ├─> 56: install_oracle
                       ├─> 57: rman_duplicate (⭐ CRÍTICO)
                       ├─> 58: setup_automation
                       ├─> 59: setup_ssh
                       └─> 60: install_cron
```

### ¿Por qué un Wrapper?

**Separación de privilegios:**
- `setup.sh` se ejecuta como usuario `vagrant` (sin privilegios)
- Necesitamos privilegios root para:
  - Configurar discos
  - Instalar paquetes
  - Crear usuarios
  - Modificar configuración del sistema
- Solución: usar `sudo bash` para invocar `root_setup.sh`

**Ventajas:**
- Punto de entrada claro y único
- Logs bien definidos (inicio y fin)
- Fácil de invocar desde Vagrant
- Permite debug rápido (timestamp de inicio/fin)

---

## 2. Código Fuente Completo

```bash
#!/bin/bash
# Standby node setup entry point

echo "******************************************************************************"
echo "Starting STANDBY node setup." `date`
echo "******************************************************************************"

# Run root setup script
sudo bash -c 'sh /vagrant/2-Standby/scripts/standby/root_setup.sh'

echo "******************************************************************************"
echo "STANDBY node setup complete." `date`
echo "******************************************************************************"
```

**Total:** 12 líneas (incluyendo comentarios)

---

## 3. Análisis Línea por Línea

### Línea 1: Shebang
```bash
#!/bin/bash
```

**Qué hace:**
- Indica al sistema que este archivo debe ejecutarse con `/bin/bash`
- Permite ejecutar el script directamente: `./setup.sh`

**Alternativas:**
- `#!/bin/sh` - Shell POSIX básico (menos features)
- `#!/usr/bin/env bash` - Busca bash en PATH (más portable)

**Por qué bash:**
- Disponible en Oracle Linux 8
- Soporte completo de features (arrays, funciones, etc.)
- Estándar de facto en scripts de automatización Oracle

---

### Líneas 2-3: Comentario Descriptivo
```bash
# Standby node setup entry point
```

**Propósito:**
- Documentación inline del propósito del script
- Visible con `head setup.sh`

---

### Líneas 4-6: Banner de Inicio
```bash
echo "******************************************************************************"
echo "Starting STANDBY node setup." `date`
echo "******************************************************************************"
```

**Qué hace:**
- Imprime banner visual en los logs de Vagrant
- Incluye timestamp con `` `date` `` (backticks)
- Facilita encontrar el inicio en logs largos

**Ejemplo de salida:**
```
******************************************************************************
Starting STANDBY node setup. Mon Nov  4 16:30:15 UTC 2025
******************************************************************************
```

**Por qué es importante:**
- Los logs de `vagrant up standby` son muy largos (miles de líneas)
- Este banner permite buscar rápidamente: `/Starting STANDBY node setup`
- El timestamp permite calcular tiempo total de ejecución

---

### Líneas 8-9: Invocación del Orquestador
```bash
# Run root setup script
sudo bash -c 'sh /vagrant/2-Standby/scripts/standby/root_setup.sh'
```

**Desglose del comando:**

```bash
sudo                                      # Elevar a privilegios root
bash -c                                  # Ejecutar comando en subshell bash
'sh /vagrant/..../root_setup.sh'         # Comando a ejecutar
```

**¿Por qué `bash -c 'sh ...'`?**
- `sudo bash -c` - Ejecuta comando bash como root
- `sh script.sh` - Ejecuta el script en subshell
- Alternativa equivalente: `sudo bash /vagrant/.../root_setup.sh`

**Ruta completa:**
- `/vagrant/` - Synced folder montado por Vagrant (mapea raíz del proyecto)
- `2-Standby/scripts/standby/` - Subdirectorio de scripts standby
- `root_setup.sh` - Orquestador principal

**Sincrónico:**
- Este comando es **bloqueante**
- `setup.sh` espera a que `root_setup.sh` termine completamente
- Duración: 20-30 minutos (todo el despliegue standby)

---

### Líneas 11-13: Banner de Finalización
```bash
echo "******************************************************************************"
echo "STANDBY node setup complete." `date`
echo "******************************************************************************"
```

**Qué hace:**
- Imprime banner de éxito
- Incluye timestamp de finalización
- Solo se imprime si `root_setup.sh` termina sin errores

**Ejemplo de salida:**
```
******************************************************************************
STANDBY node setup complete. Mon Nov  4 16:58:42 UTC 2025
******************************************************************************
```

**Cálculo de tiempo:**
```
Inicio:  16:30:15
Fin:     16:58:42
Duración: 28 minutos 27 segundos
```

**Si no ves este banner:**
- Significa que `root_setup.sh` falló con error
- Revisa logs anteriores para encontrar el error

---

## 4. Invocación desde Vagrant

### Configuración en Vagrantfile

**Vagrantfile (raíz del proyecto):**
```ruby
config.vm.define "standby" do |standby|
  # VM configuration...

  standby.vm.provision "shell", name: "root_setup", run: "once" do |s|
    s.path = "2-Standby/scripts/standby/setup.sh"
  end
end
```

**Parámetros del provisioner:**
- `run: "once"` - Solo ejecutar en primer `vagrant up`, no en `vagrant reload`
- `s.path` - Ruta relativa al Vagrantfile (raíz del proyecto)

**Vagrant traduce esto a:**
```bash
# Dentro de la VM
/bin/bash /vagrant/2-Standby/scripts/standby/setup.sh
```

---

### Comando para Ejecutar

**Despliegue completo:**
```bash
vagrant up standby
```

**Solo este provisioner:**
```bash
vagrant provision standby --provision-with root_setup
```

**Desde PowerShell (deploy.ps1):**
```powershell
# Fase 5 del deploy.ps1
vagrant up standby
```

---

### Variables de Entorno Disponibles

Cuando Vagrant ejecuta este script, estas variables están disponibles:

```bash
$HOME = /home/vagrant
$USER = vagrant
$PWD = /home/vagrant
```

**Synced folders montados:**
```
/vagrant/                    → Raíz del proyecto
/vagrant_config/             → config/
/vagrant_scripts/            → 2-Standby/infrastructure/
/vagrant_automation/         → 2-Standby/automation/
/vagrant_sql_scripts/        → 1-BD/SQL-VM scripts/
/vagrant_directories/        → 1-BD/directories/
```

**Acceso a install.env:**
```bash
# En root_setup.sh:
. /vagrant_config/install.env
```

---

## 5. Comparación con Primary

### setup.sh - Primary vs Standby

**Primary (`2-Standby/scripts/primary/setup.sh`):**
```bash
#!/bin/bash
# Primary node setup entry point

echo "******************************************************************************"
echo "Starting PRIMARY node setup." `date`
echo "******************************************************************************"

sudo bash -c 'sh /vagrant/2-Standby/scripts/primary/root_setup.sh'

echo "******************************************************************************"
echo "PRIMARY node setup complete." `date`
echo "******************************************************************************"
```

**Diferencias:**
1. **Texto del banner:** "PRIMARY" vs "STANDBY"
2. **Ruta del root_setup.sh:** `.../primary/...` vs `.../standby/...`
3. **Todo lo demás es idéntico**

**Por qué son casi idénticos:**
- Ambos son wrappers simples
- Ambos invocan un orquestador principal
- La lógica compleja está en `root_setup.sh`, no aquí

---

## 6. Logs y Verificación

### Ubicación de Logs

**Durante ejecución de `vagrant up standby`:**
- Consola de PowerShell/terminal
- Archivo: `powershell/logs/deploy-TIMESTAMP/04-standby-vagrant.log`

**Ver en tiempo real (desde otra terminal):**
```powershell
Get-Content .\powershell\logs\deploy-TIMESTAMP\04-standby-vagrant.log -Wait
```

---

### Qué Buscar en los Logs

**Banner de inicio (correcto):**
```
==> standby: Running provisioner: shell...
    standby: Running: C:/.../2-Standby/scripts/standby/setup.sh
    standby: ******************************************************************************
    standby: Starting STANDBY node setup. Mon Nov  4 16:30:15 UTC 2025
    standby: ******************************************************************************
```

**Banner de finalización (éxito):**
```
    standby: ******************************************************************************
    standby: STANDBY node setup complete. Mon Nov  4 16:58:42 UTC 2025
    standby: ******************************************************************************
```

**Error típico:**
```
    standby: Starting STANDBY node setup. Mon Nov  4 16:30:15 UTC 2025
    standby: /vagrant/2-Standby/scripts/standby/root_setup.sh: line 42: syntax error
The SSH command responded with a non-zero exit status.
```
- No hay banner de finalización
- Mensaje de error antes del banner de fin
- `vagrant up` falla y no termina

---

### Verificar que el Script se Ejecutó

**Dentro de la VM:**
```bash
vagrant ssh standby

# Ver si el orquestador creó logs
ls -l /home/oracle/logs/
```

**Si el setup.sh ni siquiera empezó:**
- Verifica que el archivo existe: `ls -l /vagrant/2-Standby/scripts/standby/setup.sh`
- Verifica permisos: `stat /vagrant/2-Standby/scripts/standby/setup.sh`
- Verifica line endings: `file /vagrant/2-Standby/scripts/standby/setup.sh`
  - Debe decir: `ASCII text` (no `ASCII text, with CRLF line terminators`)

---

## 7. Troubleshooting

### Problema: "No such file or directory: setup.sh"

**Error:**
```
/bin/bash: /vagrant/2-Standby/scripts/standby/setup.sh: No such file or directory
```

**Causas posibles:**
1. Synced folder no montado
2. Ruta incorrecta en Vagrantfile
3. VirtualBox Guest Additions desactualizadas

**Solución:**
```bash
# Dentro de la VM
ls -la /vagrant/2-Standby/scripts/standby/

# Si no existe, problema con synced folders
vagrant plugin install vagrant-vbguest
vagrant reload standby
```

---

### Problema: "Permission denied"

**Error:**
```
bash: ./setup.sh: Permission denied
```

**Causa:**
- Script no tiene permisos de ejecución

**Solución:**
```bash
# Desde raíz del proyecto en Windows
icacls "2-Standby\scripts\standby\setup.sh" /grant Everyone:RX

# O dentro de la VM
chmod +x /vagrant/2-Standby/scripts/standby/setup.sh
```

---

### Problema: "line 2: $'\r': command not found"

**Error:**
```
/vagrant/2-Standby/scripts/standby/setup.sh: line 2: $'\r': command not found
```

**Causa:**
- Line endings Windows (CRLF) en lugar de Linux (LF)

**Solución:**
```powershell
# Desde raíz del proyecto en Windows
.\powershell\fix-line-endings.ps1

# Re-ejecutar
vagrant provision standby --provision-with root_setup
```

---

### Problema: setup.sh ejecuta pero root_setup.sh falla

**Síntoma:**
- Banner de inicio se imprime
- Banner de fin NO se imprime
- Error en el medio

**Diagnóstico:**
```bash
vagrant ssh standby

# Ejecutar manualmente para ver error detallado
sudo bash -c 'sh /vagrant/2-Standby/scripts/standby/root_setup.sh'
```

**Solución:**
- Depende del error específico de root_setup.sh
- Ver: [51-standby-root-setup.md](51-standby-root-setup.md)

---

### Problema: Script ejecuta muy rápido (< 1 segundo)

**Síntoma:**
```
Starting STANDBY node setup. Mon Nov  4 16:30:15 UTC 2025
STANDBY node setup complete. Mon Nov  4 16:30:16 UTC 2025
```

**Causa:**
- `root_setup.sh` salió inmediatamente (posiblemente con error silencioso)
- O el script está vacío/comentado

**Diagnóstico:**
```bash
vagrant ssh standby

# Ver si root_setup.sh existe
ls -l /vagrant/2-Standby/scripts/standby/root_setup.sh

# Ver contenido
head -20 /vagrant/2-Standby/scripts/standby/root_setup.sh

# Ejecutar manualmente
sudo bash -x /vagrant/2-Standby/scripts/standby/root_setup.sh
```

---

### Problema: Vagrant no ejecuta el provisioner

**Síntoma:**
- `vagrant up standby` no muestra líneas de setup.sh

**Causas posibles:**
1. Provisioner ya ejecutado (VM existe)
2. Provisioner configurado con `run: "never"`

**Solución:**
```bash
# Forzar re-provisioning
vagrant provision standby --provision-with root_setup

# O destruir y recrear
vagrant destroy -f standby
vagrant up standby
```

---

## Resumen

### Puntos Clave

1. **Wrapper Simple:** setup.sh es solo un punto de entrada, no hace lógica compleja
2. **Invocación con Privilegios:** Usa `sudo bash` para ejecutar root_setup.sh
3. **Banners Importantes:** Facilitan encontrar inicio/fin en logs
4. **Sincrónico:** Bloquea hasta que todo el despliegue termina
5. **Idéntico a Primary:** Excepto por rutas y texto de banners

### Archivos Relacionados

- **Siguiente:** [51-standby-root-setup.md](51-standby-root-setup.md) - Orquestador principal
- **Equivalente Primary:** `2-Standby/scripts/primary/setup.sh`
- **Invocado por:** Vagrantfile provisioner
- **Invoca a:** root_setup.sh

### Comandos Útiles

```bash
# Ejecutar solo este provisioner
vagrant provision standby --provision-with root_setup

# Ver logs en tiempo real
Get-Content .\powershell\logs\deploy-TIMESTAMP\04-standby-vagrant.log -Wait

# Debug dentro de la VM
vagrant ssh standby
sudo bash -x /vagrant/2-Standby/scripts/standby/setup.sh

# Verificar line endings
file /vagrant/2-Standby/scripts/standby/setup.sh
```

---

**Siguiente:** [51 - Standby Root Setup - Orquestador Principal](51-standby-root-setup.md)

Este script simple pero crítico marca el inicio del despliegue standby. Todo lo interesante sucede en root_setup.sh y los scripts que invoca.
