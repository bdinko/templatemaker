using System.Globalization;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace NotificationDesigner.Model;

/// <summary>
/// Reads and writes a design as Windows toast XML (the .ntf file).
///
/// The writer is deliberately plain: one element per line, fixed attribute
/// order, and pure ASCII (anything above 127 becomes a character reference
/// such as &amp;#225;). That is what lets the Clarion template read the file
/// at generate time and embed it line by line in the program, and lets the
/// run-time read it with no code-page guessing. Sample values for
/// {placeholders} travel as &lt;!--sample:Name=Value--&gt; comments above the
/// root; Windows ignores comments and the template skips them.
/// </summary>
public static class ToastXml
{
    const string NL = "\r\n";

    public static readonly string[] LiveBindings = { "progressTitle", "progressValue", "progressValueString", "progressStatus" };

    // ------------------------------------------------------------------ write
    public static string Write(ToastDesign d)
    {
        var sb = new StringBuilder();
        foreach (var kv in d.Samples)
        {
            if (string.IsNullOrEmpty(kv.Key)) continue;
            sb.Append("<!--sample:").Append(Ascii(kv.Key, false)).Append('=')
              .Append(Ascii(kv.Value ?? "", false).Replace("-", "&#45;")).Append("-->").Append(NL);
        }

        sb.Append("<toast");
        Attr(sb, "launch", d.Launch);
        if (!string.IsNullOrEmpty(d.Scenario) && d.Scenario != "default") Attr(sb, "scenario", d.Scenario);
        if (d.LongDuration) Attr(sb, "duration", "long");
        if (d.Buttons.Any(b => b.Style != ButtonStyle.Default)) Attr(sb, "useButtonStyle", "true");
        sb.Append('>').Append(NL);

        sb.Append("  <visual>").Append(NL);
        sb.Append("    <binding template=\"ToastGeneric\">").Append(NL);
        if (d.Hero != "") sb.Append("      <image placement=\"hero\" src=\"").Append(Ascii(d.Hero, true)).Append("\"/>").Append(NL);
        if (d.AppLogo != "")
        {
            sb.Append("      <image placement=\"appLogoOverride\"");
            if (d.LogoCircle) sb.Append(" hint-crop=\"circle\"");
            sb.Append(" src=\"").Append(Ascii(d.AppLogo, true)).Append("\"/>").Append(NL);
        }
        if (d.Title != "") sb.Append("      <text hint-maxLines=\"2\">").Append(Ascii(d.Title, false)).Append("</text>").Append(NL);
        if (d.Line1 != "") sb.Append("      <text>").Append(Ascii(d.Line1, false)).Append("</text>").Append(NL);
        if (d.Line2 != "") sb.Append("      <text>").Append(Ascii(d.Line2, false)).Append("</text>").Append(NL);
        if (d.Inline != "") sb.Append("      <image src=\"").Append(Ascii(d.Inline, true)).Append("\"/>").Append(NL);
        if (d.Progress.Enabled)
        {
            var p = d.Progress;
            sb.Append("      <progress");
            if (p.Live)
            {
                sb.Append(" title=\"{progressTitle}\" value=\"{progressValue}\" valueStringOverride=\"{progressValueString}\" status=\"{progressStatus}\"");
            }
            else
            {
                Attr(sb, "title", p.Title);
                sb.Append(" value=\"").Append(Ascii(p.Value == "" ? "0" : p.Value, true)).Append('"');
                Attr(sb, "valueStringOverride", p.ValueText);
                sb.Append(" status=\"").Append(Ascii(p.Status, true)).Append('"');
            }
            sb.Append("/>").Append(NL);
        }
        if (d.Attribution != "") sb.Append("      <text placement=\"attribution\">").Append(Ascii(d.Attribution, false)).Append("</text>").Append(NL);
        sb.Append("    </binding>").Append(NL);
        sb.Append("  </visual>").Append(NL);

        if (d.Inputs.Count > 0 || d.Buttons.Count > 0)
        {
            sb.Append("  <actions>").Append(NL);
            foreach (var i in d.Inputs)
            {
                sb.Append("    <input");
                sb.Append(" id=\"").Append(Ascii(i.Id, true)).Append('"');
                sb.Append(" type=\"").Append(i.Kind == InputKind.Selection ? "selection" : "text").Append('"');
                Attr(sb, "title", i.Title);
                if (i.Kind == InputKind.Text)
                {
                    Attr(sb, "placeHolderContent", i.Placeholder);
                    sb.Append("/>").Append(NL);
                }
                else
                {
                    Attr(sb, "defaultInput", i.Default);
                    sb.Append('>').Append(NL);
                    foreach (var c in i.Choices)
                        sb.Append("      <selection id=\"").Append(Ascii(c.Id, true)).Append("\" content=\"").Append(Ascii(c.Content, true)).Append("\"/>").Append(NL);
                    sb.Append("    </input>").Append(NL);
                }
            }
            foreach (var b in d.Buttons)
            {
                sb.Append("    <action content=\"").Append(Ascii(b.Content, true)).Append('"');
                switch (b.Kind)
                {
                    case ButtonKind.Protocol: sb.Append(" activationType=\"protocol\""); Attr(sb, "arguments", b.Arguments, always: true); break;
                    case ButtonKind.Snooze:   sb.Append(" activationType=\"system\" arguments=\"snooze\""); break;
                    case ButtonKind.Dismiss:  sb.Append(" activationType=\"system\" arguments=\"dismiss\""); break;
                    default:                  Attr(sb, "arguments", b.Arguments, always: true); break;
                }
                Attr(sb, "imageUri", b.Image);
                Attr(sb, "hint-inputId", b.InputId);
                if (b.Style != ButtonStyle.Default) Attr(sb, "hint-buttonStyle", b.Style.ToString());
                sb.Append("/>").Append(NL);
            }
            sb.Append("  </actions>").Append(NL);
        }

        if (d.Silent)
            sb.Append("  <audio silent=\"true\"/>").Append(NL);
        else if (d.Sound != "")
        {
            sb.Append("  <audio src=\"").Append(Ascii(d.Sound, true)).Append('"');
            if (d.SoundLoop) sb.Append(" loop=\"true\"");
            sb.Append("/>").Append(NL);
        }
        sb.Append("</toast>").Append(NL);
        return sb.ToString();
    }

