# HP2 Machinima Panel v3 - global hotkeys + always-on-top panel
# Hotkeys work WHILE THE GAME IS FOCUSED (no focus switching needed):
#   F8  = PathAdd        F9 = PathPlay (seconds box)
#   F10 = PathStop       F11 = SaveIni (persist + panel table refresh)
# Panel buttons send commands too (they activate the game window first).

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

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

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

    public static void TapChar(char c) {
        INPUT[] inp = new INPUT[2];
        inp[0].type = INPUT_KEYBOARD; inp[0].u.ki.wScan = c; inp[0].u.ki.dwFlags = 0x0004;
        inp[1].type = INPUT_KEYBOARD; inp[1].u.ki.wScan = c; inp[1].u.ki.dwFlags = 0x0004 | KEYEVENTF_KEYUP;
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
    $h = [GameCtl]::FindWindowW("GameUnrealWWindowsViewportWindow", [NullString]::Value)
    if ($h -ne [IntPtr]::Zero) { return $h }
    $h = [GameCtl]::FindWindowW([NullString]::Value, "Harry Potter and the Chamber of Secrets (X64-Release)")
    if ($h -ne [IntPtr]::Zero) { return $h }
    $p = Get-Process Game -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ( $p ) { return [IntPtr]$p.MainWindowHandle }
    return [IntPtr]::Zero
}

function Type-Command([string]$cmd) {
    # unicode-ввод: не зависит от раскладки клавиатуры
    foreach ($ch in $cmd.ToCharArray()) {
        [GameCtl]::TapChar($ch)
        Start-Sleep -Milliseconds 12
    }
}

# NOTE: the game must be the foreground window (user is playing/flying).
# We do NOT switch focus: grave -> type -> enter -> grave right into the focused game.
function Send-GameCommand([string]$cmd) {
    $h = Find-GameWindow
    if ($h -eq [IntPtr]::Zero) { return "game window not found!" }
    $fg = [GameCtl]::GetForegroundWindow()
    if ($fg -ne $h) {
        # ????????????/???????????? ???????? ?? ????????????: ???????????????????? ???????? (???????? ??????????????)
        [GameCtl]::ShowWindow($h, 9) | Out-Null
        [GameCtl]::Tap(0x12) | Out-Null
        [GameCtl]::SetForegroundWindow($h) | Out-Null
        Start-Sleep -Milliseconds 180
        $fg = [GameCtl]::GetForegroundWindow()
        if ($fg -ne $h) {
            return "could not focus the game - click the game window once"
        }
    }
    [GameCtl]::Tap([uint16]$VK['grave'])
    Start-Sleep -Milliseconds 120
    Type-Command $cmd
    [GameCtl]::Tap([uint16]$VK['enter'])
    Start-Sleep -Milliseconds 150
    [GameCtl]::Tap([uint16]$VK['grave'])
    Start-Sleep -Milliseconds 80
    return "$cmd  OK  " + (Get-Date -Format HH:mm:ss)
}

# ---------- keyframe table: LOCAL tracking (panel counts keys itself) ----------
# Игра не отдаёт данные наружу (SaveConfig/set ini: не пишут в M212) -
# панель считает кадры сама: F8=+1, Del=-1, Clear=0. Координаты не нужны:
# двойной клик = PathGoto (камера прыгает к кадру - видно глазами).

$script:KeyFovs = New-Object System.Collections.ArrayList    # FOV на момент добавления
$script:KeySpeeds = New-Object System.Collections.ArrayList  # скорость сегмента (для PathPlaySpeed)

function Refresh-Table {
    $rows = @()
    for ( $i = 0; $i -lt $script:KeyFovs.Count; $i++ ) {
        $sp = "-"
        if ( $i -lt $script:KeySpeeds.Count ) { $sp = $script:KeySpeeds[$i] }
        $rows += [PSCustomObject]@{
            Num = $i
            X   = "-"
            Y   = "-"
            Z   = "-"
            Yaw = "-"
            Pitch = "-"
            FOV = $script:KeyFovs[$i]
            Speed = $sp
        }
    }
    $controls['LvKeys'].ItemsSource = $rows
    if ( $rows.Count -eq 0 ) {
        Set-Status "table: 0 keyframes - press F8 in game to add"
    } else {
        Set-Status "table: $($rows.Count) keyframes"
    }
}

