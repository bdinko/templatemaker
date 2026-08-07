  PROGRAM
  INCLUDE('ImageClass.INC'),ONCE
AirImg:Secs          EQUATE(20)
   MAP
!--- Application Global and Exported Procedure Definitions --------------------------------------------
         MODULE('win32')
     airApi_TempPath(ULONG,*CSTRING),ULONG,RAW,PASCAL,PROC,NAME('GetTempPathA')
     airApi_CreateFile(LONG,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,NAME('CreateFileA')
     airApi_WriteFile(LONG,LONG,ULONG,LONG,LONG),LONG,PASCAL,PROC,NAME('WriteFile')
     airApi_CloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
     airApi_CreateProcess(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
     airApi_WaitObject(LONG,ULONG),LONG,PASCAL,PROC,NAME('WaitForSingleObject')
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
   END
  INCLUDE('EQUATES.CLW'),ONCE

RptPic                ImageClass                              ! the picture, exactly as it was read
RptPic:Ref            &STRING                                 ! a BLOB, while it is being handed over
RptPic:Sz             LONG                                    ! how many bytes that was
RptPic:Path           CSTRING(261)                            ! what is on the canvas now
RptPic:Frame          LONG(1)                                 ! which frame of a multi-frame picture
RptPic:Pool           LONG                                    ! which working name this record used
Loc:File             CSTRING(261)

Report REPORT,AT(1000,1000,6000,7000),THOUS,PRE(RPT)
Detail  DETAIL,AT(,,6000,2000)
          IMAGE,AT(200,100,2000,1500),USE(?AirCanvas)
        END
      END
  CODE
  Loc:File = 'nothing.png'
  OPEN(Report)
  DO Air:Band:RptPic
  PRINT(RPT:Detail)
  CLOSE(Report)
  RETURN

Air:Band:RptPic ROUTINE
  DATA
fname CSTRING(261)
  CODE
  RptPic:Path = CLIP(Loc:File)
  AirImg_LoadPath(RptPic,RptPic:Path)
  RptPic:Pool += 1
  IF RptPic:Pool > 8 THEN RptPic:Pool = 1.
  fname = AirImg_Render(RptPic,600,450,Img:Cover, |
                       RptPic.ArgbOf(16777215),'PhotoReport_c1' & '_' & RptPic:Pool)
  SETTARGET(Report)
  ?AirCanvas{PROP:Text} = fname                                  ! blank clears the frame
  SETTARGET()

AirImg_Temp PROCEDURE(STRING pKey,STRING pExt)
tdir CSTRING(261)
n    ULONG,AUTO
  CODE
  tdir = ''
  n = airApi_TempPath(255,tdir)
  IF ~n OR n > 254 THEN tdir = '.\' .
  IF tdir[LEN(tdir) : LEN(tdir)] <> '\' THEN tdir = CLIP(tdir) & '\' .
  RETURN CLIP(tdir) & 'air_' & CLIP(pKey) & CLIP(pExt)

!  Bytes onto disk. Returns 1 when every byte arrived.
AirImg_PutBytes PROCEDURE(*STRING pData,LONG pLen,STRING pPath)
GENERIC_WRITE    EQUATE(40000000h)
CREATE_ALWAYS    EQUATE(2)
FILE_ATTR_NORMAL EQUATE(00000080h)
INVALID_HANDLE   EQUATE(-1)
fname CSTRING(261)
h     LONG,AUTO
wrote ULONG,AUTO
ok    LONG,AUTO
  CODE
  IF pLen < 1 THEN RETURN 0.
  fname = CLIP(pPath)
  wrote = 0
  h = airApi_CreateFile(ADDRESS(fname),GENERIC_WRITE,0,0,CREATE_ALWAYS,FILE_ATTR_NORMAL,0)
  IF h = INVALID_HANDLE OR ~h THEN RETURN 0.
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
AirImg_LoadBytes PROCEDURE(ImageClass pImg,*STRING pData,LONG pLen,STRING pKey)
fname CSTRING(261)
  CODE
  IF pLen < 1
    pImg.Kill()
    RETURN 0
  END
  fname = AirImg_Temp(pKey,'.tmp')
  IF ~AirImg_PutBytes(pData,pLen,fname)
    pImg.Kill()
    RETURN 0
  END
  RETURN pImg.LoadFile(fname)

!  A picture that arrived as text. Standard and URL-safe alphabets, any amount
!  of white space, and a leading data: URI is stepped over.
AirImg_LoadB64 PROCEDURE(ImageClass pImg,STRING pB64,STRING pKey)
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
  ok = AirImg_LoadBytes(pImg,out,o,pKey)
  DISPOSE(out)
  RETURN ok

!  A picture on the internet. curl.exe is run HIDDEN and SYNCHRONOUSLY -
!  CreateProcessA with CREATE_NO_WINDOW plus STARTF_USESHOWWINDOW / SW_HIDE,
!  then WaitForSingleObject. curl ships with Windows 10 and 11 in System32.
AirImg_LoadUrl PROCEDURE(ImageClass pImg,STRING pUrl,STRING pKey,LONG pSeconds)
STARTF_USESHOWWINDOW EQUATE(00000001h)
SW_HIDE              EQUATE(0)
CREATE_NO_WINDOW     EQUATE(08000000h)
INFINITE             EQUATE(0FFFFFFFFh)
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
  fname = AirImg_Temp(pKey,'.dl')
  REMOVE(fname)
!  -s silent, -L follow redirects, --max-time so a hung server cannot hold the
!  program up for ever, -o writes the body. <34> is a double quote: Windows
!  argument quoting wants double quotes, not apostrophes.
  cmd = 'curl -s -L --max-time ' & secs & |
        ' -o <34>' & CLIP(fname) & '<34> <34>' & CLIP(pUrl) & '<34>'
  si.cb      = SIZE(si)
  si.dwFlags = STARTF_USESHOWWINDOW
  si.wShow   = SW_HIDE
  IF ~airApi_CreateProcess(0,ADDRESS(cmd),0,0,0,CREATE_NO_WINDOW,0,0,ADDRESS(si),ADDRESS(pi))
    pImg.Kill()                                               ! curl.exe is not there
    RETURN 0
  END
  airApi_WaitObject(pi.hProc,INFINITE)
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
AirImg_Render PROCEDURE(ImageClass pImg,LONG pW,LONG pH,LONG pMode,ULONG pBack,STRING pKey)
cv   ImageClass
fname CSTRING(261)
  CODE
  IF ~pImg.Ok() OR pW < 4 OR pH < 4 THEN RETURN ''.
  IF ~pImg.CloneInto(cv) THEN RETURN ''.
  IF pMode >= 0 THEN cv.Fit(pW,pH,pMode,pBack).
  fname = AirImg_Temp(pKey,'.png')
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
