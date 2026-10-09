! ============================================================================
!  NotifyDemo - the notifications template, written out by hand.
!
!  Every call below is what the templates generate; the comment beside it
!  names the template and embed point that emits it. Run it, press the
!  buttons, and click the notifications (or their buttons): the list on the
!  right shows exactly what the program receives.
!
!    NotifyDemo.exe            English
!    NotifyDemo.exe es         Spanish
!    NotifyDemo.exe /shot=X    show notification X and close after 7 s
!                              (for shoot.ps1: invoice, chat, reminder, hero,
!                              urgent, progress, quick)
! ============================================================================
  PROGRAM

  INCLUDE('NotificationClass.INC'),ONCE              ! NotificationsGlobal - %AfterGlobalIncludes

  MAP
Main          PROCEDURE
ShowOne       PROCEDURE(STRING pWhat)
T             PROCEDURE(STRING pEn, STRING pEs),STRING
  END

Notifier      NotificationClass,THREAD               ! NotificationsGlobal - %GlobalData
Spanish       BYTE

  CODE
  Spanish = CHOOSE(INSTRING(' es ', ' ' & LOWER(CLIP(COMMAND(''))) & ' ', 1, 1) > 0, TRUE, FALSE)
  ! NotificationsGlobal - %ProgramSetup: register the program with Windows
  IF NOT Notifier.Init('TemplateMaker.NotifyDemo', 'Notify Demo', 'images\logo.png')
    MESSAGE(T('Windows notifications are not available: ', 'Las notificaciones de Windows no est<225>n disponibles: ') & |
            Notifier.ErrorText(), 'NotifyDemo', ICON:Exclamation)
  END
  Main
  Notifier.RemoveAll()                                ! NotificationsGlobal - %ProgramEnd ("clear on close")
  Notifier.Kill()

! ----------------------------------------------------------------------------
Main PROCEDURE

Heard       QUEUE
Line          STRING(200)
            END
Step        LONG
Shot        STRING(20)
ShotEnds    LONG
Line        STRING(260)
p           LONG

