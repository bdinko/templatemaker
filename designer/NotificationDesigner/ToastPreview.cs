using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using NotificationDesigner.Model;

namespace NotificationDesigner;

/// <summary>
/// Draws a design the way Windows 11 lays a toast out: a 364px card with the
/// app's name across the top, an optional hero picture, logo + text, inline
/// picture, progress bar, inputs, and a row of equal buttons. Only an
/// approximation - "Show on Windows" is the real thing - but close enough to
/// design by.
/// </summary>
public static class ToastPreview
{
    sealed class Palette
    {
        public Brush Card = null!, Border = null!, Primary = null!, Secondary = null!, Tertiary = null!;
        public Brush Button = null!, ButtonBorder = null!, Input = null!, InputBorder = null!, Accent = null!, Track = null!;
    }

    static Brush B(string hex) { var b = (SolidColorBrush)new BrushConverter().ConvertFromString(hex)!; b.Freeze(); return b; }

    static readonly Palette Light = new()
    {
        Card = B("#F7F7F7"), Border = B("#1A000000"), Primary = B("#1B1B1B"), Secondary = B("#5C5C5C"), Tertiary = B("#8A8A8A"),
        Button = B("#FDFDFD"), ButtonBorder = B("#E3E3E3"), Input = B("#FFFFFF"), InputBorder = B("#D3D3D3"), Accent = B("#005FB8"), Track = B("#D9D9D9"),
    };
    static readonly Palette Dark = new()
    {
        Card = B("#2B2B2B"), Border = B("#33FFFFFF"), Primary = B("#FFFFFF"), Secondary = B("#C8C8C8"), Tertiary = B("#9A9A9A"),
        Button = B("#373737"), ButtonBorder = B("#444444"), Input = B("#1F1F1F"), InputBorder = B("#4A4A4A"), Accent = B("#4CC2FF"), Track = B("#555555"),
    };
    static readonly Brush SuccessBtn = B("#0F7B0F");
    static readonly Brush CriticalBtn = B("#C42B1C");
    static readonly FontFamily Ui = new("Segoe UI Variable Text, Segoe UI");
    static readonly FontFamily Icons = new("Segoe Fluent Icons, Segoe MDL2 Assets");

    const double W = 364, Pad = 12, Inner = W - 2 * Pad;

    public static Brush Desk(bool dark)
    {
        var g = dark
            ? new LinearGradientBrush((Color)ColorConverter.ConvertFromString("#18222E"), (Color)ColorConverter.ConvertFromString("#0B1118"), 65)
            : new LinearGradientBrush((Color)ColorConverter.ConvertFromString("#DCE7F3"), (Color)ColorConverter.ConvertFromString("#B9CBE0"), 65);
        g.Freeze();
        return g;
    }

