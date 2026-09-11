try {
    $currPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
    Get-Process -Name "media_bridge" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $currPid } | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name LIKE 'powershell%' AND CommandLine LIKE '%media_bridge.ps1%'" -ErrorAction SilentlyContinue | Where-Object { $_.ProcessId -ne $currPid } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 150
} catch {}

# Dynamic Island Media Engine UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing

$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media, ContentType = WindowsRuntime]
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media, ContentType = WindowsRuntime]
$null = [Windows.Media.MediaPlaybackAutoRepeatMode, Windows.Media, ContentType = WindowsRuntime]

$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { 
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' 
}

function AwaitTask($WinRtTask, $ResultType, $TimeoutMs = 200) {
    if ($null -eq $WinRtTask) { return $null }
    try {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        if (-not $netTask.Wait($TimeoutMs)) { return $null }
        return $netTask.Result
    } catch {
        return $null
    }
}

$csharpHelper = @'
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Diagnostics;
using System.Threading;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;

namespace WinRtHelper {
    public static class ThumbnailSaver {
        public static bool SaveStream(object streamObj, string targetJpg, string targetPng, string umbJpg, string umbPng) {
            try {
                if (streamObj == null) return false;
                Type extType = null;
                foreach (var asm in AppDomain.CurrentDomain.GetAssemblies()) {
                    extType = asm.GetType("System.IO.WindowsRuntimeStreamExtensions");
                    if (extType != null) break;
                }
                if (extType == null) return false;
                MethodInfo method = null;
                foreach (var m in extType.GetMethods()) {
                    if (m.Name == "AsStreamForRead" && m.GetParameters().Length == 1) {
                        method = m;
                        break;
                    }
                }
                if (method == null) return false;
                using (var stream = (Stream)method.Invoke(null, new object[] { streamObj }))
                using (var ms = new MemoryStream()) {
                    stream.CopyTo(ms);
                    var bytes = ms.ToArray();
                    File.WriteAllBytes(targetJpg, bytes);
                    if (!string.IsNullOrEmpty(umbJpg)) {
                        File.WriteAllBytes(umbJpg, bytes);
                        try {
                            string staticJpg = Path.Combine(Path.GetDirectoryName(umbJpg), "dynamic_island_cover.jpg");
                            File.WriteAllBytes(staticJpg, bytes);
                        } catch {}
                    }
                    try {
                        using (var imgMs = new MemoryStream(bytes))
                        using (var img = Image.FromStream(imgMs)) {
                            img.Save(targetPng, System.Drawing.Imaging.ImageFormat.Png);
                            if (!string.IsNullOrEmpty(umbPng)) {
                                img.Save(umbPng, System.Drawing.Imaging.ImageFormat.Png);
                                try {
                                    string staticPng = Path.Combine(Path.GetDirectoryName(umbPng), "dynamic_island_cover.png");
                                    img.Save(staticPng, System.Drawing.Imaging.ImageFormat.Png);
                                } catch {}
                            }
                        }
                    } catch {}
                }
                return true;
            } catch {
                return false;
            }
        }

        public static int[] ExtractDominantColor(string imagePath) {
            try {
                if (!File.Exists(imagePath)) return new int[] { 255, 45, 85 };
                using (var bmp = new Bitmap(imagePath)) {
                    long totalR = 0, totalG = 0, totalB = 0;
                    int count = 0;
                    int step = Math.Max(1, bmp.Width / 16);
                    for (int x = 0; x < bmp.Width; x += step) {
                        for (int y = 0; y < bmp.Height; y += step) {
                            var p = bmp.GetPixel(x, y);
                            int brightness = (p.R + p.G + p.B) / 3;
                            int diff = Math.Max(Math.Abs(p.R - p.G), Math.Max(Math.Abs(p.R - p.B), Math.Abs(p.G - p.B)));
                            if (brightness > 25 && brightness < 240 && diff > 15) {
                                totalR += p.R;
                                totalG += p.G;
                                totalB += p.B;
                                count++;
                            }
                        }
                    }
                    if (count > 0) {
                        return new int[] { (int)(totalR / count), (int)(totalG / count), (int)(totalB / count) };
                    }
                    return new int[] { 255, 45, 85 };
                }
            } catch {
                return new int[] { 255, 45, 85 };
            }
        }
    }

