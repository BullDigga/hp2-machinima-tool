# Screenshot the Map Selector window. ASCII only.
param([string]$shot = "")
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class MSelWin {
  public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int L, T, R, B; }
  public static IntPtr Found = IntPtr.Zero;
}
'@
[MSelWin]::SetProcessDPIAware() | Out-Null
$cb = { param($h, $l)
  $sb = New-Object System.Text.StringBuilder 256
  [MSelWin]::GetWindowText($h, $sb, 256) | Out-Null
  if ( $sb.ToString() -like "*Map Selector*" ) { [MSelWin]::Found = $h }
  return $true
}
[MSelWin]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ( [MSelWin]::Found -eq [IntPtr]::Zero ) { Write-Output "NO MAPSELECTOR"; exit 1 }
$r = New-Object MSelWin+RECT
[MSelWin]::GetWindowRect([MSelWin]::Found, [ref]$r) | Out-Null
Write-Output ("rect: L={0} T={1} R={2} B={3}" -f $r.L, $r.T, $r.R, $r.B)
if ( $shot -ne "" ) {
  $b = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  $g = [System.Drawing.Graphics]::FromImage($b)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $b.Size)
  $b.Save($shot)
  Write-Output ("shot -> " + $shot)
}
