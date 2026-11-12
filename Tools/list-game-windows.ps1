# List all window classes of the running Game.exe. ASCII only.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class EW2 {
  public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public static string Out = "";
}
'@
$gp = (Get-Process Game | Select-Object -First 1).Id
$cb = { param($h, $l)
  $p2 = 0
  [EW2]::GetWindowThreadProcessId($h, [ref]$p2) | Out-Null
  if ( $p2 -eq $gp ) {
    $sb = New-Object System.Text.StringBuilder 256
    [EW2]::GetClassName($h, $sb, 256) | Out-Null
    $vis = [EW2]::IsWindowVisible($h)
    $script:Out += "$($sb.ToString()) [vis=$vis] | "
  }
  return $true
}
[EW2]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
Write-Output ("classes: " + $script:Out)
