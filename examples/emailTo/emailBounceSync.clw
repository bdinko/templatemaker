!  emailBounceSync - what the provider API is actually FOR.
!
!  A mail provider knows things your database does not: which of your
!  customers' addresses bounced, who pressed "this is junk", who unsubscribed.
!  Left alone that knowledge stays on their web site, and your program keeps
!  mailing addresses that will never be delivered - which is exactly what
!  ruins a sending reputation.
!
!  This is the job in twenty lines: read the provider's block list, find each
!  address in your own table, and mark it. Then - the other direction - take
!  the customers somebody has since corrected and let them back in at the
!  provider, so the corrected address can be used again.
!
!  It runs with no window at all, which is the point: put it in a scheduled
!  task and the two sides stay in step by themselves.
!
!      emailBounceSync                  mark the blocked customers
!      emailBounceSync /unblock         also release the ones marked "fixed"
!      emailBounceSync /quiet           no message box, just the log
!      emailBounceSync /base=http://127.0.0.1:8099
!                                       run against the stand-in server, for
!                                       trying it out with no real account
!
!  Everything it did goes to emailBounceSync.log beside the .EXE.
!
!  BUILD
!      MSBuild emailBounceSync.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32
!  The account comes from emailApiDemo.ini, so set it up once in the demo
!  next door and this program uses the same sealed key.
  PROGRAM

  INCLUDE('EmailApiClass.INC'),ONCE

  MAP
Run          PROCEDURE
Seed         PROCEDURE
Log          PROCEDURE(STRING pLine)
Switch       PROCEDURE(STRING pName),STRING
    MODULE('kernel32')
