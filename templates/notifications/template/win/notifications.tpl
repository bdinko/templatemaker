#TEMPLATE(notifications,'notifications - Windows notifications (toasts) with a designer - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  notifications template set  -  real Windows 10/11 notifications from Clarion.
#!
#!  The notifications that slide in at the bottom-right of the screen and stay
#!  in the Windows notification centre, the way Outlook's and Teams' do: title,
#!  text, logo, hero picture, progress bar, buttons, a reply box, a choice list,
#!  sounds, reminders and urgent alerts.
#!
#!  DESIGN THEM, DON'T CODE THEM. The Notification Designer (installed beside
#!  this template as accessory\bin\NotificationDesigner.exe) edits a design
#!  with a live Windows 11 preview and saves it as a .ntf file - which is the
#!  very XML Windows reads. The Design button on the code template opens it.
#!
#!  NOTHING TO SHIP. The engine is toastc.c, compiled into the program by
#!  Clarion's own C compiler; it talks to Windows directly. No DLL, no OCX, no
#!  .NET, no COM registration. The program registers itself per user (no admin)
#!  under HKCU\Software\Classes\AppUserModelId\<id> when it starts.
#!
#!  THE TEMPLATES
#!    NotificationsGlobal (APPLICATION) - declares the Notifier object, registers
#!                       the program with Windows at start-up. Add once.
#!    ShowNotification   (CODE)         - shows a design. Embeds the .ntf in the
#!                       program (or loads it at run time) and fills each
#!                       placeholder from a Clarion expression.
#!    UpdateNotification (CODE)         - moves a live progress bar.
#!    RemoveNotification (CODE)         - takes notifications away.
#!    NotificationEvents (EXTENSION)    - on a window (the frame, usually): runs
#!                       your embed code when the user clicks a notification,
#!                       presses one of its buttons, replies, or dismisses it.
#!
#!  REQUIRED FILES (beside this .tpl in the zip), on the redirection path:
#!      NotificationClass.inc   NotificationClass.clw   toastc.c
#!  and, for the Design button, accessory\bin\NotificationDesigner.exe.
#!-----------------------------------------------------------------------------
#!
#! Opens the designer, waiting for it to close. Used by the Design buttons.
#GROUP(%ntRunDesigner,%pFile)
#DECLARE(%ntExe)
#SET(%ntExe,%CWRoot & 'accessory\bin\NotificationDesigner.exe')
#IF(%pFile='')
#RUN('"' & %ntExe & '"'),WAIT
#ELSE
#RUN('"' & %ntExe & '" "' & %pFile & '"'),WAIT
#ENDIF
#!
#!#############################################################################
#!  GLOBAL EXTENSION
#!#############################################################################
#EXTENSION(NotificationsGlobal,'notifications - Global (add once per application)'),APPLICATION,HLP('~notifications.htm')
#SHEET
  #TAB('&General')
    #BOXED('notifications')
      #DISPLAY('Windows notifications for this application - version 1.0')
      #DISPLAY('')
      #DISPLAY('Declares the global object and registers the program with')
      #DISPLAY('Windows when it starts, so its notifications carry your')
      #DISPLAY('program''s name and icon.')
      #DISPLAY('')
      #DISPLAY('Then use the Show a notification code template wherever')
      #DISPLAY('one should appear, and add the Notification events extension')
      #DISPLAY('to the frame to react to clicks.')
    #ENDBOXED
    #PROMPT('&Disable this template',CHECK),%ntDisable,DEFAULT(0),AT(10)
    #PROMPT('&Object name:',@S40),%ntObject,DEFAULT('Notifier'),REQ
    #DISPLAY('The code templates default to Notifier too; change both.')
  #ENDTAB
  #TAB('&Identity')
    #BOXED('How Windows shows the program')
      #PROMPT('&Program name:',@S80),%ntDisplayName,DEFAULT('')
      #DISPLAY('Shown on every notification and in Settings. Blank = the')
      #DISPLAY('application name.')
      #PROMPT('&Icon (.png or .ico):',OPENDIALOG('The program''s icon','Pictures|*.png;*.ico|All files|*.*')),%ntIcon,DEFAULT('')
      #DISPLAY('A relative path is taken from the folder the program runs')
      #DISPLAY('from. Ship the file with the program.')
      #PROMPT('Icon &background (AARRGGBB):',@S10),%ntIconBack,DEFAULT('')
      #DISPLAY('Optional, e.g. FF1F6FB2. Blank = transparent.')
    #ENDBOXED
    #BOXED('AppUserModelID')
      #PROMPT('&Id:',@S120),%ntAppId,DEFAULT('')
      #DISPLAY('Blank = Clarion.<application name>. Keep it the same for')
      #DISPLAY('the life of the program: Windows files the notifications')
      #DISPLAY('and the user''s on/off setting under it.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Pictures')
      #PROMPT('Pictures &folder:',@S200),%ntImageFolder,DEFAULT('')
      #DISPLAY('Where relative picture paths in a design are looked up.')
      #DISPLAY('Blank = the folder the program runs from. A design loaded')
      #DISPLAY('from a file looks beside itself instead.')
    #ENDBOXED
    #BOXED('Run time')
      #PROMPT('Strings are &UTF-8 (not the ANSI code page)',CHECK),%ntUtf8,DEFAULT(0)
      #PROMPT('&Clear the program''s notifications when it closes',CHECK),%ntClearOnExit,DEFAULT(0)
      #PROMPT('&Unregister when it closes (test builds only)',CHECK),%ntUnregister,DEFAULT(0)
      #DISPLAY('Unregistering removes the name and icon Windows keeps for')
      #DISPLAY('the program; notifications still in the centre lose them.')
    #ENDBOXED
  #ENDTAB
  #TAB('De&signer')
    #BOXED('Notification Designer')
      #DISPLAY('Design notifications with a live Windows 11 preview, try them')
      #DISPLAY('on Windows, and save them as .ntf files for the code template.')
      #DISPLAY('')
      #BUTTON('&Open the Notification Designer'),WHENACCEPTED(%ntRunDesigner('')),AT(,,180)
      #ENDBUTTON
      #DISPLAY('')
      #DISPLAY('Installed as accessory\bin\NotificationDesigner.exe.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Multi-DLL')
    #BOXED('Where NotificationClass lives')
      #DISPLAY('Out of the box this follows the application''s External')
      #DISPLAY('setting: the app that owns the data compiles the class (and')
      #DISPLAY('its C engine) in and exports it; the others import it. Add')
      #DISPLAY('this extension to every app in the suite. Each app gets its')
      #DISPLAY('own Notifier object; only the EXE registers with Windows.')
    #ENDBOXED
    #BOXED('Override - place the class by hand')
      #INSERT(%AbcLibraryPrompts(ABC))
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%ntDisable=0)
INCLUDE('NotificationClass.INC'),ONCE
#ENDAT
#!
#AT(%GlobalData),WHERE(%ntDisable=0)
%[20]ntObject NotificationClass,THREAD                ! Windows notifications (notifications template)
#ENDAT
#!
#AT(%ProgramSetup),WHERE(%ntDisable=0 AND %ProgramExtension='EXE')
  #DECLARE(%ntIdQ)
  #DECLARE(%ntNameQ)
  #IF(%ntAppId='')
    #SET(%ntIdQ,'Clarion.' & %Application)
  #ELSE
    #SET(%ntIdQ,%ntAppId)
  #ENDIF
  #IF(%ntDisplayName='')
    #SET(%ntNameQ,%Application)
  #ELSE
    #SET(%ntNameQ,%ntDisplayName)
  #ENDIF
  #IF(%ntImageFolder<>'')
  %ntObject.ImageFolder = '%(QUOTE(%ntImageFolder))'
  #ENDIF
  #IF(%ntUtf8)
  %ntObject.UseUtf8()
  #ENDIF
  IF NOT %ntObject.Init('%(QUOTE(%ntIdQ))', '%(QUOTE(%ntNameQ))', '%(QUOTE(%ntIcon))', '%(QUOTE(%ntIconBack))')
    ! Windows notifications are not available here; %ntObject.ErrorText() says why.
  END
