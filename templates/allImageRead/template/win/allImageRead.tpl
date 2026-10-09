#TEMPLATE(allImageRead,'allImageRead - any picture, on a window or a report - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  allImageRead  -  put ANY picture in front of the user.
#!
#!  Clarion's IMAGE control reads a short list of formats. ImageClass (the
#!  myImage template set) reads twelve. allImageRead is the piece in between:
#!  it takes a picture from wherever it lives - a file, a BLOB, a string in
#!  memory, a base64 payload, a URL - hands it to ImageClass, and paints the
#!  result on a window or into a report band.
#!
#!  WHAT IS IN HERE
#!    allImageReadGlobal (APPLICATION) - INCLUDEs ImageClass and writes the
#!                shared readers. Add it once per application - and to EVERY
#!                app of a multi-DLL set that carries a canvas.
#!    allImageReadCanvas (CONTROL)     - THE EASY PATH. Drag it onto a window
#!                OR into a report band; it drops the canvas and wires it up.
#!                On a window it is a live viewer: wheel zoom, drag to pan,
#!                right-click menu, drop a file on it from Explorer. In a
#!                report band it renders one picture per record.
#!    allImageRead    (PROCEDURE)      - the same viewer, into an IMAGE control
#!                you already have on a window.
#!    allImageReadRpt (PROCEDURE)      - the same, into an IMAGE control you
#!                already have in a report band.
#!    allImageReadLoad (CODE)          - one statement at any embed: read a
#!                picture from any source into an object you already declared.
#!
#!  REQUIRES the myImage template set. ImageClass.inc, ImageClass.clw and
#!  imgcore.c must sit on the redirection path (the app folder or
#!  \clarion12\libsrc\win), stored ANSI with CRLF line ends. myImage itself
#!  does NOT have to be registered - only its three files have to be findable.
#!
#!  READS  bmp gif jpg png tif ico emf wmf tga pcx pnm/ppm/pgm/pbm qoi
#!  FROM   a file - a variable holding a path - a BLOB field - a STRING in
#!         memory - a base64 string (data: URIs too) - an http/https URL.
#!
#!  THE CANVAS. On a window the IMAGE control is only the paint surface: the
#!  object owns the pixels, and a REGION created over the image at run time
#!  takes the mouse - which is how Clarion's own ActiveImage class does it
#!  (libsrc\win\ActiveImage.clw:303). So zooming does not stretch a control,
#!  it re-renders the picture; panning moves the viewport, not the frame.
#!
#!  API (the object is in the procedure's data - call it from any embed):
#!    Pic1.LoadFile('holiday.jpg')       ! then POST(Air:Redraw:Pic1)
#!    Pic1.Frames() / Pic1.LoadFrame(n)  ! animated GIF, multi-page TIFF
#!    Pic1.Describe()                    ! one line for a status bar
#!    DO Air:Show:Pic1                   ! repaint now
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - allImageReadGlobal
#!#############################################################################
#EXTENSION(allImageReadGlobal,'allImageRead - Global (add once per application)'),APPLICATION,HLP('~allImageRead.htm')
#SHEET
  #TAB('&General')
    #BOXED('allImageRead')
      #DISPLAY('allImageRead - Version 1.0')
      #DISPLAY('Shows any picture ImageClass can read on a window or in a')
      #DISPLAY('report band, from a file, a BLOB, memory, base64 or a URL.')
      #DISPLAY('')
      #DISPLAY('REQUIRES the myImage files on the redirection path:')
      #DISPLAY('   ImageClass.inc    ImageClass.clw    imgcore.c')
      #DISPLAY('stored ANSI (not UTF-8), CRLF line ends.')
      #DISPLAY('')
      #DISPLAY('Add this extension ONCE per application - and to EVERY app of')
      #DISPLAY('a multi-DLL set that carries a canvas.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Disable this template',CHECK),%airGDisable,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Sources')
    #BOXED('Pictures that are not already files')
      #DISPLAY('A BLOB, a string in memory, a base64 payload or a download is')
      #DISPLAY('written to the Windows TEMP folder and read back from there.')
      #DISPLAY('Every canvas owns a fixed set of names, so the working files')
      #DISPLAY('are reused rather than piled up.')
    #ENDBOXED
    #BOXED('The internet')
      #DISPLAY('A URL is fetched with curl.exe, which ships with Windows 10 and')
      #DISPLAY('11 in System32. Nothing is installed and nothing is shipped.')
      #PROMPT('Download &timeout (seconds):',SPIN(@n3,1,300,1)),%airGUrlSecs,DEFAULT(20)
    #ENDBOXED
  #ENDTAB
  #TAB('&Zooming')
    #BOXED('The GPU canvas')
      #DISPLAY('Zooming on the processor means resampling the whole picture for')
      #DISPLAY('every wheel notch. Direct2D hands the picture to the graphics')
      #DISPLAY('card once; after that a zoom is a matrix, and costs the same')
      #DISPLAY('whether the picture is 300 pixels wide or 30,000. Measured on a')
      #DISPLAY('2400x1800 photograph: 8 ms a frame against 675 ms a step.')
      #DISPLAY('')
      #DISPLAY('Direct2D ships with Windows 7 and later and is bound at run')
      #DISPLAY('time, so nothing is linked and nothing is shipped. A canvas')
      #DISPLAY('that cannot get it falls back to the processor on its own.')
      #DISPLAY('d2dcanvas.c must be on the redirection path beside the myImage')
      #DISPLAY('files. Each canvas chooses its own engine on its Canvas tab;')
      #DISPLAY('set them all to "the processor" if you would rather not use it.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#!  The timeout lives here as an EQUATE rather than being read out of these
#!  prompts by the canvas templates: an APPLICATION extension's prompts are not
#!  in scope while a PROCEDURE template generates, and reaching for them there
#!  earns an "Unknown Variable" from the generator.
#AT(%AfterGlobalIncludes),WHERE(%airGDisable=0)
INCLUDE('ImageClass.INC'),ONCE
  PRAGMA('compile(d2dcanvas.c)')                              ! the GPU canvas, built by Clarion's own C compiler
AirImg:Secs          EQUATE(%airGUrlSecs)                     ! how long a download may take
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
#ENDAT
#!
#!  Everything a picture needs before ImageClass can see it. The Windows file
#!  API is used rather than a Clarion FILE, so the application is not obliged
#!  to carry the DOS driver just to show a photograph. Every parameter is a
#!  LONG and everything that is really a pointer is passed as ADDRESS(x) - the
#!  portable mapping that never puts a string descriptor where the API wants
#!  an address.
#AT(%GlobalMap),WHERE(%airGDisable=0)
    MODULE('win32')
