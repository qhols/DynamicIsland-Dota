using System.Diagnostics;
using System.Runtime.InteropServices;

namespace MediaBridge;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
internal class MMDeviceEnumeratorComObject { }

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IMMDeviceEnumerator
{
    int NotImpl1();
    [PreserveSig]
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IMMDevice
{
    [PreserveSig]
    int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
}

[Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IAudioMeterInformation
{
    [PreserveSig]
    int GetPeakValue(out float pfPeak);
    [PreserveSig]
    int GetMeteringChannelCount(out int pnChannelCount);
}

[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IAudioSessionManager2
{
    [PreserveSig] int NotImpl1();
    [PreserveSig] int NotImpl2();
    [PreserveSig] int GetSessionEnumerator(out IntPtr SessionEnum);
}

[Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IAudioSessionControl
{
    [PreserveSig] int GetState(out int pRetVal);
    [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    [PreserveSig] int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string Value, [In] ref Guid EventContext);
    [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
    [PreserveSig] int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string Value, [In] ref Guid EventContext);
    [PreserveSig] int GetGroupingParam(out Guid pRetVal);
}

public sealed class SessionEntry
{
    public int Index;
    public uint Pid;
    public string ProcessName = "";
    public string DisplayName = "";
    public string IconPath = "";
    public string Family = "";
    public int State;
    public float Volume;
}

public static class AppAudioControl
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("ole32.dll")]
    private static extern int CoInitializeEx(IntPtr pvReserved, uint dwCoInit);

    private static volatile bool _isDotaFocused;
    private static Thread? _watcherThread;
    private static bool _started;
    private static readonly object _focusLock = new();

    public static void StartFocusWatcher()
    {
        lock (_focusLock)
        {
            if (_started) return;
            _started = true;
            _watcherThread = new Thread(FocusLoop)
            {
                IsBackground = true,
                Name = "DotaFocusWatcher"
            };
            _watcherThread.SetApartmentState(ApartmentState.STA);
            _watcherThread.Start();
        }
    }

    private static void FocusLoop()
    {
        try
        {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk != IntPtr.Zero)
            {
                SetThreadDesktop(hDesk);
            }
        }
        catch { }

        while (true)
        {
            try
            {
                IntPtr fg = GetForegroundWindow();
                if (fg != IntPtr.Zero)
                {
                    GetWindowThreadProcessId(fg, out uint pid);
                    if (pid > 0)
                    {
                        var p = Process.GetProcessById((int)pid);
                        _isDotaFocused = p.ProcessName.Contains("dota2", StringComparison.OrdinalIgnoreCase);
                    }
                    else
                    {
                        _isDotaFocused = false;
                    }
                }
                else
                {
                    _isDotaFocused = false;
                }
            }
            catch
            {
                _isDotaFocused = false;
            }
            Thread.Sleep(100);
        }
    }

    public static bool IsDotaFocused()
    {
        StartFocusWatcher();
        return _isDotaFocused;
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetCountDelegate(IntPtr thisPtr, out int count);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetSessionDelegate(IntPtr thisPtr, int index, out IntPtr session);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int QueryInterfaceDelegate(IntPtr thisPtr, ref Guid riid, out IntPtr ppv);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetProcessIdDelegate(IntPtr thisPtr, out uint pid);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int GetMasterVolumeDelegate(IntPtr thisPtr, out float level);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int SetMasterVolumeDelegate(IntPtr thisPtr, float level, ref Guid eventContext);

    private static Guid IID_IAudioSessionControl = new("F4B1A599-7266-4319-A8CA-E70ACB11E8CD");
    private static Guid IID_IAudioSessionControl2 = new("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D");
    private static Guid IID_ISimpleAudioVolume = new("87CE5498-68D6-44E5-9215-6DA47EF883D8");
    private static Guid IID_IAudioSessionManager2 = new("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");

    private static readonly Dictionary<uint, string> _pidCache = new();
    private static string GetProcessName(uint pid)
    {
        if (pid == 0) return "";
        lock (_pidCache)
        {
            if (_pidCache.TryGetValue(pid, out string? name)) return name;
            try
            {
                name = Process.GetProcessById((int)pid).ProcessName.ToLowerInvariant();
                _pidCache[pid] = name;
                return name;
            }
            catch
            {
                _pidCache[pid] = "";
                return "";
            }
        }
    }

    public static string GetSessionFamily(string pName, string displayName, string iconPath)
    {
        string combined = (pName + " " + displayName + " " + iconPath).ToLowerInvariant();
        if (combined.Contains("dotify")) return "dotify";
        if (combined.Contains("spotify")) return "spotify";
        if (combined.Contains("yandex")) return "yandex";
        if (combined.Contains("aimp")) return "aimp";
        if (combined.Contains("foobar")) return "foobar";
        if (combined.Contains("apple") || combined.Contains("itunes")) return "apple";
        if (combined.Contains("tidal")) return "tidal";
        if (combined.Contains("deezer")) return "deezer";
        if (combined.Contains("vlc")) return "vlc";
        if (combined.Contains("zen")) return "zen";
        if (combined.Contains("chrome")) return "chrome";
        if (combined.Contains("firefox")) return "firefox";
        if (combined.Contains("msedge")) return "msedge";
        if (combined.Contains("opera")) return "opera";
        if (combined.Contains("brave")) return "brave";
        if (combined.Contains("vivaldi")) return "vivaldi";
        return "";
    }

    public static bool IsMusicPlayerFamily(string fam)
    {
        return fam is "dotify" or "spotify" or "yandex" or "aimp" or "foobar" or "apple" or "tidal" or "deezer" or "vlc";
    }

    public static List<SessionEntry> EnumerateAllSessions()
    {
        CoInitializeEx(IntPtr.Zero, 0);
        var list = new List<SessionEntry>();
        try
        {
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            if (enumerator.GetDefaultAudioEndpoint(0, 1, out IMMDevice dev) != 0 || dev == null) return list;

            var iidMgr = IID_IAudioSessionManager2;
            if (dev.Activate(ref iidMgr, 1, IntPtr.Zero, out object o) != 0 || o == null) return list;
            var mgr = (IAudioSessionManager2)o;
            if (mgr.GetSessionEnumerator(out IntPtr pEnum) != 0 || pEnum == IntPtr.Zero) return list;

            IntPtr vtbl = Marshal.ReadIntPtr(pEnum);
            var getCount = Marshal.GetDelegateForFunctionPointer<GetCountDelegate>(Marshal.ReadIntPtr(vtbl, 3 * IntPtr.Size));
            var getSession = Marshal.GetDelegateForFunctionPointer<GetSessionDelegate>(Marshal.ReadIntPtr(vtbl, 4 * IntPtr.Size));
            getCount(pEnum, out int count);

            for (int i = 0; i < count; i++)
            {
                getSession(pEnum, i, out IntPtr pSession);
                if (pSession == IntPtr.Zero) continue;

                IntPtr sVtbl = Marshal.ReadIntPtr(pSession);
                var qi = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(Marshal.ReadIntPtr(sVtbl, 0));

                uint pid = 0;
                var iidCtl2 = IID_IAudioSessionControl2;
                if (qi(pSession, ref iidCtl2, out IntPtr pCtl2) == 0 && pCtl2 != IntPtr.Zero)
                {
                    IntPtr ctl2Vtbl = Marshal.ReadIntPtr(pCtl2);
                    var getPid = Marshal.GetDelegateForFunctionPointer<GetProcessIdDelegate>(Marshal.ReadIntPtr(ctl2Vtbl, 14 * IntPtr.Size));
                    getPid(pCtl2, out pid);
                    Marshal.Release(pCtl2);
                }

                string pName = GetProcessName(pid);

                string displayName = "";
                string iconPath = "";
                int state = 0;
                var iidCtl = IID_IAudioSessionControl;
                if (qi(pSession, ref iidCtl, out IntPtr pCtl) == 0 && pCtl != IntPtr.Zero)
                {
                    var ctl = (IAudioSessionControl)Marshal.GetObjectForIUnknown(pCtl);
                    ctl.GetState(out state);
                    ctl.GetDisplayName(out displayName);
                    ctl.GetIconPath(out iconPath);
                    Marshal.Release(pCtl);
                }

                float vol = 1.0f;
                var iidVol = IID_ISimpleAudioVolume;
                if (qi(pSession, ref iidVol, out IntPtr pVol) == 0 && pVol != IntPtr.Zero)
                {
                    IntPtr volVtbl = Marshal.ReadIntPtr(pVol);
                    var getVol = Marshal.GetDelegateForFunctionPointer<GetMasterVolumeDelegate>(Marshal.ReadIntPtr(volVtbl, 4 * IntPtr.Size));
                    getVol(pVol, out vol);
                    Marshal.Release(pVol);
                }

                string fam = GetSessionFamily(pName, displayName, iconPath);
                if (!string.IsNullOrEmpty(fam))
                {
                    list.Add(new SessionEntry
                    {
                        Index = i,
                        Pid = pid,
                        ProcessName = pName,
                        DisplayName = displayName,
                        IconPath = iconPath,
                        Family = fam,
                        State = state,
                        Volume = vol
                    });
                }
                Marshal.Release(pSession);
            }
            Marshal.Release(pEnum);
        }
        catch { }
        return list;
    }

    public static string ResolveTargetFamily(string preferredFamily)
    {
        var sessions = EnumerateAllSessions();
        if (!string.IsNullOrEmpty(preferredFamily))
        {
            foreach (var s in sessions)
            {
                if (s.Family == preferredFamily) return preferredFamily;
            }
        }
        foreach (var s in sessions)
        {
            if (s.State == 1 && IsMusicPlayerFamily(s.Family)) return s.Family;
        }
        foreach (var s in sessions)
        {
            if (IsMusicPlayerFamily(s.Family)) return s.Family;
        }
        foreach (var s in sessions)
        {
            if (s.State == 1) return s.Family;
        }
        return sessions.Count > 0 ? sessions[0].Family : "";
    }

    public static int GetFamilyAudioState(string preferredFamily)
    {
        if (string.IsNullOrEmpty(preferredFamily)) return -1;
        var sessions = EnumerateAllSessions();
        bool found = false;
        foreach (var s in sessions)
        {
            if (s.Family == preferredFamily)
            {
                found = true;
                if (s.State == 1) return 1;
            }
        }
        return found ? 0 : -1;
    }

    public static float GetAppVolume(string preferredFamily = "")
    {
        string targetFam = ResolveTargetFamily(preferredFamily);
        if (string.IsNullOrEmpty(targetFam)) return 1.0f;

        foreach (var s in EnumerateAllSessions())
        {
            if (s.Family == targetFam) return s.Volume;
        }
        return 1.0f;
    }

    public static float StepAppVolume(float delta, string preferredFamily = "")
    {
        string targetFam = ResolveTargetFamily(preferredFamily);
        if (string.IsNullOrEmpty(targetFam)) return 1.0f;

        CoInitializeEx(IntPtr.Zero, 0);
        float curVol = -1.0f;
        foreach (var s in EnumerateAllSessions())
        {
            if (s.Family == targetFam)
            {
                curVol = s.Volume;
                break;
            }
        }
        if (curVol < 0.0f) curVol = 1.0f;
        float newVol = Math.Min(1.0f, Math.Max(0.0f, curVol + delta));

        try
        {
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            if (enumerator.GetDefaultAudioEndpoint(0, 1, out IMMDevice dev) != 0 || dev == null) return newVol;
            var iidMgr = IID_IAudioSessionManager2;
            if (dev.Activate(ref iidMgr, 1, IntPtr.Zero, out object o) != 0 || o == null) return newVol;
            var mgr = (IAudioSessionManager2)o;
            if (mgr.GetSessionEnumerator(out IntPtr pEnum) != 0 || pEnum == IntPtr.Zero) return newVol;

            IntPtr vtbl = Marshal.ReadIntPtr(pEnum);
            var getCount = Marshal.GetDelegateForFunctionPointer<GetCountDelegate>(Marshal.ReadIntPtr(vtbl, 3 * IntPtr.Size));
            var getSession = Marshal.GetDelegateForFunctionPointer<GetSessionDelegate>(Marshal.ReadIntPtr(vtbl, 4 * IntPtr.Size));
            getCount(pEnum, out int count);

            for (int i = 0; i < count; i++)
            {
                getSession(pEnum, i, out IntPtr pSession);
                if (pSession == IntPtr.Zero) continue;

                IntPtr sVtbl = Marshal.ReadIntPtr(pSession);
                var qi = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(Marshal.ReadIntPtr(sVtbl, 0));

                uint pid = 0;
                var iidCtl2 = IID_IAudioSessionControl2;
                if (qi(pSession, ref iidCtl2, out IntPtr pCtl2) == 0 && pCtl2 != IntPtr.Zero)
                {
                    IntPtr ctl2Vtbl = Marshal.ReadIntPtr(pCtl2);
                    var getPid = Marshal.GetDelegateForFunctionPointer<GetProcessIdDelegate>(Marshal.ReadIntPtr(ctl2Vtbl, 14 * IntPtr.Size));
                    getPid(pCtl2, out pid);
                    Marshal.Release(pCtl2);
                }

                string pName = GetProcessName(pid);
                string displayName = "";
                string iconPath = "";
                var iidCtl = IID_IAudioSessionControl;
                if (qi(pSession, ref iidCtl, out IntPtr pCtl) == 0 && pCtl != IntPtr.Zero)
                {
                    var ctl = (IAudioSessionControl)Marshal.GetObjectForIUnknown(pCtl);
                    ctl.GetDisplayName(out displayName);
                    ctl.GetIconPath(out iconPath);
                    Marshal.Release(pCtl);
                }

                string fam = GetSessionFamily(pName, displayName, iconPath);
                if (fam == targetFam)
                {
                    var iidVol = IID_ISimpleAudioVolume;
                    if (qi(pSession, ref iidVol, out IntPtr pVol) == 0 && pVol != IntPtr.Zero)
                    {
                        IntPtr volVtbl = Marshal.ReadIntPtr(pVol);
                        var setVol = Marshal.GetDelegateForFunctionPointer<SetMasterVolumeDelegate>(Marshal.ReadIntPtr(volVtbl, 3 * IntPtr.Size));
                        Guid g = Guid.Empty;
                        setVol(pVol, newVol, ref g);
                        lock (_duckLock)
                        {
                            if (_isDucked)
                            {
                                string sessionKey = pid + "_" + i;
                                float duckMultiplier = 1.0f - _targetDuckPercent;
                                float restoredEquivalent = duckMultiplier > 0.001f ? (newVol / duckMultiplier) : newVol;
                                _savedSessionVolumes[sessionKey] = Math.Min(1.0f, Math.Max(0.0f, restoredEquivalent));
                            }
                        }
                        Marshal.Release(pVol);
                    }
                }
                Marshal.Release(pSession);
            }
            Marshal.Release(pEnum);
        }
        catch { }
        return newVol;
    }

    private static readonly object _duckLock = new();
    private static volatile bool _isDucked;
    private static volatile bool _duckResetRequested;
    private static long _duckEndTime;
    private static float _targetDuckPercent = 0.5f;
    private static readonly Dictionary<string, float> _savedSessionVolumes = new();
    private static Thread? _workerThread;

    public static void DuckAllAudio(float duckPercent, int holdMs)
    {
        if (duckPercent <= 0.001f) return;
        lock (_duckLock)
        {
            long now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            long newEnd = now + holdMs;
            if (newEnd > _duckEndTime) _duckEndTime = newEnd;
            _targetDuckPercent = duckPercent;

            if (_isDucked)
            {
                _duckResetRequested = true;
                return;
            }

            _isDucked = true;
            _duckResetRequested = false;

            _workerThread = new Thread(EnvelopeWorker)
            {
                IsBackground = true,
                Name = "AudioDuckEnvelope"
            };
            _workerThread.Start();
        }
    }

    private static void ApplyDuckLevel(float duckFrac)
    {
        try
        {
            CoInitializeEx(IntPtr.Zero, 0);
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            if (enumerator.GetDefaultAudioEndpoint(0, 1, out IMMDevice dev) != 0 || dev == null) return;
            var iidMgr = IID_IAudioSessionManager2;
            if (dev.Activate(ref iidMgr, 1, IntPtr.Zero, out object o) != 0 || o == null) return;
            var mgr = (IAudioSessionManager2)o;
            if (mgr.GetSessionEnumerator(out IntPtr pEnum) != 0 || pEnum == IntPtr.Zero) return;

            IntPtr vtbl = Marshal.ReadIntPtr(pEnum);
            var getCount = Marshal.GetDelegateForFunctionPointer<GetCountDelegate>(Marshal.ReadIntPtr(vtbl, 3 * IntPtr.Size));
            var getSession = Marshal.GetDelegateForFunctionPointer<GetSessionDelegate>(Marshal.ReadIntPtr(vtbl, 4 * IntPtr.Size));
            getCount(pEnum, out int count);

            uint currentPid = (uint)Environment.ProcessId;

            for (int i = 0; i < count; i++)
            {
                getSession(pEnum, i, out IntPtr pSession);
                if (pSession == IntPtr.Zero) continue;

                IntPtr sVtbl = Marshal.ReadIntPtr(pSession);
                var qi = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(Marshal.ReadIntPtr(sVtbl, 0));

                uint pid = 0;
                var iidCtl2 = IID_IAudioSessionControl2;
                if (qi(pSession, ref iidCtl2, out IntPtr pCtl2) == 0 && pCtl2 != IntPtr.Zero)
                {
                    IntPtr ctl2Vtbl = Marshal.ReadIntPtr(pCtl2);
                    var getPid = Marshal.GetDelegateForFunctionPointer<GetProcessIdDelegate>(Marshal.ReadIntPtr(ctl2Vtbl, 14 * IntPtr.Size));
                    getPid(pCtl2, out pid);
                    Marshal.Release(pCtl2);
                }

                if (pid != 0 && pid == currentPid)
                {
                    Marshal.Release(pSession);
                    continue;
                }

                var iidVol = IID_ISimpleAudioVolume;
                if (qi(pSession, ref iidVol, out IntPtr pVol) == 0 && pVol != IntPtr.Zero)
                {
                    IntPtr volVtbl = Marshal.ReadIntPtr(pVol);
                    var getVol = Marshal.GetDelegateForFunctionPointer<GetMasterVolumeDelegate>(Marshal.ReadIntPtr(volVtbl, 4 * IntPtr.Size));
                    var setVol = Marshal.GetDelegateForFunctionPointer<SetMasterVolumeDelegate>(Marshal.ReadIntPtr(volVtbl, 3 * IntPtr.Size));

                    string sessionKey = pid + "_" + i;
                    if (!_savedSessionVolumes.TryGetValue(sessionKey, out float origVol))
                    {
                        getVol(pVol, out float cur);
                        _savedSessionVolumes[sessionKey] = cur;
                        origVol = cur;
                    }

                    float newVol = Math.Max(0.0f, Math.Min(1.0f, origVol * (1.0f - duckFrac)));
                    Guid g = Guid.Empty;
                    setVol(pVol, newVol, ref g);
                    Marshal.Release(pVol);
                }
                Marshal.Release(pSession);
            }
            Marshal.Release(pEnum);
        }
        catch { }
    }

    private static void EnvelopeWorker()
    {
        try
        {
            for (int step = 1; step <= 3; step++)
            {
                float t = step / 3.0f;
                float duckFrac = _targetDuckPercent * (t * t);
                ApplyDuckLevel(duckFrac);
                Thread.Sleep(20);
            }
            ApplyDuckLevel(_targetDuckPercent);

            while (true)
            {
                long now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                if (now >= _duckEndTime) break;
                if (_duckResetRequested)
                {
                    _duckResetRequested = false;
                    ApplyDuckLevel(_targetDuckPercent);
                }
                Thread.Sleep(30);
            }

            int releaseSteps = 8;
            for (int step = 1; step <= releaseSteps; step++)
            {
                if (_duckResetRequested)
                {
                    _duckResetRequested = false;
                    ApplyDuckLevel(_targetDuckPercent);
                    while (true)
                    {
                        long now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                        if (now >= _duckEndTime) break;
                        Thread.Sleep(30);
                    }
                    step = 0;
                    continue;
                }
                float t = step / (float)releaseSteps;
                float smoothT = t * t * (3.0f - 2.0f * t);
                float duckFrac = _targetDuckPercent * (1.0f - smoothT);
                ApplyDuckLevel(duckFrac);
                Thread.Sleep(44);
            }

            ApplyDuckLevel(0.0f);
        }
        catch { }
        finally
        {
            lock (_duckLock)
            {
                _savedSessionVolumes.Clear();
                _isDucked = false;
                _duckResetRequested = false;
                _workerThread = null;
            }
        }
    }

    public static void RestoreAudioDucking()
    {
        lock (_duckLock)
        {
            if (!_isDucked) return;
            ApplyDuckLevel(0.0f);
            _savedSessionVolumes.Clear();
            _isDucked = false;
            _duckResetRequested = false;
            _workerThread = null;
        }
    }
}

public static class Meter
{
    private static IAudioMeterInformation? _meter;

    [DllImport("ole32.dll")]
    private static extern int CoInitializeEx(IntPtr pvReserved, uint dwCoInit);

    private static void Init()
    {
        if (_meter == null)
        {
            CoInitializeEx(IntPtr.Zero, 0);
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            enumerator.GetDefaultAudioEndpoint(0, 1, out IMMDevice dev);
            var iid = typeof(IAudioMeterInformation).GUID;
            dev.Activate(ref iid, 1, IntPtr.Zero, out object o);
            _meter = (IAudioMeterInformation)o;
        }
    }

    public static float[] GetBars()
    {
        try
        {
            Init();
            if (_meter == null) return new float[] { 0f, 0f, 0f, 0f, 0f };
            _meter.GetPeakValue(out float peak);
            if (peak <= 0.001f) return new float[] { 0f, 0f, 0f, 0f, 0f };
            float p = Math.Min(1.0f, Math.Max(0.0f, peak));
            return new float[]
            {
                (float)Math.Round(p * 0.7f, 2),
                (float)Math.Round(p * 0.85f, 2),
                (float)Math.Round(p, 2),
                (float)Math.Round(p * 0.85f, 2),
                (float)Math.Round(p * 0.7f, 2)
            };
        }
        catch
        {
            return new float[] { 0f, 0f, 0f, 0f, 0f };
        }
    }
}
