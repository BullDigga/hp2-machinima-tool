# Kill ALL panel processes, start exactly one fresh instance. ASCII only.
$ps = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*HP2MachinimaPanel.ps1*' }
foreach ( $p in $ps ) {
    Write-Output ("killing panel pid " + $p.ProcessId)
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 1000
Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\HP2MachinimaPanel.ps1' -WindowStyle Hidden
Start-Sleep -Seconds 3
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*HP2MachinimaPanel.ps1*' } | ForEach-Object { Write-Output ("alive: pid " + $_.ProcessId) }
