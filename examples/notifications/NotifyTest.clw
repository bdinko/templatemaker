! ============================================================================
!  NotifyTest - self-test for NotificationClass (no window).
!
!  Part 1 checks the XML the class builds, byte for byte: escaping, the
!  builder, {placeholders}, image paths, argument parsing.
!  Part 2 talks to Windows: register, show, update a progress bar, remove.
!  Results go to NotifyTest.ini ([result] pass/fail + one line per failure).
! ============================================================================
  PROGRAM

  INCLUDE('NotificationClass.INC'),ONCE

  MAP
Check   PROCEDURE(STRING pName, STRING pGot, STRING pWant)
  END

N        NotificationClass
Passed   LONG
Failed   LONG
Ini      STRING('.\NotifyTest.ini')
id       LONG
r        LONG
Delivered LONG

  CODE
  REMOVE(Ini)
  ! ---- Part 1: pure XML -----------------------------------------------------
  Check('escape', N.Escape('a&b<<c>"d''e'), 'a&amp;b&lt;c&gt;&quot;d&apos;e')
  Check('escape empty', N.Escape(''), '')

  N.NewToast('action=open')
  N.Title('Hi & bye')
  N.Line('x<<y')
  N.AddButton('Open', 'action=open;id=5')
  Check('builder', N.XmlText(), '<<toast launch="action=open"><<visual><<binding template="ToastGeneric">' & |
        '<<text hint-maxLines="2">Hi &amp; bye<</text><<text>x&lt;y<</text><</binding><</visual>' & |
        '<<actions><<action content="Open" arguments="action=open;id=5"/><</actions><</toast>')

  N.NewToast()
  N.Title('T')
  N.Attribution('via Sync')
  N.AddTextBox('reply', 'Type a reply', '')
  N.AddButton('Send', 'action=reply', '', 'Success', 'reply')
  N.AddChoice('when', 'm15:15 minutes|h1:1 hour|later', 'h1')
  N.AddSystemButton('snooze')
  N.Scenario('reminder')
  N.LongDuration()
  N.NoSound()
  Check('builder full', N.XmlText(), '<<toast scenario="reminder" duration="long" useButtonStyle="true">' & |
        '<<visual><<binding template="ToastGeneric"><<text hint-maxLines="2">T<</text><<text placement="attribution">via Sync<</text>' & |
        '<</binding><</visual><<actions><<input id="reply" type="text" placeHolderContent="Type a reply"/>' & |
        '<<input id="when" type="selection" defaultInput="h1"><<selection id="m15" content="15 minutes"/><<selection id="h1" content="1 hour"/>' & |
        '<<selection id="later" content="later"/><</input>' & |
        '<<action content="Send" arguments="action=reply" hint-inputId="reply" hint-buttonStyle="Success"/>' & |
        '<<action activationType="system" arguments="snooze" content=""/><</actions><<audio silent="true"/><</toast>')

  N.Reset()
  N.AddXml('<<toast><<visual><<binding template="ToastGeneric"><<text>Hello {{Name}, {{progressValue} {{nAME}<</text><</binding><</visual><</toast>')
  N.SetVar('name', 'A&B')
  Check('placeholders', N.XmlText(), '<<toast><<visual><<binding template="ToastGeneric"><<text>Hello A&amp;B, {{progressValue} A&amp;B<</text><</binding><</visual><</toast><13,10>')

  N.Reset()
  N.ImageFolder = 'C:\imgs'
  Check('uri relative', N.FileUri('logo.png'), 'file:///C:/imgs/logo.png')
  Check('uri spaces', N.FileUri('C:\a b\x.png'), 'file:///C:/a%20b/x.png')
  Check('uri http', N.FileUri('https://example.com/x.png'), 'https://example.com/x.png')
  Check('uri unc', N.FileUri('\\srv\s\x.png'), 'file://srv/s/x.png')
  Check('uri ms', N.FileUri('ms-appdata:///local/x.png'), 'ms-appdata:///local/x.png')
  N.NewToast()
  N.AppLogo('img\logo.png')
  N.HeroImage('C:\pics\hero.jpg')
  Check('images', N.XmlText(), '<<toast><<visual><<binding template="ToastGeneric">' & |
        '<<image placement="appLogoOverride" hint-crop="circle" src="file:///C:/imgs/img/logo.png"/>' & |
        '<<image placement="hero" src="file:///C:/pics/hero.jpg"/><</binding><</visual><</toast>')
  N.ImageFolder = ''

  N.EventArgs = 'action=open;id=1043&who = Ann'
  Check('arg', N.Arg('ID'), '1043')
  Check('arg first', N.Arg('action'), 'open')
  Check('arg spaced', N.Arg('who'), ' Ann')
  Check('arg missing', N.Arg('none'), '')
  Check('arg whole', N.Arg(''), 'action=open;id=1043&who = Ann')

  N.NewToast()
  N.ProgressBar('Downloading', 'Starting', 0.25, '1 of 4')
  Check('progress', N.XmlText(), '<<toast><<visual><<binding template="ToastGeneric"><<progress title="{{progressTitle}" ' & |
        'value="{{progressValue}" valueStringOverride="{{progressValueString}" status="{{progressStatus}"/><</binding><</visual><</toast>')

  ! ---- Part 2: Windows --------------------------------------------------------
  IF NOT N.Init('TemplateMaker.NotifyTest', 'Notification Test')
    Check('init', N.ErrorText(), 'ok')
  ELSE
    Check('ready', N.Ready(), 1)
    Delivered = CHOOSE(N.Enabled(), 0, 2)                 ! notifications off in Settings: nothing is delivered
    PUTINI('result', 'notifications', CHOOSE(N.Enabled(), 'on', 'OFF in Settings - delivery checks expect gone'), Ini)
    ! Enabled() must agree with the switch in Settings (read here straight from the registry)
    Check('enabled matches Settings', N.Enabled(), CHOOSE(GETREG(REG_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\PushNotifications', 'ToastEnabled') = '0', 0, 1))
    Check('fail text', N.FailText(-2143420140), 'Windows notifications are turned off (Settings > System > Notifications)')
    id = N.Toast('NotifyTest', 'Part 2 of the self-test', , 'selftest')
    Check('toast shown', CHOOSE(id > 0, 'yes', 'no ' & N.ErrorText()), 'yes')
    N.NewToast()
    N.Title('Copying files')
    N.ProgressBar('backup.zip', 'Copying...', 0.1, '10%')
    id = N.ShowToast('prog1', 'tests', TRUE)
    Check('progress shown', CHOOSE(id > 0, 'yes', 'no ' & N.ErrorText()), 'yes')
    r = N.UpdateProgress(0.6, 'Almost', '60%', 'prog1', 'tests')
    Check('progress update', r, Delivered)                 ! 2 = gone: Windows dropped it
    r = N.UpdateProgress(0.9, 'Nearly', '90%', 'missing-tag', 'tests')
    Check('update missing', r, 2)
    Check('remove', N.Remove('prog1', 'tests'), 1)
    Check('remove all', N.RemoveAll(), 1)
    N.Reset()
    N.AddXml('<<toast><<visual><<binding template="ToastGeneric"><<text>{{Report}<</text><<progress title="{{progressTitle}" value="{{progressValue}" status="{{progressStatus}"/><</binding><</visual><</toast>')
    N.SetVar('Report', 'Sales')
    id = N.ShowToast(, , TRUE)
    Check('live design shown', CHOOSE(id > 0, 'yes', 'no ' & N.ErrorText()), 'yes')
    Check('live design got a tag', CHOOSE(N.LastTag <> '', 'yes', 'no'), 'yes')
    Check('live design updates', N.UpdateProgress(0.5, 'Half'), Delivered)
    N.Reset()
    N.AddXml('<<toast><<visual><<this-is-not-closed>')
    Check('bad xml refused', N.ShowToast(), 0)
    Check('bad xml stage', SUB(N.ErrorText(), 1, 27), 'reading the notification XM')
    N.Kill()
  END

  PUTINI('result', 'passed', Passed, Ini)
  PUTINI('result', 'failed', Failed, Ini)
  PUTINI('result', 'status', CHOOSE(Failed = 0, 'PASS', 'FAIL'), Ini)

Check PROCEDURE(STRING pName, STRING pGot, STRING pWant)
  CODE
  IF pGot = pWant AND LEN(pGot) = LEN(pWant)
    Passed += 1
  ELSE
    Failed += 1
    PUTINI('fail', pName, 'got [' & pGot & '] want [' & pWant & ']', Ini)
  END