    public static FrameworkElement Build(ToastDesign d, string folder, bool dark, string appName, string appIcon)
    {
        var p = dark ? Dark : Light;
        string T(string s) => Placeholders.Apply(s, d.Samples);
        string Img(string s) => s == "" ? "" : DesignPaths.Resolve(folder, T(s));

        var stack = new StackPanel();

        // ---- hero: Windows 11 runs it edge to edge across the very top, above the header
        if (d.Hero != "")
        {
            var heroSrc = LoadImage(Img(d.Hero));
            stack.Children.Add(heroSrc != null
                ? new Border { Height = W / 2, CornerRadius = new CornerRadius(7, 7, 0, 0), Background = new ImageBrush(heroSrc) { Stretch = Stretch.UniformToFill } }
                : Picture("", W - 2, W / 2, 0, false, new Thickness(0), dark));
        }

        // ---- header: app icon + name, "..." and close
        var head = new DockPanel { Margin = new Thickness(Pad, 10, 8, 0), LastChildFill = true };
        var close = Glyph("", 10, p.Tertiary);
        close.Margin = new Thickness(14, 0, 4, 0);
        DockPanel.SetDock(close, Dock.Right);
        head.Children.Add(close);
        var more = Glyph("", 12, p.Tertiary);
        DockPanel.SetDock(more, Dock.Right);
        head.Children.Add(more);
        var icon = LoadImage(appIcon);
        FrameworkElement iconEl = icon != null
            ? new Image { Source = icon, Width = 16, Height = 16, Stretch = Stretch.Uniform }
            : new Border
            {
                Width = 16, Height = 16, CornerRadius = new CornerRadius(4), Background = B("#1F6FB2"),
                Child = Glyph("", 9, Brushes.White),
            };
        iconEl.Margin = new Thickness(0, 0, 8, 0);
        iconEl.VerticalAlignment = VerticalAlignment.Center;
        if (d.Scenario == "urgent")
        {
            // urgent: a red "!" ahead of the app's icon
            var bang = Text("!", 14, CriticalBtn, FontWeights.Bold, VerticalAlignment.Center, false);
            bang.Margin = new Thickness(0, 0, 7, 0);
            DockPanel.SetDock(bang, Dock.Left);
            head.Children.Add(bang);
        }
        DockPanel.SetDock(iconEl, Dock.Left);
        head.Children.Add(iconEl);
        head.Children.Add(Text(string.IsNullOrWhiteSpace(appName) ? "My Clarion App" : appName, 12, p.Secondary));
        stack.Children.Add(head);

        // ---- logo + text
        var body = new Grid { Margin = new Thickness(Pad, 12, Pad, 0) };
        body.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        if (d.AppLogo != "")
        {
            var logo = Picture(Img(d.AppLogo), 48, 48, d.LogoCircle ? 24 : 4, d.LogoCircle, new Thickness(0, 2, 12, 0), dark);
            logo.VerticalAlignment = VerticalAlignment.Top;
            body.Children.Add(logo);
        }
        var texts = new StackPanel();
        Grid.SetColumn(texts, 1);
        if (d.Title != "")
        {
            var t = Text(T(d.Title), 14, p.Primary, FontWeights.SemiBold);
            t.MaxHeight = 40;
            texts.Children.Add(t);
        }
        if (d.Line1 != "") texts.Children.Add(Text(T(d.Line1), 14, p.Secondary));
        if (d.Line2 != "") texts.Children.Add(Text(T(d.Line2), 14, p.Secondary));
        if (d.Attribution != "")
        {
            var a = Text(T(d.Attribution), 12, p.Tertiary);
            a.Margin = new Thickness(0, 3, 0, 0);
            texts.Children.Add(a);
        }
        body.Children.Add(texts);
        stack.Children.Add(body);

        // ---- inline picture
        if (d.Inline != "")
            stack.Children.Add(Picture(Img(d.Inline), Inner, Inner * 0.56, 4, false, new Thickness(Pad, 10, Pad, 0), dark));

        // ---- progress
        if (d.Progress.Enabled)
        {
            string ptitle, pval, ptext, pstatus;
            if (d.Progress.Live)
            {
                d.Samples.TryGetValue("progressTitle", out ptitle!);
                d.Samples.TryGetValue("progressValue", out pval!);
                d.Samples.TryGetValue("progressValueString", out ptext!);
                d.Samples.TryGetValue("progressStatus", out pstatus!);
                ptitle ??= ""; pval ??= "0.4"; ptext ??= ""; pstatus ??= "";
            }
            else
            {
                ptitle = T(d.Progress.Title); pval = T(d.Progress.Value); ptext = T(d.Progress.ValueText); pstatus = T(d.Progress.Status);
            }
            var pp = new StackPanel { Margin = new Thickness(Pad, 10, Pad, 0) };
            if (ptitle != "") pp.Children.Add(Text(ptitle, 12, p.Secondary));
            bool indet = pval.Trim() == "indeterminate";
            double v = double.TryParse(pval, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var x) ? Math.Clamp(x, 0, 1) : 0.3;
            var track = new Grid { Height = 4, Margin = new Thickness(0, 6, 0, 6) };
            track.Children.Add(new Border { Height = 1, Background = p.Track, VerticalAlignment = VerticalAlignment.Center, CornerRadius = new CornerRadius(1) });
            track.Children.Add(new Border
            {
                Height = 4, CornerRadius = new CornerRadius(2), Background = p.Accent, HorizontalAlignment = HorizontalAlignment.Left,
                Width = indet ? Inner * 0.3 : Inner * v, Margin = new Thickness(indet ? Inner * 0.35 : 0, 0, 0, 0),
            });
            pp.Children.Add(track);
            var row = new DockPanel();
            var right = Text(ptext != "" ? ptext : (indet ? "" : $"{v:P0}"), 12, p.Secondary);
            DockPanel.SetDock(right, Dock.Right);
            row.Children.Add(right);
            row.Children.Add(Text(pstatus, 12, p.Secondary));
            pp.Children.Add(row);
            stack.Children.Add(pp);
        }

        // ---- inputs (a button with hint-inputId sits beside its box)
        foreach (var i in d.Inputs)
        {
            var box = new StackPanel { Margin = new Thickness(Pad, 10, Pad, 0) };
            if (i.Title != "") { var tt = Text(T(i.Title), 12, p.Secondary); tt.Margin = new Thickness(0, 0, 0, 4); box.Children.Add(tt); }
            var field = new Border
            {
                Height = 32, CornerRadius = new CornerRadius(4), Background = p.Input, BorderBrush = p.InputBorder,
                BorderThickness = new Thickness(1, 1, 1, i.Kind == InputKind.Text ? 1.5 : 1), Padding = new Thickness(10, 0, 8, 0),
            };
            if (i.Kind == InputKind.Text)
                field.Child = Text(i.Placeholder != "" ? T(i.Placeholder) : " ", 13, p.Tertiary, v: VerticalAlignment.Center);
            else
            {
                var sel = i.Choices.FirstOrDefault(c => c.Id == i.Default) ?? i.Choices.FirstOrDefault();
                var dp = new DockPanel();
                var chev = Glyph("", 10, p.Secondary);
                DockPanel.SetDock(chev, Dock.Right);
                dp.Children.Add(chev);
                dp.Children.Add(Text(sel != null ? T(sel.Content) : "", 13, p.Primary, v: VerticalAlignment.Center));
                field.Child = dp;
            }
            var beside = d.Buttons.FirstOrDefault(b => b.InputId == i.Id && b.Kind == ButtonKind.Foreground);
            if (beside != null && i.Kind == InputKind.Text)
            {
                var g = new Grid();
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                g.Children.Add(field);
                var bimg = LoadImage(Img(beside.Image));
                var send = new Border
                {
                    Width = 32, Height = 32, Margin = new Thickness(6, 0, 0, 0), CornerRadius = new CornerRadius(4),
                    Background = beside.Style == ButtonStyle.Success ? SuccessBtn : beside.Style == ButtonStyle.Critical ? CriticalBtn : p.Button,
                    BorderBrush = p.ButtonBorder, BorderThickness = new Thickness(beside.Style == ButtonStyle.Default ? 1 : 0),
                    Child = bimg != null
                        ? new Image { Source = bimg, Width = 16, Height = 16 }
                        : Glyph("", 13, beside.Style == ButtonStyle.Default ? p.Primary : Brushes.White),
                    ToolTip = T(beside.Content),
                };
                Grid.SetColumn(send, 1);
                g.Children.Add(send);
                box.Children.Add(g);
            }
            else box.Children.Add(field);
            stack.Children.Add(box);
        }

        // ---- buttons
        var row2 = d.Buttons.Where(b => !(b.Kind == ButtonKind.Foreground && b.InputId != "" && d.Inputs.Any(i => i.Id == b.InputId && i.Kind == InputKind.Text))).ToList();
        if (row2.Count > 0)
        {
            var ug = new UniformGrid { Rows = 1, Columns = row2.Count, Margin = new Thickness(Pad - 3, 12, Pad - 3, 0) };
            foreach (var b in row2)
            {
                string cap = b.Kind switch
                {
                    ButtonKind.Snooze => b.Content != "" ? T(b.Content) : "Snooze",
                    ButtonKind.Dismiss => b.Content != "" ? T(b.Content) : "Dismiss",
                    _ => T(b.Content),
                };
                bool styled = b.Style != ButtonStyle.Default;
                var content = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
                var bimg = LoadImage(Img(b.Image));
                if (bimg != null) content.Children.Add(new Image { Source = bimg, Width = 16, Height = 16, Margin = new Thickness(0, 0, 6, 0) });
                content.Children.Add(Text(cap, 13, styled ? Brushes.White : p.Primary, v: VerticalAlignment.Center, wrap: false));
                ug.Children.Add(new Border
                {
                    Height = 32, Margin = new Thickness(3, 0, 3, 0), CornerRadius = new CornerRadius(4),
                    Background = b.Style == ButtonStyle.Success ? SuccessBtn : b.Style == ButtonStyle.Critical ? CriticalBtn : p.Button,
                    BorderBrush = p.ButtonBorder, BorderThickness = new Thickness(styled ? 0 : 1),
                    Child = content,
                    ToolTip = b.Kind == ButtonKind.Protocol ? "Opens " + T(b.Arguments) : b.Kind == ButtonKind.Foreground ? "Sends: " + T(b.Arguments) : null,
                });
            }
            stack.Children.Add(ug);
        }
        stack.Children.Add(new Border { Height = Pad });

        return new Border
        {
            Width = W,
            CornerRadius = new CornerRadius(8),
            Background = p.Card,
            BorderBrush = p.Border,
            BorderThickness = new Thickness(1),
            Child = stack,
            Effect = new DropShadowEffect { BlurRadius = 28, ShadowDepth = 6, Direction = 270, Opacity = dark ? 0.55 : 0.22 },
            SnapsToDevicePixels = true,
        };
    }

