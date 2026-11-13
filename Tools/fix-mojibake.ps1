# Repair double-encoded (UTF-8 -> CP1251 -> saved) literals in the map-picker
# section of the panel script. ASCII only. Scoped to lines 3640-4060; a line is
# replaced ONLY if CP1251-reencoding yields valid UTF-8 whose decoded text has
# runs of 3+ Cyrillic letters (real Russian) or the play glyph U+25B6.
$path = 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\HP2MachinimaPanel.ps1'
$cp1251 = [System.Text.Encoding]::GetEncoding(1251)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$lines = [System.IO.File]::ReadAllLines($path, $utf8)
$fixed = 0
for ( $i = 0; $i -lt $lines.Count; $i++ ) {
    $ln = $i + 1
    if ( $ln -lt 3640 -or $ln -gt 4060 ) { continue }
    $orig = $lines[$i]
    if ( $orig -notmatch '[^\x00-\x7F]' ) { continue }
    $bytes = $cp1251.GetBytes($orig)
    $cand = ""
    try { $cand = $utf8.GetString($bytes) } catch { continue }
    if ( $cand -eq $orig ) { continue }
    # accept only real Russian runs (3+ cyrillic letters) or the play glyph
    $hasRu = [regex]::IsMatch($cand, '[\u0410-\u044F\u0401\u0451]{3}')
    $hasGlyph = $cand.Contains([string][char]0x25B6)
    if ( -not ( $hasRu -or $hasGlyph ) ) { continue }
    Write-Output ("L{0}: {1}" -f $ln, $cand.Trim())
    $lines[$i] = $cand
    $fixed++
}
if ( $fixed -gt 0 ) {
    $utf8bom = New-Object System.Text.UTF8Encoding($true)   # keep the BOM
    [System.IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), $utf8bom)
}
Write-Output ("fixed lines: " + $fixed)
