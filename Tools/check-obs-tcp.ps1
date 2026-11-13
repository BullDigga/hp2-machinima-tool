# Watch established TCP connections to OBS WebSocket port 4455 for 15s. ASCII only.
for ( $i = 0; $i -lt 6; $i++ ) {
    $c = Get-NetTCPConnection -RemotePort 4455 -State Established -ErrorAction SilentlyContinue
    $n = 0
    if ( $c -ne $null ) { $n = @($c).Count }
    Write-Output ("t+{0,2}s  established: {1}" -f ($i * 3), $n)
    Start-Sleep -Seconds 3
}
