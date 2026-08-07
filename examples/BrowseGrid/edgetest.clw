  PROGRAM
!  Does d2g_HitEdge find the right column edge - and, crucially, does it get
!  the FROZEN ones right? A frozen edge never moves; a scrolling edge that has
!  slid under the frozen block must not be grabbable, or you would be dragging
!  a column you cannot see. Answers go in the window title.
  MAP
Main PROCEDURE
    MODULE('d2grid.c')
      d2g_Available(),LONG,NAME('_d2g_Available')
      d2g_Attach(LONG hwnd,*CSTRING face,LONG pt),LONG,RAW,NAME('_d2g_Attach')
      d2g_Columns(LONG h,LONG n),NAME('_d2g_Columns')
      d2g_Column(LONG h,LONG col,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_Column')
      d2g_Frozen(LONG h,LONG n),NAME('_d2g_Frozen')
      d2g_ScrollX(LONG h,LONG x),NAME('_d2g_ScrollX')
      d2g_HitEdge(LONG h,LONG x),LONG,NAME('_d2g_HitEdge')
      d2g_ColWidth(LONG h,LONG col),LONG,NAME('_d2g_ColWidth')
      d2g_SetWidth(LONG h,LONG col,LONG width),NAME('_d2g_SetWidth')
      d2g_HdrHeight(LONG h),LONG,NAME('_d2g_HdrHeight')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  PRAGMA('compile(d2grid.c)')

  CODE
  Main

Main PROCEDURE
Win   WINDOW('EdgeTest'),AT(,,300,120),SYSTEM,GRAY,TIMER(100)
        REGION,AT(4,4,292,92),USE(?Grid),IMM
      END
g     LONG
face  CSTRING(32)
t     CSTRING(16)
res   CSTRING(250)
nm    CSTRING(8)
got   LONG
want  LONG
bad   LONG
ticks LONG
  CODE
  OPEN(Win)
  face = 'Segoe UI'
  g = d2g_Attach(?Grid{PROP:Handle}, face, 9)
  IF ~g
    Win{PROP:Text} = 'EdgeTest NO-ATTACH'
  ELSE
    d2g_Columns(g, 5)
    t = 'a' ; d2g_Column(g, 0, 150, 0, t)
    t = 'b' ; d2g_Column(g, 1, 120, 0, t)
    t = 'c' ; d2g_Column(g, 2, 100, 0, t)
    t = 'd' ; d2g_Column(g, 3,  90, 0, t)
    t = 'e' ; d2g_Column(g, 4, 110, 0, t)
    d2g_Frozen(g, 2)                                          ! the frozen block is 150+120 = 270 wide

!   ---- not scrolled ----------------------------------------------------
    d2g_ScrollX(g, 0)
    res = 'unscrolled'
    nm = 'f0'   ; got = d2g_HitEdge(g, 150) ; want =  0 ; DO Check   ! first frozen edge
    nm = 'f1'   ; got = d2g_HitEdge(g, 270) ; want =  1 ; DO Check   ! the seam
    nm = 's2'   ; got = d2g_HitEdge(g, 370) ; want =  2 ; DO Check   ! a scrolling edge
    nm = 'mid'  ; got = d2g_HitEdge(g, 200) ; want = -1 ; DO Check   ! nothing to grab
    nm = 'near' ; got = d2g_HitEdge(g, 372) ; want =  2 ; DO Check   ! inside the grab margin
    nm = 'far'  ; got = d2g_HitEdge(g, 376) ; want = -1 ; DO Check   ! outside it

!   ---- scrolled 170 sideways -------------------------------------------
    d2g_ScrollX(g, 170)
    res = CLIP(res) & ' scrolled'
    nm = 'fz0'  ; got = d2g_HitEdge(g, 150) ; want =  0 ; DO Check   ! frozen edges do not move
    nm = 'fz1'  ; got = d2g_HitEdge(g, 270) ; want =  1 ; DO Check
    nm = 'hid'  ; got = d2g_HitEdge(g, 200) ; want = -1 ; DO Check   ! col2 has slid under them
    nm = 'sc3'  ; got = d2g_HitEdge(g, 290) ; want =  3 ; DO Check   ! and the rest moved left
    nm = 'sc4'  ; got = d2g_HitEdge(g, 400) ; want =  4 ; DO Check

!   ---- widths -----------------------------------------------------------
    res = CLIP(res) & ' widths'
    nm = 'rd'   ; got = d2g_ColWidth(g, 1)  ; want = 120 ; DO Check  ! read back
    d2g_SetWidth(g, 1, 200)
    nm = 'set'  ; got = d2g_ColWidth(g, 1)  ; want = 200 ; DO Check  ! and set
    d2g_SetWidth(g, 1, 3)
    nm = 'min'  ; got = d2g_ColWidth(g, 1)  ; want =  16 ; DO Check  ! never to nothing
    got = CHOOSE(d2g_HdrHeight(g) > 0, 1, 0)
    nm = 'hdr'  ; want = 1 ; DO Check                                ! there is a header to grab in

    Win{PROP:Text} = CHOOSE(bad = 0, 'EDGE-PASS ', 'EDGE-FAIL ') & CLIP(res)
  END
  ACCEPT
    IF EVENT() = EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  RETURN

Check ROUTINE
  IF got = want
    res = CLIP(res) & '.'
  ELSE
    res = CLIP(res) & '[' & CLIP(nm) & ' got' & got & ' want' & want & ']'
    bad += 1
  END
