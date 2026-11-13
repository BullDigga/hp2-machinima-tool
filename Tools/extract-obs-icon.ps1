# Extract the OBS app icon from obs64.exe to Panel\obs-icon.png. ASCII only.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing | Out-Null
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public class IconX {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)]
  public static extern uint PrivateExtractIcons(string fn, int idx, int w, int h, IntPtr[] icons, uint[] ids, int cnt, out int got);
  [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetIconInfo(IntPtr h, out ICONINFO ii);
  [StructLayout(LayoutKind.Sequential)]
  public struct ICONINFO { public bool fIcon; public int xHotspot, yHotspot; public IntPtr hbmMask, hbmColor; }
  public static Bitmap FromExe(string exe, int size) {
    IntPtr[] icons = new IntPtr[1]; uint[] ids = new uint[1]; int got;
    uint n = PrivateExtractIcons(exe, 0, size, size, icons, ids, 1, out got);
    if ( n == 0 || icons[0] == IntPtr.Zero ) return null;
    ICONINFO ii;
    if ( !GetIconInfo(icons[0], out ii) ) return null;
    Bitmap bmp = Bitmap.FromHicon(icons[0]) as Bitmap;
    try { if ( ii.hbmColor != IntPtr.Zero ) DeleteObject(ii.hbmColor); if ( ii.hbmMask != IntPtr.Zero ) DeleteObject(ii.hbmMask); } catch { }
    DestroyIcon(icons[0]);
    return bmp;
  }
  [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
}
'@ | Out-Null
$bmp = [IconX]::FromExe('C:\obs-studio\bin\64bit\obs64.exe', 96)
if ( $bmp -eq $null ) { Write-Output "EXTRACT FAILED"; exit 1 }
$out = 'C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Panel\obs-icon.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("saved " + $out + " " + $bmp.Width + "x" + $bmp.Height)