    static void Attr(StringBuilder sb, string name, string? value, bool always = false)
    {
        if (string.IsNullOrEmpty(value) && !always) return;
        sb.Append(' ').Append(name).Append("=\"").Append(Ascii(value ?? "", true)).Append('"');
    }

    /// <summary>XML-escape and turn everything above 127 into a decimal character reference.</summary>
    public static string Ascii(string s, bool attribute)
    {
        var sb = new StringBuilder(s.Length + 8);
        for (int i = 0; i < s.Length; i++)
        {
            char c = s[i];
            switch (c)
            {
                case '&': sb.Append("&amp;"); continue;
                case '<': sb.Append("&lt;"); continue;
                case '>': sb.Append("&gt;"); continue;
                case '"' when attribute: sb.Append("&quot;"); continue;
            }
            if (c < 32 && c != '\t') { sb.Append("&#").Append((int)c).Append(';'); continue; }
            if (c < 128) { sb.Append(c); continue; }
            int cp = c;
            if (char.IsHighSurrogate(c) && i + 1 < s.Length && char.IsLowSurrogate(s[i + 1]))
            {
                cp = char.ConvertToUtf32(c, s[i + 1]);
                i++;
            }
            sb.Append("&#").Append(cp.ToString(CultureInfo.InvariantCulture)).Append(';');
        }
        return sb.ToString();
    }

