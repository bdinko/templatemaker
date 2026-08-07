  PROGRAM
!  Three fixes have now failed to stop the LIST painting through the grid, so
!  the question is no longer "which paint path did I miss" but "can the LIST be
!  stopped from painting at all, while Clarion still believes it is visible?"
!
!  HIDE() is no good - ABC reads the control's state to work out how many rows
!  to load, and a hidden browse decides it has none. But WS_VISIBLE is a
!  WINDOWS flag. Strip it off the HWND directly and Windows stops painting and
!  hit-testing the control, while PROP:Hide, the queue and everything ABC looks
!  at are untouched.
!
!  This is the faithful arrangement: a SHEET with a TAB, the LIST inside it,
!  and the region created the way the template creates it.
  MAP
Main PROCEDURE
    MODULE('win32')
      GetWindowLongA(ULONG hWnd,LONG idx),LONG,PASCAL,NAME('GetWindowLongA')
      SetWindowLongA(ULONG hWnd,LONG idx,LONG val),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      SetWindowPosA(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG f),LONG,PASCAL,PROC,NAME('SetWindowPos')
      SetForegroundWindowA(ULONG hWnd),LONG,PASCAL,PROC,NAME('SetForegroundWindow')
      GetParentA(ULONG hWnd),ULONG,PASCAL,NAME('GetParent')
      GetWindowRectA(ULONG hWnd,LONG lpRect),LONG,PASCAL,PROC,NAME('GetWindowRect')
      IsWindowVisibleA(ULONG hWnd),LONG,PASCAL,NAME('IsWindowVisible')
      GetDCA(ULONG hWnd),ULONG,PASCAL,NAME('GetDC')
      ReleaseDCA(ULONG hWnd,ULONG hdc),LONG,PASCAL,PROC,NAME('ReleaseDC')
      GetPixelA(ULONG hdc,LONG x,LONG y),ULONG,PASCAL,NAME('GetPixel')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

GWL_STYLE    EQUATE(-16)
WS_VISIBLE   EQUATE(10000000h)
WS_CLIPSIB   EQUATE(04000000h)
SWP_NOMOVE   EQUATE(0002h)
SWP_NOSIZE   EQUATE(0001h)
SWP_NOZORD   EQUATE(0004h)
SWP_FRAME    EQUATE(0020h)
HWND_TOPMOST EQUATE(-1)

  CODE
  Main

Main PROCEDURE
Q     QUEUE
f1      STRING(20)
f2      STRING(20)
      END
Win   WINDOW('NoVis'),AT(,,320,170),SYSTEM,GRAY,TIMER(20)
        SHEET,AT(2,2,316,140),USE(?Sheet)
          TAB('by Name'),USE(?Tab1)
            LIST,AT(6,20,306,116),USE(?List),FROM(Q),FORMAT('80L(2)|M~One~80L(2)|M~Two~')
          END
        END
      END
wr    GROUP
l       LONG
t       LONG
r       LONG
b       LONG
      END
Rgn   SIGNED
hw    ULONG
hl    ULONG
hr    ULONG
sty   LONG
dc    ULONG
x     SIGNED,AUTO
y     SIGNED,AUTO
w     SIGNED,AUTO
h     SIGNED,AUTO
sameP LONG
vis0  LONG
vis1  LONG
hid0  LONG
hid1  LONG
recs  LONG
ch0   LONG
ch1   LONG
chV0  LONG
chV1  LONG
pxA   ULONG
pxB   ULONG
step  LONG
res   CSTRING(240)
  CODE
  LOOP x = 1 TO 20
    Q.f1 = 'name ' & x ; Q.f2 = 'town ' & x ; ADD(Q)
  END
  OPEN(Win)
  DISPLAY
  hw = 0{PROP:Handle}
  SetWindowPosA(hw, HWND_TOPMOST, 0, 0, 0, 0, BOR(SWP_NOMOVE, SWP_NOSIZE))
  SetForegroundWindowA(hw)

!  the region, created exactly as the template creates it
  Rgn = CREATE(0,CREATE:Region,?List{PROP:Parent})
  Rgn{PROP:IMM} = 1
  GETPOSITION(?List,x,y,w,h)
  SETPOSITION(Rgn,x,y,w,h)
  Rgn{PROP:Fill} = 0000FFH                                    ! solid red, like the grid would be
  UNHIDE(Rgn)

  hl = ?List{PROP:Handle}
  hr = Rgn{PROP:Handle}
  sameP = CHOOSE(GetParentA(hl) = GetParentA(hr), 1, 0)
  sty = GetWindowLongA(hl, GWL_STYLE)
  SetWindowLongA(hl, GWL_STYLE, BOR(sty, WS_CLIPSIB))
  SetWindowPosA(hr, 0, 0, 0, 0, 0, BOR(SWP_NOMOVE, SWP_NOSIZE))

  vis0 = IsWindowVisibleA(hl)
  hid0 = ?List{PROP:Hide}

  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      step += 1
      CASE step
      OF 1
        SELECT(?List)
        ?List{PROP:Selected} = 2
        chV0 = CHOICE(?List)
        PRESSKEY(DownKey)                                     ! control arm: still visible
      OF 2
        chV1 = CHOICE(?List)
      OF 3
!       take the WINDOWS visibility away - not Clarion's
        sty = GetWindowLongA(hl, GWL_STYLE)
        SetWindowLongA(hl, GWL_STYLE, BAND(sty, BXOR(0FFFFFFFFh, WS_VISIBLE)))
        SetWindowPosA(hl, 0, 0, 0, 0, 0, BOR(BOR(SWP_FRAME, SWP_NOMOVE), BOR(SWP_NOSIZE, SWP_NOZORD)))
        SELECT(?List)                                         ! the very thing that made it paint
        DISPLAY
      OF 4
        SELECT(?List)
        ?List{PROP:Selected} = 2
        ch0 = CHOICE(?List)
        PRESSKEY(DownKey)                                     ! can an invisible control still take it?
      OF 6
        ch1 = CHOICE(?List)
        vis1 = IsWindowVisibleA(hl)
        hid1 = ?List{PROP:Hide}
        recs = RECORDS(Q)
!       read the real screen, not the parent's DC - child areas are cut out of that
        GetWindowRectA(hr, ADDRESS(wr))
        dc = GetDCA(0)
        pxA = GetPixelA(dc, wr.l + 30, wr.t + 20)
        pxB = GetPixelA(dc, wr.l + 30, wr.t + 60)
        ReleaseDCA(0, dc)
        res = 'sameparent ' & sameP                                            |
            & ' | winvis ' & vis0 & '>' & vis1                                 |
            & ' | PROP:Hide ' & hid0 & '>' & hid1                              |
            & ' | recs ' & recs & ' | visible ' & chV0 & '>' & chV1 & ' | concealed ' & ch0 & '>' & ch1                                                |
            & ' | px ' & CHOOSE(pxA = 0FFh,'red','NOT') & CHOOSE(pxB = 0FFh,'red','NOT')
        Win{PROP:Text} = 'NOVIS ' & CLIP(res)
      OF 20
        POST(EVENT:CloseWindow)
      END
    END
  END
  RETURN