    public static class SpotifyCdp {
        public static bool? ToggleLike() {
            try {
                var req = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:9222/json");
                req.Timeout = 300;
                string json;
                using (var resp = req.GetResponse())
                using (var sr = new StreamReader(resp.GetResponseStream())) {
                    json = sr.ReadToEnd();
                }

                var match = Regex.Match(json, "\"webSocketDebuggerUrl\"\\s*:\\s*\"(ws://127\\.0\\.0\\.1:9222/devtools/page/[a-zA-Z0-9]+)\"");
                if (!match.Success) return null;
                string wsUrl = match.Groups[1].Value;
                var uri = new Uri(wsUrl);

                using (var tcp = new TcpClient("127.0.0.1", 9222))
                using (var stream = tcp.GetStream()) {
                    stream.ReadTimeout = 500;
                    string key = Convert.ToBase64String(Guid.NewGuid().ToByteArray());
                    string handshake = "GET " + uri.PathAndQuery + " HTTP/1.1\r\n" +
                                       "Host: 127.0.0.1:9222\r\n" +
                                       "Upgrade: websocket\r\n" +
                                       "Connection: Upgrade\r\n" +
                                       "Sec-WebSocket-Key: " + key + "\r\n" +
                                       "Sec-WebSocket-Version: 13\r\n\r\n";
                    byte[] hsBytes = Encoding.ASCII.GetBytes(handshake);
                    stream.Write(hsBytes, 0, hsBytes.Length);

                    byte[] buf = new byte[2048];
                    stream.Read(buf, 0, buf.Length);

                    string js = "(async () => {" +
                                "  try {" +
                                "    if (window.Spicetify && window.Spicetify.Platform && window.Spicetify.Platform.LibraryAPI) {" +
                                "      const item = Spicetify.Player.data.item;" +
                                "      if (!item || !item.uri) return 'NO_ITEM';" +
                                "      const uri = item.uri;" +
                                "      const lib = Spicetify.Platform.LibraryAPI;" +
                                "      const res = await lib.contains(uri);" +
                                "      const isLiked = Array.isArray(res) ? res[0] : res;" +
                                "      if (isLiked) {" +
                                "        await lib.remove({ uris: [uri] });" +
                                "        Spicetify.showNotification('Удалено из Любимых треков');" +
                                "        return 'REMOVED';" +
                                "      } else {" +
                                "        await lib.add({ uris: [uri] });" +
                                "        Spicetify.showNotification('Добавлено в Любимые треки');" +
                                "        return 'ADDED';" +
                                "      }" +
                                "    }" +
                                "    return 'NO_SPICETIFY';" +
                                "  } catch { return 'ERR'; }" +
                                "})()";

                    string payload = "{\"id\":1,\"method\":\"Runtime.evaluate\",\"params\":{\"expression\":\"" + js + "\",\"awaitPromise\":true,\"returnByValue\":true}}";
                    byte[] plBytes = Encoding.UTF8.GetBytes(payload);

                    var frame = new MemoryStream();
                    frame.WriteByte(0x81);
                    if (plBytes.Length <= 125) {
                        frame.WriteByte((byte)(0x80 | plBytes.Length));
                    } else {
                        frame.WriteByte(0x80 | 126);
                        frame.WriteByte((byte)(plBytes.Length >> 8));
                        frame.WriteByte((byte)(plBytes.Length & 0xFF));
                    }

                    byte[] mask = new byte[] { 0x12, 0x34, 0x56, 0x78 };
                    frame.Write(mask, 0, 4);
                    for (int i = 0; i < plBytes.Length; i++) frame.WriteByte((byte)(plBytes[i] ^ mask[i % 4]));
                    byte[] frameBytes = frame.ToArray();
                    stream.Write(frameBytes, 0, frameBytes.Length);

                    byte[] resBuf = new byte[8192];
                    int total = 0;
                    while (total < resBuf.Length) {
                        int read = stream.Read(resBuf, total, resBuf.Length - total);
                        if (read <= 0) break;
                        total += read;
                        string cur = Encoding.UTF8.GetString(resBuf, 0, total);
                        if (cur.IndexOf("ADDED") >= 0) return true;
                        if (cur.IndexOf("REMOVED") >= 0) return false;
                        if (cur.IndexOf("\"result\":") >= 0 && cur.IndexOf("}") >= 0) break;
                    }
                    return null;
                }
            } catch {
                return null;
            }
        }
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorComObject { }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator {
        int NotImpl1();
        [PreserveSig]
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice {
        [PreserveSig]
        int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    }

    [Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioMeterInformation {
        [PreserveSig]
        int GetPeakValue(out float pfPeak);
        [PreserveSig]
        int GetMeteringChannelCount(out int pnChannelCount);
    }

    
    [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionManager2 {
        [PreserveSig] int NotImpl1();
        [PreserveSig] int NotImpl2();
        [PreserveSig] int GetSessionEnumerator(out IntPtr SessionEnum);
    }

[Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionControl {
        [PreserveSig] int GetState(out int pRetVal);
        [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
        [PreserveSig] int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string Value, [In] ref Guid EventContext);
        [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string pRetVal);
        [PreserveSig] int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string Value, [In] ref Guid EventContext);
        [PreserveSig] int GetGroupingParam(out Guid pRetVal);
    }

    public static class AppAudioControl {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetThreadDesktop(IntPtr hDesktop);

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        private static volatile bool _isDotaFocused = false;
        private static Thread _watcherThread;
        private static bool _started = false;
        private static readonly object _lock = new object();

        public static void StartFocusWatcher() {
            lock (_lock) {
                if (_started) return;
                _started = true;
                _watcherThread = new Thread(FocusLoop) {
                    IsBackground = true,
                    Name = "DotaFocusWatcher"
                };
                _watcherThread.SetApartmentState(ApartmentState.STA);
                _watcherThread.Start();
            }
        }

        private static void FocusLoop() {
            try {
                IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
                if (hDesk != IntPtr.Zero) {
                    SetThreadDesktop(hDesk);
                }
            } catch {}

            while (true) {
                try {
                    IntPtr fg = GetForegroundWindow();
                    if (fg != IntPtr.Zero) {
                        uint pid = 0;
                        GetWindowThreadProcessId(fg, out pid);
                        if (pid > 0) {
                            var p = Process.GetProcessById((int)pid);
                            _isDotaFocused = (p != null && p.ProcessName.IndexOf("dota2", StringComparison.OrdinalIgnoreCase) >= 0);
                        } else {
                            _isDotaFocused = false;
                        }
                    } else {
                        _isDotaFocused = false;
                    }
                } catch {
                    _isDotaFocused = false;
                }
                Thread.Sleep(100);
            }
        }

        public static bool IsDotaFocused() {
            StartFocusWatcher();
            return _isDotaFocused;
        }

        [DllImport("ole32.dll")]
        private static extern int CoInitializeEx(IntPtr pvReserved, uint dwCoInit);

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

        private static Guid IID_IAudioSessionControl = new Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD");
        private static Guid IID_IAudioSessionControl2 = new Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D");
        private static Guid IID_ISimpleAudioVolume = new Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8");

        private static readonly Dictionary<uint, string> _pidCache = new Dictionary<uint, string>();
        private static string GetProcessName(uint pid) {
            if (pid == 0) return "";
            lock (_pidCache) {
                string name;
                if (_pidCache.TryGetValue(pid, out name)) return name;
                try {
                    name = Process.GetProcessById((int)pid).ProcessName.ToLower();
                    _pidCache[pid] = name;
                    return name;
                } catch {
                    _pidCache[pid] = "";
                    return "";
                }
            }
        }

        public static string GetSessionFamily(string pName, string displayName, string iconPath) {
            string combined = (pName + " " + displayName + " " + iconPath).ToLower();
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

        public static bool IsMusicPlayerFamily(string fam) {
            return fam == "dotify" || fam == "spotify" || fam == "yandex" || fam == "aimp" ||
                   fam == "foobar" || fam == "apple" || fam == "tidal" || fam == "deezer" || fam == "vlc";
        }

        public class SessionEntry {
            public int Index;
            public uint Pid;
            public string ProcessName;
            public string DisplayName;
            public string IconPath;
            public string Family;
            public int State;
            public float Volume;
        }

        public static List<SessionEntry> EnumerateAllSessions() {
            CoInitializeEx(IntPtr.Zero, 0);
            var list = new List<SessionEntry>();
            try {
                var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                IMMDevice dev;
                if (enumerator.GetDefaultAudioEndpoint(0, 1, out dev) != 0 || dev == null) return list;
                Guid IID_IAudioSessionManager2 = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
                object o;
                if (dev.Activate(ref IID_IAudioSessionManager2, 1, IntPtr.Zero, out o) != 0 || o == null) return list;
                var mgr = (IAudioSessionManager2)o;
                IntPtr pEnum;
                if (mgr.GetSessionEnumerator(out pEnum) != 0 || pEnum == IntPtr.Zero) return list;

                IntPtr vtbl = Marshal.ReadIntPtr(pEnum);
                var getCount = (GetCountDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtbl, 3 * IntPtr.Size), typeof(GetCountDelegate));
                var getSession = (GetSessionDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtbl, 4 * IntPtr.Size), typeof(GetSessionDelegate));
                int count = 0;
                getCount(pEnum, out count);

                for (int i = 0; i < count; i++) {
                    IntPtr pSession;
                    getSession(pEnum, i, out pSession);
                    if (pSession == IntPtr.Zero) continue;

                    IntPtr sVtbl = Marshal.ReadIntPtr(pSession);
                    var qi = (QueryInterfaceDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(sVtbl, 0), typeof(QueryInterfaceDelegate));

                    uint pid = 0;
                    IntPtr pCtl2;
                    if (qi(pSession, ref IID_IAudioSessionControl2, out pCtl2) == 0 && pCtl2 != IntPtr.Zero) {
                        IntPtr ctl2Vtbl = Marshal.ReadIntPtr(pCtl2);
                        var getPid = (GetProcessIdDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(ctl2Vtbl, 14 * IntPtr.Size), typeof(GetProcessIdDelegate));
                        getPid(pCtl2, out pid);
                        Marshal.Release(pCtl2);
                    }

                    string pName = GetProcessName(pid);

                    string displayName = "";
                    string iconPath = "";
                    int state = 0;
                    IntPtr pCtl;
                    if (qi(pSession, ref IID_IAudioSessionControl, out pCtl) == 0 && pCtl != IntPtr.Zero) {
                        var ctl = (IAudioSessionControl)Marshal.GetObjectForIUnknown(pCtl);
                        ctl.GetState(out state);
                        ctl.GetDisplayName(out displayName);
                        ctl.GetIconPath(out iconPath);
                        Marshal.Release(pCtl);
                    }

                    float vol = 1.0f;
                    IntPtr pVol;
                    if (qi(pSession, ref IID_ISimpleAudioVolume, out pVol) == 0 && pVol != IntPtr.Zero) {
                        IntPtr volVtbl = Marshal.ReadIntPtr(pVol);
                        var getVol = (GetMasterVolumeDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(volVtbl, 4 * IntPtr.Size), typeof(GetMasterVolumeDelegate));
                        getVol(pVol, out vol);
                        Marshal.Release(pVol);
                    }

                    string fam = GetSessionFamily(pName, displayName, iconPath);
                    if (!string.IsNullOrEmpty(fam)) {
                        list.Add(new SessionEntry {
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
            } catch {}
            return list;
        }

        public static string ResolveTargetFamily(string preferredFamily) {
            var sessions = EnumerateAllSessions();
            if (!string.IsNullOrEmpty(preferredFamily)) {
                foreach (var s in sessions) {
                    if (s.Family == preferredFamily) return preferredFamily;
                }
            }
            foreach (var s in sessions) {
                if (s.State == 1 && IsMusicPlayerFamily(s.Family)) return s.Family;
            }
            foreach (var s in sessions) {
                if (IsMusicPlayerFamily(s.Family)) return s.Family;
            }
            foreach (var s in sessions) {
                if (s.State == 1) return s.Family;
            }
            if (sessions.Count > 0) return sessions[0].Family;
            return "";
        }

        public static int GetFamilyAudioState(string preferredFamily) {
            if (string.IsNullOrEmpty(preferredFamily)) return -1;
            var sessions = EnumerateAllSessions();
            bool found = false;
            foreach (var s in sessions) {
                if (s.Family == preferredFamily) {
                    found = true;
                    if (s.State == 1) return 1;
                }
            }
            return found ? 0 : -1;
        }

        public static float GetAppVolume(string preferredFamily = "") {
            string targetFam = ResolveTargetFamily(preferredFamily);
            if (string.IsNullOrEmpty(targetFam)) return 1.0f;

            var sessions = EnumerateAllSessions();
            foreach (var s in sessions) {
                if (s.Family == targetFam) return s.Volume;
            }
            return 1.0f;
        }

        public static float StepAppVolume(float delta, string preferredFamily = "") {
            string targetFam = ResolveTargetFamily(preferredFamily);
            if (string.IsNullOrEmpty(targetFam)) return 1.0f;

            CoInitializeEx(IntPtr.Zero, 0);
            float curVol = -1.0f;
            var sessions = EnumerateAllSessions();
            foreach (var s in sessions) {
                if (s.Family == targetFam) {
                    curVol = s.Volume;
                    break;
                }
            }
            if (curVol < 0.0f) curVol = 1.0f;
            float newVol = Math.Min(1.0f, Math.Max(0.0f, curVol + delta));

            try {
                var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                IMMDevice dev;
                if (enumerator.GetDefaultAudioEndpoint(0, 1, out dev) != 0 || dev == null) return newVol;
                Guid IID_IAudioSessionManager2 = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
                object o;
                if (dev.Activate(ref IID_IAudioSessionManager2, 1, IntPtr.Zero, out o) != 0 || o == null) return newVol;
                var mgr = (IAudioSessionManager2)o;
                IntPtr pEnum;
                if (mgr.GetSessionEnumerator(out pEnum) != 0 || pEnum == IntPtr.Zero) return newVol;

                IntPtr vtbl = Marshal.ReadIntPtr(pEnum);
                var getCount = (GetCountDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtbl, 3 * IntPtr.Size), typeof(GetCountDelegate));
                var getSession = (GetSessionDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtbl, 4 * IntPtr.Size), typeof(GetSessionDelegate));
                int count = 0;
                getCount(pEnum, out count);

                for (int i = 0; i < count; i++) {
                    IntPtr pSession;
                    getSession(pEnum, i, out pSession);
                    if (pSession == IntPtr.Zero) continue;

                    IntPtr sVtbl = Marshal.ReadIntPtr(pSession);
                    var qi = (QueryInterfaceDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(sVtbl, 0), typeof(QueryInterfaceDelegate));

                    uint pid = 0;
                    IntPtr pCtl2;
                    if (qi(pSession, ref IID_IAudioSessionControl2, out pCtl2) == 0 && pCtl2 != IntPtr.Zero) {
                        IntPtr ctl2Vtbl = Marshal.ReadIntPtr(pCtl2);
                        var getPid = (GetProcessIdDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(ctl2Vtbl, 14 * IntPtr.Size), typeof(GetProcessIdDelegate));
                        getPid(pCtl2, out pid);
                        Marshal.Release(pCtl2);
                    }

                    string pName = GetProcessName(pid);

                    string displayName = "";
                    string iconPath = "";
                    IntPtr pCtl;
                    if (qi(pSession, ref IID_IAudioSessionControl, out pCtl) == 0 && pCtl != IntPtr.Zero) {
                        var ctl = (IAudioSessionControl)Marshal.GetObjectForIUnknown(pCtl);
                        ctl.GetDisplayName(out displayName);
                        ctl.GetIconPath(out iconPath);
                        Marshal.Release(pCtl);
                    }

                    string fam = GetSessionFamily(pName, displayName, iconPath);
                    if (fam == targetFam) {
                        IntPtr pVol;
                        if (qi(pSession, ref IID_ISimpleAudioVolume, out pVol) == 0 && pVol != IntPtr.Zero) {
                            IntPtr volVtbl = Marshal.ReadIntPtr(pVol);
                            var setVol = (SetMasterVolumeDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(volVtbl, 3 * IntPtr.Size), typeof(SetMasterVolumeDelegate));
                            Guid g = Guid.Empty;
                            setVol(pVol, newVol, ref g);
                            lock (_duckLock) {
                                if (_isDucked) {
                                    string sessionKey = pid.ToString() + "_" + i.ToString();
                                    _savedSessionVolumes[sessionKey] = newVol;
                                }
                            }
                            Marshal.Release(pVol);
                        }
                    }
                    Marshal.Release(pSession);
                }
                Marshal.Release(pEnum);
            } catch {}
            return newVol;
        }



        private static readonly object _duckLock = new object();
        private static volatile bool _isDucked = false;
        private static volatile bool _duckResetRequested = false;
        private static long _duckEndTime = 0;
        private static float _targetDuckPercent = 0.5f;
        private static Dictionary<string, float> _savedSessionVolumes = new Dictionary<string, float>();
        private static Thread _workerThread = null;

        public static void DuckAllAudio(float duckPercent, int holdMs) {
            if (duckPercent <= 0.001f) return;
            lock (_duckLock) {
                long now = DateTime.UtcNow.Ticks / TimeSpan.TicksPerMillisecond;
                long newEnd = now + holdMs;
                if (newEnd > _duckEndTime) {
                    _duckEndTime = newEnd;
                }
                _targetDuckPercent = duckPercent;

                if (_isDucked) {
                    _duckResetRequested = true;
                    return;
                }

                _isDucked = true;
                _duckResetRequested = false;

                _workerThread = new Thread(EnvelopeWorker) {
                    IsBackground = true,
                    Name = "AudioDuckEnvelope"
                };
                _workerThread.Start();
            }
        }

        private static void ApplyDuckLevel(float duckFrac) {
            try {
                CoInitializeEx(IntPtr.Zero, 0);
                var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                IMMDevice dev;
                if (enumerator.GetDefaultAudioEndpoint(0, 1, out dev) != 0 || dev == null) return;
                Guid IID_IAudioSessionManager2 = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
                object o;
                if (dev.Activate(ref IID_IAudioSessionManager2, 1, IntPtr.Zero, out o) != 0 || o == null) return;
                var mgr = (IAudioSessionManager2)o;
                IntPtr pEnum;
                if (mgr.GetSessionEnumerator(out pEnum) != 0 || pEnum == IntPtr.Zero) return;

                IntPtr vtbl = Marshal.ReadIntPtr(pEnum);
                var getCount = (GetCountDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtbl, 3 * IntPtr.Size), typeof(GetCountDelegate));
                var getSession = (GetSessionDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtbl, 4 * IntPtr.Size), typeof(GetSessionDelegate));
                int count = 0;
                getCount(pEnum, out count);

                uint currentPid = (uint)Process.GetCurrentProcess().Id;

                for (int i = 0; i < count; i++) {
                    IntPtr pSession;
                    getSession(pEnum, i, out pSession);
                    if (pSession == IntPtr.Zero) continue;

                    IntPtr sVtbl = Marshal.ReadIntPtr(pSession);
                    var qi = (QueryInterfaceDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(sVtbl, 0), typeof(QueryInterfaceDelegate));

                    uint pid = 0;
                    IntPtr pCtl2;
                    if (qi(pSession, ref IID_IAudioSessionControl2, out pCtl2) == 0 && pCtl2 != IntPtr.Zero) {
                        IntPtr ctl2Vtbl = Marshal.ReadIntPtr(pCtl2);
                        var getPid = (GetProcessIdDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(ctl2Vtbl, 14 * IntPtr.Size), typeof(GetProcessIdDelegate));
                        getPid(pCtl2, out pid);
                        Marshal.Release(pCtl2);
                    }

                    if (pid != 0 && pid == currentPid) {
                        Marshal.Release(pSession);
                        continue;
                    }

                    IntPtr pVol;
                    if (qi(pSession, ref IID_ISimpleAudioVolume, out pVol) == 0 && pVol != IntPtr.Zero) {
                        IntPtr volVtbl = Marshal.ReadIntPtr(pVol);
                        var getVol = (GetMasterVolumeDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(volVtbl, 4 * IntPtr.Size), typeof(GetMasterVolumeDelegate));
                        var setVol = (SetMasterVolumeDelegate)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(volVtbl, 3 * IntPtr.Size), typeof(SetMasterVolumeDelegate));

                        string sessionKey = pid.ToString() + "_" + i.ToString();
                        float origVol;
                        if (!_savedSessionVolumes.TryGetValue(sessionKey, out origVol)) {
                            float cur = 1.0f;
                            getVol(pVol, out cur);
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
            } catch {}
        }

        private static void EnvelopeWorker() {
            try {
                for (int step = 1; step <= 3; step++) {
                    float t = step / 3.0f;
                    float duckFrac = _targetDuckPercent * (t * t);
                    ApplyDuckLevel(duckFrac);
                    Thread.Sleep(20);
                }
                ApplyDuckLevel(_targetDuckPercent);

                while (true) {
                    long now = DateTime.UtcNow.Ticks / TimeSpan.TicksPerMillisecond;
                    if (now >= _duckEndTime) break;
                    if (_duckResetRequested) {
                        _duckResetRequested = false;
                        ApplyDuckLevel(_targetDuckPercent);
                    }
                    Thread.Sleep(30);
                }

                int releaseSteps = 8;
                for (int step = 1; step <= releaseSteps; step++) {
                    if (_duckResetRequested) {
                        _duckResetRequested = false;
                        ApplyDuckLevel(_targetDuckPercent);
                        while (true) {
                            long now = DateTime.UtcNow.Ticks / TimeSpan.TicksPerMillisecond;
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
            } catch {}
            finally {
                lock (_duckLock) {
                    _savedSessionVolumes.Clear();
                    _isDucked = false;
                    _duckResetRequested = false;
                    _workerThread = null;
                }
            }
        }

        public static void RestoreAudioDucking() {
            lock (_duckLock) {
                if (!_isDucked) return;
                ApplyDuckLevel(0.0f);
                _savedSessionVolumes.Clear();
                _isDucked = false;
                _duckResetRequested = false;
                _workerThread = null;
            }
        }
    }

    public static class Meter {
        private static IAudioMeterInformation _meter;
        private static void Init() {
            if (_meter == null) {
                var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                IMMDevice dev;
                enumerator.GetDefaultAudioEndpoint(0, 1, out dev);
                var iid = typeof(IAudioMeterInformation).GUID;
                object o;
                dev.Activate(ref iid, 1, IntPtr.Zero, out o);
                _meter = (IAudioMeterInformation)o;
            }
        }
        public static float[] GetBars() {
            try {
                Init();
                if (_meter == null) return new float[] { 0f, 0f, 0f, 0f, 0f };
                float peak = 0;
                _meter.GetPeakValue(out peak);
                if (peak <= 0.001f) return new float[] { 0f, 0f, 0f, 0f, 0f };
                float p = Math.Min(1.0f, Math.Max(0.0f, peak));
                return new float[] {
                    (float)Math.Round(p * 0.7f, 2),
                    (float)Math.Round(p * 0.85f, 2),
                    (float)Math.Round(p, 2),
                    (float)Math.Round(p * 0.85f, 2),
                    (float)Math.Round(p * 0.7f, 2)
                };
            } catch { return new float[] { 0f, 0f, 0f, 0f, 0f }; }
        }
    }
}
'@

try { Add-Type -TypeDefinition $csharpHelper -Language CSharp -ReferencedAssemblies "System.Drawing" } catch {}

$global:tempDir = [System.IO.Path]::GetTempPath()
$global:coverJpg = ""
$global:coverPng = ""
$global:lastSavedTrack = ""
$global:coverVersion = 0
$global:coverBase64 = ""
$global:coverColor = @(255, 45, 85)
$global:lastValidData = $null
$global:currentIsLiked = $false

function Get-MediaSessionFamily($session) {
    if ($null -eq $session) { return "" }
    $appId = if ($session.SourceAppUserModelId) { $session.SourceAppUserModelId.ToLower() } else { "" }
    if ($appId -match "dotify") { return "dotify" }
    if ($appId -match "spotify") { return "spotify" }
    if ($appId -match "yandex") { return "yandex" }
    if ($appId -match "aimp") { return "aimp" }
    if ($appId -match "foobar") { return "foobar" }
    if ($appId -match "apple" -or $appId -match "itunes") { return "apple" }
    if ($appId -match "zen" -or $appId -eq "f0dc299d809b9700") { return "zen" }
    if ($appId -match "chrome") { return "chrome" }
    if ($appId -match "edge" -or $appId -match "msedge") { return "msedge" }
    if ($appId -match "firefox") { return "firefox" }
    if ($appId -match "opera") { return "opera" }
    if ($appId -match "brave") { return "brave" }
    if ($appId -match "vivaldi") { return "vivaldi" }
    return ""
}

function Find-BestSession($mgr) {
    if ($null -eq $mgr) { return $null }
    
    $sessions = $mgr.GetSessions()
    if ($null -eq $sessions -or $sessions.Count -eq 0) {
        return $mgr.GetCurrentSession()
    }
    
    $dedicatedPlaying = $null
    $dedicatedPaused = $null
    $browserPlaying = $null
    $browserPaused = $null
    $anyPlaying = $null
    $anyPaused = $null
    
    foreach ($s in $sessions) {
        $appId = if ($s.SourceAppUserModelId) { $s.SourceAppUserModelId.ToLower() } else { "" }
        $pb = $s.GetPlaybackInfo()
        $isPlaying = ($pb -and $pb.PlaybackStatus.ToString() -eq "Playing")
        
        $isBrowser = ($appId -match "zen" -or $appId -match "chrome" -or $appId -match "edge" -or 
                      $appId -match "msedge" -or $appId -match "firefox" -or $appId -match "opera" -or 
                      $appId -match "brave" -or $appId -match "vivaldi" -or $appId -eq "f0dc299d809b9700")
        
        $isDedicated = (-not $isBrowser) -and ($appId -match "dotify" -or $appId -match "spotify" -or 
                                              $appId -match "yandex" -or $appId -match "applemusic" -or 
                                              $appId -match "itunes" -or $appId -match "aimp" -or 
                                              $appId -match "foobar" -or $appId -match "tidal" -or 
                                              $appId -match "deezer" -or $appId -match "winamp" -or 
                                              $appId -match "musicbee")
        
        if ($isDedicated) {
            if ($isPlaying) {
                if ($null -eq $dedicatedPlaying) { $dedicatedPlaying = $s }
            } else {
                if ($null -eq $dedicatedPaused) { $dedicatedPaused = $s }
            }
        } elseif ($isBrowser) {
            if ($isPlaying) {
                if ($null -eq $browserPlaying) { $browserPlaying = $s }
            } else {
                if ($null -eq $browserPaused) { $browserPaused = $s }
            }
        } else {
            if ($isPlaying) {
                if ($null -eq $anyPlaying) { $anyPlaying = $s }
            } else {
                if ($null -eq $anyPaused) { $anyPaused = $s }
            }
        }
    }
    
    if ($dedicatedPlaying) { return $dedicatedPlaying }
    if ($dedicatedPaused) { return $dedicatedPaused }
    if ($browserPlaying) { return $browserPlaying }
    if ($anyPlaying) { return $anyPlaying }
    if ($browserPaused) { return $browserPaused }
    if ($anyPaused) { return $anyPaused }
    
    $cur = $mgr.GetCurrentSession()
    if ($cur) { return $cur }
    return $sessions[0]
}

function Fetch-Cover($props, $trackKey, $title, $artist) {
    $ver = $global:coverVersion + 1
    $targetJpg = Join-Path $global:tempDir "dynamic_island_cover_$($ver).jpg"
    $targetPng = Join-Path $global:tempDir "dynamic_island_cover_$($ver).png"
    
    $umbDir = "C:\Umbrella\scripts"
    $umbJpg = if (Test-Path $umbDir) { Join-Path $umbDir "dynamic_island_cover_$($ver).jpg" } else { "" }
    $umbPng = if (Test-Path $umbDir) { Join-Path $umbDir "dynamic_island_cover_$($ver).png" } else { "" }

    $saved = $false

    if ($props -and $props.Thumbnail) {
        try {
            $streamTask = $props.Thumbnail.OpenReadAsync()
            $stream = AwaitTask $streamTask ([Windows.Storage.Streams.IRandomAccessStreamWithContentType]) 300
            if ($stream) {
                $saved = [WinRtHelper.ThumbnailSaver]::SaveStream($stream, $targetJpg, $targetPng, $umbJpg, $umbPng)
            }
        } catch {}
    }

    if ($saved -and (Test-Path $targetJpg)) {
        $global:coverVersion = $ver
        try {
            if ($ver -gt 2) {
                $prevVer = $ver - 2
                if (Test-Path $umbDir) {
                    Remove-Item (Join-Path $umbDir "dynamic_island_cover_$($prevVer).*") -Force -ErrorAction SilentlyContinue
                }
                Remove-Item (Join-Path $global:tempDir "dynamic_island_cover_$($prevVer).*") -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $targetPng) {
                $bytes = [System.IO.File]::ReadAllBytes($targetPng)
            } else {
                $bytes = [System.IO.File]::ReadAllBytes($targetJpg)
            }
            $global:coverBase64 = [Convert]::ToBase64String($bytes)
            $global:coverColor = [WinRtHelper.ThumbnailSaver]::ExtractDominantColor($targetJpg)
            $global:coverJpg = $targetJpg
            $global:coverPng = $targetPng
            $global:hasCover = $true
        } catch {
            $global:coverBase64 = ""
            $global:coverJpg = ""
            $global:coverPng = ""
            $global:hasCover = $false
        }
    } else {
        $global:coverBase64 = ""
        $global:coverJpg = ""
        $global:coverPng = ""
        $global:hasCover = $false
    }
}

function Get-MediaInfo {
    try {
        $mgrTask = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()
        $mgr = AwaitTask $mgrTask ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]) 150
        if ($null -eq $mgr) { return $global:lastValidData }

        $session = Find-BestSession $mgr
        if ($null -eq $session) { return $global:lastValidData }

        $propsTask = $session.TryGetMediaPropertiesAsync()
        $props = AwaitTask $propsTask ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]) 350
        if ($null -eq $props) { return $global:lastValidData }

        $playback = $session.GetPlaybackInfo()
        $timeline = $session.GetTimelineProperties()

        $isPlaying = if ($playback) { 
            $playback.PlaybackStatus.ToString() -eq "Playing" 
        } else { $false }

        $isShuffle = if ($playback) { [bool]$playback.IsShuffleActive } else { $false }
        $repeatMode = 0
        if ($playback -and $playback.AutoRepeatMode) {
            $repStr = $playback.AutoRepeatMode.ToString()
            if ($repStr -eq "List") { $repeatMode = 1 }
            elseif ($repStr -eq "Track") { $repeatMode = 2 }
        }

        $pos = if ($timeline) { [int]$timeline.Position.TotalSeconds } else { 0 }
        $dur = if ($timeline) { [int]$timeline.EndTime.TotalSeconds } else { 0 }

        $title = if ($props.Title) { $props.Title.Trim() } else { "" }
        $artist = if ($props.Artist) { $props.Artist.Trim() } else { "" }
        $album = if ($props.AlbumTitle) { $props.AlbumTitle.Trim() } else { "" }
        $trackKey = "$artist - $title"

        $needsCover = ($trackKey -ne $global:lastSavedTrack)
        if ($needsCover -and $title -ne "") {
            $global:lastSavedTrack = $trackKey
            Fetch-Cover $props $trackKey $title $artist
        }

        $appId = if ($session.SourceAppId) { $session.SourceAppId } else { "" }
        $hasCover = [bool]($global:hasCover -and ($global:coverBase64 -ne "" -or ($global:coverPng -ne "" -and (Test-Path $global:coverPng))))
        $targetFam = if ($session) { Get-MediaSessionFamily $session } else { "" }
        if ($isPlaying -and $targetFam -ne "" -and [WinRtHelper.AppAudioControl]::IsMusicPlayerFamily($targetFam)) {
            $audioState = [WinRtHelper.AppAudioControl]::GetFamilyAudioState($targetFam)
            if ($audioState -eq 0) {
                $isPlaying = $false
            }
        }
        $bars = if ($isPlaying) { [WinRtHelper.Meter]::GetBars() } else { @(0.0, 0.0, 0.0, 0.0, 0.0) }
        $appVol = [WinRtHelper.AppAudioControl]::GetAppVolume($targetFam)
        $volInt = [int][Math]::Round($appVol * 100)

        $cleanPath = if ($global:coverPng) { $global:coverPng.Replace('\', '/') } else { "" }
        $cleanJpg = if ($global:coverJpg) { $global:coverJpg.Replace('\', '/') } else { "" }
        $coverVerNum = if ($hasCover) { [int]$global:coverVersion } else { 0 }

        $res = @{
            is_playing   = $isPlaying
            title        = $title
            artist       = $artist
            album        = $album
            app          = $appId
            position     = $pos
            duration     = $dur
            cover_path   = $cleanPath
            cover_jpg    = $cleanJpg
            cover_base64 = $global:coverBase64
            cover_ver    = $coverVerNum
            has_cover    = $hasCover
            cover_color  = $global:coverColor
            waveform     = $bars
            volume       = $volInt
            shuffle      = $isShuffle
            repeat       = $repeatMode
            is_liked     = $global:currentIsLiked
        }

        if ($title -ne "" -or $isPlaying) {
            $global:lastValidData = $res
        }
        return $res
    } catch {
        return $global:lastValidData
    }
}

function Handle-MediaCommand($cmd) {
    try {
        $mgrTask = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()
        $mgr = AwaitTask $mgrTask ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]) 150
        $session = if ($mgr) { Find-BestSession $mgr } else { $null }
        $targetFam = if ($session) { Get-MediaSessionFamily $session } else { "" }

        if ($cmd -eq "volup") {
            return [WinRtHelper.AppAudioControl]::StepAppVolume(0.04, $targetFam)
        } elseif ($cmd -eq "voldown") {
            return [WinRtHelper.AppAudioControl]::StepAppVolume(-0.04, $targetFam)
        }
        if ($cmd -eq "like") {
            $res = [WinRtHelper.SpotifyCdp]::ToggleLike()
            if ($null -ne $res) {
                $global:currentIsLiked = [bool]$res
            } else {
                $global:currentIsLiked = -not $global:currentIsLiked
            }
            return
        }

        if ($session) {
            if ($cmd -eq "playpause") {
                $pb = $session.GetPlaybackInfo()
                $status = if ($pb) { $pb.PlaybackStatus.ToString() } else { "" }
                $t = $null
                if ($status -eq "Playing") {
                    $t = $session.TryPauseAsync()
                } elseif ($status -eq "Paused" -or $status -eq "Stopped") {
                    $t = $session.TryPlayAsync()
                }
                if ($null -eq $t) {
                    $t = $session.TryTogglePlayPauseAsync()
                }
                if ($t) { AwaitTask $t ([bool]) 350 | Out-Null }
            } elseif ($cmd -eq "next") {
                $t = $session.TrySkipNextAsync()
                if ($t) { AwaitTask $t ([bool]) 350 | Out-Null }
            } elseif ($cmd -eq "prev") {
                $t = $session.TrySkipPreviousAsync()
                if ($t) { AwaitTask $t ([bool]) 350 | Out-Null }
            } elseif ($cmd -eq "shuffle") {
                try {
                    $pb = $session.GetPlaybackInfo()
                    $cur = if ($pb) { [bool]$pb.IsShuffleActive } else { $false }
                    $session.TryChangeShuffleActiveAsync(-not $cur) | Out-Null
                } catch {}
            } elseif ($cmd -eq "repeat") {
                try {
                    $pb = $session.GetPlaybackInfo()
                    $curRep = if ($pb -and $pb.AutoRepeatMode) { $pb.AutoRepeatMode.ToString() } else { "None" }
                    $nextRep = [Windows.Media.MediaPlaybackAutoRepeatMode]::None
                    if ($curRep -eq "None") { 
                        $nextRep = [Windows.Media.MediaPlaybackAutoRepeatMode]::List 
                    } elseif ($curRep -eq "List") { 
                        $nextRep = [Windows.Media.MediaPlaybackAutoRepeatMode]::Track 
                    }
                    $session.TryChangeAutoRepeatModeAsync($nextRep) | Out-Null
                } catch {}
            }
        }
    } catch {}
}

Add-Type -AssemblyName PresentationCore

$scriptBase = if ($PSScriptRoot) { $PSScriptRoot } else { [System.AppDomain]::CurrentDomain.BaseDirectory }
$global:SoundDir = if ($scriptBase) { Join-Path $scriptBase "sounds" } else { "sounds" }
if (-not (Test-Path $global:SoundDir)) {
    $global:SoundDir = "C:\Umbrella\scripts\media_bridge\sounds"
}
if (-not (Test-Path $global:SoundDir)) {
    $global:SoundDir = "D:\main\project\scriptForUmb\dynamicisland\media_bridge\sounds"
}

$global:SoundPlayers = @{}
$global:SoundPoolIndex = @{}

function Init-SoundPool {
    if (-not (Test-Path $global:SoundDir)) { return }
    $soundFiles = Get-ChildItem -Path $global:SoundDir | Where-Object { $_.Extension -eq ".mp3" -or $_.Extension -eq ".wav" }
    foreach ($file in $soundFiles) {
        $baseName = $file.BaseName
        $pool = @()
        $instances = 2
        if ($baseName -eq "wheel_notch" -or $baseName -eq "button_press" -or $baseName -eq "wheel_boundary_bump" -or $baseName -eq "toast_dismiss" -or $baseName -eq "button_dismiss") {
            $instances = 20
        }
        for ($i = 0; $i -lt $instances; $i++) {
            try {
                $p = New-Object System.Windows.Media.MediaPlayer
                $p.Open([System.Uri]::new($file.FullName))
                $p.Volume = 0.5
                $pool += $p
            } catch {}
        }
        $global:SoundPlayers[$baseName] = $pool
        $global:SoundPoolIndex[$baseName] = 0
    }
}

$global:SoundDurations = @{
    "toast_dismiss"         = 100
    "button_dismiss"        = 100
    "button_press"          = 350
    "courier_death_or_fail" = 2400
    "courier_delivered"     = 900
    "game_paused"           = 500
    "game_unpaused"         = 600
    "hero_stunned"          = 1100
    "island_collapse"       = 450
    "island_expand"         = 650
    "island_hover"          = 350
    "low_hp_heartbeat"      = 2200
    "match_found"           = 3500
    "notification_toast"    = 2500
    "timer_chime"           = 900
    "wheel_boundary_bump"   = 350
    "wheel_notch"           = 150
}

function Play-AppleSound($name, $volume, $force = $false) {
    if (-not $name) { return }
    if (-not $force -and $name -ne "match_found") {
        if (-not [WinRtHelper.AppAudioControl]::IsDotaFocused()) {
            return
        }
    }
    $pool = $global:SoundPlayers[$name]
    if ($null -ne $pool -and $pool.Count -gt 0) {
        $idx = $global:SoundPoolIndex[$name]
        $player = $pool[$idx]
        $global:SoundPoolIndex[$name] = ($idx + 1) % $pool.Count
        try {
            $player.Volume = $volume
            $player.Stop()
            $player.Position = [System.TimeSpan]::Zero
            $player.Play()
        } catch {}
    } else {
        if (Test-Path $global:SoundDir) {
            $soundPath = Join-Path $global:SoundDir ($name + ".wav")
            if (-not (Test-Path $soundPath)) {
                $soundPath = Join-Path $global:SoundDir ($name + ".mp3")
            }
            if (Test-Path $soundPath) {
                try {
                    $p = New-Object System.Windows.Media.MediaPlayer
                    $p.Open([System.Uri]::new($soundPath))
                    $p.Volume = $volume
                    $p.Play()
                } catch {}
            }
        }
    }
}

Init-SoundPool
[WinRtHelper.AppAudioControl]::StartFocusWatcher()

$listener = $null

while ($true) {
    try {
        if ($null -eq $listener -or -not $listener.IsListening) {
            try { if ($listener) { $listener.Close() } } catch {}
            $listener = New-Object System.Net.HttpListener
            $listener.Prefixes.Add("http://127.0.0.1:45455/")
            $listener.Start()
        }

        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $response.KeepAlive = $false
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.OutputStream.Close()
            continue
        }

        $path = $request.Url.LocalPath.ToLower()

        if ($path -eq "/media") {
            $data = Get-MediaInfo
            if ($null -eq $data -and $null -ne $global:lastValidData) {
                $data = $global:lastValidData
            }
            if ($null -eq $data) {
                $bars = @(0.0, 0.0, 0.0, 0.0, 0.0)
                $data = @{
                    is_playing   = $false
                    title        = ""
                    artist       = ""
                    album        = ""
                    app          = ""
                    position     = 0
                    duration     = 0
                    cover_path   = ""
                    cover_jpg    = ""
                    cover_base64 = ""
                    cover_ver    = 0
                    has_cover    = $false
                    cover_color  = @(255, 45, 85)
                    waveform     = $bars
                    volume       = 100
                    shuffle      = $false
                    repeat       = 0
                    is_liked     = $global:currentIsLiked
                }
            }
            $json = $data | ConvertTo-Json -Compress -Depth 3
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } elseif ($path -match "^/media/(playpause|next|prev|shuffle|repeat|like|volup|voldown)$") {
            $cmd = $matches[1]
            $bump = ($request.QueryString["bump"] -eq "1")
            $noSound = ($request.QueryString["nosound"] -eq "1")
            if ($cmd -eq "volup" -or $cmd -eq "voldown") {
                if (-not $noSound) {
                    if ($bump) {
                        Play-AppleSound "wheel_boundary_bump" 0.65
                    } else {
                        Play-AppleSound "wheel_notch" 0.45
                    }
                }
            }
            $curVol = Handle-MediaCommand $cmd
            if ($null -eq $curVol) {
                $curVol = [WinRtHelper.AppAudioControl]::GetAppVolume()
            }
            $volInt = [int][Math]::Round($curVol * 100)
            
            $json = @{ status = "ok"; volume = $volInt; is_liked = $global:currentIsLiked } | ConvertTo-Json -Compress
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } elseif ($path -eq "/sound") {
            $soundName = $request.QueryString["name"]
            $volParam = $request.QueryString["vol"]
            $force = ($request.QueryString["force"] -eq "1")
            $duckParam = $request.QueryString["duck"]
            $vol = 0.5
            if ($volParam) {
                $parsedVol = 0.0
                if ([double]::TryParse($volParam, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedVol)) {
                    $vol = [Math]::Max(0.01, [Math]::Min(1.0, $parsedVol))
                }
            }
            if ($duckParam) {
                $parsedDuck = 0.0
                if ([double]::TryParse($duckParam, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedDuck)) {
                    $duckVal = [Math]::Max(0.0, [Math]::Min(1.0, $parsedDuck))
                    if ($duckVal -gt 0.01) {
                        $dur = 800
                        if ($global:SoundDurations.ContainsKey($soundName)) {
                            $dur = $global:SoundDurations[$soundName]
                        }
                        [WinRtHelper.AppAudioControl]::DuckAllAudio($duckVal, $dur)
                    }
                }
            }
            Play-AppleSound $soundName $vol $force
            $json = '{"status":"ok"}'
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } elseif ($path -eq "/focus") {
            $isFoc = [WinRtHelper.AppAudioControl]::IsDotaFocused()
            $json = @{ status = "ok"; focused = $isFoc } | ConvertTo-Json -Compress
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } else {
            $response.StatusCode = 404
            $response.OutputStream.Close()
        }
    } catch {
        try {
            $errStr = $_ | Out-String
            Add-Content -Path 'C:\Umbrella\scripts\media_bridge\bridge_error.log' -Value "[$(Get-Date)] $errStr" -ErrorAction SilentlyContinue
        } catch {}
        Start-Sleep -Milliseconds 100
    }
}
