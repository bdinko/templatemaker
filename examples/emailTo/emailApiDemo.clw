!  emailApiDemo - the provider API, hand-coded, with no template.
!
!  emailToDemo next door shows the sending half. This one shows the other
!  half: asking the provider who is blocked and why, what last month looked
!  like, and what is in the account - through ONE set of methods whichever of
!  the eight providers you signed up with.
!
!  It does the same job two ways on purpose:
!
!    "Mail account..."   opens EmailApiClass.Manage(), the ready-made window.
!                        One line of code, every tab, every provider.
!    the buttons below   do it from your own code instead, so you can see what
!                        the queues actually look like and copy the pattern.
!
!  BUILD
!      copy EmailNetClass.inc/.clw, EmailMsgClass.inc/.clw, EmailToClass.inc/.clw,
!      EmailJsonClass.inc/.clw, EmailApiClass.inc/.clw and emailc.c next to this
!      file (or onto the redirection path), then
!          MSBuild emailApiDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32
!
!  RUN
!      emailApiDemo.exe
!  Press "Account setup..." first and put in a provider and its API key. The
!  key is DPAPI-sealed into emailApiDemo.ini beside the .EXE, so it is useless
!  on any other machine or under any other login.
!
!  TRYING IT WITH NO ACCOUNT.  Set Base address (Setup - Advanced) to
!  http://127.0.0.1:8099 and run the stand-in server that ships with the
!  template tests; every button then works against canned answers.
  PROGRAM

  INCLUDE('EmailApiClass.INC'),ONCE

  MAP
DemoWindow  PROCEDURE
  END

Mailer      EmailToClass
MailApi     EmailApiClass

  CODE
  Mailer.Init(PATH() & '\emailApiDemo.ini')
  Mailer.Trace = 1
  Mailer.LoadAccount()
  IF NOT CLIP(Mailer.Acc.ApiKey) AND NOT CLIP(Mailer.Acc.Host)
    !  Start somewhere that has an API rather than on plain SMTP.
    Mailer.SetProvider(ETPrv:SendGrid)
  END
  !  One line, and every management call in this program is signed with the
  !  account above.  There is no second copy of the key anywhere.
  MailApi.Init(Mailer)
  DemoWindow()
  RETURN

!=============================================================================
DemoWindow PROCEDURE

LocStatus   CSTRING(200)
LocAccount  CSTRING(200)
LocAddress  CSTRING(256)
LocDetail   CSTRING(1200)
i           LONG
n           LONG
ok          BYTE

!  A LIST binds to a REAL queue, never to a queue REFERENCE: FROM(MailApi.SuppQ)
!  compiles and then faults on the first paint. So the rows are copied across -
!  which is where the dates become readable anyway.
BlkQ  QUEUE
BAddr   STRING(120)
BKind   STRING(20)
BReason STRING(200)
BWhen   STRING(12)
      END
StQ   QUEUE
SDate   STRING(12)
SReq    STRING(10)
SDlv    STRING(10)
SOpn    STRING(10)
SBnc    STRING(10)
      END

