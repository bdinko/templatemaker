  PROGRAM
!  Resizing a column changes the total column width, which can make the
!  horizontal scrollbar appear or disappear. A scrollbar going away off a child
!  window GROWS its client area - and if nothing redraws what is in it, the
!  strip the bar vacated shows whatever is underneath. Underneath is the list.
!
!  A red region is put over a list exactly as BrowseGrid does it. The pixel in
!  the middle and the pixel in the strip the bar had are read back with the bar
!  on, and again with it off. Red means the grid still covers the list.
  MAP
Main PROCEDURE
    MODULE('win32')
      GetWindowLongA(ULONG hWnd,LONG idx),LONG,PASCAL,NAME('GetWindowLongA')
      SetWindowLongA(ULONG hWnd,LONG idx,LONG val),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      SetWindowPosA(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG f),LONG,PASCAL,PROC,NAME('SetWindowPos')
      SetScrollInfoA(ULONG hWnd,LONG bar,LONG lpsi,LONG redraw),LONG,PASCAL,PROC,NAME('SetScrollInfo')
      SetForegroundWindowA(ULONG hWnd),LONG,PASCAL,PROC,NAME('SetForegroundWindow')
      GetClientRectA(ULONG hWnd,LONG lpRect),LONG,PASCAL,PROC,NAME('GetClientRect')
      GetDCA(ULONG hWnd),ULONG,PASCAL,NAME('GetDC')
      ReleaseDCA(ULONG hWnd,ULONG hdc),LONG,PASCAL,PROC,NAME('ReleaseDC')
      GetPixelA(ULONG hdc,LONG x,LONG y),ULONG,PASCAL,NAME('GetPixel')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE

GWL_STYLE    EQUATE(-16)
WS_CLIPSIB   EQUATE(04000000h)
WS_HSCROLL   EQUATE(00100000h)
WS_VSCROLL   EQUATE(00200000h)
SWP_NOMOVE   EQUATE(0002h)
SWP_NOSIZE   EQUATE(0001h)
SWP_NOZORD   EQUATE(0004h)
SWP_FRAME    EQUATE(0020h)
HWND_TOPMOST EQUATE(-1)
SIF_ALL      EQUATE(17h)

  CODE
  Main

Main PROCEDURE
Q     QUEUE
f1      STRING(20)
f2      STRING(20)
      END
Win   WINDOW('ClipShot'),AT(,,300,140),SYSTEM,GRAY,TIMER(20)
        LIST,AT(4,4,290,100),USE(?List),FROM(Q),FORMAT('60L(2)|M~One~60L(2)|M~Two~')
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
cr    GROUP                                                   ! the region's CLIENT rect
l       LONG
t       LONG
r       LONG
b       LONG
      END
hw    ULONG
hl    ULONG
hr    ULONG
sty   LONG
dc    ULONG
i     LONG
rx    SIGNED,AUTO
ry    SIGNED,AUTO
rw    SIGNED,AUTO
rh    SIGNED,AUTO
midX  LONG
midY  LONG
botY  LONG
onH   LONG
onMid ULONG
onBot ULONG
ofMid ULONG
ofBot ULONG
step  LONG
  CODE
  LOOP i = 1 TO 12
    Q.f1 = 'row ' & i ; Q.f2 = 'value ' & i ; ADD(Q)
  END
  OPEN(Win)
  DISPLAY
  hw = 0{PROP:Handle}
  hl = ?List{PROP:Handle}
  hr = ?Rgn{PROP:Handle}
  SetWindowPosA(hw, HWND_TOPMOST, 0, 0, 0, 0, BOR(SWP_NOMOVE, SWP_NOSIZE))
  SetForegroundWindowA(hw)
!  exactly what BG:Place does
  sty = GetWindowLongA(hl, GWL_STYLE)
  SetWindowLongA(hl, GWL_STYLE, BOR(sty, WS_CLIPSIB))
  SetWindowPosA(hr, 0, 0, 0, 0, 0, BOR(SWP_NOMOVE, SWP_NOSIZE))
!  and what BG:Setup does - scrollbars on the region
  sty = GetWindowLongA(hr, GWL_STYLE)
  SetWindowLongA(hr, GWL_STYLE, BOR(BOR(sty, WS_HSCROLL), WS_VSCROLL))
  SetWindowPosA(hr, 0, 0, 0, 0, 0, BOR(BOR(SWP_FRAME, SWP_NOMOVE), BOR(SWP_NOSIZE, SWP_NOZORD)))

  0{PROP:Pixels} = 1
  GETPOSITION(?Rgn, rx, ry, rw, rh)
  0{PROP:Pixels} = 0
  midX = rx + 40
  midY = ry + 40
  botY = ry + rh - 6                                          ! the strip the h-bar sits in

  ACCEPT
    IF EVENT() = EVENT:Timer
      step += 1
      CASE step
      OF 2                                                    ! bar ON - the columns are wide
        si.cb = SIZE(si) ; si.mask = SIF_ALL
        si.mn = 0 ; si.mx = 999 ; si.pg = 100 ; si.ps = 0
        SetScrollInfoA(hr, 0, ADDRESS(si), 1)
      OF 4
        GetClientRectA(hr, ADDRESS(cr))
        onH = cr.b
        dc = GetDCA(hw)
        onMid = GetPixelA(dc, midX, midY)
        onBot = GetPixelA(dc, midX, botY)
        ReleaseDCA(hw, dc)
      OF 6                                                    ! bar OFF - a column got narrower
        si.cb = SIZE(si) ; si.mask = SIF_ALL
        si.mn = 0 ; si.mx = 0 ; si.pg = 1 ; si.ps = 0
        SetScrollInfoA(hr, 0, ADDRESS(si), 1)
      OF 9
        GetClientRectA(hr, ADDRESS(cr))
        dc = GetDCA(hw)
        ofMid = GetPixelA(dc, midX, midY)
        ofBot = GetPixelA(dc, midX, botY)
        ReleaseDCA(hw, dc)
        Win{PROP:Text} = 'CLIPSHOT client ' & onH & '>' & cr.b                    |
              & ' | mid ' & CHOOSE(onMid = 0FFh, 'red', 'NOT(' & onMid & ')')     |
              & '>'       & CHOOSE(ofMid = 0FFh, 'red', 'NOT(' & ofMid & ')')     |
              & ' | strip ' & CHOOSE(onBot = 0FFh, 'red', 'NOT(' & onBot & ')')   |
              & '>'         & CHOOSE(ofBot = 0FFh, 'red', 'NOT(' & ofBot & ')')
      OF 18
        POST(EVENT:CloseWindow)
      END
    END
  END
  RETURN
