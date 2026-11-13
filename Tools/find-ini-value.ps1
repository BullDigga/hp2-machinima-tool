# Find bQuietConsole in all game ini files (the Documents path has Cyrillic). ASCII only.
$dirs = @('F:\Harry Potter and the Chamber of Secrets\system')
$docs = Get-ChildItem (Join-Path $env:USERPROFILE 'OneDrive') -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'Harry - Coding Evolved') } | Select-Object -First 1
if ( $docs -ne $null ) { $dirs += (Join-Path $docs.FullName 'Harry - Coding Evolved') }
foreach ( $d in $dirs ) {
    Get-ChildItem $d -Filter '*.ini' -ErrorAction SilentlyContinue | ForEach-Object {
        $hit = Select-String -Path $_.FullName -Pattern 'bQuietConsole' -SimpleMatch -ErrorAction SilentlyContinue
        if ( $hit -ne $null ) { Write-Output ($_.FullName + " -> " + ($hit | ForEach-Object { $_.Line.Trim() })) }
    }
}
