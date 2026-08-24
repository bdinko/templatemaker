!  emailToDemo - a hand-coded demonstration of the emailTo classes.
!
!  It uses NO template: the point is to show the smallest thing that works, and
!  to give you somewhere to press the buttons without building an application
!  first.  The templates do exactly what this does, from the AppGen prompts.
!
!  BUILD
!      copy EmailNetClass.inc/.clw, EmailMsgClass.inc/.clw, EmailToClass.inc/.clw
!      and emailc.c next to this file (or onto the redirection path), then
!          MSBuild emailToDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32
!
!  The project defines _emailToLinkMode_=>1 and _emailToDllMode_=>0 by hand,
!  because there is no template here to write them for us.
!
!  RUN
!      emailToDemo.exe            the demo window
!      emailToDemo.exe /setup     opens the account window straight away
!
!  Settings go to emailToDemo.ini beside the .EXE, with the password and any
!  OAuth refresh token DPAPI-encrypted for the current Windows user.
  PROGRAM

  INCLUDE('EmailToClass.INC'),ONCE

  MAP
DemoWindow  PROCEDURE
  END

Mailer      EmailToClass

  CODE
  Mailer.Init(PATH() & '\emailToDemo.ini')
  Mailer.Trace = 1
  Mailer.LoadAccount()
  IF NOT CLIP(Mailer.Acc.Host) AND NOT CLIP(Mailer.Acc.ApiKey)
    !  nothing stored yet: start people somewhere sensible
    Mailer.SetProvider(ETPrv:Gmail)
  END
  IF INSTRING('/SETUP', UPPER(COMMAND('')), 1, 1)
    Mailer.Setup()
  ELSE
    DemoWindow()
  END
  RETURN

!=============================================================================
DemoWindow PROCEDURE

LocTo       CSTRING(256)
LocSubject  CSTRING(256)
LocStatus   CSTRING(129)
LocAccount  CSTRING(200)
i           LONG
sent        BYTE

!  A LIST binds to a real QUEUE, never to a queue REFERENCE - FROM(Mailer.Net.TraceQ)
!  compiles and then faults on the first paint.  So the conversation is copied
!  into this one for display.
LogQ        QUEUE
LLine         STRING(512)
            END

Window WINDOW('emailTo demo'),AT(,,300,224),GRAY,SYSTEM,FONT('Segoe UI',9),CENTER,ICON(ICON:Application)
         STRING('emailTo'),AT(10,8),USE(?Title),FONT('Segoe UI',14,,FONT:bold)
         STRING('Send e-mail from Clarion - SMTP/TLS, OAuth2, REST'),AT(10,26),USE(?Sub),FONT(,8),COLOR(COLOR:Gray)
         LINE,AT(10,40,280,0),USE(?Line1),COLOR(COLOR:Silver)
         STRING(@s199),AT(10,48,280,10),USE(LocAccount),FONT(,8)
         BUTTON('&Account setup...'),AT(10,64,90,16),USE(?Setup)
         BUTTON('&Write a message...'),AT(106,64,90,16),USE(?Compose)
         BUTTON('Send a &test'),AT(202,64,88,16),USE(?TestSend)
         LINE,AT(10,88,280,0),USE(?Line2),COLOR(COLOR:Silver)
         PROMPT('Send a test to:'),AT(10,98),USE(?PrTo)
         ENTRY(@s255),AT(76,96,214,10),USE(LocTo)
         PROMPT('Subject:'),AT(10,114),USE(?PrSubject)
         ENTRY(@s255),AT(76,112,214,10),USE(LocSubject)
         STRING(@s128),AT(10,130,280,10),USE(LocStatus),FONT(,8)
         GROUP('Conversation'),AT(6,142,288,58),USE(?Grp),BOXED
           LIST,AT(12,154,276,42),USE(?ListLog),FROM(LogQ),FORMAT('268L(2)@s255@'),VSCROLL,HSCROLL,FONT('Consolas',7)
         END
         BUTTON('Close'),AT(240,204,52,16),USE(?CloseBtn),STD(STD:Close)
       END

  CODE
  LocSubject = Mailer.Txt(ETTxt:TestSubject)
  LocTo      = Mailer.Acc.FromAddr
  OPEN(Window)
  DO ShowAccount
  ACCEPT
    CASE FIELD()
    OF ?Setup
      IF EVENT() = EVENT:Accepted
        Mailer.Setup()
        DO ShowAccount
        DISPLAY()
      END
    OF ?Compose
      IF EVENT() = EVENT:Accepted
        Mailer.Compose(LocTo, LocSubject)
        DO RefreshLog
        DISPLAY(?ListLog)
      END
    OF ?TestSend
      IF EVENT() = EVENT:Accepted
        IF NOT CLIP(LocTo)
          MESSAGE(Mailer.Txt(ETTxt:NeedTo), 'emailTo demo', ICON:Exclamation)
          SELECT(?LocTo)
          CYCLE
        END
        LocStatus = Mailer.Txt(ETTxt:Sending)
        DISPLAY()
        SETCURSOR(CURSOR:Wait)
        sent = Mailer.SendSimple(LocTo, LocSubject, Mailer.Txt(ETTxt:TestBody))
        SETCURSOR()
        IF sent
          LocStatus = Mailer.Txt(ETTxt:Sent)
        ELSE
          LocStatus = CLIP(Mailer.LastErrorText)
        END
        DO RefreshLog
        DISPLAY()
      END
    END
  END
  CLOSE(Window)
  RETURN

RefreshLog ROUTINE
  FREE(LogQ)
  IF Mailer.Net.TraceQ &= NULL THEN EXIT.
  LOOP i = 1 TO RECORDS(Mailer.Net.TraceQ)
    GET(Mailer.Net.TraceQ, i)
    LogQ.LLine = Mailer.Net.TraceQ.Line
    ADD(LogQ)
  END

ShowAccount ROUTINE
  IF CLIP(Mailer.Acc.Host)
    LocAccount = CLIP(Mailer.ProviderName(Mailer.Acc.Provider)) & '  -  ' & |
                 CLIP(Mailer.Acc.Host) & ':' & Mailer.Acc.Port & |
                 CHOOSE(Mailer.Acc.Security + 1, ' (plain)', ' (STARTTLS)', ' (TLS)')
  ELSE
    LocAccount = CLIP(Mailer.ProviderName(Mailer.Acc.Provider)) & '  -  API key'
  END
  IF CLIP(Mailer.Acc.FromAddr)
    LocAccount = CLIP(LocAccount) & '   from ' & CLIP(Mailer.Acc.FromAddr)
  END
