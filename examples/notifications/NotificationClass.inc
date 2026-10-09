!ABCIncludeFile(NOTIFICATIONS)
! ============================================================================
!  NotificationClass - real Windows notifications (toasts) from Clarion.
!
!  The notifications that slide in at the bottom-right of the screen and stay
!  in the Windows notification centre, like Outlook's or Teams'. Text, app
!  logo (round or square), hero banner, inline picture, attribution line,
!  progress bar, buttons, a reply box, a drop-down choice, sounds, and the
!  reminder / alarm / urgent scenarios.
!
!  The engine is toastc.c, compiled into the program by Clarion's own C
!  compiler (PRAGMA in NotificationClass.clw). It talks to Windows directly,
!  so there is no DLL, no OCX and no .NET to ship.
!
!  THREE WAYS TO SAY WHAT IT LOOKS LIKE
!    1. Quick       Notifier.Toast('Backup finished', '412 files, 3.2 GB')
!    2. Builder     Notifier.NewToast('action=open')
!                   Notifier.Title('Invoice 1043 paid')
!                   Notifier.Line('Acme Ltd paid $1,250.00')
!                   Notifier.AppLogo('images\acme.png')
!                   Notifier.AddButton('Open invoice', 'action=open;id=1043')
!                   Notifier.ShowToast('inv1043')
!    3. A design    made in the Notification Designer and saved as a .ntf:
!                   Notifier.LoadDesign('designs\paid.ntf')
!                   Notifier.SetVar('Customer', CUS:Name)   ! fills {Customer}
!                   Notifier.ShowToast()
!                   (the notifications template embeds the design in the
!                   program instead, with AddXml - no file to deploy)
!
!  WHEN THE USER CLICKS
!    Windows reports clicks, button presses, replies and dismissals on a
!    background thread; toastc.c queues them. Drain the queue from a window
!    (the template does it on EVENT:Timer):
!        LOOP WHILE Notifier.NextEvent()
!          IF Notifier.EventKind = Notify:Activated
!            CASE Notifier.Arg('action')
!            OF 'open'  ; ...
!            OF 'reply' ; Msg = Notifier.Input('reply')
!            END
!          END
!        END
!
!  IMAGES: a relative path is taken from ImageFolder (default: the folder
!  the program runs from; for LoadDesign, the folder of the design). PNG,
!  JPG or GIF, local files. Windows shows nothing for a missing picture.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================

Notify:Activated     EQUATE(1)     ! the body or a button was clicked
Notify:Dismissed     EQUATE(2)     ! closed, timed out, or hidden
Notify:Failed        EQUATE(3)     ! Windows refused to show it

Notify:UserCanceled  EQUATE(0)     ! DismissReason values
Notify:AppHidden     EQUATE(1)
Notify:TimedOut      EQUATE(2)

NotifyVarQ           QUEUE,TYPE
Name                   CSTRING(65)
UName                  CSTRING(65)
Value                  STRING(2048)
                     END

!--- a growable text buffer --------------------------------------------------
NotifyBufClass       CLASS,TYPE,MODULE('NotificationClass.clw'),LINK('NotificationClass.clw',_NotificationsLinkMode_),DLL(_NotificationsDllMode_)
S                      &STRING
L                      LONG
Add                    PROCEDURE(STRING pText)
Reset                  PROCEDURE()
Len                    PROCEDURE(),LONG
Text                   PROCEDURE(),STRING
Destruct               PROCEDURE()
                     END

!--- the notifier -------------------------------------------------------------
NotificationClass    CLASS,TYPE,MODULE('NotificationClass.clw'),LINK('NotificationClass.clw',_NotificationsLinkMode_),DLL(_NotificationsDllMode_)
AppId                  CSTRING(129)    ! who the notification comes from (AppUserModelID)
DisplayName            CSTRING(129)    ! the name Windows shows on it
IconFile               CSTRING(261)    ! .png/.ico shown as the app icon
ImageFolder            CSTRING(261)    ! base for relative image paths ('' = program folder)
LastId                 LONG            ! id of the last notification shown
LastTag                CSTRING(65)     ! its tag (made up when you gave none)
LastError              LONG            ! HRESULT of the last failure
! --- the event last taken by NextEvent() ---
EventKind              LONG            ! Notify:Activated / Dismissed / Failed
EventId                LONG            ! which notification (as returned by ShowToast)
EventTag               CSTRING(65)     ! its tag
EventArgs              CSTRING(2049)   ! launch / button arguments
DismissReason          LONG            ! Notify:UserCanceled / AppHidden / TimedOut
FailCode               LONG            ! HRESULT when EventKind = Notify:Failed
! --- private ---
Xml                    &NotifyBufClass,PROTECTED     ! raw XML (AddXml / LoadDesign)
Vis                    &NotifyBufClass,PROTECTED     ! builder: inside <binding>
Inp                    &NotifyBufClass,PROTECTED     ! builder: <input> elements
Act                    &NotifyBufClass,PROTECTED     ! builder: <action> elements
Out                    &NotifyBufClass,PROTECTED     ! the final XML
Vars                   &NotifyVarQ,PROTECTED         ! {placeholders}
Data                   &NotifyVarQ,PROTECTED         ! {bindings} (progress)
Tmp                    &STRING,PROTECTED
Launch                 CSTRING(1025),PROTECTED
ScenarioName           CSTRING(21),PROTECTED
LongDur                BYTE,PROTECTED
AudioSrc               CSTRING(261),PROTECTED
AudioLoop              BYTE,PROTECTED
AudioOff               BYTE,PROTECTED
Styled                 BYTE,PROTECTED
BaseFolder             CSTRING(261),PROTECTED        ! folder of the loaded design
Seq                    LONG,PROTECTED
AutoTag                LONG,PROTECTED

