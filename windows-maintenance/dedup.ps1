$ErrorActionPreference='Continue'
$dl=(Join-Path $env:USERPROFILE 'Downloads')
$log=Join-Path $PSScriptRoot 'dedup-log.txt'
$out=Join-Path $PSScriptRoot 'Duplicados-Eliminados.csv'
'' | Out-File $log

# Derivar carpetas a escanear SIN escribir nombres con tilde (evita mojibake al leer el .ps1 como ANSI)
$exclNames='Respaldo-Inicio-Claude','.claude'
$scan = Get-ChildItem -LiteralPath $dl -Directory -Force | Where-Object {
  ($exclNames -notcontains $_.Name) -and ($_.Name -notlike 'DS4Windows*')
} | Select-Object -ExpandProperty FullName
"Carpetas escaneadas:" | Tee-Object $log -Append
$scan | ForEach-Object { "  $_" | Tee-Object $log -Append }

$files = foreach($s in $scan){ Get-ChildItem -LiteralPath $s -Recurse -File -Force -ErrorAction SilentlyContinue }
$groups = $files | Where-Object { $_.Length -gt 0 } | Group-Object Length | Where-Object { $_.Count -gt 1 }
"Grupos por tamano (candidatos): $($groups.Count)" | Tee-Object $log -Append

$rows=New-Object System.Collections.ArrayList; $freed=0L; $delCount=0; $gi=0
$suffix=[regex]' \(\d+\)\.[^.]+$'
foreach($g in $groups){
  $gi++
  if($gi % 200 -eq 0){ "Grupo $gi/$($groups.Count) - eliminados: $delCount" | Tee-Object $log -Append }
  $hashed = foreach($f in $g.Group){ try{ $h=(Get-FileHash -LiteralPath $f.FullName -Algorithm MD5 -ErrorAction Stop).Hash; [PSCustomObject]@{F=$f;H=$h} }catch{} }
  $byHash = $hashed | Group-Object H | Where-Object { $_.Count -gt 1 }
  foreach($hg in $byHash){
    $items = $hg.Group | Sort-Object @{e={ if($suffix.IsMatch($_.F.Name)){1}else{0} }}, @{e={$_.F.Name.Length}}, @{e={$_.F.FullName}}
    $keep = $items[0].F
    for($k=1; $k -lt $items.Count; $k++){
      $d=$items[$k].F
      try{
        Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop
        [void]$rows.Add([PSCustomObject]@{Eliminado=$d.FullName;Conservado=$keep.FullName;MB=[math]::Round($d.Length/1MB,2);Hash=$hg.Name})
        $freed += $d.Length; $delCount++
      }catch{}
    }
  }
}
$rows | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
"Duplicados eliminados: $delCount" | Tee-Object $log -Append
("Espacio liberado: {0:N2} GB" -f ($freed/1GB)) | Tee-Object $log -Append
"=== FIN ===" | Tee-Object $log -Append
