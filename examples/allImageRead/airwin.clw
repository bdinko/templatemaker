   PROGRAM



   INCLUDE('ABERROR.INC'),ONCE
   INCLUDE('ABUTIL.INC'),ONCE
   INCLUDE('ERRORS.CLW'),ONCE
   INCLUDE('KEYCODES.CLW'),ONCE
   INCLUDE('ABFUZZY.INC'),ONCE
INCLUDE('ImageClass.INC'),ONCE
  PRAGMA('compile(d2dcanvas.c)')                              ! the GPU canvas, built by Clarion's own C compiler
AirImg:Secs          EQUATE(20)                     ! how long a download may take
!  The Windows constants the readers need. They live HERE, once and prefixed,
!  because a plain GENERIC_WRITE or SW_HIDE in a procedure's data collides with
!  every other template that declares the same thing in the same module - and
!  with the next procedure of ours that needs it. "Label duplicated" is the
!  compiler saying two of us picked the same word.
AirImg:GenericWrite  EQUATE(40000000h)
AirImg:CreateAlways  EQUATE(2)
AirImg:AttrNormal    EQUATE(00000080h)
AirImg:BadHandle     EQUATE(-1)
AirImg:UseShowWindow EQUATE(00000001h)
AirImg:SwHide        EQUATE(0)
AirImg:NoWindow      EQUATE(08000000h)
AirImg:Forever       EQUATE(0FFFFFFFFh)
AirImg:GwlWndProc    EQUATE(-4)
AirImg:MouseWheel    EQUATE(020Ah)
AirImg:MkControl     EQUATE(0008h)
AirImg:WheelUp       EQUATE(EVENT:User + 216)                 ! the wheel, carried in from the
AirImg:WheelDown     EQUATE(EVENT:User + 217)                 !   window procedure
AirImg:CtrlUp        EQUATE(EVENT:User + 218)                 ! ... with Ctrl held down
AirImg:CtrlDown      EQUATE(EVENT:User + 219)
AirImg:Scrolled      EQUATE(EVENT:User + 215)                 ! a canvas scrollbar was moved
AirImg:GwlStyle      EQUATE(-16)
AirImg:HScroll       EQUATE(00100000h)                        ! WS_HSCROLL
AirImg:VScroll       EQUATE(00200000h)                        ! WS_VSCROLL
AirImg:FrameChanged  EQUATE(0020h)                            ! SWP_FRAMECHANGED
AirImg:NoMove        EQUATE(0002h)
AirImg:NoSize        EQUATE(0001h)
AirImg:NoZOrder      EQUATE(0004h)
AirImg:SbHorz        EQUATE(0)
AirImg:SbVert        EQUATE(1)
AirImg:WmHScroll     EQUATE(0114h)
AirImg:WmVScroll     EQUATE(0115h)
AirImg:SifRange      EQUATE(1)
AirImg:SifPage       EQUATE(2)
AirImg:SifPos        EQUATE(4)
AirImg:SifTrack      EQUATE(10h)

   MAP
     MODULE('AIRWIN_BC.CLW')
DctInit     PROCEDURE                                      ! Initializes the dictionary definition module
DctKill     PROCEDURE                                      ! Kills the dictionary definition module
     END