function Track-AddKey {
    $fov = $controls['TbFov'].Text.Trim()
    if ($fov -notmatch '^\d+(\.\d+)?$') { $fov = "90" }
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    [void]$script:KeyFovs.Add($fov)
    [void]$script:KeySpeeds.Add($sp)
    Refresh-Table
}

function Track-DelKey([int]$idx) {
    if ( $idx -ge 0 -and $idx -lt $script:KeyFovs.Count ) {
        $script:KeyFovs.RemoveAt($idx)
    }
    if ( $idx -ge 0 -and $idx -lt $script:KeySpeeds.Count ) {
        $script:KeySpeeds.RemoveAt($idx)
    }
    Refresh-Table
}

function Track-ClearKeys {
    $script:KeyFovs.Clear()
    $script:KeySpeeds.Clear()
    Refresh-Table
}

function Track-SetKeySpeed([int]$idx, [string]$val) {
    if ( $idx -ge 0 -and $idx -lt $script:KeySpeeds.Count ) {
        $script:KeySpeeds[$idx] = $val
    }
    Refresh-Table
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
               HorizontalAlignment="Center" Margin="0,0,0,2"/>
    <TextBlock Text="F8 AddKey  |  F9 Play  |  F10 Stop  |  F11 Clear" Foreground="#F9E2AF"
               FontSize="12" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,8"/>
    <UniformGrid Columns="3" Margin="0,0,0,4">
      <Button Name="BtnHideHud" Content="HideHud" Height="30" Margin="2" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnCam9" Content="Cam_Mode 9" Height="30" Margin="2" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnEscMenu" Content="Esc (close menu)" Height="30" Margin="2" Background="#45475A" Foreground="#CDD6F4"/>
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
          <GridViewColumn Header="X" Width="62" DisplayMemberBinding="{Binding X}"/>
          <GridViewColumn Header="Y" Width="62" DisplayMemberBinding="{Binding Y}"/>
          <GridViewColumn Header="Z" Width="62" DisplayMemberBinding="{Binding Z}"/>
          <GridViewColumn Header="Yaw" Width="56" DisplayMemberBinding="{Binding Yaw}"/>
          <GridViewColumn Header="Pitch" Width="50" DisplayMemberBinding="{Binding Pitch}"/>
          <GridViewColumn Header="FOV" Width="44" DisplayMemberBinding="{Binding FOV}"/>
          <GridViewColumn Header="Speed" Width="50" DisplayMemberBinding="{Binding Speed}"/>
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
      <Button Name="BtnKeySpeed" Content="Speed -> key" Height="30" Margin="2,0" Background="#CBA6F7" Foreground="#1E1E2E"/>
    </UniformGrid>
    <UniformGrid Columns="2" Margin="0,2,0,4">
      <TextBox Name="TbSpeed" Text="250" Height="30" Margin="2,0" FontSize="13"
               VerticalContentAlignment="Center" HorizontalContentAlignment="Center" Background="#313244" Foreground="#CDD6F4"/>
      <Button Name="BtnSpeed" Content="Set fly speed" Height="30" Margin="2,0" Background="#F5C97B" Foreground="#1E1E2E"/>
    </UniformGrid>
    <TextBlock Name="TbStatus" Text="ready" Foreground="#94E2D5" FontSize="11" Margin="2,2,0,0" TextWrapping="Wrap"/>
  </StackPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
foreach ($name in @('BtnHideHud','BtnCam9','BtnEscMenu','BtnPathAdd','TbSeconds','BtnPathPlay','BtnPathStop','BtnPathList','BtnPathClear','LvKeys','BtnRefresh','BtnGoto','BtnDel','TbFov','BtnSetFov','BtnKeySpeed','TbSpeed','BtnSpeed','TbStatus')) {
    $controls[$name] = $window.FindName($name)
}

function Set-Status([string]$s) {
    $controls['TbStatus'].Text = $s
}

function Do-PathAdd {
    Set-Status (Send-GameCommand "PathAdd")
    Track-AddKey
}
function Do-PathPlay {
    # speed-driven playback: длительность сегментов = дистанция / скорость кадра
    Set-Status (Send-GameCommand "PathPlaySpeed")
}
function Send-EscKey {
    if ( -not (Activate-Game) ) {
        Set-Status "game window not found!"
        return
    }
    [GameCtl]::Tap(0x1B)   # Escape
    Set-Status "Esc sent to game"
}

$controls['BtnHideHud'].Add_Click({ Set-Status (Send-GameCommand "HideHud") })
$controls['BtnCam9'].Add_Click({ Set-Status (Send-GameCommand "Cam_Mode 9") })
$controls['BtnEscMenu'].Add_Click({ Send-EscKey })
$controls['BtnPathAdd'].Add_Click({ Do-PathAdd })
$controls['BtnPathPlay'].Add_Click({ Do-PathPlay })
$controls['BtnPathStop'].Add_Click({ Set-Status (Send-GameCommand "PathStop") })
$controls['BtnPathList'].Add_Click({ Set-Status (Send-GameCommand "PathList") })
$controls['BtnPathClear'].Add_Click({
    Set-Status (Send-GameCommand "PathClear")
    Track-ClearKeys
})
$controls['BtnRefresh'].Add_Click({ Refresh-Table })
$controls['BtnGoto'].Add_Click({
    $sel = $controls['LvKeys'].SelectedItem
    if ( $sel -ne $null ) { Set-Status (Send-GameCommand "PathGoto $($sel.Num)") }
    else { Set-Status "select a keyframe row first" }
})
$controls['BtnDel'].Add_Click({
    $sel = $controls['LvKeys'].SelectedItem
    if ( $sel -ne $null ) {
        Set-Status (Send-GameCommand "PathDel $($sel.Num)")
        Track-DelKey $sel.Num
    } else { Set-Status "select a keyframe row first" }
})
$controls['BtnSetFov'].Add_Click({
    $fov = $controls['TbFov'].Text.Trim()
    if ($fov -notmatch '^\d+(\.\d+)?$') { $fov = "90" }
    Set-Status (Send-GameCommand "Cam_FOV $fov")
})
$controls['BtnSpeed'].Add_Click({
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    Set-Status (Send-GameCommand "Cam_MoveSpeed $sp")
})
$controls['BtnKeySpeed'].Add_Click({
    $sel = $controls['LvKeys'].SelectedItem
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    if ( $sel -ne $null ) {
        Set-Status (Send-GameCommand "PathSetKeySpeed $($sel.Num) $sp")
        Track-SetKeySpeed $sel.Num $sp
    } else { Set-Status "select a keyframe row first" }
})
$controls['LvKeys'].Add_MouseDoubleClick({
    $sel = $controls['LvKeys'].SelectedItem
    if ( $sel -ne $null ) { Set-Status (Send-GameCommand "PathGoto $($sel.Num)") }
})

# ---------- global hotkeys ----------

$window.Add_Loaded({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper $window
    $hwnd = $helper.Handle
    $src = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
    # id: 1=PathAdd(F8) 2=PathPlay(F9) 3=PathStop(F10) 4=SaveIni(F11)
    [GameCtl]::RegisterHotKey($hwnd, 1, 0, 0x77) | Out-Null
    [GameCtl]::RegisterHotKey($hwnd, 2, 0, 0x78) | Out-Null
    [GameCtl]::RegisterHotKey($hwnd, 3, 0, 0x79) | Out-Null
    [GameCtl]::RegisterHotKey($hwnd, 4, 0, 0x7A) | Out-Null
    $src.AddHook({
        param($hwnd, $msg, $wparam, $lparam, $handled)
        if ( $msg -eq 0x0312 )   # WM_HOTKEY
        {
            $id = $wparam.ToInt32()
            switch ($id) {
                1 { $window.Dispatcher.BeginInvoke([Action]{ Do-PathAdd }) | Out-Null }
                2 { $window.Dispatcher.BeginInvoke([Action]{ Do-PathPlay }) | Out-Null }
                3 { $window.Dispatcher.BeginInvoke([Action]{ Set-Status (Send-GameCommand "PathStop") }) | Out-Null }
                4 {
                    # F11 = PathClear + локальный сброс (сохранение в ini в M212 не работает)
                    $window.Dispatcher.BeginInvoke([Action]{
                        Set-Status (Send-GameCommand "PathClear")
                        Track-ClearKeys
                    }) | Out-Null
                }
            }
            return [IntPtr]::Zero
        }
        return [IntPtr]::Zero
    })
    Set-Status "hotkeys: F8 add / F9 play / F10 stop / F11 clear"
    Refresh-Table
})

$window.Add_Closing({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper $window
    for ( $id = 1; $id -le 4; $id++ ) { [GameCtl]::UnregisterHotKey($helper.Handle, $id) | Out-Null }
})

$window.ShowDialog() | Out-Null


