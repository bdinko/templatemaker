

   MEMBER('airwin.clw')                                    ! This is a MEMBER module


   INCLUDE('ABTOOLBA.INC'),ONCE
   INCLUDE('ABWINDOW.INC'),ONCE

                     MAP
                       INCLUDE('AIRWIN001.INC'),ONCE        !Local module procedure declarations
                     END


!!! <summary>
!!! Generated from procedure template - Window
!!! Window
!!! </summary>
Main PROCEDURE 

Loc:Url              CSTRING(256)
Loc:B64              STRING(4096)
Loc:File             CSTRING(261)
QuickWindow          WINDOW('allImageRead test'),AT(,,340,300),RESIZE,GRAY,MAX,STATUS(-1),SYSTEM,IMM
                       IMAGE,AT(8,8,320,130),USE(?Pic1)
                       IMAGE,AT(8,150,320,130),USE(?AirCanvas)
                       BUTTON('|<<'),AT(8,284,14,12),USE(?AirFrmFirst)
                       BUTTON('<<'),AT(24,284,14,12),USE(?AirFrmPrev)
                       STRING('- / -'),AT(40,285,46,10),USE(?AirFrmText),CENTER
                       BUTTON('>'),AT(88,284,14,12),USE(?AirFrmNext)
                       BUTTON('>|'),AT(104,284,14,12),USE(?AirFrmLast)
                       BUTTON('Play'),AT(120,284,26,12),USE(?AirFrmPlay)
                     END

PicA                ImageClass                              ! the picture, exactly as it was read
PicA:Ref            &STRING                                 ! a BLOB, while it is being handed over
PicA:Sz             LONG                                    ! how many bytes that was
PicA:Path           CSTRING(261)                            ! what is on the canvas now
PicA:Frame          LONG(1)                                 ! which frame of a multi-frame picture
PicA:Cv             ImageClass                              ! the canvas: what the control is showing
PicA:Zoom           LONG                                    ! 0 = fit the frame, else per cent
PicA:PanX           LONG                                    ! the viewport, in picture pixels
PicA:PanY           LONG
PicA:Rgn            SIGNED                                  ! the region that takes the mouse
PicA:StepX          LONG                                    ! one keyboard pan step, -1 0 or 1
PicA:StepY          LONG
PicA:SpotX          REAL                                    ! where to zoom about, across the canvas
PicA:SpotY          REAL                                    !   0 = left/top, 1 = right/bottom
PicA:Over           BYTE                                    ! is the pointer on this canvas?
PicA:Gpu            LONG                                    ! the GPU canvas, 0 = drawing on the processor
PicA:Bmp            CSTRING(261)                            ! what was handed to the graphics card
PicA:Hooked         BYTE                                    ! this canvas took the window procedure
PicA:Barred         BYTE                                    ! and its control's, for the scrollbars
PicA:Drag           BYTE
PicA:PanX0          LONG                                    ! the pan when the drag began
PicA:PanY0          LONG
PicA:MX             SIGNED                                  ! the pointer, in PIXELS
PicA:MY             SIGNED
PicA:SavePx         LONG                                    ! the window's units, while we borrow them
PicA:DragX          SIGNED
PicA:DragY          SIGNED
Air:Redraw:PicA     EQUATE(EVENT:User + 260 + 2)
myQR:Last            CSTRING(256)                          ! last value actually rendered
myQR:Cur             CSTRING(256)                          ! value read this pass
myQR:Ecc             STRING(1)                             ! 1-letter ECC (set at gen time)
PicB                ImageClass                              ! the picture, exactly as it was read
PicB:Ref            &STRING                                 ! a BLOB, while it is being handed over
PicB:Sz             LONG                                    ! how many bytes that was
PicB:Path           CSTRING(261)                            ! what is on the canvas now
PicB:Frame          LONG(1)                                 ! which frame of a multi-frame picture
PicB:Cv             ImageClass                              ! the canvas: what the control is showing
PicB:Zoom           LONG                                    ! 0 = fit the frame, else per cent
PicB:PanX           LONG                                    ! the viewport, in picture pixels
PicB:PanY           LONG
PicB:Rgn            SIGNED                                  ! the region that takes the mouse
PicB:StepX          LONG                                    ! one keyboard pan step, -1 0 or 1
PicB:StepY          LONG
PicB:SpotX          REAL                                    ! where to zoom about, across the canvas
PicB:SpotY          REAL                                    !   0 = left/top, 1 = right/bottom
PicB:Over           BYTE                                    ! is the pointer on this canvas?
PicB:Gpu            LONG                                    ! the GPU canvas, 0 = drawing on the processor
PicB:Bmp            CSTRING(261)                            ! what was handed to the graphics card
PicB:Hooked         BYTE                                    ! this canvas took the window procedure
PicB:Barred         BYTE                                    ! and its control's, for the scrollbars
PicB:Drag           BYTE
PicB:PanX0          LONG                                    ! the pan when the drag began
PicB:PanY0          LONG
PicB:MX             SIGNED                                  ! the pointer, in PIXELS
PicB:MY             SIGNED
PicB:SavePx         LONG                                    ! the window's units, while we borrow them
PicB:DragX          SIGNED
PicB:DragY          SIGNED
Air:Redraw:PicB     EQUATE(EVENT:User + 220 + 1)
AirFrm4:Playing     BYTE                                    ! is the animation running?
AirFrm4:WasTimer    LONG                                    ! what PROP:Timer held before we borrowed it
ThisWindow           CLASS(WindowManager)
Init                   PROCEDURE(),BYTE,PROC,DERIVED
Kill                   PROCEDURE(),BYTE,PROC,DERIVED
TakeFieldEvent         PROCEDURE(),BYTE,PROC,DERIVED
TakeWindowEvent        PROCEDURE(),BYTE,PROC,DERIVED
                     END

Toolbar              ToolbarClass

  CODE
  GlobalResponse = ThisWindow.Run()                        ! Opens the window and starts an Accept Loop

