using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace NotificationDesigner;

public partial class App : Application
{
    /// <summary>
    /// NotificationDesigner.exe [design.ntf]  - the template's Design button passes the file.
    /// Screenshot mode, for the documentation:
    ///   --shot=out.png [--section=Buttons] [--tab=0|1|2] [--dark|--light]
    ///   --toast   sends the design to Windows (as Show on Windows does) and exits
    /// opens, renders the window to a PNG and exits without touching the file.
    /// </summary>
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        ShutdownMode = ShutdownMode.OnMainWindowClose;
        string? file = e.Args.FirstOrDefault(a => !a.StartsWith("--"));
        string? Opt(string name) => e.Args.FirstOrDefault(a => a.StartsWith("--" + name + "="))?.Split('=', 2)[1];
        bool Flag(string name) => e.Args.Contains("--" + name);

        string? export = Opt("export-presets");
        if (export != null)
        {
            Directory.CreateDirectory(export);
            foreach (var p in Model.Presets.All)
            {
                string name = new string(p.Name.ToLowerInvariant().Select(c => char.IsLetterOrDigit(c) ? c : '-').ToArray()) + ".ntf";
                File.WriteAllText(Path.Combine(export, name), Model.ToastXml.Write(p.Make()));
            }
            Shutdown();
            return;
        }

        if (Flag("toast") && file != null)
        {
            // NotificationDesigner.exe design.ntf --toast : send it to Windows and quit (scripts, tests)
            var st = DesignerSettings.Load();
            var design = Model.ToastXml.Read(File.ReadAllText(file));
            WindowsToast.Show(design, Path.GetDirectoryName(Path.GetFullPath(file))!, st.PreviewAppName, st.PreviewAppIcon, _ => { });
            Thread.Sleep(1500);
            Shutdown();
            return;
        }

        var w = new MainWindow(file);
        MainWindow = w;
        string? shot = Opt("shot");
        if (shot != null)
        {
            w.PrepareShot(Opt("section"), int.TryParse(Opt("tab"), out int t) ? t : 0, Flag("dark") ? true : Flag("light") ? false : null);
            w.ContentRendered += async (_, _) =>
            {
                await Task.Delay(700);
                var src = PresentationSource.FromVisual(w);
                double sx = src?.CompositionTarget?.TransformToDevice.M11 ?? 1, sy = src?.CompositionTarget?.TransformToDevice.M22 ?? 1;
                var root = (FrameworkElement)w.Content;
                var rtb = new RenderTargetBitmap((int)(root.ActualWidth * sx), (int)(root.ActualHeight * sy), 96 * sx, 96 * sy, PixelFormats.Pbgra32);
                rtb.Render(root);
                var enc = new PngBitmapEncoder();
                enc.Frames.Add(BitmapFrame.Create(rtb));
                using (var fs = File.Create(shot)) enc.Save(fs);
                w.ForceClose();
            };
        }
        w.Show();
    }
}
