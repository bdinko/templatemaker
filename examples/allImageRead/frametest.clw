  PROGRAM
!  Walk an animated GIF the way the frame bar does - one-based outside, minus
!  one on the call - and hash a grid of pixels per frame. Different hashes mean
!  LoadFrame really is changing the picture.
  MAP
Main PROCEDURE
Hash PROCEDURE(*ImageClass pImg),ULONG
  END
  INCLUDE('ImageClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win   WINDOW('FrameTest'),AT(,,560,120),SYSTEM,GRAY,TIMER(100)
      END
Pic   ImageClass
n     LONG
i     LONG
h1    ULONG
hx    ULONG
uniq  LONG
seen  CSTRING(400)
prev  ULONG
ticks LONG
  CODE
  OPEN(Win)
  IF ~Pic.LoadFile('C:\clarion12\accessory\template\win\NYS_FlowGraph.gif')
    Win{PROP:Text} = 'FrameTest LOAD-FAILED'
  ELSE
    n = Pic.Frames()
    LOOP i = 1 TO n
      IF i <> 1 AND i <> 2 AND i <> 25 AND i <> 50 AND i <> n THEN CYCLE.
      IF ~Pic.LoadFrame(i - 1)
        seen = CLIP(seen) & ' ' & i & '=FAIL'
        CYCLE
      END
      hx = Hash(Pic)
      seen = CLIP(seen) & ' ' & i & ':' & hx
      IF i = 1 THEN h1 = hx.
      IF hx <> prev AND i <> 1 THEN uniq += 1.
      prev = hx
    END
    Win{PROP:Text} = 'FrameTest frames=' & n & CLIP(seen) &                    |
                     CHOOSE(uniq > 0,' FRAMES-DIFFER',' ALL-IDENTICAL')
  END
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 10 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)

Hash PROCEDURE(*ImageClass pImg)
x  LONG
y  LONG
v  ULONG
  CODE
  LOOP y = 1 TO 8
    LOOP x = 1 TO 8
      v = BXOR(v * 31, pImg.Pixel(INT(pImg.Wide() * x / 9), INT(pImg.High() * y / 9)))
    END
  END
  RETURN v