airApi_TempPath(ULONG,*CSTRING),ULONG,RAW,PASCAL,PROC,NAME('GetTempPathA')
airApi_CreateFile(LONG,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,NAME('CreateFileA')
airApi_WriteFile(LONG,LONG,ULONG,LONG,LONG),LONG,PASCAL,PROC,NAME('WriteFile')
airApi_CloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
airApi_CreateProcess(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
airApi_WaitObject(LONG,ULONG),LONG,PASCAL,PROC,NAME('WaitForSingleObject')
#!  The mouse wheel. Clarion's EVENT:ScrollUp/ScrollDown belong to a LIST with
#!  IMM - "the user pressed the up arrow" - and never reach a window or an
#!  IMAGE, so the wheel has to be taken off the window procedure. The original
#!  procedure is parked on the window itself with SetProp, which is how one
#!  callback serves any number of windows with no bookkeeping of our own.
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
#!  the GPU canvas. cdecl exports from C, so the Clarion name carries a
#!  leading underscore; every canvas is a small handle, 0 meaning "no GPU".
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
#ENDAT
#!
#AT(%ProgramProcedures),WHERE(%airGDisable=0)
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
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - allImageReadCanvas
#!  Drag it onto a WINDOW or into a REPORT band. One IMAGE is dropped - the
#!  only control a report band will take - and the wiring differs by where it
#!  landed, which #ATSTART works out below.
#!#############################################################################
#CONTROL(allImageReadCanvas,'allImageRead - Image canvas (window or report band)'),WINDOW,REPORT,MULTI,REQ(allImageReadGlobal),DESCRIPTION('[Canvas] ' & %airCObject),HLP('~allImageRead.htm')
  CONTROLS
    IMAGE,AT(,,160,120),USE(?AirCanvas),#ORIG(?AirCanvas)
  END
#SHEET
  #TAB('&Picture')
    #BOXED('Object')
      #PROMPT('&Disable this canvas',CHECK),%airCDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%airCObject,REQ,DEFAULT('Pic' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('Where the picture comes from')
      #PROMPT('&Source:',DROP('A file on disk (fixed path)[FILE]|A variable holding a file path[PATH]|A BLOB field[BLOB]|A STRING variable in memory[MEM]|A base64 string[B64]|A URL (http/https)[URL]|Nothing - I set it in code[NONE]')),%airCKind,DEFAULT('FILE')
      #ENABLE(%airCKind='FILE')
        #PROMPT('File &name:',@s255),%airCFile,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airCKind='PATH' OR %airCKind='MEM' OR %airCKind='B64' OR %airCKind='URL')
        #PROMPT('&Variable / expression:',@s255),%airCVar,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airCKind='MEM')
        #PROMPT('&Bytes to use (blank = SIZE of the variable):',@s255),%airCLen,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airCKind='BLOB')
        #PROMPT('&BLOB field:',FIELD),%airCBlob
      #ENDENABLE
      #ENABLE(%airCKind='URL')
        #PROMPT('Download &timeout (seconds, 0 = the global default):',SPIN(@n3,0,300,1)),%airCSecs,DEFAULT(0)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Frames')
      #DISPLAY('An animated GIF, a multi-page TIFF and an .ico all hold more')
      #DISPLAY('than one picture. Frame 1 is the first.')
      #PROMPT('Show &frame:',SPIN(@n4,1,9999,1)),%airCFrame,DEFAULT(1)
    #ENDBOXED
  #ENDTAB
  #TAB('&On a window')
    #BOXED('Ignored when this canvas is in a report band')
      #PROMPT('&Engine:',DROP('Graphics card if it is there, else the processor[AUTO]|The processor, always[CPU]')),%airCEngine,DEFAULT('AUTO')
      #PROMPT('&Fit:',DROP('Fit inside, keep the ratio, pad[Img:Proportional]|Fit inside, keep the ratio, no padding[Img:Contain]|Fill the frame, keep the ratio, crop[Img:Cover]|Fill the frame, ignore the ratio[Img:Stretch]|No scaling, centred[Img:Centered]')),%airCFit,DEFAULT('Img:Proportional')
      #PROMPT('&Background:',COLOR),%airCBack,DEFAULT(00FFFFFFH)
      #PROMPT('&Load the picture when the window opens',CHECK),%airCAuto,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('What the user may do')
      #PROMPT('&Zoom with the mouse wheel',CHECK),%airCZoom,DEFAULT(1),AT(10)
      #PROMPT('Hold &Ctrl to zoom (wheel alone does nothing)',CHECK),%airCZoomCtrl,DEFAULT(1),AT(20)
      #PROMPT('Zoom &step (per cent):',SPIN(@n3,5,100,5)),%airCZoomStep,DEFAULT(25)
      #PROMPT('&Pan (drag the picture)',CHECK),%airCPan,DEFAULT(1),AT(10)
      #PROMPT('Pan with &Ctrl+arrows too (Ctrl+Home refits)',CHECK),%airCPanKeys,DEFAULT(1),AT(20)
      #PROMPT('&Scrollbars once it is zoomed in',CHECK),%airCBars,DEFAULT(1),AT(20)
      #PROMPT('Keyboard pan &step (per cent of the frame):',SPIN(@n3,1,100,5)),%airCPanStep,DEFAULT(15)
      #PROMPT('&Right-click menu',CHECK),%airCMenu,DEFAULT(1),AT(10)
      #PROMPT('&Open another picture (menu, and double-click)',CHECK),%airCOpen,DEFAULT(1),AT(10)
      #PROMPT('&Accept a file dropped from Explorer',CHECK),%airCDrop,DEFAULT(1),AT(10)
      #PROMPT('&Save a copy (menu)',CHECK),%airCSave,DEFAULT(1),AT(10)
      #PROMPT('Rotate and &mirror (menu)',CHECK),%airCRotate,DEFAULT(1),AT(10)
      #PROMPT('Step through &frames (menu)',CHECK),%airCFrames,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Telling the user what it is')
      #PROMPT('Put the details in the &status bar',CHECK),%airCStatus,DEFAULT(0),AT(10)
      #PROMPT('Status bar &zone:',SPIN(@n1,1,4,1)),%airCStatusZone,DEFAULT(1)
      #PROMPT('Show a &tooltip with the file name',CHECK),%airCTip,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&In a report band')
    #BOXED('Ignored when this canvas is on a window')
      #PROMPT('Load the picture for &every record',CHECK),%airCRptEach,DEFAULT(1),AT(10)
      #DISPLAY('Off = the picture is loaded once, when the report opens.')
    #ENDBOXED
    #BOXED('How big to render it')
      #DISPLAY('The band control is a frame on paper; the picture behind it is')
      #DISPLAY('pixels. Render it at least as big as it will print, or it will')
      #DISPLAY('look soft. 600 x 450 suits a photograph in a 2-inch frame.')
      #PROMPT('&Width (pixels):',SPIN(@n5,16,8000,10)),%airCRptW,DEFAULT(600)
      #PROMPT('&Height (pixels):',SPIN(@n5,16,8000,10)),%airCRptH,DEFAULT(450)
      #PROMPT('&Fit:',DROP('Fit inside, keep the ratio, pad[Img:Proportional]|Fit inside, keep the ratio, no padding[Img:Contain]|Fill the frame, keep the ratio, crop[Img:Cover]|Fill the frame, ignore the ratio[Img:Stretch]|No scaling, centred[Img:Centered]')),%airCRptFit,DEFAULT('Img:Proportional')
      #PROMPT('&Background:',COLOR),%airCRptBack,DEFAULT(00FFFFFFH)
    #ENDBOXED
    #BOXED('Working files')
      #DISPLAY('Each rendered page picture is written to the TEMP folder. The')
      #DISPLAY('names rotate, so a page still being spooled cannot have its')
      #DISPLAY('picture overwritten underneath it.')
      #PROMPT('How many names to &rotate:',SPIN(@n2,1,32,1)),%airCRptPool,DEFAULT(8)
    #ENDBOXED
  #ENDTAB
  #TAB('&Touch-up')
    #BOXED('Applied once, right after the picture is read')
      #PROMPT('&Rotate:',DROP('Leave it[0]|90 degrees right[90]|180 degrees[180]|90 degrees left[270]')),%airCRot,DEFAULT('0')
      #PROMPT('&Mirror (left to right)',CHECK),%airCMirror,DEFAULT(0),AT(10)
      #PROMPT('&Flip (top to bottom)',CHECK),%airCFlip,DEFAULT(0),AT(10)
      #PROMPT('&Greyscale',CHECK),%airCGrey,DEFAULT(0),AT(10)
      #PROMPT('Cap the &longest side at (pixels, 0 = leave it):',SPIN(@n5,0,8000,50)),%airCMax,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#!  Which control is mine, and did it land in a report band or on a window?
#!  A report band knows its controls through %ReportControl, a window through
#!  %Control. Whichever list owns this instance answers both questions.
#ATSTART
  #IF(VAREXISTS(%airCFeq) = 0)
    #DECLARE(%airCFeq)
    #DECLARE(%airCOnReport)
    #DECLARE(%airCKey)
  #ENDIF
  #SET(%airCFeq,'')
  #SET(%airCOnReport,0)
  #FOR(%ReportControl),WHERE(%ReportControlOriginal='?AirCanvas' AND %ReportControlInstance=%ActiveTemplateInstance)
    #SET(%airCFeq,%ReportControl)
    #SET(%airCOnReport,1)
  #ENDFOR
  #IF(%airCFeq = '')
    #!  match on the ORIGINAL name as well as the instance: taking merely "the
    #!  last control of this instance" picks up somebody else's button the
    #!  moment another control template shares the instance number.
    #FOR(%Control),WHERE(%ControlOriginal='?AirCanvas' AND %ControlInstance=%ActiveTemplateInstance)
      #SET(%airCFeq,%Control)
    #ENDFOR
  #ENDIF
  #SET(%airCKey,%Procedure & '_c' & %ActiveTemplateInstance)
#ENDAT
#!
#!  A canvas carries the class itself, so allImageReadGlobal is not strictly
#!  needed for the INCLUDE - but it IS needed for the readers, which is why
#!  REQ() names it. ONCE keys on the file name across the whole compile, so the
#!  class is pulled in exactly once even with both present.
#AT(%CustomGlobalDeclarations),WHERE(%airCDisable=0)
INCLUDE('ImageClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%airCDisable=0 AND %airCFeq)
#INSERT(%airDeclare,%airCObject,%airCOnReport,220)
#ENDAT
#!===== the canvas on a WINDOW ================================================
#!  PRIORITY(2000) puts this self-contained CASE EVENT() ABOVE the framework's
#!  own LOOP/CASE scaffolding, which is registered at 2500 (ABWINDOW.TPW:563).
#!  Using 2500 collides with it and duplicates CASE EVENT().
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%airCDisable=0 AND %airCFeq AND %airCOnReport=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    DO Air:Setup:%airCObject
  OF EVENT:Sized
    DO Air:Place:%airCObject
    DO Air:Size:%airCObject
    POST(Air:Redraw:%airCObject)
  OF Air:Redraw:%airCObject
    DO Air:Show:%airCObject
#INSERT(%airWheel,%airCObject,%airCZoom,%airCZoomCtrl)
#INSERT(%airKeys,%airCObject,%airCPan,%airCPanKeys)
#INSERT(%airBarEvent,%airCObject,%airCBars)
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%airCDisable=0 AND %airCFeq AND %airCOnReport=0)
#IF(%airCPan AND %airCPanKeys)
  CASE EVENT()
#INSERT(%airKeys,%airCObject,%airCPan,%airCPanKeys)
  END
#ENDIF
#INSERT(%airFieldEvents,%airCObject,%airCFeq,%airCPan,%airCMenu,%airCOpen,%airCDrop)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(2000),WHERE(%airCDisable=0 AND %airCFeq AND %airCOnReport=0 AND %airCZoom=1)
#INSERT(%airUnhook,%airCObject)
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%airCDisable=0 AND %airCFeq AND %airCOnReport=0)
#INSERT(%airCanvasFromControl)
#ENDAT
#!===== the canvas in a REPORT BAND ===========================================
#!  Nothing is drawn here. The picture is fitted to a PNG in the TEMP folder
#!  and the band control is pointed at it - which is all a report band needs,
#!  and the only thing that works on paper as well as in the preview.
#AT(%BeforePrint),WHERE(%airCDisable=0 AND %airCFeq AND %airCOnReport=1 AND %airCRptEach=1)
  DO Air:Band:%airCObject
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'OpenReport','(),BYTE'),PRIORITY(7500),WHERE(%airCDisable=0 AND %airCFeq AND %airCOnReport=1 AND %airCRptEach=0)
  IF ReturnValue = Level:Benign
    DO Air:Band:%airCObject
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%airCDisable=0 AND %airCFeq AND %airCOnReport=1)
Air:Band:%airCObject ROUTINE
  DATA
fname CSTRING(261)
  CODE
#INSERT(%airLoadStmt,%airCObject,%airCKind,%airCFile,%airCVar,%airCLen,%airCBlob,%airCKey,%airCSecs)
#INSERT(%airFrameStmt,%airCObject,%airCFrame)
#INSERT(%airTouchUp,%airCObject,%airCRot,%airCMirror,%airCFlip,%airCGrey,%airCMax)
  %airCObject:Pool += 1
  IF %airCObject:Pool > %airCRptPool THEN %airCObject:Pool = 1.
  fname = AirImg_Render(%airCObject,%airCRptW,%airCRptH,%airCRptFit, |
                       %airCObject.ArgbOf(%airCRptBack),'%airCKey' & '_' & %airCObject:Pool)
  SETTARGET(%Report)
  %airCFeq{PROP:Text} = fname                                  ! blank clears the frame
  SETTARGET()
#ENDAT
#!#############################################################################
#!  CONTROL TEMPLATE - allImageReadFrames
#!  A frame bar for the pictures that hold more than one: a multi-page TIFF, an
#!  animated GIF, an .ico carrying several sizes. Drag it onto the window beside
#!  a canvas and tell it which canvas object it drives - it calls that canvas's
#!  own Air:Frame routine, so the zoom and the pan stay where the canvas has
#!  them while the pages turn.
#!#############################################################################
#CONTROL(allImageReadFrames,'allImageRead - Frame bar (multi-page TIFF, animated GIF)'),WINDOW,MULTI,REQ(allImageReadGlobal),DESCRIPTION('[Frames] ' & %airFCanvas),HLP('~allImageRead.htm')
  CONTROLS
    BUTTON('|<'),AT(,,14,12),USE(?AirFrmFirst),#ORIG(?AirFrmFirst),TIP('First')
    BUTTON('<'),AT(,,14,12),USE(?AirFrmPrev),#ORIG(?AirFrmPrev),TIP('Previous')
    STRING('- / -'),AT(,,46,10),USE(?AirFrmText),#ORIG(?AirFrmText),CENTER
    BUTTON('>'),AT(,,14,12),USE(?AirFrmNext),#ORIG(?AirFrmNext),TIP('Next')
    BUTTON('>|'),AT(,,14,12),USE(?AirFrmLast),#ORIG(?AirFrmLast),TIP('Last')
    BUTTON('Play'),AT(,,26,12),USE(?AirFrmPlay),#ORIG(?AirFrmPlay),TIP('Play the animation')
  END
#SHEET
  #TAB('&Frames')
    #BOXED('Which canvas')
      #PROMPT('&Disable this frame bar',CHECK),%airFDisable,DEFAULT(0),AT(10)
      #PROMPT('&Canvas object name:',@s64),%airFCanvas,REQ,DEFAULT('Pic1')
      #DISPLAY('The Object name off the canvas this bar drives - the same word')
      #DISPLAY('typed on its Picture tab. A canvas in a REPORT band has no frame')
      #DISPLAY('bar: there is nobody there to press the buttons.')
    #ENDBOXED
    #BOXED('Behaviour')
      #PROMPT('&Wrap round at the ends',CHECK),%airFWrap,DEFAULT(1),AT(10)
      #PROMPT('&Hide the bar when the picture has only one frame',CHECK),%airFHide,DEFAULT(1),AT(10)
      #PROMPT('Frame &counter:',DROP('3 / 12[N/T]|Frame 3 of 12[FRAME]|Page 3 of 12[PAGE]|no counter[NONE]')),%airFText,DEFAULT('N/T')
    #ENDBOXED
  #ENDTAB
  #TAB('&Playing')
    #BOXED('The Play button')
      #PROMPT('Show the &Play button',CHECK),%airFPlay,DEFAULT(1),AT(10)
      #PROMPT('Frame &interval (1/100 sec):',SPIN(@n4,1,1000,5)),%airFSpeed,DEFAULT(10)
      #DISPLAY('ImageClass does not hand back the delay a GIF asks for, so this')
      #DISPLAY('is a fixed rate. 10 is about ten frames a second.')
      #PROMPT('Start playing when the window &opens',CHECK),%airFAuto,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('The window timer')
      #DISPLAY('Playing borrows the window timer and puts back whatever was in')
      #DISPLAY('it when it stops. If something else on this window already uses')
      #DISPLAY('PROP:Timer, run them at one interval or leave Play off.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#!  Each dropped button keeps the feq AppGen gave it, found through #ORIG.
