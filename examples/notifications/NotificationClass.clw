! ============================================================================
!  NotificationClass - implementation. See NotificationClass.inc for the API.
!
!  Everything that talks to Windows is in toastc.c, compiled in by the PRAGMA
!  below. This module builds the toast XML, fills in {placeholders}, turns
!  image paths into file:/// URIs, and drains the event queue.
!
!  This file MUST be stored in ANSI (not UTF-8).
! ============================================================================
  MEMBER

  INCLUDE('NotificationClass.INC'),ONCE      ! must precede the PRAGMA / toastc.c prototypes

  PRAGMA('compile(toastc.c)')                ! Clarion's own C compiler builds the engine

  MAP
    MODULE('toastc.c')
tc_codepage    PROCEDURE(LONG),LONG,PROC,NAME('_toastc_codepage')
tc_init        PROCEDURE(*CSTRING,*CSTRING,*CSTRING,*CSTRING),LONG,RAW,NAME('_toastc_init')
tc_unregister  PROCEDURE(*CSTRING),LONG,RAW,PROC,NAME('_toastc_unregister')
tc_setting     PROCEDURE(),LONG,NAME('_toastc_setting')
tc_show        PROCEDURE(*CSTRING,*CSTRING,*CSTRING,*CSTRING,ULONG,LONG),LONG,RAW,NAME('_toastc_show')
tc_update      PROCEDURE(*CSTRING,*CSTRING,*CSTRING,ULONG),LONG,RAW,NAME('_toastc_update')
tc_hide        PROCEDURE(LONG),LONG,NAME('_toastc_hide')
tc_remove      PROCEDURE(*CSTRING,*CSTRING),LONG,RAW,NAME('_toastc_remove')
tc_pending     PROCEDURE(),LONG,NAME('_toastc_pending')
tc_next        PROCEDURE(*LONG,*LONG,*LONG),LONG,RAW,NAME('_toastc_next')
tc_args        PROCEDURE(*CSTRING,LONG),LONG,RAW,PROC,NAME('_toastc_args')
tc_tag         PROCEDURE(*CSTRING,LONG),LONG,RAW,PROC,NAME('_toastc_tag')
tc_input       PROCEDURE(*CSTRING,*CSTRING,LONG),LONG,RAW,NAME('_toastc_input')
tc_lasterror   PROCEDURE(),LONG,NAME('_toastc_last_error')
tc_laststage   PROCEDURE(),LONG,NAME('_toastc_last_stage')
tc_ready       PROCEDURE(),LONG,NAME('_toastc_ready')
tc_kill        PROCEDURE(),LONG,PROC,NAME('_toastc_kill')
tc_readfile    PROCEDURE(*CSTRING,*CSTRING,LONG),LONG,RAW,NAME('_toastc_readfile')
tc_fullpath    PROCEDURE(*CSTRING,*CSTRING,LONG),LONG,RAW,PROC,NAME('_toastc_fullpath')
tc_exefolder   PROCEDURE(*CSTRING,LONG),LONG,RAW,PROC,NAME('_toastc_exefolder')
tc_front       PROCEDURE(LONG),LONG,PROC,NAME('_toastc_front')
    END
  END

!=== NotifyBufClass ==========================================================
NotifyBufClass.Add PROCEDURE(STRING pText)
n      LONG
cap    LONG
grown  &STRING
  CODE
  n = LEN(pText)
  IF n = 0 THEN RETURN.
  cap = CHOOSE(SELF.S &= NULL, 0, SIZE(SELF.S))
  IF SELF.L + n > cap
    cap = CHOOSE(cap < 1024, 1024, cap)
    LOOP WHILE cap < SELF.L + n
      cap *= 2
    END
    grown &= NEW STRING(cap)
    IF SELF.L THEN grown[1 : SELF.L] = SELF.S[1 : SELF.L].
    DISPOSE(SELF.S)
    SELF.S &= grown
  END
  SELF.S[SELF.L + 1 : SELF.L + n] = pText
  SELF.L += n

NotifyBufClass.Reset PROCEDURE()
  CODE
  SELF.L = 0

NotifyBufClass.Len PROCEDURE()
  CODE
  RETURN SELF.L

NotifyBufClass.Text PROCEDURE()
  CODE
  IF SELF.L = 0 THEN RETURN ''.
  RETURN SELF.S[1 : SELF.L]

NotifyBufClass.Destruct PROCEDURE()
  CODE
  DISPOSE(SELF.S)