    // ------------------------------------------------------------------- read
    public static ToastDesign Read(string xml)
    {
        XDocument doc;
        try { doc = XDocument.Parse(xml, LoadOptions.None); }
        catch (XmlException ex) { throw new FormatException("This is not valid XML: " + ex.Message, ex); }
        var toast = doc.Root;
        if (toast == null || toast.Name.LocalName != "toast")
            throw new FormatException("This is not a notification: the outermost element must be <toast>.");

        var d = new ToastDesign();
        foreach (var c in doc.Nodes().OfType<XComment>())
        {
            string v = c.Value;
            if (!v.StartsWith("sample:", StringComparison.Ordinal)) continue;
            int eq = v.IndexOf('=');
            if (eq < 0) continue;
            d.Samples[Decode(v.Substring(7, eq - 7))] = Decode(v.Substring(eq + 1));
        }

        d.Launch = A(toast, "launch");
        d.Scenario = A(toast, "scenario") is { Length: > 0 } sc ? sc : "default";
        d.LongDuration = A(toast, "duration") == "long";

        var binding = toast.Element("visual")?.Elements("binding").FirstOrDefault();
        if (binding != null)
        {
            int n = 0;
            foreach (var e in binding.Elements())
            {
                switch (e.Name.LocalName)
                {
                    case "text":
                        if (A(e, "placement") == "attribution") { d.Attribution = e.Value; break; }
                        if (n == 0) d.Title = e.Value; else if (n == 1) d.Line1 = e.Value; else if (n == 2) d.Line2 = e.Value;
                        n++;
                        break;
                    case "image":
                        switch (A(e, "placement"))
                        {
                            case "hero": d.Hero = A(e, "src"); break;
                            case "appLogoOverride": d.AppLogo = A(e, "src"); d.LogoCircle = A(e, "hint-crop") == "circle"; break;
                            default: if (d.Inline == "") d.Inline = A(e, "src"); break;
                        }
                        break;
                    case "progress":
                        d.Progress.Enabled = true;
                        d.Progress.Live = A(e, "value") == "{progressValue}" && A(e, "title") == "{progressTitle}";
                        if (!d.Progress.Live)
                        {
                            d.Progress.Title = A(e, "title");
                            d.Progress.Value = A(e, "value");
                            d.Progress.ValueText = A(e, "valueStringOverride");
                            d.Progress.Status = A(e, "status");
                        }
                        break;
                }
            }
        }

        var actions = toast.Element("actions");
        if (actions != null)
        {
            foreach (var e in actions.Elements("input"))
            {
                var i = new ToastInput
                {
                    Id = A(e, "id"),
                    Kind = A(e, "type") == "selection" ? InputKind.Selection : InputKind.Text,
                    Title = A(e, "title"),
                    Placeholder = A(e, "placeHolderContent"),
                    Default = A(e, "defaultInput"),
                };
                foreach (var s in e.Elements("selection"))
                    i.Choices.Add(new ToastChoice { Id = A(s, "id"), Content = A(s, "content") });
                d.Inputs.Add(i);
            }
            foreach (var e in actions.Elements("action"))
            {
                var b = new ToastButton
                {
                    Content = A(e, "content"),
                    Arguments = A(e, "arguments"),
                    Image = A(e, "imageUri"),
                    InputId = A(e, "hint-inputId"),
                    Style = Enum.TryParse<ButtonStyle>(A(e, "hint-buttonStyle"), true, out var st) ? st : ButtonStyle.Default,
                };
                switch (A(e, "activationType"))
                {
                    case "protocol": b.Kind = ButtonKind.Protocol; break;
                    case "system":
                        b.Kind = b.Arguments == "dismiss" ? ButtonKind.Dismiss : ButtonKind.Snooze;
                        b.Arguments = "";
                        break;
                }
                d.Buttons.Add(b);
            }
        }

        var audio = toast.Element("audio");
        if (audio != null)
        {
            d.Silent = A(audio, "silent") == "true";
            d.Sound = A(audio, "src");
            d.SoundLoop = A(audio, "loop") == "true";
        }
        return d;
    }

    static string A(XElement e, string name) => e.Attribute(name)?.Value ?? "";

    /// <summary>Undo <see cref="Ascii"/> inside a comment (the XML parser does not).</summary>
    static string Decode(string s)
    {
        if (s.IndexOf('&') < 0) return s;
        var sb = new StringBuilder();
        for (int i = 0; i < s.Length; i++)
        {
            if (s[i] == '&')
            {
                int semi = s.IndexOf(';', i);
                if (semi > i)
                {
                    string ent = s.Substring(i + 1, semi - i - 1);
                    string? rep = ent switch { "amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"", "apos" => "'", _ => null };
                    if (rep == null && ent.StartsWith('#') && int.TryParse(ent.AsSpan(1), NumberStyles.None, CultureInfo.InvariantCulture, out int cp))
                        rep = char.ConvertFromUtf32(cp);
                    if (rep != null) { sb.Append(rep); i = semi; continue; }
                }
            }
            sb.Append(s[i]);
        }
        return sb.ToString();
    }
}
