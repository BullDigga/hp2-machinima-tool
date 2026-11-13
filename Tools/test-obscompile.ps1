# Extract ObsWs C# by lines (terminator = line starting with "@) and compile. ASCII.
$src = [System.IO.File]::ReadAllLines('C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\HP2MachinimaPanel.ps1')
$start = -1
for ( $i = 0; $i -lt $src.Length; $i++ ) { if ( $src[$i] -like "*TypeName 'ObsWs'*" ) { $start = $i + 1; break } }
if ( $start -lt 0 ) { Write-Output "START NOT FOUND"; exit 1 }
$end = -1
for ( $i = $start; $i -lt $src.Length; $i++ ) { if ( $src[$i] -eq '"@' ) { $end = $i; break } }
if ( $end -lt 0 ) { Write-Output "END NOT FOUND"; exit 1 }
$code = ($src[$start..($end-1)] -join "`r`n")
try {
    Add-Type -TypeDefinition $code
    Write-Output "COMPILE OK"
} catch {
    Write-Output "COMPILE FAILED:"
    if ( $_.Exception.InnerException -ne $null ) { Write-Output $_.Exception.InnerException.Message }
    Write-Output $_.Exception.Message
}
