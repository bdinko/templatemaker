  PROGRAM
!  Sorting is posted to the LIST as a fake mouse click at the x of the column's
!  heading, because ABC's sort-header class reads PROPLIST:MouseDownField to
!  learn which column was pressed. That arithmetic is fragile and it is failing
!  on the second column.
!
!  So: is PROPLIST:MouseDownField WRITABLE? If it is, the whole coordinate
!  business goes away - set the column, post EVENT:HeaderPressed, done. And
!  does EVENT:HeaderPressed even arrive at a control Windows will not paint?
  MAP
Main PROCEDURE
    MODULE('win32')
      GetWindowLongA(ULONG hWnd,LONG idx),LONG,PASCAL,NAME('GetWindowLongA')
      SetWindowLongA(ULONG hWnd,LONG idx,LONG val),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      SetWindowPosA(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG f),LONG,PASCAL,PROC,NAME('SetWindowPos')
      PostMessageA(ULONG hWnd,ULONG msg,ULONG wp,LONG lp),LONG,PASCAL,PROC,NAME('PostMessageA')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

GWL_STYLE   EQUATE(-16)
WS_VISIBLE  EQUATE(10000000h)
SWP_NOMOVE  EQUATE(0002h)
SWP_NOSIZE  EQUATE(0001h)
SWP_NOZORD  EQUATE(0004h)
SWP_FRAME   EQUATE(0020h)
WM_LDOWN    EQUATE(0201h)
WM_LUP      EQUATE(0202h)
MK_LBUTTON  EQUATE(0001h)

  CODE
  Main

Main PROCEDURE
Q     QUEUE
f1      STRING(20)
f2      STRING(20)
f3      STRING(20)
      END
Win   WINDOW('MdField'),AT(,,320,150),SYSTEM,GRAY,TIMER(20)
        LIST,AT(4,4,310,120),USE(?List),FROM(Q),                                |
             FORMAT('60L(2)|M~One~60L(2)|M~Two~60L(2)|M~Three~')
      END
hl    ULONG
sty   LONG
wrote LONG
back  LONG
hdr   LONG
hdrF  LONG
posted LONG
i     LONG
step  LONG
  CODE
  LOOP i = 1 TO 10
    Q.f1 = 'a' & i ; Q.f2 = 'b' & i ; Q.f3 = 'c' & i ; ADD(Q)
  END
  OPEN(Win)
  DISPLAY
  hl = ?List{PROP:Handle}
!  conceal it exactly as BrowseGrid does
  sty = GetWindowLongA(hl, GWL_STYLE)
  SetWindowLongA(hl, GWL_STYLE, BAND(sty, BXOR(0FFFFFFFFh, WS_VISIBLE)))
  SetWindowPosA(hl, 0, 0, 0, 0, 0, BOR(BOR(SWP_FRAME, SWP_NOMOVE), BOR(SWP_NOSIZE, SWP_NOZORD)))

  ACCEPT
    CASE EVENT()
    OF EVENT:HeaderPressed
      hdr += 1
      hdrF = ?List{PROPLIST:MouseDownField}
    OF EVENT:Timer
      step += 1
      CASE step
      OF 2
!       can it simply be written?
        ?List{PROPLIST:MouseDownField} = 2
        wrote = 1
        back = ?List{PROPLIST:MouseDownField}
        POST(EVENT:HeaderPressed,?List)
      OF 6
!       and does a posted CLICK on a concealed control raise it?
        posted = 1
        PostMessageA(hl, WM_LDOWN, MK_LBUTTON, BSHIFT(4,16) + 130)
        PostMessageA(hl, WM_LUP,   0,          BSHIFT(4,16) + 130)
      OF 10
        Win{PROP:Text} = 'MDFIELD set2>' & back                                |
                       & ' | HeaderPressed n' & hdr & ' field ' & hdrF
      OF 20
        POST(EVENT:CloseWindow)
      END
    END
  END
  RETURN
