# Revierte la organizacion: devuelve cada archivo a su ubicacion original.
# Ejecutar: clic derecho > Ejecutar con PowerShell  (o)  powershell -ExecutionPolicy Bypass -File este_archivo.ps1
$ErrorActionPreference='Continue'
$csv = Join-Path $PSScriptRoot 'Organizacion-Registro.csv'
if(-not (Test-Path -LiteralPath $csv)){ Write-Host "No se encuentra el registro CSV."; exit }
$rows = Import-Csv -LiteralPath $csv -Encoding UTF8
$done=0; $fail=0; $skip=0
foreach($r in $rows){
  if([string]::IsNullOrWhiteSpace($r.Destino) -or $r.Destino -like 'ERROR*'){ $skip++; continue }
  if(-not (Test-Path -LiteralPath $r.Destino)){ $fail++; continue }
  $od = Split-Path -LiteralPath $r.Original -Parent
  if(-not (Test-Path -LiteralPath $od)){ New-Item -ItemType Directory -Force -Path $od | Out-Null }
  $target = $r.Original
  $n = 2
  while(Test-Path -LiteralPath $target){
    $dir=Split-Path -LiteralPath $r.Original -Parent
    $bn=[IO.Path]::GetFileNameWithoutExtension($r.Original)
    $ex=[IO.Path]::GetExtension($r.Original)
    $target = Join-Path $dir "$bn ($n)$ex"; $n++
  }
  try{ Move-Item -LiteralPath $r.Destino -Destination $target -Force -ErrorAction Stop; $done++ }catch{ $fail++ }
}
Write-Host "Restaurados: $done | Fallidos: $fail | Omitidos: $skip"
