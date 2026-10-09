! ============================================================================
!  MsgHookClass - implementation.   See MsgHookClass.inc for the overview.
!
!  This file must be stored ANSI, with CRLF line endings.
! ============================================================================
  MEMBER()

  MAP
    MODULE('win32')
      mhCreateFile(*CSTRING lpFileName, ULONG dwDesiredAccess, ULONG dwShareMode, LONG lpSecurityAttributes, ULONG dwCreationDisposition, ULONG dwFlagsAndAttributes, LONG hTemplateFile),LONG,RAW,PASCAL,NAME('CreateFileA')
      mhWriteFile( LONG hFile, *STRING lpBuffer, ULONG nBytes, *ULONG lpWritten, LONG lpOverlapped ),LONG,RAW,PASCAL,PROC,NAME('WriteFile')
      mhCloseHandle( LONG hObject ),LONG,RAW,PASCAL,PROC,NAME('CloseHandle')
      mhFileSize( LONG hFile, LONG lpFileSizeHigh ),ULONG,RAW,PASCAL,NAME('GetFileSize')
      mhDeleteFile( *CSTRING lpFileName ),LONG,RAW,PASCAL,PROC,NAME('DeleteFileA')
      mhMoveFile( *CSTRING lpExisting, *CSTRING lpNew ),LONG,RAW,PASCAL,PROC,NAME('MoveFileA')
    END
