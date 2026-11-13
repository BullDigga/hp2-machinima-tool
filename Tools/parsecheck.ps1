# Syntax check of the panel script. ASCII only.
$errs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile('C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\HP2MachinimaPanel.ps1', [ref]$null, [ref]$errs)
if ( $errs.Count -eq 0 ) { Write-Output "PARSE OK" }
else {
    foreach ( $e in $errs ) { Write-Output ($e.Message + " @ line " + $e.Extent.StartLineNumber) }
    exit 1
}