#ENDAT
#!
#AT(%ProgramEnd),WHERE(%ntDisable=0 AND %ProgramExtension='EXE')
  #IF(%ntClearOnExit)
  %ntObject.RemoveAll()
  #ENDIF
  #IF(%ntUnregister)
  %ntObject.Unregister()
  #ENDIF
  %ntObject.Kill()
#ENDAT
#!
#! Multi-DLL: the class is filed under category NOTIFICATIONS (line 1 of the
#! .inc); registering the category lets the ABC chain write the link-mode
#! pragmas and the export list (ABPROGRM.TPW, ABBLDEXP.TPW).
#AT(%BeforeGenerateApplication),WHERE(%ntDisable=0)
  #CALL(%AddCategory(ABC),'NOTIFICATIONS')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'NOTIFICATIONS','notifications','')
#ENDAT
#!
#!#############################################################################
#!  CODE TEMPLATE - show a design
#!#############################################################################
#!  Embed mode reads the .ntf AT GENERATE TIME and writes one AddXml() per line,
#!  so the program carries the design and nothing but its pictures needs to be
#!  shipped. The designer writes pure ASCII, one element per line, which is
#!  what makes this safe; QUOTE() doubles the ' < and { that Clarion string
#!  literals need doubled. Comment lines (the designer's sample values) are
#!  skipped.
#!
#!  Every {Name} in the design is filled from the Placeholders list. A name
#!  with no entry is reported when generating and is left to Windows as a data
#!  binding (it shows empty unless the program calls SetData).
#!-----------------------------------------------------------------------------
#CODE(ShowNotification,'notifications - Show a notification'),DESCRIPTION('Show notification ' & %nsDesign),HLP('~notifications.htm')
#SHEET
  #TAB('&Design')
    #PROMPT('&Design file (.ntf):',OPENDIALOG('Pick a notification design','Notification designs (*.ntf)|*.ntf|All files|*.*')),%nsDesign
    #BUTTON('&Design...   (opens the Notification Designer)'),WHENACCEPTED(%ntRunDesigner(%nsDesign)),AT(,,190)
    #ENDBUTTON
    #DISPLAY('With no file picked, Design starts a new one: save it,')
    #DISPLAY('then pick it above.')
    #DISPLAY('')
    #PROMPT('The design goes',OPTION),%nsMode,DEFAULT('Embed')
    #PROMPT('into the program (ship only its pictures)',RADIO),VALUE('Embed')
    #PROMPT('in a file read at run time (edit without compiling)',RADIO),VALUE('File')
    #ENABLE(%nsMode='File')
      #PROMPT('&Run-time file name:',@S200),%nsRuntimeFile,DEFAULT('')
      #DISPLAY('Blank = the design''s name, beside the program.')
    #ENDENABLE
    #PROMPT('&Object:',@S40),%nsObject,DEFAULT('Notifier'),REQ
  #ENDTAB
  #TAB('&Placeholders')
    #DISPLAY('A design says Invoice (InvoiceNo) is paid with the name in')
    #DISPLAY('braces. Give each name the Clarion expression that fills it.')
    #DISPLAY('The designer''s Clarion code tab lists the names.')
    #BUTTON('&Placeholders'),MULTI(%nsVars,%nsVarName & ' = ' & %nsVarValue),INLINE
      #PROMPT('&Name (no braces):',@S40),%nsVarName,REQ
      #PROMPT('&Value:',EXPR),%nsVarValue,REQ
    #ENDBUTTON
  #ENDTAB
  #TAB('&Options')
    #PROMPT('&Tag:',EXPR),%nsTag,DEFAULT('')
    #DISPLAY('An expression, e.g. ''inv'' & INV:Number. Showing another')
    #DISPLAY('notification with the same tag replaces this one; the tag is')
    #DISPLAY('also how UpdateNotification and RemoveNotification find it.')
    #PROMPT('&Group:',EXPR),%nsGroup,DEFAULT('')
    #PROMPT('&Silent: straight to the notification centre, no pop-up',CHECK),%nsSilent,DEFAULT(0)
    #PROMPT('Save the notification &id in:',FIELD),%nsIdVar
  #ENDTAB
