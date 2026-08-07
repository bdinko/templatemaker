  PROGRAM
!  The grid draws rows of one height and the browse loads a page based on
!  another, so the two never agree on how long a page is - which is why the
!  last records end up below the visible area. The fix is to make the grid use
!  the LIST's own line height. For that, two things have to be known:
!
!    what does PROP:LineHeight answer in - pixels or dialog units?
!    and does the answer follow PROP:Pixels, the way positions do?
!
!  Both go in the title, next to the control's height measured the same two
!  ways, so the numbers can be checked against each other.
  MAP
Main PROCEDURE
  END
  INCLUDE('EQUATES.CLW'),ONCE

  CODE
  Main

Main PROCEDURE
Q     QUEUE
f1      STRING(20)
      END
Win   WINDOW('LineH'),AT(,,300,150),SYSTEM,GRAY,TIMER(30)
        LIST,AT(4,4,290,120),USE(?List),FROM(Q),FORMAT('120L(2)|M~One~')
      END
lhU   LONG
lhP   LONG
hU    SIGNED,AUTO
hP    SIGNED,AUTO
x     SIGNED,AUTO
y     SIGNED,AUTO
w     SIGNED,AUTO
i     LONG
ticks LONG
  CODE
  LOOP i = 1 TO 40
    Q.f1 = 'row ' & i ; ADD(Q)
  END
  OPEN(Win)
  DISPLAY

  0{PROP:Pixels} = 0                                          ! dialog units
  lhU = ?List{PROP:LineHeight}
  GETPOSITION(?List,x,y,w,hU)
  0{PROP:Pixels} = 1                                          ! pixels
  lhP = ?List{PROP:LineHeight}
  GETPOSITION(?List,x,y,w,hP)
  0{PROP:Pixels} = 0

  Win{PROP:Text} = 'LINEH units ' & lhU & ' pixels ' & lhP                     |
                 & ' | height ' & hU & 'u ' & hP & 'p'                         |
                 & ' | rows ' & CHOOSE(lhP > 0, INT(hP / lhP), -1)

  ACCEPT
    IF EVENT() = EVENT:Timer
      ticks += 1
      IF ticks > 10 THEN POST(EVENT:CloseWindow).
    END
  END
  RETURN
