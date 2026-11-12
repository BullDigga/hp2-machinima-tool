# Report PATHEV hit offsets inside each cached region (relative MB). ASCII only.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $root "Panel\cache\MemScanPanel.dll") | Out-Null
$sc = Get-Content (Join-Path $root "Panel\scan-cache.json") -Raw | ConvertFrom-Json
$pairs = @($sc.regions | ForEach-Object { [long]$_ })
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1

$open = [MemScanPanel]::OpenProcess(0x0410, $false, $gp.Id)
for ( $r = 0; $r + 1 -lt $pairs.Length; $r += 2 ) {
  $regA = $pairs[$r]; $regS = $pairs[$r+1]
  $hits = New-Object System.Collections.Generic.List[long]
  $pos = 0
  $chunk = 0x400000
  while ( $pos -lt $regS ) {
    $toRead = [int][Math]::Min($regS - $pos, $chunk)
    $buf = New-Object byte[] $toRead
    $read = [IntPtr]::Zero
    if ( [MemScanPanel]::ReadProcessMemory($open, [IntPtr]($regA + $pos), $buf, [IntPtr]$toRead, [ref]$read) ) {
      $n = $read.ToInt32()
      $s = [System.Text.Encoding]::Unicode.GetString($buf, 0, $n)
      $i = $s.IndexOf("PATHEV:")
      while ( $i -ge 0 ) { [void]$hits.Add($pos + $i); $i = $s.IndexOf("PATHEV:", $i + 7) }
    }
    $pos += $chunk
  }
  $mb = [math]::Round($regS / 1MB, 1)
  if ( $hits.Count -gt 0 ) {
    $minMB = [math]::Round(($hits[0]) / 1MB, 1)
    $maxMB = [math]::Round(($hits[$hits.Count-1]) / 1MB, 1)
    $tailMB = [math]::Round(($regS - $hits[$hits.Count-1]) / 1MB, 1)
    Write-Output ("region {0}: {1}MB, hits {2} (first at {3}MB, last at {4}MB, last is {5}MB from region end)" -f ($r/2), $mb, $hits.Count, $minMB, $maxMB, $tailMB)
  } else {
    Write-Output ("region {0}: {1}MB, hits 0" -f ($r/2), $mb)
  }
}
[MemScanPanel]::CloseHandle($open) | Out-Null
