using System.IO;
using System.Text.Json;
using Microsoft.Win32;
using NotificationDesigner.Model;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

namespace NotificationDesigner;

/// <summary>
/// "Show on Windows": sends the design to Windows exactly as the Clarion
/// program will - same XML, same per-user AppUserModelID registration - with
/// the sample values filled in, and reports what the program would receive.
/// </summary>
public static class WindowsToast
{
    public const string AppId = "TemplateMaker.NotificationDesigner";
    static readonly List<ToastNotification> Alive = new();   // keep the event handlers alive

    public sealed record Received(string What, string Arguments, IReadOnlyList<(string Id, string Value)> Inputs);

    /// <summary>Same registry entry toastc.c writes for a Clarion program.</summary>
    public static void Register(string displayName, string iconPath)
    {
        using var k = Registry.CurrentUser.CreateSubKey(@"Software\Classes\AppUserModelId\" + AppId);
        k.SetValue("DisplayName", string.IsNullOrWhiteSpace(displayName) ? "My Clarion App" : displayName);
        if (!string.IsNullOrWhiteSpace(iconPath) && File.Exists(iconPath)) k.SetValue("IconUri", Path.GetFullPath(iconPath));
        else k.DeleteValue("IconUri", false);
    }

    /// <summary>The XML Windows gets: placeholders filled, pictures as file:/// URIs, no comments.</summary>
    public static string PrepareXml(ToastDesign design, string folder)
    {
        var d = ToastXml.Read(ToastXml.Write(design));          // a deep copy
        string T(string s) => Placeholders.Apply(s, design.Samples);
        string I(string s) => s == "" ? "" : DesignPaths.ToUri(DesignPaths.Resolve(folder, T(s)));
        d.Samples.Clear();
        d.Launch = T(d.Launch);
        d.Title = T(d.Title); d.Line1 = T(d.Line1); d.Line2 = T(d.Line2); d.Attribution = T(d.Attribution);
        d.AppLogo = I(d.AppLogo); d.Hero = I(d.Hero); d.Inline = I(d.Inline);
        if (!d.Progress.Live)
        {
            d.Progress.Title = T(d.Progress.Title); d.Progress.Value = T(d.Progress.Value);
            d.Progress.ValueText = T(d.Progress.ValueText); d.Progress.Status = T(d.Progress.Status);
        }
        foreach (var i in d.Inputs)
        {
            i.Title = T(i.Title); i.Placeholder = T(i.Placeholder);
            foreach (var c in i.Choices) c.Content = T(c.Content);
        }
        foreach (var b in d.Buttons) { b.Content = T(b.Content); b.Arguments = T(b.Arguments); b.Image = I(b.Image); }
        return ToastXml.Write(d);
    }

    public static void Show(ToastDesign design, string folder, string appName, string appIcon, Action<Received> onEvent)
    {
        Register(appName, appIcon);
        var doc = new XmlDocument();
        doc.LoadXml(PrepareXml(design, folder));
        var t = new ToastNotification(doc) { Tag = "designer", Group = "designer" };
        if (design.Progress.Enabled && design.Progress.Live)
        {
            var data = new NotificationData { SequenceNumber = 1 };
            foreach (var k in ToastXml.LiveBindings)
                data.Values[k] = design.Samples.TryGetValue(k, out var v) ? v : (k == "progressValue" ? "0" : "");
            t.Data = data;
        }
        t.Activated += (_, e) =>
        {
            var a = e as ToastActivatedEventArgs;
            var inputs = new List<(string, string)>();
            if (a?.UserInput != null)
                foreach (var kv in a.UserInput) inputs.Add((kv.Key, kv.Value?.ToString() ?? ""));
            onEvent(new Received("Activated", a?.Arguments ?? "", inputs));
        };
        t.Dismissed += (_, e) => onEvent(new Received("Dismissed - " + e.Reason switch
        {
            ToastDismissalReason.UserCanceled => "closed by the user",
            ToastDismissalReason.TimedOut => "timed out (now in the notification centre)",
            _ => "hidden by the program",
        }, "", Array.Empty<(string, string)>()));
        t.Failed += (_, e) => onEvent(new Received($"Failed - 0x{e.ErrorCode.HResult:X8}", "", Array.Empty<(string, string)>()));
        lock (Alive) { Alive.Add(t); if (Alive.Count > 20) Alive.RemoveAt(0); }
        ToastNotificationManager.CreateToastNotifier(AppId).Show(t);
    }
}

/// <summary>Per-user designer settings (%APPDATA%\NotificationDesigner\settings.json).</summary>
public sealed class DesignerSettings
{
    public string PreviewAppName { get; set; } = "My Clarion App";
    public string PreviewAppIcon { get; set; } = "";
    public bool Dark { get; set; }
    public string LastFolder { get; set; } = "";

    static string FilePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "NotificationDesigner", "settings.json");

    public static DesignerSettings Load()
    {
        try { return JsonSerializer.Deserialize<DesignerSettings>(File.ReadAllText(FilePath)) ?? new(); }
        catch { return new(); }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* settings are a convenience */ }
    }
}
