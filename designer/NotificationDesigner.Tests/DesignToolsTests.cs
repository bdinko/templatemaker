using NotificationDesigner.Model;
using Xunit;

namespace NotificationDesigner.Tests;

public class PlaceholderTests
{
    [Fact]
    public void Finds_each_placeholder_once_in_order_of_appearance()
    {
        var d = new ToastDesign { Launch = "id={InvoiceNo}", Title = "Invoice {InvoiceNo}", Line1 = "{Customer} paid {Amount}", AppLogo = @"logos\{Customer}.png" };
        d.Buttons.Add(new ToastButton { Content = "Open {InvoiceNo}", Arguments = "x" });
        Assert.Equal(new[] { "InvoiceNo", "Customer", "Amount" }, Placeholders.Find(d));
    }

    [Fact]
    public void Ignores_the_live_progress_bindings_and_non_names()
    {
        var d = new ToastDesign { Title = "Copy {File}", Line1 = "{ not a name } {} {9lives} {a-b}" };
        d.Progress.Enabled = true;
        d.Progress.Live = true;
        Assert.Equal(new[] { "File" }, Placeholders.Find(d));
    }

    [Fact]
    public void Apply_fills_known_names_case_insensitively_and_leaves_the_rest()
    {
        var v = new Dictionary<string, string> { ["customer"] = "Acme", ["Amount"] = "$5" };
        Assert.Equal("Acme paid $5 for {Other}", Placeholders.Apply("{Customer} paid {AMOUNT} for {Other}", v));
    }
}

public class ValidatorTests
{
    static bool Has(ToastDesign d, Severity s, string fragment) =>
        DesignValidator.Check(d).Any(i => i.Severity == s && i.Message.Contains(fragment, StringComparison.OrdinalIgnoreCase));

    [Fact]
    public void A_simple_design_is_clean()
    {
        Assert.Empty(DesignValidator.Check(new ToastDesign { Title = "Hi" }));
    }

    [Fact]
    public void Needs_a_title()
    {
        Assert.True(Has(new ToastDesign(), Severity.Error, "title"));
    }

    [Fact]
    public void At_most_five_buttons_and_five_inputs()
    {
        var d = new ToastDesign { Title = "x" };
        for (int i = 0; i < 6; i++) d.Buttons.Add(new ToastButton { Content = "b" + i, Arguments = "a" });
        for (int i = 0; i < 6; i++) d.Inputs.Add(new ToastInput { Id = "i" + i });
        Assert.True(Has(d, Severity.Error, "5 buttons"));
        Assert.True(Has(d, Severity.Error, "5 inputs"));
    }

