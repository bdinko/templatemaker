  MEMBER
! ============================================================================
!  YuruClass implementation - see YuruClass.INC for the overview.
!  Store this file in ANSI/CRLF (not UTF-8, not LF-only).
! ============================================================================

  PRAGMA('compile(yurucanvas.c)')                            ! Clarion's own C compiler builds the Direct2D shim

  MAP
MyAtan2  PROCEDURE(REAL pY,REAL pX),REAL                     ! two-arg arctangent (radians)
ModI     PROCEDURE(LONG pA,LONG pB),LONG                     ! integer modulo (Clarion has no %)
!   -- Direct2D direct-to-window shim (yuru_d2d_* -> yurucanvas.c) -----------
    MODULE('yurucanvas.c')
yuru_d2d_init         PROCEDURE(),LONG,NAME('_yuru_d2d_init')
yuru_d2d_makechild    PROCEDURE(LONG,LONG,LONG,LONG,LONG),LONG,NAME('_yuru_d2d_make_child')
yuru_d2d_movechild    PROCEDURE(LONG,LONG,LONG,LONG,LONG),NAME('_yuru_d2d_move_child')
yuru_d2d_resize       PROCEDURE(LONG,LONG,LONG),NAME('_yuru_d2d_resize')
yuru_d2d_destroychild PROCEDURE(LONG),NAME('_yuru_d2d_destroy_child')
yuru_d2d_beginhwnd    PROCEDURE(LONG,LONG,LONG),LONG,NAME('_yuru_d2d_begin_hwnd')
yuru_native_frame     PROCEDURE(LONG,REAL,LONG,LONG,LONG,LONG,LONG),NAME('_yuru_native_frame') ! compute a whole frame in native C
yuru_d2d_blitnative   PROCEDURE(LONG,REAL,REAL,REAL,REAL),NAME('_yuru_d2d_blit_native')         ! blit that frame to the GPU
yuru_d2d_present      PROCEDURE(LONG),NAME('_yuru_d2d_present')
yuru_d2d_end          PROCEDURE(LONG),NAME('_yuru_d2d_end')
    END
  END

  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('YuruClass.INC'),ONCE

YPI      EQUATE(3.14159265358979)
CanW     EQUATE(400)                                          ! internal bitmap is 400 x 400 px
NBytes   EQUATE(480000)                                       ! 400 * 400 * 3 (24-bit, no row pad)

! -- module-static scratch, shared across instances (rendering is synchronous:
!    each Paint fully renders then writes its file before returning) -----------
Pixels   STRING(NBytes)                                       ! the BGR pixel buffer (1-based)
CurFile  STRING(261)                                          ! the file BmpOut points at right now
HdrSet   BYTE                                                 ! constant BMP header fields written yet?

! -- the output .bmp, written whole each frame via the raw DOS driver ---------
BmpOut   FILE,DRIVER('DOS'),NAME(CurFile),CREATE,PRE(BO),THREAD
Rec        RECORD
fType        USHORT                                           ! 'BM' = 19778
fSize        ULONG                                            ! total file size
fRes         ULONG
fOff         ULONG                                            ! 54 = pixel data offset
iSize        ULONG                                            ! 40 (info header size)
iWidth       LONG                                             ! 400
iHeight      LONG                                             ! 400 (positive = bottom-up)
iPlanes      USHORT                                           ! 1
iBitCt       USHORT                                           ! 24
iComp        ULONG                                            ! 0 = BI_RGB
iImgSz       ULONG                                            ! 480000
iXppm        LONG
iYppm        LONG
iClrU        ULONG
iClrI        ULONG
Bits         STRING(NBytes)
           END
         END

! ============================================================================
YuruClass.Construct  PROCEDURE
  CODE
  SELF.Preset     = Yuru:Ribbon
  SELF.Speed      = 1.0
  SELF.InkColor   = 00FFFFFFH                                 ! white glow, like the p5.js originals
  SELF.BackGray   = 9                                         ! near-black (bg = 9,9,9)
  SELF.Brightness = 55                                        ! additive brightness per point
  SELF.tVal       = 0

! ---------------------------------------------------------------------------
YuruClass.Destruct   PROCEDURE
  CODE
  IF SELF.HCanvas  THEN yuru_d2d_end(SELF.HCanvas)         ; SELF.HCanvas  = 0.  ! release the Direct2D target
  IF SELF.HwndHost THEN yuru_d2d_destroychild(SELF.HwndHost); SELF.HwndHost = 0.  ! drop the child host window
  IF SELF.Inited                                              ! best-effort temp cleanup
    CurFile = SELF.FileA ; REMOVE(BmpOut)
    CurFile = SELF.FileB ; REMOVE(BmpOut)
  END

