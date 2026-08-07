  PROGRAM
!  Writing a new width back to a LIST is what BrowseGrid does when a column
!  drag ends, and the old list comes back the moment it does. Which of the
!  three things that keep it out of sight does that write destroy?
!
!    hwnd  - is it still the SAME control, or has Clarion rebuilt it?
!    clip  - is WS_CLIPSIBLINGS still on it?
!    zord  - is the region still above it in the child stacking order?
!
!  Answers go in the window title, before and after.
  MAP
Main PROCEDURE
    MODULE('win32')
      GetWindowLongA(ULONG hWnd,LONG idx),LONG,PASCAL,NAME('GetWindowLongA')
      SetWindowLongA(ULONG hWnd,LONG idx,LONG val),LONG,PASCAL,PROC,NAME('SetWindowLongA')
      SetWindowPosA(ULONG hWnd,LONG after,LONG x,LONG y,LONG cx,LONG cy,ULONG f),LONG,PASCAL,PROC,NAME('SetWindowPos')
      GetWindowA(ULONG hWnd,ULONG cmd),ULONG,PASCAL,NAME('GetWindow')
      GetParentA(ULONG hWnd),ULONG,PASCAL,NAME('GetParent')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE

GWL_STYLE     EQUATE(-16)
WS_CLIPSIB    EQUATE(04000000h)
WS_CLIPKIDS   EQUATE(02000000h)
SWP_NOMOVE    EQUATE(0002h)
SWP_NOSIZE    EQUATE(0001h)
GW_CHILD      EQUATE(5)
GW_HWNDNEXT   EQUATE(2)

  CODE
  Main

Main PROCEDURE
Q     QUEUE
f1      STRING(20)
f2      STRING(20)
      END
Win   WINDOW('ClipKeep'),AT(,,300,140),SYSTEM,GRAY,TIMER(100)
        LIST,AT(4,4,290,100),USE(?List),FROM(Q),FORMAT('60L(2)|M~One~60L(2)|M~Two~')
        REGION,AT(4,4,290,100),USE(?Rgn),IMM
      END
hl    ULONG
hr    ULONG
hl2   ULONG
sty   LONG
sty2  LONG
z     LONG
z2    LONG
rankOf  ULONG
ranking LONG
res   CSTRING(160)
ticks LONG
  CODE
  Q.f1 = 'alpha' ; Q.f2 = 'one' ; ADD(Q)
  Q.f1 = 'beta'  ; Q.f2 = 'two' ; ADD(Q)
  OPEN(Win)
  DISPLAY

  hl = ?List{PROP:Handle}
  hr = ?Rgn{PROP:Handle}
!  set it up exactly as BrowseGrid does
  sty = GetWindowLongA(hl, GWL_STYLE)
  SetWindowLongA(hl, GWL_STYLE, BOR(sty, WS_CLIPSIB))
  SetWindowPosA(hr, 0, 0, 0, 0, 0, BOR(SWP_NOMOVE, SWP_NOSIZE))

  sty = GetWindowLongA(hl, GWL_STYLE)
  rankOf = hr ; DO Rank ; z = ranking

!  ...and now do the one thing the end of a column drag does
  ?List{PROPLIST:Width, 1} = 40
  DISPLAY

  hl2  = ?List{PROP:Handle}
  sty2 = GetWindowLongA(hl2, GWL_STYLE)
  rankOf = hr ; DO Rank ; z2 = ranking

  res = 'parent-clipkids ' & CHOOSE(BAND(GetWindowLongA(0{PROP:Handle},GWL_STYLE),WS_CLIPKIDS) <> 0, 'YES', 'NO') |
      & ' hwnd ' & CHOOSE(hl = hl2, 'same', 'REBUILT')             |
      & ' clip ' & CHOOSE(BAND(sty, WS_CLIPSIB) <> 0, '1', '0')   |
      & '>'      & CHOOSE(BAND(sty2, WS_CLIPSIB) <> 0, '1', '0')  |
      & ' zord ' & z & '>' & z2
  Win{PROP:Text} = 'CLIPKEEP ' & CLIP(res)

  ACCEPT
    IF EVENT() = EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  RETURN

!  Which child comes first in the parent's stacking order? First = topmost.
Rank ROUTINE
  DATA
h   ULONG,AUTO
n   LONG,AUTO
  CODE
  ranking = 0
  h = GetWindowA(GetParentA(hl), GW_CHILD)
  n = 0
  LOOP WHILE h AND n < 60
    n += 1
    IF h = rankOf
      ranking = n
      BREAK
    END
    h = GetWindowA(h, GW_HWNDNEXT)
  END