!   ---- the six procedures the run-time library is handed the address of ----
    mhMessage(STRING,<STRING>,<STRING>,<STRING>,UNSIGNED=0,BOOL=FALSE),UNSIGNED,PROC
    mhStop(<STRING>)
    mhHalt(UNSIGNED=0,<STRING>)
    mhAssert(UNSIGNED,STRING)
    mhAssert2(UNSIGNED,STRING,STRING)
    mhFatal(UNSIGNED,STRING)
    mhExcept(*ICWExceptionInfo),LONG
  END

  INCLUDE('MsgHookClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('CWEXCPT.INT'),ONCE

mh:CRLF            EQUATE('<13,10>')
mh:Append          EQUATE(0004H)                ! FILE_APPEND_DATA
mh:ShareRW         EQUATE(0003H)                ! FILE_SHARE_READ + FILE_SHARE_WRITE
mh:OpenAlways      EQUATE(0004H)                ! OPEN_ALWAYS
mh:Normal          EQUATE(0080H)                ! FILE_ATTRIBUTE_NORMAL
mh:Read            EQUATE(80000000H)            ! GENERIC_READ
mh:OpenExisting    EQUATE(0003H)                ! OPEN_EXISTING

mhOwner            &MsgHookClass                ! whoever called Install() last
mhQuiet            BYTE,THREAD                  ! Suspend() was called on this thread


! ############################################################################
!  The thunks. The RTL is given ADDRESS() of these, so their prototypes have to
!  match the ones the library expects, exactly - they are copied from the
!  shipped WebBuilder hook layer, \clarion12\libsrc\win\WBHOOK.CLW.
! ############################################################################
mhMessage PROCEDURE(STRING pText,<STRING pCaption>,<STRING pIcon>,<STRING pButtons>,UNSIGNED pDefault,BOOL pStyle)
cap   CSTRING(257)
ico   CSTRING(65)
btn   LONG(0)
  CODE
  IF ~OMITTED(2)
    cap = CLIP(pCaption)
  END
  IF ~OMITTED(3)
    ico = CLIP(pIcon)
  END
  IF ~OMITTED(4)
    btn = pButtons                              ! the RTL hands the bitmap over as text
  END
  IF ~btn
    btn = BUTTON:Ok
  END
  IF mhOwner &= NULL
    RETURN btn                                  ! no object left - answer and move on
  END
  RETURN mhOwner.OnMessage(pText,cap,ico,btn,pDefault,pStyle)


mhStop PROCEDURE(<STRING pText>)
  CODE
  IF mhOwner &= NULL
    RETURN
  END
  IF OMITTED(1)
    mhOwner.OnStop('')
  ELSE
    mhOwner.OnStop(pText)
  END


mhHalt PROCEDURE(UNSIGNED pCode,<STRING pText>)
  CODE
  IF mhOwner &= NULL
    HALT(pCode)
    RETURN
  END
  IF OMITTED(2)
    mhOwner.OnHalt(pCode,'')
  ELSE
    mhOwner.OnHalt(pCode,pText)
  END


mhAssert PROCEDURE(UNSIGNED pLine,STRING pModule)
  CODE
  IF mhOwner &= NULL
    RETURN
  END
  mhOwner.OnAssert(pLine,pModule,'')


mhAssert2 PROCEDURE(UNSIGNED pLine,STRING pModule,STRING pText)
  CODE
  IF mhOwner &= NULL
    RETURN
  END
  mhOwner.OnAssert(pLine,pModule,pText)


mhFatal PROCEDURE(UNSIGNED pCode,STRING pText)
  CODE
  IF mhOwner &= NULL
    RETURN
  END
  mhOwner.OnFatal(pCode,pText)


mhExcept PROCEDURE(*ICWExceptionInfo pInfo)
  CODE
  IF pInfo &= NULL OR mhOwner &= NULL
    RETURN 1                                    ! 1 = let the thread be killed
  END
  RETURN mhOwner.OnException(pInfo.ExceptionCode(),pInfo.ExceptionAddress(),'')


! ############################################################################
!  Life
! ############################################################################
MsgHookClass.Construct PROCEDURE()
  CODE
  SELF.Rules &= NEW HookRuleQueue
  SELF.Init()


MsgHookClass.Destruct PROCEDURE()
  CODE
  SELF.Kill()
  IF ~SELF.Rules &= NULL
    FREE(SELF.Rules)
    DISPOSE(SELF.Rules)
    SELF.Rules &= NULL
  END


MsgHookClass.Init PROCEDURE()
i  LONG,AUTO
  CODE
  LOOP i = 1 TO Hook:Events
    SELF.Watch[i]   = 0
    SELF.Action[i]  = HookDo:Normal
    SELF.Answer[i]  = 0
    SELF.Seen[i]    = 0
    SELF.Changed[i] = 0
  END
  SELF.LogName   = ''
  SELF.LogFormat = HookLog:Text
  SELF.LogWhat   = HookLogged:All
  SELF.LogStamp  = 1
  SELF.LogWindow = 1
  SELF.LogMax    = 0
  SELF.LogHeaded = 0
  SELF.NextTag   = 0
  CLEAR(SELF.Info)


MsgHookClass.Kill PROCEDURE()
  CODE
  SELF.Remove()


! ############################################################################
!  Setting it up
! ############################################################################
MsgHookClass.SetEvent PROCEDURE(LONG pEvent,LONG pAction,LONG pAnswer=0)
  CODE
  IF pEvent < 1 OR pEvent > Hook:Events
    RETURN
  END
  SELF.Watch[pEvent]  = 1
  SELF.Action[pEvent] = pAction
  SELF.Answer[pEvent] = pAnswer
  IF SELF.Active
    SELF.Install()                              ! take the change up straight away
  END


MsgHookClass.AddRule PROCEDURE(LONG pEvent,STRING pMatch,LONG pMode=HookMatch:Contains,LONG pAction=HookDo:Ignore,LONG pAnswer=0,LONG pLook=HookIn:Either,<STRING pNewText>)
  CODE
  IF SELF.Rules &= NULL
    RETURN 0
  END
  CLEAR(SELF.Rules)
  SELF.NextTag += 1
  SELF.Rules.Event  = pEvent
  SELF.Rules.Look   = pLook
  SELF.Rules.Mode   = pMode
  SELF.Rules.Match  = CLIP(LEFT(pMatch))
  SELF.Rules.Action = pAction
  SELF.Rules.Answer = pAnswer
  SELF.Rules.Tag    = SELF.NextTag
  IF ~OMITTED(7)
    SELF.Rules.NewText = CLIP(LEFT(pNewText))
  END
  ADD(SELF.Rules)
  RETURN SELF.NextTag


MsgHookClass.ClearRules PROCEDURE()
  CODE
  IF ~SELF.Rules &= NULL
    FREE(SELF.Rules)
  END
  SELF.NextTag = 0


MsgHookClass.SetLog PROCEDURE(STRING pFile,BYTE pFormat=HookLog:Text,BYTE pWhat=HookLogged:All,LONG pMax=0)
  CODE
  SELF.LogName   = CLIP(LEFT(pFile))
  SELF.LogFormat = pFormat
  SELF.LogWhat   = pWhat
  SELF.LogMax    = pMax
  SELF.LogHeaded = 0


! ############################################################################
!  Turning it on and off
! ############################################################################
MsgHookClass.Install PROCEDURE()
  CODE
  mhOwner &= SELF
  IF SELF.Watch[Hook:Message]
    SYSTEM{PROP:MessageHook} = ADDRESS(mhMessage)
  END
  IF SELF.Watch[Hook:Stop]
    SYSTEM{PROP:StopHook} = ADDRESS(mhStop)
  END
  IF SELF.Watch[Hook:Halt]
    SYSTEM{PROP:HaltHook} = ADDRESS(mhHalt)
  END
  IF SELF.Watch[Hook:Assert]
    SYSTEM{PROP:AssertHook}  = ADDRESS(mhAssert)
    SYSTEM{PROP:AssertHook2} = ADDRESS(mhAssert2)
  END
  IF SELF.Watch[Hook:Fatal]
    SYSTEM{PROP:FatalErrorHook} = ADDRESS(mhFatal)
  END
  IF SELF.Watch[Hook:Exception]
    SYSTEM{PROP:LastChanceHook} = ADDRESS(mhExcept)
  END
  SELF.Active = 1


MsgHookClass.Remove PROCEDURE()
  CODE
  IF ~SELF.Active
    RETURN
  END
  IF SELF.Watch[Hook:Message]
    SYSTEM{PROP:MessageHook} = 0
  END
  IF SELF.Watch[Hook:Stop]
    SYSTEM{PROP:StopHook} = 0
  END
  IF SELF.Watch[Hook:Halt]
    SYSTEM{PROP:HaltHook} = 0
  END
  IF SELF.Watch[Hook:Assert]
    SYSTEM{PROP:AssertHook}  = 0
    SYSTEM{PROP:AssertHook2} = 0
  END
  IF SELF.Watch[Hook:Fatal]
    SYSTEM{PROP:FatalErrorHook} = 0
  END
  IF SELF.Watch[Hook:Exception]
    SYSTEM{PROP:LastChanceHook} = 0
  END
  SELF.Active = 0
  mhOwner &= NULL


MsgHookClass.Suspend PROCEDURE()
  CODE
  mhQuiet = 1


MsgHookClass.Resume PROCEDURE()
  CODE
  mhQuiet = 0


MsgHookClass.Suspended PROCEDURE()
  CODE
  RETURN mhQuiet


! ############################################################################
!  The rules
! ############################################################################
MsgHookClass.Decide PROCEDURE()
i    LONG,AUTO
hit  BYTE,AUTO
  CODE
  IF SELF.Rules &= NULL
    RETURN
  END
  LOOP i = 1 TO RECORDS(SELF.Rules)
    GET(SELF.Rules,i)
    IF ERRORCODE()
      BREAK
    END
    IF SELF.Rules.Event AND SELF.Rules.Event <> SELF.Info.Event
      CYCLE
    END
    CASE SELF.Rules.Look
    OF HookIn:Caption
      hit = SELF.Matches(SELF.Info.Caption,SELF.Rules.Match,SELF.Rules.Mode)
    OF HookIn:Either
      hit = SELF.Matches(SELF.Info.Text,SELF.Rules.Match,SELF.Rules.Mode)
      IF ~hit
        hit = SELF.Matches(SELF.Info.Caption,SELF.Rules.Match,SELF.Rules.Mode)
      END
    ELSE
      hit = SELF.Matches(SELF.Info.Text,SELF.Rules.Match,SELF.Rules.Mode)
    END
    IF hit
      SELF.Info.Tag    = SELF.Rules.Tag
      SELF.Info.Action = SELF.Rules.Action
      IF SELF.Rules.Answer
        SELF.Info.Answer = SELF.Rules.Answer
      END
      IF SELF.Rules.NewText
        SELF.Info.Text = SELF.Rules.NewText
      END
      BREAK
    END
  END


MsgHookClass.Matches PROCEDURE(STRING pText,STRING pMatch,LONG pMode)
t  CSTRING(4097)
m  CSTRING(257)
  CODE
  IF pMode = HookMatch:Any
    RETURN 1
  END
  t = UPPER(CLIP(LEFT(pText)))
  m = UPPER(CLIP(LEFT(pMatch)))
  IF ~m
    RETURN 0
  END
  CASE pMode
  OF HookMatch:Contains
    IF INSTRING(m,t,1,1)
      RETURN 1
    END
  OF HookMatch:Starts
    IF LEN(m) <= LEN(t) AND t[1 : LEN(m)] = m
      RETURN 1
    END
  OF HookMatch:Exact
    IF t = m
      RETURN 1
    END
  OF HookMatch:Wild
    RETURN SELF.Wild(t,m)
  END
  RETURN 0


! A plain * / ? matcher with backtracking. Both sides arrive upper-cased.
MsgHookClass.Wild PROCEDURE(STRING pText,STRING pPattern)
s     CSTRING(4097)
p     CSTRING(257)
si    LONG(1)
pi    LONG(1)
star  LONG(0)
mark  LONG(0)
sl    LONG,AUTO
pl    LONG,AUTO
  CODE
  s  = CLIP(pText)
  p  = CLIP(pPattern)
  sl = LEN(s)
  pl = LEN(p)
  LOOP WHILE si <= sl
    IF pi <= pl AND (p[pi] = '?' OR p[pi] = s[si])
      pi += 1
      si += 1
    ELSIF pi <= pl AND p[pi] = '*'
      star = pi
      pi   = pi + 1
      mark = si
    ELSIF star
      pi   = star + 1
      mark = mark + 1
      si   = mark
    ELSE
      RETURN 0
    END
  END
  LOOP WHILE pi <= pl AND p[pi] = '*'
    pi += 1
  END
  RETURN CHOOSE(pi > pl,1,0)


! ############################################################################
!  The six things the RTL can hand us
! ############################################################################
MsgHookClass.OnMessage PROCEDURE(STRING pText,STRING pCaption,STRING pIcon,LONG pButtons,LONG pDefault,LONG pStyle)
  CODE
  SELF.Prepare(Hook:Message)
  SELF.Info.Text      = CLIP(pText)
  SELF.Info.Caption   = CLIP(pCaption)
  SELF.Info.Icon      = CLIP(pIcon)
  SELF.Info.Buttons   = pButtons
  SELF.Info.DefButton = pDefault
  SELF.Info.Style     = pStyle
  IF ~SELF.Info.Answer
    IF pDefault
      SELF.Info.Answer = pDefault
    ELSE
      SELF.Info.Answer = SELF.FirstButton(pButtons)
    END
  END
  IF SELF.Suspended()
    RETURN SELF.PassMessage()
  END
  SELF.Decide()
  IF SELF.Info.Action = HookDo:Call
    SELF.TakeEvent()
  END
  SELF.Finish()
  CASE SELF.Info.Action
  OF HookDo:Ignore OROF HookDo:Log OROF HookDo:Answer
    RETURN SELF.Info.Answer
  OF HookDo:Halt
    SELF.OnHalt(0,SELF.Info.Text)
    RETURN SELF.Info.Answer
  OF HookDo:Show
    RETURN SELF.PassMessage()
  OF HookDo:Call
    IF SELF.Info.Handled
      RETURN SELF.Info.Answer
    END
  END
  RETURN SELF.PassMessage()                     ! HookDo:Normal


MsgHookClass.OnStop PROCEDURE(STRING pText)
  CODE
  SELF.Prepare(Hook:Stop)
  SELF.Info.Text      = CLIP(pText)
  SELF.Info.Caption   = 'Stop'
  SELF.Info.Buttons   = BUTTON:Abort + BUTTON:Ignore
  SELF.Info.DefButton = BUTTON:Abort
  IF ~SELF.Info.Answer
    SELF.Info.Answer = BUTTON:Ignore
  END
  IF SELF.Suspended()
    SELF.PassStop()
    RETURN
  END
  SELF.Decide()
  IF SELF.Info.Action = HookDo:Call
    SELF.TakeEvent()
  END
  SELF.Finish()
  CASE SELF.Info.Action
  OF HookDo:Ignore OROF HookDo:Log OROF HookDo:Answer
    RETURN                                      ! swallowed - the program carries on
  OF HookDo:Halt
    SELF.OnHalt(0,SELF.Info.Text)
    RETURN
  OF HookDo:Show
    SELF.Info.Buttons   = BUTTON:Ok
    SELF.Info.DefButton = BUTTON:Ok
    SELF.PassMessage()
    RETURN
  OF HookDo:Call
    IF SELF.Info.Handled
      RETURN
    END
  END
  SELF.PassStop()                               ! HookDo:Normal


MsgHookClass.OnHalt PROCEDURE(LONG pCode,STRING pText)
  CODE
  SELF.Prepare(Hook:Halt)
  SELF.Info.Code    = pCode
  SELF.Info.Text    = CLIP(pText)
  SELF.Info.Caption = 'Halt'
  IF SELF.Suspended()
    SELF.PassHalt()
    RETURN
  END
  SELF.Decide()
  IF SELF.Info.Action = HookDo:Call
    SELF.TakeEvent()
  END
  SELF.Finish()
  ! A HALT cannot be called off. The run-time library ends the program the
  ! moment this returns, whatever we do here - confirmed by test. What we can
  ! still change is what is said on the way out, and what goes in the log.
  CASE SELF.Info.Action
  OF HookDo:Ignore OROF HookDo:Log OROF HookDo:Answer
    RETURN                                      ! nothing shown - it still stops
  OF HookDo:Show
    IF SELF.Info.Text
      SELF.Info.Buttons   = BUTTON:Ok
      SELF.Info.DefButton = BUTTON:Ok
      SELF.PassMessage()
    END
    RETURN
  OF HookDo:Call
    IF SELF.Info.Handled
      RETURN
    END
  END
  SELF.PassHalt()                               ! HookDo:Normal - and it never comes back


MsgHookClass.OnAssert PROCEDURE(LONG pLine,STRING pModule,STRING pText)
  CODE
  SELF.Prepare(Hook:Assert)
  SELF.Info.Line   = pLine
  SELF.Info.Module = CLIP(pModule)
  SELF.Info.Text   = 'Assertion failed at line ' & pLine & ' of ' & CLIP(pModule)
  IF pText
    SELF.Info.Text = CLIP(SELF.Info.Text) & mh:CRLF & CLIP(pText)
  END
  SELF.Info.Caption   = 'Assertion Failed'
  SELF.Info.Buttons   = BUTTON:Ok
  SELF.Info.DefButton = BUTTON:Ok
  SELF.Decide()
  IF SELF.Info.Action = HookDo:Call
    SELF.TakeEvent()
  END
  SELF.Finish()
  CASE SELF.Info.Action
  OF HookDo:Ignore OROF HookDo:Log OROF HookDo:Answer
    RETURN
  OF HookDo:Show
    SELF.PassMessage()
    RETURN
  OF HookDo:Halt
    SELF.OnHalt(0,SELF.Info.Text)
    RETURN
  OF HookDo:Call
    IF SELF.Info.Handled
      RETURN
    END
  END
  ! HookDo:Normal - the standard question: show it, and stop if they say no
  SELF.Info.Text      = CLIP(SELF.Info.Text) & mh:CRLF & mh:CRLF & 'Continue?'
  SELF.Info.Buttons   = BUTTON:Yes + BUTTON:No
  SELF.Info.DefButton = BUTTON:No
  IF SELF.PassMessage() <> BUTTON:Yes
    SELF.OnHalt(0,'')
  END


MsgHookClass.OnFatal PROCEDURE(LONG pCode,STRING pText)
  CODE
  SELF.Prepare(Hook:Fatal)
  SELF.Info.Code      = pCode
  SELF.Info.Text      = CLIP(pText) & ' (' & pCode & ')'
  SELF.Info.Caption   = 'Run-Time Error'
  SELF.Info.Buttons   = BUTTON:Ok
  SELF.Info.DefButton = BUTTON:Ok
  SELF.Decide()
  IF SELF.Info.Action = HookDo:Call
    SELF.TakeEvent()
  END
  SELF.Finish()
  CASE SELF.Info.Action
  OF HookDo:Ignore OROF HookDo:Log OROF HookDo:Answer
    RETURN                                      ! carrying on after one of these is a gamble
  OF HookDo:Show
    SELF.PassMessage()
    RETURN
  OF HookDo:Call
    IF SELF.Info.Handled
      RETURN
    END
  END
  ! HookDo:Normal / HookDo:Halt - say what happened, then stop
  SELF.PassMessage()
  SELF.OnHalt(0,'')


MsgHookClass.OnException PROCEDURE(LONG pCode,LONG pAddress,STRING pText)
  CODE
  SELF.Prepare(Hook:Exception)
  SELF.Info.Code    = pCode
  SELF.Info.Address = pAddress
  SELF.Info.Caption = 'Program Error'
  SELF.Info.Text    = 'Exception ' & SELF.Hex(pCode) & ' at address ' & SELF.Hex(pAddress)
  IF pText
    SELF.Info.Text = CLIP(SELF.Info.Text) & mh:CRLF & CLIP(pText)
  END
  SELF.Info.Buttons   = BUTTON:Ok
  SELF.Info.DefButton = BUTTON:Ok
  SELF.Decide()
  IF SELF.Info.Action = HookDo:Call
    SELF.TakeEvent()
  END
  SELF.Finish()
  CASE SELF.Info.Action
  OF HookDo:Ignore OROF HookDo:Log OROF HookDo:Answer
    RETURN 0                                    ! 0 = do not kill the thread
  OF HookDo:Halt
    SELF.OnHalt(0,'')
    RETURN 1
  OF HookDo:Call
    IF SELF.Info.Handled
      RETURN 0
    END
  END
  SELF.PassMessage()                            ! HookDo:Normal / HookDo:Show
  RETURN 1                                      ! 1 = kill the thread it happened on


! ############################################################################
!  Shared plumbing
! ############################################################################
MsgHookClass.Prepare PROCEDURE(LONG pEvent)
  CODE
  CLEAR(SELF.Info)
  SELF.Info.Event  = pEvent
  SELF.Info.Thread = THREAD()
  SELF.Info.Action = SELF.Action[pEvent]
  SELF.Info.Answer = SELF.Answer[pEvent]
  IF SELF.LogWindow AND pEvent <> Hook:Exception
    SELF.Info.Window = CLIP(0{PROP:Text})
  END
  SELF.Seen[pEvent] += 1


MsgHookClass.Finish PROCEDURE()
  CODE
  IF SELF.Info.Action <> HookDo:Normal
    SELF.Changed[SELF.Info.Event] += 1
  END
  IF SELF.LogName AND SELF.LogFormat <> HookLog:Off
    IF SELF.LogWhat = HookLogged:All OR SELF.Info.Action <> HookDo:Normal
      SELF.Log()
    END
  END


MsgHookClass.TakeEvent PROCEDURE()
  CODE
  ! nothing here on purpose - derive this and read SELF.Info


MsgHookClass.FirstButton PROCEDURE(LONG pButtons)
  CODE
  IF BAND(pButtons,BUTTON:Ok)     THEN RETURN BUTTON:Ok.
  IF BAND(pButtons,BUTTON:Yes)    THEN RETURN BUTTON:Yes.
  IF BAND(pButtons,BUTTON:No)     THEN RETURN BUTTON:No.
  IF BAND(pButtons,BUTTON:Retry)  THEN RETURN BUTTON:Retry.
  IF BAND(pButtons,BUTTON:Ignore) THEN RETURN BUTTON:Ignore.
  IF BAND(pButtons,BUTTON:Cancel) THEN RETURN BUTTON:Cancel.
  IF BAND(pButtons,BUTTON:Abort)  THEN RETURN BUTTON:Abort.
  RETURN BUTTON:Ok


! To let one through we have to lift our own hook first, or the RTL would call
! straight back into us. Same trick the shipped WBHOOK.CLW / ICSERVER.CLW use.
MsgHookClass.PassMessage PROCEDURE()
saved  LONG,AUTO
answer LONG,AUTO
  CODE
  saved = SYSTEM{PROP:MessageHook}
  SYSTEM{PROP:MessageHook} = 0
  answer = MESSAGE(SELF.Info.Text,SELF.Info.Caption,SELF.Info.Icon, |
                   SELF.Info.Buttons,SELF.Info.DefButton,SELF.Info.Style)
  SYSTEM{PROP:MessageHook} = saved
  RETURN answer


MsgHookClass.PassStop PROCEDURE()
saved  LONG,AUTO
  CODE
  saved = SYSTEM{PROP:StopHook}
  SYSTEM{PROP:StopHook} = 0
  STOP(SELF.Info.Text)
  SYSTEM{PROP:StopHook} = saved


MsgHookClass.PassHalt PROCEDURE()
  CODE
  SYSTEM{PROP:HaltHook} = 0                     ! HALT does not return, so no putting it back
  IF SELF.Info.Text
    HALT(SELF.Info.Code,SELF.Info.Text)
  ELSE
    HALT(SELF.Info.Code)
  END


! ############################################################################
!  The log
! ############################################################################
MsgHookClass.Log PROCEDURE()
line  CSTRING(5121)
  CODE
  IF SELF.LogFormat = HookLog:CSV AND ~SELF.LogHeaded
    SELF.LogHeaded = 1
    IF ~SELF.LogSize()                             ! a brand new file - name the columns
      SELF.Write('"When","Event","What we did","Thread","Window","Caption",' & |
                 '"Text","Answer","Module","Line","Code"')
    END
  END
  CASE SELF.LogFormat
  OF HookLog:CSV
    line = SELF.Csv(SELF.Stamp())              & ',' & |
           SELF.Csv(SELF.EventName(SELF.Info.Event))  & ',' & |
           SELF.Csv(SELF.ActionName(SELF.Info.Action))& ',' & |
           SELF.Info.Thread                    & ',' & |
           SELF.Csv(SELF.Info.Window)          & ',' & |
           SELF.Csv(SELF.Info.Caption)         & ',' & |
           SELF.Csv(SELF.Flat(SELF.Info.Text)) & ',' & |
           SELF.Csv(SELF.ButtonName(SELF.Info.Answer))& ',' & |
           SELF.Csv(SELF.Info.Module)          & ',' & |
           SELF.Info.Line                      & ',' & |
           SELF.Info.Code
  OF HookLog:Tab
    line = SELF.Stamp()                        & '<9>' & |
           SELF.EventName(SELF.Info.Event)     & '<9>' & |
           SELF.ActionName(SELF.Info.Action)   & '<9>' & |
           SELF.Info.Thread                    & '<9>' & |
           SELF.Info.Window                    & '<9>' & |
           SELF.Info.Caption                   & '<9>' & |
           SELF.Flat(SELF.Info.Text)           & '<9>' & |
           SELF.ButtonName(SELF.Info.Answer)   & '<9>' & |
           SELF.Info.Module                    & '<9>' & |
           SELF.Info.Line                      & '<9>' & |
           SELF.Info.Code
  ELSE
    ! Every piece carries its own leading separator - CLIP() would otherwise
    ! swallow a trailing one and run the columns together.
    IF SELF.LogStamp
      line = SELF.Stamp() & '  ['
    ELSE
      line = '['
    END
    line = CLIP(line) & SELF.EventName(SELF.Info.Event) & ']'
    IF SELF.Info.Caption
      line = CLIP(line) & '  "' & CLIP(SELF.Info.Caption) & '"'
    END
    line = CLIP(line) & '  ' & SELF.Flat(SELF.Info.Text)
    IF SELF.Info.Module
      line = CLIP(line) & '  (' & CLIP(SELF.Info.Module) & ' line ' & SELF.Info.Line & ')'
    END
    line = CLIP(line) & '  -> ' & SELF.ActionName(SELF.Info.Action)
    IF SELF.Info.Action = HookDo:Answer OR SELF.Info.Action = HookDo:Ignore
      line = CLIP(line) & ' ' & SELF.ButtonName(SELF.Info.Answer)
    END
    line = CLIP(line) & '  {thread ' & SELF.Info.Thread
    IF SELF.Info.Window
      line = CLIP(line) & ', ' & CLIP(SELF.Info.Window)
    END
    line = CLIP(line) & '}'
  END
  SELF.Write(line)


! Appends one line. Opened for append and closed again every time, so several
! threads - or several copies of the program - can share the one file, and a
! HALT on the very next statement still leaves the line on disk.
MsgHookClass.Write PROCEDURE(STRING pLine)
h     LONG,AUTO
nm    CSTRING(261)
buf   STRING(5250)
body  LONG,AUTO
len   ULONG,AUTO
wr    ULONG,AUTO
  CODE
  IF ~SELF.LogName
    RETURN
  END
  SELF.Roll()
  nm   = CLIP(SELF.LogName)
  body = LEN(CLIP(pLine))
  IF body > SIZE(buf) - 2
    body = SIZE(buf) - 2
  END
  IF body > 0
    buf[1 : body] = pLine[1 : body]
  END
  buf[body + 1] = '<13>'
  buf[body + 2] = '<10>'
  len = body + 2
  h = mhCreateFile(nm,mh:Append,mh:ShareRW,0,mh:OpenAlways,mh:Normal,0)
  IF h = 0 OR h = -1
    RETURN                                      ! no log is better than a crash
  END
  wr = 0
  mhWriteFile(h,buf,len,wr,0)
  mhCloseHandle(h)


! How many bytes are in the log at the moment. 0 if it is not there yet.
! Not called Size - that shadows Clarion's own SIZE() inside the class.
MsgHookClass.LogSize PROCEDURE()
h    LONG,AUTO
sz   ULONG,AUTO
nm   CSTRING(261)
  CODE
  IF ~SELF.LogName
    RETURN 0
  END
  nm = CLIP(SELF.LogName)
  h  = mhCreateFile(nm,mh:Read,mh:ShareRW,0,mh:OpenExisting,mh:Normal,0)
  IF h = 0 OR h = -1
    RETURN 0                                    ! not there yet
  END
  sz = mhFileSize(h,0)
  mhCloseHandle(h)
  RETURN sz


! Rolls the log over to a .bak once it passes SELF.LogMax bytes.
MsgHookClass.Roll PROCEDURE()
nm   CSTRING(261)
bak  CSTRING(265)
  CODE
  IF ~SELF.LogMax OR ~SELF.LogName
    RETURN
  END
  IF SELF.LogSize() < SELF.LogMax
    RETURN
  END
  nm = CLIP(SELF.LogName)
  bak = CLIP(nm) & '.bak'
  mhDeleteFile(bak)
  mhMoveFile(nm,bak)


! ############################################################################
!  Small change
! ############################################################################
MsgHookClass.Stamp PROCEDURE()
d    LONG,AUTO
cs   LONG,AUTO
hh   LONG,AUTO
mm   LONG,AUTO
ss   LONG,AUTO
  CODE
  d  = TODAY()
  cs = CLOCK() - 1
  IF cs < 0
    cs = 0
  END
  hh = INT(cs / 360000)
  cs = cs - hh * 360000
  mm = INT(cs / 6000)
  cs = cs - mm * 6000
  ss = INT(cs / 100)
  RETURN SELF.Pad(YEAR(d),4) & '-' & SELF.Pad(MONTH(d),2) & '-' & SELF.Pad(DAY(d),2) & |
         ' ' & SELF.Pad(hh,2) & ':' & SELF.Pad(mm,2) & ':' & SELF.Pad(ss,2)


! Numeric -> text the safe way: assignment, not a picture. @N pictures group
! with commas whatever you do to them.
MsgHookClass.Pad PROCEDURE(LONG pValue,LONG pWidth)
s  CSTRING(24)
  CODE
  s = pValue
  LOOP WHILE LEN(s) < pWidth
    s = '0' & s
  END
  RETURN s


MsgHookClass.Hex PROCEDURE(LONG pValue)
s       STRING(8),AUTO
digits  STRING('0123456789ABCDEF'),STATIC
i       LONG,AUTO
v       LONG,AUTO
  CODE
  v = pValue
  i = SIZE(s)
  LOOP WHILE i <> 0
    s[i] = digits[BAND(v,0FH) + 1]
    v    = BSHIFT(v,-4)
    i   -= 1
  END
  RETURN '0' & s & 'H'


! Squashes a multi-line message down to one line for the log. Built by index,
! not by CLIP() and concatenate - that would eat every space in the message.
MsgHookClass.Flat PROCEDURE(STRING pText)
s   CSTRING(4097)
o   STRING(4200)
n   LONG(0)
i   LONG,AUTO
c   STRING(1),AUTO
gap BYTE(0)
  CODE
  s = CLIP(pText)
  LOOP i = 1 TO LEN(s)
    c = s[i]
    IF c = '<13>' OR c = '<10>' OR c = '|'
      gap = 1
    ELSE
      IF gap AND n AND n + 3 <= SIZE(o)
        o[n + 1 : n + 3] = ' | '
        n += 3
      END
      gap = 0
      IF n < SIZE(o)
        n += 1
        o[n] = c
      END
    END
  END
  IF ~n
    RETURN ''
  END
  RETURN o[1 : n]


MsgHookClass.Csv PROCEDURE(STRING pField)
s  CSTRING(5121)
o  STRING(5150)
n  LONG(1)
i  LONG,AUTO
c  STRING(1),AUTO
  CODE
  s    = CLIP(pField)
  o[1] = '"'
  LOOP i = 1 TO LEN(s)
    c = s[i]
    IF c = '"'
      IF n + 2 > SIZE(o) - 1
        BREAK
      END
      o[n + 1 : n + 2] = '""'
      n += 2
    ELSE
      IF n + 1 > SIZE(o) - 1
        BREAK
      END
      n += 1
      o[n] = c
    END
  END
  n += 1
  o[n] = '"'
  RETURN o[1 : n]


MsgHookClass.EventName PROCEDURE(LONG pEvent)
  CODE
  CASE pEvent
  OF Hook:Message   ; RETURN 'MESSAGE'
  OF Hook:Stop      ; RETURN 'STOP'
  OF Hook:Halt      ; RETURN 'HALT'
  OF Hook:Assert    ; RETURN 'ASSERT'
  OF Hook:Fatal     ; RETURN 'ERROR'
  OF Hook:Exception ; RETURN 'GPF'
  END
  RETURN 'EVENT ' & pEvent


MsgHookClass.ActionName PROCEDURE(LONG pAction)
  CODE
  CASE pAction
  OF HookDo:Normal ; RETURN 'shown as usual'
  OF HookDo:Ignore ; RETURN 'ignored'
  OF HookDo:Answer ; RETURN 'answered'
  OF HookDo:Call   ; RETURN 'handed to your code'
  OF HookDo:Show   ; RETURN 'shown as a message'
  OF HookDo:Halt   ; RETURN 'halted'
  OF HookDo:Log    ; RETURN 'logged only'
  END
  RETURN 'action ' & pAction


MsgHookClass.ButtonName PROCEDURE(LONG pButton)
  CODE
  CASE pButton
  OF BUTTON:Ok     ; RETURN 'Ok'
  OF BUTTON:Yes    ; RETURN 'Yes'
  OF BUTTON:No     ; RETURN 'No'
  OF BUTTON:Abort  ; RETURN 'Abort'
  OF BUTTON:Retry  ; RETURN 'Retry'
  OF BUTTON:Ignore ; RETURN 'Ignore'
  OF BUTTON:Cancel ; RETURN 'Cancel'
  OF BUTTON:Help   ; RETURN 'Help'
  END
  RETURN ''
