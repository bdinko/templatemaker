!ABCIncludeFile(MYHOOK)
! ============================================================================
!  MsgHookClass - take MESSAGE, STOP, HALT, ASSERT, run-time errors and GPFs
!  away from the Clarion run-time library and decide for yourself what happens.
!
!  WHAT THIS IS BUILT ON
!  ---------------------
!  The RTL will hand its own dialogs over to your code if you give it the
!  address of a replacement procedure:
!
!     SYSTEM{PROP:MessageHook}     every MESSAGE()
!     SYSTEM{PROP:StopHook}        every STOP()
!     SYSTEM{PROP:HaltHook}        every HALT()
!     SYSTEM{PROP:AssertHook}      every failed ASSERT()
!     SYSTEM{PROP:AssertHook2}     the same, with the assertion text
!     SYSTEM{PROP:FatalErrorHook}  run-time errors
!     SYSTEM{PROP:LastChanceHook}  GPFs and other unhandled exceptions
!
!  Those are the same hooks the shipped WebBuilder layer uses to move a desktop
!  MESSAGE onto a web page (see \clarion12\libsrc\win\WBHOOK.CLW). This class
!  wraps all seven, adds a rule table, a log, and a place for your own code.
!
!  WHAT YOU CAN DO WITH ONE
!  ------------------------
!     HookDo:Normal   let it through - behave exactly as if we were not here
!     HookDo:Ignore   swallow it and carry on
!     HookDo:Answer   swallow it and answer for the user (MESSAGE only)
!     HookDo:Call     hand it to a procedure of yours, then do what it says
!     HookDo:Show     show it as a plain MESSAGE, then carry on
!     HookDo:Halt     end the program
!     HookDo:Log      write it to the log and swallow it
!
!  Each of the six events gets a default action. On top of that you can add
!  rules that test the text - contains / starts with / is exactly / matches a
!  * ? pattern - and give a matching one its own action. Rules are checked in
!  the order they were added; the first one that matches wins; if none match,
!  the event's default action applies.
!
!  THE LOG
!  -------
!  SetLog() names a text file and everything that comes through is appended to
!  it - readable text, CSV or tab separated - with the date, the time, the
!  thread, the window that was on screen, what the message said and what we did
!  about it. The file is opened for append and closed on every line, so it is
!  safe across threads and survives a HALT. Give it a size limit and it rolls
!  over to a .bak of its own accord.
!
!  YOUR OWN CODE
!  -------------
!  TakeEvent() is VIRTUAL and does nothing. Derive it, read SELF.Info, and set
!  SELF.Info.Action / SELF.Info.Answer to say what should happen next:
!
!     MsgHook   CLASS(MsgHookClass)
!     TakeEvent   PROCEDURE(),DERIVED
!               END
!
!     MsgHook.TakeEvent PROCEDURE()
!       CODE
!       IF INSTRING('Record Not Found',SELF.Info.Text,1,1)
!         SELF.Info.Action = HookDo:Ignore              ! never show this one
!       END
!
!  SELF.Info.Tag carries the number of the rule that fired (0 = no rule), so
!  one TakeEvent can route to as many of your procedures as you like.
!
!  USAGE
!    INCLUDE('MsgHookClass.INC'),ONCE
!    MsgHook  MsgHookClass                              ! one per program
!
!      MsgHook.Init()
!      MsgHook.SetEvent(Hook:Message, HookDo:Log)       ! log every MESSAGE
!      MsgHook.SetEvent(Hook:Halt,    HookDo:Ignore)    ! refuse to be halted
!      MsgHook.AddRule(Hook:Message,'Record Not Found', HookMatch:Contains, |
!                      HookDo:Answer, BUTTON:Ok)
!      MsgHook.SetLog('.\myHook.log', HookLog:Text)
!      MsgHook.Install()
!      ...
!      MsgHook.Remove()                                 ! or let Kill() do it
!
!  ONE PER PROGRAM. The hooks are process-wide, so the last object to call
!  Install() is the one the RTL talks to.
!
!  HALT IS THE ONE YOU CANNOT CALL OFF. The run-time library ends the program
!  as soon as the halt hook returns, whichever action you picked - tested, not
!  assumed. What the hook CAN do with a HALT is see it, log it, replace what it
!  says on the way out, or say nothing at all. A STOP, by contrast, really can
!  be ignored: HookDo:Ignore on a STOP returns to the line after it.
!
!  A WORD ON PASSING THINGS THROUGH. To show a message the normal way we have
!  to take our own hook off first, or the RTL would call us straight back. That
!  gap is a few milliseconds wide and process-wide, so a MESSAGE raised on
!  another thread during it goes out un-intercepted. The RTL's own hook code
!  does exactly the same thing (WBHOOK.CLW, ICSERVER.CLW). If that matters,
!  answer rather than pass through.
!
!  FILES: MsgHookClass.inc + MsgHookClass.clw on the redirection path (the app
!         folder, or \clarion12\libsrc\win). ANSI, CRLF.
! ============================================================================