Window WINDOW('notifications'),AT(,,470,236),CENTER,GRAY,SYSTEM,FONT('Segoe UI',9),TIMER(25)
       PROMPT('Design-made'),AT(10,8),USE(?HDesign),FONT(,,0505B68H,FONT:bold)
       BUTTON('Invoice paid'),AT(10,20,100,18),USE(?Invoice)
       BUTTON('Chat with reply'),AT(10,42,100,18),USE(?Chat)
       BUTTON('Reminder + snooze'),AT(10,64,100,18),USE(?Reminder)
       BUTTON('Announcement'),AT(10,86,100,18),USE(?Hero)
       BUTTON('Urgent alert'),AT(10,108,100,18),USE(?Urgent)
       PROMPT('From code'),AT(10,134),USE(?HCode),FONT(,,0505B68H,FONT:bold)
       BUTTON('Quick: one line'),AT(10,146,100,18),USE(?Quick)
       BUTTON('Live progress'),AT(10,168,100,18),USE(?Progress)
       BUTTON('Remove all'),AT(10,196,100,18),USE(?RemoveAll)
       PROMPT('What the program received'),AT(124,8),USE(?HHeard),FONT(,,0505B68H,FONT:bold)
       LIST,AT(124,20,336,194),USE(?Heard),FROM(Heard),VSCROLL,FONT('Consolas',9)
       BUTTON('Close'),AT(400,218,60,14),USE(?Close),STD(STD:Close)
     END

  CODE
  Line = ' ' & LOWER(CLIP(COMMAND(''))) & ' '                   ! /shot=name, parsed by hand
  p = INSTRING('/shot=', Line, 1, 1)
  IF p
    Shot = SUB(Line, p + 6, 20)
    p = INSTRING(' ', Shot, 1, 1)
    IF p THEN Shot = SUB(Shot, 1, p - 1).
  END
  OPEN(Window)
  IF Spanish
    0{PROP:Text} = 'notifications - demostraci<243>n'
    ?HDesign{PROP:Text} = 'Hechas con el dise<241>ador'
    ?Invoice{PROP:Text} = 'Factura pagada'
    ?Chat{PROP:Text} = 'Chat con respuesta'
    ?Reminder{PROP:Text} = 'Recordatorio'
    ?Hero{PROP:Text} = 'Anuncio'
    ?Urgent{PROP:Text} = 'Alerta urgente'
    ?HCode{PROP:Text} = 'Desde c<243>digo'
    ?Quick{PROP:Text} = 'R<225>pida: una l<237>nea'
    ?Progress{PROP:Text} = 'Progreso en vivo'
    ?RemoveAll{PROP:Text} = 'Quitar todas'
    ?HHeard{PROP:Text} = 'Lo que recibe el programa'
    ?Close{PROP:Text} = 'Cerrar'
  END
  IF Shot
    0{PROP:Hide} = TRUE                               ! screenshots: only the notification
    ShowOne(Shot)
    IF CLIP(Shot) = 'progress' THEN Step = 1.
    ShotEnds = CLOCK() + 700
  END
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ! ---- NotificationEvents - TakeWindowEvent, EVENT:Timer ----------------
      IF Notifier.Pending()
        LOOP WHILE Notifier.NextEvent()
          CASE Notifier.EventKind
          OF Notify:Activated
            Notifier.BringToFront(0{PROP:Handle})       ! "Bring this window forward"
            Heard.Line = FORMAT(CLOCK(), @T4) & '  ' & T('clicked  ', 'clic     ') & Notifier.EventArgs
            ADD(Heard, 1)
            CASE Notifier.Arg('action')                 ! one OF per entry on the Actions tab
            OF 'reply'
              Heard.Line = '          Input(''reply'') = ''' & Notifier.Input('reply') & ''''
              ADD(Heard, 2)
            OF 'appointment'
              IF Notifier.Input('snoozeTime')
                Heard.Line = '          Input(''snoozeTime'') = ' & Notifier.Input('snoozeTime')
                ADD(Heard, 2)
              END
            OF 'cancel'
              Step = 0
              Notifier.Remove('export')
            END
          OF Notify:Dismissed
            Heard.Line = FORMAT(CLOCK(), @T4) & '  ' & T('dismissed', 'cerrada  ') & '  ' & |
                         CHOOSE(Notifier.DismissReason + 1, T('by the user', 'por el usuario'), |
                         T('by the program', 'por el programa'), T('timed out', 'por tiempo')) & '  (id ' & Notifier.EventId & ')'
            ADD(Heard, 1)
          OF Notify:Failed
            Heard.Line = FORMAT(CLOCK(), @T4) & '  failed   ' & Notifier.FailText()
            ADD(Heard, 1)
          END
        END
        DISPLAY()
      END
      ! ---- the live progress: UpdateNotification, once per step -------------
      IF Step
        Step += 1
        Notifier.UpdateProgress(Step / 40, T('Writing sheets...', 'Escribiendo hojas...'), Step & T(' of 40', ' de 40'), 'export')
        IF Step >= 40
          Step = 0
          Notifier.SetData('progressStatus', T('Done', 'Terminado'))
          Notifier.UpdateData('export')
        END
      END
      IF ShotEnds AND CLOCK() > ShotEnds THEN BREAK.
    OF EVENT:Accepted
      CASE ACCEPTED()
      OF ?Invoice  ; ShowOne('invoice')
      OF ?Chat     ; ShowOne('chat')
      OF ?Reminder ; ShowOne('reminder')
      OF ?Hero     ; ShowOne('hero')
      OF ?Urgent   ; ShowOne('urgent')
      OF ?Quick    ; ShowOne('quick')
      OF ?Progress
        ShowOne('progress')
        Step = 1
      OF ?RemoveAll
        Notifier.RemoveAll()                          ! RemoveNotification - "every notification"
        Step = 0
      END
    END
  END
  CLOSE(Window)

! ----------------------------------------------------------------------------
!  What the ShowNotification code template writes for each design. 'invoice'
!  is the template's "into the program" mode spelt out; the others use its
!  "file read at run time" mode, which is one LoadDesign() line.
! ----------------------------------------------------------------------------
ShowOne PROCEDURE(STRING pWhat)
es  STRING(3)
  CODE
  es = CHOOSE(Spanish, '-es', '')
  CASE CLIP(pWhat)
  OF 'invoice'
    IF Spanish
      Notifier.LoadDesign('invoice-paid-es.ntf')
    ELSE
      Notifier.Reset()                                ! ShowNotification, embedded design
      Notifier.AddXml('<<toast launch="action=open;invoice={{InvoiceNo}">')
      Notifier.AddXml('<<visual>')
      Notifier.AddXml('<<binding template="ToastGeneric">')
      Notifier.AddXml('<<image placement="appLogoOverride" src="images\logo.png"/>')
      Notifier.AddXml('<<text hint-maxLines="2">Invoice {{InvoiceNo} has been paid<</text>')
      Notifier.AddXml('<<text>{{Customer} paid {{Amount}.<</text>')
      Notifier.AddXml('<<text placement="attribution">Accounts receivable<</text>')
      Notifier.AddXml('<</binding>')
      Notifier.AddXml('<</visual>')
      Notifier.AddXml('<<actions>')
      Notifier.AddXml('<<action content="Open invoice" arguments="action=open;invoice={{InvoiceNo}"/>')
      Notifier.AddXml('<<action content="Send receipt" arguments="action=receipt;invoice={{InvoiceNo}"/>')
      Notifier.AddXml('<</actions>')
      Notifier.AddXml('<<audio src="ms-winsoundevent:Notification.Mail"/>')
      Notifier.AddXml('<</toast>')
    END
    Notifier.SetVar('InvoiceNo', 1043)                ! one SetVar per row of the Placeholders tab
    Notifier.SetVar('Customer', 'Acme Ltd')
    Notifier.SetVar('Amount', CHOOSE(Spanish, '1.250,00 $', '$1,250.00'))
    Notifier.ShowToast('inv1043')
  OF 'chat'
    Notifier.LoadDesign('chat-reply' & CLIP(es) & '.ntf')
    Notifier.SetVar('From', 'Ana Torres')
    Notifier.SetVar('Message', T('Can you approve the March figures before 5?', '<191>Puedes aprobar las cifras de marzo antes de las 5?'))
    Notifier.ShowToast('chat', 'msgs')
  OF 'reminder'
    Notifier.LoadDesign('reminder-with-snooze' & CLIP(es) & '.ntf')
    Notifier.SetVar('Id', 77)
    Notifier.SetVar('Subject', T('Quarterly review', 'Revisi<243>n trimestral'))
    Notifier.SetVar('When', T('Today 15:00', 'Hoy 15:00'))
    Notifier.SetVar('Where', T('Room 2', 'Sala 2'))
    Notifier.ShowToast('appt77')
  OF 'hero'
    Notifier.LoadDesign('announcement' & CLIP(es) & '.ntf')
    Notifier.SetVar('Version', '4.2')
    Notifier.ShowToast('news')
  OF 'urgent'
    Notifier.LoadDesign('urgent-alert' & CLIP(es) & '.ntf')
    Notifier.SetVar('AlertId', 9)
    Notifier.SetVar('Item', T('A4 paper', 'Papel A4'))
    Notifier.SetVar('Qty', T('3 boxes', '3 cajas'))
    Notifier.SetVar('Min', 10)
    Notifier.ShowToast('stock9')
  OF 'progress'
    Notifier.LoadDesign('live-progress' & CLIP(es) & '.ntf')
    Notifier.SetVar('Report', T('Sales 2026.xlsx', 'Ventas 2026.xlsx'))
    Notifier.SetData('progressTitle', T('Sales 2026.xlsx', 'Ventas 2026.xlsx'))
    Notifier.SetData('progressStatus', T('Starting...', 'Comenzando...'))
    Notifier.ShowToast('export')
  OF 'quick'
    ! the builder, no design at all
    Notifier.Toast(T('Backup finished', 'Copia de seguridad terminada'), |
                   T('1,284 files copied to the NAS.', '1.284 archivos copiados al NAS.'), 'images\logo.png')
  END

T PROCEDURE(STRING pEn, STRING pEs)
  CODE
  RETURN CHOOSE(Spanish, pEs, pEn)
