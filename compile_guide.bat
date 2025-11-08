@echo off
REM ========================================
REM Script para compilar StandbyGuide.tex
REM ========================================

echo Compilando StandbyGuide.tex con LuaLaTeX...
echo.

REM Primera compilación (genera archivos auxiliares)
lualatex -interaction=nonstopmode StandbyGuide.tex

REM Segunda compilación (resuelve referencias cruzadas y TOC)
lualatex -interaction=nonstopmode StandbyGuide.tex

REM Tercera compilación (asegura que todas las referencias están correctas)
lualatex -interaction=nonstopmode StandbyGuide.tex

echo.
echo ========================================
echo Compilación completada!
echo El archivo PDF se encuentra en: StandbyGuide.pdf
echo ========================================
echo.

REM Abrir el PDF automáticamente
if exist StandbyGuide.pdf (
    start StandbyGuide.pdf
) else (
    echo ERROR: No se generó el archivo PDF. Revise los errores anteriores.
)

pause