#ATSTART
  #IF(VAREXISTS(%airFFirst) = 0)
    #DECLARE(%airFFirst)
    #DECLARE(%airFPrev)
    #DECLARE(%airFNext)
    #DECLARE(%airFLast)
    #DECLARE(%airFBtn)
    #DECLARE(%airFStr)
    #DECLARE(%airFObj)
  #ENDIF
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #CASE(%ControlOriginal)
    #OF('?AirFrmFirst')
      #SET(%airFFirst,%Control)
    #OF('?AirFrmPrev')
      #SET(%airFPrev,%Control)
    #OF('?AirFrmNext')
      #SET(%airFNext,%Control)
    #OF('?AirFrmLast')
      #SET(%airFLast,%Control)
    #OF('?AirFrmPlay')
      #SET(%airFBtn,%Control)
    #OF('?AirFrmText')
      #SET(%airFStr,%Control)
    #ENDCASE
  #ENDFOR
  #SET(%airFObj,'AirFrm' & %ActiveTemplateInstance)
#ENDAT
#!
#AT(%DataSection),WHERE(%airFDisable=0)
%airFObj:Playing     BYTE                                    ! is the animation running?
%airFObj:WasTimer    LONG                                    ! what PROP:Timer held before we borrowed it
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%airFDisable=0)
  CASE EVENT()
  OF EVENT:OpenWindow
    DO AirFrm:Sync:%airFObj
#IF(%airFPlay AND %airFAuto)
    DO AirFrm:Play:%airFObj
#ENDIF
#IF(%airFPlay)
  OF EVENT:Timer
    IF %airFObj:Playing
      DO AirFrm:Step:%airFObj
    END
#ENDIF
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%airFDisable=0)
  IF EVENT() = EVENT:Accepted
    CASE FIELD()
    OF %airFFirst
      %airFCanvas:Frame = 1
      DO AirFrm:Go:%airFObj
    OF %airFPrev
      %airFCanvas:Frame -= 1
      IF %airFCanvas:Frame < 1
#IF(%airFWrap)
        %airFCanvas:Frame = %airFCanvas.Frames()
#ELSE
        %airFCanvas:Frame = 1
#ENDIF
      END
      DO AirFrm:Go:%airFObj
    OF %airFNext
      DO AirFrm:Step:%airFObj
    OF %airFLast
      %airFCanvas:Frame = %airFCanvas.Frames()
      DO AirFrm:Go:%airFObj
#IF(%airFPlay)
    OF %airFBtn
      IF %airFObj:Playing
        DO AirFrm:Stop:%airFObj
      ELSE
        DO AirFrm:Play:%airFObj
      END
#ENDIF
    END
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(2000),WHERE(%airFDisable=0 AND %airFPlay=1)
  IF %airFObj:Playing
    DO AirFrm:Stop:%airFObj                                   ! give the timer back
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%airFDisable=0)
AirFrm:Go:%airFObj ROUTINE
!  Move the canvas to the frame number now in its object, then bring the bar
!  into line with it.
  DO Air:Frame:%airFCanvas
  DO AirFrm:Sync:%airFObj

AirFrm:Step:%airFObj ROUTINE
!  One frame on - what Play calls on every tick, and what Next does.
  IF %airFCanvas.Frames() < 2 THEN EXIT.
  %airFCanvas:Frame += 1
  IF %airFCanvas:Frame > %airFCanvas.Frames()
#IF(%airFWrap)
    %airFCanvas:Frame = 1
#ELSE
    %airFCanvas:Frame = %airFCanvas.Frames()
#IF(%airFPlay)
    DO AirFrm:Stop:%airFObj                                   ! ran off the end
#ENDIF
    EXIT
#ENDIF
  END
  DO AirFrm:Go:%airFObj
#IF(%airFPlay)

AirFrm:Play:%airFObj ROUTINE
  IF %airFCanvas.Frames() < 2 THEN EXIT.
  %airFObj:WasTimer = 0{PROP:Timer}                           ! borrow the window timer
  %airFObj:Playing  = 1
  0{PROP:Timer} = %airFSpeed
  %airFBtn{PROP:Text} = 'Stop'

AirFrm:Stop:%airFObj ROUTINE
  %airFObj:Playing = 0
  0{PROP:Timer} = %airFObj:WasTimer                           ! and put it back
  %airFBtn{PROP:Text} = 'Play'
#ENDIF

AirFrm:Sync:%airFObj ROUTINE
!  Make the bar tell the truth: the counter, the buttons that cannot go
!  anywhere, and the whole bar when there is only one frame to look at.
  DATA
n LONG,AUTO
f LONG,AUTO
  CODE
  n = 0
  f = 0
  IF %airFCanvas.Ok()
    n = %airFCanvas.Frames()
    f = %airFCanvas:Frame
    IF f < 1 THEN f = 1.
  END
#CASE(%airFText)
#OF('N/T')
  %airFStr{PROP:Text} = CHOOSE(n < 1, '', CLIP(LEFT(f)) & ' / ' & CLIP(LEFT(n)))
#OF('FRAME')
  %airFStr{PROP:Text} = CHOOSE(n < 1, '', 'Frame ' & CLIP(LEFT(f)) & ' of ' & CLIP(LEFT(n)))
#OF('PAGE')
  %airFStr{PROP:Text} = CHOOSE(n < 1, '', 'Page ' & CLIP(LEFT(f)) & ' of ' & CLIP(LEFT(n)))
#OF('NONE')
  %airFStr{PROP:Text} = ''
#ENDCASE
#IF(%airFHide)
  IF n < 2                                                    ! nothing to step through
    HIDE(%airFFirst)
    HIDE(%airFPrev)
    HIDE(%airFNext)
    HIDE(%airFLast)
    HIDE(%airFStr)
#IF(%airFPlay)
    HIDE(%airFBtn)
#ENDIF
    EXIT
  END
  UNHIDE(%airFFirst)
  UNHIDE(%airFPrev)
  UNHIDE(%airFNext)
  UNHIDE(%airFLast)
  UNHIDE(%airFStr)
#IF(%airFPlay)
  UNHIDE(%airFBtn)
#ENDIF
#ENDIF
#IF(%airFWrap = 0)
  %airFFirst{PROP:Disable} = CHOOSE(f <= 1, 1, 0)
  %airFPrev{PROP:Disable}  = CHOOSE(f <= 1, 1, 0)
  %airFNext{PROP:Disable}  = CHOOSE(f >= n, 1, 0)
  %airFLast{PROP:Disable}  = CHOOSE(f >= n, 1, 0)
#ENDIF
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - allImageRead
#!  The same viewer, into an IMAGE control that is already on the window.
#!#############################################################################
#EXTENSION(allImageRead,'allImageRead - Show a picture in an IMAGE control on this window'),PROCEDURE,MULTI,REQ(allImageReadGlobal),DESCRIPTION('[Picture] ' & %airWObject),HLP('~allImageRead.htm')
#SHEET
  #TAB('&Picture')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this picture',CHECK),%airWDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%airWObject,REQ,DEFAULT('Pic' & %ActiveTemplateInstance)
      #PROMPT('&IMAGE control to paint into:',CONTROL),%airWImage,REQ
    #ENDBOXED
    #BOXED('Where the picture comes from')
      #PROMPT('&Source:',DROP('A file on disk (fixed path)[FILE]|A variable holding a file path[PATH]|A BLOB field[BLOB]|A STRING variable in memory[MEM]|A base64 string[B64]|A URL (http/https)[URL]|Nothing - I set it in code[NONE]')),%airWKind,DEFAULT('FILE')
      #ENABLE(%airWKind='FILE')
        #PROMPT('File &name:',@s255),%airWFile,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airWKind='PATH' OR %airWKind='MEM' OR %airWKind='B64' OR %airWKind='URL')
        #PROMPT('&Variable / expression:',@s255),%airWVar,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airWKind='MEM')
        #PROMPT('&Bytes to use (blank = SIZE of the variable):',@s255),%airWLen,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airWKind='BLOB')
        #PROMPT('&BLOB field:',FIELD),%airWBlob
      #ENDENABLE
      #ENABLE(%airWKind='URL')
        #PROMPT('Download &timeout (seconds, 0 = the global default):',SPIN(@n3,0,300,1)),%airWSecs,DEFAULT(0)
      #ENDENABLE
      #PROMPT('Show &frame:',SPIN(@n4,1,9999,1)),%airWFrame,DEFAULT(1)
    #ENDBOXED
  #ENDTAB
  #TAB('&Canvas')
    #BOXED('How it sits in the frame')
      #PROMPT('&Engine:',DROP('Graphics card if it is there, else the processor[AUTO]|The processor, always[CPU]')),%airWEngine,DEFAULT('AUTO')
      #PROMPT('&Fit:',DROP('Fit inside, keep the ratio, pad[Img:Proportional]|Fit inside, keep the ratio, no padding[Img:Contain]|Fill the frame, keep the ratio, crop[Img:Cover]|Fill the frame, ignore the ratio[Img:Stretch]|No scaling, centred[Img:Centered]')),%airWFit,DEFAULT('Img:Proportional')
      #PROMPT('&Background:',COLOR),%airWBack,DEFAULT(00FFFFFFH)
      #PROMPT('&Load the picture when the window opens',CHECK),%airWAuto,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('What the user may do')
      #PROMPT('&Zoom with the mouse wheel',CHECK),%airWZoom,DEFAULT(1),AT(10)
      #PROMPT('Hold &Ctrl to zoom (wheel alone does nothing)',CHECK),%airWZoomCtrl,DEFAULT(1),AT(20)
      #PROMPT('Zoom &step (per cent):',SPIN(@n3,5,100,5)),%airWZoomStep,DEFAULT(25)
      #PROMPT('&Pan (drag the picture)',CHECK),%airWPan,DEFAULT(1),AT(10)
      #PROMPT('Pan with &Ctrl+arrows too (Ctrl+Home refits)',CHECK),%airWPanKeys,DEFAULT(1),AT(20)
      #PROMPT('&Scrollbars once it is zoomed in',CHECK),%airWBars,DEFAULT(1),AT(20)
      #PROMPT('Keyboard pan &step (per cent of the frame):',SPIN(@n3,1,100,5)),%airWPanStep,DEFAULT(15)
      #PROMPT('&Right-click menu',CHECK),%airWMenu,DEFAULT(1),AT(10)
      #PROMPT('&Open another picture (menu, and double-click)',CHECK),%airWOpen,DEFAULT(1),AT(10)
      #PROMPT('&Accept a file dropped from Explorer',CHECK),%airWDrop,DEFAULT(1),AT(10)
      #PROMPT('&Save a copy (menu)',CHECK),%airWSave,DEFAULT(1),AT(10)
      #PROMPT('Rotate and &mirror (menu)',CHECK),%airWRotate,DEFAULT(1),AT(10)
      #PROMPT('Step through &frames (menu)',CHECK),%airWFrames,DEFAULT(1),AT(10)
    #ENDBOXED
    #BOXED('Telling the user what it is')
      #PROMPT('Put the details in the &status bar',CHECK),%airWStatus,DEFAULT(0),AT(10)
      #PROMPT('Status bar &zone:',SPIN(@n1,1,4,1)),%airWStatusZone,DEFAULT(1)
      #PROMPT('Show a &tooltip with the file name',CHECK),%airWTip,DEFAULT(1),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Touch-up')
    #BOXED('Applied once, right after the picture is read')
      #PROMPT('&Rotate:',DROP('Leave it[0]|90 degrees right[90]|180 degrees[180]|90 degrees left[270]')),%airWRot,DEFAULT('0')
      #PROMPT('&Mirror (left to right)',CHECK),%airWMirror,DEFAULT(0),AT(10)
      #PROMPT('&Flip (top to bottom)',CHECK),%airWFlip,DEFAULT(0),AT(10)
      #PROMPT('&Greyscale',CHECK),%airWGrey,DEFAULT(0),AT(10)
      #PROMPT('Cap the &longest side at (pixels, 0 = leave it):',SPIN(@n5,0,8000,50)),%airWMax,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #IF(VAREXISTS(%airWKey) = 0)
    #DECLARE(%airWKey)
  #ENDIF
  #SET(%airWKey,%Procedure & '_w' & %ActiveTemplateInstance)