! ---- which of the run-time's own dialogs fired -----------------------------
Hook:Message       EQUATE(1)                   ! MESSAGE()
Hook:Stop          EQUATE(2)                   ! STOP()
Hook:Halt          EQUATE(3)                   ! HALT()
Hook:Assert        EQUATE(4)                   ! a failed ASSERT()
Hook:Fatal         EQUATE(5)                   ! a run-time error
Hook:Exception     EQUATE(6)                   ! a GPF / unhandled exception
Hook:Events        EQUATE(6)                   ! how many of the above there are
Hook:Any           EQUATE(0)                   ! a rule that is not fussy

! ---- what to do about it ---------------------------------------------------
HookDo:Normal      EQUATE(0)                   ! behave as if we were not here
HookDo:Ignore      EQUATE(1)                   ! swallow it and carry on
HookDo:Answer      EQUATE(2)                   ! swallow it, answer for the user
HookDo:Call        EQUATE(3)                   ! hand it to TakeEvent()
HookDo:Show        EQUATE(4)                   ! show it as a plain MESSAGE
HookDo:Halt        EQUATE(5)                   ! end the program
HookDo:Log         EQUATE(6)                   ! log it and swallow it

! ---- how a rule tests the text ---------------------------------------------
HookMatch:Any      EQUATE(0)                   ! everything matches
HookMatch:Contains EQUATE(1)                   ! the text appears anywhere in it
HookMatch:Starts   EQUATE(2)                   ! the text is at the front
HookMatch:Exact    EQUATE(3)                   ! the whole thing, trimmed
HookMatch:Wild     EQUATE(4)                   ! a * and ? pattern

! ---- what a rule looks at --------------------------------------------------
HookIn:Text        EQUATE(0)                   ! the body of the message
HookIn:Caption     EQUATE(1)                   ! the title bar
HookIn:Either      EQUATE(2)                   ! either of them

! ---- how the log is written ------------------------------------------------
HookLog:Off        EQUATE(0)
HookLog:Text       EQUATE(1)                   ! one readable line per event
HookLog:CSV        EQUATE(2)                   ! comma separated, quoted
HookLog:Tab        EQUATE(3)                   ! tab separated

! ---- what gets logged ------------------------------------------------------
HookLogged:Changed EQUATE(0)                   ! only the ones we interfered with
HookLogged:All     EQUATE(1)                   ! every one that came through

! ============================================================================
!  Everything known about one intercepted event. SELF.Info is filled in before
!  TakeEvent() is called and read again afterwards.
! ============================================================================
HookInfoGroup      GROUP,TYPE
Event                LONG                      ! Hook:Message .. Hook:Exception
Text                 CSTRING(4097)             ! the body of it
Caption              CSTRING(257)              ! the title bar
Icon                 CSTRING(65)               ! the MESSAGE icon
Buttons              LONG                      ! BUTTON:Ok + BUTTON:Cancel + ...
DefButton            LONG                      ! which of them was the default
Style                LONG                      ! the MESSAGE style flag
Line                 LONG                      ! ASSERT - the source line
Module               CSTRING(257)              ! ASSERT - the source file
Code                 LONG                      ! HALT return code / error number
Address              LONG                      ! GPF - where it blew up
Thread               LONG                      ! the thread it happened on
Window               CSTRING(129)              ! the window that was on screen
Tag                  LONG                      ! the rule that fired (0 = none)
Action               LONG                      ! IN and OUT - HookDo:xxx
Answer               LONG                      ! the button to hand back
Handled              BYTE                      ! 1 = dealt with, do nothing more
                   END

! ============================================================================
!  One rule. Checked in the order they were added; the first match wins.
! ============================================================================
HookRuleQueue      QUEUE,TYPE
Event                LONG                      ! Hook:Any, or one Hook:xxx
Look                 LONG                      ! HookIn:Text / Caption / Either
Mode                 LONG                      ! HookMatch:xxx
Match                CSTRING(257)              ! what to look for
Action               LONG                      ! HookDo:xxx
Answer               LONG                      ! the button, for HookDo:Answer
NewText              CSTRING(257)              ! replacement text, for HookDo:Show
Tag                  LONG                      ! handed to TakeEvent as Info.Tag
                   END

