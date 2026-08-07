  PROGRAM
!  Dragging a group narrow and then wide again used to leave every field piled
!  up on the left: each drag scaled the CURRENT numbers, and integer arithmetic
!  drives them to nothing. Rebuilt from the proportions the format was read
!  with, it has to come back to exactly where it started.
!
!  Squeeze the Address group 300 -> 60 -> 300 and compare the field widths with
!  what they were. The title says PASS only if every one of them matches.
  MAP
Main PROCEDURE
    MODULE('d2grid.c')
      d2g_Available(),LONG,NAME('_d2g_Available')
      d2g_Attach(LONG hwnd,*CSTRING face,LONG pt),LONG,RAW,NAME('_d2g_Attach')
      d2g_Columns(LONG h,LONG n),NAME('_d2g_Columns')
      d2g_Groups(LONG h,LONG n),NAME('_d2g_Groups')
      d2g_Group(LONG h,LONG gi,LONG x,LONG width,*CSTRING title),RAW,NAME('_d2g_Group')
      d2g_ColumnAt(LONG h,LONG col,LONG grp,LONG line,LONG x,LONG width,LONG align,*CSTRING title),RAW,NAME('_d2g_ColumnAt')
      d2g_Lines(LONG h,LONG n),NAME('_d2g_Lines')
      d2g_SetGrpWidth(LONG h,LONG g,LONG width),NAME('_d2g_SetGrpWidth')
      d2g_GrpWidth(LONG h,LONG g),LONG,NAME('_d2g_GrpWidth')
      d2g_GrpColW(LONG h,LONG col),LONG,NAME('_d2g_GrpColW')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE
  PRAGMA('compile(d2grid.c)')

  CODE
  Main

Main PROCEDURE
Win   WINDOW('PropTest'),AT(,,400,120),SYSTEM,GRAY,TIMER(50)
        REGION,AT(4,4,392,92),USE(?Grid),IMM
      END
g     LONG
face  CSTRING(32)
t     CSTRING(64)
w0    LONG,DIM(4)
w1    LONG,DIM(4)
i     LONG
bad   LONG
res   CSTRING(200)
ticks LONG
  CODE
  OPEN(Win)
  IF ~d2g_Available()
    Win{PROP:Text} = 'PropTest NO-D2D'
  ELSE
    face = 'Segoe UI'
    g = d2g_Attach(?Grid{PROP:Handle}, face, 9)
    IF ~g
      Win{PROP:Text} = 'PropTest NO-ATTACH'
    ELSE
      d2g_Columns(g, 4)
      t = 'Name'    ; d2g_Group(g, 0,   0, 200, t)
      t = 'Address' ; d2g_Group(g, 1, 200, 300, t)
      t = 'Last'    ; d2g_ColumnAt(g, 0, 0, 0,   0, 200, 0, t)
      t = ''        ; d2g_ColumnAt(g, 1, 1, 0, 200, 300, 0, t)   ! whole width
      t = ''        ; d2g_ColumnAt(g, 2, 1, 1, 200, 160, 0, t)   ! City
      t = ''        ; d2g_ColumnAt(g, 3, 1, 1, 360, 140, 0, t)   ! State Zip
      d2g_Groups(g, 2)
      d2g_Lines(g, 2)

      LOOP i = 1 TO 4
        w0[i] = d2g_GrpColW(g, i - 1)
      END
!     squeeze it right down, then back to where it was
      d2g_SetGrpWidth(g, 1, 60)
      d2g_SetGrpWidth(g, 1, 300)
      LOOP i = 1 TO 4
        w1[i] = d2g_GrpColW(g, i - 1)
        IF w1[i] <> w0[i] THEN bad += 1.
      END
      res = 'was ' & w0[1] & ',' & w0[2] & ',' & w0[3] & ',' & w0[4]           |
          & ' now ' & w1[1] & ',' & w1[2] & ',' & w1[3] & ',' & w1[4]          |
          & ' grp=' & d2g_GrpWidth(g, 1)
      Win{PROP:Text} = CHOOSE(bad = 0, 'PROP-PASS ', 'PROP-FAIL ') & CLIP(res)
    END
  END
  ACCEPT
    IF EVENT() = EVENT:Timer
      ticks += 1
      IF ticks > 12 THEN POST(EVENT:CloseWindow).
    END
  END
  RETURN
