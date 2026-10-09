"""
Writes NotifyLab.txa - a small ABC application that exercises every part of
the notifications template set. build.ps1 imports it into NotifyLab.app.

  Main        an ABC Frame: a Notifications menu, one item per design
              (ShowNotification / UpdateNotification / RemoveNotification code
              templates) and the NotificationEvents extension on the frame
  HeardPopup  a small modal window that shows what a click delivered
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
D = lambda f: os.path.join(HERE, f)          # designs are read at generate time from here

def show(inst, design, mode, vars_, tag, group=''):
    """A ShowNotification code-template instance."""
    lines = [
        '[ADDITION]', 'NAME notifications ShowNotification', '[INSTANCE]', f'INSTANCE {inst}', '[PROMPTS]',
        f"%nsDesign DEFAULT  ('{D(design)}')",
        f"%nsMode DEFAULT  ('{mode}')",
        "%nsRuntimeFile DEFAULT  ('')",
        "%nsObject DEFAULT  ('Notifier')",
        f"%nsVars MULTI LONG  ({', '.join(str(i + 1) for i in range(len(vars_)))})",
        f'%nsVarName DEPEND %nsVars DEFAULT TIMES {len(vars_)}',
    ]
    lines += [f"WHEN  ({i + 1}) ('{n}')" for i, (n, _) in enumerate(vars_)]
    lines += [f'%nsVarValue DEPEND %nsVars DEFAULT TIMES {len(vars_)}']
    lines += [f"WHEN  ({i + 1}) ('{v.replace(chr(39), chr(39) * 2)}')" for i, (_, v) in enumerate(vars_)]
    lines += [
        f"%nsTag DEFAULT  ('{tag.replace(chr(39), chr(39) * 2)}')",
        f"%nsGroup DEFAULT  ('{group.replace(chr(39), chr(39) * 2)}')",
        '%nsSilent LONG  (0)',
        '%nsIdVar FIELD  ()',
    ]
    return lines

ACTIONS = [('open', 'Invoice: Open invoice, or a click on it'), ('receipt', 'Invoice: Send receipt'),
           ('chat', 'Chat: a click on it'), ('reply', 'Chat: Send with the reply box'),
           ('appointment', 'Reminder: a click on it'), ('whatsnew', 'Announcement'),
           ('alert', 'Urgent: a click on it'), ('reorder', 'Urgent: Reorder now'),
           ('later', 'Urgent: Remind me later'), ('cancel', 'Progress: Cancel')]

# what each action's embed does (code inside the generated CASE)
ACTION_CODE = {
    'open':     "HeardPopup('Open invoice ' & Notifier.Arg('invoice'), 'EventArgs = ' & Notifier.EventArgs)",
    'receipt':  "HeardPopup('Send the receipt for invoice ' & Notifier.Arg('invoice'), 'EventArgs = ' & Notifier.EventArgs)",
    'reply':    "HeardPopup('Reply to ' & Notifier.Arg('from'), 'They typed: ' & Notifier.Input('reply'))",
    'cancel':   "Loc:Done = 0\r\n            Notifier.Remove('export')\r\n            HeardPopup('Export cancelled', 'The Cancel button on the progress notification')",
    'reorder':  "HeardPopup('Reorder alert ' & Notifier.Arg('id'), 'The red Critical button')",
}

out = []
w = out.append
w('[APPLICATION]')
w('VERSION 34')
w('PROCEDURE Main')
w('[COMMON]')
w('FROM ABC')
w('[PROMPTS]')
w('[ADDITION]')
w('NAME notifications NotificationsGlobal')
w('[INSTANCE]')
w('INSTANCE 1')
w('[PROMPTS]')
for p in ["%ntDisable LONG  (0)", "%ntObject DEFAULT  ('Notifier')", "%ntDisplayName DEFAULT  ('Notify Lab')",
          "%ntIcon DEFAULT  ('images\\logo.png')", "%ntIconBack DEFAULT  ('')",
          "%ntAppId DEFAULT  ('TemplateMaker.NotifyLab')", "%ntImageFolder DEFAULT  ('')",
          "%ntUtf8 LONG  (0)", "%ntClearOnExit LONG  (1)", "%ntUnregister LONG  (0)",
          "%OverrideAbcSettings LONG  (0)", "%AbcSourceLocation DEFAULT  ('LINK')", "%AbcLibraryName DEFAULT  ('')"]:
    w(p)
w('[PROGRAM]')
w('[COMMON]')
w('FROM ABC ABC')
w('[MODULE]')
w('NAME \'NOTIFYLAB001.CLW\'')
w('[COMMON]')
w('FROM ABC GENERATED')

# ---------------------------------------------------------------- Main (frame)
w('[PROCEDURE]')
w('NAME Main')
w('[COMMON]')
w("DESCRIPTION 'notifications test frame'")
w('FROM ABC Frame')
w("CATEGORY 'Frame'")
# events extension
w('[ADDITION]')
w('NAME notifications NotificationEvents')
w('[INSTANCE]')
w('INSTANCE 1')
w('[PROMPTS]')
w('%neDisable LONG  (0)')
w("%neObject DEFAULT  ('Notifier')")
w('%neInterval LONG  (25)')
w('%neFront LONG  (1)')
w(f"%neActions MULTI LONG  ({', '.join(str(i + 1) for i in range(len(ACTIONS)))})")
w(f'%neAction DEPEND %neActions DEFAULT TIMES {len(ACTIONS)}')
for i, (a, _) in enumerate(ACTIONS): w(f"WHEN  ({i + 1}) ('{a}')")
w(f'%neNote DEPEND %neActions DEFAULT TIMES {len(ACTIONS)}')
for i, (_, n) in enumerate(ACTIONS): w(f"WHEN  ({i + 1}) ('{n}')")
# code templates
out += show(2, 'invoice-paid.ntf', 'Embed', [('InvoiceNo', '1043'), ('Customer', "'Acme Ltd'"), ('Amount', "'$1,250.00'")], "'inv1043'")
out += show(3, 'chat-reply.ntf', 'Embed', [('From', "'Ana Torres'"), ('Message', "'Can you approve the March figures before 5?'")], "'chat'", "'msgs'")
out += show(4, 'reminder-with-snooze.ntf', 'File', [('Id', '77'), ('Subject', "'Quarterly review'"), ('When', "'Today ' & FORMAT(CLOCK() + 360000, @T1)"), ('Where', "'Room 2'")], "'appt77'")
out += show(5, 'announcement.ntf', 'File', [('Version', "'4.2'")], "'news'")
out += show(6, 'urgent-alert.ntf', 'File', [('AlertId', '9'), ('Item', "'A4 paper'"), ('Qty', "'3 boxes'"), ('Min', '10')], "'stock9'")
out += show(7, 'live-progress.ntf', 'Embed', [('Report', "'Sales 2026.xlsx'")], "'export'")
out += ['[ADDITION]', 'NAME notifications UpdateNotification', '[INSTANCE]', 'INSTANCE 8', '[PROMPTS]',
        "%nuTag DEFAULT  ('''export''')", "%nuValue DEFAULT  ('Loc:Done / 10')",
        "%nuStatus DEFAULT  ('CHOOSE(Loc:Done < 10, ''Writing sheets...'', ''Done'')')",
        "%nuText DEFAULT  ('Loc:Done & '' of 10''')", "%nuObject DEFAULT  ('Notifier')"]
out += ['[ADDITION]', 'NAME notifications RemoveNotification', '[INSTANCE]', 'INSTANCE 9', '[PROMPTS]',
        "%nrWhat DEFAULT  ('All')", "%nrKey DEFAULT  ('')", "%nrObject DEFAULT  ('Notifier')"]

def src(prio, code):
    return ['[SOURCE]', 'PROPERTY:BEGIN', f'PRIORITY {prio}', 'PROPERTY:END'] + code.split('\r\n')

def group(prio, inst):
    return ['[GROUP]', f'PRIORITY {prio}', f'INSTANCE {inst}']

w('[EMBED]')
w('EMBED %DataSection')
w('[DEFINITION]')
out += src(4000, 'Loc:Done             LONG                ! steps of the live progress bar (0-10)')
w('[END]')
# start-up check
w('EMBED %WindowManagerMethodCodeSection')
w('[INSTANCES]')
w("WHEN 'Init'")
w('[INSTANCES]')
w("WHEN '(),BYTE'")
w('[DEFINITION]')
out += src(8500, "  IF NOT Notifier.Enabled()\r\n"
                 "    HeardPopup('Windows notifications are turned off', 'Nothing will appear until they are on again: Settings > System > Notifications.')\r\n"
                 "  END\r\n"
                 "  0{PROP:StatusText,2} = CHOOSE(Notifier.Ready(), 'Registered with Windows as Notify Lab', 'Not registered: ' & Notifier.ErrorText())")
w('[END]')
w('[END]')
w('[END]')
# menu items
items = [('?ShowInvoice', 2, None), ('?ShowChat', 3, None), ('?ShowReminder', 4, None), ('?ShowHero', 5, None),
         ('?ShowUrgent', 6, None), ('?StartProgress', 7, '    Loc:Done = 0'),
         ('?StepProgress', 8, '    IF Loc:Done < 10 THEN Loc:Done += 1.'), ('?RemoveAll', 9, '    Loc:Done = 0')]
w('EMBED %ControlEventHandling')
w('[INSTANCES]')
for feq, inst, before in items:
    w(f"WHEN '{feq}'")
    w('[INSTANCES]')
    w("WHEN 'Accepted'")
    w('[DEFINITION]')
    if before: out += src(3000, before)
    out += group(4000, inst)
    out += src(6000, f"    0{{PROP:StatusText,2}} = CHOOSE(Notifier.LastError = 0 OR Notifier.LastId > 0, 'Shown: id ' & Notifier.LastId & ', tag ' & Notifier.LastTag, Notifier.ErrorText())")
    w('[END]')
    w('[END]')
w('[END]')
# events: one embed per action, plus the catch-alls
w('EMBED %neOnAction')
w('[INSTANCES]')
for i, (a, _) in enumerate(ACTIONS):
    if a not in ACTION_CODE: continue
    w(f"WHEN '{i + 1}'")
    w('[DEFINITION]')
    out += src(5000, '            ' + ACTION_CODE[a])
    w('[END]')
w('[END]')
w('EMBED %neOtherAction')
w('[DEFINITION]')
out += src(5000, "            HeardPopup('Clicked: ' & Notifier.Arg('action'), 'EventArgs = ' & Notifier.EventArgs)")
w('[END]')
w('EMBED %neDismissed')
w('[DEFINITION]')
out += src(5000, "          0{PROP:StatusText,2} = 'Notification ' & Notifier.EventId & ' ' & "
                 "CHOOSE(Notifier.DismissReason + 1, 'closed by the user', 'hidden by the program', 'timed out to the notification centre')")
w('[END]')
w('EMBED %neFailed')
w('[DEFINITION]')
out += src(5000, "          HeardPopup('Windows did not show it', Notifier.FailText())")
w('[END]')
w('[END]')
w('[WINDOW]')
w("AppFrame APPLICATION('Notify Lab - notifications template test'),AT(,,420,240),STATUS(-1,320),FONT('Segoe UI',9),RESIZE,CENTER,MAX,SYSTEM,IMM")
w("  MENUBAR,USE(?Menubar)")
w("    MENU('&File'),USE(?FileMenu)")
w("      ITEM('E&xit'),USE(?Exit),STD(STD:Close)")
w("    END")
w("    MENU('&Notifications'),USE(?NotifyMenu)")
w("      ITEM('&Invoice paid  (embedded design, two buttons)'),USE(?ShowInvoice)")
w("      ITEM('&Chat with a reply box  (embedded design)'),USE(?ShowChat)")
w("      ITEM('&Reminder with snooze  (design file read at run time)'),USE(?ShowReminder)")
w("      ITEM('&Announcement with a picture  (design file)'),USE(?ShowHero)")
w("      ITEM('&Urgent alert  (design file)'),USE(?ShowUrgent)")
w("      ITEM,SEPARATOR,USE(?Sep1)")
w("      ITEM('Start a &live progress bar'),USE(?StartProgress)")
w("      ITEM('&Advance the progress bar  +10%'),USE(?StepProgress),KEY(F8Key)")
w("      ITEM,SEPARATOR,USE(?Sep2)")
w("      ITEM('Remove &all of them'),USE(?RemoveAll)")
w("    END")
w("  END")
w(" END")
w('')
w('[END]')

# ---------------------------------------------------------------- HeardPopup
out += [
    '[PROCEDURE]', 'NAME HeardPopup',
    "PROTOTYPE '(STRING pTitle, STRING pDetail)'", "PARAMETERS '(STRING pTitle, STRING pDetail)'",
    '[COMMON]', "DESCRIPTION 'What a notification click delivered'", 'FROM ABC Window', "CATEGORY 'Window'",
    '[EMBED]', 'EMBED %WindowManagerMethodCodeSection', '[INSTANCES]', "WHEN 'Init'", '[INSTANCES]', "WHEN '(),BYTE'",
    '[DEFINITION]',
] + src(8500, "  ?Title{PROP:Text} = pTitle\r\n  ?Detail{PROP:Text} = pDetail") + [
    '[END]', '[END]', '[END]', '[END]',
    '[WINDOW]',
    "Window WINDOW('Notification received'),AT(,,300,96),CENTER,GRAY,SYSTEM,MODAL,FONT('Segoe UI',10)",
    "       BOX,AT(0,0,300,4),USE(?Band),COLOR(01F6FB2H),FILL(01F6FB2H)",
    "       STRING('Title'),AT(14,14,272,12),USE(?Title),FONT(,11,0332A1FH,FONT:bold)",
    "       TEXT,AT(14,32,272,36),USE(?Detail),SKIP,TRN,READONLY,FONT(,,05B6878H)",
    "       BUTTON('OK'),AT(236,74,50,16),USE(?OK),STD(STD:Close),DEFAULT",
    "     END",
    '',
    '[END]',
]

with open(D('NotifyLab.txa'), 'w', newline='\r\n', encoding='latin-1') as f:
    f.write('\n'.join(out) + '\n')
print('wrote', D('NotifyLab.txa'))