!=== life cycle ==============================================================
NotificationClass.Construct PROCEDURE()
  CODE
  SELF.Xml &= NEW NotifyBufClass
  SELF.Vis &= NEW NotifyBufClass
  SELF.Inp &= NEW NotifyBufClass
  SELF.Act &= NEW NotifyBufClass
  SELF.Out &= NEW NotifyBufClass
  SELF.Vars &= NEW NotifyVarQ
  SELF.Data &= NEW NotifyVarQ

NotificationClass.Destruct PROCEDURE()
  CODE
  DISPOSE(SELF.Xml)
  DISPOSE(SELF.Vis)
  DISPOSE(SELF.Inp)
  DISPOSE(SELF.Act)
  DISPOSE(SELF.Out)
  FREE(SELF.Vars)
  DISPOSE(SELF.Vars)
  FREE(SELF.Data)
  DISPOSE(SELF.Data)
  DISPOSE(SELF.Tmp)

NotificationClass.Init PROCEDURE(STRING pAppId, <STRING pDisplayName>, <STRING pIconFile>, <STRING pIconBack>)
id    CSTRING(129)
dn    CSTRING(129)
ic    CSTRING(261)
bk    CSTRING(16)
full  CSTRING(261)
  CODE
  SELF.AppId = CLIP(pAppId)
  IF NOT OMITTED(pDisplayName) THEN SELF.DisplayName = CLIP(pDisplayName).
  IF NOT OMITTED(pIconFile) THEN SELF.IconFile = CLIP(pIconFile).
  id = SELF.AppId
  dn = SELF.DisplayName
  ic = ''
  IF SELF.IconFile
    ic = SELF.IconFile
    IF NOT (INSTRING(':', ic, 1, 1) OR SUB(ic, 1, 2) = '\\')      ! relative: from the program folder
      tc_exefolder(full, SIZE(full))
      ic = full & '\' & SELF.IconFile
    END
  END
  IF NOT OMITTED(pIconBack) THEN bk = CLIP(pIconBack).
  IF tc_init(id, dn, ic, bk)
    RETURN TRUE
  END
  SELF.LastError = tc_lasterror()
  RETURN FALSE

NotificationClass.Kill PROCEDURE()
  CODE
  tc_kill()

NotificationClass.Ready PROCEDURE()
  CODE
  RETURN CHOOSE(tc_ready() <> 0, TRUE, FALSE)

NotificationClass.Enabled PROCEDURE()
s  LONG
  CODE
  s = tc_setting()
  RETURN CHOOSE(s <= 0, TRUE, FALSE)      ! -1 = Windows will not say (unpackaged): assume yes

NotificationClass.Unregister PROCEDURE()
id  CSTRING(129)
  CODE
  id = SELF.AppId
  tc_unregister(id)

NotificationClass.UseUtf8 PROCEDURE(BYTE pOn=1)
  CODE
  tc_codepage(CHOOSE(pOn <> 0, 65001, 0))

NotificationClass.ErrorText PROCEDURE()
hr     LONG
st     LONG
hex    STRING(8)
i      LONG
d      LONG
u      ULONG
stage  STRING(40)
  CODE
  hr = tc_lasterror()
  st = tc_laststage()
  IF hr = 0 AND st = 0 THEN RETURN ''.
  u = hr
  LOOP i = 8 TO 1 BY -1
    d = u % 16
    hex[i] = SUB('0123456789ABCDEF', d + 1, 1)
    u = INT(u / 16)
  END
  EXECUTE st
    stage = 'loading combase/advapi32'
    stage = 'starting COM'
    stage = 'opening the notification manager'
    stage = 'creating the notifier (Init not called?)'
    stage = 'reading the notification XML'
    stage = 'creating the notification'
    stage = 'setting the tag or group'
    stage = 'building the data bindings'
    stage = 'showing the notification'
    stage = 'updating the notification'
    stage = 'notification centre history'
    stage = 'writing the registry'
  END
  RETURN CLIP(stage) & ' (0x' & hex & ')'

! What a Notify:Failed code means. pCode 0 = the last event's FailCode.
! The WPN_E_ codes are 0x803E01xx; their offset is found with LONG
! arithmetic (0x803E0100 is -2143420160 as a LONG).
NotificationClass.FailText PROCEDURE(LONG pCode=0)
c    LONG
hex  STRING(8)
u    ULONG
i    LONG
  CODE
  c = CHOOSE(pCode = 0, SELF.FailCode, pCode)
  CASE c + 2143420160
  OF 05H ; RETURN 'The Windows notification platform is not available'
  OF 11H ; RETURN 'Notifications from this program are turned off (Settings > System > Notifications)'
  OF 14H ; RETURN 'Windows notifications are turned off (Settings > System > Notifications)'
  OF 15H ; RETURN 'The notification is too large'
  OF 16H ; RETURN 'The tag or group is too long (64 characters at most)'
  END
  u = c
  LOOP i = 8 TO 1 BY -1
    hex[i] = SUB('0123456789ABCDEF', u % 16 + 1, 1)
    u = INT(u / 16)
  END
  RETURN 'Windows did not show the notification (0x' & hex & ')'

