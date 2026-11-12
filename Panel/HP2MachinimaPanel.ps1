# HP2 Machinima Panel v3 - global hotkeys + always-on-top panel
# Hotkeys work WHILE THE GAME IS FOCUSED (no focus switching needed):
#   F8  = PathAdd        F9 = PathPlay (seconds box)
#   F10 = PathStop       F11 = SaveIni (persist + panel table refresh)
# Panel buttons send commands too (they activate the game window first).

$ErrorActionPreference = "Stop"

# v5.17.27: кэш C#-хелперов (Panel\cache\*.dll) - без него КАЖДЫЙ старт панели
# гоняет csc.exe по всем блокам ниже (~30-40 сек "панель долго открывается").
# Первый старт ещё компилирует и сохраняет DLL, дальше типы грузятся с диска
function Add-TypeCached {
    param([string]$TypeName, [string]$Source, [string[]]$Refs = @())
    if ( $TypeName -as [type] ) { return }
    $dir = Join-Path $PSScriptRoot "cache"
    try {
        if ( -not (Test-Path $dir) ) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $dll = Join-Path $dir (($TypeName -replace '[^A-Za-z0-9_.]', '_') + ".dll")
        if ( Test-Path $dll ) {
            try { Add-Type -Path $dll } catch { }
            if ( $TypeName -as [type] ) { return }
        }
        if ( $Refs.Count -gt 0 ) { Add-Type -TypeDefinition $Source -ReferencedAssemblies $Refs -OutputAssembly $dll | Out-Null }
        else { Add-Type -TypeDefinition $Source -OutputAssembly $dll | Out-Null }
        if ( -not ($TypeName -as [type]) ) { throw ("type not available after compile: " + $TypeName) }
    } catch {
        if ( $Refs.Count -gt 0 ) { Add-Type -TypeDefinition $Source -ReferencedAssemblies $Refs | Out-Null }
        else { Add-Type -TypeDefinition $Source | Out-Null }
    }
}

# v5.17.10.1: свой AppUserModelID ДО любого окна - без него таскбар приколачивает
# кнопку панели к AUMID powershell.exe и показывает его значок, игнорируя Window.Icon
Add-TypeCached -TypeName 'ShellId' -Source @"
using System;
using System.Runtime.InteropServices;
public static class ShellId {
    [DllImport("shell32.dll", SetLastError=false)]
    public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
}
"@
[ShellId]::SetCurrentProcessExplicitAppUserModelID("BullDigga.HP2MachinimaPanel") | Out-Null

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

Add-TypeCached -TypeName 'GameCtl' -Source @"
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

Add-TypeCached -TypeName 'KeyRow' -Source @"
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