#ENDAT
#!
#AT(%DataSection),WHERE(%airWDisable=0 AND %airWImage)
#INSERT(%airDeclare,%airWObject,0,260)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%airWDisable=0 AND %airWImage)
  CASE EVENT()
  OF EVENT:OpenWindow
    DO Air:Setup:%airWObject
  OF EVENT:Sized
    DO Air:Place:%airWObject
    DO Air:Size:%airWObject
    POST(Air:Redraw:%airWObject)
  OF Air:Redraw:%airWObject
    DO Air:Show:%airWObject
#INSERT(%airWheel,%airWObject,%airWZoom,%airWZoomCtrl)
#INSERT(%airKeys,%airWObject,%airWPan,%airWPanKeys)
#INSERT(%airBarEvent,%airWObject,%airWBars)
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeFieldEvent','(),BYTE'),PRIORITY(2000),WHERE(%airWDisable=0 AND %airWImage)
#IF(%airWPan AND %airWPanKeys)
  CASE EVENT()
#INSERT(%airKeys,%airWObject,%airWPan,%airWPanKeys)
  END
#ENDIF
#INSERT(%airFieldEvents,%airWObject,%airWImage,%airWPan,%airWMenu,%airWOpen,%airWDrop)
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(2000),WHERE(%airWDisable=0 AND %airWImage AND %airWZoom=1)
#INSERT(%airUnhook,%airWObject)
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%airWDisable=0 AND %airWImage)
#INSERT(%airCanvasFromExtension)
#ENDAT
#!#############################################################################
#!  PROCEDURE EXTENSION - allImageReadRpt
#!  Into an IMAGE control that is already in a report band.
#!#############################################################################
#EXTENSION(allImageReadRpt,'allImageRead - Show a picture in an IMAGE control on this REPORT'),PROCEDURE,MULTI,REQ(allImageReadGlobal),DESCRIPTION('[Picture] ' & %airRObject),HLP('~allImageRead.htm')
#SHEET
  #TAB('&Picture')
    #BOXED('Object &&  control')
      #PROMPT('&Disable this picture',CHECK),%airRDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%airRObject,REQ,DEFAULT('RptPic' & %ActiveTemplateInstance)
      #! a report needs FROM(%ReportControl,...) - a window CONTROL prompt cannot see a band
      #PROMPT('&IMAGE control (in a report band):',FROM(%ReportControl,%ReportControlType = 'IMAGE')),%airRImage,REQ,DEFAULT('')
    #ENDBOXED
    #BOXED('Where the picture comes from')
      #PROMPT('&Source:',DROP('A file on disk (fixed path)[FILE]|A variable holding a file path[PATH]|A BLOB field[BLOB]|A STRING variable in memory[MEM]|A base64 string[B64]|A URL (http/https)[URL]')),%airRKind,DEFAULT('PATH')
      #ENABLE(%airRKind='FILE')
        #PROMPT('File &name:',@s255),%airRFile,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airRKind='PATH' OR %airRKind='MEM' OR %airRKind='B64' OR %airRKind='URL')
        #PROMPT('&Variable / expression (per record):',@s255),%airRVar,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airRKind='MEM')
        #PROMPT('&Bytes to use (blank = SIZE of the variable):',@s255),%airRLen,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airRKind='BLOB')
        #PROMPT('&BLOB field:',FIELD),%airRBlob
      #ENDENABLE
      #ENABLE(%airRKind='URL')
        #PROMPT('Download &timeout (seconds, 0 = the global default):',SPIN(@n3,0,300,1)),%airRSecs,DEFAULT(0)
      #ENDENABLE
      #PROMPT('Show &frame:',SPIN(@n4,1,9999,1)),%airRFrame,DEFAULT(1)
    #ENDBOXED
  #ENDTAB
  #TAB('&Rendering')
    #BOXED('When to fill it')
      #PROMPT('Load the picture for &every record',CHECK),%airREach,DEFAULT(1),AT(10)
      #DISPLAY('Off = the picture is loaded once, when the report opens.')
    #ENDBOXED
    #BOXED('How big to render it')
      #DISPLAY('Render it at least as big as it will print, or it will look soft.')
      #PROMPT('&Width (pixels):',SPIN(@n5,16,8000,10)),%airRW,DEFAULT(600)
      #PROMPT('&Height (pixels):',SPIN(@n5,16,8000,10)),%airRH,DEFAULT(450)
      #PROMPT('&Fit:',DROP('Fit inside, keep the ratio, pad[Img:Proportional]|Fit inside, keep the ratio, no padding[Img:Contain]|Fill the frame, keep the ratio, crop[Img:Cover]|Fill the frame, ignore the ratio[Img:Stretch]|No scaling, centred[Img:Centered]')),%airRFit,DEFAULT('Img:Proportional')
      #PROMPT('&Background:',COLOR),%airRBack,DEFAULT(00FFFFFFH)
      #PROMPT('How many working names to &rotate:',SPIN(@n2,1,32,1)),%airRPool,DEFAULT(8)
    #ENDBOXED
  #ENDTAB
  #TAB('&Touch-up')
    #BOXED('Applied once, right after the picture is read')
      #PROMPT('&Rotate:',DROP('Leave it[0]|90 degrees right[90]|180 degrees[180]|90 degrees left[270]')),%airRRot,DEFAULT('0')
      #PROMPT('&Mirror (left to right)',CHECK),%airRMirror,DEFAULT(0),AT(10)
      #PROMPT('&Flip (top to bottom)',CHECK),%airRFlip,DEFAULT(0),AT(10)
      #PROMPT('&Greyscale',CHECK),%airRGrey,DEFAULT(0),AT(10)
      #PROMPT('Cap the &longest side at (pixels, 0 = leave it):',SPIN(@n5,0,8000,50)),%airRMax,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #IF(VAREXISTS(%airRKey) = 0)
    #DECLARE(%airRKey)
  #ENDIF
  #SET(%airRKey,%Procedure & '_r' & %ActiveTemplateInstance)
#ENDAT
#!
#AT(%DataSection),WHERE(%airRDisable=0 AND %airRImage)
#INSERT(%airDeclare,%airRObject,1,300)
#ENDAT
#!
#AT(%BeforePrint),WHERE(%airRDisable=0 AND %airRImage AND %airREach=1)
  DO Air:Band:%airRObject
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'OpenReport','(),BYTE'),PRIORITY(7500),WHERE(%airRDisable=0 AND %airRImage AND %airREach=0)
  IF ReturnValue = Level:Benign
    DO Air:Band:%airRObject
  END
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%airRDisable=0 AND %airRImage)
Air:Band:%airRObject ROUTINE
  DATA
fname CSTRING(261)
  CODE
#INSERT(%airLoadStmt,%airRObject,%airRKind,%airRFile,%airRVar,%airRLen,%airRBlob,%airRKey,%airRSecs)
#INSERT(%airFrameStmt,%airRObject,%airRFrame)
#INSERT(%airTouchUp,%airRObject,%airRRot,%airRMirror,%airRFlip,%airRGrey,%airRMax)
  %airRObject:Pool += 1
  IF %airRObject:Pool > %airRPool THEN %airRObject:Pool = 1.
  fname = AirImg_Render(%airRObject,%airRW,%airRH,%airRFit, |
                       %airRObject.ArgbOf(%airRBack),'%airRKey' & '_' & %airRObject:Pool)
  SETTARGET(%Report)
  %airRImage{PROP:Text} = fname                                ! blank clears the frame
  SETTARGET()
#ENDAT
#!#############################################################################
#!  CODE TEMPLATE - allImageReadLoad
#!  One statement, at any embed: read a picture from any source into an object
#!  that already exists.
#!#############################################################################
#CODE(allImageReadLoad,'allImageRead - Load a picture from any source'),HLP('~allImageRead.htm')
#SHEET
  #TAB('&Load')
    #BOXED('Into')
      #PROMPT('&Object name (an ImageClass already declared):',@s64),%airKObject,REQ,DEFAULT('Pic1')
    #ENDBOXED
    #BOXED('From')
      #PROMPT('&Source:',DROP('A file on disk (fixed path)[FILE]|A variable holding a file path[PATH]|A BLOB field[BLOB]|A STRING variable in memory[MEM]|A base64 string[B64]|A URL (http/https)[URL]')),%airKKind,DEFAULT('PATH')
      #ENABLE(%airKKind='FILE')
        #PROMPT('File &name:',@s255),%airKFile,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airKKind='PATH' OR %airKKind='MEM' OR %airKKind='B64' OR %airKKind='URL')
        #PROMPT('&Variable / expression:',@s255),%airKVar,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airKKind='MEM')
        #PROMPT('&Bytes to use (blank = SIZE of the variable):',@s255),%airKLen,DEFAULT('')
      #ENDENABLE
      #ENABLE(%airKKind='BLOB')
        #PROMPT('&BLOB field:',FIELD),%airKBlob
      #ENDENABLE
      #ENABLE(%airKKind='URL')
        #PROMPT('Download &timeout (seconds, 0 = the global default):',SPIN(@n3,0,300,1)),%airKSecs,DEFAULT(0)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Then')
      #PROMPT('&Paint it into this IMAGE control:',CONTROL),%airKImage
      #PROMPT('&Fit:',DROP('Fit inside, keep the ratio, pad[Img:Proportional]|Fit inside, keep the ratio, no padding[Img:Contain]|Fill the frame, keep the ratio, crop[Img:Cover]|Fill the frame, ignore the ratio[Img:Stretch]|No scaling, centred[Img:Centered]')),%airKFit,DEFAULT('Img:Proportional')
      #PROMPT('&Background:',COLOR),%airKBack,DEFAULT(00FFFFFFH)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#INSERT(%airLoadStmtK)
#!#############################################################################
#!  GROUPS - the shared emitters.
#!  A #GROUP has no end marker: it runs to the next section directive. They all
#!  live down here, after every #AT in the file, which is where they belong.
#!#############################################################################
#!-----------------------------------------------------------------------------
#!  %airDeclare - one canvas worth of data. Labels are built from the object
#!  name, so several canvases on one window never collide. The event base keeps
#!  a canvas control and a canvas extension on the same window apart.
#!-----------------------------------------------------------------------------
#GROUP(%airDeclare,%pObj,%pOnReport,%pBase)
%pObj                ImageClass                              ! the picture, exactly as it was read
%pObj:Ref            &STRING                                 ! a BLOB, while it is being handed over
%pObj:Sz             LONG                                    ! how many bytes that was
%pObj:Path           CSTRING(261)                            ! what is on the canvas now
%pObj:Frame          LONG(1)                                 ! which frame of a multi-frame picture
#IF(%pOnReport)
%pObj:Pool           LONG                                    ! which working name this record used
#ELSE
%pObj:Cv             ImageClass                              ! the canvas: what the control is showing
%pObj:Zoom           LONG                                    ! 0 = fit the frame, else per cent
%pObj:PanX           LONG                                    ! the viewport, in picture pixels
%pObj:PanY           LONG
%pObj:Rgn            SIGNED                                  ! the region that takes the mouse
%pObj:StepX          LONG                                    ! one keyboard pan step, -1 0 or 1
%pObj:StepY          LONG
%pObj:SpotX          REAL                                    ! where to zoom about, across the canvas
%pObj:SpotY          REAL                                    !   0 = left/top, 1 = right/bottom
%pObj:Over           BYTE                                    ! is the pointer on this canvas?
%pObj:Gpu            LONG                                    ! the GPU canvas, 0 = drawing on the processor
%pObj:Bmp            CSTRING(261)                            ! what was handed to the graphics card
%pObj:Hooked         BYTE                                    ! this canvas took the window procedure
%pObj:Barred         BYTE                                    ! and its control's, for the scrollbars
%pObj:Drag           BYTE
%pObj:PanX0          LONG                                    ! the pan when the drag began
%pObj:PanY0          LONG
%pObj:MX             SIGNED                                  ! the pointer, in PIXELS
%pObj:MY             SIGNED
%pObj:SavePx         LONG                                    ! the window's units, while we borrow them
%pObj:DragX          SIGNED
%pObj:DragY          SIGNED
Air:Redraw:%pObj     EQUATE(EVENT:User + %pBase + %ActiveTemplateInstance)
#ENDIF
#!-----------------------------------------------------------------------------
#!  %airLoadStmt - read the picture into the object. Every branch either fills
#!  the object or empties it, so a canvas never shows the previous record's
#!  photograph when this record has none.
#!-----------------------------------------------------------------------------
#GROUP(%airLoadStmt,%pObj,%pKind,%pFile,%pVar,%pLen,%pBlob,%pTag,%pSecs)
#IF(VAREXISTS(%airSecs) = 0)
  #DECLARE(%airSecs)
  #DECLARE(%airHave)
