using NAudio.CoreAudioApi;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace MediaBridge;

public static class SoundEngine
{
    private static readonly object Sync = new();
    private static readonly Dictionary<string, float[]> Cache = new();
    private static WaveFormat _mixFormat = WaveFormat.CreateIeeeFloatWaveFormat(48000, 2);
    private static MixingSampleProvider? _mixer;
    private static IWavePlayer? _output;
    private static string _soundDir = "";

    private const int MaxSoundSeconds = 8;
    private const float SilenceThreshold = 0.0015f;

    public static readonly IReadOnlyDictionary<string, int> Durations = new Dictionary<string, int>
    {
        ["toast_dismiss"] = 100,
        ["button_dismiss"] = 100,
        ["button_press"] = 350,
        ["courier_death_or_fail"] = 2400,
        ["courier_delivered"] = 900,
        ["game_paused"] = 500,
        ["game_unpaused"] = 600,
        ["hero_stunned"] = 1100,
        ["island_collapse"] = 450,
        ["island_expand"] = 650,
        ["island_hover"] = 350,
        ["low_hp_heartbeat"] = 2200,
        ["match_found"] = 3500,
        ["notification_toast"] = 2500,
        ["timer_chime"] = 900,
        ["wheel_boundary_bump"] = 350,
        ["wheel_notch"] = 150,
    };

    public static int LoadedCount
    {
        get { lock (Sync) return Cache.Count; }
    }

    public static string LastError { get; private set; } = "";
    public static string OutputKind { get; private set; } = "";

    public static void Init(string exeDir)
    {
        _soundDir = Path.Combine(exeDir, "sounds");
        if (!Directory.Exists(_soundDir)) _soundDir = @"C:\Umbrella\scripts\media_bridge\sounds";
        if (!Directory.Exists(_soundDir)) return;

        _mixFormat = WaveFormat.CreateIeeeFloatWaveFormat(DeviceSampleRate(), 2);

        var files = Directory.GetFiles(_soundDir, "*.wav").Concat(Directory.GetFiles(_soundDir, "*.mp3"));
        foreach (var file in files)
        {
            string name = Path.GetFileNameWithoutExtension(file);
            if (Cache.ContainsKey(name)) continue;
            var data = Decode(file);
            if (data != null) Cache[name] = data;
        }

        lock (Sync) EnsureOutput();
    }

    private static int DeviceSampleRate()
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            using var device = enumerator.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
            return device.AudioClient.MixFormat.SampleRate;
        }
        catch
        {
            return 48000;
        }
    }

    private static float[]? Decode(string file)
    {
        try
        {
            using var reader = new MediaFoundationReader(file);
            ISampleProvider sp = reader.ToSampleProvider();
            if (sp.WaveFormat.Channels == 1) sp = new MonoToStereoSampleProvider(sp);
            else if (sp.WaveFormat.Channels != 2) return null;
            if (sp.WaveFormat.SampleRate != _mixFormat.SampleRate) sp = new WdlResamplingSampleProvider(sp, _mixFormat.SampleRate);

            int maxSamples = _mixFormat.SampleRate * 2 * MaxSoundSeconds;
            var samples = new List<float>(_mixFormat.SampleRate * 2);
            var buffer = new float[_mixFormat.SampleRate * 2 / 10];
            int read;
            while (samples.Count < maxSamples && (read = sp.Read(buffer, 0, buffer.Length)) > 0)
            {
                samples.AddRange(new ArraySegment<float>(buffer, 0, read));
            }

            int end = samples.Count;
            while (end > 0 && Math.Abs(samples[end - 1]) < SilenceThreshold) end--;
            end += end % 2;
            if (end <= 0) return null;
            return samples.GetRange(0, Math.Min(end, samples.Count)).ToArray();
        }
        catch (Exception ex)
        {
            LastError = $"decode {Path.GetFileName(file)}: {ex.GetType().Name}: {ex.Message}";
            return null;
        }
    }

    private static void EnsureOutput()
    {
        if (_output != null && _mixer != null) return;

        try { _output?.Dispose(); } catch { }
        _output = null;

        var mixer = new MixingSampleProvider(_mixFormat) { ReadFully = true };
        IWavePlayer? output = null;
        try
        {
            var wasapi = new WasapiOut(AudioClientShareMode.Shared, true, 40);
            wasapi.Init(mixer);
            output = wasapi;
            OutputKind = "wasapi";
        }
        catch (Exception wasapiEx)
        {
            LastError = $"wasapi: {wasapiEx.GetType().Name}: {wasapiEx.Message}";
            try
            {
                var waveOut = new WaveOutEvent { DesiredLatency = 80, NumberOfBuffers = 3 };
                waveOut.Init(mixer);
                output = waveOut;
                OutputKind = "waveout";
            }
            catch (Exception waveOutEx)
            {
                LastError = $"waveout: {waveOutEx.GetType().Name}: {waveOutEx.Message}";
                OutputKind = "none";
                return;
            }
        }

        output.PlaybackStopped += (_, _) =>
        {
            lock (Sync)
            {
                if (ReferenceEquals(_output, output))
                {
                    _output = null;
                    _mixer = null;
                }
            }
        };
        output.Play();
        _output = output;
        _mixer = mixer;
    }

    public static void Play(string name, double volume, bool force = false)
    {
        if (string.IsNullOrEmpty(name)) return;
        if (!force && name != "match_found" && !AppAudioControl.IsDotaFocused()) return;

        float[]? data;
        lock (Sync)
        {
            if (!Cache.TryGetValue(name, out data)) return;
            EnsureOutput();
            if (_mixer == null) return;
            _mixer.AddMixerInput(new Voice(data, _mixFormat, (float)Math.Clamp(volume, 0.0, 1.0)));
        }
    }

    private sealed class Voice : ISampleProvider
    {
        private readonly float[] _data;
        private readonly float _gain;
        private int _pos;

        public Voice(float[] data, WaveFormat format, float gain)
        {
            _data = data;
            _gain = gain;
            WaveFormat = format;
        }

        public WaveFormat WaveFormat { get; }

        public int Read(float[] buffer, int offset, int count)
        {
            int n = Math.Min(count, _data.Length - _pos);
            for (int i = 0; i < n; i++) buffer[offset + i] = _data[_pos + i] * _gain;
            _pos += n;
            return n;
        }
    }
}
