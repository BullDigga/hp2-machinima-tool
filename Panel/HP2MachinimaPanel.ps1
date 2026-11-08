# HP2 Machinima Panel v2 - control panel with keyframe table and FOV
# Requires: game running; the patched HGame.u with Path* commands.

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class GameCtl {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindowW(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT {
        public int dx; public int dy; public uint mouseData;
        public uint dwFlags; public uint time; public IntPtr dwExtraInfo;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT {
        public ushort wVk; public ushort wScan; public uint dwFlags;
        public uint time; public IntPtr dwExtraInfo;
    }
    [StructLayout(LayoutKind.Explicit)]
    public struct INPUTUNION {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public uint type; public INPUTUNION u;
    }

    public const uint INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint n, INPUT[] p, int size);

    public static void Tap(ushort vk) {
        INPUT[] inp = new INPUT[2];
        inp[0].type = INPUT_KEYBOARD; inp[0].u.ki.wVk = vk;
        inp[1].type = INPUT_KEYBOARD; inp[1].u.ki.wVk = vk; inp[1].u.ki.dwFlags = KEYEVENTF_KEYUP;
        SendInput(2, inp, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void KeyDown(ushort vk) {
        INPUT[] inp = new INPUT[1];
        inp[0].type = INPUT_KEYBOARD; inp[0].u.ki.wVk = vk;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void KeyUp(ushort vk) {
        INPUT[] inp = new INPUT[1];
        inp[0].type = INPUT_KEYBOARD; inp[0].u.ki.wVk = vk; inp[0].u.ki.dwFlags = KEYEVENTF_KEYUP;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@

$VK = @{ grave = 0xC0; enter = 0x0D; space = 0x20; shift = 0x10 }
for ($i = 0; $i -lt 26; $i++) { $VK[[string][char](65 + $i)] = 0x41 + $i }
for ($i = 0; $i -lt 10; $i++) { $VK[[string][char](48 + $i)] = 0x30 + $i }
$VK['_'] = 0xBD
$VK['.'] = 0xBE

function Find-GameWindow {
    return [GameCtl]::FindWindowW("GameUnrealWWindowsViewportWindow", $null)
}

function Activate-Game {
    $h = Find-GameWindow
    if ($h -eq [IntPtr]::Zero) { return $false }
    [GameCtl]::ShowWindow($h, 9) | Out-Null
    [GameCtl]::Tap(0x12) | Out-Null
    [GameCtl]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 150
    return $true
}

function Type-Command([string]$cmd) {
    foreach ($ch in $cmd.ToCharArray()) {
        $key = [string]$ch
        if (-not $VK.ContainsKey($key)) { continue }
        $vk = [ushort]$VK[$key]
        if ($ch -eq '_') {
            [GameCtl]::KeyDown(0x10)
            Start-Sleep -Milliseconds 15
            [GameCtl]::Tap($vk)
            [GameCtl]::KeyUp(0x10)
            Start-Sleep -Milliseconds 15
        } else {
            [GameCtl]::Tap($vk)
            Start-Sleep -Milliseconds 15
        }
    }
}

$script:Status = "ready"

function Send-GameCommand([string]$cmd) {
    if (-not (Activate-Game)) {
        $script:Status = "game window not found!"
        return $false
    }
    [GameCtl]::Tap([ushort]$VK['grave'])
    Start-Sleep -Milliseconds 120
    Type-Command $cmd
    [GameCtl]::Tap([ushort]$VK['enter'])
    Start-Sleep -Milliseconds 150
    [GameCtl]::Tap([ushort]$VK['grave'])
    Start-Sleep -Milliseconds 80
    $script:Status = "$cmd  OK  " + (Get-Date -Format HH:mm:ss)
    return $true
}

# ---------- keyframe table data ----------

function Find-PathIni {
    $candidates = @(
        "F:\Harry Potter and the Chamber of Secrets\system\User.ini",
        "F:\Harry Potter and the Chamber of Secrets\system\Default.ini",
        "C:\Users\$env:USERNAME\Documents\Harry - Coding Evolved\User.ini",
        "C:\Users\$env:USERNAME\Documents\Harry - Coding Evolved\Default.ini"
    )
    foreach ($p in $candidates) {
        if ( (Test-Path $p) -and ((Get-Content $p -Raw -ErrorAction SilentlyContinue) -match 'SavedPathData') ) {
            return $p
        }
    }
    return $null
}

function Get-SavedPathData {
    $ini = Find-PathIni
    if ( -not $ini ) { return "" }
    $t = Get-Content $ini -Raw
    $m = [regex]::Match($t, 'SavedPathData="?([^"\r\n]+)')
    if ( $m.Success ) { return $m.Groups[1].Value }
    return ""
}

function Refresh-Table {
    $rows = @()
    $data = Get-SavedPathData
    if ( $data -ne "" ) {
        $keys = $data -split ';'
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $f = $keys[$i] -split ','
            if ( $f.Count -ge 6 ) {
                $rows += [PSCustomObject]@{
                    Num   = $i
                    X     = [math]::Round([double]$f[0], 1)
                    Y     = [math]::Round([double]$f[1], 1)
                    Z     = [math]::Round([double]$f[2], 1)
                    Yaw   = $f[3]
                    Pitch = $f[4]
                    FOV   = [math]::Round([double]$f[5], 1)
                }
            }
        }
    }
    $controls['LvKeys'].ItemsSource = $rows
    if ( $rows.Count -eq 0 ) {
        $script:Status = "table empty - press SaveIni in game first"
    } else {
        $script:Status = "table: $($rows.Count) keyframes"
    }
    $controls['TbStatus'].Text = $script:Status
}

# ---------- UI ----------

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HP2 Machinima Panel" Width="560" SizeToContent="Height"
        Topmost="True" Background="#1E1E2E" WindowStyle="ToolWindow"
        ResizeMode="NoResize" WindowStartupLocation="Manual" Left="20" Top="60">
  <StackPanel Margin="10">
    <TextBlock Text="HP2 MACHINIMA PANEL" Foreground="#CDD6F4" FontSize="14" FontWeight="Bold"
               HorizontalAlignment="Center" Margin="0,0,0,8"/>
    <UniformGrid Columns="2" Margin="0,0,0,4">
      <Button Name="BtnHideHud" Content="HideHud" Height="30" Margin="2" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnCam9" Content="Cam_Mode 9" Height="30" Margin="2" Background="#313244" Foreground="#CDD6F4"/>
    </UniformGrid>
    <Button Name="BtnPathAdd" Content="ADD KEYFRAME (PathAdd)" Height="42" Margin="0,2" Background="#A6E3A1" Foreground="#1E1E2E"
            FontSize="14" FontWeight="Bold"/>
    <UniformGrid Columns="2" Margin="0,4,0,2">
      <TextBox Name="TbSeconds" Text="15" Height="34" Margin="2,0" FontSize="14"
               VerticalContentAlignment="Center" HorizontalContentAlignment="Center" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnPathPlay" Content="PLAY" Height="34" Margin="2,0" Background="#F9E2AF" Foreground="#1E1E2E"
              FontSize="14" FontWeight="Bold"/>
    </UniformGrid>
    <UniformGrid Columns="3" Margin="0,4">
      <Button Name="BtnPathStop" Content="Stop" Height="30" Margin="2" Background="#45475A" Foreground="#CDD6F4"/>
      <Button Name="BtnPathList" Content="List" Height="30" Margin="2" Background="#45475A" Foreground="#CDD6F4"/>
      <Button Name="BtnPathClear" Content="Clear" Height="30" Margin="2" Background="#F38BA8" Foreground="#1E1E2E"/>
    </UniformGrid>

    <TextBlock Text="KEYFRAMES (double-click = go to key)" Foreground="#A6ADC8" FontSize="11" Margin="2,8,0,2"/>
    <ListView Name="LvKeys" Height="150" Background="#181825" Foreground="#CDD6F4" BorderBrush="#45475A"
              FontFamily="Consolas" FontSize="11">
      <ListView.View>
        <GridView>
          <GridViewColumn Header="#" Width="34" DisplayMemberBinding="{Binding Num}"/>
          <GridViewColumn Header="X" Width="70" DisplayMemberBinding="{Binding X}"/>
          <GridViewColumn Header="Y" Width="70" DisplayMemberBinding="{Binding Y}"/>
          <GridViewColumn Header="Z" Width="70" DisplayMemberBinding="{Binding Z}"/>
          <GridViewColumn Header="Yaw" Width="62" DisplayMemberBinding="{Binding Yaw}"/>
          <GridViewColumn Header="Pitch" Width="56" DisplayMemberBinding="{Binding Pitch}"/>
          <GridViewColumn Header="FOV" Width="48" DisplayMemberBinding="{Binding FOV}"/>
        </GridView>
      </ListView.View>
    </ListView>
    <UniformGrid Columns="3" Margin="0,4">
      <Button Name="BtnRefresh" Content="Refresh table" Height="30" Margin="2" Background="#89DCEB" Foreground="#1E1E2E"/>
      <Button Name="BtnGoto" Content="Go to selected" Height="30" Margin="2" Background="#89DCEB" Foreground="#1E1E2E"/>
      <Button Name="BtnDel" Content="Delete selected" Height="30" Margin="2" Background="#F38BA8" Foreground="#1E1E2E"/>
    </UniformGrid>
    <UniformGrid Columns="3" Margin="0,2,0,4">
      <TextBox Name="TbFov" Text="90" Height="30" Margin="2,0" FontSize="13"
               VerticalContentAlignment="Center" HorizontalContentAlignment="Center" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnSetFov" Content="Set FOV" Height="30" Margin="2,0" Background="#CBA6F7" Foreground="#1E1E2E"/>
      <Button Name="BtnSaveIni" Content="SaveIni" Height="30" Margin="2,0" Background="#94E2D5" Foreground="#1E1E2E"/>
    </UniformGrid>
    <TextBlock Name="TbStatus" Text="ready" Foreground="#94E2D5" FontSize="11" Margin="2,2,0,0" TextWrapping="Wrap"/>
  </StackPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
foreach ($name in @('BtnHideHud','BtnCam9','BtnPathAdd','TbSeconds','BtnPathPlay','BtnPathStop','BtnPathList','BtnPathClear','LvKeys','BtnRefresh','BtnGoto','BtnDel','TbFov','BtnSetFov','BtnSaveIni','TbStatus')) {
    $controls[$name] = $window.FindName($name)
}

$controls['BtnHideHud'].Add_Click({
    Send-GameCommand "HideHud"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnCam9'].Add_Click({
    Send-GameCommand "Cam_Mode 9"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnPathAdd'].Add_Click({
    Send-GameCommand "PathAdd"
    $controls['TbStatus'].Text = $script:Status + "   (SaveIni + Refresh to update table)"
})
$controls['BtnPathPlay'].Add_Click({
    $sec = $controls['TbSeconds'].Text.Trim()
    if ($sec -notmatch '^\d+(\.\d+)?$') { $sec = "15" }
    Send-GameCommand "PathPlay $sec"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnPathStop'].Add_Click({
    Send-GameCommand "PathStop"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnPathList'].Add_Click({
    Send-GameCommand "PathList"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnPathClear'].Add_Click({
    Send-GameCommand "PathClear"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnRefresh'].Add_Click({
    Refresh-Table
})
$controls['BtnGoto'].Add_Click({
    $sel = $controls['LvKeys'].SelectedItem
    if ( $sel -ne $null ) {
        Send-GameCommand "PathGoto $($sel.Num)"
        $controls['TbStatus'].Text = $script:Status
    } else {
        $controls['TbStatus'].Text = "select a keyframe row first"
    }
})
$controls['BtnDel'].Add_Click({
    $sel = $controls['LvKeys'].SelectedItem
    if ( $sel -ne $null ) {
        Send-GameCommand "PathDel $($sel.Num)"
        Start-Sleep -Milliseconds 200
        Send-GameCommand "PathSave"
        Refresh-Table
    } else {
        $controls['TbStatus'].Text = "select a keyframe row first"
    }
})
$controls['BtnSetFov'].Add_Click({
    $fov = $controls['TbFov'].Text.Trim()
    if ($fov -notmatch '^\d+(\.\d+)?$') { $fov = "90" }
    Send-GameCommand "Cam_FOV $fov"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnSaveIni'].Add_Click({
    Send-GameCommand "PathSave"
    Start-Sleep -Milliseconds 300
    Refresh-Table
})

# double-click on a row = go to key
$controls['LvKeys'].Add_MouseDoubleClick({
    $sel = $controls['LvKeys'].SelectedItem
    if ( $sel -ne $null ) {
        Send-GameCommand "PathGoto $($sel.Num)"
        $controls['TbStatus'].Text = $script:Status
    }
})

$window.ShowDialog() | Out-Null
