using System.ComponentModel;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Documents;
using System.Windows.Threading;
using Microsoft.Win32;
using NotificationDesigner.Model;

namespace NotificationDesigner;

public partial class MainWindow : Window
{
    ToastDesign _d = new() { Title = "New notification" };
    string? _path;                    // the .ntf on disk ('' = untitled)
    bool _dirty;
    readonly DesignerSettings _settings = DesignerSettings.Load();
    readonly DispatcherTimer _refresh = new() { Interval = TimeSpan.FromMilliseconds(120) };

    static readonly (string Name, string Glyph, string Hint)[] Sections =
    {
        ("Content", "", "What the notification says. Write {Name} where the program fills in a value - {Customer}, {Amount} - and give it a sample under Placeholders."),
        ("Images", "", "PNG, JPG or GIF. A picture inside the design's folder is stored relative to it, so ship the folder with your program."),
        ("Progress", "", "A progress bar under the text. Make it live and the program moves it with Notifier.UpdateProgress()."),
        ("Inputs", "", "A text box or a drop-down list on the notification. The program reads the answer with Notifier.Input('id')."),
        ("Buttons", "", "Up to five. A button sends its arguments to the program, opens an address, or is Windows' own Snooze / Dismiss."),
        ("Behaviour", "", "What a click on the notification sends, how long it stays, and how it sounds."),
        ("Placeholders", "", "Every {Name} in the design. The sample values are what the preview and Show on Windows use; at run time the program sets them with Notifier.SetVar()."),
    };

    public MainWindow(string? path)
    {
        InitializeComponent();
        foreach (var s in Sections)
        {
            var sp = new StackPanel { Orientation = Orientation.Horizontal };
            sp.Children.Add(new TextBlock { Text = s.Glyph, FontFamily = (FontFamily)FindResource("Icons"), FontSize = 14, Foreground = (Brush)FindResource("Muted"), Width = 26, VerticalAlignment = VerticalAlignment.Center });
            sp.Children.Add(new TextBlock { Text = s.Name, FontSize = 13.5, Foreground = (Brush)FindResource("Ink"), VerticalAlignment = VerticalAlignment.Center });
            Nav.Items.Add(new ListBoxItem { Content = sp });
        }
        _refresh.Tick += (_, _) => { _refresh.Stop(); RefreshAll(); };
        SetTheme(_settings.Dark);

        InputBindings.Add(new KeyBinding(new Cmd(() => New_Click(this, new RoutedEventArgs())), Key.N, ModifierKeys.Control));
        InputBindings.Add(new KeyBinding(new Cmd(() => Open_Click(this, new RoutedEventArgs())), Key.O, ModifierKeys.Control));
        InputBindings.Add(new KeyBinding(new Cmd(() => Save_Click(this, new RoutedEventArgs())), Key.S, ModifierKeys.Control));
        InputBindings.Add(new KeyBinding(new Cmd(() => ShowOnWindows_Click(this, new RoutedEventArgs())), Key.F5, ModifierKeys.None));

        if (!string.IsNullOrWhiteSpace(path))
        {
            _path = Path.GetFullPath(path);
            if (File.Exists(_path)) LoadFile(_path);
            else
            {
                // called from the template for a design that does not exist yet
                _d = Presets.All[0].Make();
                _d.Samples.Clear();
                _d.Title = "New notification";
                _d.Line1 = "";
                _dirty = true;
            }
        }
        Nav.SelectedIndex = 0;
        RefreshAll();
    }

    // ===================================================================== state
    string Folder => _path != null ? Path.GetDirectoryName(_path)! : (_settings.LastFolder != "" ? _settings.LastFolder : Environment.CurrentDirectory);

    void Changed()
    {
        _dirty = true;
        _refresh.Stop();
        _refresh.Start();
    }

    void RefreshAll()
    {
        FileLabel.Text = (_path != null ? Path.GetFileName(_path) : "Untitled") + (_dirty ? "  • unsaved" : "");
        Title = (_path != null ? Path.GetFileName(_path) + " - " : "") + "Notification Designer";
        PreviewHost.Content = ToastPreview.Build(_d, Folder, _settings.Dark, _settings.PreviewAppName, _settings.PreviewAppIcon);
        BuildChips();
        XmlBox.Text = ToastXml.Write(_d);
        CodeBox.Text = ClarionCode();
        BuildChecks();
        Status.Text = _path ?? "Not saved yet";
        StatusRight.Text = $"{Placeholders.Find(_d).Count} placeholder(s)  ·  {_d.Buttons.Count} button(s)  ·  {_d.Inputs.Count} input(s)";
    }

