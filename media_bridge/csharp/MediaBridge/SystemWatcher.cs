using System.Runtime.InteropServices;
using NAudio.CoreAudioApi;

namespace MediaBridge;

public record SystemInfo(string status, string device, string device_id, string device_kind, bool muted, int battery, bool charging, bool on_ac);

public static class SystemWatcher
{
    private static volatile SystemInfo _info = new("ok", "", "", "", false, -1, false, true);

    public static SystemInfo Current => _info;

    [StructLayout(LayoutKind.Sequential)]
    private struct SystemPowerStatus
    {
        public byte ACLineStatus;
        public byte BatteryFlag;
        public byte BatteryLifePercent;
        public byte SystemStatusFlag;
        public int BatteryLifeTime;
        public int BatteryFullLifeTime;
    }

    [DllImport("kernel32.dll")]
    private static extern bool GetSystemPowerStatus(out SystemPowerStatus status);

    public static void Start()
    {
        var thread = new Thread(Loop) { IsBackground = true, Name = "SystemWatcher" };
        thread.SetApartmentState(ApartmentState.MTA);
        thread.Start();
    }

    private static void Loop()
    {
        MMDeviceEnumerator? enumerator = null;
        while (true)
        {
            string device = "", id = "", kind = "";
            bool muted = false;
            try
            {
                enumerator ??= new MMDeviceEnumerator();
                using var dev = enumerator.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
                id = dev.ID;
                device = dev.DeviceFriendlyName;
                kind = Kind(dev);
                muted = dev.AudioEndpointVolume.Mute;
            }
            catch
            {
                try { enumerator?.Dispose(); } catch { }
                enumerator = null;
            }

            int battery = -1;
            bool charging = false, onAc = true;
            if (GetSystemPowerStatus(out var ps))
            {
                onAc = ps.ACLineStatus != 0;
                bool hasBattery = (ps.BatteryFlag & 128) == 0 && ps.BatteryLifePercent <= 100;
                if (hasBattery)
                {
                    battery = ps.BatteryLifePercent;
                    charging = (ps.BatteryFlag & 8) != 0 || (onAc && battery < 100);
                }
            }

            _info = new SystemInfo("ok", device, id, kind, muted, battery, charging, onAc);
            Thread.Sleep(400);
        }
    }

    private static string Kind(MMDevice dev)
    {
        try
        {
            var prop = dev.Properties[PropertyKeys.PKEY_AudioEndpoint_FormFactor];
            uint ff = prop?.Value is uint u ? u : Convert.ToUInt32(prop?.Value ?? 10u);
            return ff switch
            {
                3 or 5 or 6 => "headphones",
                9 => "display",
                _ => "speaker",
            };
        }
        catch
        {
            return "speaker";
        }
    }
}