! ---------------------------------------------------------------------------
YuruClass.Init       PROCEDURE(SIGNED pImageFeq)
  CODE
  SELF.Feq   = pImageFeq
  SELF.FileA = 'yuru' & pImageFeq & 'a.bmp'                   ! unique per control -> no cross-object file locks
  SELF.FileB = 'yuru' & pImageFeq & 'b.bmp'
  SELF.Inited = 1
  IF ~HdrSet                                                  ! constant BMP header fields, once per program
    BO:fType  = 19778
    BO:fSize  = 54 + NBytes
    BO:fRes   = 0
    BO:fOff   = 54
    BO:iSize  = 40
    BO:iWidth = CanW
    BO:iHeight= CanW
    BO:iPlanes= 1
    BO:iBitCt = 24
    BO:iComp  = 0
    BO:iImgSz = NBytes
    BO:iXppm  = 2835
    BO:iYppm  = 2835
    BO:iClrU  = 0
    BO:iClrI  = 0
    HdrSet = 1
  END

! ---------------------------------------------------------------------------
!  Switch backend at runtime. Going back to the BMP-file path tears down the
!  Direct2D host so the underlying IMAGE control shows again; going to Direct2D
!  just flags it - EnsureHwnd builds the host lazily on the next Paint.
YuruClass.SetBackend PROCEDURE(BYTE pBackend)
  CODE
  IF pBackend = SELF.Backend THEN RETURN.
  IF SELF.HCanvas  THEN yuru_d2d_end(SELF.HCanvas)          ; SELF.HCanvas  = 0.
  IF SELF.HwndHost THEN yuru_d2d_destroychild(SELF.HwndHost); SELF.HwndHost = 0.
  SELF.D2Ready  = 0
  SELF.D2Failed = 0
  SELF.Backend  = pBackend

! ---------------------------------------------------------------------------
YuruClass.Restart    PROCEDURE
  CODE
  SELF.tVal = 0

! ---------------------------------------------------------------------------
!  Each sketch keeps its own natural time step (from the p5.js originals).
YuruClass.Dt         PROCEDURE()!,REAL
  CODE
  CASE SELF.Preset
  OF Yuru:Ribbon   ; RETURN YPI/240
  OF Yuru:Seashell ; RETURN YPI/45
  OF Yuru:Nebula   ; RETURN YPI/240
  OF Yuru:Lattice  ; RETURN YPI/60
  OF Yuru:Reeds    ; RETURN YPI/90
  OF Yuru:Plume    ; RETURN YPI/15
  END
  RETURN YPI/120

! ---------------------------------------------------------------------------
YuruClass.NextFrame  PROCEDURE
  CODE
  SELF.tVal += SELF.Dt() * SELF.Speed
  SELF.Paint()

! ---------------------------------------------------------------------------
YuruClass.RecalcInc  PROCEDURE
R  LONG
G  LONG
B  LONG
  CODE
  R = BAND(SELF.InkColor, 0FFH)                               ! Clarion color = 00BBGGRR
  G = BAND(BSHIFT(SELF.InkColor, -8), 0FFH)
  B = BAND(BSHIFT(SELF.InkColor, -16), 0FFH)
  SELF.IncR = SELF.Brightness * R / 255
  SELF.IncG = SELF.Brightness * G / 255
  SELF.IncB = SELF.Brightness * B / 255
  IF SELF.IncR = 0 AND SELF.IncG = 0 AND SELF.IncB = 0        ! never fully invisible
    SELF.IncR = 1 ; SELF.IncG = 1 ; SELF.IncB = 1
  END

! ---------------------------------------------------------------------------
!  Fill the entire pixel buffer with the flat background grey. NB: Clarion's
!  ALL(CHR(g)) only produces 255 bytes, and assigning it to the 480,000-byte
!  buffer space-pads the rest (byte 32) - so a naive fill leaves the background
!  at 32, NOT BackGray. Double the 255-byte seed out to cover the whole buffer.
YuruClass.ClearBuf   PROCEDURE
len  LONG
cp   LONG
  CODE
  Pixels = ALL(CHR(SELF.BackGray))                            ! seeds the first 255 bytes
  len = 255
  LOOP WHILE len < NBytes
    cp = len                                                  ! copy the correct prefix onto itself, doubling each pass
    IF len + cp > NBytes THEN cp = NBytes - len.
    Pixels[len+1 : len+cp] = Pixels[1 : cp]
    len += cp
  END

