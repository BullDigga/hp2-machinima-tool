# Rebuild ObsWs.dll: stop panel, drop the stale DLL (panel recompiles from source on start), start panel. ASCII only.
$ps = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*HP2MachinimaPanel.ps1*' }
foreach ( $p in $ps ) {
    Write-Output ("stopping panel pid " + $p.ProcessId)
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 800
$dll = 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\cache\ObsWs.dll'
if ( Test-Path $dll ) { Remove-Item $dll -Force; Write-Output "stale ObsWs.dll removed" }
Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\HP2MachinimaPanel.ps1' -WindowStyle Hidden
Start-Sleep -Seconds 10
if ( Test-Path $dll ) { Write-Output ("new ObsWs.dll built: " + (Get-Item $dll).LastWriteTime) } else { Write-Output "DLL NOT REBUILT - check panel" }