    [Fact]
    public void A_button_needs_a_caption_except_system_ones()
    {
        var d = new ToastDesign { Title = "x" };
        d.Buttons.Add(new ToastButton { Content = "", Arguments = "a" });
        d.Buttons.Add(new ToastButton { Kind = ButtonKind.Snooze });
        var issues = DesignValidator.Check(d);
        Assert.Single(issues, i => i.Message.Contains("caption", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void A_reply_button_must_name_an_existing_input()
    {
        var d = new ToastDesign { Title = "x" };
        d.Buttons.Add(new ToastButton { Content = "Send", Arguments = "a", InputId = "reply" });
        Assert.True(Has(d, Severity.Error, "reply"));
        d.Inputs.Add(new ToastInput { Id = "reply" });
        Assert.False(Has(d, Severity.Error, "reply"));
    }

    [Fact]
    public void Input_ids_must_be_unique_and_present()
    {
        var d = new ToastDesign { Title = "x" };
        d.Inputs.Add(new ToastInput { Id = "a" });
        d.Inputs.Add(new ToastInput { Id = "a" });
        d.Inputs.Add(new ToastInput { Id = "" });
        Assert.True(Has(d, Severity.Error, "twice"));
        Assert.True(Has(d, Severity.Error, "needs an id"));
    }

    [Fact]
    public void A_snooze_button_without_a_selection_warns()
    {
        var d = new ToastDesign { Title = "x", Scenario = "reminder" };
        d.Buttons.Add(new ToastButton { Kind = ButtonKind.Snooze });
        Assert.True(Has(d, Severity.Warning, "snooze"));
    }

    [Fact]
    public void Reminder_without_buttons_warns()
    {
        Assert.True(Has(new ToastDesign { Title = "x", Scenario = "reminder" }, Severity.Warning, "button"));
    }

    [Fact]
    public void A_protocol_button_needs_a_uri()
    {
        var d = new ToastDesign { Title = "x" };
        d.Buttons.Add(new ToastButton { Content = "Web", Kind = ButtonKind.Protocol, Arguments = "not a url" });
        Assert.True(Has(d, Severity.Error, "address"));
    }
}

public class PathTests
{
    [Fact]
    public void Makes_paths_inside_the_design_folder_relative()
    {
        Assert.Equal(@"images\logo.png", DesignPaths.MakeRelative(@"C:\app\designs", @"C:\app\designs\images\logo.png"));
        Assert.Equal(@"D:\other\logo.png", DesignPaths.MakeRelative(@"C:\app\designs", @"D:\other\logo.png"));
        Assert.Equal(@"logo.png", DesignPaths.MakeRelative(@"C:\app\designs\", @"c:\APP\designs\logo.png"));
    }

    [Fact]
    public void Resolves_relative_paths_against_the_design_folder()
    {
        Assert.Equal(@"C:\app\designs\images\logo.png", DesignPaths.Resolve(@"C:\app\designs", @"images\logo.png"));
        Assert.Equal(@"D:\x.png", DesignPaths.Resolve(@"C:\app", @"D:\x.png"));
        Assert.Equal("https://x/y.png", DesignPaths.Resolve(@"C:\app", "https://x/y.png"));
        Assert.Equal("", DesignPaths.Resolve(@"C:\app", ""));
    }

    [Fact]
    public void File_uri_for_windows()
    {
        Assert.Equal("file:///C:/a%20b/x.png", DesignPaths.ToUri(@"C:\a b\x.png"));
        Assert.Equal("https://x/y.png", DesignPaths.ToUri("https://x/y.png"));
    }
}

public class PresetTests
{
    [Fact]
    public void Every_preset_is_valid_and_round_trips()
    {
        Assert.True(Presets.All.Count >= 6);
        foreach (var p in Presets.All)
        {
            var d = p.Make();
            Assert.DoesNotContain(DesignValidator.Check(d), i => i.Severity == Severity.Error);
            Assert.Equal(ToastXml.Write(d), ToastXml.Write(ToastXml.Read(ToastXml.Write(d))));
        }
    }
}

public class ShowOnWindowsTests
{
    [Fact]
    public void Prepared_xml_has_samples_filled_pictures_as_uris_and_no_comments()
    {
        var d = new ToastDesign { Title = "Hi {Name} & co", AppLogo = @"images\{Name}.png", Launch = "id={Id}" };
        d.Buttons.Add(new ToastButton { Content = "Open {Id}", Arguments = "action=open;id={Id}" });
        d.Samples["Name"] = "Ana";
        d.Samples["Id"] = "7";
        string x = NotificationDesigner.WindowsToast.PrepareXml(d, @"C:\designs");
        Assert.DoesNotContain("<!--", x);
        Assert.Contains("<text hint-maxLines=\"2\">Hi Ana &amp; co</text>", x);
        Assert.Contains("src=\"file:///C:/designs/images/Ana.png\"", x);
        Assert.Contains("launch=\"id=7\"", x);
        Assert.Contains("<action content=\"Open 7\" arguments=\"action=open;id=7\"/>", x);
        Assert.Equal("Hi {Name} & co", d.Title);          // the design itself is untouched
    }

    [Fact]
    public void Live_progress_bindings_survive_preparation()
    {
        var d = new ToastDesign { Title = "Copy" };
        d.Progress.Enabled = true;
        d.Progress.Live = true;
        Assert.Contains("value=\"{progressValue}\"", NotificationDesigner.WindowsToast.PrepareXml(d, @"C:\x"));
    }
}
