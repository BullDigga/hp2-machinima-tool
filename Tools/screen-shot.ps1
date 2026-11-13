# Full-screen screenshot (primary monitor). ASCII only.
param([string]$shot = "C:\Users\Kolya\.zcode\workspace\4f19d2d1-d433-4180-8864-acf7c24ed6f5\hp2-machinima-tool\Tools\screen.png")
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class S2 { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll")] public static extern int GetSystemMetrics(int n); }' 2>$null
[S2]::SetProcessDPIAware() | Out-Null
$w = [S2]::GetSystemMetrics(0); $h = [S2]::GetSystemMetrics(1)
$b = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen(0, 0, 0, 0, $b.Size)
$g.Dispose()
$b.Save($shot)
$b.Dispose()
Write-Output ("shot ${w}x${h} -> " + $shot)