! ---------------------------------------------------------------------------
!  Lazily create the Direct2D child host window over the IMAGE control and its
!  render target. Called from Paint on the first Direct2D frame - by then the
!  window (and control) is realized, so PROP:Xpos/Ypos/Width/Height are valid.
!  Any failure sets D2Failed so we stay on the BMP-file path forever after.
YuruClass.EnsureHwnd PROCEDURE
wx   LONG
wy   LONG
ww   LONG
wh   LONG
save LONG
  CODE
  IF SELF.D2Ready OR SELF.D2Failed THEN RETURN.
  IF ~SELF.Feq THEN RETURN.
  IF yuru_d2d_init() < 0 THEN SELF.D2Failed = 1 ; RETURN.     ! no Direct2D on this box -> fall back
  save = 0{PROP:Pixels}                                       ! read the control rect in PIXELS
  0{PROP:Pixels} = 1
  wx = SELF.Feq{PROP:Xpos} ; wy = SELF.Feq{PROP:Ypos}
  ww = SELF.Feq{PROP:Width}; wh = SELF.Feq{PROP:Height}
  0{PROP:Pixels} = save
  IF ww < 4 OR wh < 4 THEN RETURN.                            ! control not realized yet - retry next frame
  SELF.HwndHost = yuru_d2d_makechild(0{PROP:Handle}, wx, wy, ww, wh)
  IF ~SELF.HwndHost THEN SELF.D2Failed = 1 ; RETURN.
  SELF.HCanvas = yuru_d2d_beginhwnd(SELF.HwndHost, ww, wh)
  IF ~SELF.HCanvas
    yuru_d2d_destroychild(SELF.HwndHost) ; SELF.HwndHost = 0
    SELF.D2Failed = 1 ; RETURN
  END
  SELF.HostX = wx ; SELF.HostY = wy
  SELF.HostW = ww ; SELF.HostH = wh
  SELF.D2Ready = 1

! ---------------------------------------------------------------------------
!  Follow the IMAGE control when the window is resized (or the control is moved
!  by anchoring). EnsureHwnd sizes the Direct2D host ONCE; without this the host
!  window and its GPU back buffer stay locked at that first size, so a grown
!  control just shows the animation boxed in its original rectangle. Re-read the
!  control's pixel rect each frame and, only when it actually changed, move the
!  child host and resize the render target to match. Cheap enough per frame.
YuruClass.SyncSize   PROCEDURE
wx   LONG
wy   LONG
ww   LONG
wh   LONG
save LONG
  CODE
  IF ~SELF.D2Ready THEN RETURN.
  save = 0{PROP:Pixels}                                       ! read the control rect in PIXELS
  0{PROP:Pixels} = 1
  wx = SELF.Feq{PROP:Xpos} ; wy = SELF.Feq{PROP:Ypos}
  ww = SELF.Feq{PROP:Width}; wh = SELF.Feq{PROP:Height}
  0{PROP:Pixels} = save
  IF ww < 4 OR wh < 4 THEN RETURN.                            ! control not realized - leave the host as-is
  IF wx = SELF.HostX AND wy = SELF.HostY |
     AND ww = SELF.HostW AND wh = SELF.HostH THEN RETURN.     ! nothing moved or resized
  yuru_d2d_movechild(SELF.HwndHost, wx, wy, ww, wh)           ! reposition/resize the child host window
  IF ww <> SELF.HostW OR wh <> SELF.HostH
    yuru_d2d_resize(SELF.HCanvas, ww, wh)                     ! resize the GPU back buffer to match (skip on pure moves)
  END
  SELF.HostX = wx ; SELF.HostY = wy
  SELF.HostW = ww ; SELF.HostH = wh

! ---------------------------------------------------------------------------
YuruClass.Paint      PROCEDURE
  CODE
  IF ~SELF.Inited THEN RETURN.                                ! no control wired yet
  SELF.RecalcInc()

! ---- Direct2D DIRECT-TO-WINDOW: the WHOLE frame is computed in native C and
!      blitted straight to the GPU host - the slow Clarion particle loop below is
!      skipped entirely. This is the real speed win, not just dropping the file.
  IF SELF.Backend = Yuru:Direct2D AND ~SELF.D2Failed
    SELF.EnsureHwnd()
    IF SELF.D2Ready
      SELF.SyncSize()                                          ! follow window resizes/moves before drawing
      yuru_native_frame(SELF.Preset, SELF.tVal, SELF.IncR, SELF.IncG, SELF.IncB, SELF.BackGray, CanW)
      yuru_d2d_blitnative(SELF.HCanvas, 0, 0, SELF.HostW, SELF.HostH)
      yuru_d2d_present(SELF.HCanvas)                          ! flip to the screen, re-open for next frame
      RETURN
    END
  END