CreateFileA  PROCEDURE(*CSTRING,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,RAW,NAME('CreateFileA')
WriteFile    PROCEDURE(LONG,*STRING,ULONG,*ULONG,LONG),LONG,PROC,PASCAL,RAW,NAME('WriteFile')
CloseHandle  PROCEDURE(LONG),LONG,PROC,PASCAL,NAME('CloseHandle')
SetFilePointer PROCEDURE(LONG,LONG,LONG,ULONG),ULONG,PASCAL,NAME('SetFilePointer')
    END
  END

!  Your own table. In a real application this is whatever your dictionary
!  calls the customer file - only the three columns at the bottom are new,
!  and even those are optional: the marking is what matters.
Customers  FILE,DRIVER('TOPSPEED'),NAME('customers.tps'),PRE(CUS),CREATE,THREAD
ByEmail      KEY(CUS:EMail),DUP,NOCASE
Record       RECORD,PRE()
Name           STRING(60)
EMail          CSTRING(256)
Blocked        BYTE                                  ! 1 = the provider refuses this address
Reason         STRING(120)                           ! why, in the provider's own words
BlockedOn      DATE
Fixed          BYTE                                  ! somebody corrected the address
             END
           END

Mailer     EmailToClass
MailApi    EmailApiClass
LogName    CSTRING(261)
Quiet      BYTE
Marked     LONG
Cleared    LONG
Released   LONG
Failed     LONG

  CODE
  LogName = PATH() & '\emailBounceSync.log'
  Quiet   = CHOOSE(INSTRING('/QUIET', UPPER(COMMAND('')), 1, 1) > 0, 1, 0)

  Mailer.Init(PATH() & '\emailApiDemo.ini')
  Mailer.Silent = 1
  Mailer.LoadAccount()
  IF CLIP(Switch('/base='))
    !  Point at a stand-in instead of the real provider - the same escape
    !  hatch the template calls "Base address".
    Mailer.Acc.ApiBase    = CLIP(Switch('/base='))
    Mailer.Acc.VerifyCert = 0
    IF NOT CLIP(Mailer.Acc.ApiKey) THEN Mailer.Acc.ApiKey = 'test-key'.
    IF NOT Mailer.Acc.Provider THEN Mailer.SetProvider(ETPrv:SendGrid).
  END
  MailApi.Init(Mailer)
  MailApi.Silent = 1

  Run()

  IF NOT Quiet
    MESSAGE('Marked ' & Marked & ' blocked, cleared ' & Cleared & |
            ', released ' & Released & ' back to the provider.' & |
            CHOOSE(Failed > 0, '<13,10>' & Failed & ' failed - see the log.', ''), |
            'emailBounceSync', ICON:Asterisk)
  END
  RETURN

!=============================================================================
Run PROCEDURE
n     LONG
i     LONG
addr  CSTRING(256)
  CODE
  Log('===== ' & FORMAT(TODAY(), @D10-) & ' ' & FORMAT(CLOCK(), @T4) & ' =====')
  Log('provider: ' & CLIP(Mailer.ProviderName(Mailer.Acc.Provider)))

  IF NOT MailApi.Supports(ETOp:Suppressions)
    Log('This provider has no block list to read. Nothing to do.')
    RETURN
  END

  OPEN(Customers)
  IF ERRORCODE()
    CREATE(Customers)
    OPEN(Customers)
    IF ERRORCODE()
      Log('cannot open customers.tps: ' & CLIP(ERROR()))
      RETURN
    END
    Seed()
  END

  !  ---- 1. what does the provider refuse? ----------------------------------
  n = MailApi.GetSuppressions(ETSup:All)
  IF n < 0
    Log('the provider said no: ' & CLIP(MailApi.LastErrorText))
    Log('  (it was asked for ' & CLIP(MailApi.LastUrl) & ')')
    CLOSE(Customers)
    RETURN
  END
  Log(n & ' blocked addresses at the provider')

  !  ---- 2. mark them in your own table -------------------------------------
  !  Walking the provider's list and looking each one up by key is the cheap
  !  direction: the block list is small, the customer file is not.
  LOOP i = 1 TO RECORDS(MailApi.SuppQ)
    GET(MailApi.SuppQ, i)
    CUS:EMail = CLIP(MailApi.SuppQ.Address)
    SET(Customers.ByEmail, Customers.ByEmail)
    LOOP
      NEXT(Customers)
      IF ERRORCODE() THEN BREAK.
      IF UPPER(CLIP(CUS:EMail)) <> UPPER(CLIP(MailApi.SuppQ.Address)) THEN BREAK.
      IF CUS:Blocked = 1 AND CLIP(CUS:Reason) = CLIP(MailApi.SuppQ.Reason) THEN CYCLE.
      CUS:Blocked   = 1
      CUS:Reason    = MailApi.SuppQ.Reason
      CUS:BlockedOn = CHOOSE(MailApi.SuppQ.WhenDate > 0, MailApi.SuppQ.WhenDate, TODAY())
      PUT(Customers)
      IF ERRORCODE()
        Log('  could not update ' & CLIP(CUS:EMail) & ': ' & CLIP(ERROR()))
        Failed += 1
      ELSE
        Marked += 1
        Log('  blocked  ' & CLIP(CUS:EMail) & '  (' & CLIP(MailApi.SuppQ.KindName) & ')  ' & |
            CLIP(MailApi.SuppQ.Reason))
      END
    END
  END

  !  ---- 3. anybody marked blocked who is NOT on the list any more ----------
  !  Somebody may have been let back in at the provider's web site. This puts
  !  your table back in step without anybody having to remember.
  SET(Customers)
  LOOP
    NEXT(Customers)
    IF ERRORCODE() THEN BREAK.
    IF CUS:Blocked <> 1 THEN CYCLE.
    IF MailApi.IsBlocked(CUS:EMail) THEN CYCLE.
    CUS:Blocked   = 0
    CUS:Reason    = ''
    CUS:BlockedOn = 0
    PUT(Customers)
    IF NOT ERRORCODE()
      Cleared += 1
      Log('  cleared  ' & CLIP(CUS:EMail) & ' - the provider no longer refuses it')
    END
  END

  !  ---- 4. the other direction: release the ones somebody has fixed --------
  IF INSTRING('/UNBLOCK', UPPER(COMMAND('')), 1, 1)
    IF NOT MailApi.Supports(ETOp:SuppDelete)
      Log('this provider cannot be told to unblock an address through its API')
    ELSE
      SET(Customers)
      LOOP
        NEXT(Customers)
        IF ERRORCODE() THEN BREAK.
        IF CUS:Fixed <> 1 OR CUS:Blocked <> 1 THEN CYCLE.
        addr = CLIP(CUS:EMail)
        IF NOT MailApi.IsBlocked(addr) THEN CYCLE.
        IF MailApi.DeleteSuppression(addr, ETSup:All)
          CUS:Blocked   = 0
          CUS:Fixed     = 0
          CUS:Reason    = ''
          CUS:BlockedOn = 0
          PUT(Customers)
          Released += 1
          Log('  released ' & CLIP(addr) & ' back to the provider')
        ELSE
          Failed += 1
          Log('  could not release ' & CLIP(addr) & ': ' & CLIP(MailApi.LastErrorText))
        END
      END
    END
  END

  CLOSE(Customers)
  Log('marked ' & Marked & ', cleared ' & Cleared & ', released ' & Released & |
      ', failed ' & Failed)
  Log('')
  RETURN

!=============================================================================
!  A few rows so the example does something the first time it is run.
Seed PROCEDURE
  CODE
  CLEAR(CUS:Record) ; CUS:Name = 'Ana Ruiz'      ; CUS:EMail = 'a@b.com'      ; ADD(Customers)
  CLEAR(CUS:Record) ; CUS:Name = 'Bruno Costa'   ; CUS:EMail = 'c@d.com'      ; ADD(Customers)
  !  Carla telephoned and gave a corrected address, so somebody ticked
  !  "fixed" in the customer screen.  /unblock is what releases her at the
  !  provider - without it she stays refused however good the address is now.
  CLEAR(CUS:Record) ; CUS:Name = 'Carla Mendes'  ; CUS:EMail = 'e@f.com'
  CUS:Fixed = 1                                                 ; ADD(Customers)
  CLEAR(CUS:Record) ; CUS:Name = 'Diego Alvarez' ; CUS:EMail = 'good@acme.com'; ADD(Customers)
  CLEAR(CUS:Record) ; CUS:Name = 'Elena Prat'    ; CUS:EMail = 'fine@acme.com'; ADD(Customers)
  RETURN

!=============================================================================
!  The value after a switch: /base=http://... gives http://...
Switch PROCEDURE(STRING pName)
cmd CSTRING(1025)
p   LONG
e   LONG
  CODE
  cmd = CLIP(COMMAND(''))
  p   = INSTRING(UPPER(CLIP(pName)), UPPER(cmd), 1, 1)
  IF NOT p THEN RETURN ''.
  p += LEN(CLIP(pName))
  e  = INSTRING(' ', cmd, 1, p)
  IF NOT e THEN e = LEN(CLIP(cmd)) + 1.
  IF e <= p THEN RETURN ''.
  RETURN cmd[p : e - 1]

!=============================================================================
!  Appending to a log file with no file driver, so this example adds nothing
!  to what a program has to link.
Log PROCEDURE(STRING pLine)
hFile LONG
wrote ULONG
buf   STRING(1200)
text  CSTRING(1200)
  CODE
  text  = CLIP(pLine) & '<13,10>'
  hFile = CreateFileA(LogName, 40000000h, 0, 0, 4, 80h, 0)      ! OPEN_ALWAYS
  IF hFile = -1 OR hFile = 0 THEN RETURN.
  SetFilePointer(hFile, 0, 0, 2)                                ! FILE_END
  buf[1 : LEN(CLIP(text))] = text
  WriteFile(hFile, buf, LEN(CLIP(text)), wrote, 0)
  CloseHandle(hFile)
  RETURN
