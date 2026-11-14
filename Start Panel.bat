@echo off
rem HP2 Machinima Panel launcher: restarts the panel (one instance).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$me = $PID; Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.ProcessId -ne $me -and $_.CommandLine -like '*HP2MachinimaPanel.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
start "HP2 Panel" /B powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "Panel\HP2MachinimaPanel.ps1"
