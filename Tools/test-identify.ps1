# Isolate the Identify rejection: try variants and print each close code. ASCII.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$sc = Get-Content (Join-Path $root "Panel\settings.json") -Raw | ConvertFrom-Json
$pass = [string]$sc.obspass

Add-Type -Path (Join-Path $root "Panel\cache\ObsWs.dll") | Out-Null
Add-Type -TypeDefinition @'
using System;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
public class HV2 {
  public static ClientWebSocket ws = new ClientWebSocket();
  public static string Recv(int ms) {
    var buf = new byte[65536];
    try {
      var r = ws.ReceiveAsync(new ArraySegment<byte>(buf), new CancellationTokenSource(ms).Token);
      r.Wait(ms);
      if ( !r.IsCompleted ) return "";
      return Encoding.UTF8.GetString(buf, 0, r.Result.Count);
    } catch { return "ERR:" + ws.State + "/" + ws.CloseStatus; }
  }
  public static void Send(string s) {
    ws.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes(s)), WebSocketMessageType.Text, true, CancellationToken.None).Wait(2000);
  }
}
'@ | Out-Null

$sha = [System.Security.Cryptography.SHA256]::Create()

function Try-Variant([string]$name, [string]$json) {
    Write-Output ("== " + $name)
    try {
        [HV2]::ws = New-Object System.Net.WebSockets.ClientWebSocket
        [HV2]::ws.ConnectAsync([Uri]::new("ws://127.0.0.1:4455/"), [Threading.CancellationToken]::None).Wait(3000)
        $hello = [HV2]::Recv(3000)
        $salt = [regex]::Match($hello, '"salt":"([^"]*)"').Groups[1].Value
        $chal = [regex]::Match($hello, '"challenge":"([^"]*)"').Groups[1].Value
        $secret = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($pass + $salt)))
        $auth = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($secret + $chal)))
        $json = $json.Replace('%AUTH%', $auth).Replace('%SALT%', $salt)
        [HV2]::Send($json)
        $ack = [HV2]::Recv(3000)
        Write-Output ("resp: " + $(if ( $ack -eq "" ) { "<empty> state=" + [HV2]::ws.State + " close=" + [HV2]::ws.CloseStatus } else { $ack.Substring(0, [Math]::Min(240, $ack.Length)) }))
    } catch { Write-Output ("err: " + $_.Exception.Message) }
}

Try-Variant "no-auth-field" '{"op":1,"d":{"rpcVersion":5}}'
Try-Variant "auth-only" '{"op":1,"d":{"rpcVersion":5,"authentication":"%AUTH%"}}'
Try-Variant "auth-no-esubs" '{"op":1,"d":{"rpcVersion":5,"authentication":"%AUTH%"}}'
Try-Variant "auth+esubs33" '{"op":1,"d":{"rpcVersion":5,"eventSubscriptions":33,"authentication":"%AUTH%"}}'
Try-Variant "esubs-as-string" '{"op":1,"d":{"rpcVersion":5,"eventSubscriptions":"33","authentication":"%AUTH%"}}'
