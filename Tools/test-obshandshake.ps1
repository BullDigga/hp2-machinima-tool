# Manual OBS WebSocket handshake with full response logging (uses settings.json password).
# ASCII only. The password is NOT printed.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$sc = Get-Content (Join-Path $root "Panel\settings.json") -Raw | ConvertFrom-Json
$port = 4455; if ( $sc.obspass -ne $null ) { $pass = [string]$sc.obspass } else { $pass = "" }
Write-Output ("password length: " + $pass.Length)

Add-Type -Path (Join-Path $root "Panel\cache\ObsWs.dll") | Out-Null
# use a raw ClientWebSocket here for transparent logging
Add-Type -TypeDefinition @'
using System;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
public class HW {
  public static ClientWebSocket ws = new ClientWebSocket();
  public static string Recv(int ms) {
    var buf = new byte[65536];
    var r = ws.ReceiveAsync(new ArraySegment<byte>(buf), new CancellationTokenSource(ms).Token);
    r.Wait(ms);
    if ( !r.IsCompleted ) return "";
    return Encoding.UTF8.GetString(buf, 0, r.Result.Count);
  }
  public static void Send(string s) {
    ws.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes(s)), WebSocketMessageType.Text, true, CancellationToken.None).Wait(2000);
  }
}
'@ | Out-Null

[HW]::ws.ConnectAsync([Uri]::new("ws://127.0.0.1:" + $port + "/"), [Threading.CancellationToken]::None).Wait(4000)
Write-Output ("ws state: " + [HW]::ws.State)
if ( [HW]::ws.State -ne 'Open' ) { exit 1 }
$hello = [HW]::Recv(3000)
Write-Output ("HELLO: " + $hello.Substring(0, [Math]::Min(220, $hello.Length)))
$salt = [regex]::Match($hello, '"salt":"([^"]*)"').Groups[1].Value
$chal = [regex]::Match($hello, '"challenge":"([^"]*)"').Groups[1].Value
$sha = [System.Security.Cryptography.SHA256]::Create()
$secret = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($pass + $salt)))
$auth = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($secret + $chal)))
$ident = '{"op":1,"d":{"rpcVersion":1,"eventSubscriptions":33,"authentication":"' + $auth + '"}}'
Write-Output ("IDENT: " + $ident)
[HW]::Send($ident)
$ack = [HW]::Recv(3000)
Write-Output ("ACK: " + $ack.Substring(0, [Math]::Min(300, $ack.Length)))
Write-Output ("ws state after identify: " + [HW]::ws.State + " closestatus: " + [HW]::ws.CloseStatus)
Write-Output ("close reason: " + [HW]::ws.CloseStatusDescription)
# late ack: wait longer and try again
if ( $ack -eq "" ) {
    $ack2 = [HW]::Recv(5000)
    Write-Output ("ACK2 (late): " + $ack2.Substring(0, [Math]::Min(300, $ack2.Length)))
    Write-Output ("ws state after late: " + [HW]::ws.State)
}
if ( $ack -like '*op":2*' ) {
    [HW]::Send('{"op":6,"d":{"requestType":"GetRecordStatus","requestId":"t"}}')
    $st = [HW]::Recv(3000)
    Write-Output ("STATUS: " + $st.Substring(0, [Math]::Min(300, $st.Length)))
}
