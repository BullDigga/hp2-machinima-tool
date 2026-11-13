# Read the tail of the game log bypassing the game's exclusive lock. ASCII only.
$dir = Join-Path $env:USERPROFILE 'OneDrive'
$dir = Join-Path (Get-ChildItem $dir -Directory | Where-Object { $_.Name -like '*одumenten*' -or $_.Name -like '*Documents*' } | Select-Object -First 1).FullName 'Harry - Coding Evolved'
# Documents folder name is Cyrillic - find it by pattern instead
$base = Get-ChildItem (Join-Path $env:USERPROFILE 'OneDrive') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'Harry - Coding Evolved\Game.log') } | Select-Object -First 1
if ( $base -eq $null ) { Write-Output "LOG NOT FOUND"; exit 1 }
$log = Join-Path $base.FullName 'Harry - Coding Evolved\Game.log'
$fs = [System.IO.FileStream]::new($log, 'Open', 'Read', [System.IO.FileShare]::ReadWrite)
$back = [Math]::Min(8000, $fs.Length)
$buf = New-Object byte[] $back
$fs.Seek($fs.Length - $back, 'Begin') | Out-Null
$n = $fs.Read($buf, 0, $back)
$fs.Close()
[System.Text.Encoding]::GetEncoding(1251).GetString($buf, 0, $n)
