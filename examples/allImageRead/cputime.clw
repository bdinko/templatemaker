  PROGRAM
!  Two questions about the processor path, answered together.
!
!  1. WHERE DOES THE TIME GO? Time the pieces of a wheel notch as the canvas
!     performs it today, and time the crop-first version beside it.
!  2. DOES CROP-FIRST SHOW THE SAME THING - including part-way through a pan,
!     where it only ever cuts a small piece out of the middle of the picture?
!     Render both ways at several pan positions and hash what comes out.
  MAP
Main PROCEDURE
Hash PROCEDURE(*ImageClass pImg),ULONG
OldWay PROCEDURE(*ImageClass pSrc,*ImageClass pCv,LONG pZoom,LONG pPanX,LONG pPanY,LONG pW,LONG pH)
NewWay PROCEDURE(*ImageClass pSrc,*ImageClass pCv,LONG pZoom,LONG pPanX,LONG pPanY,LONG pW,LONG pH)
  END
  INCLUDE('ImageClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win    WINDOW('CpuTime'),AT(,,700,120),SYSTEM,GRAY,TIMER(100)
       END
Src    ImageClass
Cv     ImageClass
t0     LONG
tOld   LONG
tNew   LONG
n      LONG
px     LONG
py     LONG
hOld   ULONG
hNew   ULONG
same   LONG
bad    LONG
note   CSTRING(300)
ticks  LONG
VW     EQUATE(620)
VH     EQUATE(460)
ZOOM   EQUATE(400)
  CODE
  OPEN(Win)
  IF ~Src.TestCard(2400,1800)
    Win{PROP:Text} = 'CpuTime NO-CARD'
  ELSE
! ---- same picture, both ways, at three places in the pan -------------------
    LOOP n = 1 TO 3
      CASE n
      OF 1 ; px = 0    ; py = 0
      OF 2 ; px = 900  ; py = 700
      OF 3 ; px = 3000 ; py = 2200
      END
      OldWay(Src, Cv, ZOOM, px, py, VW, VH)
      hOld = Hash(Cv)
      NewWay(Src, Cv, ZOOM, px, py, VW, VH)
      hNew = Hash(Cv)
      IF hOld = hNew
        same += 1
      ELSE
        bad += 1
        note = CLIP(note) & ' pan(' & px & ',' & py & ')MISMATCH'
      END
    END
! ---- and what each costs ---------------------------------------------------
    t0 = CLOCK()
    OldWay(Src, Cv, ZOOM, 900, 700, VW, VH)
    tOld = CLOCK() - t0
    t0 = CLOCK()
    LOOP n = 1 TO 10
      NewWay(Src, Cv, ZOOM, 900 + n, 700 + n, VW, VH)         ! ten pans, to time one properly
    END
    tNew = CLOCK() - t0
    Win{PROP:Text} = 'CpuTime  old=' & tOld & 'cs/step   new=' & (tNew / 10) & |
                     'cs/step   identical=' & same & '/3' & CLIP(note) &       |
                     CHOOSE(bad = 0,' SAME-PICTURE',' DIFFERENT')
  END
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)

!  Scale the whole picture, then keep the part that shows.
OldWay PROCEDURE(*ImageClass pSrc,*ImageClass pCv,LONG pZoom,LONG pPanX,LONG pPanY,LONG pW,LONG pH)
cw LONG,AUTO
ch LONG,AUTO
x  LONG,AUTO
y  LONG,AUTO
  CODE
  IF ~pSrc.CloneInto(pCv) THEN RETURN.
  pCv.Zoom(pZoom, Img:Best)
  cw = pW ; ch = pH
  IF cw > pCv.Wide() THEN cw = pCv.Wide().
  IF ch > pCv.High() THEN ch = pCv.High().
  x = pPanX ; y = pPanY
  IF x > pCv.Wide() - cw THEN x = pCv.Wide() - cw.
  IF y > pCv.High() - ch THEN y = pCv.High() - ch.
  IF x < 0 THEN x = 0.
  IF y < 0 THEN y = 0.
  pCv.Crop(x, y, cw, ch)
  pCv.Fit(pW, pH, Img:Centered, 0FFFFFFh)

!  Cut out what shows, then scale only that - what the template does now.
NewWay PROCEDURE(*ImageClass pSrc,*ImageClass pCv,LONG pZoom,LONG pPanX,LONG pPanY,LONG pW,LONG pH)
iw LONG,AUTO
ih LONG,AUTO
zw LONG,AUTO
zh LONG,AUTO
cw LONG,AUTO
ch LONG,AUTO
sx LONG,AUTO
sy LONG,AUTO
sw LONG,AUTO
sh LONG,AUTO
x  LONG,AUTO
y  LONG,AUTO
  CODE
  iw = pSrc.Wide() ; ih = pSrc.High()
  IF iw < 1 OR ih < 1 THEN RETURN.
  zw = INT(iw * pZoom / 100)
  zh = INT(ih * pZoom / 100)
  cw = pW ; ch = pH
  IF cw > zw THEN cw = zw.
  IF ch > zh THEN ch = zh.
  IF cw < 1 OR ch < 1 THEN RETURN.
  x = pPanX ; y = pPanY
  IF x > zw - cw THEN x = zw - cw.
  IF y > zh - ch THEN y = zh - ch.
  IF x < 0 THEN x = 0.
  IF y < 0 THEN y = 0.
  sx = INT(x * 100 / pZoom)
  sy = INT(y * 100 / pZoom)
  sw = INT(cw * 100 / pZoom) + 2
  sh = INT(ch * 100 / pZoom) + 2
  IF sx + sw > iw THEN sw = iw - sx.
  IF sy + sh > ih THEN sh = ih - sy.
  IF sw < 1 OR sh < 1 THEN RETURN.
  IF ~pSrc.CloneInto(pCv) THEN RETURN.
  pCv.Crop(sx, sy, sw, sh)
  pCv.Resize(INT(sw * pZoom / 100), INT(sh * pZoom / 100), Img:Best)
  pCv.Crop(x - INT(sx * pZoom / 100), y - INT(sy * pZoom / 100), cw, ch)
  pCv.Fit(pW, pH, Img:Centered, 0FFFFFFh)

Hash PROCEDURE(*ImageClass pImg)
x  LONG
y  LONG
v  ULONG
  CODE
  LOOP y = 1 TO 12
    LOOP x = 1 TO 12
      v = BXOR(v * 31, pImg.Pixel(INT(pImg.Wide() * x / 13), INT(pImg.High() * y / 13)))
    END
  END
  RETURN v
