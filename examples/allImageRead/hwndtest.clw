  PROGRAM
!  Does a Clarion IMAGE or REGION own a Windows HWND of its own? Direct2D wants
!  one to render into. The answer goes in the window title.
  MAP
Main PROCEDURE
  END
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win     WINDOW('HwndTest'),AT(,,200,120),SYSTEM,GRAY,TIMER(100)
          IMAGE,AT(4,4,90,60),USE(?Pic)
          REGION,AT(100,4,90,60),USE(?Rgn)
        END
rgn2    SIGNED
ticks   LONG
  CODE
  OPEN(Win)
  rgn2 = CREATE(0,CREATE:Region,?Pic{PROP:Parent})             ! one made at run time, as the canvas does
  SETPOSITION(rgn2,4,70,90,40)
  UNHIDE(rgn2)
  Win{PROP:Text} = 'HwndTest win=' & Win{PROP:Handle} &        |
                   ' client=' & Win{PROP:ClientHandle} &       |
                   ' img=' & ?Pic{PROP:Handle} &               |
                   ' rgn=' & ?Rgn{PROP:Handle} &               |
                   ' made=' & rgn2{PROP:Handle}
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)
