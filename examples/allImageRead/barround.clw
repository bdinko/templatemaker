  PROGRAM
!  The invariant the canvas depends on: write the pan into a scrollbar, read it
!  straight back, and get the same number. If Windows clamps it somewhere else
!  the canvas adopts that on the next scroll event and the picture jumps to a
!  place nobody panned to. Walk a range of zooms and pans and count the
!  disagreements.
  MAP
Main PROCEDURE
    Air_SetBar(LONG,LONG,LONG,LONG,LONG)
    Air_BarPos(LONG,LONG),LONG
    MODULE('win32')
      apiSetWindowLong(ULONG hWnd,LONG nIndex,LONG dwNewLong),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      apiGetWindowLong(ULONG hWnd,LONG nIndex),LONG,PASCAL,NAME('GetWindowLongA')
      apiSetWindowPos(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG flags),LONG,PASCAL,PROC,NAME('SetWindowPos')
      apiSetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
      apiGetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi),LONG,PASCAL,PROC,NAME('GetScrollInfo')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE

GWL_STYLE        EQUATE(-16)
WS_HSCROLL       EQUATE(00100000h)
WS_VSCROLL       EQUATE(00200000h)
SWP_FRAMECHANGED EQUATE(0020h)
SWP_NOMOVE       EQUATE(0002h)
SWP_NOSIZE       EQUATE(0001h)
SWP_NOZORDER     EQUATE(0004h)
SB_HORZ          EQUATE(0)
SIF_RANGE        EQUATE(1)
SIF_PAGE         EQUATE(2)
SIF_POS          EQUATE(4)

  CODE
  Main

Main PROCEDURE
Win   WINDOW('BarRound'),AT(,,320,140),SYSTEM,GRAY,TIMER(100)
        IMAGE,AT(4,4,300,120),USE(?Pic)
      END
rgn   SIGNED
x     SIGNED
y     SIGNED
w     SIGNED
h     SIGNED
hwnd  LONG
IW    EQUATE(2400)                                            ! the picture
VW    EQUATE(620)                                             ! the frame
zoom  LONG
pan   LONG
page  LONG
tot   LONG
back  LONG
bad   LONG
tests LONG
worst LONG
note  CSTRING(300)
maxp  LONG
ticks LONG
  CODE
  OPEN(Win)
  rgn = CREATE(0,CREATE:Region,?Pic{PROP:Parent})
  GETPOSITION(?Pic,x,y,w,h)
  SETPOSITION(rgn,x,y,w,h)
  rgn{PROP:IMM} = 1
  UNHIDE(rgn)
  hwnd = rgn{PROP:Handle}
  apiSetWindowLong(hwnd,GWL_STYLE,BOR(BOR(apiGetWindowLong(hwnd,GWL_STYLE),WS_HSCROLL),WS_VSCROLL))
  apiSetWindowPos(hwnd,0,0,0,0,0,BOR(BOR(BOR(SWP_FRAMECHANGED,SWP_NOMOVE),SWP_NOSIZE),SWP_NOZORDER))

!  the graphics-card units: pan in image pixels, page = what the frame shows
  LOOP zoom = 110 TO 800 BY 15
    page = INT(VW * 100 / zoom)
    tot  = IW
    maxp = tot - page                                         ! the furthest the canvas will pan
    LOOP pan = 0 TO maxp BY 37
      Air_SetBar(hwnd,SB_HORZ,pan,page,tot)
      back = Air_BarPos(hwnd,SB_HORZ)
      tests += 1
      IF back <> pan
        bad += 1
        IF ABS(back - pan) > worst
          worst = ABS(back - pan)
          note = ' worst: zoom=' & zoom & ' page=' & page & ' asked=' & pan &  |
                 ' got=' & back
        END
      END
    END
  END
  Win{PROP:Text} = 'BarRound tests=' & tests & ' mismatched=' & bad &          |
                   CLIP(note) & CHOOSE(bad = 0,' ROUND-TRIPS',' DRIFTS')
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 20 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)

Air_SetBar PROCEDURE(LONG pHwnd,LONG pBar,LONG pPos,LONG pPage,LONG pTotal)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  si.cbSize = SIZE(si)
  si.fMask  = BOR(BOR(SIF_RANGE,SIF_PAGE),SIF_POS)
  si.nMin   = 0
  si.nMax   = pTotal - 1
  si.nPage  = pPage
  si.nPos   = pPos
  apiSetScrollInfo(pHwnd,pBar,ADDRESS(si),1)

Air_BarPos PROCEDURE(LONG pHwnd,LONG pBar)
si   GROUP
cbSize  ULONG
fMask   ULONG
nMin    LONG
nMax    LONG
nPage   ULONG
nPos    LONG
nTrack  LONG
     END
  CODE
  si.cbSize = SIZE(si)
  si.fMask  = SIF_POS
  IF ~apiGetScrollInfo(pHwnd,pBar,ADDRESS(si)) THEN RETURN -1.
  RETURN si.nPos
