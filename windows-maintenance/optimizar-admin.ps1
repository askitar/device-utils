$ErrorActionPreference='Continue'
$log = (Join-Path $PSScriptRoot 'optimizar-resultado.txt')
$done = (Join-Path $PSScriptRoot 'optimizar-DONE.txt')
if(Test-Path $done){ Remove-Item $done -Force }
function Log($m){ $m | Tee-Object -FilePath $log -Append }
"=== Optimizacion $(Get-Date) ===" | Out-File $log

$free0 = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace

# 1) Plan de energia Ultimate Performance
try{
  $u = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
  $g = ($u | Select-String -Pattern '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})').Matches.Value
  if($g){ powercfg /setactive $g | Out-Null; Log "Plan de energia Ultimate Performance activado" }
  else { Log "Ultimate Performance ya existia o no se pudo duplicar (se mantiene Alto rendimiento)" }
}catch{ Log "Power plan error: $($_.Exception.Message)" }

# 2) Desactivar telemetria DiagTrack
try{ Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction Stop; Log "Servicio de telemetria DiagTrack desactivado" }catch{ Log "DiagTrack: $($_.Exception.Message)" }

# 3) Desactivar tareas programadas de telemetria/CEIP
try{
  Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $_.State -eq 'Ready' -and (
      $_.TaskName -match 'Consolidator|UsbCeip|Telemetry|CEIP|Appraiser|ProgramDataUpdater|DiskDiagnosticDataCollector' -or
      ($_.TaskPath -match 'Autochk' -and $_.TaskName -eq 'Proxy')
    )
  } | ForEach-Object {
    try{ Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction Stop | Out-Null; Log "Tarea desactivada: $($_.TaskName)" }catch{}
  }
}catch{}

# 4) Limpiar cache de Delivery Optimization
try{ Delete-DeliveryOptimizationCache -Force -ErrorAction Stop; Log "Cache de Delivery Optimization limpiada" }catch{ Log "Delivery Optimization: $($_.Exception.Message)" }

# 5) Limpiar cache de Windows Update
try{
  Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
  Stop-Service bits -Force -ErrorAction SilentlyContinue
  $wu = 'C:\Windows\SoftwareDistribution\Download'
  if(Test-Path $wu){ Get-ChildItem $wu -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
  Start-Service bits -ErrorAction SilentlyContinue
  Start-Service wuauserv -ErrorAction SilentlyContinue
  Log "Cache de Windows Update limpiada"
}catch{ Log "Windows Update cache: $($_.Exception.Message)" }

# 6) Limpiar logs antiguos de Windows (CBS / temp del sistema)
try{ Get-ChildItem 'C:\Windows\Logs\CBS' -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 50MB } | Remove-Item -Force -ErrorAction SilentlyContinue }catch{}

# 7) DISM: analizar y limpiar almacen de componentes (WinSxS)
try{ Log "--- DISM AnalyzeComponentStore ---"; (Dism /Online /Cleanup-Image /AnalyzeComponentStore 2>&1 | Out-String) | Tee-Object -FilePath $log -Append }catch{}
try{ Log "--- DISM StartComponentCleanup (puede tardar varios minutos) ---"; (Dism /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-String) | Tee-Object -FilePath $log -Append }catch{ Log "DISM: $($_.Exception.Message)" }

$free1 = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
Log ("Espacio liberado en esta fase: {0:N2} GB" -f (($free1-$free0)/1GB))
Log ("Libre ahora: {0:N1} GB" -f ($free1/1GB))
Log "=== FIN ==="
"OK $(Get-Date)" | Out-File $done
