# 30 - Primary Setup - Punto de Entrada

## Script de Inicio del Nodo Primario

Este es el punto de entrada principal para el despliegue automatizado del nodo primario de Oracle Data Guard. Es un wrapper simple que invoca el script orquestador principal con privilegios de root.

## Ubicación

`2-Standby/scripts/primary/setup.sh`

## Propósito

- **Función principal:** Punto de entrada inicial llamado por Vagrant durante el provisionamiento
- **Responsabilidad:** Delegar la ejecución al script `root_setup.sh` con privilegios elevados
- **Simplicidad:** Script intencionalmente minimalista para facilitar debugging y logs claros

## Cuándo se Ejecuta

- **Llamado por:** Vagrant durante `vagrant up primary` o `vagrant provision primary`
- **Orden:** Primer script en ejecutarse (Paso 1 de 12 en el flujo de despliegue primario)
- **Usuario:** `vagrant` (usuario predeterminado de Vagrant)
- **Timing:** Inmediatamente después de que la VM arranca y VirtualBox Guest Additions se instala

### Contexto de Ejecución en Vagrantfile

```ruby
primary.vm.provision "shell",
  name: "setup",
  path: "2-Standby/scripts/primary/setup.sh",
  privileged: false  # Se ejecuta como usuario vagrant
```

## Variables de Entorno Utilizadas

**Ninguna directamente.** Este script no carga `install.env`, simplemente delega al script siguiente que sí lo hace.

## Flujo de Ejecución Paso a Paso

### Paso 1: Mostrar Banner de Inicio

```bash
echo "******************************************************************************"
echo "Starting PRIMARY node setup." `date`
echo "******************************************************************************"
```

**Explicación:**
- Imprime un banner visual claro para identificar el inicio del proceso en los logs
- Incluye timestamp para tracking de duración
- Separadores `****` facilitan localizar secciones en logs largos

### Paso 2: Invocar Script Root Setup con Privilegios Elevados

```bash
sudo bash -c 'sh /vagrant/2-Standby/scripts/primary/root_setup.sh'
```

**Explicación:**
- `sudo`: Eleva privilegios a root (necesario para instalaciones del sistema)
- `bash -c 'sh ...'`: Ejecuta el script en una nueva shell con contexto limpio
- `/vagrant/`: Ruta del directorio sincronizado de Vagrant (corresponde a la raíz del proyecto en Windows)
- `root_setup.sh`: Script orquestador principal que coordina todos los pasos siguientes

**¿Por qué usar `bash -c 'sh ...'` en lugar de `sudo sh ...` directamente?**
- Asegura que el script se ejecute en un contexto shell limpio
- Evita problemas de herencia de variables de entorno del usuario vagrant
- Previene conflictos con paths relativos

### Paso 3: Mostrar Banner de Finalización

```bash
echo "******************************************************************************"
echo "PRIMARY node setup complete." `date`
echo "******************************************************************************"
```

**Explicación:**
- Indica que toda la cadena de provisionamiento completó exitosamente
- Segundo timestamp permite calcular duración total
- Facilita detección visual del fin del proceso en logs

## Archivos Creados/Modificados

Este script no crea ni modifica archivos directamente. Toda la lógica de provisionamiento está delegada a `root_setup.sh`.

## Dependencias

### Scripts que Deben Existir

- `/vagrant/2-Standby/scripts/primary/root_setup.sh` - Script orquestador principal

### Prerequisitos del Sistema

- VM debe estar arrancada y accesible
- VirtualBox Guest Additions debe estar instalado (para synced folders)
- Directorio `/vagrant` debe estar montado y accesible
- Usuario vagrant debe tener permisos sudo sin contraseña

### Dependencias de Vagrant

```ruby
# En Vagrantfile
config.vm.synced_folder ".", "/vagrant"
```

El directorio raíz del proyecto debe estar sincronizado en `/vagrant/` dentro de la VM.

## Logs y Verificación

### Ubicación de Logs en Windows Host

Durante el despliegue con `deploy.ps1`:
```
powershell/logs/deploy-YYYY-MM-DD-HHMMSS/primary-setup.log
```

### Ubicación de Logs en VM

Logs de Vagrant:
```bash
# Ver logs completos de provisionamiento
vagrant ssh primary -c "cat /var/log/vagrant-provision.log"
```

### Comandos de Verificación

```bash
# Verificar que el script existe y es ejecutable
vagrant ssh primary -c "ls -la /vagrant/2-Standby/scripts/primary/setup.sh"

# Ver contenido del script
vagrant ssh primary -c "cat /vagrant/2-Standby/scripts/primary/setup.sh"

# Ver últimas líneas de logs de provisionamiento
vagrant ssh primary -c "sudo tail -50 /var/log/messages | grep -i vagrant"
```

### Indicadores de Éxito

**En consola de PowerShell:**
```
primary: ******************************************************************************
primary: Starting PRIMARY node setup. Mon Nov  4 14:35:22 UTC 2025
primary: ******************************************************************************
primary: ******************************************************************************
primary: PRIMARY Root Setup Started. Mon Nov  4 14:35:23 UTC 2025
primary: ******************************************************************************
...
primary: ******************************************************************************
primary: PRIMARY Root Setup Complete. Mon Nov  4 15:18:45 UTC 2025
primary: ******************************************************************************
primary: ******************************************************************************
primary: PRIMARY node setup complete. Mon Nov  4 15:18:46 UTC 2025
primary: ******************************************************************************
```

**Duración esperada:** 35-45 minutos (todo el flujo de root_setup.sh)

## Puntos de Fallo Comunes

### 1. Synced Folder No Disponible