Window WINDOW('emailTo - the provider API'),AT(,,440,300),GRAY,SYSTEM,FONT('Segoe UI',9),CENTER,ICON(ICON:Application)
         STRING('emailTo'),AT(10,8),USE(?Title),FONT('Segoe UI',14,,FONT:bold)
         STRING('One class, eight providers: who is blocked, and why'),AT(10,26),USE(?Sub),FONT(,8),COLOR(COLOR:Gray)
         LINE,AT(10,40,420,0),USE(?Line1),COLOR(COLOR:Silver)
         STRING(@s199),AT(10,48,420,10),USE(LocAccount),FONT(,8)
         BUTTON('&Account setup...'),AT(10,62,84,16),USE(?Setup)
         BUTTON('&Mail account...'),AT(100,62,84,16),USE(?Manage),TIP('The ready-made window: every tab, every provider')
         BUTTON('Who is &blocked'),AT(190,62,80,16),USE(?Blocked)
         BUTTON('&Statistics'),AT(276,62,64,16),USE(?Stats)
         BUTTON('&Who am I'),AT(346,62,84,16),USE(?Account)
         LINE,AT(10,84,420,0),USE(?Line2),COLOR(COLOR:Silver)
         SHEET,AT(6,90,428,166),USE(?Sheet),SPREAD
           TAB('Blocked addresses'),USE(?TabBlocked)
             LIST,AT(12,106,416,110),USE(?BlkList),FROM(BlkQ),VSCROLL,|
                  FORMAT('90L(2)|M~Address~@s120@46L(2)|M~Kind~@s20@180L(2)|M~Reason~@s200@' & |
                         '52L(2)|M~When~@s12@')
             BUTTON('&Unblock this one'),AT(12,222,80,14),USE(?Unblock)
             BUTTON('Unblock &all'),AT(98,222,64,14),USE(?UnblockAll)
             BUTTON('&Export CSV'),AT(168,222,60,14),USE(?Export)
             PROMPT('Blocked?'),AT(240,224),USE(?PrAddr)
             ENTRY(@s255),AT(276,222,100,10),USE(LocAddress)
             BUTTON('Chec&k'),AT(382,222,46,14),USE(?Check)
           END
           TAB('Statistics'),USE(?TabStats)
             LIST,AT(12,106,416,130),USE(?StatList),FROM(StQ),VSCROLL,|
                  FORMAT('70L(2)|M~Date~@s12@70R(2)|M~Requested~@s10@70R(2)|M~Delivered~@s10@' & |
                         '60R(2)|M~Opens~@s10@60R(2)|M~Bounces~@s10@')
           END
           TAB('What came back'),USE(?TabRaw)
             TEXT,AT(12,106,416,130),USE(LocDetail),VSCROLL,HSCROLL,READONLY,FONT('Consolas',8)
           END
         END
         STRING(@s199),AT(10,262,340,10),USE(LocStatus),FONT(,8)
         BUTTON('Close'),AT(378,276,52,16),USE(?CloseBtn),STD(STD:Close)
       END

  CODE
  OPEN(Window)
  DO ShowAccount
  DO Capability
  ACCEPT
    CASE FIELD()
    OF ?Setup
      IF EVENT() = EVENT:Accepted
        Mailer.Setup()
        DO ShowAccount
        DO Capability
        DISPLAY()
      END

    OF ?Manage
      IF EVENT() = EVENT:Accepted
        !  The whole management window, in one line.
        MailApi.Manage()
      END

    OF ?Blocked
      IF EVENT() = EVENT:Accepted THEN DO LoadBlocked.

    OF ?Stats
      IF EVENT() = EVENT:Accepted THEN DO LoadStats.

    OF ?Account
      IF EVENT() = EVENT:Accepted THEN DO LoadAccount.

    OF ?Unblock
      IF EVENT() = EVENT:Accepted THEN DO DoUnblock.

    OF ?UnblockAll
      IF EVENT() = EVENT:Accepted THEN DO DoUnblockAll.

    OF ?Export
      IF EVENT() = EVENT:Accepted THEN DO DoExport.

    OF ?Check
      IF EVENT() = EVENT:Accepted THEN DO DoCheck.
    END
  END
  CLOSE(Window)
  RETURN

!-----------------------------------------------------------------------------
!  Who is blocked, and why.  This is the whole point of the class: the same
!  six lines read SendGrid's five separate lists, Brevo's single labelled one,
!  Mailgun's cursor-paged bounces and Postmark's stream dump.
LoadBlocked ROUTINE
  LocStatus = 'Asking ' & CLIP(Mailer.ProviderName(Mailer.Acc.Provider)) & '...'
  DISPLAY(?LocStatus)
  SETCURSOR(CURSOR:Wait)
  n = MailApi.GetSuppressions(ETSup:All)
  SETCURSOR()
  FREE(BlkQ)
  IF n < 0
    LocStatus = CLIP(MailApi.LastErrorText)
  ELSE
    LOOP i = 1 TO RECORDS(MailApi.SuppQ)
      GET(MailApi.SuppQ, i)
      BlkQ.BAddr   = MailApi.SuppQ.Address
      BlkQ.BKind   = MailApi.SuppQ.KindName
      BlkQ.BReason = MailApi.SuppQ.Reason
      BlkQ.BWhen   = CHOOSE(MailApi.SuppQ.WhenDate > 0, |
                            CLIP(FORMAT(MailApi.SuppQ.WhenDate, @D10-)), '')
      ADD(BlkQ)
    END
    LocStatus = n & ' blocked'
  END
  LocDetail = SUB(CLIP(MailApi.LastUrl) & '<13,10><13,10>' & CLIP(MailApi.Net.Body()), 1, 1199)
  SELECT(?TabBlocked)
  DISPLAY()

LoadStats ROUTINE
  LocStatus = 'Asking for the last 30 days...'
  DISPLAY(?LocStatus)
  SETCURSOR(CURSOR:Wait)
  n = MailApi.GetStats(TODAY() - 30, TODAY())
  SETCURSOR()
  FREE(StQ)
  IF n < 0
    LocStatus = CLIP(MailApi.LastErrorText)
  ELSE
    LOOP i = 1 TO RECORDS(MailApi.StatQ)
      GET(MailApi.StatQ, i)
      StQ.SDate = CHOOSE(MailApi.StatQ.WhenDate > 0, |
                         CLIP(FORMAT(MailApi.StatQ.WhenDate, @D10-)), '')
      StQ.SReq  = MailApi.StatQ.Requests
      StQ.SDlv  = MailApi.StatQ.Delivered
      StQ.SOpn  = MailApi.StatQ.Opens
      StQ.SBnc  = MailApi.StatQ.HardBounces + MailApi.StatQ.SoftBounces
      ADD(StQ)
    END
    LocStatus = n & ' days'
  END
  LocDetail = SUB(CLIP(MailApi.LastUrl) & '<13,10><13,10>' & CLIP(MailApi.Net.Body()), 1, 1199)
  SELECT(?TabStats)
  DISPLAY()

