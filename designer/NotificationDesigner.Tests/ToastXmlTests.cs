using NotificationDesigner.Model;
using Xunit;

namespace NotificationDesigner.Tests;

public class ToastXmlTests
{
    static ToastDesign Full()
    {
        var d = new ToastDesign
        {
            Launch = "action=open;id={InvoiceNo}",
            Scenario = "reminder",
            LongDuration = true,
            Title = "Invoice {InvoiceNo} paid",
            Line1 = "{Customer} paid {Amount}",
            Line2 = "Thank you & see you soon",
            Attribution = "via Accounts",
            AppLogo = @"images\logo.png",
            LogoCircle = false,
            Hero = @"images\hero.png",
            Inline = @"C:\pics\chart.png",
            Sound = "ms-winsoundevent:Notification.Reminder",
            SoundLoop = true,
        };
        d.Progress.Enabled = true;
        d.Progress.Title = "Upload";
        d.Progress.Value = "0.6";
        d.Progress.ValueText = "60%";
        d.Progress.Status = "Uploading...";
        d.Inputs.Add(new ToastInput { Id = "reply", Kind = InputKind.Text, Placeholder = "Type a reply", Title = "Reply" });
        var sel = new ToastInput { Id = "when", Kind = InputKind.Selection, Default = "h1", Title = "Remind me" };
        sel.Choices.Add(new ToastChoice { Id = "m15", Content = "15 minutes" });
        sel.Choices.Add(new ToastChoice { Id = "h1", Content = "1 hour" });
        d.Inputs.Add(sel);
        d.Buttons.Add(new ToastButton { Content = "Send", Arguments = "action=reply", InputId = "reply", Style = ButtonStyle.Success, Image = @"images\send.png" });
        d.Buttons.Add(new ToastButton { Content = "Website", Arguments = "https://example.com/?a=1&b=2", Kind = ButtonKind.Protocol });
        d.Buttons.Add(new ToastButton { Kind = ButtonKind.Snooze, InputId = "when" });
        d.Buttons.Add(new ToastButton { Kind = ButtonKind.Dismiss, Content = "Later" });
        d.Samples["Customer"] = "Acme Ltd";
        d.Samples["InvoiceNo"] = "1043";
        return d;
    }

    [Fact]
    public void Minimal_design_writes_the_exact_xml()
    {
        var d = new ToastDesign { Title = "Hello", Line1 = "World" };
        Assert.Equal(
            "<toast>\r\n" +
            "  <visual>\r\n" +
            "    <binding template=\"ToastGeneric\">\r\n" +
            "      <text hint-maxLines=\"2\">Hello</text>\r\n" +
            "      <text>World</text>\r\n" +
            "    </binding>\r\n" +
            "  </visual>\r\n" +
            "</toast>\r\n",
            ToastXml.Write(d));
    }

    [Fact]
    public void Full_design_writes_every_part_in_schema_order()
    {
        string x = ToastXml.Write(Full());
        string[] lines = x.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal("<!--sample:Customer=Acme Ltd-->", lines[0]);
        Assert.Equal("<!--sample:InvoiceNo=1043-->", lines[1]);
        Assert.Equal("<toast launch=\"action=open;id={InvoiceNo}\" scenario=\"reminder\" duration=\"long\" useButtonStyle=\"true\">", lines[2]);
        Assert.Contains("      <image placement=\"hero\" src=\"images\\hero.png\"/>", lines);
        Assert.Contains("      <image placement=\"appLogoOverride\" src=\"images\\logo.png\"/>", lines);
        Assert.Contains("      <text>Thank you &amp; see you soon</text>", lines);
        Assert.Contains("      <progress title=\"Upload\" value=\"0.6\" valueStringOverride=\"60%\" status=\"Uploading...\"/>", lines);
        Assert.Contains("      <text placement=\"attribution\">via Accounts</text>", lines);
        Assert.Contains("    <input id=\"reply\" type=\"text\" title=\"Reply\" placeHolderContent=\"Type a reply\"/>", lines);
        Assert.Contains("    <input id=\"when\" type=\"selection\" title=\"Remind me\" defaultInput=\"h1\">", lines);
        Assert.Contains("      <selection id=\"m15\" content=\"15 minutes\"/>", lines);
        Assert.Contains("    <action content=\"Send\" arguments=\"action=reply\" imageUri=\"images\\send.png\" hint-inputId=\"reply\" hint-buttonStyle=\"Success\"/>", lines);
        Assert.Contains("    <action content=\"Website\" activationType=\"protocol\" arguments=\"https://example.com/?a=1&amp;b=2\"/>", lines);
        Assert.Contains("    <action content=\"\" activationType=\"system\" arguments=\"snooze\" hint-inputId=\"when\"/>", lines);
        Assert.Contains("    <action content=\"Later\" activationType=\"system\" arguments=\"dismiss\"/>", lines);
        Assert.Contains("  <audio src=\"ms-winsoundevent:Notification.Reminder\" loop=\"true\"/>", lines);
        Assert.Equal("</toast>", lines[^1]);

        // the visual parts come in the order Windows lays them out
        int hero = Array.FindIndex(lines, l => l.Contains("placement=\"hero\""));
        int title = Array.FindIndex(lines, l => l.Contains("hint-maxLines"));
        int prog = Array.FindIndex(lines, l => l.Contains("<progress"));
        int attr = Array.FindIndex(lines, l => l.Contains("attribution"));
        Assert.True(hero < title && title < prog && prog < attr);
    }

