  PROGRAM
!  Can the grid draw a GROUPED, multi-line record - several fields per record
!  over more than one line, under headings that span them? This is the shape
!  the List Box Formatter shows as a tree, laid out here by hand the way
!  BG:Groups lays it out from PROPLIST:GroupNo, LastOnLine and Group.
!
!    group 0  "Last Name"   line 0: LastName  FirstName
!                           line 1: Major     GradYear
!    group 1  "Address"     line 0: Address
!                           line 1: City  State  Zip
!    group 2  "Telephone"   line 0: Telephone
  MAP
Main PROCEDURE
    MODULE('d2grid.c')
      d2g_Available(),LONG,NAME('_d2g_Available')
      d2g_Attach(LONG hwnd,*CSTRING face,LONG pt),LONG,RAW,NAME('_d2g_Attach')
      d2g_Columns(LONG h,LONG n),NAME('_d2g_Columns')
      d2g_Groups(LONG h,LONG n),NAME('_d2g_Groups')
      d2g_Group(LONG h,LONG gi,LONG x,LONG width,*CSTRING title),RAW,NAME('_d2g_Group')
      d2g_ColumnAt(LONG h,LONG col,LONG grp,LONG line,LONG x,LONG width,LONG align),NAME('_d2g_ColumnAt')
      d2g_Lines(LONG h,LONG n),NAME('_d2g_Lines')
      d2g_Wrap(LONG h,LONG on,LONG lines),NAME('_d2g_Wrap')
      d2g_Frozen(LONG h,LONG n),NAME('_d2g_Frozen')
      d2g_Total(LONG h,LONG n),NAME('_d2g_Total')
      d2g_Select(LONG h,LONG row),NAME('_d2g_Select')
      d2g_Page(LONG h,LONG firstRow,LONG rows),NAME('_d2g_Page')
      d2g_Cell(LONG h,LONG visRow,LONG col,*CSTRING s),RAW,NAME('_d2g_Cell')
      d2g_PageSize(LONG h),LONG,NAME('_d2g_PageSize')
      d2g_HitCol(LONG h,LONG x),LONG,NAME('_d2g_HitCol')
      d2g_Repaint(LONG h),NAME('_d2g_Repaint')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  PRAGMA('compile(d2grid.c)')

  CODE
  Main

Main PROCEDURE
Win   WINDOW('GrpTest'),AT(,,540,260),SYSTEM,GRAY,RESIZE,TIMER(100)
        REGION,AT(4,4,532,232),USE(?Grid),IMM
      END
g     LONG
face  CSTRING(32)
t     CSTRING(64)
cell  CSTRING(64)
i     LONG
rows  LONG
hit   LONG
tn    LONG
tn    LONG
ticks LONG
towns STRING('Leeds    Bristol  Madrid   Oporto   Cardiff  Bergen   ')
  CODE
  OPEN(Win)
  IF ~d2g_Available()
    Win{PROP:Text} = 'GrpTest NO-D2D'
  ELSE
    face = 'Segoe UI'
    g = d2g_Attach(?Grid{PROP:Handle}, face, 9)
    IF ~g
      Win{PROP:Text} = 'GrpTest NO-ATTACH'
    ELSE
      d2g_Columns(g, 8)
      t = 'Last Name' ; d2g_Group(g, 0,   0, 220, t)
      t = 'Address'   ; d2g_Group(g, 1, 220, 300, t)
      t = 'Telephone' ; d2g_Group(g, 2, 520, 140, t)
!     group, line, x, width, align
      d2g_ColumnAt(g, 0, 0, 0,   0, 110, 0)                   ! LastName
      d2g_ColumnAt(g, 1, 0, 0, 110, 110, 0)                   ! FirstName
      d2g_ColumnAt(g, 2, 0, 1,   0, 110, 0)                   ! Major
      d2g_ColumnAt(g, 3, 0, 1, 110, 110, 2)                   ! GradYear
      d2g_ColumnAt(g, 4, 1, 0, 220, 160, 0)                   ! Address
      d2g_ColumnAt(g, 5, 1, 1, 220, 160, 0)                   ! City
      d2g_ColumnAt(g, 6, 1, 1, 380, 140, 0)                   ! State Zip
      d2g_ColumnAt(g, 7, 2, 0, 520, 140, 0)                   ! Telephone
      d2g_Groups(g, 3)
      d2g_Lines(g, 2)                                         ! two lines to a record
      d2g_Wrap(g, 1, 2)                                       ! and long text may use two more
      d2g_Frozen(g, 1)                                        ! the name group stays put

      rows = d2g_PageSize(g) + 1
      IF rows > 20 THEN rows = 20.
      d2g_Page(g, 0, rows)
      LOOP i = 1 TO rows
        cell = 'Ackerman ' & i          ; d2g_Cell(g, i - 1, 0, cell)
        cell = 'Neal E'                 ; d2g_Cell(g, i - 1, 1, cell)
        cell = 'Computer Science'       ; d2g_Cell(g, i - 1, 2, cell)
        cell = '20' & (10 + i)          ; d2g_Cell(g, i - 1, 3, cell)
        cell = (340 + i) & ' Tidd Drive, Apartment ' & i & ', Lighthouse Point Business Park, Building C'
                                          d2g_Cell(g, i - 1, 4, cell)
        tn = i - 1 - INT((i - 1) / 6) * 6
        cell = CLIP(towns[1 + tn * 9 : 8 + tn * 9])
        d2g_Cell(g, i - 1, 5, cell)
        cell = 'FL  3328' & (i - INT(i / 10) * 10)
        d2g_Cell(g, i - 1, 6, cell)
        cell = '305-555-01' & (10 + i)  ; d2g_Cell(g, i - 1, 7, cell)
      END
      d2g_Total(g, rows)
      d2g_Select(g, 2)
      hit = d2g_HitCol(g, 300)                                ! in the Address group
      Win{PROP:Text} = 'GRPTEST rows=' & rows & ' hitcol@300=' & hit
      d2g_Repaint(g)
    END
  END
  ACCEPT
    IF EVENT() = EVENT:Timer
      ticks += 1
      IF ticks > 40 THEN POST(EVENT:CloseWindow).
    END
  END
  RETURN