    void BuildChips()
    {
        PreviewChips.Children.Clear();
        void Chip(string glyph, string text)
        {
            var sp = new StackPanel { Orientation = Orientation.Horizontal };
            sp.Children.Add(new TextBlock { Text = glyph, FontFamily = (FontFamily)FindResource("Icons"), FontSize = 11, Margin = new Thickness(0, 1, 6, 0), VerticalAlignment = VerticalAlignment.Center });
            sp.Children.Add(new TextBlock { Text = text, FontSize = 12 });
            var chip = new Border
            {
                Child = sp, Padding = new Thickness(10, 4, 10, 5), Margin = new Thickness(4), CornerRadius = new CornerRadius(12),
                Background = _settings.Dark ? new SolidColorBrush(Color.FromArgb(0x33, 0xFF, 0xFF, 0xFF)) : new SolidColorBrush(Color.FromArgb(0xB3, 0xFF, 0xFF, 0xFF)),
            };
            TextElement.SetForeground(chip, _settings.Dark ? Brushes.WhiteSmoke : (Brush)FindResource("Slate"));
            PreviewChips.Children.Add(chip);
        }
        switch (_d.Scenario)
        {
            case "reminder": Chip("", "Reminder - stays on screen until the user acts"); break;
            case "alarm": Chip("", "Alarm - stays on screen, looping sound"); break;
            case "incomingCall": Chip("", "Incoming call - full width, stays on screen"); break;
            case "urgent": Chip("", "Urgent - breaks through Do Not Disturb (Windows 11)"); break;
        }
        if (_d.LongDuration) Chip("", "Long - about 25 seconds on screen");
        if (_d.Silent) Chip("", "Silent");
        else if (_d.Sound != "") Chip("", SoundName(_d.Sound) + (_d.SoundLoop ? " (looping)" : ""));
        if (_d.Progress.Enabled && _d.Progress.Live) Chip("", "Live progress - moved by the program");
        if (_d.Launch != "") Chip("", "Click sends: " + Placeholders.Apply(_d.Launch, _d.Samples));
    }

    void BuildChecks()
    {
        Checks.Children.Clear();
        var issues = DesignValidator.Check(_d, Folder);
        if (issues.Count == 0)
        {
            Checks.Children.Add(CheckLine("", (Brush)FindResource("Success"), "Ready. Windows will show this as designed."));
            return;
        }
        foreach (var i in issues.OrderByDescending(i => i.Severity))
            Checks.Children.Add(CheckLine(i.Severity == Severity.Error ? "" : "",
                (Brush)FindResource(i.Severity == Severity.Error ? "Danger" : "Warn"), i.Message));
    }

    FrameworkElement CheckLine(string glyph, Brush fg, string text)
    {
        var dp = new DockPanel { Margin = new Thickness(0, 2, 0, 2) };
        var g = new TextBlock { Text = glyph, FontFamily = (FontFamily)FindResource("Icons"), Foreground = fg, FontSize = 13, Margin = new Thickness(0, 2, 8, 0), VerticalAlignment = VerticalAlignment.Top };
        DockPanel.SetDock(g, Dock.Left);
        dp.Children.Add(g);
        dp.Children.Add(new TextBlock { Text = text, TextWrapping = TextWrapping.Wrap, FontSize = 12.5, Foreground = (Brush)FindResource("Ink") });
        return dp;
    }

    static string SoundName(string src) => src == "" ? "Windows default" : src.Replace("ms-winsoundevent:Notification.", "").Replace("Looping.", "Looping ");

