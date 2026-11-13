# Bring the panel window to the foreground (ALT-tap trick + SetForegroundWindow). ASCII only.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class FP {
  public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int m);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  public static IntPtr Found = IntPtr.Zero;
}
'@
$cb = {
    param($h, $l)
    $sb = New-Object System.Text.StringBuilder 256
    [FP]::GetWindowText($h, $sb, 256) | Out-Null
    if ( $sb.ToString() -eq "HP2 Machinima Panel" ) { [FP]::Found = $h }
    return $true
}
[FP]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ( [FP]::Found -eq [IntPtr]::Zero ) { Write-Output "NO PANEL"; exit 1 }
[FP]::ShowWindow([FP]::Found, 9) | Out-Null
Start-Sleep -Milliseconds 200
[FP]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 50
[FP]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
[FP]::SetForegroundWindow([FP]::Found) | Out-Null
Write-Output ("panel focused: " + [FP]::Found)
