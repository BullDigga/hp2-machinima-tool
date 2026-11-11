# HP2 Machinima Panel v3 - global hotkeys + always-on-top panel
# Hotkeys work WHILE THE GAME IS FOCUSED (no focus switching needed):
#   F8  = PathAdd        F9 = PathPlay (seconds box)
#   F10 = PathStop       F11 = SaveIni (persist + panel table refresh)
# Panel buttons send commands too (they activate the game window first).

$ErrorActionPreference = "Stop"

# v5.17.10.1: свой AppUserModelID ДО любого окна - без него таскбар приколачивает
# кнопку панели к AUMID powershell.exe и показывает его значок, игнорируя Window.Icon
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ShellId {
    [DllImport("shell32.dll", SetLastError=false)]
    public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
}
"@
[ShellId]::SetCurrentProcessExplicitAppUserModelID("BullDigga.HP2MachinimaPanel") | Out-Null

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

Add-Type -TypeDefinition @"
public class KeyRow {
    public int Num { get; set; }
    public string Time { get; set; }
    public double X { get; set; }
    public double Y { get; set; }
    public double Z { get; set; }
    public int Yaw { get; set; }
    public int Pitch { get; set; }
    public double FOV { get; set; }
    public double Speed { get; set; }
    public long Seq { get; set; }
}
"@

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MemScanPanel {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool b, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [StructLayout(LayoutKind.Sequential)]
    public struct MBI { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h, IntPtr addr, out MBI info, uint len);

    // ищем область памяти с полным логом сессии и выгружаем события PATH*
    public static string GetLogEvents(int pid) {
        IntPtr h = OpenProcess(0x0410, false, pid);
        if ( h == IntPtr.Zero ) return "|OPENFAILED";
        // ---- пасс 1: разведка - ищем UTF-16LE "PATHEV:" по ВСЕМ областям ----
        byte[] wprobe = System.Text.Encoding.Unicode.GetBytes("PATHEV:");
        long addr = 0x10000;
        MBI mbi;
        byte[] probe = new byte[0x400000];
        var hitRegs = new System.Collections.Generic.List<long>();  // пары addr,size
        while ( VirtualQueryEx(h, (IntPtr)addr, out mbi, (uint)Marshal.SizeOf(typeof(MBI))) != 0 ) {
            long size = mbi.RegionSize.ToInt64();
            if ( mbi.State == 0x1000 && size > 0 ) {
                int cnt = 0;
                long off = 0;
                while ( off < size ) {
                    IntPtr read;
                    int toRead = (int)Math.Min(size - off, probe.Length);
                    if ( ReadProcessMemory(h, (IntPtr)(mbi.BaseAddress.ToInt64() + off), probe, (IntPtr)toRead, out read) ) {
                        int n = read.ToInt32();
                        for ( int i = 0; i <= n - wprobe.Length; i++ ) {
                            if ( probe[i] != wprobe[0] || probe[i+1] != wprobe[1] ) continue;
                            bool ok = true;
                            for ( int k = 2; k < wprobe.Length; k++ ) { if ( probe[i+k] != wprobe[k] ) { ok = false; break; } }
                            if ( ok ) { cnt++; i += wprobe.Length; }
                        }
                    }
                    off += 0x400000;
                }
                if ( cnt > 0 ) { hitRegs.Add(mbi.BaseAddress.ToInt64()); hitRegs.Add(size); }
            }
            addr += size;
            if ( addr > 0x7FFFFFFEFFFF ) break;
        }
        // ---- пасс 2: извлечение PATHEV из КАЖДОЙ области с попаданиями ----
        // (в куче живёт несколько копий буфера лога; дедуп по seq делает панель)
        var sb = new System.Text.StringBuilder();
        int chunk = 0x400000;
        int overlap = 4096;
        byte[] buf = new byte[chunk + overlap];
        for ( int r = 0; r < hitRegs.Count; r += 2 ) {
            long regA = hitRegs[r];
            long regS = hitRegs[r + 1];
            var seen = new System.Collections.Generic.HashSet<long>();
            long pos = 0;
            while ( pos < regS ) {
                int toRead = (int)Math.Min(regS - pos + overlap, buf.Length);
                if ( toRead > regS - pos && regS - pos < buf.Length ) toRead = (int)(regS - pos);
                IntPtr rd;
                if ( ReadProcessMemory(h, (IntPtr)(regA + pos), buf, (IntPtr)toRead, out rd) ) {
                    int n = rd.ToInt32();
                    string s = System.Text.Encoding.Unicode.GetString(buf, 0, n);
                    for ( int i = s.IndexOf("PATHEV:"); i >= 0; i = s.IndexOf("PATHEV:", i + 7) ) {
                        long abs = (pos >> 1) + i;
                        if ( !seen.Add(abs) ) continue;
                        int en = i;
                        while ( en < s.Length && s[en] >= 32 ) en++;
                        sb.Append(s.Substring(i, en - i) + "\n");
                    }
                }
                pos += chunk;
            }
        }
        CloseHandle(h);
        var hdr2 = new System.Text.StringBuilder("|REGS:" + (hitRegs.Count / 2));
        for ( int r = 0; r < hitRegs.Count; r++ ) { hdr2.Append("|" + hitRegs[r]); }
        return hdr2.ToString() + "\n" + sb.ToString();
    }

    // быстрый путь: извлечь PATHEV только из кэшированных областей (addr,size,...)
    public static string ExtractRegions(int pid, long[] pairs) {
        if ( pairs.Length < 2 ) return "";
        IntPtr h = OpenProcess(0x0410, false, pid);
        if ( h == IntPtr.Zero ) return "";
        var sb = new System.Text.StringBuilder();
        int chunk = 0x400000;
        int overlap = 4096;
        byte[] buf = new byte[chunk + overlap];
        for ( int r = 0; r + 1 < pairs.Length; r += 2 ) {
            long regA = pairs[r];
            long regS = pairs[r + 1];
            var seen = new System.Collections.Generic.HashSet<long>();
            long pos = 0;
            while ( pos < regS ) {
                int toRead = (int)Math.Min(regS - pos + overlap, buf.Length);
                if ( toRead > regS - pos && regS - pos < buf.Length ) toRead = (int)(regS - pos);
                IntPtr rd;
                if ( ReadProcessMemory(h, (IntPtr)(regA + pos), buf, (IntPtr)toRead, out rd) ) {
                    int n = rd.ToInt32();
                    string s = System.Text.Encoding.Unicode.GetString(buf, 0, n);
                    for ( int i = s.IndexOf("PATHEV:"); i >= 0; i = s.IndexOf("PATHEV:", i + 7) ) {
                        long abs = (pos >> 1) + i;
                        if ( !seen.Add(abs) ) continue;
                        int en = i;
                        while ( en < s.Length && s[en] >= 32 ) en++;
                        sb.Append(s.Substring(i, en - i) + "\n");
                    }
                }
                pos += chunk;
            }
        }
        CloseHandle(h);
        return sb.ToString();
    }

    // v5.8: фоновый скан (UI панели не блокируется, иконка ⟳ крутится)
    public static string AsyncResult = "";
    public static int AsyncState = 0;   // 0 idle, 1 running, 2 done

    public static void StartAsync(int pid, long[] pairs) {
        if ( AsyncState == 1 ) return;
        AsyncState = 1;
        AsyncResult = "";
        System.Threading.Thread t = new System.Threading.Thread(new System.Threading.ThreadStart(() => {
            try {
                AsyncResult = (pairs != null && pairs.Length >= 2) ? ExtractRegions(pid, pairs) : GetLogEvents(pid);
            } catch { AsyncResult = ""; }
            AsyncState = 2;
        }));
        t.IsBackground = true;
        t.Start();
    }
}
"@

$VK = @{ grave = 0xC0; enter = 0x0D; space = 0x20; shift = 0x10; numpad0 = 0x60 }
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

