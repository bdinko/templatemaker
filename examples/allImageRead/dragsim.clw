  PROGRAM
!  Simulate a drag the way the canvas performs it. A real drag arrives as a
!  stream of small MouseMove deltas - a pixel or three at a time - and the
!  canvas turns each one into image pixels on its own. Compare that with
!  measuring from where the drag STARTED, and see which one ends up where the
!  pointer actually went.
  MAP
Main PROCEDURE
  END
  INCLUDE('EQUATES.CLW'),ONCE
  CODE
  Main

Main PROCEDURE
Win     WINDOW('DragSim'),AT(,,660,140),SYSTEM,GRAY,TIMER(100)
        END
zoom    LONG
step    LONG
i       LONG
mouse   LONG
prev    LONG
panInc  LONG                                                  ! pan built up delta by delta
panAnc  LONG                                                  ! pan measured from the anchor
pan0    LONG
mouse0  LONG
want    LONG
note    CSTRING(400)
badInc  LONG
badAnc  LONG
  CODE
  OPEN(Win)
!  Drag the pointer 60 pixels to the left, in steps of 1, 2 and 3 pixels, at
!  three zooms. The picture should follow by exactly 60 screen pixels, which is
!  6000/zoom image pixels.
  LOOP zoom = 200 TO 800 BY 300
    LOOP step = 1 TO 3
      panInc = 0
      panAnc = 0
      pan0   = 0
      mouse  = 0
      mouse0 = 0
      prev   = 0
      LOOP i = 1 TO 60 BY step
        mouse = i                                             ! the pointer, in screen pixels
        panInc += (prev - mouse) * 100 / zoom                  ! what the canvas does now
        prev = mouse
        panAnc = pan0 + (mouse0 - mouse) * 100 / zoom          ! measured from the anchor
      END
      want = (mouse0 - mouse) * 100 / zoom                     ! where it should have ended up
      IF panInc <> want THEN badInc += 1.
      IF panAnc <> want THEN badAnc += 1.
      note = CLIP(note) & ' z' & zoom & '/s' & step & '[want' & want &        |
             ' inc' & panInc & ' anc' & panAnc & ']'
    END
  END
  Win{PROP:Text} = 'DragSim' & CLIP(note) & '  incWrong=' & badInc &          |
                   ' ancWrong=' & badAnc
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      IF 1 = 2 THEN POST(EVENT:CloseWindow).
    END
  END
  CLOSE(Win)
