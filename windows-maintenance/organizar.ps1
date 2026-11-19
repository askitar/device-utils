$ErrorActionPreference = 'Continue'
$base = (Join-Path $env:USERPROFILE 'Downloads')
$roots = @((Join-Path $env:USERPROFILE 'Downloads'),(Join-Path $env:USERPROFILE 'Videos'),(Join-Path $env:USERPROFILE 'OneDrive\Escritorio'),(Join-Path $env:USERPROFILE 'OneDrive\Imágenes'))
$manifest = (Join-Path $PSScriptRoot 'Organizacion-Registro.csv')
$logfile  = (Join-Path $PSScriptRoot 'organizar-log.txt')
"" | Out-File $logfile

$img  = '.jpg','.jpeg','.png','.gif','.bmp','.tif','.tiff','.webp','.heic','.svg','.psd','.ai','.cr2','.nef','.dng','.raw','.ico'
$vid  = '.mp4','.mov','.avi','.mkv','.wmv','.flv','.webm','.m4v','.mpg','.mpeg','.ts','.m2ts'
$doc  = '.pdf','.doc','.docx','.xls','.xlsx','.ppt','.pptx','.txt','.rtf','.odt','.csv','.epub'
$appx = '.exe','.msi','.msix','.appx','.apk','.bat','.cmd'
$zip  = '.zip','.rar','.7z','.tar','.gz','.iso'
$edit = '.prproj','.aep','.aepx','.veg','.drp','.fcpxml','.aup','.als','.flp','.c4d','.blend','.prfpset','.cube','.lut'

function SizeBucket($l){ if($l -lt 1GB){'Menos de 1 GB'} elseif($l -lt 5GB){'1 GB a 5 GB'} else {'5 GB en adelante'} }

function DestFolder($f){
  $e = $f.Extension.ToLower(); $l = $f.Length
  if($img -contains $e){ return (Join-Path $base ('Imágenes y Videos\Imágenes\' + (SizeBucket $l))) }
  if($vid -contains $e){ return (Join-Path $base ('Imágenes y Videos\Videos\'   + (SizeBucket $l))) }
  if($doc -contains $e){
    if($e -eq '.pdf'){ return (Join-Path $base 'Documentos\PDF') }
    if('.doc','.docx','.rtf','.odt' -contains $e){ return (Join-Path $base 'Documentos\Word') }
    if('.xls','.xlsx','.csv' -contains $e){ return (Join-Path $base 'Documentos\Hojas de cálculo') }
    if('.ppt','.pptx' -contains $e){ return (Join-Path $base 'Documentos\Presentaciones') }
    return (Join-Path $base 'Documentos\Texto y otros')
  }
  if($appx -contains $e){ return (Join-Path $base 'Aplicaciones') }
  if($zip  -contains $e){ return (Join-Path $base 'Otros\Comprimidos') }
  if($edit -contains $e){ return (Join-Path $base 'Otros\Proyectos Premiere y edición') }
  return (Join-Path $base 'Otros\Varios')
}

# 1) Capturar lista de archivos ANTES de crear destinos
$exclude = '\Respaldo-Inicio-Claude\','\.claude\','\AppData\'
$all = New-Object System.Collections.ArrayList
foreach($r in $roots){
  if(Test-Path -LiteralPath $r){
    Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
      $p = $_.FullName; $skip = $false
      foreach($x in $exclude){ if($p -like "*$x*"){ $skip = $true; break } }
      if(-not $skip){ [void]$all.Add($_) }
    }
  }
}
"Archivos a procesar: $($all.Count)" | Tee-Object -FilePath $logfile -Append

# 2) Mover con registro y manejo de colisiones
$rows = New-Object System.Collections.ArrayList
$ok=0; $err=0; $i=0
foreach($f in $all){
  $i++
  if($i % 1500 -eq 0){ "Progreso: $i / $($all.Count)" | Tee-Object -FilePath $logfile -Append }
  try{
    $destDir = DestFolder $f
    if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
    $bn = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $ex = [IO.Path]::GetExtension($f.Name)
    $target = Join-Path $destDir ($bn + $ex)
    $n = 2
    while(Test-Path -LiteralPath $target){ $target = Join-Path $destDir ("$bn ($n)$ex"); $n++ }
    Move-Item -LiteralPath $f.FullName -Destination $target -Force -ErrorAction Stop
    [void]$rows.Add([PSCustomObject]@{ Original=$f.FullName; Destino=$target; MB=[math]::Round($f.Length/1MB,2) })
    $ok++
  } catch {
    [void]$rows.Add([PSCustomObject]@{ Original=$f.FullName; Destino="ERROR: $($_.Exception.Message)"; MB=[math]::Round($f.Length/1MB,2) })
    $err++
  }
}
$rows | Export-Csv -LiteralPath $manifest -NoTypeInformation -Encoding UTF8
"Movidos OK: $ok  |  Errores: $err" | Tee-Object -FilePath $logfile -Append

# 3) Eliminar carpetas vacias (no los roots ni respaldo)
$keep = $roots + @($manifest)
$dirs = New-Object System.Collections.ArrayList
foreach($r in $roots){ if(Test-Path -LiteralPath $r){ Get-ChildItem -LiteralPath $r -Recurse -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { [void]$dirs.Add($_.FullName) } } }
$dirs = $dirs | Sort-Object { $_.Length } -Descending
$removed=0
foreach($d in $dirs){
  if($d -like '*\Respaldo-Inicio-Claude*' -or $d -like '*\.claude*'){ continue }
  if($roots -contains $d){ continue }
  $hasChild = Get-ChildItem -LiteralPath $d -Force -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if(-not $hasChild){ try{ Remove-Item -LiteralPath $d -Force -Recurse -ErrorAction Stop; $removed++ }catch{} }
}
"Carpetas vacias eliminadas: $removed" | Tee-Object -FilePath $logfile -Append
"=== FIN ===" | Tee-Object -FilePath $logfile -Append
