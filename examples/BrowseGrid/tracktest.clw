  PROGRAM
!  While a scrollbar thumb is being dragged, Windows runs its OWN message loop
!  inside DefWindowProc. The question BrowseGrid's live-scrolling depends on:
!  does Clarion's ACCEPT get a turn during that loop, or does every POSTed
!  event just queue up until the button comes back up?
!
!  The region's window proc writes S<code> for each WM_VSCROLL it sees and
!  posts an event; the ACCEPT loop writes A when it receives one. Read the
!  order off the title afterwards. S5 S5 S5 ... A A A means nothing can move
!  until the drag ends. S5 A S5 A means it can.
  MAP
Main PROCEDURE
TrackProc PROCEDURE(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
    MODULE('win32')
      GetWindowLongA(ULONG hWnd,LONG idx),LONG,PASCAL,NAME('GetWindowLongA')
      SetWindowLongA(ULONG hWnd,LONG idx,LONG val),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      SetWindowPosA(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG f),LONG,PASCAL,PROC,NAME('SetWindowPos')
      SetScrollInfoA(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
      CallWindowProcA(LONG prev,ULONG hWnd,ULONG msg,ULONG wp,LONG lp),LONG,PASCAL,NAME('CallWindowProcA')
      GetWindowRectA(ULONG hWnd,LONG lpRect),LONG,PASCAL,PROC,NAME('GetWindowRect')
      SetForegroundWindowA(ULONG hWnd),LONG,PASCAL,PROC,NAME('SetForegroundWindow')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE

GWL_STYLE    EQUATE(-16)
GWL_WNDPROC  EQUATE(-4)
WS_VSCROLL   EQUATE(00200000h)
SWP_NOMOVE   EQUATE(0002h)
SWP_NOSIZE   EQUATE(0001h)
SWP_NOZORD   EQUATE(0004h)
SWP_FRAME    EQUATE(0020h)
HWND_TOPMOST EQUATE(-1)
WM_VSCROLL   EQUATE(0115h)
SIF_ALL      EQUATE(17h)
EV:Tick      EQUATE(EVENT:User + 7)

Log      CSTRING(220)                                         ! shared: proc writes, ACCEPT writes
OldProc  LONG
Marked   LONG
Seen     LONG

  CODE
  Main

TrackProc PROCEDURE(ULONG hWnd,ULONG msg,ULONG wp,LONG lp)
  CODE
  Seen += 1
  IF msg = WM_VSCROLL
    IF LEN(Log) < 200
      Log = CLIP(Log) & ' S' & BAND(wp,0FFFFh)
    END
    POST(EV:Tick)
  END
  RETURN CallWindowProcA(OldProc,hWnd,msg,wp,lp)

Main PROCEDURE
Win   WINDOW('TrackTest'),AT(,,300,140),SYSTEM,GRAY,TIMER(50)
        REGION,AT(4,4,290,100),USE(?Rgn),IMM,COLOR(0000FFH)
      END
si    GROUP
cb      ULONG
mask    ULONG
mn      LONG
mx      LONG
pg      ULONG
ps      LONG
tr      LONG
      END
wr    GROUP
l       LONG
t       LONG
r       LONG
b       LONG
      END
hw    ULONG
hr    ULONG
sty   LONG
ticks LONG
  CODE
  OPEN(Win)
  DISPLAY
  hw = 0{PROP:Handle}
  hr = ?Rgn{PROP:Handle}
  SetWindowPosA(hw, HWND_TOPMOST, 0, 0, 0, 0, BOR(SWP_NOMOVE, SWP_NOSIZE))
  SetForegroundWindowA(hw)
!  a vertical scrollbar on the region, subclassed - exactly as BrowseGrid does
  sty = GetWindowLongA(hr, GWL_STYLE)
  SetWindowLongA(hr, GWL_STYLE, BOR(sty, WS_VSCROLL))
  SetWindowPosA(hr, 0, 0, 0, 0, 0, BOR(BOR(SWP_FRAME, SWP_NOMOVE), BOR(SWP_NOSIZE, SWP_NOZORD)))
  si.cb = SIZE(si) ; si.mask = SIF_ALL
  si.mn = 0 ; si.mx = 999 ; si.pg = 40 ; si.ps = 0
  SetScrollInfoA(hr, 1, ADDRESS(si), 1)
  OldProc = SetWindowLongA(hr, GWL_WNDPROC, ADDRESS(TrackProc))

  GetWindowRectA(hr, ADDRESS(wr))
  Win{PROP:Text} = 'TRACKREADY ' & wr.l & ',' & wr.t & ',' & wr.r & ',' & wr.b

  ACCEPT
    CASE EVENT()
    OF EV:Tick
      IF LEN(Log) < 200
        Log = CLIP(Log) & ' A'
      END
      Marked = 1
    OF EVENT:Timer
      ticks += 1
      Win{PROP:Text} = 'TRACKLOG n' & Seen & CLIP(Log)
      IF ticks > 100 THEN POST(EVENT:CloseWindow).
    END
  END
  SetWindowLongA(hr, GWL_WNDPROC, OldProc)
  RETURN