!---------------------------------------------------------------------------
DefineListboxStyle ROUTINE
!|
!| This routine create all the styles to be shared in this window
!| It`s called after the window open
!|
!---------------------------------------------------------------------------
Air:Setup:PicA ROUTINE
!  The IMAGE control is only the paint surface. A REGION created over it takes
!  the mouse - the way Clarion's own ActiveImage class does it
!  (libsrc\win\ActiveImage.clw:303). A REGION has nothing of its own to draw,
!  so the picture underneath shows through untouched.
  IF ~PicA:Rgn
    PicA:Rgn = CREATE(0,CREATE:Region,?Pic1{PROP:Parent})
!  IMM, or the mouse never speaks. EVENT:MouseMove and EVENT:MouseUp are
!  documented as arriving "on a REGION with the IMM attribute" - without it a
!  region still gets MouseDown (it is a synonym for EVENT:Accepted) and then
!  nothing at all, so a drag begins and never moves. A region built at run time
!  has no attribute list to carry IMM, so it is set as a property here.
    PicA:Rgn{PROP:IMM} = 1
  END
  DO Air:Place:PicA
  UNHIDE(PicA:Rgn)
!  The scrollbars go on BEFORE the graphics card attaches: adding the styles
!  takes a slice off the client area, and the render target must be built for
!  what is left of it.
  IF AirImg_HookBars(PicA:Rgn{PROP:Handle})
    PicA:Barred = 1
  END
!  Hand the canvas to the graphics card. The REGION laid over the image owns a
!  real window, so Direct2D renders into THAT and Clarion keeps the rest of the
!  window to itself. If there is no Direct2D, or it will not attach, the canvas
!  quietly goes on drawing with the processor.
  IF ~PicA:Gpu AND d2c_Available()
    PicA:Gpu = d2c_Attach(PicA:Rgn{PROP:Handle})
  END
  IF PicA:Gpu
    HIDE(?Pic1)                                            ! the IMAGE control is not used now
  END
!  Take the mouse wheel off the window procedure. The first canvas on a window
!  does it; the rest ride along, because the event reaches all of them.
  IF AirImg_HookWheel(QuickWindow{PROP:Handle})                   ! the helper takes the address,
    PicA:Hooked = 1                                       !   never this module
  END
  ?Pic1{PROP:DropID,1}     = '~FILE'                       ! a file dragged out of Explorer
  PicA:Rgn{PROP:DropID,1} = '~FILE'
  PicA:Rgn{PROP:Alrt,255} = MouseRight
  PicA:Rgn{PROP:Alrt,254} = MouseLeft2
!  ALERT() adds to the window's alerted keys rather than claiming a numbered
!  slot, so it cannot tread on another template's alert. Ctrl+arrows, because
!  the bare arrows belong to whatever browse the window is carrying.
  ALERT(CtrlUp)
  ALERT(CtrlDown)
  ALERT(CtrlLeft)
  ALERT(CtrlRight)
  ALERT(CtrlHome)
  AirImg_LoadB64(PicA,Loc:B64,'Main_w2')
  PicA:Path = ''
  DO Air:Fresh:PicA
  POST(Air:Redraw:PicA)                                   ! first paint, once the window is up

Air:Place:PicA ROUTINE
!  Keep the region exactly over the image, however the resizer moves it.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~PicA:Rgn THEN EXIT.
  GETPOSITION(?Pic1,x,y,w,h)
  SETPOSITION(PicA:Rgn,x,y,w,h)

Air:Size:PicA ROUTINE
!  The canvas control moved or changed size, so the render target has to be
!  told; Direct2D will not notice on its own.
  IF PicA:Gpu
    d2c_Resize(PicA:Gpu)
  END

Air:Upload:PicA ROUTINE
!  Hand the graphics card the pixels the object is holding NOW. Called when a
!  new picture arrives and again whenever the frame changes - a zoom does not
!  need it, which is the whole point of the GPU path.
  IF PicA:Gpu
    IF ~PicA.Ok()
      d2c_Clear(PicA:Gpu)
    ELSIF PicA.CloneInto(PicA:Cv)
      PicA:Cv.Flatten(PicA.ArgbOf(16777215))
      PicA:Cv.BmpBits = 32
      PicA:Bmp = AirImg_Temp('Main_w2','.bmp')
      IF PicA:Cv.SaveFile(PicA:Bmp, Img:Bmp)
        d2c_LoadBmp(PicA:Gpu, PicA:Bmp)
      END
    END
  END

Air:Frame:PicA ROUTINE
!  Show whatever frame number is in <object>:Frame - a page of a TIFF, a frame
!  of an animated GIF, one size out of an .ico. The zoom and the pan are left
!  alone, so stepping through pages does not throw the view away.
  IF ~PicA.Ok() THEN EXIT.
  IF PicA:Frame < 1 THEN PicA:Frame = 1.
  IF PicA:Frame > PicA.Frames() THEN PicA:Frame = PicA.Frames().
  IF ~PicA.LoadFrame(PicA:Frame - 1) THEN EXIT.       ! the engine counts from zero
  DO Air:Upload:PicA
  DO Air:Show:PicA

Air:Fresh:PicA ROUTINE
!  A NEW picture has just landed in the object.
  DO Air:Upload:PicA
  PicA:Zoom = 0                                           ! back to fitting the frame
  PicA:PanX = 0
  PicA:PanY = 0
  ?Pic1{PROP:Tooltip} = PicA:Path
  IF PicA.Ok()
    0{PROP:StatusText,1} = PicA.Describe()
  ELSE
    0{PROP:StatusText,1} = ''
  END

Air:Show:PicA ROUTINE
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
!  On the graphics card a repaint is a zoom factor and an offset. Nothing is
!  resampled, nothing is written to disk, and the cost does not depend on how
!  big the picture is. Zoom 0 still means "fit the frame"; the factor for that
!  is worked out from the canvas and the picture.
  IF PicA:Gpu
    DO Air:Gpu:PicA
    EXIT
  END
  IF ~PicA.Ok()
    ?Pic1{PROP:Text} = ''
    DISPLAY(?Pic1)
    EXIT
  END
  IF ~PicA:Zoom
    PicA.Draw(QuickWindow,?Pic1,Img:Cover,PicA.ArgbOf(16777215))
    DO Air:Bars:PicA
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the frame, in real pixels
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  IF w < 4 OR h < 4 THEN EXIT.
!  CROP FIRST, then scale. Scaling the whole picture and keeping the sliver
!  that shows costs the whole picture: at 400 per cent a 2400x1800 photograph
!  becomes 9600x7200 - 69 million pixels resampled to fill a 620x460 hole, and
!  it gets four times worse each time you double the zoom. Cutting the source
!  rectangle out first makes the work depend on the SIZE OF THE FRAME instead,
!  whatever the picture and whatever the zoom. Measured on that photograph:
!  8.9 seconds a step becomes 52 milliseconds.
  iw = PicA.Wide()
  ih = PicA.High()
  IF iw < 1 OR ih < 1 THEN EXIT.
  zw = INT(iw * PicA:Zoom / 100)                          ! the picture at this zoom
  zh = INT(ih * PicA:Zoom / 100)
  cw = w                                                      ! the viewport, never bigger than the picture
  ch = h
  IF cw > zw THEN cw = zw.
  IF ch > zh THEN ch = zh.
  IF cw < 1 OR ch < 1 THEN EXIT.
  IF PicA:PanX > zw - cw THEN PicA:PanX = zw - cw.
  IF PicA:PanY > zh - ch THEN PicA:PanY = zh - ch.
  IF PicA:PanX < 0 THEN PicA:PanX = 0.
  IF PicA:PanY < 0 THEN PicA:PanY = 0.
  sx = INT(PicA:PanX * 100 / PicA:Zoom)               ! source pixel at the view's corner
  sy = INT(PicA:PanY * 100 / PicA:Zoom)
  sw = INT(cw * 100 / PicA:Zoom) + 2                      ! enough source to cover it, plus slack
  sh = INT(ch * 100 / PicA:Zoom) + 2
  IF sx + sw > iw THEN sw = iw - sx.
  IF sy + sh > ih THEN sh = ih - sy.
  IF sw < 1 OR sh < 1 THEN EXIT.
  IF ~PicA.CloneInto(PicA:Cv) THEN EXIT.
  PicA:Cv.Crop(sx,sy,sw,sh)                               ! just what shows
  PicA:Cv.Resize(INT(sw * PicA:Zoom / 100),           |
                     INT(sh * PicA:Zoom / 100),Img:Best)  ! and scale only that
!  The crop landed on a whole source pixel, which is up to one pixel adrift of
!  where the view really starts; take that back off the scaled piece so the
!  picture does not jump about as it is panned.
  PicA:Cv.Crop(PicA:PanX - INT(sx * PicA:Zoom / 100),             |
                   PicA:PanY - INT(sy * PicA:Zoom / 100),cw,ch)
  PicA:Cv.Fit(w,h,Img:Centered,PicA.ArgbOf(16777215))  ! pad out to the frame
  PicA:Cv.Draw(QuickWindow,?Pic1,-1)                       ! -1 = blit it as it is
  DO Air:Bars:PicA

Air:Gpu:PicA ROUTINE
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
  vw = d2c_ViewW(PicA:Gpu)
  vh = d2c_ViewH(PicA:Gpu)
  iw = d2c_ImageW(PicA:Gpu)
  ih = d2c_ImageH(PicA:Gpu)
  IF iw < 1 OR ih < 1 OR vw < 1 OR vh < 1
    d2c_SetView(PicA:Gpu, 1.0, 0, 0, PicA.ArgbOf(16777215), 1)
    EXIT
  END
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  IF ~PicA:Zoom
    z = fit                                                   ! 0 means fit the frame
    PicA:PanX = 0
    PicA:PanY = 0
  ELSE
    z = PicA:Zoom / 100
  END
  IF z < 0.001 THEN z = 0.001.
!  keep the view on the picture
  IF PicA:PanX > iw - (vw / z) THEN PicA:PanX = iw - (vw / z).
  IF PicA:PanY > ih - (vh / z) THEN PicA:PanY = ih - (vh / z).
  IF PicA:PanX < 0 THEN PicA:PanX = 0.
  IF PicA:PanY < 0 THEN PicA:PanY = 0.
  d2c_SetView(PicA:Gpu, z, PicA:PanX, PicA:PanY,                |
              PicA.ArgbOf(16777215), 1)
  DO Air:Bars:PicA

Air:Spot:PicA ROUTINE
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
  PicA:SpotX = 0.5
  PicA:SpotY = 0.5
  PicA:Over  = 0
  GETPOSITION(?Pic1,rx,ry,rw,rh)
  IF rw < 1 OR rh < 1 THEN EXIT.
  IF MOUSEX() < rx OR MOUSEX() > rx + rw THEN EXIT.
  IF MOUSEY() < ry OR MOUSEY() > ry + rh THEN EXIT.
  PicA:Over  = 1
  PicA:SpotX = (MOUSEX() - rx) / rw
  PicA:SpotY = (MOUSEY() - ry) / rh

Air:WheelIn:PicA ROUTINE
!  A wheel notch reaches EVERY canvas on the window, so only the one under the
!  pointer takes it. The menu calls Air:In directly and is not filtered.
  DO Air:Spot:PicA
  IF PicA:Over
    DO Air:In:PicA
  END

Air:WheelOut:PicA ROUTINE
  DO Air:Spot:PicA
  IF PicA:Over
    DO Air:Out:PicA
  END

Air:In:PicA ROUTINE
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
  IF ~PicA.Ok() THEN EXIT.
  DO Air:Spot:PicA
  IF PicA:Gpu
    DO Air:GpuIn:PicA
    EXIT
  END
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicA:Zoom
  IF ~was THEN was = AirImg_FitPct(PicA,w,h).
  now = was + 25
  IF now > 1600 THEN now = 1600.
  mx = PicA:SpotX * w
  my = PicA:SpotY * h
  PicA:PanX = INT((PicA:PanX + mx) * now / was - mx)
  PicA:PanY = INT((PicA:PanY + my) * now / was - my)
  PicA:Zoom = now
  DO Air:Show:PicA

Air:Out:PicA ROUTINE
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
mx     LONG,AUTO
my     LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicA.Ok() OR ~PicA:Zoom THEN EXIT.               ! already fitted
  DO Air:Spot:PicA
  IF PicA:Gpu
    DO Air:GpuOut:PicA
    EXIT
  END
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicA:Zoom
  now = was - 25
  IF now <= AirImg_FitPct(PicA,w,h)                        ! all the way out = fit the frame
    DO Air:Fit:PicA
    EXIT
  END
  mx = PicA:SpotX * w
  my = PicA:SpotY * h
  PicA:PanX = INT((PicA:PanX + mx) * now / was - mx)
  PicA:PanY = INT((PicA:PanY + my) * now / was - my)
  PicA:Zoom = now
  DO Air:Show:PicA

Air:PanBy:PicA ROUTINE
!  One keyboard step. There is nothing to pan when the picture is fitted, so
!  the keys are quiet then - the same rule the drag follows.
  DATA
w      LONG,AUTO
h      LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicA.Ok() OR ~PicA:Zoom THEN EXIT.
  IF PicA:Gpu
!  The GPU pans in IMAGE pixels. The frame shows ViewW/zoom of them, so a step
!  of PanStep per cent is ViewW * PanStep / Zoom - the hundreds cancel.
    PicA:PanX += PicA:StepX * d2c_ViewW(PicA:Gpu) *              |
                     15 / PicA:Zoom
    PicA:PanY += PicA:StepY * d2c_ViewH(PicA:Gpu) *              |
                     15 / PicA:Zoom
    DO Air:Gpu:PicA
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the processor pans in scaled pixels
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  PicA:PanX += INT(PicA:StepX * w * 15 / 100)
  PicA:PanY += INT(PicA:StepY * h * 15 / 100)
  DO Air:Show:PicA

Air:Bars:PicA ROUTINE
!  Tell the scrollbars how much picture there is and how much of it shows, in
!  whatever units this engine pans in. Windows hides a bar whose page covers
!  its whole range, so at "fit the frame" they take themselves away.
  DATA
tot  LONG,AUTO
page LONG,AUTO
w    LONG,AUTO
h    LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicA:Barred THEN EXIT.
  IF ~PicA.Ok() OR ~PicA:Zoom                         ! fitted: no bars
    AirImg_SetBar(PicA:Rgn{PROP:Handle},AirImg:SbHorz,0,1,1)
    AirImg_SetBar(PicA:Rgn{PROP:Handle},AirImg:SbVert,0,1,1)
    IF PicA:Gpu THEN d2c_Resize(PicA:Gpu).
    EXIT
  END
  IF PicA:Gpu                                             ! the GPU pans in image pixels
    tot  = d2c_ImageW(PicA:Gpu)
    page = INT(d2c_ViewW(PicA:Gpu) * 100 / PicA:Zoom)
    AirImg_SetBar(PicA:Rgn{PROP:Handle},AirImg:SbHorz,PicA:PanX,page,tot)
    tot  = d2c_ImageH(PicA:Gpu)
    page = INT(d2c_ViewH(PicA:Gpu) * 100 / PicA:Zoom)
    AirImg_SetBar(PicA:Rgn{PROP:Handle},AirImg:SbVert,PicA:PanY,page,tot)
    d2c_Resize(PicA:Gpu)
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the processor pans in scaled pixels
  0{PROP:Pixels} = 1
  w = ?Pic1{PROP:Width}
  h = ?Pic1{PROP:Height}
  0{PROP:Pixels} = savePx
  AirImg_SetBar(PicA:Rgn{PROP:Handle},AirImg:SbHorz,PicA:PanX,w,      |
                INT(PicA.Wide() * PicA:Zoom / 100))
  AirImg_SetBar(PicA:Rgn{PROP:Handle},AirImg:SbVert,PicA:PanY,h,      |
                INT(PicA.High() * PicA:Zoom / 100))

Air:Scrolled:PicA ROUTINE
!  A bar moved - on this canvas or on another one. Read our own two back; if
!  they have not moved there is nothing to do, which is what makes it safe to
!  send the one event to every canvas on the window.
  DATA
nx LONG,AUTO
ny LONG,AUTO
  CODE
  IF ~PicA:Barred OR ~PicA:Zoom THEN EXIT.
  nx = AirImg_BarPos(PicA:Rgn{PROP:Handle},AirImg:SbHorz)
  ny = AirImg_BarPos(PicA:Rgn{PROP:Handle},AirImg:SbVert)
  IF nx = PicA:PanX AND ny = PicA:PanY THEN EXIT.
  PicA:PanX = nx
  PicA:PanY = ny
  IF PicA:Gpu
    DO Air:Gpu:PicA
    EXIT
  END
  DO Air:Show:PicA

Air:Fit:PicA ROUTINE
  PicA:Zoom = 0
  PicA:PanX = 0
  PicA:PanY = 0
  DO Air:Show:PicA

Air:GpuIn:PicA ROUTINE
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
  vw = d2c_ViewW(PicA:Gpu)
  vh = d2c_ViewH(PicA:Gpu)
  mx = PicA:SpotX * vw
  my = PicA:SpotY * vh
  DO Air:GpuWas:PicA
  was = PicA:Zoom / 100
  now = was * (1 + 25 / 100)
  IF now > 64 THEN now = 64.
  PicA:PanX += mx / was - mx / now
  PicA:PanY += my / was - my / now
  PicA:Zoom = now * 100
  DO Air:Gpu:PicA

Air:GpuOut:PicA ROUTINE
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
  vw = d2c_ViewW(PicA:Gpu)
  vh = d2c_ViewH(PicA:Gpu)
  mx = PicA:SpotX * vw
  my = PicA:SpotY * vh
  iw = d2c_ImageW(PicA:Gpu)
  ih = d2c_ImageH(PicA:Gpu)
  IF iw < 1 OR ih < 1 THEN EXIT.
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  DO Air:GpuWas:PicA
  was = PicA:Zoom / 100
  now = was / (1 + 25 / 100)
  IF now <= fit                                               ! all the way out = fit again
    DO Air:Fit:PicA
    EXIT
  END
  PicA:PanX += mx / was - mx / now
  PicA:PanY += my / was - my / now
  PicA:Zoom = now * 100
  DO Air:Gpu:PicA

Air:GpuWas:PicA ROUTINE
!  Zoom 0 means "fitted"; turn that into the percentage it is really showing
!  at, so a step can be taken from it.
  DATA
fit  REAL,AUTO
vw   LONG,AUTO
vh   LONG,AUTO
iw   LONG,AUTO
ih   LONG,AUTO
  CODE
  IF PicA:Zoom THEN EXIT.
  vw = d2c_ViewW(PicA:Gpu)
  vh = d2c_ViewH(PicA:Gpu)
  iw = d2c_ImageW(PicA:Gpu)
  ih = d2c_ImageH(PicA:Gpu)
  IF iw < 1 OR ih < 1
    PicA:Zoom = 100
    EXIT
  END
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  PicA:Zoom = fit * 100

Air:Open:PicA ROUTINE
!  Whichever picture the user wants.
  DATA
pick CSTRING(261)
  CODE
  pick = PicA:Path
  IF ~FILEDIALOG('Open a picture',pick,AirImg_Filter(),FILE:KeepDir + FILE:LongName) THEN EXIT.
  PicA:Path = pick
  IF AirImg_LoadPath(PicA,PicA:Path)
    DO Air:Fresh:PicA
  END
  DO Air:Show:PicA

Air:Save:PicA ROUTINE
!  The format follows the name the user types: .png .jpg .gif .bmp .tif .tga
!  .pcx .ppm and .qoi are all written by the class.
  DATA
pick CSTRING(261)
  CODE
  IF ~PicA.Ok() THEN EXIT.
  pick = PicA:Path
  IF ~FILEDIALOG('Save a copy',pick,AirImg_Filter(),FILE:Save + FILE:KeepDir + FILE:LongName) THEN EXIT.
  IF ~PicA.SaveFile(pick)
    MESSAGE('That picture could not be written.||' & pick,'Save a copy',ICON:Exclamation)
  END

Air:Menu:PicA ROUTINE
!  The menu is built at generate time out of the boxes the developer ticked, so
!  the numbers below always line up with the lines that are actually on it.
  CASE POPUP('Open a picture...|Zoom in|Zoom out|Actual size|Fit the frame|Rotate left|Rotate right|Next frame|Previous frame|Save a copy...|What is this picture?')
  OF 1
    DO Air:Open:PicA
  OF 2
    DO Air:In:PicA
  OF 3
    DO Air:Out:PicA
  OF 4
    PicA:Zoom = 100
    PicA:PanX = 0
    PicA:PanY = 0
    DO Air:Show:PicA
  OF 5
    DO Air:Fit:PicA
  OF 6
    PicA.RotateLeft()
    DO Air:Show:PicA
  OF 7
    PicA.RotateRight()
    DO Air:Show:PicA
  OF 8
    IF PicA.Frames() > 1
      PicA:Frame += 1
      IF PicA:Frame > PicA.Frames() THEN PicA:Frame = 1.
      DO Air:Frame:PicA
    END
  OF 9
    IF PicA.Frames() > 1
      PicA:Frame -= 1
      IF PicA:Frame < 1 THEN PicA:Frame = PicA.Frames().
      DO Air:Frame:PicA
    END
  OF 10
    DO Air:Save:PicA
  OF 11
    IF PicA.Ok()
      MESSAGE(PicA.Describe() & '||' & PicA:Path,'Picture',ICON:Asterisk)
    ELSE
      MESSAGE('There is no picture on this canvas.','Picture',ICON:Asterisk)
    END
  END
myQRRefresh ROUTINE
  myQR:Ecc = 'M'                              ! error-correction level
  myQR:Cur = 'https://example.com'                                  ! a literal - auto-quoted (use variable mode, or double any internal <39>, for a value with a quote)
  myQRLoad(?Pic1, myQR:Cur, 200, myQR:Ecc, 1)
  myQR:Last = myQR:Cur                                     ! remember what we just rendered
Air:Setup:PicB ROUTINE
!  The IMAGE control is only the paint surface. A REGION created over it takes
!  the mouse - the way Clarion's own ActiveImage class does it
!  (libsrc\win\ActiveImage.clw:303). A REGION has nothing of its own to draw,
!  so the picture underneath shows through untouched.
  IF ~PicB:Rgn
    PicB:Rgn = CREATE(0,CREATE:Region,?AirCanvas{PROP:Parent})
!  IMM, or the mouse never speaks. EVENT:MouseMove and EVENT:MouseUp are
!  documented as arriving "on a REGION with the IMM attribute" - without it a
!  region still gets MouseDown (it is a synonym for EVENT:Accepted) and then
!  nothing at all, so a drag begins and never moves. A region built at run time
!  has no attribute list to carry IMM, so it is set as a property here.
    PicB:Rgn{PROP:IMM} = 1
  END
  DO Air:Place:PicB
  UNHIDE(PicB:Rgn)
!  The scrollbars go on BEFORE the graphics card attaches: adding the styles
!  takes a slice off the client area, and the render target must be built for
!  what is left of it.
  IF AirImg_HookBars(PicB:Rgn{PROP:Handle})
    PicB:Barred = 1
  END
!  Hand the canvas to the graphics card. The REGION laid over the image owns a
!  real window, so Direct2D renders into THAT and Clarion keeps the rest of the
!  window to itself. If there is no Direct2D, or it will not attach, the canvas
!  quietly goes on drawing with the processor.
  IF ~PicB:Gpu AND d2c_Available()
    PicB:Gpu = d2c_Attach(PicB:Rgn{PROP:Handle})
  END
  IF PicB:Gpu
    HIDE(?AirCanvas)                                            ! the IMAGE control is not used now
  END
!  Take the mouse wheel off the window procedure. The first canvas on a window
!  does it; the rest ride along, because the event reaches all of them.
  IF AirImg_HookWheel(QuickWindow{PROP:Handle})                   ! the helper takes the address,
    PicB:Hooked = 1                                       !   never this module
  END
  ?AirCanvas{PROP:DropID,1}     = '~FILE'                       ! a file dragged out of Explorer
  PicB:Rgn{PROP:DropID,1} = '~FILE'
  PicB:Rgn{PROP:Alrt,255} = MouseRight
  PicB:Rgn{PROP:Alrt,254} = MouseLeft2
!  ALERT() adds to the window's alerted keys rather than claiming a numbered
!  slot, so it cannot tread on another template's alert. Ctrl+arrows, because
!  the bare arrows belong to whatever browse the window is carrying.
  ALERT(CtrlUp)
  ALERT(CtrlDown)
  ALERT(CtrlLeft)
  ALERT(CtrlRight)
  ALERT(CtrlHome)
  PicB:Path = CLIP(Loc:Url)
  AirImg_LoadUrl(PicB,PicB:Path,'Main_c1',AirImg:Secs)
  DO Air:Fresh:PicB
  POST(Air:Redraw:PicB)                                   ! first paint, once the window is up

Air:Place:PicB ROUTINE
!  Keep the region exactly over the image, however the resizer moves it.
  DATA
x  SIGNED,AUTO
y  SIGNED,AUTO
w  SIGNED,AUTO
h  SIGNED,AUTO
  CODE
  IF ~PicB:Rgn THEN EXIT.
  GETPOSITION(?AirCanvas,x,y,w,h)
  SETPOSITION(PicB:Rgn,x,y,w,h)

Air:Size:PicB ROUTINE
!  The canvas control moved or changed size, so the render target has to be
!  told; Direct2D will not notice on its own.
  IF PicB:Gpu
    d2c_Resize(PicB:Gpu)
  END

Air:Upload:PicB ROUTINE
!  Hand the graphics card the pixels the object is holding NOW. Called when a
!  new picture arrives and again whenever the frame changes - a zoom does not
!  need it, which is the whole point of the GPU path.
  IF PicB:Gpu
    IF ~PicB.Ok()
      d2c_Clear(PicB:Gpu)
    ELSIF PicB.CloneInto(PicB:Cv)
      PicB:Cv.Flatten(PicB.ArgbOf(16777215))
      PicB:Cv.BmpBits = 32
      PicB:Bmp = AirImg_Temp('Main_c1','.bmp')
      IF PicB:Cv.SaveFile(PicB:Bmp, Img:Bmp)
        d2c_LoadBmp(PicB:Gpu, PicB:Bmp)
      END
    END
  END

Air:Frame:PicB ROUTINE
!  Show whatever frame number is in <object>:Frame - a page of a TIFF, a frame
!  of an animated GIF, one size out of an .ico. The zoom and the pan are left
!  alone, so stepping through pages does not throw the view away.
  IF ~PicB.Ok() THEN EXIT.
  IF PicB:Frame < 1 THEN PicB:Frame = 1.
  IF PicB:Frame > PicB.Frames() THEN PicB:Frame = PicB.Frames().
  IF ~PicB.LoadFrame(PicB:Frame - 1) THEN EXIT.       ! the engine counts from zero
  PicB.RotateRight()
  IF PicB.Wide() > 2000 OR PicB.High() > 2000
    PicB.Fit(2000,2000,Img:Contain,0)                      ! cap the longest side
  END
  DO Air:Upload:PicB
  DO Air:Show:PicB

Air:Fresh:PicB ROUTINE
!  A NEW picture has just landed in the object.
!  LoadFrame counts from ZERO - imgcore's img_select_frame rejects anything
!  from Frames() up - while everything a person sees counts from one.
  IF PicB.Frames() >= 2
    PicB:Frame = 2
    PicB.LoadFrame(PicB:Frame - 1)
  END
  PicB.RotateRight()
  IF PicB.Wide() > 2000 OR PicB.High() > 2000
    PicB.Fit(2000,2000,Img:Contain,0)                      ! cap the longest side
  END
  DO Air:Upload:PicB
  PicB:Zoom = 0                                           ! back to fitting the frame
  PicB:PanX = 0
  PicB:PanY = 0
  ?AirCanvas{PROP:Tooltip} = PicB:Path
  IF PicB.Ok()
    0{PROP:StatusText,2} = PicB.Describe()
  ELSE
    0{PROP:StatusText,2} = ''
  END

Air:Show:PicB ROUTINE
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
!  On the graphics card a repaint is a zoom factor and an offset. Nothing is
!  resampled, nothing is written to disk, and the cost does not depend on how
!  big the picture is. Zoom 0 still means "fit the frame"; the factor for that
!  is worked out from the canvas and the picture.
  IF PicB:Gpu
    DO Air:Gpu:PicB
    EXIT
  END
  IF ~PicB.Ok()
    ?AirCanvas{PROP:Text} = ''
    DISPLAY(?AirCanvas)
    EXIT
  END
  IF ~PicB:Zoom
    PicB.Draw(QuickWindow,?AirCanvas,Img:Proportional,PicB.ArgbOf(16777215))
    DO Air:Bars:PicB
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the frame, in real pixels
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  IF w < 4 OR h < 4 THEN EXIT.
!  CROP FIRST, then scale. Scaling the whole picture and keeping the sliver
!  that shows costs the whole picture: at 400 per cent a 2400x1800 photograph
!  becomes 9600x7200 - 69 million pixels resampled to fill a 620x460 hole, and
!  it gets four times worse each time you double the zoom. Cutting the source
!  rectangle out first makes the work depend on the SIZE OF THE FRAME instead,
!  whatever the picture and whatever the zoom. Measured on that photograph:
!  8.9 seconds a step becomes 52 milliseconds.
  iw = PicB.Wide()
  ih = PicB.High()
  IF iw < 1 OR ih < 1 THEN EXIT.
  zw = INT(iw * PicB:Zoom / 100)                          ! the picture at this zoom
  zh = INT(ih * PicB:Zoom / 100)
  cw = w                                                      ! the viewport, never bigger than the picture
  ch = h
  IF cw > zw THEN cw = zw.
  IF ch > zh THEN ch = zh.
  IF cw < 1 OR ch < 1 THEN EXIT.
  IF PicB:PanX > zw - cw THEN PicB:PanX = zw - cw.
  IF PicB:PanY > zh - ch THEN PicB:PanY = zh - ch.
  IF PicB:PanX < 0 THEN PicB:PanX = 0.
  IF PicB:PanY < 0 THEN PicB:PanY = 0.
  sx = INT(PicB:PanX * 100 / PicB:Zoom)               ! source pixel at the view's corner
  sy = INT(PicB:PanY * 100 / PicB:Zoom)
  sw = INT(cw * 100 / PicB:Zoom) + 2                      ! enough source to cover it, plus slack
  sh = INT(ch * 100 / PicB:Zoom) + 2
  IF sx + sw > iw THEN sw = iw - sx.
  IF sy + sh > ih THEN sh = ih - sy.
  IF sw < 1 OR sh < 1 THEN EXIT.
  IF ~PicB.CloneInto(PicB:Cv) THEN EXIT.
  PicB:Cv.Crop(sx,sy,sw,sh)                               ! just what shows
  PicB:Cv.Resize(INT(sw * PicB:Zoom / 100),           |
                     INT(sh * PicB:Zoom / 100),Img:Best)  ! and scale only that
!  The crop landed on a whole source pixel, which is up to one pixel adrift of
!  where the view really starts; take that back off the scaled piece so the
!  picture does not jump about as it is panned.
  PicB:Cv.Crop(PicB:PanX - INT(sx * PicB:Zoom / 100),             |
                   PicB:PanY - INT(sy * PicB:Zoom / 100),cw,ch)
  PicB:Cv.Fit(w,h,Img:Centered,PicB.ArgbOf(16777215))  ! pad out to the frame
  PicB:Cv.Draw(QuickWindow,?AirCanvas,-1)                       ! -1 = blit it as it is
  DO Air:Bars:PicB

Air:Gpu:PicB ROUTINE
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
  vw = d2c_ViewW(PicB:Gpu)
  vh = d2c_ViewH(PicB:Gpu)
  iw = d2c_ImageW(PicB:Gpu)
  ih = d2c_ImageH(PicB:Gpu)
  IF iw < 1 OR ih < 1 OR vw < 1 OR vh < 1
    d2c_SetView(PicB:Gpu, 1.0, 0, 0, PicB.ArgbOf(16777215), 1)
    EXIT
  END
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  IF ~PicB:Zoom
    z = fit                                                   ! 0 means fit the frame
    PicB:PanX = 0
    PicB:PanY = 0
  ELSE
    z = PicB:Zoom / 100
  END
  IF z < 0.001 THEN z = 0.001.
!  keep the view on the picture
  IF PicB:PanX > iw - (vw / z) THEN PicB:PanX = iw - (vw / z).
  IF PicB:PanY > ih - (vh / z) THEN PicB:PanY = ih - (vh / z).
  IF PicB:PanX < 0 THEN PicB:PanX = 0.
  IF PicB:PanY < 0 THEN PicB:PanY = 0.
  d2c_SetView(PicB:Gpu, z, PicB:PanX, PicB:PanY,                |
              PicB.ArgbOf(16777215), 1)
  DO Air:Bars:PicB

Air:Spot:PicB ROUTINE
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
  PicB:SpotX = 0.5
  PicB:SpotY = 0.5
  PicB:Over  = 0
  GETPOSITION(?AirCanvas,rx,ry,rw,rh)
  IF rw < 1 OR rh < 1 THEN EXIT.
  IF MOUSEX() < rx OR MOUSEX() > rx + rw THEN EXIT.
  IF MOUSEY() < ry OR MOUSEY() > ry + rh THEN EXIT.
  PicB:Over  = 1
  PicB:SpotX = (MOUSEX() - rx) / rw
  PicB:SpotY = (MOUSEY() - ry) / rh

Air:WheelIn:PicB ROUTINE
!  A wheel notch reaches EVERY canvas on the window, so only the one under the
!  pointer takes it. The menu calls Air:In directly and is not filtered.
  DO Air:Spot:PicB
  IF PicB:Over
    DO Air:In:PicB
  END

Air:WheelOut:PicB ROUTINE
  DO Air:Spot:PicB
  IF PicB:Over
    DO Air:Out:PicB
  END

Air:In:PicB ROUTINE
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
  IF ~PicB.Ok() THEN EXIT.
  DO Air:Spot:PicB
  IF PicB:Gpu
    DO Air:GpuIn:PicB
    EXIT
  END
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicB:Zoom
  IF ~was THEN was = AirImg_FitPct(PicB,w,h).
  now = was + 25
  IF now > 1600 THEN now = 1600.
  mx = PicB:SpotX * w
  my = PicB:SpotY * h
  PicB:PanX = INT((PicB:PanX + mx) * now / was - mx)
  PicB:PanY = INT((PicB:PanY + my) * now / was - my)
  PicB:Zoom = now
  DO Air:Show:PicB

Air:Out:PicB ROUTINE
  DATA
was    LONG,AUTO
now    LONG,AUTO
w      LONG,AUTO
h      LONG,AUTO
mx     LONG,AUTO
my     LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicB.Ok() OR ~PicB:Zoom THEN EXIT.               ! already fitted
  DO Air:Spot:PicB
  IF PicB:Gpu
    DO Air:GpuOut:PicB
    EXIT
  END
  savePx = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  was = PicB:Zoom
  now = was - 25
  IF now <= AirImg_FitPct(PicB,w,h)                        ! all the way out = fit the frame
    DO Air:Fit:PicB
    EXIT
  END
  mx = PicB:SpotX * w
  my = PicB:SpotY * h
  PicB:PanX = INT((PicB:PanX + mx) * now / was - mx)
  PicB:PanY = INT((PicB:PanY + my) * now / was - my)
  PicB:Zoom = now
  DO Air:Show:PicB

Air:PanBy:PicB ROUTINE
!  One keyboard step. There is nothing to pan when the picture is fitted, so
!  the keys are quiet then - the same rule the drag follows.
  DATA
w      LONG,AUTO
h      LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicB.Ok() OR ~PicB:Zoom THEN EXIT.
  IF PicB:Gpu
!  The GPU pans in IMAGE pixels. The frame shows ViewW/zoom of them, so a step
!  of PanStep per cent is ViewW * PanStep / Zoom - the hundreds cancel.
    PicB:PanX += PicB:StepX * d2c_ViewW(PicB:Gpu) *              |
                     15 / PicB:Zoom
    PicB:PanY += PicB:StepY * d2c_ViewH(PicB:Gpu) *              |
                     15 / PicB:Zoom
    DO Air:Gpu:PicB
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the processor pans in scaled pixels
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  PicB:PanX += INT(PicB:StepX * w * 15 / 100)
  PicB:PanY += INT(PicB:StepY * h * 15 / 100)
  DO Air:Show:PicB

Air:Bars:PicB ROUTINE
!  Tell the scrollbars how much picture there is and how much of it shows, in
!  whatever units this engine pans in. Windows hides a bar whose page covers
!  its whole range, so at "fit the frame" they take themselves away.
  DATA
tot  LONG,AUTO
page LONG,AUTO
w    LONG,AUTO
h    LONG,AUTO
savePx LONG,AUTO
  CODE
  IF ~PicB:Barred THEN EXIT.
  IF ~PicB.Ok() OR ~PicB:Zoom                         ! fitted: no bars
    AirImg_SetBar(PicB:Rgn{PROP:Handle},AirImg:SbHorz,0,1,1)
    AirImg_SetBar(PicB:Rgn{PROP:Handle},AirImg:SbVert,0,1,1)
    IF PicB:Gpu THEN d2c_Resize(PicB:Gpu).
    EXIT
  END
  IF PicB:Gpu                                             ! the GPU pans in image pixels
    tot  = d2c_ImageW(PicB:Gpu)
    page = INT(d2c_ViewW(PicB:Gpu) * 100 / PicB:Zoom)
    AirImg_SetBar(PicB:Rgn{PROP:Handle},AirImg:SbHorz,PicB:PanX,page,tot)
    tot  = d2c_ImageH(PicB:Gpu)
    page = INT(d2c_ViewH(PicB:Gpu) * 100 / PicB:Zoom)
    AirImg_SetBar(PicB:Rgn{PROP:Handle},AirImg:SbVert,PicB:PanY,page,tot)
    d2c_Resize(PicB:Gpu)
    EXIT
  END
  savePx = 0{PROP:Pixels}                                     ! the processor pans in scaled pixels
  0{PROP:Pixels} = 1
  w = ?AirCanvas{PROP:Width}
  h = ?AirCanvas{PROP:Height}
  0{PROP:Pixels} = savePx
  AirImg_SetBar(PicB:Rgn{PROP:Handle},AirImg:SbHorz,PicB:PanX,w,      |
                INT(PicB.Wide() * PicB:Zoom / 100))
  AirImg_SetBar(PicB:Rgn{PROP:Handle},AirImg:SbVert,PicB:PanY,h,      |
                INT(PicB.High() * PicB:Zoom / 100))

Air:Scrolled:PicB ROUTINE
!  A bar moved - on this canvas or on another one. Read our own two back; if
!  they have not moved there is nothing to do, which is what makes it safe to
!  send the one event to every canvas on the window.
  DATA
nx LONG,AUTO
ny LONG,AUTO
  CODE
  IF ~PicB:Barred OR ~PicB:Zoom THEN EXIT.
  nx = AirImg_BarPos(PicB:Rgn{PROP:Handle},AirImg:SbHorz)
  ny = AirImg_BarPos(PicB:Rgn{PROP:Handle},AirImg:SbVert)
  IF nx = PicB:PanX AND ny = PicB:PanY THEN EXIT.
  PicB:PanX = nx
  PicB:PanY = ny
  IF PicB:Gpu
    DO Air:Gpu:PicB
    EXIT
  END
  DO Air:Show:PicB

Air:Fit:PicB ROUTINE
  PicB:Zoom = 0
  PicB:PanX = 0
  PicB:PanY = 0
  DO Air:Show:PicB

Air:GpuIn:PicB ROUTINE
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
  vw = d2c_ViewW(PicB:Gpu)
  vh = d2c_ViewH(PicB:Gpu)
  mx = PicB:SpotX * vw
  my = PicB:SpotY * vh
  DO Air:GpuWas:PicB
  was = PicB:Zoom / 100
  now = was * (1 + 25 / 100)
  IF now > 64 THEN now = 64.
  PicB:PanX += mx / was - mx / now
  PicB:PanY += my / was - my / now
  PicB:Zoom = now * 100
  DO Air:Gpu:PicB

Air:GpuOut:PicB ROUTINE
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
  vw = d2c_ViewW(PicB:Gpu)
  vh = d2c_ViewH(PicB:Gpu)
  mx = PicB:SpotX * vw
  my = PicB:SpotY * vh
  iw = d2c_ImageW(PicB:Gpu)
  ih = d2c_ImageH(PicB:Gpu)
  IF iw < 1 OR ih < 1 THEN EXIT.
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  DO Air:GpuWas:PicB
  was = PicB:Zoom / 100
  now = was / (1 + 25 / 100)
  IF now <= fit                                               ! all the way out = fit again
    DO Air:Fit:PicB
    EXIT
  END
  PicB:PanX += mx / was - mx / now
  PicB:PanY += my / was - my / now
  PicB:Zoom = now * 100
  DO Air:Gpu:PicB

Air:GpuWas:PicB ROUTINE
!  Zoom 0 means "fitted"; turn that into the percentage it is really showing
!  at, so a step can be taken from it.
  DATA
fit  REAL,AUTO
vw   LONG,AUTO
vh   LONG,AUTO
iw   LONG,AUTO
ih   LONG,AUTO
  CODE
  IF PicB:Zoom THEN EXIT.
  vw = d2c_ViewW(PicB:Gpu)
  vh = d2c_ViewH(PicB:Gpu)
  iw = d2c_ImageW(PicB:Gpu)
  ih = d2c_ImageH(PicB:Gpu)
  IF iw < 1 OR ih < 1
    PicB:Zoom = 100
    EXIT
  END
  fit = vw / iw
  IF (vh / ih) < fit THEN fit = vh / ih.
  PicB:Zoom = fit * 100

Air:Open:PicB ROUTINE
!  Whichever picture the user wants.
  DATA
pick CSTRING(261)
  CODE
  pick = PicB:Path
  IF ~FILEDIALOG('Open a picture',pick,AirImg_Filter(),FILE:KeepDir + FILE:LongName) THEN EXIT.
  PicB:Path = pick
  IF AirImg_LoadPath(PicB,PicB:Path)
    DO Air:Fresh:PicB
  END
  DO Air:Show:PicB

Air:Save:PicB ROUTINE
!  The format follows the name the user types: .png .jpg .gif .bmp .tif .tga
!  .pcx .ppm and .qoi are all written by the class.
  DATA
pick CSTRING(261)
  CODE
  IF ~PicB.Ok() THEN EXIT.
  pick = PicB:Path
  IF ~FILEDIALOG('Save a copy',pick,AirImg_Filter(),FILE:Save + FILE:KeepDir + FILE:LongName) THEN EXIT.
  IF ~PicB.SaveFile(pick)
    MESSAGE('That picture could not be written.||' & pick,'Save a copy',ICON:Exclamation)
  END

Air:Menu:PicB ROUTINE
!  The menu is built at generate time out of the boxes the developer ticked, so
!  the numbers below always line up with the lines that are actually on it.
  CASE POPUP('Open a picture...|Zoom in|Zoom out|Actual size|Fit the frame|Rotate left|Rotate right|Next frame|Previous frame|Save a copy...|What is this picture?')
  OF 1
    DO Air:Open:PicB
  OF 2
    DO Air:In:PicB
  OF 3
    DO Air:Out:PicB
  OF 4
    PicB:Zoom = 100
    PicB:PanX = 0
    PicB:PanY = 0
    DO Air:Show:PicB
  OF 5
    DO Air:Fit:PicB
  OF 6
    PicB.RotateLeft()
    DO Air:Show:PicB
  OF 7
    PicB.RotateRight()
    DO Air:Show:PicB
  OF 8
    IF PicB.Frames() > 1
      PicB:Frame += 1
      IF PicB:Frame > PicB.Frames() THEN PicB:Frame = 1.
      DO Air:Frame:PicB
    END
  OF 9
    IF PicB.Frames() > 1
      PicB:Frame -= 1
      IF PicB:Frame < 1 THEN PicB:Frame = PicB.Frames().
      DO Air:Frame:PicB
    END
  OF 10
    DO Air:Save:PicB
  OF 11
    IF PicB.Ok()
      MESSAGE(PicB.Describe() & '||' & PicB:Path,'Picture',ICON:Asterisk)
    ELSE
      MESSAGE('There is no picture on this canvas.','Picture',ICON:Asterisk)
    END
  END
AirFrm:Go:AirFrm4 ROUTINE
!  Move the canvas to the frame number now in its object, then bring the bar
!  into line with it.
  DO Air:Frame:PicB
  DO AirFrm:Sync:AirFrm4

AirFrm:Step:AirFrm4 ROUTINE
!  One frame on - what Play calls on every tick, and what Next does.
  IF PicB.Frames() < 2 THEN EXIT.
  PicB:Frame += 1
  IF PicB:Frame > PicB.Frames()
    PicB:Frame = 1
  END
  DO AirFrm:Go:AirFrm4

AirFrm:Play:AirFrm4 ROUTINE
  IF PicB.Frames() < 2 THEN EXIT.
  AirFrm4:WasTimer = 0{PROP:Timer}                           ! borrow the window timer
  AirFrm4:Playing  = 1
  0{PROP:Timer} = 10
  ?AirFrmPlay{PROP:Text} = 'Stop'

AirFrm:Stop:AirFrm4 ROUTINE
  AirFrm4:Playing = 0
  0{PROP:Timer} = AirFrm4:WasTimer                           ! and put it back
  ?AirFrmPlay{PROP:Text} = 'Play'

AirFrm:Sync:AirFrm4 ROUTINE
!  Make the bar tell the truth: the counter, the buttons that cannot go
!  anywhere, and the whole bar when there is only one frame to look at.
  DATA
n LONG,AUTO
f LONG,AUTO
  CODE
  n = 0
  f = 0
  IF PicB.Ok()
    n = PicB.Frames()
    f = PicB:Frame
    IF f < 1 THEN f = 1.
  END
  ?AirFrmText{PROP:Text} = CHOOSE(n < 1, '', 'Frame ' & CLIP(LEFT(f)) & ' of ' & CLIP(LEFT(n)))
  IF n < 2                                                    ! nothing to step through
    HIDE(?AirFrmFirst)
    HIDE(?AirFrmPrev)
    HIDE(?AirFrmNext)
    HIDE(?AirFrmLast)
    HIDE(?AirFrmText)
    HIDE(?AirFrmPlay)
    EXIT
  END
  UNHIDE(?AirFrmFirst)
  UNHIDE(?AirFrmPrev)
  UNHIDE(?AirFrmNext)
  UNHIDE(?AirFrmLast)
  UNHIDE(?AirFrmText)
  UNHIDE(?AirFrmPlay)

ThisWindow.Init PROCEDURE

ReturnValue          BYTE,AUTO

  CODE
  GlobalErrors.SetProcedureName('Main')
  SELF.Request = GlobalRequest                             ! Store the incoming request
  ReturnValue = PARENT.Init()
  IF ReturnValue THEN RETURN ReturnValue.
  SELF.FirstField = ?Pic1
  SELF.VCRRequest &= VCRRequest
  SELF.Errors &= GlobalErrors                              ! Set this windows ErrorManager to the global ErrorManager
  CLEAR(GlobalRequest)                                     ! Clear GlobalRequest after storing locally
  CLEAR(GlobalResponse)
  SELF.AddItem(Toolbar)
  SELF.Open(QuickWindow)                                   ! Open window
  Do DefineListboxStyle
  INIMgr.Fetch('Main',QuickWindow)                         ! Restore window settings from non-volatile store
  SELF.SetAlerts()
  RETURN ReturnValue


ThisWindow.Kill PROCEDURE

ReturnValue          BYTE,AUTO

  CODE
    IF PicA:Hooked
      AirImg_DropWheel(QuickWindow{PROP:Handle})
      PicA:Hooked = 0
    END
    IF PicA:Barred
      AirImg_DropBars(PicA:Rgn{PROP:Handle})
      PicA:Barred = 0
    END
    IF PicA:Gpu
      d2c_Detach(PicA:Gpu)                                     ! gives the control its own window back
      PicA:Gpu = 0
    END
    IF PicB:Hooked
      AirImg_DropWheel(QuickWindow{PROP:Handle})
      PicB:Hooked = 0
    END
    IF PicB:Barred
      AirImg_DropBars(PicB:Rgn{PROP:Handle})
      PicB:Barred = 0
    END
    IF PicB:Gpu
      d2c_Detach(PicB:Gpu)                                     ! gives the control its own window back
      PicB:Gpu = 0
    END
    IF AirFrm4:Playing
      DO AirFrm:Stop:AirFrm4                                   ! give the timer back
    END
  ReturnValue = PARENT.Kill()
  IF ReturnValue THEN RETURN ReturnValue.
  IF SELF.Opened
    INIMgr.Update('Main',QuickWindow)                      ! Save window data to non-volatile store
  END
  GlobalErrors.SetProcedureName
  RETURN ReturnValue


ThisWindow.TakeFieldEvent PROCEDURE

ReturnValue          BYTE,AUTO

Looped BYTE
  CODE
    CASE EVENT()
    OF EVENT:AlertKey
      CASE KEYCODE()
      OF CtrlUp
        PicA:StepX = 0
        PicA:StepY = -1
        DO Air:PanBy:PicA
      OF CtrlDown
        PicA:StepX = 0
        PicA:StepY = 1
        DO Air:PanBy:PicA
      OF CtrlLeft
        PicA:StepX = -1
        PicA:StepY = 0
        DO Air:PanBy:PicA
      OF CtrlRight
        PicA:StepX = 1
        PicA:StepY = 0
        DO Air:PanBy:PicA
      OF CtrlHome
        DO Air:Fit:PicA
      END
    END
    IF FIELD() = PicA:Rgn OR FIELD() = ?Pic1
      CASE EVENT()
      OF EVENT:MouseDown
        IF KEYCODE() = MouseLeft AND PicA:Zoom
  !  MOUSEX and MOUSEY answer in the WINDOW's units, and a window unit is not a
  !  pixel - it is half of one across and half of one down on a default window.
  !  The pan is in pixels, so read the pointer with the units switched to pixels
  !  or the picture drags at half speed and slides out from under the pointer.
          PicA:SavePx = 0{PROP:Pixels}
          0{PROP:Pixels} = 1
          PicA:Drag  = 1
          PicA:DragX = MOUSEX()
          PicA:DragY = MOUSEY()
          0{PROP:Pixels} = PicA:SavePx
          PicA:PanX0 = PicA:PanX                              ! the anchor: where we started
          PicA:PanY0 = PicA:PanY
        END
      OF EVENT:MouseMove
        IF PicA:Drag
          PicA:SavePx = 0{PROP:Pixels}
          0{PROP:Pixels} = 1
          PicA:MX = MOUSEX()
          PicA:MY = MOUSEY()
          0{PROP:Pixels} = PicA:SavePx
  !  Measure from where the drag STARTED, never from the last move. A drag
  !  arrives as a stream of one- and two-pixel deltas, and on the graphics card
  !  each one is divided by the zoom: at 500 per cent a one-pixel move is a fifth
  !  of an image pixel, which rounds to nothing, and the remainder is gone for
  !  good. Add up sixty of those and the picture has not moved at all. Taken from
  !  the anchor there is one rounding, of the whole distance, and the picture
  !  sits where the pointer put it.
          IF PicA:Gpu AND PicA:Zoom                           ! the GPU pans in IMAGE pixels
            PicA:PanX = PicA:PanX0 + (PicA:DragX - PicA:MX) * 100 / PicA:Zoom
            PicA:PanY = PicA:PanY0 + (PicA:DragY - PicA:MY) * 100 / PicA:Zoom
          ELSE
            PicA:PanX = PicA:PanX0 + PicA:DragX - PicA:MX
            PicA:PanY = PicA:PanY0 + PicA:DragY - PicA:MY
          END
          DO Air:Show:PicA
        END
      OF EVENT:MouseUp
        PicA:Drag = 0
      OF EVENT:Drop
        PicA:Path = CLIP(DROPID())                             ! several files? take the first
        IF INSTRING(',',PicA:Path,1,1)
          PicA:Path = SUB(PicA:Path,1,INSTRING(',',PicA:Path,1,1) - 1)
        END
        IF AirImg_LoadPath(PicA,PicA:Path)
          DO Air:Fresh:PicA
        END
        DO Air:Show:PicA
      OF EVENT:AlertKey
        CASE KEYCODE()
        OF MouseRight
          DO Air:Menu:PicA
        OF MouseLeft2
          DO Air:Open:PicA
        END
      END
    END
    CASE EVENT()
    OF EVENT:AlertKey
      CASE KEYCODE()
      OF CtrlUp
        PicB:StepX = 0
        PicB:StepY = -1
        DO Air:PanBy:PicB
      OF CtrlDown
        PicB:StepX = 0
        PicB:StepY = 1
        DO Air:PanBy:PicB
      OF CtrlLeft
        PicB:StepX = -1
        PicB:StepY = 0
        DO Air:PanBy:PicB
      OF CtrlRight
        PicB:StepX = 1
        PicB:StepY = 0
        DO Air:PanBy:PicB
      OF CtrlHome
        DO Air:Fit:PicB
      END
    END
    IF FIELD() = PicB:Rgn OR FIELD() = ?AirCanvas
      CASE EVENT()
      OF EVENT:MouseDown
        IF KEYCODE() = MouseLeft AND PicB:Zoom
  !  MOUSEX and MOUSEY answer in the WINDOW's units, and a window unit is not a
  !  pixel - it is half of one across and half of one down on a default window.
  !  The pan is in pixels, so read the pointer with the units switched to pixels
  !  or the picture drags at half speed and slides out from under the pointer.
          PicB:SavePx = 0{PROP:Pixels}
          0{PROP:Pixels} = 1
          PicB:Drag  = 1
          PicB:DragX = MOUSEX()
          PicB:DragY = MOUSEY()
          0{PROP:Pixels} = PicB:SavePx
          PicB:PanX0 = PicB:PanX                              ! the anchor: where we started
          PicB:PanY0 = PicB:PanY
        END
      OF EVENT:MouseMove
        IF PicB:Drag
          PicB:SavePx = 0{PROP:Pixels}
          0{PROP:Pixels} = 1
          PicB:MX = MOUSEX()
          PicB:MY = MOUSEY()
          0{PROP:Pixels} = PicB:SavePx
  !  Measure from where the drag STARTED, never from the last move. A drag
  !  arrives as a stream of one- and two-pixel deltas, and on the graphics card
  !  each one is divided by the zoom: at 500 per cent a one-pixel move is a fifth
  !  of an image pixel, which rounds to nothing, and the remainder is gone for
  !  good. Add up sixty of those and the picture has not moved at all. Taken from
  !  the anchor there is one rounding, of the whole distance, and the picture
  !  sits where the pointer put it.
          IF PicB:Gpu AND PicB:Zoom                           ! the GPU pans in IMAGE pixels
            PicB:PanX = PicB:PanX0 + (PicB:DragX - PicB:MX) * 100 / PicB:Zoom
            PicB:PanY = PicB:PanY0 + (PicB:DragY - PicB:MY) * 100 / PicB:Zoom
          ELSE
            PicB:PanX = PicB:PanX0 + PicB:DragX - PicB:MX
            PicB:PanY = PicB:PanY0 + PicB:DragY - PicB:MY
          END
          DO Air:Show:PicB
        END
      OF EVENT:MouseUp
        PicB:Drag = 0
      OF EVENT:Drop
        PicB:Path = CLIP(DROPID())                             ! several files? take the first
        IF INSTRING(',',PicB:Path,1,1)
          PicB:Path = SUB(PicB:Path,1,INSTRING(',',PicB:Path,1,1) - 1)
        END
        IF AirImg_LoadPath(PicB,PicB:Path)
          DO Air:Fresh:PicB
        END
        DO Air:Show:PicB
      OF EVENT:AlertKey
        CASE KEYCODE()
        OF MouseRight
          DO Air:Menu:PicB
        OF MouseLeft2
          DO Air:Open:PicB
        END
      END
    END
    IF EVENT() = EVENT:Accepted
      CASE FIELD()
      OF ?AirFrmFirst
        PicB:Frame = 1
        DO AirFrm:Go:AirFrm4
      OF ?AirFrmPrev
        PicB:Frame -= 1
        IF PicB:Frame < 1
          PicB:Frame = PicB.Frames()
        END
        DO AirFrm:Go:AirFrm4
      OF ?AirFrmNext
        DO AirFrm:Step:AirFrm4
      OF ?AirFrmLast
        PicB:Frame = PicB.Frames()
        DO AirFrm:Go:AirFrm4
      OF ?AirFrmPlay
        IF AirFrm4:Playing
          DO AirFrm:Stop:AirFrm4
        ELSE
          DO AirFrm:Play:AirFrm4
        END
      END
    END
  LOOP                                                     ! This method receives all field specific events
    IF Looped
      RETURN Level:Notify
    ELSE
      Looped = 1
    END
  ReturnValue = PARENT.TakeFieldEvent()
    RETURN ReturnValue
  END
  ReturnValue = Level:Fatal
  RETURN ReturnValue


ThisWindow.TakeWindowEvent PROCEDURE

ReturnValue          BYTE,AUTO

Looped BYTE
  CODE
    CASE EVENT()
    OF EVENT:OpenWindow
      DO Air:Setup:PicA
    OF EVENT:Sized
      DO Air:Place:PicA
      DO Air:Size:PicA
      POST(Air:Redraw:PicA)
    OF Air:Redraw:PicA
      DO Air:Show:PicA
    OF AirImg:CtrlUp
      DO Air:WheelIn:PicA
    OF AirImg:CtrlDown
      DO Air:WheelOut:PicA
    OF EVENT:AlertKey
      CASE KEYCODE()
      OF CtrlUp
        PicA:StepX = 0
        PicA:StepY = -1
        DO Air:PanBy:PicA
      OF CtrlDown
        PicA:StepX = 0
        PicA:StepY = 1
        DO Air:PanBy:PicA
      OF CtrlLeft
        PicA:StepX = -1
        PicA:StepY = 0
        DO Air:PanBy:PicA
      OF CtrlRight
        PicA:StepX = 1
        PicA:StepY = 0
        DO Air:PanBy:PicA
      OF CtrlHome
        DO Air:Fit:PicA
      END
    OF AirImg:Scrolled
      DO Air:Scrolled:PicA
    END
    CASE EVENT()
    OF EVENT:OpenWindow
      DO myQRRefresh                                         ! first render
    END
    CASE EVENT()
    OF EVENT:OpenWindow
      DO Air:Setup:PicB
    OF EVENT:Sized
      DO Air:Place:PicB
      DO Air:Size:PicB
      POST(Air:Redraw:PicB)
    OF Air:Redraw:PicB
      DO Air:Show:PicB
    OF AirImg:CtrlUp
      DO Air:WheelIn:PicB
    OF AirImg:CtrlDown
      DO Air:WheelOut:PicB
    OF EVENT:AlertKey
      CASE KEYCODE()
      OF CtrlUp
        PicB:StepX = 0
        PicB:StepY = -1
        DO Air:PanBy:PicB
      OF CtrlDown
        PicB:StepX = 0
        PicB:StepY = 1
        DO Air:PanBy:PicB
      OF CtrlLeft
        PicB:StepX = -1
        PicB:StepY = 0
        DO Air:PanBy:PicB
      OF CtrlRight
        PicB:StepX = 1
        PicB:StepY = 0
        DO Air:PanBy:PicB
      OF CtrlHome
        DO Air:Fit:PicB
      END
    OF AirImg:Scrolled
      DO Air:Scrolled:PicB
    END
    CASE EVENT()
    OF EVENT:OpenWindow
      DO AirFrm:Sync:AirFrm4
    OF EVENT:Timer
      IF AirFrm4:Playing
        DO AirFrm:Step:AirFrm4
      END
    END
  LOOP                                                     ! This method receives all window specific events
    IF Looped
      RETURN Level:Notify
    ELSE
      Looped = 1
    END
  ReturnValue = PARENT.TakeWindowEvent()
    RETURN ReturnValue
  END
  ReturnValue = Level:Fatal
  RETURN ReturnValue