!=== quick ===================================================================
NotificationClass.Toast PROCEDURE(STRING pTitle, <STRING pBody>, <STRING pImage>, <STRING pTag>)
  CODE
  SELF.NewToast()
  SELF.Title(pTitle)
  IF NOT OMITTED(pBody) AND CLIP(pBody) <> '' THEN SELF.Line(pBody).
  IF NOT OMITTED(pImage) AND CLIP(pImage) <> '' THEN SELF.AppLogo(pImage).
  IF NOT OMITTED(pTag) THEN RETURN SELF.ShowToast(pTag).
  RETURN SELF.ShowToast()

!=== builder =================================================================
NotificationClass.NewToast PROCEDURE(<STRING pLaunchArgs>)
  CODE
  SELF.Reset()
  IF NOT OMITTED(pLaunchArgs) THEN SELF.Launch = CLIP(pLaunchArgs).

NotificationClass.Title PROCEDURE(STRING pText)
  CODE
  SELF.Vis.Add('<<text hint-maxLines="2">' & SELF.Escape(CLIP(pText)) & '<</text>')

NotificationClass.Line PROCEDURE(STRING pText)
  CODE
  SELF.Vis.Add('<<text>' & SELF.Escape(CLIP(pText)) & '<</text>')

NotificationClass.Attribution PROCEDURE(STRING pText)
  CODE
  SELF.Vis.Add('<<text placement="attribution">' & SELF.Escape(CLIP(pText)) & '<</text>')

NotificationClass.AppLogo PROCEDURE(STRING pImage, BYTE pCircle=1)
  CODE
  SELF.Vis.Add('<<image placement="appLogoOverride"' & CHOOSE(pCircle <> 0, ' hint-crop="circle"', '') & |
               ' src="' & SELF.Escape(CLIP(pImage)) & '"/>')

NotificationClass.HeroImage PROCEDURE(STRING pImage)
  CODE
  SELF.Vis.Add('<<image placement="hero" src="' & SELF.Escape(CLIP(pImage)) & '"/>')

NotificationClass.InlineImage PROCEDURE(STRING pImage)
  CODE
  SELF.Vis.Add('<<image src="' & SELF.Escape(CLIP(pImage)) & '"/>')

NotificationClass.ProgressBar PROCEDURE(<STRING pTitle>, <STRING pStatus>, REAL pValue=0, <STRING pValueText>)
  CODE
  SELF.Vis.Add('<<progress title="{{progressTitle}" value="{{progressValue}" ' & |
               'valueStringOverride="{{progressValueString}" status="{{progressStatus}"/>')
  SELF.SetData('progressTitle', '')
  SELF.SetData('progressStatus', '')
  SELF.SetData('progressValueString', '')
  IF NOT OMITTED(pTitle) THEN SELF.SetData('progressTitle', CLIP(pTitle)).
  IF NOT OMITTED(pStatus) THEN SELF.SetData('progressStatus', CLIP(pStatus)).
  IF NOT OMITTED(pValueText) THEN SELF.SetData('progressValueString', CLIP(pValueText)).
  SELF.SetData('progressValue', LEFT(FORMAT(pValue, @N6.3)))

NotificationClass.AddButton PROCEDURE(STRING pCaption, STRING pArgs, <STRING pImage>, <STRING pStyle>, <STRING pInputId>)
a  STRING(2048)
  CODE
  a = '<<action content="' & SELF.Escape(CLIP(pCaption)) & '" arguments="' & SELF.Escape(CLIP(pArgs)) & '"'
  IF NOT OMITTED(pImage) AND CLIP(pImage) <> ''
    a = CLIP(a) & ' imageUri="' & SELF.Escape(CLIP(pImage)) & '"'
  END
  IF NOT OMITTED(pInputId) AND CLIP(pInputId) <> ''
    a = CLIP(a) & ' hint-inputId="' & SELF.Escape(CLIP(pInputId)) & '"'
  END
  IF NOT OMITTED(pStyle) AND CLIP(pStyle) <> ''
    a = CLIP(a) & ' hint-buttonStyle="' & SELF.Escape(CLIP(pStyle)) & '"'
    SELF.Styled = TRUE
  END
  SELF.Act.Add(CLIP(a) & '/>')

