  PROGRAM
!  Clicking the drawn scrollbar's trough works but dragging its thumb does
!  nothing. Trough clicks need only EVENT:MouseDown; a drag needs
!  EVENT:MouseMove. What changed in between is that the focus was handed to the
!  LIST so the browse could keep its keyboard.
!
!  So: does an IMM region still get mouse MOVES when it does not have the
!  focus? It plainly still gets mouse DOWNS. The title counts what arrives with
!  the focus on the region, and again with the focus on the list.
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
Win   WINDOW('MoveFocus'),AT(,,320,150),SYSTEM,GRAY,TIMER(20)
        LIST,AT(4,4,120,120),USE(?List),FROM(Q)
        REGION,AT(140,4,170,120),USE(?Rgn),IMM,COLOR(00C0C0C0H)
      END
dn    LONG
mv    LONG
up    LONG
i     LONG
ticks LONG
  CODE
  LOOP i = 1 TO 8
    Q.f1 = 'row ' & i ; ADD(Q)
  END
  OPEN(Win)
  DISPLAY
  SELECT(?Rgn)                                                ! phase one: region has the focus
  Win{PROP:Text} = 'MOVEFOCUS ready-rgn'
  ACCEPT
    CASE EVENT()
    OF EVENT:MouseDown
      IF FIELD() = ?Rgn THEN dn += 1.
    OF EVENT:MouseMove
      IF FIELD() = ?Rgn THEN mv += 1.
    OF EVENT:MouseUp
      IF FIELD() = ?Rgn THEN up += 1.
    OF EVENT:Timer
      ticks += 1
      IF ticks = 25                                           ! phase two: list takes the focus
        SELECT(?List)
        Win{PROP:Text} = 'MOVEFOCUS rgn d' & dn & 'm' & mv & 'u' & up & ' ready-list'
        dn = 0 ; mv = 0 ; up = 0
      ELSIF ticks > 25
        Win{PROP:Text} = 'MOVEFOCUS list d' & dn & 'm' & mv & 'u' & up
      ELSE
        Win{PROP:Text} = 'MOVEFOCUS rgn d' & dn & 'm' & mv & 'u' & up
      END
      IF ticks > 60 THEN POST(EVENT:CloseWindow).
    END
  END
  RETURN