function Pump-Dispatcher {
    # v5.17.6: прокачка dispatcher'а во время долгой печати команд - UI-поток спит
    # в Start-Sleep и спиннер не крутится; PushFrame даёт отрисовке дойти до экрана
    try {
        $pumpFrame = New-Object System.Windows.Threading.DispatcherFrame
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([Action]{ $pumpFrame.Continue = $false }, [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
        [System.Windows.Threading.Dispatcher]::PushFrame($pumpFrame)
    } catch { }
}

function Wait-Pump([int]$ms) {
    # v5.17.7: сон кусочками по 10мс с прокачкой dispatcher'а на КАЖДОМ кусочке.
    # Раньше паузы были цельными Start-Sleep (180/260/600мс) - спиннер начинал
    # крутиться, но замирал на каждой паузе; теперь кадр отрисовки уходит каждые ~10мс
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ( $sw.ElapsedMilliseconds -lt $ms ) {
        Start-Sleep -Milliseconds 10
        Pump-Dispatcher
    }
}

function Type-Command([string]$cmd) {
    # unicode-ввод: не зависит от раскладки клавиатуры.
    # v5.17.2: 20мс/символ и 260мс после Enter - при быстрой печати длинных пачек команд
    # (импорт) консоль теряла символы и Enters, значения кадров мутировали
    foreach ($ch in $cmd.ToCharArray()) {
        [GameCtl]::TapChar($ch)
        Wait-Pump 20   # v5.17.7: пауза с прокачкой отрисовки на КАЖДОМ символе
    }
}

# NOTE: the game must be the foreground window (user is playing/flying).
# We do NOT switch focus: grave -> type -> enter -> grave right into the focused game.
# v5.8: окно консоли СКРЫТО на стороне игры (HPConsole.bQuietConsole - ConsoleWindow
# прячется в ShowConsole/Tick). Панель печатает как раньше, но окно не отрисовывается -
# пользователь не видит никаких всплывашек.
function Focus-GameWindow([IntPtr]$h) {
    $fg = [GameCtl]::GetForegroundWindow()
    if ($fg -eq $h) { return $true }
    [GameCtl]::ShowWindow($h, 9) | Out-Null
    [GameCtl]::Tap(0x12) | Out-Null
    [GameCtl]::SetForegroundWindow($h) | Out-Null
    Wait-Pump 180
    return ([GameCtl]::GetForegroundWindow() -eq $h)
}

$script:SendBusy = $false
$script:ConfirmBypass = $false
function Confirm-GameActive {
    # v5.17.15 (#1): перед манипуляциями с терминалом убеждаемся, что игра НА УРОВНЕ.
    # Игра запущена, но уровень не определён (CurrentMap == "") = меню или загрузка:
    # фокусируем окно игры и до ~3с ждём появления уровня; не дождались - отказ.
    # Вызывается из Send-GameCommands (пользовательские действия); 5.4с-полл живёт на
    # одиночном Send-GameCommand и меню не покидает.
    # ВНИМАНИЕ: зонд через Send-GameCommand -> Send-GameCommands -> Confirm - рекурсия;
    # поэтому зонд идёт с флагом ConfirmBypass (один уровень вложенности, UI однопоточен)
    try {
        if ( (Get-Process Game -ErrorAction SilentlyContinue) -eq $null ) {
            Set-Status $script:LocData[$script:Lang].TipNoWindow "err"
            return $false
        }
        if ( $script:CurrentMap -ne "" ) { return $true }
        $h = Find-GameWindow
        if ( $h -ne [IntPtr]::Zero ) { Focus-GameWindow $h | Out-Null }
        for ( $i = 0; $i -lt 6; $i++ ) {
            Wait-Pump 500
            $script:ConfirmBypass = $true
            try { Send-GameCommand "PathDumpKeys" | Out-Null } finally { $script:ConfirmBypass = $false }
            Sync-FromLog -Force
            if ( $script:CurrentMap -ne "" ) { return $true }
        }
        Set-Status $script:LocData[$script:Lang].TipInMenu "err"
        return $false
    } catch { return $false }
}

function Send-GameCommands([string[]]$cmds) {
    # v5.17.6: защита от повторного клика во время печати + Pump-Dispatcher
    # прокачивает отрисовку - спиннер крутится СРАЗУ и НЕ ЗАМИРАЕТ на весь ввод
    if ( $script:SendBusy ) { return "busy - command still sending" }
    if ( -not $script:ConfirmBypass -and -not (Confirm-GameActive) ) { return "aborted: game not on a level" }
    $script:SendBusy = $true
    try {
        Start-Spin   # v5.11: крутится СРАЗУ при клике, не после отправки команды
        # v5.17.7: оранжевый debug-статус СРАЗУ при клике - что и сколько печатаем
        $dbg = if ( $cmds.Count -gt 0 ) { [string]$cmds[0] } else { "" }
        if ( $dbg.Length -gt 42 ) { $dbg = $dbg.Substring(0, 42) + "..." }
        Set-Status ("typing $($cmds.Count) cmd(s): $dbg") "warn"
        $h = Find-GameWindow
        if ($h -eq [IntPtr]::Zero) { Stop-Spin; return "game window not found!" }
        if ( -not (Focus-GameWindow $h) ) { Stop-Spin; return "could not focus the game - click the game window once" }
        # v5.13: ОТКРЫТИЕ консоли панелью - Shift+` (тихая ветка KeyEvent, окно за экраном).
        # Обычный ` остаётся терминалом пользователя.
        [GameCtl]::KeyDown([uint16]0x10)
        [GameCtl]::Tap([uint16]$VK['grave'])
        [GameCtl]::KeyUp([uint16]0x10)
        Wait-Pump 120
        # v5.17.8: прогресс [i/N] с бегущими точками + проверка фокуса ПЕРЕД КАЖДОЙ командой.
        # Alt-Tab во время пачки (импорт) печатал остаток команд в ЧУЖОЕ окно, а консоль игры
        # оставалась открытой (чёрный экран). Теперь: фокус потерян -> один тихий рефокус,
        # не вышло -> чистый ABORT (ничего не печатаем дальше), пользователь видит [i/N].
        $ci = 0
        $res = ""
        foreach ($c in $cmds) {
            $dots = "." * (1 + ($ci % 3))
            Set-Status ("typing [$($ci+1)/$($cmds.Count)] $c $dots") "warn"
            if ( [GameCtl]::GetForegroundWindow() -ne $h -and -not (Focus-GameWindow $h) ) {
                $res = "ABORTED at [$($ci+1)/$($cmds.Count)] - focus lost! unfinished text may have gone to another window; press `` in game to close the console"
                break
            }
            Type-Command $c
            [GameCtl]::Tap([uint16]$VK['enter'])
            Wait-Pump 260
            $ci++
        }
        if ( $res -ne "" ) {
            # рефокус не удался: В ИГРУ НЕ ТЫКАЕМ (клавиши ушли бы в чужое окно) - только стоп
            Stop-Spin
            Set-Status $res "warn"
            return $res
        }
        # v5.17.8: консоль закрывает ИГРА изнутри по команде-маркеру PathPing (см. HPConsole).
        # Старый финальный grave-тап был тогглом: человеческий ` во время печати инвертировал
        # состояние консоли, и следующая пачка уходила в геймплей.
        Type-Command "PathPing"
        [GameCtl]::Tap([uint16]$VK['enter'])
        Wait-Pump 260
        Wait-Pump 80
        # одиночные команды без последующего синка: гасим спиннер сами (синк делает это раньше, если запущен)
        $script:SpinStopTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:SpinStopTimer.Interval = [TimeSpan]::FromMilliseconds(1400)
        $script:SpinStopTimer.Add_Tick({
            $script:SpinStopTimer.Stop()
            if ( -not $script:SyncBusy ) { Stop-Spin }
        })
        $script:SpinStopTimer.Start()
        return ("$($cmds.Count) cmds OK  " + (Get-Date -Format HH:mm:ss))
    } finally {
        $script:SendBusy = $false
    }
}

function Send-GameCommand([string]$cmd) { return Send-GameCommands @($cmd) }

# ---------- keyframe table: источник истины = лог игры ----------
# v4.3: ini-канал мёртв (SaveConfig молчит в M212 даже из HPConsole). Вместо него:
# игра запускается через 'Start Game with Log.bat' (-log) и движок пишет лог-файл;
# каждый PathAdd/PathDel/PathClear/PathSetKeySpeed уже пишет событие PATH* в лог.
# Панель переигрывает события и заполняет X/Y/Z/Yaw/Pitch/FOV/Speed.
# Редактирование Speed в таблице -> PathSetKeySpeed -> событие PATHSPEED в логе.

$script:IniPaths = @(
    "F:\Harry Potter and the Chamber of Secrets\system\DefUser.ini",
    "F:\Harry Potter and the Chamber of Secrets\system\Default.ini"
)
$script:KeyRows = New-Object System.Collections.ArrayList
$script:SeenSeqs = @{}      # "<gamepid>:<seq>" кадра -> seen
$script:KeyTimes = @{}      # "<gamepid>:<seq>" кадра -> "HH:mm:ss" времени постановки
$script:StampNextSync = $false
$script:ScanCache = @{ Pid = 0; Regions = @(); LastSeq = 0 }   # кэш областей лог-буфера
$script:CurrentMap = ""   # карта, где игра СЕЙЧАС (из MAP-событий)
$script:KeyMap = ""       # v5.14: карта, которой принадлежат кадры в таблице
$script:LastGen = -1      # v5.16: поколение лога (меняется на каждой загрузке уровня)
# времена постановки кадров переживают перезапуск панели (файл рядом со скриптом)
$script:KeyTimesFile = Join-Path $PSScriptRoot "key-times.txt"
if ( Test-Path $script:KeyTimesFile ) {
    foreach ( $ln in [System.IO.File]::ReadAllLines($script:KeyTimesFile) ) {
        $pp = $ln.Split('|')
        if ( $pp.Count -eq 2 -and $pp[0] -ne "" ) {
            # v5.17.9: ключ времени БЕЗ pid игры - времена должны переживать перезапуск
            # игры (pid меняется, координаты кадра - нет). Старые записи "pid:x;y;z|t"
            # мигрируем: отрезаем pid. Старые seq-ключи "pid:N" (без ';') не трогаем.
            $k = $pp[0]
            if ( $k.Contains(";") ) {
                $ci = $k.IndexOf(":")
                if ( $ci -ge 0 ) { $k = $k.Substring($ci + 1) }
            }
            if ( -not $script:KeyTimes.ContainsKey($k) ) { $script:KeyTimes[$k] = $pp[1] }
        }
    }
}

function Read-SavedPathData {
    foreach ( $f in $script:IniPaths ) {
        if ( Test-Path $f ) {
            try {
                $txt = [System.IO.File]::ReadAllText($f)
                $sec = [regex]::Match($txt, '(?ms)^\[HGame\.HPConsole\]\s*(.*?)(?=^\[|\z)')
                if ( $sec.Success ) {
                    $m = [regex]::Match($sec.Groups[1].Value, '(?m)^SavedPathData\s*=\s*(.*)$')
                    if ( $m.Success -and $m.Groups[1].Value.Trim() -ne "" ) {
                        return $m.Groups[1].Value.Trim()
                    }
                }
            } catch { }
        }
    }
    return ""
}

function Refresh-Table {
    # строки уже собраны в $script:KeyRows
    $dg = $controls['DgKeys']
    # v5.16.2: сохраняем выделение при перезагрузке таблицы: полный рескан после
    # удаления сбрасывал выделенную строку - несколько кадров подряд удалить нельзя
    $sel = -1
    try { $sel = $dg.SelectedIndex } catch { }
    $dg.ItemsSource = $script:KeyRows
    if ( $sel -ge 0 -and $script:KeyRows -ne $null -and $sel -lt $script:KeyRows.Count ) {
        try { $dg.SelectedIndex = $sel } catch { }
    }
    Update-SelectionButtons   # v5.11: серые кнопки (в т.ч. корзина) синхронно с таблицей
    $n = 0
    if ( $script:KeyRows -ne $null ) { $n = $script:KeyRows.Count }
    if ( $n -eq 0 ) {
        # v5.12: кадров нет - метка карты смысла не имеет, сбрасываем
        $script:KeyMap = ""
        $controls['TbMap'].Text = Get-MapText
        Update-MapPreview
        Set-Status "table: 0 keyframes - press F8 in game to add"
    } else {
        Set-Status "table: $n keyframes (ini synced)"
        Save-KeysBackup   # v5.17.17: автосейв при каждом изменении таблицы
    }
}

$script:KeysBackupFile = Join-Path $PSScriptRoot "keyframes-backup.hp2path"
function Save-KeysBackup {
    param([switch]$ForceEmpty)
    # v5.17.17: автосейв кадров в .hp2path (тот же формат, что экспорт/импорт):
    # переживает краш/закрытие игры и перезапуск панели. Кадры в панели живут,
    # ПОКА ПОЛЬЗОВАТЕЛЬ САМ их не удалит: пустая таблица файл НЕ перезаписывает
    # (явные очистки вызывают Save-KeysBackup -ForceEmpty сами)
    try {
        if ( $script:KeyRows.Count -eq 0 -and -not $ForceEmpty ) { return }
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        $lines = @("# map=$($script:KeyMap)  format: x,y,z,yaw,pitch,fov,speed,time")
        foreach ( $r in $script:KeyRows ) {
            $t = $r.Time
            if ( $t -eq $null -or $t -eq "" ) { $t = "-" }
            $lines += ($r.X.ToString($inv) + "," + $r.Y.ToString($inv) + "," + $r.Z.ToString($inv) + "," + $r.Yaw.ToString($inv) + "," + $r.Pitch.ToString($inv) + "," + $r.FOV.ToString($inv) + "," + $r.Speed.ToString($inv) + "," + $t)
        }
        [System.IO.File]::WriteAllLines($script:KeysBackupFile, $lines)
    } catch { }
}
function Restore-KeysBackup {
    # v5.17.17: восстановление кадров из автосейва - ЛОКАЛЬНО в панель (без отправки
    # в игру: её может не быть). Карта и времена тоже восстанавливаются; времена
    # складываются в KeyTimes, чтобы пережить будущие ре-дампы
    try {
        if ( -not (Test-Path $script:KeysBackupFile) ) { return }
        $allLines = [System.IO.File]::ReadAllLines($script:KeysBackupFile)
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        $rows = New-Object System.Collections.ArrayList
        $km = ""
        $times = @{}
        foreach ( $ln in $allLines ) {
            if ( $ln -eq $null ) { continue }
            $ln = $ln.TrimStart([char]0xFEFF)   # BOM первой строки не должен ломать "# map="
            if ( $ln.Trim() -eq "" ) { continue }
            if ( $ln.StartsWith("#") ) {
                $m = [regex]::Match($ln, '#\s*map=([A-Za-z0-9_]+)')
                if ( $m.Success ) { $km = $m.Groups[1].Value }
                continue
            }
            $p = $ln.Trim() -split ','
            if ( $p.Count -ge 7 -and $p[0] -match '^-?\d+(\.\d+)?$' ) {
                $r = New-Object KeyRow
                $r.Num  = $rows.Count
                $r.X    = [double]$p[0]
                $r.Y    = [double]$p[1]
                $r.Z    = [double]$p[2]
                $r.Yaw  = [int][double]$p[3]
                $r.Pitch= [int][double]$p[4]
                $r.FOV  = [double]$p[5]
                if ( $p[6] -match '^-?\d+(\.\d+)?$' ) { $r.Speed = [double]$p[6] } else { $r.Speed = 250 }
                $t = "-"
                if ( $p.Count -ge 8 -and $p[7] -match '^\d{2}:\d{2}:\d{2}$' ) { $t = $p[7] }
                $r.Time = $t
                [void]$rows.Add($r)
                if ( $t -ne "-" ) { $times[($r.X.ToString('F1',$inv) + ";" + $r.Y.ToString('F1',$inv) + ";" + $r.Z.ToString('F1',$inv))] = $t }
            }
        }
        if ( $rows.Count -eq 0 ) { return }
        $script:KeyRows = $rows
        if ( $km -ne "" ) { $script:KeyMap = $km }
        foreach ( $k in $times.Keys ) { if ( -not $script:KeyTimes.ContainsKey($k) ) { $script:KeyTimes[$k] = $times[$k] } }
        Refresh-Table
        $controls['TbMap'].Text = Get-MapText
        Update-MapPreview
        $hint = ""
        if ( $script:KeyMap -ne "" ) { $hint = " (" + $script:KeyMap + ")" }
        Set-Status ("restored $($rows.Count) frames from backup" + $hint)
    } catch { }
}

$script:SyncBusy = $false
$script:SyncForce = $false
$script:LastScanFast = $false

function Sync-FromLog([switch]$Force) {
    # v5.8: асинхронно - скан памяти в C#-потоке, UI и крутящийся ⟳ живут.
    # Завершение разбора - в Complete-SyncFromLog (вызывается из таймера).
    # v5.17.3: возвращает $true если синк запущен/выполнен, $false - отклонён (SyncBusy)
    if ( $script:SyncBusy ) { return $false }
    $lf = Find-LogFile
    if ( $lf -ne "" ) {
        try {
            $txtLF = [System.IO.File]::ReadAllText($lf)
            if ( $txtLF -ne "" ) { Complete-SyncFromLog $txtLF; return }
        } catch { }
    }
    $gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
    if ( $gp -eq $null ) {
        # v5.15: игра закрыта - сброс карты/плей-состояния и лочка кнопок
        if ( $script:CurrentMap -ne "" -or $script:Playing ) {
            $script:CurrentMap = ""
            if ( $script:Playing ) { Set-Playing $false }
            Update-SelectionButtons
        }
        Stop-Spin
        Set-Status "no keyframe source - is the game running?"
        return
    }
    $pairs = $null
    if ( -not $Force -and $script:ScanCache.Pid -eq $gp.Id -and $script:ScanCache.Regions.Count -ge 2 ) { $pairs = [long[]]$script:ScanCache.Regions }
    $script:LastScanFast = ($pairs -ne $null)
    $script:SyncBusy = $true
    $script:SyncForce = [bool]$Force
    Start-Spin
    [MemScanPanel]::StartAsync($gp.Id, $pairs)
    return $true
}

function Complete-SyncFromLog {
    param([string]$txtOverride = "")
    try {
        Complete-SyncFromLogInner
    } catch {
        # v5.17.3: исключение в синке убивало панель МОЛЧА (процесс исчезал без окна)
        try {
            $msg = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] Complete-Sync: " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message + "`r`n" + $_.Exception.StackTrace + "`r`n---`r`n"
            [System.IO.File]::AppendAllText((Join-Path $PSScriptRoot "crash.log"), $msg)
        } catch { }
    }
}

function Complete-SyncFromLogInner {
    param([string]$txtOverride = "")
    $script:SyncBusy = $false
    [MemScanPanel]::AsyncState = 0
    Stop-Spin
    $rows = New-Object System.Collections.ArrayList
    $txt = $txtOverride
    # v5.17.17: карта кадров ДО синка - синк может сбросить KeyMap (смена поколения),
    # а правило "не стирать кадры при пустом пути" сравнивает с ней
    $prevKeyMap = $script:KeyMap
    if ( $txtOverride -eq "" ) {
        $txt = [MemScanPanel]::AsyncResult
        [MemScanPanel]::AsyncResult = ""
    }
    $src = ""
    $gp = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
    if ( $gp -eq $null ) {
        if ( $script:CurrentMap -ne "" -or $script:Playing ) {
            $script:CurrentMap = ""
            if ( $script:Playing ) { Set-Playing $false }
            Update-SelectionButtons
        }
        Set-Status "no keyframe source - is the game running?"
        return
    }
    # v5.16.1: быстрый скан вернулся пустым = кэш областей устарел (буфер лога вырос
    # и ПЕРЕВЫДЕЛИЛСЯ - новые события ушли из кэшированных адресов). Инвалидировать
    # кэш и ВСЕГДА пересканировать полностью: иначе таблица зависает на старых данных.
    if ( $txt -eq "" -and $script:LastScanFast ) {
        $script:ScanCache.Regions = @()
        Sync-FromLog -Force
        return
    }
    if ( $txt -ne "" ) {
        if ( $txt.StartsWith("|REGS:") ) {
            # полный скан: первая строка = |REGS:n|addr|size|... - сохраняем области в кэш
            $src = "memory"
            $nl = $txt.IndexOf("`n")
            if ( $nl -gt 0 ) {
                $hdr = $txt.Substring(0, $nl)
                $txt = $txt.Substring($nl + 1)
                if ( $hdr.StartsWith("|REGS:") ) {
                    $parts = $hdr.TrimStart('|').Split('|')
                    if ( $parts.Length -ge 3 ) {
                        $regs = @()
                        foreach ( $pv in ($parts | Select-Object -Skip 1) ) { $regs += [long]$pv }
                        $script:ScanCache.Regions = $regs
                    }
                }
            }
            if ( $txt -notmatch 'PATHEV:' ) { $txt = ""; $src = "" }
        } else {
            # быстрый путь (кэш областей): принимаем только при НОВЫХ событиях.
            # v5.16.2: с v5.16 события несут поколение - PATHEV:<gen>:<seq>| (старый
            # регэкс PATHEV:(\d+)\| не совпадал НИКОГДА, все быстрые синхронизации
            # отбрасывались как "нет новых событий" - DEL/CLEAR не доходили до таблицы)
            $src = "memory"
            $newMax = 0
            $hadEv = $false
            foreach ( $mm in [regex]::Matches($txt, 'PATHEV:(\d+):(\d+)\|') ) {
                $hadEv = $true
                $v = [long]$mm.Groups[2].Value
                if ( $v -gt $newMax ) { $newMax = $v }
            }
            if ( -not $hadEv ) {
                # fallback: буфер без поколений (старый формат игры)
                foreach ( $mm in [regex]::Matches($txt, 'PATHEV:(\d+)\|') ) {
                    $hadEv = $true
                    $v = [long]$mm.Groups[1].Value
                    if ( $v -gt $newMax ) { $newMax = $v }
                }
            }
            if ( -not $hadEv ) {
                # в кэшированных областях нет событий вовсе - буфер переехал,
                # нужен полный скан (Force внутри не зациклится: там LastScanFast=false)
                $script:ScanCache.Regions = @()
                Sync-FromLog -Force
                return
            }
            if ( $newMax -le $script:ScanCache.LastSeq ) { $txt = ""; $src = "" }
        }
    }
    if ( $txt -ne "" ) {
        # v4.5: только PATHEV:<seq>|TYPE|data - события с монотонным номером.
        # Старые PATHADD-строки игнорируются: в памяти живут КОПИИ буфера лога,
        # проигрывание сырых событий даёт мусор (очистка отменяется старыми кадрами).
        # v5.17.3: data только из безопасного charset - в хвосты частичных копий буфера
        # попадает мусор кучи ("98938.00䏆▗"), каст в Double ронял ВЕСЬ синк
        $rxEv = [regex]'PATHEV:(\d+):(\d+)\|([A-Z]+)\|?([0-9A-Za-z.,:_\-]*)'
        $ev = @()
        foreach ( $m in $rxEv.Matches($txt) ) {
            $ev += New-Object PSObject -Property @{Gen=[long]$m.Groups[1].Value; Seq=[long]$m.Groups[2].Value; T=$m.Groups[3].Value; D=$m.Groups[4].Value}
        }
        # v5.16: ПОКОЛЕНИЯ. Уровень сменился - движок сбрасывает seq в 1 и инкрементирует
        # поколение (в самом событии). Играем только события текущего поколения:
        # старый уровень больше никогда не вмешается, копии буфера отфильтруются по Gen.
        $maxGen = 0
        foreach ( $e0 in $ev ) { if ( $e0.Gen -gt $maxGen ) { $maxGen = $e0.Gen } }
        $ev = @($ev | Where-Object { $_.Gen -eq $maxGen })
        $genSwitch = ($maxGen -ne $script:LastGen)
        if ( $genSwitch ) {
            $script:LastGen = $maxGen
            $script:KeyMap = ""
            $gp2 = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
            if ( $gp2 -ne $null ) {
                $pfx2 = [string]$gp2.Id + ":"
                foreach ( $k in (@($script:SeenSeqs.Keys) ) ) {
                    if ( $k.StartsWith($pfx2) ) { $script:SeenSeqs.Remove($k) }
                }
                foreach ( $k in (@($script:KeyTimes.Keys) ) ) {
                    if ( $k.StartsWith($pfx2) ) { $script:KeyTimes.Remove($k) }
                }
            }
        }
        $ev = @($ev | Sort-Object -Property Seq -Unique)
        # LastSeq: смена уровня = новый отсчёт seq; смена процесса = новая сессия
        $mx = 0
        foreach ( $e2 in $ev ) { if ( $e2.Seq -gt $mx ) { $mx = $e2.Seq } }
        if ( $script:ScanCache.Pid -ne $gp.Id ) {
            $script:ScanCache.Pid = $gp.Id
            $script:ScanCache.LastSeq = $mx
        } elseif ( $genSwitch ) {
            $script:ScanCache.LastSeq = $mx
        } elseif ( $mx -gt $script:ScanCache.LastSeq ) {
            $script:ScanCache.LastSeq = $mx
        }
        $isNum = '^-?\d+(\.\d+)?$'
        # v5.17: DUMP-блок (PathDumpKeys) = снапшот истинного состояния пути от игры.
        # Лог-буфер в памяти КОЛЬЦЕВОЙ: старые ADD-события вытесняются новыми строками
        # лога, реплей "всей истории" даёт фантомов и неверные индексы при DEL.
        $inDump = $false
        $dumpRows = New-Object System.Collections.ArrayList
        foreach ( $e in $ev ) {
            switch ( $e.T ) {
                'CLEAR' { $rows.Clear() | Out-Null; $script:KeyMap = "" }
                'DEL'   {
                    $i = [int]$e.D
                    if ( $i -ge 0 -and $i -lt $rows.Count ) { $rows.RemoveAt($i) }
                    if ( $rows.Count -eq 0 ) { $script:KeyMap = "" }
                }
                'DUMPBEGIN' {
                    $inDump = $true
                    $dumpRows = New-Object System.Collections.ArrayList
                }
                'DUMPMAP' {
                    # v5.17.1: имя карты в дампе - панель определяет уровень даже без -log
                    if ( $e.D -ne "" ) { $script:CurrentMap = $e.D }
                }
                'KEY'   {
                    # KEY|i,x,y,z,yaw,pitch,fov,spd - строка снапшота пути (только внутри DUMP)
                    if ( $inDump ) {
                        $p = $e.D -split ','
                        if ( $p.Count -ge 8 -and $p[1] -match $isNum -and $p[2] -match $isNum -and $p[3] -match $isNum -and $p[4] -match $isNum -and $p[5] -match $isNum -and $p[6] -match $isNum -and $p[7] -match $isNum ) {
                            $r = New-Object KeyRow
                            $r.Time  = "-"
                            $r.Seq   = $e.Seq
                            $r.X     = [double]$p[1]
                            $r.Y     = [double]$p[2]
                            $r.Z     = [double]$p[3]
                            $r.Yaw   = [int][double]$p[4]
                            $r.Pitch = [int][double]$p[5]
                            $r.FOV   = [double]$p[6]
                            if ( $p[7] -match $isNum ) { $r.Speed = [double]$p[7] } else { $r.Speed = 250 }
                            [void]$dumpRows.Add($r)
                            if ( $script:CurrentMap -ne "" ) { $script:KeyMap = $script:CurrentMap }
                        }
                    }
                }
                'DUMPEND' {
                    if ( $inDump ) {
                        # время постановки кадров переносим со старых строк по координатам:
                        # у дампных строк новые seq, KeyTimes на них не указывает
                        $byCoord = @{}
                        foreach ( $old in $rows ) {
                            $ck = ('{0:F2};{1:F2};{2:F2}' -f $old.X, $old.Y, $old.Z)
                            if ( -not $byCoord.ContainsKey($ck) ) { $byCoord[$ck] = $old.Time }
                        }
                        foreach ( $nr in $dumpRows ) {
                            $ck = ('{0:F2};{1:F2};{2:F2}' -f $nr.X, $nr.Y, $nr.Z)
                            if ( $byCoord.ContainsKey($ck) -and $byCoord[$ck] -ne "-" ) { $nr.Time = $byCoord[$ck] }
                        }
                        $rows = $dumpRows
                        $inDump = $false
                    }
                }
                'MAP'   {
                    # v5.6: имя карты идёт в том же PATHEV-потоке (событие от BaseCam.PathLogMap)
                    if ( $e.D -ne "" ) { $script:CurrentMap = $e.D }
                }
                'PLAYEND' {
                    # v5.7: проигрывание закончилось само - гасим красный Stop
                    if ( $script:Playing ) { Set-Playing $false }
                }
                'ADD'   {
                    $p = $e.D -split ','
                    # v5.17.3: валидация ВСЕХ числовых полей (мусорный хвост = пропуск события)
                    if ( $p.Count -ge 6 -and $p[0] -match $isNum -and $p[1] -match $isNum -and $p[2] -match $isNum -and $p[3] -match $isNum -and $p[4] -match $isNum -and $p[5] -match $isNum ) {
                        $r = New-Object KeyRow
                        $r.Num   = $rows.Count
                        $r.Time  = "-"
                        $r.Seq   = $e.Seq
                        $r.X     = [double]$p[0]
                        $r.Y     = [double]$p[1]
                        $r.Z     = [double]$p[2]
                        $r.Yaw   = [int][double]$p[3]
                        $r.Pitch = [int][double]$p[4]
                        $r.FOV   = [double]$p[5]
                        if ( $p.Count -ge 7 -and $p[6] -match $isNum ) { $r.Speed = [double]$p[6] } else { $r.Speed = 250 }
                        [void]$rows.Add($r)
                        if ( $script:CurrentMap -ne "" ) { $script:KeyMap = $script:CurrentMap }
                    }
                }
                'SPEED' {
                    $pp = $e.D -split ','
                    $i = [int]$pp[0]
                    if ( $pp.Count -ge 2 -and $i -ge 0 -and $i -lt $rows.Count -and $pp[1] -match $isNum ) { $rows[$i].Speed = [double]$pp[1] }
                }
                'INS'   {
                    # вставка кадра по индексу: INS|i,x,y,z,yaw,pitch,fov,spd
                    $p = $e.D -split ','
                    if ( $p.Count -ge 8 -and $p[1] -match $isNum -and $p[2] -match $isNum -and $p[3] -match $isNum ) {
                        $i = [int]$p[0]
                        if ( $i -lt 0 -or $i -gt $rows.Count ) { $i = $rows.Count }
                        $r = New-Object KeyRow
                        $r.Time  = "-"
                        $r.Seq   = $e.Seq
                        $r.X     = [double]$p[1]
                        $r.Y     = [double]$p[2]
                        $r.Z     = [double]$p[3]
                        $r.Yaw   = [int][double]$p[4]
                        $r.Pitch = [int][double]$p[5]
                        $r.FOV   = [double]$p[6]
                        if ( $p[7] -match $isNum ) { $r.Speed = [double]$p[7] } else { $r.Speed = 250 }
                        $rows.Insert($i, $r)
                        if ( $script:CurrentMap -ne "" ) { $script:KeyMap = $script:CurrentMap }
                    }
                }
                'KEYFOV' {
                    $pp = $e.D -split ','
                    $i = [int]$pp[0]
                    if ( $pp.Count -ge 2 -and $i -ge 0 -and $i -lt $rows.Count -and $pp[1] -match $isNum ) { $rows[$i].FOV = [double]$pp[1] }
                }
                'ALLFOV' {
                    if ( $e.D -match $isNum ) { foreach ( $r in $rows ) { $r.FOV = [double]$e.D } }
                }
            }
        }
        for ( $k = 0; $k -lt $rows.Count; $k++ ) { $rows[$k].Num = $k }

        # время постановки кадра: штампуем только НОВЫЕ координаты (после F8/вставки);
        # v5.17.9: ключ = координаты БЕЗ pid (времена переживают перезапуск игры);
        # карта времён сохраняется в файл и переживает перезапуск панели
        $now = Get-Date -Format HH:mm:ss
        $stampChanged = $false
        $ri = 0
        foreach ( $r in $rows ) {
            # v5.17.3: время привязано к КООРДИНАТАМ кадра, а не к seq: дамп даёт строкам
            # новые seq при каждом запросе, и старая привязка перештамповывала ВСЕ строки
            # v5.17.9: БЕЗ pid игры - времена переживают перезапуск игры (pid меняется,
            # координаты кадра на карте - нет)
            $inv = [System.Globalization.CultureInfo]::InvariantCulture
            $sk = $r.X.ToString('F1', $inv) + ";" + $r.Y.ToString('F1', $inv) + ";" + $r.Z.ToString('F1', $inv)
            if ( -not $script:SeenSeqs.ContainsKey($sk) ) {
                # v5.17.11: штампуем ТОЛЬКО если у координат ещё НЕТ сохранённого времени.
                # SeenSeqs живёт в памяти панели и пуст после её перезапуска; если стартовый
                # дамп поймал не все кадры, без этой проверки штемпель "сейчас" ПЕРЕЗАПИСЫВАЛ
                # сохранённое в key-times.txt время старого кадра (у 2840.9 сломалось
                # 13:42:40 -> 22:22:26 при вставке соседнего кадра)
                if ( -not $script:KeyTimes.ContainsKey($sk) ) {
                    # при импорте время берём из файла (по порядку строк), а не "сейчас"
                    if ( $script:StampNextSync -and $script:PendingImportTimes -ne $null -and $ri -lt $script:PendingImportTimes.Count -and $script:PendingImportTimes[$ri] -ne "" ) {
                        $script:KeyTimes[$sk] = $script:PendingImportTimes[$ri]
                        $stampChanged = $true
                    } elseif ( $script:StampNextSync ) {
                        $script:KeyTimes[$sk] = $now
                        $stampChanged = $true
                    }
                }
                $script:SeenSeqs[$sk] = $true
            }
            if ( $script:KeyTimes.ContainsKey($sk) ) { $r.Time = $script:KeyTimes[$sk] }
            $ri++
        }
        $script:StampNextSync = $false
        $script:PendingImportTimes = $null
        if ( $stampChanged ) {
            $lines = @()
            foreach ( $k in $script:KeyTimes.Keys ) { $lines += "$k|$($script:KeyTimes[$k])" }
            try { [System.IO.File]::WriteAllLines($script:KeyTimesFile, $lines) } catch { }
        }

        # текущая карта - из событий LoadMap в логе
        $lm = [regex]::Match($txt, 'LoadMap: ([A-Za-z0-9_]+)')
        if ( $lm.Success ) { $script:CurrentMap = $lm.Groups[1].Value }
        $controls['TbMap'].Text = Get-MapText
        Update-MapPreview

        # v5.17.17: путь в игре ПУСТ (дамп 0 кадров), а в панели есть кадры той же
        # карты и пользователь не давал явную очистку - игра перезапустилась после
        # краша/закрытия: кадры СОХРАНЯЕМ (требование #backup: в панели всё живёт,
        # пока пользователь сам не удалит). Явная очистка - PathClear из панели с
        # флагом UserClearPending (гасится после этого синка). ДРУГАЯ карта - старые
        # кадры не отображаем (goto/вставка считаются по пути игры), бэкап-файл
        # с ними сохранён, восстановление через Import from file
        if ( $rows.Count -eq 0 -and $script:KeyRows.Count -gt 0 -and -not $script:UserClearPending ) {
            if ( $prevKeyMap -ne "" -and $prevKeyMap -eq $script:CurrentMap ) {
                $rows = $script:KeyRows
                $script:KeyMap = $prevKeyMap
            }
        }
        $wasClear = $script:UserClearPending
        $script:UserClearPending = $false
        $script:KeyRows = $rows
        Refresh-Table
        Update-SelectionButtons
        if ( $rows.Count -eq 0 -and $wasClear ) {
            # явная очистка в игре - бэкап тоже пустеет
            Save-KeysBackup -ForceEmpty
        }
        Set-Status "table: $($rows.Count) keys (memory scan OK)"
    }
}

function Find-LogFile {
    $cut = (Get-Date).AddHours(-12)
    $best = $null
    Get-ChildItem -Path "F:\Harry Potter and the Chamber of Secrets\system" -Filter "*.log" -ErrorAction SilentlyContinue | ForEach-Object {
        if ( $_.Name -match '^(WS_FTP|uninstal)' ) { return }
        if ( $_.LastWriteTime -gt $cut ) {
            if ( $best -eq $null -or $_.LastWriteTime -gt $best.LastWriteTime ) { $best = $_ }
        }
    }
    if ( $best -ne $null ) { return $best.FullName }
    return ""
}

function Sync-AfterCommand([string]$status) {
    # событие пишется в лог сразу после Enter - короткая пауза на всякий случай.
    # v5.16.2: синхронизация ПОСЛЕ команды всегда полная: новое событие живёт в
    # хвосте буфера, которого нет в кэшированных областях быстрого скана.
    # v5.17: перед синком запрашиваем у игры СНАПШОТ пути (PathDumpKeys): таблица
    # строится из дампа, а не из уцелевших обрывков кольцевого лог-буфера.
    # v5.17.3: если синк отклонён (SyncBusy от предыдущего) - повторяем до 6 раз
    Wait-Pump 120
    Send-GameCommands @("PathDumpKeys") | Out-Null
    Wait-Pump 120
    $tries = 0
    while ( -not (Sync-FromLog -Force) -and $tries -lt 6 ) {
        Wait-Pump 600
        $tries++
    }
    if ( $status -ne "" ) { Set-Status $status }
}


function Send-PathSaveAndSync([string]$prefix) {
    Sync-AfterCommand $prefix
}

# ---------- UI ----------

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="HP2 Machinima Panel" Width="800" Height="640" MinWidth="800" MinHeight="550"
        Topmost="True" Background="{DynamicResource BgBrush}" WindowStyle="None" AllowsTransparency="True"
        ResizeMode="CanResize" WindowStartupLocation="Manual" Left="20" Top="60"
        FontFamily="Segoe UI">
  <WindowChrome.WindowChrome>
    <WindowChrome CaptionHeight="0" ResizeBorderThickness="10" GlassFrameThickness="0" CornerRadius="0" UseAeroCaptionButtons="False"/>
  </WindowChrome.WindowChrome>
  <Window.Resources>
    <SolidColorBrush x:Key="BgBrush" Color="#F21E1E2E"/>
    <SolidColorBrush x:Key="PanelBrush" Color="#313244"/>
    <SolidColorBrush x:Key="TableBgBrush" Color="#181825"/>
    <SolidColorBrush x:Key="AltRowBrush" Color="#313244"/>
    <SolidColorBrush x:Key="TextBrush" Color="#CDD6F4"/>
    <SolidColorBrush x:Key="MutedBrush" Color="#A6ADC8"/>
    <SolidColorBrush x:Key="LineBrush" Color="#585B70"/>
    <SolidColorBrush x:Key="StatusBrush" Color="#94E2D5"/>
    <SolidColorBrush x:Key="DotBrush" Color="#A6E3A1"/>
    <SolidColorBrush x:Key="SyncBrush" Color="#FF1F3D2E"/>
    <SolidColorBrush x:Key="DirtyBrush" Color="#FF3A3F4D"/>
    <SolidColorBrush x:Key="NavBrush" Color="#FF89DCEB"/>
    <SolidColorBrush x:Key="HdrBrush" Color="#FF313244"/>
    <SolidColorBrush x:Key="SelBrush" Color="#FF3D4A66"/>
    <SolidColorBrush x:Key="StatusWarnBrush" Color="#FFFAB387"/>
    <SolidColorBrush x:Key="StatusErrBrush" Color="#FFE5484D"/>
    <BooleanToVisibilityConverter x:Key="BoolToVis"/>

    <Style TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="TplBorder" CornerRadius="8" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Opacity" Value="0.85"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Opacity" Value="0.65"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="TplBorder" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border CornerRadius="6" Background="{TemplateBinding Background}"
                    BorderBrush="{DynamicResource LineBrush}" BorderThickness="1">
              <ScrollViewer x:Name="PART_ContentHost" Margin="4,2" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="{x:Type DataGridColumnHeader}">
      <Setter Property="Background" Value="{DynamicResource HdrBrush}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="BorderBrush" Value="{DynamicResource LineBrush}"/>
      <Setter Property="BorderThickness" Value="0,0,1,1"/>
    </Style>
    <!-- v5.12.3: ContextMenu без серой подложки - просто белый скруглённый борд с тенью -->
    <Style TargetType="ContextMenu">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ContextMenu">
            <Border x:Name="CmB" Background="White" BorderBrush="#FFB8BFCC" BorderThickness="1"
                    CornerRadius="6" Padding="4">
              <ItemsPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="HasDropShadow" Value="True">
                <Setter TargetName="CmB" Property="Effect">
                  <Setter.Value>
                    <DropShadowEffect BlurRadius="14" ShadowDepth="2" Opacity="0.35"/>
                  </Setter.Value>
                </Setter>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- v5.13: спокойная подсветка выбранной строки вместо дефолтного ярко-синего -->
    <Style TargetType="DataGridCell" BasedOn="{StaticResource {x:Type DataGridCell}}">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="ClipToBounds" Value="False"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{DynamicResource SelBrush}"/>
          <Setter Property="Foreground" Value="{DynamicResource TextBrush}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="DataGridRow" BasedOn="{StaticResource {x:Type DataGridRow}}">
      <Setter Property="ClipToBounds" Value="False"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{DynamicResource SelBrush}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <!-- v5.17.11: пилюля "+" обязана ВЫЛЕЗАТЬ за верхнюю границу строки (ровно на стык
         с предыдущей строкой) - запрещаем обрезку по всей вертикальной цепочке -->
    <Style TargetType="DataGridCellsPresenter" BasedOn="{StaticResource {x:Type DataGridCellsPresenter}}">
      <Setter Property="ClipToBounds" Value="False"/>
    </Style>
  </Window.Resources>
  <!-- v5.17.11.2: AdornerDecorator обязателен - в окне из XamlReader БЕЗ него
       GetAdornerLayer возвращает null и адорнер верхней половины плюса не живёт -->
  <AdornerDecorator>
  <Grid Name="RootGrid" Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- header: title + hotkey pills + close -->
    <Grid Name="HdrGrid" Grid.Row="0" Background="Transparent" Margin="0,0,0,6">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
        <Image Name="ImgOwl" Width="26" Height="26" Margin="2,0,8,0"/>
        <TextBlock Text="HP2 Machinima Panel" Foreground="{DynamicResource TextBrush}" FontSize="16" FontWeight="Bold" VerticalAlignment="Center"/>
      </StackPanel>
      <UniformGrid Grid.Column="1" Columns="4" VerticalAlignment="Center" Margin="0,0,10,0">
        <Border CornerRadius="6" Background="{DynamicResource PanelBrush}" Margin="2,0" Padding="8,4">
          <TextBlock Foreground="{DynamicResource TextBrush}" FontSize="12"><Run FontWeight="Bold" Text="F8"/> <Run Name="TxHkFrame" Foreground="{DynamicResource MutedBrush}" Text="  frame"/></TextBlock>
        </Border>
        <Border CornerRadius="6" Background="{DynamicResource PanelBrush}" Margin="2,0" Padding="8,4">
          <TextBlock Foreground="{DynamicResource TextBrush}" FontSize="12"><Run FontWeight="Bold" Text="F9"/> <Run Name="TxHkPlay" Foreground="{DynamicResource MutedBrush}" Text="  play"/></TextBlock>
        </Border>
        <Border CornerRadius="6" Background="{DynamicResource PanelBrush}" Margin="2,0" Padding="8,4">
          <TextBlock Foreground="{DynamicResource TextBrush}" FontSize="12"><Run FontWeight="Bold" Text="F10"/> <Run Name="TxHkStop" Foreground="{DynamicResource MutedBrush}" Text="  stop"/></TextBlock>
        </Border>
        <Border CornerRadius="6" Background="{DynamicResource PanelBrush}" Margin="2,0" Padding="8,4">
          <TextBlock Foreground="{DynamicResource TextBrush}" FontSize="12"><Run FontWeight="Bold" Text="F11"/> <Run Name="TxHkClear" Foreground="{DynamicResource MutedBrush}" Text="  clear"/></TextBlock>
        </Border>
      </UniformGrid>
      <Button Name="BtnLang" Grid.Column="2" Width="34" Height="30" Margin="0,0,12,0" BorderThickness="0"
              Background="{DynamicResource PanelBrush}" Cursor="Hand" ToolTip="{DynamicResource TipLang}">
        <Grid>
          <Border Name="FlagEN" CornerRadius="3" Width="22" Height="15" ClipToBounds="True">
            <Canvas Width="22" Height="15">
              <Rectangle Width="22" Height="15" Fill="#012169"/>
              <Line X1="0" Y1="0" X2="22" Y2="15" Stroke="White" StrokeThickness="3.6"/>
              <Line X1="22" Y1="0" X2="0" Y2="15" Stroke="White" StrokeThickness="3.6"/>
              <Line X1="0" Y1="0" X2="22" Y2="15" Stroke="#C8102E" StrokeThickness="1.4"/>
              <Line X1="22" Y1="0" X2="0" Y2="15" Stroke="#C8102E" StrokeThickness="1.4"/>
              <Rectangle Width="22" Height="5.4" Canvas.Top="4.8" Fill="White"/>
              <Rectangle Width="5.4" Height="15" Canvas.Left="8.3" Fill="White"/>
              <Rectangle Width="22" Height="3.2" Canvas.Top="5.9" Fill="#C8102E"/>
              <Rectangle Width="3.2" Height="15" Canvas.Left="9.4" Fill="#C8102E"/>
            </Canvas>
          </Border>
          <Border Name="FlagRU" CornerRadius="3" Width="22" Height="15" ClipToBounds="True" Visibility="Collapsed">
            <Canvas Width="22" Height="15">
              <Rectangle Width="22" Height="5" Fill="White" Stroke="#B0B7C3" StrokeThickness="0.6"/>
              <Rectangle Canvas.Top="5" Width="22" Height="5" Fill="#0039A6"/>
              <Rectangle Canvas.Top="10" Width="22" Height="5" Fill="#D52B1E"/>
            </Canvas>
          </Border>
        </Grid>
        <Button.ContextMenu>
          <ContextMenu>
            <ContextMenu.Resources>
              <!-- v5.12.2: без серой колонки иконок - пункты перешаблонены, флаг уже в Header -->
              <Style TargetType="MenuItem">
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="MenuItem">
                      <Border x:Name="ItmB" Background="Transparent" Padding="12,6">
                        <ContentPresenter ContentSource="Header" VerticalAlignment="Center"/>
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsHighlighted" Value="True">
                          <Setter TargetName="ItmB" Property="Background" Value="#FFE4EEFC"/>
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </ContextMenu.Resources>
            <MenuItem Tag="en">
              <MenuItem.Header>
                <StackPanel Orientation="Horizontal">
                  <Viewbox Width="19" Height="13" VerticalAlignment="Center" Margin="0,0,9,0">
                    <Border CornerRadius="2" Width="22" Height="15" ClipToBounds="True">
                      <Canvas Width="22" Height="15">
                        <Rectangle Width="22" Height="15" Fill="#012169"/>
                        <Line X1="0" Y1="0" X2="22" Y2="15" Stroke="White" StrokeThickness="3.6"/>
                        <Line X1="22" Y1="0" X2="0" Y2="15" Stroke="White" StrokeThickness="3.6"/>
                        <Line X1="0" Y1="0" X2="22" Y2="15" Stroke="#C8102E" StrokeThickness="1.4"/>
                        <Line X1="22" Y1="0" X2="0" Y2="15" Stroke="#C8102E" StrokeThickness="1.4"/>
                        <Rectangle Width="22" Height="5.4" Canvas.Top="4.8" Fill="White"/>
                        <Rectangle Width="5.4" Height="15" Canvas.Left="8.3" Fill="White"/>
                        <Rectangle Width="22" Height="3.2" Canvas.Top="5.9" Fill="#C8102E"/>
                        <Rectangle Width="3.2" Height="15" Canvas.Left="9.4" Fill="#C8102E"/>
                      </Canvas>
                    </Border>
                  </Viewbox>
                  <TextBlock Text="English" VerticalAlignment="Center"/>
                </StackPanel>
              </MenuItem.Header>
            </MenuItem>
            <MenuItem Tag="ru">
              <MenuItem.Header>
                <StackPanel Orientation="Horizontal">
                  <Viewbox Width="19" Height="13" VerticalAlignment="Center" Margin="0,0,9,0">
                    <Border CornerRadius="2" Width="22" Height="15" ClipToBounds="True">
                      <Canvas Width="22" Height="15">
                        <Rectangle Width="22" Height="5" Fill="White" Stroke="#B0B7C3" StrokeThickness="0.6"/>
                        <Rectangle Canvas.Top="5" Width="22" Height="5" Fill="#0039A6"/>
                        <Rectangle Canvas.Top="10" Width="22" Height="5" Fill="#D52B1E"/>
                      </Canvas>
                    </Border>
                  </Viewbox>
                  <TextBlock Text="Русский" VerticalAlignment="Center"/>
                </StackPanel>
              </MenuItem.Header>
            </MenuItem>
          </ContextMenu>
        </Button.ContextMenu>
      </Button>
      <Button Name="BtnTheme" Grid.Column="3" Content="☀" Width="34" Height="30" FontSize="14" BorderThickness="0"
              Margin="0,0,12,0" Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}"/>
      <Button Name="BtnHide" Grid.Column="4" Content="_" Width="34" Height="30" FontWeight="Bold" FontSize="16" BorderThickness="0"
              Margin="0,0,10,0" Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}" Padding="0,2,0,0"
              ToolTip="{DynamicResource TipHide}"/>
      <Button Name="BtnClose" Grid.Column="5" Content="✕" Width="34" Height="30" FontWeight="Bold" FontSize="14"
              Background="#EB6F8E" Foreground="White" BorderThickness="0"/>
    </Grid>

    <!-- v5.17.12: таблица растянута на весь остаток окна; правая колонка - управление
         (Hide HUD / ADD KEYFRAME / PLAY by TIME / Play / Stop) + MAP + экспорт -->
    <Grid Grid.Row="1" Margin="3,0,3,6">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="5*"/>
        <ColumnDefinition Width="2*"/>
      </Grid.ColumnDefinitions>
      <Grid Grid.Column="0" Margin="0,0,6,0">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Name="TxFramesLabel" Text="▦ KEYFRAMES (click a cell to edit; double-click = select text; eye = preview)" Foreground="{DynamicResource MutedBrush}" FontSize="11" Margin="5,0,0,3"/>
        <Grid Grid.Row="1">
      <DataGrid Name="DgKeys" Margin="0,3,0,0" Background="{DynamicResource TableBgBrush}" Foreground="{DynamicResource TextBrush}" BorderBrush="{DynamicResource LineBrush}"
              FontFamily="Consolas" FontSize="11" AutoGenerateColumns="False" CanUserAddRows="False"
              CanUserDeleteRows="False" CanUserSortColumns="False" SelectionMode="Single"
              HeadersVisibility="Column" GridLinesVisibility="Horizontal" RowBackground="{DynamicResource TableBgBrush}"
              AlternatingRowBackground="{DynamicResource AltRowBrush}" RowHeight="26"
              EnableRowVirtualization="False">
      <DataGrid.Columns>
        <DataGridTemplateColumn Header="#" Width="36">
          <DataGridTemplateColumn.CellTemplate>
            <DataTemplate>
              <Grid Background="Transparent">
                <!-- v5.17.9: цифра в ВЕРХНЕЙ части ячейки - на уровне текста остальных
                     колонок (DataGridTextColumn рисует текст выше геометрического центра);
                     плюсик справа от неё, поэтому колонка расширена 30 -> 40 -->
                <TextBlock Text="{Binding Num}" Margin="4,2,0,0" VerticalAlignment="Top" HorizontalAlignment="Left" FontFamily="Consolas"/>
                <!-- v5.17.11: зелёный "+" РОВНО НА СТЫКЕ этой и предыдущей строки:
                     центр кнопки совпадает с верхней границей ячейки (верхняя половина
                     в предыдущей строке, нижняя - в этой). Пилюля принадлежит СТРОКЕ k,
                     но рисуется поверх строки k-1: StackPanel рисует поздние строки
                     поверх ранних, а ClipToBounds=False снял обрезку по цепочке
                     DataGridCell/CellsPresenter/Row. Вниз так нельзя: строка k+1
                     рисуется ПОЗЖЕ и закрашивает выступ нижней половины.
                     Справа от цифры, чтобы не перекрывать её.
                     Клик = вставить ТЕКУЩИЙ кадр камеры на позицию Num (между k-1 и k);
                     у строки 0 это вставка в начало пути. delHandler шлёт PathInsertAt Num -->
                <!-- видны, пока курсор где-либо над таблицей (IsMouseOver грида) -->
                <Button x:Name="PillBtn" Content="+" Tag="{Binding Num}" FontSize="10" FontWeight="Bold"
                        Width="16" Height="12" Padding="0" BorderThickness="0" Cursor="Hand"
                        Background="#E02F9E44" Foreground="White" HorizontalAlignment="Left" VerticalAlignment="Top"
                        Margin="22,-6,0,0" ToolTip="{DynamicResource TipInsertRow}"
                        Visibility="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGrid}, Converter={StaticResource BoolToVis}}"/>
                <!-- у строки 0 глиф "+" рисует АДОРНЕР (верхняя половина пилюли лежит НА
                     шапке, кнопка клипуется вьюпортом) - глушим глиф кнопки, Content="+"
                     нужен роутеру кликов -->
              </Grid>
              <DataTemplate.Triggers>
                <DataTrigger Binding="{Binding Num}" Value="0">
                  <Setter TargetName="PillBtn" Property="Foreground" Value="Transparent"/>
                </DataTrigger>
              </DataTemplate.Triggers>
            </DataTemplate>
          </DataGridTemplateColumn.CellTemplate>
        </DataGridTemplateColumn>
        <DataGridTextColumn Header="Time" Width="56" Binding="{Binding Time}"/>
        <DataGridTextColumn Header="X" Width="56" Binding="{Binding X, StringFormat=F1}"/>
        <DataGridTextColumn Header="Y" Width="56" Binding="{Binding Y, StringFormat=F1}"/>
        <DataGridTextColumn Header="Z" Width="56" Binding="{Binding Z, StringFormat=F1}"/>
        <DataGridTextColumn Header="Yaw" Width="48" Binding="{Binding Yaw}"/>
        <DataGridTextColumn Header="Pitch" Width="44" Binding="{Binding Pitch}"/>
        <DataGridTextColumn Header="FOV" Width="36" Binding="{Binding FOV}"/>
        <DataGridTextColumn Header="Speed" Width="*" Binding="{Binding Speed}" IsReadOnly="False"/>
        <DataGridTemplateColumn Width="44">
          <DataGridTemplateColumn.CellTemplate>
            <DataTemplate>
              <!-- v5.17.18 (#2): галочка/крестик строки - подтвердить/отменить правки
                   значений строки (появляются при наведении, как корзина и глаз).
                   Глифы MDL2: E73E CheckMark / E711 Cancel; роутер delHandler по [char] -->
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Center"
                          Visibility="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGridRow}, Converter={StaticResource BoolToVis}}">
                <Button Content="&#xE73E;" FontFamily="Segoe MDL2 Assets" Tag="{Binding Num}" FontSize="13" Cursor="Hand" BorderThickness="0"
                        Background="Transparent" Foreground="#2F9E44" Padding="2,0" Margin="0,0,2,0"
                        ToolTip="{DynamicResource TipAcceptRow}"
                        Visibility="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGridRow}, Converter={StaticResource BoolToVis}}"/>
                <Button Content="&#xE711;" FontFamily="Segoe MDL2 Assets" Tag="{Binding Num}" FontSize="13" Cursor="Hand" BorderThickness="0"
                        Background="Transparent" Foreground="#E5484D" Padding="2,0"
                        ToolTip="{DynamicResource TipCancelRow}"
                        Visibility="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGridRow}, Converter={StaticResource BoolToVis}}"/>
              </StackPanel>
            </DataTemplate>
          </DataGridTemplateColumn.CellTemplate>
        </DataGridTemplateColumn>
        <DataGridTemplateColumn Width="26">
          <DataGridTemplateColumn.CellTemplate>
            <DataTemplate>
              <!-- v5.17.11.7: значок-глаз "посмотреть как выглядит кадр" (goto, вместо
                   метки; 📍 убрана, а 👁 U+1F441 в этих кнопках НЕ РИСУЕТСЯ - поэтому
                   глиф RedEye U+E7B3 из Segoe MDL2 Assets, он рендерится reliably).
                   Появляется при наведении на строку, слева от корзины. Клик = PathGoto Num -->
              <Button Content="&#xE7B3;" FontFamily="Segoe MDL2 Assets" Tag="{Binding Num}" FontSize="14" Cursor="Hand" BorderThickness="0"
                      Background="Transparent" Foreground="#2196F3" HorizontalAlignment="Center" Padding="2,0"
                      ToolTip="{DynamicResource TipGotoRow}"
                      Visibility="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGridRow}, Converter={StaticResource BoolToVis}}"/>
            </DataTemplate>
          </DataGridTemplateColumn.CellTemplate>
        </DataGridTemplateColumn>
        <DataGridTemplateColumn Width="30">
          <DataGridTemplateColumn.CellTemplate>
            <DataTemplate>
              <Button Content="🗑" Tag="{Binding Num}" FontSize="13" Cursor="Hand" BorderThickness="0"
                      Background="Transparent" Foreground="#EB6F8E" HorizontalAlignment="Center" Padding="2,0"
                      ToolTip="{DynamicResource TipDelRow}"
                      Visibility="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGridRow}, Converter={StaticResource BoolToVis}}"/>
            </DataTemplate>
          </DataGridTemplateColumn.CellTemplate>
        </DataGridTemplateColumn>
      </DataGrid.Columns>
    </DataGrid>
      <Button Name="BtnRefresh" Width="34" Height="34" FontSize="17" FontWeight="Bold"
              HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,16,8"
              Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource NavBrush}"
              BorderBrush="{DynamicResource LineBrush}" BorderThickness="1" Cursor="Hand" ToolTip="{DynamicResource TipRefresh}" ToolTipService.ShowOnDisabled="True">
        <TextBlock Text="⟳"/>
      </Button>
      <Button Name="BtnPathClear" Content="🗑" Width="30" Height="30" FontSize="14"
              HorizontalAlignment="Left" VerticalAlignment="Bottom" Margin="8,0,0,8"
              Background="#EB6F8E" Foreground="White"
              BorderThickness="0" Cursor="Hand" ToolTip="{DynamicResource TipClear}" ToolTipService.ShowOnDisabled="True"/>
        </Grid>
      </Grid>
      <StackPanel Grid.Column="1" Margin="10,0,0,0">
        <Button Name="BtnHudHide" Content="🙈  Hide HUD" Height="34" Margin="0,0,0,6"
                Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}"/>
        <Button Name="BtnPathAdd" Content="📷  ADD KEYFRAME" Height="52" Margin="0,0,0,6"
                Background="#3FA85C" Foreground="White" FontSize="16" FontWeight="Bold"/>
        <Border CornerRadius="8" Background="#6C71C4" Margin="0,0,0,6" Padding="8,4">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <TextBlock Text="🕐 FLIGHT TIME, SEC — whole path in N seconds" Foreground="#C9CCEF" FontSize="11" Visibility="Collapsed"/>
            <Grid Grid.Row="1">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Button Name="BtnPathPlay" Content="▶  PLAY by TIME" Background="Transparent" BorderThickness="0"
                      Foreground="White" FontSize="14" FontWeight="Bold" HorizontalAlignment="Stretch" Cursor="Hand"
                      HorizontalContentAlignment="Left" Padding="8,4" ToolTipService.ShowOnDisabled="True"/>
              <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,4,0">
                <TextBox Name="TbSeconds" Text="15" Width="44" Height="28" FontSize="14" FontWeight="Bold"
                         Background="#464B8B" Foreground="White" BorderBrush="#9A9FDB" BorderThickness="1"
                         HorizontalContentAlignment="Center" VerticalContentAlignment="Center"/>
                <TextBlock Name="TxSec" Text="sec" Foreground="#D0D3F0" FontSize="11" VerticalAlignment="Center" Margin="4,0,0,0"/>
              </StackPanel>
            </Grid>
          </Grid>
        </Border>
        <Button Name="BtnPathPlaySpeed" Content="▶  Play" Background="#CBA6F7"
                Foreground="#1E1E2E" FontSize="16" FontWeight="Bold" HorizontalAlignment="Stretch"
                HorizontalContentAlignment="Left" Padding="18,4" Margin="0,0,0,6" ToolTipService.ShowOnDisabled="True"/>
        <Button Name="BtnPathStop" Content="■  Stop" Height="34" Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}" ToolTipService.ShowOnDisabled="True"/>
        <TextBlock Name="TbMapLabel" Text="🗺 MAP" Foreground="{DynamicResource MutedBrush}" FontSize="11" Margin="0,10,0,3"/>
        <Grid Margin="2,0,0,10">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Name="TbMap" Grid.Column="0" Text="(no map)" Foreground="{DynamicResource TextBrush}" FontSize="14" FontWeight="Bold"
                     TextWrapping="Wrap" VerticalAlignment="Center"/>
          <!-- v5.17.13: превью карты из system/Thumbnails/<MapName>.bmp (120x90,
               генерируется самой игрой для UI выбора карт), справа от названия -->
          <Image Name="ImgMapPreview" Grid.Column="1" Width="72" Height="54" Stretch="Uniform"
                 HorizontalAlignment="Right" VerticalAlignment="Top"/>
        </Grid>
        <Button Name="BtnExport" Content="↗  Export to file" Height="34" Margin="0,0,0,6"
                Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}"
                HorizontalContentAlignment="Left" Padding="14,4" ToolTipService.ShowOnDisabled="True"/>
        <Button Name="BtnImport" Content="↙  Import from file" Height="34"
                Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}"
                HorizontalContentAlignment="Left" Padding="14,4"/>
      </StackPanel>
    </Grid>

    <!-- v5.17.11.5: кнопка "Go to selected" убрана - переход к кадру теперь значком-меткой
         на самой строке (см. колонку перед корзиной) -->

    <!-- parameters: two rows (FOV / Fly speed) on shared columns, so key/ALL buttons align by X -->
    <Grid Grid.Row="2" Margin="3,0,3,6">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock Grid.Row="0" Grid.Column="0" Text="📷 FOV" Foreground="{DynamicResource TextBrush}" FontSize="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBox Grid.Row="0" Grid.Column="1" Name="TbFov" Text="90" Width="56" Height="30" FontSize="13" Margin="0,0,0,4"
               VerticalContentAlignment="Center" HorizontalContentAlignment="Center" Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}"/>
      <Button Grid.Row="0" Grid.Column="2" Name="BtnSetFov" Content="Set FOV" Height="30" Margin="6,0,0,4" Background="#6C71C4" Foreground="White" ToolTipService.ShowOnDisabled="True"/>
      <Button Grid.Row="0" Grid.Column="3" Name="BtnFovKey" Content="🎯 FOV → key" Height="30" Margin="10,0,0,4" Background="#94E2D5" Foreground="#1E1E2E" FontWeight="Bold" ToolTipService.ShowOnDisabled="True"/>
      <Button Grid.Row="0" Grid.Column="4" Name="BtnFovAll" Content="🌐 FOV → ALL" Height="30" Margin="6,0,0,4" Background="#89B4FA" Foreground="#1E1E2E" FontWeight="Bold" ToolTipService.ShowOnDisabled="True"/>
      <TextBlock Grid.Row="1" Grid.Column="0" Name="TxFlySpeed" Text="✈ Fly speed" Foreground="{DynamicResource TextBrush}" FontSize="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBox Grid.Row="1" Grid.Column="1" Name="TbSpeed" Text="500" Width="56" Height="30" FontSize="13"
               VerticalContentAlignment="Center" HorizontalContentAlignment="Center" Background="{DynamicResource PanelBrush}" Foreground="{DynamicResource TextBrush}"/>
      <Button Grid.Row="1" Grid.Column="2" Name="BtnSpeed" Content="Set fly speed" Height="30" Margin="6,0,0,0" Background="#6C71C4" Foreground="White" ToolTipService.ShowOnDisabled="True"/>
      <Button Grid.Row="1" Grid.Column="3" Name="BtnKeySpeed" Content="⚡ Speed → key" Height="30" Margin="10,0,0,0" Background="#F9E2AF" Foreground="#1E1E2E" FontWeight="Bold" ToolTipService.ShowOnDisabled="True"/>
      <Button Grid.Row="1" Grid.Column="4" Name="BtnSpeedAll" Content="🗂 Speed → ALL" Height="30" Margin="6,0,0,0" Background="#F5C97B" Foreground="#1E1E2E" FontWeight="Bold" ToolTipService.ShowOnDisabled="True"/>
    </Grid>

    <!-- status + transparency -->
    <Grid Grid.Row="3" Margin="3,2,3,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <Ellipse Name="StatusDot" Width="10" Height="10" Fill="{DynamicResource DotBrush}" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <TextBlock Name="TbStatus" Grid.Column="1" Text="ready" Foreground="{DynamicResource StatusBrush}" FontSize="12" VerticalAlignment="Center" TextWrapping="Wrap"/>
      <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="8,0,0,0">
        <!-- v5.17.14 (#10): кнопка-иконка GitHub - открывает репозиторий -->
        <Button Name="BtnGithub" Width="34" Height="26" Background="Transparent" BorderThickness="0" Cursor="Hand"
                ToolTip="{DynamicResource TipGithub}" Margin="0,0,6,0">
          <Path Data="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"
                Fill="{DynamicResource TextBrush}" Stretch="Uniform" Width="16" Height="16"/>
        </Button>
        <CheckBox Name="CbTransparent" Content="Transparent" Foreground="{DynamicResource MutedBrush}"
                  FontSize="12" VerticalAlignment="Center" Margin="8,0,0,0"/>
      </StackPanel>
    </Grid>
    <!-- v5.17.14 (#6): журнал последних логов - раскрывается при наведении на статус -->
    <Popup x:Name="LogPopup" PlacementTarget="{Binding ElementName=TbStatus}" Placement="Top" StaysOpen="True" AllowsTransparency="True" VerticalOffset="6">
      <Border Name="LogPopupBorder" CornerRadius="8" Background="{DynamicResource PanelBrush}" BorderBrush="{DynamicResource LineBrush}" BorderThickness="1" Padding="8" MinWidth="440" MaxWidth="620">
        <TextBox Name="TbLogHistory" IsReadOnly="True" FontFamily="Consolas" FontSize="11" MaxHeight="210" MinWidth="420"
                 Background="Transparent" Foreground="{DynamicResource TextBrush}" BorderThickness="0"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
      </Border>
    </Popup>
  </Grid>
  </AdornerDecorator>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
foreach ($name in @('BtnHudHide','BtnPathAdd','TbSeconds','BtnPathPlay','BtnPathPlaySpeed','BtnPathStop','BtnPathClear','DgKeys','TbMap','TbMapLabel','TxFramesLabel','TxSec','TxFlySpeed','BtnExport','BtnImport','BtnRefresh','TbFov','BtnSetFov','BtnFovKey','BtnFovAll','BtnKeySpeed','TbSpeed','BtnSpeed','BtnSpeedAll','CbTransparent','HdrGrid','BtnLang','FlagEN','FlagRU','BtnTheme','ImgOwl','ImgMapPreview','BtnHide','BtnClose','TbStatus','StatusDot','TxHkFrame','TxHkPlay','TxHkStop','TxHkClear','BtnGithub','LogPopup','LogPopupBorder','TbLogHistory')) {
    $controls[$name] = $window.FindName($name)
}

# v5.17.7: kind="warn" красит статус ОРАНЖЕВЫМ (идёт печать команд в игру),
# v5.17.14 (#7): kind="err" красит КРАСНЫМ (не видно активного окна игры),
# по умолчанию - обычный зелёный.
# v5.17.14 (#6): каждый статус пишется в журнал (со временем; в обычной строке
# время не показывается) - при наведении на статус раскрывается журнал
$script:StatusLog = New-Object System.Collections.Generic.List[string]
function Set-Status([string]$s, [string]$kind = "ok") {
    $script:StatusKind = $kind
    $controls['TbStatus'].Text = $s
    $sk = "StatusBrush"
    if ( $kind -eq "warn" ) { $sk = "StatusWarnBrush" }
    if ( $kind -eq "err" ) { $sk = "StatusErrBrush" }
    try { $controls['TbStatus'].Foreground = $window.Resources[$sk] } catch { }
    # v5.17.16 (#7): кружок статуса красится тем же цветом - красный, когда нет игры
    try { $controls['StatusDot'].Fill = $window.Resources[$sk] } catch { }
    try {
        # дубли подряд (полл статуса раз в 5.4с) в журнал не пишем - шум
        $dup = $false
        if ( $script:StatusLog.Count -gt 0 -and $script:StatusLog[$script:StatusLog.Count-1].EndsWith("  " + $s) ) { $dup = $true }
        if ( -not $dup ) {
            $script:StatusLog.Add((Get-Date -Format "HH:mm:ss") + "  " + $s)
            while ( $script:StatusLog.Count -gt 100 ) { $script:StatusLog.RemoveAt(0) }
        }
        if ( $controls['LogPopup'].IsOpen ) {
            $controls['TbLogHistory'].Text = ($script:StatusLog -join "`n")
            $controls['TbLogHistory'].ScrollToEnd()
        }
    } catch { }
}

function Get-MapText {
    # v5.14: лейбл показывает карту КАДРОВ, а не где игрок сейчас
    if ( $script:KeyMap -ne "" ) { return $script:KeyMap }
    return $script:LocData[$script:Lang].NoMap
}

function Update-MapPreview {
    # v5.17.13: превью карты кадров из system/Thumbnails/<MapName>.bmp
    # (120x90 bmp, сама игра генерирует их для UI выбора карт). Нет файла -
    # картинка скрывается
    try {
        $img = $controls['ImgMapPreview']
        if ( $img -eq $null ) { return }
        $map = $script:KeyMap
        $path = "F:\Harry Potter and the Chamber of Secrets\system\Thumbnails\" + $map + ".bmp"
        if ( $map -ne "" -and (Test-Path $path) ) {
            $bmp = New-Object Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = (New-Object Uri($path))
            $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $bmp.Freeze()
            $img.Source = $bmp
            $img.Visibility = [System.Windows.Visibility]::Visible
        } else {
            $img.Source = $null
            $img.Visibility = [System.Windows.Visibility]::Collapsed
        }
    } catch { }
}

function Do-PathAdd {
    # скорость кадра = поле fly speed: применяем её перед добавлением
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    $script:StampNextSync = $true   # новый кадр получит время постановки
    $st = Send-GameCommands @("Cam_MoveSpeed $sp", "PathAdd")
    $script:SpeedApplied = $sp
    Update-ParamBox "speed"
    Sync-AfterCommand $st
}
# v5.7: Stop красный, пока идёт показ; гаснет по клику на Stop или по PLAYEND из игры
$script:Playing = $false
$script:PlayWatch = $null
function Set-Playing([bool]$p) {
    $script:Playing = $p
    $controls['BtnPathStop'].IsEnabled = $p
    Update-SelectionButtons   # v5.12: лочка кнопок на время воспроизведения
    if ( $p ) {
        $controls['BtnPathStop'].Background = "#E5484D"
        $controls['BtnPathStop'].Foreground = "White"
    } else {
        $controls['BtnPathStop'].Background = $window.Resources['PanelBrush']
        $controls['BtnPathStop'].Foreground = $window.Resources['TextBrush']
    }
    if ( $p -and $script:PlayWatch -eq $null ) {
        # таймер синка, пока играем: ловит PLAYEND из памяти игры
        $script:PlayWatch = New-Object System.Windows.Threading.DispatcherTimer
        $script:PlayWatch.Interval = [TimeSpan]::FromMilliseconds(350)
        $script:PlayWatch.Add_Tick({
            if ( $script:Playing ) { Sync-FromLog }
            if ( -not $script:Playing ) { $script:PlayWatch.Stop(); $script:PlayWatch = $null }
        })
        $script:PlayWatch.Start()
    }
}
function Start-PlayFallback([double]$dur) {
    # страховка: если PLAYEND не поймали, гасим Stop через длительность показа + запас
    $fb = New-Object System.Windows.Threading.DispatcherTimer
    $fb.Interval = [TimeSpan]::FromSeconds($dur + 1.5)
    $fb.Add_Tick({
        param($s, $e)
        if ( $script:Playing ) { Set-Playing $false }
        $s.Stop()
    })
    $fb.Start()
}
function Get-PathTotalDur {
    # как PathPlaySpeedPath в игре: сумма (дистанция / скорость кадра)
    $tot = 0.0
    for ( $i = 0; $i -lt $script:KeyRows.Count - 1; $i++ ) {
        $a = $script:KeyRows[$i]; $b = $script:KeyRows[$i + 1]
        $d = [Math]::Sqrt([Math]::Pow($b.X - $a.X, 2) + [Math]::Pow($b.Y - $a.Y, 2) + [Math]::Pow($b.Z - $a.Z, 2))
        $sp = $a.Speed
        if ( $sp -le 0 ) { $sp = 250 }
        $seg = $d / $sp
        if ( $seg -lt 0.05 ) { $seg = 0.05 }
        $tot += $seg
    }
    return $tot
}
function Do-PathPlay {
    # один кадр = просто перейти к нему (игра требует минимум 2 для проигрывания)
    if ( $script:KeyRows.Count -eq 1 ) {
        $st = Send-GameCommand "PathGoto 0"
        Set-Status ($script:LocData[$script:Lang].OneKey + " | " + $st)
        return
    }
    # speed-driven playback: длительность сегментов = дистанция / скорость кадра
    # v5.17.14 (#8): Stop активен СРАЗУ, до ввода команд (команда печатается секунды)
    $controls['BtnPathStop'].IsEnabled = $true
    $st = Send-GameCommand "PathPlaySpeed"
    if ( $st -like "*OK*" ) { Set-Playing $true; Start-PlayFallback (Get-PathTotalDur) }
    else { if ( -not $script:Playing ) { $controls['BtnPathStop'].IsEnabled = $false } }
    Set-Status $st
}
function Do-PathPlayTime {
    # один кадр = просто перейти к нему
    if ( $script:KeyRows.Count -eq 1 ) {
        $st = Send-GameCommand "PathGoto 0"
        Set-Status ($script:LocData[$script:Lang].OneKey + " | " + $st)
        return
    }
    # равномерный режим: весь путь за N секунд из поля FLIGHT TIME
    $sec = $controls['TbSeconds'].Text.Trim()
    if ($sec -notmatch '^\d+(\.\d+)?$') { $sec = "15" }
    # v5.17.14 (#8): Stop активен СРАЗУ, до ввода команд
    $controls['BtnPathStop'].IsEnabled = $true
    $st = Send-GameCommand "PathPlay $sec"
    if ( $st -like "*OK*" ) { Set-Playing $true; Start-PlayFallback ([double]$sec) }
    else { if ( -not $script:Playing ) { $controls['BtnPathStop'].IsEnabled = $false } }
    Set-Status $st
}
# HideHud в игре - ПЕРЕКЛЮЧАТЕЛЬ; панель помнит состояние, кнопка одна и меняет подпись
$script:HudHidden = $false
function Update-HudButton {
    $L = $null
    if ( $script:LocData -ne $null ) { $L = $script:LocData[$script:Lang] }
    if ( $L -eq $null ) { return }
    if ( $script:HudHidden ) { $controls['BtnHudHide'].Content = $L.HudShow }
    else { $controls['BtnHudHide'].Content = $L.HudHide }
}
$controls['BtnHudHide'].Add_Click({
    $script:HudHidden = -not $script:HudHidden
    Update-HudButton
    Set-Status (Send-GameCommand "HideHud")
})
$controls['BtnPathAdd'].Add_Click({ Do-PathAdd })
$controls['BtnPathPlay'].Add_Click({ Do-PathPlayTime })
$controls['BtnPathPlaySpeed'].Add_Click({ Do-PathPlay })
$controls['BtnPathStop'].Add_Click({
    $st = Send-GameCommand "PathStop"
    Set-Playing $false
    Set-Status $st
})
$controls['BtnPathClear'].Add_Click({
    # v5.14: игра закрыта - чистим таблицу локально (команды отправлять некому)
    if ( (Get-Process Game -ErrorAction SilentlyContinue) -eq $null ) {
        # v5.17.16 (#hotfix): KeyRows - ArrayList, УЖЕ назначенный ItemsSource: мутируя
        # его (Clear) и переназначая ТОТ ЖЕ экземпляр, вью таблицы не перестраивается -
        # строки оставались на экране. Заменяем экземпляр новым пустым
        $script:KeyRows = New-Object System.Collections.ArrayList
        $script:KeyMap = ""
        Refresh-Table
        Save-KeysBackup -ForceEmpty   # v5.17.17: явная очистка - бэкап тоже пустеет
        Set-Status "game is not running - table cleared locally"
        return
    }
    # v5.17.17: явная очистка - после синка с пустым путём бэкап тоже пустеет
    $script:UserClearPending = $true
    $st = Send-GameCommand "PathClear"
    Sync-AfterCommand $st
})
$controls['BtnRefresh'].Add_Click({
    # v5.17: обновить = истина от игры: запрашиваем снапшот пути, затем полный скан
    if ( (Get-Process Game -ErrorAction SilentlyContinue) -ne $null ) { Send-GameCommand "PathDumpKeys" | Out-Null }
    Sync-FromLog -Force
})
# ---------- v5.17.11: зелёные "+" РОВНО НА СТЫКАХ строк ----------
# ПЛЮСИКИ ЖИВУТ В ШАБЛОНЕ КОЛОНКИ # (см. XAML): кнопка центрирована на ВЕРХНЕЙ
# границе строки (половина в предыдущей строке) = ровно стык, видна когда курсор
# где-либо над таблицей (IsMouseOver грида). Вниз выступать нельзя: строка k+1
# рисуется позже и ЗАКРАШИВАЕТ выступ; вверх - можно (строка k рисуется поверх
# k-1), ClipToBounds=False по цепочке Cell/CellsPresenter/Row снимает обрезку.
# v5.17.8-pivot-история: overlay-Canvas в гриде упорно не рендерился (layout-лог
# идеальный, зелёных пикселей 0) - шаблонные кнопки в ячейках рендерятся надёжно.
# Клик ловится routed-хендлером Button.Click ниже: Content=="+" -> PathInsertAt Num.
# удаление строки (корзина по наведению) + v5.17.8: вставка зелёным "+" на стыке строк.
# Все ловятся routed-хендлером Button.Click внутри таблицы: тег корзины/метки = число
# (индекс для PathDel/PathGoto), тег плюсика = Num (PathInsertAt N - ТЕКУЩАЯ камера)
$delHandler = [System.Windows.RoutedEventHandler]{
    param($s, $e)
    $b = $e.OriginalSource
    if ( $b -is [System.Windows.Controls.Button] -and $b.Tag -ne $null ) {
        try {
            $tag = [string]$b.Tag
            # ВАЖНО: различаем по Content, НЕ по Tag-формату: Tag биндится к Num, а
            # StringFormat на object-свойстве (Tag) WPF МОЛЧА ИГНОРИРУЕТ - тег всегда
            # просто число, "ins:N" не получить. Пилюля "+" = Content "+", корзина = "🗑"
            if ( [string]$b.Content -eq [string][char]0xE73E ) {
                # v5.17.18 (#2): галочка = подтвердить правки строки
                Accept-RowEdits ([int]$tag)
                return
            }
            if ( [string]$b.Content -eq [string][char]0xE711 ) {
                # v5.17.18 (#2): крестик = откатить правки строки
                Revert-RowEdits ([int]$tag)
                return
            }
            if ( [string]$b.Content -eq "+" ) {
                # v5.17.11: плюсик сидит РОВНО НА СТЫКЕ над строкой N (верхняя граница
                # её ячейки) = между строками N-1 и N: вставляем ТЕКУЩИЙ кадр камеры на
                # позицию N. У строки 0 это вставка в начало пути.
                Insert-KeyframeAt ([int]$tag)
                return
            }
            if ( [string]$b.Content -eq [string][char]0xE7B3 ) {
                # v5.17.11.7: глаз на строке = "посмотреть как выглядит кадр": переход
                # камеры к кадру N (PathGoto). Роутер по Content - глиф RedEye из Segoe
                # MDL2 Assets (нет в тексте - сравнение через [char])
                # v5.17.15 (#1): игра должна быть на уровне (меню -> фокус на игру/отказ)
                if ( -not (Confirm-GameActive) ) { return }
                # v5.14: кадры с другой карты - переходить нельзя
                if ( $script:KeyMap -ne "" -and $script:CurrentMap -ne "" -and $script:KeyMap -ne $script:CurrentMap ) {
                    $L = $script:LocData[$script:Lang]
                    Set-Status $L.TipWrongMap
                    return
                }
                Set-Status (Send-GameCommand "PathGoto $([int]$tag)")
                return
            }
            $idx = [int]$tag
            # v5.14: игра закрыта - удаляем строку локально
            if ( (Get-Process Game -ErrorAction SilentlyContinue) -eq $null ) {
                if ( $idx -ge 0 -and $idx -lt $script:KeyRows.Count ) {
                    # v5.17.16: новая коллекция ВМЕСТО мутации - ItemsSource держит старый
                    # экземпляр, вью иначе не перестраивается (см. очистку таблицы выше)
                    $new = New-Object System.Collections.ArrayList
                    for ( $k = 0; $k -lt $script:KeyRows.Count; $k++ ) {
                        if ( $k -ne $idx ) { [void]$new.Add($script:KeyRows[$k]) }
                    }
                    $script:KeyRows = $new
                    for ( $k = 0; $k -lt $script:KeyRows.Count; $k++ ) { $script:KeyRows[$k].Num = $k }
                    Refresh-Table
                    Save-KeysBackup -ForceEmpty   # v5.17.17: явное удаление - сейвим остаток (может быть пусто)
                    Set-Status "game is not running - keyframe deleted locally"
                }
                return
            }
            # v5.17.15 (#1): игра запущена, но в меню - удалять из терминала нельзя
            if ( -not (Confirm-GameActive) ) { return }
            $st = Send-GameCommand "PathDel $idx"
            Send-PathSaveAndSync $st
        } catch { }
    }
}
$controls['DgKeys'].AddHandler([System.Windows.Controls.Button]::ClickEvent, $delHandler)

# v5.17.11.2: общая вставка ТЕКУЩЕГО кадра на позицию idx (между idx-1 и idx);
# новый кадр получает время постановки + активные значения FOV/скорости панели
function Insert-KeyframeAt([int]$idx) {
    if ( (Get-Process Game -ErrorAction SilentlyContinue) -eq $null ) {
        Set-Status "game is not running - cannot insert"; return
    }
    $script:StampNextSync = $true
    $cmds = @("PathInsertAt $idx",
              "FovIdx $idx", "FovVal $($script:FovApplied)", "FovApply",
              "SpeedIdx $idx", "SpeedVal $($script:SpeedApplied)", "SpeedApply")
    $st = Send-GameCommands $cmds
    Sync-AfterCommand "insert at #$idx | $st"
}

# ---------- v5.17.11.2: верхняя половина плюса стыка "шапка / строка 0" ----------
# Плюс строки 0 вылезает на -6px выше верхней кромки таблицы, а ScrollContentPresenter
# клипует всё, что выше content-top -> у стыка шапка/строка-0 видна только нижняя
# половина пилюли (юзер: "дорисовывай на шапке оставшуюся половину"). Хедер-костыль
# (вторая кнопка в HeaderTemplate) отвергнут - у шапки свой padding, половинки не
# сошлись. РЕШЕНИЕ: AdornerLayer - адорнер рисуется ПОВЕРХ всего дерева окна и не
# клипается вьюпортом. Рисуем ПОЛНЫЙ эллипс на позиции центра плюса строки 0 (низ
# совпадает с нижней половиной 1:1, тот же цвет), а "+" глиф - ТОЛЬКО верхнюю
# половину (PushClip), нижнюю рисует сама кнопка строки. IsHitTestVisible=false:
# клик ловит кнопка строки 0 (вставка в начало пути). Позиция = TranslatePoint
# строки 0 в координаты DataGrid, пересчёт на LayoutUpdated / MouseEnter/Leave /
# ScrollChanged (скролл не поднимает LayoutUpdated).
try {
    Add-Type -TypeDefinition @"
using System;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;
namespace HP2 {
public class TopHalfPillAdorner : Adorner {
    public double PillX = -100; public double PillY = -100; public bool Show = false;
    static readonly Brush _b = new SolidColorBrush(Color.FromArgb(0xE0, 0x2F, 0x9E, 0x44));
    public TopHalfPillAdorner(UIElement el) : base(el) { IsHitTestVisible = false; }
    protected override void OnRender(DrawingContext dc) {
        if (!Show) return;
        dc.DrawEllipse(_b, null, new Point(PillX, PillY), 8.0, 6.0);
        // "+" целиком из адорнера (глиф кнопки строки 0 погашен триггером Num=0):
        // пол-глифа от кнопки + пол-глифа от FormattedText не совпали бы по метрикам
        FormattedText ft = new FormattedText("+", System.Globalization.CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            new Typeface(new FontFamily("Consolas"), FontStyles.Normal, FontWeights.Bold, FontStretches.Normal),
            10, Brushes.White, VisualTreeHelper.GetDpi(this).PixelsPerDip);
        dc.DrawText(ft, new Point(PillX - ft.Width/2, PillY - ft.Height/2));
    }
}
}
"@ -ReferencedAssemblies @('PresentationCore','PresentationFramework','WindowsBase','System.Xaml')
} catch { }

try {
    # ВАЖНО: адорним КОРНЕВОЙ грид, а не сам DgKeys! Слой адорнеров в этом окне
    # размещает адорнер в (0,0) координат декоратора, игнорируя смещение adorned-
    # элемента (живой тест: эллипс для DgKeys лег в левый верхний угол окна).
    # Корневой грид стоит в (0,0), поэтому рисуем сразу в его координатах.
    $script:RootGrid = $window.FindName('RootGrid')
    $script:PillAdorner = New-Object HP2.TopHalfPillAdorner($script:RootGrid)
    $adLayer = [System.Windows.Documents.AdornerLayer]::GetAdornerLayer($script:RootGrid)
    if ( $adLayer -ne $null ) { $adLayer.Add([System.Windows.Documents.Adorner]$script:PillAdorner) | Out-Null }
} catch { }

function Update-PillAdorner {
    try {
        $a = $script:PillAdorner
        if ( $a -eq $null ) { return }
        $dg = $controls['DgKeys']
        $row0 = $null
        try { $row0 = $dg.ItemContainerGenerator.ContainerFromIndex(0) } catch { }
        # позиция кэшируется: при пересборке таблицы ContainerFromIndex(0) МОЖЕТ
        # временно вернуть null - если бы Show зависел от удачного lookup, плюс
        # навсегда оставался бы скрыт до следующего LayoutUpdated
        if ( $row0 -ne $null -and $script:PillAdorner.Parent -ne $null ) {
            # координаты в пространстве AdornerLayer: слой покрывает декоратор ЦЕЛИКОМ
            # (включая Margin грида), поэтому TranslatePoint именно к слою - иначе
            # эллипс уезжает на 12 WPF (маргин) вверх-влево
            $p = $row0.TranslatePoint([System.Windows.Point]::new(0,0), $script:PillAdorner.Parent)
            $script:PillAX = $p.X + 30   # центр пилюли: Margin 22 слева + половина ширины 16
            $script:PillAY = $p.Y        # верх строки 0 = стык с шапкой
        }
        if ( $script:PillAX -gt 0 -and $dg.Items.Count -gt 0 -and $dg.IsMouseOver ) {
            $a.PillX = $script:PillAX
            $a.PillY = $script:PillAY
            $a.Show = $true
        } else {
            $a.Show = $false
        }
        $a.InvalidateVisual()
    } catch { }
}
$controls['DgKeys'].Add_LayoutUpdated({ Update-PillAdorner })
$controls['DgKeys'].Add_MouseEnter({ Update-PillAdorner })
$controls['DgKeys'].Add_MouseLeave({ Update-PillAdorner })

# КЛИК по верхней половине плюса (лежит НА шапке): слой адорнеров в этом окружении
# НЕ УЧАСТВУЕТ в hit-test (изолированный тест: InputHitTest в точке кнопки адорнера
# возвращает содержимое под ним, кнопка клика не получает). Ловим PreviewMouseDown
# на уровне окна: если клик попал в рект ВЕРХНЕЙ половины пилюли (в координатах
# слоя) и таблица под курсором - вставка в НАЧАЛО пути. Нижняя половина кликается
# обычной кнопкой строки 0 (roутер delHandler).
$window.Add_PreviewMouseLeftButtonDown({
    param($s, $e)
    try {
        if ( $script:PillAdorner -eq $null -or $script:PillAX -le 0 ) { return }
        $dg = $controls['DgKeys']
        if ( -not $dg.IsMouseOver ) { return }
        $pt = $e.GetPosition($script:PillAdorner.Parent)
        if ( $pt.X -ge ($script:PillAX - 8) -and $pt.X -le ($script:PillAX + 8) -and
             $pt.Y -ge ($script:PillAY - 6) -and $pt.Y -le $script:PillAY ) {
            Insert-KeyframeAt 0
            $e.Handled = $true
        }
    } catch { }
})

# скролл не поднимает LayoutUpdated - вешаем ScrollChanged на ScrollViewer грида,
# когда он появится в визуальном дереве (после Loaded)
$window.Add_Loaded({
    try {
        $script:DgScrollViewer = Find-VisualChildOfType $controls['DgKeys'] ([System.Windows.Controls.ScrollViewer])
        if ( $script:DgScrollViewer -ne $null ) { $script:DgScrollViewer.Add_ScrollChanged({ Update-PillAdorner }) }
    } catch { }
})

# v5.17.11.4: курсор-рука над ВЕРХНЕЙ половиной плюса - она лежит НА шапке, и курсор
# там задаёт хедер (стрелка), а не адорнер. Хук на MouseMove САМОГО грида (пузырится
# из хедера): в ректе ВЕРХНЕЙ половины пилюли ставим Hand на OriginalSource; ниже
# стыка не трогаем - у кнопки строки 0 уже свой Hand. Сброс - только если текущий
# источник был Hand (иначе затрём курсоры других элементов)
# ВАЖНО: Add_MouseMove НЕ срабатывает над хедером - DataGrid глотает MouseMove
# внутренними обработчиками (e.Handled, колонки-драг). Только AddHandler c
# handledEventsToo=$true доходит сюда
$pillMoveHandler = [System.Windows.Input.MouseEventHandler]{
    param($s, $e)
    try {
        if ( $script:PillAdorner -eq $null -or $script:PillAX -le 0 ) { return }
        $pt = $e.GetPosition($script:PillAdorner.Parent)
        $src = $e.OriginalSource
        if ( -not ($src -is [System.Windows.FrameworkElement]) ) { return }
        if ( $pt.Y -le $script:PillAY -and $pt.Y -ge ($script:PillAY - 6) -and [Math]::Abs($pt.X - $script:PillAX) -le 8 ) {
            $src.Cursor = [System.Windows.Input.Cursors]::Hand
        } elseif ( $pt.Y -le $script:PillAY -and $src.Cursor -eq [System.Windows.Input.Cursors]::Hand ) {
            $src.Cursor = [System.Windows.Input.Cursors]::Arrow
        }
    } catch { }
}
$controls['DgKeys'].AddHandler([System.Windows.Input.Mouse]::MouseMoveEvent, $pillMoveHandler, $true)

function Find-VisualChildOfType($el, $t) {
    $n = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($el)
    for ( $i = 0; $i -lt $n; $i++ ) {
        $c = [System.Windows.Media.VisualTreeHelper]::GetChild($el, $i)
        if ( $c -is $t ) { return $c }
        $r = Find-VisualChildOfType $c $t
        if ( $r -ne $null ) { return $r }
    }
    return $null
}
# FOV / Fly speed: зелёный фон = значение применено к игре, серый = редактируется (Set доступен только тогда)
$script:FovApplied = "90"
$script:SpeedApplied = "500"
function Set-ParamBoxState([string]$which) {
    # v5.17.7: ядро Update-ParamBox, вызывается и из Update-SelectionButtons -
    # иначе цикл PlayLock каждый раз ПЕРЕВКЛЮЧАЛ Set FOV / Set fly speed, даже когда
    # в поле уже стоит применённое (активное) значение - кнопки висели доступными.
    # Рекурсии нет: Set-ParamBoxState ничего не вызывает назад.
    $box = if ( $which -eq "fov" ) { $controls['TbFov'] } else { $controls['TbSpeed'] }
    $btn = if ( $which -eq "fov" ) { $controls['BtnSetFov'] } else { $controls['BtnSpeed'] }
    $applied = if ( $which -eq "fov" ) { $script:FovApplied } else { $script:SpeedApplied }
    $key = if ( $box.Text.Trim() -eq $applied ) { "SyncBrush" } else { "DirtyBrush" }
    $box.Background = $window.Resources[$key]
    $btn.IsEnabled = ($key -eq "DirtyBrush")
}
function Update-ParamBox([string]$which) {
    Set-ParamBoxState $which
    # v5.17.6/7: FOV->key / Speed->key и FOV->ALL / Speed->ALL зависят ещё и от
    # значения поля - правка бокса меняет доступность всех этих кнопок на лету
    try { Update-SelectionButtons } catch { }
}
$controls['TbFov'].Add_TextChanged({ Update-ParamBox "fov" })
$controls['TbSpeed'].Add_TextChanged({ Update-ParamBox "speed" })
Update-ParamBox "fov"
Update-ParamBox "speed"
$controls['BtnSetFov'].Add_Click({
    $fov = $controls['TbFov'].Text.Trim()
    if ($fov -notmatch '^\d+(\.\d+)?$') { $fov = "90" }
    $fovI = [string][int][math]::Round([double]$fov)   # v5.17.2: без точки в typed-команде
    $script:FovApplied = $fovI
    Update-ParamBox "fov"
    Set-Status (Send-GameCommand "Cam_FOV $fovI")
})
$controls['BtnFovKey'].Add_Click({
    $sel = $controls['DgKeys'].SelectedItem
    $fov = $controls['TbFov'].Text.Trim()
    if ($fov -notmatch '^\d+(\.\d+)?$') { $fov = "90" }
    if ( $sel -ne $null ) {
        # v5.17.2: 2 аргумента консоль теряет - пошагово FOV для выбранного кадра
        $fv = [int][math]::Round([double]$fov)
        $st = Send-GameCommands @("FovIdx $($sel.Num)","FovVal $fv","FovApply")
        Send-PathSaveAndSync $st
    } else { Set-Status "select a keyframe row first" }
})
$controls['BtnFovAll'].Add_Click({
    $fov = $controls['TbFov'].Text.Trim()
    if ($fov -notmatch '^\d+(\.\d+)?$') { $fov = "90" }
    $fovI = [string][int][math]::Round([double]$fov)
    $st = Send-GameCommand "PathSetAllFov $fovI"
    Sync-AfterCommand $st
})
$controls['BtnSpeed'].Add_Click({
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    $spI = [string][int][math]::Round([double]$sp)
    $script:SpeedApplied = $spI
    Update-ParamBox "speed"
    Set-Status (Send-GameCommand "Cam_MoveSpeed $spI")
})
$controls['BtnKeySpeed'].Add_Click({
    $sel = $controls['DgKeys'].SelectedItem
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    if ( $sel -ne $null ) {
        # v5.17.2: пошагово скорость для выбранного кадра
        $sv = [int][math]::Round([double]$sp)
        $st = Send-GameCommands @("SpeedIdx $($sel.Num)","SpeedVal $sv","SpeedApply")
        Send-PathSaveAndSync $st
    } else { Set-Status "select a keyframe row first" }
})
# применить скорость из бокса ко ВСЕМ кадрам: пачка staged-команд за одну сессию консоли
$controls['BtnSpeedAll'].Add_Click({
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    if ( $script:KeyRows.Count -eq 0 ) { Set-Status "no keyframes"; return }
    $sv = [int][math]::Round([double]$sp)
    $cmds = @()
    for ( $i = 0; $i -lt $script:KeyRows.Count; $i++ ) { $cmds += @("SpeedIdx $i","SpeedVal $sv","SpeedApply") }
    $st = Send-GameCommands $cmds
    Sync-AfterCommand $st
})

# ---------- export / import keyframes ----------
$controls['BtnExport'].Add_Click({
    if ( $script:KeyRows.Count -eq 0 ) { Set-Status "no keyframes to export"; return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "HP2 path (*.hp2path)|*.hp2path|All files (*.*)|*.*"
    $dlg.FileName = "$($script:KeyMap).hp2path"
    if ( $dlg.ShowDialog() ) {
        # v5.17.3: 8-е поле - время постановки кадра (переживает экспорт/импорт).
        # Числа - через InvariantCulture: -f с ru-RU культурой пишет "195,153931"
        # (запятая = десятичный разделитель) и рвёт CSV на лишние поля
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        $lines = @("# map=$($script:CurrentMap)  format: x,y,z,yaw,pitch,fov,speed,time")
        foreach ( $r in $script:KeyRows ) {
            $lines += ($r.X.ToString($inv) + "," + $r.Y.ToString($inv) + "," + $r.Z.ToString($inv) + "," + $r.Yaw.ToString($inv) + "," + $r.Pitch.ToString($inv) + "," + $r.FOV.ToString($inv) + "," + $r.Speed.ToString($inv) + "," + $r.Time)
        }
        try {
            [System.IO.File]::WriteAllLines($dlg.FileName, $lines)
            Set-Status "exported $($script:KeyRows.Count) keys -> $($dlg.FileName)"
        } catch { Set-Status "export failed: $($_.Exception.Message)" }
    }
})
$controls['BtnImport'].Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "HP2 path (*.hp2path)|*.hp2path|All files (*.*)|*.*"
    if ( $dlg.ShowDialog() ) {
        try {
            $allLines = [System.IO.File]::ReadAllLines($dlg.FileName)
            # BOM первой строки не должен ломать разбор "# map=..."
            $allLines = $allLines | ForEach-Object { $_.TrimStart([char]0xFEFF) }
            $lines = $allLines | Where-Object { $_.Trim() -ne "" -and -not $_.StartsWith("#") }
        } catch { Set-Status "import failed: $($_.Exception.Message)"; return }
        # v5.14: файл хранит карту кадров - если она не запущена, спрашиваем
        $fileMap = ""
        foreach ( $ln in $allLines ) {
            if ( $ln.StartsWith("#") ) {
                $m = [regex]::Match($ln, '#\s*map=([A-Za-z0-9_]+)')
                if ( $m.Success ) { $fileMap = $m.Groups[1].Value; break }
            }
        }
        if ( $fileMap -ne "" -and $script:CurrentMap -ne "" -and $fileMap -ne $script:CurrentMap ) {
            $L = $script:LocData[$script:Lang]
            $msg = ($L.LoadMapQ -f $fileMap, $script:CurrentMap)
            $r = [System.Windows.MessageBox]::Show($msg, $L.LoadMapTitle, 'YesNo', 'Question')
            if ( $r -ne 'Yes' ) { Set-Status "import cancelled"; return }
            Set-Status ("loading map $($fileMap)...")
            [void](Send-GameCommand "open $($fileMap)")
            Start-Sleep -Seconds 8
        }
        # v5.17.2: консоль M212 при вводе берёт ТОЛЬКО ПЕРВЫЙ аргумент typed-exec -
        # PathAddXYZ x y z ... терял y,z,yaw,pitch,fov,spd (нули и дефолты в кадре).
        # Кадр собирается пошагово: AddX/AddY/.../AddSpd, затем AddCommit.
        # Координаты - offset-целые (v=(coord+16777216)*10, без точек и минусов),
        # углы - положительный mod 65536 (ротатор заворачивается семантически верно)
        $cmds = @("PathClear")
        $n = 0
        $script:PendingImportTimes = @()
        foreach ( $ln in $lines ) {
            $p = $ln.Trim() -split ','
            if ( $p.Count -ge 7 ) {
                try {
                    # offset 1000000: закодированное значение < 2^24 - коэрция float на стороне игры точная
                    $xk = [int][math]::Round(([double]$p[0] + 1000000.0) * 10.0)
                    $yk = [int][math]::Round(([double]$p[1] + 1000000.0) * 10.0)
                    $zk = [int][math]::Round(([double]$p[2] + 1000000.0) * 10.0)
                    $yw = [long][double]$p[3]; $yw = (($yw % 65536) + 65536) % 65536
                    $pt = [long][double]$p[4]; $pt = (($pt % 65536) + 65536) % 65536
                    $fv = [int][math]::Round([double]$p[5])
                    $sp = [int][math]::Round([double]$p[6])
                    $cmds += @("AddX $xk","AddY $yk","AddZ $zk","AddYaw $yw","AddPitch $pt","AddFov $fv","AddSpd $sp","AddCommit")
                    $n++
                    # v5.17.3: время постановки из 8-го поля (если валидное)
                    $t = ""
                    if ( $p.Count -ge 8 -and $p[7] -match '^\d{2}:\d{2}:\d{2}$' ) { $t = $p[7] }
                    $script:PendingImportTimes += $t
                } catch { }
            }
        }
        if ( $n -eq 0 ) { Set-Status "no valid keyframe lines in file"; return }
        $script:StampNextSync = $true
        $st = Send-GameCommands $cmds
        Sync-AfterCommand "imported $n keys from $([System.IO.Path]::GetFileName($dlg.FileName)) | $st"
    }
})
# прозрачность панели (честная: AllowsTransparency)
$controls['CbTransparent'].Add_Checked({   $window.Opacity = 0.8; Set-Status "panel transparent (80%)" })
$controls['CbTransparent'].Add_Unchecked({ $window.Opacity = 1.0 })
# перетаскивание за ВСЮ верхнюю панель, крестик закрывает
$controls['HdrGrid'].Add_MouseLeftButtonDown({ try { $window.DragMove() } catch { } })
$controls['BtnHide'].Add_Click({
    # v5.17.9: ghost instead of $window.Hide(): with the AllowsTransparency window the
    # real Hide SILENTLY KILLED the process ~3s later (3 reproductions, empty crash.log -
    # native render death). Ghost keeps the HWND alive for WPF: fully transparent,
    # click-through, not topmost. ПАНЕЛЬ ОСТАЁТСЯ В ТАСКБАРЕ - клик по нему возвращает
    # (см. Add_Activated ниже). Ctrl+Alt+H (hotkey id 5) тоже.
    $window.Topmost = $false
    $window.Opacity = 0
    $window.IsHitTestVisible = $false
    $window.ShowInTaskbar = $true
})
# клик по значку в таскбаре активирует окно -> снимаем ghost немедленно
$window.Add_Activated({
    try {
        if ( $window.Opacity -eq 0 ) {
            $window.Topmost = $true
            $window.Opacity = 1
            $window.IsHitTestVisible = $true
            $window.ShowInTaskbar = $true
        }
    } catch { }
})
$controls['BtnClose'].Add_Click({ $window.Close() })
# Speed редактируется прямо в таблице: после правки ячейки -> в игру + ini
# ---------- v5.17.18 (#2): редактирование значений таблицы ----------
# одиночный клик по ячейке = редактирование; двойной - выделить текст целиком;
# правки строки подтверждаются галочкой / отменяются крестиком (колонка перед глазом),
# клик мимо таблицы сохраняет правки в поля (DataGrid коммитит сам при потере фокуса).
# Пуш в игру (FOV/Speed) - по ГАЛОЧКЕ; координаты в игре менять нечем, они локальные
$script:RowSnapshots = @{}

$controls['DgKeys'].Add_BeginningEdit({
    param($sender, $e)
    try {
        $row = $e.Row.Item
        if ( $row -eq $null ) { return }
        $n = $row.Num
        if ( -not $script:RowSnapshots.ContainsKey($n) ) {
            $script:RowSnapshots[$n] = @{
                X = $row.X; Y = $row.Y; Z = $row.Z; Yaw = $row.Yaw; Pitch = $row.Pitch
                FOV = $row.FOV; Speed = $row.Speed; Time = $row.Time
            }
        }
    } catch { }
})
$controls['DgKeys'].Add_CellEditEnding({
    param($sender, $e)
    try {
        $row = $e.Row.Item
        if ( $row -eq $null ) { return }
        $n = $row.Num
        # правка времени = обновление key-times (время привязано к координатам)
        if ( $e.Column.Header -eq "Time" ) {
            $t = ""
            try { $t = $e.EditingElement.Text } catch { }
            if ( $t -match '^\d{2}:\d{2}:\d{2}$' ) {
                $inv = [System.Globalization.CultureInfo]::InvariantCulture
                $sk = $row.X.ToString('F1', $inv) + ";" + $row.Y.ToString('F1', $inv) + ";" + $row.Z.ToString('F1', $inv)
                $script:KeyTimes[$sk] = $t
            }
        }
    } catch { }
})
# одиночный клик = начало редактирования; двойной внутри редактирования = SelectAll.
# Preview+handledEventsToo: DataGrid/TextBox глотают часть кликов
$dgKeysEditHandler = [System.Windows.Input.MouseButtonEventHandler]{
    param($s, $e)
    try {
        $dg = $controls['DgKeys']
        # ячейка под курсором: у DataGrid НЕТ свойства IsEditing - проверять надо
        # на самой ячейке ($cell.IsEditing), иначе обработчик тихо падал в catch
        $cell = $null
        $dep = $e.OriginalSource
        while ( $dep -ne $null ) {
            if ( $dep -is [System.Windows.Controls.DataGridCell] ) { $cell = $dep; break }
            $dep = [Windows.Media.VisualTreeHelper]::GetParent($dep)
        }
        # двойной клик в редактируемом TextBox - выделить весь текст
        if ( $e.ClickCount -ge 2 ) {
            $tb = $null
            $dep2 = $e.OriginalSource
            while ( $dep2 -ne $null ) {
                if ( $dep2 -is [System.Windows.Controls.TextBox] ) { $tb = $dep2; break }
                $dep2 = [Windows.Media.VisualTreeHelper]::GetParent($dep2)
            }
            if ( $tb -ne $null ) { $tb.SelectAll(); $e.Handled = $true }
            return
        }
        if ( $cell -eq $null -or $cell.IsEditing -or $cell.IsReadOnly ) { return }
        if ( $script:Playing ) { return }
        if ( $e.OriginalSource -is [System.Windows.Controls.Button] ) { return }
        if ( [string]$cell.Column.Header -eq "#" ) { return }
        # строка-контейнер для BeginEdit(unit, row)
        $drow = $null
        $dep3 = $cell
        while ( $dep3 -ne $null ) {
            if ( $dep3 -is [System.Windows.Controls.DataGridRow] ) { $drow = $dep3; break }
            $dep3 = [Windows.Media.VisualTreeHelper]::GetParent($dep3)
        }
        # ВАЖНО: [Action]-замыкание выполняется ПОЗЖЕ на диспетчере - локальные
        # переменные хендлера там НЕ ВИДНЫ (динамический скоуп PS) - только script:!
        # CurrentCell = кликнутая ячейка; BeginEdit() без аргументов редактирует её
        $script:EditCell = $cell
        $window.Dispatcher.BeginInvoke([Action]{
            try {
                $dgv = $controls['DgKeys']
                $dgv.CurrentCell = New-Object System.Windows.Controls.DataGridCellInfo($script:EditCell)
                $dgv.BeginEdit()
            } catch {
                try { [IO.File]::AppendAllText((Join-Path $PSScriptRoot "markers.log"), ("[" + (Get-Date -Format HH:mm:ss) + "] beginEdit FAIL: " + $_.Exception.Message + "`r`n")) } catch { }
            }
        }) | Out-Null
    } catch { }
}
$controls['DgKeys'].AddHandler([System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent, $dgKeysEditHandler, $true)

# галочка: подтвердить правки строки - пуш FOV/Speed в игру (если она на уровне) + бэкап
function Accept-RowEdits([int]$n) {
    try {
        $row = $null
        foreach ( $r in $script:KeyRows ) { if ( $r.Num -eq $n ) { $row = $r; break } }
        if ( $row -eq $null ) { return }
        if ( $script:ConfirmBypass -eq $false -and (Get-Process Game -ErrorAction SilentlyContinue) -ne $null -and $script:CurrentMap -ne "" ) {
            $cmds = @("FovIdx $n", "FovVal $([int]$row.FOV)", "FovApply",
                      "SpeedIdx $n", "SpeedVal $([int]$row.Speed)", "SpeedApply")
            Send-GameCommands $cmds | Out-Null
        }
        if ( $script:RowSnapshots.ContainsKey($n) ) { $script:RowSnapshots.Remove($n) }
        Save-KeysBackup
        Set-Status "row $n edits applied"
    } catch { }
}
# крестик: откатить строку к снимку до правок
function Revert-RowEdits([int]$n) {
    try {
        if ( -not $script:RowSnapshots.ContainsKey($n) ) { return }
        $snap = $script:RowSnapshots[$n]
        foreach ( $r in $script:KeyRows ) {
            if ( $r.Num -eq $n ) {
                $r.X = $snap.X; $r.Y = $snap.Y; $r.Z = $snap.Z
                $r.Yaw = $snap.Yaw; $r.Pitch = $snap.Pitch
                $r.FOV = $snap.FOV; $r.Speed = $snap.Speed; $r.Time = $snap.Time
                break
            }
        }
        # время вернулось - вернуть и key-times
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        $sk = $snap.X.ToString('F1', $inv) + ";" + $snap.Y.ToString('F1', $inv) + ";" + $snap.Z.ToString('F1', $inv)
        if ( $snap.Time -match '^\d{2}:\d{2}:\d{2}$' ) { $script:KeyTimes[$sk] = $snap.Time }
        $script:RowSnapshots.Remove($n)
        $new = New-Object System.Collections.ArrayList
        foreach ( $r in $script:KeyRows ) { [void]$new.Add($r) }
        $script:KeyRows = $new
        Refresh-Table
        Set-Status "row $n edits reverted"
    } catch { }
}
$controls['DgKeys'].Add_MouseDoubleClick({
    $sel = $controls['DgKeys'].SelectedItem
    if ( $sel -eq $null ) { return }
    # v5.14: кадры с другой карты - переходить нельзя
    if ( $script:KeyMap -ne "" -and $script:CurrentMap -ne "" -and $script:KeyMap -ne $script:CurrentMap ) {
        $L = $script:LocData[$script:Lang]
        Set-Status $L.TipWrongMap
        return
    }
    Set-Status (Send-GameCommand "PathGoto $($sel.Num)")
})

# ---------- global hotkeys ----------

$window.Add_Loaded({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper $window
    $hwnd = $helper.Handle
    $src = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
    # id: 1=PathAdd(F8) 2=PathPlay(F9) 3=PathStop(F10) 4=SaveIni(F11) 5=ShowPanel(Ctrl+Alt+H)
    [GameCtl]::RegisterHotKey($hwnd, 1, 0, 0x77) | Out-Null
    [GameCtl]::RegisterHotKey($hwnd, 2, 0, 0x78) | Out-Null
    [GameCtl]::RegisterHotKey($hwnd, 3, 0, 0x79) | Out-Null
    [GameCtl]::RegisterHotKey($hwnd, 4, 0, 0x7A) | Out-Null
    [GameCtl]::RegisterHotKey($hwnd, 5, 3, 0x48) | Out-Null   # MOD_CONTROL|MOD_ALT + H
    $src.AddHook({
        param($hwnd, $msg, $wparam, $lparam, $handled)
        if ( $msg -eq 0x0312 )   # WM_HOTKEY
        {
            $id = $wparam.ToInt32()
            switch ($id) {
                1 { $window.Dispatcher.BeginInvoke([Action]{ Do-PathAdd }) | Out-Null }
                2 { $window.Dispatcher.BeginInvoke([Action]{ Do-PathPlay }) | Out-Null }
                3 { $window.Dispatcher.BeginInvoke([Action]{ $st = Send-GameCommand "PathStop"; Set-Playing $false; Set-Status $st }) | Out-Null }
                4 {
                    # F11 = PathClear + сброс ini + таблица
                    $window.Dispatcher.BeginInvoke([Action]{
                        $st = Send-GameCommand "PathClear"
                        Send-PathSaveAndSync $st
                    }) | Out-Null
                }
                5 {
                    # Ctrl+Alt+H = return the ghosted panel
                    $window.Dispatcher.BeginInvoke([Action]{
                        try {
                            $window.Topmost = $true
                            $window.Opacity = 1
                            $window.IsHitTestVisible = $true
                            $window.ShowInTaskbar = $true
                            $window.Show()
                            $window.Activate()
                        } catch { }
                    }) | Out-Null
                }
            }
            return [IntPtr]::Zero
        }
        return [IntPtr]::Zero
    })
    Set-Status "hotkeys: F8 add / F9 play / F10 stop / F11 clear / Ctrl+Alt+H panel"
    Sync-FromLog -Force
})

$window.Add_Closing({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper $window
    for ( $id = 1; $id -le 5; $id++ ) { [GameCtl]::UnregisterHotKey($helper.Handle, $id) | Out-Null }
})

# ---------- theme toggle (dark default) ----------
$script:DarkTheme = $true
$script:DarkBrushes = @{ BgBrush = "#F21E1E2E"; PanelBrush = "#FF313244"; TableBgBrush = "#FF181825"; AltRowBrush = "#FF313244"; TextBrush = "#FFCDD6F4"; MutedBrush = "#FFA6ADC8"; LineBrush = "#FF585B70"; StatusBrush = "#FF94E2D5"; StatusWarnBrush = "#FFFAB387"; DotBrush = "#FFA6E3A1"; SyncBrush = "#FF1F3D2E"; DirtyBrush = "#FF3A3F4D"; NavBrush = "#FF89DCEB"; HdrBrush = "#FF313244"; SelBrush = "#FF3D4A66" }
$script:LightBrushes = @{ BgBrush = "#F2E9EDF2"; PanelBrush = "#FFFFFFFF"; TableBgBrush = "#FFFFFFFF"; AltRowBrush = "#FFE9EDF3"; TextBrush = "#FF1E1E2E"; MutedBrush = "#FF5C6470"; LineBrush = "#FFB8BFCC"; StatusBrush = "#FF0B7285"; StatusWarnBrush = "#FFB45309"; DotBrush = "#FF2F9E44"; SyncBrush = "#FFD6F0DA"; DirtyBrush = "#FFE2E2E8"; NavBrush = "#FF0B7285"; HdrBrush = "#FFE4EAF3"; SelBrush = "#FFD8E6F8" }
function Set-Theme([bool]$dark) {
    $script:DarkTheme = $dark   # фикс: без этого оба клика вычисляли одну и ту же цель
    $map = $script:DarkBrushes
    if ( -not $dark ) { $map = $script:LightBrushes }
    foreach ( $k in $map.Keys ) {
        $window.Resources[$k] = [Windows.Media.SolidColorBrush][Windows.Media.ColorConverter]::ConvertFromString($map[$k])
    }
    # иконка = то, НА что переключаемся: в тёмной теме показываем солнце, в светлой - луну
    $controls['BtnTheme'].Content = "☀"
    if ( -not $dark ) { $controls['BtnTheme'].Content = "🌙" }
    # FOV/Fly speed боксы держат кисть напрямую - перерисовать под текущую тему
    Update-ParamBox "fov"
    Update-ParamBox "speed"
    # v5.17.7: Set-Status красит текст локальным значением (перебивает DynamicResource) -
    # после смены темы перекрашиваем статус текущей кистью того же цвета
    try {
        $sk = "StatusBrush"
        if ( $script:StatusKind -eq "warn" ) { $sk = "StatusWarnBrush" }
        $controls['TbStatus'].Foreground = $window.Resources[$sk]
    } catch { }
}
$controls['BtnTheme'].Add_Click({ Set-Theme (-not $script:DarkTheme) })

# v5.17.14 (#10): кнопка GitHub - открыть репозиторий
$controls['BtnGithub'].Add_Click({ Start-Process "https://github.com/BullDigga/hp2-machinima-tool" })

# v5.17.14 (#6): журнал логов - наведение на статус раскрывает попап с историей
# (строки со временем); закрытие с задержкой, чтобы курсор успел перейти в попап
$controls['TbStatus'].Add_MouseEnter({
    try {
        $controls['TbLogHistory'].Text = ($script:StatusLog -join "`n")
        $controls['TbLogHistory'].ScrollToEnd()
        $controls['LogPopup'].IsOpen = $true
    } catch { }
})
$script:LogCloseTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:LogCloseTimer.Interval = [TimeSpan]::FromMilliseconds(350)
$script:LogCloseTimer.Add_Tick({
    $script:LogCloseTimer.Stop()
    try {
        if ( -not $controls['LogPopupBorder'].IsMouseOver -and -not $controls['TbStatus'].IsMouseOver ) {
            $controls['LogPopup'].IsOpen = $false
        }
    } catch { }
})
$controls['TbStatus'].Add_MouseLeave({ $script:LogCloseTimer.Stop(); $script:LogCloseTimer.Start() })
$controls['LogPopupBorder'].Add_MouseEnter({ $script:LogCloseTimer.Stop() })
$controls['LogPopupBorder'].Add_MouseLeave({ $script:LogCloseTimer.Stop(); $script:LogCloseTimer.Start() })

# ---------- v5.8: кнопки, требующие выбранный кадр / наличие кадров ----------
$script:SelDep = @('BtnFovKey','BtnKeySpeed')
$script:KeysDep = @('BtnFovAll','BtnSpeedAll','BtnExport','BtnPathPlay','BtnPathPlaySpeed')
# v5.15: блокируется, пока игра не загружена на какой-либо карте
$script:NoGameDep = @('BtnHudHide','BtnPathAdd','BtnPathPlay','BtnPathPlaySpeed','BtnSetFov','BtnFovKey','BtnFovAll','BtnSpeed','BtnKeySpeed','BtnSpeedAll','BtnExport','BtnImport','TbFov','TbSpeed')
# v5.12: во время воспроизведения блокируется всё, кроме Стопа, Плея (повторного), поля
# секунд и Экспорта; тема/язык/прозрачность (UI) остаются доступны
$script:PlayLock = @('BtnPathAdd','BtnHudHide','BtnPathClear','BtnSetFov','BtnFovKey','BtnFovAll','BtnSpeed','BtnKeySpeed','BtnSpeedAll','BtnImport','BtnRefresh','TbFov','TbSpeed','DgKeys')
function Update-SelectionButtons {
    # v5.17.14 (#8): ветка ИГРАЕТ проверяется ПЕРВОЙ и безусловно - иначе синк или
    # 5.4с-полл со сбойным сканом (CurrentMap слетел в "") гасили Stop посреди
    # проигрывания, а через несколько секунд полл его возвращал
    if ( $script:Playing ) {
        foreach ( $b in $script:PlayLock ) {
            try { $controls[$b].IsEnabled = $false } catch { }
        }
        $controls['BtnExport'].IsEnabled = $true
        $controls['BtnPathStop'].IsEnabled = $true
        $controls['BtnPathPlay'].IsEnabled = $true
        $controls['BtnPathPlaySpeed'].IsEnabled = $true
        return
    }
    # v5.15: игра не на карте (закрыта или меню) - доступна только Прозрачность и поле
    # секунд; таблица с кадрами остаётся живой ради оффлайн-удаления
    $gameOn = ($script:CurrentMap -ne "")
    if ( -not $gameOn ) {
        $rowsLeft = ($script:KeyRows -ne $null -and $script:KeyRows.Count -gt 0)
        foreach ( $b in $script:NoGameDep ) {
            try { $controls[$b].IsEnabled = $false } catch { }
        }
        try {
            $controls['DgKeys'].IsEnabled = $rowsLeft
            $controls['BtnPathClear'].IsEnabled = $rowsLeft
        } catch { }
        $controls['BtnPathStop'].IsEnabled = $false
        $L = $null
        if ( $script:LocData -ne $null ) { $L = $script:LocData[$script:Lang] }
        if ( $L -ne $null ) {
            foreach ( $b in $script:NoGameDep ) {
                try { $controls[$b].ToolTip = $L.TipNoGame } catch { }
            }
        }
        return
    }
    $has = $controls['DgKeys'].SelectedItem -ne $null
    $n = 0
    if ( $script:KeyRows -ne $null ) { $n = $script:KeyRows.Count }
    # v5.14: кадры с другой карты - нельзя добавлять/воспроизводить/переходить
    $wrong = ($script:KeyMap -ne "" -and $script:CurrentMap -ne "" -and $script:KeyMap -ne $script:CurrentMap)
    if ( $wrong ) {
        foreach ( $b in ($script:SelDep + @('BtnPathAdd','BtnPathPlay','BtnPathPlaySpeed','BtnFovKey','BtnKeySpeed')) ) {
            try { $controls[$b].IsEnabled = $false } catch { }
        }
        # v5.17.7: цикл PlayLock выше перевключил Set FOV / Set fly speed - вернуть
        # серость по правилу "в поле уже применённое значение"
        Set-ParamBoxState "fov"
        Set-ParamBoxState "speed"
        $L = $null
        if ( $script:LocData -ne $null ) { $L = $script:LocData[$script:Lang] }
        if ( $L -ne $null ) {
            foreach ( $b in ($script:SelDep + @('BtnPathAdd','BtnPathPlay','BtnPathPlaySpeed')) ) {
                try { $controls[$b].ToolTip = $L.TipWrongMap } catch { }
            }
        }
        Set-Status ("keyframes are from '$($script:KeyMap)', but '$($script:CurrentMap)' is loaded - load the keyframe map or clear the table")
        return
    }
    foreach ( $b in $script:SelDep ) { $controls[$b].IsEnabled = $has }
    foreach ( $b in $script:KeysDep ) { $controls[$b].IsEnabled = ($n -gt 0) }
    $controls['BtnPathClear'].IsEnabled = ($n -gt 0)
    $controls['BtnPathStop'].IsEnabled = $false
    # v5.17.6: FOV->key / Speed->key серые, если выбранная строка УЖЕ имеет значение из поля
    try {
        $selRow = $controls['DgKeys'].SelectedItem
        if ( $selRow -ne $null ) {
            $fovTxt = $controls['TbFov'].Text.Trim()
            $spdTxt = $controls['TbSpeed'].Text.Trim()
            $controls['BtnFovKey'].IsEnabled = ( ($fovTxt -match '^\d+(\.\d+)?$') -and ([double]$fovTxt -ne $selRow.FOV) )
            $controls['BtnKeySpeed'].IsEnabled = ( ($spdTxt -match '^\d+(\.\d+)?$') -and ([double]$spdTxt -ne $selRow.Speed) )
        }
    } catch { }
    # v5.17.7: FOV->ALL / Speed->ALL серые, если во ВСЕХ кадрах уже стоит значение из
    # поля (сравниваем с тем, что реально уйдёт в игру - округлённый int, как в хендлерах)
    try {
        if ( $n -gt 0 ) {
            $fovTxt = $controls['TbFov'].Text.Trim()
            $spdTxt = $controls['TbSpeed'].Text.Trim()
            $fovOk = ($fovTxt -match '^\d+(\.\d+)?$')
            $spdOk = ($spdTxt -match '^\d+(\.\d+)?$')
            $sameFov = $fovOk
            $sameSpd = $spdOk
            foreach ( $r in $script:KeyRows ) {
                if ( $fovOk -and [double]([math]::Round([double]$fovTxt)) -ne $r.FOV ) { $sameFov = $false }
                if ( $spdOk -and [double]([math]::Round([double]$spdTxt)) -ne $r.Speed ) { $sameSpd = $false }
            }
            $controls['BtnFovAll'].IsEnabled = (-not $sameFov)
            $controls['BtnSpeedAll'].IsEnabled = (-not $sameSpd)
        }
    } catch { }
    # v5.17.7: Set FOV / Set fly speed - вернуть правило "в поле уже применённое значение":
    # цикл PlayLock в начале функции включил их принудительно
    Set-ParamBoxState "fov"
    Set-ParamBoxState "speed"
    $L = $null
    if ( $script:LocData -ne $null ) { $L = $script:LocData[$script:Lang] }
    if ( $L -ne $null ) {
        foreach ( $b in $script:KeysDep ) {
            $controls[$b].ToolTip = if ( $n -gt 0 ) { $null } else { $L.TipNeedKeys }
        }
        $controls['BtnPathStop'].ToolTip = $L.TipStop
    }
}
$controls['DgKeys'].Add_SelectionChanged({ Update-SelectionButtons })
# v5.17.6: клик по пустому месту таблицы (мимо строк) снимает выделение -
# кнопки редактирования и перехода сразу сереют
$controls['DgKeys'].AddHandler([System.Windows.UIElement]::MouseLeftButtonDownEvent, [System.Windows.Input.MouseButtonEventHandler]{
    param($s, $e)
    try {
        $hit = $controls['DgKeys'].InputHitTest($e.GetPosition($controls['DgKeys']))
        $cur = $hit
        $inRow = $false
        while ( $cur -ne $null ) {
            if ( $cur -is [System.Windows.Controls.DataGridRow] -or $cur -is [System.Windows.Controls.Primitives.ScrollBar] ) { $inRow = $true; break }
            $cur = [System.Windows.Media.VisualTreeHelper]::GetParent($cur)
        }
        if ( -not $inRow ) {
            $controls['DgKeys'].SelectedIndex = -1
            Update-SelectionButtons
        }
    } catch { }
}, $true)
Update-SelectionButtons

# ---------- v5.8: ресайз окна за кромки - WindowChrome (ResizeBorderThickness=10) ----------

# ---------- v5.11: крутящийся ⟳ (плавная WPF-анимация) + таймер завершения скана ----------
function Start-Spin {
    # v5.13: анимация на живом unfrozen-трансформе ($script:SpinTransform, создан в коде)
    try {
        if ( $script:SpinTransform -ne $null ) {
            $anim = [System.Windows.Media.Animation.DoubleAnimation]::new()
            $anim.From = 0
            $anim.To = 360
            $anim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds(1.1))
            $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $script:SpinTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $anim)
            # страховка: если анимация не завелась - тикает ручной fallback в UiTimer
            $script:SpinManual = (-not $script:SpinTransform.HasAnimatedProperties)
        } else {
            $script:SpinManual = $true
        }
    } catch { $script:SpinManual = $true }
}
function Stop-Spin {
    try {
        if ( $script:SpinTransform -ne $null ) {
            $script:SpinTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $null)
            $script:SpinTransform.Angle = 0
        }
    } catch { }
    $script:SpinManual = $false
}
$script:SpinManual = $false
$script:SpinAngle = 0
$script:GamePoll = 0
$script:UiTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:UiTimer.Interval = [TimeSpan]::FromMilliseconds(90)
$script:UiTimer.Add_Tick({
    # резервное вращение вручную (если анимация не завелась): пока идёт синк - шаг за тик
    if ( $script:SyncBusy -and $script:SpinManual -and $script:SpinTransform -ne $null ) {
        $script:SpinAngle = ($script:SpinAngle + 27) % 360
        $script:SpinTransform.Angle = $script:SpinAngle
    }
    if ( [MemScanPanel]::AsyncState -eq 2 ) { Complete-SyncFromLog }
    # v5.15.1: состояние игры опрашиваем раз в ~5.4с:
    # - игра вышла -> сброс карты/плей-состояния и лочка
    # - игра есть, уровень не определён -> полный рескан ловит MAP-событие уровня и разблокирует UI
    #   (иначе дедлок: кнопки заблокированы - синк сам не запустится)
    $script:GamePoll = ($script:GamePoll + 1) % 60
    if ( $script:GamePoll -eq 0 -and -not $script:SyncBusy ) {
        $g = Get-Process Game -ErrorAction SilentlyContinue
        if ( $g -eq $null ) {
            # v5.17.14 (#7): игра не запущена - статус КРАСНЫМ, постоянно (каждый полл)
            Set-Status $script:LocData[$script:Lang].TipNoWindow "err"
            if ( $script:CurrentMap -ne "" -or $script:Playing ) {
                $script:CurrentMap = ""
                if ( $script:Playing ) { Set-Playing $false }
                Update-SelectionButtons
            }
        } elseif ( $script:CurrentMap -eq "" ) {
            # v5.17.1: карта не определена - запрашиваем у игры снапшот: без -log буфер
            # крошечный и MAP-событие уровня в нём не выживает, а дамп несёт DUMPMAP.
            # v5.17.15: ПОЛЛ идёт мимо Confirm-GameActive - фоновые зонды не должны
            # воровать фокус и выходить из меню каждые 5.4с
            $script:ConfirmBypass = $true
            try { Send-GameCommand "PathDumpKeys" | Out-Null } finally { $script:ConfirmBypass = $false }
            Sync-FromLog -Force
        }
    }
})
$script:UiTimer.Start()

