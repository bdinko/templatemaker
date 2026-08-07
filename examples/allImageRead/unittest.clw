  PROGRAM
!  Are MOUSEX/GETPOSITION in pixels? The canvas pans in pixels, so if the
!  window's units are something else every drag is scaled wrong. Read the same
!  control both ways and compare.
  MAP
Main PROCEDURE
  END
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win   WINDOW('UnitTest'),AT(,,320,160),SYSTEM,GRAY,TIMER(100)
        IMAGE,AT(4,4,300,140),USE(?Pic)
      END
ux    SIGNED
uy    SIGNED
uw    SIGNED
uh    SIGNED
px    SIGNED
py    SIGNED
pw    SIGNED
ph    SIGNED
save  LONG
ticks LONG
  CODE
  OPEN(Win)
  GETPOSITION(?Pic,ux,uy,uw,uh)                               ! whatever the window uses
  save = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  GETPOSITION(?Pic,px,py,pw,ph)                               ! and in real pixels
  0{PROP:Pixels} = save
  Win{PROP:Text} = 'UnitTest units=' & uw & 'x' & uh & '  pixels=' & pw & 'x' & ph &|
                   '  xscale=' & (pw / uw) & ' yscale=' & (ph / uh) &               |
                   CHOOSE(pw = uw AND ph = uh,' SAME',' DIFFERENT-UNITS')
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 10 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)