! ---- classic BMP-file path (default, and the fallback if Direct2D is unavailable)
  SELF.ClearBuf()                                             ! clear to the flat background (full buffer, not just 255 bytes)
  CASE SELF.Preset
  OF Yuru:Ribbon   ; SELF.Ribbon()
  OF Yuru:Seashell ; SELF.Seashell()
  OF Yuru:Nebula   ; SELF.Nebula()
  OF Yuru:Lattice  ; SELF.Lattice()
  OF Yuru:Reeds    ; SELF.Reeds()
  OF Yuru:Plume    ; SELF.Plume()
  ELSE             ; SELF.Ribbon()
  END

  SELF.Toggle = 1 - SELF.Toggle                              ! flip-flop the two temp files
  CurFile = CHOOSE(SELF.Toggle = 1, SELF.FileA, SELF.FileB)
  BO:Bits = Pixels
  CREATE(BmpOut)
  OPEN(BmpOut, 22H)                                          ! read/write, deny none
  IF ~ERRORCODE()
    ADD(BmpOut)
    CLOSE(BmpOut)
  END
  SELF.Feq{PROP:Text} = CurFile
  DISPLAY(SELF.Feq)

! ---------------------------------------------------------------------------
!  Write the buffer as it stands (the last rendered frame) to a named file.
YuruClass.SaveAs     PROCEDURE(STRING pFile)
  CODE
  CurFile = pFile
  BO:Bits = Pixels
  CREATE(BmpOut)
  OPEN(BmpOut, 22H)
  IF ~ERRORCODE()
    ADD(BmpOut)
    CLOSE(BmpOut)
  END

! ---------------------------------------------------------------------------
!  Plot one point additively at (pX,pY). Off-canvas points are ignored.
YuruClass.Plot       PROCEDURE(REAL pX,REAL pY)
ix   LONG
iy   LONG
rr   LONG
ofs  LONG
vv   LONG
  CODE
  ix = pX                                                    ! REAL -> LONG rounds
  iy = pY
  IF ix < 0 OR ix > CanW-1 OR iy < 0 OR iy > CanW-1 THEN RETURN.
  rr  = CanW - 1 - iy                                        ! BMP rows are bottom-up
  ofs = (rr * CanW + ix) * 3 + 1
  vv = VAL(Pixels[ofs])   + SELF.IncB ; IF vv > 255 THEN vv = 255. ; Pixels[ofs]   = CHR(vv)
  vv = VAL(Pixels[ofs+1]) + SELF.IncG ; IF vv > 255 THEN vv = 255. ; Pixels[ofs+1] = CHR(vv)
  vv = VAL(Pixels[ofs+2]) + SELF.IncR ; IF vv > 255 THEN vv = 255. ; Pixels[ofs+2] = CHR(vv)

! ===========================================================================
!  The six point sketches. Ported faithfully from the p5.js one-liners; the
!  local scratch vars mirror the original single-letter names.
! ===========================================================================
YuruClass.Ribbon     PROCEDURE
i    LONG
yY   REAL
kK   REAL
eE   REAL
dD   REAL
qQ   REAL
cC   REAL
t    REAL
  CODE
  t = SELF.tVal
  LOOP i = 9999 TO 0 BY -1
    yY = i / 235
    kK = (4 + SIN(yY*2 - t)*3) * COS(i/29)
    IF ABS(kK) < 0.0001 THEN kK = 0.0001.                    ! guard the 0.3/k term
    eE = yY/8 - 13
    dD = SQRT(kK*kK + eE*eE)
    qQ = 3*SIN(kK*2) + 0.3/kK + SIN(yY/25)*kK*(9 + 4*SIN(eE*9 - dD*3 + t*2))
    cC = dD - t
    SELF.Plot(qQ + 30*COS(cC) + 200, qQ*SIN(cC) + dD*39 - 220)
  END

! ---------------------------------------------------------------------------
YuruClass.Seashell   PROCEDURE
i    LONG
xX   REAL
yY   REAL
kK   REAL
eE   REAL
dD   REAL
qQ   REAL
cC   REAL
t    REAL
  CODE
  t = SELF.tVal
  LOOP i = 9999 TO 0 BY -1
    xX = ModI(i, 200)
    yY = i / 55
    kK = 9*COS(xX/8)
    eE = yY/8 - 12.5
    dD = (kK*kK + eE*eE)/99 + SIN(t)/6 + 0.5                 ! mag^2/99 + ...
    qQ = 99 - eE*SIN(MyAtan2(kK,eE)*7)/dD + kK*(3 + COS(dD*dD - t)*2)
    cC = dD/2 + eE/69 - t/16
    SELF.Plot(qQ*SIN(cC) + 200, (qQ + 19*dD)*COS(cC) + 200)
  END

