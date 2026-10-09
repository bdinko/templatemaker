namespace NotificationDesigner.Model;

/// <summary>What a button does when it is pressed.</summary>
public enum ButtonKind
{
    /// <summary>Hands <see cref="ToastButton.Arguments"/> to the program (Notifier.NextEvent).</summary>
    Foreground,
    /// <summary>Opens <see cref="ToastButton.Arguments"/> as an address (https:, mailto:, ...).</summary>
    Protocol,
    /// <summary>Windows' own snooze; with a selection input, the user picks how long.</summary>
    Snooze,
    /// <summary>Windows' own dismiss.</summary>
    Dismiss,
}

public enum ButtonStyle { Default, Success, Critical }

public enum InputKind { Text, Selection }

public sealed class ToastButton
{
    public string Content { get; set; } = "";
    public string Arguments { get; set; } = "";
    public ButtonKind Kind { get; set; }
    public ButtonStyle Style { get; set; }
    public string Image { get; set; } = "";
    /// <summary>Put the button beside this text box (a "Send" next to a reply box).</summary>
    public string InputId { get; set; } = "";
}

public sealed class ToastChoice
{
    public string Id { get; set; } = "";
    public string Content { get; set; } = "";
}

public sealed class ToastInput
{
    public string Id { get; set; } = "";
    public InputKind Kind { get; set; }
    public string Title { get; set; } = "";
    public string Placeholder { get; set; } = "";
    /// <summary>The id of the choice selected at first (selection inputs).</summary>
    public string Default { get; set; } = "";
    public List<ToastChoice> Choices { get; } = new();
}

public sealed class ToastProgress
{
    public bool Enabled { get; set; }
    /// <summary>Bind to {progressTitle}/{progressValue}/... so the program can move the bar.</summary>
    public bool Live { get; set; }
    public string Title { get; set; } = "";
    /// <summary>0 to 1, "indeterminate", or a {placeholder}.</summary>
    public string Value { get; set; } = "0.5";
    public string ValueText { get; set; } = "";
    public string Status { get; set; } = "";
}

/// <summary>
/// One notification. Maps one-to-one onto the Windows "ToastGeneric" XML that
/// <see cref="ToastXml"/> reads and writes, so the saved .ntf file is the very
/// XML the Clarion program hands to Windows.
/// </summary>
public sealed class ToastDesign
{
    public string Launch { get; set; } = "";
    /// <summary>default, reminder, alarm, incomingCall or urgent.</summary>
    public string Scenario { get; set; } = "default";
    public bool LongDuration { get; set; }

    public string Title { get; set; } = "";
    public string Line1 { get; set; } = "";
    public string Line2 { get; set; } = "";
    public string Attribution { get; set; } = "";

    public string AppLogo { get; set; } = "";
    public bool LogoCircle { get; set; } = true;
    public string Hero { get; set; } = "";
    public string Inline { get; set; } = "";

    public ToastProgress Progress { get; } = new();
    public List<ToastInput> Inputs { get; } = new();
    public List<ToastButton> Buttons { get; } = new();

    /// <summary>'' = the Windows default sound.</summary>
    public string Sound { get; set; } = "";
    public bool SoundLoop { get; set; }
    public bool Silent { get; set; }

    /// <summary>Sample values for {placeholders}: the preview and "Show on Windows" use them.</summary>
    public Dictionary<string, string> Samples { get; } = new(StringComparer.OrdinalIgnoreCase);

    public static readonly string[] Scenarios = { "default", "reminder", "alarm", "incomingCall", "urgent" };

    /// <summary>The sounds Windows has for notifications (ms-winsoundevent:...).</summary>
    public static readonly string[] Sounds =
    {
        "",
        "ms-winsoundevent:Notification.Default",
        "ms-winsoundevent:Notification.IM",
        "ms-winsoundevent:Notification.Mail",
        "ms-winsoundevent:Notification.Reminder",
        "ms-winsoundevent:Notification.SMS",
        "ms-winsoundevent:Notification.Looping.Alarm",
        "ms-winsoundevent:Notification.Looping.Alarm2",
        "ms-winsoundevent:Notification.Looping.Alarm3",
        "ms-winsoundevent:Notification.Looping.Alarm4",
        "ms-winsoundevent:Notification.Looping.Alarm5",
        "ms-winsoundevent:Notification.Looping.Alarm6",
        "ms-winsoundevent:Notification.Looping.Alarm7",
        "ms-winsoundevent:Notification.Looping.Alarm8",
        "ms-winsoundevent:Notification.Looping.Alarm9",
        "ms-winsoundevent:Notification.Looping.Alarm10",
        "ms-winsoundevent:Notification.Looping.Call",
        "ms-winsoundevent:Notification.Looping.Call2",
        "ms-winsoundevent:Notification.Looping.Call3",
        "ms-winsoundevent:Notification.Looping.Call4",
        "ms-winsoundevent:Notification.Looping.Call5",
        "ms-winsoundevent:Notification.Looping.Call6",
        "ms-winsoundevent:Notification.Looping.Call7",
        "ms-winsoundevent:Notification.Looping.Call8",
        "ms-winsoundevent:Notification.Looping.Call9",
        "ms-winsoundevent:Notification.Looping.Call10",
    };
}
