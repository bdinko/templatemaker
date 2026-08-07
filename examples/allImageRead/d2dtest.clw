  PROGRAM
!  Proves d2dcanvas.c end to end, without a human: make a picture with
!  ImageClass, save it as a 32-bit BMP, attach the canvas to a REGION's own
!  HWND, upload it, then zoom hard and time it. Everything lands in the window
!  title, which the driver script reads back.
  MAP
Main PROCEDURE
    MODULE('d2dcanvas.c')
      d2c_Available(),LONG,NAME('_d2c_Available')
      d2c_Attach(LONG hwnd),LONG,NAME('_d2c_Attach')
      d2c_Detach(LONG h),NAME('_d2c_Detach')
      d2c_LoadBmp(LONG h,*CSTRING path),LONG,RAW,NAME('_d2c_LoadBmp')
      d2c_SetView(LONG h,REAL zoom,REAL panX,REAL panY,ULONG bg,LONG smooth),NAME('_d2c_SetView')
      d2c_Resize(LONG h),LONG,NAME('_d2c_Resize')
      d2c_ImageW(LONG h),LONG,NAME('_d2c_ImageW')
      d2c_ImageH(LONG h),LONG,NAME('_d2c_ImageH')
      d2c_HasImage(LONG h),LONG,NAME('_d2c_HasImage')
      d2c_ViewW(LONG h),LONG,NAME('_d2c_ViewW')
      d2c_ViewH(LONG h),LONG,NAME('_d2c_ViewH')
      d2c_Clear(LONG h),NAME('_d2c_Clear')
      d2c_PaintNow(LONG h),LONG,NAME('_d2c_PaintNow')
    END
  END
  INCLUDE('ImageClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  PRAGMA('compile(d2dcanvas.c)')

  CODE
  Main

Main PROCEDURE
Win     WINDOW('D2DTest'),AT(,,320,240),SYSTEM,GRAY,TIMER(100)
          IMAGE,AT(4,4,312,232),USE(?Pic)
        END
Pic     ImageClass
Work    ImageClass
zwas    REAL
znow    REAL
zpanX   REAL
zmx     REAL
zbefore REAL
zafter  REAL
zworst  REAL
zn      LONG
zspot   REAL
rgn     SIGNED
x       SIGNED
y       SIGNED
w       SIGNED
h       SIGNED
cv      LONG
gpu     LONG
cpu     LONG
bmp     CSTRING(261)
ok      LONG
t0      LONG
t1      LONG
n       LONG
z       REAL
ticks   LONG
note    CSTRING(200)
  CODE
  OPEN(Win)
  note = 'D2DTest '
! ---- is Direct2D there at all? --------------------------------------------
  IF ~d2c_Available()
    Win{PROP:Text} = 'D2DTest NO-D2D'
  ELSE
! ---- a picture, straight from the engine, out as a 32-bit BMP -------------
    IF ~Pic.TestCard(2400, 1800)
      Win{PROP:Text} = 'D2DTest NO-CARD'
    ELSE
      Pic.BmpBits = 32
      bmp = 'd2dtest_src.bmp'
      IF ~Pic.SaveFile(bmp, Img:Bmp)
        Win{PROP:Text} = 'D2DTest NO-BMP'
      ELSE
! ---- attach to the REGION's own window and upload ----------------------
!  the canvas the template builds: a REGION made at run time over the IMAGE
        rgn = CREATE(0,CREATE:Region,?Pic{PROP:Parent})
        GETPOSITION(?Pic,x,y,w,h)
        SETPOSITION(rgn,x,y,w,h)
        UNHIDE(rgn)
        HIDE(?Pic)
        cv = d2c_Attach(rgn{PROP:Handle})
        IF ~cv
          Win{PROP:Text} = 'D2DTest NO-ATTACH'
        ELSIF ~d2c_LoadBmp(cv, bmp)
          Win{PROP:Text} = 'D2DTest NO-UPLOAD'
        ELSE
! ---- 200 zoom steps, timed. On the CPU path each one of these would
!      resample the whole 2400x1800 picture; here it is a matrix.
! ---- GPU: 300 real frames, each one a zoom step actually drawn -------
          t0 = CLOCK()
          LOOP n = 1 TO 300
            z = 1.0 + (n / 60)
            d2c_SetView(cv, z, n, n, 0FFFFFFh, 1)
            d2c_PaintNow(cv)
          END
          t1 = CLOCK()
          gpu = t1 - t0
! ---- CPU: the same zoom steps the old way, 10 of them ---------------
          t0 = CLOCK()
          LOOP n = 1 TO 10
            z = 1.0 + (n / 60)
            IF Pic.CloneInto(Work)
              Work.Zoom(z * 100, Img:Best)
              IF Work.Wide() > 620 AND Work.High() > 460
                Work.Crop(n, n, 620, 460)
              END
              Work.SaveFile('d2dtest_cpu.png', Img:Png)
            END
          END
          t1 = CLOCK()
          cpu = t1 - t0
! ---- the zoom-about-the-pointer arithmetic, exactly as the template emits
!      it: the image pixel under the spot must not move when the zoom does.
          zworst = 0
          LOOP zn = 1 TO 60
            zspot = (zn % 11) / 10                            ! spots across the canvas
            zmx   = zspot * 624
            zwas  = 0.2 + (zn / 40)
            zpanX = zn * 3
            zbefore = zpanX + zmx / zwas                      ! image pixel under the spot
            znow  = zwas * 1.25                               ! one step in, 25 per cent
            zpanX += zmx / zwas - zmx / znow                  ! the emitted formula
            zafter  = zpanX + zmx / znow
            IF ABS(zafter - zbefore) > zworst
              zworst = ABS(zafter - zbefore)
            END
          END
! ---- leave it fitted to the frame, so a screenshot shows the picture --
          z = d2c_ViewW(cv) / d2c_ImageW(cv)
          IF (d2c_ViewH(cv) / d2c_ImageH(cv)) < z
            z = d2c_ViewH(cv) / d2c_ImageH(cv)
          END
          d2c_SetView(cv, z, 0, 0, 0FFFFFFh, 1)
          d2c_PaintNow(cv)
          note = 'D2DTest OK img=' & d2c_ImageW(cv) & 'x' & d2c_ImageH(cv) &|
                 ' view=' & d2c_ViewW(cv) & 'x' & d2c_ViewH(cv) &           |
                 ' GPU300=' & gpu & 'cs CPU10=' & cpu & 'cs' &                |
                 ' spotdrift=' & FORMAT(zworst,@n9.6) &                       |
                 CHOOSE(zworst < 0.001,' PASS',' FAIL')
          Win{PROP:Text} = note
        END
      END
    END
  END
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 15 THEN POST(EVENT:CloseWindow).
    END
  END
  IF cv THEN d2c_Detach(cv).
  CLOSE(Win)
