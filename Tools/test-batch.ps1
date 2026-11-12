# Batch SendInput probe: inject the whole command as ONE atomic SendInput call.
# If the console digests it without losing chars, per-char delays are dead.
# Probe delivers "PathPing" (harmless); a fresh PING in the buffer = success.
param([string]$Cmd = "PathPing", [string]$Shot = "", [int]$Segment = 0, [int]$Gap = 0)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $root "Panel\cache\GameCtl.dll") | Out-Null
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class SB {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowW(string c, IntPtr t);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public const uint KEYEVENTF_UNICODE = 0x1000;
  public const uint KEYEVENTF_KEYUP   = 0x0002;
  [StructLayout(LayoutKind.Sequential)]
  public struct INPUT {
    public uint type;
    public InputUnion u;
  }
  [StructLayout(LayoutKind.Explicit)]
  public struct InputUnion {
    [FieldOffset(0)] public MOUSEINPUT mi;
    [FieldOffset(0)] public KEYBDINPUT ki;
  }
  [StructLayout(LayoutKind.Sequential)]
  public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)]
  public struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; public uint unused1, unused2; }
  // inject: unicode chars for text, then VK RETURN down/up
  public static uint SendText(string text, int segment, int gapMs) {
    uint sent = 0;
    var buf = new System.Collections.Generic.List<INPUT>();
    int sinceGap = 0;
    foreach ( char c in text ) {
      buf.Add(MakeUnicode(c, 0));
      buf.Add(MakeUnicode(c, KEYEVENTF_KEYUP));
      sinceGap++;
      if ( segment > 0 && sinceGap >= segment ) {
        INPUT[] arr = buf.ToArray();
        sent += SendInput((uint)arr.Length, arr, Marshal.SizeOf(typeof(INPUT)));
        buf.Clear();
        sinceGap = 0;
        System.Threading.Thread.Sleep(gapMs);
      }
    }
    buf.Add(MakeVk(0x0D, 0));
    buf.Add(MakeVk(0x0D, KEYEVENTF_KEYUP));
    INPUT[] fin = buf.ToArray();
    sent += SendInput((uint)fin.Length, fin, Marshal.SizeOf(typeof(INPUT)));
    if ( gapMs > 0 ) {
      // lost-Enter insurance: second Enter after a gap executes whatever the
      // first Enter dropped (an empty repeat line is harmless in the console)
      System.Threading.Thread.Sleep(400);
      buf.Clear();
      buf.Add(MakeVk(0x0D, 0));
      buf.Add(MakeVk(0x0D, KEYEVENTF_KEYUP));
      INPUT[] fin2 = buf.ToArray();
      sent += SendInput((uint)fin2.Length, fin2, Marshal.SizeOf(typeof(INPUT)));
    }
    System.Threading.Thread.Sleep(gapMs);
    return sent;
  }
  static INPUT MakeUnicode(char c, uint flags) {
    INPUT i = new INPUT(); i.type = 1;
    i.u.ki.wVk = 0; i.u.ki.wScan = (ushort)c; i.u.ki.dwFlags = KEYEVENTF_UNICODE | flags; i.u.ki.time = 0;
    return i;
  }
  static INPUT MakeVk(ushort vk, uint flags) {
    INPUT i = new INPUT(); i.type = 1;
    i.u.ki.wVk = vk; i.u.ki.wScan = 0; i.u.ki.dwFlags = flags; i.u.ki.time = 0;
    return i;
  }
}
'@ | Out-Null
[SB]::SetProcessDPIAware() | Out-Null

$proc = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $proc -eq $null ) { Write-Output "NO GAME"; exit 1 }
$h = [SB]::FindWindowW("GameUnrealWWindowsViewportWindow", [IntPtr]::Zero)
if ( $h -eq [IntPtr]::Zero ) { Write-Output "NO VIEWPORT"; exit 1 }
[SB]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[SB]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 60
[SB]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400
if ( [SB]::GetForegroundWindow() -ne $h ) { Write-Output "FOCUS FAILED"; exit 1 }

# ensure-open: Shift+grave, ONE tap (batch replaces the triple-open if it works)
[SB]::keybd_event(0x10, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
[SB]::keybd_event(0xC0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
[SB]::keybd_event(0xC0, 0, 2, [UIntPtr]::Zero)
[SB]::keybd_event(0x10, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 1200

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$injected = [SB]::SendText($Cmd, $Segment, $Gap)
$sw.Stop()
Write-Output ("batch injected {0} events in {1}ms" -f $injected, $sw.ElapsedMilliseconds)
Start-Sleep -Milliseconds 800
if ( $Shot -ne "" ) {
    Add-Type -AssemblyName System.Drawing
    $b = New-Object System.Drawing.Bitmap 3840,2160
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen(0,0,0,0,$b.Size)
    $b2 = New-Object System.Drawing.Bitmap 1920,1080
    $g2 = [System.Drawing.Graphics]::FromImage($b2)
    $g2.InterpolationMode = 'NearestNeighbor'
    $g2.DrawImage($b, 0, 0, 1920, 1080)
    $b2.Save($Shot)
    Write-Output ("shot -> " + $Shot)
}
Write-Output "done - run dump-buf-diag.ps1"
