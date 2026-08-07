  PROGRAM
!  What does a Clarion WINDOW actually give back for PROP:WndProc before
!  anything has hooked it - a real window procedure, or nothing? The whole
!  chaining question turns on this.
  MAP
Main PROCEDURE
    MODULE('win32')
      wGetWindowLong(ULONG hWnd,LONG idx),LONG,PASCAL,NAME('GetWindowLongA')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win     WINDOW('ProcTest'),AT(,,240,120),SYSTEM,GRAY,TIMER(100)
          REGION,AT(4,4,230,110),USE(?Rgn)
        END
GWL_WNDPROC EQUATE(-4)
pw      LONG
gw      LONG
pr      LONG
gr      LONG
ticks   LONG
  CODE
  OPEN(Win)
  pw = Win{PROP:WndProc}                                      ! Clarion's answer, window
  gw = wGetWindowLong(Win{PROP:Handle},GWL_WNDPROC)           ! Windows' answer, window
  pr = ?Rgn{PROP:WndProc}                                     ! Clarion's answer, control
  gr = wGetWindowLong(?Rgn{PROP:Handle},GWL_WNDPROC)          ! Windows' answer, control
  Win{PROP:Text} = 'ProcTest winProp=' & pw & ' winApi=' & gw &|
                   ' rgnProp=' & pr & ' rgnApi=' & gr
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)