**Error:**
```
sh: /vagrant/2-Standby/scripts/primary/root_setup.sh: No such file or directory
```

**Causa:** VirtualBox Guest Additions no instalado o desactualizado

**Solución:**
```bash
# Instalar plugin vagrant-vbguest
vagrant plugin install vagrant-vbguest

# Recargar VM para actualizar Guest Additions
vagrant reload primary
```

### 2. Permisos Insuficientes

**Error:**
```
Sorry, user vagrant is not allowed to execute '/bin/sh /vagrant/...' as root
```

**Causa:** Configuración sudo incorrecta en la box base

**Solución:**
- Usar una box base de Oracle Linux oficial que incluya configuración sudo correcta
- Verificar: `vagrant ssh primary -c "sudo whoami"` debe retornar `root`

### 3. Line Endings Incorrectos (CRLF)

**Error:**
```
': not a valid identifier: 'oot_setup.sh: line 2: `ORACLE_BASE
```

**Causa:** Script tiene line endings Windows (CRLF) en lugar de Unix (LF)

**Solución:**
```powershell
# Ejecutar antes de vagrant up
.\powershell\fix-line-endings.ps1
```

O automáticamente con `deploy.ps1` que incluye esta corrección.

### 4. Script root_setup.sh No Ejecutable

**Error:**
```
bash: /vagrant/2-Standby/scripts/primary/root_setup.sh: Permission denied
```

**Causa:** El archivo no tiene permisos de ejecución

**Solución:**
```bash
# En Git (desde Windows)
git update-index --chmod=+x 2-Standby/scripts/primary/root_setup.sh
git commit -m "Make root_setup.sh executable"

# Directamente en el proyecto
chmod +x 2-Standby/scripts/primary/root_setup.sh
```

**Nota:** Los permisos de ejecución en synced folders de Windows son limitados. El script usa `sh <script>` en lugar de `./<script>` para evitar este problema.

## Importancia para Data Guard

### Rol en la Arquitectura

Este script es el **punto de control de entrada** que garantiza:

1. **Trazabilidad:** Logs claros de inicio/fin del proceso completo
2. **Aislamiento:** Ejecución en contexto limpio sin variables heredadas
3. **Debugging:** Separación clara entre invocación de Vagrant y lógica de provisionamiento
4. **Atomicidad:** Si falla cualquier paso en root_setup.sh, este script captura el error

### Por Qué No Se Hace Todo en Vagrantfile

**Alternativa no usada:**
```ruby
# Podríamos llamar directamente a root_setup.sh desde Vagrantfile
primary.vm.provision "shell",
  path: "2-Standby/scripts/primary/root_setup.sh",
  privileged: true
```

**Razones para usar este wrapper:**

1. **Logs más claros:** Banners de inicio/fin visibles en salida de Vagrant
2. **Flexibilidad:** Permite pre-procesamiento o post-procesamiento futuro
3. **Debugging:** Facilita ejecutar manualmente: `vagrant ssh primary -c "sh /vagrant/2-Standby/scripts/primary/setup.sh"`
4. **Consistencia:** Patrón uniforme para primary y standby

## Referencias Cruzadas

### Scripts Relacionados

- **[31 - Primary Root Setup](31-primary-root-setup.md)** - Script orquestador invocado por este
- **[50 - Standby Setup](../standby/50-standby-setup.md)** - Equivalente para nodo standby

### Documentación de Contexto

- **[04 - Cómo Usar](../../04-como-usar.md)** - Guía de usuario para ejecutar deploy.ps1
- **[20 - Vagrantfile](../20-vagrantfile.md)** - Configuración de Vagrant que llama a este script
- **[10 - Deploy PowerShell](../10-deploy-powershell.md)** - Orquestación desde PowerShell

### Flujo Completo

```
deploy.ps1
  └─> vagrant up primary
      └─> setup.sh (ESTE SCRIPT)
          └─> root_setup.sh
              └─> 12 scripts de provisionamiento...
```

## Ejemplo de Ejecución Manual

### Desde Windows Host

```powershell
# Via Vagrant
vagrant provision primary --provision-with setup

# Ver logs en tiempo real
vagrant up primary | Tee-Object -FilePath "primary-setup-manual.log"
```

### Desde Dentro de la VM

```bash
# SSH a la VM
vagrant ssh primary

# Ejecutar manualmente (requiere synced folder funcionando)
sudo sh /vagrant/2-Standby/scripts/primary/setup.sh
```

**⚠️ Advertencia:** Ejecutar manualmente puede causar problemas si ya se ejecutó antes, ya que algunos pasos no son idempotentes (e.g., creación de base de datos).

## Mejoras Futuras Posibles

1. **Pre-flight Checks:** Verificar que synced folders están montados antes de continuar
2. **Lock File:** Crear `/tmp/primary-setup.lock` para prevenir ejecuciones simultáneas
3. **Resumen de Estado:** Mostrar resumen de recursos del sistema antes de comenzar
4. **Estimación de Tiempo:** Informar al usuario que el proceso tomará ~40 minutos

## Código Fuente Completo

```bash
#!/bin/bash
# Primary node setup entry point

echo "******************************************************************************"
echo "Starting PRIMARY node setup." `date`
echo "******************************************************************************"

# Run root setup script
sudo bash -c 'sh /vagrant/2-Standby/scripts/primary/root_setup.sh'

echo "******************************************************************************"
echo "PRIMARY node setup complete." `date`
echo "******************************************************************************"
```

**Total:** 14 líneas (incluyendo comentarios y líneas en blanco)

---

**Siguiente:** [31 - Primary Root Setup](31-primary-root-setup.md) - El orquestador principal que coordina los 12 pasos del despliegue primario.
