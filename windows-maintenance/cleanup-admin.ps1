$log = (Join-Path $PSScriptRoot 'resultado-admin.txt')
"=== Limpieza administrador $(Get-Date) ===" | Out-File $log

function Log($m){ $m | Tee-Object -FilePath $log -Append }

# 1) Quitar entradas de arranque HKLM
$hklm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
foreach($n in 'AdobeAAMUpdater-1.0','XboxStat','Nearby Share'){
  try {
    if (Get-ItemProperty $hklm -Name $n -ErrorAction SilentlyContinue) {
      Remove-ItemProperty $hklm -Name $n -Force -ErrorAction Stop
      Log "Arranque HKLM quitado: $n"
    }
  } catch { Log "ERROR arranque $n : $($_.Exception.Message)" }
}

# 2) Desinstalar MSIs (silencioso)
$msis = @{
  'User Experience Improvement Program (Acer)' = '{323EA05D-046D-449D-9D7C-89243C957CCE}'
  'Acer Jumpstart' = '{0C5ED25A-B8D1-4E71-BFCB-6B370A4EA19C}'
  'ExpressVPN' = '{6F76698F-471A-4038-8912-4FFB2516AA8C}'
}
foreach($m in $msis.GetEnumerator()){
  $p = Start-Process msiexec.exe -ArgumentList "/X$($m.Value) /quiet /norestart" -Wait -PassThru
  Log "Desinstalar $($m.Key): codigo $($p.ExitCode)"
}

# 3) Planet9 Stub (exe silencioso)
$pl = 'C:\Program Files\Planet9 Stub\Uninstall Planet9 Stub.exe'
if (Test-Path $pl){ $p = Start-Process $pl -ArgumentList '/allusers /S' -Wait -PassThru; Log "Planet9 Stub: codigo $($p.ExitCode)" }

# 4) App Explorer (SweetLabs)
$ae = (Join-Path $env:USERPROFILE 'AppData\Local\Host App Service\Uninstall.exe')
if (Test-Path $ae){ $p = Start-Process $ae -ArgumentList '/S' -Wait -PassThru; Log "App Explorer: codigo $($p.ExitCode)" }

Log "=== FIN ==="
