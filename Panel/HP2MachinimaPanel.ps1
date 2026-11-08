# HP2 Machinima Panel - always-on-top control panel for HP2 free camera (M212 engine)
# Buttons send console commands into the game window automatically.

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
        return
    }
    [GameCtl]::Tap([ushort]$VK['grave'])
    Start-Sleep -Milliseconds 120
    Type-Command $cmd
    [GameCtl]::Tap([ushort]$VK['enter'])
    Start-Sleep -Milliseconds 150
    [GameCtl]::Tap([ushort]$VK['grave'])
    Start-Sleep -Milliseconds 80
    $script:Status = "$cmd  OK  " + (Get-Date -Format HH:mm:ss)
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HP2 Machinima Panel" Width="300" SizeToContent="Height"
        Topmost="True" Background="#1E1E2E" WindowStyle="ToolWindow"
        ResizeMode="NoResize" WindowStartupLocation="Manual" Left="20" Top="120">
  <StackPanel Margin="10">
    <TextBlock Text="HP2 MACHINIMA" Foreground="#CDD6F4" FontSize="14" FontWeight="Bold"
               HorizontalAlignment="Center" Margin="0,0,0,8"/>
    <UniformGrid Columns="2" Margin="0,0,0,6">
      <Button Name="BtnHideHud" Content="HideHud" Height="34" Margin="2" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnCam9" Content="Cam_Mode 9" Height="34" Margin="2" Background="#313244" Foreground="#CDD6F4"/>
    </UniformGrid>
    <Button Name="BtnPathAdd" Content="ADD KEYFRAME" Height="46" Margin="0,2" Background="#A6E3A1" Foreground="#1E1E2E"
            FontSize="15" FontWeight="Bold"/>
    <UniformGrid Columns="2" Margin="0,6,0,2">
      <TextBox Name="TbSeconds" Text="15" Height="40" Margin="2,0" FontSize="16"
               VerticalContentAlignment="Center" HorizontalContentAlignment="Center" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnPathPlay" Content="PLAY" Height="40" Margin="2,0" Background="#F9E2AF" Foreground="#1E1E2E"
              FontSize="15" FontWeight="Bold"/>
    </UniformGrid>
    <UniformGrid Columns="3" Margin="0,6">
      <Button Name="BtnPathStop" Content="Stop" Height="32" Margin="2" Background="#45475A" Foreground="#CDD6F4"/>
      <Button Name="BtnPathList" Content="List" Height="32" Margin="2" Background="#45475A" Foreground="#CDD6F4"/>
      <Button Name="BtnPathClear" Content="Clear" Height="32" Margin="2" Background="#F38BA8" Foreground="#1E1E2E"/>
    </UniformGrid>
    <UniformGrid Columns="2" Margin="0,2,0,6">
      <Button Name="BtnCam3" Content="Cam 3 (Harry)" Height="30" Margin="2" Background="#45475A" Foreground="#CDD6F4"/>
      <Button Name="BtnQuickLoad" Content="QuickLoad" Height="30" Margin="2" Background="#45475A" Foreground="#CDD6F4"/>
    </UniformGrid>
    <TextBlock Name="TbStatus" Text="ready" Foreground="#94E2D5" FontSize="11" Margin="2,4,0,0" TextWrapping="Wrap"/>
  </StackPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
foreach ($name in @('BtnHideHud','BtnCam9','BtnPathAdd','TbSeconds','BtnPathPlay','BtnPathStop','BtnPathList','BtnPathClear','BtnCam3','BtnQuickLoad','TbStatus')) {
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
    $controls['TbStatus'].Text = $script:Status
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
$controls['BtnCam3'].Add_Click({
    Send-GameCommand "Cam_Mode 3"
    $controls['TbStatus'].Text = $script:Status
})
$controls['BtnQuickLoad'].Add_Click({
    Send-GameCommand "QuickLoad"
    $controls['TbStatus'].Text = $script:Status
})

$window.ShowDialog() | Out-Null