    [Fact]
    public void Output_is_pure_ascii_and_accents_round_trip()
    {
        var d = new ToastDesign { Title = "Factura pagada \u2014 \u00e1\u00e9\u00ed\u00f3\u00fa \u00f1", Line1 = "\u20ac 1.250,00 \U0001F600" };
        d.Samples["Cliente"] = "Jos\u00e9";
        string x = ToastXml.Write(d);
        Assert.All(x, c => Assert.True(c < 128, $"non-ASCII char U+{(int)c:X4}"));
        Assert.Contains("&#225;", x);
        var back = ToastXml.Read(x);
        Assert.Equal(d.Title, back.Title);
        Assert.Equal(d.Line1, back.Line1);
        Assert.Equal("Jos\u00e9", back.Samples["Cliente"]);
    }

    [Fact]
    public void Full_design_round_trips()
    {
        var d = Full();
        var back = ToastXml.Read(ToastXml.Write(d));
        Assert.Equal(ToastXml.Write(d), ToastXml.Write(back));
        Assert.Equal("Invoice {InvoiceNo} paid", back.Title);
        Assert.False(back.LogoCircle);
        Assert.Equal("reminder", back.Scenario);
        Assert.True(back.LongDuration);
        Assert.True(back.Progress.Enabled);
        Assert.Equal("60%", back.Progress.ValueText);
        Assert.Equal(2, back.Inputs.Count);
        Assert.Equal(InputKind.Selection, back.Inputs[1].Kind);
        Assert.Equal("1 hour", back.Inputs[1].Choices[1].Content);
        Assert.Equal(4, back.Buttons.Count);
        Assert.Equal(ButtonKind.Protocol, back.Buttons[1].Kind);
        Assert.Equal("https://example.com/?a=1&b=2", back.Buttons[1].Arguments);
        Assert.Equal(ButtonKind.Snooze, back.Buttons[2].Kind);
        Assert.Equal("when", back.Buttons[2].InputId);
        Assert.Equal(ButtonStyle.Success, back.Buttons[0].Style);
        Assert.True(back.SoundLoop);
        Assert.Equal("Acme Ltd", back.Samples["Customer"]);
    }

    [Fact]
    public void Reads_what_the_Clarion_builder_writes()
    {
        // NotificationClass builder output: one line, circle logo, attribution, silent audio
        string x = "<toast launch=\"action=open\" scenario=\"urgent\"><visual><binding template=\"ToastGeneric\">" +
                   "<text hint-maxLines=\"2\">T</text><text>a</text><text placement=\"attribution\">via X</text>" +
                   "<image placement=\"appLogoOverride\" hint-crop=\"circle\" src=\"logo.png\"/><image src=\"in.png\"/>" +
                   "</binding></visual><actions><action content=\"Open\" arguments=\"action=open\"/></actions>" +
                   "<audio silent=\"true\"/></toast>";
        var d = ToastXml.Read(x);
        Assert.Equal("T", d.Title);
        Assert.Equal("a", d.Line1);
        Assert.Equal("", d.Line2);
        Assert.Equal("via X", d.Attribution);
        Assert.Equal("logo.png", d.AppLogo);
        Assert.True(d.LogoCircle);
        Assert.Equal("in.png", d.Inline);
        Assert.Equal("urgent", d.Scenario);
        Assert.True(d.Silent);
        Assert.Single(d.Buttons);
    }

    [Fact]
    public void Silent_wins_over_a_sound()
    {
        var d = new ToastDesign { Title = "x", Sound = "ms-winsoundevent:Notification.Mail", Silent = true };
        Assert.Contains("  <audio silent=\"true\"/>\r\n", ToastXml.Write(d));
    }

    [Fact]
    public void Read_rejects_something_that_is_not_a_toast()
    {
        Assert.Throws<FormatException>(() => ToastXml.Read("<tile><visual/></tile>"));
        Assert.Throws<FormatException>(() => ToastXml.Read("<toast><visual>"));
    }

    [Fact]
    public void Live_progress_writes_the_standard_bindings()
    {
        var d = new ToastDesign { Title = "Copying" };
        d.Progress.Enabled = true;
        d.Progress.Live = true;
        string x = ToastXml.Write(d);
        Assert.Contains("<progress title=\"{progressTitle}\" value=\"{progressValue}\" valueStringOverride=\"{progressValueString}\" status=\"{progressStatus}\"/>", x);
        Assert.True(ToastXml.Read(x).Progress.Live);
    }
}
