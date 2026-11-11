# Diagnostic: dump FULL UTF-16 text of the log buffer regions. ASCII only.
$ErrorActionPreference = "Stop"
$dll = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\cache\MemScanPanel.dll"
Add-Type -Path $dll
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $gp -eq $null ) { Write-Output "NO GAME PROCESS"; exit 1 }

# reuse region cache from the PATHEV dump header
$hdr = Get-Content "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\buf-diag.txt" -TotalCount 1
$parts = $hdr.TrimStart('|').Split('|')
$pairs = @()
for ( $i = 2; $i + 1 -lt $parts.Length; $i += 2 ) { $pairs += [long]$parts[$i]; $pairs += [long]$parts[$i+1] }

$pid2 = $gp.Id
$open = [MemScanPanel].GetMethod("OpenProcess")
$h = [MemScanPanel]::OpenProcess(0x0410, $false, $pid2)
$sb = New-Object System.Text.StringBuilder
for ( $r = 0; $r + 1 -lt $pairs.Length; $r += 2 ) {
  $regA = $pairs[$r]; $regS = $pairs[$r+1]
  $pos = 0
  while ( $pos -lt $regS ) {
    $toRead = [int][Math]::Min($regS - $pos, 0x400000)
    $buf = New-Object byte[] $toRead
    $read = [IntPtr]::Zero
    if ( [MemScanPanel]::ReadProcessMemory($h, [IntPtr]($regA + $pos), $buf, [IntPtr]$toRead, [ref]$read) ) {
      $n = $read.ToInt32()
      $s = [System.Text.Encoding]::Unicode.GetString($buf, 0, $n)
      [void]$sb.Append($s)
    }
    $pos += 0x400000
  }
}
[MemScanPanel]::CloseHandle($h) | Out-Null
$out = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\buf-full.txt"
[System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Output ("written " + $sb.Length + " chars")