    // ============================================================== Clarion code
    string ClarionCode()
    {
        string file = _path != null ? Path.GetFileName(_path) : "mydesign.ntf";
        var names = Placeholders.Find(_d);
        var sb = new StringBuilder();
        sb.AppendLine("! ---------------------------------------------------------------------------");
        sb.AppendLine("!  1. WITH THE TEMPLATE (recommended)");
        sb.AppendLine("!     Add the 'Show a notification' code template to any embed and pick");
        sb.AppendLine($"!     {file}. It embeds the design in the program - nothing to ship but");
        sb.AppendLine("!     the pictures - and asks for a Clarion expression for each placeholder.");
        sb.AppendLine("! ---------------------------------------------------------------------------");
        sb.AppendLine();
        sb.AppendLine("! ---------------------------------------------------------------------------");
        sb.AppendLine("!  2. BY HAND - load the design at run time");
        sb.AppendLine("! ---------------------------------------------------------------------------");
        sb.AppendLine($"  Notifier.LoadDesign('{file}')");
        foreach (var n in names)
        {
            _d.Samples.TryGetValue(n, out var sample);
            sb.AppendLine($"  Notifier.SetVar('{n}', Loc:{n})".PadRight(52) + (string.IsNullOrEmpty(sample) ? "" : $"! e.g. {sample.Replace("'", "''")}"));
        }
        string tag = _path != null ? Path.GetFileNameWithoutExtension(_path) : "mynote";
        sb.AppendLine($"  Notifier.ShowToast('{tag}')".PadRight(52) + "! the tag finds it again later");
        if (_d.Progress.Enabled && _d.Progress.Live)
        {
            sb.AppendLine();
            sb.AppendLine("  ! move the bar while the work runs (0.0 - 1.0)");
            sb.AppendLine($"  Notifier.UpdateProgress(Done / Total, 'Working...', Done & ' of ' & Total, '{tag}')");
            sb.AppendLine($"  Notifier.Remove('{tag}')".PadRight(52) + "! when finished");
        }
        sb.AppendLine();
        sb.AppendLine("! ---------------------------------------------------------------------------");
        sb.AppendLine("!  3. WHEN THE USER CLICKS - the window extension generates this loop");
        sb.AppendLine("! ---------------------------------------------------------------------------");
        sb.AppendLine("  LOOP WHILE Notifier.NextEvent()");
        sb.AppendLine("    CASE Notifier.EventKind");
        sb.AppendLine("    OF Notify:Activated");

        var acts = new List<(string Action, string From)>();
        void Collect(string args, string from)
        {
            foreach (var part in args.Split(';', '&'))
            {
                var kv = part.Split('=', 2);
                if (kv.Length == 2 && kv[0].Trim().Equals("action", StringComparison.OrdinalIgnoreCase))
                {
                    var a = kv[1].Trim();
                    var i = acts.FindIndex(x => x.Action == a);
                    if (i < 0) acts.Add((a, from)); else acts[i] = (a, acts[i].From + ", " + from);
                }
            }
        }
        if (_d.Launch != "") Collect(_d.Launch, "a click on the notification");
        foreach (var b in _d.Buttons.Where(b => b.Kind == ButtonKind.Foreground)) Collect(b.Arguments, $"'{b.Content}'");
        if (acts.Count > 0)
        {
            sb.AppendLine("      CASE Notifier.Arg('action')");
            foreach (var (a, from) in acts)
            {
                sb.AppendLine($"      OF '{a}'".PadRight(36) + $"! {from}");
                var b = _d.Buttons.FirstOrDefault(x => x.Arguments.Contains("action=" + a) && x.InputId != "");
                foreach (var part in (_d.Buttons.FirstOrDefault(x => x.Arguments.Contains("action=" + a))?.Arguments ?? _d.Launch).Split(';', '&'))
                {
                    var kv = part.Split('=', 2);
                    if (kv.Length == 2 && !kv[0].Trim().Equals("action", StringComparison.OrdinalIgnoreCase))
                        sb.AppendLine($"        ! Notifier.Arg('{kv[0].Trim()}')");
                }
                if (b != null) sb.AppendLine($"        ! Notifier.Input('{b.InputId}') is what the user typed");
            }
            sb.AppendLine("      END");
        }
        else
        {
            sb.AppendLine("      ! Notifier.EventArgs holds the arguments of what was clicked");
        }
        foreach (var i in _d.Inputs.Where(i => !_d.Buttons.Any(b => b.InputId == i.Id && b.Kind == ButtonKind.Foreground)))
            sb.AppendLine($"      ! Notifier.Input('{i.Id}')  - the {(i.Kind == InputKind.Selection ? "choice picked" : "text typed")}");
        sb.AppendLine("    OF Notify:Dismissed");
        sb.AppendLine("      ! Notifier.DismissReason: Notify:UserCanceled / Notify:TimedOut / Notify:AppHidden");
        sb.AppendLine("    OF Notify:Failed");
        sb.AppendLine("      ! Notifier.FailText() says why, e.g. notifications turned off in Settings");
        sb.AppendLine("    END");
        sb.AppendLine("  END");
        return sb.ToString();
    }

    // ================================================================= sections
    void Nav_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (Nav.SelectedIndex < 0) return;
        BuildSection();
        EditorScroll.ScrollToTop();
    }

    void BuildSection()
    {
        var s = Sections[Math.Max(0, Nav.SelectedIndex)];
        SectionTitle.Text = s.Name;
        SectionHint.Text = s.Hint;
        Editor.Children.Clear();
        switch (s.Name)
        {
            case "Content": BuildContent(); break;
            case "Images": BuildImages(); break;
            case "Progress": BuildProgress(); break;
            case "Inputs": BuildInputs(); break;
            case "Buttons": BuildButtons(); break;
            case "Behaviour": BuildBehaviour(); break;
            case "Placeholders": BuildPlaceholders(); break;
        }
    }

    void BuildContent()
    {
        Editor.Children.Add(Field("Title", () => _d.Title, v => _d.Title = v, "Bold, up to two lines."));
        Editor.Children.Add(Field("Text", () => _d.Line1, v => _d.Line1 = v, multiline: true));
        Editor.Children.Add(Field("Second text", () => _d.Line2, v => _d.Line2 = v, "Optional. Windows shows at most four lines of text in all.", multiline: true));
        Editor.Children.Add(Field("Attribution", () => _d.Attribution, v => _d.Attribution = v, "Small print under the text: where it came from (\"Accounts\", \"via Sync\")."));
    }

    void BuildImages()
    {
        Editor.Children.Add(ImageField("App logo", () => _d.AppLogo, v => _d.AppLogo = v, "Square, shown 48 x 48 beside the text. 96 x 96 or larger looks sharp."));
        Editor.Children.Add(Check("Crop the logo to a circle (avatars)", () => _d.LogoCircle, v => _d.LogoCircle = v));
        Editor.Children.Add(Spacer());
        Editor.Children.Add(ImageField("Hero picture", () => _d.Hero, v => _d.Hero = v, "Wide banner across the top, 2:1 (728 x 364 is ideal)."));
        Editor.Children.Add(ImageField("Inline picture", () => _d.Inline, v => _d.Inline = v, "Full width under the text."));
        Editor.Children.Add(Note("Placeholders work in paths too: images\\{Customer}.png picks a picture per customer at run time."));
    }

    void BuildProgress()
    {
        var p = _d.Progress;
        Editor.Children.Add(Check("Show a progress bar", () => p.Enabled, v => { p.Enabled = v; BuildSection(); }));
        if (!p.Enabled) return;
        Editor.Children.Add(Check("Live - the program moves it while the work runs", () => p.Live, v => { p.Live = v; BuildSection(); }));
        if (p.Live)
        {
            Editor.Children.Add(Note("The bar is bound to {progressTitle}, {progressValue}, {progressValueString} and {progressStatus}. " +
                                     "Notifier.UpdateProgress(0.62, 'Writing sheets...', '62%') moves it without a new pop-up. " +
                                     "These samples are only for the preview:"));
            Editor.Children.Add(SampleField("Title", "progressTitle"));
            Editor.Children.Add(SampleField("Value (0 - 1)", "progressValue"));
            Editor.Children.Add(SampleField("Value text", "progressValueString"));
            Editor.Children.Add(SampleField("Status", "progressStatus"));
            return;
        }
        Editor.Children.Add(Field("Title", () => p.Title, v => p.Title = v, "Above the bar, left."));
        Editor.Children.Add(Field("Value", () => p.Value, v => p.Value = v, "0 to 1 (0.75 = 75%), indeterminate, or a {placeholder}."));
        Editor.Children.Add(Field("Value text", () => p.ValueText, v => p.ValueText = v, "Replaces the percentage under the bar, right (\"3 of 8 files\")."));
        Editor.Children.Add(Field("Status", () => p.Status, v => p.Status = v, "Under the bar, left (\"Downloading...\")."));
    }

    void BuildInputs()
    {
        var bar = new WrapPanel { Margin = new Thickness(0, 0, 0, 12) };
        bar.Children.Add(SmallButton("", "Text box", () => { _d.Inputs.Add(new ToastInput { Id = NextId("text"), Kind = InputKind.Text, Placeholder = "Type here" }); Changed(); BuildSection(); }));
        bar.Children.Add(SmallButton("", "Choice list", () =>
        {
            var i = new ToastInput { Id = NextId("choice"), Kind = InputKind.Selection, Default = "a" };
            i.Choices.Add(new ToastChoice { Id = "a", Content = "First choice" });
            i.Choices.Add(new ToastChoice { Id = "b", Content = "Second choice" });
            _d.Inputs.Add(i);
            Changed();
            BuildSection();
        }));
        Editor.Children.Add(bar);
        if (_d.Inputs.Count == 0) Editor.Children.Add(Note("No inputs. A text box with a Send button beside it makes a quick-reply notification (see the Chat reply preset)."));
        for (int n = 0; n < _d.Inputs.Count; n++)
        {
            var i = _d.Inputs[n];
            var card = Card(i.Kind == InputKind.Text ? "Text box" : "Choice list", n, _d.Inputs);
            var c = (StackPanel)card.Tag;
            c.Children.Add(Field("Id", () => i.Id, v => i.Id = v, "The program reads the answer with Notifier.Input('" + i.Id + "')."));
            c.Children.Add(Field("Title", () => i.Title, v => i.Title = v, "Optional label above it."));
            if (i.Kind == InputKind.Text)
                c.Children.Add(Field("Placeholder", () => i.Placeholder, v => i.Placeholder = v, "Grey hint inside the empty box."));
            else
            {
                c.Children.Add(Field("Choices", () => string.Join("\r\n", i.Choices.Select(x => x.Id + ": " + x.Content)), v =>
                {
                    i.Choices.Clear();
                    foreach (var line in v.Split('\n').Select(l => l.Trim()).Where(l => l != ""))
                    {
                        int colon = line.IndexOf(':');
                        i.Choices.Add(colon > 0
                            ? new ToastChoice { Id = line[..colon].Trim(), Content = line[(colon + 1)..].Trim() }
                            : new ToastChoice { Id = line, Content = line });
                    }
                }, "One per line:  id: text   - the program receives the id.", multiline: true));
                c.Children.Add(Field("Selected at first", () => i.Default, v => i.Default = v, "The id of the choice shown first."));
            }
            Editor.Children.Add(card);
        }
    }

    string NextId(string stem)
    {
        for (int n = 1; ; n++)
            if (!_d.Inputs.Any(i => i.Id == stem + n)) return stem + n;
    }

    void BuildButtons()
    {
        var bar = new WrapPanel { Margin = new Thickness(0, 0, 0, 12) };
        bar.Children.Add(SmallButton("", "Button", () => AddButton(new ToastButton { Content = "Open", Arguments = "action=open" })));
        bar.Children.Add(SmallButton("", "Link", () => AddButton(new ToastButton { Content = "Website", Kind = ButtonKind.Protocol, Arguments = "https://" })));
        bar.Children.Add(SmallButton("", "Snooze", () => AddButton(new ToastButton { Kind = ButtonKind.Snooze })));
        bar.Children.Add(SmallButton("", "Dismiss", () => AddButton(new ToastButton { Kind = ButtonKind.Dismiss })));
        Editor.Children.Add(bar);
        if (_d.Buttons.Count == 0) Editor.Children.Add(Note("No buttons. A click on the notification itself still reaches the program (Behaviour > When clicked)."));
        for (int n = 0; n < _d.Buttons.Count; n++)
        {
            var b = _d.Buttons[n];
            string kind = b.Kind switch { ButtonKind.Protocol => "Link", ButtonKind.Snooze => "Snooze (Windows)", ButtonKind.Dismiss => "Dismiss (Windows)", _ => "Button" };
            var card = Card(kind, n, _d.Buttons);
            var c = (StackPanel)card.Tag;
            bool system = b.Kind is ButtonKind.Snooze or ButtonKind.Dismiss;
            c.Children.Add(Field("Caption", () => b.Content, v => b.Content = v, system ? "Leave empty for Windows' own wording, in the user's language." : null));
            if (b.Kind == ButtonKind.Foreground)
                c.Children.Add(Field("Arguments", () => b.Arguments, v => b.Arguments = v, "Sent to the program: action=open;id={Id} -> Notifier.Arg('action') = 'open'."));
            if (b.Kind == ButtonKind.Protocol)
                c.Children.Add(Field("Address", () => b.Arguments, v => b.Arguments = v, "https://..., mailto:..., or any registered protocol. Windows opens it; the program is not told."));
            var inputs = new List<string> { "" };
            inputs.AddRange(_d.Inputs.Where(i => b.Kind == ButtonKind.Snooze ? i.Kind == InputKind.Selection : i.Kind == InputKind.Text).Select(i => i.Id));
            if (b.Kind is ButtonKind.Foreground or ButtonKind.Snooze && inputs.Count > 1)
                c.Children.Add(Combo(b.Kind == ButtonKind.Snooze ? "Snooze time from" : "Beside the text box", inputs, () => b.InputId, v => b.InputId = v,
                    b.Kind == ButtonKind.Snooze ? "The choice list whose ids are minutes." : "Makes it a Send button next to that box."));
            if (!system)
            {
                c.Children.Add(Combo("Style", new[] { "Default", "Success", "Critical" }, () => b.Style.ToString(), v => b.Style = Enum.Parse<ButtonStyle>(v),
                    "Success is green, Critical red."));
                c.Children.Add(ImageField("Icon", () => b.Image, v => b.Image = v, "Optional 16 x 16 picture before the caption."));
            }
            Editor.Children.Add(card);
        }
    }

    void AddButton(ToastButton b)
    {
        if (_d.Buttons.Count >= 5) { Dialogs.Show(this, "Five buttons already", "Windows shows at most five buttons on a notification.", DialogKind.Warning); return; }
        _d.Buttons.Add(b);
        Changed();
        BuildSection();
    }

    void BuildBehaviour()
    {
        Editor.Children.Add(Field("When clicked, send", () => _d.Launch, v => _d.Launch = v,
            "Arguments for a click on the notification itself, e.g. action=open;id={Id}. Read them with Notifier.Arg('id')."));
        Editor.Children.Add(Combo("Kind", ToastDesign.Scenarios, () => _d.Scenario, v => _d.Scenario = v,
            "reminder / alarm / incomingCall stay on screen until the user acts (they need a button); urgent breaks through Do Not Disturb."));
        Editor.Children.Add(Check("Stay longer on screen (about 25 seconds)", () => _d.LongDuration, v => _d.LongDuration = v));
        Editor.Children.Add(Spacer());
        Editor.Children.Add(Check("Silent", () => _d.Silent, v => { _d.Silent = v; BuildSection(); }));
        if (!_d.Silent)
        {
            Editor.Children.Add(Combo("Sound", ToastDesign.Sounds.Select(SoundName).ToList(), () => SoundName(_d.Sound),
                v => _d.Sound = ToastDesign.Sounds.First(s => SoundName(s) == v), "The Looping sounds repeat only for alarms and calls."));
            Editor.Children.Add(Check("Loop the sound", () => _d.SoundLoop, v => _d.SoundLoop = v));
        }
    }

    void BuildPlaceholders()
    {
        var names = Placeholders.Find(_d);
        if (names.Count == 0)
            Editor.Children.Add(Note("This design has no placeholders yet. Type {Customer} (any name in braces) into a text, an argument or a picture path."));
        foreach (var n in names) Editor.Children.Add(SampleField("{" + n + "}", n));

        Editor.Children.Add(Spacer());
        Editor.Children.Add(new TextBlock { Text = "PREVIEW AS", FontSize = 11, FontWeight = FontWeights.SemiBold, Foreground = (Brush)FindResource("Subtle"), Margin = new Thickness(0, 6, 0, 8) });
        Editor.Children.Add(Field("Program name", () => _settings.PreviewAppName, v => { _settings.PreviewAppName = v; _settings.Save(); }, "What your Init() registers as DisplayName. A designer setting, not part of the file.", dirties: false));
        Editor.Children.Add(ImageField("Program icon", () => _settings.PreviewAppIcon, v => { _settings.PreviewAppIcon = v; _settings.Save(); }, "Your IconFile.", relative: false, dirties: false));
    }

    // =============================================================== form parts
    FrameworkElement Labelled(string label, FrameworkElement input, string? hint)
    {
        var sp = new StackPanel { Margin = new Thickness(0, 0, 0, 14) };
        sp.Children.Add(new TextBlock { Text = label, FontSize = 12.5, FontWeight = FontWeights.SemiBold, Foreground = (Brush)FindResource("Ink"), Margin = new Thickness(0, 0, 0, 5) });
        sp.Children.Add(input);
        if (!string.IsNullOrEmpty(hint))
            sp.Children.Add(new TextBlock { Text = hint, FontSize = 12, Foreground = (Brush)FindResource("Muted"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 5, 0, 0) });
        return sp;
    }

    FrameworkElement Field(string label, Func<string> get, Action<string> set, string? hint = null, bool multiline = false, bool dirties = true)
    {
        var tb = new TextBox { Text = get() };
        if (multiline) { tb.AcceptsReturn = true; tb.TextWrapping = TextWrapping.Wrap; tb.MinHeight = 56; tb.VerticalContentAlignment = VerticalAlignment.Top; }
        tb.TextChanged += (_, _) =>
        {
            set(tb.Text);
            if (dirties) Changed(); else { _refresh.Stop(); _refresh.Start(); }
        };
        return Labelled(label, tb, hint);
    }

    FrameworkElement SampleField(string label, string key)
    {
        _d.Samples.TryGetValue(key, out var v);
        return Field(label, () => v ?? "", s => _d.Samples[key] = s, null);
    }

    FrameworkElement ImageField(string label, Func<string> get, Action<string> set, string? hint, bool relative = true, bool dirties = true)
    {
        var dp = new DockPanel();
        var tb = new TextBox { Text = get() };
        var browse = new Button { Content = "Browse...", Margin = new Thickness(6, 0, 0, 0), Padding = new Thickness(10, 6, 10, 6) };
        DockPanel.SetDock(browse, Dock.Right);
        dp.Children.Add(browse);
        dp.Children.Add(tb);
        tb.TextChanged += (_, _) => { set(tb.Text.Trim()); if (dirties) Changed(); else { _refresh.Stop(); _refresh.Start(); } };
        browse.Click += (_, _) =>
        {
            var ofd = new OpenFileDialog
            {
                Title = label,
                Filter = "Pictures (*.png;*.jpg;*.jpeg;*.gif;*.ico)|*.png;*.jpg;*.jpeg;*.gif;*.ico|All files (*.*)|*.*",
                InitialDirectory = Folder,
            };
            if (ofd.ShowDialog(this) == true)
                tb.Text = relative ? DesignPaths.MakeRelative(Folder, ofd.FileName) : ofd.FileName;
        };
        return Labelled(label, dp, hint);
    }

    FrameworkElement Check(string label, Func<bool> get, Action<bool> set)
    {
        var cb = new CheckBox { Content = label, IsChecked = get(), Margin = new Thickness(0, 0, 0, 10) };
        cb.Click += (_, _) => { set(cb.IsChecked == true); Changed(); };
        return cb;
    }

    FrameworkElement Combo(string label, IList<string> items, Func<string> get, Action<string> set, string? hint)
    {
        var cb = new ComboBox { ItemsSource = items.Select(i => i == "" ? "(none)" : i).ToList() };
        string cur = get();
        cb.SelectedItem = cur == "" ? "(none)" : cur;
        cb.SelectionChanged += (_, _) =>
        {
            if (cb.SelectedItem is string s) { set(s == "(none)" ? "" : s); Changed(); }
        };
        return Labelled(label, cb, hint);
    }

    FrameworkElement Note(string text) => new Border
    {
        Background = (Brush)FindResource("Hover"), CornerRadius = new CornerRadius(8), Padding = new Thickness(12, 9, 12, 10), Margin = new Thickness(0, 0, 0, 14),
        Child = new TextBlock { Text = text, TextWrapping = TextWrapping.Wrap, FontSize = 12.5, Foreground = (Brush)FindResource("Muted"), LineHeight = 18 },
    };

    static FrameworkElement Spacer() => new Border { Height = 1, Background = new SolidColorBrush(Color.FromRgb(0xE7, 0xEA, 0xEF)), Margin = new Thickness(0, 4, 0, 16) };

    Button SmallButton(string glyph, string text, Action click)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal };
        sp.Children.Add(new TextBlock { Text = glyph, FontFamily = (FontFamily)FindResource("Icons"), FontSize = 11, Margin = new Thickness(0, 2, 6, 0) });
        sp.Children.Add(new TextBlock { Text = text });
        var b = new Button { Content = sp, Margin = new Thickness(0, 0, 6, 6), Padding = new Thickness(11, 6, 12, 6) };
        b.Click += (_, _) => click();
        return b;
    }

    /// <summary>A card with a header (kind, up, down, remove); its body StackPanel is in Tag.</summary>
    Border Card<T>(string kind, int index, List<T> list)
    {
        var body = new StackPanel { Margin = new Thickness(0, 10, 0, 0) };
        var head = new DockPanel();
        var del = new Button { Style = (Style)FindResource("IconBtn"), Content = "", ToolTip = "Remove" };
        var down = new Button { Style = (Style)FindResource("IconBtn"), Content = "", ToolTip = "Move down", IsEnabled = index < list.Count - 1 };
        var up = new Button { Style = (Style)FindResource("IconBtn"), Content = "", ToolTip = "Move up", IsEnabled = index > 0 };
        foreach (var b in new[] { del, down, up }) { DockPanel.SetDock(b, Dock.Right); head.Children.Add(b); }
        del.Click += (_, _) => { list.RemoveAt(index); Changed(); BuildSection(); };
        up.Click += (_, _) => { (list[index - 1], list[index]) = (list[index], list[index - 1]); Changed(); BuildSection(); };
        down.Click += (_, _) => { (list[index + 1], list[index]) = (list[index], list[index + 1]); Changed(); BuildSection(); };
        head.Children.Add(new TextBlock { Text = $"{index + 1}.  {kind}", FontWeight = FontWeights.SemiBold, FontSize = 13, Foreground = (Brush)FindResource("Slate"), VerticalAlignment = VerticalAlignment.Center });
        var all = new StackPanel();
        all.Children.Add(head);
        all.Children.Add(body);
        return new Border
        {
            Child = all, Tag = body, Margin = new Thickness(0, 0, 0, 12), Padding = new Thickness(14, 8, 8, 0),
            CornerRadius = new CornerRadius(10), BorderBrush = (Brush)FindResource("Line"), BorderThickness = new Thickness(1), Background = (Brush)FindResource("Panel"),
        };
    }

    // ================================================================ commands
    void New_Click(object sender, RoutedEventArgs e)
    {
        if (!ConfirmDiscard()) return;
        var p = Dialogs.PickPreset(this);
        if (p == null) return;
        _d = p.Make();
        _path = null;
        _dirty = false;
        Nav.SelectedIndex = 0;
        BuildSection();
        RefreshAll();
    }

    void Open_Click(object sender, RoutedEventArgs e)
    {
        if (!ConfirmDiscard()) return;
        var ofd = new OpenFileDialog { Filter = "Notification designs (*.ntf)|*.ntf|XML (*.xml)|*.xml|All files (*.*)|*.*", InitialDirectory = Folder };
        if (ofd.ShowDialog(this) != true) return;
        LoadFile(ofd.FileName);
        Nav.SelectedIndex = 0;
        BuildSection();
        RefreshAll();
    }

    void LoadFile(string file)
    {
        try
        {
            _d = ToastXml.Read(File.ReadAllText(file));
            _path = Path.GetFullPath(file);
            _dirty = false;
            _settings.LastFolder = Path.GetDirectoryName(_path)!;
            _settings.Save();
        }
        catch (Exception ex)
        {
            Dialogs.Show(this, "Cannot open the design", $"{Path.GetFileName(file)} could not be read.\n\n{ex.Message}", DialogKind.Error);
        }
    }

    void Save_Click(object sender, RoutedEventArgs e) => Save(false);
    void SaveAs_Click(object sender, RoutedEventArgs e) => Save(true);

    bool Save(bool askName)
    {
        string? target = _path;
        if (askName || target == null)
        {
            var sfd = new SaveFileDialog
            {
                Filter = "Notification designs (*.ntf)|*.ntf", DefaultExt = ".ntf", AddExtension = true, InitialDirectory = Folder,
                FileName = target != null ? Path.GetFileName(target) : MakeFileName(_d.Title),
            };
            if (sfd.ShowDialog(this) != true) return false;
            target = sfd.FileName;
        }
        try
        {
            // pictures that now sit under the design's folder are stored relative to it
            string folder = Path.GetDirectoryName(target)!;
            string Rel(string p) => p == "" ? "" : DesignPaths.MakeRelative(folder, DesignPaths.Resolve(Folder, p));
            _d.AppLogo = Rel(_d.AppLogo); _d.Hero = Rel(_d.Hero); _d.Inline = Rel(_d.Inline);
            foreach (var b in _d.Buttons) b.Image = Rel(b.Image);
            File.WriteAllText(target, ToastXml.Write(_d), new UTF8Encoding(false));   // ASCII in practice
            _path = target;
            _dirty = false;
            _settings.LastFolder = folder;
            _settings.Save();
            BuildSection();
            RefreshAll();
            Status.Text = "Saved " + target;
            return true;
        }
        catch (Exception ex)
        {
            Dialogs.Show(this, "Cannot save", ex.Message, DialogKind.Error);
            return false;
        }
    }

    static string MakeFileName(string title)
    {
        var sb = new StringBuilder();
        foreach (char c in title.ToLowerInvariant())
            if (char.IsLetterOrDigit(c) && c < 128) sb.Append(c);
            else if (sb.Length > 0 && sb[^1] != '-') sb.Append('-');
        string s = sb.ToString().Trim('-');
        return (s == "" ? "notification" : s.Length > 40 ? s[..40] : s) + ".ntf";
    }

    bool ConfirmDiscard()
    {
        if (!_dirty) return true;
        int r = Dialogs.Ask(this, "Save your changes?", $"{(_path != null ? Path.GetFileName(_path) : "This design")} has changes that are not saved.",
            DialogKind.Question, "Save", "Don't save", "Cancel");
        return r switch { 0 => Save(false), 1 => true, _ => false };
    }

    bool _force;

    /// <summary>Screenshot mode: which section, tab and theme to show (the theme is not saved).</summary>
    public void PrepareShot(string? section, int tab, bool? dark)
    {
        int i = Array.FindIndex(Sections, s => s.Name.Equals(section ?? "", StringComparison.OrdinalIgnoreCase));
        if (i >= 0) Nav.SelectedIndex = i;
        StageTabs.SelectedIndex = tab;
        if (dark != null)
        {
            bool keep = DesignerSettings.Load().Dark;
            SetTheme(dark.Value);
            _settings.Dark = keep;
            _settings.Save();
            _settings.Dark = dark.Value;
            Desk.Background = tab == 0 ? ToastPreview.Desk(dark.Value) : (Brush)FindResource("Panel");
            RefreshAll();
        }
    }

    public void ForceClose()
    {
        _force = true;
        Close();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!_force && !ConfirmDiscard()) e.Cancel = true;
        base.OnClosing(e);
    }

    void ShowOnWindows_Click(object sender, RoutedEventArgs e)
    {
        var errors = DesignValidator.Check(_d).Where(i => i.Severity == Severity.Error).ToList();
        if (errors.Count > 0)
        {
            Dialogs.Show(this, "Fix the design first", string.Join("\n", errors.Select(i => "• " + i.Message)), DialogKind.Warning);
            return;
        }
        try
        {
            WindowsToast.Show(_d, Folder, _settings.PreviewAppName, _settings.PreviewAppIcon, r => Dispatcher.BeginInvoke(() => LogEvent(r)));
            Status.Text = "Sent to Windows - look at the bottom-right corner of the screen.";
        }
        catch (Exception ex)
        {
            Dialogs.Show(this, "Windows refused the notification", ex.Message, DialogKind.Error);
        }
    }

    void LogEvent(WindowsToast.Received r)
    {
        EventHint.Visibility = Visibility.Collapsed;
        var sp = new StackPanel { Margin = new Thickness(0, 0, 0, 6) };
        var line = new TextBlock { FontSize = 12.5, TextWrapping = TextWrapping.Wrap, Foreground = (Brush)FindResource("Ink") };
        line.Inlines.Add(new System.Windows.Documents.Run(DateTime.Now.ToString("HH:mm:ss") + "  ") { Foreground = (Brush)FindResource("Subtle") });
        bool act = r.What == "Activated";
        line.Inlines.Add(new System.Windows.Documents.Run(act ? "Notify:Activated" : r.What) { FontWeight = FontWeights.SemiBold });
        if (act)
        {
            var src = _d.Buttons.FirstOrDefault(b => b.Kind == ButtonKind.Foreground && Placeholders.Apply(b.Arguments, _d.Samples) == r.Arguments);
            line.Inlines.Add(new System.Windows.Documents.Run(src != null ? $"  - button '{Placeholders.Apply(src.Content, _d.Samples)}'" : "  - the notification itself"));
        }
        sp.Children.Add(line);
        if (act)
            sp.Children.Add(new TextBlock
            {
                Text = "EventArgs = '" + r.Arguments + "'" + string.Concat(r.Inputs.Select(i => $"   Input('{i.Id}') = '{i.Value}'")),
                FontFamily = (FontFamily)FindResource("Mono"), FontSize = 12, Foreground = (Brush)FindResource("Muted"), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(62, 1, 0, 0),
            });
        EventLog.Children.Insert(0, sp);
    }

    void ClearLog_Click(object sender, RoutedEventArgs e)
    {
        EventLog.Children.Clear();
        EventHint.Visibility = Visibility.Visible;
        EventLog.Children.Add(EventHint);
    }

    void Help_Click(object sender, RoutedEventArgs e) => Dialogs.Show(this, "How it fits together",
        "1. Design the notification here and save it as a .ntf file - the design is the very XML Windows reads.\n\n" +
        "2. In your Clarion app, add the 'notifications' global extension (it registers your program with Windows), " +
        "then the 'Show a notification' code template wherever it should pop up. Pick the .ntf there - its Design button " +
        "opens this designer on it - and give each {placeholder} a Clarion expression.\n\n" +
        "3. Add the 'Notification events' extension to the frame (or any window) and fill in its embeds to react when the " +
        "user clicks the notification, a button, or replies.\n\n" +
        "Show on Windows sends the design to Windows right now, and the panel on the right shows exactly what your program would receive.",
        DialogKind.Info);

    void StageTabs_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (PreviewScroll == null) return;
        int i = StageTabs.SelectedIndex;
        PreviewScroll.Visibility = i == 0 ? Visibility.Visible : Visibility.Collapsed;
        XmlBox.Visibility = i == 1 ? Visibility.Visible : Visibility.Collapsed;
        CodeBox.Visibility = i == 2 ? Visibility.Visible : Visibility.Collapsed;
        CopyBtn.Visibility = i == 0 ? Visibility.Collapsed : Visibility.Visible;
        ThemeSwitch.Visibility = i == 0 ? Visibility.Visible : Visibility.Hidden;
        Desk.Background = i == 0 ? ToastPreview.Desk(_settings.Dark) : (Brush)FindResource("Panel");
    }

    void Copy_Click(object sender, RoutedEventArgs e)
    {
        Clipboard.SetText(StageTabs.SelectedIndex == 1 ? XmlBox.Text : CodeBox.Text);
        Status.Text = "Copied to the clipboard.";
    }

    void Theme_Click(object sender, RoutedEventArgs e) => SetTheme(((FrameworkElement)sender).Tag as string == "dark");

    void SetTheme(bool dark)
    {
        _settings.Dark = dark;
        _settings.Save();
        LightBtn.IsChecked = !dark;
        DarkBtn.IsChecked = dark;
        if (StageTabs.SelectedIndex <= 0) Desk.Background = ToastPreview.Desk(dark);
        if (PreviewHost != null && IsLoaded) RefreshAll();
    }

    sealed class Cmd(Action a) : ICommand
    {
        public event EventHandler? CanExecuteChanged { add { } remove { } }
        public bool CanExecute(object? p) => true;
        public void Execute(object? p) => a();
    }
}