LoadAccount ROUTINE
  SETCURSOR(CURSOR:Wait)
  ok = MailApi.GetAccount()
  SETCURSOR()
  IF NOT ok
    LocStatus = CLIP(MailApi.LastErrorText)
  ELSE
    LocStatus = CLIP(MailApi.Account.Name) & '  ' & CLIP(MailApi.Account.Company) & |
                '   plan: ' & CLIP(MailApi.Account.Plan) & |
                CHOOSE(MailApi.Account.Credits >= 0, |
                       '   credits: ' & MailApi.Account.Credits, '')
  END
  LocDetail = SUB(CLIP(MailApi.LastUrl) & '<13,10><13,10>' & CLIP(MailApi.Account.Raw), 1, 1199)
  SELECT(?TabRaw)
  DISPLAY()

DoUnblock ROUTINE
  IF NOT RECORDS(BlkQ) THEN EXIT.
  GET(MailApi.SuppQ, CHOICE(?BlkList))
  IF ERRORCODE() THEN EXIT.
  SETCURSOR(CURSOR:Wait)
  ok = MailApi.DeleteSuppression(MailApi.SuppQ.Address, MailApi.SuppQ.Kind)
  SETCURSOR()
  IF ok
    DO LoadBlocked
    LocStatus = 'Let back in.'
  ELSE
    LocStatus = CLIP(MailApi.LastErrorText)
  END
  DISPLAY()

!  "Delete all" means the same thing everywhere, even at the providers with no
!  endpoint for it - there the class simply deletes them one at a time.
DoUnblockAll ROUTINE
  IF NOT RECORDS(MailApi.SuppQ) THEN EXIT.
  IF MESSAGE('Unblock every one of these ' & RECORDS(MailApi.SuppQ) & ' addresses?', |
             'Unblock all', ICON:Question, BUTTON:Yes + BUTTON:No, BUTTON:No) <> BUTTON:Yes
    EXIT
  END
  SETCURSOR(CURSOR:Wait)
  n = MailApi.DeleteAllSuppressions(ETSup:All)
  SETCURSOR()
  IF n < 0
    LocStatus = CLIP(MailApi.LastErrorText)
  ELSE
    LocStatus = n & ' let back in.'
    DO LoadBlocked
  END
  DISPLAY()

DoExport ROUTINE
  IF NOT RECORDS(MailApi.SuppQ) THEN DO LoadBlocked.
  LocAddress = 'blocked.csv'
  IF NOT FILEDIALOG('Export the blocked list', LocAddress, 'CSV|*.csv|All files|*.*', |
                    FILE:Save + FILE:KeepDir + FILE:AddExtension)
    EXIT
  END
  n = MailApi.ExportSuppressions(LocAddress)
  IF n < 0
    LocStatus = CLIP(MailApi.LastErrorText)
  ELSE
    LocStatus = n & ' rows written to ' & CLIP(LocAddress)
  END
  LocAddress = ''
  DISPLAY()

!  Worth doing before a send: a hard bounce that you keep mailing costs
!  reputation, and the provider will refuse it anyway.
DoCheck ROUTINE
  IF NOT CLIP(LocAddress)
    LocStatus = 'Type an address first.'
    DISPLAY()
    EXIT
  END
  IF NOT RECORDS(MailApi.SuppQ) THEN DO LoadBlocked.
  IF MailApi.IsBlocked(LocAddress)
    LocStatus = CLIP(LocAddress) & ' IS blocked - do not send to it.'
  ELSE
    LocStatus = CLIP(LocAddress) & ' is not on the list.'
  END
  DISPLAY()

ShowAccount ROUTINE
  LocAccount = CLIP(Mailer.ProviderName(Mailer.Acc.Provider))
  IF CLIP(Mailer.Acc.FromAddr)
    LocAccount = CLIP(LocAccount) & '   from ' & CLIP(Mailer.Acc.FromAddr)
  END
  IF NOT CLIP(Mailer.Acc.ApiKey)
    LocAccount = CLIP(LocAccount) & '   -   no API key yet: press Account setup'
  END

!  Grey out what this provider cannot answer, rather than letting somebody
!  press a button that can only fail.
Capability ROUTINE
  ?Blocked{PROP:Disable}    = CHOOSE(MailApi.Supports(ETOp:Suppressions) = 0, 1, 0)
  ?Stats{PROP:Disable}      = CHOOSE(MailApi.Supports(ETOp:Stats) = 0, 1, 0)
  ?Account{PROP:Disable}    = CHOOSE(MailApi.Supports(ETOp:Account) = 0, 1, 0)
  ?Unblock{PROP:Disable}    = CHOOSE(MailApi.Supports(ETOp:SuppDelete) = 0, 1, 0)
  ?UnblockAll{PROP:Disable} = CHOOSE(MailApi.Supports(ETOp:SuppDeleteAll) = 0, 1, 0)