#ENDIF
#!  a per-instance timeout of 0 means "whatever the global extension says"
#IF(%pSecs > 0)
  #SET(%airSecs,%pSecs)
#ELSE
  #SET(%airSecs,'AirImg:Secs')
#ENDIF
#!  nothing to read from? then empty the object rather than emit half a
#!  statement around a prompt the developer left blank
#SET(%airHave,1)
#IF(%pKind = 'BLOB' AND %pBlob = '')
  #SET(%airHave,0)
#ENDIF
#IF((%pKind = 'PATH' OR %pKind = 'MEM' OR %pKind = 'B64' OR %pKind = 'URL') AND %pVar = '')
  #SET(%airHave,0)
#ENDIF
#IF(%airHave = 0)
  %pObj.Kill()                                                ! no source was named
  %pObj:Path = ''
#ELSE
#CASE(%pKind)
#OF('FILE')
  %pObj:Path = '%pFile'
  AirImg_LoadPath(%pObj,%pObj:Path)
#OF('PATH')
  %pObj:Path = CLIP(%pVar)
  AirImg_LoadPath(%pObj,%pObj:Path)
#OF('BLOB')
  %pObj:Sz = %pBlob{PROP:Size}
  IF %pObj:Sz > 0
    %pObj:Ref &= NEW(STRING(%pObj:Sz))
    %pObj:Ref = %pBlob[1 : %pObj:Sz]
    AirImg_LoadBytes(%pObj,%pObj:Ref,%pObj:Sz,'%pTag')
    DISPOSE(%pObj:Ref)
  ELSE
    %pObj.Kill()
  END
  %pObj:Path = ''
#OF('MEM')
#IF(%pLen)
  %pObj:Sz = %pLen
#ELSE
  %pObj:Sz = SIZE(%pVar)
#ENDIF
  AirImg_LoadBytes(%pObj,%pVar,%pObj:Sz,'%pTag')
  %pObj:Path = ''
#OF('B64')
  AirImg_LoadB64(%pObj,%pVar,'%pTag')
  %pObj:Path = ''
#OF('URL')
  %pObj:Path = CLIP(%pVar)
  AirImg_LoadUrl(%pObj,%pObj:Path,'%pTag',%airSecs)
#ENDCASE
#ENDIF
#!-----------------------------------------------------------------------------
#!  %airLoadStmtK - the code template's own emitter (its prompts, its embed).
#!-----------------------------------------------------------------------------
#GROUP(%airLoadStmtK)
#INSERT(%airLoadStmt,%airKObject,%airKKind,%airKFile,%airKVar,%airKLen,%airKBlob,%Procedure & '_k',%airKSecs)
#IF(%airKImage)
%airKObject.Draw(%Window,%airKImage,%airKFit,%airKObject.ArgbOf(%airKBack))
#ENDIF
#!-----------------------------------------------------------------------------
#!  %airFrameStmt - pick a frame out of an animated GIF, a multi-page TIFF or
#!  an .ico. Frame 1 is what LoadFile already gave us.
#!-----------------------------------------------------------------------------
#GROUP(%airFrameStmt,%pObj,%pFrame)
#IF(%pFrame > 1)
!  LoadFrame counts from ZERO - imgcore's img_select_frame rejects anything
!  from Frames() up - while everything a person sees counts from one.
  IF %pObj.Frames() >= %pFrame
    %pObj:Frame = %pFrame
    %pObj.LoadFrame(%pObj:Frame - 1)
  END
#ENDIF
#!-----------------------------------------------------------------------------
#!  %airTouchUp - the once-only corrections, straight after reading.
#!-----------------------------------------------------------------------------
#GROUP(%airTouchUp,%pObj,%pRot,%pMirror,%pFlip,%pGrey,%pMax)
#IF(%pRot = '90')
  %pObj.RotateRight()
#ENDIF
#IF(%pRot = '180')
  %pObj.Rotate180()
#ENDIF
#IF(%pRot = '270')
  %pObj.RotateLeft()
#ENDIF
#IF(%pMirror)
  %pObj.Mirror()
#ENDIF
#IF(%pFlip)
  %pObj.FlipVert()
#ENDIF
#IF(%pGrey)
  %pObj.Greyscale(Img:Luma)
#ENDIF
#IF(%pMax > 0)
  IF %pObj.Wide() > %pMax OR %pObj.High() > %pMax
    %pObj.Fit(%pMax,%pMax,Img:Contain,0)                      ! cap the longest side
  END
#ENDIF
#!-----------------------------------------------------------------------------
#!  %airWheel - the mouse wheel, inside the window's CASE EVENT().
#!  Ctrl+wheel is the usual bargain in a picture viewer: the wheel on its own
#!  belongs to whatever the window wants to scroll, and only Ctrl means "zoom".
#!  Windows is asked for the Ctrl state directly - see the prototype above for
#!  why KEYSTATE() is no good during a wheel event.
#!-----------------------------------------------------------------------------
#GROUP(%airBarEvent,%pObj,%pBars)
#IF(%pBars)
  OF AirImg:Scrolled
    DO Air:Scrolled:%pObj
#ENDIF
#!-----------------------------------------------------------------------------
#GROUP(%airKeys,%pObj,%pPan,%pPanKeys)
#IF(%pPan AND %pPanKeys)
  OF EVENT:AlertKey
    CASE KEYCODE()
    OF CtrlUp
      %pObj:StepX = 0
      %pObj:StepY = -1
      DO Air:PanBy:%pObj
    OF CtrlDown
      %pObj:StepX = 0
      %pObj:StepY = 1
      DO Air:PanBy:%pObj
    OF CtrlLeft
      %pObj:StepX = -1
      %pObj:StepY = 0
      DO Air:PanBy:%pObj
    OF CtrlRight
      %pObj:StepX = 1
      %pObj:StepY = 0
      DO Air:PanBy:%pObj
    OF CtrlHome
      DO Air:Fit:%pObj
    END
#ENDIF
#!-----------------------------------------------------------------------------
#GROUP(%airWheel,%pObj,%pZoom,%pCtrl)
#IF(%pZoom)
  OF AirImg:CtrlUp
    DO Air:WheelIn:%pObj
  OF AirImg:CtrlDown
    DO Air:WheelOut:%pObj
#IF(%pCtrl = 0)
  OF AirImg:WheelUp                                           ! Ctrl not required here
    DO Air:WheelIn:%pObj
  OF AirImg:WheelDown
    DO Air:WheelOut:%pObj
#ENDIF
#ENDIF
#!-----------------------------------------------------------------------------
#!  %airUnhook - give the window its own procedure back on the way out. Only
#!  the canvas that took it puts it back.
#!-----------------------------------------------------------------------------
#GROUP(%airUnhook,%pObj)
  IF %pObj:Hooked
    AirImg_DropWheel(%Window{PROP:Handle})
    %pObj:Hooked = 0
  END
  IF %pObj:Barred
    AirImg_DropBars(%pObj:Rgn{PROP:Handle})
    %pObj:Barred = 0
  END
  IF %pObj:Gpu
    d2c_Detach(%pObj:Gpu)                                     ! gives the control its own window back
    %pObj:Gpu = 0
  END
#!-----------------------------------------------------------------------------
#!  %airFieldEvents - the mouse, for whichever control the canvas paints into.
#!  The events arrive from the REGION laid over the image; the image's own feq
#!  is accepted too, so a drop that lands on the picture still counts.
#!-----------------------------------------------------------------------------
#GROUP(%airFieldEvents,%pObj,%pFeq,%pPan,%pMenu,%pOpen,%pDrop)
  IF FIELD() = %pObj:Rgn OR FIELD() = %pFeq
    CASE EVENT()
#IF(%pPan)
    OF EVENT:MouseDown
      IF KEYCODE() = MouseLeft AND %pObj:Zoom
!  MOUSEX and MOUSEY answer in the WINDOW's units, and a window unit is not a
!  pixel - it is half of one across and half of one down on a default window.
!  The pan is in pixels, so read the pointer with the units switched to pixels
!  or the picture drags at half speed and slides out from under the pointer.
        %pObj:SavePx = 0{PROP:Pixels}
        0{PROP:Pixels} = 1
        %pObj:Drag  = 1
        %pObj:DragX = MOUSEX()
        %pObj:DragY = MOUSEY()
        0{PROP:Pixels} = %pObj:SavePx
        %pObj:PanX0 = %pObj:PanX                              ! the anchor: where we started
        %pObj:PanY0 = %pObj:PanY
      END
    OF EVENT:MouseMove
      IF %pObj:Drag
        %pObj:SavePx = 0{PROP:Pixels}
        0{PROP:Pixels} = 1
        %pObj:MX = MOUSEX()
        %pObj:MY = MOUSEY()
        0{PROP:Pixels} = %pObj:SavePx
!  Measure from where the drag STARTED, never from the last move. A drag
!  arrives as a stream of one- and two-pixel deltas, and on the graphics card
!  each one is divided by the zoom: at 500 per cent a one-pixel move is a fifth
!  of an image pixel, which rounds to nothing, and the remainder is gone for
!  good. Add up sixty of those and the picture has not moved at all. Taken from
!  the anchor there is one rounding, of the whole distance, and the picture
!  sits where the pointer put it.
        IF %pObj:Gpu AND %pObj:Zoom                           ! the GPU pans in IMAGE pixels
          %pObj:PanX = %pObj:PanX0 + (%pObj:DragX - %pObj:MX) * 100 / %pObj:Zoom
          %pObj:PanY = %pObj:PanY0 + (%pObj:DragY - %pObj:MY) * 100 / %pObj:Zoom
        ELSE
          %pObj:PanX = %pObj:PanX0 + %pObj:DragX - %pObj:MX
          %pObj:PanY = %pObj:PanY0 + %pObj:DragY - %pObj:MY
        END
        DO Air:Show:%pObj
      END
    OF EVENT:MouseUp
      %pObj:Drag = 0
#ENDIF
#IF(%pDrop)
    OF EVENT:Drop
      %pObj:Path = CLIP(DROPID())                             ! several files? take the first
      IF INSTRING(',',%pObj:Path,1,1)
        %pObj:Path = SUB(%pObj:Path,1,INSTRING(',',%pObj:Path,1,1) - 1)
      END
      IF AirImg_LoadPath(%pObj,%pObj:Path)
        DO Air:Fresh:%pObj
      END
      DO Air:Show:%pObj
#ENDIF
#IF(%pMenu OR %pOpen)
    OF EVENT:AlertKey
      CASE KEYCODE()
#IF(%pMenu)
      OF MouseRight
        DO Air:Menu:%pObj
#ENDIF
#IF(%pOpen)
      OF MouseLeft2
        DO Air:Open:%pObj
#ENDIF
      END
#ENDIF
    END
  END
