using System.IO;
using System.Globalization;
using System.Text.RegularExpressions;

namespace NotificationDesigner.Model;

/// <summary>{Name} placeholders - filled by Notifier.SetVar('Name', value) at run time.</summary>
public static partial class Placeholders
{
    [GeneratedRegex(@"\{([A-Za-z_][A-Za-z0-9_]*)\}")]
    private static partial Regex Token();

    public static IReadOnlyList<string> Find(ToastDesign d)
    {
        var texts = new List<string> { d.Launch, d.Title, d.Line1, d.Line2, d.Attribution, d.AppLogo, d.Hero, d.Inline };
        if (d.Progress.Enabled && !d.Progress.Live)
            texts.AddRange(new[] { d.Progress.Title, d.Progress.Value, d.Progress.ValueText, d.Progress.Status });
        foreach (var i in d.Inputs) texts.AddRange(new[] { i.Title, i.Placeholder });
        foreach (var b in d.Buttons) texts.AddRange(new[] { b.Content, b.Arguments, b.Image });

        var found = new List<string>();
        foreach (var t in texts)
            foreach (Match m in Token().Matches(t ?? ""))
            {
                string n = m.Groups[1].Value;
                if (d.Progress.Enabled && d.Progress.Live && ToastXml.LiveBindings.Contains(n, StringComparer.OrdinalIgnoreCase)) continue;
                if (!found.Contains(n, StringComparer.OrdinalIgnoreCase)) found.Add(n);
            }
        return found;
    }

    public static string Apply(string text, IDictionary<string, string> values)
    {
        var ci = new Dictionary<string, string>(values, StringComparer.OrdinalIgnoreCase);
        return Token().Replace(text ?? "", m => ci.TryGetValue(m.Groups[1].Value, out var v) ? v : m.Value);
    }
}

public enum Severity { Warning, Error }

public sealed record Issue(Severity Severity, string Message);

/// <summary>The rules Windows enforces (it silently drops what breaks them) plus a few of taste.</summary>
public static class DesignValidator
{
    public static IReadOnlyList<Issue> Check(ToastDesign d, string? designFolder = null)
    {
        var r = new List<Issue>();
        void Err(string m) => r.Add(new Issue(Severity.Error, m));
        void Warn(string m) => r.Add(new Issue(Severity.Warning, m));

        if (string.IsNullOrWhiteSpace(d.Title)) Err("A notification needs a title.");
        if (d.Buttons.Count > 5) Err("Windows shows at most 5 buttons; the rest are dropped.");
        if (d.Inputs.Count > 5) Err("Windows shows at most 5 inputs; the rest are dropped.");

        var ids = new HashSet<string>(StringComparer.Ordinal);
        for (int n = 0; n < d.Inputs.Count; n++)
        {
            var i = d.Inputs[n];
            if (string.IsNullOrWhiteSpace(i.Id)) { Err($"Input {n + 1} needs an id (the program reads the answer by it)."); continue; }
            if (!ids.Add(i.Id)) Err($"The input id '{i.Id}' is used twice.");
            if (i.Kind == InputKind.Selection && i.Choices.Count == 0) Err($"The selection '{i.Id}' has no choices.");
            if (i.Kind == InputKind.Selection && i.Default != "" && !i.Choices.Any(c => c.Id == i.Default))
                Warn($"The selection '{i.Id}' starts on '{i.Default}', which is not one of its choices.");
        }

        for (int n = 0; n < d.Buttons.Count; n++)
        {
            var b = d.Buttons[n];
            string name = b.Content != "" ? $"'{b.Content}'" : $"{n + 1}";
            bool system = b.Kind is ButtonKind.Snooze or ButtonKind.Dismiss;
            if (!system && string.IsNullOrWhiteSpace(b.Content)) Err($"Button {n + 1} needs a caption.");
            if (b.Kind == ButtonKind.Protocol && !b.Arguments.Contains(':'))
                Err($"Button {name} opens an address, but '{b.Arguments}' is not one (https://..., mailto:...).");
            if (b.InputId != "" && !d.Inputs.Any(i => i.Id == b.InputId))
                Err($"Button {name} sits beside input '{b.InputId}', but there is no input with that id.");
            if (b.Kind == ButtonKind.Snooze && !d.Inputs.Any(i => i.Id == b.InputId && i.Kind == InputKind.Selection))
                Warn("The snooze button has no selection input for the snooze time; Windows uses its own default.");
        }

        if (d.Scenario is "reminder" or "alarm" or "incomingCall" && d.Buttons.Count == 0)
            Warn($"A {d.Scenario} without buttons behaves like an ordinary notification; add at least one button.");

        if (d.Progress.Enabled && !d.Progress.Live)
        {
            string v = d.Progress.Value.Trim();
            bool ok = v == "indeterminate" || v.StartsWith('{') ||
                      (double.TryParse(v, NumberStyles.Float, CultureInfo.InvariantCulture, out double x) && x >= 0 && x <= 1);
            if (!ok) Err("The progress value must be between 0 and 1 (0.75 = 75%), 'indeterminate', or a {placeholder}.");
        }

        if (designFolder != null)
        {
            foreach (var (label, path) in new[] { ("app logo", d.AppLogo), ("hero image", d.Hero), ("inline image", d.Inline) })
            {
                if (path == "" || path.Contains('{') || path.Contains("://")) continue;
                if (!File.Exists(DesignPaths.Resolve(designFolder, path)))
                    Warn($"The {label} '{path}' was not found; Windows shows nothing in its place.");
            }
        }
        return r;
    }
}

public static class DesignPaths
{
    static bool IsUri(string p) =>
        p.Contains("://") || p.StartsWith("ms-", StringComparison.OrdinalIgnoreCase) ||
        p.StartsWith("file:", StringComparison.OrdinalIgnoreCase) || p.StartsWith("data:", StringComparison.OrdinalIgnoreCase);

    static bool IsAbsolute(string p) => (p.Length >= 2 && p[1] == ':') || p.StartsWith(@"\\");

    /// <summary>A file inside the design's folder is stored relative to it, so the folder can move.</summary>
    public static string MakeRelative(string designFolder, string path)
    {
        if (string.IsNullOrEmpty(path) || IsUri(path) || string.IsNullOrEmpty(designFolder)) return path ?? "";
        string folder = Path.GetFullPath(designFolder).TrimEnd('\\') + "\\";
        string full = Path.GetFullPath(path);
        return full.StartsWith(folder, StringComparison.OrdinalIgnoreCase) ? full.Substring(folder.Length) : path;
    }

    public static string Resolve(string designFolder, string path)
    {
        if (string.IsNullOrEmpty(path)) return "";
        if (IsUri(path) || IsAbsolute(path)) return path;
        return Path.GetFullPath(Path.Combine(designFolder, path));
    }

    public static string ToUri(string path)
    {
        if (string.IsNullOrEmpty(path) || IsUri(path)) return path ?? "";
        return new Uri(path).AbsoluteUri;
    }
}
