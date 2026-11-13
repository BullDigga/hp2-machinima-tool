# Dump RAW console echo (typed input) by enumerating the game's committed
# MEM_PRIVATE memory and searching for console echo markers. Slow (full enum),
# diagnostic only. ASCII only.
param([int]$maxHits = 12)
$ErrorActionPreference = "Stop"
$gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
if ( $gp -eq $null ) { Write-Output "GAME NOT RUNNING"; exit 1 }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MemWalk {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool h, int pid);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr p, IntPtr addr, byte[] buf, int size, out int read);
  [StructLayout(LayoutKind.Sequential)]
  public struct MBI { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public uint align1; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; public uint align2; }
  [DllImport("kernel32.dll")] public static extern IntPtr VirtualQueryEx(IntPtr p, IntPtr addr, out MBI info, int len);
}
'@
$h = [MemWalk]::OpenProcess(0x1010, $false, $gp.Id)   # VM_READ + QUERY_LIMITED
if ( $h -eq [IntPtr]::Zero ) { Write-Output "OpenProcess FAILED"; exit 1 }
$addr = [long]0x10000
$all = New-Object System.Text.StringBuilder
$regions = 0
while ( $addr -lt 0x7FFFFFFFFFFF ) {
    $mbi = New-Object MemWalk+MBI
    $r = [MemWalk]::VirtualQueryEx($h, [IntPtr]$addr, [ref]$mbi, [System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
    if ( $r -eq 0 ) { break }
    $rsize = [long]$mbi.RegionSize
    if ( $mbi.State -eq 0x1000 -and $rsize -ge 4096 ) {
        $cap = [int][Math]::Min($rsize, 8MB)
        $buf = New-Object byte[] $cap
        $read = 0
        if ( [MemWalk]::ReadProcessMemory($h, [IntPtr]$addr, $buf, $cap, [ref]$read) -and $read -gt 0 ) {
            $txt = [System.Text.Encoding]::Unicode.GetString($buf, 0, $read)
            if ( $txt.Contains("PATHEV:") -or $txt.Contains("Unrecognized") -or $txt.Contains("> PathAdd") -or $txt.Contains("Path: key") ) {
                [void]$all.Append($txt)
                $regions++
            }
        }
    }
    $addr += $rsize
}
[MemWalk]::CloseHandle($h) | Out-Null
Write-Output ("log regions: $regions, chars: " + $all.Length)
$allTxt = $all.ToString()
$unk = [regex]::Matches($allTxt, 'Unrecognized command')
Write-Output ("Unrecognized contexts:")
foreach ( $h in $unk ) {
    $s = [Math]::Max(0, $h.Index - 200)
    $len = [Math]::Min(420, $allTxt.Length - $s)
    Write-Output ("=====")
    Write-Output ($allTxt.Substring($s, $len) -replace "[^\x20-\x7E\r\n]", ".")
}
$echoes = [regex]::Matches($allTxt, 'Path(Add|Ping|PlaySpeed|DumpKeys)')
Write-Output ("command mentions: " + $echoes.Count)
$skip = [Math]::Max(0, $echoes.Count - $maxHits)
for ( $i = $skip; $i -lt $echoes.Count; $i++ ) {
    $s = [Math]::Max(0, $echoes[$i].Index - 40)
    $len = [Math]::Min(110, $allTxt.Length - $s)
    Write-Output ("--- " + ($allTxt.Substring($s, $len) -replace "[^\x20-\x7E\r\n]", "."))
}