#!-----------------------------------------------------------------------------
#!  %airCanvasFromControl / %airCanvasFromExtension - the two front doors to
#!  the canvas routines. Each copies its own prompts into the %airX symbols the
#!  body reads, so one body serves both templates and no argument can slip.
#!-----------------------------------------------------------------------------
#GROUP(%airCanvasFromControl)
#CALL(%airPrep)
#SET(%airXObj,%airCObject)
#SET(%airXFeq,%airCFeq)
#SET(%airXKind,%airCKind)
#SET(%airXFile,%airCFile)
#SET(%airXVar,%airCVar)
#SET(%airXLen,%airCLen)
#SET(%airXBlob,%airCBlob)
#SET(%airXKey,%airCKey)
#SET(%airXSecs,%airCSecs)
#SET(%airXEngine,%airCEngine)
#SET(%airXFit,%airCFit)
#SET(%airXBack,%airCBack)
#SET(%airXAuto,%airCAuto)
#SET(%airXZoom,%airCZoom)
#SET(%airXStep,%airCZoomStep)
#SET(%airXPan,%airCPan)
#SET(%airXPanKeys,%airCPanKeys)
#SET(%airXBars,%airCBars)
#SET(%airXPanStep,%airCPanStep)
#SET(%airXMenu,%airCMenu)
#SET(%airXOpen,%airCOpen)
#SET(%airXDrop,%airCDrop)
#SET(%airXSave,%airCSave)
#SET(%airXRotate,%airCRotate)
#SET(%airXFrames,%airCFrames)
#SET(%airXFrame,%airCFrame)
#SET(%airXStatus,%airCStatus)
#SET(%airXZone,%airCStatusZone)
#SET(%airXTip,%airCTip)
#SET(%airXRot,%airCRot)
#SET(%airXMirror,%airCMirror)
#SET(%airXFlip,%airCFlip)
#SET(%airXGrey,%airCGrey)
#SET(%airXMax,%airCMax)
#INSERT(%airCanvasBody)
#!
#GROUP(%airCanvasFromExtension)
#CALL(%airPrep)
#SET(%airXObj,%airWObject)
#SET(%airXFeq,%airWImage)
#SET(%airXKind,%airWKind)
#SET(%airXFile,%airWFile)
#SET(%airXVar,%airWVar)
#SET(%airXLen,%airWLen)
#SET(%airXBlob,%airWBlob)
#SET(%airXKey,%airWKey)
#SET(%airXSecs,%airWSecs)
#SET(%airXEngine,%airWEngine)
#SET(%airXFit,%airWFit)
#SET(%airXBack,%airWBack)
#SET(%airXAuto,%airWAuto)
#SET(%airXZoom,%airWZoom)
#SET(%airXStep,%airWZoomStep)
#SET(%airXPan,%airWPan)
#SET(%airXPanKeys,%airWPanKeys)
#SET(%airXBars,%airWBars)
#SET(%airXPanStep,%airWPanStep)
#SET(%airXMenu,%airWMenu)
#SET(%airXOpen,%airWOpen)
#SET(%airXDrop,%airWDrop)
#SET(%airXSave,%airWSave)
#SET(%airXRotate,%airWRotate)
#SET(%airXFrames,%airWFrames)
#SET(%airXFrame,%airWFrame)
#SET(%airXStatus,%airWStatus)
#SET(%airXZone,%airWStatusZone)
#SET(%airXTip,%airWTip)
#SET(%airXRot,%airWRot)
#SET(%airXMirror,%airWMirror)
#SET(%airXFlip,%airWFlip)
#SET(%airXGrey,%airWGrey)
#SET(%airXMax,%airWMax)
#INSERT(%airCanvasBody)
#!
#GROUP(%airPrep)
#IF(VAREXISTS(%airXObj) = 0)
  #DECLARE(%airXObj)
  #DECLARE(%airXFeq)
  #DECLARE(%airXKind)
  #DECLARE(%airXFile)
  #DECLARE(%airXVar)
  #DECLARE(%airXLen)
  #DECLARE(%airXBlob)
  #DECLARE(%airXKey)
  #DECLARE(%airXSecs)
  #DECLARE(%airXEngine)
  #DECLARE(%airXFit)
  #DECLARE(%airXBack)
  #DECLARE(%airXAuto)
  #DECLARE(%airXZoom)
  #DECLARE(%airXStep)
  #DECLARE(%airXPan)
  #DECLARE(%airXPanKeys)
  #DECLARE(%airXBars)
  #DECLARE(%airXPanStep)
  #DECLARE(%airXMenu)
  #DECLARE(%airXOpen)
  #DECLARE(%airXDrop)
  #DECLARE(%airXSave)
  #DECLARE(%airXRotate)
  #DECLARE(%airXFrames)
  #DECLARE(%airXFrame)
  #DECLARE(%airXStatus)
  #DECLARE(%airXZone)
  #DECLARE(%airXTip)
  #DECLARE(%airXRot)
  #DECLARE(%airXMirror)
  #DECLARE(%airXFlip)
  #DECLARE(%airXGrey)
  #DECLARE(%airXMax)
  #DECLARE(%airMenuN)
  #DECLARE(%airMenuTxt)
  #DECLARE(%airItemOpen)
  #DECLARE(%airItemIn)
  #DECLARE(%airItemOut)
  #DECLARE(%airItem100)
  #DECLARE(%airItemFit)
  #DECLARE(%airItemLeft)
  #DECLARE(%airItemRight)
  #DECLARE(%airItemNext)
  #DECLARE(%airItemPrev)
  #DECLARE(%airItemSave)
  #DECLARE(%airItemInfo)
#ENDIF
#!-----------------------------------------------------------------------------
#!  %airMenuAdd - one more line on the right-click menu, and the number it will
#!  answer with. No separators: a separator takes a number of its own and makes
#!  the CASE below lie about which line was clicked.
#!-----------------------------------------------------------------------------
#GROUP(%airMenuAdd,%pText)
#IF(%airMenuTxt <> '')
  #SET(%airMenuTxt,%airMenuTxt & '|')
#ENDIF
#SET(%airMenuTxt,%airMenuTxt & %pText)
#SET(%airMenuN,%airMenuN + 1)
#RETURN(%airMenuN)
#!-----------------------------------------------------------------------------
#!  %airCanvasBody - everything the canvas does on a window.
#!
#!    Air:Setup  once, when the window opens: make the region, read the picture
#!    Air:Place  put the region exactly over the image, again after a resize
#!    Air:Fresh  a NEW picture is in the object: touch it up, reset the view
#!    Air:Show   paint what the object holds, at the current zoom and pan
#!    Air:In     zoom a step in, about the middle of the viewport
#!    Air:Out    zoom a step out; past the fit, it goes back to fitting
#!    Air:Fit    fit the frame again
#!    Air:Open   let the user choose another picture
#!    Air:Save   write a copy, in whatever format the name asks for
#!    Air:Menu   the right-click menu
#!-----------------------------------------------------------------------------
#GROUP(%airCanvasBody)
#SET(%airMenuN,0)
#SET(%airMenuTxt,'')
#SET(%airItemOpen,0)
#SET(%airItemIn,0)
#SET(%airItemOut,0)
#SET(%airItem100,0)
#SET(%airItemFit,0)
#SET(%airItemLeft,0)
#SET(%airItemRight,0)
#SET(%airItemNext,0)
#SET(%airItemPrev,0)
#SET(%airItemSave,0)
#SET(%airItemInfo,0)
#IF(%airXOpen)
  #SET(%airItemOpen,%airMenuAdd('Open a picture...'))
#ENDIF
#IF(%airXZoom)
  #SET(%airItemIn,%airMenuAdd('Zoom in'))
  #SET(%airItemOut,%airMenuAdd('Zoom out'))
  #SET(%airItem100,%airMenuAdd('Actual size'))
  #SET(%airItemFit,%airMenuAdd('Fit the frame'))
#ENDIF
#IF(%airXRotate)
  #SET(%airItemLeft,%airMenuAdd('Rotate left'))
  #SET(%airItemRight,%airMenuAdd('Rotate right'))
#ENDIF
#IF(%airXFrames)
  #SET(%airItemNext,%airMenuAdd('Next frame'))
  #SET(%airItemPrev,%airMenuAdd('Previous frame'))
#ENDIF
#IF(%airXSave)
  #SET(%airItemSave,%airMenuAdd('Save a copy...'))
#ENDIF
#SET(%airItemInfo,%airMenuAdd('What is this picture?'))
Air:Setup:%airXObj ROUTINE
!  The IMAGE control is only the paint surface. A REGION created over it takes
!  the mouse - the way Clarion's own ActiveImage class does it
!  (libsrc\win\ActiveImage.clw:303). A REGION has nothing of its own to draw,
!  so the picture underneath shows through untouched.
  IF ~%airXObj:Rgn
    %airXObj:Rgn = CREATE(0,CREATE:Region,%airXFeq{PROP:Parent})
!  IMM, or the mouse never speaks. EVENT:MouseMove and EVENT:MouseUp are
!  documented as arriving "on a REGION with the IMM attribute" - without it a
!  region still gets MouseDown (it is a synonym for EVENT:Accepted) and then
!  nothing at all, so a drag begins and never moves. A region built at run time
!  has no attribute list to carry IMM, so it is set as a property here.
    %airXObj:Rgn{PROP:IMM} = 1
  END
  DO Air:Place:%airXObj
  UNHIDE(%airXObj:Rgn)
#IF(%airXBars)
!  The scrollbars go on BEFORE the graphics card attaches: adding the styles
!  takes a slice off the client area, and the render target must be built for
!  what is left of it.
  IF AirImg_HookBars(%airXObj:Rgn{PROP:Handle})
    %airXObj:Barred = 1
  END
#ENDIF
#IF(%airXEngine = 'AUTO')
!  Hand the canvas to the graphics card. The REGION laid over the image owns a
!  real window, so Direct2D renders into THAT and Clarion keeps the rest of the
!  window to itself. If there is no Direct2D, or it will not attach, the canvas
!  quietly goes on drawing with the processor.
  IF ~%airXObj:Gpu AND d2c_Available()
    %airXObj:Gpu = d2c_Attach(%airXObj:Rgn{PROP:Handle})
  END
  IF %airXObj:Gpu
    HIDE(%airXFeq)                                            ! the IMAGE control is not used now
  END
#ENDIF
#IF(%airXZoom)
!  Take the mouse wheel off the window procedure. The first canvas on a window
!  does it; the rest ride along, because the event reaches all of them.
  IF AirImg_HookWheel(%Window{PROP:Handle})                   ! the helper takes the address,
    %airXObj:Hooked = 1                                       !   never this module
  END
#ENDIF
#IF(%airXDrop)
  %airXFeq{PROP:DropID,1}     = '~FILE'                       ! a file dragged out of Explorer
  %airXObj:Rgn{PROP:DropID,1} = '~FILE'
#ENDIF
#IF(%airXMenu)
  %airXObj:Rgn{PROP:Alrt,255} = MouseRight
#ENDIF
#IF(%airXOpen)
  %airXObj:Rgn{PROP:Alrt,254} = MouseLeft2
#ENDIF
#IF(%airXPan AND %airXPanKeys)
!  ALERT() adds to the window's alerted keys rather than claiming a numbered
!  slot, so it cannot tread on another template's alert. Ctrl+arrows, because
!  the bare arrows belong to whatever browse the window is carrying.
  ALERT(CtrlUp)
  ALERT(CtrlDown)
  ALERT(CtrlLeft)
  ALERT(CtrlRight)
  ALERT(CtrlHome)
#ENDIF
#IF(%airXAuto AND %airXKind <> 'NONE')
#INSERT(%airLoadStmt,%airXObj,%airXKind,%airXFile,%airXVar,%airXLen,%airXBlob,%airXKey,%airXSecs)
  DO Air:Fresh:%airXObj
#ENDIF
  POST(Air:Redraw:%airXObj)                                   ! first paint, once the window is up

Air:Place:%airXObj ROUTINE
!  Keep the region exactly over the image, however the resizer moves it.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~%airXObj:Rgn THEN EXIT.
  GETPOSITION(%airXFeq,x,y,w,h)
  SETPOSITION(%airXObj:Rgn,x,y,w,h)

Air:Size:%airXObj ROUTINE
!  The canvas control moved or changed size, so the render target has to be
!  told; Direct2D will not notice on its own.
#IF(%airXEngine = 'AUTO')
  IF %airXObj:Gpu
    d2c_Resize(%airXObj:Gpu)
  END
#ELSE
  EXIT                                                        ! nothing to resize on the processor path
#ENDIF