# ---------- localization (EN default / RU) ----------
$script:LocData = @{
    en = @{
        HudHide = "🙈  Hide HUD"; HudShow = "👁  Show HUD"
        AddKey = "📷  ADD KEYFRAME"
        PlayTime = "▶  PLAY by TIME"; Sec = "sec"
        PlaySpeed = "▶  Play"; Stop = "■  Stop"
        Keyframes = "▦ KEYFRAMES (click a cell to edit; eye = preview)"
        NoMap = "(no map)"; Map = "🗺 MAP"
        Export = "↗  Export to file"; Import = "↙  Import from file"
        Insert = "➕  Add keyframe after selected key"
        Fov = "📷 FOV"; FlySpeed = "✈ Fly speed"
        SetFov = "Set FOV"; FovKey = "🎯 FOV → key"; FovAll = "🌐 FOV → ALL"
        SetSpeed = "Set fly speed"; SpeedKey = "⚡ Speed → key"; SpeedAll = "🗂 Speed → ALL"
        Transparent = "Transparent"; HideBtn = "Hide"
        HkFrame = "  frame"; HkPlay = "  play"; HkStop = "  stop"; HkClear = "  clear"
        TipSelect = "Select a keyframe row in the table first"
        TipEdit = "Edit the value - the button unlocks when it differs from the applied one"
        TipNeedKeys = "Add at least one keyframe first (F8)"
        TipStop = "Nothing is playing right now"
        OneKey = "only 1 key - jumped to it"
        TipWrongMap = "Keyframes belong to a different map - load it or clear the table"
        TipNoGame = "The game is not running on a level - launch the game and load a map"
        TipInsertRow = "insert CURRENT camera keyframe here (between this and the previous row)"
        TipGotoRow = "preview this keyframe (jump the camera to it)"
        TipDelRow = "delete this keyframe"
        TipRefresh = "Full table resync (full memory scan)"
        TipClear = "Clear table (delete ALL keyframes)"
        TipHide = "Hide panel (Ctrl+Alt+H - return)"
        TipLang = "Language"
        TipGithub = "Open the GitHub repository"
        TipNoWindow = "can't see the game window"
        TipInMenu = "the game is in the menu - load a map first"
        TipAcceptRow = "apply this row's edits (FOV/speed go to the game)"
        TipCancelRow = "revert this row's edits"
        LoadMapQ = "This file is for map '{0}', but '{1}' is loaded.`nLoad '{0}' and import?"
        LoadMapTitle = "Different map"
    }
    ru = @{
        HudHide = "🙈  Скрыть HUD"; HudShow = "👁  Показать HUD"
        AddKey = "📷  ДОБАВИТЬ КАДР"
        PlayTime = "▶  ВОСПРОИЗВЕСТИ по времени"; Sec = "сек"
        PlaySpeed = "▶  Проиграть (по скоростям)"; Stop = "■  Стоп"
        Keyframes = "▦ КАДРЫ (клик по ячейке = правка; глаз = превью)"
        NoMap = "(нет карты)"; Map = "🗺 КАРТА"
        Export = "↗  Экспорт в файл"; Import = "↙  Импорт из файла"
        Insert = "➕  Добавить кадр после выбранного"
        Fov = "📷 FOV"; FlySpeed = "✈ Скорость полёта"
        SetFov = "Задать FOV"; FovKey = "🎯 FOV → кадр"; FovAll = "🌐 FOV → ВСЕ"
        SetSpeed = "Задать скорость"; SpeedKey = "⚡ Скор. → кадр"; SpeedAll = "🗂 Скор. → ВСЕ"
        Transparent = "Прозрачность"; HideBtn = "Скрыть"
        HkFrame = "  кадр"; HkPlay = "  воспроизв."; HkStop = "  стоп"; HkClear = "  очистка"
        TipSelect = "Сначала выберите кадр в таблице (клик по строке)"
        TipEdit = "Измените значение - кнопка станет активной, когда оно отличается от применённого"
        TipNeedKeys = "Сначала добавьте хотя бы один кадр (F8)"
        TipStop = "Сейчас ничего не воспроизводится"
        OneKey = "всего один кадр - перешли к нему"
        TipWrongMap = "Кадры с другой карты - загрузите её или очистите таблицу"
        TipNoGame = "Игра не запущена на уровне - запусти игру и выбери карту"
        TipInsertRow = "вставить ТЕКУЩИЙ кадр камеры сюда (между этой и предыдущей строкой)"
        TipGotoRow = "посмотреть, как выглядит этот кадр (камера перейдёт к нему)"
        TipDelRow = "удалить этот кадр"
        TipRefresh = "Полный ре-синк таблицы (полное сканирование памяти)"
        TipClear = "Очистить таблицу (удалить ВСЕ кадры)"
        TipHide = "Скрыть панель (Ctrl+Alt+H - вернуть)"
        TipLang = "Язык"
        TipGithub = "Открыть репозиторий на GitHub"
        TipNoWindow = "не видно активного окна игры"
        TipInMenu = "игра в меню - сначала загрузи карту"
        TipAcceptRow = "применить правки этой строки (FOV/скорость уйдут в игру)"
        TipCancelRow = "откатить правки этой строки"
        LoadMapQ = "Файл для карты '{0}', сейчас запущена '{1}'.`nЗагрузить '{0}' и импортировать?"
        LoadMapTitle = "Другая карта"
    }
}
$script:Lang = "en"
function Set-Lang([string]$lang) {
    $script:Lang = $lang
    $L = $script:LocData[$lang]
    # v5.17.11.8: тултипы кнопок ВНУТРИ DataTemplate (плюсики/глаз/корзина на строках)
    # локализуются через ресурсы окна: в шаблоне - DynamicResource, а на поимённые
    # кнопки из PS не попасть (строки генерируются)
    foreach ( $kv in @('TipInsertRow','TipGotoRow','TipDelRow','TipRefresh','TipClear','TipHide','TipLang','TipGithub') ) {
        try { $window.Resources[$kv] = $L.$kv } catch { }
    }
    Update-HudButton
    $controls['BtnPathAdd'].Content = $L.AddKey
    $controls['BtnPathPlay'].Content = $L.PlayTime
    $controls['BtnPathPlaySpeed'].Content = $L.PlaySpeed
    if ( -not $script:Playing ) { $controls['BtnPathStop'].Content = $L.Stop }
    $controls['BtnExport'].Content = $L.Export
    $controls['BtnImport'].Content = $L.Import
    $controls['BtnSetFov'].Content = $L.SetFov
    $controls['BtnFovKey'].Content = $L.FovKey
    $controls['BtnFovAll'].Content = $L.FovAll
    $controls['BtnSpeed'].Content = $L.SetSpeed
    $controls['BtnKeySpeed'].Content = $L.SpeedKey
    $controls['BtnSpeedAll'].Content = $L.SpeedAll
    $controls['CbTransparent'].Content = $L.Transparent
    $controls['TxHkFrame'].Text = $L.HkFrame
    $controls['TxHkPlay'].Text = $L.HkPlay
    $controls['TxHkStop'].Text = $L.HkStop
    $controls['TxHkClear'].Text = $L.HkClear
    $controls['TxFramesLabel'].Text = $L.Keyframes
    $controls['TbMapLabel'].Text = $L.Map
    $controls['TxSec'].Text = $L.Sec
    $controls['TxFlySpeed'].Text = $L.FlySpeed
    $controls['TbMap'].Text = Get-MapText
    Update-MapPreview
    # подсказки на серых кнопках
    foreach ( $b in @('BtnFovKey','BtnKeySpeed') ) { $controls[$b].ToolTip = $L.TipSelect }
    foreach ( $b in @('BtnSetFov','BtnSpeed') ) { $controls[$b].ToolTip = $L.TipEdit }
    $controls['FlagEN'].Visibility = if ( $lang -eq "en" ) { "Visible" } else { "Collapsed" }
    $controls['FlagRU'].Visibility = if ( $lang -eq "ru" ) { "Visible" } else { "Collapsed" }
    Save-Settings
}
# выпадающий список языков по клику на флаг
$controls['BtnLang'].Add_Click({
    $cm = $controls['BtnLang'].ContextMenu
    $cm.PlacementTarget = $controls['BtnLang']
    $cm.Placement = "Bottom"
    $cm.IsOpen = $true
})
foreach ( $mi in @($controls['BtnLang'].ContextMenu.Items) ) {
    $mi.Add_Click({
        param($s, $e)
        $tag = ""
        try { $tag = [string]$e.OriginalSource.Tag } catch { }
        if ( $tag -eq "" ) { try { $tag = [string]$s.Tag } catch { } }
        if ( $tag -eq "en" -or $tag -eq "ru" ) {
            $script:PendingLang = $tag
            $window.Dispatcher.BeginInvoke([Action]{ Set-Lang $script:PendingLang }) | Out-Null
        }
    })
}