! ---------------------------------------------------------------------------
YuruClass.Nebula     PROCEDURE
i    LONG
xX   REAL
yY   REAL
kK   REAL
eE   REAL
dD   REAL
qQ   REAL
cC   REAL
t    REAL
  CODE
  t = SELF.tVal
  LOOP i = 9999 TO 0 BY -1
    xX = i
    yY = i / 41
    kK = 5*COS(xX/19)*COS(yY/30)
    eE = yY/8 - 12
    dD = (kK*kK + eE*eE)/59 + 2                              ! mag^2/59 + 2
    qQ = 4*SIN(MyAtan2(kK,eE)*9) + 9*SIN(dD - t) - kK/dD*(9 + SIN(dD*9 - t*16)*3)
    cC = dD*dD/7 - t
    SELF.Plot(qQ + 50*COS(cC) + 200, qQ*SIN(cC) + dD*45 - 9)
  END

! ---------------------------------------------------------------------------
YuruClass.Lattice    PROCEDURE
i    LONG
yY   REAL
kK   REAL
eE   REAL
dD   REAL
qQ   REAL
cC   REAL
t    REAL
  CODE
  t = SELF.tVal
  LOOP i = 29999 TO 0 BY -1
    yY = i / 799
    kK = 5*COS(i/48)
    eE = 5*COS(yY/9)
    dD = SQRT(kK*kK + eE*eE) / (6 + ModI(i,4))
    dD = dD*dD*dD*dD + 4                                     ! ( ... )^4 + 4
    qQ = kK*(3 + eE/2*SIN(dD*8 + kK/9 - t)) - 3*SIN(kK*dD/3) + (BAND(i,1)+1)*80
    cC = dD - t/9 + ModI(i,5)
    SELF.Plot(qQ*SIN(cC) + 200, qQ*COS(cC - ModI(i,2) + ModI(i,5)*3 + 7) + 200)
  END

! ---------------------------------------------------------------------------
YuruClass.Reeds      PROCEDURE
i    LONG
yY   REAL
kK   REAL
eE   REAL
dD   REAL
qQ   REAL
cC   REAL
t    REAL
  CODE
  t = SELF.tVal
  LOOP i = 9999 TO 0 BY -1
    yY = i / 790
    IF yY < 5
      kK = (6 + SIN(BXOR(INT(yY),1))*6) * COS(i + t/4)
    ELSE
      kK = (4 + COS(yY)) * COS(i + t/4)
    END
    eE = yY/3 - 13
    dD = SQRT(kK*kK + eE*eE) + SIN(eE/4 - t)/3
    qQ = yY*kK/5 * (2 + SIN(dD*2 + yY - t*4))
    cC = dD/3 - t/2 + ModI(i,2)
    SELF.Plot(qQ + 90*COS(cC) + 200, qQ*SIN(cC) + dD*29 - 170)
  END

! ---------------------------------------------------------------------------
YuruClass.Plume      PROCEDURE
i    LONG
xX   REAL
yY   REAL
kK   REAL
eE   REAL
dD   REAL
qQ   REAL
cC   REAL
t    REAL
  CODE
  t = SELF.tVal
  LOOP i = 9999 TO 0 BY -1
    xX = i
    yY = i / 235
    kK = 4*COS(xX/29)
    eE = yY/7 - 13
    dD = SQRT(kK*kK + eE*eE)
    qQ = 3*SIN(MyAtan2(kK,eE)*19) + SIN(yY/19)*kK*(9 + 2*SIN(eE*9 - dD*3 + t/4))
    cC = dD - t/8
    SELF.Plot(qQ + 60*COS(cC) + 200, qQ*SIN(cC) + dD*39 - 195)
  END

! ===========================================================================
!  Two small helpers Clarion lacks natively.
! ===========================================================================
MyAtan2  PROCEDURE(REAL pY,REAL pX)!,REAL
  CODE
  IF pX > 0
    RETURN ATAN(pY/pX)
  ELSIF pX < 0
    IF pY >= 0
      RETURN ATAN(pY/pX) + YPI
    ELSE
      RETURN ATAN(pY/pX) - YPI
    END
  ELSE
    IF pY > 0 THEN RETURN YPI/2.
    IF pY < 0 THEN RETURN -(YPI/2).
    RETURN 0
  END

! ---------------------------------------------------------------------------
ModI     PROCEDURE(LONG pA,LONG pB)!,LONG
  CODE
  RETURN pA - INT(pA/pB) * pB
