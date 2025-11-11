# Guía de Compilación del Manual (StandbyGuide.tex)

## Resumen de Cambios Realizados

✅ **Typo corregido**: "catastficos" → "catastróficos" (línea 212)

✅ **Nota de alcance del esquema**: Agregada aclaración de que los detalles del esquema de aplicación están fuera del alcance (línea 135)

✅ **Nuevo Capítulo 5**: "Procedimientos de Prueba y Validación" con:
- Pruebas de switchover paso a paso
- Simulación de failover de emergencia
- Validación de backups RMAN
- Prueba de recuperación de archive gaps
- Plan de simulacros (DR drills)

✅ **Diagramas añadidos**:
- Diagrama de flujo de backups (Figura en Capítulo 4)
- Árbol de decisión para failover (Figura en Capítulo 4)

✅ **Nuevo Apéndice D**: "Glosario de Términos y Acrónimos" con definiciones de:
- Acrónimos de Oracle Database (CDB, PDB, FRA, RMAN, SYS)
- Acrónimos de Data Guard (DG, DGMGRL, MRP, LNS, RFS, FAL, LGWR, ARCn)
- Términos de Alta Disponibilidad (HA, DR, RTO, RPO, Switchover, Failover, etc.)
- Modos de protección y transporte
- Términos de infraestructura (VirtualBox, Vagrant, Synced Folders, XFS, SSH, rsync)
- Procesos de automatización (Cron, Alert Log, TNS, Listener)

✅ **Nuevo Apéndice E**: "Tarjeta de Referencia Rápida" con:
- Cadenas de conexión (desde Windows y desde VMs)
- Comandos de Vagrant esenciales
- Comandos DGMGRL (Data Guard Broker)
- Consultas SQL de monitoreo
- Comandos RMAN esenciales
- Scripts de automatización
- Procedimientos de emergencia

## Requisitos para Compilar el PDF

### Opción 1: Windows con MiKTeX (RECOMENDADO)

1. **Instalar MiKTeX** (distribución LaTeX para Windows):
   - Descargar desde: https://miktex.org/download
   - Instalar con la opción "Install missing packages on-the-fly = Yes"

2. **Ejecutar el script de compilación**:
   ```cmd
   cd C:\path\to\AdminBDProyecto-STBY
   compile_guide.bat
   ```

3. El PDF se generará automáticamente como `StandbyGuide.pdf`

### Opción 2: Windows con TeX Live

1. **Instalar TeX Live**:
   - Descargar desde: https://tug.org/texlive/acquire-netinstall.html
   - Instalación completa (~7 GB) o instalación básica + paquetes adicionales

2. **Compilar manualmente**:
   ```cmd
   cd C:\path\to\AdminBDProyecto-STBY
   lualatex -interaction=nonstopmode StandbyGuide.tex
   lualatex -interaction=nonstopmode StandbyGuide.tex
   lualatex -interaction=nonstopmode StandbyGuide.tex
   ```
   (Se requieren 3 compilaciones para resolver referencias cruzadas y tabla de contenidos)

### Opción 3: Linux/macOS

1. **Instalar TeX Live**:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install texlive-xetex texlive-latex-extra texlive-fonts-recommended \
                        texlive-lang-spanish texlive-luatex fonts-noto

   # macOS (con Homebrew)
   brew install --cask mactex
   ```

2. **Compilar**:
   ```bash
   cd /path/to/AdminBDProyecto-STBY
   lualatex -interaction=nonstopmode StandbyGuide.tex
   lualatex -interaction=nonstopmode StandbyGuide.tex
   lualatex -interaction=nonstopmode StandbyGuide.tex
   ```

### Opción 4: Overleaf (Online, Sin Instalación)

1. Ir a: https://www.overleaf.com/
2. Crear una cuenta gratuita
3. Crear nuevo proyecto → Upload Project → Subir `StandbyGuide.tex`
4. Configurar el compilador:
   - Menu → Settings → Compiler: **LuaLaTeX**
5. Click en "Recompile" → El PDF se genera automáticamente

## Paquetes LaTeX Necesarios

El documento requiere los siguientes paquetes (instalados automáticamente con MiKTeX/TeX Live completos):

- `geometry` - Márgenes y tamaño de página
- `amsmath`, `amssymb` - Símbolos matemáticos
- `booktabs` - Tablas profesionales
- `enumitem` - Listas personalizadas
- `fancyhdr` - Encabezados y pies de página
- `xcolor` - Colores
- `tikz` (con bibliotecas: arrows.meta, positioning, shapes, fit, backgrounds, shadows) - Diagramas
- `fontspec` - Fuentes personalizadas (requiere LuaLaTeX o XeLaTeX)
- `babel` - Soporte multiidioma
- `hyperref` - Hipervínculos y PDF interactivo
- `listings` - Bloques de código
- `needspace` - Prevención de cortes de página en bloques de código
- Fuente: **Noto Sans** (incluida en la mayoría de distribuciones)

## Prevenir Cortes de Bloques de Código Entre Páginas

El documento incluye mejoras para evitar que los bloques de código se corten al final de las páginas:

### Características Automáticas

✅ **Ajuste automático de líneas largas**: Las líneas que exceden el margen se ajustan automáticamente dentro del bloque
✅ **Indicador de continuación**: Aparece una flecha roja (→) cuando una línea continúa en la siguiente línea
✅ **Ruptura inteligente**: Prefiere romper en espacios en blanco cuando sea posible

### Uso del Comando `\lstneedspace` (Opcional)

Para bloques de código críticos que no deben cortarse entre páginas:

```latex
% Antes de un bloque de código grande:
\lstneedspace
\begin{lstlisting}[language=bash, caption={Mi comando importante}]
# Código que no debe cortarse
comando_largo_aqui
\end{lstlisting}
```

**Cuándo usar `\lstneedspace`**:
- Bloques de código de 10+ líneas
- Comandos complejos que deben verse completos
- Procedimientos críticos paso a paso

**Comportamiento**: Si no hay suficiente espacio en la página actual (al menos 10 líneas), LaTeX automáticamente moverá el bloque a la página siguiente.

## Solución de Problemas

### Error: "Font 'Noto Sans' not found"

**Solución**:
1. Instalar la fuente Noto Sans:
   - Windows: Descargar de https://fonts.google.com/noto/specimen/Noto+Sans
   - Instalar haciendo doble clic en el archivo .ttf
2. O cambiar la fuente en el documento (línea 27):
   ```latex
   \babelfont{rm}{Arial}  % o cualquier fuente instalada
   ```

### Error: "Package tikz not found"

**Solución**: Instalar paquete faltante:
```cmd
# MiKTeX (como administrador)
mpm --install=pgf