# ---------- settings: тема + язык переживают перезапуск панели ----------
$script:SettingsFile = Join-Path $PSScriptRoot "settings.json"
function Save-Settings {
    try {
        @{ theme = $(if ( $script:DarkTheme ) { "dark" } else { "light" }); lang = $script:Lang } |
            ConvertTo-Json | Set-Content -Path $script:SettingsFile -Encoding UTF8
    } catch { }
}
$script:StartTheme = "dark"
$script:StartLang = "en"
try {
    $s = Get-Content $script:SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json
    if ( $s.theme -eq "light" ) { $script:StartTheme = "light" }
    if ( $s.lang -eq "ru" ) { $script:StartLang = "ru" }
} catch { }
Set-Theme ($script:StartTheme -eq "dark")
Set-Lang $script:StartLang

# ---------- owl icon ----------
# v5.13: стрелка обновления - глиф "Refresh" из Segoe MDL2 + СВЕЖИЙ unfrozen-трансформ.
# XAML-трансформ от XamlReader заморожен - BeginAnimation на нём бросал исключение
# (catch глотал), поэтому анимация не стартовала и крутился только ручной fallback.
try {
    $tbR = $controls['BtnRefresh'].Content
    $tbR.FontFamily = New-Object Windows.Media.FontFamily("Segoe MDL2 Assets")
    $tbR.Text = [char]::ConvertFromUtf32(0xE72C)
    $tbR.FontSize = 16
    $script:SpinTransform = [System.Windows.Media.RotateTransform]::new()
    $tbR.RenderTransform = $script:SpinTransform
    $tbR.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
} catch { }
$owlPath = Join-Path $PSScriptRoot "owl.png"
if ( Test-Path $owlPath ) {
    try {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.UriSource = (New-Object Uri($owlPath))
        $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $bmp.Freeze()
        $controls['ImgOwl'].Source = $bmp
    } catch { }
}