NotificationClass.AddLinkButton PROCEDURE(STRING pCaption, STRING pUrl)
  CODE
  SELF.Act.Add('<<action content="' & SELF.Escape(CLIP(pCaption)) & '" activationType="protocol" arguments="' & |
               SELF.Escape(CLIP(pUrl)) & '"/>')

NotificationClass.AddSystemButton PROCEDURE(STRING pKind, <STRING pCaption>)
cap  STRING(256)
  CODE
  IF NOT OMITTED(pCaption) THEN cap = pCaption.
  SELF.Act.Add('<<action activationType="system" arguments="' & SELF.Escape(LOWER(CLIP(pKind))) & |
               '" content="' & SELF.Escape(CLIP(cap)) & '"/>')

NotificationClass.AddTextBox PROCEDURE(STRING pId, <STRING pPlaceholder>, <STRING pTitle>)
a  STRING(1024)
  CODE
  a = '<<input id="' & SELF.Escape(CLIP(pId)) & '" type="text"'
  IF NOT OMITTED(pPlaceholder) AND CLIP(pPlaceholder) <> ''
    a = CLIP(a) & ' placeHolderContent="' & SELF.Escape(CLIP(pPlaceholder)) & '"'
  END
  IF NOT OMITTED(pTitle) AND CLIP(pTitle) <> ''
    a = CLIP(a) & ' title="' & SELF.Escape(CLIP(pTitle)) & '"'
  END
  SELF.Inp.Add(CLIP(a) & '/>')

! pChoices = 'id1:Text one|id2:Text two' (an item without ':' is its own id)
NotificationClass.AddChoice PROCEDURE(STRING pId, STRING pChoices, <STRING pDefault>, <STRING pTitle>)
a      STRING(1024)
rest   STRING(4096)
item   STRING(512)
p      LONG
c      LONG
  CODE
  a = '<<input id="' & SELF.Escape(CLIP(pId)) & '" type="selection"'
  IF NOT OMITTED(pDefault) AND CLIP(pDefault) <> ''
    a = CLIP(a) & ' defaultInput="' & SELF.Escape(CLIP(pDefault)) & '"'
  END
  IF NOT OMITTED(pTitle) AND CLIP(pTitle) <> ''
    a = CLIP(a) & ' title="' & SELF.Escape(CLIP(pTitle)) & '"'
  END
  SELF.Inp.Add(CLIP(a) & '>')
  rest = pChoices
  LOOP WHILE CLIP(rest) <> ''
    p = INSTRING('|', rest, 1, 1)
    IF p
      item = rest[1 : p - 1]
      rest = rest[p + 1 : SIZE(rest)]
    ELSE
      item = rest
      rest = ''
    END
    IF CLIP(item) = '' THEN CYCLE.
    c = INSTRING(':', item, 1, 1)
    IF c
      SELF.Inp.Add('<<selection id="' & SELF.Escape(CLIP(item[1 : c - 1])) & '" content="' & |
                   SELF.Escape(CLIP(item[c + 1 : SIZE(item)])) & '"/>')
    ELSE
      SELF.Inp.Add('<<selection id="' & SELF.Escape(CLIP(item)) & '" content="' & SELF.Escape(CLIP(item)) & '"/>')
    END
  END
  SELF.Inp.Add('<</input>')

NotificationClass.Scenario PROCEDURE(STRING pScenario)
  CODE
  SELF.ScenarioName = CLIP(pScenario)

NotificationClass.LongDuration PROCEDURE(BYTE pOn=1)
  CODE
  SELF.LongDur = pOn

NotificationClass.Sound PROCEDURE(STRING pSound, BYTE pLoop=0)
  CODE
  SELF.AudioSrc = CLIP(pSound)
  SELF.AudioLoop = pLoop
  SELF.AudioOff = FALSE

NotificationClass.NoSound PROCEDURE()
  CODE
  SELF.AudioOff = TRUE

!=== raw XML, designs, variables =============================================
NotificationClass.Reset PROCEDURE()
  CODE
  SELF.Xml.Reset()
  SELF.Vis.Reset()
  SELF.Inp.Reset()
  SELF.Act.Reset()
  SELF.Out.Reset()
  FREE(SELF.Vars)
  FREE(SELF.Data)
  SELF.Launch = ''
  SELF.ScenarioName = ''
  SELF.LongDur = FALSE
  SELF.AudioSrc = ''
  SELF.AudioLoop = FALSE
  SELF.AudioOff = FALSE
  SELF.Styled = FALSE
  SELF.BaseFolder = ''

