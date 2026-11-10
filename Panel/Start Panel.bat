@echo off
rem v5.17.9: -WindowStyle Hidden hides the compiler console immediately.
rem Previously the visible console window (Add-Type compiles for ~40s) could be
rem closed accidentally - the WPF panel dies with its console.
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0HP2MachinimaPanel.ps1"