! ============================================================================
MsgHookClass       CLASS,TYPE,MODULE('MsgHookClass.CLW'),LINK('MsgHookClass.CLW')
! ---- what happened (read this from TakeEvent) ------------------------------
Info                 LIKE(HookInfoGroup)
! ---- the default action for each event -------------------------------------
Watch                BYTE,DIM(Hook:Events)     ! 1 = we take this one over
Action               LONG,DIM(Hook:Events)     ! HookDo:xxx
Answer               LONG,DIM(Hook:Events)     ! the button, for HookDo:Answer
! ---- the log ---------------------------------------------------------------
LogName              CSTRING(261)              ! '' = no log
LogFormat            BYTE(HookLog:Text)
LogWhat              BYTE(HookLogged:All)
LogStamp             BYTE(1)                   ! put the date and time in front
LogWindow            BYTE(1)                   ! record the window on screen
LogMax               LONG(0)                   ! bytes, 0 = let it grow
! ---- housekeeping ----------------------------------------------------------
Active               BYTE,PROTECTED            ! the hooks are in place
LogHeaded            BYTE,PROTECTED            ! the CSV heading row has been dealt with
Seen                 LONG,DIM(Hook:Events)     ! how many came through
Changed              LONG,DIM(Hook:Events)     ! how many we interfered with
Rules                &HookRuleQueue,PROTECTED
NextTag              LONG,PROTECTED

Construct            PROCEDURE()
Destruct             PROCEDURE()
Init                 PROCEDURE()
Kill                 PROCEDURE()

! ---- setting it up ---------------------------------------------------------
SetEvent             PROCEDURE(LONG pEvent,LONG pAction,LONG pAnswer=0)
AddRule              PROCEDURE(LONG pEvent,STRING pMatch,LONG pMode=HookMatch:Contains,LONG pAction=HookDo:Ignore,LONG pAnswer=0,LONG pLook=HookIn:Either,<STRING pNewText>),LONG,PROC
ClearRules           PROCEDURE()
SetLog               PROCEDURE(STRING pFile,BYTE pFormat=HookLog:Text,BYTE pWhat=HookLogged:All,LONG pMax=0)

! ---- turning it on and off -------------------------------------------------
Install              PROCEDURE()
Remove               PROCEDURE()
Suspend              PROCEDURE()                ! stop intercepting, this thread
Resume               PROCEDURE()                ! start again, this thread
Suspended            PROCEDURE(),BYTE

! ---- yours to derive -------------------------------------------------------
TakeEvent            PROCEDURE(),VIRTUAL        ! read SELF.Info, set .Action
Decide               PROCEDURE(),VIRTUAL        ! run the rules over SELF.Info
Log                  PROCEDURE(),VIRTUAL        ! write SELF.Info to the log

! ---- odds and ends you may want --------------------------------------------
Write                PROCEDURE(STRING pLine)    ! append one raw line to the log
EventName            PROCEDURE(LONG pEvent),STRING
ActionName           PROCEDURE(LONG pAction),STRING
ButtonName           PROCEDURE(LONG pButton),STRING
Flat                 PROCEDURE(STRING pText),STRING   ! newlines -> ' | '
Stamp                PROCEDURE(),STRING         ! 'YYYY-MM-DD HH:MM:SS'
Hex                  PROCEDURE(LONG pValue),STRING
Pad                  PROCEDURE(LONG pValue,LONG pWidth),STRING

! ---- what the RTL ends up calling. Not for you to call. --------------------
OnMessage            PROCEDURE(STRING pText,STRING pCaption,STRING pIcon,LONG pButtons,LONG pDefault,LONG pStyle),LONG
OnStop               PROCEDURE(STRING pText)
OnHalt               PROCEDURE(LONG pCode,STRING pText)
OnAssert             PROCEDURE(LONG pLine,STRING pModule,STRING pText)
OnFatal              PROCEDURE(LONG pCode,STRING pText)
OnException          PROCEDURE(LONG pCode,LONG pAddress,STRING pText),LONG

! ---- inside ----------------------------------------------------------------
Matches              PROCEDURE(STRING pText,STRING pMatch,LONG pMode),BYTE,PROTECTED
Wild                 PROCEDURE(STRING pText,STRING pPattern),BYTE,PROTECTED
Prepare              PROCEDURE(LONG pEvent),PROTECTED
Finish               PROCEDURE(),PROTECTED
FirstButton          PROCEDURE(LONG pButtons),LONG,PROTECTED
PassMessage          PROCEDURE(),LONG,PROC,PROTECTED
PassStop             PROCEDURE(),PROTECTED
PassHalt             PROCEDURE(),PROTECTED
Csv                  PROCEDURE(STRING pField),STRING,PROTECTED
LogSize              PROCEDURE(),LONG,PROTECTED
Roll                 PROCEDURE(),PROTECTED
                   END
