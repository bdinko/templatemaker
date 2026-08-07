  PROGRAM
!  Is ADDRESS(procedure) the same seen from the program module and from a
!  MEMBER module? The template takes it in a member module for a procedure the
!  global extension writes into the program module.
  MAP
Main PROCEDURE
    MODULE('addrsub')
Sub PROCEDURE(LONG)
    END
    AirImg_WheelProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
  END
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win     WINDOW('AddrTest'),AT(,,320,120),SYSTEM,GRAY,TIMER(100)
        END
here    LONG
ticks   LONG
  CODE
  OPEN(Win)
  here = ADDRESS(AirImg_WheelProc)
  Sub(here)
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)

AirImg_WheelProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
  CODE
  RETURN 0