Add-TypeCached -TypeName 'MemScanPanel' -Source @"
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
            var seenL = new System.Collections.Generic.HashSet<long>();
            long pos = 0;
            while ( pos < regS ) {
                int toRead = (int)Math.Min(regS - pos + overlap, buf.Length);
                if ( toRead > regS - pos && regS - pos < buf.Length ) toRead = (int)(regS - pos);
                IntPtr rd;
                if ( ReadProcessMemory(h, (IntPtr)(regA + pos), buf, (IntPtr)toRead, out rd) ) {
                    int n = rd.ToInt32();
                    string s = System.Text.Encoding.Unicode.GetString(buf, 0, n);
                    var evIdx = new System.Collections.Generic.List<int>();
                    var evGen = new System.Collections.Generic.List<int>();
                    for ( int i = s.IndexOf("PATHEV:"); i >= 0; i = s.IndexOf("PATHEV:", i + 7) ) {
                        long abs = (pos >> 1) + i;
                        if ( !seen.Add(abs) ) continue;
                        int en = i;
                        while ( en < s.Length && s[en] >= 32 ) en++;
                        sb.Append(s.Substring(i, en - i) + "\n");
                        // gen каждого события - привязка для PLVL-строк (v5.17.29)
                        int q = i + 7;
                        long gv = 0; bool gok = false;
                        while ( q < en && s[q] >= '0' && s[q] <= '9' ) { gok = true; gv = gv * 10 + (s[q] - '0'); q++; }
                        if ( gok ) { evIdx.Add(i); evGen.Add(gv > int.MaxValue ? int.MaxValue : (int)gv); }
                    }
                    // v5.17.29: смена уровня ВО ВРЕМЯ ИГРЫ (переходы-триггеры, die-телепорт)
                    // НЕ пишет MAP-событие - поколение инкрементируется, а имя уровня нигде
                    // нет. Движок при каждой загрузке уровня пишет в лог
                    // "Possessed PlayerPawn: <pawn> <Map>.<Actor>" - выгружаем как
                    // PLVL:<gen>|<map>, где gen = поколение СЛЕДУЮЩЕГО PATHEV-события
                    // (строка пишется сразу после загрузки нового уровня). Строки формата
                    // ("%s..." в статических таблицах) отсекаются проверкой charset пешки
                    // и обязательным "Possessed " перед "PlayerPawn: ".
                    // v5.17.30.3: если ПОСЛЕ строки PATHEV в этой копии буфера нет (панель
                    // ещё не слала команд: смерть на уровне без зондов - CurrentMap не
                    // пуст, полл-ветка с PathDumpKeys молчит), берём gen ПОСЛЕДНЕГО
                    // PATHEV ДО строки + 1: движок инкрементирует поколение ЗАГРУЗКОЙ
                    // уровня, Possessed пишется сразу после инкремента - детерминированно
                    int l = s.IndexOf("Possessed PlayerPawn: ");
                    while ( l >= 0 ) {
                        long labs = (pos >> 1) + l;
                        if ( seenL.Add(labs) && l >= 12 ) {
                            int ws = l + 22, we = ws;
                            while ( we < s.Length && s[we] > 32 && s[we] != '%' ) we++;
                            if ( we > ws && we < s.Length && s[we] == 32 ) {
                                int ms2 = we + 1, me2 = ms2;
                                while ( me2 < s.Length && (char.IsLetterOrDigit(s[me2]) || s[me2] == '_') ) me2++;
                                if ( me2 > ms2 && me2 < s.Length && s[me2] == '.' ) {
                                    int gidx = -1;
                                    for ( int k2 = 0; k2 < evIdx.Count; k2++ ) { if ( evIdx[k2] > l ) { gidx = k2; break; } }
                                    long gOut = -1;
                                    if ( gidx >= 0 ) gOut = evGen[gidx];
                                    else if ( evGen.Count > 0 ) gOut = (long)evGen[evGen.Count - 1] + 1;   // v5.17.30.3
                                    if ( gOut >= 0 ) sb.Append("PLVL:" + gOut + "|" + s.Substring(ms2, me2 - ms2) + "\n");
                                }
                            }
                        }
                        l = s.IndexOf("Possessed PlayerPawn: ", l + 22);
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
            var seenL = new System.Collections.Generic.HashSet<long>();
            long pos = 0;
            while ( pos < regS ) {
                int toRead = (int)Math.Min(regS - pos + overlap, buf.Length);
                if ( toRead > regS - pos && regS - pos < buf.Length ) toRead = (int)(regS - pos);
                IntPtr rd;
                if ( ReadProcessMemory(h, (IntPtr)(regA + pos), buf, (IntPtr)toRead, out rd) ) {
                    int n = rd.ToInt32();
                    string s = System.Text.Encoding.Unicode.GetString(buf, 0, n);
                    var evIdx = new System.Collections.Generic.List<int>();
                    var evGen = new System.Collections.Generic.List<int>();
                    for ( int i = s.IndexOf("PATHEV:"); i >= 0; i = s.IndexOf("PATHEV:", i + 7) ) {
                        long abs = (pos >> 1) + i;
                        if ( !seen.Add(abs) ) continue;
                        int en = i;
                        while ( en < s.Length && s[en] >= 32 ) en++;
                        sb.Append(s.Substring(i, en - i) + "\n");
                        // gen каждого события - привязка для PLVL-строк (v5.17.29)
                        int q = i + 7;
                        long gv = 0; bool gok = false;
                        while ( q < en && s[q] >= '0' && s[q] <= '9' ) { gok = true; gv = gv * 10 + (s[q] - '0'); q++; }
                        if ( gok ) { evIdx.Add(i); evGen.Add(gv > int.MaxValue ? int.MaxValue : (int)gv); }
                    }
                    // v5.17.29: смена уровня ВО ВРЕМЯ ИГРЫ (переходы-триггеры, die-телепорт)
                    // НЕ пишет MAP-событие - поколение инкрементируется, а имя уровня нигде
                    // нет. Движок при каждой загрузке уровня пишет в лог
                    // "Possessed PlayerPawn: <pawn> <Map>.<Actor>" - выгружаем как
                    // PLVL:<gen>|<map>, где gen = поколение СЛЕДУЮЩЕГО PATHEV-события
                    // (строка пишется сразу после загрузки нового уровня). Строки формата
                    // ("%s..." в статических таблицах) отсекаются проверкой charset пешки
                    // и обязательным "Possessed " перед "PlayerPawn: ".
                    // v5.17.30.3: если ПОСЛЕ строки PATHEV в этой копии буфера нет (панель
                    // ещё не слала команд: смерть на уровне без зондов - CurrentMap не
                    // пуст, полл-ветка с PathDumpKeys молчит), берём gen ПОСЛЕДНЕГО
                    // PATHEV ДО строки + 1: движок инкрементирует поколение ЗАГРУЗКОЙ
                    // уровня, Possessed пишется сразу после инкремента - детерминированно
                    int l = s.IndexOf("Possessed PlayerPawn: ");
                    while ( l >= 0 ) {
                        long labs = (pos >> 1) + l;
                        if ( seenL.Add(labs) && l >= 12 ) {
                            int ws = l + 22, we = ws;
                            while ( we < s.Length && s[we] > 32 && s[we] != '%' ) we++;
                            if ( we > ws && we < s.Length && s[we] == 32 ) {
                                int ms2 = we + 1, me2 = ms2;
                                while ( me2 < s.Length && (char.IsLetterOrDigit(s[me2]) || s[me2] == '_') ) me2++;
                                if ( me2 > ms2 && me2 < s.Length && s[me2] == '.' ) {
                                    int gidx = -1;
                                    for ( int k2 = 0; k2 < evIdx.Count; k2++ ) { if ( evIdx[k2] > l ) { gidx = k2; break; } }
                                    long gOut = -1;
                                    if ( gidx >= 0 ) gOut = evGen[gidx];
                                    else if ( evGen.Count > 0 ) gOut = (long)evGen[evGen.Count - 1] + 1;   // v5.17.30.3
                                    if ( gOut >= 0 ) sb.Append("PLVL:" + gOut + "|" + s.Substring(ms2, me2 - ms2) + "\n");
                                }
                            }
                        }
                        l = s.IndexOf("Possessed PlayerPawn: ", l + 22);
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

function Type-Command([string]$cmd, [IntPtr]$hGame) {
    # unicode-ввод: не зависит от раскладки клавиатуры.
    # v5.17.2: 20мс/символ и 260мс после Enter - при быстрой печати длинных пачек команд
    # (импорт) консоль теряла символы и Enters, значения кадров мутировали
    # v5.17.30.4: КРИТИЧНО - пауза на символе БЕЗ прокачки dispatcher'а. Wait-Pump
    # на каждом символе выполнял ВСЮ накопленную очередь (полл-синк каждые 5.4с =
    # тяжёлый парс событий на UI-потоке) - буквы шли по одной раз в 5-10с (юзер
    # видел "будто я сам печатаю медленно"). Спиннер во время печати может
    # подмёрзнуть - это цена корректности ввода; между командами (260мс после
    # Enter) прокачка остаётся
    # v5.17.30.6: ФОКУС НА КАЖДОМ СИМВОЛЕ (юзер: "Alt-Tab - продолжает печататься
    # в другом окне, это критично"). Проверка фокуса была раз в КОМАНДУ - остаток
    # команды допечатывался в чужое окно. Теперь: фокус ушёл => СРАЗУ стоп (окно
    # утечки сужено до одного символа/20мс) и БЕЗ рефокуса - юзер сознательно
    # ушёл Alt-Tab'ом, выдёргивать его обратно нельзя. Родительский цикл видит
    # SendFocusLost и прерывает пачку
    foreach ($ch in $cmd.ToCharArray()) {
        if ( [GameCtl]::GetForegroundWindow() -ne $hGame ) {
            $script:SendFocusLost = $true
            return
        }
        [GameCtl]::TapChar($ch)
        Start-Sleep -Milliseconds 20
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
$script:SendDepth = 0     # v5.17.30.4: защита от втиснутых отправок поверх живой
$script:SendFocusLost = $false  # v5.17.30.6: фокус ушёл посреди печати команды
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
        # v5.17.28.3: без вьюпорта (меню/загрузка) уровня нет - фокус не трогаем,
        # ждём не циклом, а честным отказом (зонд всё равно не напечатается)
        $vw2 = [GameCtl]::FindWindowW("GameUnrealWWindowsViewportWindow", [NullString]::Value)
        if ( $vw2 -eq [IntPtr]::Zero ) {
            Set-Status $script:LocData[$script:Lang].TipInMenu "err"
            return $false
        }
        $h = $vw2
        Focus-GameWindow $h | Out-Null
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
    if ( $script:SendBusy ) {
        # v5.17.30.1: отказ был НЕВИДИМ - статус "typing..." оставался висеть, юзер
        # жаловался "кадр не добавляется". Показываем warn прямо в статус
        Set-Status "busy: the previous command is still sending - try again in a moment" "warn"
        return "busy - command still sending"
    }
    # v5.17.30.4: РЕЕНТЕР-ГВАРД. Watchdog может сбросить SendBusy живой отправки -
    # новая команда тогда стартует ВНУТРИ Wait-Pump старой (прокачка!) и ДВЕ печати
    # идут вперемешку - команды портятся посимвольно ("перестал карты грузить").
    # Глубина защищает от этого независимо от состояния флага
    if ( $script:SendDepth -gt 0 ) {
        Set-Status "busy: another send is still typing (re-entry blocked)" "warn"
        return "busy - re-entry blocked"
    }
    if ( -not $script:ConfirmBypass -and -not (Confirm-GameActive) ) { return "aborted: game not on a level" }
    # v5.17.27: фоновые зонды (ConfirmBypass: старт панели, 5.4с-полл в меню) обязаны
    # сфокусировать игру ради консоли, но не должны УВОДИТЬ фокус - жалоба юзера
    # "перед панелью открывается Гарри Поттер". Запоминаем активное окно и возвращаем
    # его после печати (жёсткий SetForegroundWindow после Alt-тапа, как в Focus-GameWindow)
    $fgSaved = [IntPtr]::Zero
    if ( $script:ConfirmBypass ) { $fgSaved = [GameCtl]::GetForegroundWindow() }
    $script:SendBusy = $true
    $script:SendDepth = $script:SendDepth + 1
    $script:SendStartedAt = Get-Date
    try {
        Start-Spin   # v5.11: крутится СРАЗУ при клике, не после отправки команды
        # v5.17.7: оранжевый debug-статус СРАЗУ при клике - что и сколько печатаем
        $dbg = if ( $cmds.Count -gt 0 ) { [string]$cmds[0] } else { "" }
        if ( $dbg.Length -gt 42 ) { $dbg = $dbg.Substring(0, 42) + "..." }
        Set-Status ("typing $($cmds.Count) cmd(s): $dbg") "warn"
        $h = Find-GameWindow
        if ($h -eq [IntPtr]::Zero) { Stop-Spin; return "game window not found!" }
        # v5.17.28.3: КРИТИЧНО - печатаем ТОЛЬКО в окно вьюпорта (окно уровня).
        # В меню фронтенда вьюпорта нет, а Find-GameWindow тогда возвращает окно
        # "Main" - и буквы команды падали прямо в поля меню (юзер видел "thD" в
        # поле GState). Нет вьюпорта = игра не на уровне = не печатаем ничего
        $vw = [GameCtl]::FindWindowW("GameUnrealWWindowsViewportWindow", [NullString]::Value)
        if ( $vw -eq [IntPtr]::Zero -or $vw -ne $h ) {
            Stop-Spin
            return "game is not on a level (no viewport window) - typing skipped"
        }
        if ( -not (Focus-GameWindow $h) ) { Stop-Spin; return "could not focus the game - click the game window once" }
        # v5.13: ОТКРЫТИЕ консоли панелью - Shift+` (тихая ветка KeyEvent, окно за экраном).
        # Обычный ` остаётся терминалом пользователя.
        # v5.17.30.4: ЖИВОЙ ФАКТ - ПЕРВАЯ команда пачки печаталась в ещё закрытую
        # консоль и уходила в геймплей (буфер: 4x PathClear потеряно при дошедших
        # финальных PathPing; open карт - та же история: "перестал грузить карты").
        # Паузы 450/1200мс НЕ помогли => лаг открытия нестабилен. Надёжное решение:
        # ТРОЙНОЙ ensure-open. Ветка Shift+` в HPConsole ИДЕМПОТЕНТНА (повтор при
        # уже открытой консоли ничего не закрывает - только LaunchUWindow/ShowConsole
        # снова) - три тапа с паузами гарантируют открытие независимо от лагов
        [GameCtl]::KeyDown([uint16]0x10)
        [GameCtl]::Tap([uint16]$VK['grave'])
        [GameCtl]::KeyUp([uint16]0x10)
        Wait-Pump 350
        [GameCtl]::KeyDown([uint16]0x10)
        [GameCtl]::Tap([uint16]$VK['grave'])
        [GameCtl]::KeyUp([uint16]0x10)
        Wait-Pump 350
        [GameCtl]::KeyDown([uint16]0x10)
        [GameCtl]::Tap([uint16]$VK['grave'])
        [GameCtl]::KeyUp([uint16]0x10)
        Wait-Pump 350
        # v5.17.8: прогресс [i/N] с бегущими точками + проверка фокуса ПЕРЕД КАЖДОЙ командой.
        # Alt-Tab во время пачки (импорт) печатал остаток команд в ЧУЖОЕ окно, а консоль игры
        # оставалась открытой (чёрный экран). Теперь: фокус потерян -> один тихий рефокус,
        # не вышло -> чистый ABORT (ничего не печатаем дальше), пользователь видит [i/N].
        $ci = 0
        $res = ""
        $script:SendFocusLost = $false
        foreach ($c in $cmds) {
            # v5.17.30.4: само-прерывание застрявшей отправки - watchdog полла (60с)
            # сбрасывает флаг, но ЦИКЛ старой отправки продолжает жить и печатать;
            # теперь цикл умирает сам до того, как новая отправка начнёт мешать
            if ( $script:SendStartedAt -ne $null -and ((Get-Date) - $script:SendStartedAt).TotalSeconds -gt 50 ) {
                $res = "send timed out at [$($ci+1)/$($cmds.Count)] - aborted (stale typing stopped)"
                break
            }
            $dots = "." * (1 + ($ci % 3))
            Set-Status ("typing [$($ci+1)/$($cmds.Count)] $c $dots") "warn"
            # v5.17.30.6: фокус потерян => ЧИСТЫЙ abort БЕЗ рефокуса (Alt-Tab юзера -
            # сознательное действие, выдёргивать фокус обратно нельзя; остаток пачки
            # не печатается, Type-Command сам остановился на первом символе не в игру)
            if ( [GameCtl]::GetForegroundWindow() -ne $h ) {
                $res = "ABORTED at [$($ci+1)/$($cmds.Count)] - you switched away from the game; typing stopped, no keys were sent to other windows"
                break
            }
            Type-Command $c $h
            if ( $script:SendFocusLost ) {
                $res = "ABORTED mid-command [$($ci+1)/$($cmds.Count)] - you Alt-Tabbed; typing stopped (at most 1 char may have slipped)"
                break
            }
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
        # v5.17.30.2: замер длительности отправки. Живой факт: отправка open из
        # пикера ВИСЛА ~2 мин при норме ~5с (SendBusy всё это время отбивал новые
        # команды "busy", юзер видел "ничего не происходит"). Где блокируется -
        # покажет длительность в статусе
        $dur = [int]((Get-Date) - $script:SendStartedAt).TotalMilliseconds
        return ("$($cmds.Count) cmds OK ${dur}ms  " + (Get-Date -Format HH:mm:ss))
    } finally {
        $script:SendBusy = $false
        $script:SendDepth = [Math]::Max(0, $script:SendDepth - 1)
        try {
            if ( $fgSaved -ne [IntPtr]::Zero -and [GameCtl]::GetForegroundWindow() -ne $fgSaved ) {
                [GameCtl]::Tap(0x12) | Out-Null
                [GameCtl]::SetForegroundWindow($fgSaved) | Out-Null
            }
        } catch { }
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
# v5.17.30: подкнопка "вернуться к кадрам" - флаги перехода и прибытия
$script:KeyMapGoClicked = $false
$script:KeyMapGoArrived = $false
# v5.17.30.5: CLEAR виделся в буфере игры за сессию панели (явная очистка юзером)
$script:SawClearInBuffer = $false
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
    $gpChk = Get-Process Game -ErrorAction SilentlyContinue | Select-Object -First 1
    # v5.17.28.4: фронтенд при "Play Map!" ПЕРЕЗАПУСКАЕТ игру новым процессом.
    # Если асинхронный скан висел на старом pid, Complete-SyncFromLog никогда
    # не придёт - SyncBusy/SendBusy зависают навсегда и панель перестаёт видеть
    # игру ("я в игре, а панель всё серое"). Сброс зависших флагов:
    if ( $gpChk -ne $null -and $script:ScanCache.Pid -ne 0 -and $script:ScanCache.Pid -ne $gpChk.Id ) {
        $script:SyncBusy = $false
        $script:SendBusy = $false
        $script:ScanCache.Pid = 0
        $script:ScanCache.Regions = @()
        # КРИТИЧНО (v5.17.28.5): новый процесс начинает seq с 1 - старый LastSeq
        # (сотни событий прошлого сеанса) отбрасывал ВЕСЬ дамп фильтром
        # "newMax <= LastSeq" наверху синка, и карта никогда не определялась.
        $script:ScanCache.LastSeq = 0
        $script:LastGen = 0
        $Force = $true
    }
    # защита от зависшего скана на ТОМ ЖЕ pid (процесс умер посреди чтения памяти)
    if ( $script:SyncBusy ) {
        if ( $script:SyncStartedAt -ne $null -and ((Get-Date) - $script:SyncStartedAt).TotalSeconds -gt 20 ) {
            $script:SyncBusy = $false
            $Force = $true
        } else { return $false }
    }
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
    $script:SyncStartedAt = Get-Date
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
            $newGen = 0
            $hadEv = $false
            foreach ( $mm in [regex]::Matches($txt, 'PATHEV:(\d+):(\d+)\|') ) {
                $hadEv = $true
                $g = [long]$mm.Groups[1].Value
                $v = [long]$mm.Groups[2].Value
                # v5.17.30: максимум по паре (gen,seq), НЕ по голому seq. Смена уровня
                # сбрасывает seq в 1 - новые события (gen N+1, seq 1-2) были "меньше"
                # старого LastSeq (сотни seq прошлого уровня), фильтр отбрасывал весь
                # дамп, и панель не видела загрузку новой карты до полного рескана
                if ( ($g -gt $newGen) -or ($g -eq $newGen -and $v -gt $newMax) ) {
                    $newGen = $g; $newMax = $v
                }
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
            if ( $newGen -gt $script:LastGen ) { $script:ScanCache.LastSeq = 0 }
            if ( $newMax -le $script:ScanCache.LastSeq ) { $txt = ""; $src = "" }
        }
    }
    # v5.17.30.4: ДЕШЁВЫЙ гейт свежести ПЕРЕД тяжёлым парсом. Полные сканы всегда
    # несли ВСЕ события (тысячи PSObject'ов на UI-потоке), а полл теперь форсирует
    # их каждые ~54с + отложенные таймеры после команд - парс шёл каждые несколько
    # секунд и морил печать команд (см. Type-Command). Regex-проход в тысячи раз
    # дешевле материализации; нечего нового - выходим без парса
    if ( $txt -ne "" ) {
        $frGen = 0; $frSeq = 0; $frAny = $false
        foreach ( $fm in [regex]::Matches($txt, 'PATHEV:(\d+):(\d+)\|') ) {
            $frAny = $true
            $fg2 = [long]$fm.Groups[1].Value
            $fv2 = [long]$fm.Groups[2].Value
            if ( ($fg2 -gt $frGen) -or ($fg2 -eq $frGen -and $fv2 -gt $frSeq) ) { $frGen = $fg2; $frSeq = $fv2 }
        }
        if ( $frAny ) {
            $frFresh = ( ($frGen -gt $script:LastGen) -or ($frGen -eq $script:LastGen -and $frSeq -gt $script:ScanCache.LastSeq) )
            if ( -not $frFresh ) {
                foreach ( $fp in [regex]::Matches($txt, 'PLVL:(\d+)\|') ) {
                    if ( [long]$fp.Groups[1].Value -gt $script:LastGen ) { $frFresh = $true; break }
                }
            }
            if ( -not $frFresh ) {
                if ( -not $script:SendBusy ) { Set-Status "table: $($script:KeyRows.Count) keys (no new events)" }
                return
            }
        }
    }
    if ( $txt -ne "" ) {
        # v4.5: только PATHEV:<seq>|TYPE|data - события с монотонным номером.
        # Старые PATHADD-строки игнорируются: в памяти живут КОПИИ буфера лога,
        # проигрывание сырых событий даёт мусор (очистка отменяется старыми кадрами).
        # v5.17.3: data только из безопасного charset - в хвосты частичных копий буфера
        # попадает мусор кучи ("98938.00䏆▗"), каст в Double ронял ВЕСЬ синк
        $rxEv = [regex]'PATHEV:(\d+):(\d+)\|([A-Z]+)\|?([0-9A-Za-z.,:_\-]*)'
        # v5.17.30.4: maxGen ДО материализации - PSObject создаётся только для событий
        # ТЕКУЩЕГО поколения (обычные копии буфера держат сотни событий прошлых
        # уровней; их материализация на UI-потоке и была главным тормозом синка)
        $ev = @()
        $mgPre = 0
        foreach ( $mp2 in $rxEv.Matches($txt) ) { $g3 = [long]$mp2.Groups[1].Value; if ( $g3 -gt $mgPre ) { $mgPre = $g3 } }
        foreach ( $m in $rxEv.Matches($txt) ) {
            if ( [long]$m.Groups[1].Value -ne $mgPre ) { continue }
            $ev += New-Object PSObject -Property @{Gen=[long]$m.Groups[1].Value; Seq=[long]$m.Groups[2].Value; T=$m.Groups[3].Value; D=$m.Groups[4].Value}
        }
        # v5.17.28.5: MAP-событие уровня может лежать в ПРЕДЫДУЩЕМ поколении:
        # фронтенд ("Play Map!") пишет MAP|<карта> ДО инкремента поколения, так что
        # фильтр "только maxGen" выбрасывал его, и панель не видела уровень.
        # Последний MAP по позиции в буфере = текущий уровень (буфер хронологический)
        $lastMap = ""
        foreach ( $mMap in [regex]::Matches($txt, 'PATHEV:\d+:\d+\|MAP\|([0-9A-Za-z_]+)') ) {
            $lastMap = $mMap.Groups[1].Value
        }
        if ( $lastMap -ne "" ) {
            Update-SelectionButtons
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
            # v5.17.30: KeyMap при смене поколения БОЛЬШЕ не стирается. Смена уровня
            # ВО ВРЕМЯ ИГРЫ (die-телепорт, переход-триггер) - кадры по-прежнему
            # принадлежат старой карте: лок кнопок и подкнопка "вернуться к кадрам"
            # должны знать целевую карту. ADD при новом кадре перетегирует KeyMap
            # на текущую карту как раньше (юзер осознанно начал новый путь)
            # $script:KeyMap = ""
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
        # v5.17.30.5: CLEAR в буфере = ЯВНАЯ очистка (краш/перезапуск игры её не пишет).
        # Сессионный флаг: старт-рестор бэкапа тоже не должен возвращать очищенное
        $hadClear = $false
        foreach ( $e in $ev ) {
            switch ( $e.T ) {
                'CLEAR' { $rows.Clear() | Out-Null; $script:KeyMap = ""; $script:KeyMapGoClicked = $false; $hadClear = $true; $script:SawClearInBuffer = $true }
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
                    if ( $e.D -match '^[0-9A-Za-z_]+$' ) { $script:CurrentMap = $e.D }
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
                    if ( $e.D -match '^[0-9A-Za-z_]+$' ) { $script:CurrentMap = $e.D }
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
        Update-MapPreview

        # v5.17.17: путь в игре ПУСТ (дамп 0 кадров), а в панели есть кадры той же
        # карты и пользователь не давал явную очистку - игра перезапустилась после
        # краша/закрытия: кадры СОХРАНЯЕМ (требование #backup: в панели всё живёт,
        # пока пользователь сам не удалит). Явная очистка - PathClear из панели с
        # флагом UserClearPending (гасится после этого синка). ДРУГАЯ карта (v5.17.30) -
        # кадры тоже сохраняем и показываем: лок кнопок защищает их от порчи,
        # подкнопка на карточке предлагает вернуться на карту кадров
        # v5.17.30.5: -not $hadClear - CLEAR в буфере = юзер явно очистил путь
        # (в т.ч. F11 хоткеем, который не ставит UserClearPending): кадры НЕ
        # восстанавливать. Краш/перезапуск игры CLEAR не пишет - там восстановление
        # остаётся. Живой случай: F11 очистил путь (CLEAR seq 46 в буфере), панель
        # вернула кадры обратно - юзер: "нажал очистку - ничего не произошло"
        if ( $rows.Count -eq 0 -and $script:KeyRows.Count -gt 0 -and -not $script:UserClearPending -and -not $hadClear ) {
            if ( $prevKeyMap -ne "" -and $prevKeyMap -eq $script:CurrentMap ) {
                $rows = $script:KeyRows
                $script:KeyMap = $prevKeyMap
                # v5.17.30: вернулись на карту кадров после подкнопки - путь игры пуст
                # (дамп 0 кадров), предложим записать кадры в игру (промпт в конце синка)
                if ( $script:KeyMapGoClicked ) { $script:KeyMapGoClicked = $false; $script:KeyMapGoArrived = $true }
            } elseif ( $prevKeyMap -ne "" -and $script:CurrentMap -ne "" ) {
                # v5.17.30: ДРУГАЯ карта (die-телепорт, переход уровня) - кадры остаются
                # в памяти панели и ПОКАЗЫВАЮТСЯ (лок кнопок не даёт их портить:
                # goto/вставка считаются по пути игры, а он тут пуст). Раньше кадры
                # стирались в 0 и восстанавливались только через Import из файла
                $rows = $script:KeyRows
            }
        }
        $wasClear = $script:UserClearPending
        $script:UserClearPending = $false
        $script:KeyRows = $rows
        Refresh-Table
        # v5.17.28.5: current level = last MAP event of the buffer. The frontend
        # ("Play Map!") writes MAP BEFORE the generation increment, so the maxGen
        # filter dropped it; applying at sync end also keeps a garbage DUMPMAP
        # (save path cut to "C:" by the regex) from overwriting the map name
        # v5.17.29: смена уровня ВО ВРЕМЯ ИГРЫ не пишет MAP-событие вообще
        # (die-телепорт, переходы-триггеры) - последнее MAP в буфере остаётся от
        # СТАРОЙ карты и панель навсегда залипает на ней. PLVL:<gen>|<map> из
        # "Possessed PlayerPawn: <pawn> <map>.<actor>" привязан к поколению нового
        # уровня - приоритет у PLVL для текущего maxGen, lastMap - фолбэк
        $plvlMap = ""
        foreach ( $mPl in [regex]::Matches($txt, 'PLVL:(\d+)\|([0-9A-Za-z_]+)') ) {
            if ( $mPl.Groups[1].Value -eq [string]$maxGen ) { $plvlMap = $mPl.Groups[2].Value }
        }
        if ( $plvlMap -ne "" ) {
            if ( $script:CurrentMap -ne $plvlMap ) { $script:CurrentMap = $plvlMap }
        } elseif ( $lastMap -ne "" -and $script:CurrentMap -ne $lastMap ) {
            $script:CurrentMap = $lastMap
        }
        Update-SelectionButtons
        # v5.17.30: после перехода по подкнопке кадры восстановлены из памяти, но путь
        # игры пуст - промпт "записать кадры в игру?" через короткий таймер (UI уже
        # отрисован, Send-GameCommands не должен идти внутри синка)
        if ( $script:KeyMapGoArrived ) {
            $script:KeyMapGoArrived = $false
            $tGo = New-Object System.Windows.Threading.DispatcherTimer
            $tGo.Interval = [TimeSpan]::FromMilliseconds(600)
            $tGo.Add_Tick({ param($s, $e) $s.Stop(); Prompt-PushKeysAfterArrival })
            $tGo.Start()
        }
        if ( $rows.Count -eq 0 -and $wasClear ) {
            # явная очистка в игре - бэкап тоже пустеет
            Save-KeysBackup -ForceEmpty
        }
        # v5.17.30.1: во время печати команд статус принадлежит пачке ("typing [i/N]") -
        # не затираем его завершением скана (иначе юзер не видел отказ "busy")
        if ( -not $script:SendBusy ) { Set-Status "table: $($rows.Count) keys (memory scan OK)" }
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
    # v5.16.2 делала синк ПОСЛЕ команды ВСЕГДА полным ("событие в хвосте буфера") -
    # полный скан занимает 10-20с и каждая команда (F8!) висела в typing минуту.
    # v5.17.30.1: быстрый скан ЛОВИТ новые события на стабильном буфере (фильтр
    # newMax теперь учитывает gen), а буфер переезжает только при загрузке карты -
    # это покрывают полл-форс (~54с) и отложенный полный рескан ниже (10с)
    # v5.17.30.5: УБРАН зонд PathDumpKeys после каждой команды (юзер: "F8 зависает
    # на несколько секунд - пишет в терминал"). Это была ВТОРАЯ пачка печати с
    # собственным тройным открытием консоли (+1.05с) и печатью (+0.8с) - F8 стоил
    # ~2с только на зонд. ADD-событие свежее в буфере - быстрый скан ловит его
    # сразу; дамп-зонд остаётся там, где нужен без печати: старт панели, полл при
    # пустой карте, кнопка ⟳
    Wait-Pump 120
    $tries = 0
    while ( -not (Sync-FromLog) -and $tries -lt 6 ) {
        Wait-Pump 300
        $tries++
    }
    $tFs = New-Object System.Windows.Threading.DispatcherTimer
    $tFs.Interval = [TimeSpan]::FromSeconds(10)
    $tFs.Add_Tick({ param($s, $e) $s.Stop(); Sync-FromLog -Force })
    $tFs.Start()
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
                        Background="#E02F9E44" Foreground="White" HorizontalAlignment="Right" VerticalAlignment="Top"
                        Margin="0,-6,2,0" ToolTip="{DynamicResource TipInsertRow}"
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
        <DataGridTextColumn Header="X" Width="56" Binding="{Binding X, StringFormat=F1}" IsReadOnly="True"/>
        <DataGridTextColumn Header="Y" Width="56" Binding="{Binding Y, StringFormat=F1}" IsReadOnly="True"/>
        <DataGridTextColumn Header="Z" Width="56" Binding="{Binding Z, StringFormat=F1}" IsReadOnly="True"/>
        <DataGridTextColumn Header="Yaw" Width="48" Binding="{Binding Yaw}" IsReadOnly="True"/>
        <DataGridTextColumn Header="Pitch" Width="44" Binding="{Binding Pitch}" IsReadOnly="True"/>
        <DataGridTextColumn Header="FOV" Width="36" Binding="{Binding FOV}"/>
        <DataGridTextColumn Header="Speed" Width="*" Binding="{Binding Speed}" IsReadOnly="False"/>
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
        <!-- v5.17.27: большая кнопка карты. MAP-метка видна ТОЛЬКО пока карта не
             загружена (тогда в карточке только метка справа сверху, кнопка серая);
             при загруженной карте метка не нужна - имя и превью говорят сами за себя -->
        <Button Name="BtnMapSwitch" Height="86" Margin="0,10,0,10" HorizontalContentAlignment="Stretch"
                Background="{DynamicResource PanelBrush}" ToolTip="{DynamicResource TipMapSwitch}" Cursor="Hand" Padding="10,6">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Image Name="ImgSwitchThumb" Grid.Column="0" Width="72" Height="54" Stretch="Uniform" VerticalAlignment="Top" Margin="0,2,0,0"/>
            <StackPanel Grid.Column="1" Margin="10,4,0,0" VerticalAlignment="Top">
              <TextBlock Name="TbSwitchFriendly" FontSize="13" FontWeight="Bold" Foreground="{DynamicResource TextBrush}" TextWrapping="Wrap"/>
              <TextBlock Name="TbSwitchTech" FontSize="11" Foreground="{DynamicResource MutedBrush}" Margin="0,1,0,0"/>
            </StackPanel>
            <TextBlock Name="TbMapLabel" Grid.Column="1" Text="🗺 MAP" Foreground="{DynamicResource MutedBrush}" FontSize="10"
                       HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,-4,0,0"/>
          </Grid>
        </Button>
        <!-- v5.17.30: подкнопка "вернуться к кадрам" - видна ТОЛЬКО когда кадры в панели
             с другой карты, чем та, где сейчас игра (die-телепорт, переход уровня).
             Клик = Switch-ToMap(KeyMap): open <карта> в консоли игры. Пока карты
             совпадают (или кадров нет) кнопка скрыта, карточка обычного размера -->
        <Button Name="BtnKeyMapGo" Height="30" Margin="0,-4,0,10" Visibility="Collapsed"
                Background="#FAB387" Foreground="#1E1E2E" FontSize="12" FontWeight="Bold"
                HorizontalContentAlignment="Left" Padding="14,3" Cursor="Hand" BorderThickness="0"/>
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
foreach ($name in @('BtnHudHide','BtnPathAdd','TbSeconds','BtnPathPlay','BtnPathPlaySpeed','BtnPathStop','BtnPathClear','DgKeys','TbMapLabel','TxFramesLabel','TxSec','TxFlySpeed','BtnExport','BtnImport','BtnRefresh','TbFov','BtnSetFov','BtnFovKey','BtnFovAll','BtnKeySpeed','TbSpeed','BtnSpeed','BtnSpeedAll','CbTransparent','HdrGrid','BtnLang','FlagEN','FlagRU','BtnTheme','ImgOwl','ImgSwitchThumb','TbSwitchFriendly','TbSwitchTech','BtnMapSwitch','BtnKeyMapGo','BtnHide','BtnClose','TbStatus','StatusDot','TxHkFrame','TxHkPlay','TxHkStop','TxHkClear','BtnGithub','LogPopup','LogPopupBorder','TbLogHistory')) {
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
    # картинка скрывается. v5.17.23: также большая кнопка Switch map (превью +
    # понятное название + техническое имя файла). v5.17.25: только большая
    # кнопка - старый блок названия+превью удалён как дубликат
    try {
        # v5.17.28.5: карточка показывает ТЕКУЩУЮ карту игры (CurrentMap), а не карту
        # кадров (KeyMap): юзер в игре без кадров видел пустой чип вместо карты.
        # Кадровая карта важна только когда игра не на уровне (офлайн-режим)
        $map = $script:CurrentMap
        if ( $map -eq "" ) { $map = $script:KeyMap }
        # v5.17.27: два состояния карточки. Игра не на карте (закрыта/меню) ->
        # в карточке ТОЛЬКО метка MAP справа сверху (юзер), кнопка серая.
        # Карта загружена -> метка не нужна (имя+превью говорят сами за себя)
        $gameOn = ( $script:CurrentMap -ne "" )
        if ( -not $gameOn -or $map -eq "" ) {
            # v5.17.28: игра не видна - кнопка АКТИВНА и запускает игру на карте,
            # выбранной в пикере (юзер передумал насчёт серой кнопки)
            $controls['TbMapLabel'].Visibility = [System.Windows.Visibility]::Visible
            $controls['ImgSwitchThumb'].Visibility = [System.Windows.Visibility]::Collapsed
            $controls['TbSwitchFriendly'].Visibility = [System.Windows.Visibility]::Collapsed
            $controls['TbSwitchTech'].Visibility = [System.Windows.Visibility]::Collapsed
            $controls['BtnMapSwitch'].IsEnabled = $true
            $controls['BtnMapSwitch'].Height = 48
            $L = $script:LocData[$script:Lang]
            $controls['BtnMapSwitch'].ToolTip = $L.TipLaunchMap
            return
        }
        $controls['BtnMapSwitch'].IsEnabled = $true
        $controls['BtnMapSwitch'].Height = 86
        $controls['TbMapLabel'].Visibility = [System.Windows.Visibility]::Collapsed
        $controls['TbSwitchFriendly'].Visibility = [System.Windows.Visibility]::Visible
        $controls['TbSwitchTech'].Visibility = [System.Windows.Visibility]::Visible
        $controls['BtnMapSwitch'].ToolTip = $script:LocData[$script:Lang].TipMapSwitch
        $path = "F:\Harry Potter and the Chamber of Secrets\system\Thumbnails\" + $map + ".bmp"
        $hasThumb = ( $map -ne "" -and (Test-Path $path) )
        if ( $hasThumb ) {
            $bmp = New-Object Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = (New-Object Uri($path))
            $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $bmp.Freeze()
            $controls['ImgSwitchThumb'].Source = $bmp
            $controls['ImgSwitchThumb'].Visibility = [System.Windows.Visibility]::Visible
        } else {
            $controls['ImgSwitchThumb'].Source = $null
            $controls['ImgSwitchThumb'].Visibility = [System.Windows.Visibility]::Collapsed
        }
        $controls['TbSwitchFriendly'].Text = Get-MapFriendlyName $map
        $controls['TbSwitchTech'].Text = $map + ".unr"
    } catch { }
}

# ---------- v5.17.30: die-телепорт / переход уровня с кадрами другой карты ----------
function Update-KeyMapGoButton {
    # подкнопка "вернуться к кадрам" под карточкой карты. Видна ТОЛЬКО когда кадры
    # в панели с другой карты, чем та, где сейчас игра (die-телепорт, переход-триггер).
    # Карточка в этот момент сжимается (86->58, превью прячется), чтобы блок
    # "карта + подкнопка" не разъезжался по вертикали
    try {
        $wrong = ($script:KeyMap -ne "" -and $script:CurrentMap -ne "" -and $script:KeyMap -ne $script:CurrentMap)
        if ( $wrong ) {
            $L = $script:LocData[$script:Lang]
            $fn = Get-MapFriendlyName $script:KeyMap
            $controls['BtnKeyMapGo'].Content = ($L.KeyMapGo -f $fn)
            $controls['BtnKeyMapGo'].ToolTip = ($L.TipKeyMapGo -f $script:KeyMap)
            $controls['BtnKeyMapGo'].Visibility = "Visible"
            $controls['BtnMapSwitch'].Height = 58
            $controls['ImgSwitchThumb'].Visibility = "Collapsed"
        } else {
            $controls['BtnKeyMapGo'].Visibility = "Collapsed"
        }
    } catch { }
}
function Push-KeysToGame {
    # запись кадров из памяти панели в путь игры: PathClear + AddX/AddY/.../AddCommit
    # на каждый кадр (та же пошаговая схема, что у Import from file - консоль M212
    # берёт ТОЛЬКО ПЕРВЫЙ аргумент typed-exec). Времена постановки уже лежат в
    # KeyTimes по координатам - StampNextSync не нужен
    if ( $script:KeyRows.Count -eq 0 ) { return }
    $cmds = @("PathClear")
    foreach ( $r in $script:KeyRows ) {
        $xk = [int][math]::Round(($r.X + 1000000.0) * 10.0)
        $yk = [int][math]::Round(($r.Y + 1000000.0) * 10.0)
        $zk = [int][math]::Round(($r.Z + 1000000.0) * 10.0)
        $yw = [long]$r.Yaw; $yw = (($yw % 65536) + 65536) % 65536
        $pt = [long]$r.Pitch; $pt = (($pt % 65536) + 65536) % 65536
        $fv = [int][math]::Round($r.FOV)
        $sp = [int][math]::Round($r.Speed)
        $cmds += @("AddX $xk","AddY $yk","AddZ $zk","AddYaw $yw","AddPitch $pt","AddFov $fv","AddSpd $sp","AddCommit")
    }
    $st = Send-GameCommands $cmds
    Sync-AfterCommand ("pushed $($script:KeyRows.Count) keys to the game | $st")
}
function Prompt-PushKeysAfterArrival {
    # после перехода по подкнопке кадры восстановлены в таблице из памяти, но путь
    # игры пуст (дамп 0 кадров). Предлагаем записать их в игру сразу
    try {
        if ( $script:KeyRows.Count -eq 0 ) { return }
        if ( $script:CurrentMap -eq "" -or $script:CurrentMap -ne $script:KeyMap ) { return }
        $L = $script:LocData[$script:Lang]
        $r = [System.Windows.MessageBox]::Show(($L.PushKeysQ -f $script:KeyRows.Count), $L.PushKeysTitle, 'YesNo', 'Question')
        if ( $r -eq 'Yes' ) { Push-KeysToGame }
        else { Set-Status $L.PushKeysNo }
    } catch { }
}
$controls['BtnKeyMapGo'].Add_Click({
    if ( $script:KeyMap -ne "" ) {
        $script:KeyMapGoClicked = $true
        Switch-ToMap $script:KeyMap
    }
})
function Test-WrongMap {
    # v5.17.30: единый гвард "кадры с другой карты" - блокирует и ДОБАВЛЕНИЕ кадров
    # (F8 горячей клавишей обходится серость кнопки: ADD перетегировал бы KeyMap на
    # текущую карту, записи прежней карты потерялись бы)
    return ( $script:KeyMap -ne "" -and $script:CurrentMap -ne "" -and $script:KeyMap -ne $script:CurrentMap )
}
function Do-PathAdd {
    if ( Test-WrongMap ) { Set-Status ($script:LocData[$script:Lang].TipWrongMap); return }
    # скорость кадра = поле fly speed: применяем её перед добавлением
    # v5.17.30.5: Cam_MoveSpeed печатается ТОЛЬКО если скорость изменилась
    # (повторные F8 на той же скорости - минус одна команда и ~0.6с печати;
    # юзер: "F8 зависает на несколько секунд"). Скорость глобальная - не сбрасывается
    $sp = $controls['TbSpeed'].Text.Trim()
    if ($sp -notmatch '^\d+(\.\d+)?$') { $sp = "250" }
    $script:StampNextSync = $true   # новый кадр получит время постановки
    if ( $script:SpeedApplied -eq $sp ) {
        $st = Send-GameCommands @("PathAdd")
    } else {
        $st = Send-GameCommands @("Cam_MoveSpeed $sp", "PathAdd")
        $script:SpeedApplied = $sp
    }
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
    # v5.17.30: кадры с другой карты - проигрывать нельзя (и F9 тоже)
    if ( Test-WrongMap ) { Set-Status ($script:LocData[$script:Lang].TipWrongMap); return }
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
    # v5.17.30: кадры с другой карты - проигрывать нельзя
    if ( Test-WrongMap ) { Set-Status ($script:LocData[$script:Lang].TipWrongMap); return }
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
    Add-TypeCached -TypeName 'HP2.TopHalfPillAdorner' -Source @"
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
"@ -Refs @('PresentationCore','PresentationFramework','WindowsBase','System.Xaml')
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
            $script:PillAX = $p.X + 26   # центр пилюли: правый край (# 36 - margin 2) - половина ширины 16
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
# одиночный клик по ячейке = редактирование; двойной - выделить текст целиком.
# Сохранение: Enter или клик в любое место панели (DataGrid коммитит при потере
# фокуса/Enter). Правка FOV/Speed уходит в игру СРАЗУ при завершении ячейки;
# правка времени = обновление key-times (время привязано к координатам).
# Координаты в игре менять нечем, они локальные
$script:EditingNow = $false

$controls['DgKeys'].Add_CellEditEnding({
    param($sender, $e)
    try {
        $row = $e.Row.Item
        if ( $row -eq $null ) { return }
        $n = $row.Num
        $hdr = [string]$e.Column.Header
        $val = ""
        try { $val = $e.EditingElement.Text } catch { }
        $window.Dispatcher.BeginInvoke([Action]{
            try {
                if ( $hdr -eq "Time" ) {
                    if ( $val -match '^\d{2}:\d{2}:\d{2}$' ) {
                        $inv = [System.Globalization.CultureInfo]::InvariantCulture
                        $sk = $row.X.ToString('F1', $inv) + ";" + $row.Y.ToString('F1', $inv) + ";" + $row.Z.ToString('F1', $inv)
                        $script:KeyTimes[$sk] = $val
                    }
                    return
                }
                if ( (Get-Process Game -ErrorAction SilentlyContinue) -eq $null -or $script:CurrentMap -eq "" ) { return }
                if ( $hdr -eq "FOV" -and $val -match '^\d+(\.\d+)?$' ) {
                    $fv = [int][math]::Round([double]$val)
                    Send-GameCommands @("FovIdx $n","FovVal $fv","FovApply") | Out-Null
                }
                if ( $hdr -eq "Speed" -and $val -match '^\d+(\.\d+)?$' ) {
                    $sv = [int][math]::Round([double]$val)
                    Send-GameCommands @("SpeedIdx $n","SpeedVal $sv","SpeedApply") | Out-Null
                }
            } catch { }
        }) | Out-Null
    } catch { }
})
# v5.17.21 (#2 UX, финал): КЛИК ПО РЕДАКТИРУЕМОЙ ЯЧЕЙКЕ (Time/FOV/Speed):
#   1 клик  = начать правку (каретка в конец, текст НЕ выделен)
#   2 клик  = выделить весь текст (замена) - ТОЛЬКО если оба клика в одну ячейку
# Клик по нередактируемым полям (координаты, #) = просто выделение строки.
# "Проглатывание" первого клика после клика вне таблицы УДАЛЕНО - правка начинается
# с первого клика всегда. Клик по другой редактируемой ячейке при активной правке =
# коммит предыдущей + правка новой (два deferred строго по порядку диспетчера)
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
        # кнопки таблицы (глаз/корзина/пилюли/галочка) не участвуют в правке
        $btn = $null
        $depB = $e.OriginalSource
        while ( $depB -ne $null ) {
            if ( $depB -is [System.Windows.Controls.Button] ) { $btn = $depB; break }
            $depB = [Windows.Media.VisualTreeHelper]::GetParent($depB)
        }
        # двойной клик в редактируемом TextBox - выделить весь текст (замена);
        # ветка ДО коммита: двойной клик по уже правимой ячейке выделяет, а не коммитит
        if ( $e.ClickCount -ge 2 ) {
            $tb = $null
            $dep2 = $e.OriginalSource
            while ( $dep2 -ne $null ) {
                if ( $dep2 -is [System.Windows.Controls.TextBox] ) { $tb = $dep2; break }
                $dep2 = [Windows.Media.VisualTreeHelper]::GetParent($dep2)
            }
            if ( $tb -ne $null ) { $tb.SelectAll(); $e.Handled = $true; return }
        }
        if ( $script:Playing ) { return }
        if ( $btn -ne $null ) { return }
        # клик по УЖЕ редактируемой ячейке - не трогаем (позиция каретки в TextBox,
        # выделение мышью); коммита нет, правка продолжается
        if ( $cell -ne $null -and $cell.IsEditing ) { return }
        # v5.17.21.3: активная правка + клик мимо неё = «выметание» фокусом: переносим
        # фокус на внешнюю кнопку, DataGrid САМ завершает правку (нативный путь, без
        # застревания). Иначе старая ячейка оставалась с TextBox (белый фон) - на
        # скрине юзера: FOV row1/row3 оставались белыми после переключения правки
        if ( $script:EditingNow ) {
            try { $null = [System.Windows.Input.Keyboard]::Focus($controls['BtnRefresh']) } catch { }
            $script:EditingNow = $false
            if ( $cell -eq $null ) {
                $window.Dispatcher.BeginInvoke([Action]{
                    try {
                        try { $null = [System.Windows.Input.Keyboard]::Focus($controls['BtnRefresh']) } catch { }
                        $controls['DgKeys'].CommitEdit()
                    } catch { }
                }) | Out-Null
                return
            }
        }
        if ( $cell.IsReadOnly ) { return }
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
        # CurrentCell = кликнутая ячейка; BeginEdit() без аргументов редактирует её.
        # Один клик = правка БЕЗ выделения текста (каретка в конец); SelectAll -
        # только по двойному клику (см. ветку выше)
        $script:EditCell = $cell
        $script:EditRowC = $drow
        $window.Dispatcher.BeginInvoke([Action]{
            try {
                $dgv = $controls['DgKeys']
                $dgv.CurrentCell = New-Object System.Windows.Controls.DataGridCellInfo($script:EditCell)
                $dgv.BeginEdit()
                $script:EditingNow = $true
                # каретка в конец, текст не выделен - выделение только по двойному клику
                $tb = Find-VisualChildOfType $script:EditCell ([System.Windows.Controls.TextBox])
                if ( $tb -ne $null ) {
                    $tb.SelectionLength = 0
                    $tb.CaretIndex = $tb.Text.Length
                }
                # v5.17.21.2: клик по другой ячейке ПРИ активной правке - native commit
                # предыдущей строки может ещё не завершиться к этому моменту, BeginEdit
                # молча отказывает. Повторяем попытку, пока TextBox не появится (3x60ms)
                if ( $tb -eq $null ) {
                    $script:EditRetryLeft = 3
                    $script:EditRetryTimer = New-Object System.Windows.Threading.DispatcherTimer
                    $script:EditRetryTimer.Interval = [TimeSpan]::FromMilliseconds(60)
                    $script:EditRetryTimer.Add_Tick({
                        try {
                            $tb2 = Find-VisualChildOfType $script:EditCell ([System.Windows.Controls.TextBox])
                            if ( $tb2 -ne $null ) {
                                $tb2.SelectionLength = 0
                                $tb2.CaretIndex = $tb2.Text.Length
                                $script:EditRetryTimer.Stop()
                                return
                            }
                            $controls['DgKeys'].BeginEdit()
                            $tb2 = Find-VisualChildOfType $script:EditCell ([System.Windows.Controls.TextBox])
                            if ( $tb2 -ne $null ) {
                                $tb2.SelectionLength = 0
                                $tb2.CaretIndex = $tb2.Text.Length
                                $script:EditRetryTimer.Stop()
                                return
                            }
                            $script:EditRetryLeft--
                            if ( $script:EditRetryLeft -le 0 ) { $script:EditRetryTimer.Stop() }
                        } catch { $script:EditRetryTimer.Stop() }
                    })
                    $script:EditRetryTimer.Start()
                }
            } catch { }
        }) | Out-Null
    } catch { }
}
$controls['DgKeys'].AddHandler([System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent, $dgKeysEditHandler, $true)

# v5.17.20: клик ВНЕ таблицы (MAP, пустые места, другие кнопки) при активной правке
# = СОХРАНИТЬ правку. TextBlock'и не забирают фокус, поэтому DataGrid сам такие
# клики не коммитил - выделение висело
$window.Add_PreviewMouseLeftButtonDown({
    param($s, $e)
    try {
        if ( -not $script:EditingNow ) { return }
        $dep = $e.OriginalSource
        while ( $dep -ne $null ) {
            if ( $dep -eq $controls['DgKeys'] ) { return }
            $dep = [Windows.Media.VisualTreeHelper]::GetParent($dep)
        }
        $script:EditingNow = $false
        $window.Dispatcher.BeginInvoke([Action]{
            try { Commit-RowEdit } catch { }
        }) | Out-Null
    } catch { }
})

# v5.17.20: коммит правки строки с ВЫВОДОМ фокуса из TextBox. Без этого CommitEdit
# коммитит, но фокус остаётся в ячейке и DataGrid МОМЕНТАЛЬНО входит в правку
# заново (известное поведение) - "правка застревала" навсегда
function Commit-RowEdit {
    # фокус на ВНЕШНЮЮ фокусируемую кнопку: DataGrid САМ коммитит по потере фокуса
    # (нативный путь, без re-entry в edit)
    try { $null = [System.Windows.Input.Keyboard]::Focus($controls['BtnRefresh']) } catch { }
    try {
        # ВАЖНО: перегрузка CommitEdit(unit, cancelEdits) падает NRE, если CurrentCell
        # указывает на ПЕРЕСОЗДАННЫЙ контейнер ячейки (живой скрин: DataGridCellInfo
        # умер после регенерации). Безаргументная перегрузка коммитит через внутреннее
        # состояние - не разыменовывает контейнер
        $controls['DgKeys'].CommitEdit()
    } catch {
    }
}

# v5.17.22: галочка/крестик удалены (юзер) - сохранение на Enter и клик в любое
# место панели (см. EditingNow-ветки и window Preview-хендлер), откат не нужен

# ---------- v5.17.23 (#13): переключение карт ----------
$script:MapsDir = "F:\Harry Potter and the Chamber of Secrets\Maps"
$script:ThumbsDir = "F:\Harry Potter and the Chamber of Secrets\system\Thumbnails"
# понятные названия (ru); без словаря - сырое имя карты
$script:MapNames = @{
    AOLDemo = "Демо-арена"; Adv10Hermione_Extended = "Спасение Гермионы (расшир.)"
    Adv11aCorridor = "Тайный коридор"; Adv11bSecrets = "Комната секретов"
    Adv12Chamber = "Тайная комната"; Adv1Willow = "Битва у вербы"
    Adv3DungeonQuest = "Побег из подземелья"; Adv4Greenhouse = "Оранжерея"
    Adv6Goyle = "Драка с Гойлом"; Adv7SlythComRoom = "Гостиная Слизерина"
    Adv8Forest = "Запретный лес"; Adv9Aragog = "Арагог"
    Arena = "Арена"; BeanRewardRoom = "Комната фасолек"
    Ch1Rictusempra = "Риктусемпра"; Ch2Skurge = "Скурдж"
    Ch3Diffindo = "Диффиндо"; Ch4Spongify = "Спонджифай"
    Ch6WizardCard = "Карта волшебника"; Ch7Gryffindor = "Гриффиндор"
    Credits = "Титры"; Entry = "Вход"
    Entryhall_hub = "Входной зал"; FlyingFordCutscene = "Летающий Форд (катсцена)"
    Grandstaircase_hub = "Гранд-лестница"; GreatHall_G = "Большой зал (Г)"
    GreatHall_S = "Большой зал (С)"; Grounds_Night = "Двор ночью"
    Grounds_hub = "Двор Хогвартса"; HPDemo = "Демо-игра"
    Library = "Библиотека"; Library_Night = "Библиотека ночью"
    PrivetDr = "Тисовая улица"; Quidditch = "Квиддич"
    Quidditch_Intro = "Квиддич (интро)"; Quidditch_Match = "Квиддич (матч)"
    Sepia_Hallway = "Коридор (сепия)"; Transition = "Переход"
    Duel01 = "Дуэль 1"; Duel02 = "Дуэль 2"; Duel03 = "Дуэль 3"; Duel04 = "Дуэль 4"
    Duel05 = "Дуэль 5"; Duel06 = "Дуэль 6"; Duel07 = "Дуэль 7"; Duel08 = "Дуэль 8"
    Duel09 = "Дуэль 9"; Duel10 = "Дуэль 10"; startup = "Стартовая сцена"
}
$script:MapNamesEn = @{
    AOLDemo = "Demo Arena"; Adv10Hermione_Extended = "Rescuing Hermione (Extended)"
    Adv11aCorridor = "Secret Corridor"; Adv11bSecrets = "Room of Secrets"
    Adv12Chamber = "Chamber of Secrets"; Adv1Willow = "Battle at the Willow"
    Adv3DungeonQuest = "Dungeon Escape"; Adv4Greenhouse = "Greenhouse"
    Adv6Goyle = "Fight with Goyle"; Adv7SlythComRoom = "Slytherin Common Room"
    Adv8Forest = "Forbidden Forest"; Adv9Aragog = "Aragog"
    Arena = "Arena"; BeanRewardRoom = "Bean Bonus Room"
    Ch1Rictusempra = "Rictusempra"; Ch2Skurge = "Skurge"
    Ch3Diffindo = "Diffindo"; Ch4Spongify = "Spongify"
    Ch6WizardCard = "Wizard Card"; Ch7Gryffindor = "Gryffindor"
    Credits = "Credits"; Entry = "Entrance"
    Entryhall_hub = "Entrance Hall"; FlyingFordCutscene = "Flying Ford (Cutscene)"
    Grandstaircase_hub = "Grand Staircase"; GreatHall_G = "Great Hall (G)"
    GreatHall_S = "Great Hall (S)"; Grounds_Night = "Grounds at Night"
    Grounds_hub = "Hogwarts Grounds"; HPDemo = "Demo Game"
    Library = "Library"; Library_Night = "Library at Night"
    PrivetDr = "Privet Drive"; Quidditch = "Quidditch"
    Quidditch_Intro = "Quidditch (Intro)"; Quidditch_Match = "Quidditch (Match)"
    Sepia_Hallway = "Hallway (Sepia)"; Transition = "Transition"
    Duel01 = "Duel 1"; Duel02 = "Duel 2"; Duel03 = "Duel 3"; Duel04 = "Duel 4"
    Duel05 = "Duel 5"; Duel06 = "Duel 6"; Duel07 = "Duel 7"; Duel08 = "Duel 8"
    Duel09 = "Duel 9"; Duel10 = "Duel 10"; startup = "Startup Scene"
}
function Get-MapFriendlyName([string]$map) {
    # v5.17.26: имя карты по языку панели (EN-словарь для английского режима)
    if ( $script:Lang -eq "ru" ) { $n = $script:MapNames[$map] }
    else { $n = $script:MapNamesEn[$map] }
    if ( $n -ne $null -and $n -ne "" ) { return $n }
    return $map
}
function Get-MapCategory([string]$m) {
    # РєР°С‚РµРіРѕСЂРёРё РєР°Рє РІ UI РІС‹Р±РѕСЂР° РєР°СЂС‚
    if ( $m -like 'Duel*' ) { return "Dueling Club" }
    if ( $m -eq 'Arena' ) { return "Dueling Club" }
    if ( $m -like 'Grounds*' ) { return "Grounds" }
    if ( $m -like 'Quidditch*' ) { return "Quidditch" }
    if ( $m -like 'Ch*' ) { return "Spell Challenge" }
    if ( $m -eq 'Adv9Aragog' ) { return "Boss Fight" }
    if ( $m -eq 'Adv8Forest' ) { return "Forbidden Forest" }
    if ( $m -like 'GreatHall*' -or $m -like 'Library*' -or $m -like 'Grandstaircase*' -or $m -like 'Entryhall*' -or $m -eq 'Entry' ) { return "Hogwarts Castle" }
    if ( $m -like 'Adv*' ) { return "Adventure" }
    if ( $m -eq 'PrivetDr' ) { return "Privet Drive" }
    if ( $m -eq 'BeanRewardRoom' ) { return "Bonus Room" }
    return "Service"
}
function Switch-ToMap([string]$map) {
    # РІС‹Р±РѕСЂ РєР°СЂС‚С‹ РёР· РїРёРєРµСЂР°: РїСЂРµРґСѓРїСЂРµР¶РґРµРЅРёРµ Рѕ СЃР±СЂРѕСЃРµ РїСѓС‚Рё + open <map>
    try {
        $L = $script:LocData[$script:Lang]
        $gameRun = ( (Get-Process Game -ErrorAction SilentlyContinue) -ne $null )
        if ( $gameRun -and $script:KeyRows.Count -gt 0 ) {
            $r = [System.Windows.MessageBox]::Show($L.MapWarnQ, $(if ( $script:Lang -eq "ru" ) { "Смена карты" } else { "Switch map" }), 'YesNo', 'Question')
            if ( $r -ne 'Yes' ) { return }
        }
        # v5.17.28: игра закрыта - кнопка карты ЗАПУСКАЕТ игру на выбранном уровне
        if ( -not $gameRun ) {
            Start-LaunchSequence $map
            return
        }
        Set-Status ("switching to " + $map + "...")
        $st = Send-GameCommand ("open " + $map)
        Set-Status ($st + " | " + $(if ( $script:Lang -eq "ru" ) { "РєР°СЂС‚Р° " } else { "map " }) + $map)
        # v5.17.30.2: ЖИВОЙ ФАКТ - печать open дошла до консоли игры (PING-маркер
        # в буфере), но карта НЕ сменилась (exec видимо потерял текст/аргумент).
        # Через 20с проверяем CurrentMap: не сменилась - автоматический ПОВТОР open
        $mapFrom = $script:CurrentMap
        $tSw = New-Object System.Windows.Threading.DispatcherTimer
        $tSw.Interval = [TimeSpan]::FromSeconds(20)
        $tSw.Add_Tick({
            param($s, $e)
            $s.Stop()
            try {
                if ( $script:CurrentMap -ne $mapFrom -and $script:CurrentMap -ne "" ) { return }   # грузится/загрузилась
                Set-Status ("map did not load - retrying open " + $map + "...") "warn"
                $st2 = Send-GameCommand ("open " + $map)
                Set-Status ($st2 + " | retry map " + $map)
            } catch { }
        })
        $tSw.Start()
        # v5.17.30: детерминированные полные ресканы после open - загрузка карты
        # перевыделяет буфер лога, быстрый скан слепнет до очередного Force
        foreach ( $sec in @(12, 26) ) {
            $tSw = New-Object System.Windows.Threading.DispatcherTimer
            $tSw.Interval = [TimeSpan]::FromSeconds($sec)
            $tSw.Add_Tick({ param($s, $e) $s.Stop(); Sync-FromLog -Force })
            $tSw.Start()
        }
    } catch { }
}
# ---------- v5.17.28: запуск игры на выбранной карте (игра не запущена) ----------
# юзер: "если игру панель не видит - пусть эта кнопка запускает игру на выбираемом
# уровне". Пикер закрываем, дальше живёт стейт-машина на DispatcherTimer (UI-поток):
# boot (старт Start Game with Log.bat) -> waitwin (окно игры) -> send (open <map>
# штатной консольной печатью панели, ConfirmBypass) -> waitmap (по CurrentMap)
$script:GameDir = "F:\Harry Potter and the Chamber of Secrets"
# перечислитель окон: нужен класс GameUnrealWM212Log (окно лога - ЕДИНСТВЕННЫЙ
# надёжный канал команд, пока игра в меню: тихая консоль вьюпорта в меню молчит)
if ( -not ('HP2WinEnum' -as [type]) ) {
    Add-TypeCached -TypeName 'HP2WinEnum' -Source @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class HP2WinEnum {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    public delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
    public static IntPtr FindByClass(string cls) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr lp) {
            StringBuilder sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            if ( sb.ToString() == cls ) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
"@
}
function Find-LogConsoleWindow {
    try { return [HP2WinEnum]::FindByClass("GameUnrealWM212Log") } catch { return [IntPtr]::Zero }
}
$script:LaunchSeq = $null
function Start-LaunchSequence([string]$map) {
    try { if ( $script:MPWin -ne $null ) { $script:MPWin.Close() } } catch { }
    $script:LaunchSeq = @{ Map = $map; Stage = "boot"; Tries = 0; Sent = 0 }
    $ru = ( $script:Lang -eq "ru" )
    Set-Status ($(if ( $ru ) { "запускаю игру для карты " } else { "launching game for map " }) + $map + "...") "warn"
    $script:LaunchTimer.Start()
}
function Fail-Launch([string]$why) {
    $ru = ( $script:Lang -eq "ru" )
    $script:LaunchSeq = $null
    $script:LaunchTimer.Stop()
    Set-Status ($(if ( $ru ) { "не удалось запустить игру: " } else { "launch failed: " }) + $why) "err"
}
$script:LaunchTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:LaunchTimer.Interval = [TimeSpan]::FromSeconds(2)
$script:LaunchTimer.Add_Tick({
    if ( $script:LaunchSeq -eq $null ) { $script:LaunchTimer.Stop(); return }
    $L = $script:LaunchSeq
    $ru = ( $script:Lang -eq "ru" )
    try {
        switch ( $L.Stage ) {
            "boot" {
                if ( (Get-Process Game -ErrorAction SilentlyContinue) -ne $null ) { $L.Stage = "waitwin"; $L.Tries = 0; return }
                if ( $L.Sent -eq 0 ) {
                    $L.Sent = 1
                    Start-Process -FilePath (Join-Path $script:GameDir "system\Start Game with Log.bat") -WorkingDirectory (Join-Path $script:GameDir "system")
                }
                $L.Tries++
                if ( $L.Tries -gt 10 ) { Fail-Launch $(if ( $ru ) { "процесс игры не появился" } else { "game process did not appear" }) }
            }
            "waitwin" {
                if ( (Find-GameWindow) -ne [IntPtr]::Zero ) { $L.Stage = "settle"; $L.Tries = 0; return }
                $L.Tries++
                if ( $L.Tries -gt 45 ) { Fail-Launch $(if ( $ru ) { "окно игры не появилось" } else { "game window did not appear" }) }
            }
            "settle" {
                # интро-заставки ~20с глотают ввод: окно вьюпорта появляется с самого
                # старта, но меню ещё не живое - ждём перед первой отправкой
                $L.Tries++
                if ( $L.Tries -ge 12 ) { $L.Stage = "send"; $L.Tries = 0 }
            }
            "send" {
                # v5.17.28.2: тихая консоль вьюпорта в ГЛАВНОМ МЕНЮ молчит (зонды
                # PathDumpKeys не возвращают дампы) - печатаем open <map> прямо в
                # окно лога GameUnrealWM212Log: оно живёт с старта и принимает
                # команды в любом состоянии. SendKeys - юникод, раскладка не важна
                $cw = Find-LogConsoleWindow
                if ( $cw -eq [IntPtr]::Zero ) {
                    $L.Tries++
                    if ( $L.Tries -gt 15 ) { Fail-Launch $(if ( $ru ) { "окно лога игры не найдено" } else { "game log window not found" }) }
                    return
                }
                [void][GameCtl]::SetForegroundWindow($cw)
                Start-Sleep -Milliseconds 400
                Add-Type -AssemblyName System.Windows.Forms
                [System.Windows.Forms.SendKeys]::SendWait(("open " + $L.Map + "{ENTER}"))
                $L.Sent++
                $L.Stage = "waitmap"
                $L.Tries = 0
                Set-Status ($(if ( $ru ) { "загружаю карту " } else { "loading map " }) + $L.Map + "...") "warn"
            }
            "waitmap" {
                Sync-FromLog -Force
                if ( $script:CurrentMap -ieq $L.Map ) {
                    $script:LaunchSeq = $null
                    $script:LaunchTimer.Stop()
                    Set-Status ($(if ( $ru ) { "игра запущена на карте " } else { "game launched on map " }) + $L.Map)
                    return
                }
                $L.Tries++
                if ( $L.Tries -ge 6 ) {
                    if ( $L.Sent -lt 5 ) { $L.Stage = "send" }
                    else { Fail-Launch $(if ( $ru ) { "карта не загрузилась" } else { "map did not load" }) }
                }
            }
        }
    } catch {
        Fail-Launch $_.Exception.Message
    }
})

function Build-MapRows {
    # v5.17.24: СЃС‚СЂРѕРєРё РїРёРєРµСЂР° РІ СЃС‚РёР»Рµ СЂРµС„РµСЂРµРЅСЃР° - РїСЂРµРІСЊСЋ, РёРјСЏ + Р±РµР№РґР¶ РєР°С‚РµРіРѕСЂРёРё +
    # С‚РµС….РёРјСЏ, Р·РІРµР·РґР°, Launch. РўРµРјР° - С‡РµСЂРµР· СЂРµСЃСѓСЂСЃС‹ РіР»Р°РІРЅРѕРіРѕ РѕРєРЅР°
    param($listPanel, $allMaps, $filter, $favOnly)
    $listPanel.Children.Clear()
    $f = ""
    if ( $filter -ne $null ) { $f = $filter.Trim().ToLower() }
    $shown = 0
    $sorted = @($allMaps | Sort-Object -Property @{ Expression = { if ( $script:FavMaps -contains $_ ) { 0 } else { 1 } } }, @{ Expression = { Get-MapFriendlyName $_ } })
    foreach ( $m in $sorted ) {
        $fn = Get-MapFriendlyName $m
        if ( $favOnly -and ($script:FavMaps -notcontains $m) ) { continue }
        if ( $f -ne "" -and ($fn.ToLower().Contains($f) -eq $false) -and ($m.ToLower().Contains($f) -eq $false) ) { continue }
        $shown++
        $row = New-Object System.Windows.Controls.Border
        $row.CornerRadius = [System.Windows.CornerRadius]::new(8)
        $row.Background = $window.Resources['PanelBrush']
        $row.BorderBrush = $window.Resources['LineBrush']
        $row.BorderThickness = [System.Windows.Thickness]::new(1)
        $row.Margin = [System.Windows.Thickness]::new(0,0,0,8)
        $g2 = New-Object System.Windows.Controls.Grid
        $g2.Margin = [System.Windows.Thickness]::new(10,8,10,8)
        $gc = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::new(96)}
        $cn = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)}
        $cs = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::Auto}
        $cl = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::Auto}
        $g2.ColumnDefinitions.Add($gc); $g2.ColumnDefinitions.Add($cn); $g2.ColumnDefinitions.Add($cs); $g2.ColumnDefinitions.Add($cl)
        # РїСЂРµРІСЊСЋ / NO PREVIEW
        $thumb = $script:ThumbsDir + "\" + $m + ".bmp"
        if ( Test-Path $thumb ) {
            $img = New-Object System.Windows.Controls.Image
            $img.Width = 96; $img.Height = 72; $img.Stretch = [System.Windows.Media.Stretch]::UniformToFill
            $bi = New-Object System.Windows.Media.Imaging.BitmapImage
            $bi.BeginInit()
            $bi.UriSource = New-Object System.Uri($thumb)
            $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bi.EndInit(); $bi.Freeze()
            $img.Source = $bi
            [System.Windows.Controls.Grid]::SetColumn($img, 0)
            $g2.Children.Add($img) | Out-Null
        } else {
            $ph = New-Object System.Windows.Controls.Border
            $ph.Background = $window.Resources['TableBgBrush']
            $ph.Width = 96; $ph.Height = 72
            $pt = New-Object System.Windows.Controls.TextBlock
            $pt.Text = "NO PREVIEW"
            $pt.FontSize = 9
            $pt.Foreground = $window.Resources['MutedBrush']
            $pt.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $pt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $ph.Child = $pt
            [System.Windows.Controls.Grid]::SetColumn($ph, 0)
            $g2.Children.Add($ph) | Out-Null
        }
        # РёРјСЏ + Р±РµР№РґР¶ РєР°С‚РµРіРѕСЂРёРё + С‚РµС….РёРјСЏ
        $np = New-Object System.Windows.Controls.StackPanel
        $np.Margin = [System.Windows.Thickness]::new(12,0,8,0)
        $np.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $tbN = New-Object System.Windows.Controls.TextBlock
        $tbN.Text = $fn
        $tbN.FontSize = 14
        $tbN.FontWeight = [System.Windows.FontWeights]::Bold
        $tbN.Foreground = $window.Resources['TextBrush']
        $tbN.TextWrapping = [System.Windows.TextWrapping]::Wrap
        [void]$np.Children.Add($tbN)
        $bdg = New-Object System.Windows.Controls.Border
        $bdg.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $bdg.Background = $window.Resources['TableBgBrush']
        $bdg.Padding = [System.Windows.Thickness]::new(6,2,6,2)
        $bdg.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
        $bdg.Margin = [System.Windows.Thickness]::new(0,4,0,4)
        $bt = New-Object System.Windows.Controls.TextBlock
        $bt.Text = Get-MapCategory $m
        $bt.FontSize = 10
        $bt.Foreground = $window.Resources['MutedBrush']
        $bdg.Child = $bt
        [void]$np.Children.Add($bdg)
        $tbT = New-Object System.Windows.Controls.TextBlock
        $tbT.Text = $m + ".unr"
        $tbT.FontSize = 11
        $tbT.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas")
        $tbT.Foreground = $window.Resources['MutedBrush']
        [void]$np.Children.Add($tbT)
        [System.Windows.Controls.Grid]::SetColumn($np, 1)
        $g2.Children.Add($np) | Out-Null
        # Р·РІРµР·РґР° РёР·Р±СЂР°РЅРЅРѕРіРѕ
        $isFav = $script:FavMaps -contains $m
        $star = New-Object System.Windows.Controls.Button
        if ( $isFav ) { $star.Content = [string][char]0xE735 } else { $star.Content = [string][char]0xE734 }
        $star.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $star.FontSize = 18
        $star.Width = 32; $star.Height = 34
        $star.BorderThickness = [System.Windows.Thickness]::new(0)
        $star.Cursor = [System.Windows.Input.Cursors]::Hand
        if ( $isFav ) { $star.Foreground = [System.Windows.Media.Brushes]::Gold } else { $star.Foreground = $window.Resources['TextBrush'] }
        # v5.17.26: own template - the default button chrome paints an ugly blue
        # square on hover; now a subtle theme-colored highlight (rounded, small)
        $fBd = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.Border])
        $fBd.Name = "bd"
        $fBd.SetValue([System.Windows.Controls.Border]::BackgroundProperty, [System.Windows.Media.Brushes]::Transparent)
        $fBd.SetValue([System.Windows.Controls.Border]::CornerRadiusProperty, [System.Windows.CornerRadius]::new(6))
        # v5.17.27: плавное увеличение при наведении (принятый паттерн аффорданса)
        $fBd.SetValue([System.Windows.UIElement]::RenderTransformProperty, [System.Windows.Media.ScaleTransform]::new(1.0, 1.0))
        $fBd.SetValue([System.Windows.UIElement]::RenderTransformOriginProperty, [System.Windows.Point]::new(0.5, 0.5))
        $fCp = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ContentPresenter])
        $fCp.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Center)
        $fCp.SetValue([System.Windows.Controls.ContentPresenter]::VerticalAlignmentProperty, [System.Windows.VerticalAlignment]::Center)
        $fBd.AppendChild($fCp)
        $tplStar = New-Object System.Windows.Controls.ControlTemplate([System.Windows.Controls.Button])
        $tplStar.VisualTree = $fBd
        $trgOver = New-Object System.Windows.Trigger
        $trgOver.Property = [System.Windows.Controls.Button]::IsMouseOverProperty
        $trgOver.Value = $true
        $stOver = New-Object System.Windows.Setter
        $stOver.Property = [System.Windows.Controls.Border]::BackgroundProperty
        $stOver.Value = $window.Resources['TableBgBrush']
        $stOver.TargetName = "bd"
        $trgOver.Setters.Add($stOver)
        # v5.17.27: подсказка "можно нажать" - звезда золотеет на время наведения
        $stFg = New-Object System.Windows.Setter
        $stFg.Property = [System.Windows.Controls.Control]::ForegroundProperty
        $stFg.Value = [System.Windows.Media.Brushes]::Gold
        $trgOver.Setters.Add($stFg)
        # плавный scale 1 -> 1.18 и обратно
        $dur = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(120))
        $sbIn = New-Object System.Windows.Media.Animation.Storyboard
        foreach ( $dpT in @([System.Windows.Media.ScaleTransform]::ScaleXProperty, [System.Windows.Media.ScaleTransform]::ScaleYProperty) ) {
            $da = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 1.18, $dur)
            [System.Windows.Media.Animation.Storyboard]::SetTargetName($da, "bd")
            [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($da, (New-Object System.Windows.PropertyPath("(0).(1)", @([System.Windows.UIElement]::RenderTransformProperty, $dpT))))
            $sbIn.Children.Add($da)
        }
        $bsbIn = New-Object System.Windows.Media.Animation.BeginStoryboard
        $bsbIn.Storyboard = $sbIn
        $trgOver.EnterActions.Add($bsbIn)
        $sbOut = New-Object System.Windows.Media.Animation.Storyboard
        foreach ( $dpT in @([System.Windows.Media.ScaleTransform]::ScaleXProperty, [System.Windows.Media.ScaleTransform]::ScaleYProperty) ) {
            $da2 = New-Object System.Windows.Media.Animation.DoubleAnimation(1.18, 1.0, $dur)
            [System.Windows.Media.Animation.Storyboard]::SetTargetName($da2, "bd")
            [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($da2, (New-Object System.Windows.PropertyPath("(0).(1)", @([System.Windows.UIElement]::RenderTransformProperty, $dpT))))
            $sbOut.Children.Add($da2)
        }
        $bsbOut = New-Object System.Windows.Media.Animation.BeginStoryboard
        $bsbOut.Storyboard = $sbOut
        $trgOver.ExitActions.Add($bsbOut)
        $tplStar.Triggers.Add($trgOver)
        $star.Template = $tplStar
        $star.ToolTip = $(if ( $script:Lang -eq "ru" ) { "Р’ РёР·Р±СЂР°РЅРЅРѕРµ" } else { "Favorite" })
        $star.Tag = $m
        $star.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $star.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($star, 2)
        $star.Add_Click({
            param($s3, $e3)
            try {
                $m3 = [string]$s3.Tag
                if ( $script:FavMaps -contains $m3 ) { $script:FavMaps.Remove($m3) }
                else { [void]$script:FavMaps.Add($m3) }
                Save-Settings
                Build-MapRows -listPanel $script:MPList -allMaps $script:MPMaps -filter $script:MPSearch.Text -favOnly $script:MPFavOnly
                Update-MapCounter
            } catch { }
        })
        $g2.Children.Add($star) | Out-Null
        # Launch
        $ln = New-Object System.Windows.Controls.Button
        $ln.Content = "в–¶  Launch"
        $ln.Height = 40
        $ln.FontSize = 13
        $ln.FontWeight = [System.Windows.FontWeights]::Bold
        $ln.Background = $window.Resources['PanelBrush']
        $ln.Foreground = $window.Resources['TextBrush']
        $ln.Cursor = [System.Windows.Input.Cursors]::Hand
        $ln.Padding = [System.Windows.Thickness]::new(14,4,14,4)
        $ln.Tag = $m
        $ln.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $ln.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($ln, 3)
        $ln.Add_Click({
            param($s4, $e4)
            try { Switch-ToMap ([string]$s4.Tag) } catch { }
        })
        $g2.Children.Add($ln) | Out-Null
        $row.Child = $g2
        [void]$listPanel.Children.Add($row)
    }
    $script:MPShown = $shown
}
function Update-MapCounter {
    try {
        $L = $script:LocData[$script:Lang]
        $n = $script:MPShown
        $word = "maps"
        $script:MPCounter.Text = "$n $word"
    } catch { }
}
function Show-MapPicker {
    # v5.17.24: РїРёРєРµСЂ РєР°СЂС‚ РІ СЃС‚РёР»Рµ СЂРµС„РµСЂРµРЅСЃР°, С‚РµРјР° С‡РµСЂРµР· СЂРµСЃСѓСЂСЃС‹ РіР»Р°РІРЅРѕРіРѕ РѕРєРЅР°
    try {
        if ( -not (Test-Path $script:MapsDir) ) { Set-Status "maps folder not found"; return }
        $maps = @(Get-ChildItem -Path $script:MapsDir -Filter "*.unr" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.BaseName } | Where-Object { $_ -notin @('vssver') } | Sort-Object)
        if ( $maps.Count -eq 0 ) { Set-Status "no maps found"; return }
        $script:MPMaps = $maps
        $script:MPFilter = "all"
        $ru = ( $script:Lang -eq "ru" )

        $win2 = New-Object System.Windows.Window
        $win2.Title = "HP2 - " + $(if ( $ru ) { "Р’С‹Р±РѕСЂ РєР°СЂС‚С‹" } else { "Map Selector" })
        $win2.Width = 1060; $win2.Height = 920
        $win2.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
        # v5.17.25: Left/Top главного окна бывают NaN (окно ещё не показано) -
        # присваивание NaN кидает исключение и пикер "не нажимается"
        if ( -not [double]::IsNaN($window.Left) -and -not [double]::IsNaN($window.Top) ) {
            $win2.Left = $window.Left + 40; $win2.Top = $window.Top + 20
        } else {
            $win2.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        }
        $win2.Topmost = $true
        # v5.17.27: та же иконка (сова), что у панели - дефолтная смотрится чужеродно
        $iconPath2 = Join-Path $PSScriptRoot "icon.png"
        if ( Test-Path $iconPath2 ) {
            try {
                $ic2 = New-Object Windows.Media.Imaging.BitmapImage
                $ic2.BeginInit()
                $ic2.UriSource = (New-Object Uri($iconPath2))
                $ic2.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $ic2.EndInit()
                $ic2.Freeze()
                $win2.Icon = $ic2
            } catch { }
        }
        $win2.Background = $window.Resources['TableBgBrush']

        $root2 = New-Object System.Windows.Controls.Grid
        $root2.Margin = [System.Windows.Thickness]::new(16)
        $root2.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height=[System.Windows.GridLength]::Auto}))
        $root2.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height=[System.Windows.GridLength]::Auto}))
        $root2.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)}))

        # С…РµРґРµСЂ: Р·Р°РіРѕР»РѕРІРѕРє + РїРѕРёСЃРє + РІРєР»Р°РґРєРё
        $hdr = New-Object System.Windows.Controls.Grid
        $hdr.Margin = [System.Windows.Thickness]::new(0,0,0,10)
        [System.Windows.Controls.Grid]::SetRow($hdr, 0)
        $h1 = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::Auto}
        $h2 = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)}
        $h3 = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::Auto}
        $h4 = New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::Auto}
        $hdr.ColumnDefinitions.Add($h1); $hdr.ColumnDefinitions.Add($h2); $hdr.ColumnDefinitions.Add($h3); $hdr.ColumnDefinitions.Add($h4)
        $ttl = New-Object System.Windows.Controls.TextBlock
        $ttl.Text = $(if ( $ru ) { "Р’С‹Р±РѕСЂ РєР°СЂС‚С‹" } else { "Map Selector" })
        $ttl.FontSize = 20
        $ttl.FontWeight = [System.Windows.FontWeights]::Bold
        $ttl.Foreground = $window.Resources['TextBrush']
        $ttl.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($ttl, 0)
        $hdr.Children.Add($ttl) | Out-Null
        $search = New-Object System.Windows.Controls.TextBox
        $search.FontSize = 13
        $search.Height = 34
        $search.Margin = [System.Windows.Thickness]::new(10,0,10,0)
        $search.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($search, 1)
        $hdr.Children.Add($search) | Out-Null
        $tabs = New-Object System.Windows.Controls.StackPanel
        $tabs.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $tabs.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($tabs, 2)
        $tabAll = New-Object System.Windows.Controls.Button
        $tabAll.Content = $(if ( $ru ) { "Р’СЃРµ РєР°СЂС‚С‹" } else { "All Maps" })
        $tabAll.Height = 34
        $tabAll.Padding = [System.Windows.Thickness]::new(12,4,12,4)
        $tabAll.FontWeight = [System.Windows.FontWeights]::Bold
        $tabAll.Cursor = [System.Windows.Input.Cursors]::Hand
        $tabAll.Tag = "all"
        [void]$tabs.Children.Add($tabAll)
        $tabFav = New-Object System.Windows.Controls.Button
        $tabFav.Content = [string][char]0xE735 + "  " + $(if ( $ru ) { "РР·Р±СЂР°РЅРЅРѕРµ" } else { "Favorites" })
        $tabFav.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
        $tabFav.Height = 34
        $tabFav.Padding = [System.Windows.Thickness]::new(12,4,12,4)
        $tabFav.Cursor = [System.Windows.Input.Cursors]::Hand
        $tabFav.Tag = "fav"
        $tabFav.Margin = [System.Windows.Thickness]::new(6,0,0,0)
        [void]$tabs.Children.Add($tabFav)
        $hdr.Children.Add($tabs) | Out-Null
        # v5.17.27: выбор папки с картами - вдруг пользователь хранит их не в Paths игры
        $btnDir = New-Object System.Windows.Controls.Button
        $btnDir.Content = [string][char]0xE8B7
        $btnDir.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe MDL2 Assets")
        $btnDir.FontSize = 15
        $btnDir.Width = 34; $btnDir.Height = 34
        $btnDir.Margin = [System.Windows.Thickness]::new(8,0,0,0)
        $btnDir.Padding = [System.Windows.Thickness]::new(0)
        $btnDir.Background = $window.Resources['PanelBrush']
        $btnDir.Foreground = $window.Resources['TextBrush']
        $btnDir.Cursor = [System.Windows.Input.Cursors]::Hand
        $Ldir = $script:LocData[$script:Lang]
        $btnDir.ToolTip = $Ldir.TipMapsDir
        [System.Windows.Controls.Grid]::SetColumn($btnDir, 3)
        $btnDir.Add_Click({
            param($bd1, $be1)
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $dlg2 = New-Object System.Windows.Forms.FolderBrowserDialog
                $dlg2.Description = "HP2 - maps folder"
                $dlg2.SelectedPath = $script:MapsDir
                if ( $dlg2.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK ) {
                    $script:MapsDir = $dlg2.SelectedPath
                    Save-Settings
                    $script:MPMaps = @(Get-ChildItem -Path $script:MapsDir -Filter "*.unr" -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.BaseName } | Where-Object { $_ -notin @('vssver') } | Sort-Object)
                    Build-MapRows -listPanel $script:MPList -allMaps $script:MPMaps -filter $script:MPSearch.Text -favOnly $script:MPFavOnly
                    Update-MapCounter
                    Set-Status ("maps folder: " + $script:MapsDir)
                }
            } catch { }
        })
        $hdr.Children.Add($btnDir) | Out-Null
        $root2.Children.Add($hdr) | Out-Null

        # СЃС‡С‘С‚С‡РёРє
        $script:MPCounter = New-Object System.Windows.Controls.TextBlock
        $script:MPCounter.Foreground = $window.Resources['MutedBrush']
        $script:MPCounter.Margin = [System.Windows.Thickness]::new(0,0,0,8)
        [System.Windows.Controls.Grid]::SetRow($script:MPCounter, 1)
        $root2.Children.Add($script:MPCounter) | Out-Null

        # СЃРїРёСЃРѕРє
        $sv = New-Object System.Windows.Controls.ScrollViewer
        $sv.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
        [System.Windows.Controls.Grid]::SetRow($sv, 2)
        $root2.Children.Add($sv) | Out-Null
        $list = New-Object System.Windows.Controls.StackPanel
        $sv.Content = $list

        # Р·Р°РјС‹РєР°РЅРёСЏ - С‚РѕР»СЊРєРѕ script:!
        $script:MPWin = $win2
        $script:MPList = $list
        $script:MPSearch = $search
        $script:MPTabAll = $tabAll
        $script:MPTabFav = $tabFav
        $tabAll.Add_Click({
            try {
                $script:MPFilter = "all"
                $script:MPTabAll.Background = $window.Resources['StatusWarnBrush']
                $script:MPTabAll.Foreground = [System.Windows.Media.Brushes]::Black
                $script:MPTabFav.Background = $window.Resources['PanelBrush']
                $script:MPTabFav.Foreground = $window.Resources['TextBrush']
                Build-MapRows -listPanel $script:MPList -allMaps $script:MPMaps -filter $script:MPSearch.Text -favOnly $false
                Update-MapCounter
            } catch { }
        })
        $tabFav.Add_Click({
            try {
                $script:MPFilter = "fav"
                $script:MPTabFav.Background = $window.Resources['StatusWarnBrush']
                $script:MPTabFav.Foreground = [System.Windows.Media.Brushes]::Black
                $script:MPTabAll.Background = $window.Resources['PanelBrush']
                $script:MPTabAll.Foreground = $window.Resources['TextBrush']
                Build-MapRows -listPanel $script:MPList -allMaps $script:MPMaps -filter $script:MPSearch.Text -favOnly $true
                Update-MapCounter
            } catch { }
        })
        $search.Add_TextChanged({
            try {
                Build-MapRows -listPanel $script:MPList -allMaps $script:MPMaps -filter $script:MPSearch.Text -favOnly ($script:MPFilter -eq "fav")
                Update-MapCounter
            } catch { }
        })

        # Р°РєС‚РёРІРЅР°СЏ РІРєР»Р°РґРєР° РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ - All
        $tabAll.Background = $window.Resources['StatusWarnBrush']
        $tabAll.Foreground = [System.Windows.Media.Brushes]::Black
        Build-MapRows -listPanel $list -allMaps $maps -filter "" -favOnly $false
        Update-MapCounter

        $win2.Content = $root2
        $win2.ShowDialog() | Out-Null
    } catch {
        # v5.17.25: тихий catch маскировал ошибки - кнопка выглядела мёртвой
        Set-Status ("map picker error: " + $_.Exception.Message)
    }
}
$controls['BtnMapSwitch'].Add_Click({ Show-MapPicker })
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
                    # v5.17.30.5: ЯВНАЯ очистка - как кнопка корзины, должна ставить
                    # UserClearPending, иначе правило "путь пуст + кадры в панели"
                    # ВОССТАНАВЛИВАЛО кадры сразу после их удаления (юзер: "нажал
                    # очистку - ничего не произошло": в игре путь пуст, в таблице
                    # те же кадры). Живая проверка буфера: CLEAR исполнился игрой
                    $window.Dispatcher.BeginInvoke([Action]{
                        $script:UserClearPending = $true
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
$script:LogCloseTimer.Interval = [TimeSpan]::FromMilliseconds(100)
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
    # v5.17.27: карточка карты живёт в тех же состояниях (chip-only при выключенной
    # игре) - обновляем её вместе с кнопками, иначе после закрытия игры она
    # оставалась кликабельной со старым именем до следующего синка
    try { Update-MapPreview } catch { }
    # v5.17.30: подкнопка "вернуться к кадрам" (видна только при чужой карте)
    Update-KeyMapGoButton
    # v5.17.30.6: кнопки с ЖЁСТКИМ фоном (FOV->key мятный, Speed->key жёлтый и т.д.)
    # игнорируют стандартный "серый" триггер стиля при IsEnabled=False (локальное
    # значение фона приоритетнее триггера) - выглядели ДОСТУПНЫМИ будучи
    # заблокированными (репорт юзера). Затемнение Opacity = честная индикация
    function Set-CtlEnabled([string]$name, [bool]$en) {
        try {
            $controls[$name].IsEnabled = $en
            $controls[$name].Opacity = $(if ( $en ) { 1.0 } else { 0.45 })
        } catch { }
    }
    # v5.17.14 (#8): ветка ИГРАЕТ проверяется ПЕРВОЙ и безусловно - иначе синк или
    # 5.4с-полл со сбойным сканом (CurrentMap слетел в "") гасили Stop посреди
    # проигрывания, а через несколько секунд полл его возвращал
    if ( $script:Playing ) {
        foreach ( $b in $script:PlayLock ) {
            Set-CtlEnabled $b $false
        }
        Set-CtlEnabled 'BtnExport' $true
        $controls['BtnPathStop'].IsEnabled = $true
        Set-CtlEnabled 'BtnPathPlay' $true
        Set-CtlEnabled 'BtnPathPlaySpeed' $true
        return
    }
    # v5.15: игра не на карте (закрыта или меню) - доступна только Прозрачность и поле
    # секунд; таблица с кадрами остаётся живой ради оффлайн-удаления
    $gameOn = ($script:CurrentMap -ne "")
    if ( -not $gameOn ) {
        $rowsLeft = ($script:KeyRows -ne $null -and $script:KeyRows.Count -gt 0)
        foreach ( $b in $script:NoGameDep ) {
            Set-CtlEnabled $b $false
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
        # v5.17.30: расширенный лок - FOV/Speed->ALL тоже пишут в путь игры, а он на
        # другой карте пуст; таблица замораживается целиком (строки чужой карты видны,
        # но edit/goto/trash на них идти не должны - goto/вставка считаются по пути игры)
        foreach ( $b in ($script:SelDep + @('BtnPathAdd','BtnPathPlay','BtnPathPlaySpeed','BtnFovKey','BtnKeySpeed','BtnFovAll','BtnSpeedAll')) ) {
            Set-CtlEnabled $b $false
        }
        try { $controls['DgKeys'].IsEnabled = $false } catch { }
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
    # v5.17.30: КРИТИЧНЫЙ фикс - NoGameDep кнопки никогда не включались обратно.
    # Ветка "игра не на карте" (старт панели до синка: CurrentMap ещё пуст, игра
    # закрыта/в меню) их выключала, нормальная ветка - нет. Кнопки выглядели
    # цветными (жёсткий фон у ADD), но НЕ КЛИКАЛИСЬ ("карта видна, кнопки мертвы"
    # - репродукция: перезапуск панели при уже загруженной карте)
    # v5.17.30.6: ре-энeйбл ПЕРЕМЕЩЁН ДО SelDep/KeysDep - он ПЕРЕЗАПИСЫВАЛ их
    # правила (BtnFovKey/BtnKeySpeed из NoGameDep включались после "IsEnabled=$has"
    # и оставались яркими БЕЗ выделенного кадра - репорт юзера; FovAll/SpeedAll
    # перезаписывались KeysDep ниже, потому виделись правильными)
    foreach ( $b in $script:NoGameDep ) { Set-CtlEnabled $b $true }
    foreach ( $b in $script:SelDep ) { Set-CtlEnabled $b $has }
    # v5.17.30: после wrong-map лока и PlayLock таблица включается обратно явно
    try { $controls['DgKeys'].IsEnabled = $true } catch { }
    foreach ( $b in $script:KeysDep ) { Set-CtlEnabled $b ($n -gt 0) }
    Set-CtlEnabled 'BtnPathClear' ($n -gt 0)
    $controls['BtnPathStop'].IsEnabled = $false
    # v5.17.6: FOV->key / Speed->key серые, если выбранная строка УЖЕ имеет значение из поля
    try {
        $selRow = $controls['DgKeys'].SelectedItem
        if ( $selRow -ne $null ) {
            $fovTxt = $controls['TbFov'].Text.Trim()
            $spdTxt = $controls['TbSpeed'].Text.Trim()
            Set-CtlEnabled 'BtnFovKey' ( ($fovTxt -match '^\d+(\.\d+)?$') -and ([double]$fovTxt -ne $selRow.FOV) )
            Set-CtlEnabled 'BtnKeySpeed' ( ($spdTxt -match '^\d+(\.\d+)?$') -and ([double]$spdTxt -ne $selRow.Speed) )
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
            Set-CtlEnabled 'BtnFovAll' (-not $sameFov)
            Set-CtlEnabled 'BtnSpeedAll' (-not $sameSpd)
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
$script:PollInGame = 0
$script:UiTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:UiTimer.Interval = [TimeSpan]::FromMilliseconds(90)
$script:UiTimer.Add_Tick({
    # резервное вращение вручную (если анимация не завелась): пока идёт синк - шаг за тик
    if ( $script:SyncBusy -and $script:SpinManual -and $script:SpinTransform -ne $null ) {
        $script:SpinAngle = ($script:SpinAngle + 27) % 360
        $script:SpinTransform.Angle = $script:SpinAngle
    }
    # v5.17.30.4: завершение скана ОТКЛАДЫВАЕТСЯ на время печати команд - парс
    # событий идёт на UI-потоке и морил посимвольную печать (буквы раз в 5-10с).
    # AsyncState остаётся 2 - следующий тик после отправки доделает
    if ( [MemScanPanel]::AsyncState -eq 2 -and -not $script:SendBusy ) { Complete-SyncFromLog }
    # v5.15.1: состояние игры опрашиваем раз в ~5.4с:
    # - игра вышла -> сброс карты/плей-состояния и лочка
    # - игра есть, уровень не определён -> полный рескан ловит MAP-событие уровня и разблокирует UI
    #   (иначе дедлок: кнопки заблокированы - синк сам не запустится)
    $script:GamePoll = ($script:GamePoll + 1) % 60
    if ( $script:GamePoll -eq 0 ) {
        $g = Get-Process Game -ErrorAction SilentlyContinue
        if ( $g -eq $null ) {
            # v5.17.14 (#7): игра не запущена - статус КРАСНЫМ, постоянно (каждый полл)
            Set-Status $script:LocData[$script:Lang].TipNoWindow "err"
            if ( $script:CurrentMap -ne "" -or $script:Playing ) {
                $script:CurrentMap = ""
                if ( $script:Playing ) { Set-Playing $false }
                Update-SelectionButtons
            }
        } elseif ( $script:SendBusy ) {
            # v5.17.30.2: ЖИВОЙ ФАКТ - отправка из пикера висела ~2 мин при норме ~5с
            # (SendBusy всё это время молча отбивал команды, юзер: "ничего не
            # происходит"). Причина блокировки неясна - надёжный авто-борт: флаг
            # старше 25с = отправка умерла, сбрасываем (нормальная печать <10с).
            # v5.17.30.1: Sync-FromLog в этой ветке безопасен (сброс 20s-зависшего
            # скана теперь достижим)
            if ( $script:SendStartedAt -ne $null -and ((Get-Date) - $script:SendStartedAt).TotalSeconds -gt 60 ) {
                $script:SendBusy = $false
                Set-Status "send timed out (>60s) - flag reset, try again" "warn"
            }
            Sync-FromLog
        } elseif ( $script:CurrentMap -eq "" ) {
            # v5.17.1: карта не определена - запрашиваем у игры снапшот: без -log буфер
            # крошечный и MAP-событие уровня не выживает, а дамп несёт DUMPMAP.
            # v5.17.15: ПОЛЛ идёт мимо Confirm-GameActive - фоновые зонды не должны
            # воровать фокус и выходить из меню каждые 5.4с
            $script:ConfirmBypass = $true
            try { Send-GameCommand "PathDumpKeys" | Out-Null } finally { $script:ConfirmBypass = $false }
            Sync-FromLog -Force
        } else {
            # v5.17.30: игра на карте - полл обязан синкаться БЕЗ зонда. Раньше синков
            # в этом состоянии не было вообще: смена карты в игре (die-телепорт,
            # переход, open из панели) не обнаруживалась, пока юзер не нажмёт кнопку
            # или панель не перезапустится. Быстрый скан каждый полл ловит смену
            # поколения за ~5.4с (фильтр newMax теперь учитывает gen); раз в 10 поллов
            # (~54с) полный рескан - буфер лога может перевылелиться, кэш областей
            # устаревает и быстрый скан молча видит только старые копии
            $script:PollInGame = ($script:PollInGame + 1) % 10
            if ( $script:PollInGame -eq 0 ) { Sync-FromLog -Force } else { Sync-FromLog }
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
        TipMapsDir = "Choose the folder with .unr maps"
        TipLaunchMap = "The game is not running - click to open the map picker and launch the game on the selected map"
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
        MapSwitch = "⇄  Switch map"
        TipMapSwitch = "Open the map picker"
        MapWarnQ = "Switch map? The in-game path will be cleared (a backup copy stays in the panel - Import restores it)."
        KeyMapGo = "→  {0}"
        TipKeyMapGo = "The keyframes belong to '{0}', but another map is loaded - click to load '{0}' (the in-game path restarts; the keyframes stay in the panel)"
        PushKeysQ = "Keyframes restored in the table, but the in-game path is empty after the map load.`nWrite {0} keyframes into the game now?"
        PushKeysTitle = "Restore path"
        PushKeysNo = "keyframes are in the table - use Import from file to write them into the game"
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
        TipMapsDir = "Выбрать папку с картами .unr"
        TipLaunchMap = "Игра не запущена - откройте выбор карты и запустите игру на выбранной карте"
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
        MapSwitch = "⇄  Сменить карту"
        TipMapSwitch = "Открыть выбор карты"
        MapWarnQ = "Сменить карту? Путь в игре сбросится (копия кадров осталась в панели - восстановится через Импорт)."
        KeyMapGo = "→  {0}"
        TipKeyMapGo = "Кадры относятся к карте '{0}', но сейчас загружена другая - клик загрузит '{0}' (путь в игре перезапишется; кадры останутся в панели)"
        PushKeysQ = "Кадры восстановлены в таблице, но путь в игре пуст после загрузки карты.`nЗаписать {0} кадров в игру сейчас?"
        PushKeysTitle = "Восстановить путь"
        PushKeysNo = "кадры в таблице - для записи в игру используйте Импорт из файла"
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
    Update-MapPreview
    # v5.17.30: подкнопка "вернуться к кадрам" - перерисовать контент под язык
    Update-KeyMapGoButton
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

# ---------- settings: тема + язык + избранные карты переживают перезапуск ----------
$script:SettingsFile = Join-Path $PSScriptRoot "settings.json"
$script:FavMaps = New-Object System.Collections.Generic.List[string]
function Save-Settings {
    try {
        @{ theme = $(if ( $script:DarkTheme ) { "dark" } else { "light" }); lang = $script:Lang; favmaps = @($script:FavMaps); mapsdir = $script:MapsDir } |
            ConvertTo-Json | Set-Content -Path $script:SettingsFile -Encoding UTF8
    } catch { }
}
$script:StartTheme = "dark"
$script:StartLang = "en"
try {
    $s = Get-Content $script:SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json
    if ( $s.theme -eq "light" ) { $script:StartTheme = "light" }
    if ( $s.lang -eq "ru" ) { $script:StartLang = "ru" }
    if ( $s.favmaps -ne $null ) {
        foreach ( $fm in @($s.favmaps) ) { if ( $fm -ne $null -and $fm -ne "" ) { [void]$script:FavMaps.Add([string]$fm) } }
    }
    # v5.17.27: пользовательская папка карт (вдруг хранит не в Paths игры)
    if ( $s.mapsdir -ne $null -and $s.mapsdir -ne "" -and (Test-Path ([string]$s.mapsdir)) ) {
        $script:MapsDir = [string]$s.mapsdir
    }
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
# v5.17.30.5: НО если в буфере игры уже был CLEAR (юзер явно очистил путь, а
# панель перезапускалась) - восстановление вернуло бы только что удалённые кадры
# (живой случай: F11 очистил путь, панель показывала кадры снова и снова)
if ( $script:KeyRows.Count -eq 0 -and -not $script:SawClearInBuffer ) { Restore-KeysBackup }

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


