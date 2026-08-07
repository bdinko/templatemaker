  PROGRAM
!  The column chooser sets PROPLIST:Width to 0 to hide a column, and nothing
!  happens. The generated code is right, so the question is whether the write
!  takes at all on a LIST that has had WS_VISIBLE stripped off its HWND - which
!  is how BrowseGrid conceals it.
!
!  Writes a width, reads it back, then strips WS_VISIBLE and does it again.
  MAP
Main PROCEDURE
    MODULE('win32')
      GetWindowLongA(ULONG hWnd,LONG idx),LONG,PASCAL,NAME('GetWindowLongA')
      SetWindowLongA(ULONG hWnd,LONG idx,LONG val),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      SetWindowPosA(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG f),LONG,PASCAL,PROC,NAME('SetWindowPos')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('PROPERTY.CLW'),ONCE

GWL_STYLE  EQUATE(-16)
WS_VISIBLE EQUATE(10000000h)
SWP_NOMOVE EQUATE(0002h)
SWP_NOSIZE EQUATE(0001h)
SWP_NOZORD EQUATE(0004h)
SWP_FRAME  EQUATE(0020h)

  CODE
  Main

Main PROCEDURE
Q     QUEUE
f1      STRING(20)
f2      STRING(20)
f3      STRING(20)
      END
Win   WINDOW('WidZero'),AT(,,320,140),SYSTEM,GRAY,TIMER(20)
        LIST,AT(4,4,310,110),USE(?List),FROM(Q),                                |
             FORMAT('60L(2)|M~One~60L(2)|M~Two~60L(2)|M~Three~')
      END
hl    ULONG
sty   LONG
w0    LONG
w1    LONG
w2    LONG
w3    LONG
i     LONG
step  LONG
  CODE
  LOOP i = 1 TO 6
    Q.f1 = 'a' & i ; Q.f2 = 'b' & i ; Q.f3 = 'c' & i ; ADD(Q)
  END
  OPEN(Win)
  DISPLAY
  hl = ?List{PROP:Handle}

  w0 = ?List{PROPLIST:Width,2}                                ! as designed
  ?List{PROPLIST:Width,2} = 0                                 ! hide it while still visible
  w1 = ?List{PROPLIST:Width,2}
  ?List{PROPLIST:Width,2} = w0                                ! put it back

!  now conceal the control exactly as BrowseGrid does
  sty = GetWindowLongA(hl, GWL_STYLE)
  SetWindowLongA(hl, GWL_STYLE, BAND(sty, BXOR(0FFFFFFFFh, WS_VISIBLE)))
  SetWindowPosA(hl, 0, 0, 0, 0, 0, BOR(BOR(SWP_FRAME, SWP_NOMOVE), BOR(SWP_NOSIZE, SWP_NOZORD)))

  w2 = ?List{PROPLIST:Width,2}                                ! still reads?
  ?List{PROPLIST:Width,2} = 0                                 ! and still writes?
  w3 = ?List{PROPLIST:Width,2}

  Win{PROP:Text} = 'WIDZERO visible ' & w0 & '>' & w1                          |
                 & ' | concealed ' & w2 & '>' & w3                             |
                 & CHOOSE(w3 = 0, ' TAKES', ' IGNORED')

  ACCEPT
    IF EVENT() = EVENT:Timer
      step += 1
      IF step > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  RETURN