Air:Upload:%airXObj ROUTINE
!  Hand the graphics card the pixels the object is holding NOW. Called when a
!  new picture arrives and again whenever the frame changes - a zoom does not
!  need it, which is the whole point of the GPU path.
#IF(%airXEngine = 'AUTO')
  IF %airXObj:Gpu
    IF ~%airXObj.Ok()
      d2c_Clear(%airXObj:Gpu)
    ELSIF %airXObj.CloneInto(%airXObj:Cv)
      %airXObj:Cv.Flatten(%airXObj.ArgbOf(%airXBack))
      %airXObj:Cv.BmpBits = 32
      %airXObj:Bmp = AirImg_Temp('%airXKey','.bmp')
      IF %airXObj:Cv.SaveFile(%airXObj:Bmp, Img:Bmp)
        d2c_LoadBmp(%airXObj:Gpu, %airXObj:Bmp)
      END
    END
  END
#ELSE
  EXIT                                                        ! nothing to upload on the processor path
#ENDIF

Air:Frame:%airXObj ROUTINE
!  Show whatever frame number is in <object>:Frame - a page of a TIFF, a frame
!  of an animated GIF, one size out of an .ico. The zoom and the pan are left
!  alone, so stepping through pages does not throw the view away.
  IF ~%airXObj.Ok() THEN EXIT.
  IF %airXObj:Frame < 1 THEN %airXObj:Frame = 1.
  IF %airXObj:Frame > %airXObj.Frames() THEN %airXObj:Frame = %airXObj.Frames().
  IF ~%airXObj.LoadFrame(%airXObj:Frame - 1) THEN EXIT.       ! the engine counts from zero
#INSERT(%airTouchUp,%airXObj,%airXRot,%airXMirror,%airXFlip,%airXGrey,%airXMax)
  DO Air:Upload:%airXObj
  DO Air:Show:%airXObj

Air:Fresh:%airXObj ROUTINE
!  A NEW picture has just landed in the object.
#INSERT(%airFrameStmt,%airXObj,%airXFrame)
#INSERT(%airTouchUp,%airXObj,%airXRot,%airXMirror,%airXFlip,%airXGrey,%airXMax)
  DO Air:Upload:%airXObj
  %airXObj:Zoom = 0                                           ! back to fitting the frame
  %airXObj:PanX = 0
  %airXObj:PanY = 0
#IF(%airXTip)
  %airXFeq{PROP:Tooltip} = %airXObj:Path
#ENDIF
#IF(%airXStatus)
  IF %airXObj.Ok()
    0{PROP:StatusText,%airXZone} = %airXObj.Describe()
  ELSE
    0{PROP:StatusText,%airXZone} = ''
  END
#ENDIF

Air:Show:%airXObj ROUTINE
!  Paint what the object holds. At zoom 0 the class fits a copy to the control
!  for us; from there on the viewport is cut out here and blitted as it is.
  DATA
w      LONG,AUTO
h      LONG,AUTO
cw     LONG,AUTO
ch     LONG,AUTO
iw     LONG,AUTO
ih     LONG,AUTO
zw     LONG,AUTO
zh     LONG,AUTO
sx     LONG,AUTO
sy     LONG,AUTO
sw     LONG,AUTO
sh     LONG,AUTO
savePx LONG,AUTO
  CODE
#IF(%airXEngine = 'AUTO')
!  On the graphics card a repaint is a zoom factor and an offset. Nothing is
!  resampled, nothing is written to disk, and the cost does not depend on how
!  big the picture is. Zoom 0 still means "fit the frame"; the factor for that
!  is worked out from the canvas and the picture.
  IF %airXObj:Gpu
    DO Air:Gpu:%airXObj
    EXIT
  END
#ENDIF
  IF ~%airXObj.Ok()
    %airXFeq{PROP:Text} = ''
    DISPLAY(%airXFeq)
    EXIT
  END
  IF ~%airXObj:Zoom
    %airXObj.Draw(%Window,%airXFeq,%airXFit,%airXObj.ArgbOf(%airXBack))
    DO Air:Bars:%airXObj
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the frame, in real pixels
  0{PROP:Pixels} = 1
  w = %airXFeq{PROP:Width}
  h = %airXFeq{PROP:Height}
  0{PROP:Pixels} = savePx
  IF w < 4 OR h < 4 THEN EXIT.
!  CROP FIRST, then scale. Scaling the whole picture and keeping the sliver
!  that shows costs the whole picture: at 400 per cent a 2400x1800 photograph
!  becomes 9600x7200 - 69 million pixels resampled to fill a 620x460 hole, and
!  it gets four times worse each time you double the zoom. Cutting the source
!  rectangle out first makes the work depend on the SIZE OF THE FRAME instead,
!  whatever the picture and whatever the zoom. Measured on that photograph:
!  8.9 seconds a step becomes 52 milliseconds.
  iw = %airXObj.Wide()
  ih = %airXObj.High()
  IF iw < 1 OR ih < 1 THEN EXIT.
  zw = INT(iw * %airXObj:Zoom / 100)                          ! the picture at this zoom
  zh = INT(ih * %airXObj:Zoom / 100)
  cw = w                                                      ! the viewport, never bigger than the picture
  ch = h
  IF cw > zw THEN cw = zw.
  IF ch > zh THEN ch = zh.
  IF cw < 1 OR ch < 1 THEN EXIT.
  IF %airXObj:PanX > zw - cw THEN %airXObj:PanX = zw - cw.
  IF %airXObj:PanY > zh - ch THEN %airXObj:PanY = zh - ch.
  IF %airXObj:PanX < 0 THEN %airXObj:PanX = 0.
  IF %airXObj:PanY < 0 THEN %airXObj:PanY = 0.
  sx = INT(%airXObj:PanX * 100 / %airXObj:Zoom)               ! source pixel at the view's corner
  sy = INT(%airXObj:PanY * 100 / %airXObj:Zoom)
  sw = INT(cw * 100 / %airXObj:Zoom) + 2                      ! enough source to cover it, plus slack
  sh = INT(ch * 100 / %airXObj:Zoom) + 2
  IF sx + sw > iw THEN sw = iw - sx.
  IF sy + sh > ih THEN sh = ih - sy.
  IF sw < 1 OR sh < 1 THEN EXIT.
  IF ~%airXObj.CloneInto(%airXObj:Cv) THEN EXIT.
  %airXObj:Cv.Crop(sx,sy,sw,sh)                               ! just what shows
  %airXObj:Cv.Resize(INT(sw * %airXObj:Zoom / 100),           |
                     INT(sh * %airXObj:Zoom / 100),Img:Best)  ! and scale only that
!  The crop landed on a whole source pixel, which is up to one pixel adrift of
!  where the view really starts; take that back off the scaled piece so the
!  picture does not jump about as it is panned.
  %airXObj:Cv.Crop(%airXObj:PanX - INT(sx * %airXObj:Zoom / 100),             |
                   %airXObj:PanY - INT(sy * %airXObj:Zoom / 100),cw,ch)
  %airXObj:Cv.Fit(w,h,Img:Centered,%airXObj.ArgbOf(%airXBack))  ! pad out to the frame
  %airXObj:Cv.Draw(%Window,%airXFeq,-1)                       ! -1 = blit it as it is
  DO Air:Bars:%airXObj
#IF(%airXEngine = 'AUTO')

Air:Gpu:%airXObj ROUTINE
!  Push the current view at the graphics card. Zoom is a factor here (1 = one
!  image pixel per screen pixel) and the pan is in IMAGE pixels, which is what
!  Direct2D wants; the canvas keeps its zoom as a percentage, as the processor
!  path does, so the two stay interchangeable.
  DATA
z    REAL,AUTO
fit  REAL,AUTO
vw   LONG,AUTO
vh   LONG,AUTO
iw   LONG,AUTO
ih   LONG,AUTO
  CODE
  vw = d2c_ViewW(%airXObj:Gpu)
  vh = d2c_ViewH(%airXObj:Gpu)
  iw = d2c_ImageW(%airXObj:Gpu)
  ih = d2c_ImageH(%airXObj:Gpu)
  IF iw < 1 OR ih < 1 OR vw < 1 OR vh < 1
    d2c_SetView(%airXObj:Gpu, 1.0, 0, 0, %airXObj.ArgbOf(%airXBack), 1)
    EXIT
  END
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  IF ~%airXObj:Zoom
    z = fit                                                   ! 0 means fit the frame
    %airXObj:PanX = 0
    %airXObj:PanY = 0
  ELSE
    z = %airXObj:Zoom / 100
  END
  IF z < 0.001 THEN z = 0.001.
!  keep the view on the picture
  IF %airXObj:PanX > iw - (vw / z) THEN %airXObj:PanX = iw - (vw / z).
  IF %airXObj:PanY > ih - (vh / z) THEN %airXObj:PanY = ih - (vh / z).
  IF %airXObj:PanX < 0 THEN %airXObj:PanX = 0.
  IF %airXObj:PanY < 0 THEN %airXObj:PanY = 0.
  d2c_SetView(%airXObj:Gpu, z, %airXObj:PanX, %airXObj:PanY,                |
              %airXObj.ArgbOf(%airXBack), 1)
  DO Air:Bars:%airXObj
#ENDIF
#IF(%airXZoom)

Air:Spot:%airXObj ROUTINE
!  Decide what the zoom turns about. Under the pointer if the pointer is on
!  this canvas - so the detail you are pointing at stays put - and the middle
!  if it is anywhere else, which is what the menu and the keyboard want. The
!  answer is a fraction across the canvas, so it does not matter whether the
!  window is measured in dialog units or pixels.
  DATA
rx SIGNED,AUTO
ry SIGNED,AUTO
rw SIGNED,AUTO
rh SIGNED,AUTO
  CODE
  %airXObj:SpotX = 0.5
  %airXObj:SpotY = 0.5
  %airXObj:Over  = 0
  GETPOSITION(%airXFeq,rx,ry,rw,rh)
  IF rw < 1 OR rh < 1 THEN EXIT.
  IF MOUSEX() < rx OR MOUSEX() > rx + rw THEN EXIT.
  IF MOUSEY() < ry OR MOUSEY() > ry + rh THEN EXIT.
  %airXObj:Over  = 1
  %airXObj:SpotX = (MOUSEX() - rx) / rw
  %airXObj:SpotY = (MOUSEY() - ry) / rh

Air:WheelIn:%airXObj ROUTINE
!  A wheel notch reaches EVERY canvas on the window, so only the one under the
!  pointer takes it. The menu calls Air:In directly and is not filtered.
  DO Air:Spot:%airXObj
  IF %airXObj:Over
    DO Air:In:%airXObj
  END

Air:WheelOut:%airXObj ROUTINE
  DO Air:Spot:%airXObj
  IF %airXObj:Over
    DO Air:Out:%airXObj
  END

Air:In:%airXObj ROUTINE
!  A step in, about whatever Air:Spot picked.
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
mx     LONG,AUTO
my     LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~%airXObj.Ok() THEN EXIT.
  DO Air:Spot:%airXObj
#IF(%airXEngine = 'AUTO')
  IF %airXObj:Gpu
    DO Air:GpuIn:%airXObj
    EXIT
  END
#ENDIF
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = %airXFeq{PROP:Width}
  h = %airXFeq{PROP:Height}
  0{PROP:Pixels} = savePx
  was = %airXObj:Zoom
  IF ~was THEN was = AirImg_FitPct(%airXObj,w,h).
  now = was + %airXStep
  IF now > 1600 THEN now = 1600.
  mx = %airXObj:SpotX * w
  my = %airXObj:SpotY * h
  %airXObj:PanX = INT((%airXObj:PanX + mx) * now / was - mx)
  %airXObj:PanY = INT((%airXObj:PanY + my) * now / was - my)
  %airXObj:Zoom = now
  DO Air:Show:%airXObj

Air:Out:%airXObj ROUTINE
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
mx     LONG,AUTO
my     LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~%airXObj.Ok() OR ~%airXObj:Zoom THEN EXIT.               ! already fitted
  DO Air:Spot:%airXObj
#IF(%airXEngine = 'AUTO')
  IF %airXObj:Gpu
    DO Air:GpuOut:%airXObj
    EXIT
  END
