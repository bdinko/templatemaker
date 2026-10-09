namespace NotificationDesigner.Model;

public sealed record Preset(string Name, string Description, Func<ToastDesign> Make);

/// <summary>Starting points for File > New. Images point at the sample set in images\.</summary>
public static class Presets
{
    public static IReadOnlyList<Preset> All { get; } = new List<Preset>
    {
        new("Simple message", "A title and a line of text. The everyday notification.", () =>
        {
            var d = new ToastDesign { Title = "Backup finished", Line1 = "{Files} files copied to {Target}.", Launch = "action=open" };
            d.Samples["Files"] = "1,284";
            d.Samples["Target"] = "the NAS";
            return d;
        }),

        new("Invoice paid", "Logo, two lines, attribution and two buttons that report back to the program.", () =>
        {
            var d = new ToastDesign
            {
                Launch = "action=open;invoice={InvoiceNo}",
                Title = "Invoice {InvoiceNo} has been paid",
                Line1 = "{Customer} paid {Amount}.",
                Attribution = "Accounts receivable",
                AppLogo = @"images\logo.png",
                LogoCircle = false,
                Sound = "ms-winsoundevent:Notification.Mail",
            };
            d.Buttons.Add(new ToastButton { Content = "Open invoice", Arguments = "action=open;invoice={InvoiceNo}" });
            d.Buttons.Add(new ToastButton { Content = "Send receipt", Arguments = "action=receipt;invoice={InvoiceNo}" });
            d.Samples["InvoiceNo"] = "1043";
            d.Samples["Customer"] = "Acme Ltd";
            d.Samples["Amount"] = "$1,250.00";
            return d;
        }),

        new("Chat reply", "Round avatar, a reply box and a Send button beside it.", () =>
        {
            var d = new ToastDesign
            {
                Launch = "action=chat;from={From}",
                Title = "{From}",
                Line1 = "{Message}",
                AppLogo = @"images\avatar.png",
                LogoCircle = true,
                Sound = "ms-winsoundevent:Notification.IM",
            };
            d.Inputs.Add(new ToastInput { Id = "reply", Kind = InputKind.Text, Placeholder = "Type a reply" });
            d.Buttons.Add(new ToastButton { Content = "Send", Arguments = "action=reply;from={From}", InputId = "reply", Style = ButtonStyle.Success });
            d.Samples["From"] = "Ana Torres";
            d.Samples["Message"] = "Can you approve the March figures before 5?";
            return d;
        }),

        new("Reminder with snooze", "Stays on screen until dealt with; the user picks the snooze time.", () =>
        {
            var d = new ToastDesign
            {
                Scenario = "reminder",
                Launch = "action=appointment;id={Id}",
                Title = "{Subject}",
                Line1 = "{When} - {Where}",
                AppLogo = @"images\calendar.png",
                LogoCircle = false,
            };
            var s = new ToastInput { Id = "snoozeTime", Kind = InputKind.Selection, Default = "15" };
            s.Choices.Add(new ToastChoice { Id = "5", Content = "5 minutes" });
            s.Choices.Add(new ToastChoice { Id = "15", Content = "15 minutes" });
            s.Choices.Add(new ToastChoice { Id = "60", Content = "1 hour" });
            d.Inputs.Add(s);
            d.Buttons.Add(new ToastButton { Kind = ButtonKind.Snooze, InputId = "snoozeTime" });
            d.Buttons.Add(new ToastButton { Kind = ButtonKind.Dismiss });
            d.Samples["Id"] = "77";
            d.Samples["Subject"] = "Quarterly review";
            d.Samples["When"] = "Today 15:00";
            d.Samples["Where"] = "Room 2";
            return d;
        }),

        new("Live progress", "A progress bar the program moves with Notifier.UpdateProgress().", () =>
        {
            var d = new ToastDesign { Title = "Exporting {Report}", AppLogo = @"images\logo.png", LogoCircle = false, Silent = true };
            d.Progress.Enabled = true;
            d.Progress.Live = true;
            d.Buttons.Add(new ToastButton { Content = "Cancel", Arguments = "action=cancel" });
            d.Samples["Report"] = "Sales 2026.xlsx";
            d.Samples["progressTitle"] = "Sales 2026.xlsx";
            d.Samples["progressValue"] = "0.62";
            d.Samples["progressValueString"] = "62%";
            d.Samples["progressStatus"] = "Writing sheets...";
            return d;
        }),

        new("Announcement", "A wide hero picture across the top - for news and promotions.", () =>
        {
            var d = new ToastDesign
            {
                Launch = "action=whatsnew",
                Hero = @"images\hero.png",
                Title = "Version {Version} is ready",
                Line1 = "Faster reports, dark mode and a new dashboard.",
                AppLogo = @"images\logo.png",
                LogoCircle = false,
            };
            d.Buttons.Add(new ToastButton { Content = "What's new", Arguments = "action=whatsnew" });
            d.Buttons.Add(new ToastButton { Content = "Release notes", Kind = ButtonKind.Protocol, Arguments = "https://example.com/release-notes" });
            d.Samples["Version"] = "4.2";
            return d;
        }),

        new("Urgent alert", "Breaks through Do Not Disturb (Windows 11), with a red action.", () =>
        {
            var d = new ToastDesign
            {
                Scenario = "urgent",
                Launch = "action=alert;id={AlertId}",
                Title = "Stock below minimum",
                Line1 = "{Item}: {Qty} left (minimum {Min}).",
                AppLogo = @"images\warning.png",
                LogoCircle = false,
                Sound = "ms-winsoundevent:Notification.Looping.Alarm2",
            };
            d.Buttons.Add(new ToastButton { Content = "Reorder now", Arguments = "action=reorder;id={AlertId}", Style = ButtonStyle.Critical });
            d.Buttons.Add(new ToastButton { Content = "Remind me later", Arguments = "action=later;id={AlertId}" });
            d.Samples["AlertId"] = "9";
            d.Samples["Item"] = "A4 paper";
            d.Samples["Qty"] = "3 boxes";
            d.Samples["Min"] = "10";
            return d;
        }),
    };
}
