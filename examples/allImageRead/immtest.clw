  PROGRAM
!  EVENT:MouseDown / MouseMove / MouseUp are documented as arriving "on a
!  REGION with the IMM attribute". The canvas creates its region at run time,
!  where there is no attribute to write - so does PROP:IMM do it? Two regions,
!  one with and one without, and a driver that posts real mouse messages.
  MAP
Main PROCEDURE
  END
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win     WINDOW('ImmTest'),AT(,,320,200),SYSTEM,GRAY,TIMER(100)
          IMAGE,AT(4,4,150,150),USE(?PicA)
          IMAGE,AT(160,4,150,150),USE(?PicB)
        END
rgnA    SIGNED
rgnB    SIGNED
x       SIGNED
y       SIGNED
w       SIGNED
h       SIGNED
dnA     LONG
mvA     LONG
upA     LONG
dnB     LONG
mvB     LONG
upB     LONG
ticks   LONG
  CODE
  OPEN(Win)
  rgnA = CREATE(0,CREATE:Region,?PicA{PROP:Parent})
  GETPOSITION(?PicA,x,y,w,h)
  SETPOSITION(rgnA,x,y,w,h)
  rgnA{PROP:IMM} = 1                                          ! the one under test
  UNHIDE(rgnA)
  rgnB = CREATE(0,CREATE:Region,?PicB{PROP:Parent})
  GETPOSITION(?PicB,x,y,w,h)
  SETPOSITION(rgnB,x,y,w,h)
  UNHIDE(rgnB)                                                ! no IMM, as the canvas ships today
  DO Retitle
  ACCEPT
    CASE FIELD()
    OF rgnA
      CASE EVENT()
      OF EVENT:MouseDown ; dnA += 1 ; DO Retitle
      OF EVENT:MouseMove ; mvA += 1 ; DO Retitle
      OF EVENT:MouseUp   ; upA += 1 ; DO Retitle
      END
    OF rgnB
      CASE EVENT()
      OF EVENT:MouseDown ; dnB += 1 ; DO Retitle
      OF EVENT:MouseMove ; mvB += 1 ; DO Retitle
      OF EVENT:MouseUp   ; upB += 1 ; DO Retitle
      END
    END
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 25 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)

Retitle ROUTINE
  Win{PROP:Text} = 'ImmTest hA=' & rgnA{PROP:Handle} & ' hB=' & rgnB{PROP:Handle} &|
                   ' IMM[d' & dnA & 'm' & mvA & 'u' & upA & ']' &                  |
                   ' PLAIN[d' & dnB & 'm' & mvB & 'u' & upB & ']'
