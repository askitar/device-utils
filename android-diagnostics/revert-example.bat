@echo off
chcp 65001 >nul
REM ==========================================================
REM  Revertir TODOS los cambios del diagnostico del Galaxy S22+
REM  (ejemplo de un caso real). Conecta el celular por USB con la
REM  depuracion USB activa y haz doble clic en este archivo.
REM ==========================================================
set ADB=%LOCALAPPDATA%\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe
if not exist "%ADB%" set ADB=adb

echo Verificando conexion...
"%ADB%" devices
echo.

echo [1/5] Reactivando Enlace a Windows (com.microsoft.appmanager)...
"%ADB%" shell pm enable --user 0 com.microsoft.appmanager

echo [2/5] Reactivando CapCut (com.lemon.lvoverseas)...
"%ADB%" shell pm enable --user 0 com.lemon.lvoverseas

echo [3/5] Animaciones de vuelta a 1x...
"%ADB%" shell settings put global window_animation_scale 1.0
"%ADB%" shell settings put global transition_animation_scale 1.0
"%ADB%" shell settings delete global animator_duration_scale

echo [4/5] Fluidez de movimiento de vuelta a Estandar (60 Hz)...
"%ADB%" shell settings put secure refresh_rate_mode 0

echo.
echo [5/5] RAM Plus: hazlo a mano en el celular:
echo       Ajustes ^> Cuidado del dispositivo ^> Memoria ^> RAM Plus ^> 4 GB
echo       (te pedira reiniciar)
echo.
echo Verificacion:
"%ADB%" shell "pm list packages -d --user 0 | grep -E 'appmanager|lvoverseas' || echo   Apps: ambas activas"
"%ADB%" shell "echo   Animaciones: $(settings get global window_animation_scale) / $(settings get global transition_animation_scale) / $(settings get global animator_duration_scale)"
"%ADB%" shell "echo   refresh_rate_mode: $(settings get secure refresh_rate_mode)"
echo.
pause