#ENDSHEET
#!
#DECLARE(%nsLine)
#DECLARE(%nsFile)
#DECLARE(%nsRest)
#DECLARE(%nsAt)
#DECLARE(%nsEnd)
#DECLARE(%nsName)
#DECLARE(%nsMissing)
#DECLARE(%nsShowArgs)
#!
#IF(%nsDesign='')
  #ERROR('Show a notification: no design file is picked.')
  ! notifications: no design picked
#ELSE
  ! notifications - %nsDesign
  #IF(%nsMode='File')
    #IF(%nsRuntimeFile<>'')
      #SET(%nsFile,%nsRuntimeFile)
    #ELSE
      #SET(%nsFile,%nsDesign)
      #LOOP
        #SET(%nsAt,INSTRING('\',%nsFile,1,1))
        #IF(%nsAt=0)
          #BREAK
        #ENDIF
        #SET(%nsFile,SUB(%nsFile,%nsAt+1,LEN(%nsFile)))
      #ENDLOOP
    #ENDIF
  IF NOT %nsObject.LoadDesign('%(QUOTE(%nsFile))')
    ! the design file is missing: %nsObject shows nothing
  END
  #ELSE
  %nsObject.Reset()
  #ENDIF
  #! read the design: write it out (embed mode) and collect its placeholders
  #OPEN(%nsDesign),READ
  #LOOP
    #READ(%nsLine)
    #IF(%nsLine=%EOF)
      #BREAK
    #ENDIF
    #SET(%nsLine,CLIP(LEFT(%nsLine)))
    #IF(%nsLine='' OR SUB(%nsLine,1,4)=CHR(60) & '!--')
      #CYCLE
    #ENDIF
    #IF(%nsMode<>'File')
  %nsObject.AddXml('%(QUOTE(%nsLine))')
    #ENDIF
    #SET(%nsRest,%nsLine)
    #LOOP
      #SET(%nsAt,INSTRING(CHR(123),%nsRest,1,1))
      #IF(%nsAt=0)
        #BREAK
      #ENDIF
      #SET(%nsRest,SUB(%nsRest,%nsAt+1,LEN(%nsRest)))
      #SET(%nsEnd,INSTRING(CHR(125),%nsRest,1,1))
      #IF(%nsEnd<2)
        #CYCLE
      #ENDIF
      #SET(%nsName,SUB(%nsRest,1,%nsEnd-1))
      #IF(SUB(%nsName,1,8)='progress')
        #CYCLE
      #ENDIF
      #SET(%nsMissing,1)
      #FOR(%nsVars)
        #IF(UPPER(%nsVarName)=UPPER(%nsName))
          #SET(%nsMissing,0)
        #ENDIF
      #ENDFOR
      #IF(%nsMissing AND INSTRING(' ' & UPPER(%nsName) & ' ',UPPER(%nsShowArgs),1,1)=0)
        #SET(%nsShowArgs,%nsShowArgs & ' ' & %nsName & ' ')
        #ERROR('Show a notification (' & %nsDesign & '): the placeholder ' & %nsName & ' has no value on the Placeholders tab.')
  ! placeholder %nsName has no value: Windows shows it empty
      #ENDIF
    #ENDLOOP
  #ENDLOOP
  #CLOSE,READ
  #FOR(%nsVars)
  %nsObject.SetVar('%(QUOTE(%nsVarName))', %nsVarValue)
  #ENDFOR
  #SET(%nsShowArgs,'')
  #IF(%nsTag<>'')
    #SET(%nsShowArgs,%nsTag)
  #ENDIF
  #IF(%nsGroup<>'' OR %nsSilent)
    #SET(%nsShowArgs,%nsShowArgs & ',' & %nsGroup)
  #ENDIF
  #IF(%nsSilent)
    #SET(%nsShowArgs,%nsShowArgs & ',TRUE')
  #ENDIF
  #IF(%nsIdVar<>'')
  %nsIdVar = %nsObject.ShowToast(%nsShowArgs)
  #ELSE
  %nsObject.ShowToast(%nsShowArgs)
  #ENDIF
