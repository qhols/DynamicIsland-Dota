using System.Diagnostics;

namespace MediaBridge;

public static class DotaLifetime
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan ExitGrace = TimeSpan.FromSeconds(6);

    public static bool Stay { get; private set; }

    public static string[] ParseFlags(string[] args)
    {
        var rest = new List<string>();
        foreach (var a in args)
        {
            if (a.Equals("--stay", StringComparison.OrdinalIgnoreCase)) Stay = true;
            else rest.Add(a);
        }
        return rest.ToArray();
    }

    public static void LaunchGame(string[] args, Action<string> log)
    {
        if (args.Length == 0) return;
        string exe = args[0];
        try
        {
            var psi = new ProcessStartInfo(exe)
            {
                UseShellExecute = false,
                WorkingDirectory = Path.GetDirectoryName(exe) ?? ""
            };
            for (int i = 1; i < args.Length; i++) psi.ArgumentList.Add(args[i]);
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            log($"launch {exe}: {ex}");
        }
    }

    public static void StartExitWatcher()
    {
        if (Stay) return;
        var thread = new Thread(() =>
        {
            bool seen = false;
            DateTime goneSince = DateTime.MinValue;
            while (true)
            {
                bool running = IsDotaRunning();
                if (running)
                {
                    seen = true;
                    goneSince = DateTime.MinValue;
                }
                else if (seen)
                {
                    if (goneSince == DateTime.MinValue) goneSince = DateTime.UtcNow;
                    else if (DateTime.UtcNow - goneSince >= ExitGrace) Environment.Exit(0);
                }
                Thread.Sleep(PollInterval);
            }
        })
        {
            IsBackground = true,
            Name = "DotaLifetime"
        };
        thread.Start();
    }

    private static bool IsDotaRunning()
    {
        try
        {
            var procs = Process.GetProcessesByName("dota2");
            bool any = procs.Length > 0;
            foreach (var p in procs) p.Dispose();
            return any;
        }
        catch
        {
            return true;
        }
    }
}
