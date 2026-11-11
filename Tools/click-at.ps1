# Synthetic left click at physical screen coords. ASCII only.
param([int]$x, [int]$y)
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices;
public class C {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
}' 2>$null
[C]::SetProcessDPIAware() | Out-Null
[C]::SetCursorPos($x, $y) | Out-Null
Start-Sleep -Milliseconds 120
[C]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)   # down
[C]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)   # up
'clicked {0},{1}' -f $x, $y