#ENDIF
#!
#!#############################################################################
#!  CODE TEMPLATE - move a live progress bar
#!#############################################################################
#CODE(UpdateNotification,'notifications - Move a live progress bar'),DESCRIPTION('Update notification progress'),HLP('~notifications.htm')
  #PROMPT('&Tag:',EXPR),%nuTag,DEFAULT('')
  #DISPLAY('The tag it was shown with. Blank = the last one shown.')
  #PROMPT('&Value (0 to 1):',EXPR),%nuValue,REQ
  #PROMPT('&Status:',EXPR),%nuStatus,DEFAULT('')
  #PROMPT('Value &text:',EXPR),%nuText,DEFAULT('')
  #DISPLAY('Status and value text are optional, e.g. ''Copying...''')
  #DISPLAY('and Done & '' of '' & Total.')
  #PROMPT('&Object:',@S40),%nuObject,DEFAULT('Notifier'),REQ
#DECLARE(%nuArgs)
#SET(%nuArgs,%nuValue)
#IF(%nuStatus<>'' OR %nuText<>'' OR %nuTag<>'')
  #SET(%nuArgs,%nuArgs & ',' & %nuStatus)
#ENDIF
#IF(%nuText<>'' OR %nuTag<>'')
  #SET(%nuArgs,%nuArgs & ',' & %nuText)
#ENDIF
#IF(%nuTag<>'')
  #SET(%nuArgs,%nuArgs & ',' & %nuTag)
