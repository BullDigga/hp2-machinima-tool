# Write panel-batch.txt to the game ROOT with proper CRLF. ASCII only.
$ErrorActionPreference = "Stop"
$f = 'F:\Harry Potter and the Chamber of Secrets\panel-batch.txt'
[System.IO.File]::WriteAllText($f, "PathPing" + [char]13 + [char]10)
Write-Output ("written: " + ((Get-Item $f).Length) + " bytes")