NotificationClass.AddXml PROCEDURE(STRING pXml)
  CODE
  SELF.Xml.Add(CLIP(pXml) & '<13,10>')

NotificationClass.LoadDesign PROCEDURE(STRING pFileName)
fn     CSTRING(261)
full   CSTRING(261)
buf    &CSTRING
n      LONG
i      LONG
  CODE
  SELF.Reset()
  fn = CLIP(pFileName)
  IF NOT (INSTRING(':', fn, 1, 1) OR SUB(fn, 1, 2) = '\\')
    IF SELF.ImageFolder
      fn = SELF.ImageFolder & '\' & CLIP(pFileName)
    ELSE
      tc_exefolder(full, SIZE(full))
      fn = full & '\' & CLIP(pFileName)
    END
  END
  n = 65536
  LOOP 2 TIMES
    buf &= NEW CSTRING(n)
    n = tc_readfile(fn, buf, n)
    IF n >= 0 THEN BREAK.
    DISPOSE(buf)
    IF n = -1 THEN RETURN FALSE.
    n = -n + 16
  END
  IF n < 0 THEN RETURN FALSE.
  IF n THEN SELF.Xml.Add(buf[1 : n]).
  DISPOSE(buf)
  tc_fullpath(fn, full, SIZE(full))                   ! images are relative to the design
  LOOP i = LEN(full) TO 1 BY -1
    IF full[i] = '\'
      SELF.BaseFolder = full[1 : i - 1]
      BREAK
    END
  END
  RETURN TRUE

NotificationClass.SetVar PROCEDURE(STRING pName, STRING pValue)
  CODE
  SELF.Vars.UName = UPPER(CLIP(pName))
  GET(SELF.Vars, SELF.Vars.UName)
  IF ERRORCODE()
    SELF.Vars.Name = CLIP(pName)
    SELF.Vars.UName = UPPER(CLIP(pName))
    SELF.Vars.Value = pValue
    ADD(SELF.Vars, SELF.Vars.UName)
  ELSE
    SELF.Vars.Value = pValue
    PUT(SELF.Vars)
  END

NotificationClass.ClearVars PROCEDURE()
  CODE
  FREE(SELF.Vars)

NotificationClass.SetData PROCEDURE(STRING pKey, STRING pValue)
  CODE
  SELF.Data.UName = UPPER(CLIP(pKey))
  GET(SELF.Data, SELF.Data.UName)
  IF ERRORCODE()
    SELF.Data.Name = CLIP(pKey)
    SELF.Data.UName = UPPER(CLIP(pKey))
    SELF.Data.Value = pValue
    ADD(SELF.Data, SELF.Data.UName)
  ELSE
    SELF.Data.Value = pValue
    PUT(SELF.Data)
  END

NotificationClass.XmlText PROCEDURE()
  CODE
  SELF.Assemble()
  RETURN SELF.Out.Text()

! Build the final XML into SELF.Out: from the raw XML if there is any, else
! from the builder; then fill in the {placeholders} and resolve image paths.
NotificationClass.Assemble PROCEDURE()
src    &NotifyBufClass
  CODE
  IF SELF.Xml.Len() = 0
    SELF.Xml.Add('<<toast')
    IF SELF.Launch THEN SELF.Xml.Add(' launch="' & SELF.Escape(SELF.Launch) & '"').
    IF SELF.ScenarioName THEN SELF.Xml.Add(' scenario="' & SELF.Escape(SELF.ScenarioName) & '"').
    IF SELF.LongDur THEN SELF.Xml.Add(' duration="long"').
    IF SELF.Styled THEN SELF.Xml.Add(' useButtonStyle="true"').
    SELF.Xml.Add('><<visual><<binding template="ToastGeneric">')
    SELF.Xml.Add(SELF.Vis.Text())
    SELF.Xml.Add('<</binding><</visual>')
    IF SELF.Inp.Len() OR SELF.Act.Len()
      SELF.Xml.Add('<<actions>')
      SELF.Xml.Add(SELF.Inp.Text())
      SELF.Xml.Add(SELF.Act.Text())
      SELF.Xml.Add('<</actions>')
    END
    IF SELF.AudioOff
      SELF.Xml.Add('<<audio silent="true"/>')
    ELSIF SELF.AudioSrc
      SELF.Xml.Add('<<audio src="' & SELF.Escape(SELF.AudioSrc) & '"' & CHOOSE(SELF.AudioLoop <> 0, ' loop="true"', '') & '/>')
    END
    SELF.Xml.Add('<</toast>')
    SELF.Vis.Reset()                       ! consumed: the XML now holds them
    SELF.Inp.Reset()
    SELF.Act.Reset()
  END
  SELF.Substitute(SELF.Xml.Text())