!--- Application Global and Exported Procedure Definitions --------------------------------------------
         MODULE('win32')
     airApi_TempPath(ULONG,*CSTRING),ULONG,RAW,PASCAL,PROC,NAME('GetTempPathA')
     airApi_CreateFile(LONG,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,NAME('CreateFileA')
     airApi_WriteFile(LONG,LONG,ULONG,LONG,LONG),LONG,PASCAL,PROC,NAME('WriteFile')
     airApi_CloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
     airApi_CreateProcess(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
     airApi_WaitObject(LONG,ULONG),LONG,PASCAL,PROC,NAME('WaitForSingleObject')
     airApi_SetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
     airApi_GetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
     airApi_RemoveProp(ULONG hWnd,LONG lpString),LONG,PASCAL,PROC,NAME('RemovePropA')
     airApi_CallWndProc(LONG lpPrevWndFunc,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
     airApi_SetWindowLong(ULONG hWnd,LONG nIndex,LONG dwNewLong),LONG,PASCAL,PROC,NAME('SetWindowLongA')
     airApi_GetWindowLong(ULONG hWnd,LONG nIndex),LONG,PASCAL,NAME('GetWindowLongA')
     airApi_SetWindowPos(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG flags),LONG,PASCAL,PROC,NAME('SetWindowPos')
     airApi_SetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
     airApi_GetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi),LONG,PASCAL,PROC,NAME('GetScrollInfo')
         END
     AirImg_Temp(STRING,STRING),STRING
     AirImg_PutBytes(*STRING,LONG,STRING),BYTE,PROC
     AirImg_LoadPath(ImageClass,STRING),BYTE,PROC
     AirImg_LoadBytes(ImageClass,*STRING,LONG,STRING),BYTE,PROC
     AirImg_LoadB64(ImageClass,STRING,STRING),BYTE,PROC
     AirImg_LoadUrl(ImageClass,STRING,STRING,LONG),BYTE,PROC
     AirImg_Render(ImageClass,LONG,LONG,LONG,ULONG,STRING),STRING
     AirImg_FitPct(ImageClass,LONG,LONG),LONG
     AirImg_Filter(),STRING
     AirImg_WheelProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
     AirImg_HookWheel(LONG),BYTE,PROC
     AirImg_DropWheel(LONG),LONG,PROC
     AirImg_BarProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
     AirImg_HookBars(LONG),BYTE,PROC
     AirImg_DropBars(LONG),LONG,PROC
     AirImg_SetBar(LONG,LONG,LONG,LONG,LONG)
     AirImg_BarPos(LONG,LONG),LONG
         MODULE('d2dcanvas.c')
     d2c_Available(),LONG,NAME('_d2c_Available')
     d2c_Attach(LONG hwnd),LONG,NAME('_d2c_Attach')
     d2c_Detach(LONG h),NAME('_d2c_Detach')
     d2c_LoadBmp(LONG h,*CSTRING path),LONG,RAW,PROC,NAME('_d2c_LoadBmp')
     d2c_SetView(LONG h,REAL zoom,REAL panX,REAL panY,ULONG bg,LONG smooth),NAME('_d2c_SetView')
     d2c_Resize(LONG h),LONG,PROC,NAME('_d2c_Resize')
     d2c_ImageW(LONG h),LONG,NAME('_d2c_ImageW')
     d2c_ImageH(LONG h),LONG,NAME('_d2c_ImageH')
     d2c_HasImage(LONG h),LONG,NAME('_d2c_HasImage')
     d2c_ViewW(LONG h),LONG,NAME('_d2c_ViewW')
     d2c_ViewH(LONG h),LONG,NAME('_d2c_ViewH')
     d2c_Clear(LONG h),NAME('_d2c_Clear')
         END
     myQRUrlEncode(STRING pText),STRING
     myQRLoad(SIGNED pImageFeq, STRING pData, SIGNED pSize, STRING pEccLetter, SIGNED pMargin),BYTE,PROC
       MODULE('kernel32')
     myQR_CreateProcess(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
     myQR_WaitObject(LONG,ULONG),LONG,PASCAL,PROC,NAME('WaitForSingleObject')
     myQR_CloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
       END
   END

SilentRunning        BYTE(0)                               ! Set true when application is running in 'silent mode'

!region File Declaration
!endregion


FuzzyMatcher         FuzzyClass                            ! Global fuzzy matcher
GlobalErrorStatus    ErrorStatusClass,THREAD
GlobalErrors         ErrorClass                            ! Global error manager
INIMgr               INIClass                              ! Global non-volatile storage manager
GlobalRequest        BYTE(0),THREAD                        ! Set when a browse calls a form, to let it know action to perform
GlobalResponse       BYTE(0),THREAD                        ! Set to the response from the form
VCRRequest           LONG(0),THREAD                        ! Set to the request from the VCR buttons

Dictionary           CLASS,THREAD
Construct              PROCEDURE
Destruct               PROCEDURE
                     END


  CODE
  GlobalErrors.Init(GlobalErrorStatus)
  FuzzyMatcher.Init                                        ! Initilaize the browse 'fuzzy matcher'
  FuzzyMatcher.SetOption(MatchOption:NoCase, 1)            ! Configure case matching
  FuzzyMatcher.SetOption(MatchOption:WordOnly, 0)          ! Configure 'word only' matching
  INIMgr.Init('.\airwin.INI', NVD_INI)                     ! Configure INIManager to use INI file
  DctInit()
  
  INIMgr.Update
  INIMgr.Kill                                              ! Destroy INI manager
  FuzzyMatcher.Kill                                        ! Destroy fuzzy matcher
    
!-----------------------------------------------------------------------------
!  allImageRead - the shared readers, written once per application by the
!  allImageReadGlobal extension.
!-----------------------------------------------------------------------------
!  A working file in the Windows TEMP folder. The key makes the name unique
!  per canvas, and it is FIXED - the same canvas reuses the same name for ever,
!  so the folder never fills up.
AirImg_Temp PROCEDURE(STRING pTag,STRING pExt)
tdir CSTRING(261)
n    ULONG,AUTO
  CODE
  tdir = ''
  n = airApi_TempPath(255,tdir)
  IF ~n OR n > 254 THEN tdir = '.\' .
  IF tdir[LEN(tdir) : LEN(tdir)] <> '\' THEN tdir = CLIP(tdir) & '\' .
  RETURN CLIP(tdir) & 'air_' & CLIP(pTag) & CLIP(pExt)

!  Bytes onto disk. Returns 1 when every byte arrived.
AirImg_PutBytes PROCEDURE(*STRING pData,LONG pLen,STRING pPath)
fname CSTRING(261)
h     LONG,AUTO
wrote ULONG,AUTO
ok    LONG,AUTO
  CODE
  IF pLen < 1 THEN RETURN 0.
  fname = CLIP(pPath)
  wrote = 0
  h = airApi_CreateFile(ADDRESS(fname),AirImg:GenericWrite,0,0,                |
                        AirImg:CreateAlways,AirImg:AttrNormal,0)
  IF h = AirImg:BadHandle OR ~h THEN RETURN 0.
  ok = airApi_WriteFile(h,ADDRESS(pData),pLen,ADDRESS(wrote),0)
  airApi_CloseHandle(h)
  IF ok AND wrote = pLen THEN RETURN 1.
  RETURN 0

!  A picture that is already a file. ImageClass sniffs the signature, so the
!  extension is never trusted - a .jpg that is really a PNG still opens.
AirImg_LoadPath PROCEDURE(ImageClass pImg,STRING pPath)
  CODE
  IF ~LEN(CLIP(pPath))
    pImg.Kill()
    RETURN 0
  END
  IF ~EXISTS(CLIP(pPath))
    pImg.Kill()
    RETURN 0
  END
  RETURN pImg.LoadFile(CLIP(pPath))

!  A picture that is bytes - a BLOB the caller has sliced, or a string in
!  memory. It goes to the working file and is read back from there.
AirImg_LoadBytes PROCEDURE(ImageClass pImg,*STRING pData,LONG pLen,STRING pTag)
fname CSTRING(261)
  CODE
  IF pLen < 1
    pImg.Kill()
    RETURN 0
  END
  fname = AirImg_Temp(pTag,'.tmp')
  IF ~AirImg_PutBytes(pData,pLen,fname)
    pImg.Kill()
    RETURN 0
  END
  RETURN pImg.LoadFile(fname)

!  A picture that arrived as text. Standard and URL-safe alphabets, any amount
!  of white space, and a leading data: URI is stepped over.
AirImg_LoadB64 PROCEDURE(ImageClass pImg,STRING pB64,STRING pTag)
alpha STRING('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/')
tab   STRING(256),STATIC
built BYTE,STATIC
out   &STRING
i     LONG,AUTO
n     LONG,AUTO
p     LONG,AUTO
c     LONG,AUTO
v     LONG,AUTO
acc   LONG,AUTO
bits  LONG,AUTO
o     LONG,AUTO
ok    BYTE,AUTO
  CODE
  IF ~built                                                   ! 255 marks "not a base64 character"
    tab = ALL(CHR(255))
    LOOP i = 1 TO 64
      c = VAL(alpha[i : i]) + 1
      tab[c : c] = CHR(i - 1)
    END
    c = VAL('-') + 1 ; tab[c : c] = CHR(62)                   ! the URL-safe pair
    c = VAL('_') + 1 ; tab[c : c] = CHR(63)
    built = 1
  END
  n = LEN(CLIP(pB64))
  IF n < 4
    pImg.Kill()
    RETURN 0
  END
  p = INSTRING('base64,',pB64,1,1)                            ! data:image/png;base64,....
  IF p THEN p += 7 ELSE p = 1.
  out &= NEW(STRING(INT((n - p + 1) * 3 / 4) + 8))
  acc = 0
  bits = 0
  o = 0
  LOOP i = p TO n
    c = VAL(pB64[i : i])
    IF c = VAL('=') THEN BREAK.
    v = VAL(tab[c + 1 : c + 1])
    IF v = 255 THEN CYCLE.                                    ! CR, LF, space, quote - skip it
    acc = BOR(BSHIFT(acc,6),v)
    bits += 6
    IF bits >= 8
      bits -= 8
      o += 1
      out[o : o] = CHR(BAND(BSHIFT(acc,-bits),0FFh))
      acc = BAND(acc,BSHIFT(1,bits) - 1)                      ! keep only the bits still owed
    END
  END
  IF o < 1
    DISPOSE(out)
    pImg.Kill()
    RETURN 0
  END
  ok = AirImg_LoadBytes(pImg,out,o,pTag)
  DISPOSE(out)
  RETURN ok

!  A picture on the internet. curl.exe is run HIDDEN and SYNCHRONOUSLY -
!  CreateProcessA with CREATE_NO_WINDOW plus STARTF_USESHOWWINDOW / SW_HIDE,
!  then WaitForSingleObject. curl ships with Windows 10 and 11 in System32.
AirImg_LoadUrl PROCEDURE(ImageClass pImg,STRING pUrl,STRING pTag,LONG pSeconds)
cmd   CSTRING(2048)                                           ! CreateProcessA writes back into this
fname CSTRING(261)
secs  LONG,AUTO
si    GROUP                                                   ! STARTUPINFOA
cb      ULONG
lpRes   LONG(0)
lpDesk  LONG(0)
lpTitle LONG(0)
dwX     ULONG
dwY     ULONG
dwXS    ULONG
dwYS    ULONG
dwXC    ULONG
dwYC    ULONG
dwFill  ULONG
dwFlags ULONG
wShow   SHORT(0)
cbRes2  SHORT(0)
lpRes2  LONG(0)
hIn     LONG
hOut    LONG
hErr    LONG
      END
pi    GROUP                                                   ! PROCESS_INFORMATION
hProc   LONG
hThr    LONG
dwPid   ULONG
dwTid   ULONG
      END
  CODE
  IF ~LEN(CLIP(pUrl))
    pImg.Kill()
    RETURN 0
  END
  secs = pSeconds
  IF secs < 1 THEN secs = 20.
  fname = AirImg_Temp(pTag,'.dl')
  REMOVE(fname)
!  -s silent, -L follow redirects, --max-time so a hung server cannot hold the
!  program up for ever, -o writes the body. <34> is a double quote: Windows
!  argument quoting wants double quotes, not apostrophes.
  cmd = 'curl -s -L --max-time ' & secs & |
        ' -o <34>' & CLIP(fname) & '<34> <34>' & CLIP(pUrl) & '<34>'
  si.cb      = SIZE(si)
  si.dwFlags = AirImg:UseShowWindow
  si.wShow   = AirImg:SwHide
  IF ~airApi_CreateProcess(0,ADDRESS(cmd),0,0,0,AirImg:NoWindow,0,0,ADDRESS(si),ADDRESS(pi))
    pImg.Kill()                                               ! curl.exe is not there
    RETURN 0
  END
  airApi_WaitObject(pi.hProc,AirImg:Forever)
  airApi_CloseHandle(pi.hThr)
  airApi_CloseHandle(pi.hProc)
  IF ~EXISTS(fname)
    pImg.Kill()
    RETURN 0
  END
  RETURN pImg.LoadFile(fname)

!  Fit a COPY of the picture to a box and leave it on disk as a PNG. The
!  original is never touched. Used for report bands, where the print engine
!  wants a file it can open. Returns the path, or blank when there is nothing
!  to show.
AirImg_Render PROCEDURE(ImageClass pImg,LONG pW,LONG pH,LONG pMode,ULONG pBack,STRING pTag)
cv   ImageClass
fname CSTRING(261)
  CODE
  IF ~pImg.Ok() OR pW < 4 OR pH < 4 THEN RETURN ''.
  IF ~pImg.CloneInto(cv) THEN RETURN ''.
  IF pMode >= 0 THEN cv.Fit(pW,pH,pMode,pBack).
  fname = AirImg_Temp(pTag,'.png')
  IF ~cv.SaveFile(fname,Img:Png) THEN RETURN ''.
  RETURN CLIP(fname)

!  At what per cent is the picture showing when it is fitted to a box? The
!  answer is where a zoom step starts from.
AirImg_FitPct PROCEDURE(ImageClass pImg,LONG pW,LONG pH)
a LONG,AUTO
b LONG,AUTO
  CODE
  IF ~pImg.Ok() OR pImg.Wide() < 1 OR pImg.High() < 1 THEN RETURN 100.
  a = INT(100 * pW / pImg.Wide())
  b = INT(100 * pH / pImg.High())
  IF b < a THEN a = b.
  IF a < 5 THEN a = 5.
  IF a > 1600 THEN a = 1600.
  RETURN a

!  ---- the mouse wheel ------------------------------------------------------
!  The hooking is done HERE, in the module that also defines the callback, and
!  that is not a stylistic choice. ADDRESS(procedure) does not answer the same
!  thing everywhere: taken in a MEMBER module for a procedure defined in the
!  program module it yields the import thunk, not the procedure, and handing
!  Windows that thunk as a window procedure crashes the moment a message
!  arrives. So no canvas ever takes this address - it just asks for a hook.
!
!  The window's own procedure is parked ON the window with SetProp, so one
!  callback serves every window in the program with no bookkeeping of ours.
!  Returns 1 to the FIRST caller only: a second canvas on the same window must
!  not hook it twice.
AirImg_HookWheel PROCEDURE(LONG pHwnd)
prop CSTRING('AirImgOldWndProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF airApi_GetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.       ! already hooked by another canvas
  old = airApi_SetWindowLong(pHwnd,AirImg:GwlWndProc,ADDRESS(AirImg_WheelProc))
  IF ~old THEN RETURN 0.
  airApi_SetProp(pHwnd,ADDRESS(prop),old)
  RETURN 1

!  Give the window its own procedure back and forget it.
AirImg_DropWheel PROCEDURE(LONG pHwnd)
prop CSTRING('AirImgOldWndProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  old = airApi_GetProp(pHwnd,ADDRESS(prop))
  IF old
    airApi_SetWindowLong(pHwnd,AirImg:GwlWndProc,old)
  END
  airApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

!  The window procedure. WM_MOUSEWHEEL carries the distance in the high word of
!  wParam - signed, one notch is 120 - and the modifier keys in the low word,
!  where 0008h is Ctrl (this is how Clarion's own smartzoom.clw reads it). All
!  it does here is turn the message into an EVENT the ACCEPT loop understands,
!  and then hand the message on to the window's own procedure so nothing else
!  changes.
AirImg_WheelProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
prop CSTRING('AirImgOldWndProc')
old  LONG,AUTO
dz   LONG,AUTO
  CODE
  old = airApi_GetProp(hWnd,ADDRESS(prop))
  IF wMsg = AirImg:MouseWheel
    dz = BSHIFT(BAND(wParam,0FFFF0000h),-16)                  ! the high word is the distance
    IF dz > 32767 THEN dz -= 65536.                           ! and it is signed
    IF BAND(wParam,AirImg:MkControl)
      IF dz > 0
        POST(AirImg:CtrlUp)
      ELSIF dz < 0
        POST(AirImg:CtrlDown)
      END
    ELSE
      IF dz > 0
        POST(AirImg:WheelUp)
      ELSIF dz < 0
        POST(AirImg:WheelDown)
      END
    END
  END
  IF old
    RETURN airApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0

!  ---- the scrollbars ---------------------------------------------------
!  A REGION is not born with scrollbars, so the styles go on at run time and
!  the control is subclassed for the two scroll messages. Same shape as the
!  wheel hook, and for the same reason: the address of the callback is taken
!  HERE, in the module that defines it, never in a member module.
AirImg_HookBars PROCEDURE(LONG pHwnd)
prop CSTRING('AirImgBarProc')
old  LONG,AUTO
sty  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF airApi_GetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.       ! already hooked
  sty = airApi_GetWindowLong(pHwnd,AirImg:GwlStyle)
  airApi_SetWindowLong(pHwnd,AirImg:GwlStyle,                                 |
                       BOR(BOR(sty,AirImg:HScroll),AirImg:VScroll))
  airApi_SetWindowPos(pHwnd,0,0,0,0,0,BOR(BOR(BOR(AirImg:FrameChanged,        |
                      AirImg:NoMove),AirImg:NoSize),AirImg:NoZOrder))
  old = airApi_SetWindowLong(pHwnd,AirImg:GwlWndProc,ADDRESS(AirImg_BarProc))
  IF ~old THEN RETURN 0.
  airApi_SetProp(pHwnd,ADDRESS(prop),old)
  RETURN 1

AirImg_DropBars PROCEDURE(LONG pHwnd)
prop CSTRING('AirImgBarProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  old = airApi_GetProp(pHwnd,ADDRESS(prop))
  IF old
    airApi_SetWindowLong(pHwnd,AirImg:GwlWndProc,old)
  END
  airApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

!  Range, page and position for one bar. Windows hides a bar whose page covers
!  its whole range, which is exactly what should happen when the picture fits.
AirImg_SetBar PROCEDURE(LONG pHwnd,LONG pBar,LONG pPos,LONG pPage,LONG pTotal)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN.
  si.cbSize = SIZE(si)
  si.fMask  = BOR(BOR(AirImg:SifRange,AirImg:SifPage),AirImg:SifPos)
  si.nMin   = 0
  si.nMax   = pTotal - 1
  si.nPage  = pPage
  si.nPos   = pPos
  airApi_SetScrollInfo(pHwnd,pBar,ADDRESS(si),1)

AirImg_BarPos PROCEDURE(LONG pHwnd,LONG pBar)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  IF ~pHwnd THEN RETURN 0.
  si.cbSize = SIZE(si)
  si.fMask  = AirImg:SifPos
  IF ~airApi_GetScrollInfo(pHwnd,pBar,ADDRESS(si)) THEN RETURN 0.
  RETURN si.nPos

!  The canvas control's window procedure, for the scrollbars only. It works out
!  the new position itself - Windows does not do that for you - writes it back,
!  and tells the ACCEPT loop something moved. Which canvas moved is not in the
!  message, and does not need to be: every canvas reads its own bars back.
AirImg_BarProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
prop CSTRING('AirImgBarProc')
old  LONG,AUTO
bar  LONG,AUTO
code LONG,AUTO
pos  LONG,AUTO
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  old = airApi_GetProp(hWnd,ADDRESS(prop))
  IF wMsg = AirImg:WmHScroll OR wMsg = AirImg:WmVScroll
    bar = CHOOSE(wMsg = AirImg:WmHScroll, AirImg:SbHorz, AirImg:SbVert)
    code = BAND(wParam,0FFFFh)
    si.cbSize = SIZE(si)
    si.fMask  = BOR(BOR(BOR(AirImg:SifRange,AirImg:SifPage),AirImg:SifPos),AirImg:SifTrack)
    IF airApi_GetScrollInfo(hWnd,bar,ADDRESS(si))
      pos = si.nPos
      CASE code
      OF 0                                                    ! a line back
        pos -= INT(si.nPage / 10) + 1
      OF 1                                                    ! a line on
        pos += INT(si.nPage / 10) + 1
      OF 2                                                    ! a page back
        pos -= si.nPage
      OF 3                                                    ! a page on
        pos += si.nPage
      OF 4                                                    ! the thumb, dropped
        pos = si.nTrack
      OF 5                                                    ! the thumb, dragging
        pos = si.nTrack
      OF 6
        pos = si.nMin
      OF 7
        pos = si.nMax
      END
      IF pos > si.nMax - si.nPage + 1 THEN pos = si.nMax - si.nPage + 1.
      IF pos < si.nMin THEN pos = si.nMin.
      si.fMask = AirImg:SifPos
      si.nPos  = pos
      airApi_SetScrollInfo(hWnd,bar,ADDRESS(si),1)
      POST(AirImg:Scrolled)
    END
  END
  IF old
    RETURN airApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0

!  Everything ImageClass can open, for FILEDIALOG.
AirImg_Filter PROCEDURE()
  CODE
  RETURN 'All pictures|*.bmp;*.dib;*.gif;*.jpg;*.jpeg;*.jpe;*.png;*.tif;*.tiff;' & |
         '*.ico;*.emf;*.wmf;*.tga;*.pcx;*.pnm;*.ppm;*.pgm;*.pbm;*.qoi' & |
         '|Windows bitmap|*.bmp;*.dib' & |
         '|GIF|*.gif' & |
         '|JPEG|*.jpg;*.jpeg;*.jpe' & |
         '|PNG|*.png' & |
         '|TIFF|*.tif;*.tiff' & |
         '|Icon|*.ico' & |
         '|Metafile|*.emf;*.wmf' & |
         '|Targa|*.tga' & |
         '|PCX|*.pcx' & |
         '|Portable any-map|*.pnm;*.ppm;*.pgm;*.pbm' & |
         '|QOI|*.qoi' & |
         '|All files|*.*'
myQRUrlEncode PROCEDURE(STRING pText)
loc:In         CSTRING(1024)                              ! the value to encode
loc:Out        CSTRING(3072)                              ! room for worst-case %XX expansion
loc:I          LONG
loc:C          BYTE                                       ! current character code
loc:Hex        STRING('0123456789ABCDEF')                 ! for the %XX nibbles
  CODE
  !Percent-encode for a URL query. Unreserved chars pass through (RFC 3986:
  ! A-Z a-z 0-9 - _ . ~). A space becomes %20. Everything else becomes %XX.
  loc:In = CLIP(pText)
  LOOP loc:I = 1 TO LEN(loc:In)
    loc:C = VAL(loc:In[loc:I])
    CASE loc:C
    OF VAL('A') TO VAL('Z')                               ! unreserved: emit as-is
    OROF VAL('a') TO VAL('z')
    OROF VAL('0') TO VAL('9')
    OROF VAL('-') OROF VAL('_') OROF VAL('.') OROF VAL('~')
      loc:Out = loc:Out & loc:In[loc:I]
    OF VAL(' ')                                           ! space -> %20
      loc:Out = loc:Out & '%20'
    ELSE                                                  ! anything else -> %XX
      loc:Out = loc:Out & '%' & loc:Hex[ BAND(BSHIFT(loc:C,-4),0Fh) + 1 ] & loc:Hex[ BAND(loc:C,0Fh) + 1 ]
    END
  END
  RETURN loc:Out
myQRLoad      PROCEDURE(SIGNED pImageFeq, STRING pData, SIGNED pSize, STRING pEccLetter, SIGNED pMargin)
loc:URL        CSTRING(4096)                              ! the full request URL
loc:File       CSTRING(File:MaxFilePath+1)                ! the per-image temp PNG
loc:Cmd        CSTRING(4352)                              ! full curl command line - CreateProcessA writes back into this, so size it big (url 4096 + curl flags + quotes)
loc:Ok         LONG                                       ! CreateProcessA return (0 = failed to launch)
loc:Dir        QUEUE,PRE(dir)                             ! DIRECTORY() target - standard ff_: layout
dir:Name         STRING(File:MaxFileName)
dir:ShortName    STRING(13)
dir:Date         LONG
dir:Time         LONG
dir:Size         LONG                                     ! file size in bytes - >0 means a real PNG
dir:Attrib       BYTE
               END
si             GROUP                                      ! STARTUPINFOA - field order/types per OddJobEq.inc:328-347
cb               ULONG                                    ! sizeof(STARTUPINFO)
lpReserved       LONG(0)
lpDesktop        LONG(0)
lpTitle          LONG(0)
dwX              ULONG
dwY              ULONG
dwXSize          ULONG
dwYSize          ULONG
dwXCountChars    ULONG
dwYCountChars    ULONG
dwFillAttribute  ULONG
dwFlags          ULONG                                    ! myQR:UseShowWindow bit goes here
wShowWindow      SHORT(0)                                 ! myQR:SwHide = 0
cbReserved2      SHORT(0)
lpReserved2      LONG(0)
hStdInput        LONG
hStdOutput       LONG
hStdError        LONG
               END
pi             GROUP                                      ! PROCESS_INFORMATION - OddJobEq.inc:305-310
hProcess         LONG
hThread          LONG
dwProcessId      ULONG
dwThreadId       ULONG
               END
!  Prefixed, because a bare SW_HIDE or INFINITE here collides with every other
!  template that declares the same word in the same module.
myQR:UseShowWindow  EQUATE(00000001h)                     ! OddJobEq.inc:349
myQR:SwHide         EQUATE(0)                             ! OddJobEq.inc:35
myQR:NoWindow       EQUATE(08000000h)                     ! OddJobEq.inc:390 - no console window for a console app
myQR:Forever        EQUATE(0FFFFFFFFh)                    ! WaitForSingleObject: wait with no timeout
  CODE
  !Per-image temp file in the current directory, keyed by the control FEQ so two QR
  !images on one window never clash. PNG, because the service returns PNG.
  loc:File = '.\myQR_' & pImageFeq & '.png'
  !Build the request for the goqr.me API. size=SxS, margin (quiet zone), ecc=L|M|Q|H,
  !data = the URL-encoded value. https = the value travels over TLS (see privacy note).
  loc:URL = 'https://api.qrserver.com/v1/create-qr-code/?size=' & pSize & 'x' & pSize |
          & '&margin=' & pMargin |
          & '&ecc=' & CLIP(pEccLetter) |
          & '&data=' & CLIP(myQRUrlEncode(pData))
  !Release the image's hold on the temp file BEFORE re-downloading, or the download
  !cannot overwrite a locked file (feq{PROP:Text}='' clears the loaded picture -
  !ActiveImage.clw uses the same PROP:Text channel to set/clear an IMAGE file).
  pImageFeq{PROP:Text} = ''
  REMOVE(loc:File)                                        ! drop the stale PNG (ignore if absent)
  !Build the curl command line. -s silent, -L follow redirects, --max-time guards a hung
  !server, -o writes the PNG. CreateProcessA modifies lpCommandLine in place, so loc:Cmd
  !is a generously sized CSTRING (see its declaration). <34> is a literal double-quote (")
  !- Windows arg quoting uses double quotes, so paths/URLs are quoted with <34>, not <39>.
  loc:Cmd = 'curl -s -L --max-time 15 -o <34>' & CLIP(loc:File) & '<34> <34>' & CLIP(loc:URL) & '<34>'
  !Launch curl HIDDEN: SW_HIDE in wShowWindow + STARTF_USESHOWWINDOW so it is honoured,
  !and CREATE_NO_WINDOW so a console app gets no console at all. cb = sizeof(STARTUPINFO).
  si.cb         = SIZE(si)
  si.dwFlags    = myQR:UseShowWindow
  si.wShowWindow = myQR:SwHide
  !appName=0 (parse from command line), inherit=0, env/dir=0. All params are LONG; the
  !command string and the two GROUPs are passed by ADDRESS(). loc:Ok=0 means curl could
  !not be launched (curl.exe missing).
  loc:Ok = myQR_CreateProcess(0, ADDRESS(loc:Cmd), 0, 0, 0, myQR:NoWindow, 0, 0, ADDRESS(si), ADDRESS(pi))
  IF loc:Ok
    !Synchronous: block until curl exits, then release the handles it handed back.
    myQR_WaitObject(pi.hProcess, myQR:Forever)
    myQR_CloseHandle(pi.hThread)
    myQR_CloseHandle(pi.hProcess)
  END
  !Trust the FILE, not the exit code: success = the PNG now exists and is non-empty.
  !DIRECTORY() lists the temp file and gives us its byte size; >0 bytes = a real PNG.
  FREE(loc:Dir)
  DIRECTORY(loc:Dir, loc:File, ff_:NORMAL)
  GET(loc:Dir, 1)
  IF EXISTS(loc:File) AND RECORDS(loc:Dir) AND dir:Size > 0
    pImageFeq{PROP:Text} = loc:File                        ! load the fresh QR into the image
    RETURN 1
  END
  RETURN 0                                                 ! curl missing / offline / service down
  !--- SIMPLE FALLBACK (console may FLASH; use only if you do not care about the flash) ---
  !  Replace the CreateProcessA block above with one line - RUN(...,1) runs and WAITS:
  !    RUN('curl -s -L -o <34>' & CLIP(loc:File) & '<34> <34>' & CLIP(loc:URL) & '<34>', 1)
  !----------------------------------------------------------------------------------------


Dictionary.Construct PROCEDURE

  CODE
  IF THREAD()<>1
     DctInit()
  END


Dictionary.Destruct PROCEDURE

  CODE
  DctKill()