# v5.17.10: иконка окна/таскбара - сова (Panel/icon.png); без неё таскбар показывает
# дефолтный значок PowerShell, что мешает найти панель после Hide-ghost
$iconPath = Join-Path $PSScriptRoot "icon.png"
if ( Test-Path $iconPath ) {
    try {
        $iconBmp = New-Object Windows.Media.Imaging.BitmapImage
        $iconBmp.BeginInit()
        $iconBmp.UriSource = (New-Object Uri($iconPath))
        $iconBmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $iconBmp.EndInit()
        $iconBmp.Freeze()
        $window.Icon = $iconBmp
    } catch { }
}

# v5.17: при старте панели запрашиваем у игры снапшот пути: таблица строится из
# дампа, а не из уцелевших обрывков кольцевого лог-буфера (иначе - фантомные кадры)
if ( (Get-Process Game -ErrorAction SilentlyContinue) -ne $null ) {
    Send-GameCommand "PathDumpKeys" | Out-Null
    Sync-FromLog -Force
}
# v5.17.17: таблица пуста (игра закрыта/крашнулась) - восстанавливаем кадры из
# автосейва: в панели они живут, пока пользователь сам их не удалит
if ( $script:KeyRows.Count -eq 0 ) { Restore-KeysBackup }

# v5.17.3: необработанные исключения dispatcher'а -> crash.log (панель молча умирала)
$window.Dispatcher.add_UnhandledException({
    param($s, $a)
    try {
        $msg = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] Dispatcher: " + $a.Exception.GetType().FullName + ": " + $a.Exception.Message + "`r`n" + $a.Exception.StackTrace + "`r`n---`r`n"
        [System.IO.File]::AppendAllText((Join-Path $PSScriptRoot "crash.log"), $msg)
    } catch { }
    $a.Handled = $true
})

$window.ShowDialog() | Out-Null


