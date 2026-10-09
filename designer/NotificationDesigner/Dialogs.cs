using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using NotificationDesigner.Model;

namespace NotificationDesigner;

public enum DialogKind { Info, Success, Warning, Error, Question }

/// <summary>
/// The designer's modal pop-ups - every message goes through here, never a
/// system MessageBox. A borderless window with a soft shadow, centred on its
/// owner, Enter = the default button, Esc = cancel.
/// </summary>
public static class Dialogs
{
    static Brush R(string key) => (Brush)Application.Current.Resources[key];

    static (Window win, StackPanel body, StackPanel buttons) Frame(Window? owner, string title, DialogKind kind, double width = 460)
    {
        var win = new Window
        {
            Owner = owner,
            WindowStyle = WindowStyle.None,
            AllowsTransparency = true,
            Background = Brushes.Transparent,
            ResizeMode = ResizeMode.NoResize,
            SizeToContent = SizeToContent.Height,
            Width = width + 40,
            ShowInTaskbar = owner == null,
            WindowStartupLocation = owner != null ? WindowStartupLocation.CenterOwner : WindowStartupLocation.CenterScreen,
            FontFamily = (FontFamily)Application.Current.Resources["Ui"],
            Title = title,
        };
        var (glyph, fg, bg) = kind switch
        {
            DialogKind.Success => ("", R("Success"), R("SuccessSoft")),
            DialogKind.Warning => ("", R("Warn"), R("WarnSoft")),
            DialogKind.Error => ("", R("Danger"), R("DangerSoft")),
            DialogKind.Question => ("", R("Accent"), R("AccentSoft")),
            _ => ("", R("Accent"), R("AccentSoft")),
        };
        var head = new DockPanel { Margin = new Thickness(0, 0, 0, 12) };
        var badge = new Border
        {
            Width = 36, Height = 36, CornerRadius = new CornerRadius(18), Background = bg, Margin = new Thickness(0, 0, 14, 0),
            Child = new TextBlock
            {
                Text = glyph, FontFamily = (FontFamily)Application.Current.Resources["Icons"], FontSize = 16, Foreground = fg,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
            },
        };
        DockPanel.SetDock(badge, Dock.Left);
        head.Children.Add(badge);
        head.Children.Add(new TextBlock
        {
            Text = title, FontSize = 17, FontWeight = FontWeights.SemiBold, Foreground = R("Ink"),
            VerticalAlignment = VerticalAlignment.Center, TextWrapping = TextWrapping.Wrap,
        });
        var body = new StackPanel();
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 22, 0, 0) };
        var all = new StackPanel();
        all.Children.Add(head);
        all.Children.Add(body);
        all.Children.Add(buttons);
        var card = new Border
        {
            Margin = new Thickness(20),
            Background = Brushes.White,
            CornerRadius = new CornerRadius(12),
            BorderBrush = R("Line"),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(24, 22, 24, 20),
            Child = all,
            Effect = new DropShadowEffect { BlurRadius = 30, ShadowDepth = 8, Direction = 270, Opacity = 0.28 },
        };
        card.MouseLeftButtonDown += (_, e) => { if (e.ButtonState == MouseButtonState.Pressed) try { win.DragMove(); } catch { } };
        win.Content = card;
        return (win, body, buttons);
    }

    static TextBlock Para(string s) => new()
    {
        Text = s, TextWrapping = TextWrapping.Wrap, FontSize = 13.5, LineHeight = 20, Foreground = R("Muted"), Margin = new Thickness(50, 0, 0, 0),
    };

    static Button Btn(string text, Style? style, bool isDefault = false, bool isCancel = false) => new()
    {
        Content = text, Style = style, IsDefault = isDefault, IsCancel = isCancel, MinWidth = 92, Margin = new Thickness(8, 0, 0, 0),
    };

    public static void Show(Window? owner, string title, string message, DialogKind kind = DialogKind.Info)
    {
        var (win, body, buttons) = Frame(owner, title, kind);
        body.Children.Add(Para(message));
        var ok = Btn("OK", (Style)Application.Current.Resources["Primary"], true, true);
        ok.Click += (_, _) => win.Close();
        buttons.Children.Add(ok);
        win.ShowDialog();
    }

    /// <summary>Returns the index of the button pressed; Esc / close returns the last one.</summary>
    public static int Ask(Window? owner, string title, string message, DialogKind kind, params string[] choices)
    {
        var (win, body, buttons) = Frame(owner, title, kind);
        body.Children.Add(Para(message));
        int result = choices.Length - 1;
        for (int n = 0; n < choices.Length; n++)
        {
            int k = n;
            var b = Btn(choices[n], n == 0 ? (Style)Application.Current.Resources["Primary"] : null, n == 0, n == choices.Length - 1);
            b.Click += (_, _) => { result = k; win.Close(); };
            buttons.Children.Add(b);
        }
        win.ShowDialog();
        return result;
    }

    /// <summary>File > New: a gallery of starting points.</summary>
    public static Preset? PickPreset(Window? owner)
    {
        var (win, body, buttons) = Frame(owner, "Start a new notification", DialogKind.Question, 620);
        Preset? picked = null;
        body.Children.Add(new TextBlock
        {
            Text = "Pick a starting point. Everything can be changed afterwards.",
            Foreground = R("Muted"), FontSize = 13.5, Margin = new Thickness(50, 0, 0, 14),
        });
        var grid = new System.Windows.Controls.Primitives.UniformGrid { Columns = 2 };
        var blank = new Preset("Blank", "Just a title - build it up yourself.", () => new ToastDesign { Title = "New notification" });
        foreach (var p in new[] { blank }.Concat(Presets.All))
        {
            var card = new Border
            {
                Margin = new Thickness(5), Padding = new Thickness(14, 11, 14, 12), CornerRadius = new CornerRadius(8),
                BorderBrush = R("Line"), BorderThickness = new Thickness(1), Background = Brushes.White, Cursor = Cursors.Hand,
            };
            var sp = new StackPanel();
            sp.Children.Add(new TextBlock { Text = p.Name, FontWeight = FontWeights.SemiBold, FontSize = 13.5, Foreground = R("Ink") });
            sp.Children.Add(new TextBlock { Text = p.Description, TextWrapping = TextWrapping.Wrap, FontSize = 12.5, Foreground = R("Muted"), Margin = new Thickness(0, 3, 0, 0) });
            card.Child = sp;
            card.MouseEnter += (_, _) => { card.BorderBrush = R("Accent"); card.Background = R("AccentSoft"); };
            card.MouseLeave += (_, _) => { card.BorderBrush = R("Line"); card.Background = Brushes.White; };
            var pp = p;
            card.MouseLeftButtonUp += (_, _) => { picked = pp; win.Close(); };
            grid.Children.Add(card);
        }
        body.Children.Add(grid);
        var cancel = Btn("Cancel", null, false, true);
        cancel.Click += (_, _) => win.Close();
        buttons.Children.Add(cancel);
        win.ShowDialog();
        return picked;
    }
}