#ENDIF
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = %airXFeq{PROP:Width}
  h = %airXFeq{PROP:Height}
  0{PROP:Pixels} = savePx
  was = %airXObj:Zoom
  now = was - %airXStep
  IF now <= AirImg_FitPct(%airXObj,w,h)                        ! all the way out = fit the frame
    DO Air:Fit:%airXObj
    EXIT
  END
  mx = %airXObj:SpotX * w
  my = %airXObj:SpotY * h
  %airXObj:PanX = INT((%airXObj:PanX + mx) * now / was - mx)
  %airXObj:PanY = INT((%airXObj:PanY + my) * now / was - my)
  %airXObj:Zoom = now
  DO Air:Show:%airXObj

Air:PanBy:%airXObj ROUTINE
!  One keyboard step. There is nothing to pan when the picture is fitted, so
!  the keys are quiet then - the same rule the drag follows.
  DATA
w      LONG,AUTO
h      LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~%airXObj.Ok() OR ~%airXObj:Zoom THEN EXIT.
#IF(%airXEngine = 'AUTO')
  IF %airXObj:Gpu
!  The GPU pans in IMAGE pixels. The frame shows ViewW/zoom of them, so a step
!  of PanStep per cent is ViewW * PanStep / Zoom - the hundreds cancel.
    %airXObj:PanX += %airXObj:StepX * d2c_ViewW(%airXObj:Gpu) *              |
                     %airXPanStep / %airXObj:Zoom
    %airXObj:PanY += %airXObj:StepY * d2c_ViewH(%airXObj:Gpu) *              |
                     %airXPanStep / %airXObj:Zoom
    DO Air:Gpu:%airXObj
    EXIT
  END
#ENDIF
  savePx = 0{PROP:Pixels}                                     ! the processor pans in scaled pixels
  0{PROP:Pixels} = 1
  w = %airXFeq{PROP:Width}
  h = %airXFeq{PROP:Height}
  0{PROP:Pixels} = savePx
  %airXObj:PanX += INT(%airXObj:StepX * w * %airXPanStep / 100)
  %airXObj:PanY += INT(%airXObj:StepY * h * %airXPanStep / 100)
  DO Air:Show:%airXObj

Air:Bars:%airXObj ROUTINE
!  Tell the scrollbars how much picture there is and how much of it shows, in
!  whatever units this engine pans in. Windows hides a bar whose page covers
!  its whole range, so at "fit the frame" they take themselves away.
#IF(%airXBars)
  DATA
tot  LONG,AUTO
page LONG,AUTO
w    LONG,AUTO
h    LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~%airXObj:Barred THEN EXIT.
  IF ~%airXObj.Ok() OR ~%airXObj:Zoom                         ! fitted: no bars
    AirImg_SetBar(%airXObj:Rgn{PROP:Handle},AirImg:SbHorz,0,1,1)
    AirImg_SetBar(%airXObj:Rgn{PROP:Handle},AirImg:SbVert,0,1,1)
#IF(%airXEngine = 'AUTO')
    IF %airXObj:Gpu THEN d2c_Resize(%airXObj:Gpu).
#ENDIF
    EXIT
  END
#IF(%airXEngine = 'AUTO')
  IF %airXObj:Gpu                                             ! the GPU pans in image pixels
    tot  = d2c_ImageW(%airXObj:Gpu)
    page = INT(d2c_ViewW(%airXObj:Gpu) * 100 / %airXObj:Zoom)
    AirImg_SetBar(%airXObj:Rgn{PROP:Handle},AirImg:SbHorz,%airXObj:PanX,page,tot)
    tot  = d2c_ImageH(%airXObj:Gpu)
    page = INT(d2c_ViewH(%airXObj:Gpu) * 100 / %airXObj:Zoom)
    AirImg_SetBar(%airXObj:Rgn{PROP:Handle},AirImg:SbVert,%airXObj:PanY,page,tot)
    d2c_Resize(%airXObj:Gpu)
    EXIT
  END
#ENDIF
  savePx = 0{PROP:Pixels}                                     ! the processor pans in scaled pixels
  0{PROP:Pixels} = 1
  w = %airXFeq{PROP:Width}
  h = %airXFeq{PROP:Height}
  0{PROP:Pixels} = savePx
  AirImg_SetBar(%airXObj:Rgn{PROP:Handle},AirImg:SbHorz,%airXObj:PanX,w,      |
                INT(%airXObj.Wide() * %airXObj:Zoom / 100))
  AirImg_SetBar(%airXObj:Rgn{PROP:Handle},AirImg:SbVert,%airXObj:PanY,h,      |
                INT(%airXObj.High() * %airXObj:Zoom / 100))
#ELSE
  EXIT                                                        ! scrollbars are switched off
#ENDIF

Air:Scrolled:%airXObj ROUTINE
!  A bar moved - on this canvas or on another one. Read our own two back; if
!  they have not moved there is nothing to do, which is what makes it safe to
!  send the one event to every canvas on the window.
#IF(%airXBars)
  DATA
nx LONG,AUTO
ny LONG,AUTO
  CODE
  IF ~%airXObj:Barred OR ~%airXObj:Zoom THEN EXIT.
  nx = AirImg_BarPos(%airXObj:Rgn{PROP:Handle},AirImg:SbHorz)
  ny = AirImg_BarPos(%airXObj:Rgn{PROP:Handle},AirImg:SbVert)
  IF nx = %airXObj:PanX AND ny = %airXObj:PanY THEN EXIT.
  %airXObj:PanX = nx
  %airXObj:PanY = ny
#IF(%airXEngine = 'AUTO')
  IF %airXObj:Gpu
    DO Air:Gpu:%airXObj
    EXIT
  END
#ENDIF
  DO Air:Show:%airXObj
#ELSE
  EXIT
#ENDIF

Air:Fit:%airXObj ROUTINE
  %airXObj:Zoom = 0
  %airXObj:PanX = 0
  %airXObj:PanY = 0
  DO Air:Show:%airXObj
#IF(%airXEngine = 'AUTO')

Air:GpuIn:%airXObj ROUTINE
!  A step in, turning about the spot Air:Spot picked. The pan is in image
!  pixels, so the pixel under that spot before the step is the pixel under it
!  after: pan += spot/was - spot/now.
  DATA
was  REAL,AUTO
now  REAL,AUTO
mx   REAL,AUTO
my   REAL,AUTO
vw   LONG,AUTO
vh   LONG,AUTO
  CODE
  vw = d2c_ViewW(%airXObj:Gpu)
  vh = d2c_ViewH(%airXObj:Gpu)
  mx = %airXObj:SpotX * vw
  my = %airXObj:SpotY * vh
  DO Air:GpuWas:%airXObj
  was = %airXObj:Zoom / 100
  now = was * (1 + %airXStep / 100)
  IF now > 64 THEN now = 64.
  %airXObj:PanX += mx / was - mx / now
  %airXObj:PanY += my / was - my / now
  %airXObj:Zoom = now * 100
  DO Air:Gpu:%airXObj

Air:GpuOut:%airXObj ROUTINE
  DATA
was  REAL,AUTO
now  REAL,AUTO
fit  REAL,AUTO
mx   REAL,AUTO
my   REAL,AUTO
vw   LONG,AUTO
vh   LONG,AUTO
iw   LONG,AUTO
ih   LONG,AUTO
  CODE
  vw = d2c_ViewW(%airXObj:Gpu)
  vh = d2c_ViewH(%airXObj:Gpu)
  mx = %airXObj:SpotX * vw
  my = %airXObj:SpotY * vh
  iw = d2c_ImageW(%airXObj:Gpu)
  ih = d2c_ImageH(%airXObj:Gpu)
  IF iw < 1 OR ih < 1 THEN EXIT.
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  DO Air:GpuWas:%airXObj
  was = %airXObj:Zoom / 100
  now = was / (1 + %airXStep / 100)
  IF now <= fit                                               ! all the way out = fit again
    DO Air:Fit:%airXObj
    EXIT
  END
  %airXObj:PanX += mx / was - mx / now
  %airXObj:PanY += my / was - my / now
  %airXObj:Zoom = now * 100
  DO Air:Gpu:%airXObj

Air:GpuWas:%airXObj ROUTINE
!  Zoom 0 means "fitted"; turn that into the percentage it is really showing
!  at, so a step can be taken from it.
  DATA
fit  REAL,AUTO
vw   LONG,AUTO
vh   LONG,AUTO
iw   LONG,AUTO
ih   LONG,AUTO
  CODE
  IF %airXObj:Zoom THEN EXIT.
  vw = d2c_ViewW(%airXObj:Gpu)
  vh = d2c_ViewH(%airXObj:Gpu)
  iw = d2c_ImageW(%airXObj:Gpu)
  ih = d2c_ImageH(%airXObj:Gpu)
  IF iw < 1 OR ih < 1
    %airXObj:Zoom = 100
    EXIT
  END
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  %airXObj:Zoom = fit * 100
#ENDIF
#ENDIF
#IF(%airXOpen)

Air:Open:%airXObj ROUTINE
!  Whichever picture the user wants.
  DATA
pick CSTRING(261)
  CODE
  pick = %airXObj:Path
  IF ~FILEDIALOG('Open a picture',pick,AirImg_Filter(),FILE:KeepDir + FILE:LongName) THEN EXIT.
  %airXObj:Path = pick
  IF AirImg_LoadPath(%airXObj,%airXObj:Path)
    DO Air:Fresh:%airXObj
  END
  DO Air:Show:%airXObj
#ENDIF
#IF(%airXSave)

Air:Save:%airXObj ROUTINE
!  The format follows the name the user types: .png .jpg .gif .bmp .tif .tga
!  .pcx .ppm and .qoi are all written by the class.
  DATA
pick CSTRING(261)
  CODE
  IF ~%airXObj.Ok() THEN EXIT.
  pick = %airXObj:Path
  IF ~FILEDIALOG('Save a copy',pick,AirImg_Filter(),FILE:Save + FILE:KeepDir + FILE:LongName) THEN EXIT.
  IF ~%airXObj.SaveFile(pick)
    MESSAGE('That picture could not be written.||' & pick,'Save a copy',ICON:Exclamation)
  END
#ENDIF
#IF(%airXMenu)

Air:Menu:%airXObj ROUTINE
!  The menu is built at generate time out of the boxes the developer ticked, so
!  the numbers below always line up with the lines that are actually on it.
  CASE POPUP('%airMenuTxt')
#IF(%airItemOpen)
  OF %airItemOpen
    DO Air:Open:%airXObj
#ENDIF
#IF(%airItemIn)
  OF %airItemIn
    DO Air:In:%airXObj
  OF %airItemOut
    DO Air:Out:%airXObj
  OF %airItem100
    %airXObj:Zoom = 100
    %airXObj:PanX = 0
    %airXObj:PanY = 0
    DO Air:Show:%airXObj
  OF %airItemFit
    DO Air:Fit:%airXObj
#ENDIF
#IF(%airItemLeft)
  OF %airItemLeft
    %airXObj.RotateLeft()
    DO Air:Show:%airXObj
  OF %airItemRight
    %airXObj.RotateRight()
    DO Air:Show:%airXObj
#ENDIF
#IF(%airItemNext)
  OF %airItemNext
    IF %airXObj.Frames() > 1
      %airXObj:Frame += 1
      IF %airXObj:Frame > %airXObj.Frames() THEN %airXObj:Frame = 1.
      DO Air:Frame:%airXObj
    END
  OF %airItemPrev
    IF %airXObj.Frames() > 1
      %airXObj:Frame -= 1
      IF %airXObj:Frame < 1 THEN %airXObj:Frame = %airXObj.Frames().
      DO Air:Frame:%airXObj
    END
#ENDIF
#IF(%airItemSave)
  OF %airItemSave
    DO Air:Save:%airXObj
#ENDIF
  OF %airItemInfo
    IF %airXObj.Ok()
      MESSAGE(%airXObj.Describe() & '||' & %airXObj:Path,'Picture',ICON:Asterisk)
    ELSE
      MESSAGE('There is no picture on this canvas.','Picture',ICON:Asterisk)
    END
  END
#ENDIF
#!-----------------------------------------------------------------------------
#!  End of allImageRead template set
#!-----------------------------------------------------------------------------
