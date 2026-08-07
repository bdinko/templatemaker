  PROGRAM
!  Can d2grid.c actually draw a grid - header, banded rows, gridlines, a
!  selected row, a frozen first column - with real text, into an ordinary
!  Clarion REGION? Fill it with made-up rows and take its picture.
  MAP
Main PROCEDURE
    MODULE('d2grid.c')
      d2g_Available(),LONG,NAME('_d2g_Available')
      d2g_Attach(LONG hwnd,*CSTRING face,LONG pt),LONG,RAW,NAME('_d2g_Attach')
      d2g_Detach(LONG h),NAME('_d2g_Detach')
      d2g_Columns(LONG h,LONG n),NAME('_d2g_Columns')
      d2g_Column(LONG h,LONG col,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_Column')
      d2g_Frozen(LONG h,LONG n),NAME('_d2g_Frozen')
      d2g_RowHeight(LONG h,LONG px),NAME('_d2g_RowHeight')
      d2g_Total(LONG h,LONG n),NAME('_d2g_Total')
      d2g_Select(LONG h,LONG row),NAME('_d2g_Select')
      d2g_Page(LONG h,LONG firstRow,LONG rows),NAME('_d2g_Page')
      d2g_Cell(LONG h,LONG visRow,LONG col,*CSTRING s),RAW,NAME('_d2g_Cell')
      d2g_Repaint(LONG h),NAME('_d2g_Repaint')
      d2g_PaintNow(LONG h),LONG,NAME('_d2g_PaintNow')
      d2g_PageSize(LONG h),LONG,NAME('_d2g_PageSize')
      d2g_Resize(LONG h),LONG,NAME('_d2g_Resize')
      d2g_ScrollY(LONG h,LONG y),NAME('_d2g_ScrollY')
      d2g_ScrollX(LONG h,LONG x),NAME('_d2g_ScrollX')
      d2g_RowH(LONG h),LONG,NAME('_d2g_RowH')
      d2g_VBar(LONG h,LONG show,LONG pos,LONG pct),NAME('_d2g_VBar')
      d2g_VHit(LONG h,LONG x,LONG y),LONG,NAME('_d2g_VHit')
      d2g_FontSize(LONG h,LONG pt),LONG,PROC,NAME('_d2g_FontSize')
      d2g_RowNeed(LONG h),LONG,NAME('_d2g_RowNeed')
      d2g_ColWidth(LONG h,LONG col),LONG,NAME('_d2g_ColWidth')
      d2g_BarStyle(LONG h,LONG style),NAME('_d2g_BarStyle')
      d2g_HBar(LONG h,LONG show,LONG pos,LONG page,LONG total),NAME('_d2g_HBar')
      d2g_BarsShow(LONG h,LONG on),NAME('_d2g_BarsShow')
      d2g_FilterBtns(LONG h,LONG on),NAME('_d2g_FilterBtns')
      d2g_FilterOn(LONG h,LONG col,LONG on),NAME('_d2g_FilterOn')
      d2g_SortMark(LONG h,LONG col,LONG dir),NAME('_d2g_SortMark')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  PRAGMA('compile(d2grid.c)')

  CODE
  Main

Main PROCEDURE
Win     WINDOW('GridTest'),AT(,,520,300),SYSTEM,GRAY,RESIZE,TIMER(100)
          REGION,AT(4,4,512,272),USE(?Grid),IMM
        END
g       LONG
face    CSTRING(32)
title   CSTRING(64)
cell    CSTRING(64)
i       LONG
n       LONG
t8      LONG
t3      LONG
page    LONG
ticks   LONG
big     LONG
small   LONG
w9      LONG
w18     LONG
wback   LONG
towns   STRING('Leeds    Bristol  Madrid   Oporto   Cardiff  Bergen   Toledo   Dundee   ')
  CODE
  OPEN(Win)
  IF ~d2g_Available()
    Win{PROP:Text} = 'GridTest NO-D2D'
  ELSE
    face = 'Segoe UI'
    g = d2g_Attach(?Grid{PROP:Handle}, face, 9)
    IF ~g
      Win{PROP:Text} = 'GridTest NO-ATTACH'
    ELSE
      d2g_Columns(g, 5)
      title = 'Customer'  ; d2g_Column(g, 0, 150, 0, title)
      title = 'Town'      ; d2g_Column(g, 1, 110, 0, title)
      title = 'Credit'    ; d2g_Column(g, 2,  90, 1, title)
      title = 'Orders'    ; d2g_Column(g, 3,  70, 1, title)
      title = 'Status'    ; d2g_Column(g, 4, 120, 0, title)
      d2g_Frozen(g, 2)
!     Grow, squash, then shrink again - the rows must come back DOWN
      w9  = d2g_ColWidth(g, 0)                                ! Customer at 9 point
      d2g_FontSize(g, 18)
      w18 = d2g_ColWidth(g, 0)                                ! ...and at 18
      d2g_RowHeight(g, 16)                                    ! the LIST tries to squash it
      big = d2g_RowH(g)
      d2g_FontSize(g, 9)                                      ! Ctrl-wheel the other way
      small = d2g_RowH(g)
      wback = d2g_ColWidth(g, 0)                              ! and back where it started?
      d2g_BarStyle(g, 1)                                      ! Slim
      d2g_HBar(g, 1, 120, 400, 900)
      d2g_VBar(g, 1, 40, 12)                                  ! the drawn thumb, 40 pct down                                        ! two columns stay put
      d2g_RowHeight(g, 22)
      d2g_Total(g, 5000)
      d2g_Select(g, 3)                                        ! fourth row highlighted
      page = d2g_PageSize(g)
      IF page > 40 THEN page = 40.
      d2g_Page(g, 0, page)
      LOOP i = 0 TO page - 1
        n = i + 1
        cell = 'Customer ' & CLIP(LEFT(FORMAT(1000 + n, @n4)))
        d2g_Cell(g, i, 0, cell)
        cell = CLIP(towns[ (1 + t8 * 9) : (9 + t8 * 9) ])
        d2g_Cell(g, i, 1, cell)
        cell = FORMAT(n * 137, @n11.2)
        d2g_Cell(g, i, 2, cell)
        cell = FORMAT(n * 3, @n5)
        d2g_Cell(g, i, 3, cell)
        cell = CHOOSE(1 + t3, 'Active', 'On hold', 'Closed')
        t8 += 1 ; IF t8 > 7 THEN t8 = 0.
        t3 += 1 ; IF t3 > 2 THEN t3 = 0.
        d2g_Cell(g, i, 4, cell)
      END
      d2g_ScrollY(g, 11)                                      ! half a row: the top record is sliced
      d2g_FilterBtns(g, 1)
      d2g_FilterOn(g, 0, 1)                                   ! Customer filtered...
      d2g_FilterOn(g, 2, 1)                                   ! ...and Status too
      d2g_SortMark(g, 1, 1)                                   ! Town, ascending
      d2g_ScrollX(g, 0)                                     ! scrolled sideways, under the frozen pair
      d2g_PaintNow(g)
      Win{PROP:Text} = 'GridTest grew=' & big & ' shrank=' & small & ' col ' & w9 & '>' & w18 & '>' & wback |
                     & ' rows=' & page & ' pagesize=' & d2g_PageSize(g)
    END
  END
  ACCEPT
    CASE EVENT()
    OF EVENT:Sized
      IF g THEN d2g_Resize(g).
    OF EVENT:Timer
      ticks += 1
      IF ticks > 25 THEN POST(EVENT:CloseWindow).
    END
  END
  IF g THEN d2g_Detach(g).
  CLOSE(Win)