! {Name} -> the escaped value of SetVar('Name'); anything else in braces is
! left alone (Windows' own {bindings}). Then every src="..." and imageUri="..."
! that is a local path becomes a file:/// URI.
NotificationClass.Substitute PROCEDURE(STRING pXml)
n      LONG
i      LONG
j      LONG
k      LONG
q      LONG
found  BYTE
mid    &NotifyBufClass
s      &STRING
val    STRING(1024)
  CODE
  SELF.Out.Reset()
  n = LEN(pXml)
  mid &= NEW NotifyBufClass
  i = 1
  LOOP WHILE i <= n
    j = INSTRING('{{', pXml[i : n], 1, 1)
    IF j = 0
      mid.Add(pXml[i : n])
      BREAK
    END
    j += i - 1
    IF j > i THEN mid.Add(pXml[i : j - 1]).
    k = INSTRING('}', pXml[j : n], 1, 1)
    IF k = 0 OR k > 66
      mid.Add('{{')
      i = j + 1
      CYCLE
    END
    k += j - 1
    found = FALSE
    IF k > j + 1
      SELF.Vars.UName = UPPER(pXml[j + 1 : k - 1])
      GET(SELF.Vars, SELF.Vars.UName)
      IF NOT ERRORCODE() THEN found = TRUE.
    END
    IF found
      mid.Add(SELF.Escape(CLIP(SELF.Vars.Value)))
    ELSE
      mid.Add(pXml[j : k])
      IF k > j + 1 AND k - j <= 65 AND SELF.IsName(pXml[j + 1 : k - 1])      ! a Windows binding: give it data
        SELF.Data.UName = UPPER(pXml[j + 1 : k - 1])
        GET(SELF.Data, SELF.Data.UName)
        IF ERRORCODE()
          SELF.SetData(pXml[j + 1 : k - 1], CHOOSE(SELF.Data.UName = 'PROGRESSVALUE', '0', ''))
        END
      END
    END
    i = k + 1
  END
  ! --- image paths -> file:/// ---
  IF mid.Len() = 0
    DISPOSE(mid)
    RETURN
  END
  s &= mid.S
  n = mid.Len()
  i = 1
  LOOP WHILE i <= n
    j = INSTRING('src="', s[i : n], 1, 1)
    k = INSTRING('imageUri="', s[i : n], 1, 1)
    IF j = 0 AND k = 0
      SELF.Out.Add(s[i : n])
      BREAK
    END
    IF j = 0 OR (k AND k < j)
      j = k + 9                                      ! just past imageUri="
    ELSE
      j = j + 4                                      ! just past src="
    END
    j += i - 1
    SELF.Out.Add(s[i : j])
    q = INSTRING('"', s[j + 1 : n], 1, 1)
    IF q = 0
      SELF.Out.Add(s[j + 1 : n])
      BREAK
    END
    q += j
    IF q > j + 1
      val = s[j + 1 : q - 1]
      SELF.Out.Add(SELF.FileUri(CLIP(val)))
    END
    i = q
  END
  DISPOSE(mid)

! Is it a name: a letter or _ then letters, digits or _ ?
NotificationClass.IsName PROCEDURE(STRING pText)
i   LONG
c   STRING(1)
  CODE
  IF LEN(pText) = 0 THEN RETURN FALSE.
  LOOP i = 1 TO LEN(pText)
    c = pText[i]
    IF c = '_' OR (c >= 'A' AND c <= 'Z') OR (c >= 'a' AND c <= 'z') THEN CYCLE.
    IF i > 1 AND c >= '0' AND c <= '9' THEN CYCLE.
    RETURN FALSE
  END
  RETURN TRUE

! A local path (relative or absolute) becomes file:///C:/x/y.png; anything
! that already has a scheme (http://, ms-appdata:, file:) is left as it is.
NotificationClass.FileUri PROCEDURE(STRING pPath)
p      STRING(1024)
base   CSTRING(261)
r      STRING(2048)
i      LONG
ch     STRING(1)
  CODE
  p = pPath
  IF INSTRING('://', p, 1, 1) OR LOWER(SUB(p, 1, 3)) = 'ms-' OR LOWER(SUB(p, 1, 5)) = 'file:' OR LOWER(SUB(p, 1, 5)) = 'data:'
    RETURN CLIP(p)
  END
  IF NOT (SUB(p, 2, 1) = ':' OR SUB(p, 1, 2) = '\\')
    IF SELF.ImageFolder
      base = SELF.ImageFolder
    ELSIF SELF.BaseFolder
      base = SELF.BaseFolder
    ELSE
      tc_exefolder(base, SIZE(base))
    END
    p = base & '\' & CLIP(p)
  END
  r = CHOOSE(SUB(p, 1, 2) = '\\', 'file:', 'file:///')
  LOOP i = 1 TO LEN(CLIP(p))
    ch = p[i]
    CASE ch
    OF '\'
      r = CLIP(r) & '/'
    OF ' '
      r = CLIP(r) & '%20'
    ELSE
      r = CLIP(r) & ch
    END
  END
  RETURN CLIP(r)

!=== show / change / remove ==================================================
NotificationClass.ShowToast PROCEDURE(<STRING pTag>, <STRING pGroup>, BYTE pSilent=0)
x      &CSTRING
tg     CSTRING(65)
gr     CSTRING(65)
dt     &CSTRING
db     &NotifyBufClass
i      LONG
id     LONG
  CODE
  SELF.Assemble()
  IF NOT OMITTED(pTag) THEN tg = CLIP(pTag).
  IF NOT OMITTED(pGroup) THEN gr = CLIP(pGroup).
  IF tg = '' AND RECORDS(SELF.Data)              ! bindings need a tag to be updated later
    SELF.AutoTag += 1
    tg = 'n' & THREAD() & '_' & SELF.AutoTag
  END
  db &= NEW NotifyBufClass
  LOOP i = 1 TO RECORDS(SELF.Data)
    GET(SELF.Data, i)
    db.Add(SELF.Data.Name & '=' & CLIP(SELF.Data.Value) & '<10>')
  END
  dt &= NEW CSTRING(db.Len() + 1)
  dt = db.Text()
  x &= NEW CSTRING(SELF.Out.Len() + 1)
  x = SELF.Out.Text()
  SELF.Seq += 1
  id = tc_show(x, tg, gr, dt, SELF.Seq, pSilent)
  DISPOSE(x)
  DISPOSE(dt)
  DISPOSE(db)
  IF id
    SELF.LastId = id
    SELF.LastTag = tg
  ELSE
    SELF.LastError = tc_lasterror()
  END
  RETURN id

NotificationClass.UpdateData PROCEDURE(<STRING pTag>, <STRING pGroup>)
tg     CSTRING(65)
gr     CSTRING(65)
dt     &CSTRING
db     &NotifyBufClass
i      LONG
r      LONG
  CODE
  IF NOT OMITTED(pTag) THEN tg = CLIP(pTag).
  IF tg = '' THEN tg = SELF.LastTag.
  IF NOT OMITTED(pGroup) THEN gr = CLIP(pGroup).
  db &= NEW NotifyBufClass
  LOOP i = 1 TO RECORDS(SELF.Data)
    GET(SELF.Data, i)
    db.Add(SELF.Data.Name & '=' & CLIP(SELF.Data.Value) & '<10>')
  END
  dt &= NEW CSTRING(db.Len() + 1)
  dt = db.Text()
  SELF.Seq += 1
  r = tc_update(tg, gr, dt, SELF.Seq)
  DISPOSE(dt)
  DISPOSE(db)
  RETURN r

NotificationClass.UpdateProgress PROCEDURE(REAL pValue, <STRING pStatus>, <STRING pValueText>, <STRING pTag>, <STRING pGroup>)
v  REAL
  CODE
  v = pValue
  IF v < 0 THEN v = 0.
  IF v > 1 THEN v = 1.
  SELF.SetData('progressValue', LEFT(FORMAT(v, @N6.3)))
  IF NOT OMITTED(pStatus) THEN SELF.SetData('progressStatus', CLIP(pStatus)).
  IF NOT OMITTED(pValueText) THEN SELF.SetData('progressValueString', CLIP(pValueText)).
  IF OMITTED(pTag)
    RETURN SELF.UpdateData()
  ELSIF OMITTED(pGroup)
    RETURN SELF.UpdateData(pTag)
  END
  RETURN SELF.UpdateData(pTag, pGroup)

NotificationClass.Hide PROCEDURE(LONG pId=0)
  CODE
  RETURN CHOOSE(tc_hide(CHOOSE(pId = 0, SELF.LastId, pId)) <> 0, TRUE, FALSE)

NotificationClass.Remove PROCEDURE(STRING pTag, <STRING pGroup>)
tg  CSTRING(65)
gr  CSTRING(65)
  CODE
  tg = CLIP(pTag)
  IF NOT OMITTED(pGroup) THEN gr = CLIP(pGroup).
  IF tg = '' THEN RETURN FALSE.                    ! '' would mean "everything": use RemoveAll
  RETURN CHOOSE(tc_remove(tg, gr) <> 0, TRUE, FALSE)

NotificationClass.RemoveGroup PROCEDURE(STRING pGroup)
tg  CSTRING(2)
gr  CSTRING(65)
  CODE
  gr = CLIP(pGroup)
  IF gr = '' THEN RETURN FALSE.
  RETURN CHOOSE(tc_remove(tg, gr) <> 0, TRUE, FALSE)

NotificationClass.RemoveAll PROCEDURE()
tg  CSTRING(2)
gr  CSTRING(2)
  CODE
  RETURN CHOOSE(tc_remove(tg, gr) <> 0, TRUE, FALSE)

!=== events ==================================================================
NotificationClass.Pending PROCEDURE()
  CODE
  RETURN tc_pending()

NotificationClass.NextEvent PROCEDURE()
k   LONG
id  LONG
rs  LONG
hr  LONG
  CODE
  k = tc_next(id, rs, hr)
  SELF.EventKind = k
  SELF.EventId = id
  SELF.DismissReason = rs
  SELF.FailCode = hr
  SELF.EventArgs = ''
  SELF.EventTag = ''
  IF k = 0 THEN RETURN FALSE.
  tc_args(SELF.EventArgs, SIZE(SELF.EventArgs))
  tc_tag(SELF.EventTag, SIZE(SELF.EventTag))
  RETURN TRUE

! 'action=open;id=1043' (or & separated) -> Arg('id') = '1043'.
! Arguments with no '=' at all are returned whole for Arg('').
NotificationClass.Arg PROCEDURE(STRING pKey)
a     STRING(2049)
key   STRING(128)
i     LONG
st    LONG
e     LONG
eq    LONG
  CODE
  a = SELF.EventArgs
  key = UPPER(CLIP(pKey))
  IF key = '' THEN RETURN CLIP(a).
  st = 1
  LOOP i = 1 TO LEN(CLIP(a)) + 1
    IF i > LEN(CLIP(a)) OR a[i] = ';' OR a[i] = '&'
      e = i - 1
      IF e >= st
        eq = INSTRING('=', a[st : e], 1, 1)
        IF eq
          eq += st - 1
          IF eq > st AND UPPER(CLIP(LEFT(a[st : eq - 1]))) = CLIP(key)
            IF eq = e THEN RETURN ''.
            RETURN a[eq + 1 : e]
          END
        END
      END
      st = i + 1
    END
  END
  RETURN ''

NotificationClass.Input PROCEDURE(STRING pId)
id   CSTRING(129)
v    CSTRING(4097)
  CODE
  id = CLIP(pId)
  IF tc_input(id, v, SIZE(v)) < 0 THEN RETURN ''.
  RETURN v

! Bring a window forward (call it with 0{PROP:Handle} when a click arrives).
NotificationClass.BringToFront PROCEDURE(LONG pHandle)
  CODE
  RETURN CHOOSE(tc_front(pHandle) <> 0, TRUE, FALSE)

!=== helpers =================================================================
NotificationClass.Escape PROCEDURE(STRING pText)
n     LONG
i     LONG
o     LONG
need  LONG
ch    STRING(1)
  CODE
  n = LEN(pText)
  IF n = 0 THEN RETURN ''.
  need = 0
  LOOP i = 1 TO n
    CASE pText[i]
    OF '&'
      need += 5
    OF '<<' OROF '>'
      need += 4
    OF '"' OROF ''''
      need += 6
    ELSE
      need += 1
    END
  END
  DISPOSE(SELF.Tmp)
  SELF.Tmp &= NEW STRING(need)
  o = 0
  LOOP i = 1 TO n
    ch = pText[i]
    CASE ch
    OF '&'
      SELF.Tmp[o + 1 : o + 5] = '&amp;'
      o += 5
    OF '<<'
      SELF.Tmp[o + 1 : o + 4] = '&lt;'
      o += 4
    OF '>'
      SELF.Tmp[o + 1 : o + 4] = '&gt;'
      o += 4
    OF '"'
      SELF.Tmp[o + 1 : o + 6] = '&quot;'
      o += 6
    OF ''''
      SELF.Tmp[o + 1 : o + 6] = '&apos;'
      o += 6
    ELSE
      o += 1
      SELF.Tmp[o] = ch
    END
  END
  RETURN SELF.Tmp
