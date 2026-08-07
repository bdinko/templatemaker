  PROGRAM
!  Can a Clarion REGION carry real Windows scrollbars, and do its scroll
!  messages come back to us? Add WS_HSCROLL/WS_VSCROLL to the region built at
!  run time, give the bars a range, subclass it, and count what arrives. The
!  screenshot says whether they are drawn; the title says whether they talk.
  MAP
Main PROCEDURE
    Air_BarProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
    Air_HookBars(LONG),BYTE,PROC
    Air_SetBar(LONG,LONG,LONG,LONG,LONG)
    Air_BarPos(LONG,LONG),LONG
    MODULE('win32')
      apiSetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
      apiGetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
      apiCallWndProc(LONG lpPrev,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
      apiSetWindowLong(ULONG hWnd,LONG nIndex,LONG dwNewLong),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      apiGetWindowLong(ULONG hWnd,LONG nIndex),LONG,PASCAL,NAME('GetWindowLongA')
      apiSetWindowPos(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG flags),LONG,PASCAL,PROC,NAME('SetWindowPos')
      apiSetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
      apiGetScrollInfo(ULONG hWnd,LONG bar,LONG lpsi),LONG,PASCAL,PROC,NAME('GetScrollInfo')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE

Air:Scrolled     EQUATE(EVENT:User + 215)
GWL_STYLE        EQUATE(-16)
GWL_WNDPROC      EQUATE(-4)
WS_HSCROLL       EQUATE(00100000h)
WS_VSCROLL       EQUATE(00200000h)
SWP_FRAMECHANGED EQUATE(0020h)
SWP_NOMOVE       EQUATE(0002h)
SWP_NOSIZE       EQUATE(0001h)
SWP_NOZORDER     EQUATE(0004h)
SB_HORZ          EQUATE(0)
SB_VERT          EQUATE(1)
WM_HSCROLL       EQUATE(0114h)
WM_VSCROLL       EQUATE(0115h)
SIF_RANGE        EQUATE(1)
SIF_PAGE         EQUATE(2)
SIF_POS          EQUATE(4)
SIF_TRACKPOS     EQUATE(10h)

  CODE
  Main

Main PROCEDURE
Win   WINDOW('BarTest'),AT(,,300,200),SYSTEM,GRAY,TIMER(100)
        IMAGE,AT(4,4,290,180),USE(?Pic)
      END
rgn   SIGNED
x     SIGNED
y     SIGNED
w     SIGNED
h     SIGNED
hits  LONG
ticks LONG
  CODE
  OPEN(Win)
  rgn = CREATE(0,CREATE:Region,?Pic{PROP:Parent})
  GETPOSITION(?Pic,x,y,w,h)
  SETPOSITION(rgn,x,y,w,h)
  rgn{PROP:IMM} = 1
  UNHIDE(rgn)
  IF Air_HookBars(rgn{PROP:Handle})
    Air_SetBar(rgn{PROP:Handle},SB_HORZ,0,20,100)             ! pos 0, page 20, max 100
    Air_SetBar(rgn{PROP:Handle},SB_VERT,0,20,100)
  END
  Win{PROP:Text} = 'BarTest hwnd=' & rgn{PROP:Handle} & ' hits=0'
  ACCEPT
    CASE EVENT()
    OF Air:Scrolled
      hits += 1
      Win{PROP:Text} = 'BarTest hwnd=' & rgn{PROP:Handle} & ' hits=' & hits & |
                       ' hpos=' & Air_BarPos(rgn{PROP:Handle},SB_HORZ) &      |
                       ' vpos=' & Air_BarPos(rgn{PROP:Handle},SB_VERT)
    OF EVENT:Timer
      ticks += 1
      IF ticks > 25 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)

!  Give the control the scrollbar styles it was not born with, then subclass it.
Air_HookBars PROCEDURE(LONG pHwnd)
prop CSTRING('AirImgBarProc')
old  LONG,AUTO
sty  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF apiGetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.
  sty = apiGetWindowLong(pHwnd,GWL_STYLE)
  apiSetWindowLong(pHwnd,GWL_STYLE,BOR(BOR(sty,WS_HSCROLL),WS_VSCROLL))
  apiSetWindowPos(pHwnd,0,0,0,0,0,BOR(BOR(BOR(SWP_FRAMECHANGED,SWP_NOMOVE),SWP_NOSIZE),SWP_NOZORDER))
  old = apiSetWindowLong(pHwnd,GWL_WNDPROC,ADDRESS(Air_BarProc))
  IF ~old THEN RETURN 0.
  apiSetProp(pHwnd,ADDRESS(prop),old)
  RETURN 1

Air_SetBar PROCEDURE(LONG pHwnd,LONG pBar,LONG pPos,LONG pPage,LONG pMax)
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
  si.nMax   = pMax
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
  si.fMask  = BOR(SIF_POS,SIF_TRACKPOS)
  IF ~apiGetScrollInfo(pHwnd,pBar,ADDRESS(si)) THEN RETURN -1.
  RETURN si.nPos

Air_BarProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
prop CSTRING('AirImgBarProc')
old  LONG,AUTO
bar  LONG,AUTO
code LONG,AUTO
pos  LONG,AUTO
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
  old = apiGetProp(hWnd,ADDRESS(prop))
  IF wMsg = WM_HSCROLL OR wMsg = WM_VSCROLL
    bar = CHOOSE(wMsg = WM_HSCROLL, SB_HORZ, SB_VERT)
    code = BAND(wParam,0FFFFh)
    si.cbSize = SIZE(si)
    si.fMask  = BOR(BOR(BOR(SIF_RANGE,SIF_PAGE),SIF_POS),SIF_TRACKPOS)
    IF apiGetScrollInfo(hWnd,bar,ADDRESS(si))
      pos = si.nPos
      CASE code
      OF 0 ; pos -= 16                                        ! SB_LINEUP / LINELEFT
      OF 1 ; pos += 16                                        ! SB_LINEDOWN / LINERIGHT
      OF 2 ; pos -= si.nPage                                  ! SB_PAGEUP
      OF 3 ; pos += si.nPage                                  ! SB_PAGEDOWN
      OF 5 ; pos = si.nTrack                                  ! SB_THUMBTRACK
      OF 4 ; pos = si.nTrack                                  ! SB_THUMBPOSITION
      OF 6 ; pos = si.nMin
      OF 7 ; pos = si.nMax
      END
      IF pos < si.nMin THEN pos = si.nMin.
      IF pos > si.nMax - si.nPage + 1 THEN pos = si.nMax - si.nPage + 1.
      si.fMask = SIF_POS
      si.nPos  = pos
      apiSetScrollInfo(hWnd,bar,ADDRESS(si),1)
      POST(Air:Scrolled)
    END
  END
  IF old
    RETURN apiCallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0
