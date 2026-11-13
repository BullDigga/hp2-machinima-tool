# Enumerate ALL windows titled 'HP2 Machinima Panel' + all panel processes. ASCII only.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class EW {
  public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int L, T, R, B; }
}
'@
$found = @()
$cb = {
    param($h, $l)
    $sb = New-Object System.Text.StringBuilder 256
    [EW]::GetWindowText($h, $sb, 256) | Out-Null
    if ( $sb.ToString() -like "*Machinima Panel*" ) {
        $pid2 = 0
        [EW]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
        $r = New-Object EW+RECT
        [EW]::GetWindowRect($h, [ref]$r) | Out-Null
        $script:found += ("hwnd={0} pid={1} visible={2} rect=({3},{4})-({5},{6})" -f $h, $pid2, [EW]::IsWindowVisible($h), $r.L, $r.T, $r.R, $r.B)
    }
    return $true
}
[EW]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
$found | ForEach-Object { Write-Output $_ }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*HP2MachinimaPanel*' } | ForEach-Object { Write-Output ("panel process pid=" + $_.ProcessId + " started " + $_.CreationDate) }
