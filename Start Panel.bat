@echo off
rem HP2 Machinima Panel launcher: restarts the panel (one instance).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process | Where-Object { $_.MainWindowTitle -eq 'HP2 Machinima Panel' } | Stop-Process -Force"
timeout /t 1 /nobreak >nul
start "HP2 Panel" /b powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "Panel\HP2MachinimaPanel.ps1"