Construct              PROCEDURE()
Destruct               PROCEDURE()

! --- set up / tear down ---
Init                   PROCEDURE(STRING pAppId, <STRING pDisplayName>, <STRING pIconFile>, <STRING pIconBack>),BYTE,PROC
Kill                   PROCEDURE()                   ! once, at the end of the program
Ready                  PROCEDURE(),BYTE              ! has Init succeeded (on any thread)
Enabled                PROCEDURE(),BYTE              ! has the user switched us off in Settings
Unregister             PROCEDURE()                   ! remove the per-user registration
UseUtf8                PROCEDURE(BYTE pOn=1)         ! strings are UTF-8 instead of ANSI
ErrorText              PROCEDURE(),STRING
FailText               PROCEDURE(LONG pCode=0),STRING   ! words for FailCode (Notify:Failed)

! --- quick ---
Toast                  PROCEDURE(STRING pTitle, <STRING pBody>, <STRING pImage>, <STRING pTag>),LONG,PROC

! --- builder ---
NewToast               PROCEDURE(<STRING pLaunchArgs>)
Title                  PROCEDURE(STRING pText)
Line                   PROCEDURE(STRING pText)
Attribution            PROCEDURE(STRING pText)
AppLogo                PROCEDURE(STRING pImage, BYTE pCircle=1)
HeroImage              PROCEDURE(STRING pImage)
InlineImage            PROCEDURE(STRING pImage)
ProgressBar            PROCEDURE(<STRING pTitle>, <STRING pStatus>, REAL pValue=0, <STRING pValueText>)
AddButton              PROCEDURE(STRING pCaption, STRING pArgs, <STRING pImage>, <STRING pStyle>, <STRING pInputId>)
AddLinkButton          PROCEDURE(STRING pCaption, STRING pUrl)
AddSystemButton        PROCEDURE(STRING pKind, <STRING pCaption>)   ! 'snooze' or 'dismiss'
AddTextBox             PROCEDURE(STRING pId, <STRING pPlaceholder>, <STRING pTitle>)
AddChoice              PROCEDURE(STRING pId, STRING pChoices, <STRING pDefault>, <STRING pTitle>)
Scenario               PROCEDURE(STRING pScenario)  ! reminder / alarm / incomingCall / urgent
LongDuration           PROCEDURE(BYTE pOn=1)
Sound                  PROCEDURE(STRING pSound, BYTE pLoop=0)       ! ms-winsoundevent:Notification.Mail ...
NoSound                PROCEDURE()

! --- raw XML and designs ---
Reset                  PROCEDURE()                   ! forget XML, builder, variables and data
AddXml                 PROCEDURE(STRING pXml)
LoadDesign             PROCEDURE(STRING pFileName),BYTE,PROC
SetVar                 PROCEDURE(STRING pName, STRING pValue)
ClearVars              PROCEDURE()
SetData                PROCEDURE(STRING pKey, STRING pValue)
XmlText                PROCEDURE(),STRING            ! what ShowToast would send

! --- show / change / remove ---
ShowToast              PROCEDURE(<STRING pTag>, <STRING pGroup>, BYTE pSilent=0),LONG,PROC
UpdateData             PROCEDURE(<STRING pTag>, <STRING pGroup>),LONG,PROC
UpdateProgress         PROCEDURE(REAL pValue, <STRING pStatus>, <STRING pValueText>, <STRING pTag>, <STRING pGroup>),LONG,PROC
Hide                   PROCEDURE(LONG pId=0),BYTE,PROC
Remove                 PROCEDURE(STRING pTag, <STRING pGroup>),BYTE,PROC
RemoveGroup            PROCEDURE(STRING pGroup),BYTE,PROC
RemoveAll              PROCEDURE(),BYTE,PROC

! --- events ---
Pending                PROCEDURE(),LONG
NextEvent              PROCEDURE(),BYTE
Arg                    PROCEDURE(STRING pKey),STRING
Input                  PROCEDURE(STRING pId),STRING
BringToFront           PROCEDURE(LONG pHandle),BYTE,PROC     ! 0{PROP:Handle} of the window to raise

! --- helpers ---
Escape                 PROCEDURE(STRING pText),STRING
FileUri                PROCEDURE(STRING pPath),STRING,VIRTUAL
Assemble               PROCEDURE(),PROTECTED
Substitute             PROCEDURE(STRING pXml),PROTECTED
IsName                 PROCEDURE(STRING pText),BYTE,PROTECTED
                     END