    static TextBlock Text(string s, double size, Brush fg, FontWeight? w = null, VerticalAlignment v = VerticalAlignment.Top, bool wrap = true) => new()
    {
        Text = s,
        FontFamily = Ui,
        FontSize = size,
        Foreground = fg,
        FontWeight = w ?? FontWeights.Normal,
        TextWrapping = wrap ? TextWrapping.Wrap : TextWrapping.NoWrap,
        TextTrimming = TextTrimming.CharacterEllipsis,
        VerticalAlignment = v,
    };

    static TextBlock Glyph(string g, double size, Brush fg) => new()
    {
        Text = g, FontFamily = Icons, FontSize = size, Foreground = fg,
        VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center,
    };

    static FrameworkElement Picture(string path, double w, double h, double radius, bool circle, Thickness margin, bool dark)
    {
        var src = LoadImage(path);
        if (src == null)
        {
            // what Windows does is show nothing; the designer shows where it would go
            var ph = new Border
            {
                Width = w, Height = h, Margin = margin, CornerRadius = new CornerRadius(radius),
                Background = dark ? B("#3A3A3A") : B("#E4E8ED"),
                BorderBrush = dark ? B("#555555") : B("#C4CCD6"), BorderThickness = new Thickness(1),
                HorizontalAlignment = HorizontalAlignment.Left,
                ToolTip = path == "" ? "No picture" : "Not found: " + path,
                Child = Glyph("", Math.Min(22, h / 2.4), dark ? B("#8A8A8A") : B("#8A95A3")),
            };
            return ph;
        }
        if (circle)
            return new Ellipse { Width = w, Height = h, Margin = margin, Fill = new ImageBrush(src) { Stretch = Stretch.UniformToFill } };
        return new Border
        {
            Width = w, Height = h, Margin = margin, CornerRadius = new CornerRadius(radius), HorizontalAlignment = HorizontalAlignment.Left,
            Background = new ImageBrush(src) { Stretch = Stretch.UniformToFill },
        };
    }

    public static BitmapSource? LoadImage(string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return null;
        try
        {
            Uri uri;
            if (path.Contains("://")) uri = new Uri(path);
            else if (File.Exists(path)) uri = new Uri(System.IO.Path.GetFullPath(path));
            else return null;
            var bi = new BitmapImage();
            bi.BeginInit();
            bi.CacheOption = BitmapCacheOption.OnLoad;
            bi.CreateOptions = BitmapCreateOptions.IgnoreImageCache;
            bi.UriSource = uri;
            bi.EndInit();
            bi.Freeze();
            return bi;
        }
        catch
        {
            return null;
        }
    }
}
