# Diagnostic: find panel hwnd + rect, crop screenshot. ASCII only.
param([string]$shot = "")
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class PanelWin {
  public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int L, T, R, B; }
  public static IntPtr Found = IntPtr.Zero;
}
'@
[PanelWin]::SetProcessDPIAware() | Out-Null
$pp = (Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*MachinimaPanel*' } | Select-Object -First 1).ProcessId
if ( -not $pp ) { Write-Output "NO PANEL"; exit 1 }
$cb = { param($h, $l)
  $p2 = 0
  [PanelWin]::GetWindowThreadProcessId($h, [ref]$p2) | Out-Null
  if ( $p2 -eq $pp ) {
    $sb = New-Object System.Text.StringBuilder 256
    [PanelWin]::GetWindowText($h, $sb, 256) | Out-Null
    if ( $sb.ToString() -eq "HP2 Machinima Panel" ) { [PanelWin]::Found = $h }
  }
  return $true
}
[PanelWin]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ( [PanelWin]::Found -eq [IntPtr]::Zero ) { Write-Output "NO WINDOW"; exit 1 }
$r = New-Object PanelWin+RECT
[PanelWin]::GetWindowRect([PanelWin]::Found, [ref]$r) | Out-Null
Write-Output ("hwnd={0} rect: L={1} T={2} R={3} B={4}" -f [PanelWin]::Found, $r.L, $r.T, $r.R, $r.B)
if ( $shot -ne "" ) {
  $b = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $b.Size)
  $b.Save($shot)
  Write-Output ("shot -> " + $shot)
}