# TeX Live
tlmgr install pgf
```

### Error: "Undefined control sequence \usetikzlibrary"

**Solución**: El paquete tikz está incompleto. Reinstalar:
```cmd
# MiKTeX
mpm --update=pgf

# TeX Live
tlmgr install pgf tikz-cd
```

### Compilación muy lenta

**Causa**: Los diagramas TikZ son complejos y requieren tiempo.

**Solución**: Es normal. Primera compilación: ~2-5 minutos. Siguientes: ~1-2 minutos.

### Warnings sobre "Overfull/Underfull hbox"

**Causa**: Avisos sobre espaciado de líneas (no críticos).

**Solución**: Ignorar si el PDF se ve bien. Para corregir, ajustar manualmente los anchos de columna en tablas.

## Estructura del Documento Final

El PDF generado tendrá aproximadamente **100+ páginas** con la siguiente estructura:

1. **Portada** - Título, autores, universidad
2. **Tabla de Contenidos** - Navegación completa
3. **Capítulo 1**: Introducción y Conceptos Fundamentales
4. **Capítulo 2**: Arquitectura y Configuración Detallada
5. **Capítulo 3**: Guía de Uso y Operaciones
6. **Capítulo 4**: Operaciones y Mantenimiento Diario
7. **Capítulo 5**: Procedimientos de Prueba y Validación (NUEVO)
8. **Capítulo 6**: Conclusiones y Recomendaciones Finales
9. **Apéndice A**: Análisis Detallado - Despliegue del Nodo Principal
10. **Apéndice B**: Análisis Detallado - Despliegue del Nodo Standby
11. **Apéndice C**: Análisis Detallado - Scripts de Automatización
12. **Apéndice D**: Glosario de Términos y Acrónimos (NUEVO)
13. **Apéndice E**: Tarjeta de Referencia Rápida (NUEVO)
14. **Apéndice F**: Bibliografía y Recursos Adicionales

## Verificación del PDF Generado

Después de compilar, verificar que el PDF contenga:

✅ Diagramas renderizados correctamente (arquitectura, backup flow, árbol de decisión)
✅ Tabla de contenidos con números de página
✅ Hipervínculos funcionando (click en TOC navega a la sección)
✅ Bloques de código con sintaxis resaltada
✅ Fuente Noto Sans (o fuente alternativa si se cambió)
✅ Todas las advertencias/cajas resaltadas (color rojo)
✅ Sin páginas en blanco extra

## Contacto y Soporte

Para problemas de compilación o errores en el documento:
- Revisar el archivo `.log` generado durante la compilación
- Buscar líneas con "ERROR" o "!" para identificar el problema exacto
- Consultar documentación de LaTeX: https://www.latex-project.org/help/documentation/

## Archivos Generados Durante la Compilación

Después de compilar, se generarán los siguientes archivos (pueden eliminarse excepto el PDF):

- `StandbyGuide.pdf` - **ARCHIVO FINAL** (mantener)
- `StandbyGuide.aux` - Referencias cruzadas
- `StandbyGuide.log` - Log de compilación
- `StandbyGuide.out` - Hipervínculos PDF
- `StandbyGuide.toc` - Tabla de contenidos
- `StandbyGuide.lof` - Lista de figuras

Para limpiar archivos temporales:
```cmd
del StandbyGuide.aux StandbyGuide.log StandbyGuide.out StandbyGuide.toc StandbyGuide.lof
```