#ENDIF
  %nuObject.UpdateProgress(%nuArgs)
#!
#!#############################################################################
#!  CODE TEMPLATE - take notifications away
#!#############################################################################
#CODE(RemoveNotification,'notifications - Remove notifications'),DESCRIPTION('Remove notifications'),HLP('~notifications.htm')
  #PROMPT('&Remove',OPTION),%nrWhat,DEFAULT('Tag')
  #PROMPT('the one with this tag',RADIO),VALUE('Tag')
  #PROMPT('a whole group',RADIO),VALUE('Group')
  #PROMPT('every notification of this program',RADIO),VALUE('All')
  #ENABLE(%nrWhat<>'All')
    #PROMPT('&Tag or group:',EXPR),%nrKey,DEFAULT('')
  #ENDENABLE
  #PROMPT('&Object:',@S40),%nrObject,DEFAULT('Notifier'),REQ
#CASE(%nrWhat)
#OF('Tag')
  %nrObject.Remove(%nrKey)
#OF('Group')
  %nrObject.RemoveGroup(%nrKey)
#ELSE
  %nrObject.RemoveAll()
#ENDCASE
#!
#!#############################################################################
#!  PROCEDURE EXTENSION - react to clicks
#!#############################################################################
#!  Windows reports clicks on a background thread; toastc.c queues them and
#!  this drains the queue on EVENT:Timer. If the window has no timer, one is
#!  set; a window that already has a timer keeps its own rate.
#!
#!  Self-contained CASE at TakeWindowEvent PRIORITY(2000): ABC's own CASE
#!  EVENT() scaffolding sits at 2500.
#!-----------------------------------------------------------------------------
#EXTENSION(NotificationEvents,'notifications - React when a notification is clicked'),PROCEDURE,WINDOW,HLP('~notifications.htm')
#SHEET
  #TAB('&Events')
    #BOXED('notifications - events')
      #DISPLAY('Runs your embed code when the user clicks a notification,')
      #DISPLAY('presses one of its buttons, replies, or dismisses it.')
      #DISPLAY('Put it on the frame (or the window that is always open).')
    #ENDBOXED
    #PROMPT('&Disable',CHECK),%neDisable,DEFAULT(0),AT(10)
    #PROMPT('&Object:',@S40),%neObject,DEFAULT('Notifier'),REQ
    #PROMPT('&Check every (1/100 s):',SPIN(@n4,5,500)),%neInterval,DEFAULT(25)
    #PROMPT('&Bring this window forward on a click',CHECK),%neFront,DEFAULT(1)
  #ENDTAB
  #TAB('&Actions')
    #DISPLAY('One entry per action=... value the designs send (the')
    #DISPLAY('designer''s Clarion code tab lists them). Each gets its')
    #DISPLAY('own embed: Notification events - action.')
    #BUTTON('&Actions'),MULTI(%neActions,%neAction & '  ' & %neNote),INLINE
      #PROMPT('&Action:',@S40),%neAction,REQ
      #PROMPT('&Note:',@S80),%neNote
    #ENDBUTTON
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%neDisable=0)
INCLUDE('NotificationClass.INC'),ONCE
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%neDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    IF 0{PROP:Timer} = 0 THEN 0{PROP:Timer} = %neInterval.            ! notifications: ask for clicks
  OF EVENT:Timer
    IF %neObject.Pending()                                  ! anything clicked since the last tick?
      LOOP WHILE %neObject.NextEvent()
        CASE %neObject.EventKind
        OF Notify:Activated                                 ! the notification or a button was clicked
  #IF(%neFront)
          %neObject.BringToFront(0{PROP:Handle})
  #ENDIF
          #EMBED(%neActivated,'Notification events - clicked (any action)')
  #IF(ITEMS(%neActions))
          CASE %neObject.Arg('action')
    #FOR(%neActions)
          OF '%(QUOTE(%neAction))'
            #EMBED(%neOnAction,'Notification events - action'),%neActions,TREE('Notification events|Action ' & %neAction)
    #ENDFOR
          ELSE
            #EMBED(%neOtherAction,'Notification events - any other action')
          END
  #ENDIF
        OF Notify:Dismissed                                 ! closed, timed out, or hidden
          #EMBED(%neDismissed,'Notification events - dismissed')
        OF Notify:Failed                                    ! Windows would not show it: %neObject.FailText() says why
          #EMBED(%neFailed,'Notification events - failed')
        END
      END
      DISPLAY()                                             ! show what the embeds changed
    END
  END
#ENDAT
